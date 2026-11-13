#!/usr/bin/env python3
"""scGPT pipeline concept figure (SVG), drawn in the visual style of the source figure
(Tejada-Lapuerta et al. 2025, Fig. 1: slate and sage blocks, mustard highlight, banner titles,
shaded cell icons, upper-case panel letters as in the manuscripts).

a: redrawn and changed from Tejada-Lapuerta et al., Nat Methods 2025, 22:2525-2538, Figure 1c-e
   (Nicheformer; CC BY 4.0, doi:10.1038/s41592-025-02814-z): the cell with its expression values,
   tokenizer, token embeddings, transformer block, output and the embedding UMAP are kept;
   changed to scGPT (gene and binned value embeddings, <cls> output as the cell embedding, frozen
   weights); metadata tokens, position embeddings and masking removed.
   The scGPT paper (Cui et al. 2024 Nat Methods) has no open licence.
b: redrawn and simplified from Do & Lahdesmaki, Bioinformatics 2025, 41(Suppl 1):i96-i104,
   Figure 1 (CC BY 4.0, doi:10.1093/bioinformatics/btaf241): only the cell-level attention is
   kept (the cell-type level is removed), and the patient label and the comparison are added.
Values are schematic.
Run: python3 docs/scGPT/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/scGPT/pipeline/figures/concept.svg -o docs/scGPT/pipeline/figures/concept.png
"""
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 1120
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2 = "#1F1F1F", "#555555"
SLATE, SLATE_L, SAGE, SAGE_D, MUST = "#56688E", "#9AA7C0", "#D9DCD0", "#B9BDAE", "#E2C25B"
CT = {"T cell": SLATE, "Monocyte": MUST, "B cell": SLATE_L, "NK": "#B6844F"}
POS, NEG = "#B8860B", SLATE
g = []
random.seed(11)


def text(x, y, s, size=20, weight=400, anchor="middle", color=TXT):
    g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" '
             f'font-weight="{weight}" fill="{color}" dominant-baseline="middle">{s}</text>')


def rect(x, y, w, h, fill, stroke="none", sw=0, rx=0, extra=""):
    g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" '
             f'stroke-width="{sw}" {extra}/>')


def arrow(x1, y1, x2, y2, color=TXT, sw=2.2):
    ang = math.atan2(y2 - y1, x2 - x1)
    bx, by = x2 - 11 * math.cos(ang), y2 - 11 * math.sin(ang)
    g.append(f'<line x1="{x1}" y1="{y1}" x2="{bx:.1f}" y2="{by:.1f}" stroke="{color}" stroke-width="{sw}"/>')
    p1 = (bx - 6 * math.sin(ang), by + 6 * math.cos(ang))
    p2 = (bx + 6 * math.sin(ang), by - 6 * math.cos(ang))
    g.append(f'<path d="M{x2},{y2} L{p1[0]:.1f},{p1[1]:.1f} L{p2[0]:.1f},{p2[1]:.1f} z" fill="{color}"/>')


def banner(x, w, y, letter, title, fill, color="#FFFFFF"):
    text(x - 28, y + 8, letter, 34, 800, "middle", TXT)
    rect(x, y - 22, w, 52, fill)
    text(x + w / 2, y + 4, title, 22, 500, color=color)


def cell(cx, cy, r, tint="#E6E6E6"):
    """Shaded cell with a dark nucleus, like the cell icons of the source figure."""
    g.append(f'<ellipse cx="{cx + 4}" cy="{cy + 7}" rx="{r}" ry="{r * 0.9}" fill="#000000" fill-opacity="0.08"/>')
    g.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{r}" ry="{r * 0.9}" fill="url(#cellgrad)" '
             f'stroke="#CFCFCF" stroke-width="1"/>')
    g.append(f'<circle cx="{cx + r * 0.08}" cy="{cy - r * 0.05}" r="{r * 0.3}" fill="url(#nucgrad)"/>')


def strip(x, y, color, n=12, w=13, h=26, seed=0):
    rnd = random.Random(seed)
    for i in range(n):
        op = 0.2 + 0.8 * rnd.random()
        rect(x + i * w, y, w - 1, h, color, extra=f'fill-opacity="{op:.2f}"')


