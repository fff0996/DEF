#!/usr/bin/env python3
"""ATAC-seq concept figure (SVG), redrawn in the KOBIC portal style.

Adapted from Yan F. et al., Genome Biology 21, 22 (2020), Fig. 1A
(CC BY 4.0); check the source and license before publishing.
Run: python3 docs/ATAC-seq/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/ATAC-seq/pipeline/figures/concept.svg -o docs/ATAC-seq/pipeline/figures/concept.png
(the Pretendard font gives the intended look).
"""
import math
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 630
FONT = "Pretendard, 'Noto Sans KR', sans-serif"

TXT, TXT2, POINT = "#222222", "#3A3A3A", "#32549C"      # portal colors
NUC, NUC_EDGE = "#A7ADB6", "#3A3A3A"
TN5_FILL, TF_FILL = "#C9D7F0", "#8CC3EE"
END_L, END_R = "#F08A24", "#2E9E6B"                    # Tn5 insertion ends
FOOT, BAND = "#5AA9E6", "#EEF0F3"

g = []


def text(x, y, s, size=22, weight=600, anchor="end", color=TXT):
    rows = s.split("\n")
    y0 = y - (len(rows) - 1) * size * 0.6
    for i, r in enumerate(rows):
        g.append(f'<text x="{x}" y="{y0 + i * size * 1.2}" text-anchor="{anchor}" font-family="{FONT}" '
                 f'font-size="{size}" font-weight="{weight}" fill="{color}" dominant-baseline="middle">{r}</text>')


def nucleosome(x, y, r=27):
    d = r * 0.55
    g.append(f'<circle cx="{x}" cy="{y}" r="{r}" fill="{NUC}" stroke="{NUC_EDGE}" stroke-width="4"/>'
             f'<path d="M{x - d},{y - d} L{x + d},{y + d} M{x - d},{y + d} L{x + d},{y - d}" '
             f'stroke="{NUC_EDGE}" stroke-width="5" stroke-linecap="round"/>')


def tn5(x, y, s=1.0):
    g.append(f'<g transform="translate({x},{y}) scale({s}) rotate(-35)">'
             f'<ellipse cx="0" cy="0" rx="20" ry="30" fill="{TN5_FILL}" stroke="{POINT}" stroke-width="3"/>'
             f'<ellipse cx="0" cy="0" rx="8" ry="22" fill="#fff" stroke="{POINT}" stroke-width="2" opacity="0.8"/>'
             f'<rect x="-5" y="-48" width="10" height="26" rx="4" fill="#6B4E3D"/>'
             f'<rect x="-6" y="16" width="12" height="34" rx="5" fill="{POINT}"/></g>')


def hexagon(x, y, r=24, fill=TF_FILL):
    pts = " ".join(f"{x + r * math.cos(math.radians(a))},{y + r * math.sin(math.radians(a))}"
                   for a in range(0, 360, 60))
    g.append(f'<polygon points="{pts}" fill="{fill}" stroke="{POINT}" stroke-width="3"/>')


def fragment(x0, x1, y):
    g.append(f'<rect x="{x0}" y="{y - 5}" width="{x1 - x0}" height="10" rx="2" fill="{TXT}"/>'
             f'<rect x="{x0}" y="{y - 5}" width="8" height="10" fill="{END_L}"/>'
             f'<rect x="{x1 - 8}" y="{y - 5}" width="8" height="10" fill="{END_R}"/>')


# ------------------------------------------------------------ chromatin
DNA_Y, X0, X1 = 130, 250, 1330
# coiled DNA at the left
for k, col in enumerate([TXT2, "#8A93A3"]):
    pts = []
    for i in range(0, 161):
        t = i / 160
        x = 70 + t * (X0 - 70)
        amp = 34 * (1 - t) + 2
        pts.append(f"{x:.1f},{DNA_Y + amp * math.sin(t * 6 * math.pi + k * math.pi):.1f}")
    g.append(f'<polyline points="{" ".join(pts)}" fill="none" stroke="{col}" stroke-width="5"/>')
g.append(f'<line x1="{X0}" y1="{DNA_Y}" x2="{X1}" y2="{DNA_Y}" stroke="{TXT2}" stroke-width="5"/>')

for x in (300, 365, 430, 700, 920):
    nucleosome(x, DNA_Y - 30)
regions = [(505, 640), (752, 865), (975, 1225)]
for (a, b), tx in zip(regions, (545, 780, 1010)):
    tn5(tx, DNA_Y - 40)
