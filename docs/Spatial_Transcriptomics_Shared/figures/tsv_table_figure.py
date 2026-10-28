#!/usr/bin/env python3
"""Draw a TSV summary table (for example hd_prep_summary.tsv) as an SVG figure for the portal.

Run: python3 docs/Spatial_Transcriptomics_Shared/figures/tsv_table_figure.py <table.tsv> <out.svg> "<title>"
then rsvg-convert -z 2 <out.svg> -o <out.png>. Numbers with four or more digits get thousands separators.
"""
import csv
import sys

FONT = "Pretendard, sans-serif"
MAIN, SUB, PALE = "#222222", "#3A3A3A", "#EEF0F3"


def fmt(v):
    return f"{int(v):,}" if v.isdigit() and len(v) >= 4 else v


def main(tsv, out, title):
    with open(tsv, newline="") as f:
        rows = list(csv.reader(f, delimiter="\t"))
    rows = [rows[0]] + [[fmt(c) for c in r] for r in rows[1:]]
    widths = [max(len(r[i]) for r in rows) * 9.5 + 34 for i in range(len(rows[0]))]
    x0, y0, rh = 20, 60, 38
    w = sum(widths) + 2 * x0
    h = y0 + rh * len(rows) + 20
    g = [f'<text x="{x0}" y="32" font-family="{FONT}" font-size="18" font-weight="700" fill="{MAIN}" '
         f'dominant-baseline="middle">{title}</text>',
         f'<rect x="{x0}" y="{y0}" width="{sum(widths):.1f}" height="{rh}" rx="4" fill="{PALE}"/>']
    numeric = [c > 0 and all(r[c].replace(",", "").replace(".", "").isdigit() for r in rows[1:])
               for c in range(len(rows[0]))]
    for r, row in enumerate(rows):
        y = y0 + rh * r + rh / 2
        x = x0
        for c, (v, cw) in enumerate(zip(row, widths)):
            num = numeric[c]
            tx, anchor = (x + cw - 14, "end") if num else (x + 14, "start")
            g.append(f'<text x="{tx:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="15" '
                     f'font-weight="{700 if r == 0 else 500}" fill="{SUB if r == 0 else MAIN}" '
                     f'text-anchor="{anchor}" dominant-baseline="middle">{v}</text>')
            x += cw
        if r > 0:
            g.append(f'<line x1="{x0}" y1="{y0 + rh * (r + 1):.1f}" x2="{x0 + sum(widths):.1f}" '
                     f'y2="{y0 + rh * (r + 1):.1f}" stroke="#DDE1E6" stroke-width="1"/>')
    with open(out, "w") as f:
        f.write(f'<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0f}" height="{h:.0f}" '
                f'viewBox="0 0 {w:.0f} {h:.0f}"><rect width="{w:.0f}" height="{h:.0f}" fill="#FFFFFF"/>'
                + "".join(g) + "</svg>")


if __name__ == "__main__":
    main(*sys.argv[1:4])
