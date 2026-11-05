#!/usr/bin/env python3
"""SIMULATED 10-sample input for cnv_summary, to show its cohort figures (oncoprint and others)
with several patients. Writes folders shaped like the outputs of cnvkit_call and cnv_facets, a
sample_data CSV and a gene list. All values come from a fixed random seed: they are not results
of any patient or cell line and must be labelled as simulated wherever a figure is shown.

Usage: python3 tools/cnv/make_simulated_cohort.py <output folder>
Writes <out>/cnvkit_call/, <out>/cnv_facets/, <out>/sample_data.csv, <out>/genes.txt.
Needs numpy and pandas.
"""
import sys
from pathlib import Path

import numpy as np
import pandas as pd

# hg38 chromosome lengths (chr1-22) and approximate gene positions (Mb)
CHROM_LEN = [248.96, 242.19, 198.3, 190.21, 181.54, 170.81, 159.35, 145.14, 138.39, 133.8, 135.09,
             133.28, 114.36, 107.04, 101.99, 90.34, 83.26, 80.37, 58.62, 64.44, 46.71, 50.82]
GENES = {  # gene: (chrom, start Mb, P(AMP), P(GAIN), P(LOSS), P(DEEPDEL))
    "CDKN2A": (9, 21.97, 0, 0, .2, .4), "MYC": (8, 127.74, .2, .3, 0, 0), "EGFR": (7, 55.02, .2, .2, 0, 0),
    "TERT": (5, 1.25, .1, .4, 0, 0), "NKX2-1": (14, 36.52, .2, .1, 0, 0), "SOX2": (3, 181.71, .1, .3, 0, 0),
    "KRAS": (12, 25.21, .1, .2, 0, 0), "MDM2": (12, 68.81, .1, .1, 0, 0), "CCND1": (11, 69.64, .1, .2, 0, 0),
    "TP53": (17, 7.67, 0, 0, .5, 0), "STK11": (19, 1.18, 0, 0, .4, .1), "PTEN": (10, 87.86, 0, 0, .3, .1),
    "RB1": (13, 48.3, 0, 0, .3, .1), "SMARCA4": (19, 10.96, 0, 0, .3, 0), "MET": (7, 116.67, .1, .1, 0, 0)}
LOG2 = {"AMP": 1.6, "GAIN": 0.45, "NEUTRAL": 0.0, "LOSS": -0.6, "DEEPDEL": -2.5}
CN = {"AMP": 7, "GAIN": 3, "NEUTRAL": 2, "LOSS": 1, "DEEPDEL": 0}


def category(v):
    return "AMP" if v >= 1.0 else "GAIN" if v >= 0.25 else "DEEPDEL" if v <= -1.5 else "LOSS" if v <= -0.3 else "NEUTRAL"


