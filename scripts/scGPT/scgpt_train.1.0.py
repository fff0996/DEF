#!/usr/bin/env python3
# scGPT pipeline, module 3: train a patient-level classifier on scGPT cell embeddings.
# scGPT itself stays frozen. Each patient is a bag of cell embeddings; the model pools the
# cells (gated attention, or the plain mean) and gives the probability of the positive label.
# Performance is measured with the scgpt_prep folds (every patient is predicted by a model that
# never saw it), then a final model is trained on all labeled patients and saved with a model
# card for scgpt_predict and scgpt_compare.
#
# Usage:
#   python3 scgpt_train.1.0.py input_dir="..." output_dir="..."
#       [pooling="attention"] [init_model=""] [hidden="64"] [epochs="200"]
#       [learning_rate="0.001"] [weight_decay="0.01"] [dropout="0.25"] [cell_dropout="0.2"]
#       [model_name=""] [data_terms=""] [seed="1234"]
#
# Example:
#   apptainer exec bx_scgpt.1.0.sif python3 scgpt_train.1.0.py \
#       input_dir=/data/scgpt_embed output_dir=/data/scgpt_train model_name=KBDS_lung_ICI
#
# Arguments:
#   input_dir     (required) - scgpt_embed output folder (embeddings.h5ad, patients.tsv, splits.tsv)
#   output_dir    (required) - Output directory
#   pooling       (optional) - attention (gated attention over cells; also shows which cells
#                              weigh most) or mean (average embedding + logistic layer).
#                              default: attention
#   init_model    (optional) - scgpt_train output folder of an earlier model to continue from
#                              (same scGPT checkpoint and settings). Empty starts from random
#                              weights. default: empty
#   hidden        (optional) - Size of the attention layer. default: 64
#   epochs        (optional) - Training passes over all patients. default: 200
#   learning_rate (optional) - Adam learning rate. default: 0.001
#   weight_decay  (optional) - L2 penalty (AdamW). default: 0.01
#   dropout       (optional) - Dropout on the pooled patient vector. default: 0.25
#   cell_dropout  (optional) - Fraction of each patient's cells left out at random in every
#                              training pass (makes the model rely on many cells). default: 0.2
#   model_name    (optional) - Name written in the model card. default: scgpt_<date>
#   data_terms    (optional) - Terms of use of the training data, copied into the model card
#                              (e.g. "K-BDS KAP241028, approved users only"). default: empty
#   seed          (optional) - Random seed. default: 1234
#
# Outputs (output_dir):
#   model/model.pt         final model (weights and settings)
#   model/model_card.json  what the model was trained on and how well it did (also .md)
#   cv_predictions.tsv     cross-validation: Repeat, Fold, PatientID, Label, label01, prob
#   cv_cohort_predictions.tsv   leave-one-cohort-out predictions (two or more labeled cohorts)
#   cv_metrics.tsv         AUC per repeat and for the patient-averaged predictions (95% CI)
#   plots/                 roc_cv (cross-validation ROC), training_loss (final model)
#   logs/                  <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Small cohorts give wide confidence intervals; read cv_metrics.tsv together with
# scgpt_compare, which checks the model against simpler baselines on the same patients.
# Rerunning removes everything in output_dir except logs/.

import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import warnings
from pathlib import Path

MODULE = "scgpt_train"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"pooling": "attention", "init_model": "", "hidden": "64", "epochs": "200",
            "learning_rate": "0.001", "weight_decay": "0.01", "dropout": "0.25", "cell_dropout": "0.2",
            "model_name": "", "data_terms": "", "seed": "1234"}


# ----------------------------------------------------------------- common (same in every module)
def early_fail(message):
    """Error before the log files exist: stderr only."""
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    params = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            early_fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            early_fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            early_fail(f"Unknown parameter: {key}")
        value = value.strip().strip("'\"")
        params[key] = value if value or key in REQUIRED else OPTIONAL[key]
    for key in REQUIRED:
        if not params.get(key):
            early_fail(f"Required parameter '{key}' is missing")
    return params


