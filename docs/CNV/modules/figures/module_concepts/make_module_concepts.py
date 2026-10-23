#!/usr/bin/env python3
"""Concept figures for the CNV modules, one drawing per module, in the style of the
ATAC-seq module concepts (drawing helpers imported from there).

Run: python3 docs/CNV/modules/figures/module_concepts/make_module_concepts.py, then
for f in docs/CNV/modules/figures/module_concepts/*.svg; do rsvg-convert -w 1600 "$f" -o "${f%.svg}.png"; done
Values in the drawings are schematic, not data. Colours follow the module plots.
"""
import random
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parents[3] / "ATAC-seq" / "modules" / "figures" / "module_concepts"))
from make_module_concepts import (MAIN, SUB, POINT, TINT, GRAY, PALE, t, panel, line, rect, arrow,  # noqa: E402
                                  poly, axes, svg, table, legend)

AMP, GAIN, NEUTRAL, LOSS, DEEPDEL, LOH = "#B2182B", "#EF8A62", "#7F7F7F", "#67A9CF", "#2166AC", "#CC79A7"
CALL = {"AMP": AMP, "GAIN": GAIN, "NEUTRAL": NEUTRAL, "LOSS": LOSS, "DEEPDEL": DEEPDEL}


def cnvkit_reference():
    g = [panel(40, "A", "Bins from the capture targets")]
    y = 250
    g.append(line(60, y, 500, y, SUB, 4))
    for x0 in (90, 200, 330, 420):
        g.append(rect(x0, y - 18, 40, 36, POINT, 4))
    for x0 in (140, 250, 370):
        g.append(rect(x0, y - 9, 50 if x0 != 250 else 70, 18, GRAY, 3))
    g.append(legend(70, 330, [("box", POINT, "target bins (exons, targets_bed)"),
                              ("box", GRAY, "antitarget (off-target) bins")]))
    g.append(t(70, 430, "hybrid: targets + antitargets", 15, 600, MAIN, "start"))
    g.append(t(70, 458, "wgs: bins over the whole genome", 15, 600, MAIN, "start"))
    g.append(t(70, 486, "amplicon: targets only", 15, 600, MAIN, "start"))
    g.append(t(70, 530, "Bins are labelled with gene names (annotation)", 14, 500, SUB, "start"))

    g.append(panel(560, "B", "Normal coverage → reference.cnn"))
    random.seed(3)
    for k, name in enumerate(("NORMAL01", "NORMAL02", "NORMAL03")):
        yy = 120 + k * 90
        g.append(t(580, yy + 25, name, 14, 700, SUB, "start"))
        for b in range(12):
            h = 18 + random.uniform(-6, 6) + (12 if b in (3, 4) else 0)
            g.append(rect(680 + b * 26, yy + 50 - h, 18, h, GRAY, 2))
    g.append(arrow(830, 395, 830, 440, SUB, 3))
    g.append(rect(600, 450, 440, 110, TINT, 10, POINT))
    g.append(t(820, 482, "reference.cnn", 18, 800, POINT))
    g.append(t(820, 512, "expected depth per bin (pooled normals),", 14, 600, MAIN))
    g.append(t(820, 536, "GC content and spread", 14, 600, MAIN))
    g.append(t(600, 590, "No normal (NormalID empty): flat reference", 14, 600, SUB, "start"))

    g.append(panel(1100, "C", "Normal QC"))
    rows = [("NORMAL01", "59,878", "0.31", "ok"), ("NORMAL02", "59,878", "0.29", "ok"), ("NORMAL03", "59,878", "0.62", "ok")]
    g.append(table(1100, 100, ["NormalID", "Bins", "MAD", "Status"], rows, [130, 100, 80, 80], {2: "#D6604D"}))
    g.append(t(1100, 250, "03_qc/normal_qc.tsv", 14, 600, SUB, "start"))
    g.append(t(1100, 300, "MAD: spread of each normal's bin log2", 14, 600, MAIN, "start"))
    g.append(t(1100, 324, "ratio against the reference", 14, 600, MAIN, "start"))
    g.append(t(1100, 364, "A normal much noisier than the others", 14, 600, "#D6604D", "start"))
    g.append(t(1100, 388, "(red) is best left out of the reference", 14, 600, "#D6604D", "start"))
    g.append(t(1100, 450, "Output folder = reference_dir of cnvkit_call", 14, 700, POINT, "start"))
    return svg("".join(g))


