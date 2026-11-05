#!/usr/bin/env python3
"""Real public example input for cnv_summary: TCGA lung adenocarcinoma (PanCancer Atlas) from the
cBioPortal public API (open access; TCGA, Cell 2018). For n randomly chosen tumour samples it
writes folders shaped like the cnvkit_call output (segments, gene table, summary), a sample_data
CSV with clinical tracks and a gene list.

The gene calls are TCGA GISTIC2 thresholded calls (-2 DEEPDEL, -1 LOSS, 0, 1 GAIN, 2 AMP) with the
TCGA log2 values, and the segments are the TCGA segments (hg19); they were NOT made by our CNVkit
modules, so figures from this input must say "TCGA LUAD (cBioPortal), GISTIC2 calls".

Usage: python3 tools/cnv/make_tcga_example.py <output folder> [n_samples=10] [seed=7]
Needs numpy and pandas; downloads from https://www.cbioportal.org/api.
"""
import json
import sys
import urllib.request
from pathlib import Path

import numpy as np
import pandas as pd

API = "https://www.cbioportal.org/api"
STUDY = "luad_tcga_pan_can_atlas_2018"
GENES = {"CDKN2A": 1029, "MYC": 4609, "EGFR": 1956, "TERT": 7015, "NKX2-1": 7080, "SOX2": 6657,
         "KRAS": 3845, "MDM2": 4193, "CCND1": 595, "TP53": 7157, "STK11": 6794, "PTEN": 5728,
         "RB1": 5925, "SMARCA4": 6597, "MET": 4233}
CALL = {-2: "DEEPDEL", -1: "LOSS", 0: "NEUTRAL", 1: "GAIN", 2: "AMP"}
CN = {"DEEPDEL": 0, "LOSS": 1, "NEUTRAL": 2, "GAIN": 3, "AMP": 6}


def get(path):
    with urllib.request.urlopen(f"{API}{path}", timeout=120) as r:
        return json.load(r)


def post(path, body):
    req = urllib.request.Request(f"{API}{path}", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.load(r)


def seg_category(v):
    return "AMP" if v >= 1.0 else "GAIN" if v >= 0.2 else "DEEPDEL" if v <= -1.2 else "LOSS" if v <= -0.2 else "NEUTRAL"


def main():
    out = Path(sys.argv[1])
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    cna_samples = get(f"/sample-lists/{STUDY}_cna/sample-ids")
    rng = np.random.default_rng(seed)
    samples = sorted(rng.choice(sorted(cna_samples), size=n, replace=False))
    ids = list(GENES.values())
    disc = post(f"/molecular-profiles/{STUDY}_gistic/discrete-copy-number/fetch"
                "?discreteCopyNumberEventType=ALL&projection=SUMMARY",
                {"sampleIds": samples, "entrezGeneIds": ids})
    log2 = post(f"/molecular-profiles/{STUDY}_log2CNA/molecular-data/fetch?projection=SUMMARY",
                {"sampleIds": samples, "entrezGeneIds": ids})
    sym = {v: k for k, v in GENES.items()}
    calls = {(d["sampleId"], sym[d["entrezGeneId"]]): CALL[d["alteration"]] for d in disc}
    l2 = {(d["sampleId"], sym[d["entrezGeneId"]]): d["value"] for d in log2}

    d_call, d_gene, d_sum, d_plot = (out / "cnvkit_call" / x for x in ("02_calls", "03_genes", "05_summary", "04_plots"))
    for d in (d_call, d_gene, d_sum, d_plot):
        d.mkdir(parents=True, exist_ok=True)
    summary = []
    for s in samples:
        seg = pd.DataFrame(get(f"/studies/{STUDY}/samples/{s}/copy-number-segments?projection=SUMMARY"))
        seg = pd.DataFrame({"chromosome": seg["chromosome"].astype(str), "start": seg["start"], "end": seg["end"],
                            "probes": seg["numberOfProbes"], "log2_centered": seg["segmentMean"]})
        seg = seg[seg["chromosome"].isin([str(i) for i in range(1, 23)] + ["X"])].sort_values(
            ["chromosome", "start"], key=lambda c: c.map(lambda x: int(x) if str(x).isdigit() else 23) if c.name == "chromosome" else c)
        seg["category"] = seg["log2_centered"].map(seg_category)
        seg.to_csv(d_call / f"{s}.segments.tsv", sep="\t", index=False)
        rows = []
        for g in GENES:
            call = calls.get((s, g), "NEUTRAL")
            v = l2.get((s, g))
            rows.append({"Gene": g, "CN": CN[call], "Call": call, "Log2": "" if v is None else round(float(v), 3)})
        pd.DataFrame(rows).to_csv(d_gene / f"{s}.genes.tsv", sep="\t", index=False)
        alt = seg[seg["category"] != "NEUTRAL"]
        summary.append({"SampleID": s, "Status": "ok",
                        "FGA": round((alt["end"] - alt["start"]).sum() / (seg["end"] - seg["start"]).sum(), 3),
                        "Segments": len(seg), "AMP_genes": sum(r["Call"] == "AMP" for r in rows),
                        "DEEPDEL_genes": sum(r["Call"] == "DEEPDEL" for r in rows), "Noise_MAD": "NA",
                        "Concordance_FACETS": "NA", "Purity": "NA", "Recentered": "no"})
    pd.DataFrame(summary).to_csv(d_sum / "cnvkit_summary.tsv", sep="\t", index=False)

    pat = pd.DataFrame(get(f"/studies/{STUDY}/clinical-data?clinicalDataType=PATIENT&projection=SUMMARY"))
    pat = pat.pivot(index="patientId", columns="clinicalAttributeId", values="value")
    smp = pd.DataFrame(get(f"/studies/{STUDY}/clinical-data?clinicalDataType=SAMPLE&projection=SUMMARY"))
    smp = smp.pivot(index="sampleId", columns="clinicalAttributeId", values="value")

    def stage(x):
        x = str(x).upper().replace("STAGE ", "")
        return next((r for r in ("IV", "III", "II", "I") if x.startswith(r)), "")

    meta = []
    for s in samples:
        p = pat.loc[s[:12]] if s[:12] in pat.index else pd.Series(dtype=str)
        meta.append({"SampleID": s, "Stage": stage(p.get("AJCC_PATHOLOGIC_TUMOR_STAGE", "")),
                     "Sex": str(p.get("SEX", "")).title(),
                     "Vital status": {"0:LIVING": "Alive", "1:DECEASED": "Dead"}.get(p.get("OS_STATUS", ""), ""),
                     "Fraction genome altered": smp.loc[s].get("FRACTION_GENOME_ALTERED", "") if s in smp.index else ""})
    pd.DataFrame(meta).to_csv(out / "sample_data.csv", index=False)
    (out / "genes.txt").write_text("\n".join(GENES) + "\n")
    (out / "SOURCE.txt").write_text(
        f"TCGA {STUDY} via {API} (public; TCGA, Cell 2018). Samples (seed {seed}): {', '.join(samples)}.\n"
        "Gene calls: GISTIC2 thresholded; segments: TCGA hg19. Not produced by our CNVkit modules.\n")
    print("samples:", ", ".join(samples))


if __name__ == "__main__":
    main()
