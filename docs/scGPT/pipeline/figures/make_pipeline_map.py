#!/usr/bin/env python3
"""Metro-style schematic of the CLOSHA scGPT patient-level prediction pipeline (SVG):
scgpt_prep -> scgpt_embed (GPU) -> scgpt_train; scgpt_predict and scgpt_compare take the
embeddings (input_dir) and the trained model (model / models)."""
# Run: python3 docs/scGPT/pipeline/figures/make_pipeline_map.py, then
# rsvg-convert -w 2500 docs/scGPT/pipeline/figures/pipeline.svg -o docs/scGPT/pipeline/figures/pipeline.png
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
W, H = 2500, 1800

m.reset()
yT, yM, yB = 480, 930, 1340
xP, xE, xT, xR = 450, 1050, 1650, 2280       # prep, embed, train, predict/compare
xB, xG = 1300, 2020                         # embeddings branch, model branch
d = 20                                      # two lines enter predict / compare side by side

m.route([(140, yT), (xE, yT)], PURPLE)
m.route([(xE, yT), (xT, yT)], BLUE)
m.route([(xB, yT), (xB, yM + d), (xR, yM + d)], BLUE)             # embeddings -> scgpt_predict
m.route([(xB, yM + d), (xB, yB + d), (xR, yB + d)], BLUE)         # embeddings -> scgpt_compare
m.route([(xT, yT), (xG, yT), (xG, yB - d), (xR, yB - d)], GREEN, halo=True)   # model -> compare
m.route([(xG, yM - d), (xR, yM - d)], GREEN)                       # model -> predict
for x, y, n in ((xP, yT, 150), (xE, yT, 150), (xT, yT, 150), (xR, yM, 150), (xR, yB, 150)):
    m.route([(x, y), (x, y + n)], YELLOW)

m.node(xP, yT, "scgpt_prep", color=PURPLE)
m.node(xE, yT, "scgpt_embed", color=BLUE)
m.node(xT, yT, "scgpt_train", color=GREEN)
m.node(xR, yM, "scgpt_predict", color=GREEN)
m.node(xR, yB, "scgpt_compare", color=GREEN)
m.refs(xP, yT, [("Sample sheet (.csv)", "doc")])
m.refs(xE, yT, [("scGPT whole-human (in image)", "table")])

m.tag(140, yT, "H5 / H5AD / MTX", "in", gap=50, icon="table")
m.tag(760, yT, "H5AD", "in", gap=50, icon="doc")
m.tag(1440, yT, "H5AD", "in", gap=50, icon="doc")
m.tag(1900, yT, "PT", "in", gap=50, icon="doc")

m.outputs(xP, yT + 150, ["H5AD", "TSV", "JSON", "PDF", "PNG"], above=False, gap=30)
m.outputs(xE, yT + 150, ["H5AD", "JSON", "PDF", "PNG"], above=False, gap=30)
m.outputs(xT, yT + 150, ["PT", "JSON", "TSV", "PDF", "PNG"], above=False, gap=30)
m.outputs(xR, yM + 150, ["TSV", "JSON", "PDF", "PNG"], above=False, gap=30)
m.outputs(xR, yB + 150, ["TSV", "MD", "PDF", "PNG"], above=False, gap=30)
m.save(HERE / "pipeline.svg", W, H, "scGPT_Patient_Prediction_Pipeline",
       [(PURPLE, "Data preparation"), (BLUE, "scGPT cell embedding (GPU)"),
        (GREEN, "Patient model: train, predict, compare"), (YELLOW, "Results")], 1560)
