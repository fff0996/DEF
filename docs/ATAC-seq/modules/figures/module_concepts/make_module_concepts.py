#!/usr/bin/env python3
"""Concept figures for the ATAC-seq modules, one drawing per module, in the
style of docs/ATAC-seq/pipeline/figures/concept.svg (KOBIC portal font and colors).

Run: python3 docs/ATAC-seq/modules/figures/module_concepts/make_module_concepts.py, then
rsvg-convert -w 1600 <name>.svg -o <name>.png (needs the Pretendard font).
Values in the drawings are schematic, not data.
"""
import math
import random
from pathlib import Path
from xml.sax.saxutils import escape

OUT = Path(__file__).resolve().parent
W, H = 1600, 660
FONT = "Pretendard, sans-serif"
MAIN, SUB, POINT = "#222222", "#3A3A3A", "#32549C"
TINT, LIGHT, SKY = "#EAF0FA", "#C9D7F0", "#8CC3EE"
GRAY, PALE, ORANGE, GREEN = "#A7ADB6", "#EEF0F3", "#F08A24", "#2E9E6B"
# Red and blue follow the real output plots (edgeR plotMD, monaLisa heatmap, idr).
RED, BLUE = "#D6604D", "#2166AC"


# ---------------------------------------------------------------- helpers
def t(x, y, s, size=18, weight=500, color=MAIN, anchor="middle"):
    return (f'<text x="{x:.1f}" y="{y:.1f}" font-family="{FONT}" font-size="{size}" font-weight="{weight}" '
            f'fill="{color}" text-anchor="{anchor}" dominant-baseline="middle">{escape(s)}</text>')


def panel(x, letter, title):
    return (f'<text x="{x}" y="40" font-family="{FONT}" font-size="26" font-weight="800" fill="{POINT}">{letter}</text>'
            + t(x + 28, 32, title, 20, 700, MAIN, "start"))


def line(x1, y1, x2, y2, color=SUB, w=3, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    return f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" stroke="{color}" stroke-width="{w}"{d}/>'


def rect(x, y, w, h, fill, rx=0, stroke=None, sw=2, op=1):
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{rx}" fill="{fill}"{s} opacity="{op}"/>'


def arrow(x1, y1, x2, y2, color=SUB, w=3):
    a = math.atan2(y2 - y1, x2 - x1)
    hx, hy = x2 - 14 * math.cos(a), y2 - 14 * math.sin(a)
    p1 = (hx + 7 * math.sin(a), hy - 7 * math.cos(a))
    p2 = (hx - 7 * math.sin(a), hy + 7 * math.cos(a))
    return (line(x1, y1, hx, hy, color, w)
            + f'<path d="M{x2:.1f},{y2:.1f} L{p1[0]:.1f},{p1[1]:.1f} L{p2[0]:.1f},{p2[1]:.1f} Z" fill="{color}"/>')


def nucleosome(x, y, r=17):
    d = r * 0.55
    return (f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{r}" fill="{GRAY}" stroke="{SUB}" stroke-width="3"/>'
            f'<path d="M{x - d:.1f},{y - d:.1f} L{x + d:.1f},{y + d:.1f} M{x - d:.1f},{y + d:.1f} L{x + d:.1f},{y - d:.1f}" '
            f'stroke="{SUB}" stroke-width="3" stroke-linecap="round"/>')


def tn5(x, y, s=0.7):
    return (f'<g transform="translate({x:.1f},{y:.1f}) scale({s}) rotate(-35)">'
            f'<ellipse rx="20" ry="30" fill="{LIGHT}" stroke="{POINT}" stroke-width="3"/>'
            f'<ellipse rx="8" ry="22" fill="#fff" stroke="{POINT}" stroke-width="2" opacity="0.8"/>'
            f'<rect x="-5" y="-48" width="10" height="26" rx="4" fill="#6B4E3D"/>'
            f'<rect x="-6" y="16" width="12" height="34" rx="5" fill="{POINT}"/></g>')


def hexagon(x, y, r=18, fill=SKY):
    pts = " ".join(f"{x + r * math.cos(math.radians(a)):.1f},{y + r * math.sin(math.radians(a)):.1f}"
                   for a in range(0, 360, 60))
    return f'<polygon points="{pts}" fill="{fill}" stroke="{POINT}" stroke-width="3"/>'


def frag(x0, x1, y, color=MAIN, h=8):
    return (rect(x0, y - h / 2, x1 - x0, h, color, 2) + rect(x0, y - h / 2, 6, h, ORANGE)
            + rect(x1 - 6, y - h / 2, 6, h, GREEN))


def poly(points, color, w=3, dash=None, fill="none"):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in points)
    return f'<polyline points="{pts}" fill="{fill}" stroke="{color}" stroke-width="{w}"{d}/>'


def axes(x, y, w, h, xlab, ylab):
    return (line(x, y, x, y + h, SUB, 2.5) + line(x, y + h, x + w, y + h, SUB, 2.5)
            + t(x + w / 2, y + h + 24, xlab, 15, 600, SUB) +
            f'<text x="{x - 22:.1f}" y="{y + h / 2:.1f}" font-family="{FONT}" font-size="15" font-weight="600" '
            f'fill="{SUB}" text-anchor="middle" transform="rotate(-90 {x - 22:.1f} {y + h / 2:.1f})">{escape(ylab)}</text>')


def svg(body):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'<rect width="{W}" height="{H}" fill="#FFFFFF"/>' + body + "</svg>")


def table(x, y, header, rows, widths, hl=None):
    """Small text table drawn like a TSV preview; hl maps row index to a text color."""
    out = rect(x, y, sum(widths), 34, PALE, 4)
    cx = x
    for h, wd in zip(header, widths):
        out += t(cx + 10, y + 17, h, 14, 700, SUB, "start")
        cx += wd
    for r, row in enumerate(rows):
        yy = y + 34 + r * 32
        out += line(x, yy + 32, x + sum(widths), yy + 32, PALE, 1.5)
        cx = x
        for v, wd in zip(row, widths):
            out += t(cx + 10, yy + 16, v, 14, 600, (hl or {}).get(r, MAIN), "start")
            cx += wd
    return out


