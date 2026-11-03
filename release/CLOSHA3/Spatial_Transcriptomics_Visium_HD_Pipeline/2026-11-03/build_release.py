#!/usr/bin/env python3
"""Build the CLOSHA 3.0 Visium HD spatial release of 2026-11-03 from the work files.

This release adds three downstream modules, new in CLOSHA 3.0 and released as
1.0: spatial_niche, spatial_signature_score, spatial_de_enrichment. Their work
files already carry the number 1.0 and have no work-version history, so they
are copied as they are. They run in bx_spatial 1.2. The modules of the
2026-10-28 release are not changed and stay in that folder.
The docs (all modules), the portal images of the three modules and the
pipeline figures (map with the new modules) are copied as they are.

Run from the repository root:
  python3 release/CLOSHA3/Spatial_Transcriptomics_Visium_HD_Pipeline/2026-11-03/build_release.py
"""
import re
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "scripts" / "Spatial_Transcriptomics_Analysis_Pipeline"
DOCS = ROOT / "docs" / "Spatial_Transcriptomics_Visium_HD_Pipeline"
SHARED = ROOT / "docs" / "Spatial_Transcriptomics_Shared"
OUT = Path(__file__).resolve().parent
IMAGE = "bx_spatial 1.2 (defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.2.def)"

# module, work file, release file, CLOSHA 2.0 file
MODULES = [
    ("spatial_niche", "spatial_niche.1.0.R", "spatial_niche.1.0.R", "(new in 3.0)"),
    ("spatial_signature_score", "spatial_signature_score.1.0.R", "spatial_signature_score.1.0.R", "(new in 3.0)"),
    ("spatial_de_enrichment", "spatial_de_enrichment.1.0.R", "spatial_de_enrichment.1.0.R", "(new in 3.0)"),
]

# Docs copied as they are: (source, target under docs)
DOC_FILES = [
    (DOCS / "modules/Portal_Content.md", "Portal_Content.md"),
    (DOCS / "modules/Portal_Content.docx", "Portal_Content.docx"),
    (DOCS / "modules/Registration.md", "Registration.md"),
    (SHARED / "containers/Container_Manual.md", "Container_Manual.md"),
    (ROOT / "defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.2.def", "bx_spatial.1.2.def"),
    (ROOT / "tools/spatial/example/crc_gene_sets.gmt", "example/crc_gene_sets.gmt"),
    (DOCS / "pipeline/Portal_Content.md", "pipeline/Portal_Content.md"),
    (DOCS / "pipeline/Portal_Content.docx", "pipeline/Portal_Content.docx"),
    (DOCS / "pipeline/figures/pipeline_visium_hd.png", "pipeline/pipeline.png"),
    (DOCS / "pipeline/figures/pipeline_visium_hd.svg", "pipeline/pipeline.svg"),
]
# Pipeline portal image that changed (map with the new modules)
PIPELINE_IMAGES = [
    ("pipeline/figures/pipeline_visium_hd.png", "pipeline/pipeline.png"),
]


def git_commit():
    return subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def module_images(modules):
    """(source, target) of the concept and result figures of the given modules, in manuscript order."""
    text = (DOCS / "modules/Portal_Content.md").read_text()
    pairs = []
    for section in re.split(r"(?m)^(?=## \d+\. )", text):
        m = re.match(r"## \d+\. (\S+)", section)
        if not m or m.group(1) not in modules:
            continue
        module = m.group(1)
        concepts = 0
        for path in re.findall(r"(?m)^그림: `([^`]+)`", section):
            src = ROOT / path
            if "/module_concepts/" in path:
                concepts += 1
                name = f"{module}_concept.png" if concepts == 1 else f"{module}_concept_{concepts}.png"
            else:
                name = Path(path).name  # already <module>_result_<N>.png
            pairs.append((src, f"{module}/{name}"))
    return pairs


def copy(pairs, base):
    for src, dst in pairs:
        target = OUT / base / dst
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, target)


def main():
    commit = git_commit()
    rows = []
    for module, work, release, closha2 in MODULES:
        shutil.copy2(WORK / work, OUT / release)
        (OUT / release).chmod(0o644)
        rows.append((module, release, closha2, f"scripts/Spatial_Transcriptomics_Analysis_Pipeline/{work}", IMAGE))
    with open(OUT / "release.tsv", "w") as fh:
        fh.write("module\trelease_file\tclosha2_file\twork_file\timage\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    images = module_images({m[0] for m in MODULES})
    copy(images, "portal_images")
    copy([(DOCS / s, d) for s, d in PIPELINE_IMAGES], "portal_images")
    copy(DOC_FILES, "docs")
    print(f"built {len(rows)} release files and {len(images)} module images from commit {commit}")


if __name__ == "__main__":
    main()
