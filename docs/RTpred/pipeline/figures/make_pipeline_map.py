#!/usr/bin/env python3
"""Metro-style schematic of the CLOSHA RTpred pipeline (SVG): rtpred_train -> rtpred_predict and
rtpred_train -> rtpred_compare; rtpred_predict also runs alone with the pre-trained models."""
# Run: python3 docs/RTpred/pipeline/figures/make_pipeline_map.py, then
# rsvg-convert -w 2500 docs/RTpred/pipeline/figures/pipeline.svg -o docs/RTpred/pipeline/figures/pipeline.png
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
W = 2500

m.reset()
yT, yB = 560, 1180
m.route([(260, yT), (700, yT)], PURPLE)
m.route([(700, yT), (1650, yT)], PURPLE)                 # trained models to rtpred_predict
m.route([(1000, yT), (1000, yB), (1650, yB)], GREEN)       # same train output to rtpred_compare
m.route([(700, yT), (700, yT + 150)], YELLOW)
m.route([(1650, yT), (1650, yT + 170)], YELLOW)
m.route([(1650, yB), (1650, yB + 170)], YELLOW)

m.node(700, yT, "rtpred_train")
m.node(1650, yT, "rtpred_predict")
m.node(1650, yB, "rtpred_compare")
m.refs(1650, yT, [("Compounds (SMILES)", "doc"), ("or pre-trained models", "table")])
m.refs(1650, yB, [("Pre-trained models (in image)", "table"), ("Evaluation table (optional)", "doc")])

m.tag(260, yT, "SMILES + RT + model_type", "in", gap=50, icon="doc")
m.tag(1170, yT, "RP / HILIC models", "in", gap=50, icon="folder")
m.tag(1300, yB, "models + reserved_test.csv", "in", above=False, gap=50, icon="folder")

m.outputs(700, yT + 150, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=30)
m.outputs(1650, yT + 170, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=46)
m.outputs(1650, yB + 170, ["CSV", "PNG", "SVG", "HTML", "JSON"], above=False, gap=46)
m.save(HERE / "pipeline.svg", W, 1800, "RTpred: retention time prediction (train, predict, compare)",
       [(PURPLE, "Model training and prediction"), (GREEN, "Model comparison"), (YELLOW, "Results")], 1620)
