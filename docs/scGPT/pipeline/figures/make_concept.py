#!/usr/bin/env python3
"""scGPT pipeline concept figure (SVG).

A: drawn from scratch (no CC BY figure shows a frozen single-cell foundation model turning a
   cell into an embedding; the scGPT paper, Cui et al. 2024 Nat Methods, has no open licence).
B: redrawn and simplified from Do & Lahdesmaki, Bioinformatics 2025, 41(Suppl 1):i96-i104,
   Figure 1 (CC BY 4.0, doi:10.1093/bioinformatics/btaf241): only the cell-level attention is
   kept (the cell-type level is removed), and the patient label and the comparison are added.
Values are schematic.
Run: python3 docs/scGPT/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/scGPT/pipeline/figures/concept.svg -o docs/scGPT/pipeline/figures/concept.png
"""
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 1060
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT, LINE = "#222222", "#5A5A5A", "#32549C", "#8A8F98"
CT = {"T cell": "#4C9BE8", "Monocyte": "#F2B134", "B cell": "#6BBF59", "NK": "#CC79A7"}
POS, NEG = "#D55E00", "#0072B2"
g = []
random.seed(11)


def text(x, y, s, size=20, weight=500, anchor="middle", color=TXT):
    g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" '
             f'font-weight="{weight}" fill="{color}" dominant-baseline="middle">{s}</text>')


def rect(x, y, w, h, fill, stroke="none", sw=0, rx=0):
    g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" stroke="{stroke}" '
             f'stroke-width="{sw}"/>')


def arrow(x1, y1, x2, y2, color=LINE, sw=3):
    g.append(f'<line x1="{x1}" y1="{y1}" x2="{x2 - 10}" y2="{y2}" stroke="{color}" stroke-width="{sw}"/>'
             f'<path d="M{x2},{y2} l-14,-8 v16 z" fill="{color}"/>')


def panel_label(y, letter, title):
    text(40, y, letter, 30, 800, "start", POINT)
    text(80, y, title, 24, 700, "start")


def embedding(x, y, color, n=12, w=14, h=34, seed=0):
    """A cell embedding as a strip of shaded boxes; the colour tints the strip by cell type."""
    rnd = random.Random(seed)
    for i in range(n):
        op = 0.25 + 0.75 * rnd.random()
        rect(x + i * w, y, w - 1, h, color)
        g[-1] = g[-1].replace("/>", f' fill-opacity="{op:.2f}"/>')
    rect(x, y, n * w - 1, h, "none", TXT2, 1)


# ------------------------------------------------------------------ A
panel_label(48, "A", "Pretrained scGPT turns each cell into an embedding (frozen, not trained here)")
# cell with gene expression
g.append(f'<circle cx="150" cy="220" r="78" fill="#EEF4FB" stroke="{CT["T cell"]}" stroke-width="3"/>')
g.append(f'<circle cx="168" cy="205" r="26" fill="#FFFFFF" stroke="{TXT2}" stroke-width="2"/>')
text(150, 322, "one cell", 19, 600)
genes = [("CD3D", 0.9), ("IL7R", 0.75), ("CD2", 0.6), ("LTB", 0.5), ("LYZ", 0.08), ("MS4A1", 0.04)]
bx, by = 280, 120
text(bx + 120, by - 18, "expressed genes (raw counts)", 18, 600, color=TXT2)
for i, (gname, v) in enumerate(genes):
    yy = by + i * 33
    text(bx + 52, yy + 13, gname, 16, 500, "end", TXT2)
    rect(bx + 62, yy, 190 * v, 24, CT["T cell"])