def cnv_facets():
    g = [panel(40, "A", "snp-pileup at common SNPs")]
    for k, (lab, ref_n, alt_n, col) in enumerate((("normal", 6, 6, SUB), ("tumor", 10, 2, MAIN))):
        x0 = 80 + k * 220
        g.append(t(x0 + 70, 100, lab, 17, 800, col))
        for r in range(ref_n + alt_n):
            alt = r >= ref_n
            g.append(rect(x0 + 10, 125 + r * 26, 120, 16, "#F2B134" if alt else GRAY, 3))
        g.append(line(x0 + 70, 115, x0 + 70, 125 + (ref_n + alt_n) * 26, POINT, 2, "5,4"))
    g.append(legend(80, 480, [("box", GRAY, "reference allele reads"), ("box", "#F2B134", "alternate allele reads")]))
    g.append(t(80, 560, "SNP sites from snp_vcf; normal depth ≥ ndepth", 14, 500, SUB, "start"))

    g.append(panel(560, "B", "Joint segmentation and EM fit"))
    random.seed(5)
    x0, w = 600, 440
    g.append(axes(x0, 90, w, 150, "", "log-ratio"))
    for seg, (a, b, v) in enumerate(((0, 0.4, 0.0), (0.4, 0.7, -0.6), (0.7, 1, 0.5))):
        for _ in range(40):
            xx = x0 + random.uniform(a, b) * w
            g.append(f'<circle cx="{xx:.1f}" cy="{165 - (v + random.gauss(0, 0.15)) * 90:.1f}" r="2.5" fill="{GRAY}"/>')
        g.append(line(x0 + a * w, 165 - v * 90, x0 + b * w, 165 - v * 90, "#D6604D", 4))
    g.append(axes(x0, 300, w, 150, "position", "log-odds-ratio"))
    for seg, (a, b, v) in enumerate(((0, 0.4, 0.0), (0.4, 0.7, 2.4), (0.7, 1, 1.0))):
        for _ in range(40):
            xx = x0 + random.uniform(a, b) * w
            s = random.choice((-1, 1))
            g.append(f'<circle cx="{xx:.1f}" cy="{375 - s * (v + random.gauss(0, 0.2)) * 25:.1f}" r="2.5" fill="{GRAY}"/>')
        g.append(line(x0 + a * w, 375 - v * 25, x0 + b * w, 375 - v * 25, "#D6604D", 3))
        g.append(line(x0 + a * w, 375 + v * 25, x0 + b * w, 375 + v * 25, "#D6604D", 3))
    g.append(t(600, 530, "→ purity, ploidy, and per segment", 15, 700, POINT, "start"))
    g.append(t(600, 556, "total (tcn) and minor (lcn) copy number", 15, 700, POINT, "start"))

    g.append(panel(1100, "C", "Purity, ploidy and LOH"))
    rows = [("TUMOR01", "ok", "0.97", "3.08", "yes"), ("TUMOR02", "low_purity", "0.12", "NA", "NA")]
    g.append(table(1100, 100, ["SampleID", "Status", "Purity", "Ploidy", "WGD"], rows, [110, 110, 70, 70, 60], {1: "#D6604D"}))
    g.append(t(1100, 220, "04_summary/facets_summary.tsv", 14, 600, SUB, "start"))
    rows = [("chr6", "94.1", "96.5", "0", "0"), ("chr17", "0.1", "22.0", "3", "0"), ("chr21", "5.0", "46.7", "2", "1")]
    g.append(table(1100, 260, ["chrom", "start", "end", "tcn", "lcn"], rows, [80, 80, 80, 60, 60], {1: LOH}))
    g.append(t(1100, 412, "02_segments/<SampleID>.facets_segments.tsv (Mb)", 14, 600, SUB, "start"))
    g.append(t(1100, 450, "lcn = 0: loss of heterozygosity (LOH)", 15, 700, LOH, "start"))
    g.append(t(1100, 480, "Low purity or failed fit: a status, exit 0", 14, 600, SUB, "start"))
    return svg("".join(g))