def legend(x, y, items):
    out = ""
    for i, (kind, color, label) in enumerate(items):
        yy = y + i * 28
        if kind == "box":
            out += rect(x, yy - 8, 26, 16, color, 3)
        elif kind == "line":
            out += line(x, yy, x + 26, yy, color, 3)
        elif kind == "dash":
            out += line(x, yy, x + 26, yy, color, 3, "7,5")
        elif kind == "dot":
            out += f'<circle cx="{x + 13}" cy="{yy}" r="7" fill="{color}"/>'
        out += t(x + 36, yy, label, 15, 500, SUB, "start")
    return out



# ---------------------------------------------------------------- 0. bowtie2
def bowtie2():
    g = [panel(40, "A", "Reference index")]
    g.append(rect(70, 110, 170, 60, TINT, 8, POINT) + t(155, 140, "genome.fa", 17, 700, POINT))
    g.append(arrow(155, 175, 155, 245, SUB, 3) + t(170, 210, "bowtie2-build", 15, 700, SUB, "start"))
    for k in range(6):
        name = f"genome.fa.{k + 1}.bt2" if k < 4 else f"genome.fa.rev.{k - 3}.bt2"
        g.append(rect(70, 255 + k * 40, 230, 32, PALE, 6) + t(84, 271 + k * 40, name, 14, 600, MAIN, "start"))
    g.append(t(70, 520, "Built beside the FASTA when no index exists;", 14, 500, SUB, "start"))
    g.append(t(70, 544, "an existing index prefix is used as is", 14, 500, SUB, "start"))

    g.append(panel(380, "B", "Paired-end alignment"))
    y = 300
    g.append(line(410, y, 900, y, SUB, 5) + t(410, y + 30, "reference", 14, 600, SUB, "start"))
    g.append(t(420, 120, "R1", 16, 800, POINT) + t(870, 120, "R2", 16, 800, ORANGE))
    g.append(rect(445, 140, 120, 14, POINT, 3) + rect(745, 140, 120, 14, ORANGE, 3))
    g.append(arrow(505, 162, 520, y - 18, GRAY, 2) + arrow(805, 162, 790, y - 18, GRAY, 2))
    g.append(arrow(470, y - 10, 590, y - 10, POINT, 4) + arrow(840, y - 10, 720, y - 10, ORANGE, 4))
    g.append(line(470, y + 60, 840, y + 60, MAIN, 2) + line(470, y + 50, 470, y + 70, MAIN, 2) + line(840, y + 50, 840, y + 70, MAIN, 2))
    g.append(t(655, y + 84, "fragment (insert) length", 14, 700, MAIN))
    g.append(rect(410, 430, 490, 120, PALE, 10))
    g.append(t(430, 458, "bowtie2 defaults: end-to-end alignment,", 14, 600, MAIN, "start"))
    g.append(t(430, 484, "concordant pairs up to 500 bp (-X 500)", 14, 600, MAIN, "start"))
    g.append(t(430, 516, "Pairs: _R1/_R2, .R1/.R2, _1/_2; unpaired → single-end", 13, 500, SUB, "start"))

    g.append(panel(960, "C", "Outputs per sample"))
    steps = [("<sample>_bowtie_paired.sam", PALE, MAIN), ("…unsorted.bam", PALE, MAIN),
             ("…sorted.bam + .bai", TINT, POINT)]
    for k, (lab, fill, col) in enumerate(steps):
        yy = 100 + k * 78
        g.append(rect(990, yy, 300, 46, fill, 8, col if k == 2 else None) + t(1140, yy + 23, lab, 15, 700, col))
        if k < 2:
            g.append(arrow(1140, yy + 50, 1140, yy + 74, SUB, 2.5))
    g.append(t(1305, 201, "post_process_bam=yes", 13, 700, ORANGE, "start") + t(1305, 221, "(samtools view, sort, index)", 13, 500, SUB, "start"))
    g.append(t(990, 365, "<sample>_bowtie.log (alignment summary, excerpt)", 14, 700, SUB, "start"))
    summary = ["10000000 reads; of these:", "  10000000 (100.00%) were paired; of these:",
               "    412000 (4.12%) aligned concordantly 0 times", "    8930000 (89.30%) aligned concordantly exactly 1 time",
               "    658000 (6.58%) aligned concordantly >1 times", "97.31% overall alignment rate"]
    g.append(rect(990, 380, 560, 190, "#fff", 6, GRAY, 1.5))
    for k, row in enumerate(summary):
        g.append(f'<text x="1004" y="{408 + k * 28}" font-family="DejaVu Sans Mono, monospace" font-size="14" '
                 f'fill="{POINT if k == 5 else MAIN}" font-weight="{700 if k == 5 else 400}" '
                 f'dominant-baseline="middle" xml:space="preserve">{escape(row)}</text>')
    return svg("".join(g))

