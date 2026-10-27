#!/usr/bin/env python3
"""Concept figures for the spatial transcriptomics modules, one drawing per module, in the
style of the ATAC-seq module concepts (drawing helpers imported from there).

Each figure is written to the module_concepts folder of the pipeline(s) using the module
(spatial_condition_de and check_reference to both).
Run: python3 docs/Spatial_Transcriptomics_Shared/figures/make_module_concepts.py, then
for f in docs/Spatial_Transcriptomics_Visium*_Pipeline/modules/figures/module_concepts/*.svg; do
    rsvg-convert -w 1600 "$f" -o "${f%.svg}.png"; done
Tissue shapes, clusters and values are schematic, not data.
"""
import math
import re
import random
import sys
from pathlib import Path

DOCS = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(DOCS / "ATAC-seq" / "modules" / "figures" / "module_concepts"))
VIS = DOCS / "Spatial_Transcriptomics_Visium_Pipeline" / "modules" / "figures" / "module_concepts"
HD = DOCS / "Spatial_Transcriptomics_Visium_HD_Pipeline" / "modules" / "figures" / "module_concepts"
from make_module_concepts import (MAIN, SUB, POINT, TINT, GRAY, PALE, t, panel, line, rect, arrow,  # noqa: E402
                                  axes, svg, table, legend)

TISSUE, EDGE = "#F3E6EC", "#B98AA0"
REG = ["#4E79A7", "#F28E2B", "#59A14F", "#E15759", "#B07AA1"]
RED, BLUE = "#B2182B", "#2166AC"
CT = ["#1B9E77", "#D95F02", "#7570B3", "#E7298A", "#66A61E"]   # cell types


def inside(x, y, cx, cy, rx, ry):
    e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
    notch = ((x - (cx + rx * 0.55)) / (rx * 0.35)) ** 2 + ((y - (cy - ry * 0.7)) / (ry * 0.45)) ** 2 <= 1
    return e and not notch


def region(x, y, cx, cy, rx, ry):
    d = math.hypot((x - cx) / rx, (y - cy) / ry)
    if math.hypot((x - cx - rx * 0.25) / (rx * 0.28), (y - cy - ry * 0.15) / (ry * 0.3)) < 1:
        return 3
    return 0 if d > 0.8 else 1 if d > 0.55 else 2


def tissue(cx, cy, rx, ry, color=None, step=20, r=7, square=False, pick=None):
    """Tissue with a spot (or square bin) grid; color(x, y, k) gives each spot's fill."""
    out = f'<ellipse cx="{cx}" cy="{cy}" rx="{rx + 10}" ry="{ry + 10}" fill="{TISSUE}" stroke="{EDGE}" stroke-width="2.5"/>'
    row, y, k = 0, cy - ry, 0
    while y <= cy + ry:
        x = cx - rx + (0 if square else (step / 2 if row % 2 else 0))
        while x <= cx + rx:
            if inside(x, y, cx, cy, rx, ry):
                fill = color(x, y, k) if color else "#C9CDD3"
                if fill:
                    if square:
                        out += f'<rect x="{x - r:.1f}" y="{y - r:.1f}" width="{2 * r - 1:.1f}" height="{2 * r - 1:.1f}" fill="{fill}"/>'
                    else:
                        out += f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{fill}"/>'
                k += 1
            x += step
        y += step * (1 if square else 0.866)
        row += 1
    return out


def by_region(cx, cy, rx, ry, cols=REG):
    return lambda x, y, k: cols[region(x, y, cx, cy, rx, ry) % len(cols)]


def blobs(centers, cols, n=26, spread=22, r=4.5, seed=1):
    random.seed(seed)
    out = ""
    for (x, y), c in zip(centers, cols):
        for _ in range(n):
            a, d = random.uniform(0, 6.28), abs(random.gauss(0, spread / 2))
            out += f'<circle cx="{x + d * math.cos(a):.1f}" cy="{y + d * math.sin(a):.1f}" r="{r}" fill="{c}" opacity="0.85"/>'
    return out