def cnvkit_call():
    g = [panel(40, "A", "Copy ratio and segments")]
    random.seed(7)
    x0, w, y0, h = 90, 400, 100, 300
    g.append(axes(x0, y0, w, h, "genome position", "Copy ratio (log2, centred)"))
    zero = y0 + 150
    g.append(line(x0, zero, x0 + w, zero, GRAY, 1.5, "4,4"))
    segs = ((0, 0.3, 0.5, "GAIN"), (0.3, 0.55, -0.28, "LOSS"), (0.55, 0.65, -2.2, "DEEPDEL"), (0.65, 1, -0.28, "LOSS"))
    for a, b, v, c in segs:
        for _ in range(45):
            xx = x0 + random.uniform(a, b) * w
            g.append(f'<circle cx="{xx:.1f}" cy="{zero - (v + random.gauss(0, 0.18)) * 55:.1f}" r="2.5" fill="{GRAY}" opacity="0.7"/>')
        g.append(line(x0 + a * w, zero - v * 55, x0 + b * w, zero - v * 55, CALL[c], 6))
    g.append(t(90, 480, "CNVkit: coverage → fix (reference, GC)", 15, 600, MAIN, "start"))
    g.append(t(90, 506, "→ segment (cbs) → call", 15, 600, MAIN, "start"))

    g.append(panel(560, "B", "Recentre on FACETS 2/1 and use purity"))
    x0, w = 620, 420
    g.append(axes(x0, 100, w, 300, "segment copy ratio (log2)", "genome length"))
    for k, (pos, hgt) in enumerate(((0.15, 120), (0.42, 200), (0.66, 150), (0.82, 90))):
        g.append(rect(x0 + pos * w - 12, 400 - hgt, 24, hgt, GRAY, 2))
    for k, (pos, lab) in enumerate(((0.15, "1"), (0.42, "2"), (0.66, "3"), (0.82, "4"))):
        g.append(line(x0 + pos * w, 100, x0 + pos * w, 400, "#D6604D", 2, "6,5") + t(x0 + pos * w, 90, lab, 14, 700, "#D6604D"))
    g.append(t(620, 470, "Centre: median log2 of the regions FACETS calls", 14, 600, MAIN, "start"))
    g.append(t(620, 494, "2/1 → integer copy numbers from purity", 14, 600, MAIN, "start"))
    g.append(t(620, 530, "Dashed: expected integer copy numbers (cn_state_hist)", 13, 500, SUB, "start"))
    g.append(t(620, 556, "Baseline copy number 4 when ploidy ≥ 2.7", 14, 700, POINT, "start"))

    g.append(panel(1100, "C", "Calls per gene"))
    rows = [("TP53", "3", "LOSS", "yes"), ("ERBB2", "2", "LOSS", "yes"), ("BRCA2", "5", "GAIN", "no"),
            ("RB1", "4", "NEUTRAL", "no"), ("CDKN2A", "0", "DEEPDEL", "no")]
    g.append(table(1100, 100, ["Gene", "CN", "Call", "LOH"], rows, [110, 60, 110, 70],
                   {0: LOSS, 1: LOSS, 2: GAIN, 3: NEUTRAL, 4: DEEPDEL}))
    g.append(t(1100, 315, "03_genes/<SampleID>.genes.tsv (baseline 4)", 14, 600, SUB, "start"))
    g.append(legend(1100, 350, [("box", AMP, "AMP  CN ≥ amp_ratio × baseline"), ("box", GAIN, "GAIN"),
                                ("box", NEUTRAL, "NEUTRAL  CN = baseline"), ("box", LOSS, "LOSS"),
                                ("box", DEEPDEL, "DEEPDEL  CN = 0")]))
    g.append(t(1100, 520, "Plots, SEG for IGV, cnvkit_summary.tsv", 14, 600, SUB, "start"))
    return svg("".join(g))