# ---------------------------------------------------------------- 1. organellar_filter
def organellar_filter():
    g = [panel(40, "A", "Tn5 also cuts organellar DNA")]
    # cell with nucleus, mitochondria, chloroplast
    g.append(f'<rect x="60" y="80" width="460" height="460" rx="80" fill="{PALE}" stroke="{SUB}" stroke-width="3"/>')
    g.append(f'<circle cx="230" cy="300" r="120" fill="#fff" stroke="{POINT}" stroke-width="3"/>' + t(230, 200, "Nucleus", 17, 700, POINT))
    for k in range(3):
        y = 260 + k * 40
        pts = [(140 + i * 9, y + 7 * math.sin(i * 0.9)) for i in range(21)]
        g.append(poly(pts, SUB, 3))
        for j in range(4):
            g.append(nucleosome(155 + j * 45, y, 9))
    g.append(tn5(190, 222, 0.5))
    for cx, cy, name in [(420, 170, "Mitochondrion"), (420, 420, "Chloroplast")]:
        rx, ry = (70, 40) if name == "Mitochondrion" else (75, 48)
        fill = "#fff" if name == "Mitochondrion" else TINT
        g.append(f'<ellipse cx="{cx}" cy="{cy}" rx="{rx}" ry="{ry}" fill="{fill}" stroke="{SUB}" stroke-width="3"/>')
        g.append(f'<circle cx="{cx}" cy="{cy}" r="18" fill="none" stroke="{ORANGE}" stroke-width="3"/>')
        g.append(t(cx, cy + ry + 18, name, 15, 700, SUB))
        g.append(tn5(cx - 30, cy - 18, 0.45) + tn5(cx + 30, cy - 14, 0.45) + tn5(cx + 4, cy + 22, 0.45))
    g.append(t(290, 580, "Naked organellar DNA has no nucleosomes → many Tn5 cuts", 15, 600, SUB))

    g.append(panel(580, "B", "Reads per contig (idxstats)"))
    rows = [("chr1", "8,120,400", "kept"), ("chr2", "6,904,210", "kept"), ("chr3", "7,388,950", "kept"),
            ("…", "…", ""), ("Mt", "9,812,300", "removed"), ("Pt", "4,276,180", "removed")]
    g.append(table(610, 100, ["contig", "mapped reads", ""], rows, [90, 160, 110], {4: ORANGE, 5: ORANGE}))
    g.append(t(610, 360, "flagstat before / after", 15, 700, SUB, "start"))
    g.append(table(610, 380, ["", "before", "after"], [("mapped", "36,502,040", "22,413,560")], [90, 140, 130]))
    g.append(t(610, 500, "Files: 01_stats/ (idxstats, flagstat),", 14, 500, SUB, "start"))
    g.append(t(610, 524, "04_summary/organellar_filter_summary.tsv", 14, 500, SUB, "start"))

    g.append(panel(1000, "C", "Contigs matched by organellar_pattern"))
    rows = [("1", False), ("2", False), ("3", False), ("4", False), ("5", False), ("Mt", True), ("Pt", True)]
    for i, (name, org) in enumerate(rows):
        y = 110 + i * 52
        g.append(rect(1040, y, 200, 40, TINT if not org else "#FDEBD9", 6, POINT if not org else ORANGE))
        g.append(t(1140, y + 20, f"contig {name}", 17, 600, MAIN))
        if org:
            g.append(line(1050, y + 20, 1230, y + 20, ORANGE, 3))
            g.append(t(1260, y + 20, "removed", 16, 700, ORANGE, "start"))
        else:
            g.append(t(1260, y + 20, "kept", 16, 600, POINT, "start"))
    g.append(t(1040, 500, "pattern (case-insensitive):", 15, 600, SUB, "start"))
    g.append(t(1040, 526, "^chrM$ | ^MT$ | mitochond… | chloroplast | ^Pt$ | ^chrC$", 15, 500, SUB, "start"))
    g.append(t(1040, 560, "Filtered BAM keeps nuclear reads only", 15, 600, POINT, "start"))
    return svg("".join(g))


# ---------------------------------------------------------------- 2. ATAC_QC
def atac_qc():
    g = [panel(40, "A", "Fragments by nucleosome occupancy")]
    y = 140
    g.append(line(60, y, 560, y, SUB, 4))
    # Tn5 cuts open DNA at 105, 285, 315 and 505; nucleosomes sit between them
    for x in [195, 380, 435]:
        g.append(nucleosome(x, y - 18))
    for x in [105, 300, 505]:
        g.append(tn5(x, y - 28, 0.5))
    for x in [105, 285, 315, 505]:
        g.append(line(x, y + 6, x, 400, GRAY, 1.5, "4,4"))
    rows = [("NFR", 285, 315, POINT), ("NFR", 505, 555, POINT), ("Mononucleosome", 105, 285, SUB),
            ("Dinucleosome", 315, 505, MAIN)]
    for i, (lab, a, b, col) in enumerate(rows):
        yy = 210 + i * 44
        g.append(frag(a, b, yy, col))
        g.append(t(570, yy, lab, 15, 600, col, "start"))
    g.append(t(310, 470, "Short fragments: open DNA between nucleosomes (NFR)", 15, 500, SUB))
    g.append(t(310, 496, "Longer fragments span one or more nucleosomes", 15, 500, SUB))

    g.append(panel(720, "B", "Fragment size distribution"))
    x0, y0, w, h = 780, 110, 420, 330
    g.append(axes(x0, y0, w, h, "Fragment length (bp)", "Normalized read density"))

    def dens(L):
        base = (1.0 * math.exp(-((L - 60) / 30) ** 2) + 0.5 * math.exp(-((L - 200) / 35) ** 2)
                + 0.2 * math.exp(-((L - 390) / 45) ** 2) + 0.08 * math.exp(-((L - 590) / 55) ** 2))
        ripple = 1 + 0.12 * math.sin(2 * math.pi * L / 10.5) * math.exp(-L / 260)   # ~10.5 bp helical pitch
        return base * ripple
    pts = [(x0 + i / 400 * w, y0 + h - dens(20 + i * 1.75) * (h - 30)) for i in range(401)]
    g.append(poly(pts, POINT, 2.5))
    # log-scale inset, as in ATACseqQC Fig. 1a
    ix, iy, iw, ih = x0 + 200, y0 + 10, 200, 120
    g.append(rect(ix, iy, iw, ih, "#fff", 0, SUB, 1.5))
    lp = [(ix + 8 + i / 100 * (iw - 16), iy + 10 + (1 - (math.log10(dens(20 + i * 7) + 1e-3) + 3) / 3.1) * (ih - 20))
          for i in range(101)]
    g.append(poly(lp, SUB, 2) + t(ix + iw / 2, iy + ih + 14, "log scale", 13, 600, SUB))
    for L, lab, yy in [(60, "NFR (<100 bp)", 0.05), (200, "mono (~200)", 0.48), (390, "di", 0.76), (590, "tri", 0.9)]:
        g.append(t(x0 + (L - 20) / 700 * w + (60 if lab.startswith("NFR") else 0), y0 + h * yy, lab, 14, 700, MAIN))
    g.append(t(x0 + w / 2, y0 + h + 60, "Nucleosome periodicity of ~200 bp = good library", 15, 600, POINT))

    g.append(panel(1240, "C", "Tn5 shift"))
    cx = 1400
    g.append(line(1270, 200, 1560, 200, SUB, 4) + line(1270, 230, 1560, 230, SUB, 4))
    g.append(t(1262, 200, "+", 18, 700, SUB, "end") + t(1262, 230, "−", 18, 700, SUB, "end"))
    g.append(rect(cx - 40, 188, 80, 54, SKY, 6, POINT, 2, 0.6) + t(cx, 150, "9-bp duplication", 14, 600, POINT))
    g.append(line(cx - 40, 170, cx - 40, 200, ORANGE, 3) + line(cx + 40, 230, cx + 40, 260, GREEN, 3))
    g.append(t(1330, 300, "+ strand read: shift +4 bp", 15, 600, MAIN) + arrow(1290, 330, cx - 10, 330, POINT, 3))
    g.append(arrow(1530, 410, cx + 10, 410, SUB, 3) + t(1470, 440, "− strand read: shift −5 bp", 15, 600, MAIN))
    g.append(line(cx, 315, cx, 425, POINT, 2, "6,5") + t(cx, 475, "Tn5 insertion center", 15, 700, POINT))
    g.append(t(1400, 520, "Shifted reads mark the real", 15, 500, SUB) + t(1400, 544, "cut site for peaks and footprints", 15, 500, SUB))
    return svg("".join(g))


