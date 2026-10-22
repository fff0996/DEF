#!/usr/bin/env python3
"""CNV concept figure (SVG): allele states, depth ratio, B-allele frequency and calls.

Drawn from scratch (no published figure used). Values are schematic: a tumor with
purity 0.8, ratios centred on the 2/1 state, as cnvkit_call does with FACETS.
Run: python3 docs/CNV/pipeline/figures/make_concept.py, then
rsvg-convert -w 1800 docs/CNV/pipeline/figures/concept.svg -o docs/CNV/pipeline/figures/concept.png
"""
import math
import random
from pathlib import Path

OUT = Path(__file__).resolve().parent / "concept.svg"
W, H = 1800, 950
FONT = "Pretendard, 'Noto Sans KR', sans-serif"
TXT, TXT2, POINT = "#222222", "#3A3A3A", "#32549C"
# call colours of cnvkit_call / cnv_summary
COL = {"AMP": "#B2182B", "GAIN": "#EF8A62", "NEUTRAL": "#7F7F7F", "LOSS": "#67A9CF", "DEEPDEL": "#2166AC"}
LOH = "#CC79A7"
MAJOR, MINOR = "#5B6573", "#F2B134"   # allele boxes
PURITY = 0.8

# total CN, minor CN, call, name
SEGS = [(2, 1, "NEUTRAL", "2/1"), (3, 1, "GAIN", "3/1"), (1, 0, "LOSS", "1/0"),
        (2, 0, "NEUTRAL", "2/0"), (0, 0, "DEEPDEL", "0/0"), (5, 1, "AMP", "5/1")]
X0, X1 = 260, 1740
SW = (X1 - X0) / len(SEGS)
g = []
random.seed(7)


def text(x, y, s, size=22, weight=500, anchor="middle", color=TXT):
    g.append(f'<text x="{x}" y="{y}" text-anchor="{anchor}" font-family="{FONT}" font-size="{size}" '
             f'font-weight="{weight}" fill="{color}" dominant-baseline="middle">{s}</text>')


def panel_label(y, letter, title):
    text(40, y, letter, 30, 800, "start", POINT)
    text(80, y, title, 24, 700, "start")


def axis(y0, y1, ticks, label):
    g.append(f'<line x1="{X0}" y1="{y0}" x2="{X0}" y2="{y1}" stroke="{TXT2}" stroke-width="2"/>'
             f'<line x1="{X0}" y1="{y1}" x2="{X1}" y2="{y1}" stroke="{TXT2}" stroke-width="2"/>')
    for v, yy in ticks:
        g.append(f'<line x1="{X0 - 8}" y1="{yy}" x2="{X0}" y2="{yy}" stroke="{TXT2}" stroke-width="2"/>')
        text(X0 - 14, yy, v, 17, 500, "end", TXT2)
    g.append(f'<text transform="translate({X0 - 75},{(y0 + y1) / 2}) rotate(-90)" text-anchor="middle" '
             f'font-family="{FONT}" font-size="19" font-weight="600" fill="{TXT}">{label}</text>')


def log2r(cn):
    return math.log2((PURITY * cn + 2 * (1 - PURITY)) / 2)


def baf(cn, nb):
    return (PURITY * nb + (1 - PURITY)) / (PURITY * cn + 2 * (1 - PURITY))


# segment separators over all panels
for i in range(1, len(SEGS)):
    x = X0 + i * SW
    g.append(f'<line x1="{x}" y1="150" x2="{x}" y2="900" stroke="#C8CDD4" stroke-width="2" stroke-dasharray="6,6"/>')

# (A) allele states
panel_label(60, "A", "Tumor genome: copies of each allele per segment")
for i, (cn, nb, call, name) in enumerate(SEGS):
    cx = X0 + (i + 0.5) * SW
    na = cn - nb
    boxes = [MAJOR] * na + [MINOR] * nb
    bw, gap = 30, 6
    total = len(boxes) * bw + max(0, len(boxes) - 1) * gap
    for k, c in enumerate(boxes):
        bx = cx - total / 2 + k * (bw + gap)
        g.append(f'<rect x="{bx}" y="125" width="{bw}" height="52" rx="5" fill="{c}"/>')
    if cn == 0:
        text(cx, 151, "no copy", 19, 600, "middle", TXT2)
    text(cx, 205, f"{name}", 22, 700)
