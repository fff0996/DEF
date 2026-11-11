#!/usr/bin/env python3
"""Build the CLOSHA 3.0 scGPT release of 2026-11-11 from the work files.

scGPT is new in CLOSHA 3.0 and its work files were fixed in place at 1.0, so
each release file is a byte copy of scripts/scGPT/<module>.1.0.py (no version
history block to replace); tools/check_release.py verifies that. The docs,
portal images and pipeline figures are copied as they are.

Run from the repository root:
  python3 release/CLOSHA3/scGPT/2026-11-11/build_release.py
"""
import shutil
import subprocess
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "scripts" / "scGPT"
DOCS = ROOT / "docs" / "scGPT"
OUT = Path(__file__).resolve().parent

# module, work file, release file, image
MODULES = [
    ("scgpt_prep", "scgpt_prep.1.0.py", "scgpt_prep.1.0.py", "bx_scgpt 1.0"),
    ("scgpt_embed", "scgpt_embed.1.0.py", "scgpt_embed.1.0.py", "bx_scgpt_gpu 1.0"),
    ("scgpt_train", "scgpt_train.1.0.py", "scgpt_train.1.0.py", "bx_scgpt 1.0"),
    ("scgpt_predict", "scgpt_predict.1.0.py", "scgpt_predict.1.0.py", "bx_scgpt 1.0"),
    ("scgpt_compare", "scgpt_compare.1.0.py", "scgpt_compare.1.0.py", "bx_scgpt 1.0"),
]

# Portal images: (source under docs/scGPT, target under portal_images)
IMAGES = [
    ("modules/figures/results_kap241712/scgpt_embed_result_1.png", "scgpt_embed/scgpt_embed_result_1.png"),
    ("modules/figures/results_kap241712/scgpt_compare_result_1.png", "scgpt_compare/scgpt_compare_result_1.png"),
    ("modules/figures/results_kap241712/scgpt_compare_result_2.png", "scgpt_compare/scgpt_compare_result_2.png"),
    ("pipeline/figures/concept.png", "scgpt_embed/scgpt_embed_concept.png"),
    ("pipeline/figures/concept.png", "scgpt_train/scgpt_train_concept.png"),
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/concept.png", "pipeline/concept.png"),
    ("pipeline/figures/thumbnail.png", "pipeline/thumbnail.png"),
]
# Docs copied as they are: (source under docs/scGPT, target under docs)
DOC_FILES = [
    ("modules/Portal_Content.md", "Portal_Content.md"),
    ("modules/Portal_Content.docx", "Portal_Content.docx"),
    ("modules/Registration.md", "Registration.md"),
    ("containers/Container_Manual.md", "Container_Manual.md"),
    ("Data_Sources.md", "Data_Sources.md"),
    ("pipeline/Portal_Content.md", "pipeline/Portal_Content.md"),
    ("pipeline/Portal_Content.docx", "pipeline/Portal_Content.docx"),
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/pipeline.svg", "pipeline/pipeline.svg"),
    ("pipeline/figures/concept.png", "pipeline/concept.png"),
    ("pipeline/figures/concept.svg", "pipeline/concept.svg"),
    ("pipeline/figures/thumbnail.png", "pipeline/thumbnail.png"),
]


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
        shutil.copy2(WORK / work, OUT / release)
        (OUT / release).chmod(0o644)
        rows.append((module, release, "(new in 3.0)", f"scripts/scGPT/{work}", image))
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