# ---------------------------------------------------------------- 3. ATAC_QC_plot
def atac_qc_plot():
    """Redrawn after ATACseqQC (Ou et al., BMC Genomics 2018) Fig. 1b, c."""
    g = [panel(40, "A", "Signal heatmaps around TSSs")]
    random.seed(21)
    for k, (title, kind) in enumerate([("NucleosomeFree", "nfr"), ("mononucleosome*", "nuc")]):
        x0, y0, cw, rh = 70 + k * 360, 110, 13, 14
        g.append(t(x0 + 150, 88, title, 16, 700, POINT if kind == "nfr" else SUB))
        for r in range(26):
            depth = 1 - r / 30
            for c in range(23):
                d = (c - 11) / 11
                if kind == "nfr":
                    v = math.exp(-((d + 0.05) / 0.16) ** 2) * depth
                else:
                    v = 0.55 * (math.exp(-((d - 0.3) / 0.15) ** 2) + math.exp(-((d + 0.3) / 0.15) ** 2)) * depth
                v = min(1, max(0.04, v + random.uniform(-0.08, 0.08)))
                g.append(rect(x0 + c * cw, y0 + r * rh, cw, rh, POINT if kind == "nfr" else SUB, 0, op=v))
        g.append(line(x0 + 11.5 * cw, y0 - 4, x0 + 11.5 * cw, y0 + 26 * rh + 4, ORANGE, 2, "5,4"))
        g.append(t(x0, y0 + 26 * rh + 22, "−1 kb", 14, 600, SUB) + t(x0 + 11.5 * cw, y0 + 26 * rh + 22, "TSS", 14, 700, ORANGE)
                 + t(x0 + 23 * cw, y0 + 26 * rh + 22, "+1 kb", 14, 600, SUB))
    g.append(t(370, 560, "Each row is one TSS (genes sorted by signal)", 15, 500, SUB))
    g.append(t(370, 586, "* labelled mononucleosome in the output: mono-, di- and trinucleosome combined", 14, 500, SUB))

    g.append(panel(780, "B", "Averaged coverage around TSSs"))
    x0, y0, w, h = 860, 120, 600, 340
    g.append(axes(x0, y0, w, h, "Distance to TSS (bp)", "Averaged coverage"))
    g.append(line(x0 + w / 2, y0, x0 + w / 2, y0 + h, GRAY, 2, "6,5"))
    nfr = [(x0 + i / 200 * w, y0 + h - (0.06 + 0.9 * math.exp(-((((i - 100) / 100) + 0.05) / 0.12) ** 2)) * (h - 20))
           for i in range(201)]
    nuc = [(x0 + i / 200 * w, y0 + h - (0.12 + 0.42 * (math.exp(-((((i - 100) / 100) - 0.3) / 0.12) ** 2)
                                                     + 0.8 * math.exp(-((((i - 100) / 100) + 0.32) / 0.12) ** 2))) * (h - 20))
           for i in range(201)]
    g.append(poly(nfr, POINT, 3.5) + poly(nuc, SUB, 3.5, "9,6"))
    for sgn, lab in [(-1, "−1"), (1, "+1")]:
        x = x0 + w / 2 + sgn * 0.31 * w / 2
        g.append(nucleosome(x, 95, 14) + t(x + 28 * sgn, 95, lab, 14, 700, SUB))
    g.append(t(x0, y0 + h + 24, "−1000", 13, 600, SUB) + t(x0 + w, y0 + h + 24, "1000", 13, 600, SUB))
    g.append(legend(1290, 140, [("line", POINT, "NucleosomeFree"), ("dash", SUB, "mononucleosome*")]))
    g.append(t(1160, 560, "Good library: NFR peak at the TSS, nucleosomes positioned on both sides", 15, 600, POINT))
    return svg("".join(g))


