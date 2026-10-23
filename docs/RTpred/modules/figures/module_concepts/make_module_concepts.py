#!/usr/bin/env python3
"""Concept figures for the RTpred modules (rtpred_predict, rtpred_train, rtpred_compare), one
drawing per module, in the style of the ATAC-seq module concepts (drawing helpers imported
from there).

Drawn from scratch; the layout follows the usual retention time (RT) prediction workflow
described in the Retip paper (Bonini et al., Anal Chem 2020) and the use of predicted RT to
narrow candidates (Domingo-Almenara et al., Nat Commun 2019). No published figure is copied.

Run: python3 docs/RTpred/modules/figures/module_concepts/make_module_concepts.py,
then for f in <that folder>/*.svg; do rsvg-convert -w 1600 "$f" -o "${f%.svg}.png"; done
Structures, RTs and errors are schematic, not data.
"""
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parent
sys.path.insert(0, str(OUT.parents[3] / "ATAC-seq" / "modules" / "figures" / "module_concepts"))
from make_module_concepts import (MAIN, SUB, POINT, GRAY, PALE, t, panel, line, rect, arrow,  # noqa: E402
                                  axes, svg, table, poly)

RP, HILIC = "#4E79A7", "#E8862A"
OK, NONE = "#2E9E6B", "#8A9099"


def note(x, y, s, color=SUB):
    return t(x, y, s, 14, 500, color, "start")


def chip(x, y, w, label, color, dashed=False, sub=None):
    """Rounded model box; dashed = not available."""
    st = f' stroke-dasharray="6,4"' if dashed else ""
    out = (f'<rect x="{x}" y="{y}" width="{w}" height="46" rx="10" fill="{"#FFFFFF" if dashed else color}" '
           f'fill-opacity="{1 if dashed else 0.14}" stroke="{color}" stroke-width="2.5"{st}/>')
    out += t(x + w / 2, y + (16 if sub else 23), label, 15, 700, color)
    if sub:
        out += t(x + w / 2, y + 34, sub, 12, 500, color)
    return out


def folder(x, y, label, color):
    return (f'<path d="M{x},{y + 8} h22 l6,-8 h34 v8 h18 v46 h-80 z" fill="{color}" fill-opacity="0.16" '
            f'stroke="{color}" stroke-width="2.5"/>' + t(x + 95, y + 30, label, 15, 700, color, "start"))


# ---------------------------------------------------------------- rtpred_predict
def rtpred_predict():
    g = [panel(40, "A", "Compound list")]
    rows = [("C001", "O=C(O)c1ccccc1", "RP"), ("C002", "NCC(=O)O", "HILIC"), ("C003", "CCCCCC(=O)O", "RP")]
    g.append(table(50, 110, ["compound_id", "SMILES", "model_type"], [r[:2] + ("",) for r in rows], [120, 190, 110]))
    for i, (_, _, m) in enumerate(rows):
        g.append(t(370, 160 + i * 32, m, 14, 800, RP if m == "RP" else HILIC, "start"))
    g.append(note(50, 290, "CSV or XLSX, one compound per row"))
    g.append(note(50, 316, "model_type (RP or HILIC) on every row; modes may be mixed"))
    g.append(note(50, 342, "Measured RT optional: gives ΔRT (measured - predicted)"))

    g.append(panel(560, "B", "Model for each row"))
    g.append(t(580, 100, "model_dir empty (default)", 15, 700, MAIN, "start"))
    g.append(chip(580, 115, 200, "RP model", RP, sub="pre-trained, in image"))
    g.append(chip(800, 115, 200, "HILIC model", HILIC, sub="pre-trained, in image"))
    g.append(t(580, 215, "model_dir = rtpred_train output", 15, 700, MAIN, "start"))
    g.append(chip(580, 230, 200, "RP model", RP, sub="user-trained"))
    g.append(chip(800, 230, 200, "HILIC: not trained", NONE, dashed=True))
    g.append(note(580, 320, "Each row uses the model of its model_type"))
    g.append(note(580, 346, "RDKit descriptors → AutoGluon best ensemble"))
    g.append(note(580, 372, "Rows of an untrained mode: not predicted"))

    g.append(panel(1100, "C", "Predicted RT"))
    res = [("C001", "RP", "5.21", "ok"), ("C002", "HILIC", "", "no_trained_model"), ("C003", "RP", "7.84", "ok")]
    g.append(table(1100, 100, ["id", "mode", "pred. RT", "parse_status"], res, [70, 80, 90, 210], {1: NONE}))
    # candidates of one m/z ranked by predicted RT
    ax, ay, aw, ah = 1140, 300, 400, 90
    g.append(axes(ax, ay, aw, ah, "RT (min)", ""))
    g.append(rect(ax + 165, ay, 70, ah, OK, op=0.14))
    g.append(line(ax + 200, ay, ax + 200, ay + ah, OK, 2.5, "6,4"))
    g.append(t(ax + 200, ay - 12, "measured RT", 13, 700, OK))
    for xx, inside in ((60, False), (120, False), (185, True), (215, True), (330, False)):
        g.append(f'<circle cx="{ax + xx}" cy="{ay + 50}" r="9" fill="{OK if inside else GRAY}"/>')
    g.append(note(1100, 440, "Candidates of one m/z: keep those whose predicted RT"))
    g.append(note(1100, 464, "is near the measured RT (metabolite annotation)"))
    return svg("".join(g))


