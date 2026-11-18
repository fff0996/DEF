#!/usr/bin/env python3
"""Build the CLOSHA 3.0 CNV release (Somatic_CNV_Pipeline) of 2026-11-18 from the work files.

CNV is new in CLOSHA 3.0, so every module is released as 1.0. Three work files are
already 1.0 and are byte copies; cnvkit_call.1.1.py is released as cnvkit_call.1.0.py
with its version block removed and its own name replaced. tools/check_release.py
verifies that. The docs, portal images and pipeline figures are copied as they are.

Run from the repository root:
  python3 release/CLOSHA3/CNV/2026-11-18/build_release.py
"""
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "scripts" / "CNV"
DOCS = ROOT / "docs" / "CNV"
OUT = Path(__file__).resolve().parent

# module, work file, release file, image
MODULES = [
    ("cnvkit_reference", "cnvkit_reference.1.0.py", "cnvkit_reference.1.0.py", "bx_cnvkit 1.0"),
    ("cnv_facets", "cnv_facets.1.0.R", "cnv_facets.1.0.R", "bx_facets 1.0"),
    ("cnvkit_call", "cnvkit_call.1.1.py", "cnvkit_call.1.0.py", "bx_cnvkit 1.0"),
    ("cnv_summary", "cnv_summary.1.0.py", "cnv_summary.1.0.py", "bx_cnvkit 1.0"),
]

R = "modules/figures/results/"
C = "modules/figures/module_concepts/"
# Portal images: (source under docs/CNV, target under portal_images)
IMAGES = [(C + f"{m}_concept.png", f"{m}/{m}_concept.png") for m, *_ in MODULES] + \
    [(R + "cnvkit_reference_result_1.png", "cnvkit_reference/cnvkit_reference_result_1.png")] + \
    [(R + f"cnv_facets_result_{i}.png", f"cnv_facets/cnv_facets_result_{i}.png") for i in range(1, 5)] + \
    [(R + f"cnvkit_call_result_{i}.png", f"cnvkit_call/cnvkit_call_result_{i}.png") for i in range(1, 7)] + \
    [(R + f"cnv_summary_result_{i}.png", f"cnv_summary/cnv_summary_result_{i}.png") for i in range(1, 8)] + [
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/concept.png", "pipeline/concept.png"),
]
# Docs copied as they are: (source under docs/CNV, target under docs)
DOC_FILES = [
    ("CNV_Pipeline_Design.md", "CNV_Pipeline_Design.md"),
    ("modules/Portal_Content.md", "Portal_Content.md"),
    ("modules/Portal_Content.docx", "Portal_Content.docx"),
    ("modules/Registration.md", "Registration.md"),
    ("containers/Container_Manual.md", "Container_Manual.md"),
    ("pipeline/Portal_Content.md", "pipeline/Portal_Content.md"),
    ("pipeline/Portal_Content.docx", "pipeline/Portal_Content.docx"),
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/pipeline.svg", "pipeline/pipeline.svg"),
    ("pipeline/figures/concept.png", "pipeline/concept.png"),
    ("pipeline/figures/concept.svg", "pipeline/concept.svg"),
]


def release_text(work, release):
    """Work file text as released: version block (top '# Version' comment lines) removed, own name replaced."""
    lines = (WORK / work).read_text().split("\n")
    if len(lines) > 1 and lines[1].startswith("# Version "):
        end = 2
        while end < len(lines) and lines[end].startswith("#   "):
            end += 1
        lines = lines[:1] + lines[end:]
    return "\n".join(lines).replace(work, release)


def git_commit():
    return subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def copy(pairs, base):
    for src, dst in pairs:
        target = OUT / base / dst
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(DOCS / src, target)


def main():
    commit = git_commit()
    rows = []
    for module, work, release, image in MODULES:
        if work == release:
            shutil.copy2(WORK / work, OUT / release)
        else:
            (OUT / release).write_text(release_text(work, release))
        (OUT / release).chmod(0o644)
        rows.append((module, release, "(new in 3.0)", f"scripts/CNV/{work}", image))
    with open(OUT / "release.tsv", "w") as fh:
        fh.write("module\trelease_file\tclosha2_file\twork_file\timage\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    copy(IMAGES, "portal_images")
    copy(DOC_FILES, "docs")
    with zipfile.ZipFile(OUT / "portal_images.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted((OUT / "portal_images").rglob("*.png")):
            z.write(f, f.relative_to(OUT))
    print(f"built {len(rows)} release files from commit {commit}")


if __name__ == "__main__":
    main()
