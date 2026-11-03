#!/usr/bin/env python3
"""Small test input for the scGPT pipeline from the public 10x PBMC 3k data (scanpy
pbmc3k raw counts). Cells are dealt to fake patients in two cohorts; positive patients
get more monocytes, so a model has a planted signal to find. One sample is written as a
10x mtx folder and the others as h5ad, so both readers are exercised. A Before and an
After sample of one patient check the time filter.

Usage: python3 tools/scgpt/make_test_data.py <pbmc3k_raw.h5ad> <output folder> [patients] [cells]
Writes <output>/matrices/ and <output>/samples.csv. Not real patients: for code tests only.
"""
import gzip
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import scanpy as sc
import scipy.io
import scipy.sparse as sp


def main():
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    n_pat = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    n_cells = int(sys.argv[4]) if len(sys.argv) > 4 else 120
    rng = np.random.default_rng(7)
    a = sc.read_h5ad(src)
    a.var_names_make_unique()
    mono = np.asarray(a[:, ["LYZ", "S100A8", "CD14"]].X.sum(axis=1)).ravel() > 5
    mats = out / "matrices"
    mats.mkdir(parents=True, exist_ok=True)
    rows = []
    for i in range(n_pat):
        pid = f"P{i + 1:02d}"
        label = "PR" if i % 2 == 0 else "PD"
        cohort = "CohortA" if i < n_pat // 2 else "CohortB"
        w = np.where(mono, 4.0 if label == "PR" else 0.5, 1.0)
        times = ["Before", "After"] if i == 0 else ["Before"]
        for t in times:
            idx = rng.choice(a.n_obs, size=n_cells, replace=False, p=w / w.sum())
            s = a[idx].copy()
            sid = f"{pid}_{t}"
            if i == 1:
                d = mats / sid
                d.mkdir(exist_ok=True)
                with gzip.open(d / "matrix.mtx.gz", "wb") as fh:
                    scipy.io.mmwrite(fh, sp.csr_matrix(s.X).T.tocoo())
                pd.DataFrame({"id": s.var["gene_ids"] if "gene_ids" in s.var else s.var_names,
                              "name": s.var_names, "type": "Gene Expression"}).to_csv(
                    d / "features.tsv.gz", sep="\t", header=False, index=False)
                pd.Series(s.obs_names).to_csv(d / "barcodes.tsv.gz", sep="\t", header=False, index=False)
            else:
                s.obs = s.obs[[]]
                s.write_h5ad(mats / f"{sid}.h5ad")
            rows.append({"SampleID": sid, "PatientID": pid, "Cohort": cohort, "Tissue": "blood",
                         "Time": t, "Label": label, "Drug": "anti-PD-1"})
    rows.append({"SampleID": "P99_Before", "PatientID": "P99", "Cohort": "CohortB", "Tissue": "blood",
                 "Time": "Before", "Label": "", "Drug": "anti-PD-1"})
    s = a[rng.choice(a.n_obs, size=n_cells, replace=False)].copy()
    s.obs = s.obs[[]]
    s.write_h5ad(mats / "P99_Before.h5ad")
    pd.DataFrame(rows).to_csv(out / "samples.csv", index=False)
    print(f"{len(rows)} samples in {out}")


if __name__ == "__main__":
    main()
