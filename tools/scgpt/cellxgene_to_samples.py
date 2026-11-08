#!/usr/bin/env python3
"""Split a CELLxGENE h5ad into one raw-count <SampleID>.h5ad per sample and write a sample
sheet for scgpt_prep. Reads the file in backed mode, one sample at a time, so the whole
matrix is never in memory. Run it where anndata is installed (for example the bx_scgpt image).

Usage:
  python3 cellxgene_to_samples.py h5ad=data.h5ad
      Lists the obs columns with few values, writes nothing.
  python3 cellxgene_to_samples.py h5ad=data.h5ad sample_col=sample_uuid patient_col=donor_id \
      label_col=disease labels="systemic lupus erythematosus=SLE,normal=Normal" \
      cohort_col=Processing_Cohort tissue=Blood max_cells_per_sample=1000 output_dir=lupus

Arguments:
  h5ad                  CELLxGENE h5ad (raw counts in raw.X, or in X when there is no raw)
  sample_col            obs column naming the sample (one file per value)
  patient_col           obs column naming the patient or donor
  label_col             obs column with the label
  labels                value=label pairs, comma separated, exactly two label names; cells of
                        other values are left out
  cohort_col            obs column used as Cohort (batch or study); empty writes one cohort
  tissue                text written in the Tissue column. default: Tissue
  max_cells_per_sample  random cells kept per sample (0 keeps all). default: 0
  seed                  random seed for the cell sampling. default: 1234
  output_dir            new folder: matrices/<SampleID>.h5ad and samples.csv
"""
import csv
import re
import sys
from collections import Counter
from pathlib import Path

OPTIONAL = {"cohort_col": "", "tissue": "Tissue", "max_cells_per_sample": "0", "seed": "1234"}
REQUIRED = ["h5ad", "sample_col", "patient_col", "label_col", "labels", "output_dir"]


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    args = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}")
        args[key] = value.strip().strip("'\"")
    if not args.get("h5ad"):
        fail("Required parameter 'h5ad' is missing")
    return args


def safe_id(text):
    return re.sub(r"[^A-Za-z0-9_.-]", "_", str(text))


def main():
    args = parse_args(sys.argv[1:])
    path = Path(args["h5ad"])
    if not path.is_file():
        fail(f"h5ad not found: {path}")
    import anndata as ad
    import numpy as np
    import scipy.sparse as sp

    a = ad.read_h5ad(path, backed="r")
    obs = a.obs
    list_only = not args.get("sample_col")
    if list_only:
        print(f"Cells: {a.n_obs}, genes: {a.n_vars}, raw: {a.raw is not None}")
        for c in obs.columns:
            n = obs[c].nunique()
            if n <= 30:
                print(f"  {c}: {n} values: " + ", ".join(f"{k} ({v})" for k, v in obs[c].value_counts().items()))
            else:
                print(f"  {c}: {n} values")
        print("Nothing written (list only).")
        return
    for key in REQUIRED:
        if not args.get(key):
            fail(f"Required parameter '{key}' is missing")
    for key in ("sample_col", "patient_col", "label_col") + (("cohort_col",) if args["cohort_col"] else ()):
        if args[key] not in obs.columns:
            fail(f"{key} {args[key]} is not an obs column; columns: {', '.join(obs.columns)}")
    labels = {}
    for pair in args["labels"].split(","):
        if "=" not in pair:
            fail(f"labels needs value=label pairs: {pair}")
        value, label = (x.strip() for x in pair.split("=", 1))
        if value not in set(obs[args["label_col"]].astype(str)):
            fail(f"label value not in {args['label_col']}: {value}; values: "
                 + ", ".join(sorted(set(obs[args["label_col"]].astype(str)))))
        labels[value] = label
    if len(set(labels.values())) != 2:
        fail("labels must give exactly two label names")
    if not re.fullmatch(r"\d+", args["max_cells_per_sample"]) or not re.fullmatch(r"\d+", args["seed"]):
        fail("max_cells_per_sample and seed must be non-negative integers")
    max_cells, seed = int(args["max_cells_per_sample"]), int(args["seed"])
    out = Path(args["output_dir"])
    if out.exists():
        fail(f"output_dir already exists: {out}")

    src = a.raw if a.raw is not None else a
    genes = a.var["feature_name"].astype(str).values if "feature_name" in a.var.columns else a.var_names.values
    sample = obs[args["sample_col"]].astype(str).values
    patient = obs[args["patient_col"]].astype(str).values
    label = obs[args["label_col"]].astype(str).values
    cohort = obs[args["cohort_col"]].astype(str).values if args["cohort_col"] else np.full(a.n_obs, "cohort1")
    keep = np.isin(label, list(labels))
    import pandas as pd
    check = pd.DataFrame({"s": sample[keep], "p": patient[keep], "l": label[keep]}).groupby("s").nunique()
    conflicts = int(((check["p"] > 1) | (check["l"] > 1)).sum())
    if conflicts:
        fail(f"{conflicts} sample(s) have cells of several patients or labels; choose another sample_col")
    rng = np.random.default_rng(seed)
    (out / "matrices").mkdir(parents=True)
    rows, used_ids = [], set()
    order = sorted(set(sample[keep]))
    for n, s in enumerate(order, 1):
        idx = np.flatnonzero(keep & (sample == s))
        pats, labs, cohs = set(patient[idx]), set(label[idx]), Counter(cohort[idx])
        if max_cells and len(idx) > max_cells:
            idx = np.sort(rng.choice(idx, size=max_cells, replace=False))
        x = src.X[idx]
        x = sp.csr_matrix(x, dtype=np.float32)
        if x.nnz and np.any(x.data != np.round(x.data)):
            fail(f"sample {s} has non-integer values; the h5ad does not hold raw counts where expected")
        sid = safe_id(s)
        if sid in used_ids:
            fail(f"two samples map to the same file name {sid}")
        used_ids.add(sid)
        part = ad.AnnData(X=x, obs={"barcode": np.asarray(a.obs_names[idx])},
                          var={"feature_name": genes})
        part.obs_names = part.obs["barcode"].astype(str).values
        part.var_names = [str(g) for g in a.var_names]
        part.write_h5ad(out / "matrices" / f"{sid}.h5ad", compression="gzip")
        rows.append([sid, safe_id(next(iter(pats))), safe_id(cohs.most_common(1)[0][0]), args["tissue"],
                     "Baseline", labels[next(iter(labs))]])
        if n % 25 == 0:
            print(f"  samples written: {n} of {len(order)}", flush=True)
    with (out / "samples.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SampleID", "PatientID", "Cohort", "Tissue", "Time", "Label"])
        w.writerows(rows)
    pat_label = {r[1]: r[5] for r in rows}
    print(f"Samples written: {len(rows)}, patients: {len(pat_label)} ("
          + ", ".join(f"{k} {v}" for k, v in sorted(Counter(pat_label.values()).items())) + ")")
    print(f"Written: {out}/matrices/ and {out}/samples.csv (scgpt_prep: time=all)")


if __name__ == "__main__":
    main()