def main():
    out = Path(sys.argv[1])
    rng = np.random.default_rng(2026)
    samples = [f"P{i:02d}" for i in range(1, 11)]
    call_dir, gene_dir, sum_dir, plot_dir = (out / "cnvkit_call" / d for d in ("02_calls", "03_genes", "05_summary", "04_plots"))
    fsum, fseg = out / "cnv_facets" / "04_summary", out / "cnv_facets" / "02_segments"
    for d in (call_dir, gene_dir, sum_dir, plot_dir, fsum, fseg):
        d.mkdir(parents=True, exist_ok=True)
    summary, facets = [], []
    for s in samples:
        calls = {}
        for g, (_, _, amp, gain, loss, dd) in GENES.items():
            calls[g] = rng.choice(["AMP", "GAIN", "LOSS", "DEEPDEL", "NEUTRAL"],
                                  p=[amp, gain, loss, dd, 1 - amp - gain - loss - dd])
        segs = []
        for ci, length in enumerate(CHROM_LEN, start=1):
            mid = length * rng.uniform(0.35, 0.55)
            for a, b in ((0, mid), (mid, length)):          # arm-like background segments
                v = rng.choice([0.0, 0.0, 0.0, 0.3, -0.4]) + rng.normal(0, 0.05)
                segs.append([str(ci), a, b, v])
        for g, (c, pos, *_ ) in GENES.items():             # focal segment over each gene
            if calls[g] != "NEUTRAL":
                segs.append([str(c), pos - 1.0, pos + 1.0, LOG2[calls[g]] + rng.normal(0, 0.05)])
        seg = pd.DataFrame(segs, columns=["chromosome", "start", "end", "log2_centered"])
        # focal segments override the background: split background around them
        rows = []
        for c, grp in seg.groupby("chromosome", sort=False):
            focal = grp.iloc[2:] if len(grp) > 2 else grp.iloc[0:0]
            for _, bg in grp.iloc[:2].iterrows():
                cuts = [bg.start] + sorted(x for f in focal.itertuples() for x in (f.start, f.end)
                                           if bg.start < x < bg.end) + [bg.end]
                for a, b in zip(cuts[:-1], cuts[1:]):
                    hit = focal[(focal.start <= a) & (focal.end >= b)]
                    v = hit.log2_centered.iloc[0] if len(hit) else bg.log2_centered
                    rows.append([c, int(a * 1e6), int(b * 1e6), v])
        seg = pd.DataFrame(rows, columns=["chromosome", "start", "end", "log2_centered"])
        seg["probes"] = ((seg["end"] - seg["start"]) / 50000).astype(int).clip(lower=5)
        seg["category"] = seg["log2_centered"].map(category)
        seg[["chromosome", "start", "end", "probes", "log2_centered", "category"]].to_csv(
            call_dir / f"{s}.segments.tsv", sep="\t", index=False)
        purity, ploidy = round(rng.uniform(0.3, 0.9), 2), round(rng.choice([2.0, 2.1, 2.4, 3.3, 3.8]), 2)
        genes = []
        for g, (c, pos, *_ ) in GENES.items():
            call = calls[g]
            loh = "yes" if call in ("LOSS", "DEEPDEL") and rng.random() < .6 else "no"
            genes.append({"Gene": g, "Chromosome": str(c), "Start": int(pos * 1e6), "End": int(pos * 1e6) + 50000,
                          "CN": CN[call], "Call": call, "Log2": round(LOG2[call] + rng.normal(0, 0.05), 3),
                          "FACETS_TCN": str(CN[call]), "FACETS_LCN": "0" if loh == "yes" else "1", "LOH": loh})
        pd.DataFrame(genes).to_csv(gene_dir / f"{s}.genes.tsv", sep="\t", index=False)
        altered = seg[seg["category"] != "NEUTRAL"]
        fga = (altered["end"] - altered["start"]).sum() / (seg["end"] - seg["start"]).sum()
        summary.append({"SampleID": s, "Status": "ok", "FGA": round(fga, 3), "Segments": len(seg),
                        "AMP_genes": sum(v == "AMP" for v in calls.values()),
                        "DEEPDEL_genes": sum(v == "DEEPDEL" for v in calls.values()),
                        "Noise_MAD": round(rng.uniform(0.1, 0.25), 3),
                        "Concordance_FACETS": round(rng.uniform(0.7, 0.95), 3), "Purity": purity, "Recentered": "no"})
        facets.append({"SampleID": s, "Status": "ok", "Purity": purity, "Ploidy": ploidy,
                       "LOH_fraction": round(rng.uniform(0.05, 0.4), 3), "WGD": "yes" if ploidy > 3 else "no"})
    pd.DataFrame(summary).to_csv(sum_dir / "cnvkit_summary.tsv", sep="\t", index=False)
    pd.DataFrame(facets).to_csv(fsum / "facets_summary.tsv", sep="\t", index=False)
    pd.DataFrame({"SampleID": samples,
                  "Histology": rng.choice(["LUAD", "LUSC"], 10, p=[.6, .4]),
                  "Stage": rng.choice(["I", "II", "III", "IV"], 10),
                  "Smoking": rng.choice(["Never", "Former", "Current"], 10),
                  "Response": rng.choice(["PR", "SD", "PD"], 10)}).to_csv(out / "sample_data.csv", index=False)
    (out / "genes.txt").write_text("\n".join(GENES) + "\n")
    print(f"simulated cohort written to {out}")


if __name__ == "__main__":
    main()