def box(x, y, w, h, title, lines, color=POINT):
    out = rect(x, y, w, h, TINT, 10, color) + t(x + w / 2, y + 26, title, 16, 800, color)
    for i, s in enumerate(lines):
        out += t(x + w / 2, y + 54 + i * 24, s, 13, 600, MAIN)
    return out


def bars(x, y, vals, cols, w=18, scale=1.0, gap=6):
    out = ""
    for i, (v, c) in enumerate(zip(vals, cols)):
        out += rect(x + i * (w + gap), y - v * scale, w, v * scale, c, 2)
    return out


def stacked(x, y, h, fracs, cols, w=40):
    out, yy = "", y
    for f, c in zip(fracs, cols):
        out += rect(x, yy, w, f * h, c, 0)
        yy += f * h
    return out


def heat_note(x, y, s, size=13, color=SUB):
    return t(x, y, s, size, 600, color, "start")


# ---------------------------------------------------------------- Visium modules
def spatial_prep():
    g = [panel(40, "A", "Space Ranger slices")]
    tree = ["input_dir/", "  slice_A/outs/", "    filtered_feature_bc_matrix.h5", "    spatial/ (images, positions)",
            "  slice_B/outs/ ..."]
    for i, s in enumerate(tree):
        g.append(f'<text x="70" y="{120 + i * 30}" font-family="DejaVu Sans Mono, monospace" font-size="15" '
                 f'fill="{POINT if i in (0, 1) else MAIN}" xml:space="preserve">{s}</text>')
    g.append(heat_note(70, 300, "One subfolder = one slice; its name is the slice name"))
    g.append(heat_note(70, 326, "Spots under the tissue only (filtered matrix)"))

    g.append(panel(560, "B", "Spot QC (UMI counts)"))
    random.seed(2)
    g.append(tissue(780, 260, 170, 120, lambda x, y, k: ["#2C7BB6", "#ABD9E9", "#FFFFBF", "#FDAE61", "#D7191C"][
        min(4, int(random.random() * 2 + (x - 610) / 110))]))
    g.append(heat_note(600, 430, "nCount_Spatial per spot (violin and on the tissue)"))
    g.append(heat_note(600, 456, "min_counts > 0 removes low-count spots"))

    g.append(panel(1100, "C", "SCTransform per slice"))
    g.append(t(1130, 110, "raw counts", 14, 700, SUB, "start") + bars(1130, 300, [150, 60, 110, 40, 170], [GRAY] * 5, 26, 1, 8))
    g.append(arrow(1310, 220, 1360, 220, SUB, 3))
    g.append(t(1380, 110, "normalised (SCT)", 14, 700, POINT, "start") + bars(1380, 300, [95, 85, 100, 80, 98], [POINT] * 5, 26, 1, 8))
    g.append(box(1120, 380, 420, 110, "<slice>/<slice>_prep.rds", ["SCT assay + tissue image", "plots/<slice>_qc_nCount_Spatial.png"]))
    return svg("".join(g))


