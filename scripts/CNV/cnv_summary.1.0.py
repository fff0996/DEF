#!/usr/bin/env python3
"""CNV module 3: cohort summary, cohort figures and an HTML report.

Usage:
    python cnv_summary.1.0.py input_dir="..." output_dir="..."
        [facets_dir="..."] [genes="..."] [genome="hg38"] [cytoband=""] [bin_size="1000000"]
        [top_genes="30"]

Example:
    apptainer exec bx_cnvkit.1.0.sif python cnv_summary.1.0.py \
        input_dir="/out/cnvkit_call" \
        facets_dir="/out/cnv_facets" \
        output_dir="/out/cnv_summary"

Arguments (key=value):
    input_dir  (required) - CNVkit call folder with 02_calls/<SampleID>.segments.tsv and .seg,
                            03_genes/<SampleID>.genes.tsv, 04_plots/ and
                            05_summary/cnvkit_summary.tsv (as written by cnvkit_call).
    output_dir (required) - Output directory.
    facets_dir (optional) - FACETS folder with 04_summary/facets_summary.tsv,
                            02_segments/ and 03_plots/ (as written by cnv_facets).
                            Adds purity, ploidy, LOH and WGD. Empty: CNVkit only.
    genes      (optional) - Genes of interest, one symbol per line (or the first column
                            of a TSV). Empty: the most frequently altered genes.
    genome     (optional) - hg38 or hg19; selects the bundled UCSC cytoband table for
                            chromosome arms. default: hg38
    cytoband   (optional) - UCSC cytoBand file (plain or .gz) instead of the bundled one.
    bin_size   (optional) - Genome bin size (bp) for the cohort heatmap, frequency plot
                            and sample similarity. default: 1000000
    top_genes  (optional) - Number of genes in the oncoprint when genes is empty.
                            default: 30

Outputs (output_dir):
    01_tables/  gene_calls.tsv (gene x sample category), gene_cn.tsv (gene x sample copy
                number), interest_genes.tsv, arm_calls.tsv, instability.tsv
    02_seg/     cohort.seg (IGV), gistic_segments.txt (GISTIC2 segmentation input)
    03_plots/   cohort_heatmap, frequency, arm_heatmap, gene_oncoprint, instability,
                purity_ploidy and concordance (with FACETS), sample_similarity
                (two or more samples); each as .pdf and .png
    04_report/  cnv_report.html with all cohort and per-sample figures (images/)
    logs/       <stamp>.log (stdout) and <stamp>.error.log (stderr)

The previous output_dir content except logs/ is removed at the start, so no input
may be inside output_dir.
"""
import csv
import datetime
import gzip
import html
import math
import os
from pathlib import Path
import re
import shutil
import sys
import threading

MODULE = "cnv_summary"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"facets_dir": "", "genes": "", "genome": "hg38", "cytoband": "", "bin_size": "1000000",
            "top_genes": "30"}
CATEGORY_COLORS = {"AMP": "#B2182B", "GAIN": "#EF8A62", "NEUTRAL": "#F0F0F0",
                   "LOSS": "#67A9CF", "DEEPDEL": "#2166AC", "NA": "#FFFFFF"}
CATEGORIES = ["AMP", "GAIN", "LOSS", "DEEPDEL"]
LOH_COLOR = "#CC79A7"


# ---------------------------------------------------------------- messages and logs
class Tee:
    def __init__(self, stream, path):
        self.stream = stream
        self.file = open(path, "a", encoding="utf-8")
        self.lock = threading.Lock()

    def write(self, text):
        with self.lock:
            self.stream.write(text)
            self.stream.flush()
            self.file.write(text)
            self.file.flush()

    def flush(self):
        with self.lock:
            self.stream.flush()
            self.file.flush()


def fail(*lines):
    sys.stderr.write("Error: " + "\n".join(lines) + "\n")
    sys.stderr.flush()
    sys.exit(1)


def warn(*lines):
    sys.stderr.write("Warning: " + "\n".join(lines) + "\n")
    sys.stderr.flush()


def info(text=""):
    sys.stdout.write(text + "\n")
    sys.stdout.flush()


def start_logs(output_dir):
    logs_dir = output_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    stamp = f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{os.getpid()}"
    sys.stdout = Tee(sys.__stdout__, logs_dir / f"{stamp}.log")
    sys.stderr = Tee(sys.__stderr__, logs_dir / f"{stamp}.error.log")
    return stamp


def parse_args(argv):
    params = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}",
                 "Known parameters: " + ", ".join(REQUIRED + list(OPTIONAL)))
        value = value.strip().strip("'\"").strip()
        params[key] = value if (value or key in REQUIRED) else OPTIONAL[key]
    for key in REQUIRED:
        if not params.get(key):
            fail(f"Required parameter '{key}' is missing")
    return params


