#!/usr/bin/env python3
"""Spatial transcriptomics concept figure (SVG): spots and bins, clusters as tissue
regions, condition comparison with slice-level pseudobulk, and cell types from a
single-cell reference.

Drawn from scratch (no published figure used); the tissue and counts are schematic.
Both pipelines use the same figure, so it is written to each pipeline's figures folder.
Run: python3 docs/Spatial_Transcriptomics_Shared/figures/make_concept.py, then
for d in docs/Spatial_Transcriptomics_Visium*_Pipeline/pipeline/figures; do
    rsvg-convert -w 1800 $d/concept.svg -o $d/concept.png; done
"""
import math
from pathlib import Path

DOCS = Path(__file__).resolve().parents[2]
OUTS = [DOCS / p / "pipeline" / "figures" / "concept.svg"
        for p in ("Spatial_Transcriptomics_Visium_Pipeline", "Spatial_Transcriptomics_Visium_HD_Pipeline")]
W, H = 1800, 1220
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT = "#222222", "#3A3A3A", "#32549C"
TISSUE, EDGE = "#F3E6EC", "#B98AA0"
REG = ["#4E79A7", "#F28E2B", "#59A14F", "#E15759"]   # four tissue regions
COND = {"control": "#7F7F7F", "treated": "#C0504D"}
CT = {"type A": "#9C6ADE", "type B": "#2CA6A4", "type C": "#E8A33D"}   # reference cell types
g = []


def text(x, y, s, size=22, weight=500, anchor="middle", color=TXT):
    g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" '
             f'font-weight="{weight}" fill="{color}" dominant-baseline="middle">{s}</text>')


def panel_label(x, y, letter, title):
    text(x, y, letter, 30, 800, "start", POINT)
    text(x + 40, y, title, 24, 700, "start")


def inside(x, y, cx, cy, rx, ry):
    """Tissue shape: an ellipse with a notch, in local units."""
    e = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
    notch = ((x - (cx + rx * 0.55)) / (rx * 0.35)) ** 2 + ((y - (cy - ry * 0.7)) / (ry * 0.45)) ** 2 <= 1
    return e and not notch


def region(x, y, cx, cy, rx, ry):
    """Layered regions: three bands plus a core, like cortex layers around a nucleus."""
    d = math.hypot((x - cx) / rx, (y - cy) / ry)
    if math.hypot((x - cx - rx * 0.25) / (rx * 0.28), (y - cy - ry * 0.15) / (ry * 0.3)) < 1:
        return 3
    return 0 if d > 0.8 else 1 if d > 0.55 else 2


def tissue(cx, cy, rx, ry, mode, scale=1.0):
    """mode: 'outline', 'spots' (gray), 'clusters' (region colors), or 'bins'."""
    if mode in ("spots", "clusters"):
        step = 26 * scale
        r = 9 * scale
        row = 0
        y = cy - ry
        while y <= cy + ry:
            x0 = cx - rx + (step / 2 if row % 2 else 0)
            x = x0
            while x <= cx + rx:
                if inside(x, y, cx, cy, rx, ry):
                    fill = "#C9CDD3" if mode == "spots" else REG[region(x, y, cx, cy, rx, ry)]
                    g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r:.1f}" fill="{fill}"/>')
                x += step
            y += step * 0.866
            row += 1
    elif mode == "bins":
        step = 9 * scale
        y = cy - ry
        while y <= cy + ry:
            x = cx - rx
            while x <= cx + rx:
                if inside(x + step / 2, y + step / 2, cx, cy, rx, ry):
                    g.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{step - 1.5:.1f}" height="{step - 1.5:.1f}" fill="#C9CDD3"/>')
                x += step
            y += step


def tissue_bg(cx, cy, rx, ry):
    g.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx + 14}" ry="{ry + 14}" fill="{TISSUE}" stroke="{EDGE}" stroke-width="3"/>')


# The measurement panel (spots and bins on a grid) was dropped: Figure 1 of the pipeline
# content (Williams et al. 2022, Fig. 1) shows it.

# (A) clusters as regions
B0 = len(g)
panel_label(900, 50, "A", "Clusters of similar spots map tissue regions")
tissue_bg(1110, 270, 170, 140)
tissue(1110, 270, 170, 140, "clusters")
# UMAP-like cloud next to it
for k, (ux, uy) in enumerate([(1450, 170), (1600, 210), (1480, 340), (1640, 360)]):
    for j in range(28):
        a = j * 2.4
        rr = 8 + (j % 7) * 6
        g.append(f'<circle cx="{ux + rr * math.cos(a):.1f}" cy="{uy + rr * math.sin(a):.1f}" r="6" fill="{REG[k]}" opacity="0.85"/>')
    text(ux, uy - 62 if k < 2 else uy + 66, f"cluster {k + 1}", 18, 600, "middle", REG[k])
text(1110, 460, "clusters on the tissue", 22, 700)
text(1545, 460, "UMAP", 22, 700)
g.append(f'<path d="M1300,270 L1380,270" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')
g[B0:] = ['<g transform="translate(-860,0)">' + "".join(g[B0:]) + "</g>"]

# (C) condition comparison
yC = 600
panel_label(40, yC - 40, "B", "Conditions are compared within a cluster, with slices as replicates")
slices = [("control", 1), ("control", 2), ("treated", 1), ("treated", 2)]
for i, (cond, rep) in enumerate(slices):
    cx = 130 + i * 190
    tissue_bg(cx, yC + 110, 70, 58)
    tissue(cx, yC + 110, 70, 58, "clusters", scale=0.42)
    text(cx, yC + 205, f"{cond} {rep}", 19, 700, "middle", COND[cond])