def allocated_cores():
    """Cores bound to this job. Public CLOSHA modules run with OMP_NUM_THREADS=1, which nproc
    would follow, so it is removed for this one call (docs/CLOSHA_Script_Rules_v1.md 11)."""
    try:
        out = subprocess.run(["env", "-u", "OMP_NUM_THREADS", "-u", "OMP_THREAD_LIMIT", "nproc"],
                             capture_output=True, text=True, check=True).stdout.strip()
        return max(1, int(out))
    except (OSError, ValueError, subprocess.CalledProcessError):
        return max(1, len(os.sched_getaffinity(0)))


class Log:
    """stdout -> <stamp>.log, stderr -> <stamp>.error.log, both also on screen."""

    def __init__(self, output_dir):
        logs_dir = output_dir / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        stamp = f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{os.getpid()}"
        self.log_file = logs_dir / f"{stamp}.log"
        self.err_file = logs_dir / f"{stamp}.error.log"
        self.out = self.log_file.open("a", encoding="utf-8")
        self.err = self.err_file.open("a", encoding="utf-8")
        warnings.showwarning = self._python_warning

    def msg(self, text=""):
        print(text, flush=True)
        self.out.write(text + "\n")
        self.out.flush()

    def warn(self, text):
        print(f"Warning: {text}", file=sys.stderr, flush=True)
        self.err.write(f"Warning: {text}\n")
        self.err.flush()

    def fail(self, text):
        print(f"Error: {text}", file=sys.stderr, flush=True)
        self.err.write(f"Error: {text}\n")
        self.err.flush()
        sys.exit(1)

    def step(self, text):
        self.msg(f"############################## {text}")

    def _python_warning(self, message, category, filename, lineno, file=None, line=None):
        text = f"Warning: {category.__name__}: {message} ({Path(filename).name}:{lineno})"
        print(text, file=sys.stderr, flush=True)
        self.err.write(text + "\n")
        self.err.flush()


def prepare_output(output_dir, inputs):
    """Remove everything in output_dir except logs/, after checking that no input is inside it."""
    out = Path(output_dir).resolve()
    if str(out) == "/":
        early_fail("output_dir must not be /")
    for p in inputs:
        rp = Path(p).resolve()
        if rp == out or out in rp.parents:
            early_fail(f"input {p} is inside output_dir {out}, which is cleared on each run")
    if out.exists():
        for child in out.iterdir():
            if child.name == "logs":
                continue
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
    out.mkdir(parents=True, exist_ok=True)
    return out


def positive_int(log, name, value, minimum=1):
    if not re.fullmatch(r"\d+", value) or int(value) < minimum:
        log.fail(f"{name} must be an integer >= {minimum}: {value}")
    return int(value)


def number(log, name, value, low, high):
    try:
        v = float(value)
    except ValueError:
        log.fail(f"{name} must be a number: {value}")
    if not low <= v <= high:
        log.fail(f"{name} must be between {low} and {high}: {value}")
    return v


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def save_plot(fig, path_stem):
    fig.savefig(f"{path_stem}.png", dpi=150, bbox_inches="tight", facecolor="white")
    fig.savefig(f"{path_stem}.pdf", bbox_inches="tight", facecolor="white")


# ----------------------------------------------------------------- model (same in scgpt_predict)
def build_model(torch, cfg):
    nn = torch.nn

    class PatientModel(nn.Module):
        """Bag of cell embeddings -> logit of the positive label.
        attention: gated attention pooling (Ilse et al., ICML 2018); mean: average of the cells."""

        def __init__(self):
            super().__init__()
            d, h = cfg["embedding_size"], cfg["hidden"]
            self.pooling = cfg["pooling"]
            if self.pooling == "attention":
                self.att_v = nn.Linear(d, h)
                self.att_u = nn.Linear(d, h)
                self.att_w = nn.Linear(h, 1)
            self.drop = nn.Dropout(cfg["dropout"])
            self.out = nn.Linear(d, 1)

        def forward(self, x, mask):
            # x: patients x cells x d, mask: patients x cells (True = real cell)
            if self.pooling == "attention":
                s = self.att_w(torch.tanh(self.att_v(x)) * torch.sigmoid(self.att_u(x))).squeeze(-1)
                s = s.masked_fill(~mask, float("-inf"))
                a = torch.softmax(s, dim=1)
            else:
                a = mask.float() / mask.float().sum(dim=1, keepdim=True)
            z = (a.unsqueeze(-1) * x).sum(dim=1)
            return self.out(self.drop(z)).squeeze(-1), a

    return PatientModel()