def check_outside(output_dir, *inputs):
    out = output_dir.resolve()
    if out == Path("/"):
        fail("output_dir must not be /")
    for p in inputs:
        if not p:
            continue
        rp = Path(p).resolve()
        if rp == out or out in rp.parents:
            fail(f"input {p} is inside output_dir {output_dir}, which is cleaned at the start")


def clean_output(output_dir):
    if output_dir.exists():
        for entry in output_dir.iterdir():
            if entry.name == "logs":
                continue
            if entry.is_dir() and not entry.is_symlink():
                shutil.rmtree(entry)
            else:
                entry.unlink()
    output_dir.mkdir(parents=True, exist_ok=True)


def read_gene_list(path):
    genes = []
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            name = line.strip().split("\t")[0].split(",")[0].strip()
            if name and not name.startswith("#") and name.lower() not in ("gene", "symbol", "hugo_symbol"):
                genes.append(name)
    return list(dict.fromkeys(genes))


def chrom_key(name):
    c = str(name)
    c = c[3:] if c.lower().startswith("chr") else c
    if c.isdigit():
        return int(c)
    return {"X": 23, "Y": 24}.get(c.upper(), 1000)


def chrom_label(name):
    c = str(name)
    return c[3:] if c.lower().startswith("chr") else c


# ---------------------------------------------------------------- plotting helpers
def plotting():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 9, "axes.titlesize": 10, "axes.spines.top": False,
                         "axes.spines.right": False, "pdf.fonttype": 42})
    return plt


