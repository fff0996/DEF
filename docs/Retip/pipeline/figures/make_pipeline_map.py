#!/usr/bin/env python3
"""Metro-style schematics of the CLOSHA RTpred (Retip) pipelines (SVG):
default prediction (retip_predict only) and user model (retip_train -> retip_predict,
retip_train -> retip_compare)."""
# Run: python3 docs/Retip/pipeline/figures/make_pipeline_map.py, then
# for f in docs/Retip/pipeline/figures/pipeline_*.svg; do rsvg-convert -w 2500 "$f" -o "${f%.svg}.png"; done
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
W = 2500

# ---------------------------------------------------------------- default prediction
m.reset()
y = 520
m.route([(300, y), (1250, y)], BLUE)
m.route([(1250, y), (1250, y + 170)], YELLOW)
m.node(1250, y, "retip_predict")
m.refs(1250, y, [("Default RP/HILIC models (in image)", "table")])
m.tag(300, y, "CSV / XLSX (SMILES)", "in", gap=50, icon="doc")
m.outputs(1250, y + 170, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=46)
m.save(HERE / "pipeline_default.svg", W, 1060, "RTpred: default model prediction",
       [(BLUE, "Prediction"), (YELLOW, "Results")], 880)

# ---------------------------------------------------------------- user model
m.reset()
yT, yB = 560, 1180
m.route([(260, yT), (700, yT)], PURPLE)
m.route([(700, yT), (1650, yT)], PURPLE)                 # trained model to retip_predict
m.route([(1000, yT), (1000, yB), (1650, yB)], GREEN)       # same train output to retip_compare
m.route([(700, yT), (700, yT + 150)], YELLOW)
m.route([(1650, yT), (1650, yT + 170)], YELLOW)
m.route([(1650, yB), (1650, yB + 170)], YELLOW)

m.node(700, yT, "retip_train")
m.node(1650, yT, "retip_predict")
m.node(1650, yB, "retip_compare")
m.refs(1650, yT, [("Compounds: CSV / XLSX (SMILES)", "doc")])
m.refs(1650, yB, [("Default models (in image)", "table"), ("Evaluation table (optional)", "doc")])

m.tag(260, yT, "CSV / XLSX (SMILES + RT)", "in", gap=50, icon="doc")
m.tag(1300, yT, "model/ (AutoGluon)", "in", gap=50, icon="folder")
m.tag(1300, yB, "model/ + reserved_test.csv", "in", above=False, gap=50, icon="folder")

m.outputs(700, yT + 150, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=30)
m.outputs(1650, yT + 170, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=46)
m.outputs(1650, yB + 170, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=46)
m.save(HERE / "pipeline_user_model.svg", W, 1800, "RTpred: user model (train, predict, compare)",
       [(PURPLE, "Model training"), (GREEN, "Model comparison"), (YELLOW, "Results")], 1620)