def spatial_cluster():
    g = [panel(40, "A", "PCA → neighbours → clusters")]
    for i, s in enumerate(("PCA (npcs = 30)", "neighbour graph", "Louvain clusters (resolution)", "UMAP")):
        g.append(rect(70, 100 + i * 90, 330, 56, PALE if i < 3 else TINT, 8) + t(235, 128 + i * 90, s, 16, 700, MAIN))
        if i < 3:
            g.append(arrow(235, 158 + i * 90, 235, 188 + i * 90, SUB, 2.5))
    g.append(heat_note(70, 480, "Computed per slice on the SCT assay"))

    g.append(panel(560, "B", "Clusters on the UMAP and tissue"))
    g.append(blobs([(640, 170), (720, 260), (640, 340), (760, 150)], REG[:4], seed=3))
    g.append(t(700, 420, "UMAP", 14, 700, SUB))
    g.append(tissue(930, 260, 120, 95, by_region(930, 260, 120, 95), step=15, r=5))
    g.append(heat_note(600, 470, "Cluster numbers are per slice (compare after spatial_merge)"))

    g.append(panel(1100, "C", "Cluster markers (presto)"))
    random.seed(4)
    for r in range(4):
        g.append(t(1130, 130 + r * 50, f"cluster {r}", 13, 700, REG[r], "start"))
        for c in range(6):
            hi = c // 1.5 == r or (c == r + 1)
            rr = 12 if hi else random.choice((3, 5, 7))
            col = "#3B2CE0" if hi else "#C9C4F2"
            g.append(f'<circle cx="{1240 + c * 42}" cy="{130 + r * 50}" r="{rr}" fill="{col}"/>')
    g.append(heat_note(1130, 350, "dot size: % expressing spots; colour: average expression"))
    g.append(box(1120, 390, 420, 110, "<slice>_clustered.rds", ["cluster summary, markers (CSV)", "UMAP, highlight, heatmap, dot plot"]))
    return svg("".join(g))


def spatial_svf():
    g = [panel(40, "A", "Spatial pattern vs. random")]
    g.append(tissue(170, 230, 110, 85, lambda x, y, k: "#D7191C" if region(x, y, 170, 230, 110, 85) == 1 else "#2C7BB6",
                    step=14, r=5))
    random.seed(6)
    g.append(tissue(420, 230, 110, 85, lambda x, y, k: "#D7191C" if random.random() < 0.3 else "#2C7BB6", step=14, r=5))
    g.append(t(170, 350, "Moran's I ≈ 0.8", 15, 800, RED) + t(420, 350, "Moran's I ≈ 0", 15, 800, SUB))
    g.append(heat_note(60, 420, "Neighbouring spots with similar expression → high Moran's I"))

    g.append(panel(560, "B", "Test the variable genes"))
    g.append(box(600, 100, 420, 120, "svf_topn most variable genes", ["(SCT variable features)", "Moran's I with spot coordinates (ape)"]))
    g.append(arrow(810, 225, 810, 280, SUB, 3))
    g.append(box(600, 290, 420, 90, "rank by spatial autocorrelation", ["markvariogram: slower alternative"], SUB))
    g.append(heat_note(600, 430, "Cost grows with the square of the number of spots"))

    g.append(panel(1100, "C", "Top genes"))
    g.append(table(1100, 100, ["rank", "gene"], [("1", "Gene A"), ("2", "Gene B"), ("3", "Gene C")], [80, 160]))
    g.append(heat_note(1100, 250, "<slice>_svf_moransi.csv"))
    g.append(tissue(1350, 400, 110, 80, lambda x, y, k: "#D7191C" if region(x, y, 1350, 400, 110, 80) == 1 else "#ABD9E9",
                    step=14, r=5))
    g.append(heat_note(1100, 520, "plots/<slice>_top_svf_moransi.png (svf_show genes)"))
    return svg("".join(g))


def spatial_merge():
    g = [panel(40, "A", "Clusters per slice (numbers differ)")]
    g.append(tissue(160, 200, 95, 75, by_region(160, 200, 95, 75, REG), step=14, r=5))
    g.append(tissue(390, 200, 95, 75, by_region(390, 200, 95, 75, [REG[2], REG[0], REG[3], REG[1]]), step=14, r=5))
    g.append(t(160, 300, "slice A", 14, 700, SUB) + t(390, 300, "slice B", 14, 700, SUB))
    g.append(heat_note(60, 360, "Same region, different colour (independent numbering)"))

    g.append(panel(560, "B", "Merge + Harmony → joint clusters"))
    g.append(arrow(560, 200, 610, 200, SUB, 3))
    g.append(tissue(720, 200, 95, 75, by_region(720, 200, 95, 75), step=14, r=5))
    g.append(tissue(950, 200, 95, 75, by_region(950, 200, 95, 75), step=14, r=5))
    g.append(t(720, 300, "slice A", 14, 700, SUB) + t(950, 300, "slice B", 14, 700, SUB))
    g.append(heat_note(600, 360, "Same number = same region in every slice"))
    g.append(heat_note(600, 386, "integration = harmony corrects slice differences"))

    g.append(panel(1100, "C", "Composition by slice"))
    for k, fr in enumerate(([0.4, 0.25, 0.2, 0.15], [0.35, 0.3, 0.2, 0.15], [0.2, 0.2, 0.3, 0.3])):
        g.append(stacked(1140 + k * 90, 110, 280, fr, REG[:4], 50) + t(1165 + k * 90, 410, f"slice {'ABC'[k]}", 13, 600, SUB))
    g.append(heat_note(1100, 460, "merged_cluster_by_slice.csv, stacked bar, heatmap"))
    g.append(heat_note(1100, 486, "merged/merged_clustered.rds → spatial_condition_de"))
    return svg("".join(g))


