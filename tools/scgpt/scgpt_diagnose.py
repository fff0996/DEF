#!/usr/bin/env python3
# Diagnose a scGPT pipeline result: why does scgpt_train differ from scgpt_mean? Not a portal module.
#   1. Checks cv_predictions.tsv (rows, predictions per patient, each patient tested once a repeat).
#   2. Refits every fold and reports train and validation AUC per fold.
#   3. Compares variants on the same embeddings, splits and aggregation, one change at a time.
# Run it in the bx_scgpt image. The screen shows counts and AUCs only, never patient IDs; files in
# output_dir hold patient IDs, so keep them where the data is.
#
# Usage:
#   python3 scgpt_diagnose.py input_dir="..." train_dir="..." output_dir="..." [variants="all"]
#       [seed="1234"] [epochs=""]
#
# Arguments (key=value, --key=value or --key value):
#   input_dir   (required) - scgpt_embed output folder
#   train_dir   (required) - scgpt_train output folder (model settings and cv_predictions.tsv)
#   output_dir  (required) - New folder for the results; must be empty or not exist
#   variants    (optional) - Comma separated names, or all. default: all
#   seed        (optional) - The seed of the scgpt_train run. default: 1234
#   epochs      (optional) - Epochs of the nn variants without e1000; empty uses the value of the
#                            scgpt_train run, and only then the refit is compared with its
#                            stored predictions. default: empty
#
# Outputs (output_dir):
#   summary.tsv              per variant: AUC of patient-mean predictions (95% CI), fold AUCs
#   fold_auc.tsv             per variant, repeat, fold: patients, train AUC, validation AUC
#   variant_predictions.tsv  variant, repeat, fold, patient_id, y_true, prob
#
# Variants: lr_* is scikit-learn logistic regression on patient means, as scgpt_compare does; nn_*
# is the scgpt_train model. std scales by the mean and SD of the training patients' mean embeddings
# (the StandardScaler of scgpt_mean, fitted in each training fold only). e1000 uses 1000 epochs.

import os
import re
import shutil
import sys
from pathlib import Path

REQUIRED = ["input_dir", "train_dir", "output_dir"]
OPTIONAL = {"variants": "all", "seed": "1234", "epochs": ""}
# name: (classifier, pooling, standardize, epochs or None for the trained value, what changed)
VARIANTS = {
    "lr_mean_std": ("lr", "mean", True, None, "reference: must match scgpt_mean of scgpt_compare"),
    "lr_mean_nostd": ("lr", "mean", False, None, "lr_mean_std without standardization"),
    "nn_attention": ("nn", "attention", False, None, "scgpt_train before standardize (standardize=no)"),
    "nn_attention_std": ("nn", "attention", True, None, "scgpt_train default (standardize=yes)"),
    "nn_attention_e1000": ("nn", "attention", False, 1000, "nn_attention with 1000 epochs"),
    "nn_mean": ("nn", "mean", False, None, "nn_attention with mean pooling"),
    "nn_mean_std": ("nn", "mean", True, None, "nn_mean with standardization"),
    "nn_mean_e1000": ("nn", "mean", False, 1000, "nn_mean with 1000 epochs"),
}


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    params = dict(OPTIONAL)
    i = 0
    while i < len(argv):
        arg = argv[i]
        i += 1
        if arg.startswith("--"):
            arg = arg[2:]
            if "=" in arg:
                key, value = arg.split("=", 1)
            else:
                key, value = arg, ""
                if i < len(argv) and not argv[i].startswith("--"):
                    value = argv[i]
                    i += 1
        elif "=" in arg:
            key, value = arg.split("=", 1)
        else:
            fail(f"Invalid argument format: {arg} (use key=value or --key value)")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}")
        value = value.strip().strip("'\"")
        params[key] = value if value or key in REQUIRED else OPTIONAL[key]
    for key in REQUIRED:
        if not params.get(key):
            fail(f"Required parameter '{key}' is missing")
    return params


