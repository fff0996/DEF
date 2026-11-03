#!/usr/bin/env python3
# scGPT pipeline, module 1: build an AI-ready single-cell dataset with patient labels.
# Reads one count matrix per sample, joins the sample sheet (patient, cohort, tissue,
# time, label), filters cells, matches gene symbols to the scGPT vocabulary, marks coarse
# cell types from markers, checks the labels, and fixes patient-level cross-validation
# folds so that every later module evaluates on the same patients.
#
# Usage:
#   python3 scgpt_prep.1.0.py input_dir="..." sample_data="..." output_dir="..."
#       [positive_label=""] [time="Before"] [tissue="auto"] [min_genes="200"]
#       [max_mito="20"] [min_cells_per_sample="50"] [folds="5"] [repeats="3"]
#       [checkpoint_dir="builtin"] [seed="1234"]
#
# Example:
#   apptainer exec bx_scgpt.1.0.sif python3 scgpt_prep.1.0.py \
#       input_dir=/data/kbds_h5 sample_data=/data/samples.csv output_dir=/data/scgpt_prep \
#       positive_label=PR time=Before
#
# Arguments:
#   input_dir            (required) - Folder with one count matrix per sample, found by SampleID:
#                                     <SampleID>.h5 (10x Cell Ranger), <SampleID>.h5ad (raw counts
#                                     in X or layers["counts"]), or a folder <SampleID>/ with a 10x
#                                     matrix (matrix.mtx.gz, features.tsv.gz, barcodes.tsv.gz or
#                                     filtered_feature_bc_matrix.h5)
#   sample_data          (required) - Sample sheet (CSV), one row per sample. Columns: SampleID,
#                                     PatientID, Cohort, Tissue, Time, Label (Label may be empty
#                                     for patients to be predicted). Other columns are kept as
#                                     metadata and never used as model input.
#   output_dir           (required) - Output directory
#   positive_label       (optional) - Label value counted as positive (1), e.g. PR. Needed when
#                                     labels are given, unless they are already 1 and 0.
#                                     default: empty
#   time                 (optional) - Time point kept for the dataset (e.g. Before); all keeps
#                                     every time point. default: Before
#   tissue               (optional) - Tissue kept; auto uses the only tissue in the sheet and
#                                     stops when there are several. default: auto
#   min_genes            (optional) - Minimum detected genes per cell. default: 200
#   max_mito             (optional) - Maximum mitochondrial UMI percent per cell. default: 20
#   min_cells_per_sample (optional) - Samples with fewer cells after QC are left out. default: 50
#   folds                (optional) - Folds of the patient-level cross-validation. default: 5
#   repeats              (optional) - Repeats of the cross-validation (different shuffles).
#                                     default: 3
#   checkpoint_dir       (optional) - scGPT checkpoint folder (vocab.json is used here); builtin
#                                     is the whole-human checkpoint in the image. default: builtin
#   seed                 (optional) - Random seed. default: 1234
#
# Outputs (output_dir):
#   dataset.h5ad          raw counts of the kept cells; obs: SampleID, PatientID, Cohort, Tissue,
#                         Time, Label, cell_type (coarse, from markers) and QC values
#   patients.tsv          one row per patient: label, label01 (1/0, empty when unlabeled), cells
#   samples.tsv           one row per sample in the sheet: file, cells before/after QC, status
#   splits.tsv            Repeat, Fold, PatientID, Set (train/test) for labeled patients
#   splits_cohort.tsv     leave-one-cohort-out splits (only with two or more labeled cohorts)
#   gene_match.tsv        per cohort: genes, genes in the scGPT vocabulary, fraction
#   cohort_labels.tsv     patients per cohort and label
#   data_dictionary.tsv   meaning of every column in the files above
#   prep_info.json        options, counts and the vocabulary checksum (read by later modules)
#   plots/                cells_per_patient, qc_by_sample, cell_types_by_patient (.png, .pdf)
#   logs/                 <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Labels are not created here: they come from the sample sheet (clinical records). The label is
# a patient property, so every sample of a patient must carry the same label. Rerunning removes
# everything in output_dir except logs/.

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