def spatial_condition_de():
    g = [panel(40, "A", "Pseudobulk per slice and cluster")]
    for i, (cond, col) in enumerate((("control", "#7F7F7F"), ("control", "#7F7F7F"), ("treated", RED), ("treated", RED))):
        g.append(tissue(95 + i * 115, 170, 45, 38, by_region(95 + i * 115, 170, 45, 38), step=10, r=3.5))
        g.append(t(95 + i * 115, 230, f"{cond} {i % 2 + 1}", 13, 700, col))
    g.append(arrow(260, 255, 260, 295, SUB, 3) + t(275, 275, "sum counts of one cluster per slice", 13, 600, SUB, "start"))
    g.append(table(70, 310, ["gene", "ctrl1", "ctrl2", "trt1", "trt2"], [("A", "120", "135", "410", "388"),
                                                                          ("B", "560", "590", "575", "548")],
                   [70, 85, 85, 85, 85]))
    g.append(heat_note(70, 440, "DESeq2 ~ Condition (~ Patient + Condition if paired)"))
    g.append(heat_note(70, 466, "One slice per condition: spot-level Wilcoxon (exploratory)"))

    g.append(panel(560, "B", "Volcano per cluster"))
    random.seed(8)
    x0, w = 620, 400
    g.append(axes(x0, 100, w, 300, "log2 fold change", "-log10 adjusted p"))
    for _ in range(140):
        lfc, p = random.gauss(0, 0.6), abs(random.gauss(0, 1.2))
        if abs(lfc) > 0.9:
            p += abs(lfc) * 2.2
        col = RED if (lfc > 0.5 and p > 2) else BLUE if (lfc < -0.5 and p > 2) else GRAY
        g.append(f'<circle cx="{x0 + w / 2 + lfc * 100:.1f}" cy="{400 - min(p, 6) * 48:.1f}" r="3.5" fill="{col}" opacity="0.85"/>')
    g.append(line(x0, 304, x0 + w, 304, GRAY, 1.5, "5,4"))
    for v in (-0.5, 0.5):
        g.append(line(x0 + w / 2 + v * 100, 100, x0 + w / 2 + v * 100, 400, GRAY, 1.5, "5,4"))
    g.append(legend(620, 470, [("dot", RED, "up vs reference"), ("dot", BLUE, "down")]))

    g.append(panel(1100, "C", "Summary per cluster"))
    rows = [("0", "pseudobulk_DESeq2", "ok"), ("2", "spot_level_wilcoxon", "ok_exploratory"), ("12", "-", "insufficient_slices")]
    g.append(table(1100, 100, ["group", "method", "status"], rows, [70, 190, 170], {1: "#E08214", 2: SUB}))
    g.append(heat_note(1100, 250, "04_summary/de_summary.tsv"))
    g.append(heat_note(1100, 280, "Also: composition by condition, significant gene"))
    g.append(heat_note(1100, 304, "counts, log2FC heatmap, genes on the tissue"))
    g.append(heat_note(1100, 350, "Input: Visium merge output or Visium HD"))
    g.append(heat_note(1100, 374, "(hd_slides.tsv; group_by may be a cell-type column)"))
    return svg("".join(g))