def make_bags(np, torch, emb, patient_of_cell, patients):
    """Pad each patient's cells into one tensor with a mask."""
    idx = {p: np.where(patient_of_cell == p)[0] for p in patients}
    n_max = max(len(v) for v in idx.values())
    x = np.zeros((len(patients), n_max, emb.shape[1]), dtype=np.float32)
    m = np.zeros((len(patients), n_max), dtype=bool)
    for i, p in enumerate(patients):
        c = idx[p]
        x[i, :len(c)] = emb[c]
        m[i, :len(c)] = True
    return torch.from_numpy(x), torch.from_numpy(m)


def fit(torch, np, cfg, x, m, y, seed, init_state=None, record=None):
    torch.manual_seed(seed)
    model = build_model(torch, cfg)
    if init_state is not None:
        model.load_state_dict(init_state)
    opt = torch.optim.AdamW(model.parameters(), lr=cfg["learning_rate"], weight_decay=cfg["weight_decay"])
    yt = torch.tensor(y, dtype=torch.float32)
    pos = max(float(y.sum()), 1.0)
    neg = max(float(len(y) - y.sum()), 1.0)
    loss_fn = torch.nn.BCEWithLogitsLoss(pos_weight=torch.tensor(neg / pos))
    gen = torch.Generator().manual_seed(seed)
    model.train()
    for _ in range(cfg["epochs"]):
        mm = m
        if cfg["cell_dropout"] > 0:
            keep = torch.rand(m.shape, generator=gen) >= cfg["cell_dropout"]
            mm = m & keep
            empty = mm.sum(dim=1) == 0
            mm[empty] = m[empty]
        opt.zero_grad()
        logit, _ = model(x, mm)
        loss = loss_fn(logit, yt)
        loss.backward()
        opt.step()
        if record is not None:
            record.append(float(loss))
    model.eval()
    return model


def predict(torch, model, x, m):
    with torch.no_grad():
        logit, a = model(x, m)
    return torch.sigmoid(logit).numpy(), a.numpy()


def auc_ci(np, roc_auc_score, y, p, seed, n_boot=2000):
    if len(set(y)) < 2:
        return float("nan"), float("nan"), float("nan")
    auc = roc_auc_score(y, p)
    rng = np.random.default_rng(seed)
    boots = []
    for _ in range(n_boot):
        i = rng.integers(0, len(y), len(y))
        if len(set(y[i])) == 2:
            boots.append(roc_auc_score(y[i], p[i]))
    return auc, float(np.percentile(boots, 2.5)), float(np.percentile(boots, 97.5))


