#!/usr/bin/env python3
"""RTpred pipeline concept figure 2 (SVG): the QSRR principle behind RTpred, redrawn in the
portal style from Xie J, Chen S, Zhao L, Dong X, J Pharm Anal 15, 101155 (2025), Fig. 1
(CC BY 4.0), with the RTpred module of each step added. Drawing helpers come from the
ATAC-seq module concept generator.

Run: python3 docs/RTpred/pipeline/figures/make_concept_2.py, then
rsvg-convert -w 1600 docs/RTpred/pipeline/figures/concept_2.svg -o docs/RTpred/pipeline/figures/concept_2.png
Everything drawn is schematic; no data are shown.
"""
import math
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parents[2] / "ATAC-seq" / "modules" / "figures" / "module_concepts"))
from make_module_concepts import MAIN, SUB, POINT, GRAY, PALE, t, line, rect, arrow, svg  # noqa: E402

OK = "#2E9E6B"
COLS = {"A": "#C2185B", "B": "#3F7CC0", "C": "#5A9E3A", "D": "#E8862A", "E": "#7B5EA7"}


def box(x, y, w, h, letter, title, col):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="10" fill="{col}" fill-opacity="0.07" '
            f'stroke="{col}" stroke-width="2.5" stroke-dasharray="8,5"/>'
            + t(x + 14, y - 16, letter, 24, 800, POINT, "start") + t(x + 40, y - 16, title, 16, 700, MAIN, "start"))


def hexring(x, y, r=22, col=SUB):
    pts = " ".join(f"{x + r * math.cos(math.radians(a)):.1f},{y + r * math.sin(math.radians(a)):.1f}" for a in range(30, 390, 60))
    return f'<polygon points="{pts}" fill="none" stroke="{col}" stroke-width="2.5"/>'


def peaks(x, y, w, h, col):
    out = line(x, y + h, x + w, y + h, SUB, 2)
    for i, px in enumerate((0.15, 0.32, 0.5, 0.7, 0.88)):
        hh = h * (0.9, 0.6, 0.8, 0.5, 0.7)[i]
        cx = x + w * px
        out += (f'<path d="M{cx - 10:.1f},{y + h} Q{cx:.1f},{y + h - 2 * hh:.1f} {cx + 10:.1f},{y + h}" fill="none" '
                f'stroke="{col}" stroke-width="2.5"/>')
    return out


def module_tag(x, y, w, label):
    return (f'<rect x="{x}" y="{y}" width="{w}" height="28" rx="14" fill="{POINT}"/>' + t(x + w / 2, y + 14, label, 13, 700, "#FFFFFF"))


def concept_2():
    g = [t(800, 30, "QSRR: predicting retention time from structure", 22, 800, MAIN)]
    y0, h = 300, 250
    # A dataset
    g.append(box(30, y0, 250, h, "A", "Measured RTs + structures", COLS["A"]))
    g.append(hexring(90, y0 + 60) + hexring(128, y0 + 60) + hexring(200, y0 + 60))
    g.append(peaks(60, y0 + 120, 190, 70, COLS["A"]))
    g.append(t(155, y0 + 220, "retention time (min)", 13, 600, SUB))
    # B representation
    g.append(box(330, y0, 260, h, "B", "Molecular representation", COLS["B"]))
    g.append(t(460, y0 + 45, "SMILES", 14, 700, SUB))
    g.append(t(460, y0 + 70, "O=Cc1ccc(O)c(OC)c1", 13, 500, MAIN))
    g.append(arrow(460, y0 + 88, 460, y0 + 118, SUB, 2.5))
    g.append(t(460, y0 + 138, "RDKit descriptors", 14, 700, COLS["B"]))
    g.append(t(460, y0 + 162, "logP, TPSA, H-bond acceptors, ...", 13, 500, SUB))
    for i in range(10):
        g.append(rect(380 + i * 16, y0 + 190, 14, 22, COLS["B"], 2, op=0.25 + 0.07 * (i % 5)))
    # C modelling
    g.append(box(640, y0, 260, h, "C", "Model training", COLS["C"]))
    for i, (lab, col, x) in enumerate((("training", COLS["C"], 670), ("held-out", GRAY, 790))):
        for k in range(4):
            g.append(f'<ellipse cx="{x + 40}" cy="{y0 + 50 + k * 14}" rx="38" ry="9" fill="#FFFFFF" stroke="{col}" stroke-width="2"/>')
        g.append(t(x + 40, y0 + 112, lab, 13, 600, SUB))
    g.append(arrow(770, y0 + 125, 770, y0 + 150, SUB, 2.5))
    g.append(rect(690, y0 + 155, 160, 70, "#FFFFFF", 6, COLS["C"], 2))
    g.append(f'<path d="M700,{y0 + 215} C740,{y0 + 215} 750,{y0 + 165} 840,{y0 + 165}" fill="none" stroke="{MAIN}" stroke-width="2.5"/>')
    g.append(t(770, y0 + 240, "machine learning model", 13, 600, SUB))
    # D validation (above C)
    g.append(box(560, 80, 420, 150, "D", "Validation", COLS["D"]))
    for j in range(3):
        x = 590 + j * 120
        for k in range(4):
            val = (k == j)
            g.append(rect(x, 105 + k * 26, 100, 22, COLS["D"] if val else "#FFFFFF", 3, COLS["D"], 1.5, op=0.35 if val else 1))
        g.append(t(x + 50, 215, "fold " + str(j + 1), 12, 600, SUB))
    g.append(t(940, 155, "…", 22, 800, SUB))
    g.append(line(880, y0, 880, 232, COLS["D"], 2.5, "6,5"))
    # E prediction
    g.append(box(950, y0, 260, h, "E", "Predicted RT", COLS["E"]))
    ax, ay = 990, y0 + 30
    g.append(line(ax, ay, ax, ay + 160, SUB, 2) + line(ax, ay + 160, ax + 180, ay + 160, SUB, 2))
    g.append(line(ax, ay + 160, ax + 175, ay + 5, MAIN, 2, "6,5"))
    for k in range(14):
        px = ax + 15 + k * 11.5
        py = ay + 160 - (px - ax) * 0.88 + (12 if k % 3 == 0 else -9 if k % 3 == 1 else 3)
        g.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="5" fill="{COLS["E"]}" opacity="0.6"/>')
    g.append(t(ax + 90, ay + 182, "predicted vs measured", 13, 600, SUB))
    for x1, x2 in ((280, 330), (590, 640), (900, 950)):
        g.append(arrow(x1 + 2, y0 + h / 2, x2 - 4, y0 + h / 2, SUB, 3))
    # RTpred mapping
    g.append(module_tag(30, 580, 870, "rtpred_train (A → D): AutoGluon on 217 RDKit descriptors, one model per mode"))
    g.append(module_tag(950, 580, 260, "rtpred_predict"))
    g.append(module_tag(1240, 580, 330, "rtpred_compare (D, E on held-out rows)"))
    g.append(t(1255, 380, "The pre-trained RP and HILIC", 14, 600, SUB, "start"))
    g.append(t(1255, 404, "models in the image were", 14, 600, SUB, "start"))
    g.append(t(1255, 428, "built the same way (A → D).", 14, 600, SUB, "start"))
    g.append(t(800, 640, "Schematic. Adapted from Xie et al., J Pharm Anal 15, 101155 (2025), Fig. 1 (CC BY 4.0).", 13, 500, SUB))
    return svg("".join(g))


if __name__ == "__main__":
    p = OUT / "concept_2.svg"
    p.write_text(concept_2())
    print(p)
