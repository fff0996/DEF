#!/usr/bin/env python3
"""RTpred module 3: compare the bundled default model with a user-trained model
on the same measured compounds.

Usage:
    python retip_compare.1.0.py input_dir="..." output_dir="..." model="RP" [eval_file="..."] [options]

Examples:
    After retip_train (its reserved_test.csv is the evaluation set):
        apptainer exec bx_retip_compare.1.0.sif python retip_compare.1.0.py \
            input_dir="/path/to/train_output" \
            output_dir="/path/to/output" \
            model="RP"

    With a separate evaluation table:
        apptainer exec bx_retip_compare.1.0.sif python retip_compare.1.0.py \
            input_dir="/path/to/train_output" \
            eval_file="/path/to/evaluation.csv" \
            output_dir="/path/to/output" \
            model="RP"

Arguments:
    input_dir  (required) - retip_train output directory (its output_dir;
                            output_dir/result or result/model also work)
    output_dir (required) - Output directory. Results go to output_dir/result
                            and logs to output_dir/logs.
    model      (required) - RP or HILIC (must match the user model)
    eval_file  (optional) - Evaluation table (*.csv or *.xlsx with SMILES and
                            measured RT), or reserved_test (or empty) for the
                            reserved_test.csv written by retip_train.
                            default: reserved_test
    sheet      (optional) - XLSX sheet name; first (or empty) reads the first
                            sheet. Ignored for CSV. default: first
    rt_unit    (optional) - RT unit label for plots. default: model unit
    scope      (optional) - all (every user-model candidate) or best. default: all
    title      (optional) - Report title. default: Default and user model comparison

Outputs (output_dir/result):
    comparison.csv, predictions_long.csv, comparison.png/.svg, report.html,
    manifest.json

Runs inside bx_retip_compare.1.0.sif. Nothing is deleted: output_dir/result
must be new or empty.
"""
import datetime
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

MODULE = "compare"
IMAGE = "bx_retip_compare.1.0.sif"
REQUIRED = ["input_dir", "output_dir", "model"]
OPTIONAL = {"eval_file": "reserved_test", "sheet": "first", "rt_unit": "model unit",
            "scope": "all", "title": "Default and user model comparison"}
TABLE_SUFFIXES = {".csv", ".xlsx"}


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    """Parse key=value arguments, as in the other CLOSHA scripts."""
    params = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}")
        params[key] = value.strip().strip("'\"")
    for key in REQUIRED:
        if not params.get(key):
            fail(f"Required parameter '{key}' is missing")
    return params


def open_log(output_dir):
    logs_dir = output_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    return (logs_dir / f"{stamp}_{os.getpid()}.log").open("a", encoding="utf-8")


def log(handle, message=""):
    print(message, flush=True)
    handle.write(message + "\n")
    handle.flush()


def run_mdcc(handle, args):
    """Run python -m mdcc.cli and copy its combined output to the console and log."""
    command = [sys.executable, "-m", "mdcc.cli", *args]
    log(handle, "Command: " + " ".join(command))
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          text=True, bufsize=1) as process:
        for line in process.stdout:
            log(handle, line.rstrip("\n"))
    return process.returncode


def locate_train_output(path):
    """Accept a retip_train output_dir, its result/ directory, or result/model.

    Returns (model directory, directory holding reserved_test.csv).
    """
    for model_dir in (path / "result" / "model", path / "model", path):
        if (model_dir / "model_manifest.json").is_file():
            return model_dir, model_dir.parent
    fail(f"no retip_train model found in input_dir: {path}")


def select_eval_table(eval_file, train_result):
    if eval_file in ("", "reserved_test"):
        table = train_result / "reserved_test.csv"
        if not table.is_file():
            fail(f"reserved_test.csv not found in {train_result}; set eval_file")
        return table
    table = Path(eval_file)
    if not table.is_file():
        fail(f"eval_file not found: {table}")
    if table.suffix.lower() not in TABLE_SUFFIXES:
        fail(f"eval_file must be a *.csv or *.xlsx table: {table}")
    return table


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    model = params["model"]

    if model not in ("RP", "HILIC"):
        fail(f"model must be RP or HILIC: {model}")
    if params["scope"] not in ("all", "best"):
        fail(f"scope must be all or best: {params['scope']}")
    if not input_dir.is_dir():
        fail(f"input_dir not found: {input_dir}")
    model_dir, train_result = locate_train_output(input_dir)
    table = select_eval_table(params["eval_file"], train_result)
    result_dir = output_dir / "result"
    if result_dir.exists() and any(result_dir.iterdir()):
        fail(f"{result_dir} is not empty; use a new output_dir")
    if importlib.util.find_spec("mdcc") is None:
        fail(f"mdcc is not importable; run inside {IMAGE}")

    handle = open_log(output_dir)
    log(handle, f"############################## RTpred {MODULE}")
    log(handle, f"Log file: {handle.name}")
    log(handle, f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    log(handle)
    log(handle, "parameters:")
    log(handle, f"  input_dir  = {input_dir}")
    log(handle, f"  user model = {model_dir}")
    log(handle, f"  eval table = {table}")
    log(handle, f"  output_dir = {output_dir}")
    for key in ["model", "sheet", "rt_unit", "scope", "title"]:
        log(handle, f"  {key:<10} = {params.get(key) or '<default>'}")
    log(handle)

    args = [MODULE, "--input", str(table), "--output", str(result_dir),
            "--model", model, "--user-model", str(model_dir),
            "--rt-unit", params["rt_unit"], "--scope", params["scope"], "--title", params["title"]]
    # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
    if params["sheet"] not in ("", "first"):
        args += ["--sheet", params["sheet"]]
    code = run_mdcc(handle, args)

    log(handle)
    log(handle, f"Results: {result_dir}")
    log(handle, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
