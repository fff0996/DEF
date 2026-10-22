#!/usr/bin/env python3
"""Spatial transcriptomics concept figure (SVG): spots and bins, clusters as tissue
regions, and condition comparison with slice-level pseudobulk.

Drawn from scratch (no published figure used); the tissue and counts are schematic.
Run: python3 docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/concept.svg \
    -o docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/concept.png
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 880
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT = "#222222", "#3A3A3A", "#32549C"
TISSUE, EDGE = "#F3E6EC", "#B98AA0"
REG = ["#4E79A7", "#F28E2B", "#59A14F", "#E15759"]   # four tissue regions
COND = {"control": "#7F7F7F", "treated": "#C0504D"}
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


# (A) measurement units
panel_label(40, 50, "A", "Expression is measured on a grid over the tissue")
tissue_bg(250, 270, 170, 140)
tissue(250, 270, 170, 140, "spots")
text(250, 460, "Visium: 55 µm spots", 22, 700)
text(250, 492, "1-10 cells per spot", 19, 500, "middle", TXT2)
tissue_bg(640, 270, 170, 140)
tissue(640, 270, 170, 140, "bins")
text(640, 460, "Visium HD: 8 or 16 µm bins", 22, 700)
text(640, 492, "about one cell per 8 µm bin", 19, 500, "middle", TXT2)

# (B) clusters as regions
panel_label(900, 50, "B", "Clusters of similar spots map tissue regions")
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

# (C) condition comparison
yC = 600
panel_label(40, yC - 40, "C", "Conditions are compared within a cluster, with slices as replicates")
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

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<defs><marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
       f'<path d="M0,0 L10,5 L0,10 z" fill="{TXT2}"/></marker></defs>'
       f'<rect width="{W}" height="{H}" fill="#fff"/>' + "".join(g) + "</svg>")
OUT.write_text(svg)
print(OUT)
