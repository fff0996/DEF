#!/usr/bin/env python3
"""RTpred module 1: retention time prediction with the bundled default models.

Usage:
    python retip_predict.1.0.py input_file="..." output_dir="..." [model="RP"] [sheet="..."]

Example:
    apptainer exec bx_retip_predict.1.0.sif python retip_predict.1.0.py \
        input_file="/path/to/compounds.csv" \
        output_dir="/path/to/output" \
        model="RP"

Arguments:
    input_file (required) - Compound table (*.csv or *.xlsx) with a SMILES
                            column (smiles or structure); experimental_rt is
                            optional.
    output_dir (required) - Output directory. Results go to output_dir/result
                            and logs to output_dir/logs.
    model      (optional) - RP or HILIC. If omitted, the table must have a
                            model_type column (RP or HILIC per row).
    sheet      (optional) - XLSX sheet name; first (or empty) reads the first
                            sheet. Ignored for CSV. default: first

Outputs (output_dir/result):
    predictions.csv, prediction.png/.svg, report.html, manifest.json

Runs inside bx_retip_predict.1.0.sif, where mdcc and the default models are
installed. Nothing is deleted: output_dir/result must be new or empty.
"""
import datetime
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

MODULE = "predict"
IMAGE = "bx_retip_predict.1.0.sif"
REQUIRED = ["input_file", "output_dir"]
OPTIONAL = {"model": "", "sheet": "first"}
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


def main():
    params = parse_args(sys.argv[1:])
    input_file = Path(params["input_file"])
    output_dir = Path(params["output_dir"])
    model = params["model"]

    if model and model not in ("RP", "HILIC"):
        fail(f"model must be RP or HILIC: {model}")
    if not input_file.is_file():
        fail(f"input_file not found: {input_file}")
    if input_file.suffix.lower() not in TABLE_SUFFIXES:
        fail(f"input_file must be a *.csv or *.xlsx table: {input_file}")
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
    log(handle, f"  input_file = {input_file}")
    log(handle, f"  output_dir = {output_dir}")
    log(handle, f"  model      = {model or '<from input model_type>'}")
    log(handle, f"  sheet      = {params['sheet'] or 'first'}")
    log(handle)

    args = [MODULE, "--input", str(input_file), "--output", str(result_dir)]
    if model:
        args += ["--model", model]
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