# ---------------------------------------------------------------- 4. MACS3
def macs3():
    random.seed(3)
    g = [panel(40, "A", "Fragment pileup and local background")]
    x0, y0, w, h = 90, 110, 760, 330
    g.append(axes(x0, y0, w, h, "Genome position", "Fragment pileup"))
    center = x0 + w * 0.55
    frags = []
    for i in range(52):
        inpeak = i < 34
        c = random.gauss(center, 50) if inpeak else random.uniform(x0 + 40, x0 + w - 40)
        L = random.uniform(50, 100)
        frags.append((c - L / 2, c + L / 2, inpeak))
    rows = []   # right end of the last fragment in each row
    top = y0 + h
    # background fragments first, so they form the bottom layer
    for a, b, inpeak in sorted(frags, key=lambda f: (f[2], f[0])):
        for k, end in enumerate(rows):
            if a > end + 4:
                rows[k] = b
                break
        else:
            rows.append(b)
            k = len(rows) - 1
        yy = y0 + h - 12 - k * 10
        top = min(top, yy)
        g.append(rect(a, yy, b - a, 7, POINT if inpeak else GRAY, 2, op=0.9))
    g.append(line(x0, y0 + h - 34, x0 + w, y0 + h - 34, ORANGE, 3, "10,6"))
    g.append(t(x0 + w - 6, y0 + h - 50, "local background λ", 15, 700, ORANGE, "end"))
    g.append(rect(center - 120, y0 + h + 40, 240, 16, MAIN, 2) + t(center, y0 + h + 72, "Peak (q < 0.05)", 15, 700, MAIN))
    g.append(f'<path d="M{center},{top - 6} l-9,-16 h18 Z" fill="{POINT}"/>' + t(center + 16, top - 16, "summit", 14, 700, POINT, "start"))

    g.append(panel(930, "B", "Peak test"))
    g.append(rect(960, 90, 290, 170, TINT, 10))
    g.append(t(1105, 125, "observed fragments in window", 15, 600, MAIN))
    g.append(t(1105, 155, "vs", 15, 600, SUB))
    g.append(t(1105, 185, "expected from λ (Poisson)", 15, 600, MAIN))
    g.append(t(1105, 225, "→ p-value → q-value", 16, 700, POINT))
    g.append(t(960, 300, "narrowPeak record", 15, 700, SUB, "start"))
    g.append(rect(960, 316, 290, 40, PALE, 6) + t(1105, 336, "chr · start · end · score · summit", 14, 600, MAIN))

    g.append(panel(1290, "C", "FRiP per sample"))
    rows = [("ctrl_1", "41,230", "0.38"), ("ctrl_2", "39,870", "0.35"), ("trt_1", "45,610", "0.41"), ("trt_2", "44,020", "0.39")]
    g.append(table(1290, 100, ["SampleID", "peaks", "FRiP"], rows, [110, 100, 70]))
    g.append(t(1290, 300, "frip_summary.tsv", 14, 600, SUB, "start"))
    g.append(t(1290, 360, "FRiP = reads in peaks / all reads", 16, 700, POINT, "start"))
    g.append(t(1290, 392, "ENCODE: ≥ 0.3 ideal, ≥ 0.2 acceptable", 14, 500, SUB, "start"))
    return svg("".join(g))


# ---------------------------------------------------------------- 5. peak_annotation
def peak_annotation():
    g = [panel(40, "A", "Where each peak falls in the gene structure")]
    y = 300
    g.append(line(60, y, 1000, y, SUB, 4))
    g.append(rect(250, y - 40, 260, 80, TINT, 6, op=0.9) + t(380, y + 62, "Promoter region (±3 kb of TSS)", 15, 700, POINT))
    g.append(f'<path d="M400,{y} V{y - 30} H440" fill="none" stroke="{MAIN}" stroke-width="4"/>'
             f'<path d="M436,{y - 39} L452,{y - 30} L436,{y - 21} Z" fill="{MAIN}"/>')
    g.append(t(470, y - 46, "TSS", 15, 700, MAIN, "start"))
    exons = [(400, 470), (560, 620), (700, 760), (840, 900)]
    for i, (a, b) in enumerate(exons):
        g.append(rect(a, y - 16, b - a, 32, POINT, 3))
        if i < len(exons) - 1:
            nb = exons[i + 1][0]
            g.append(f'<path d="M{b},{y} L{(b + nb) / 2},{y - 22} L{nb},{y}" fill="none" stroke="{POINT}" stroke-width="3"/>')
    g.append(t(650, y + 34, "exons and introns", 14, 600, POINT))
    peaks = [(330, "Promoter"), (590, "Exon"), (660, "Intron"), (950, "Downstream"), (130, "Distal intergenic")]
    for x, lab in peaks:
        g.append(rect(x - 25, 150, 50, 16, MAIN, 2) + line(x, 166, x, y - 22, GRAY, 2, "5,4"))
        g.append(t(x, 132, lab, 14, 700, MAIN))
    g.append(arrow(130, 430, 400, 430, ORANGE, 3) + t(265, 452, "distanceToTSS", 15, 700, ORANGE))
    g.append(t(265, 476, "nearest gene: geneId", 15, 600, SUB))
    g.append(t(520, 560, "Annotation from a TxDb built from the GFF3/GTF of the species", 15, 500, SUB))

    g.append(panel(1080, "B", "Feature distribution per sample"))
    cats = [("Promoter", POINT), ("5' UTR", SKY), ("3' UTR", TINT), ("Exon", LIGHT), ("Intron", SUB),
            ("Downstream", GRAY), ("Distal Intergenic", MAIN)]
    fracs = [[0.42, 0.04, 0.03, 0.08, 0.16, 0.05, 0.22], [0.40, 0.05, 0.03, 0.07, 0.17, 0.06, 0.22],
             [0.36, 0.04, 0.04, 0.09, 0.19, 0.05, 0.23]]
    for k, (sample, fr) in enumerate(zip(["ctrl_1", "ctrl_2", "trt_1"], fracs)):
        x, y0 = 1110 + k * 70, 110
        for (name, col), f in zip(cats, fr):
            hh = f * 380
            g.append(rect(x, y0, 50, hh, col, 0, "#fff", 1))
            y0 += hh
        g.append(t(x + 25, 512, sample, 13, 600, SUB))
    g.append(t(1190, 545, "percent of peaks", 14, 600, SUB))
    g.append(legend(1340, 140, [("box", col, name) for name, col in cats]))
    return svg("".join(g))


