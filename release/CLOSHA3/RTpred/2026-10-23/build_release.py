#!/usr/bin/env python3
"""Build the CLOSHA 3.0 RTpred release of 2026-10-23 from the work files.

RTpred is new in CLOSHA 3.0, so every module is released as 1.0. Each
release file is the work file in scripts/RTpred/ with
  - the work-version change history at the top replaced by one block that
    describes what the module does, and
  - its own work file name replaced by the release file name.
Nothing else is changed; tools/check_release.py verifies that. The docs,
portal images and pipeline figures are copied as they are.

Run from the repository root:
  python3 release/CLOSHA3/RTpred/2026-10-23/build_release.py
"""
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "scripts" / "RTpred"
DOCS = ROOT / "docs" / "RTpred"
OUT = Path(__file__).resolve().parent

# module, work file, release file, image
MODULES = [
    ("rtpred_predict", "rtpred_predict.1.2.py", "rtpred_predict.1.0.py", "bx_rtpred_predict 1.0"),
    ("rtpred_train", "rtpred_train.1.1.py", "rtpred_train.1.0.py", "bx_rtpred_train 1.0"),
    ("rtpred_compare", "rtpred_compare.1.1.py", "rtpred_compare.1.0.py", "bx_rtpred_compare 1.0"),
]

LOGS = ("Logs: progress goes to stdout and logs/<stamp>.log; errors and warnings go\n"
        "  to stderr and logs/<stamp>.err. Rerunning replaces output_dir/result only.")
MODE = ("Mode: the model_type column of the input table (RP or HILIC on every row;\n"
        "  modes may be mixed) is required and is the only source of the mode.")

HEADERS = {
    "rtpred_predict": f"""Retention time (RT) prediction from compound structures (SMILES) with
  the RTpred code (mdcc) of the SNU food metabolomics lab. model_dir empty or
  default uses the bundled default RP and HILIC models (RT in minutes);
  a rtpred_train output folder uses its trained model for each row's mode.
  Rows of a mode that was not trained are kept in predictions.csv with an
  empty predicted_rt and parse_status=no_trained_model, with a warning.
{MODE}
{LOGS}""",
    "rtpred_train": f"""Trains user RT models (pyRetip-style AutoGluon training in mdcc) from
  measured RTs: one model per mode in the table (result/RP/, result/HILIC/),
  with a structure-group split and the best model chosen by validation RMSE.
  A mode that fails (for example too few rows) is reported; the run fails
  only when no mode was trained. rt_unit defaults to min.
{MODE}
{LOGS}""",
    "rtpred_compare": f"""Compares the default model and the user model of each trained mode on the
  same evaluation compounds (the reserved_test.csv of each mode by default):
  RMSE, MAE and R2 per candidate in result/<MODE>/, joined in
  result/comparison.csv with a Mode column. Evaluation structures used in
  training stop the run (leakage).
{MODE}
{LOGS}""",
}

# Portal images: (source under docs/RTpred, target under portal_images)
IMAGES = [
    ("modules/figures/module_concepts/rtpred_predict_concept.png", "rtpred_predict/rtpred_predict_concept.png"),
    ("images/module1_result.png", "rtpred_predict/rtpred_predict_result_1.png"),
    ("modules/figures/module_concepts/rtpred_train_concept.png", "rtpred_train/rtpred_train_concept.png"),
    ("modules/figures/module_concepts/rtpred_train_conditions_concept.png", "rtpred_train/rtpred_train_concept_2.png"),
    ("images/module2_result.png", "rtpred_train/rtpred_train_result_1.png"),
    ("modules/figures/module_concepts/rtpred_compare_concept.png", "rtpred_compare/rtpred_compare_concept.png"),
    ("images/module3_result.png", "rtpred_compare/rtpred_compare_result_1.png"),
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/concept_xie2025_fig1.png", "pipeline/concept.png"),
]
# Docs copied as they are: (source under docs/RTpred, target under docs)
DOC_FILES = [
    ("modules/Portal_Content.md", "Portal_Content.md"),
    ("modules/Portal_Content.docx", "Portal_Content.docx"),
    ("modules/Registration.md", "Registration.md"),
    ("containers/Container_Manual.md", "Container_Manual.md"),
    ("pipeline/Portal_Content.md", "pipeline/Portal_Content.md"),
    ("pipeline/Portal_Content.docx", "pipeline/Portal_Content.docx"),
    ("pipeline/figures/pipeline.png", "pipeline/pipeline.png"),
    ("pipeline/figures/pipeline.svg", "pipeline/pipeline.svg"),
    ("pipeline/figures/concept_xie2025_fig1.png", "pipeline/concept_xie2025_fig1.png"),
]


def git_commit():
    return subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def strip_history(lines):
    """Return (start, end) of the work-version history block at the top."""
    idx = [i for i, ln in enumerate(lines[:80]) if ln.startswith("# Version ")]
    if not idx:
        raise SystemExit("no version history found")
    end = idx[-1] + 1
    while end < len(lines) and lines[end].strip() not in ("#", ""):
        end += 1
    return idx[0], end + 1  # drop the separator line too


def header_block(module):
    body = ["#   " + ln if ln.strip() else "#" for ln in HEADERS[module].split("\n")]
    return ["# Version 1.0 (first release in CLOSHA 3.0):"] + body + ["#"]


def copy(pairs, base):
    for src, dst in pairs:
        target = OUT / base / dst
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(DOCS / src, target)


def main():
    commit = git_commit()
    rows = []
    for module, work, release, image in MODULES:
        lines = (WORK / work).read_text().split("\n")
        start, end = strip_history(lines)
        new = lines[:start] + header_block(module) + lines[end:]
        text = "\n".join(new).replace(work, release)
        (OUT / release).write_text(text)
        (OUT / release).chmod(0o644)
        rows.append((module, release, "(new in 3.0)", f"scripts/RTpred/{work}", image))
    with open(OUT / "release.tsv", "w") as fh:
        fh.write("module\trelease_file\tclosha2_file\twork_file\timage\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    copy(IMAGES, "portal_images")
    copy(DOC_FILES, "docs")
    print(f"built {len(rows)} release files from commit {commit}")


if __name__ == "__main__":
    main()
