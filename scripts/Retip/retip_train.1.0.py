#!/usr/bin/env python3
"""RTpred module 2: train a user retention time model (pyRetip / AutoGluon).

Usage:
    python retip_train.1.0.py input_dir="..." output_dir="..." model="RP" [options]

Example:
    apptainer exec bx_retip_train.1.0.sif python retip_train.1.0.py \
        input_dir="/path/to/library" \
        output_dir="/path/to/output" \
        model="RP" \
        time_limit="1200" \
        cpus="4"

Arguments:
    input_dir             (required) - Directory with the training table
                                       (*.csv or *.xlsx): SMILES and measured
                                       RT (experimental_rt / rt / retention_time)
    output_dir            (required) - Output directory. Results go to
                                       output_dir/result, logs to output_dir/logs.
    model                 (required) - RP or HILIC
    input_name            (optional) - Table file name inside input_dir; required
                                       when input_dir holds more than one table
    sheet                 (optional) - XLSX sheet name. default: first sheet
    rt_unit               (optional) - RT unit label (values are not converted).
                                       default: model unit
    time_limit            (optional) - AutoGluon fit budget in seconds. default: 1200
    cpus                  (optional) - CPU cores for training. default: 2
    algorithms            (optional) - Comma-separated subset of GBM,CAT,RF,XT,KNN.
                                       default: GBM,CAT,RF,XT,KNN
    test_size             (optional) - Reserved test fraction. default: 0.2
    validation_size       (optional) - Validation fraction. default: 0.2
    seed                  (optional) - Random seed. default: 42
    max_missing_fraction  (optional) - Max missing descriptor fraction. default: 0.2
    correlation_threshold (optional) - Descriptor correlation cutoff. default: 0.995
    method_label          (optional) - User LC method identifier. default: user method

Outputs (output_dir/result):
    model/ (trained models and manifest), reserved_test.csv (held-out
    compounds), validation_leaderboard.csv, split_assignments.csv,
    rejected_rows.csv, training.png/.svg, report.html, manifest.json
    The whole output_dir is the input_dir of retip_compare.

Runs inside bx_retip_train.1.0.sif. Nothing is deleted: output_dir/result
must be new or empty.
"""
import datetime
import importlib.util
import os
from pathlib import Path
import re
import subprocess
import sys

MODULE = "train"
IMAGE = "bx_retip_train.1.0.sif"
REQUIRED = ["input_dir", "output_dir", "model"]
OPTIONAL = {"input_name": "", "sheet": "", "rt_unit": "model unit", "time_limit": "1200",
            "cpus": "2", "algorithms": "GBM,CAT,RF,XT,KNN", "test_size": "0.2",
            "validation_size": "0.2", "seed": "42", "max_missing_fraction": "0.2",
            "correlation_threshold": "0.995", "method_label": "user method"}
TABLE_SUFFIXES = {".csv", ".xlsx"}
ALGORITHMS = {"GBM", "CAT", "RF", "XT", "KNN"}


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


def select_table(input_dir, input_name):
    tables = find_tables(input_dir)
    if input_name:
        chosen = input_dir / input_name
        if chosen not in tables:
            fail(f"input_name is not a *.csv or *.xlsx table in input_dir: {input_name}")
        return chosen
    if not tables:
        fail(f"no *.csv or *.xlsx table in input_dir: {input_dir}")
    if len(tables) > 1:
        fail("input_dir holds more than one table; set input_name to one of: "
             + ", ".join(t.name for t in tables))
    return tables[0]


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    model = params["model"]

    if model not in ("RP", "HILIC"):
        fail(f"model must be RP or HILIC: {model}")
    algorithms = [a.strip() for a in params["algorithms"].split(",") if a.strip()]
    unknown = [a for a in algorithms if a not in ALGORITHMS]
    if not algorithms or unknown:
        fail(f"algorithms must be a comma-separated subset of GBM,CAT,RF,XT,KNN: {params['algorithms']}")
    if not input_dir.is_dir():
        fail(f"input_dir not found: {input_dir}")
    table = select_table(input_dir, params["input_name"])
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
    log(handle, f"  table      = {table.name}")
    log(handle, f"  output_dir = {output_dir}")
    for key in ["model", "sheet", "rt_unit", "time_limit", "cpus", "algorithms", "test_size",
                "validation_size", "seed", "max_missing_fraction", "correlation_threshold",
                "method_label"]:
        log(handle, f"  {key:<21} = {params.get(key) or '<default>'}")
    log(handle)

    args = [MODULE, "--input", str(table), "--output", str(result_dir),
            "--model", model, "--rt-unit", params["rt_unit"],
            "--time-limit", params["time_limit"], "--cpus", params["cpus"],
            "--algorithms", *algorithms,
            "--test-size", params["test_size"], "--validation-size", params["validation_size"],
            "--seed", params["seed"], "--max-missing-fraction", params["max_missing_fraction"],
            "--correlation-threshold", params["correlation_threshold"],
            "--method-label", params["method_label"]]
    if params["sheet"]:
        args += ["--sheet", params["sheet"]]
    code = run_mdcc(handle, args)

    log(handle)
    log(handle, f"Results: {result_dir}")
    log(handle, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