text(bx + 160, by + 214, "top 1,200 genes per cell", 16, 500, color=TXT2)
arrow(560, 220, 640, 220)
# scGPT box
rect(650, 140, 330, 160, "#F4F1FB", "#7B5EA7", 3, 14)
text(815, 185, "scGPT", 30, 800, color="#5B3F8C")
text(815, 225, "pretrained on 33 million", 18, 500, color=TXT2)
text(815, 250, "human cells (whole_human)", 18, 500, color=TXT2)
text(815, 280, "weights stay fixed", 18, 700, color="#5B3F8C")
arrow(990, 220, 1070, 220)
embedding(1080, 203, CT["T cell"], seed=1)
text(1163, 262, "cell embedding (512 numbers)", 18, 600)
# similar cells, similar numbers
cx0, cy0 = 1460, 205
text(1600, 100, "similar cells get similar embeddings", 18, 600, color=TXT2)
for name, (mx, my) in zip(CT, [(1470, 170), (1640, 160), (1520, 300), (1690, 280)]):
    for _ in range(26):
        x = mx + random.gauss(0, 22)
        y = my + random.gauss(0, 18)
        g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="5" fill="{CT[name]}" fill-opacity="0.85"/>')
for i, name in enumerate(CT):
    lx = 1405 + i * 100
    g.append(f'<circle cx="{lx}" cy="372" r="7" fill="{CT[name]}"/>')
    text(lx + 12, 372, name, 15, 500, "start", TXT2)

g.append(f'<line x1="40" y1="415" x2="{W - 40}" y2="415" stroke="#DDDDDD" stroke-width="2"/>')

# ------------------------------------------------------------------ B
panel_label(460, "B", "Attention over a patient's cells gives one prediction per patient (scgpt_train)")
patients = [("patient 1", ["T cell", "T cell", "Monocyte", "B cell"], [0.15, 0.2, 0.55, 0.1], 0.82, "PR"),
            ("patient 2", ["Monocyte", "T cell", "NK", "T cell"], [0.4, 0.15, 0.35, 0.1], 0.71, "PR"),
            ("patient 3", ["T cell", "B cell", "T cell", "NK"], [0.3, 0.25, 0.3, 0.15], 0.18, "PD")]
x_cells, x_att, x_pat, x_pred = 170, 520, 790, 1150
text(x_cells + 84, 515, "cell embeddings", 18, 600, color=TXT2)
text(x_att + 30, 515, "attention", 18, 600, color=TXT2)
text(x_pat + 84, 515, "patient embedding", 18, 600, color=TXT2)
text(x_pred + 40, 515, "P(positive)", 18, 600, color=TXT2)
for k, (pname, cells, att, prob, lab) in enumerate(patients):
    y0 = 550 + k * 150
    text(x_cells - 20, y0 + 54, pname, 18, 600, "end")
    for j, ct in enumerate(cells):
        embedding(x_cells, y0 + j * 27, CT[ct], n=12, w=14, h=24, seed=10 * k + j)
        rect(x_att, y0 + j * 27, 60 * att[j] / max(att), 24, "#7B5EA7")
    text(x_att + 120, y0 + 54, "×", 26, 700, color=TXT2)
    arrow(x_att + 140, y0 + 54, x_pat - 10, y0 + 54)
    embedding(x_pat, y0 + 37, "#7B5EA7", n=12, w=14, h=34, seed=99 + k)
    arrow(x_pat + 180, y0 + 54, x_pred - 10, y0 + 54)
    col = POS if prob >= 0.5 else NEG
    rect(x_pred, y0 + 34, 80, 40, "#FFFFFF", col, 3, 8)
    text(x_pred + 40, y0 + 54, f"{prob:.2f}", 20, 700, color=col)
    text(x_pred + 105, y0 + 54, f"label {lab}", 18, 600, "start", col)
text(x_att + 30, 1010, "weight of each cell", 16, 500, color=TXT2)
text(x_pat + 84, 1010, "weighted average, standardized", 16, 500, color=TXT2)
# comparison box
rect(1390, 560, 360, 380, "#F7F7F7", "#BBBBBB", 2, 14)
text(1570, 600, "scgpt_compare", 22, 800, color=POINT)
lines = ["Same patients, same folds:", "", "cell-type fractions", "PCA of variable genes",
         "scGPT embedding mean", "trained model (this panel)", "", "AUC on patients the model", "has not seen"]
for i, s in enumerate(lines):
    text(1570, 645 + i * 32, s, 18, 600 if i in (0, 7, 8) else 500, color=TXT if i in (0, 7, 8) else TXT2)

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + "".join(g) + "</svg>")
OUT.write_text(svg)
print(f"Written: {OUT}")