def spatial_labelTransfer():
    g = [panel(40, "A", "Single-cell reference")]
    g.append(blobs([(130, 170), (230, 140), (180, 250), (300, 230), (110, 300)], CT, seed=9))
    g.append(legend(330, 120, [("dot", CT[i], f"type {'ABCDE'[i]}") for i in range(5)]))
    g.append(heat_note(60, 380, "Seurat RDS with a cell-type column"))
    g.append(heat_note(60, 404, "(reference_label_col; see check_reference)"))
    g.append(heat_note(60, 428, "SCT + PCA built here when raw counts exist"))

    g.append(panel(560, "B", "Anchors between reference and spots"))
    g.append(blobs([(650, 200), (700, 300)], CT[:2], n=14, seed=10))
    g.append(tissue(930, 250, 95, 75, step=14, r=5))
    for (a, b) in ((650, 200), (700, 300)):
        g.append(line(a + 20, b, 860, 250 + (b - 250) * 0.3, POINT, 2, "6,5"))
    g.append(heat_note(600, 380, "FindTransferAnchors → TransferData"))
    g.append(heat_note(600, 404, "prediction score per cell type for every spot"))

    g.append(panel(1100, "C", "Predicted cell types per slice"))
    g.append(tissue(1230, 220, 110, 85, by_region(1230, 220, 110, 85, CT), step=14, r=5))
    g.append(heat_note(1100, 360, "<slice>_predicted_celltype_scores.csv"))
    g.append(heat_note(1100, 384, "plots/<slice>_predicted_<celltype>.png"))
    g.append(heat_note(1100, 408, "summary/: cell type by slice (CSV, heatmap)"))
    return svg("".join(g))


def spatial_rctd():
    g = [panel(40, "A", "Reference cell-type profiles")]
    random.seed(12)
    for r in range(5):
        g.append(t(70, 130 + r * 44, f"type {'ABCDE'[r]}", 13, 700, CT[r], "start"))
        for c in range(8):
            v = random.random() if c // 2 != r else 0.9 + random.random() * 0.1
            g.append(rect(140 + c * 32, 115 + r * 44, 28, 30, CT[r], 3, op=0.15 + 0.85 * v))
    g.append(heat_note(140, 360, "genes →  (mean raw-count profile per type)"))
    g.append(heat_note(60, 410, "Raw counts and ≥ min_cells_per_type cells per type"))

    g.append(panel(560, "B", "Each spot = mixture of types"))
    g.append(f'<circle cx="700" cy="230" r="70" fill="{TISSUE}" stroke="{EDGE}" stroke-width="3"/>')
    for i, (cx, cy) in enumerate(((680, 210), (720, 245), (690, 260), (715, 205))):
        g.append(f'<circle cx="{cx}" cy="{cy}" r="16" fill="{CT[[0, 0, 2, 3][i]]}" opacity="0.85"/>')
    g.append(arrow(790, 230, 840, 230, SUB, 3))
    g.append(stacked(870, 120, 220, [0.55, 0.25, 0.2], [CT[0], CT[2], CT[3]], 50))
    g.append(t(895, 360, "weights", 13, 700, SUB))
    g.append(heat_note(600, 410, "RCTD full mode: weights for every spot (spacexr)"))

    g.append(panel(1100, "C", "Cell types on the tissue"))
    g.append(tissue(1230, 220, 110, 85, by_region(1230, 220, 110, 85, CT), step=14, r=5))
    g.append(heat_note(1100, 360, "<slice>_rctd_weights.csv, mean abundance"))
    g.append(heat_note(1100, 384, "plots: dominant cell type, top abundances"))
    g.append(heat_note(1100, 408, "summary/: cell type by slice"))
    return svg("".join(g))