# ---------------------------------------------------------------- 6. differential_accessibility
def differential_accessibility():
    g = [panel(40, "A", "Consensus peaks")]
    rows = [("ctrl_1", [(80, 160), (260, 330), (420, 480)]), ("ctrl_2", [(90, 170), (250, 320)]),
            ("trt_1", [(85, 150), (420, 490)]), ("trt_2", [(70, 160), (255, 335), (430, 485)])]
    for i, (name, iv) in enumerate(rows):
        y = 100 + i * 40
        g.append(t(60, y, name, 14, 600, SUB, "end") + line(70, y, 510, y, GRAY, 2))
        for a, b in iv:
            g.append(rect(a, y - 7, b - a, 14, POINT if name.startswith("trt") else SUB, 2))
    g.append(arrow(290, 270, 290, 300, SUB, 3))
    for a, b in [(70, 170), (250, 335), (420, 490)]:
        g.append(rect(a, 320, b - a, 18, MAIN, 2))
    g.append(t(290, 360, "merged peak set used for counting", 15, 600, MAIN))

    g.append(panel(560, "B", "Counts per peak and condition"))
    for j, (lab, c, tr) in enumerate([("up", 3, 9), ("unchanged", 6, 6), ("down", 8, 3)]):
        x = 610 + j * 150
        g.append(t(x + 50, 90, lab, 16, 700, RED if lab == "up" else (BLUE if lab == "down" else SUB)))
        for k in range(c):
            g.append(rect(x + 5, 330 - k * 22, 40, 16, SUB, 2))
        for k in range(tr):
            g.append(rect(x + 55, 330 - k * 22, 40, 16, POINT, 2))
        g.append(line(x, 350, x + 100, 350, SUB, 2))
        g.append(t(x + 25, 370, "C", 14, 700, SUB) + t(x + 75, 370, "T", 14, 700, POINT))
    g.append(legend(620, 420, [("box", SUB, "control (C)"), ("box", POINT, "treated (T)")]))
    g.append(t(830, 510, "TMM normalization → edgeR QL F-test", 16, 700, MAIN))

    g.append(panel(1060, "C", "MD plot"))
    random.seed(5)
    x0, y0, w, h = 1120, 110, 420, 360
    g.append(axes(x0, y0, w, h, "Average log CPM", "log-fold-change (treated / control)"))
    g.append(line(x0, y0 + h / 2, x0 + w, y0 + h / 2, GRAY, 2, "6,5"))
    for i in range(260):
        a = random.uniform(0.05, 0.95)
        m = random.gauss(0, 0.05 + 0.1 * (1 - a))
        col, rr = GRAY, 3.5
        if i < 22:
            m, col, rr = random.uniform(0.25, 0.42), RED, 5
        elif i < 40:
            m, col, rr = -random.uniform(0.25, 0.42), BLUE, 5
        m = max(-0.46, min(0.46, m))
        g.append(f'<circle cx="{x0 + a * w:.1f}" cy="{y0 + h / 2 - m * h:.1f}" r="{rr}" fill="{col}" opacity="0.85"/>')
    g.append(legend(1150, 520, [("dot", RED, "up: more accessible in treated"), ("dot", BLUE, "down: less accessible")]))
    return svg("".join(g))


# ---------------------------------------------------------------- 7. atac_motif
def atac_motif():
    g = [panel(40, "A", "Rank peaks by logFC")]
    x, y0, hh = 90, 90, 440
    for i in range(100):
        f = i / 99
        col = RED if f < 0.5 else BLUE
        op = abs(f - 0.5) * 2
        g.append(rect(x, y0 + i * hh / 100, 60, hh / 100 + 0.5, col, op=max(0.1, op)))
    for b in range(5):
        yy = y0 + b * hh / 5
        g.append(line(x - 10, yy, x + 70, yy, MAIN, 2))
        g.append(t(x + 90, yy + hh / 10, f"bin{5 - b}", 15, 700, MAIN, "start"))
    g.append(t(x + 30, y0 - 18, "up", 15, 700, RED) + t(x + 30, y0 + hh + 20, "down", 15, 700, BLUE))
    g.append(f'<rect x="{x}" y="{y0}" width="60" height="{hh}" fill="none" stroke="{SUB}" stroke-width="2"/>')

    g.append(panel(330, "B", "Motif occurrences per bin"))
    random.seed(7)
    for b in range(5):
        yy = 110 + b * 88
        for s in range(3):
            ys = yy + s * 20
            g.append(line(330, ys, 760, ys, GRAY, 2))
            nA = [3, 2, 1, 0, 0][b]
            nB = [0, 0, 1, 2, 3][b]
            for k in range(nA):
                xx = random.uniform(350, 740)
                g.append(rect(xx, ys - 6, 22, 12, MAIN, 2))
            for k in range(nB):
                xx = random.uniform(350, 740)
                g.append(rect(xx, ys - 6, 22, 12, ORANGE, 2))
        g.append(t(780, yy + 20, f"bin{5 - b}", 14, 700, SUB, "start"))
    g.append(legend(360, 560, [("box", MAIN, "motif A"), ("box", ORANGE, "motif B")]))

    g.append(panel(880, "C", "Motif heatmap (motif × bin)"))
    vals = [[-1.2, -0.6, 0.0, 0.7, 1.5], [1.4, 0.8, 0.1, -0.5, -1.1], [-0.2, 0.1, 0.0, 0.2, 0.3]]
    sig = [[3, 1, 0, 2, 8], [7, 3, 0, 1, 4], [0, 0, 0, 0, 1]]
    names = ["motif A", "motif B", "motif C"]
    logos = [["T", "G", "A", "C", "G"], ["C", "A", "C", "G", "T"], ["A", "T", "A", "T", "A"]]
    lcol = {"A": GREEN, "C": BLUE, "G": ORANGE, "T": RED}
    x1, x2, cw, rh, y0 = 1100, 1350, 44, 80, 150
    for c in range(5):
        g.append(rect(x1 + c * cw, y0 - 22, cw - 2, 14, BLUE if c < 2 else (GRAY if c == 2 else RED), 0, op=0.35 + 0.15 * abs(c - 2)))
        g.append(rect(x2 + c * cw, y0 - 22, cw - 2, 14, BLUE if c < 2 else (GRAY if c == 2 else RED), 0, op=0.35 + 0.15 * abs(c - 2)))
    for r in range(3):
        y = y0 + r * rh
        g.append(t(960, y + rh / 2, names[r], 15, 700, MAIN, "end"))
        for k, L in enumerate(logos[r]):
            g.append(t(985 + k * 20, y + rh / 2, L, 24 - (k % 2) * 6, 900, lcol[L]))
        for c in range(5):
            v = vals[r][c]
            g.append(rect(x1 + c * cw, y, cw - 2, rh - 2, RED if v > 0 else BLUE, 0, op=max(0.06, min(1, abs(v) / 1.5))))
            g.append(rect(x2 + c * cw, y, cw - 2, rh - 2, MAIN, 0, op=max(0.04, sig[r][c] / 8)))
    g.append(t(x1 + 2.5 * cw, 110, "enrichment (log2)", 14, 700, SUB) + t(x2 + 2.5 * cw, 110, "adj. P value (−log10)", 14, 700, SUB))
    g.append(t(x1 + 2.5 * cw, y0 + 3 * rh + 22, "bins: down ← logFC → up", 13, 600, SUB))
    g.append(t(x2 + 2.5 * cw, y0 + 3 * rh + 22, "bins: down ← logFC → up", 13, 600, SUB))
    g.append(legend(1000, 480, [("box", RED, "enriched (log2 enrichment > 0)"), ("box", BLUE, "depleted (< 0)"),
                                ("box", MAIN, "darker = more significant")]))
    return svg("".join(g))


