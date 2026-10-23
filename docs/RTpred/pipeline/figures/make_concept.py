#!/usr/bin/env python3
"""RTpred concept figure (SVG): structures -> descriptors -> model -> predicted RT, and how
predicted RT narrows candidate annotations of an LC-MS peak.

Drawn from scratch (no published figure used); structures, RTs and the window are schematic.
Run: python3 docs/RTpred/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/RTpred/pipeline/figures/concept.svg -o docs/RTpred/pipeline/figures/concept.png
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 800
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT = "#222222", "#3A3A3A", "#32549C"
KEEP, DROP, PEAK = "#2E9E6B", "#C0504D", "#5B6573"
g = []


def text(x, y, s, size=22, weight=500, anchor="middle", color=TXT):
    g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" '
             f'font-weight="{weight}" fill="{color}" dominant-baseline="middle">{s}</text>')


def box(x, y, w, h, title, lines, color=POINT):
    g.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="14" fill="#F4F6FA" stroke="{color}" stroke-width="3"/>')
    text(x + w / 2, y + 34, title, 22, 700, "middle", color)
    for i, t in enumerate(lines):
        text(x + w / 2, y + 74 + i * 30, t, 18, 500, "middle", TXT2)


def arrow(x0, y0, x1, y1):
    g.append(f'<path d="M{x0},{y0} L{x1},{y1}" stroke="{TXT2}" stroke-width="3" marker-end="url(#ar)"/>')


# (A) prediction
text(40, 40, "A", 30, 800, "start", POINT)
text(80, 40, "Retention time is predicted from structure", 24, 700, "start")
box(40, 80, 330, 190, "Compound", ["SMILES", "O=C(O)c1ccccc1", "RP or HILIC"])
box(450, 80, 330, 190, "RDKit descriptors", ["mass, polarity (logP),", "rings, H-bond donors ...", "one row per compound"])
box(860, 80, 330, 190, "Trained model", ["AutoGluon ensemble", "default (bundled) or", "user model (rtpred_train)"])
box(1270, 80, 330, 190, "Predicted RT", ["predicted_rt per row", "ΔRT = measured - predicted", "when RT is given"], KEEP)
for x in (370, 780, 1190):
    arrow(x + 8, 175, x + 72, 175)

# (B) candidate filtering
text(40, 340, "B", 30, 800, "start", POINT)
text(80, 340, "Predicted RT narrows the candidates of one LC-MS peak", 24, 700, "start")
X0, X1, YB, YT = 120, 1000, 730, 420
g.append(f'<line x1="{X0}" y1="{YB}" x2="{X1}" y2="{YB}" stroke="{TXT2}" stroke-width="2"/>')
for t in range(0, 11, 2):
    x = X0 + t / 10 * (X1 - X0)
    g.append(f'<line x1="{x}" y1="{YB}" x2="{x}" y2="{YB + 8}" stroke="{TXT2}" stroke-width="2"/>')
    text(x, YB + 26, str(t), 17, 500, "middle", TXT2)
text((X0 + X1) / 2, YB + 56, "Retention time", 19, 600)
# measured peak at 5.2 and window
pk = 5.2
xp = X0 + pk / 10 * (X1 - X0)
win = 0.8
xw0, xw1 = X0 + (pk - win) / 10 * (X1 - X0), X0 + (pk + win) / 10 * (X1 - X0)
g.append(f'<rect x="{xw0}" y="{YT}" width="{xw1 - xw0}" height="{YB - YT}" fill="{KEEP}" opacity="0.10"/>')
pts = []
for i in range(0, 201):
    t = i / 20
    y = YB - 230 * math.exp(-((t - pk) / 0.22) ** 2)
    pts.append(f"{X0 + t / 10 * (X1 - X0):.1f},{y:.1f}")
g.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{PEAK}" stroke-width="4"/>')
text(xp, YB - 250, "measured LC-MS peak", 19, 700, "middle", PEAK)
text((xw0 + xw1) / 2, YT + 18, "predicted RT window", 17, 600, "middle", KEEP)
# candidates with predicted RT
cands = [("candidate 1", 1.6), ("candidate 2", 4.9), ("candidate 3", 8.3)]
for i, (name, rt) in enumerate(cands):
    x = X0 + rt / 10 * (X1 - X0)
    keep = abs(rt - pk) <= win
    c = KEEP if keep else DROP
    y = YB - 40 - i * 46
    g.append(f'<path d="M{x},{y - 13} L{x + 13},{y} L{x},{y + 13} L{x - 13},{y} Z" fill="{c}"/>')
    left = rt > 4    # labels of candidates near or right of the peak go to the left
    text(x - 22 if left else x + 22, y, name, 17, 600, "end" if left else "start", c)
# right side: candidate table
tx = 1090
text(tx, 450, "Same mass, different structures", 20, 700, "start")
rows = [("candidate 1", "1.6", "drop", DROP), ("candidate 2", "4.9", "keep", KEEP), ("candidate 3", "8.3", "drop", DROP)]
text(tx, 500, "candidate", 17, 700, "start", TXT2)
text(tx + 260, 500, "predicted RT", 17, 700, "middle", TXT2)
text(tx + 470, 500, "|ΔRT| ≤ window", 17, 700, "middle", TXT2)
for i, (n, rt, k, c) in enumerate(rows):
    y = 545 + i * 48
    g.append(f'<rect x="{tx - 10}" y="{y - 20}" width="620" height="40" rx="6" fill="#F4F6FA"/>')
    text(tx, y, n, 18, 600, "start")
    text(tx + 260, y, rt, 18, 500)
    text(tx + 470, y, k, 18, 700, "middle", c)

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<defs><marker id="ar" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto">'
       f'<path d="M0,0 L10,5 L0,10 z" fill="{TXT2}"/></marker></defs>'
       f'<rect width="{W}" height="{H}" fill="#fff"/>' + "".join(g) + "</svg>")
OUT.write_text(svg)
print(OUT)
