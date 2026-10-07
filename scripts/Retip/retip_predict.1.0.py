#!/usr/bin/env python3
"""RTpred module 1: retention time prediction with the bundled default models.

Usage:
    python retip_predict.1.0.py input_dir="..." output_dir="..." [model="RP"] [sheet="..."]

Example:
    apptainer exec bx_retip_predict.1.0.sif python retip_predict.1.0.py \
        input_dir="/path/to/compounds" \
        output_dir="/path/to/output" \
        model="RP"

Arguments:
    input_dir  (required) - Directory with one or more compound tables
                            (*.csv or *.xlsx). Each table needs a SMILES
                            column (smiles or structure); experimental_rt is
                            optional. Every table is predicted separately.
    output_dir (required) - Output directory. Results go to
                            output_dir/result/<table name>/ and logs to
                            output_dir/logs/.
    model      (optional) - RP or HILIC. If omitted, every table must have a
                            model_type column (RP or HILIC per row).
    sheet      (optional) - XLSX sheet name. default: first sheet

Outputs (output_dir/result/<table name>/):
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
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"model": "", "sheet": ""}
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


def find_tables(directory):
    """Return CSV/XLSX tables directly under directory, skipping hidden and lock files."""
    return sorted(p for p in directory.iterdir()
                  if p.is_file() and p.suffix.lower() in TABLE_SUFFIXES
                  and not p.name.startswith((".", "~$")))


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
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    model = params["model"]

    if model and model not in ("RP", "HILIC"):
        fail(f"model must be RP or HILIC: {model}")
    if not input_dir.is_dir():
        fail(f"input_dir not found: {input_dir}")
    tables = find_tables(input_dir)
    if not tables:
        fail(f"no *.csv or *.xlsx table in input_dir: {input_dir}")
    stems = [t.stem for t in tables]
    duplicates = sorted({s for s in stems if stems.count(s) > 1})
    if duplicates:
        fail(f"tables share a name with different extensions: {', '.join(duplicates)}")
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
    log(handle, f"  output_dir = {output_dir}")
    log(handle, f"  model      = {model or '<from input model_type>'}")
    log(handle, f"  sheet      = {params['sheet'] or '<first sheet>'}")
    log(handle, f"  tables     = {', '.join(t.name for t in tables)}")
    log(handle)

    failed = []
    for table in tables:
        log(handle, f"=== {table.name}")
        args = [MODULE, "--input", str(table), "--output", str(result_dir / table.stem)]
        if model:
            args += ["--model", model]
        if params["sheet"]:
            args += ["--sheet", params["sheet"]]
        if run_mdcc(handle, args) != 0:
            failed.append(table.name)
        log(handle)

    log(handle, f"Results: {result_dir}")
    log(handle, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    if failed:
        log(handle, f"Failed tables: {', '.join(failed)}")
        sys.exit(1)


if __name__ == "__main__":
    main()
