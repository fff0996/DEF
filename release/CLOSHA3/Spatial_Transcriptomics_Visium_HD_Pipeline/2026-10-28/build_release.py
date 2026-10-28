#!/usr/bin/env python3
"""Build the CLOSHA 3.0 Visium HD spatial release of 2026-10-28 from the work files.

Five modules are new in CLOSHA 3.0 and are released as 1.0. check_reference
was in CLOSHA 2.0 (1.0) and is released as 1.1; its work file already has that
number and one "changes from CLOSHA 2.0" block, so it is copied as it is.
For the new modules each release file is the work file with
  - the work-version change history at the top replaced by one
    "first release" line, and
  - its own work file name replaced by the release file name.
Nothing else is changed; tools/check_release.py verifies that. The docs,
portal images and pipeline figures are copied as they are.

Run from the repository root:
  python3 release/CLOSHA3/Spatial_Transcriptomics_Visium_HD_Pipeline/2026-10-28/build_release.py
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
IMAGE = "bx_spatial 1.1 (defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def)"

# module, work file, release file, CLOSHA 2.0 file
MODULES = [
    ("spatial_hd_prep", "spatial_hd_prep.1.1.R", "spatial_hd_prep.1.0.R", "(new in 3.0)"),
    ("spatial_hd_cluster", "spatial_hd_cluster.1.1.R", "spatial_hd_cluster.1.0.R", "(new in 3.0)"),
    ("spatial_hd_svf", "spatial_hd_svf.1.1.R", "spatial_hd_svf.1.0.R", "(new in 3.0)"),
    ("spatial_condition_de", "spatial_condition_de.1.4.R", "spatial_condition_de.1.0.R", "(new in 3.0)"),
    ("spatial_hd_rctd", "spatial_hd_rctd.1.2.R", "spatial_hd_rctd.1.0.R", "(new in 3.0)"),
    ("check_reference", "check_reference.1.1.R", "check_reference.1.1.R", "check_reference.1.0.R"),
]

# Docs copied as they are: (source, target under docs)
DOC_FILES = [
    (DOCS / "modules/Portal_Content.md", "Portal_Content.md"),
    (DOCS / "modules/Portal_Content.docx", "Portal_Content.docx"),
    (DOCS / "modules/Registration.md", "Registration.md"),
    (SHARED / "containers/Container_Manual.md", "Container_Manual.md"),
    (DOCS / "pipeline/Portal_Content.md", "pipeline/Portal_Content.md"),
    (DOCS / "pipeline/Portal_Content.docx", "pipeline/Portal_Content.docx"),
    (DOCS / "pipeline/figures/pipeline_visium_hd.png", "pipeline/pipeline.png"),
    (DOCS / "pipeline/figures/pipeline_visium_hd.svg", "pipeline/pipeline.svg"),
    (DOCS / "pipeline/figures/concept_williams2022_fig1_arrays.png", "pipeline/concept_williams2022_fig1_arrays.png"),
    (DOCS / "pipeline/figures/concept_williams2022_fig3.png", "pipeline/concept_williams2022_fig3.png"),
    (DOCS / "pipeline/figures/concept.png", "pipeline/concept.png"),
    (DOCS / "pipeline/figures/concept.svg", "pipeline/concept.svg"),
    (DOCS / "pipeline/figures/representative.png", "pipeline/thumbnail.png"),
]
# Pipeline portal images in the order of the pipeline manuscript
PIPELINE_IMAGES = [
    ("pipeline/figures/pipeline_visium_hd.png", "pipeline/pipeline.png"),
    ("pipeline/figures/concept_williams2022_fig1_arrays.png", "pipeline/concept_1.png"),
    ("pipeline/figures/concept_williams2022_fig3.png", "pipeline/concept_2.png"),
    ("pipeline/figures/concept.png", "pipeline/concept_3.png"),
    ("pipeline/figures/representative.png", "pipeline/thumbnail.png"),
]


def git_commit():
    return subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def release_text(work, release):
    """Replace the version history (first '# Version' line up to the module description) with one line."""
    lines = (WORK / work).read_text().split("\n")
    start = next(i for i, ln in enumerate(lines[:80]) if ln.startswith("# Version "))
    end = next(i for i, ln in enumerate(lines[:80]) if ln.startswith("# Spatial module"))
    work_no = re.search(r"\.(\d+\.\d+)\.R$", work).group(1)
    head = [f"# Version 1.0 (first release in CLOSHA 3.0; work version {work_no}):"]
    return "\n".join(lines[:start] + head + lines[end:]).replace(work, release)


def module_images():
    """(source, target) of each module's concept and result figures, in manuscript order."""
    text = (DOCS / "modules/Portal_Content.md").read_text()
    pairs = []
    for section in re.split(r"(?m)^(?=## \d+\. )", text):
        m = re.match(r"## \d+\. (\S+)", section)
        if not m:
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
        if work == release:
            shutil.copy2(WORK / work, OUT / release)
        else:
            (OUT / release).write_text(release_text(work, release))
        (OUT / release).chmod(0o644)
        rows.append((module, release, closha2, f"scripts/Spatial_Transcriptomics_Analysis_Pipeline/{work}", IMAGE))
    with open(OUT / "release.tsv", "w") as fh:
        fh.write("module\trelease_file\tclosha2_file\twork_file\timage\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    copy(module_images(), "portal_images")
    copy([(DOCS / s, d) for s, d in PIPELINE_IMAGES], "portal_images")
    copy(DOC_FILES, "docs")
    print(f"built {len(rows)} release files from commit {commit}")


if __name__ == "__main__":
    main()