# ---------------------------------------------------------------- rtpred_train
def rtpred_train():
    g = [panel(40, "A", "Measured RT table, split by mode")]
    rows = [("CCO", "2.10", "RP"), ("CCN", "2.80", "RP"), ("O=C(O)c1ccccc1", "5.40", "HILIC"), ("NCC(=O)O", "3.95", "HILIC")]
    g.append(table(50, 100, ["SMILES", "RT (min)", "model_type"], [r[:2] + ("",) for r in rows], [180, 100, 120]))
    for i, (_, _, m) in enumerate(rows):
        g.append(t(340, 150 + i * 32, m, 14, 800, RP if m == "RP" else HILIC, "start"))
    g.append(arrow(250, 270, 150, 320, SUB, 3))
    g.append(arrow(250, 270, 350, 320, SUB, 3))
    g.append(chip(60, 330, 180, "RP rows", RP))
    g.append(chip(270, 330, 180, "HILIC rows", HILIC))
    g.append(note(50, 410, "Each mode: ≥ 25 rows, ≥ 15 distinct structures"))
    g.append(note(50, 436, "One column, mobile phase and gradient per mode"))

    g.append(panel(560, "B", "Per mode: split, train, select"))
    x0, w = 580, 470
    for (lab, frac, col), xx in zip((("train", 0.6, POINT), ("validation", 0.2, OK), ("reserved test", 0.2, GRAY)),
                                    (0, 0.6, 0.8)):
        g.append(rect(x0 + xx * w, 100, frac * w - 4, 34, col, 4, op=0.85))
        g.append(t(x0 + xx * w + frac * w / 2 - 2, 117, lab, 12, 700, "#FFFFFF"))
    g.append(note(580, 156, "Split by canonical structure (no structure in two splits)"))
    cands = [("WeightedEnsemble", 0.42, True), ("ExtraTrees", 0.47, False), ("CatBoost", 0.55, False),
             ("LightGBM", 0.6, False), ("RandomForest", 0.66, False), ("KNeighbors", 0.9, False)]
    for i, (name, v, best) in enumerate(cands):
        y = 190 + i * 34
        g.append(t(720, y + 12, name, 13, 700 if best else 500, POINT if best else SUB, "end"))
        g.append(rect(732, y, v * 300, 24, POINT if best else GRAY, 3, op=0.9 if best else 0.6))
    g.append(t(890, 410, "validation RMSE (shorter = better)", 13, 600, SUB))
    g.append(note(580, 446, "AutoGluon candidates; best = lowest validation RMSE"))

    g.append(panel(1100, "C", "One model per mode"))
    g.append(folder(1110, 100, "result/RP/", RP))
    g.append(note(1205, 160, "model/, reserved_test.csv, leaderboard"))
    g.append(folder(1110, 190, "result/HILIC/", HILIC))
    g.append(note(1205, 250, "model/, reserved_test.csv, leaderboard"))
    g.append(table(1110, 285, ["Mode", "Rows", "Status", "Best_model"],
                   [("RP", "300", "ok", "WeightedEnsemble_L2"), ("HILIC", "200", "ok", "WeightedEnsemble_L2")],
                   [70, 60, 60, 200]))
    g.append(note(1110, 410, "train_summary.tsv"))
    g.append(note(1110, 436, "→ model_dir of rtpred_predict, input_dir of rtpred_compare"))
    return svg("".join(g))


