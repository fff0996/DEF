#!/usr/bin/env python3
"""Metro-style schematics of the CLOSHA spatial transcriptomics pipelines (Visium, Visium HD) (SVG)."""
# Run: python3 docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/make_pipeline_map.py, then
# for f in docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/pipeline_*.svg; do
#     rsvg-convert -w 2500 "$f" -o "${f%.svg}.png"; done
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
STAGES = [(PURPLE, "Loading &amp; normalisation"), (BLUE, "Clustering"),
          (GREEN, "Condition comparison"), (YELLOW, "Results")]
W = 2500

# ---------------------------------------------------------------- Visium
m.reset()
y, yS = 560, 900
m.route([(140, y), (400, y)], PURPLE)
m.route([(400, y), (1760, y)], BLUE)
m.route([(1250, y), (1250, yS), (1500, yS)], BLUE)      # clustered slices to spatial_svf
m.route([(1760, y), (2270, y)], GREEN)
for x in (400, 1000, 1760):
    m.route([(x, y), (x, y + 150)], YELLOW)
m.route([(2270, y), (2270, y + 170)], YELLOW)
m.route([(1500, yS), (1500, yS + 150)], YELLOW)

m.node(400, y, "spatial_prep")
m.node(1000, y, "spatial_cluster")
m.node(1760, y, "spatial_merge")
m.node(2270, y, "spatial_\ncondition_de")
m.node(1500, yS, "spatial_svf")

m.tag(140, y, "H5 + spatial/", "in", gap=50, icon="folder")
m.tag(700, y, "RDS", "in", gap=50, icon="table")
m.tag(1450, y, "RDS", "in", gap=50, icon="table")
m.tag(2010, y, "RDS", "in", gap=50, icon="table")

m.outputs(400, y + 150, ["RDS", "PNG"], above=False, gap=30)
m.outputs(1000, y + 150, ["RDS", "CSV", "PNG"], above=False, gap=30)
m.outputs(1760, y + 150, ["RDS", "CSV", "PNG", "TXT"], above=False, gap=30, dx=60)
m.outputs(2270, y + 170, ["TSV", "PDF", "PNG"], above=False, gap=46)
m.outputs(1500, yS + 150, ["RDS", "CSV", "PNG"], above=False, gap=30)
m.save(HERE / "pipeline_visium.svg", W, 1500, "Spatial transcriptomics pipeline (Visium)", STAGES, 1320)

# ---------------------------------------------------------------- Visium HD
m.reset()
y, yS = 560, 1020
m.route([(140, y), (550, y)], PURPLE)
m.route([(550, y), (1350, y)], BLUE)
m.route([(1350, y), (2100, y)], GREEN)
m.route([(1700, y), (1700, yS), (1950, yS)], BLUE)      # clustered slides to spatial_hd_svf
for x in (550, 1350):
    m.route([(x, y), (x, y + 150)], YELLOW)
m.route([(2100, y), (2100, y + 170)], YELLOW)
m.route([(1950, yS), (1950, yS + 150)], YELLOW)

m.node(550, y, "spatial_hd_prep")
m.node(1350, y, "spatial_hd_cluster")
m.node(2100, y, "spatial_\ncondition_de")
m.node(1950, yS, "spatial_hd_svf")

m.tag(140, y, "H5 + Parquet", "in", gap=50, icon="folder")
m.tag(950, y, "RDS", "in", gap=50, icon="table")
m.tag(1750, y, "RDS + TSV", "in", gap=50, icon="table")

m.outputs(550, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1350, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(2100, y + 170, ["TSV", "PDF", "PNG"], above=False, gap=46)
m.outputs(1950, yS + 150, ["TSV", "PNG", "PDF"], above=False, gap=30)
m.save(HERE / "pipeline_visium_hd.svg", W, 1640, "Spatial transcriptomics pipeline (Visium HD)", STAGES, 1440)