g.append(f'<path d="M870,{yC + 110} L950,{yC + 110}" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')
text(910, yC + 80, "sum counts", 17, 600, "middle", TXT2)
text(910, yC + 140, "per slice", 17, 600, "middle", TXT2)
# pseudobulk table for cluster 2
tx, ty = 980, yC + 10
text(tx + 200, ty - 10, "cluster 2 pseudobulk counts", 20, 700, "middle", REG[1])
cols = ["control 1", "control 2", "treated 1", "treated 2"]
vals = [[120, 135, 410, 388], [560, 590, 575, 548], [80, 66, 21, 30]]
genes = ["Gene A", "Gene B", "Gene C"]
cw, rh = 100, 40
for j, c in enumerate(cols):
    text(tx + 80 + j * cw + cw / 2, ty + 25, c, 16, 700, "middle", COND[c.split()[0]])
for i, (gname, row) in enumerate(zip(genes, vals)):
    yy = ty + 60 + i * rh
    text(tx + 70, yy, gname, 17, 600, "end", TXT2)
    for j, v in enumerate(row):
        g.append(f'<rect x="{tx + 80 + j * cw + 4}" y="{yy - 16}" width="{cw - 8}" height="32" rx="5" fill="#F1F3F6"/>')
        text(tx + 80 + j * cw + cw / 2, yy, str(v), 17, 500, "middle")
g.append(f'<path d="M1490,{yC + 110} L1560,{yC + 110}" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')
text(1660, yC + 70, "DESeq2", 22, 700)
text(1660, yC + 105, "~ Condition", 19, 600, "middle", TXT2)
text(1660, yC + 150, "Gene A up", 18, 700, "middle", COND["treated"])
text(1660, yC + 180, "Gene C down", 18, 700, "middle", POINT)
text(1180, yC + 245, "One slice per condition: spot-level test only (exploratory)", 18, 600, "middle", TXT2)

# (D) cell types from a single-cell reference
yD = 930
panel_label(40, yD - 40, "C", "With a single-cell reference, cell types are assigned to spots and bins")
# reference: cells grouped by type, with a mean expression profile per type
g.append(f'<rect x="60" y="{yD}" width="330" height="230" rx="14" fill="#F7F7FA" stroke="#D5D8DE" stroke-width="2"/>')
text(225, yD + 28, "single-cell reference", 19, 700)
profiles = {"type A": [0.9, 0.2, 0.1], "type B": [0.1, 0.8, 0.3], "type C": [0.2, 0.1, 0.9]}
for i, (ct, prof) in enumerate(profiles.items()):
    yy = yD + 75 + i * 55
    for j in range(5):
        g.append(f'<circle cx="{95 + j * 16}" cy="{yy}" r="7" fill="{CT[ct]}"/>')
    text(200, yy, ct, 17, 700, "middle", CT[ct])
    for k, v in enumerate(prof):
        g.append(f'<rect x="{255 + k * 38}" y="{yy + 14 - 30 * v:.1f}" width="26" height="{30 * v:.1f}" fill="{CT[ct]}" opacity="0.8"/>')
text(312, yD + 215, "genes 1  2  3", 14, 600, "middle", TXT2)
g.append(f'<path d="M410,{yD + 115} L490,{yD + 115}" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')
# Visium: proportions per spot (pies)
def pie(cx, cy, r, parts):
    a0 = -math.pi / 2
    for ct, f in parts:
        a1 = a0 + 2 * math.pi * f
        large = 1 if f > 0.5 else 0
        x0, y0 = cx + r * math.cos(a0), cy + r * math.sin(a0)
        x1, y1 = cx + r * math.cos(a1), cy + r * math.sin(a1)
        g.append(f'<path d="M{cx},{cy} L{x0:.1f},{y0:.1f} A{r},{r} 0 {large} 1 {x1:.1f},{y1:.1f} z" fill="{CT[ct]}"/>')
        a0 = a1
spots = [[("type A", 0.6), ("type B", 0.3), ("type C", 0.1)], [("type A", 0.2), ("type B", 0.7), ("type C", 0.1)],
         [("type A", 0.1), ("type B", 0.2), ("type C", 0.7)], [("type A", 0.4), ("type B", 0.4), ("type C", 0.2)],
         [("type A", 0.8), ("type B", 0.1), ("type C", 0.1)], [("type A", 0.1), ("type B", 0.5), ("type C", 0.4)]]
for i, parts in enumerate(spots):
    pie(560 + (i % 3) * 85, yD + 70 + (i // 3) * 85, 34, parts)
text(645, yD + 205, "Visium: cell-type proportions per spot", 18, 700)
# Visium HD: one type per bin
types = list(CT)
for i in range(10):
    for j in range(8):
        k = 0 if (i + j) < 6 else 1 if (i - j) > 2 else 2
        if (i * 7 + j * 3) % 11 == 0:
            k = (k + 1) % 3
        g.append(f'<rect x="{900 + i * 22}" y="{yD + 15 + j * 22}" width="20" height="20" fill="{CT[types[k]]}"/>')
text(1010, yD + 205, "Visium HD: a cell type per bin", 18, 700)
g.append(f'<path d="M1150,{yD + 100} L1230,{yD + 100}" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')
text(1480, yD + 75, "Conditions can then be compared", 19, 700)
text(1480, yD + 105, "within each cell type (group_by)", 19, 700)
text(1480, yD + 150, "Without a reference this step is skipped;", 17, 600, "middle", TXT2)
text(1480, yD + 178, "clusters are read through their marker genes.", 17, 600, "middle", TXT2)

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<defs><marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
       f'<path d="M0,0 L10,5 L0,10 z" fill="{TXT2}"/></marker></defs>'
       f'<rect width="{W}" height="{H}" fill="#fff"/>' + "".join(g) + "</svg>")
for out in OUTS:
    out.write_text(svg)
    print(out)