defs = ('<defs>'
        '<radialGradient id="cellgrad" cx="38%" cy="32%" r="75%">'
        '<stop offset="0%" stop-color="#FFFFFF"/><stop offset="70%" stop-color="#E4E4E4"/>'
        '<stop offset="100%" stop-color="#C9C9C9"/></radialGradient>'
        '<radialGradient id="nucgrad" cx="35%" cy="30%" r="80%">'
        '<stop offset="0%" stop-color="#7A7A7A"/><stop offset="100%" stop-color="#1E1E1E"/></radialGradient>'
        '<filter id="shadow" x="-10%" y="-10%" width="125%" height="125%">'
        '<feDropShadow dx="3" dy="4" stdDeviation="5" flood-color="#000000" flood-opacity="0.13"/></filter>'
        '</defs>')

# ------------------------------------------------------------------ a
banner(70, 1670, 40, "A", "Cell representation: pretrained scGPT reads each cell (frozen, not trained here)", SLATE)
cell(115, 235, 52)
text(115, 315, "one cell", 18, 500)
genes = [("CD3D", 12), ("IL7R", 8), ("CD2", 5), ("LTB", 3)]
base = 290
for i, (gname, v) in enumerate(genes):
    x = 200 + i * 54
    rect(x, base - 12 * v, 34, 12 * v, SAGE_D)
    text(x + 17, base - 12 * v - 14, str(v), 16, 400)
    text(x + 17, base + 18, gname, 15, 400)
text(420, base - 8, "···", 18, 700, color=TXT2)
g.append(f'<line x1="192" y1="{base}" x2="440" y2="{base}" stroke="{TXT}" stroke-width="1.5"/>')
text(316, 352, "expression values", 17, 400)
text(316, 374, "top 1,200 genes per cell", 15, 400, color=TXT2)
arrow(452, 232, 482, 232)
rect(490, 104, 118, 268, SAGE)
text(549, 222, "scGPT", 19, 500)
text(549, 246, "tokenizer", 19, 500)
text(549, 290, "values", 14, 400, color=TXT2)
text(549, 308, "binned", 14, 400, color=TXT2)
rows = [("&lt;cls&gt;", "–"), ("CD3D", "50"), ("IL7R", "42"), ("CD2", "31"), ("LTB", "20"),
        (None, None), ("Gene n", "k")]
for i, (tok, val) in enumerate(rows):
    y = 104 + i * 39
    if tok is None:
        for xx in (672, 790, 1086):
            text(xx, y + 12, "⋮", 20, 700, color=TXT2)
        continue
    cls = i == 0
    rect(630, y, 84, 30, MUST if cls else SAGE)
    text(672, y + 15, tok, 15, 500 if cls else 400)
    text(735, y + 15, "+", 18, 400)
    rect(756, y, 68, 30, SAGE)
    text(790, y + 15, val, 15, 400)
    rect(1044, y, 84, 30, MUST if cls else SAGE)
    text(1086, y + 15, tok, 15, 500 if cls else 400)
text(672, 394, "Gene", 17, 400)
text(672, 416, "embeddings", 17, 400)
text(790, 394, "Value", 17, 400)
text(790, 416, "embeddings", 17, 400)
text(1086, 405, "Output", 17, 400)
arrow(610, 238, 626, 238)
arrow(828, 238, 852, 238)
rect(858, 104, 166, 268, SLATE)
text(941, 196, "scGPT", 22, 500, color="#FFFFFF")
text(941, 224, "transformer", 22, 500, color="#FFFFFF")
text(941, 252, "block", 22, 500, color="#FFFFFF")
text(941, 300, "whole_human,", 14, 400, color="#E4E8F0")
text(941, 318, "33 million cells", 14, 400, color="#E4E8F0")
text(941, 348, "weights fixed", 15, 600, color=MUST)
arrow(1026, 238, 1040, 238)
arrow(1132, 119, 1176, 119)
strip(1182, 104, SLATE, n=12, w=12, h=30, seed=1)
text(1254, 158, "cell embedding", 17, 400)
text(1254, 180, "(512 numbers)", 15, 400, color=TXT2)
# embedding map in a raised card (like Fig. 1e)
rect(1390, 92, 340, 320, "#FFFFFF", extra='filter="url(#shadow)"')
text(1560, 122, "scGPT embedding", 18, 400)
centers = {"T cell": (1480, 210), "Monocyte": (1640, 200), "B cell": (1500, 330), "NK": (1650, 320)}
for name, (mx, my) in centers.items():
    for _ in range(140):
        a, rr = random.uniform(0, 2 * math.pi), abs(random.gauss(0, 1)) * 26
        x, y = mx + rr * math.cos(a) * 1.3, my + rr * math.sin(a)
        g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="2.2" fill="{CT[name]}" fill-opacity="0.75"/>')
