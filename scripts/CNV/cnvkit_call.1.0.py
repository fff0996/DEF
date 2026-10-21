#!/usr/bin/env python3
"""CNV module 2: tumor copy-number segments and calls with CNVkit.

Usage:
    python cnvkit_call.1.0.py input_dir="..." sample_data="..." reference_dir="..." output_dir="..."
        [facets_dir="..."] [genes="..."] [segment_method="cbs"] [amp_ratio="2"]
        [bam_suffix=""] [threads="auto"]

Example:
    apptainer exec bx_cnvkit.1.0.sif python cnvkit_call.1.0.py \
        input_dir="/data/bam" \
        sample_data="/data/samples.csv" \
        reference_dir="/out/cnvkit_reference" \
        facets_dir="/out/cnv_facets" \
        output_dir="/out/cnvkit_call"

Arguments (key=value):
    input_dir      (required) - Directory with coordinate-sorted, duplicate-marked BAM
                                files and their indexes (.bai); searched recursively.
    sample_data    (required) - Sample sheet (CSV): SampleID (tumor), NormalID, optional
                                Sex (female, male, or empty: inferred). Every SampleID
                                is analysed.
    reference_dir  (required) - CNVkit reference folder. It must hold
                                01_reference/reference.cnn and 04_metadata/reference_info.tsv
                                (seq_method, reference type), as written by cnvkit_reference.
    output_dir     (required) - Output directory.
    facets_dir     (optional) - FACETS result folder with 04_summary/facets_summary.tsv and
                                02_segments/<SampleID>.facets_segments.tsv (as written by
                                cnv_facets). When a sample has a FACETS fit with status ok,
                                its copy ratios are recentred on the regions FACETS calls
                                diploid heterozygous (total 2, minor 1) and converted to
                                integer copy numbers with its purity. Empty: no correction.
    genes          (optional) - Genes of interest, one symbol per line (or the first column
                                of a TSV). They are labelled in the plots and get zoomed
                                panels. Empty: the most strongly altered genes are shown.
    segment_method (optional) - CNVkit segmentation: cbs, hmm, or haar. default: cbs
    amp_ratio      (optional) - A gene is AMP when its copy number is at least amp_ratio
                                times the baseline copy number. default: 2
    bam_suffix     (optional) - Only BAM files whose name ends with this text are used.
    threads        (optional) - auto uses the cores allocated to the job. default: auto

Copy-number categories per gene and segment (baseline = 2, or 4 when the FACETS
ploidy is 2.7 or more; half of it on chrX and chrY of male samples):
    DEEPDEL CN = 0; LOSS 0 < CN < baseline; NEUTRAL CN = baseline;
    GAIN baseline < CN < amp_ratio x baseline; AMP CN >= amp_ratio x baseline.

Outputs (output_dir):
    01_cnvkit/<SampleID>/     CNVkit batch output (coverage, .cnr, .cns)
    02_calls/<SampleID>.cnr, .cns, .call.cns (CN per segment), .seg (IGV; log2 after
             recentring), .segments.tsv (chromosome, start, end, probes,
             log2_centered, cn, category)
    03_genes/<SampleID>.genes.tsv   Gene, Chromosome, Start, End, Bins, Log2, CN,
             Call, and with FACETS: FACETS_TCN, FACETS_LCN, LOH
    04_plots/<SampleID>.<plot>.pdf and .png for genome_profile, chromosomes (one page
             per chromosome in the PDF, grid in the PNG), chromosome_diagram,
             focal_genes, cn_state_hist, qc
    05_summary/cnvkit_summary.tsv, all_samples.seg
    logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)

The run fails (exit 1) only if every sample fails; failed samples are listed in
cnvkit_summary.tsv. The previous output_dir content except logs/ is removed at
the start, so no input may be inside output_dir.
"""
import csv
import datetime
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading

MODULE = "cnvkit_call"
REQUIRED = ["input_dir", "sample_data", "reference_dir", "output_dir"]
OPTIONAL = {"facets_dir": "", "genes": "", "segment_method": "cbs", "amp_ratio": "2",
            "bam_suffix": "", "threads": "auto"}
ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")
CATEGORY_COLORS = {"AMP": "#B2182B", "GAIN": "#EF8A62", "NEUTRAL": "#7F7F7F",
                   "LOSS": "#67A9CF", "DEEPDEL": "#2166AC"}
CATEGORIES = ["AMP", "GAIN", "NEUTRAL", "LOSS", "DEEPDEL"]


# ---------------------------------------------------------------- messages and logs
class Tee:
    """Write to a console stream and a log file (thread-safe)."""

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