# ----------------------------------------------------------------- module
def main():
    params = parse_args(sys.argv[1:])
    in_dir = Path(params["input_dir"])
    for f in ("embeddings.h5ad", "patients.tsv", "embed_info.json"):
        if not (in_dir / f).exists():
            early_fail(f"{f} not found in input_dir {in_dir}; give the scgpt_embed output folder")
    init_dir = Path(params["init_model"]) if params["init_model"] else None
    out = prepare_output(params["output_dir"], [in_dir] + ([init_dir] if init_dir else []))
    log = Log(out)
    start = datetime.datetime.now()

    if params["pooling"] not in ("attention", "mean"):
        log.fail(f"pooling must be attention or mean: {params['pooling']}")
    seed = positive_int(log, "seed", params["seed"], 0)
    cfg = {"pooling": params["pooling"], "hidden": positive_int(log, "hidden", params["hidden"], 1),
           "epochs": positive_int(log, "epochs", params["epochs"], 1),
           "learning_rate": number(log, "learning_rate", params["learning_rate"], 1e-6, 1.0),
           "weight_decay": number(log, "weight_decay", params["weight_decay"], 0.0, 10.0),
           "dropout": number(log, "dropout", params["dropout"], 0.0, 0.9),
           "cell_dropout": number(log, "cell_dropout", params["cell_dropout"], 0.0, 0.9)}
    cores = allocated_cores()

    for name in ("numpy", "pandas", "torch", "anndata", "sklearn", "matplotlib"):
        try:
            __import__(name)
        except ImportError:
            log.fail(f"required Python package not found: {name}")
    import numpy as np
    import pandas as pd
    import anndata as ad
    import torch
    from sklearn.metrics import roc_auc_score, roc_curve
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    torch.set_num_threads(cores)

    log.msg(f"############################## {MODULE}")
    log.msg(f"Log file: {log.log_file}")
    log.msg(f"Start time: {start:%Y-%m-%d %H:%M:%S}")
    log.msg("")
    log.msg("parameters:")
    for k in REQUIRED + list(OPTIONAL):
        log.msg(f"  {k:<14}= {params[k]}")
    log.msg(f"  {'threads':<14}= {cores} (allocated {cores})")
    log.msg("")

    # ------------------------------------------------------------- Step 1: data
    log.step("Step 1: Embeddings, labels and folds")
    info = json.loads((in_dir / "embed_info.json").read_text())
    e = ad.read_h5ad(in_dir / "embeddings.h5ad")
    emb = np.asarray(e.X, dtype=np.float32)
    cell_patient = e.obs["PatientID"].astype(str).values
    pat = pd.read_csv(in_dir / "patients.tsv", sep="\t", dtype=str, keep_default_na=False)
    pat = pat[pat["PatientID"].isin(set(cell_patient))]
    lab = pat[pat["label01"] != ""].reset_index(drop=True)
    if lab.empty:
        log.fail("no labeled patient in input_dir: training needs labels (Label column of the sample sheet)")
    y_of = dict(zip(lab["PatientID"], lab["label01"].astype(int)))
    n_pos, n_neg = int(sum(y_of.values())), int(len(y_of) - sum(y_of.values()))
    log.msg(f"Patients: {len(lab)} labeled (positive {info['positive_label']} = {n_pos}, "
            f"negative {info['negative_label']} = {n_neg}); cells: {e.n_obs}; embedding size {emb.shape[1]}")
    if min(n_pos, n_neg) < 2:
        log.fail(f"each label needs at least 2 patients; positive {n_pos}, negative {n_neg}")
    if len(lab) < 100:
        log.warn(f"{len(lab)} labeled patients: performance estimates are uncertain (see the 95% CI)")
    cfg["embedding_size"] = int(emb.shape[1])

    init_state, init_card = None, None
    if init_dir:
        mp = init_dir / "model" / "model.pt"
        if not mp.exists():
            log.fail(f"model/model.pt not found in init_model {init_dir}")
        saved = torch.load(mp, map_location="cpu", weights_only=False)
        init_card = json.loads((init_dir / "model" / "model_card.json").read_text())
        if init_card["scgpt_checkpoint_sha256"] != info["checkpoint_sha256"]:
            log.fail("init_model was trained on embeddings of another scGPT checkpoint "
                     f"({init_card['scgpt_checkpoint']}); embed this data with the same checkpoint")
        for k in ("pooling", "hidden", "embedding_size"):
            if saved["config"][k] != cfg[k]:
                log.fail(f"init_model has {k}={saved['config'][k]}, this run {k}={cfg[k]}; use the same setting")
        init_state = saved["state_dict"]
        log.msg(f"Continuing from model {init_card['model_name']} ({init_card['model_id']})")

    # ------------------------------------------------------------- Step 2: cross-validation
    log.step("Step 2: Cross-validation (patients never seen in training)")
    cv_rows, metric_rows = [], []
    splits_file = in_dir / "splits.tsv"
    if not splits_file.exists():
        log.fail("splits.tsv not found in input_dir (scgpt_prep makes it when labels are given)")
    splits = pd.read_csv(splits_file, sep="\t", dtype={"PatientID": str})
    splits = splits[splits["PatientID"].isin(y_of)]
    for (rep, fold), s in splits.groupby(["Repeat", "Fold"]):
        tr = s.loc[s["Set"] == "train", "PatientID"].tolist()
        te = s.loc[s["Set"] == "test", "PatientID"].tolist()
        xtr, mtr = make_bags(np, torch, emb, cell_patient, tr)
        ytr = np.array([y_of[p] for p in tr])
        model = fit(torch, np, cfg, xtr, mtr, ytr, seed + 100 * int(rep) + int(fold), init_state)
        xte, mte = make_bags(np, torch, emb, cell_patient, te)
        p, _ = predict(torch, model, xte, mte)
        for pid, prob in zip(te, p):
            cv_rows.append((int(rep), int(fold), pid, y_of[pid], float(prob)))
        log.msg(f"  repeat {rep} fold {fold}: train {len(tr)}, test {len(te)}")
    cv = pd.DataFrame(cv_rows, columns=["Repeat", "Fold", "PatientID", "label01", "prob"])
    lab_name = {1: info["positive_label"], 0: info["negative_label"]}
    cv.insert(3, "Label", cv["label01"].map(lab_name))
    cv.to_csv(out / "cv_predictions.tsv", sep="\t", index=False)
    for rep, s in cv.groupby("Repeat"):
        if s["label01"].nunique() == 2:
            metric_rows.append(("cv_repeat", str(rep), len(s), roc_auc_score(s["label01"], s["prob"]), "", ""))
    avg = cv.groupby("PatientID").agg(label01=("label01", "first"), prob=("prob", "mean")).reset_index()
    auc, lo, hi = auc_ci(np, roc_auc_score, avg["label01"].values, avg["prob"].values, seed)
    metric_rows.append(("cv_patient_mean", "all", len(avg), auc, lo, hi))
    rep_aucs = [r[3] for r in metric_rows if r[0] == "cv_repeat"]
    log.msg(f"Cross-validation AUC: {auc:.3f} (95% CI {lo:.3f}-{hi:.3f}); per repeat "
            + ", ".join(f"{a:.3f}" for a in rep_aucs))

    cohort_file = in_dir / "splits_cohort.tsv"
    if cohort_file.exists():
        cs = pd.read_csv(cohort_file, sep="\t", dtype={"PatientID": str})
        crows = []
        for coh, s in cs.groupby("TestCohort"):
            tr = [p for p in s.loc[s["Set"] == "train", "PatientID"] if p in y_of]
            te = [p for p in s.loc[s["Set"] == "test", "PatientID"] if p in y_of]
            xtr, mtr = make_bags(np, torch, emb, cell_patient, tr)
            model = fit(torch, np, cfg, xtr, mtr, np.array([y_of[p] for p in tr]), seed, init_state)
            xte, mte = make_bags(np, torch, emb, cell_patient, te)
            p, _ = predict(torch, model, xte, mte)
            yte = np.array([y_of[q] for q in te])
            crows += [(coh, pid, lab_name[y_of[pid]], y_of[pid], float(pr)) for pid, pr in zip(te, p)]
            a, l, h = auc_ci(np, roc_auc_score, yte, p, seed)
            metric_rows.append(("leave_cohort_out", coh, len(te), a, l, h))
            log.msg(f"Leave-cohort-out, test cohort {coh}: AUC {a:.3f} (95% CI {l:.3f}-{h:.3f}), {len(te)} patients")
        pd.DataFrame(crows, columns=["TestCohort", "PatientID", "Label", "label01", "prob"]).to_csv(
            out / "cv_cohort_predictions.tsv", sep="\t", index=False)
    metrics = pd.DataFrame(metric_rows, columns=["evaluation", "part", "patients", "auc", "auc_ci_low", "auc_ci_high"])
    metrics.to_csv(out / "cv_metrics.tsv", sep="\t", index=False, float_format="%.4f")

    # ------------------------------------------------------------- Step 3: final model
    log.step("Step 3: Final model on all labeled patients")
    allp = lab["PatientID"].tolist()
    xa, ma = make_bags(np, torch, emb, cell_patient, allp)
    losses = []
    final = fit(torch, np, cfg, xa, ma, np.array([y_of[p] for p in allp]), seed, init_state, losses)
    (out / "model").mkdir()
    torch.save({"state_dict": final.state_dict(), "config": cfg}, out / "model" / "model.pt")
    created = datetime.datetime.now()
    model_sha = sha256_file(out / "model" / "model.pt")
    name = params["model_name"] or f"scgpt_{created:%Y%m%d}"
    card = {
        "model_name": name, "model_id": f"{name}_{model_sha[:12]}", "created": f"{created:%Y-%m-%d %H:%M:%S}",
        "module": MODULE, "model_sha256": model_sha, "config": cfg, "seed": seed,
        "scgpt_checkpoint": info["checkpoint"], "scgpt_checkpoint_sha256": info["checkpoint_sha256"],
        "embedding": {"max_cells_per_patient": info["options"]["max_cells_per_patient"],
                      "max_genes": info["options"]["max_genes"]},
        "positive_label": info["positive_label"], "negative_label": info["negative_label"],
        "tissue": info["tissue"], "time": info["time"],
        "training_data": {"patients": len(allp), "positive": n_pos, "negative": n_neg,
                          "cohorts": sorted(pat.loc[pat["PatientID"].isin(allp), "Cohort"].unique().tolist()),
                          "cells": int(np.isin(cell_patient, allp).sum()), "splits_sha256": info.get("splits_sha256", "")},
        "cross_validation": {"auc": round(auc, 4), "auc_ci_95": [round(lo, 4), round(hi, 4)],
                             "auc_per_repeat": [round(a, 4) for a in rep_aucs]},
        "init_model": init_card["model_id"] if init_card else "",
        "data_terms": params["data_terms"],
    }
    if any(r[0] == "leave_cohort_out" for r in metric_rows):
        card["leave_cohort_out"] = {r[1]: round(r[3], 4) for r in metric_rows if r[0] == "leave_cohort_out"}
    (out / "model" / "model_card.json").write_text(json.dumps(card, indent=2, ensure_ascii=False))
    md = [f"# Model card: {name}", "", f"- Model ID: {card['model_id']}", f"- Created: {card['created']}",
          f"- scGPT checkpoint: {card['scgpt_checkpoint']} (frozen), SHA256 {card['scgpt_checkpoint_sha256'][:16]}...",
          f"- Pooling: {cfg['pooling']}, hidden {cfg['hidden']}, epochs {cfg['epochs']}",
          f"- Label: positive = {card['positive_label']}, negative = {card['negative_label']}",
          f"- Tissue / time: {card['tissue']} / {card['time']}",
          f"- Training patients: {len(allp)} (positive {n_pos}, negative {n_neg}), cohorts: "
          + ", ".join(card["training_data"]["cohorts"]),
          f"- Cross-validation AUC: {auc:.3f} (95% CI {lo:.3f}-{hi:.3f})",
          f"- Continued from: {card['init_model'] or 'none'}",
          f"- Data terms: {card['data_terms'] or 'not given'}", "",
          "Use only on data of the same tissue and time point, embedded with the same scGPT checkpoint."]
    (out / "model" / "model_card.md").write_text("\n".join(md) + "\n")
    log.msg(f"Model: {card['model_id']}")

    # ------------------------------------------------------------- Step 4: plots
    log.step("Step 4: Plots")
    (out / "plots").mkdir()
    fig, ax = plt.subplots(figsize=(4.6, 4.4))
    if avg["label01"].nunique() == 2:
        fpr, tpr, _ = roc_curve(avg["label01"], avg["prob"])
        ax.plot(fpr, tpr, color="#D55E00", lw=2, label=f"AUC {auc:.3f} ({lo:.2f}-{hi:.2f})")
    ax.plot([0, 1], [0, 1], color="#999999", ls="--", lw=1)
    ax.set_xlabel("False positive rate")
    ax.set_ylabel("True positive rate")
    ax.set_title(f"Cross-validation ROC ({len(avg)} patients)")
    ax.legend(loc="lower right", frameon=False)
    save_plot(fig, out / "plots" / "roc_cv")
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(5, 3.4))
    ax.plot(range(1, len(losses) + 1), losses, color="#0072B2")
    ax.set_xlabel("Epoch")
    ax.set_ylabel("Training loss")
    ax.set_title("Final model training")
    save_plot(fig, out / "plots" / "training_loss")
    plt.close(fig)

    log.step("Summary")
    log.msg(f"Patients: {len(allp)}, cross-validation AUC {auc:.3f} (95% CI {lo:.3f}-{hi:.3f})")
    log.step("Done")
    log.msg(f"Model: {out / 'model'}")
    log.msg(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
