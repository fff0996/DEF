#!/usr/bin/env python3
"""RTpred module 2: train a user retention time model (pyRetip / AutoGluon).

Usage:
    python retip_train.1.0.py input_file="..." output_dir="..." [model="auto"] [options]

Example:
    apptainer exec bx_retip_train.1.0.sif python retip_train.1.0.py \
        input_file="/path/to/library.csv" \
        output_dir="/path/to/output" \
        model="RP" \
        time_limit="1200" \
        cpus="auto"

Arguments (key=value, --key=value, or --key value):
    input_file            (required) - Training table (*.csv or *.xlsx) with
                                       SMILES and measured RT
                                       (experimental_rt / rt / retention_time)
    output_dir            (required) - Output directory. Results go to
                                       output_dir/result, logs to output_dir/logs.
    model                 (optional) - RP, HILIC, or auto. auto (or empty) takes
                                       the single mode in the table's model_type
                                       column; it stops if the column is missing
                                       or mixes modes. default: auto
    sheet                 (optional) - XLSX sheet name; first (or empty) reads
                                       the first sheet. Ignored for CSV.
                                       default: first
    rt_unit               (optional) - RT unit label (values are not converted);
                                       auto (or empty) means "model unit".
                                       default: auto
    time_limit            (optional) - AutoGluon fit budget in seconds. default: 1200
    cpus                  (optional) - CPU cores for training and numeric
                                       libraries: auto uses the cores allocated
                                       to the job (Slurm/cgroup); a number is
                                       capped by them. default: auto
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

Logs (output_dir/logs): <time>_<pid>.log copies stdout (progress) and
<time>_<pid>.err copies stderr (errors and warnings).

Runs inside bx_retip_train.1.0.sif. Rerunning replaces output_dir/result
(only that folder is removed; logs are kept).
"""
import csv
import datetime
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading

MODULE = "train"
IMAGE = "bx_retip_train.1.0.sif"
REQUIRED = ["input_file", "output_dir"]
OPTIONAL = {"model": "auto", "sheet": "first", "rt_unit": "auto", "time_limit": "1200",
            "cpus": "auto", "algorithms": "GBM,CAT,RF,XT,KNN", "test_size": "0.2",
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


# Column names mdcc reads as the chromatography mode (mdcc.core.load_table).
MODE_COLUMNS = {"model_type", "column", "chrom_system", "mode"}


def table_modes(path, sheet):
    """Return the set of modes in the table's mode column, or None if it has none."""
    if path.suffix.lower() == ".csv":
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.reader(handle))
    else:
        import pandas
        frame = pandas.read_excel(path, sheet_name=0 if sheet in ("", "first") else sheet,
                                  header=None, dtype=str, keep_default_na=False)
        rows = frame.values.tolist()
    if not rows:
        fail(f"input_file is empty: {path}")
    columns = [i for i, name in enumerate(rows[0]) if str(name).strip().lower() in MODE_COLUMNS]
    if not columns:
        return None
    if len(columns) > 1:
        fail("input_file has more than one mode column (model_type/column/chrom_system/mode)")
    return {str(row[columns[0]]).strip().upper() for row in rows[1:] if len(row) > columns[0]}


def resolve_model(value, path, sheet):
    """auto picks the single RP/HILIC mode written in the table."""
    if value not in ("", "auto"):
        if value not in ("RP", "HILIC"):
            fail(f"model must be RP, HILIC, or auto: {value}")
        return value
    modes = table_modes(path, sheet)
    if modes is None:
        fail("model=auto needs a model_type column in input_file; otherwise choose RP or HILIC")
    if modes - {"RP", "HILIC"}:
        fail(f"model_type values must be RP or HILIC (found {sorted(modes)}); train one mode per run")
    if len(modes) != 1:
        fail(f"input_file mixes chromatography modes {sorted(modes)}; train one mode per run")
    return modes.pop()


def allocated_cpus():
    """CPU cores this job may use: the affinity mask (which reflects Slurm and
    cgroup limits), capped by SLURM_CPUS_PER_TASK when Slurm sets it."""
    try:
        count = len(os.sched_getaffinity(0))
    except AttributeError:
        count = os.cpu_count() or 1
    slurm = os.environ.get("SLURM_CPUS_PER_TASK", "")
    if slurm.isdigit() and int(slurm) > 0:
        count = min(count, int(slurm))
    return max(1, count)