hexagon(1120, DNA_Y - 28)
# TSS arrow and gene
g.append(f'<path d="M1240,{DNA_Y} V45 H1340" fill="none" stroke="{TXT}" stroke-width="9"/>'
         f'<path d="M1335,28 L1368,45 L1335,62 Z" fill="{TXT}"/>'
         f'<rect x="1258" y="{DNA_Y - 26}" width="80" height="44" rx="4" fill="{POINT}" opacity="0.9"/>')

# dashed guides from the open regions down to the peak track
for a, b in regions:
    for x in (a, b):
        g.append(f'<line x1="{x}" y1="{DNA_Y + 8}" x2="{x}" y2="330" stroke="{TXT}" stroke-width="3" stroke-dasharray="9,7"/>')
for x in (1095, 1148):
    g.append(f'<line x1="{x}" y1="{DNA_Y + 8}" x2="{x}" y2="330" stroke="{END_L}" stroke-width="3" stroke-dasharray="7,6"/>')

# ------------------------------------------------------------ NFR density
BASE = 330
g.append(f'<path d="M230,{BASE} H{X1 + 10} M230,{BASE} V170" stroke="{TXT}" stroke-width="3" fill="none"/>'
         f'<path d="M222,178 L230,160 L238,178 Z" fill="{TXT}"/>')
text(205, 250, "NFR fragments\ndensity", 21)
bars = {
    0: [18, 34, 50, 62, 56, 44, 30, 16],
    1: [12, 20, 28, 36, 30, 22, 14],
    2: [22, 40, 62, 86, 110, 122, 70, 46, 58, 66, 74, 128, 112, 86, 58, 30, 18],
}
for idx, (a, b) in enumerate(regions):
    hs = bars[idx]
    step = (b - a - 16) / len(hs)
    for i, h in enumerate(hs):
        x = a + 8 + i * step
        g.append(f'<rect x="{x:.1f}" y="{BASE - h}" width="{step * 0.62:.1f}" height="{h}" fill="{TXT}"/>')

# ------------------------------------------------------------ fragment tracks
g.append(f'<rect x="230" y="360" width="{X1 - 220}" height="98" fill="{BAND}"/>'
         f'<rect x="230" y="470" width="{X1 - 220}" height="78" fill="{BAND}"/>')
text(205, 409, "NFR fragments", 21)
text(205, 509, "Mononucleosome\nfragments", 21)
for (x0, x1, y) in [(512, 610, 378), (520, 628, 398), (515, 600, 418), (530, 636, 438),
                    (760, 830, 383), (765, 850, 408), (775, 842, 433),
                    (985, 1095, 376), (1000, 1210, 394), (1010, 1090, 412), (1150, 1222, 412),
                    (1030, 1215, 430), (1060, 1205, 448)]:
    fragment(x0, x1, y)
for (x0, x1, y) in [(600, 780, 488), (612, 790, 508), (622, 772, 528),
                    (840, 1000, 493), (852, 1012, 513), (860, 990, 533)]:
    fragment(x0, x1, y)

# ------------------------------------------------------------ peaks
text(205, 590, "Peaks", 21)
for a, b in regions:
    g.append(f'<rect x="{a}" y="582" width="{b - a}" height="14" fill="{TXT}"/>')
g.append(f'<rect x="1095" y="582" width="53" height="14" fill="{FOOT}"/>')

# ------------------------------------------------------------ legend
LX = 1450
items = [("gene", "Gene"), ("tf", "Transcription factor"), ("nuc", "Nucleosome"),
         ("tn5", "Transposase Tn5"), ("peak", "Peak"), ("foot", "Footprint"),
         ("ends", "Tn5 insertion ends")]
for i, (k, label) in enumerate(items):
    y = 70 + i * 66
    if k == "gene":
        g.append(f'<rect x="{LX - 28}" y="{y - 18}" width="56" height="36" rx="4" fill="{POINT}" opacity="0.9"/>')
    elif k == "tf":
        hexagon(LX, y, 21)
    elif k == "nuc":
        nucleosome(LX, y, 22)
    elif k == "tn5":
        tn5(LX, y + 4, 0.7)
    elif k == "peak":
        g.append(f'<rect x="{LX - 28}" y="{y - 7}" width="56" height="14" fill="{TXT}"/>')
    elif k == "foot":
        g.append(f'<rect x="{LX - 28}" y="{y - 7}" width="56" height="14" fill="{FOOT}"/>')
    else:
        fragment(LX - 28, LX + 28, y)
    text(LX + 52, y, label, 22, 500, "start", TXT2)

doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + "".join(g) +
       f'</svg>')
OUT.write_text(doc)
print(OUT)
