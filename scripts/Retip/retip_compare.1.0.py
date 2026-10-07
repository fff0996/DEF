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

Arguments (key=value, --key=value, or --key value):
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

Logs (output_dir/logs): <time>_<pid>.log copies stdout (progress) and
<time>_<pid>.err copies stderr (errors and warnings).

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
import threading

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


class Logs:
    """Run log files: <stamp>.log mirrors stdout, <stamp>.err mirrors stderr."""

    def __init__(self, output_dir):
        logs_dir = output_dir / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        stamp = f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{os.getpid()}"
        self.out = (logs_dir / f"{stamp}.log").open("a", encoding="utf-8")
        self.err = (logs_dir / f"{stamp}.err").open("a", encoding="utf-8")
        self.lock = threading.Lock()


def log(logs, message=""):
    """Progress message: stdout and the .log file."""
    with logs.lock:
        print(message, flush=True)
        logs.out.write(message + "\n")
        logs.out.flush()


def log_err(logs, message):
    """Error or warning: stderr and the .err file."""
    with logs.lock:
        print(message, file=sys.stderr, flush=True)
        logs.err.write(message + "\n")
        logs.err.flush()


def run_mdcc(logs, args):
    """Run python -m mdcc.cli, keeping its stdout and stderr apart."""
    command = [sys.executable, "-m", "mdcc.cli", *args]
    log(logs, "Command: " + " ".join(command))
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, bufsize=1) as process:
        def pump(stream, write):
            for line in stream:
                write(logs, line.rstrip("\n"))
        readers = [threading.Thread(target=pump, args=(process.stdout, log)),
                   threading.Thread(target=pump, args=(process.stderr, log_err))]
        for reader in readers:
            reader.start()
        for reader in readers:
            reader.join()
    if process.returncode != 0:
        log_err(logs, f"Error: mdcc {args[0]} exited with status {process.returncode}")
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

    logs = Logs(output_dir)
    log(logs, f"############################## RTpred {MODULE}")
    log(logs, f"Log files: {logs.out.name} (stdout), {logs.err.name} (stderr)")
    log(logs, f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    log(logs)
    log(logs, "parameters:")
    log(logs, f"  input_dir  = {input_dir}")
    log(logs, f"  user model = {model_dir}")
    log(logs, f"  eval table = {table}")
    log(logs, f"  output_dir = {output_dir}")
    for key in ["model", "sheet", "rt_unit", "scope", "title"]:
        log(logs, f"  {key:<10} = {params.get(key) or '<default>'}")
    log(logs)

    args = [MODULE, "--input", str(table), "--output", str(result_dir),
            "--model", model, "--user-model", str(model_dir),
            "--rt-unit", params["rt_unit"], "--scope", params["scope"], "--title", params["title"]]
    # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
    if params["sheet"] not in ("", "first"):
        args += ["--sheet", params["sheet"]]
    code = run_mdcc(logs, args)

    log(logs)
    log(logs, f"Results: {result_dir}")
    log(logs, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