MODULE = "scgpt_prep"
REQUIRED = ["input_dir", "sample_data", "output_dir"]
OPTIONAL = {"positive_label": "", "time": "Before", "tissue": "auto", "min_genes": "200",
            "max_mito": "20", "min_cells_per_sample": "50", "folds": "5", "repeats": "3",
            "checkpoint_dir": "builtin", "seed": "1234"}
BUILTIN_CHECKPOINT = "/opt/bio/share/scgpt/checkpoints/whole_human"
SHEET_COLUMNS = ["SampleID", "PatientID", "Cohort", "Tissue", "Time", "Label"]

# Coarse cell types for the baseline model and for reading attention: blood and common
# tumour-microenvironment populations. A cell gets the type with the highest mean marker
# expression (log-normalised); cells with no marker signal stay Unassigned.
MARKERS = {
    "CD4_T": ["CD3D", "CD3E", "IL7R", "CD4"],
    "CD8_T": ["CD3D", "CD8A", "CD8B"],
    "NK": ["NKG7", "GNLY", "KLRD1", "KLRF1"],
    "B": ["MS4A1", "CD79A", "CD79B"],
    "Plasma": ["MZB1", "JCHAIN", "IGHG1"],
    "Mono_CD14": ["CD14", "LYZ", "S100A8", "S100A9"],
    "Mono_FCGR3A": ["FCGR3A", "MS4A7", "LST1"],
    "cDC": ["FCER1A", "CLEC10A", "CD1C"],
    "pDC": ["LILRA4", "IL3RA", "CLEC4C"],
    "Platelet": ["PPBP", "PF4"],
    "Erythrocyte": ["HBB", "HBA1", "HBA2"],
    "Epithelial": ["EPCAM", "KRT18", "KRT8"],
    "Fibroblast": ["COL1A1", "COL1A2", "DCN"],
    "Endothelial": ["PECAM1", "VWF"],
}


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


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


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


# ----------------------------------------------------------------- module
def find_matrix(log, input_dir, sample_id):
    """The matrix of one sample: exact name first (<id>.h5, <id>.h5ad, <id>/), then names that
    start with the id followed by a separator. Several candidates stop the run."""
    exact = [input_dir / f"{sample_id}.h5", input_dir / f"{sample_id}.h5ad", input_dir / sample_id]
    found = [p for p in exact if p.exists()]
    if not found:
        pat = re.compile(re.escape(sample_id) + r"[._-]")
        found = [p for p in sorted(input_dir.iterdir()) if pat.match(p.name)
                 and (p.is_dir() or p.suffix in (".h5", ".h5ad"))]
    if len(found) > 1:
        log.fail(f"several matrices match SampleID {sample_id}: " + ", ".join(p.name for p in found)
                 + "\nRename the files so that one starts with the SampleID.")
    return found[0] if found else None