# ---------------------------------------------------------------- rtpred_compare
def rtpred_compare():
    g = [panel(40, "A", "Same mode, two models, same rows")]
    for i, (m, col) in enumerate((("RP", RP), ("HILIC", HILIC))):
        y = 100 + i * 150
        g.append(chip(60, y, 220, f"{m} evaluation rows", col, sub="reserved_test.csv"))
        g.append(arrow(285, y + 23, 345, y + 23, SUB, 3))
        g.append(chip(355, y, 190, f"pre-trained {m}", col))
        g.append(t(575, y + 23, "vs", 16, 800, SUB))
        g.append(chip(605, y, 190, f"user {m}", col))
    g.append(note(60, 420, "Default evaluation rows: reserved_test.csv of each mode; or eval_file with model_type"))
    g.append(note(60, 446, "RP and HILIC are never compared with each other"))
    g.append(note(60, 472, "Structures used in training or validation stop the run (leakage check)"))

    g.append(panel(960, "B", "Errors on the same rows"))
    ax, ay, aw, ah = 1020, 110, 480, 230
    g.append(axes(ax, ay, aw, ah, "", "RMSE (min)"))
    bars = [("RP", RP, 0.75, 0.45), ("HILIC", HILIC, 0.85, 0.6)]
    for i, (m, col, pre, usr) in enumerate(bars):
        bx = ax + 60 + i * 230
        g.append(rect(bx, ay + ah - pre * ah, 70, pre * ah, GRAY, 3))
        g.append(rect(bx + 80, ay + ah - usr * ah, 70, usr * ah, col, 3, op=0.9))
        g.append(t(bx + 75, ay + ah + 24, m, 15, 700, col))
    g.append(rect(1040, 395, 18, 14, GRAY, 3) + t(1066, 402, "pre-trained", 14, 500, SUB, "start"))
    g.append(rect(1200, 395, 9, 14, RP, 0) + rect(1209, 395, 9, 14, HILIC, 0) + t(1226, 402, "user (RP, HILIC)", 14, 500, SUB, "start"))
    g.append(note(980, 446, "RMSE, MAE, R² per candidate, rank, measured vs predicted plot"))
    g.append(note(980, 472, "comparison.csv joins modes (Mode column); pre-trained models stay unchanged"))
    return svg("".join(g))


FIGS = {"rtpred_predict": rtpred_predict, "rtpred_train": rtpred_train, "rtpred_compare": rtpred_compare}


# ---------------------------------------------------------------- figures adapted from CC BY papers
def stepbox(x, y, w, h, title, lines, color=POINT, fill="#FFFFFF"):
    out = f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="12" fill="{fill}" stroke="{color}" stroke-width="2.5"/>'
    out += t(x + w / 2, y + 26, title, 16, 800, color)
    for i, s in enumerate(lines):
        out += t(x + w / 2, y + 58 + i * 24, s, 13, 500, SUB)
    return out


