#!/usr/bin/env python3
# scGPT pipeline, module 4: predict patient labels with a trained model.
# Reads scgpt_embed output (labels not needed) and a model from scgpt_train (or the built-in
# model of the image, when it has one), and writes the probability of the positive label for
# every patient and, for attention models, how much each cell weighed in that patient.
#
# Usage:
#   python3 scgpt_predict.1.0.py input_dir="..." output_dir="..." [model="builtin"]
#       [threshold="0.5"]
#
# Example:
#   apptainer exec bx_scgpt.1.0.sif python3 scgpt_predict.1.0.py \
#       input_dir=/data/new_embed model=/data/scgpt_train output_dir=/data/scgpt_predict
#
# Arguments:
#   input_dir  (required) - scgpt_embed output folder of the patients to predict
#   output_dir (required) - Output directory
#   model      (optional) - scgpt_train output folder (its model/ is used), or builtin for the
#                           model shipped in the image. default: builtin
#   threshold  (optional) - Probability at or above which a patient is called positive.
#                           default: 0.5
#
# Outputs (output_dir):
#   predictions.tsv          PatientID, Cohort, cells, prob, predicted label, given label (if any)
#   cell_attention.tsv.gz    attention models: cell, patient, cell type, attention weight
#   attention_by_cell_type.tsv   attention models: share of attention per patient and cell type
#   model_card.json          copy of the card of the model used
#   plots/                   predictions (probability per patient), attention_by_cell_type
#   logs/                    <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# The embeddings must come from the same scGPT checkpoint as the model (checked with SHA256).
# A different tissue or time point than the training data gives a warning. Rerunning removes
# everything in output_dir except logs/.

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import warnings
from pathlib import Path

MODULE = "scgpt_predict"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"model": "builtin", "threshold": "0.5"}
BUILTIN_MODEL = "/opt/bio/share/scgpt/models/default"


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


def use_private_cache(out):
    """Caches of matplotlib, numba, Hugging Face and PyTorch go to output_dir/.cache (removed at
    the end), never to the user's home, which CLOSHA binds from the host. No network access."""
    cache = out / ".cache"
    cache.mkdir(exist_ok=True)
    for var in ("XDG_CACHE_HOME", "MPLCONFIGDIR", "NUMBA_CACHE_DIR", "HF_HOME", "TORCH_HOME"):
        os.environ[var] = str(cache / var.lower())
    os.environ["HF_DATASETS_OFFLINE"] = "1"
    os.environ["HF_HUB_OFFLINE"] = "1"
    return cache

def save_plot(fig, path_stem):
    fig.savefig(f"{path_stem}.png", dpi=150, bbox_inches="tight", facecolor="white")
    fig.savefig(f"{path_stem}.pdf", bbox_inches="tight", facecolor="white")


# ----------------------------------------------------------------- model (same in scgpt_train)
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
    return torch.from_numpy(x), torch.from_numpy(m), idx