def read_matrix(log, sc, path):
    """Return an AnnData with raw counts and gene symbols as var_names."""
    if path.is_dir():
        h5 = path / "filtered_feature_bc_matrix.h5"
        if h5.exists():
            a = sc.read_10x_h5(str(h5))
        elif any((path / n).exists() for n in ("matrix.mtx.gz", "matrix.mtx")):
            a = sc.read_10x_mtx(str(path), var_names="gene_symbols", cache=False)
        else:
            log.fail(f"no 10x matrix in folder {path} (matrix.mtx(.gz) or filtered_feature_bc_matrix.h5)")
    elif path.suffix == ".h5":
        a = sc.read_10x_h5(str(path))
    else:
        a = sc.read_h5ad(str(path))
        if "counts" in a.layers:
            a.X = a.layers["counts"]
        for col in ("feature_name", "gene_symbols", "gene_symbol", "gene_name", "symbol"):
            if col in a.var.columns:
                a.var_names = a.var[col].astype(str).values
                break
        a.layers.clear()
        a.obsm.clear()
        a.uns.clear()
    if "feature_types" in a.var.columns:
        a = a[:, a.var["feature_types"] == "Gene Expression"].copy()
    a.var_names_make_unique()
    return a


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    sheet_path = Path(params["sample_data"])
    for p, what in ((input_dir, "input_dir"), (sheet_path, "sample_data")):
        if not p.exists():
            early_fail(f"{what} not found: {p}")
    out = prepare_output(params["output_dir"], [input_dir, sheet_path])
    log = Log(out)
    cache = use_private_cache(out)
    start = datetime.datetime.now()

    min_genes = positive_int(log, "min_genes", params["min_genes"], 0)
    min_cells = positive_int(log, "min_cells_per_sample", params["min_cells_per_sample"], 1)
    folds = positive_int(log, "folds", params["folds"], 2)
    repeats = positive_int(log, "repeats", params["repeats"], 1)
    seed = positive_int(log, "seed", params["seed"], 0)
    try:
        max_mito = float(params["max_mito"])
    except ValueError:
        log.fail(f"max_mito must be a number: {params['max_mito']}")
    ckpt = Path(BUILTIN_CHECKPOINT if params["checkpoint_dir"] == "builtin" else params["checkpoint_dir"])
    cores = allocated_cores()

    log.msg(f"############################## {MODULE}")
    log.msg(f"Log file: {log.log_file}")
    log.msg(f"Start time: {start:%Y-%m-%d %H:%M:%S}")
    log.msg("")
    log.msg("parameters:")
    for k in REQUIRED + list(OPTIONAL):
        log.msg(f"  {k:<21}= {params[k]}")
    log.msg(f"  {'cores':<21}= {cores} (allocated)")
    log.msg("")

    import numpy as np
    import pandas as pd
    for name in ("scanpy", "anndata", "sklearn", "matplotlib"):
        try:
            __import__(name)
        except ImportError:
            log.fail(f"required Python package not found: {name}")
    import anndata as ad
    import scanpy as sc
    import scipy.sparse as sp
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from sklearn.model_selection import RepeatedStratifiedKFold

    vocab_file = ckpt / "vocab.json"
    if not vocab_file.exists():
        log.fail(f"vocab.json not found in checkpoint_dir: {ckpt}")
    vocab = set(json.loads(vocab_file.read_text()).keys())

    # ------------------------------------------------------------- Step 1: sample sheet
    log.step("Step 1: Sample sheet")
    try:
        sheet = pd.read_csv(sheet_path, dtype=str, keep_default_na=False)
    except Exception as e:  # noqa: BLE001 - report any reader error with the file name
        log.fail(f"cannot read sample_data {sheet_path}: {e}")
    sheet.columns = [c.strip() for c in sheet.columns]
    missing = [c for c in SHEET_COLUMNS if c not in sheet.columns]
    if missing:
        log.fail(f"sample_data needs the columns {', '.join(SHEET_COLUMNS)}; missing: {', '.join(missing)}"
                 f"\nFound: {', '.join(sheet.columns)}")
    for c in sheet.columns:
        sheet[c] = sheet[c].astype(str).str.strip()
    for c in ["SampleID", "PatientID", "Cohort", "Tissue", "Time"]:
        empty = sheet.index[sheet[c] == ""].tolist()
        if empty:
            log.fail(f"sample_data has an empty {c} in row(s) {', '.join(str(i + 2) for i in empty)}")
    dup = sheet["SampleID"][sheet["SampleID"].duplicated()].unique().tolist()
    if dup:
        log.fail(f"duplicate SampleID in sample_data: {', '.join(dup)}")
    log.msg(f"Samples in sheet: {len(sheet)}, patients: {sheet['PatientID'].nunique()}, "
            f"cohorts: {sheet['Cohort'].nunique()}")

    status = {sid: "" for sid in sheet["SampleID"]}
    keep = pd.Series(True, index=sheet.index)
    if params["time"].lower() != "all":
        t = sheet["Time"].str.lower() == params["time"].lower()
        for sid in sheet.loc[~t, "SampleID"]:
            status[sid] = "other_time"
        keep &= t
        if not t.any():
            log.fail(f"no sample with Time={params['time']}; Time values: {', '.join(sorted(sheet['Time'].unique()))}")
    tissues = sorted(sheet.loc[keep, "Tissue"].unique())
    if params["tissue"] == "auto":
        if len(tissues) > 1:
            log.fail(f"several tissues in the sheet ({', '.join(tissues)}); set tissue= to one of them. "
                     "Training on mixed tissues mostly learns the tissue difference.")
        tissue = tissues[0]
    else:
        tissue = params["tissue"]
        if tissue not in tissues:
            log.fail(f"tissue {tissue} not in the sheet; tissues: {', '.join(tissues)}")
    tmask = sheet["Tissue"] == tissue
    for sid in sheet.loc[keep & ~tmask, "SampleID"]:
        status[sid] = "other_tissue"
    keep &= tmask
    used = sheet[keep].copy()
    log.msg(f"Kept: {len(used)} samples (time={params['time']}, tissue={tissue})")

    # Labels: patient property, binary.
    lab = used.groupby("PatientID")["Label"].agg(lambda s: sorted(set(v for v in s if v != "")))
    conflict = [p for p, v in lab.items() if len(v) > 1]
    if conflict:
        log.fail("samples of one patient carry different labels: " + "; ".join(
            f"{p}: {', '.join(lab[p])}" for p in conflict[:10]))
    patient_label = {p: (v[0] if v else "") for p, v in lab.items()}
    values = sorted({v for v in patient_label.values() if v})
    positive = params["positive_label"]
    if values:
        if len(values) != 2:
            log.fail(f"labels must have exactly two values for a binary model; found: {', '.join(values)}")
        if not positive:
            if set(values) == {"0", "1"}:
                positive = "1"
            else:
                log.fail(f"set positive_label to one of the labels: {', '.join(values)}")
        if positive not in values:
            log.fail(f"positive_label {positive} is not a label value; labels: {', '.join(values)}")
        negative = [v for v in values if v != positive][0]
        log.msg(f"Labels: positive (1) = {positive}, negative (0) = {negative}")
    else:
        negative = ""
        log.msg("No labels in the sheet: dataset for prediction only (no folds)")
    unlabeled = sorted(p for p, v in patient_label.items() if not v)
    if values and unlabeled:
        log.warn(f"{len(unlabeled)} patient(s) without a label are kept for prediction but not used in "
                 f"folds: {', '.join(unlabeled[:10])}{' ...' if len(unlabeled) > 10 else ''}")

    # ------------------------------------------------------------- Step 2: read and filter cells
    log.step("Step 2: Read matrices and filter cells")
    rows, parts = [], []
    for _, r in sheet.iterrows():
        sid = r["SampleID"]
        row = {"SampleID": sid, "PatientID": r["PatientID"], "Cohort": r["Cohort"], "Tissue": r["Tissue"],
               "Time": r["Time"], "Label": r["Label"], "file": "", "cells_raw": 0, "cells_qc": 0,
               "genes": 0, "genes_in_vocab": 0, "status": status[sid]}
        if status[sid]:
            rows.append(row)
            continue
        log.msg(f"############################## Processing sample: {sid}")
        path = find_matrix(log, input_dir, sid)
        if path is None:
            log.warn(f"sample skipped: {sid} / no matrix named {sid}.h5, {sid}.h5ad or {sid}/ in {input_dir}")
            row["status"] = "no_matrix"
            rows.append(row)
            continue
        row["file"] = path.name
        a = read_matrix(log, sc, path)
        x = a.X
        sample_vals = x[: min(200, x.shape[0])]
        sample_vals = sample_vals.data if sp.issparse(sample_vals) else np.asarray(sample_vals).ravel()
        if sample_vals.size and (np.any(sample_vals < 0) or np.any(np.abs(sample_vals - np.round(sample_vals)) > 1e-6)):
            log.fail(f"{path.name} does not hold raw counts (negative or non-integer values). "
                     "Give the raw count matrix (for h5ad, X or layers['counts']).")
        a.X = sp.csr_matrix(x, dtype=np.float32)
        row["cells_raw"] = a.n_obs
        row["genes"] = a.n_vars
        row["genes_in_vocab"] = int(sum(g in vocab for g in a.var_names))
        mito = a.var_names.str.upper().str.startswith("MT-")
        counts = np.asarray(a.X.sum(axis=1)).ravel()
        ngenes = np.asarray((a.X > 0).sum(axis=1)).ravel()
        mt = np.asarray(a.X[:, mito].sum(axis=1)).ravel()
        pct_mt = np.where(counts > 0, 100 * mt / np.maximum(counts, 1), 0)
        ok = (ngenes >= min_genes) & (pct_mt <= max_mito)
        a = a[ok].copy()
        a.obs["n_counts"] = counts[ok]
        a.obs["n_genes"] = ngenes[ok]
        a.obs["pct_mito"] = np.round(pct_mt[ok], 3)
        row["cells_qc"] = a.n_obs
        log.msg(f"  {path.name}: {row['cells_raw']} cells, {row['genes']} genes "
                f"({row['genes_in_vocab']} in scGPT vocabulary); after QC {row['cells_qc']} cells")
        if a.n_obs < min_cells:
            log.warn(f"sample skipped: {sid} / {a.n_obs} cells after QC (< min_cells_per_sample {min_cells})")
            row["status"] = "too_few_cells"
            rows.append(row)
            continue
        a.obs_names = [f"{sid}:{bc}" for bc in a.obs_names]
        for c in ["SampleID", "PatientID", "Cohort", "Tissue", "Time"]:
            a.obs[c] = r[c]
        a.obs["Label"] = patient_label[r["PatientID"]]
        row["status"] = "used"
        rows.append(row)
        parts.append(a)
    samples = pd.DataFrame(rows)
    if not parts:
        log.fail("no sample was usable; see samples.tsv statuses in the log above")
    log.msg(f"Samples used: {len(parts)} / {len(sheet)}")

    # Union of genes; a gene missing in a sample is zero there (scGPT reads only non-zero genes).
    adata = ad.concat(parts, join="outer", fill_value=0, merge="first")
    adata.X = sp.csr_matrix(adata.X, dtype=np.float32)
    adata.var["in_vocab"] = [g in vocab for g in adata.var_names]
    gene_cohorts = {}
    for a in parts:
        coh = a.obs["Cohort"].iloc[0]
        expressed = set(a.var_names[np.asarray((a.X > 0).sum(axis=0)).ravel() > 0])
        gene_cohorts.setdefault(coh, set()).update(expressed)
    adata.var["n_cohorts"] = [sum(g in s for s in gene_cohorts.values()) for g in adata.var_names]
    del parts

    # ------------------------------------------------------------- Step 3: coarse cell types
    log.step("Step 3: Coarse cell types from markers")
    norm = adata.copy()
    sc.pp.normalize_total(norm, target_sum=1e4)
    sc.pp.log1p(norm)
    scores = {}
    for ct, genes in MARKERS.items():
        g = [x for x in genes if x in norm.var_names]
        if g:
            scores[ct] = np.asarray(norm[:, g].X.mean(axis=1)).ravel()
    del norm
    score_df = pd.DataFrame(scores, index=adata.obs_names)
    best = score_df.idxmax(axis=1)
    best[score_df.max(axis=1) < 0.5] = "Unassigned"
    adata.obs["cell_type"] = pd.Categorical(best.values)
    ct_counts = adata.obs["cell_type"].value_counts()
    for ct, n in ct_counts.items():
        log.msg(f"  {ct:<14}{n:>8}")

    # ------------------------------------------------------------- Step 4: patients and folds
    log.step("Step 4: Patients, label check and folds")
    pat = (adata.obs.groupby("PatientID", observed=True)
           .agg(Cohort=("Cohort", "first"), Tissue=("Tissue", "first"), n_samples=("SampleID", "nunique"),
                n_cells=("SampleID", "size")).reset_index())
    pat["Label"] = pat["PatientID"].map(patient_label)
    pat["label01"] = pat["Label"].map(lambda v: "" if not v else ("1" if v == positive else "0"))
    extra = [c for c in sheet.columns if c not in SHEET_COLUMNS]
    for c in extra:
        per = used.groupby("PatientID")[c].agg(lambda s: ";".join(sorted(set(s))))
        pat[c] = pat["PatientID"].map(per)
    pat = pat[["PatientID", "Cohort", "Tissue", "Label", "label01", "n_samples", "n_cells"] + extra]

    cohort_labels = pat.pivot_table(index="Cohort", columns="Label", values="PatientID",
                                    aggfunc="count", fill_value=0)
    cohort_labels.columns = [c if c else "unlabeled" for c in cohort_labels.columns]
    cohort_labels = cohort_labels.reset_index()
    log.msg(cohort_labels.to_string(index=False))
    labeled = pat[pat["label01"] != ""].reset_index(drop=True)
    split_rows, cohort_rows = [], []
    if values:
        n_pos = int((labeled["label01"] == "1").sum())
        n_neg = int((labeled["label01"] == "0").sum())
        log.msg(f"Labeled patients: {len(labeled)} (positive {n_pos}, negative {n_neg})")
        if min(n_pos, n_neg) < 2:
            log.fail(f"each label needs at least 2 patients for cross-validation; positive {n_pos}, negative {n_neg}")
        if folds > min(n_pos, n_neg):
            log.warn(f"folds={folds} is more than the smaller label group ({min(n_pos, n_neg)}); "
                     f"using {min(n_pos, n_neg)} folds")
            folds = min(n_pos, n_neg)
        for coh in pat["Cohort"].unique():
            sub = labeled[labeled["Cohort"] == coh]
            if len(sub) and sub["label01"].nunique() == 1 and labeled["Cohort"].nunique() > 1:
                log.warn(f"cohort {coh} has only label {sub['Label'].iloc[0]}: a model can learn the cohort "
                         "difference instead of the label. Check cohort_labels.tsv.")
        rskf = RepeatedStratifiedKFold(n_splits=folds, n_repeats=repeats, random_state=seed)
        y = labeled["label01"].astype(int).values
        for i, (tr, te) in enumerate(rskf.split(np.zeros(len(y)), y)):
            rep, fold = i // folds + 1, i % folds + 1
            for idx, s in ((tr, "train"), (te, "test")):
                for p in labeled["PatientID"].values[idx]:
                    split_rows.append((rep, fold, p, s))
        cohorts = sorted(labeled["Cohort"].unique())
        if len(cohorts) >= 2:
            for coh in cohorts:
                tr = labeled[labeled["Cohort"] != coh]
                te = labeled[labeled["Cohort"] == coh]
                if tr["label01"].nunique() < 2 or te["label01"].nunique() < 2:
                    log.warn(f"leave-cohort-out split for {coh} skipped: training or test part has one label only")
                    continue
                for p in tr["PatientID"]:
                    cohort_rows.append((coh, p, "train"))
                for p in te["PatientID"]:
                    cohort_rows.append((coh, p, "test"))
        log.msg(f"Folds: {folds} x {repeats} repeats; leave-cohort-out splits: "
                f"{len({r[0] for r in cohort_rows})}")

    # ------------------------------------------------------------- Step 5: write
    log.step("Step 5: Write dataset")
    adata.obs = adata.obs[["SampleID", "PatientID", "Cohort", "Tissue", "Time", "Label", "cell_type",
                           "n_counts", "n_genes", "pct_mito"]].copy()
    for c in ["SampleID", "PatientID", "Cohort", "Tissue", "Time", "Label"]:
        adata.obs[c] = adata.obs[c].astype(str).astype("category")
    adata.uns["scgpt_prep"] = {"positive_label": positive, "negative_label": negative, "tissue": tissue,
                               "time": params["time"]}
    adata.write_h5ad(out / "dataset.h5ad", compression="gzip")
    pat.to_csv(out / "patients.tsv", sep="\t", index=False)
    samples.to_csv(out / "samples.tsv", sep="\t", index=False)
    if split_rows:
        pd.DataFrame(split_rows, columns=["Repeat", "Fold", "PatientID", "Set"]).to_csv(
            out / "splits.tsv", sep="\t", index=False)
    if cohort_rows:
        pd.DataFrame(cohort_rows, columns=["TestCohort", "PatientID", "Set"]).to_csv(
            out / "splits_cohort.tsv", sep="\t", index=False)
    gm = samples[samples["status"] == "used"].groupby("Cohort").agg(
        samples=("SampleID", "size"), genes=("genes", "max"), genes_in_vocab=("genes_in_vocab", "max")).reset_index()
    gm["fraction_in_vocab"] = (gm["genes_in_vocab"] / gm["genes"].clip(lower=1)).round(4)
    gm.to_csv(out / "gene_match.tsv", sep="\t", index=False)
    for _, r in gm.iterrows():
        if r["fraction_in_vocab"] < 0.5:
            log.warn(f"cohort {r['Cohort']}: only {r['fraction_in_vocab']:.0%} of genes are in the scGPT "
                     "vocabulary; check that gene names are human gene symbols")
    cohort_labels.to_csv(out / "cohort_labels.tsv", sep="\t", index=False)
    dictionary = [
        ("dataset.h5ad", "X", "raw UMI counts (float32), cells x genes"),
        ("dataset.h5ad", "obs.SampleID/PatientID/Cohort/Tissue/Time", "from the sample sheet"),
        ("dataset.h5ad", "obs.Label", "patient label from the sample sheet (empty: unlabeled)"),
        ("dataset.h5ad", "obs.cell_type", "coarse cell type from marker genes (scgpt_prep MARKERS)"),
        ("dataset.h5ad", "obs.n_counts/n_genes/pct_mito", "UMI count, detected genes, mitochondrial UMI percent"),
        ("dataset.h5ad", "var.in_vocab", "gene symbol is in the scGPT vocabulary"),
        ("dataset.h5ad", "var.n_cohorts", "number of cohorts in which the gene is detected"),
        ("patients.tsv", "label01", "1 = positive_label, 0 = the other label, empty = unlabeled"),
        ("patients.tsv", "n_samples/n_cells", "samples and QC-passed cells of the patient"),
        ("samples.tsv", "status", "used, other_time, other_tissue, no_matrix, too_few_cells"),
        ("splits.tsv", "Repeat/Fold/Set", "patient-level stratified cross-validation; a patient is in one test fold per repeat"),
        ("splits_cohort.tsv", "TestCohort/Set", "leave-one-cohort-out: the test cohort is never used for training"),
        ("gene_match.tsv", "fraction_in_vocab", "genes of the cohort found in the scGPT vocabulary"),
    ]
    pd.DataFrame(dictionary, columns=["file", "field", "meaning"]).to_csv(
        out / "data_dictionary.tsv", sep="\t", index=False)
    info = {"module": MODULE, "created": f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}",
            "options": params, "positive_label": positive, "negative_label": negative, "tissue": tissue,
            "folds": folds, "repeats": repeats, "cells": int(adata.n_obs), "genes": int(adata.n_vars),
            "genes_in_vocab": int(adata.var["in_vocab"].sum()), "patients": int(len(pat)),
            "labeled_patients": int(len(labeled)), "vocab_sha256": sha256_file(vocab_file),
            "dataset_dir": str(out)}
    if split_rows:
        info["splits_sha256"] = sha256_file(out / "splits.tsv")
    (out / "prep_info.json").write_text(json.dumps(info, indent=2))

    # ------------------------------------------------------------- Step 6: plots
    log.step("Step 6: Plots")
    pdir = out / "plots"
    pdir.mkdir()
    colors = {"1": "#D55E00", "0": "#0072B2", "": "#999999"}
    ps = pat.sort_values(["label01", "n_cells"], ascending=[False, False])
    fig, ax = plt.subplots(figsize=(max(6, 0.12 * len(ps) + 2), 4))
    ax.bar(range(len(ps)), ps["n_cells"], color=[colors[v] for v in ps["label01"]])
    ax.set_xticks(range(len(ps)))
    ax.set_xticklabels(ps["PatientID"], rotation=90, fontsize=6)
    ax.set_ylabel("Cells after QC")
    handles = [plt.Rectangle((0, 0), 1, 1, color=colors[k]) for k in ("1", "0", "")]
    ax.legend(handles, [f"{positive or 'label 1'} (1)", f"{negative or 'label 0'} (0)", "unlabeled"],
              frameon=False, fontsize=8)
    ax.set_title("Cells per patient")
    save_plot(fig, pdir / "cells_per_patient")
    plt.close(fig)
    used_s = samples[samples["status"] == "used"]["SampleID"].tolist()
    obs = adata.obs
    fig, axes = plt.subplots(1, 2, figsize=(max(8, 0.12 * len(used_s) + 4), 4))
    for ax, col, lab_ in zip(axes, ["n_genes", "pct_mito"], ["Detected genes", "Mitochondrial UMI %"]):
        data = [obs.loc[obs["SampleID"] == s, col].values for s in used_s]
        ax.boxplot(data, showfliers=False)
        ax.set_xticks(range(1, len(used_s) + 1))
        ax.set_xticklabels(used_s, rotation=90, fontsize=6)
        ax.set_ylabel(lab_)
    fig.suptitle("Cell QC by sample (after filtering)")
    save_plot(fig, pdir / "qc_by_sample")
    plt.close(fig)
    frac = pd.crosstab(obs["PatientID"], obs["cell_type"], normalize="index").loc[ps["PatientID"]]
    fig, ax = plt.subplots(figsize=(max(6, 0.12 * len(ps) + 3), 4))
    bottom = np.zeros(len(frac))
    cmap = plt.get_cmap("tab20")
    for i, ct in enumerate(frac.columns):
        ax.bar(range(len(frac)), frac[ct].values, bottom=bottom, color=cmap(i % 20), label=ct)
        bottom += frac[ct].values
    ax.set_xticks(range(len(frac)))
    ax.set_xticklabels(frac.index, rotation=90, fontsize=6)
    ax.set_ylabel("Fraction of cells")
    ax.set_title("Coarse cell types by patient (ordered by label)")
    ax.legend(bbox_to_anchor=(1.01, 1), loc="upper left", fontsize=7, frameon=False)
    save_plot(fig, pdir / "cell_types_by_patient")
    plt.close(fig)

    log.step("Summary")
    log.msg(f"Samples: {len(sheet)} in sheet, {len(used_s)} used")
    log.msg(f"Patients: {len(pat)} ({len(labeled)} labeled), cells: {adata.n_obs}, genes: {adata.n_vars} "
            f"({int(adata.var['in_vocab'].sum())} in scGPT vocabulary)")
    log.step("Done")
    log.msg(f"Dataset: {out / 'dataset.h5ad'}")
    shutil.rmtree(cache, ignore_errors=True)
    log.msg(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