def save_figure(plt, fig, plot_dir, name, made):
    fig.savefig(plot_dir / f"{name}.pdf", bbox_inches="tight")
    fig.savefig(plot_dir / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    made.append(name)


def read_cytoband(path):
    """Arms per chromosome label: {label: (p_start, p_end, q_start, q_end)}."""
    opener = gzip.open if str(path).endswith(".gz") else open
    bands = {}
    with opener(path, "rt") as fh:
        for line in fh:
            f = line.rstrip("\n").split("\t")
            if len(f) < 5:
                continue
            label = chrom_label(f[0])
            start, end, stain = int(f[1]), int(f[2]), f[4]
            b = bands.setdefault(label, {"end": 0, "acen": []})
            b["end"] = max(b["end"], end)
            if stain == "acen":
                b["acen"].append((start, end))
    arms = {}
    for label, b in bands.items():
        if b["acen"] and chrom_key(label) < 1000:
            c0 = min(s for s, _ in b["acen"])
            c1 = max(e for _, e in b["acen"])
            arms[label] = (0, c0, c1, b["end"])
    return arms


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    facets_dir = Path(params["facets_dir"]) if params["facets_dir"] else None
    if not (input_dir / "05_summary" / "cnvkit_summary.tsv").is_file():
        fail(f"input_dir does not hold CNVkit call results: {input_dir}",
             "Expected: 05_summary/cnvkit_summary.tsv, 02_calls/, 03_genes/, 04_plots/")
    if facets_dir and not (facets_dir / "04_summary" / "facets_summary.tsv").is_file():
        fail(f"facets_dir does not hold FACETS results: {facets_dir}",
             "Expected: 04_summary/facets_summary.tsv")
    genes_path = Path(params["genes"]) if params["genes"] else None
    if genes_path and not genes_path.is_file():
        fail(f"genes file not found: {genes_path}")
    if params["genome"] not in ("hg38", "hg19"):
        fail(f"genome must be hg38 or hg19: {params['genome']}")
    if params["cytoband"]:
        cytoband = Path(params["cytoband"])
        if not cytoband.is_file():
            fail(f"cytoband file not found: {cytoband}")
    else:
        data_dir = os.environ.get("CNV_DATA_DIR", "")
        cytoband = Path(data_dir) / f"cytoBand.{params['genome']}.txt.gz" if data_dir else None
    for name in ("bin_size", "top_genes"):
        if not params[name].isdigit() or int(params[name]) < 1:
            fail(f"{name} must be a positive integer: {params[name]}")
    bin_size, top_n = int(params["bin_size"]), int(params["top_genes"])
    check_outside(output_dir, input_dir, facets_dir, genes_path, params["cytoband"])

    import numpy as np
    import pandas as pd

    clean_output(output_dir)
    stamp = start_logs(output_dir)
    d_tab, d_seg, d_plot, d_rep = (output_dir / d for d in ("01_tables", "02_seg", "03_plots", "04_report"))
    for d in (d_tab, d_seg, d_plot, d_rep):
        d.mkdir()
    (d_rep / "images").mkdir()

    info(f"############################## {MODULE}")
    info(f"Log files: logs/{stamp}.log (stdout), logs/{stamp}.error.log (stderr)")
    info(f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    info("")
    info("parameters:")
    for key in REQUIRED + list(OPTIONAL):
        info(f"  {key:10s} = {params[key]}")
    info("")

    # ------------------------------------------------------------ inputs
    cn_summary = pd.read_csv(input_dir / "05_summary" / "cnvkit_summary.tsv", sep="\t", dtype=str)
    samples = [s for s in cn_summary.loc[cn_summary["Status"] == "ok", "SampleID"]]
    if not samples:
        fail("no sample with status ok in cnvkit_summary.tsv")
    segs, genes = {}, {}
    for s in samples:
        p = input_dir / "02_calls" / f"{s}.segments.tsv"
        g = input_dir / "03_genes" / f"{s}.genes.tsv"
        if not p.is_file():
            fail(f"segment table not found: {p}")
        segs[s] = pd.read_csv(p, sep="\t", dtype={"chromosome": str})
        genes[s] = pd.read_csv(g, sep="\t", keep_default_na=False, na_values=[""],
                               dtype={"Chromosome": str, "FACETS_TCN": str, "FACETS_LCN": str, "LOH": str,
                                      "CN": "Int64"}) if g.is_file() else pd.DataFrame()
    facets = pd.read_csv(facets_dir / "04_summary" / "facets_summary.tsv", sep="\t", dtype=str) if facets_dir else None
    gene_set = read_gene_list(genes_path) if genes_path else []
    info(f"Samples: {len(samples)} ({', '.join(samples)})")
    info(f"FACETS: {'yes' if facets is not None else 'no'}")
    plt = plotting()
    made = []
    notes = []

    # ------------------------------------------------------------ Step 1: tables
    info("")
    info("############################## Step 1: gene and segment tables")
    long = []
    for s in samples:
        g = genes[s]
        if g.empty:
            continue
        g = g.assign(SampleID=s)
        long.append(g)
    gl = pd.concat(long) if long else pd.DataFrame(columns=["Gene", "Call", "CN", "SampleID"])
    if not gl.empty:
        gl = gl.drop_duplicates(["SampleID", "Gene"])
        gl.pivot(index="Gene", columns="SampleID", values="Call").reindex(columns=samples).to_csv(
            d_tab / "gene_calls.tsv", sep="\t")
        gl.pivot(index="Gene", columns="SampleID", values="CN").reindex(columns=samples).to_csv(
            d_tab / "gene_cn.tsv", sep="\t")
    if gene_set:
        sel = gl[gl["Gene"].isin(gene_set)]
        missing = [g for g in gene_set if g not in set(gl["Gene"])]
        if missing:
            warn(f"{len(missing)} gene(s) of interest have no bins (not covered or not annotated): "
                 + ", ".join(missing[:20]) + (" ..." if len(missing) > 20 else ""))
    else:
        alt = gl[gl["Call"].isin(CATEGORIES)]
        score = alt.assign(w=alt["Call"].map({"AMP": 3, "DEEPDEL": 3, "GAIN": 1, "LOSS": 1})).groupby("Gene")["w"].sum()
        top = list(score.sort_values(ascending=False).head(top_n).index)
        sel = gl[gl["Gene"].isin(top)]
        gene_set = top
    keep_cols = [c for c in ["SampleID", "Gene", "Chromosome", "Start", "End", "CN", "Call", "Log2",
                             "FACETS_TCN", "FACETS_LCN", "LOH"] if c in sel.columns]
    sel[keep_cols].to_csv(d_tab / "interest_genes.tsv", sep="\t", index=False)

    seg_frames = []
    for s in samples:
        d = segs[s][["chromosome", "start", "end", "probes", "log2_centered"]].copy()
        d.insert(0, "ID", s)
        seg_frames.append(d)
    cohort_seg = pd.concat(seg_frames)
    cohort_seg.columns = ["ID", "chrom", "loc.start", "loc.end", "num.mark", "seg.mean"]
    cohort_seg.to_csv(d_seg / "cohort.seg", sep="\t", index=False)
    gistic = cohort_seg.copy()
    gistic["chrom"] = gistic["chrom"].map(chrom_key)
    gistic = gistic[gistic["chrom"] <= 23]
    gistic.columns = ["Sample", "Chromosome", "Start", "End", "Num_Markers", "Seg.CN"]
    gistic.to_csv(d_seg / "gistic_segments.txt", sep="\t", index=False)
    info(f"Genes of interest in the tables: {len(gene_set)}")

    # ------------------------------------------------------------ genome bins
    chroms = sorted({c for s in samples for c in segs[s]["chromosome"] if chrom_key(c) <= 24}, key=chrom_key)
    chrom_len = {c: max(int(segs[s].loc[segs[s]["chromosome"] == c, "end"].max())
                        for s in samples if (segs[s]["chromosome"] == c).any()) for c in chroms}
    bin_chrom, bin_start = [], []
    for c in chroms:
        for b in range(0, chrom_len[c], bin_size):
            bin_chrom.append(c)
            bin_start.append(b)
    bin_chrom, bin_start = np.array(bin_chrom), np.array(bin_start)
    bin_mid = bin_start + bin_size / 2
    log2_mat = np.full((len(samples), len(bin_chrom)), np.nan)
    cat_mat = np.full((len(samples), len(bin_chrom)), "NA", dtype=object)
    for i, s in enumerate(samples):
        d = segs[s]
        for c in chroms:
            mask = bin_chrom == c
            dc = d[d["chromosome"] == c].sort_values("start")
            if dc.empty:
                continue
            idx = np.clip(np.searchsorted(dc["start"].to_numpy(), bin_mid[mask], side="right") - 1, 0, None)
            inside = bin_mid[mask] < dc["end"].to_numpy()[idx]
            cols = np.where(mask)[0]
            log2_mat[i, cols[inside]] = dc["log2_centered"].to_numpy()[idx][inside]
            cat_mat[i, cols[inside]] = dc["category"].to_numpy()[idx][inside]
    offsets, acc = {}, 0
    for c in chroms:
        offsets[c] = acc
        acc += chrom_len[c]
    total = acc
    bin_x = np.array([offsets[c] for c in bin_chrom]) + bin_mid

    def genome_axis(ax):
        for k, c in enumerate(chroms):
            if k % 2:
                ax.axvspan(offsets[c], offsets[c] + chrom_len[c], color="#F3F3F3", lw=0, zorder=0)
        ax.set_xlim(0, total)
        ax.set_xticks([offsets[c] + chrom_len[c] / 2 for c in chroms])
        ax.set_xticklabels([chrom_label(c) for c in chroms], fontsize=7)
        ax.tick_params(axis="x", length=0)

    # ------------------------------------------------------------ Step 2: arm-level calls
    info("")
    info("############################## Step 2: chromosome arms and instability")
    arms = {}
    if cytoband is not None and Path(cytoband).is_file():
        arms = read_cytoband(cytoband)
    else:
        warn("no cytoband table (set cytoband= or use the image with bundled tables); arm-level calls are skipped.")
        notes.append("Arm-level calls were skipped: no cytoband table.")
    arm_rows = []
    for s in samples:
        d = segs[s]
        row = {"SampleID": s}
        altered = 0
        for c in chroms:
            label = chrom_label(c)
            if label not in arms:
                continue
            p0, p1, q0, q1 = arms[label]
            for arm, (a0, a1) in (("p", (p0, p1)), ("q", (q0, q1))):
                dc = d[d["chromosome"] == c]
                ov = (np.minimum(dc["end"], a1) - np.maximum(dc["start"], a0)).clip(lower=0)
                covered = ov.sum()
                if covered < 0.2 * (a1 - a0):
                    row[f"{label}{arm}"] = "NA"
                    continue
                gain = ov[dc["category"].isin(["GAIN", "AMP"])].sum() / covered
                loss = ov[dc["category"].isin(["LOSS", "DEEPDEL"])].sum() / covered
                call = "GAIN" if gain >= 0.5 else ("LOSS" if loss >= 0.5 else "NEUTRAL")
                altered += call != "NEUTRAL"
                row[f"{label}{arm}"] = call
        row["AneuploidyScore"] = altered if arms else "NA"
        arm_rows.append(row)
    arm_df = pd.DataFrame(arm_rows)
    arm_df.to_csv(d_tab / "arm_calls.tsv", sep="\t", index=False)

    inst = cn_summary[cn_summary["SampleID"].isin(samples)][
        ["SampleID", "FGA", "Segments", "AMP_genes", "DEEPDEL_genes", "Noise_MAD", "Concordance_FACETS", "Purity",
         "Recentered"]].copy()
    inst = inst.merge(arm_df[["SampleID", "AneuploidyScore"]], on="SampleID", how="left")
    if facets is not None:
        f = facets[["SampleID", "Status", "Purity", "Ploidy", "LOH_fraction", "WGD"]].rename(
            columns={"Status": "FACETS_Status", "Purity": "FACETS_Purity", "Ploidy": "FACETS_Ploidy"})
        inst = inst.merge(f, on="SampleID", how="left")
    inst.to_csv(d_tab / "instability.tsv", sep="\t", index=False)

    # ------------------------------------------------------------ Step 3: cohort figures
    info("")
    info("############################## Step 3: cohort figures")
    from matplotlib.colors import ListedColormap
    order = list(range(len(samples)))
    if len(samples) >= 3:
        from scipy.cluster.hierarchy import leaves_list, linkage
        filled = np.nan_to_num(log2_mat, nan=0.0)
        order = list(leaves_list(linkage(filled, method="average", metric="euclidean")))

    # Cohort heatmap.
    fig, ax = plt.subplots(figsize=(14, 0.35 * len(samples) + 1.6))
    im = ax.imshow(np.clip(log2_mat[order], -1.5, 1.5), aspect="auto", cmap="RdBu_r", vmin=-1.5, vmax=1.5,
                   interpolation="nearest", extent=(0, len(bin_x), len(samples), 0))
    starts = [np.where(bin_chrom == c)[0][0] for c in chroms]
    for k in starts[1:]:
        ax.axvline(k, color="#333333", lw=0.5)
    ax.set_xticks([np.mean(np.where(bin_chrom == c)[0]) for c in chroms])
    ax.set_xticklabels([chrom_label(c) for c in chroms], fontsize=7)
    ax.set_yticks(np.arange(len(samples)) + 0.5)
    ax.set_yticklabels([samples[i] for i in order], fontsize=7)
    ax.tick_params(length=0)
    cb = fig.colorbar(im, ax=ax, fraction=0.02, pad=0.01)
    cb.set_label("log2 copy ratio (centred)", fontsize=8)
    ax.set_title(f"Copy number across the cohort ({len(samples)} samples, {bin_size // 1000} kb bins"
                 + (", clustered" if len(samples) >= 3 else "") + ")", loc="left")
    save_figure(plt, fig, d_plot, "cohort_heatmap", made)

    # Frequency plot.
    n = len(samples)
    gain_f = np.array([(cat_mat[:, j] == "GAIN").sum() + (cat_mat[:, j] == "AMP").sum() for j in range(len(bin_x))]) / n
    amp_f = np.array([(cat_mat[:, j] == "AMP").sum() for j in range(len(bin_x))]) / n
    loss_f = np.array([(cat_mat[:, j] == "LOSS").sum() + (cat_mat[:, j] == "DEEPDEL").sum() for j in range(len(bin_x))]) / n
    del_f = np.array([(cat_mat[:, j] == "DEEPDEL").sum() for j in range(len(bin_x))]) / n
    fig, ax = plt.subplots(figsize=(14, 3.8))
    genome_axis(ax)
    w = bin_size
    ax.bar(bin_x, gain_f * 100, width=w, color=CATEGORY_COLORS["GAIN"], lw=0, label="Gain (incl. AMP)")
    ax.bar(bin_x, amp_f * 100, width=w, color=CATEGORY_COLORS["AMP"], lw=0, label="AMP")
    ax.bar(bin_x, -loss_f * 100, width=w, color=CATEGORY_COLORS["LOSS"], lw=0, label="Loss (incl. DEEPDEL)")
    ax.bar(bin_x, -del_f * 100, width=w, color=CATEGORY_COLORS["DEEPDEL"], lw=0, label="DEEPDEL")
    ax.axhline(0, color="#333333", lw=0.6)
    ax.set_ylim(-105, 105)
    ax.set_yticks([-100, -50, 0, 50, 100])
    ax.set_yticklabels(["100", "50", "0", "50", "100"])
    ax.set_ylabel("Samples (%)   loss  |  gain")
    ax.legend(loc="upper right", ncol=4, fontsize=7, frameon=False, bbox_to_anchor=(1, 1.12))
    ax.set_title(f"Frequency of copy-number changes ({n} samples)", loc="left")
    save_figure(plt, fig, d_plot, "frequency", made)

    # Arm heatmap.
    arm_cols = [c for c in arm_df.columns if c not in ("SampleID", "AneuploidyScore")]
    if arm_cols:
        code = {"LOSS": 0, "NEUTRAL": 1, "GAIN": 2}
        mat = np.array([[code.get(v, np.nan) for v in arm_df.loc[i, arm_cols]] for i in range(len(arm_df))], dtype=float)
        fig, (ax, ax2) = plt.subplots(1, 2, figsize=(14, 0.35 * len(samples) + 1.8),
                                      gridspec_kw={"width_ratios": [12, 1.2]})
        cmap = ListedColormap([CATEGORY_COLORS["LOSS"], "#F0F0F0", CATEGORY_COLORS["GAIN"]])
        cmap.set_bad("#FFFFFF")
        ax.imshow(np.ma.masked_invalid(mat), aspect="auto", cmap=cmap, vmin=0, vmax=2, interpolation="nearest")
        ax.set_xticks(range(len(arm_cols)))
        ax.set_xticklabels(arm_cols, rotation=90, fontsize=6.5)
        ax.set_yticks(range(len(arm_df)))
        ax.set_yticklabels(arm_df["SampleID"], fontsize=7)
        ax.tick_params(length=0)
        ax.set_title("Chromosome arm calls (blue: loss, red: gain, white: not covered)", loc="left")
        ax2.barh(range(len(arm_df)), pd.to_numeric(arm_df["AneuploidyScore"], errors="coerce").fillna(0), color="#555555")
        ax2.set_ylim(len(arm_df) - 0.5, -0.5)
        ax2.set_yticks([])
        ax2.set_title("Aneuploidy\nscore", fontsize=8)
        save_figure(plt, fig, d_plot, "arm_heatmap", made)

    # Gene oncoprint.
    genes_in = [g for g in gene_set if g in set(gl["Gene"])]
    if genes_in:
        piv = gl[gl["Gene"].isin(genes_in)].pivot(index="Gene", columns="SampleID", values="Call").reindex(
            index=genes_in, columns=samples)
        loh = gl[gl["Gene"].isin(genes_in)].pivot(index="Gene", columns="SampleID", values="LOH").reindex(
            index=genes_in, columns=samples) if "LOH" in gl.columns else None
        fig, ax = plt.subplots(figsize=(max(4, 0.45 * len(samples) + 2.5), 0.3 * len(genes_in) + 1.6))
        for yi, g in enumerate(genes_in):
            for xi, s in enumerate(samples):
                cat = piv.loc[g, s] if isinstance(piv.loc[g, s], str) else "NA"
                ax.add_patch(plt.Rectangle((xi + 0.05, yi + 0.08), 0.9, 0.84, fc=CATEGORY_COLORS.get(cat, "#FFFFFF"),
                                           ec="#DDDDDD", lw=0.4))
                if loh is not None and loh.loc[g, s] == "yes":
                    ax.plot(xi + 0.5, yi + 0.5, marker="o", ms=3.5, color=LOH_COLOR, mec="white", mew=0.4)
        ax.set_xlim(0, len(samples))
        ax.set_ylim(len(genes_in), 0)
        ax.set_xticks(np.arange(len(samples)) + 0.5)
        ax.set_xticklabels(samples, rotation=90, fontsize=7)
        ax.set_yticks(np.arange(len(genes_in)) + 0.5)
        ax.set_yticklabels(genes_in, fontsize=7, style="italic")
        ax.tick_params(length=0)
        for side in ("left", "bottom"):
            ax.spines[side].set_visible(False)
        from matplotlib.patches import Patch
        from matplotlib.lines import Line2D
        handles = [Patch(color=CATEGORY_COLORS[c], label=c) for c in CATEGORIES]
        if loh is not None:
            handles.append(Line2D([0], [0], marker="o", color="w", markerfacecolor=LOH_COLOR, ms=6, label="LOH"))
        ax.legend(handles=handles, loc="upper left", bbox_to_anchor=(1.01, 1), fontsize=7, frameon=False)
        ax.set_title("Gene-level copy number" + ("" if params["genes"] else " (most frequently altered genes)"),
                     loc="left")
        save_figure(plt, fig, d_plot, "gene_oncoprint", made)

    # Instability.
    fga = pd.to_numeric(inst["FGA"], errors="coerce")
    srt = inst.assign(_f=fga).sort_values("_f", ascending=False)
    has_loh = "LOH_fraction" in srt.columns
    fig, axes = plt.subplots(2 if has_loh else 1, 1, figsize=(max(5, 0.4 * len(samples) + 2), 5.4 if has_loh else 3),
                             squeeze=False, sharex=True)
    axes[0, 0].bar(range(len(srt)), srt["_f"].fillna(0), color="#7A4F9A")
    axes[0, 0].set_ylabel("Fraction genome\naltered (FGA)")
    axes[0, 0].set_ylim(0, 1)
    if has_loh:
        axes[1, 0].bar(range(len(srt)), pd.to_numeric(srt["LOH_fraction"], errors="coerce").fillna(0), color=LOH_COLOR)
        axes[1, 0].set_ylabel("LOH fraction\n(FACETS)")
        axes[1, 0].set_ylim(0, 1)
    axes[-1, 0].set_xticks(range(len(srt)))
    axes[-1, 0].set_xticklabels(srt["SampleID"], rotation=90, fontsize=7)
    axes[0, 0].set_title("Genomic instability per sample (sorted by FGA)", loc="left")
    save_figure(plt, fig, d_plot, "instability", made)

    if facets is not None:
        ok = facets[facets["Status"].isin(["ok", "low_purity"])].copy()
        if not ok.empty:
            pur, plo = pd.to_numeric(ok["Purity"], errors="coerce"), pd.to_numeric(ok["Ploidy"], errors="coerce")
            fig, ax = plt.subplots(figsize=(5.2, 4.4))
            wgd = ok["WGD"] == "yes"
            ax.scatter(pur[~wgd], plo[~wgd], s=36, color="#0072B2", label="no WGD", zorder=3)
            ax.scatter(pur[wgd], plo[wgd], s=36, color="#D55E00", marker="D", label="WGD", zorder=3)
            for x, y, s in zip(pur, plo, ok["SampleID"]):
                if not (math.isnan(x) or math.isnan(y)):
                    ax.annotate(s, (x, y), xytext=(4, 3), textcoords="offset points", fontsize=6.5)
            ax.set_xlim(0, 1.02)
            ax.set_ylim(1, max(5, float(np.nanmax(plo)) + 0.5) if plo.notna().any() else 5)
            ax.set_xlabel("Purity (FACETS)")
            ax.set_ylabel("Ploidy (FACETS)")
            ax.legend(fontsize=7, frameon=False)
            ax.set_title("Tumor purity and ploidy", loc="left")
            save_figure(plt, fig, d_plot, "purity_ploidy", made)
        conc = pd.to_numeric(cn_summary.set_index("SampleID").reindex(samples)["Concordance_FACETS"], errors="coerce")
        if conc.notna().any():
            fig, ax = plt.subplots(figsize=(max(4, 0.4 * len(samples) + 2), 3))
            ax.bar(range(len(samples)), conc.fillna(0), color="#009E73")
            ax.set_xticks(range(len(samples)))
            ax.set_xticklabels(samples, rotation=90, fontsize=7)
            ax.set_ylim(0, 1)
            ax.set_ylabel("Length fraction with the\nsame total copy number")
            ax.set_title("Agreement of CNVkit and FACETS copy numbers", loc="left")
            save_figure(plt, fig, d_plot, "concordance", made)

    if len(samples) >= 2:
        sim = pd.DataFrame(log2_mat.T, columns=samples).corr()
        fig, ax = plt.subplots(figsize=(0.45 * len(samples) + 3, 0.45 * len(samples) + 2.4))
        im = ax.imshow(sim.iloc[order, order], cmap="viridis", vmin=-1, vmax=1)
        ax.set_xticks(range(len(samples)))
        ax.set_xticklabels([samples[i] for i in order], rotation=90, fontsize=7)
        ax.set_yticks(range(len(samples)))
        ax.set_yticklabels([samples[i] for i in order], fontsize=7)
        if len(samples) <= 20:
            for a in range(len(samples)):
                for b in range(len(samples)):
                    v = sim.iloc[order[a], order[b]]
                    ax.text(b, a, f"{v:.2f}", ha="center", va="center", fontsize=6,
                            color="white" if v < 0.5 else "black")
        fig.colorbar(im, ax=ax, fraction=0.04, label="Pearson r of binned log2")
        ax.set_title("Similarity of copy-number profiles", loc="left")
        save_figure(plt, fig, d_plot, "sample_similarity", made)
    else:
        notes.append("Sample similarity needs two or more samples.")
    info("Figures: " + ", ".join(made))

    # ------------------------------------------------------------ Step 4: HTML report
    info("")
    info("############################## Step 4: HTML report")
    img_dir = d_rep / "images"

    def add_image(src, label):
        if src.is_file():
            shutil.copyfile(src, img_dir / src.name)
            return (f'<figure><img src="images/{html.escape(src.name)}" alt="{html.escape(label)}">'
                    f'<figcaption>{html.escape(label)} &middot; '
                    f'<a href="images/{html.escape(src.name)}">PNG</a></figcaption></figure>')
        return ""

    def table_html(df, max_rows=60):
        return df.head(max_rows).to_html(index=False, escape=True, na_rep="NA", border=0, classes="tbl")

    cohort_titles = {"cohort_heatmap": "Cohort heatmap", "frequency": "Gain and loss frequency",
                     "arm_heatmap": "Chromosome arms", "gene_oncoprint": "Genes", "instability": "Instability",
                     "purity_ploidy": "Purity and ploidy", "concordance": "CNVkit and FACETS agreement",
                     "sample_similarity": "Sample similarity"}
    sample_plots = [("cnvkit", "genome_profile", "Genome-wide copy number (CNVkit)"),
                    ("facets", "allele_specific", "Allele-specific copy number and LOH (FACETS)"),
                    ("cnvkit", "chromosome_diagram", "Altered segments by chromosome"),
                    ("cnvkit", "focal_genes", "Genes of interest"),
                    ("facets", "facets_cncf", "FACETS fit (log ratio, allelic imbalance, copy number)"),
                    ("facets", "baf", "B-allele frequency"),
                    ("cnvkit", "chromosomes", "All chromosomes (one page each in the PDF)"),
                    ("cnvkit", "cn_state_hist", "Segment levels"),
                    ("cnvkit", "qc", "Quality control")]
    parts = [f"<h1>CNV report</h1><p class='meta'>{len(samples)} sample(s) &middot; "
             f"{'CNVkit + FACETS' if facets is not None else 'CNVkit only (no purity correction)'} &middot; "
             f"generated {datetime.datetime.now():%Y-%m-%d %H:%M}</p>"]
    toc = ["<nav><b>Contents</b><ul><li><a href='#cohort'>Cohort</a></li>"] + \
          [f"<li><a href='#s-{html.escape(s)}'>{html.escape(s)}</a></li>" for s in samples] + ["</ul></nav>"]
    parts.append("".join(toc))
    parts.append("<section id='cohort'><h2>Cohort</h2>")
    parts.append(table_html(inst))
    for note in notes:
        parts.append(f"<p class='note'>{html.escape(note)}</p>")
    for name in made:
        parts.append(f"<h3>{html.escape(cohort_titles.get(name, name))}</h3>")
        parts.append(add_image(d_plot / f"{name}.png", cohort_titles.get(name, name)))
    parts.append("</section>")
    for s in samples:
        parts.append(f"<section id='s-{html.escape(s)}'><h2>{html.escape(s)}</h2>")
        srow = cn_summary[cn_summary["SampleID"] == s].iloc[0]
        facts = [f"Segments {srow['Segments']}", f"FGA {srow['FGA']}", f"AMP genes {srow['AMP_genes']}",
                 f"DEEPDEL genes {srow['DEEPDEL_genes']}", f"Purity used {srow['Purity']}",
                 f"Recentred {srow['Recentered']}"]
        if facets is not None and (facets["SampleID"] == s).any():
            frow = facets[facets["SampleID"] == s].iloc[0]
            facts += [f"FACETS {frow['Status']}", f"Ploidy {frow['Ploidy']}", f"LOH {frow['LOH_fraction']}",
                      f"WGD {frow['WGD']}"]
        parts.append("<p class='facts'>" + " &middot; ".join(html.escape(str(x)) for x in facts) + "</p>")
        for source, plot, label in sample_plots:
            folder = input_dir / "04_plots" if source == "cnvkit" else (facets_dir / "03_plots" if facets_dir else None)
            if folder is not None:
                parts.append(add_image(folder / f"{s}.{plot}.png", label))
        g = genes[s]
        if not g.empty:
            altered = g[g["Call"].isin(["AMP", "DEEPDEL"])].copy()
            if not altered.empty:
                altered["abs"] = altered["Log2"].abs()
                cols = [c for c in ["Gene", "Chromosome", "Start", "End", "CN", "Call", "Log2", "LOH"] if c in altered]
                parts.append("<h3>Amplified and deeply deleted genes</h3>")
                parts.append(table_html(altered.sort_values("abs", ascending=False)[cols], 40))
        parts.append("</section>")
    style = ("body{font-family:-apple-system,Segoe UI,Helvetica,Arial,sans-serif;max-width:1180px;margin:24px auto;"
             "padding:0 16px;color:#222}h1{margin-bottom:4px}h2{border-bottom:2px solid #ddd;padding-bottom:4px;"
             "margin-top:40px}nav ul{columns:4;padding-left:18px}.meta,.facts,.note{color:#555}"
             "figure{margin:14px 0}img{max-width:100%;border:1px solid #eee}figcaption{font-size:12px;color:#666}"
             "table.tbl{border-collapse:collapse;font-size:12px}table.tbl td,table.tbl th{border:1px solid #ddd;"
             "padding:3px 6px;text-align:right}table.tbl th{background:#f5f5f5}")
    (d_rep / "cnv_report.html").write_text(
        "<!doctype html><html lang='en'><meta charset='utf-8'><title>CNV report</title>"
        f"<style>{style}</style><body>" + "".join(parts) + "</body></html>", encoding="utf-8")

    info("")
    info("############################## Summary")
    info(f"Samples: {len(samples)}; figures: {len(made)}; genes of interest: {len(gene_set)}")
    info("")
    info("############################## Done")
    info(f"Report: {d_rep / 'cnv_report.html'}")
    info(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