def build_model(torch, cfg):
    """Same as scgpt_train.1.0.py."""
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
            if cfg.get("standardize"):
                # Mean and SD of the training patients' mean embeddings, set before training and
                # saved with the weights. scGPT embeddings have length 1, so patients differ by
                # small amounts that an unscaled model hardly uses.
                self.register_buffer("center", torch.zeros(d))
                self.register_buffer("scale", torch.ones(d))

        def forward(self, x, mask):
            # x: patients x cells x d, mask: patients x cells (True = real cell)
            if hasattr(self, "center"):
                x = (x - self.center) / self.scale
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
    """Same as scgpt_train.1.0.py."""
    idx = {p: np.where(patient_of_cell == p)[0] for p in patients}
    n_max = max(len(v) for v in idx.values())
    x = np.zeros((len(patients), n_max, emb.shape[1]), dtype=np.float32)
    m = np.zeros((len(patients), n_max), dtype=bool)
    for i, p in enumerate(patients):
        c = idx[p]
        x[i, :len(c)] = emb[c]
        m[i, :len(c)] = True
    return torch.from_numpy(x), torch.from_numpy(m)


def fit(torch, cfg, x, m, y, seed):
    """Same as scgpt_train.1.0.py."""
    torch.manual_seed(seed)
    model = build_model(torch, cfg)
    if cfg.get("standardize"):
        w = m.float() / m.float().sum(dim=1, keepdim=True)
        patient_means = (w.unsqueeze(-1) * x).sum(dim=1)
        sd = patient_means.std(dim=0, unbiased=False)
        model.center.copy_(patient_means.mean(dim=0))
        model.scale.copy_(torch.where(sd > 0, sd, torch.ones_like(sd)))
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
    model.eval()
    return model


def probs(torch, model, x, m):
    with torch.no_grad():
        logit, _ = model(x, m)
    return torch.sigmoid(logit).numpy()


def safe_auc(np, roc_auc_score, y, p):
    y = np.asarray(y)
    return float(roc_auc_score(y, p)) if len(set(y.tolist())) == 2 else float("nan")


def auc_ci(np, roc_auc_score, y, p, seed, n_boot=2000):
    """Same bootstrap as scgpt_train.1.0.py."""
    rng = np.random.default_rng(seed)
    auc = roc_auc_score(y, p)
    boots = []
    while len(boots) < n_boot:
        i = rng.integers(0, len(y), len(y))
        if len(set(y[i])) == 2:
            boots.append(roc_auc_score(y[i], p[i]))
    return auc, float(np.percentile(boots, 2.5)), float(np.percentile(boots, 97.5))


def check_cv_table(pd, path, splits, y_of):
    """Step 1: the stored predictions; prints counts only."""
    print("############################## Step 1: cv_predictions.tsv", flush=True)
    cv = pd.read_csv(path, sep="\t", dtype={"PatientID": str})
    repeats = cv["Repeat"].nunique()
    per_patient = cv.groupby("PatientID").size()
    once = cv.groupby(["Repeat", "PatientID"]).size()
    expected = len(y_of) * repeats
    print(f"Rows: {len(cv)} (expected {len(y_of)} patients x {repeats} repeats = {expected})")
    print(f"Patients: {cv['PatientID'].nunique()}; predictions per patient: "
          f"min {per_patient.min()}, max {per_patient.max()}")
    print(f"Patient tested more than once in a repeat: {int((once > 1).sum())}")
    print(f"Folds per repeat: {cv.groupby('Repeat')['Fold'].nunique().min()}"
          f"-{cv.groupby('Repeat')['Fold'].nunique().max()}")
    test = splits[splits["Set"] == "test"][["Repeat", "Fold", "PatientID"]]
    same = cv[["Repeat", "Fold", "PatientID"]].merge(test, on=["Repeat", "Fold", "PatientID"])
    print(f"Rows whose fold matches splits.tsv: {len(same)} of {len(cv)}")
    wrong = int((cv["label01"].values != cv["PatientID"].map(y_of).values).sum())
    print(f"Rows whose label differs from patients.tsv: {wrong}", flush=True)
    return cv