# ---------------------------------------------------------------- 8. tf_footprinting
def tf_footprinting():
    """Redrawn after TOBIAS (Bentsen et al., Nat Commun 2020) Fig. 1a, c, e."""
    g = [panel(40, "A", "Binding event → fragments → footprint")]
    y = 170
    pts = [(60 + i * 5, y + 6 * math.sin(i * 0.7)) for i in range(101)]
    g.append(poly(pts, SUB, 4))
    g.append(nucleosome(90, y - 2, 20) + nucleosome(530, y - 2, 20))
    g.append(f'<ellipse cx="310" cy="{y - 18}" rx="42" ry="30" fill="{POINT}" opacity="0.9"/>' + t(310, y - 62, "DNA-binding protein", 14, 700, POINT))
    g.append(tn5(215, y - 26, 0.5) + tn5(405, y - 26, 0.5) + t(215, y + 40, "Tn5 cleavage", 14, 700, SUB))
    heights = [10, 16, 26, 40, 54, 64, 70, 52, 8, 4, 6, 50, 72, 66, 56, 44, 30, 18, 10, 6]
    for i, hgt in enumerate(heights):
        g.append(rect(80 + i * 24, 440 - hgt * 2.4, 15, hgt * 2.4, MAIN))
    g.append(rect(268, 260, 84, 180, LIGHT, 0, op=0.7) + t(310, 462, "Footprint", 16, 800, POINT))
    g.append(line(70, 440, 560, 440, SUB, 2.5) + t(560, 270, "Tn5 signal", 14, 700, SUB, "end"))
    for k, (a, b) in enumerate([(110, 260), (360, 520), (150, 255), (365, 470)]):
        g.append(frag(a, b, 500 + k * 16, MAIN, 6))
    g.append(t(310, 584, "Library fragments end at Tn5 cut sites", 14, 500, SUB))

    g.append(panel(620, "B", "Bias correction"))
    random.seed(23)
    tracks = [("Observed cut sites", None), ("Expected (Tn5 sequence bias)", None), ("Corrected", None)]
    obs = [random.random() ** 2 for _ in range(40)]
    exp = [min(1, o * random.uniform(0.6, 1.3) + random.uniform(0, 0.15)) for o in obs]
    for k, (lab, _) in enumerate(tracks):
        y0 = 120 + k * 150
        g.append(rect(660, y0 - 10, 380, 120, "#fff", 4, SUB if k < 2 else ORANGE, 2))
        g.append(t(670, y0 + 4, lab, 14, 700, SUB if k < 2 else ORANGE, "start"))
        base = y0 + (90 if k < 2 else 62)
        g.append(line(670, base, 1030, base, GRAY, 1.5))
        for i in range(40):
            v = [obs[i], exp[i], obs[i] - exp[i]][k]
            hh = v * (60 if k < 2 else 70)
            x = 676 + i * 8.8
            g.append(rect(x, base - hh if hh > 0 else base, 5, abs(hh), POINT))
    g.append(t(850, 568, "Corrected = more or less cutting than expected", 14, 600, SUB))

    g.append(panel(1080, "C", "Differential binding"))
    x0, y0, w, h = 1140, 120, 400, 360
    g.append(axes(x0, y0, w, h, "Differential binding score", "−log10(p-value)"))
    g.append(line(x0 + w / 2, y0, x0 + w / 2, y0 + h, GRAY, 2, "6,5"))
    random.seed(13)
    for i in range(60):
        dx = random.gauss(0, 0.09)
        g.append(f'<circle cx="{x0 + w / 2 + dx * w:.1f}" cy="{y0 + h - min(abs(dx) * random.uniform(2, 3), 0.6) * h:.1f}" r="4.5" fill="{GRAY}"/>')
    # BINDetect colors: change > 0 (higher in condition 1) red, change < 0 (higher in condition 2) blue
    for name, dx, dy, col in [("TF1", 0.36, 0.86, RED), ("TF3", 0.28, 0.66, RED), ("TF2", -0.3, 0.74, BLUE)]:
        cx, cy = x0 + w / 2 + dx * w, y0 + h - dy * h
        g.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="8" fill="{col}"/>' + t(cx + 14, cy - 12, name, 14, 700, col, "start"))
    g.append(t(x0 + 6, y0 + h + 50, "← higher in condition 2", 13, 700, BLUE, "start")
             + t(x0 + w - 6, y0 + h + 50, "higher in condition 1 →", 13, 700, RED, "end"))
    g.append(t(1340, 570, "Each dot is one transcription factor motif", 15, 600, SUB))
    g.append(t(1340, 594, "conditions 1 and 2 in alphabetical order of the names", 13, 500, SUB))
    return svg("".join(g))


