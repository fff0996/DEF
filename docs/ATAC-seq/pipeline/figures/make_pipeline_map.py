#!/usr/bin/env python3
"""Metro-style schematic of the CLOSHA ATAC-seq pipeline (SVG)."""
# Run: python3 docs/ATAC-seq/pipeline/figures/make_pipeline_map.py, then render the PNG with
# rsvg-convert -w 2700 docs/ATAC-seq/pipeline/figures/pipeline.svg -o docs/ATAC-seq/pipeline/figures/pipeline.png
# (the Montserrat font gives the intended look).
from pathlib import Path

OUT = Path(__file__).resolve().parent / "pipeline.svg"
W, H = 2700, 1860
FONT = "Montserrat, 'DejaVu Sans', Arial, sans-serif"

PURPLE, BLUE, GREEN, YELLOW = "#A8509C", "#1269FF", "#7CC744", "#FFB400"
ORANGE, DARK, GRAY_BG, TEXT = "#F07800", "#3D3D3D", "#EEEEEE", "#2B2B2B"
LW = 15

svg = []
lines, overlay = [], []
segments = []     # straight parts of routes, for direction arrows
blocks = []       # boxes that arrows must not sit under: (x0, y0, x1, y1)


def route(points, color, r=42, arrows=()):
    """Orthogonal polyline with rounded corners; arrows = segment indexes."""
    d = f"M{points[0][0]},{points[0][1]}"
    for i in range(1, len(points) - 1):
        (x0, y0), (x1, y1), (x2, y2) = points[i - 1], points[i], points[i + 1]
        rr = min(r, abs(x1 - x0 + y1 - y0) / 2, abs(x2 - x1 + y2 - y1) / 2)
        sx = (x1 - x0 > 0) - (x1 - x0 < 0)
        sy = (y1 - y0 > 0) - (y1 - y0 < 0)
        tx = (x2 - x1 > 0) - (x2 - x1 < 0)
        ty = (y2 - y1 > 0) - (y2 - y1 < 0)
        d += f" L{x1 - sx * rr},{y1 - sy * rr} Q{x1},{y1} {x1 + tx * rr},{y1 + ty * rr}"
    d += f" L{points[-1][0]},{points[-1][1]}"
    lines.append(f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{LW}" '
                 f'stroke-linecap="round" stroke-linejoin="round"/>')
    for i in range(len(points) - 1):
        (x0, y0), (x1, y1) = points[i], points[i + 1]
        # trim the rounded corners off both ends
        a = r if i > 0 else 0
        b = r if i < len(points) - 2 else 0
        segments.append((x0, y0, x1, y1, a, b))


def chevron(x, y, dx, dy):
    """White double arrowhead pointing along (dx, dy), drawn inside the line."""
    import math
    ang = math.degrees(math.atan2(dy, dx))
    tri = "M-5,-6 L4,0 L-5,6 Z"
    return (f'<g transform="translate({x},{y}) rotate({ang})" fill="#fff">'
            f'<path d="{tri}" transform="translate(-6,0)"/><path d="{tri}" transform="translate(5,0)"/></g>')


