#!/usr/bin/env python3
"""RTpred module 2: train a user retention time model (pyRetip / AutoGluon).

Usage:
    python retip_train.1.0.py input_file="..." output_dir="..." model="RP" [options]

Example:
    apptainer exec bx_retip_train.1.0.sif python retip_train.1.0.py \
        input_file="/path/to/library.csv" \
        output_dir="/path/to/output" \
        model="RP" \
        time_limit="1200" \
        cpus="4"

Arguments (key=value, --key=value, or --key value):
    input_file            (required) - Training table (*.csv or *.xlsx) with
                                       SMILES and measured RT
                                       (experimental_rt / rt / retention_time)
    output_dir            (required) - Output directory. Results go to
                                       output_dir/result, logs to output_dir/logs.
    model                 (required) - RP or HILIC
    sheet                 (optional) - XLSX sheet name; first (or empty) reads
                                       the first sheet. Ignored for CSV.
                                       default: first
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
REQUIRED = ["input_file", "output_dir", "model"]
OPTIONAL = {"sheet": "first", "rt_unit": "model unit", "time_limit": "1200",
            "cpus": "2", "algorithms": "GBM,CAT,RF,XT,KNN", "test_size": "0.2",
            "validation_size": "0.2", "seed": "42", "max_missing_fraction": "0.2",
            "correlation_threshold": "0.995", "method_label": "user method"}
TABLE_SUFFIXES = {".csv", ".xlsx"}
ALGORITHMS = {"GBM", "CAT", "RF", "XT", "KNN"}


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    """Parse key=value, --key=value, or --key value arguments.

    A --key followed directly by another --option (or nothing) gets an empty
    value, which keeps that option's default behavior.
    """
    params = dict(OPTIONAL)
    i = 0
    while i < len(argv):
        arg = argv[i]
        i += 1
        if arg.startswith("--"):
            arg = arg[2:]
            if "=" in arg:
                key, value = arg.split("=", 1)
            else:
                key, value = arg, ""
                if i < len(argv) and not argv[i].startswith("--"):
                    value = argv[i]
                    i += 1
        elif "=" in arg:
            key, value = arg.split("=", 1)
        else:
            fail(f"Invalid argument format: {arg} (use key=value or --key value)")
        key = key.replace("-", "_")
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}")
        value = value.strip().strip("'\"")
        # An empty optional value keeps its default.
        params[key] = value if value or key in REQUIRED else OPTIONAL[key]
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

    if model not in ("RP", "HILIC"):
        fail(f"model must be RP or HILIC: {model}")
    algorithms = [a.strip() for a in params["algorithms"].split(",") if a.strip()]
    unknown = [a for a in algorithms if a not in ALGORITHMS]
    if not algorithms or unknown:
        fail(f"algorithms must be a comma-separated subset of GBM,CAT,RF,XT,KNN: {params['algorithms']}")
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
    for key in ["model", "sheet", "rt_unit", "time_limit", "cpus", "algorithms", "test_size",
                "validation_size", "seed", "max_missing_fraction", "correlation_threshold",
                "method_label"]:
        log(handle, f"  {key:<21} = {params.get(key) or '<default>'}")
    log(handle)

    args = [MODULE, "--input", str(input_file), "--output", str(result_dir),
            "--model", model, "--rt-unit", params["rt_unit"],
            "--time-limit", params["time_limit"], "--cpus", params["cpus"],
            "--algorithms", *algorithms,
            "--test-size", params["test_size"], "--validation-size", params["validation_size"],
            "--seed", params["seed"], "--max-missing-fraction", params["max_missing_fraction"],
            "--correlation-threshold", params["correlation_threshold"],
            "--method-label", params["method_label"]]
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