def rtpred_annotation_use():
    """Pipeline concept 2, adapted from Sille et al. 2025 Fig. 1 (CC BY 4.0): the RT calibration
    and projection steps are left out (RTpred has none) and the model is RTpred's."""
    g = [t(800, 34, "Predicted RT in metabolite annotation", 22, 800, MAIN)]
    y, h = 250, 170
    # 1 LC-MS peak
    g.append(stepbox(30, y, 250, h, "1  LC-MS peak", ["m/z 168.0423", "measured RT 9.0 min"]))
    g.append(poly_peak(80, y + 100, 150, 55))
    # 2 candidates
    g.append(stepbox(330, y, 260, h, "2  Candidates", ["structures with the", "same m/z (database)", "candidate a, b, c"]))
    # 3 RTpred
    g.append(stepbox(640, y, 300, h, "3  RTpred prediction", ["RT of each candidate", "pre-trained RP / HILIC model", "or user model (rtpred_train)"],
                     POINT, "#EAF0FA"))
    g.append(stepbox(690, 70, 200, 110, "Measured RT library", ["trains the model", "(beforehand)"], GRAY))
    g.append(arrow(790, 180, 790, y - 4, GRAY, 3))
    # 4 rank
    g.append(stepbox(990, y, 290, h + 60, "4  Rank by ΔRT", []))
    g.append(table(1005, y + 50, ["cand.", "pred. RT", "ΔRT"], [("a", "8.8", "0.2"), ("c", "10.5", "1.5"), ("b", "6.7", "2.3")],
                   [70, 100, 90], {0: OK}))
    # 5 annotation
    g.append(stepbox(1330, y, 250, h, "5  Annotation", ["candidate a kept", "with m/z and MS/MS", "evidence"], OK))
    for x1, x2 in ((280, 330), (590, 640), (940, 990), (1280, 1330)):
        g.append(arrow(x1 + 2, y + h / 2, x2 - 4, y + h / 2, SUB, 3))
    g.append(note(30, 560, "ΔRT = |measured RT - predicted RT|; a small ΔRT supports the candidate, a large one argues against it."))
    g.append(note(30, 590, "Schematic values. Adapted from Sillé et al., Front Public Health 13, 1687056 (2025), Fig. 1 (CC BY 4.0)."))
    return svg("".join(g))


def poly_peak(x, y, w, h):
    pts = []
    import math as _m
    for i in range(41):
        xx = x + w * i / 40
        yy = y + h - h * 0.9 * _m.exp(-((i - 20) / 5.5) ** 2)
        pts.append((xx, yy))
    d = " ".join(f"{a:.1f},{b:.1f}" for a, b in pts)
    return (f'<polyline points="{d}" fill="none" stroke="{POINT}" stroke-width="3"/>'
            + line(x, y + h, x + w, y + h, SUB, 2))