def place_arrows():
    """Arrows in the middle of every part of a straight segment not covered
    by a node or station."""
    out = []
    for x0, y0, x1, y1, a, b in segments:
        horiz = y0 == y1
        lo, hi = (x0, x1) if horiz else (y0, y1)
        sign = 1 if hi >= lo else -1
        start, end = lo + sign * a, hi - sign * b
        s0, s1 = sorted((start, end))
        if s1 - s0 < 50:
            continue
        cut = []
        for bx0, by0, bx1, by1 in blocks:
            if horiz and by0 <= y0 <= by1:
                cut.append((bx0, bx1))
            if not horiz and bx0 <= x0 <= bx1:
                cut.append((by0, by1))
        free, cur = [], s0
        for c0, c1 in sorted(cut):
            if c1 <= cur or c0 >= s1:
                continue
            if c0 > cur:
                free.append((cur, c0))
            cur = max(cur, c1)
        if cur < s1:
            free.append((cur, s1))
        # one arrow in every visible gap long enough to hold it
        for f0, f1 in free:
            if f1 - f0 < 42:
                continue
            n = max(1, int((f1 - f0) // 300))   # long gaps get a repeated arrow
            for k in range(n):
                m = f0 + (f1 - f0) * (k + 0.5) / n
                x, y = (m, y0) if horiz else (x0, m)
                out.append(chevron(x, y, x1 - x0, y1 - y0))
    return "".join(out)


def node(x, y, label, w=None):
    rows = label.split("\n")
    w = w or max(len(t) for t in rows) * 15.5 + 120
    h = 80
    blocks.append((x - w / 2 - 8, y - h / 2, x + w / 2 + 8, y + h / 2))
    s = (f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{h / 2}" fill="{DARK}"/>'
         f'<rect x="{x - w / 2 + 30}" y="{y - 12}" width="24" height="22" rx="3" fill="#6B6B6B"/>'
         f'<text x="{x - w / 2 + 34}" y="{y + 4}" font-family="monospace" font-size="11" fill="#fff">&gt;_</text>')
    ty = y + 9 - (len(rows) - 1) * 13
    for i, t in enumerate(rows):
        s += (f'<text x="{x + 18}" y="{ty + i * 26}" text-anchor="middle" font-family="{FONT}" '
              f'font-size="24" font-weight="600" fill="#fff">{t}</text>')
    overlay.append(s)
    return w


def station(x, y, color=DARK, fill="#fff"):
    blocks.append((x - 26, y - 26, x + 26, y + 26))
    overlay.append(f'<circle cx="{x}" cy="{y}" r="13" fill="{fill}" stroke="{color}" stroke-width="7"/>')


def doc_icon(x, y):
    overlay.append(f'<path d="M{x - 17},{y - 22} h22 l12,12 v32 h-34 Z" fill="{DARK}"/>'
                   f'<path d="M{x + 5},{y - 22} v12 h12 Z" fill="#fff"/>')


def fastq_icon(x, y):
    """Sequencing reads: rows of dashes (as in the BIO-EXPRESS pipeline maps)."""
    s = ""
    for r, segs in enumerate([[(-30, -8), (-2, 14), (20, 30)], [(-24, 2), (8, 30)],
                              [(-30, -12), (-6, 16), (22, 30)], [(-20, 4), (10, 30)]]):
        for a, b in segs:
            s += f'<rect x="{x + a}" y="{y - 20 + r * 11}" width="{b - a}" height="5" fill="{DARK}"/>'
    overlay.append(s)


def fasta_icon(x, y):
    """Reference or assembled sequence: DNA double helix, wide at the top,
    middle, and bottom and crossing twice, with rungs between the strands."""
    import math
    hh, r = 30, 13                       # half height, strand amplitude
    def pts(sign):
        return " ".join(f"{x + sign * r * math.cos(2 * math.pi * t / 40):.1f},{y - hh + t * 2 * hh / 40:.1f}"
                        for t in range(41))
    s = (f'<polyline points="{pts(1)}" fill="none" stroke="{DARK}" stroke-width="5" stroke-linecap="round"/>'
         f'<polyline points="{pts(-1)}" fill="none" stroke="{DARK}" stroke-width="5" stroke-linecap="round"/>')
    for t in (0, 4, 16, 20, 24, 36, 40):     # rungs where the strands are apart
        c = abs(math.cos(2 * math.pi * t / 40))
        yy = y - hh + t * 2 * hh / 40
        half = r * c - 2
        s += f'<line x1="{x - half:.1f}" y1="{yy:.1f}" x2="{x + half:.1f}" y2="{yy:.1f}" stroke="{DARK}" stroke-width="{4 if t in (0, 40) else 3}" stroke-linecap="round"/>'
    overlay.append(s)


def bam_icon(x, y):
    """Alignment file: framed read over a reference with A/T/C/G."""
    s = (f'<rect x="{x - 28}" y="{y - 26}" width="56" height="52" rx="4" fill="#fff" stroke="{DARK}" stroke-width="2.5"/>'
         f'<line x1="{x - 22}" y1="{y - 14}" x2="{x + 10}" y2="{y - 14}" stroke="{DARK}" stroke-width="2.5"/>'
         f'<line x1="{x - 22}" y1="{y - 19}" x2="{x - 22}" y2="{y - 9}" stroke="{DARK}" stroke-width="2.5"/>'
         f'<line x1="{x + 10}" y1="{y - 19}" x2="{x + 10}" y2="{y - 9}" stroke="{DARK}" stroke-width="2.5"/>'
         f'<path d="M{x - 6},{y - 4} v10 l-4,-4 M{x - 6},{y + 6} l4,-4" fill="none" stroke="{DARK}" stroke-width="2"/>'
         f'<line x1="{x - 22}" y1="{y + 16}" x2="{x + 10}" y2="{y + 16}" stroke="{PURPLE}" stroke-width="3"/>')
    for i, ch in enumerate("ATCG"):
        s += (f'<text x="{x + 20}" y="{y - 15 + i * 11}" text-anchor="middle" font-family="{FONT}" font-size="10" '
              f'font-weight="700" fill="{PURPLE}">{ch}</text>')
    overlay.append(s)


ICONS = {"doc": doc_icon, "fastq": fastq_icon, "fasta": fasta_icon, "bam": bam_icon}


def label_box(x, y, text, kind):
    """kind: 'in' (gray input format) or 'out' (orange output)."""
    rows = text.split("\n")
    w = max(len(t) for t in rows) * 12.2 + 44
    h = 22 + 25 * len(rows)
    fill, fg = (GRAY_BG, TEXT) if kind == "in" else (ORANGE, "#fff")
    s = f'<rect x="{x - w / 2}" y="{y - h / 2}" width="{w}" height="{h}" rx="{min(h / 2, 24)}" fill="{fill}"/>'
    for i, t in enumerate(rows):
        s += (f'<text x="{x}" y="{y + 7 - (len(rows) - 1) * 12.5 + i * 25}" text-anchor="middle" '
              f'font-family="{FONT}" font-size="19" font-weight="{500 if kind == "in" else 600}" fill="{fg}">{t}</text>')
    overlay.append(s)
    return h


def tag(cx, cy, text, kind, above=True, gap=78, icon=True):
    """Station at (cx, cy) with a dashed connector to a label box."""
    color = DARK if kind == "in" else ORANGE
    rows = text.count("\n") + 1
    h = 22 + 25 * rows
    ly = cy - gap - h / 2 if above else cy + gap + h / 2
    edge = ly + h / 2 if above else ly - h / 2
    overlay.append(f'<line x1="{cx}" y1="{cy}" x2="{cx}" y2="{edge}" stroke="{color}" stroke-width="3" '
                   f'stroke-dasharray="7,6"/>')
    label_box(cx, ly, text, kind)
    if icon:
        iy = ly - h / 2 - 40 if above else ly + h / 2 + 40
        ICONS["doc" if icon is True else icon](cx, iy)
    station(cx, cy, color if kind == "out" else DARK)


# ---------------------------------------------------------------- layout
yA, yR, yB, yC, yF, yD, yE = 380, 620, 830, 1050, 1250, 1340, 1520
yJ = 1160   # BAM line joining the peaks track

# Preprocessing row and the return to row B
route([(175, yA), (1880, yA), (1940, yA), (1940, yR), (90, yR), (90, yB), (200, yB)], PURPLE,
      arrows=(0, 3, 5))
for x, t in [(400, "fastp"), (800, "bowtie2"), (1250, "GATK_\nMarkDuplicates"), (1720, "organellar_\nfilter")]:
    node(x, yA, t)
tag(175, yA, "FASTQ.GZ", "in", gap=50, icon="fastq")
tag(596, yA, "FASTQ.GZ", "in", gap=50, icon="fastq")
tag(998, yA, "BAM", "in", gap=50, icon="bam")
tag(1497, yA, "BAM", "in", gap=50, icon="bam")
# bowtie2 also takes the reference genome (index built from it)
label_box(800, yA - 76, "REF.FASTA", "in")
overlay.append(f'<text x="800" y="{yA - 42}" text-anchor="middle" font-family="{FONT}" font-size="22" font-weight="700" fill="{TEXT}">+</text>')
fasta_icon(800, yA - 140)
tag(1250, yR, "organellar-removed\nBAM", "in", gap=40, icon="bam")

# Row B: ATAC_QC -> MACS3 -> peak_annotation -> functional_enrichment
route([(330, yB), (1250, yB)], BLUE, arrows=(0,))
route([(1250, yB), (2300, yB), (2470, yB)], GREEN, arrows=(1,))
# Trunk from ATAC_QC output (shifted BAM) down to QC_plot and replicate_consistency
route([(620, yB), (620, yE), (800, yE)], BLUE, arrows=(0,))
route([(620, yC), (800, yC)], BLUE)
# BAM joins the peaks track to differential_accessibility and tf_footprinting
route([(620, yJ), (1380, yJ)], BLUE, arrows=(0,))
route([(1250, yB), (1380, yB), (1380, yD), (1500, yD)], GREEN, arrows=(1,))
route([(1380, yC), (1500, yC)], GREEN)
# differential_accessibility -> atac_motif and functional_enrichment (DA)
route([(1640, yC), (2470, yC)], GREEN, arrows=(0,))
route([(2060, yC), (2060, yF), (2470, yF)], GREEN)

# Output lines
route([(330, yB), (330, yB + 150)], YELLOW)
route([(950, yC), (1200, yC)], YELLOW)
route([(1640, yC), (1640, yC + 120), (1800, yC + 120)], YELLOW)
route([(1640, yD), (1960, yD)], GREEN)
route([(950, yE), (1240, yE)], GREEN)

# Nodes
node(330, yB, "ATAC_QC")
node(950, yB, "MACS3_\ncallpeak_ATAC")
node(1640, yB, "peak_\nannotation")
node(2280, yB, "functional_\nenrichment")
node(950, yC, "ATAC_QC_plot")
node(1640, yC, "differential_\naccessibility")
node(2280, yC, "atac_motif")
node(2280, yF, "functional_\nenrichment")
node(1640, yD, "tf_footprinting")
node(950, yE, "replicate_\nconsistency")

# Intermediate data (input format) stations
tag(620, yB, "shifted BAM\nsplit BAM (bam)", "in", gap=50, icon="bam")
tag(1250, yB, "peaks (narrowPeak)\nFRiP (tsv)", "in", gap=50, icon="doc")
tag(1960, yB, "annotation (tsv)\ngene_lists (tsv)", "in", gap=50, icon="doc")
tag(1960, yC, "diff_accessibility\n(csv)", "in", gap=50, icon="doc")

# Outputs
tag(330, yB + 150, "TSS enrichment (tsv)\nbigWig (bw)", "out", above=False, gap=46)
tag(1200, yC, "TSS heatmap\nprofile (pdf)", "out", gap=50)
tag(1800, yC + 120, "MDS · PCA ·\ncorrelation (pdf)", "out", above=False, gap=12, icon=False)
doc_icon(1945, yC + 175)
tag(2470, yB, "GO enrichment\n(tsv / pdf)", "out", gap=50)
tag(2470, yC, "motif enrichment\nheatmap (pdf)", "out", gap=50)
tag(2470, yF, "GO up / down\n(tsv / pdf)", "out", above=False, gap=46)
tag(1960, yD, "footprints (bw)\nBINDetect (tsv / pdf)", "out", above=False, gap=46)
tag(1240, yE, "reproducible peaks\n(narrowPeak) · IDR plot", "out", above=False, gap=46)

# Title and legend
title = (f'<g transform="translate(60,62)">'
         f'<rect width="88" height="52" rx="8" fill="url(#bx)"/>'
         f'<text x="44" y="38" text-anchor="middle" font-family="{FONT}" font-size="34" font-weight="800" fill="#fff">BX</text>'
         f'<text x="108" y="42" font-family="{FONT}" font-size="46" font-weight="800" fill="#3A3A3A">BIO-EXPRESS</text></g>'
         f'<text x="60" y="172" font-family="{FONT}" font-size="38" font-weight="700" fill="{TEXT}">ATAC-seq pipeline</text>')
lg = [f'<text x="60" y="1660" font-family="{FONT}" font-size="30" font-weight="700" fill="{TEXT}">Legend</text>']
for i, (c, t) in enumerate([(PURPLE, "Preprocessing"), (BLUE, "QC &amp; Tn5 shift"),
                            (GREEN, "Peak &amp; downstream analysis"), (YELLOW, "Visualization")]):
    y = 1702 + i * 42
    lg.append(f'<rect x="60" y="{y - 9}" width="80" height="17" fill="{c}"/>'
              f'<text x="158" y="{y + 7}" font-family="{FONT}" font-size="22" font-weight="500" fill="{TEXT}">{t}</text>')
for i, (c, t) in enumerate([(DARK, "Input format"), (ORANGE, "Output format")]):
    y = 1702 + i * 42
    lg.append(f'<circle cx="470" cy="{y}" r="10" fill="#fff" stroke="{c}" stroke-width="5"/>'
              f'<line x1="484" y1="{y}" x2="530" y2="{y}" stroke="{c}" stroke-width="3" stroke-dasharray="7,6"/>'
              f'<text x="545" y="{y + 7}" font-family="{FONT}" font-size="22" font-weight="500" fill="{TEXT}">{t}</text>')

doc = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
       f'<defs><linearGradient id="bx" x1="0" x2="1" y1="0" y2="1">'
       f'<stop offset="0" stop-color="#C13BE0"/><stop offset="0.55" stop-color="#5B5BFF"/>'
       f'<stop offset="1" stop-color="#19D3E6"/></linearGradient></defs>'
       f'<rect width="{W}" height="{H}" fill="#fff"/>' + title + "".join(lines) + place_arrows() + "".join(overlay)
       + "".join(lg) + "</svg>")
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(doc)
print(OUT)
