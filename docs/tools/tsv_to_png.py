#!/usr/bin/env python3
"""Draw a TSV result table as a portal-style table image (SVG and PNG).

The portal accepts only PNG/JPEG, so summary tables (frip_summary.tsv,
atac_qc_metrics.tsv, ...) are drawn here instead of screen-captured. The
style follows the module concept figures (Pretendard, portal colours).

Usage:
  python3 docs/tools/tsv_to_png.py <table.tsv> -o <out.png>
      [--cols "SampleID=Sample,peaks=Peaks,FRiP"]   columns to show (in order), optional new header
      [--flag "FRiP:0.2,0.3"]                       colour a column by thresholds (warn,good); repeatable
      [--flag "PERCENT_DUPLICATION:0.5,0.3:lower"]  ':lower' when smaller is better
      [--title "..."] [--note "..."] (repeatable)    title above, notes below the table
      [--max-rows 30]

Numbers are right-aligned with thousands separators (5e+05 -> 500,000);
paths are shortened to the file name. A flagged value gets a coloured dot:
green = good, orange = acceptable, red = below the acceptable value.
Needs rsvg-convert and the Pretendard font for the PNG.
"""
import argparse
import csv
import math
import os
import re
import subprocess
from xml.sax.saxutils import escape

FONT = "Pretendard, sans-serif"
MAIN, SUB, POINT = "#222222", "#3A3A3A", "#32549C"
PALE, LINE = "#EEF0F3", "#D9DDE3"
GOOD, WARN, BAD = "#2E9E6B", "#F08A24", "#D6604D"
FS, ROW_H, HEAD_H, PAD = 15, 34, 38, 14


def text_width(s, size=FS):
    """Rough rendered width: CJK characters are about twice as wide."""
    w = 0.0
    for ch in s:
        if ord(ch) > 0x2E80:
            w += size * 1.0
        elif ch in "il.,:;|'":
            w += size * 0.3
        elif ch.isupper() or ch in "mwMW%":
            w += size * 0.68
        else:
            w += size * 0.56
    return w


def as_number(s):
    try:
        return float(s)
    except ValueError:
        return None


def fmt(s):
    s = s.strip()
    if "/" in s and not s.startswith("http"):
        return os.path.basename(s.rstrip("/")) or s
    v = as_number(s)
    if v is None or s.lower() in ("nan", "inf", "-inf", "na"):
        return s
    if math.isfinite(v) and v == int(v) and abs(v) >= 1 and not re.search(r"\.\d*[1-9]", s):
        return f"{int(v):,}"
    if abs(v) >= 1000:
        return f"{v:,.1f}"
    dec = len(s.split(".")[1]) if "." in s and "e" not in s.lower() else 3
    return f"{v:.{min(max(dec, 1), 4)}f}"


def parse_flags(items):
    flags = {}
    for it in items or []:
        name, rest = it.split(":", 1)
        parts = rest.split(":")
        warn, good = (float(x) for x in parts[0].split(","))
        flags[name] = (warn, good, len(parts) > 1 and parts[1] == "lower")
    return flags


def flag_colour(v, rule):
    warn, good, lower = rule
    if v is None:
        return None
    if lower:
        return GOOD if v <= good else WARN if v <= warn else BAD
    return GOOD if v >= good else WARN if v >= warn else BAD


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("tsv")
    ap.add_argument("-o", "--out", required=True)
    ap.add_argument("--cols")
    ap.add_argument("--flag", action="append")
    ap.add_argument("--title")
    ap.add_argument("--note", action="append")
    ap.add_argument("--max-rows", type=int, default=40)
    a = ap.parse_args()

    with open(a.tsv, newline="") as fh:
        rows = [r for r in csv.reader(fh, delimiter="\t") if r and not r[0].startswith("#")]
    header, body = rows[0], rows[1:]
    if a.cols:
        pick = [c.split("=", 1) for c in a.cols.split(",")]
        idx = [header.index(c[0]) for c in pick]
        labels = [c[1] if len(c) > 1 else c[0] for c in pick]
        names = [c[0] for c in pick]
    else:
        idx, labels, names = list(range(len(header))), header, header
    flags = parse_flags(a.flag)
    shown = body[:a.max_rows]
    cells = [[fmt(r[i]) if i < len(r) else "" for i in idx] for r in shown]
    numeric = [all(as_number(r[i]) is not None for r in shown if i < len(r) and r[i].strip()) for i in idx]

    dot = 18
    widths = []
    for k, lab in enumerate(labels):
        w = max([text_width(lab, FS) * 1.05] + [text_width(c[k]) for c in cells])
        widths.append(w + 2 * PAD + (dot if names[k] in flags else 0))
    table_w = sum(widths)
    top = 20 + (40 if a.title else 0)
    table_h = HEAD_H + ROW_H * len(cells)
    notes = list(a.note or [])
    if len(body) > a.max_rows:
        notes.insert(0, f"{len(body) - a.max_rows} more rows not shown ({len(body)} in total)")
    W = int(table_w + 40)
    H = int(top + table_h + 18 + 24 * len(notes) + 16)

    out = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
           f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>']

    def t(x, y, s, size=FS, weight=500, color=MAIN, anchor="start"):
        return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
                f'fill="{color}" text-anchor="{anchor}" dominant-baseline="middle">{escape(s)}</text>')

    x0 = 20
    if a.title:
        out.append(t(x0, 32, a.title, 18, 700, MAIN))
    out.append(f'<rect x="{x0}" y="{top}" width="{table_w:.1f}" height="{HEAD_H}" rx="4" fill="{PALE}"/>')
    x = x0
    for k, lab in enumerate(labels):
        if numeric[k]:
            out.append(t(x + widths[k] - PAD, top + HEAD_H / 2, lab, FS, 700, SUB, "end"))
        else:
            out.append(t(x + PAD, top + HEAD_H / 2, lab, FS, 700, SUB))
        x += widths[k]
    for r, row in enumerate(cells):
        y = top + HEAD_H + r * ROW_H
        out.append(f'<line x1="{x0}" y1="{y + ROW_H:.1f}" x2="{x0 + table_w:.1f}" y2="{y + ROW_H:.1f}" '
                   f'stroke="{LINE}" stroke-width="1"/>')
        x = x0
        for k, val in enumerate(row):
            colour = flag_colour(as_number(shown[r][idx[k]]), flags[names[k]]) if names[k] in flags else None
            if numeric[k]:
                out.append(t(x + widths[k] - PAD, y + ROW_H / 2, val, FS, 600 if colour else 500,
                             colour or MAIN, "end"))
                if colour:
                    tw = text_width(val)
                    out.append(f'<circle cx="{x + widths[k] - PAD - tw - 12:.1f}" cy="{y + ROW_H / 2:.1f}" '
                               f'r="5" fill="{colour}"/>')
            else:
                out.append(t(x + PAD, y + ROW_H / 2, val, FS, 500, MAIN))
            x += widths[k]
    y = top + table_h + 24
    for n in notes:
        out.append(t(x0, y, n, 13, 500, SUB))
        y += 24
    out.append("</svg>")

    svg_path = os.path.splitext(a.out)[0] + ".svg"
    with open(svg_path, "w") as fh:
        fh.write("".join(out))
    subprocess.run(["rsvg-convert", "-z", "2", svg_path, "-o", a.out], check=True)
    print(a.out)


if __name__ == "__main__":
    main()