# ---------------------------------------------------------------- 9. functional_enrichment
def functional_enrichment():
    g = [panel(40, "A", "Peaks to nearest genes")]
    y = 220
    g.append(line(60, y, 560, y, SUB, 4))
    genes = [(120, "gene 1"), (300, "gene 2"), (470, "gene 3")]
    for x, lab in genes:
        g.append(rect(x, y - 12, 70, 24, POINT, 3) + t(x + 35, y + 34, lab, 14, 700, POINT))
        g.append(f'<path d="M{x},{y} V{y - 28} H{x + 26}" fill="none" stroke="{MAIN}" stroke-width="3"/>')
    for px, gx, ok in [(90, 120, True), (260, 300, True), (440, 470, True), (380, 300, False)]:
        g.append(rect(px - 18, 120, 36, 14, MAIN if ok else GRAY, 2))
        g.append(line(px, 134, gx, y - 30, POINT if ok else GRAY, 2, None if ok else "5,4"))
    g.append(t(310, 330, "Peak → gene with the nearest TSS", 15, 600, MAIN))
    g.append(t(310, 356, "(within max_distance_to_tss; gray: too far)", 14, 500, SUB))
    g.append(t(310, 420, "From differential results: up and down lists", 15, 600, POINT))

    g.append(panel(620, "B", "Over-representation test"))
    g.append(rect(650, 90, 420, 400, PALE, 12, SUB, 2) + t(860, 115, "Background genes (universe, N)", 15, 700, SUB))
    g.append(f'<circle cx="800" cy="300" r="120" fill="{POINT}" opacity="0.25" stroke="{POINT}" stroke-width="3"/>')
    g.append(f'<circle cx="920" cy="300" r="110" fill="{ORANGE}" opacity="0.22" stroke="{ORANGE}" stroke-width="3"/>')
    g.append(t(740, 300, "Your genes (n)", 15, 700, POINT) + t(985, 300, "GO term (M)", 15, 700, ORANGE))
    g.append(t(862, 300, "k", 26, 800, MAIN))
    g.append(t(860, 530, "P(X ≥ k), hypergeometric → adjusted p (BH)", 16, 700, MAIN))

    g.append(panel(1110, "C", "Dot plot"))
    terms = [("photosynthesis", 0.78, 60, 1.0), ("light reaction", 0.55, 42, 0.85), ("precursor metabolites", 0.57, 44, 0.7),
             ("response to light", 0.32, 25, 0.45), ("chloroplast organization", 0.21, 16, 0.3)]
    x0, y0, w = 1330, 110, 220
    g.append(line(x0, y0 + 360, x0 + w, y0 + 360, SUB, 2.5) + t(x0 + w / 2, y0 + 390, "GeneRatio", 15, 600, SUB))
    for i, (name, gr, cnt, sig) in enumerate(terms):
        yy = y0 + 40 + i * 64
        g.append(t(x0 - 14, yy, name, 15, 600, MAIN, "end"))
        g.append(f'<circle cx="{x0 + gr * w:.1f}" cy="{yy}" r="{6 + cnt / 5:.1f}" fill="{POINT}" opacity="{sig:.2f}"/>')
    g.append(t(1330, 560, "size: gene count · color: significance", 14, 600, SUB))
    return svg("".join(g))


# ---------------------------------------------------------------- 10. replicate_consistency
def replicate_consistency():
    g = [panel(40, "A", "Peak ranks in two replicates")]
    random.seed(17)
    for i in range(12):
        y1 = 110 + i * 34
        j = [0, 2, 1, 3, 4, 6, 5, 11, 8, 10, 7, 9][i]
        y2 = 110 + j * 34
        good = i < 7
        g.append(rect(90, y1 - 10, 120, 20, POINT if good else GRAY, 3) + rect(400, y2 - 10, 120, 20, POINT if j < 7 else GRAY, 3))
        g.append(line(210, y1, 400, y2, POINT if good else GRAY, 2, None if good else "5,4"))
    g.append(t(150, 80, "Replicate 1", 16, 700, MAIN) + t(460, 80, "Replicate 2", 16, 700, MAIN))
    g.append(t(305, 540, "strong peaks keep their rank; noise does not", 15, 600, SUB))
    g.append(t(60, 110, "rank 1", 13, 600, SUB, "end"))

    g.append(panel(620, "B", "Ranks (idr plot, upper left)"))
    x0, y0, w, h = 690, 110, 380, 380
    g.append(axes(x0, y0, w, h, "Sample 1 Rank", "Sample 2 Rank"))
    for i in range(170):
        if i < 80:
            r = random.uniform(0.45, 1)
            a, b = r + random.gauss(0, 0.03), r + random.gauss(0, 0.03)
            col = MAIN
        else:
            a, b = random.uniform(0, 0.75), random.uniform(0, 0.75)
            col = RED
        g.append(f'<circle cx="{x0 + min(max(a, 0), 1) * w:.1f}" cy="{y0 + h - min(max(b, 0), 1) * h:.1f}" r="4.5" fill="{col}" opacity="0.8"/>')
    g.append(legend(720, 560, [("dot", MAIN, "passing IDR (reproducible)"), ("dot", RED, "IDR ≥ threshold (red in the plot)")]))

    g.append(panel(1130, "C", "Peaks passing IDR"))
    rows = [("ctrl", "r1_vs_r2", "98,400", "31,250"), ("trt", "r1_vs_r2", "102,700", "34,980")]
    g.append(table(1130, 110, ["condition", "pair", "relaxed", "passing"], rows, [100, 100, 100, 90]))
    g.append(t(1130, 250, "04_summary/idr_summary.tsv", 14, 600, SUB, "start"))
    g.append(t(1130, 320, "Pair with the most passing peaks", 15, 600, MAIN, "start"))
    g.append(t(1130, 346, "= conservative peaks of the condition", 15, 600, MAIN, "start"))
    g.append(t(1130, 372, "(03_reproducible_peaks/*.narrowPeak)", 14, 500, SUB, "start"))
    return svg("".join(g))


FIGS = {
    "bowtie2": bowtie2,
    "organellar_filter": organellar_filter, "ATAC_QC": atac_qc, "ATAC_QC_plot": atac_qc_plot,
    "MACS3_callpeak_ATAC": macs3, "peak_annotation": peak_annotation,
    "differential_accessibility": differential_accessibility, "atac_motif": atac_motif,
    "tf_footprinting": tf_footprinting, "functional_enrichment": functional_enrichment,
    "replicate_consistency": replicate_consistency,
}

if __name__ == "__main__":
    for name, fn in FIGS.items():
        p = OUT / f"{name}_concept.svg"
        p.write_text(fn())
        print(p)
