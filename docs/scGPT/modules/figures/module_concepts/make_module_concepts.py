#!/usr/bin/env python3
"""Module concept figures for scgpt_prep, scgpt_predict and scgpt_compare (SVG).

Drawn from scratch in the style of docs/scGPT/pipeline/figures/make_concept.py: no CC BY
figure found (Europe PMC, 2026-11-11) shows a patient-level split of single-cell data, the
application of a trained attention model to new individuals, or a paired comparison of
classifiers on the same folds. Values are schematic.
Run: python3 docs/scGPT/modules/figures/module_concepts/make_module_concepts.py, then
for m in scgpt_prep scgpt_predict scgpt_compare; do
  rsvg-convert -w 1800 docs/scGPT/modules/figures/module_concepts/${m}_concept.svg \
    -o docs/scGPT/modules/figures/module_concepts/${m}_concept.png; done
"""
from pathlib import Path

HERE = Path(__file__).resolve().parent
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT, LINE = "#222222", "#5A5A5A", "#32549C", "#8A8F98"
CT = {"T cell": "#4C9BE8", "Monocyte": "#F2B134", "B cell": "#6BBF59", "NK": "#CC79A7"}
POS, NEG, PURPLE, GRAY = "#D55E00", "#0072B2", "#7B5EA7", "#BBBBBB"


class Fig:
    def __init__(self, w, h):
        self.w, self.h, self.g = w, h, []

    def text(self, x, y, s, size=20, weight=500, anchor="middle", color=TXT):
        self.g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" '
                      f'font-size="{size}" font-weight="{weight}" fill="{color}" '
                      f'dominant-baseline="middle">{s}</text>')

    def rect(self, x, y, w, h, fill, stroke="none", sw=0, rx=0, op=1):
        self.g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{rx}" fill="{fill}" '
                      f'fill-opacity="{op}" stroke="{stroke}" stroke-width="{sw}"/>')

    def circle(self, x, y, r, fill, stroke="none", sw=0):
        self.g.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{fill}" stroke="{stroke}" '
                      f'stroke-width="{sw}"/>')

    def line(self, x1, y1, x2, y2, color=LINE, sw=2, dash=""):
        d = f' stroke-dasharray="{dash}"' if dash else ""
        self.g.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" '
                      f'stroke-width="{sw}"{d}/>')

    def arrow(self, x1, y1, x2, y2, color=LINE, sw=3):
        self.line(x1, y1, x2 - 10, y2, color, sw)
        self.g.append(f'<path d="M{x2},{y2} l-14,-8 v16 z" fill="{color}"/>')

    def panel(self, y, letter, title):
        self.text(40, y, letter, 30, 800, "start", POINT)
        self.text(80, y, title, 24, 700, "start")

    def save(self, name):
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.w}" height="{self.h}" '
               f'viewBox="0 0 {self.w} {self.h}"><rect width="{self.w}" height="{self.h}" '
               f'fill="#FFFFFF"/>' + "".join(self.g) + "</svg>")
        (HERE / f"{name}_concept.svg").write_text(svg)
        print(f"Written: {HERE / (name + '_concept.svg')}")