# ----------------------------------------------------------------- module
def main():
    params = parse_args(sys.argv[1:])
    in_dir = Path(params["input_dir"])
    for f in ("embeddings.h5ad", "embed_info.json"):
        if not (in_dir / f).exists():
            early_fail(f"{f} not found in input_dir {in_dir}; give the scgpt_embed output folder")
    model_dir = Path(BUILTIN_MODEL) if params["model"] == "builtin" else Path(params["model"]) / "model"
    if not (model_dir / "model.pt").exists():
        if params["model"] == "builtin":
            early_fail(f"this image has no built-in model ({BUILTIN_MODEL}); give model=<scgpt_train output folder>")
        early_fail(f"model/model.pt not found in {params['model']}; give the scgpt_train output folder")
    out = prepare_output(params["output_dir"], [in_dir, model_dir])
    log = Log(out)
    cache = use_private_cache(out)
    start = datetime.datetime.now()
    try:
        threshold = float(params["threshold"])
    except ValueError:
        log.fail(f"threshold must be a number: {params['threshold']}")
    if not 0 < threshold < 1:
        log.fail(f"threshold must be between 0 and 1: {threshold}")
    cores = allocated_cores()

    for name in ("numpy", "pandas", "torch", "anndata", "matplotlib"):
        try:
            __import__(name)
        except ImportError:
            log.fail(f"required Python package not found: {name}")
    import numpy as np
    import pandas as pd
    import anndata as ad
    import torch
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
        log.msg(f"  {k:<11}= {params[k]}")
    log.msg(f"  {'model dir':<11}= {model_dir}")
    log.msg(f"  {'threads':<11}= {cores} (allocated {cores})")
    log.msg("")

    # ------------------------------------------------------------- Step 1: model and data
    log.step("Step 1: Model and embeddings")
    card = json.loads((model_dir / "model_card.json").read_text())
    saved = torch.load(model_dir / "model.pt", map_location="cpu", weights_only=False)
    cfg = saved["config"]
    model = build_model(torch, cfg)
    model.load_state_dict(saved["state_dict"])
    model.eval()
    info = json.loads((in_dir / "embed_info.json").read_text())
    log.msg(f"Model: {card['model_name']} ({card['model_id']}), pooling {cfg['pooling']}, "
            f"trained on {card['training_data']['patients']} patients, CV AUC {card['cross_validation']['auc']}")
    if card.get("data_terms"):
        log.msg(f"Model data terms: {card['data_terms']}")
    if info["checkpoint_sha256"] != card["scgpt_checkpoint_sha256"]:
        log.fail(f"the embeddings come from scGPT checkpoint {info['checkpoint']} but the model was trained on "
                 f"{card['scgpt_checkpoint']} embeddings (SHA256 differs); rerun scgpt_embed with that checkpoint")
    for k in ("tissue", "time"):
        if info.get(k) and card.get(k) and info[k].lower() != card[k].lower():
            log.warn(f"{k} of the data ({info[k]}) differs from the training data ({card[k]}); "
                     "predictions may not be valid")
    e = ad.read_h5ad(in_dir / "embeddings.h5ad")
    emb = np.asarray(e.X, dtype=np.float32)
    if emb.shape[1] != cfg["embedding_size"]:
        log.fail(f"embedding size {emb.shape[1]} differs from the model ({cfg['embedding_size']})")
    cell_patient = e.obs["PatientID"].astype(str).values
    patients = sorted(set(cell_patient))
    log.msg(f"Patients: {len(patients)}, cells: {e.n_obs}")

    # ------------------------------------------------------------- Step 2: predict
    log.step("Step 2: Predict")
    x, m, idx = make_bags(np, torch, emb, cell_patient, patients)
    with torch.no_grad():
        logit, a = model(x, m)
    prob = torch.sigmoid(logit).numpy()
    a = a.numpy()
    obs = e.obs
    pos, neg = card["positive_label"], card["negative_label"]
    rows = []
    for i, p in enumerate(patients):
        c = idx[p]
        given = str(obs["Label"].iloc[c[0]]) if "Label" in obs else ""
        rows.append({"PatientID": p, "Cohort": str(obs["Cohort"].iloc[c[0]]), "cells": len(c),
                     "prob_" + pos: round(float(prob[i]), 4),
                     "predicted": pos if prob[i] >= threshold else neg,
                     "given_label": given if given not in ("nan", "") else ""})
        log.msg(f"  {p}: P({pos}) = {prob[i]:.3f} -> {rows[-1]['predicted']}")
    pred = pd.DataFrame(rows)
    pred.to_csv(out / "predictions.tsv", sep="\t", index=False)
    shutil.copy2(model_dir / "model_card.json", out / "model_card.json")
    labeled = pred[pred["given_label"].isin([pos, neg])]
    if len(labeled):
        acc = float((labeled["predicted"] == labeled["given_label"]).mean())
        log.msg(f"Patients with a given label: {len(labeled)}, agreement at threshold {threshold}: {acc:.3f} "
                "(use scgpt_compare for AUC and confidence intervals)")

    (out / "plots").mkdir()
    if cfg["pooling"] == "attention":
        log.step("Step 3: Attention by cell")
        cell_rows = []
        for i, p in enumerate(patients):
            c = idx[p]
            w = a[i, :len(c)]
            cell_rows.append(pd.DataFrame({"cell": e.obs_names[c], "PatientID": p,
                                           "cell_type": obs["cell_type"].astype(str).values[c],
                                           "attention": w, "attention_x_cells": w * len(c)}))
        ca = pd.concat(cell_rows)
        ca.to_csv(out / "cell_attention.tsv.gz", sep="\t", index=False, float_format="%.6g")
        by = ca.groupby(["PatientID", "cell_type"])["attention"].sum().unstack(fill_value=0)
        frac = ca.groupby(["PatientID", "cell_type"]).size().unstack(fill_value=0)
        frac = frac.div(frac.sum(axis=1), axis=0)
        ratio = (by / frac.replace(0, np.nan)).fillna(0)
        long = by.stack().rename("attention_share").to_frame().join(
            frac.stack().rename("cell_fraction")).join(ratio.stack().rename("enrichment")).reset_index()
        long.to_csv(out / "attention_by_cell_type.tsv", sep="\t", index=False, float_format="%.4f")
        mean_enrich = ratio.mean(axis=0).sort_values(ascending=False)
        log.msg("Mean attention enrichment by cell type (attention share / cell share; > 1 = weighed more):")
        for ct, v in mean_enrich.items():
            log.msg(f"  {ct:<14}{v:6.2f}")
        fig, ax = plt.subplots(figsize=(5.5, 3.6))
        ax.bar(range(len(mean_enrich)), mean_enrich.values, color="#009E73")
        ax.axhline(1, color="#999999", ls="--", lw=1)
        ax.set_xticks(range(len(mean_enrich)))
        ax.set_xticklabels(mean_enrich.index, rotation=60, ha="right", fontsize=8)
        ax.set_ylabel("Attention share / cell share")
        ax.set_title("Which cell types the model weighed (mean over patients)")
        save_plot(fig, out / "plots" / "attention_by_cell_type")
        plt.close(fig)

    ps = pred.sort_values("prob_" + pos, ascending=False)
    colors = {pos: "#D55E00", neg: "#0072B2", "": "#999999"}
    fig, ax = plt.subplots(figsize=(max(5, 0.15 * len(ps) + 2), 3.8))
    ax.bar(range(len(ps)), ps["prob_" + pos], color=[colors.get(v, "#999999") for v in ps["given_label"]])
    ax.axhline(threshold, color="#333333", ls="--", lw=1)
    ax.set_xticks(range(len(ps)))
    ax.set_xticklabels(ps["PatientID"], rotation=90, fontsize=7)
    ax.set_ylabel(f"P({pos})")
    ax.set_ylim(0, 1)
    handles = [plt.Rectangle((0, 0), 1, 1, color=colors[k]) for k in (pos, neg, "")]
    ax.legend(handles, [f"given {pos}", f"given {neg}", "no label"], frameon=False, fontsize=8)
    ax.set_title(f"Predicted probability per patient ({card['model_name']})")
    save_plot(fig, out / "plots" / "predictions")
    plt.close(fig)

    log.step("Summary")
    log.msg(f"Patients: {len(pred)}, predicted {pos}: {int((pred['predicted'] == pos).sum())}, "
            f"{neg}: {int((pred['predicted'] == neg).sum())}")
    log.step("Done")
    log.msg(f"Predictions: {out / 'predictions.tsv'}")
    shutil.rmtree(cache, ignore_errors=True)
    log.msg(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
