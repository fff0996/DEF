#!/usr/bin/env python3
"""Draw a TSV summary table (for example hd_prep_summary.tsv) as an SVG figure for the portal.

Run: python3 docs/Spatial_Transcriptomics_Shared/figures/tsv_table_figure.py <table.tsv> <out.svg> "<title>" [wrap]
then rsvg-convert -z 2 <out.svg> -o <out.png>. Numbers with four or more digits get thousands separators.
With wrap (characters), longer cells are broken into lines after ", " (for value lists).
"""
import csv
import sys

FONT = "Pretendard, sans-serif"
MAIN, SUB, PALE = "#222222", "#3A3A3A", "#EEF0F3"


def fmt(v):
    return f"{int(v):,}" if v.isdigit() and len(v) >= 4 else v


def wrap_cell(v, width):
    """Split v after ', ' so that no line is longer than width (a single long item stays whole)."""
    if not width or len(v) <= width:
        return [v]
    out, cur = [], ""
    for part in v.split(", "):
        piece = part if not cur else f"{cur}, {part}"
        if cur and len(piece) > width:
            out.append(cur + ",")
            cur = part
        else:
            cur = piece
    return out + [cur]


def main(tsv, out, title, wrap=0):
    with open(tsv, newline="") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    rows = [rows[0]] + [[fmt(c) for c in r] for r in rows[1:]]
    cells = [[wrap_cell(c, wrap) for c in r] for r in rows]
    widths = [max(len(ln) for r in cells for ln in r[i]) * 9.5 + 34 for i in range(len(rows[0]))]
    x0, y0, rh, lh = 20, 60, 38, 22
    heights = [rh + lh * (max(len(c) for c in r) - 1) for r in cells]
    w = sum(widths) + 2 * x0
    h = y0 + sum(heights) + 20
    g = [f'<text x="{x0}" y="32" font-family="{FONT}" font-size="18" font-weight="700" fill="{MAIN}" '
         f'dominant-baseline="middle">{title}</text>',
         f'<rect x="{x0}" y="{y0}" width="{sum(widths):.1f}" height="{heights[0]}" rx="4" fill="{PALE}"/>']
    numeric = [c > 0 and any(r[c] for r in rows[1:]) and
               all(r[c].replace(",", "").replace(".", "").isdigit() for r in rows[1:] if r[c])
               for c in range(len(rows[0]))]
    top = y0
    for r, (row, hr) in enumerate(zip(cells, heights)):
        x = x0
        for c, (lines, cw) in enumerate(zip(row, widths)):
            tx, anchor = (x + cw - 14, "end") if numeric[c] else (x + 14, "start")
            y = top + hr / 2 - lh * (len(lines) - 1) / 2
            for i, ln in enumerate(lines):
                g.append(f'<text x="{tx:.1f}" y="{y + i * lh:.1f}" font-family="{FONT}" font-size="15" '
                         f'font-weight="{700 if r == 0 else 500}" fill="{SUB if r == 0 else MAIN}" '
                         f'text-anchor="{anchor}" dominant-baseline="middle">{ln}</text>')
            x += cw
        top += hr
        if r > 0:
            g.append(f'<line x1="{x0}" y1="{top:.1f}" x2="{x0 + sum(widths):.1f}" '
                     f'y2="{top:.1f}" stroke="#DDE1E6" stroke-width="1"/>')
    with open(out, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" '
                f'viewBox="0 0 {w:.0f} {h:.0f}"><rect width="{w:.0f}" height="{h:.0f}" fill="#FFFFFF"/>'
                + "".join(g) + "</svg>")


if __name__ == "__main__":
    a = sys.argv[1:]
    main(a[0], a[1], a[2], int(a[3]) if len(a) > 3 else 0)
