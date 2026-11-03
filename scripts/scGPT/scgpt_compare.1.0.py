#!/usr/bin/env python3
# scGPT pipeline, module 5: is the model better? Compares trained models with simpler
# baselines on the same patients and the same folds.
#   baseline_celltype : coarse cell-type fractions per patient + logistic regression
#   baseline_pca      : mean of 30 principal components of highly variable genes + logistic regression
#   scgpt_mean        : mean scGPT embedding per patient + logistic regression (scGPT as it is)
#   models            : scgpt_train models. A model trained on this dataset is judged by its own
#                       cross-validation predictions (same folds); a model trained elsewhere is
#                       applied to every patient here (external test).
# A model counts as better than a baseline only when the 95% CI of the paired bootstrap
# difference in AUC (same patients resampled) is above 0.
#
# Usage:
#   python3 scgpt_compare.1.0.py input_dir="..." output_dir="..." [models=""]
#       [n_hvg="2000"] [n_pcs="30"] [permutations="1000"] [seed="1234"]
#
# Example:
#   apptainer exec bx_scgpt.1.0.sif python3 scgpt_compare.1.0.py \
#       input_dir=/data/scgpt_embed models=/data/scgpt_train output_dir=/data/scgpt_compare
#
# Arguments:
#   input_dir    (required) - scgpt_embed output folder with labeled patients. The PCA baseline
#                             also reads the scgpt_prep folder recorded in its embed_info.json.
#   output_dir   (required) - Output directory
#   models       (optional) - scgpt_train output folders, comma separated; builtin adds the
#                             model shipped in the image. Empty compares the baselines only.
#                             default: empty
#   n_hvg        (optional) - Highly variable genes for the PCA baseline. default: 2000
#   n_pcs        (optional) - Principal components for the PCA baseline. default: 30
#   permutations (optional) - Label permutations for the p value of each AUC. default: 1000
#   seed         (optional) - Random seed. default: 1234
#
# Outputs (output_dir):
#   compare_metrics.tsv      per method: AUC (95% CI), AUC per repeat, accuracy, sensitivity,
#                            specificity at 0.5, permutation p
#   compare_delta.tsv        paired bootstrap difference in AUC of each model against each baseline
#   compare_cohort.tsv       leave-one-cohort-out AUC (two or more labeled cohorts)
#   compare_predictions.tsv  patient probabilities of every method (mean over repeats)
#   summary.md               the conclusion in a few lines
#   plots/                   roc (all methods), auc (AUC with 95% CI)
#   logs/                    <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Rerunning removes everything in output_dir except logs/.

import datetime
import json
import os
import re
import shutil
import subprocess
import sys
import warnings
from pathlib import Path

MODULE = "scgpt_compare"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"models": "", "n_hvg": "2000", "n_pcs": "30", "permutations": "1000", "seed": "1234"}
BUILTIN_MODEL = "/opt/bio/share/scgpt/models/default"
BASELINES = ["baseline_celltype", "baseline_pca", "scgpt_mean"]


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


