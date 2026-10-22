#!/usr/bin/env python3
"""Metro-style schematics of the CLOSHA CNV pipelines (tumor-normal, tumor-only) (SVG)."""
# Run: python3 docs/CNV/pipeline/figures/make_pipeline_map.py, then render the PNGs with
# for f in docs/CNV/pipeline/figures/pipeline_*.svg; do rsvg-convert -w 2500 "$f" -o "${f%.svg}.png"; done
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parents[2] / "tools"))
import metro_map as m  # noqa: E402

PURPLE, BLUE, GREEN, YELLOW = m.PURPLE, m.BLUE, m.GREEN, m.YELLOW
STAGES = [(PURPLE, "Normal reference"), (BLUE, "Purity &amp; ploidy (FACETS)"),
          (GREEN, "Copy-number calling"), (YELLOW, "Results &amp; report")]
W = 2500

# ---------------------------------------------------------------- tumor-normal
m.reset()
yT, yM, yL = 430, 1000, 1340
# BAM folder feeds FACETS (top), the normal reference (middle) and cnvkit_call (bottom)
m.route([(140, yM), (300, yM), (300, yT), (1560, yT), (1560, yM)], BLUE)
m.route([(1560, yT), (2150, yT), (2150, yM)], BLUE)
m.route([(300, yM), (1450, yM)], PURPLE)
m.route([(300, yM), (300, yL), (1390, yL), (1390, yM)], GREEN)
m.route([(1450, yM), (2150, yM)], GREEN)
m.route([(2150, yM), (2150, yM + 170)], YELLOW)
# per-module output stubs
m.route([(700, yT), (700, yT + 150)], YELLOW)
m.route([(700, yM), (700, yM + 150)], YELLOW)
m.route([(1520, yM), (1520, yM + 170)], YELLOW)

m.node(700, yT, "cnv_facets")
m.node(700, yM, "cnvkit_\nreference")
m.node(1450, yM, "cnvkit_call")
m.node(2150, yM, "cnv_summary")

m.refs(700, yT, [("SNP sites (.vcf.gz)", "vcf")])
m.refs(700, yM, [("REF.FASTA", "fasta"), ("Targets (.bed)", "doc"), ("refFlat (.txt)", "fasta")])
m.refs(1400, yM, [("Genes (.txt)", "doc")])

m.tag(140, yM, "BAM", "in", gap=50, icon="bam")
m.tag(1150, yT, "TSV", "in", gap=50, icon="doc")
m.tag(1100, yM, "CNN", "in", gap=50, icon="doc")
m.tag(1800, yM, "TSV", "in", gap=50, icon="doc")
m.tag(850, yL, "BAM", "in", above=False, gap=50, icon="bam")

m.outputs(700, yT + 150, ["TSV", "PDF", "PNG"], above=False, gap=30)
m.outputs(700, yM + 150, ["CNN", "BED", "TSV"], above=False, gap=30)
m.outputs(1520, yM + 170, ["TSV", "SEG", "PDF", "PNG"], above=False, gap=46, dx=170)
m.outputs(2150, yM + 170, ["TSV", "SEG", "PDF", "PNG", "HTML"], above=False, gap=46)
m.save(HERE / "pipeline_tumor_normal.svg", W, 1800, "CNV pipeline (tumor-normal)", STAGES, 1620)

# ---------------------------------------------------------------- tumor-only
m.reset()
yM = 560
m.route([(140, yM), (300, yM), (1450, yM)], PURPLE)
m.route([(300, yM), (300, yM + 340), (1390, yM + 340), (1390, yM)], GREEN)
m.route([(1450, yM), (2150, yM)], GREEN)
m.route([(2150, yM), (2150, yM + 170)], YELLOW)
m.route([(700, yM), (700, yM + 150)], YELLOW)
m.route([(1520, yM), (1520, yM + 170)], YELLOW)

m.node(700, yM, "cnvkit_\nreference")
m.node(1450, yM, "cnvkit_call")
m.node(2150, yM, "cnv_summary")
m.refs(700, yM, [("REF.FASTA", "fasta"), ("Targets (.bed)", "doc"), ("refFlat (.txt)", "fasta")])
m.refs(1400, yM, [("Genes (.txt)", "doc")])

m.tag(140, yM, "BAM", "in", gap=50, icon="bam")
m.tag(1100, yM, "CNN", "in", gap=50, icon="doc")
m.tag(1800, yM, "TSV", "in", gap=50, icon="doc")
m.tag(850, yM + 340, "BAM", "in", above=False, gap=50, icon="bam")

m.outputs(700, yM + 150, ["CNN", "BED", "TSV"], above=False, gap=30)
m.outputs(1520, yM + 170, ["TSV", "SEG", "PDF", "PNG"], above=False, gap=46, dx=170)
m.outputs(2150, yM + 170, ["TSV", "SEG", "PDF", "PNG", "HTML"], above=False, gap=46)
m.save(HERE / "pipeline_tumor_only.svg", W, 1300, "CNV pipeline (tumor-only)",
       [s for s in STAGES if s[0] != BLUE], 1100)