def cells(f, x, y, colors, r=9, step=24):
    for i, c in enumerate(colors):
        f.circle(x + (i % 4) * step, y + (i // 4) * step, r, c)


# ------------------------------------------------------------------ scgpt_prep
f = Fig(1800, 980)
f.panel(48, "A", "Cells are filtered and gene names matched to the scGPT vocabulary")
# sample matrices
for k, (sid, pid) in enumerate([("S1", "P1"), ("S2", "P1"), ("S3", "P2")]):
    x = 70 + k * 150
    f.rect(x, 110, 120, 150, "#F7F7F7", GRAY, 2, 10)
    f.text(x + 60, 135, f"{sid} matrix", 17, 600)
    for i in range(5):
        for j in range(4):
            f.rect(x + 18 + j * 22, 158 + i * 18, 18, 14, POINT, op=0.15 + 0.15 * ((i + j + k) % 5))
f.text(295, 290, "count matrix per sample", 17, 500, color=TXT2)
# sample sheet
f.rect(560, 110, 330, 150, "#FFFFFF", GRAY, 2, 10)
rows = [("SampleID", "PatientID", "Label"), ("S1", "P1", "DCM"), ("S2", "P1", "DCM"), ("S3", "P2", "HCM")]
for i, r in enumerate(rows):
    for j, v in enumerate(r):
        f.text(620 + j * 105, 135 + i * 33, v, 16, 700 if i == 0 else 500,
               color=TXT if i == 0 else (POS if v == "DCM" else NEG if v == "HCM" else TXT2))
f.text(725, 290, "sample sheet: one label per individual", 17, 500, color=TXT2)
f.arrow(910, 185, 990, 185)
# QC box
f.rect(1000, 100, 360, 175, "#F4F1FB", PURPLE, 3, 14)
f.text(1180, 130, "scgpt_prep", 24, 800, color="#5B3F8C")
for i, s in enumerate(["cells: genes ≥ min_genes, mito ≤ max_mito",
                       "genes matched to scGPT vocabulary",
                       "labels checked: one per individual",
                       "coarse cell types from markers"]):
    f.text(1020, 168 + i * 27, "· " + s, 16, 500, "start", TXT2)
f.arrow(1380, 185, 1460, 185)
f.rect(1470, 125, 280, 120, "#FFFFFF", POINT, 3, 12)
f.text(1610, 165, "dataset.h5ad", 20, 700, color=POINT)
f.text(1610, 200, "cells + labels + cell types", 16, 500, color=TXT2)
f.line(40, 360, 1760, 360, "#DDDDDD", 2)

# B: individual-level folds
f.panel(405, "B", "Folds are made by individual, so one person's cells never sit on both sides")
people = [("P1", POS), ("P2", NEG), ("P3", POS), ("P4", NEG), ("P5", POS), ("P6", NEG)]
f.text(250, 470, "individuals (each a bag of cells)", 17, 600, color=TXT2)
for k, (pid, col) in enumerate(people):
    x = 90 + k * 60
    f.rect(x - 24, 495, 48, 70, "#FFFFFF", col, 2, 8)
    cells(f, x - 13, 512, [list(CT.values())[(k + i) % 4] for i in range(4)], r=5, step=9)
    f.text(x, 548, pid, 15, 700, color=col)
f.arrow(470, 530, 560, 530)
for rep in range(2):
    for fold in range(3):
        y = 470 + (rep * 3 + fold) * 70
        f.text(600, y + 25, f"repeat {rep + 1}, fold {fold + 1}", 16, 600, "start", TXT2)
        order = [0, 1, 2, 3, 4, 5] if rep == 0 else [3, 0, 5, 4, 1, 2]
        test = set(order[fold * 2:fold * 2 + 2])
        for k, (pid, col) in enumerate(people):
            x = 800 + k * 62
            inside = k in test
            f.rect(x, y + 5, 52, 40, col if inside else "#FFFFFF", col, 2, 8, op=0.85 if inside else 1)
            f.text(x + 26, y + 25, pid, 15, 700, color="#FFFFFF" if inside else col)
f.rect(1230, 520, 30, 22, POS, POS, 2, 5, op=0.85)
f.text(1272, 531, "evaluation (held out)", 17, 500, "start", TXT2)
f.rect(1230, 560, 30, 22, "#FFFFFF", POS, 2, 5)
f.text(1272, 571, "training", 17, 500, "start", TXT2)
f.text(1230, 640, "splits.tsv: every later module", 17, 600, "start")
f.text(1230, 668, "scores the same individuals", 17, 600, "start")
f.text(1230, 720, "folds keep the label ratio (stratified);", 16, 500, "start", TXT2)
f.text(1230, 746, "default 5 folds × 3 repeats; cohort-out", 16, 500, "start", TXT2)
f.text(1230, 772, "splits with two or more cohorts", 16, 500, "start", TXT2)
f.save("scgpt_prep")

# ------------------------------------------------------------------ scgpt_predict
f = Fig(1800, 820)
f.panel(48, "A", "A trained model gives each new individual a probability")
f.text(230, 115, "new individual (no label)", 18, 600, color=TXT2)
f.rect(120, 140, 220, 210, "#FFFFFF", GRAY, 2, 12)
emb_cols = [CT["T cell"], CT["Monocyte"], CT["T cell"], CT["B cell"], CT["NK"], CT["Monocyte"]]
for i, c in enumerate(emb_cols):
    for j in range(8):
        f.rect(140 + j * 22, 158 + i * 30, 20, 22, c, op=0.3 + 0.08 * ((i * 3 + j) % 8))
f.text(230, 375, "cell embeddings (same checkpoint)", 16, 500, color=TXT2)
f.arrow(360, 245, 450, 245)
f.rect(460, 165, 330, 160, "#F4F1FB", PURPLE, 3, 14)
f.text(625, 205, "trained model", 24, 800, color="#5B3F8C")
f.text(625, 245, "model.pt from scgpt_train", 17, 500, color=TXT2)
f.text(625, 275, "attention + classifier (fixed)", 17, 500, color=TXT2)
f.text(625, 302, "same standardization", 17, 500, color=TXT2)
f.arrow(810, 245, 900, 245)
# prob bar
f.text(1190, 140, "probability of the positive label", 18, 600, color=TXT2)
f.rect(920, 225, 540, 40, "#F1F1F1", GRAY, 1, 8)
f.rect(920, 225, 540 * 0.78, 40, POS, op=0.8, rx=8)
f.line(920 + 540 * 0.5, 210, 920 + 540 * 0.5, 280, TXT, 2, "6 4")
f.text(920 + 540 * 0.5, 300, "threshold 0.5", 15, 500, color=TXT)
f.text(920 + 540 * 0.78, 195, "0.78 → positive", 18, 700, color=POS)
f.text(1190, 345, "predictions.tsv: probability and call per individual", 16, 500, color=TXT2)
f.line(40, 420, 1760, 420, "#DDDDDD", 2)
f.panel(465, "B", "Attention shows which cells the model weighs most")
att = [0.10, 0.45, 0.08, 0.05, 0.07, 0.25]
f.text(250, 520, "attention per cell", 18, 600, color=TXT2)
for i, (c, a) in enumerate(zip(emb_cols, att)):
    f.circle(150, 555 + i * 34, 10, c)
    f.rect(175, 545 + i * 34, 300 * a / max(att), 20, PURPLE, op=0.8)
f.arrow(520, 640, 610, 640)
f.text(940, 520, "share per cell type (attention vs cells)", 18, 600, color=TXT2)
share = [("T cell", 0.18, 0.33), ("Monocyte", 0.70, 0.33), ("B cell", 0.05, 0.17), ("NK", 0.07, 0.17)]
for i, (name, a, c) in enumerate(share):
    y = 550 + i * 52
    f.text(760, y + 15, name, 17, 600, "end", CT[name])
    f.rect(780, y, 380 * a, 16, PURPLE, op=0.85)
    f.rect(780, y + 18, 380 * c, 12, GRAY)
f.rect(1250, 560, 26, 14, PURPLE, op=0.85)
f.text(1288, 567, "share of attention", 16, 500, "start", TXT2)
f.rect(1250, 590, 26, 12, GRAY)
f.text(1288, 596, "share of cells", 16, 500, "start", TXT2)
f.text(1250, 650, "attention_by_cell_type.tsv", 16, 600, "start")
f.text(1250, 678, "weight is not cause", 16, 500, "start", TXT2)
f.save("scgpt_predict")

# ------------------------------------------------------------------ scgpt_compare
f = Fig(1800, 900)
f.panel(48, "A", "Four methods are scored on the same individuals and the same folds")
methods = [("cell-type fractions", "fraction per cell type → logistic regression", GRAY),
           ("PCA of variable genes", "patient mean of PCs → logistic regression", "#E69F00"),
           ("scGPT embedding mean", "patient mean embedding → logistic regression", "#56B4E9"),
           ("trained model", "scgpt_train cross-validation predictions", POS)]
f.rect(70, 110, 260, 300, "#FFFFFF", GRAY, 2, 12)
f.text(200, 140, "same splits.tsv", 18, 700, color=POINT)
for k in range(6):
    col = POS if k % 2 == 0 else NEG
    f.rect(100 + (k % 3) * 70, 175 + (k // 3) * 70, 54, 46, "#FFFFFF", col, 2, 8)
    f.text(127 + (k % 3) * 70, 198 + (k // 3) * 70, f"P{k + 1}", 15, 700, color=col)
f.text(200, 345, "held-out individuals", 16, 500, color=TXT2)
f.text(200, 370, "per fold and repeat", 16, 500, color=TXT2)
for i, (name, how, col) in enumerate(methods):
    y = 120 + i * 75
    f.arrow(345, 260, 430, y + 28, LINE, 2)
    f.rect(440, y, 520, 56, "#FFFFFF", col, 3, 10)
    f.text(460, y + 19, name, 18, 700, "start", TXT)
    f.text(460, y + 41, how, 15, 500, "start", TXT2)
f.arrow(975, 260, 1050, 260)
f.text(1290, 115, "AUC (95% CI) on held-out individuals", 18, 600, color=TXT2)
aucs = [0.70, 0.82, 0.94, 0.93]
lo = [0.46, 0.64, 0.84, 0.81]
for i, ((name, _, col), a, l) in enumerate(zip(methods, aucs, lo)):
    y = 160 + i * 60
    x0, sc = 1070, 520
    f.line(x0, y, x0 + sc, y, "#EEEEEE", 18)
    f.line(x0 + sc * l, y, x0 + sc * min(1, a + (a - l) * 0.6), y, TXT2, 3)
    f.circle(x0 + sc * a, y, 10, col)
f.line(1070 + 520 * 0.5, 140, 1070 + 520 * 0.5, 360, TXT, 1.5, "6 4")
f.text(1070 + 520 * 0.5, 382, "0.5 = chance", 15, 500, color=TXT)
f.text(1070, 382, "0", 15, 500, color=TXT2)
f.text(1590, 382, "1", 15, 500, color=TXT2)
f.line(40, 450, 1760, 450, "#DDDDDD", 2)
f.panel(495, "B", "A paired bootstrap decides whether the model is better than each baseline")
f.text(300, 560, "resample individuals with replacement", 18, 600, color=TXT2)
for b in range(3):
    y = 595 + b * 60
    f.text(80, y + 18, f"bootstrap {b + 1}", 16, 600, "start", TXT2)
    for k in range(6):
        pid = [1, 3, 3, 4, 6, 2] if b == 0 else ([2, 2, 5, 1, 6, 4] if b == 1 else [5, 1, 3, 6, 6, 4])
        p = pid[k]
        col = POS if p % 2 == 1 else NEG
        f.rect(200 + k * 58, y, 48, 36, "#FFFFFF", col, 2, 7)
        f.text(224 + k * 58, y + 18, f"P{p}", 14, 700, color=col)
f.text(300, 800, "both methods scored on the same draw", 16, 500, color=TXT2)
f.arrow(570, 680, 640, 680)
f.text(1140, 560, "ΔAUC = trained model − baseline", 18, 600, color=TXT2)
cases = [("vs cell-type fractions", 0.04, 0.46, "better"),
         ("vs PCA", -0.06, 0.28, "not clearly different"),
         ("vs scGPT mean", -0.05, 0.00, "not clearly different")]
x0, sc = 920, 420
zero = x0 + sc * 0.3
for i, (name, l, h, verdict) in enumerate(cases):
    y = 610 + i * 70
    f.text(x0 - 20, y, name, 16, 600, "end", TXT)
    f.line(zero + sc * l, y, zero + sc * h, y, POS if verdict == "better" else TXT2, 4)
    f.circle(zero + sc * (l + h) / 2, y, 8, POS if verdict == "better" else TXT2)
    f.text(1440, y, verdict, 17, 700 if verdict == "better" else 500, "start",
           POS if verdict == "better" else TXT2)
f.line(zero, 585, zero, 790, TXT, 1.5, "6 4")
f.text(zero, 808, "0", 15, 600, color=TXT)
f.text(1440, 790, "interval above 0 = better", 15, 500, "start", TXT2)
f.text(1440, 815, "interval includes 0 = not clearly different", 15, 500, "start", TXT2)
f.save("scgpt_compare")