# ----------------------------------------------------------------- module
def main():
    params = parse_args(sys.argv[1:])
    in_dir = Path(params["input_dir"])
    for f in ("embeddings.h5ad", "embed_info.json", "patients.tsv", "splits.tsv"):
        if not (in_dir / f).exists():
            early_fail(f"{f} not found in input_dir {in_dir}; give the scgpt_embed output folder of labeled data")
    model_dirs = []
    for m in [s.strip() for s in params["models"].split(",") if s.strip()]:
        d = Path(BUILTIN_MODEL) if m == "builtin" else Path(m) / "model"
        if not (d / "model.pt").exists():
            early_fail(f"model.pt not found for models entry {m}")
        model_dirs.append((m, d))
    out = prepare_output(params["output_dir"], [in_dir] + [d for _, d in model_dirs])
    log = Log(out)
    start = datetime.datetime.now()
    n_hvg = positive_int(log, "n_hvg", params["n_hvg"], 50)
    n_pcs = positive_int(log, "n_pcs", params["n_pcs"], 2)
    n_perm = positive_int(log, "permutations", params["permutations"], 0)
    seed = positive_int(log, "seed", params["seed"], 0)
    cores = allocated_cores()

    for name in ("numpy", "pandas", "torch", "scanpy", "anndata", "sklearn", "matplotlib"):
        try:
            __import__(name)
        except ImportError:
            log.fail(f"required Python package not found: {name}")
    import numpy as np
    import pandas as pd
    import anndata as ad
    import scanpy as sc
    import torch
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler
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
        log.msg(f"  {k:<13}= {params[k]}")
    log.msg(f"  {'threads':<13}= {cores} (allocated {cores})")
    log.msg("")

    # ------------------------------------------------------------- Step 1: data
    log.step("Step 1: Patients, folds and features")
    info = json.loads((in_dir / "embed_info.json").read_text())
    e = ad.read_h5ad(in_dir / "embeddings.h5ad")
    emb = np.asarray(e.X, dtype=np.float32)
    cell_patient = e.obs["PatientID"].astype(str).values
    pat = pd.read_csv(in_dir / "patients.tsv", sep="\t", dtype=str, keep_default_na=False)
    lab = pat[(pat["label01"] != "") & pat["PatientID"].isin(set(cell_patient))].reset_index(drop=True)
    if lab.empty or lab["label01"].nunique() < 2:
        log.fail("comparison needs labeled patients of both labels")
    patients = lab["PatientID"].tolist()
    y_of = dict(zip(patients, lab["label01"].astype(int)))
    pos, neg = info["positive_label"], info["negative_label"]
    log.msg(f"Patients: {len(patients)} (positive {pos} = {sum(y_of.values())}, "
            f"negative {neg} = {len(patients) - sum(y_of.values())})")
    if len(patients) < 100:
        log.warn(f"{len(patients)} labeled patients: AUC differences between methods are uncertain")
    splits = pd.read_csv(in_dir / "splits.tsv", sep="\t", dtype={"PatientID": str})
    splits = splits[splits["PatientID"].isin(y_of)]
    cohort_splits = None
    if (in_dir / "splits_cohort.tsv").exists():
        cohort_splits = pd.read_csv(in_dir / "splits_cohort.tsv", sep="\t", dtype={"PatientID": str})

    feats = {}
    ct = pd.crosstab(e.obs["PatientID"].astype(str), e.obs["cell_type"].astype(str), normalize="index")
    feats["baseline_celltype"] = ct.reindex(patients).fillna(0).values
    log.msg(f"baseline_celltype: {ct.shape[1]} cell-type fractions per patient")
    emb_mean = pd.DataFrame(emb).groupby(cell_patient).mean()
    feats["scgpt_mean"] = emb_mean.reindex(patients).values
    log.msg(f"scgpt_mean: mean of {emb.shape[1]} embedding dimensions per patient")
    prep_ds = Path(info.get("prep_dir", "")) / "dataset.h5ad"
    if prep_ds.exists():
        d = sc.read_h5ad(prep_ds)
        d = d[d.obs_names.isin(e.obs_names)].copy()
        n_coh = d.obs["Cohort"].nunique()
        shared = d.var["n_cohorts"].values >= n_coh if "n_cohorts" in d.var else np.ones(d.n_vars, bool)
        d = d[:, shared].copy()
        sc.pp.normalize_total(d, target_sum=1e4)
        sc.pp.log1p(d)
        sc.pp.highly_variable_genes(d, n_top_genes=min(n_hvg, d.n_vars - 1), flavor="seurat")
        d = d[:, d.var["highly_variable"]].copy()
        sc.pp.scale(d, max_value=10)
        k = min(n_pcs, d.n_obs - 1, d.n_vars - 1)
        sc.tl.pca(d, n_comps=k, random_state=seed)
        pcs = pd.DataFrame(d.obsm["X_pca"], index=d.obs_names).groupby(d.obs["PatientID"].astype(str).values).mean()
        feats["baseline_pca"] = pcs.reindex(patients).values
        log.msg(f"baseline_pca: {k} PCs of {int(d.n_vars)} highly variable genes (genes shared by all cohorts), "
                "patient means")
        del d
    else:
        log.warn(f"scgpt_prep dataset not found at {prep_ds}; baseline_pca is skipped")

    # ------------------------------------------------------------- Step 2: baselines
    log.step("Step 2: Baselines on the same folds")
    preds = {}       # method -> DataFrame Repeat, PatientID, prob
    cohort_preds = {}

    def lr():
        return make_pipeline(StandardScaler(), LogisticRegression(C=1.0, class_weight="balanced", max_iter=5000))

    pidx = {p: i for i, p in enumerate(patients)}
    for method in [b for b in BASELINES if b in feats]:
        X = feats[method]
        rows = []
        for (rep, fold), s in splits.groupby(["Repeat", "Fold"]):
            tr = [pidx[p] for p in s.loc[s["Set"] == "train", "PatientID"]]
            te = [pidx[p] for p in s.loc[s["Set"] == "test", "PatientID"]]
            clf = lr().fit(X[tr], [y_of[patients[i]] for i in tr])
            for i, pr in zip(te, clf.predict_proba(X[te])[:, 1]):
                rows.append((int(rep), patients[i], float(pr)))
        preds[method] = pd.DataFrame(rows, columns=["Repeat", "PatientID", "prob"])
        if cohort_splits is not None:
            crow = []
            for coh, s in cohort_splits.groupby("TestCohort"):
                tr = [pidx[p] for p in s.loc[s["Set"] == "train", "PatientID"] if p in pidx]
                te = [pidx[p] for p in s.loc[s["Set"] == "test", "PatientID"] if p in pidx]
                clf = lr().fit(X[tr], [y_of[patients[i]] for i in tr])
                crow += [(coh, patients[i], float(pr)) for i, pr in zip(te, clf.predict_proba(X[te])[:, 1])]
            cohort_preds[method] = pd.DataFrame(crow, columns=["TestCohort", "PatientID", "prob"])
        log.msg(f"  {method}: done")

    # ------------------------------------------------------------- Step 3: models
    log.step("Step 3: Models")
    model_names = []
    for given, mdir in model_dirs:
        card = json.loads((mdir / "model_card.json").read_text())
        name = card["model_name"]
        if name in preds or name in model_names:
            name = f"{name}_{card['model_id'][-6:]}"
        if card["positive_label"] == pos and card["negative_label"] == neg:
            flip = False
        elif card["positive_label"] == neg and card["negative_label"] == pos:
            flip = True
        else:
            log.fail(f"model {name} predicts {card['positive_label']}/{card['negative_label']}, "
                     f"this data has {pos}/{neg}")
        same = (card["training_data"].get("splits_sha256") and
                card["training_data"]["splits_sha256"] == info.get("splits_sha256"))
        train_dir = mdir.parent
        if same and (train_dir / "cv_predictions.tsv").exists():
            cv = pd.read_csv(train_dir / "cv_predictions.tsv", sep="\t", dtype={"PatientID": str})
            preds[name] = cv[["Repeat", "PatientID", "prob"]].copy()
            if (train_dir / "cv_cohort_predictions.tsv").exists():
                cohort_preds[name] = pd.read_csv(train_dir / "cv_cohort_predictions.tsv", sep="\t",
                                                 dtype={"PatientID": str})[["TestCohort", "PatientID", "prob"]]
            log.msg(f"  {name}: trained on this dataset -> its own cross-validation predictions (same folds)")
        else:
            if card["scgpt_checkpoint_sha256"] != info["checkpoint_sha256"]:
                log.fail(f"model {name} needs embeddings of scGPT checkpoint {card['scgpt_checkpoint']}")
            saved = torch.load(mdir / "model.pt", map_location="cpu", weights_only=False)
            model = build_model(torch, saved["config"])
            model.load_state_dict(saved["state_dict"])
            model.eval()
            idx = {p: np.where(cell_patient == p)[0] for p in patients}
            n_max = max(len(v) for v in idx.values())
            x = np.zeros((len(patients), n_max, emb.shape[1]), dtype=np.float32)
            mk = np.zeros((len(patients), n_max), dtype=bool)
            for i, p in enumerate(patients):
                x[i, :len(idx[p])] = emb[idx[p]]
                mk[i, :len(idx[p])] = True
            with torch.no_grad():
                pr = torch.sigmoid(model(torch.from_numpy(x), torch.from_numpy(mk))[0]).numpy()
            preds[name] = pd.DataFrame({"Repeat": 1, "PatientID": patients, "prob": pr.astype(float)})
            log.msg(f"  {name}: trained on other data -> applied to all {len(patients)} patients (external test)")
        if flip:
            preds[name]["prob"] = 1 - preds[name]["prob"]
            if name in cohort_preds:
                cohort_preds[name]["prob"] = 1 - cohort_preds[name]["prob"]
        model_names.append(name)

    # ------------------------------------------------------------- Step 4: metrics
    log.step("Step 4: Metrics")
    methods = [m for m in BASELINES if m in preds] + model_names
    y = np.array([y_of[p] for p in patients])
    mean_prob = {m: preds[m].groupby("PatientID")["prob"].mean().reindex(patients).values for m in methods}
    rng = np.random.default_rng(seed)
    boot_idx = []
    while len(boot_idx) < 2000:
        i = rng.integers(0, len(y), len(y))
        if len(set(y[i])) == 2:
            boot_idx.append(i)
    boot_auc = {m: np.array([roc_auc_score(y[i], mean_prob[m][i]) for i in boot_idx]) for m in methods}
    rows = []
    for m in methods:
        p = mean_prob[m]
        auc = roc_auc_score(y, p)
        rep_aucs = [roc_auc_score([y_of[q] for q in s["PatientID"]], s["prob"])
                    for _, s in preds[m].groupby("Repeat") if len({y_of[q] for q in s["PatientID"]}) == 2]
        perm = np.array([roc_auc_score(rng.permutation(y), p) for _ in range(n_perm)]) if n_perm else np.array([])
        pval = (1 + int((perm >= auc).sum())) / (1 + n_perm) if n_perm else float("nan")
        call = (p >= 0.5).astype(int)
        rows.append({"method": m, "kind": "baseline" if m in BASELINES else "model", "patients": len(y),
                     "auc": auc, "auc_ci_low": np.percentile(boot_auc[m], 2.5),
                     "auc_ci_high": np.percentile(boot_auc[m], 97.5),
                     "auc_repeat_mean": float(np.mean(rep_aucs)) if rep_aucs else float("nan"),
                     "auc_repeat_sd": float(np.std(rep_aucs)) if len(rep_aucs) > 1 else float("nan"),
                     "accuracy": float((call == y).mean()), "sensitivity": float(call[y == 1].mean()),
                     "specificity": float(1 - call[y == 0].mean()), "permutation_p": pval})
        log.msg(f"  {m:<20} AUC {auc:.3f} (95% CI {rows[-1]['auc_ci_low']:.3f}-{rows[-1]['auc_ci_high']:.3f}), "
                f"permutation p {pval:.3g}")
    metrics = pd.DataFrame(rows)
    metrics.to_csv(out / "compare_metrics.tsv", sep="\t", index=False, float_format="%.4f")
    delta_rows = []
    for m in model_names:
        for b in [x for x in BASELINES if x in preds]:
            dlt = boot_auc[m] - boot_auc[b]
            lo, hi = np.percentile(dlt, [2.5, 97.5])
            verdict = "better" if lo > 0 else ("worse" if hi < 0 else "not clearly different")
            delta_rows.append({"model": m, "baseline": b, "delta_auc": roc_auc_score(y, mean_prob[m]) - roc_auc_score(y, mean_prob[b]),
                               "ci_low": lo, "ci_high": hi, "verdict": verdict})
    delta = pd.DataFrame(delta_rows, columns=["model", "baseline", "delta_auc", "ci_low", "ci_high", "verdict"])
    delta.to_csv(out / "compare_delta.tsv", sep="\t", index=False, float_format="%.4f")
    cohort_rows = []
    for m, cp in cohort_preds.items():
        for coh, s in cp.groupby("TestCohort"):
            yy = np.array([y_of[q] for q in s["PatientID"]])
            if len(set(yy)) == 2:
                cohort_rows.append({"method": m, "test_cohort": coh, "patients": len(yy),
                                    "auc": roc_auc_score(yy, s["prob"])})
    if cohort_rows:
        pd.DataFrame(cohort_rows).to_csv(out / "compare_cohort.tsv", sep="\t", index=False, float_format="%.4f")
    pp = pd.DataFrame({"PatientID": patients, "Label": [pos if v else neg for v in y], "label01": y})
    for m in methods:
        pp[m] = np.round(mean_prob[m], 4)
    pp.to_csv(out / "compare_predictions.tsv", sep="\t", index=False)

    # ------------------------------------------------------------- Step 5: summary and plots
    log.step("Step 5: Summary and plots")
    lines = [f"# scGPT model comparison", "", f"- Data: {len(y)} labeled patients "
             f"({pos} {int(y.sum())}, {neg} {int(len(y) - y.sum())}), embeddings from {info['checkpoint']}",
             "- Every method is scored on patients it was not trained on (same folds for all).", ""]
    for _, r in metrics.iterrows():
        lines.append(f"- {r['method']}: AUC {r['auc']:.3f} (95% CI {r['auc_ci_low']:.3f}-{r['auc_ci_high']:.3f})")
    lines.append("")
    if model_names:
        for m in model_names:
            d = delta[delta["model"] == m]
            parts = [f"{r['baseline']} {r['verdict']} (dAUC {r['delta_auc']:+.3f}, 95% CI {r['ci_low']:+.3f} to {r['ci_high']:+.3f})"
                     for _, r in d.iterrows()]
            lines.append(f"- {m} vs " + "; ".join(parts))
            if (d["verdict"] == "better").all() and len(d):
                lines.append(f"  Conclusion: {m} is better than every baseline on these patients.")
            elif (d.loc[d["baseline"] == "scgpt_mean", "verdict"] == "better").any():
                lines.append(f"  Conclusion: {m} improves on scGPT as it is, but not clearly on every baseline.")
            else:
                lines.append(f"  Conclusion: {m} is not clearly better than scGPT as it is (scgpt_mean).")
    else:
        lines.append("- No trained model given (models=): baselines only.")
    if len(y) < 100:
        lines += ["", f"Note: with {len(y)} patients the confidence intervals are wide; differences need confirmation "
                      "in an independent cohort."]
    (out / "summary.md").write_text("\n".join(lines) + "\n")
    for ln in lines:
        log.msg(ln)
    (out / "plots").mkdir()
    palette = ["#999999", "#E69F00", "#56B4E9", "#D55E00", "#009E73", "#CC79A7", "#0072B2"]
    fig, ax = plt.subplots(figsize=(5, 4.6))
    for i, m in enumerate(methods):
        fpr, tpr, _ = roc_curve(y, mean_prob[m])
        ax.plot(fpr, tpr, lw=2.2 if m in model_names else 1.4, color=palette[i % len(palette)],
                label=f"{m} ({roc_auc_score(y, mean_prob[m]):.3f})")
    ax.plot([0, 1], [0, 1], color="#cccccc", ls="--", lw=1)
    ax.set_xlabel("False positive rate")
    ax.set_ylabel("True positive rate")
    ax.set_title(f"ROC on held-out patients (n = {len(y)})")
    ax.legend(loc="lower right", frameon=False, fontsize=8)
    save_plot(fig, out / "plots" / "roc")
    plt.close(fig)
    fig, ax = plt.subplots(figsize=(max(4.5, 1.1 * len(methods) + 1.5), 3.8))
    for i, (_, r) in enumerate(metrics.iterrows()):
        ax.bar(i, r["auc"], color=palette[i % len(palette)])
        ax.errorbar(i, r["auc"], yerr=[[r["auc"] - r["auc_ci_low"]], [r["auc_ci_high"] - r["auc"]]],
                    color="#333333", capsize=4)
    ax.axhline(0.5, color="#999999", ls="--", lw=1)
    ax.set_xticks(range(len(metrics)))
    ax.set_xticklabels(metrics["method"], rotation=30, ha="right", fontsize=8)
    ax.set_ylim(0, 1.05)
    ax.set_ylabel("AUC (95% CI)")
    ax.set_title("AUC on held-out patients")
    save_plot(fig, out / "plots" / "auc")
    plt.close(fig)

    log.step("Summary")
    log.msg(f"Methods: {len(methods)}, patients: {len(y)}")
    log.step("Done")
    log.msg(f"Summary: {out / 'summary.md'}")
    log.msg(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
