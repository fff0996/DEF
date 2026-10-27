#!/usr/bin/env python3
"""Metro-style schematics of the CLOSHA spatial transcriptomics pipelines (Visium, Visium HD) (SVG)."""
# Run: python3 docs/Spatial_Transcriptomics_Shared/figures/make_pipeline_map.py, then
# for f in docs/Spatial_Transcriptomics_Visium*_Pipeline/pipeline/figures/pipeline_*.svg; do
#     rsvg-convert -w 2500 "$f" -o "${f%.svg}.png"; done
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[1] / "tools"))
DOCS = HERE.parents[1]
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
TEAL = "#0FA3A3"    # cell-type branch: runs only when a single-cell reference is given
STAGES = [(PURPLE, "Loading &amp; normalisation"), (BLUE, "Clustering"),
          (GREEN, "Condition comparison"), (TEAL, "Cell types (with a reference)"), (YELLOW, "Results")]
W = 2500

# ---------------------------------------------------------------- Visium
m.reset()
y, yS, yL, yR = 1030, 1370, 760, 370
m.route([(140, y), (400, y)], PURPLE)
# clustered slices to the two cell-type modules, two separate branches
m.route([(1130, y), (1130, yR), (1750, yR)], TEAL)
m.route([(1130, yL), (1750, yL)], TEAL)
m.route([(400, y), (1760, y)], BLUE)
m.route([(1250, y), (1250, yS), (1500, yS)], BLUE)      # clustered slices to spatial_svf
m.route([(1760, y), (2270, y)], GREEN)
for x in (400, 1000, 1760):
    m.route([(x, y), (x, y + 150)], YELLOW)
m.route([(2270, y), (2270, y + 170)], YELLOW)
m.route([(1500, yS), (1500, yS + 150)], YELLOW)
m.route([(1750, yL), (1750, yL - 150)], YELLOW)
m.route([(1750, yR), (1750, yR - 150)], YELLOW)

m.node(400, y, "spatial_prep")
m.node(1000, y, "spatial_cluster")
m.node(1760, y, "spatial_merge")
m.node(2270, y, "spatial_\ncondition_de")
m.node(1500, yS, "spatial_svf")
m.node(1750, yL, "spatial_\nlabelTransfer")
m.node(1750, yR, "spatial_rctd")

m.tag(140, y, "H5 + spatial/", "in", gap=50, icon="folder")
m.tag(700, y, "RDS", "in", gap=50, icon="table")
m.tag(1450, y, "RDS", "in", gap=50, icon="table")
m.tag(2010, y, "RDS", "in", gap=50, icon="table")
m.tag(1400, yL, "Reference RDS\n(optional)", "in", gap=50, icon="table")
m.tag(1400, yR, "Reference RDS\n(optional)", "in", gap=50, icon="table")

m.outputs(400, y + 150, ["RDS", "PNG"], above=False, gap=30)
m.outputs(1000, y + 150, ["RDS", "CSV", "PNG"], above=False, gap=30)
m.outputs(1760, y + 150, ["RDS", "CSV", "PNG", "TXT"], above=False, gap=30, dx=60)
m.outputs(2270, y + 170, ["TSV", "PDF", "PNG"], above=False, gap=46)
m.outputs(1500, yS + 150, ["RDS", "CSV", "PNG"], above=False, gap=30)
m.outputs(1750, yL - 150, ["RDS", "CSV", "PNG"], above=True, gap=30)
m.outputs(1750, yR - 150, ["RDS", "CSV", "PNG"], above=True, gap=30)
m.save(DOCS / "Spatial_Transcriptomics_Visium_Pipeline" / "pipeline" / "figures" / "pipeline_visium.svg", W, 2030, "Spatial transcriptomics pipeline (Visium)", STAGES, 1790)

# ---------------------------------------------------------------- Visium HD
m.reset()
y, yS, yC = 860, 1320, 420
m.route([(140, y), (550, y)], PURPLE)
m.route([(1530, y), (1530, yC), (2320, yC)], TEAL)    # clustered slides to spatial_hd_rctd, then condition_de
m.route([(550, y), (1350, y)], BLUE)
m.route([(1350, y), (2100, y)], GREEN)
m.route([(1700, y), (1700, yS), (1950, yS)], BLUE)      # clustered slides to spatial_hd_svf
for x in (550, 1350):
    m.route([(x, y), (x, y + 150)], YELLOW)
m.route([(2100, y), (2100, y + 170)], YELLOW)
m.route([(1950, yS), (1950, yS + 150)], YELLOW)
m.route([(1900, yC), (1900, yC - 150)], YELLOW)
m.route([(2320, yC), (2320, yC - 150)], YELLOW)

m.node(550, y, "spatial_hd_prep")
m.node(1350, y, "spatial_hd_cluster")
m.node(2100, y, "spatial_\ncondition_de")
m.node(1950, yS, "spatial_hd_svf")
m.node(1900, yC, "spatial_hd_rctd")
m.node(2320, yC, "spatial_\ncondition_de")

m.tag(140, y, "H5 + Parquet", "in", gap=50, icon="folder")
m.tag(950, y, "RDS", "in", gap=50, icon="table")
m.tag(1750, y, "RDS + TSV", "in", gap=50, icon="table")
m.tag(1650, yC, "Reference RDS\n(optional)", "in", above=False, gap=50, icon="table")

m.outputs(550, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1350, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(2100, y + 170, ["TSV", "PDF", "PNG"], above=False, gap=46)
m.outputs(1950, yS + 150, ["TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1900, yC - 150, ["RDS", "TSV", "PNG"], above=True, gap=30)
m.outputs(2320, yC - 150, ["TSV", "PDF", "PNG"], above=True, gap=30)
m.save(DOCS / "Spatial_Transcriptomics_Visium_HD_Pipeline" / "pipeline" / "figures" / "pipeline_visium_hd.svg", W, 2000, "Spatial transcriptomics pipeline (Visium HD)", STAGES, 1740)