text(X0 - 14, 151, "alleles", 19, 600, "end", TXT2)
g.append(f'<rect x="{X1 - 330}" y="46" width="22" height="22" rx="4" fill="{MAJOR}"/>')
text(X1 - 300, 58, "major allele", 18, 500, "start", TXT2)
g.append(f'<rect x="{X1 - 170}" y="46" width="22" height="22" rx="4" fill="{MINOR}"/>')
text(X1 - 140, 58, "minor allele", 18, 500, "start", TXT2)

# (B) copy ratio
yb0, yb1 = 270, 470
panel_label(245, "B", "Depth ratio to the normal reference (CNVkit)")
lo, hi = -2.6, 1.6
ymap = lambda v: yb1 - (v - lo) / (hi - lo) * (yb1 - yb0)
axis(yb0, yb1, [(f"{v:g}", ymap(v)) for v in (-2, -1, 0, 1)], "Copy ratio (log2, centred)")
g.append(f'<line x1="{X0}" y1="{ymap(0)}" x2="{X1}" y2="{ymap(0)}" stroke="#9AA1AB" stroke-width="1.5" stroke-dasharray="4,5"/>')
for i, (cn, nb, call, name) in enumerate(SEGS):
    v = log2r(cn)
    for _ in range(46):
        x = X0 + i * SW + 10 + random.random() * (SW - 20)
        y = ymap(v + random.gauss(0, 0.17))
        g.append(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="3.2" fill="#9AA1AB" opacity="0.75"/>')
    g.append(f'<line x1="{X0 + i * SW + 6}" y1="{ymap(v)}" x2="{X0 + (i + 1) * SW - 6}" y2="{ymap(v)}" '
             f'stroke="{COL[call]}" stroke-width="7" stroke-linecap="round"/>')

# (C) B-allele frequency
yc0, yc1 = 560, 740
panel_label(535, "C", "B-allele frequency of heterozygous SNPs (FACETS)")
ymapc = lambda v: yc1 - v * (yc1 - yc0)
axis(yc0, yc1, [(f"{v:g}", ymapc(v)) for v in (0, 0.5, 1)], "Tumor BAF")
for i, (cn, nb, call, name) in enumerate(SEGS):
    if nb == 0 and cn - nb > 0:
        g.append(f'<rect x="{X0 + i * SW + 2}" y="{yc0}" width="{SW - 4}" height="{yc1 - yc0}" fill="{LOH}" opacity="0.13"/>')
    b = baf(cn, nb) if cn > 0 else 0.5
    for _ in range(40):
        x = X0 + i * SW + 10 + random.random() * (SW - 20)
        v = b if random.random() < 0.5 else 1 - b
        v = min(0.99, max(0.01, v + random.gauss(0, 0.04 if cn > 0 else 0.12)))
        g.append(f'<circle cx="{x:.1f}" cy="{ymapc(v):.1f}" r="3.2" fill="{POINT}" opacity="0.55"/>')

# (D) calls
panel_label(810, "D", "Integer copy number and call (purity, ploidy and LOH from FACETS)")
for i, (cn, nb, call, name) in enumerate(SEGS):
    x = X0 + i * SW + 6
    g.append(f'<rect x="{x}" y="845" width="{SW - 12}" height="46" rx="8" fill="{COL[call]}"/>')
    text(x + (SW - 12) / 2, 868, f"CN {cn}  {call}", 20, 700, "middle", "#fff")
    if nb == 0 and cn > 0:
        g.append(f'<rect x="{x}" y="899" width="{SW - 12}" height="14" rx="4" fill="{LOH}"/>')
text(X0 - 14, 868, "call", 19, 600, "end", TXT2)
text(X0 - 14, 906, "LOH", 19, 600, "end", LOH)

svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<rect width="{W}" height="{H}" fill="#fff"/>' + "".join(g) + "</svg>")
OUT.write_text(svg)
print(OUT)