def check_reference():
    g = [panel(40, "A", "Reference metadata")]
    rows = [("AAAC...", "Astro", "3", "12000"), ("AAAG...", "CA1", "1", "8400"), ("AACT...", "Dentate", "5", "9100")]
    g.append(table(60, 110, ["cell", "celltype", "batch", "nCount"], rows, [110, 110, 80, 90]))
    g.append(heat_note(60, 260, "reference_rds: Seurat object (.rds)"))

    g.append(panel(560, "B", "Column report in the log"))
    lines = ["[CELLTYPE?] celltype : 17 categories -> CA1 (30), ...", "[CELLTYPE?] batch    : 6 categories -> ...",
             "[SKIP     ] nCount   : numeric (range 512 ~ 40210)", "[SKIP     ] cell_id  : 5100 categories"]
    for i, s in enumerate(lines):
        g.append(f'<text x="580" y="{130 + i * 34}" font-family="DejaVu Sans Mono, monospace" font-size="13" '
                 f'fill="{POINT if i < 2 else SUB}" xml:space="preserve">{s}</text>')
    g.append(heat_note(580, 300, "Candidate: categorical with 2-100 categories"))

    g.append(panel(1100, "C", "Choose reference_label_col"))
    g.append(table(1100, 110, ["Column", "Candidate"], [("celltype", "yes"), ("batch", "yes"), ("nCount", "no")], [150, 110],
                   {0: POINT}))
    g.append(heat_note(1100, 250, "reference_columns.tsv"))
    g.append(arrow(1250, 280, 1250, 330, SUB, 3))
    g.append(box(1100, 340, 400, 90, "reference_label_col = celltype", ["spatial_labelTransfer, spatial_rctd, spatial_hd_rctd"]))
    return svg("".join(g))


# ---------------------------------------------------------------- Visium HD modules
def spatial_hd_prep():
    g = [panel(40, "A", "2 µm squares binned to 8 or 16 µm")]
    for i in range(8):
        for j in range(8):
            g.append(rect(80 + i * 16, 110 + j * 16, 14, 14, "#C9CDD3", 1))
    g.append(arrow(230, 175, 280, 175, SUB, 3))
    for i in range(2):
        for j in range(2):
            g.append(rect(300 + i * 62, 120 + j * 62, 58, 58, "#8FA9C9", 3))
    g.append(t(144, 260, "2 µm", 14, 700, SUB) + t(360, 260, "8 µm bins", 14, 700, POINT))
    g.append(heat_note(70, 320, "binned_outputs/square_008um (or 016um)"))
    g.append(heat_note(70, 346, "filtered_feature_bc_matrix.h5, tissue_positions.parquet"))
    g.append(heat_note(70, 372, "2 µm bins are not supported (memory)"))

    g.append(panel(560, "B", "Bin QC and log normalisation"))
    random.seed(13)
    g.append(tissue(780, 250, 160, 110, lambda x, y, k: ["#2C7BB6", "#ABD9E9", "#FFFFBF", "#FDAE61"][
        min(3, int(random.random() * 1.5 + (x - 620) / 110))], step=10, r=5, square=True))
    g.append(heat_note(600, 410, "min_counts, min_features; NormalizeData (log)"))
    g.append(heat_note(600, 436, "QC: UMI counts and genes per bin"))

    g.append(panel(1100, "C", "Sketch: informative bins"))
    random.seed(14)
    g.append(tissue(1290, 250, 160, 110, lambda x, y, k: POINT if random.random() < 0.18 else "#E1E4E8", step=10, r=5,
                    square=True))
    g.append(heat_note(1130, 410, "Leverage-score sample (sketch_cells per slide)"))
    g.append(heat_note(1130, 436, "<slide>_hd_prep.rds: all bins + sketch assay"))
    return svg("".join(g))