def cnv_summary():
    g = [panel(40, "A", "Gene × sample calls (oncoprint)")]
    random.seed(11)
    genes = ["TP53", "ERBB2", "MYC", "CDKN2A", "PTEN"]
    cats = ["LOSS", "AMP", "GAIN", "DEEPDEL", "LOSS"]
    for r, gname in enumerate(genes):
        g.append(t(130, 125 + r * 52, gname, 15, 700, MAIN, "end"))
        for c in range(6):
            cat = cats[r] if random.random() < 0.55 else "NEUTRAL"
            col = CALL[cat] if cat != "NEUTRAL" else "#F0F0F0"
            g.append(rect(145 + c * 52, 104 + r * 52, 44, 42, col, 3))
            if cat == "LOSS" and random.random() < 0.6:
                g.append(f'<circle cx="{167 + c * 52}" cy="{125 + r * 52}" r="6" fill="{LOH}" stroke="#fff" stroke-width="1.5"/>')
    for c in range(6):
        g.append(t(167 + c * 52, 385, f"T{c + 1}", 13, 600, SUB))
    g.append(t(70, 440, "01_tables/gene_calls.tsv, interest_genes.tsv", 14, 600, SUB, "start"))
    g.append(t(70, 470, "Pink dot: LOH (with facets_dir)", 14, 600, LOH, "start"))

    g.append(panel(560, "B", "Gain and loss frequency"))
    x0, w = 620, 440
    g.append(axes(x0, 100, w, 320, "genome position", "Samples (%)"))
    mid = 260
    g.append(line(x0, mid, x0 + w, mid, SUB, 1.5))
    for b in range(22):
        up = max(0, 70 * random.random() - (10 if b > 12 else 0))
        dn = max(0, 70 * random.random() - (10 if b < 8 else 0))
        g.append(rect(x0 + 6 + b * 19.5, mid - up * 1.8, 16, up * 1.8, GAIN, 1))
        g.append(rect(x0 + 6 + b * 19.5, mid, 16, dn * 1.8, LOSS, 1))
    g.append(t(x0 + w - 6, 112, "gain", 14, 700, GAIN, "end") + t(x0 + w - 6, 408, "loss", 14, 700, LOSS, "end"))
    g.append(t(620, 480, "Also: cohort heatmap, arm heatmap,", 14, 600, MAIN, "start"))
    g.append(t(620, 504, "sample similarity (2+ samples)", 14, 600, MAIN, "start"))

    g.append(panel(1100, "C", "Instability and report"))
    vals = [0.84, 0.62, 0.45, 0.31, 0.12]
    for k, v in enumerate(vals):
        g.append(rect(1130 + k * 60, 330 - v * 220, 42, v * 220, "#7B4F96", 2) + t(1151 + k * 60, 350, f"T{k + 1}", 13, 600, SUB))
    g.append(line(1120, 330, 1440, 330, SUB, 2) + t(1100, 100, "FGA (sorted)", 14, 700, SUB, "start"))
    g.append(rect(1100, 400, 400, 120, TINT, 10, POINT))
    g.append(t(1300, 432, "04_report/cnv_report.html", 16, 800, POINT))
    g.append(t(1300, 462, "all cohort and per-sample figures", 14, 600, MAIN))
    g.append(t(1300, 488, "02_seg: cohort.seg (IGV), GISTIC2 input", 14, 600, MAIN))
    return svg("".join(g))


FIGS = {"cnvkit_reference": cnvkit_reference, "cnv_facets": cnv_facets, "cnvkit_call": cnvkit_call,
        "cnv_summary": cnv_summary}

if __name__ == "__main__":
    for name, fn in FIGS.items():
        p = OUT / f"{name}_concept.svg"
        p.write_text(fn())
        print(p)