def run(cmd, label, threads=None, capture=False):
    """Run a command with stdout to the log and stderr to the error log.
    Returns (exit code, captured stdout when capture=True)."""
    env = dict(os.environ)
    if threads:
        for name in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
            env[name] = str(threads)
    info("Command: " + " ".join(str(c) for c in cmd))
    proc = subprocess.Popen([str(c) for c in cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, bufsize=1, env=env)
    captured = []

    def pump(src, dst, keep):
        for line in src:
            dst.write(line)
            if keep:
                captured.append(line)

    readers = [threading.Thread(target=pump, args=(proc.stdout, sys.stdout, capture)),
               threading.Thread(target=pump, args=(proc.stderr, sys.stderr, False))]
    for r in readers:
        r.start()
    for r in readers:
        r.join()
    proc.wait()
    if proc.returncode != 0:
        warn(f"{label} failed (exit code {proc.returncode})")
    return proc.returncode, "".join(captured)


# ---------------------------------------------------------------- arguments and inputs
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


def allocated_cores():
    try:
        return max(1, int(subprocess.check_output(["nproc"], text=True).strip()))
    except (OSError, ValueError, subprocess.CalledProcessError):
        return max(1, len(os.sched_getaffinity(0)))


def resolve_threads(value):
    allocated = allocated_cores()
    if value == "auto":
        return allocated, allocated
    if not value.isdigit() or int(value) < 1:
        fail(f"threads must be auto or a positive integer: {value}")
    return min(int(value), allocated), allocated


def read_sample_sheet(path):
    with open(path, newline="", encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        fail(f"sample_data has no rows: {path}")
    header = [h.strip() for h in rows[0].keys()]
    if "SampleID" not in header or "NormalID" not in header:
        fail(f"sample_data must have the columns SampleID and NormalID: {path}",
             "Columns found: " + ", ".join(header))
    samples, seen = [], set()
    for i, row in enumerate(rows, start=2):
        row = {k.strip(): (v or "").strip() for k, v in row.items() if k}
        sid, nid, sex = row.get("SampleID", ""), row.get("NormalID", ""), row.get("Sex", "").lower()
        if not sid:
            fail(f"sample_data line {i}: SampleID is empty")
        for value in (sid, nid):
            if value and not ID_PATTERN.match(value):
                fail(f"sample_data line {i}: invalid ID '{value}' "
                     "(use letters, digits, dot, underscore, hyphen)")
        if sid in seen:
            fail(f"sample_data line {i}: duplicate SampleID {sid}")
        if sex not in ("", "female", "male", "f", "m"):
            fail(f"sample_data line {i}: Sex must be female, male, or empty: {row.get('Sex')}")
        seen.add(sid)
        samples.append({"SampleID": sid, "NormalID": nid, "Sex": {"f": "female", "m": "male"}.get(sex, sex)})
    return samples


def list_bams(input_dir, suffix):
    bams = []
    for root, _dirs, files in os.walk(input_dir):
        for name in files:
            if name.endswith(".bam") and (not suffix or name.endswith(suffix)):
                bams.append(Path(root) / name)
    return sorted(bams)


def find_bam(bams, sample_id, input_dir, suffix):
    exact = re.compile(rf"^{re.escape(sample_id)}([._-]|$)")
    loose = re.compile(rf"(^|[._-]){re.escape(sample_id)}([._-]|$)")
    hits = [b for b in bams if exact.search(b.name)] or [b for b in bams if loose.search(b.name)]
    if not hits:
        shown = [f"  {b.relative_to(input_dir)}" for b in bams[:20]]
        fail(f"No BAM file for {sample_id} in {input_dir}"
             + (f" (bam_suffix={suffix})" if suffix else ""),
             "BAM files found:" if shown else "No BAM files were found.", *shown,
             "Tip: the BAM file name must start with the ID followed by '.', '_' or '-'.")
    if len(hits) > 1:
        fail(f"Several BAM files match {sample_id}:", *[f"  {h.relative_to(input_dir)}" for h in hits],
             "Tip: set bam_suffix (for example bam_suffix=_marked.bam) to pick one.")
    bam = hits[0]
    if not (Path(str(bam) + ".bai").is_file() or bam.with_suffix(".bai").is_file()):
        fail(f"BAM index (.bai) not found for {bam}",
             "Tip: index the BAM (samtools index) in the alignment step.")
    return bam


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


def read_key_value(path):
    values = {}
    with open(path) as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            values[row["key"]] = row["value"]
    return values


def read_gene_list(path):
    genes = []
    with open(path, encoding="utf-8-sig") as fh:
        for line in fh:
            name = line.strip().split("\t")[0].split(",")[0].strip()
            if name and not name.startswith("#") and name.lower() not in ("gene", "symbol", "hugo_symbol"):
                genes.append(name)
    return list(dict.fromkeys(genes))


# ---------------------------------------------------------------- genome helpers
def chrom_key(name):
    c = str(name)
    c = c[3:] if c.lower().startswith("chr") else c
    if c.isdigit():
        return int(c)
    return {"X": 23, "Y": 24}.get(c.upper(), 1000)


def chrom_label(name):
    c = str(name)
    return c[3:] if c.lower().startswith("chr") else c


def weighted_median(values, weights):
    pairs = sorted(zip(values, weights))
    total = sum(w for _, w in pairs)
    if total <= 0:
        return None
    acc = 0.0
    for v, w in pairs:
        acc += w
        if acc >= total / 2:
            return v
    return pairs[-1][0]


def overlap(a0, a1, b0, b1):
    return max(0, min(a1, b1) - max(a0, b0))


def categorize(cn, baseline, amp_ratio):
    if cn is None or (isinstance(cn, float) and math.isnan(cn)):
        return "NA"
    cn = int(round(cn))
    if cn == 0:
        return "DEEPDEL"
    if cn < baseline:
        return "LOSS"
    if cn == baseline:
        return "NEUTRAL"
    if cn >= amp_ratio * baseline:
        return "AMP"
    return "GAIN"


def expected_log2(cn, purity, normal_cn=2.0):
    """Expected centred log2 ratio for an integer copy number at a given purity."""
    value = purity * cn + (1 - purity) * normal_cn
    return math.log2(value / normal_cn) if value > 0 else None


# ---------------------------------------------------------------- plotting
def plotting():
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    plt.rcParams.update({"font.size": 9, "axes.titlesize": 10, "axes.spines.top": False,
                         "axes.spines.right": False, "pdf.fonttype": 42})
    return plt


def save_figure(plt, fig, plot_dir, name):
    fig.savefig(plot_dir / f"{name}.pdf", bbox_inches="tight")
    fig.savefig(plot_dir / f"{name}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)


class GenomeLayout:
    """Cumulative x positions for chromosomes 1-22, X, Y in natural order."""

    def __init__(self, bins):
        lengths = bins.groupby("chromosome")["end"].max()
        names = sorted([c for c in lengths.index if chrom_key(c) < 1000], key=chrom_key)
        self.names = names
        self.length = {c: int(lengths[c]) for c in names}
        self.offset, acc = {}, 0
        for c in names:
            self.offset[c] = acc
            acc += self.length[c]
        self.total = acc

    def x(self, chrom, pos):
        return self.offset[chrom] + pos

    def frame(self, ax):
        for i, c in enumerate(self.names):
            if i % 2:
                ax.axvspan(self.offset[c], self.offset[c] + self.length[c], color="#F3F3F3", lw=0, zorder=0)
        ax.set_xlim(0, self.total)
        ax.set_xticks([self.offset[c] + self.length[c] / 2 for c in self.names])
        ax.set_xticklabels([chrom_label(c) for c in self.names], fontsize=7)
        ax.tick_params(axis="x", length=0)


def y_limits(values_bins, values_segs):
    import numpy as np
    lo = min(np.nanpercentile(values_bins, 0.5) if len(values_bins) else -1, np.nanmin(values_segs) if len(values_segs) else -1)
    hi = max(np.nanpercentile(values_bins, 99.5) if len(values_bins) else 1, np.nanmax(values_segs) if len(values_segs) else 1)
    lo = -5.3 if lo < -5.0 else lo - 0.3
    return lo, max(hi + 0.4, 1.0)


def draw_bins_and_segments(ax, bins_x, bins_y, segs, seg_x0, seg_x1, ylim, point_size=1.5):
    import numpy as np
    y = np.clip(bins_y, ylim[0], ylim[1])
    clipped = (bins_y < ylim[0]) | (bins_y > ylim[1])
    ax.scatter(bins_x[~clipped], y[~clipped], s=point_size, c="#9A9A9A", alpha=0.35, lw=0, rasterized=True)
    if clipped.any():
        ax.scatter(bins_x[clipped], y[clipped], s=point_size * 4, c="#555555", marker="^", alpha=0.6, lw=0,
                   rasterized=True)
    for x0, x1, v, cat in zip(seg_x0, seg_x1, segs["log2_centered"], segs["category"]):
        ax.plot([x0, x1], [np.clip(v, ylim[0] + 0.12, ylim[1] - 0.05)] * 2,
                color=CATEGORY_COLORS.get(cat, "#000000"), lw=2.4, solid_capstyle="butt", zorder=3)
    ax.axhline(0, color="#444444", lw=0.6, zorder=2)
    ax.set_ylim(*ylim)


def add_cn_axis(ax, purity, ylim):
    """Secondary y axis with integer copy numbers (purity-adjusted)."""
    ticks, labels = [], []
    for cn in range(0, 9):
        v = expected_log2(cn, purity)
        if v is None:
            v = ylim[0] + 0.12
        if ylim[0] <= v <= ylim[1] and (not ticks or v - ticks[-1] >= 0.12):
            ticks.append(v)
            labels.append(str(cn))
    sec = ax.twinx()
    sec.set_ylim(*ylim)
    sec.set_yticks(ticks)
    sec.set_yticklabels(labels, fontsize=7)
    sec.set_ylabel("Copy number", fontsize=8)
    sec.spines["top"].set_visible(False)


def draw_baseline(ax, baseline, purity):
    """Dashed line at the ploidy baseline when it is not 2 copies."""
    if purity and baseline != 2:
        v = expected_log2(baseline, purity)
        ax.axhline(v, color="#555555", lw=0.8, ls="--", zorder=2)
        ax.text(0.002, v, f" baseline CN {baseline} (ploidy)", transform=ax.get_yaxis_transform(),
                va="bottom", ha="left", fontsize=6.5, color="#333333")


def place_labels(ax, items, xspan, ylim):
    """Gene labels above (or below) their segment, stacked when they are close."""
    placed = []
    for x, y, name in sorted(items):
        y = min(max(y, ylim[0] + 0.12), ylim[1])
        level = 0
        while any(abs(x - px) < xspan * 0.03 and pl == level for px, pl in placed):
            level += 1
        placed.append((x, level))
        up = y < ylim[1] - 0.6
        dy = (9 + 9 * level) * (1 if up else -1)
        ax.annotate(name, (x, y), xytext=(0, dy), textcoords="offset points", ha="center",
                    va="bottom" if up else "top", fontsize=6.5, color="#111111", style="italic",
                    arrowprops=dict(arrowstyle="-", lw=0.4, color="#666666"))


def category_legend(ax, loc="upper right"):
    from matplotlib.lines import Line2D
    handles = [Line2D([0], [0], color=CATEGORY_COLORS[c], lw=3, label=c) for c in CATEGORIES]
    ax.legend(handles=handles, loc=loc, ncol=5, fontsize=7, frameon=False, bbox_to_anchor=(1, 1.13))


def make_plots(sample, bins, segs, genes, gene_set, purity, plot_dir, reference_cnn, baseline=2):
    import numpy as np
    import pandas as pd
    plt = plotting()
    layout = GenomeLayout(bins)
    bins = bins[bins["chromosome"].isin(layout.names)].copy()
    segs = segs[segs["chromosome"].isin(layout.names)].copy()
    bins["x"] = [layout.x(c, (s + e) / 2) for c, s, e in zip(bins["chromosome"], bins["start"], bins["end"])]
    segs["x0"] = [layout.x(c, s) for c, s in zip(segs["chromosome"], segs["start"])]
    segs["x1"] = [layout.x(c, e) for c, e in zip(segs["chromosome"], segs["end"])]
    shown = bins.sample(n=300000, random_state=1) if len(bins) > 300000 else bins
    ylim = y_limits(shown["log2_centered"].to_numpy(), segs["log2_centered"].to_numpy())
    title_extra = f"   purity {purity:.2f}" if purity else "   no purity correction"

    # Genes to label: genes of interest, else the strongest AMP and DEEPDEL genes.
    labelled = genes[genes["Gene"].isin(gene_set)] if gene_set else pd.DataFrame()
    if labelled.empty and not genes.empty:
        strong = genes[genes["Call"].isin(["AMP", "DEEPDEL"])].copy()
        strong["abs"] = strong["Log2"].abs()
        labelled = strong.sort_values("abs", ascending=False).head(12)

    # 1. Genome profile.
    fig, ax = plt.subplots(figsize=(14, 4.2))
    layout.frame(ax)
    draw_bins_and_segments(ax, shown["x"].to_numpy(), shown["log2_centered"].to_numpy(), segs,
                           segs["x0"].to_numpy(), segs["x1"].to_numpy(), ylim)
    place_labels(ax, [(layout.x(g["Chromosome"], (g["Start"] + g["End"]) / 2), g["Log2"], g["Gene"])
                      for _, g in labelled.iterrows() if g["Chromosome"] in layout.offset and pd.notna(g["Log2"])],
                 layout.total, ylim)
    draw_baseline(ax, baseline, purity)
    ax.set_ylabel("Copy ratio (log2, centred)")
    ax.set_title(f"{sample}   genome-wide copy number{title_extra}", loc="left")
    category_legend(ax)
    if purity:
        add_cn_axis(ax, purity, ylim)
    save_figure(plt, fig, plot_dir, f"{sample}.genome_profile")

    # 2. Chromosomes: one page per chromosome in the PDF, grid in the PNG.
    from matplotlib.backends.backend_pdf import PdfPages
    with PdfPages(plot_dir / f"{sample}.chromosomes.pdf") as pdf:
        for c in layout.names:
            b = bins[bins["chromosome"] == c]
            s = segs[segs["chromosome"] == c]
            if b.empty:
                continue
            fig, ax = plt.subplots(figsize=(11, 3.6))
            draw_bins_and_segments(ax, ((b["start"] + b["end"]) / 2 / 1e6).to_numpy(), b["log2_centered"].to_numpy(),
                                   s, (s["start"] / 1e6).to_numpy(), (s["end"] / 1e6).to_numpy(), ylim, 3)
            gl = genes[(genes["Chromosome"] == c) & (genes["Call"].isin(["AMP", "DEEPDEL"]) |
                                                     genes["Gene"].isin(gene_set or []))]
            place_labels(ax, [((g["Start"] + g["End"]) / 2 / 1e6, g["Log2"], g["Gene"])
                              for _, g in gl.head(25).iterrows() if pd.notna(g["Log2"])],
                         layout.length[c] / 1e6, ylim)
            draw_baseline(ax, baseline, purity)
            ax.set_xlim(0, layout.length[c] / 1e6)
            ax.set_xlabel(f"chr{chrom_label(c)} position (Mb)")
            ax.set_ylabel("Copy ratio (log2)")
            ax.set_title(f"{sample}   chr{chrom_label(c)}", loc="left")
            if purity:
                add_cn_axis(ax, purity, ylim)
            pdf.savefig(fig, bbox_inches="tight")
            plt.close(fig)
    ncol = 6
    nrow = math.ceil(len(layout.names) / ncol)
    fig, axes = plt.subplots(nrow, ncol, figsize=(18, 2.4 * nrow), squeeze=False)
    for ax, c in zip(axes.flat, layout.names):
        b = bins[bins["chromosome"] == c]
        s = segs[segs["chromosome"] == c]
        draw_bins_and_segments(ax, ((b["start"] + b["end"]) / 2 / 1e6).to_numpy(), b["log2_centered"].to_numpy(),
                               s, (s["start"] / 1e6).to_numpy(), (s["end"] / 1e6).to_numpy(), ylim, 1)
        ax.set_xlim(0, layout.length[c] / 1e6)
        ax.set_title(f"chr{chrom_label(c)}", loc="left", fontsize=8)
        ax.tick_params(labelsize=6)
    for ax in list(axes.flat)[len(layout.names):]:
        ax.axis("off")
    fig.suptitle(f"{sample}   chromosomes (x: Mb, y: log2 copy ratio)", x=0.01, ha="left")
    fig.tight_layout()
    save_figure(plt, fig, plot_dir, f"{sample}.chromosomes_grid")
    # The PNG of the chromosome pages is the grid.
    (plot_dir / f"{sample}.chromosomes_grid.png").replace(plot_dir / f"{sample}.chromosomes.png")
    (plot_dir / f"{sample}.chromosomes_grid.pdf").unlink()

    # 3. Chromosome diagram: each chromosome as a bar coloured by segment category.
    fig, ax = plt.subplots(figsize=(10, 0.32 * len(layout.names) + 1.2))
    longest = max(layout.length.values())
    for i, c in enumerate(layout.names):
        y = len(layout.names) - i
        ax.add_patch(plt.Rectangle((0, y - 0.32), layout.length[c] / 1e6, 0.64, fc="#EEEEEE", ec="#999999", lw=0.5))
        for _, s in segs[segs["chromosome"] == c].iterrows():
            if s["category"] != "NEUTRAL":
                ax.add_patch(plt.Rectangle((s["start"] / 1e6, y - 0.32), (s["end"] - s["start"]) / 1e6, 0.64,
                                           fc=CATEGORY_COLORS.get(s["category"], "#000000"), lw=0))
        ax.text(-longest / 1e6 * 0.01, y, f"chr{chrom_label(c)}", ha="right", va="center", fontsize=7)
    ax.set_xlim(-longest / 1e6 * 0.06, longest / 1e6 * 1.01)
    ax.set_ylim(0.3, len(layout.names) + 0.8)
    ax.set_yticks([])
    ax.spines["left"].set_visible(False)
    ax.set_xlabel("Position (Mb)")
    ax.set_title(f"{sample}   altered segments by chromosome", loc="left")
    category_legend(ax)
    save_figure(plt, fig, plot_dir, f"{sample}.chromosome_diagram")

    # 4. Focal gene panels.
    focus = labelled.head(12)
    if not focus.empty:
        ncol = 3
        nrow = math.ceil(len(focus) / ncol)
        fig, axes = plt.subplots(nrow, ncol, figsize=(13, 2.9 * nrow), squeeze=False)
        for ax, (_, g) in zip(axes.flat, focus.iterrows()):
            c, g0, g1 = g["Chromosome"], g["Start"], g["End"]
            w0, w1 = max(0, g0 - 2_000_000), g1 + 2_000_000
            b = bins[(bins["chromosome"] == c) & (bins["end"] > w0) & (bins["start"] < w1)]
            s = segs[(segs["chromosome"] == c) & (segs["end"] > w0) & (segs["start"] < w1)]
            ax.axvspan(g0 / 1e6, g1 / 1e6, color="#FFE08A", alpha=0.6, lw=0, zorder=0)
            local = y_limits(b["log2_centered"].to_numpy(), s["log2_centered"].to_numpy()) if len(b) else ylim
            local = (min(local[0], -1.0), max(local[1], 1.0))
            draw_bins_and_segments(ax, ((b["start"] + b["end"]) / 2 / 1e6).to_numpy(), b["log2_centered"].to_numpy(),
                                   s, (np.maximum(s["start"], w0) / 1e6).to_numpy(),
                                   (np.minimum(s["end"], w1) / 1e6).to_numpy(), local, 6)
            draw_baseline(ax, baseline, purity)
            ax.set_xlim(w0 / 1e6, w1 / 1e6)
            cn = "NA" if pd.isna(g["CN"]) else int(g["CN"])
            loh = "  LOH" if g.get("LOH") == "yes" else ""
            ax.set_title(f"{g['Gene']}  chr{chrom_label(c)}  CN {cn}  {g['Call']}{loh}", loc="left", fontsize=8)
            ax.tick_params(labelsize=6)
        for ax in list(axes.flat)[len(focus):]:
            ax.axis("off")
        fig.suptitle(f"{sample}   genes of interest (gene shaded, +/- 2 Mb; x: Mb, y: log2)", x=0.01, ha="left")
        fig.tight_layout()
        save_figure(plt, fig, plot_dir, f"{sample}.focal_genes")

    # 5. Copy-number state histogram (length-weighted segment log2).
    fig, ax = plt.subplots(figsize=(7, 3.6))
    widths = (segs["end"] - segs["start"]).to_numpy() / 1e6
    ax.hist(np.clip(segs["log2_centered"], ylim[0], ylim[1]), bins=120, weights=widths, color="#5A5A5A")
    if purity:
        for cn in range(0, 9):
            v = expected_log2(cn, purity)
            if v is not None and ylim[0] <= v <= ylim[1]:
                ax.axvline(v, color="#D55E00", lw=0.8, ls="--")
                ax.text(v, ax.get_ylim()[1] * 0.97, str(cn), color="#D55E00", ha="center", va="top", fontsize=7)
    ax.set_xlabel("Segment copy ratio (log2, centred)")
    ax.set_ylabel("Genome length (Mb)")
    ax.set_title(f"{sample}   segment levels" + ("   (dashed: expected integer copy numbers)" if purity else ""),
                 loc="left")
    save_figure(plt, fig, plot_dir, f"{sample}.cn_state_hist")

    # 6. QC: depth, GC bias, residual noise.
    fig, axes = plt.subplots(1, 3, figsize=(14, 3.6))
    if "depth" in bins:
        anti = bins["gene"].eq("Antitarget") if "gene" in bins else pd.Series(False, index=bins.index)
        for mask, label, color in ((~anti, "target bins", "#4D4D4D"), (anti, "off-target bins", "#56B4E9")):
            d = bins.loc[mask & (bins["depth"] > 0), "depth"].to_numpy()
            if len(d):
                axes[0].hist(np.log10(d), bins=80, color=color, alpha=0.85, label=label)
        axes[0].legend(fontsize=7, frameon=False)
    axes[0].set_xlabel("Bin read depth (log10)")
    axes[0].set_ylabel("Bins")
    axes[0].set_title("Coverage", loc="left")
    try:
        ref = pd.read_csv(reference_cnn, sep="\t", usecols=["chromosome", "start", "end", "gc"])
        merged = bins.merge(ref, on=["chromosome", "start", "end"], how="inner")
        merged = merged.sample(n=60000, random_state=1) if len(merged) > 60000 else merged
        axes[1].scatter(merged["gc"], merged["log2_centered"], s=1, alpha=0.2, c="#4D4D4D", lw=0, rasterized=True)
        q = merged.groupby(pd.cut(merged["gc"], 20), observed=True)["log2_centered"].median()
        axes[1].plot([iv.mid for iv in q.index], q.to_numpy(), color="#D55E00", lw=1.5)
        axes[1].set_ylim(-2, 2.5)
    except (ValueError, KeyError):
        axes[1].text(0.5, 0.5, "GC content not available", ha="center", transform=axes[1].transAxes)
    axes[1].set_xlabel("Bin GC fraction")
    axes[1].set_ylabel("log2 (centred)")
    axes[1].set_title("GC bias after correction (orange: median)", loc="left")
    resid = bins["residual"].dropna().to_numpy()
    axes[2].hist(np.clip(resid, -2, 2), bins=100, color="#4D4D4D")
    mad = 1.4826 * np.median(np.abs(resid - np.median(resid))) if len(resid) else float("nan")
    axes[2].set_xlabel("Bin log2 minus segment log2 (clipped at +/-2)")
    axes[2].set_title(f"Noise: MAD {mad:.3f}", loc="left")
    fig.suptitle(f"{sample}   quality control", x=0.01, ha="left")
    fig.tight_layout()
    save_figure(plt, fig, plot_dir, f"{sample}.qc")
    return mad


# ---------------------------------------------------------------- per-sample analysis
def facets_inputs(facets_dir, sample):
    """(summary row or None, segment table path or None)."""
    if not facets_dir:
        return None, None
    summary = facets_dir / "04_summary" / "facets_summary.tsv"
    row = None
    with open(summary) as fh:
        for r in csv.DictReader(fh, delimiter="\t"):
            if r["SampleID"] == sample:
                row = r
    seg = facets_dir / "02_segments" / f"{sample}.facets_segments.tsv"
    return row, (seg if seg.exists() else None)


def diploid_level(cns, facets_segs):
    """Length-weighted median CNVkit segment log2 over FACETS 2/1 regions
    (fallback: total copy number 2). Returns (level, fraction of length used, rule)."""
    for rule, test in (("tcn=2,lcn=1", lambda r: r["tcn.em"] == "2" and r["lcn.em"] == "1"),
                       ("tcn=2", lambda r: r["tcn.em"] == "2")):
        target = [r for r in facets_segs if test(r)]
        values, weights = [], []
        for _, s in cns.iterrows():
            for r in target:
                if chrom_label(r["chrom"]) == chrom_label(s["chromosome"]):
                    o = overlap(int(s["start"]), int(s["end"]), int(float(r["start"])), int(float(r["end"])))
                    if o > 0:
                        values.append(float(s["log2"]))
                        weights.append(o)
        total = float((cns["end"] - cns["start"]).sum())
        if values and sum(weights) / total >= 0.02:
            return weighted_median(values, weights), sum(weights) / total, rule
    return None, 0.0, ""


def gene_table(cnr, call_cns, baseline_for, amp_ratio, facets_segs):
    import pandas as pd
    t = cnr[~cnr["gene"].isin(["-", "Antitarget", ""])].copy()
    t = t.assign(Gene=t["gene"].str.split(",")).explode("Gene")
    t["Gene"] = t["Gene"].str.strip()
    t = t[t["Gene"].ne("") & t["Gene"].ne("-")]
    if t.empty:
        return pd.DataFrame(columns=["Gene", "Chromosome", "Start", "End", "Bins", "Log2", "CN", "Call"])
    g = t.groupby(["Gene", "chromosome"]).agg(Start=("start", "min"), End=("end", "max"),
                                              Bins=("start", "size")).reset_index()
    g = g.rename(columns={"chromosome": "Chromosome"})
    by_chrom = {c: d for c, d in call_cns.groupby("chromosome")}
    log2s, cns_, calls = [], [], []
    for _, row in g.iterrows():
        segs = by_chrom.get(row["Chromosome"])
        best, best_o = None, 0
        if segs is not None:
            for _, s in segs.iterrows():
                o = overlap(row["Start"], row["End"], s["start"], s["end"])
                if o > best_o:
                    best, best_o = s, o
        if best is None:
            log2s.append(float("nan"))
            cns_.append(float("nan"))
            calls.append("NA")
        else:
            log2s.append(round(float(best["log2_centered"]), 4))
            cns_.append(best["cn"])
            calls.append(categorize(best["cn"], baseline_for(row["Chromosome"]), amp_ratio))
    g["Log2"], g["CN"], g["Call"] = log2s, pd.array([None if pd.isna(v) else int(v) for v in cns_], dtype="Int64"), calls
    if facets_segs is not None:
        tcn, lcn, loh = [], [], []
        for _, row in g.iterrows():
            mid = (row["Start"] + row["End"]) / 2
            hit = next((r for r in facets_segs if chrom_label(r["chrom"]) == chrom_label(row["Chromosome"])
                        and float(r["start"]) <= mid <= float(r["end"])), None)
            tcn.append(hit["tcn.em"] if hit else "NA")
            lcn.append(hit["lcn.em"] if hit else "NA")
            loh.append("yes" if hit and hit["lcn.em"] == "0" and hit["tcn.em"] not in ("0", "NA") else
                       ("no" if hit and hit["lcn.em"] not in ("NA", "") else "NA"))
        g["FACETS_TCN"], g["FACETS_LCN"], g["LOH"] = tcn, lcn, loh
    g["_key"] = g["Chromosome"].map(chrom_key)
    return g.sort_values(["_key", "Start"]).drop(columns="_key")


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    reference_dir = Path(params["reference_dir"])
    facets_dir = Path(params["facets_dir"]) if params["facets_dir"] else None
    for name, d in (("input_dir", input_dir), ("reference_dir", reference_dir), ("facets_dir", facets_dir)):
        if d is not None and not d.is_dir():
            fail(f"{name} not found: {d}")
    sample_data = Path(params["sample_data"])
    if not sample_data.is_file():
        fail(f"sample_data not found: {sample_data}")
    ref_cnn = reference_dir / "01_reference" / "reference.cnn"
    ref_info_path = reference_dir / "04_metadata" / "reference_info.tsv"
    if not ref_cnn.is_file() or not ref_info_path.is_file():
        fail(f"reference_dir does not hold a CNVkit reference: {reference_dir}",
             "Expected: 01_reference/reference.cnn and 04_metadata/reference_info.tsv")
    ref_info = read_key_value(ref_info_path)
    method = ref_info.get("seq_method", "hybrid")
    if facets_dir and not (facets_dir / "04_summary" / "facets_summary.tsv").is_file():
        fail(f"facets_dir does not hold FACETS results: {facets_dir}",
             "Expected: 04_summary/facets_summary.tsv and 02_segments/<SampleID>.facets_segments.tsv")
    genes_path = Path(params["genes"]) if params["genes"] else None
    if genes_path and not genes_path.is_file():
        fail(f"genes file not found: {genes_path}")
    if params["segment_method"] not in ("cbs", "hmm", "haar"):
        fail(f"segment_method must be cbs, hmm, or haar: {params['segment_method']}")
    try:
        amp_ratio = float(params["amp_ratio"])
        assert amp_ratio > 1
    except (ValueError, AssertionError):
        fail(f"amp_ratio must be a number greater than 1: {params['amp_ratio']}")
    threads, allocated = resolve_threads(params["threads"])
    check_outside(output_dir, input_dir, sample_data, reference_dir, facets_dir, genes_path)

    samples = read_sample_sheet(sample_data)
    bams = list_bams(input_dir, params["bam_suffix"])
    tumor_bams = {s["SampleID"]: find_bam(bams, s["SampleID"], input_dir, params["bam_suffix"]) for s in samples}
    gene_set = read_gene_list(genes_path) if genes_path else []

    clean_output(output_dir)
    stamp = start_logs(output_dir)
    d_raw, d_calls, d_genes, d_plots, d_sum = (output_dir / d for d in
                                               ("01_cnvkit", "02_calls", "03_genes", "04_plots", "05_summary"))
    for d in (d_raw, d_calls, d_genes, d_plots, d_sum):
        d.mkdir()

    import numpy as np
    import pandas as pd

    info(f"############################## {MODULE}")
    info(f"Log files: logs/{stamp}.log (stdout), logs/{stamp}.error.log (stderr)")
    info(f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    info("")
    info("parameters:")
    for key in REQUIRED + list(OPTIONAL):
        if key == "threads":
            info(f"  threads        = {threads} (requested {params['threads']}, allocated {allocated})")
        else:
            info(f"  {key:14s} = {params[key]}")
    info(f"  reference      = {ref_info.get('reference_type', '?')} ({method}; normals: {ref_info.get('normals') or 'none'})")
    info(f"  genes of interest = {len(gene_set)}")
    info("")

    summary_rows, all_seg = [], []
    for s in samples:
        sid, sex = s["SampleID"], s["Sex"]
        info(f"############################## Processing sample: {sid}")
        row = {"SampleID": sid, "Status": "ok", "Sex": sex or "inferred", "Reference": ref_info.get("reference_type", ""),
               "Purity": "NA", "FACETS_Ploidy": "NA", "FACETS_Status": "none", "CenterAt": "0", "Recentered": "no",
               "CallMethod": "threshold", "Baseline": 2, "Bins": 0, "Segments": 0, "Noise_MAD": "NA", "FGA": "NA",
               "AMP_genes": 0, "DEEPDEL_genes": 0, "Concordance_FACETS": "NA", "Note": ""}
        work = d_raw / sid
        work.mkdir()
        bam = tumor_bams[sid]
        code, _ = run(["cnvkit.py", "batch", bam, "-r", ref_cnn, "-m", method, "-p", threads,
                       "--drop-low-coverage", "--segment-method", params["segment_method"], "-d", work],
                      f"cnvkit.py batch ({sid})", threads)
        stem = bam.name[:-4]
        cnr_path, cns_path = work / f"{stem}.cnr", work / f"{stem}.cns"
        if code != 0 or not cnr_path.exists() or not cns_path.exists():
            row["Status"], row["Note"] = "failed", "cnvkit batch failed"
            summary_rows.append(row)
            continue
        shutil.copyfile(cnr_path, d_calls / f"{sid}.cnr")
        shutil.copyfile(cns_path, d_calls / f"{sid}.cns")
        cnr = pd.read_csv(cnr_path, sep="\t")
        cns = pd.read_csv(cns_path, sep="\t")

        if not sex:
            code, out = run(["cnvkit.py", "sex", cnr_path], f"cnvkit.py sex ({sid})", capture=True)
            lines = [line.split("\t") for line in out.strip().splitlines()[1:]]
            sex = lines[0][1].strip().lower() if code == 0 and lines and len(lines[0]) > 1 else ""
            sex = sex if sex in ("female", "male") else ""
            row["Sex"] = f"{sex} (inferred)" if sex else "unknown"

        # Purity and diploid level from FACETS.
        frow, fseg_path = facets_inputs(facets_dir, sid)
        facets_segs = None
        center, purity = 0.0, None
        if frow is not None:
            row["FACETS_Status"] = frow["Status"]
            row["FACETS_Ploidy"] = frow["Ploidy"]
        if frow is not None and frow["Status"] == "ok" and fseg_path:
            with open(fseg_path) as fh:
                facets_segs = list(csv.DictReader(fh, delimiter="\t"))
            level, frac, rule = diploid_level(cns, facets_segs)
            if level is not None:
                center, purity = level, float(frow["Purity"])
                row.update({"Purity": f"{purity:.4f}", "CenterAt": f"{center:.4f}", "Recentered": "yes",
                            "CallMethod": "clonal"})
                info(f"  FACETS: purity {purity:.3f}, ploidy {frow['Ploidy']}; diploid level {center:.4f} "
                     f"from {rule} regions ({frac:.1%} of the segment length)")
            else:
                warn(f"{sid}: FACETS has no diploid (total copy number 2) region overlapping the CNVkit segments;",
                     "  copy ratios are not recentred and copy numbers assume a diploid median.")
                row["Note"] = "FACETS without diploid regions"
        elif frow is not None:
            warn(f"{sid}: FACETS status {frow['Status']}; no purity correction for this sample.")
            row["Note"] = f"FACETS {frow['Status']}"
        elif facets_dir:
            warn(f"{sid}: not in the FACETS results (tumor-only or not run); no purity correction.")
        call_path = d_calls / f"{sid}.call.cns"
        cmd = ["cnvkit.py", "call", cns_path, "-o", call_path]
        if purity:
            cmd += ["--center-at", f"{center:.6f}", "-m", "clonal", "--purity", f"{purity:.6f}"]
        else:
            cmd += ["-m", "threshold"]
        if sex:
            cmd += ["--sample-sex", sex]
        code, _ = run(cmd, f"cnvkit.py call ({sid})")
        if code != 0 or not call_path.exists():
            row["Status"], row["Note"] = "failed", "cnvkit call failed"
            summary_rows.append(row)
            continue
        call = pd.read_csv(call_path, sep="\t")
        # Centred log2 (before purity rescaling) for plots, genes and SEG.
        cns["log2_centered"] = cns["log2"] - center
        call["log2_centered"] = call.merge(cns[["chromosome", "start", "end", "log2_centered"]],
                                           on=["chromosome", "start", "end"], how="left")["log2_centered"].to_numpy()
        call["log2_centered"] = call["log2_centered"].fillna(call["log2"])
        cnr["log2_centered"] = cnr["log2"] - center

        try:
            ploidy = float(frow["Ploidy"]) if purity and frow is not None else None
        except (TypeError, ValueError):
            ploidy = None
        baseline = 4 if ploidy and ploidy >= 2.7 else 2
        row["Baseline"] = baseline
        male = sex == "male"

        def baseline_for(chrom, _b=baseline, _male=male):
            return max(1, _b // 2) if _male and chrom_label(chrom).upper() in ("X", "Y") else _b

        call["category"] = [categorize(cn, baseline_for(c), amp_ratio) for cn, c in zip(call["cn"], call["chromosome"])]
        seg_table = call[["chromosome", "start", "end", "probes", "log2_centered", "cn", "category"]].copy()
        seg_table["log2_centered"] = seg_table["log2_centered"].round(4)
        seg_table.to_csv(d_calls / f"{sid}.segments.tsv", sep="\t", index=False)

        # Bin residuals against their segment (noise).
        cnr["residual"] = np.nan
        seg_by_chrom = {c: d.sort_values("start") for c, d in call.groupby("chromosome")}
        for c, d in cnr.groupby("chromosome"):
            segs_c = seg_by_chrom.get(c)
            if segs_c is None:
                continue
            starts, ends = segs_c["start"].to_numpy(), segs_c["end"].to_numpy()
            levels = segs_c["log2_centered"].to_numpy()
            idx = np.clip(np.searchsorted(starts, d["start"].to_numpy(), side="right") - 1, 0, None)
            inside = d["start"].to_numpy() < ends[idx]
            cnr.loc[d.index, "residual"] = np.where(inside, d["log2_centered"].to_numpy() - levels[idx], np.nan)

        genes = gene_table(cnr, call, baseline_for, amp_ratio, facets_segs)
        genes.to_csv(d_genes / f"{sid}.genes.tsv", sep="\t", index=False)

        seg = call[["chromosome", "start", "end", "probes", "log2_centered"]].copy()
        seg.insert(0, "ID", sid)
        seg.columns = ["ID", "chrom", "loc.start", "loc.end", "num.mark", "seg.mean"]
        seg["seg.mean"] = seg["seg.mean"].round(4)
        seg.to_csv(d_calls / f"{sid}.seg", sep="\t", index=False)
        all_seg.append(seg)

        length = (call["end"] - call["start"]).astype(float)
        auto = call["chromosome"].map(lambda c: chrom_key(c) <= 22)
        row["Bins"] = len(cnr)
        row["Segments"] = len(call)
        row["FGA"] = f"{(length[auto & (call['category'] != 'NEUTRAL')].sum() / length[auto].sum()):.4f}" \
            if length[auto].sum() > 0 else "NA"
        row["AMP_genes"] = int((genes["Call"] == "AMP").sum()) if not genes.empty else 0
        row["DEEPDEL_genes"] = int((genes["Call"] == "DEEPDEL").sum()) if not genes.empty else 0
        if facets_segs:
            agree = tot = 0.0
            for _, sgm in call.iterrows():
                for r in facets_segs:
                    if chrom_label(r["chrom"]) == chrom_label(sgm["chromosome"]) and r["tcn.em"] not in ("NA", ""):
                        o = overlap(int(sgm["start"]), int(sgm["end"]), int(float(r["start"])), int(float(r["end"])))
                        if o:
                            tot += o
                            agree += o * (int(sgm["cn"]) == int(float(r["tcn.em"])))
            row["Concordance_FACETS"] = f"{agree / tot:.4f}" if tot else "NA"

        try:
            mad = make_plots(sid, cnr, call, genes, gene_set, purity, d_plots, ref_cnn, baseline)
            row["Noise_MAD"] = f"{mad:.4f}"
        except Exception as exc:  # plots must not lose the calls
            warn(f"{sid}: plotting failed: {exc}")
            row["Note"] = (row["Note"] + "; " if row["Note"] else "") + "plots failed"
        info(f"  bins={row['Bins']} segments={row['Segments']} FGA={row['FGA']} AMP genes={row['AMP_genes']} "
             f"DEEPDEL genes={row['DEEPDEL_genes']} MAD={row['Noise_MAD']} concordance with FACETS={row['Concordance_FACETS']}")
        summary_rows.append(row)

    fields = list(summary_rows[0].keys()) if summary_rows else ["SampleID", "Status"]
    with open(d_sum / "cnvkit_summary.tsv", "w", newline="") as fh:
        w = csv.DictWriter(fh, fields, delimiter="\t")
        w.writeheader()
        w.writerows(summary_rows)
    if all_seg:
        pd.concat(all_seg).to_csv(d_sum / "all_samples.seg", sep="\t", index=False)

    failed = [r["SampleID"] for r in summary_rows if r["Status"] == "failed"]
    info("")
    info("############################## Summary")
    info(f"Samples: {len(summary_rows)}, done: {len(summary_rows) - len(failed)}, failed: {len(failed)}")
    info(f"Recentred with FACETS: {sum(r['Recentered'] == 'yes' for r in summary_rows)}")
    info("")
    info("############################## Done")
    info(f"Summary: {d_sum / 'cnvkit_summary.tsv'}")
    info(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    if len(failed) == len(summary_rows):
        fail("all samples failed: " + ", ".join(failed))
    if failed:
        warn("some samples failed: " + ", ".join(failed) + f". Check {d_sum / 'cnvkit_summary.tsv'}")


if __name__ == "__main__":
    main()