def spatial_hd_cluster():
    g = [panel(40, "A", "Joint clusters on the sketches")]
    g.append(blobs([(130, 170), (250, 150), (180, 270), (300, 260)], REG[:4], seed=15))
    g.append(heat_note(60, 380, "Sketch bins of all slides, Harmony across slides"))
    g.append(heat_note(60, 404, "PCA, clusters, UMAP, markers (presto)"))

    g.append(panel(560, "B", "Label every bin from k nearest sketch bins"))
    random.seed(16)
    pts = [(650 + random.uniform(0, 300), 120 + random.uniform(0, 220)) for _ in range(30)]
    for i, (x, y) in enumerate(pts):
        g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="6" fill="{REG[0] if x < 800 else REG[1]}"/>')
    q = (790, 230)
    for x, y in sorted(pts, key=lambda p: (p[0] - q[0]) ** 2 + (p[1] - q[1]) ** 2)[:6]:
        g.append(line(q[0], q[1], x, y, SUB, 1.5, "4,4"))
    g.append(f'<rect x="{q[0] - 8}" y="{q[1] - 8}" width="16" height="16" fill="#fff" stroke="{MAIN}" stroke-width="3"/>')
    g.append(heat_note(600, 380, "Every bin projected onto the joint PCA;"))
    g.append(heat_note(600, 404, "majority of its k_transfer neighbours (same slide)"))
    g.append(heat_note(600, 428, "Cluster_score = fraction of neighbours agreeing"))

    g.append(panel(1100, "C", "Clusters on every bin"))
    g.append(tissue(1290, 240, 160, 110, by_region(1290, 240, 160, 110), step=10, r=5, square=True))
    g.append(heat_note(1130, 400, "<slide>_hd_clustered.rds, hd_slides.tsv"))
    g.append(heat_note(1130, 426, "→ spatial_condition_de, spatial_hd_svf, spatial_hd_rctd"))
    return svg("".join(g))


def spatial_hd_svf():
    g = [panel(40, "A", "Sample bins per slide")]
    random.seed(17)
    g.append(tissue(220, 230, 160, 110, lambda x, y, k: POINT if random.random() < 0.25 else "#E1E4E8", step=10, r=5,
                    square=True))
    g.append(heat_note(60, 390, "max_bins random bins (cost ~ bins²)"))

    g.append(panel(560, "B", "Moran's I of the variable genes"))
    g.append(box(600, 110, 420, 110, "svf_topn variable genes", ["Moran's I, p-value, BH adjusted p", "(Seurat RunMoransI, ape)"]))
    g.append(arrow(810, 225, 810, 270, SUB, 3))
    g.append(table(600, 280, ["Gene", "Morans_I", "P_adj", "Rank"], [("Prox1", "0.62", "1e-40", "1"), ("Mbp", "0.55", "1e-31", "2")],
                   [110, 110, 100, 70]))

    g.append(panel(1100, "C", "Top genes on all bins"))
    g.append(tissue(1290, 240, 160, 110, lambda x, y, k: RED if region(x, y, 1290, 240, 160, 110) == 2 else "#ABD9E9",
                    step=10, r=5, square=True))
    g.append(heat_note(1130, 400, "<slide>_hd_svf.tsv, svf_summary.tsv"))
    g.append(heat_note(1130, 426, "plots/<slide>_top_svf.png"))
    return svg("".join(g))