def resolve_cpus(value):
    """auto (or empty) uses the allocated cores; a number is capped by them."""
    allocated = allocated_cpus()
    if value in ("", "auto"):
        return allocated
    if not value.isdigit() or int(value) < 1:
        fail(f"cpus must be auto or a positive integer: {value}")
    return min(int(value), allocated)


def check_inputs_outside(result_dir, *inputs):
    """The previous result is removed before each run, so no input may be
    inside output_dir/result."""
    target = result_dir.resolve()
    for path in inputs:
        resolved = Path(path).resolve()
        if resolved == target or target in resolved.parents:
            fail(f"input {path} is inside {result_dir}, which is replaced on each run")


def clear_previous_result(logs, output_dir, result_dir):
    """Remove only output_dir/result from an earlier run, after checking that
    it is a real directory directly under output_dir (not a symlink)."""
    if not result_dir.exists() and not result_dir.is_symlink():
        return
    if result_dir.is_symlink() or not result_dir.is_dir():
        fail(f"{result_dir} is not a plain directory; not removing it")
    if result_dir.resolve().parent != output_dir.resolve():
        fail(f"{result_dir} does not resolve directly under {output_dir}; not removing it")
    log(logs, f"Removing previous result: {result_dir}")
    shutil.rmtree(result_dir)


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


def run_mdcc(logs, args, cpus):
    """Run python -m mdcc.cli with numeric-library threads set to cpus,
    keeping its stdout and stderr apart."""
    command = [sys.executable, "-m", "mdcc.cli", *args]
    env = dict(os.environ, **{name: str(cpus) for name in
               ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")})
    log(logs, "Command: " + " ".join(command))
    with subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          text=True, bufsize=1, env=env) as process:
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


def main():
    params = parse_args(sys.argv[1:])
    input_file = Path(params["input_file"])
    output_dir = Path(params["output_dir"])
    cpus = resolve_cpus(params["cpus"])

    algorithms = [a.strip() for a in params["algorithms"].split(",") if a.strip()]
    unknown = [a for a in algorithms if a not in ALGORITHMS]
    if not algorithms or unknown:
        fail(f"algorithms must be a comma-separated subset of GBM,CAT,RF,XT,KNN: {params['algorithms']}")
    if not input_file.is_file():
        fail(f"input_file not found: {input_file}")
    if input_file.suffix.lower() not in TABLE_SUFFIXES:
        fail(f"input_file must be a *.csv or *.xlsx table: {input_file}")
    model = resolve_model(params["model"], input_file, params["sheet"])
    rt_unit = "model unit" if params["rt_unit"] in ("", "auto") else params["rt_unit"]
    result_dir = output_dir / "result"
    check_inputs_outside(result_dir, input_file)
    if importlib.util.find_spec("mdcc") is None:
        fail(f"mdcc is not importable; run inside {IMAGE}")

    logs = Logs(output_dir)
    log(logs, f"############################## RTpred {MODULE}")
    log(logs, f"Log files: {logs.out.name} (stdout), {logs.err.name} (stderr)")
    log(logs, f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    log(logs)
    log(logs, "parameters:")
    log(logs, f"  input_file = {input_file}")
    log(logs, f"  output_dir = {output_dir}")
    log(logs, f"  {'cpus':<21} = {cpus} (requested {params['cpus']}, allocated {allocated_cpus()})")
    log(logs, f"  {'model':<21} = {model} (requested {params['model']})")
    log(logs, f"  {'rt_unit':<21} = {rt_unit}")
    for key in ["sheet", "time_limit", "algorithms", "test_size",
                "validation_size", "seed", "max_missing_fraction", "correlation_threshold",
                "method_label"]:
        log(logs, f"  {key:<21} = {params.get(key) or '<default>'}")
    log(logs)

    args = [MODULE, "--input", str(input_file), "--output", str(result_dir),
            "--model", model, "--rt-unit", rt_unit,
            "--time-limit", params["time_limit"], "--cpus", str(cpus),
            "--algorithms", *algorithms,
            "--test-size", params["test_size"], "--validation-size", params["validation_size"],
            "--seed", params["seed"], "--max-missing-fraction", params["max_missing_fraction"],
            "--correlation-threshold", params["correlation_threshold"],
            "--method-label", params["method_label"]]
    # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
    if params["sheet"] not in ("", "first"):
        args += ["--sheet", params["sheet"]]
    clear_previous_result(logs, output_dir, result_dir)
    code = run_mdcc(logs, args, cpus)

    log(logs)
    log(logs, f"Results: {result_dir}")
    log(logs, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