def main():
    params = parse_args(sys.argv[1:])
    in_dir, train_dir, out = Path(params["input_dir"]), Path(params["train_dir"]), Path(params["output_dir"])
    if not re.fullmatch(r"\d+", params["seed"]):
        fail(f"seed must be an integer: {params['seed']}")
    seed = int(params["seed"])
    if params["epochs"] and not re.fullmatch(r"[1-9]\d*", params["epochs"]):
        fail(f"epochs must be a positive integer: {params['epochs']}")
    names = list(VARIANTS) if params["variants"] == "all" else \
        [v.strip() for v in params["variants"].split(",") if v.strip()]
    unknown = [v for v in names if v not in VARIANTS]
    if unknown:
        fail(f"unknown variants: {', '.join(unknown)}; choose from {', '.join(VARIANTS)}")
    for path in (in_dir / "embeddings.h5ad", in_dir / "patients.tsv", in_dir / "splits.tsv",
                 train_dir / "cv_predictions.tsv", train_dir / "model" / "model.pt"):
        if not path.exists():
            fail(f"not found: {path}")
    if out.exists() and any(out.iterdir()):
        fail(f"output_dir is not empty: {out}")
    out.mkdir(parents=True, exist_ok=True)
    for var in ("XDG_CACHE_HOME", "MPLCONFIGDIR", "NUMBA_CACHE_DIR"):
        os.environ[var] = str(out / ".cache")

    import time
    import anndata as ad
    import numpy as np
    import pandas as pd
    import torch
    from sklearn.linear_model import LogisticRegression
    from sklearn.metrics import roc_auc_score
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
    torch.set_num_threads(max(1, len(os.sched_getaffinity(0))))

    e = ad.read_h5ad(in_dir / "embeddings.h5ad")
    emb = np.asarray(e.X, dtype=np.float32)
    cell_patient = e.obs["PatientID"].astype(str).values
    pat = pd.read_csv(in_dir / "patients.tsv", sep="\t", dtype=str, keep_default_na=False)
    pat = pat[pat["PatientID"].isin(set(cell_patient))]
    lab = pat[pat["label01"] != ""].reset_index(drop=True)
    if lab.empty or lab["label01"].nunique() < 2:
        fail("needs labeled patients of both labels")
    patients = lab["PatientID"].tolist()
    y_of = dict(zip(patients, lab["label01"].astype(int)))
    splits = pd.read_csv(in_dir / "splits.tsv", sep="\t", dtype={"PatientID": str})
    splits = splits[splits["PatientID"].isin(y_of)]
    saved = torch.load(train_dir / "model" / "model.pt", map_location="cpu", weights_only=False)
    base = dict(saved["config"])
    stored_epochs = base["epochs"]
    if params["epochs"]:
        base["epochs"] = int(params["epochs"])
    print(f"Patients: {len(patients)}, cells: {e.n_obs}, embedding size: {emb.shape[1]}")
    print(f"Epochs of the scgpt_train run: {stored_epochs}")
    print("Settings used: " + ", ".join(f"{k}={base[k]}" for k in sorted(base)), flush=True)

    cv = check_cv_table(pd, train_dir / "cv_predictions.tsv", splits, y_of)

    emb_mean = pd.DataFrame(emb).groupby(cell_patient).mean().reindex(patients)
    pidx = {p: i for i, p in enumerate(patients)}
    pred_rows, fold_rows, summary = [], [], []
    print("############################## Step 2-3: refit folds, one change at a time", flush=True)
    for name in names:
        kind, pooling, standardize, epochs, change = VARIANTS[name]
        cfg = dict(base, pooling=pooling, standardize=standardize)
        if epochs:
            cfg["epochs"] = epochs
        begin = time.time()
        for (rep, fold), s in splits.groupby(["Repeat", "Fold"]):
            tr = s.loc[s["Set"] == "train", "PatientID"].tolist()
            te = s.loc[s["Set"] == "test", "PatientID"].tolist()
            ytr = np.array([y_of[p] for p in tr])
            yte = np.array([y_of[p] for p in te])
            if kind == "lr":
                steps = [StandardScaler()] if standardize else []
                steps.append(LogisticRegression(C=1.0, class_weight="balanced", max_iter=5000))
                clf = make_pipeline(*steps)
                xm = emb_mean.values
                itr, ite = [pidx[p] for p in tr], [pidx[p] for p in te]
                clf.fit(xm[itr], ytr)
                ptr, pte = clf.predict_proba(xm[itr])[:, 1], clf.predict_proba(xm[ite])[:, 1]
            else:
                data = emb
                xtr, mtr = make_bags(np, torch, data, cell_patient, tr)
                model = fit(torch, cfg, xtr, mtr, ytr, seed + 100 * int(rep) + int(fold))
                xte, mte = make_bags(np, torch, data, cell_patient, te)
                ptr, pte = probs(torch, model, xtr, mtr), probs(torch, model, xte, mte)
            fold_rows.append((name, int(rep), int(fold), len(tr), len(te),
                              safe_auc(np, roc_auc_score, ytr, ptr), safe_auc(np, roc_auc_score, yte, pte)))
            for p, value in zip(te, pte):
                pred_rows.append((name, int(rep), int(fold), p, y_of[p], float(value)))
        part = pd.DataFrame([r for r in pred_rows if r[0] == name],
                            columns=["variant", "repeat", "fold", "patient_id", "y_true", "prob"])
        avg = part.groupby("patient_id").agg(y=("y_true", "first"), p=("prob", "mean"))
        auc, lo, hi = auc_ci(np, roc_auc_score, avg["y"].values, avg["p"].values, seed)
        folds = pd.DataFrame([r for r in fold_rows if r[0] == name])
        row = {"variant": name, "change": change, "auc_patient_mean": round(auc, 4), "ci_low": round(lo, 4),
               "ci_high": round(hi, 4), "train_auc_fold_mean": round(float(folds[5].mean()), 4),
               "val_auc_fold_mean": round(float(folds[6].mean()), 4),
               "val_auc_fold_sd": round(float(folds[6].std()), 4), "minutes": round((time.time() - begin) / 60, 1)}
        summary.append(row)
        print(f"{name:<20} AUC {auc:.3f} ({lo:.3f}-{hi:.3f})  train {row['train_auc_fold_mean']:.3f}  "
              f"val fold {row['val_auc_fold_mean']:.3f} +- {row['val_auc_fold_sd']:.3f}  "
              f"[{row['minutes']} min]", flush=True)
        trained = saved["config"]
        if trained.get("pooling") == pooling and bool(trained.get("standardize")) == standardize \
                and kind == "nn" and not epochs and base["epochs"] == stored_epochs:
            m = part.merge(cv, left_on=["repeat", "fold", "patient_id"], right_on=["Repeat", "Fold", "PatientID"])
            largest = float((m["prob_x"] - m["prob_y"]).abs().max())
            print(f"  Refit vs stored cv_predictions: {len(m)} rows, largest probability difference "
                  f"{largest:.6f}", flush=True)

    pd.DataFrame(summary).to_csv(out / "summary.tsv", sep="\t", index=False)
    pd.DataFrame(fold_rows, columns=["variant", "repeat", "fold", "n_train", "n_val", "train_auc", "val_auc"]).to_csv(
        out / "fold_auc.tsv", sep="\t", index=False, float_format="%.4f")
    pd.DataFrame(pred_rows, columns=["variant", "repeat", "fold", "patient_id", "y_true", "prob"]).to_csv(
        out / "variant_predictions.tsv", sep="\t", index=False, float_format="%.6f")
    shutil.rmtree(out / ".cache", ignore_errors=True)
    print(f"Written: {out}/summary.tsv, fold_auc.tsv, variant_predictions.tsv", flush=True)


if __name__ == "__main__":
    main()
