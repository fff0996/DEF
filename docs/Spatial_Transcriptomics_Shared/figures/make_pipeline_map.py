#!/usr/bin/env python3
"""Metro-style schematics of the CLOSHA spatial transcriptomics pipelines (Visium, Visium HD) (SVG)."""
# Run: python3 docs/Spatial_Transcriptomics_Shared/figures/make_pipeline_map.py, then
# for f in docs/Spatial_Transcriptomics_Visium*_Pipeline/pipeline/figures/pipeline_*.svg; do
#     rsvg-convert -w 2500 "$f" -o "${f%.svg}.png"; done  (Visium HD map: -w 3000)
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
# Rows: niche (top), cell-type branch, main line, spatially variable genes, gene set scores.
m.reset()
WH = 3000
y, yC, yN, yS, yG = 1200, 690, 330, 1660, 2050
m.route([(140, y), (550, y)], PURPLE)
m.route([(1530, y), (1530, yC), (2760, yC)], TEAL)    # clustered slides to spatial_hd_rctd, condition_de, enrichment
m.route([(2110, yC), (2110, yN), (2400, yN)], TEAL)   # cell types to spatial_niche
m.route([(550, y), (1350, y)], BLUE)
m.route([(1350, y), (2560, y)], GREEN)
m.route([(1700, y), (1700, yS), (1950, yS)], BLUE)      # clustered slides to spatial_hd_svf
m.route([(1620, y), (1620, yG), (1950, yG)], BLUE)      # clustered slides to spatial_signature_score
for x in (550, 1350):
    m.route([(x, y), (x, y + 150)], YELLOW)
for x in (2100, 2560):
    m.route([(x, y), (x, y + 170)], YELLOW)
m.route([(1950, yS), (1950, yS + 150)], YELLOW)
m.route([(1950, yG), (1950, yG + 150)], YELLOW)
for x in (1900, 2320, 2760):
    m.route([(x, yC), (x, yC + 150)], YELLOW)
m.route([(2400, yN), (2400, yN - 150)], YELLOW)

m.node(550, y, "spatial_hd_prep")
m.node(1350, y, "spatial_hd_cluster")
m.node(2100, y, "spatial_\ncondition_de")
m.node(2560, y, "spatial_de_\nenrichment")
m.node(1950, yS, "spatial_hd_svf")
m.node(1950, yG, "spatial_signature_\nscore")
m.node(1900, yC, "spatial_hd_rctd")
m.node(2320, yC, "spatial_\ncondition_de")
m.node(2760, yC, "spatial_de_\nenrichment")
m.node(2400, yN, "spatial_niche")

m.tag(140, y, "H5 + Parquet", "in", gap=50, icon="folder")
m.tag(950, y, "RDS", "in", gap=50, icon="table")
m.tag(1830, y, "RDS + TSV", "in", gap=50, icon="table")
m.tag(1650, yC, "Reference RDS\n(optional)", "in", above=True, gap=50, icon="table")
# check_reference is a separate pre-check of the reference, run on its own: it reads the same
# reference file and prints its columns, and no module takes its output, so it is not joined to
# the pipeline line; its own input, its column report below and a caption above
yK, xK = yC - 86, 1170
m.route([(xK - 380, yK), (xK, yK)], TEAL)
m.node(xK, yK, "check_reference")
m.tag(xK - 380, yK, "Reference RDS", "in", gap=50, icon="table")
m.overlay.append(f'<text x="{xK}" y="{yK - 92}" text-anchor="middle" font-family="{m.FONT}" font-size="19" '
                 f'font-weight="500" fill="{m.TEXT}">Optional pre-check, run on its own</text>'
                 f'<text x="{xK}" y="{yK - 66}" text-anchor="middle" font-family="{m.FONT}" font-size="19" '
                 f'font-weight="500" fill="{m.TEXT}">(lists the cell-type columns)</text>')
m.route([(xK, yK), (xK, yK + 150)], YELLOW)
m.outputs(xK, yK + 150, ["TSV"], above=False, gap=30)

m.outputs(550, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1350, y + 150, ["RDS", "TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(2100, y + 170, ["TSV", "PDF", "PNG"], above=False, gap=46)
m.outputs(2560, y + 170, ["TSV", "PNG", "PDF"], above=False, gap=46)
m.outputs(1950, yS + 150, ["TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1950, yG + 150, ["TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(1900, yC + 150, ["RDS", "TSV", "PNG"], above=False, gap=30)
m.outputs(2320, yC + 150, ["TSV", "PDF", "PNG"], above=False, gap=30)
m.outputs(2760, yC + 150, ["TSV", "PNG", "PDF"], above=False, gap=30)
m.outputs(2400, yN - 150, ["TSV", "PNG", "PDF"], above=True, gap=30)
m.save(DOCS / "Spatial_Transcriptomics_Visium_HD_Pipeline" / "pipeline" / "figures" / "pipeline_visium_hd.svg", WH, 2450, "Spatial transcriptomics pipeline (Visium HD)", STAGES, 2140)