def spatial_hd_rctd():
    g = [panel(40, "A", "Chunks of bins + reference")]
    for k in range(3):
        g.append(rect(70, 110 + k * 70, 300, 52, PALE, 6) + t(220, 136 + k * 70, f"bins {k * 20000 + 1}-{(k + 1) * 20000}", 14, 700, MAIN))
    g.append(heat_note(70, 340, "chunk_bins per RCTD run (memory bound)"))
    g.append(heat_note(70, 366, "Reference: raw counts + cell-type column"))

    g.append(panel(560, "B", "doublet mode: up to two types per bin"))
    for i, (cls, cols) in enumerate((("singlet", [CT[0]]), ("doublet_certain", [CT[0], CT[2]]), ("reject", [GRAY]))):
        y = 120 + i * 90
        g.append(rect(600, y, 60, 60, "#fff", 4, MAIN, 2))
        if len(cols) == 1:
            g.append(rect(605, y + 5, 50, 50, cols[0], 3))
        else:
            g.append(rect(605, y + 5, 25, 50, cols[0], 3) + rect(630, y + 5, 25, 50, cols[1], 3))
        g.append(t(680, y + 30, cls, 15, 700, MAIN, "start"))
    g.append(heat_note(600, 420, "rctd_first_type, rctd_second_type, rctd_spot_class"))
    g.append(heat_note(600, 446, "full mode (16 µm): weights; first = highest weight"))

    g.append(panel(1100, "C", "Cell types on every bin"))
    g.append(tissue(1290, 240, 160, 110, by_region(1290, 240, 160, 110, CT), step=10, r=5, square=True))
    g.append(heat_note(1130, 400, "<slide>_hd_rctd.rds, weights.tsv.gz, celltype_by_slide"))
    g.append(heat_note(1130, 426, "hd_slides.tsv → spatial_condition_de"))
    g.append(heat_note(1130, 452, "(group_by = rctd_first_type)"))
    return svg("".join(g))


FIGS = {"spatial_prep": spatial_prep, "spatial_cluster": spatial_cluster, "spatial_svf": spatial_svf,
        "spatial_merge": spatial_merge, "spatial_condition_de": spatial_condition_de,
        "spatial_labelTransfer": spatial_labelTransfer, "spatial_rctd": spatial_rctd, "check_reference": check_reference,
        "spatial_hd_prep": spatial_hd_prep, "spatial_hd_cluster": spatial_hd_cluster, "spatial_hd_svf": spatial_hd_svf,
        "spatial_hd_rctd": spatial_hd_rctd}

# Panels kept per figure. Panels that repeat the paper figure placed before the drawing, that
# list inputs already in the parameter table, or that show outputs instead of the principle
# are dropped; the kept panels are relettered A, B, ... (a single panel has no letter).
KEEP = {"spatial_prep": "BC", "spatial_cluster": "BC", "spatial_svf": "AB", "spatial_merge": "AB",
        "spatial_condition_de": "BC", "spatial_labelTransfer": "AB", "spatial_rctd": "AB", "check_reference": "BC",
        "spatial_hd_prep": "ABC", "spatial_hd_cluster": "AB", "spatial_hd_svf": "AB", "spatial_hd_rctd": "AB"}
REGION_X = {"A": 0, "B": 540, "C": 1080}   # each drawing has three 540-px-wide panel regions
PANEL_X = {"A": 40, "B": 560, "C": 1100}   # x of the panel letter


def keep_panels(drawing, keep):
    """Cut the kept panel regions out of a three-panel drawing and set them side by side."""
    if keep == "ABC":
        return drawing
    height = int(re.search(r'height="(\d+)"', drawing).group(1))
    inner = drawing[drawing.index(">") + 1:drawing.rindex("</svg>")]
    for i, old in enumerate(keep):
        new = "" if len(keep) == 1 else "ABC"[i]
        inner = re.sub(rf'(<text x="{PANEL_X[old]}" y="40"[^>]*>){old}(</text>)', rf"\g<1>{new}\g<2>", inner)
    width = 540 * len(keep) + 20
    parts = [f'<svg x="{i * 540}" y="0" width="540" height="{height}" viewBox="{REGION_X[p]} 0 540 {height}">{inner}</svg>'
             for i, p in enumerate(keep)]
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">'
            f'<rect width="{width}" height="{height}" fill="#FFFFFF"/>' + "".join(parts) + "</svg>")


if __name__ == "__main__":
    for name, fn in FIGS.items():
        dirs = [HD] if name.startswith("spatial_hd_") else \
            [VIS, HD] if name in ("spatial_condition_de", "check_reference") else [VIS]
        drawing = keep_panels(fn(), KEEP[name])
        for d in dirs:
            p = d / f"{name}_concept.svg"
            p.write_text(drawing)
            print(p)