def rtpred_predict_ranking():
    """rtpred_predict concept 2, adapted from Domingo-Almenara et al. 2019 Fig. 4 (CC BY 4.0)."""
    import random as _r
    _r.seed(7)
    g = [panel(40, "A", "Predicted vs measured RT")]
    ax, ay, aw, ah = 120, 90, 560, 360
    g.append(axes(ax, ay, aw, ah, "Predicted RT (min)", "Measured RT (min)"))
    for _ in range(80):
        u = _r.random()
        px, py = ax + 20 + u * (aw - 40), ay + ah - 20 - u * (ah - 40) + _r.gauss(0, 26)
        g.append(f'<circle cx="{px:.1f}" cy="{max(ay + 5, min(ay + ah - 5, py)):.1f}" r="5.5" fill="{SUB}" opacity="0.75"/>')
    g.append(line(ax + 15, ay + ah - 15, ax + aw - 15, ay + 15, RED_, 3, "10,7"))
    hx, hy = ax + 0.45 * aw, ay + ah - 0.45 * ah - 34
    lx, ly = ax + 0.45 * aw, ay + ah - 0.45 * ah
    g.append(line(hx, hy, lx, ly, SUB, 2, "4,4"))
    g.append(f'<circle cx="{hx:.1f}" cy="{hy:.1f}" r="11" fill="{RED_}"/>')
    g.append(line(hx - 8, hy - 8, ax + 150, ay + 62, RED_, 1.5))
    g.append(t(ax + 30, ay + 30, "peak m/z 168.0423", 15, 700, RED_, "start"))
    g.append(t(ax + 30, ay + 52, "distance to the line = RT error", 13, 500, SUB, "start"))
    g.append(note(120, 510, "Points: compounds with known structure; dashed line: predicted = measured"))

    g.append(panel(800, "B", "Candidates ranked by RT error"))
    cands = [("1", "Vanillic acid", "0.2", OK), ("2", "2,6-Dimethoxybenzoquinone", "1.4", RED_),
             ("3", "2,5-Dimethoxybenzoquinone", "2.1", RED_), ("4", "candidate 4", "3.0", RED_),
             ("5", "candidate 5", "4.2", RED_), ("6", "candidate 6", "5.6", RED_)]
    g.append(t(840, 100, "Candidates with m/z 168.0423", 16, 700, SUB, "start"))
    g.append(t(1450, 100, "RT error", 15, 700, SUB, "end"))
    for i, (num, name, err, col) in enumerate(cands):
        y = 150 + i * 58
        rr = 24 - i * 2.4
        g.append(f'<circle cx="870" cy="{y}" r="{rr + 6:.1f}" fill="#F6E3A1"/>')
        g.append(f'<circle cx="870" cy="{y}" r="14" fill="{col}"/>' + t(870, y, num, 14, 800, "#FFFFFF"))
        g.append(t(915, y, name, 16, 700 if i == 0 else 500, OK if i == 0 else MAIN, "start"))
        g.append(t(1450, y, err + " min", 15, 600, OK if i == 0 else SUB, "end"))
    g.append(t(1500, 150, "✓", 24, 800, OK))
    g.append(note(840, 510, "Smaller predicted RT error → higher rank; 1 is the correct structure"))
    g.append(note(40, 600, "Schematic values. Adapted from Domingo-Almenara et al., Nat Commun 10, 5811 (2019), Fig. 4 (CC BY 4.0)."))
    return svg("".join(g))


def rtpred_train_representation():
    """rtpred_train concept 2, adapted from Liu et al. 2024 Fig. 4 (CC BY 4.0): the representations;
    the model timeline is left out."""
    g = [t(800, 34, "Molecular representations for RT prediction", 22, 800, MAIN)]
    g.append(stepbox(620, 90, 360, 140, "String of symbols", ["SMILES, canonical SMILES, InChI", "(input of RTpred: SMILES)"], SUB, "#F5F6F8"))
    boxes = [(80, "Molecular descriptors", ["physicochemical values", "and graph operators", "RTpred: 217 RDKit descriptors"], POINT, "#EAF0FA"),
             (620, "Molecular fingerprints", ["MACCS keys", "ECFP, PFP"], GRAY, "#FFFFFF"),
             (1160, "Molecular graphs", ["computer-generated graphs", "for graph neural networks"], GRAY, "#FFFFFF")]
    for x, title, lines, col, fill in boxes:
        g.append(stepbox(x, 320, 360, 170, title, lines, col, fill))
    g.append(arrow(700, 230, 300, 316, POINT, 3.5))
    g.append(arrow(800, 230, 800, 316, GRAY, 3))
    g.append(arrow(900, 230, 1300, 316, GRAY, 3))
    g.append(t(470, 262, "convert (RDKit)", 14, 700, POINT))
    g.append(t(1150, 262, "convert", 14, 600, SUB))
    g.append(note(80, 530, "RTpred (like Retip) converts SMILES to descriptors and trains AutoGluon models on them."))
    g.append(note(80, 600, "Adapted from Liu et al., J Cheminform 16, 113 (2024), Fig. 4 (CC BY 4.0); the model timeline is left out."))
    return svg("".join(g))


RED_ = "#D6604D"
FIGS.update({"rtpred_predict_ranking": rtpred_predict_ranking, "rtpred_train_representation": rtpred_train_representation,
             "rtpred_annotation_use": rtpred_annotation_use})

if __name__ == "__main__":
    for name, fn in FIGS.items():
        p = OUT / f"{name}_concept.svg"
        p.write_text(fn())
        print(p)