for i, name in enumerate(CT):
    lx = [1412, 1484, 1584, 1656][i]
    g.append(f'<circle cx="{lx}" cy="395" r="6" fill="{CT[name]}"/>')
    text(lx + 10, 395, name, 13, 400, "start", TXT2)
text(1560, 440, "similar cells get similar embeddings", 15, 400, color=TXT2)

# ------------------------------------------------------------------ b
banner(70, 1670, 510, "B", "Patient classification: attention over a patient's cells (scgpt_train)", SLATE_L, TXT)
patients = [("Patient 1", ["T cell", "T cell", "Monocyte", "B cell"], [0.15, 0.2, 0.55, 0.1], 0.82, "PR"),
            ("Patient 2", ["Monocyte", "T cell", "NK", "T cell"], [0.4, 0.15, 0.35, 0.1], 0.71, "PR"),
            ("Patient 3", ["T cell", "B cell", "T cell", "NK"], [0.3, 0.25, 0.3, 0.15], 0.18, "PD")]
x_cells, x_att, x_pat, x_pred = 260, 520, 780, 1105
text(x_cells + 78, 588, "Cell embeddings", 18, 400)
text(x_att + 34, 588, "Attention", 18, 400)
text(x_pat + 78, 588, "Patient embedding", 18, 400)
text(x_pred + 40, 588, "P(positive)", 18, 400)
for k, (pname, cells, att, prob, lab) in enumerate(patients):
    y0 = 618 + k * 150
    cell(150, y0 + 52, 30)
    text(150, y0 + 100, pname, 16, 400)
    for j, ct in enumerate(cells):
        strip(x_cells, y0 + j * 27, CT[ct], n=12, w=13, h=24, seed=10 * k + j)
        rect(x_att, y0 + j * 27, 68 * att[j] / max(att), 24, SLATE)
    text(x_att + 112, y0 + 54, "×", 26, 400, color=TXT2)
    arrow(x_att + 132, y0 + 54, x_pat - 12, y0 + 54)
    strip(x_pat, y0 + 37, SLATE, n=12, w=13, h=34, seed=99 + k)
    arrow(x_pat + 168, y0 + 54, x_pred - 12, y0 + 54)
    col = POS if prob >= 0.5 else NEG
    rect(x_pred, y0 + 32, 82, 44, MUST if prob >= 0.5 else SLATE_L)
    text(x_pred + 41, y0 + 54, f"{prob:.2f}", 20, 600)
    text(x_pred + 104, y0 + 54, f"label {lab}", 18, 500, "start", col)
text(x_att + 34, 1080, "weight of each cell", 15, 400, color=TXT2)
text(x_pat + 78, 1080, "weighted average, standardized", 15, 400, color=TXT2)
# comparison card
rect(1360, 600, 370, 420, "#FFFFFF", extra='filter="url(#shadow)"')
rect(1360, 600, 370, 52, SAGE)
text(1545, 626, "scgpt_compare", 20, 600)
text(1545, 690, "same patients, same folds", 16, 400, color=TXT2)
methods = [("cell-type fractions", 0.70, SAGE_D), ("PCA of variable genes", 0.82, SLATE_L),
           ("scGPT embedding mean", 0.94, SLATE), ("trained model (panel B)", 0.86, MUST)]
for i, (m, auc, colr) in enumerate(methods):
    y = 735 + i * 62
    text(1385, y, m, 15, 400, "start")
    rect(1385, y + 14, 300 * auc, 18, colr)
    text(1385 + 300 * auc + 8, y + 23, f"{auc:.2f}", 14, 400, "start", TXT2)
for i in range(len(methods)):
    y = 735 + i * 62
    g.append(f'<line x1="{1385 + 150}" y1="{y + 9}" x2="{1385 + 150}" y2="{y + 37}" stroke="{TXT}" '
             f'stroke-width="1.4" stroke-dasharray="4 3"/>')
text(1535, 985, "dashed: 0.5 = chance", 13, 400, color=TXT2)
text(1545, 1005, "AUC on patients the model has not seen", 14, 400, color=TXT2)

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'{defs}<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + "".join(g) + "</svg>")
OUT.write_text(svg)
print(f"Written: {OUT}")
