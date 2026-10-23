#!/usr/bin/env python3
# Version 1.0 (first release in CLOSHA 3.0):
#   Compares the default model and the user model of each trained mode on the
#     same evaluation compounds (the reserved_test.csv of each mode by default):
#     RMSE, MAE and R2 per candidate in result/<MODE>/, joined in
#     result/comparison.csv with a Mode column. Evaluation structures used in
#     training stop the run (leakage).
#   Mode: the model_type column of the input table (RP or HILIC on every row;
#     modes may be mixed) is required and is the only source of the mode.
#   Logs: progress goes to stdout and logs/<stamp>.log; errors and warnings go
#     to stderr and logs/<stamp>.err. Rerunning replaces output_dir/result only.
#
"""RTpred module 3: compare the bundled default model with a user-trained model
on the same measured compounds.

Usage:
    python rtpred_compare.1.0.py input_dir="..." output_dir="..." [eval_file="..."] [options]

Examples:
    After rtpred_train (its reserved_test.csv is the evaluation set):
        apptainer exec bx_rtpred_compare.1.0.sif python rtpred_compare.1.0.py \
            input_dir="/path/to/train_output" \
            output_dir="/path/to/output"

    With a separate evaluation table:
        apptainer exec bx_rtpred_compare.1.0.sif python rtpred_compare.1.0.py \
            input_dir="/path/to/train_output" \
            eval_file="/path/to/evaluation.csv" \
            output_dir="/path/to/output"

Arguments (key=value, --key=value, or --key value):
    input_dir  (required) - rtpred_train output directory (its output_dir;
                            output_dir/result or result/model also work)
    output_dir (required) - Output directory. Results go to output_dir/result
                            and logs to output_dir/logs.
    eval_file  (optional) - Evaluation table (*.csv or *.xlsx with SMILES and
                            measured RT and a model_type column, RP or HILIC
                            per row), or reserved_test (or empty)
                            for the reserved_test.csv of each trained mode
                            written by rtpred_train. default: reserved_test
    cpus       (optional) - Threads for numeric libraries: auto uses the cores
                            allocated to the job (Slurm/cgroup); a number is
                            capped by them. default: auto
    sheet      (optional) - XLSX sheet name; first (or empty) reads the first
                            sheet. Ignored for CSV. default: first
    rt_unit    (optional) - RT unit label. mdcc requires it to equal the label
                            used in rtpred_train; auto (or empty) reads it from
                            each user model. default: auto
    scope      (optional) - all (every user-model candidate) or best. default: all
    title      (optional) - Report title. default: Default and user model comparison

Outputs (output_dir/result):
    <MODE>/ for each compared mode: comparison.csv, predictions_long.csv,
    comparison.png/.svg, report.html, manifest.json
    comparison.csv: the per-mode comparison tables with a Mode column
    compare_summary.tsv: Mode, Eval_rows, Status, Best_candidate, Output
    inputs/eval_<MODE>.csv: the evaluation rows of each mode (eval_file only)

Logs (output_dir/logs): <time>_<pid>.log copies stdout (progress) and
<time>_<pid>.err copies stderr (errors and warnings).

Runs inside bx_rtpred_compare.1.0.sif. Rerunning replaces output_dir/result
(only that folder is removed; logs are kept).
"""
import csv
import datetime
import json
import importlib.util
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading

MODULE = "compare"
IMAGE = "bx_rtpred_compare.1.0.sif"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"eval_file": "reserved_test", "sheet": "first", "cpus": "auto", "rt_unit": "auto",
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


# Column names mdcc reads as the chromatography mode (mdcc.core.load_table).
MODE_COLUMNS = {"model_type", "column", "chrom_system", "mode"}


def read_rows(path, sheet):
    """Read the table as rows of strings (header first), as mdcc reads it."""
    if path.suffix.lower() == ".csv":
        with path.open(encoding="utf-8-sig", newline="") as handle:
            rows = list(csv.reader(handle))
    else:
        import pandas
        frame = pandas.read_excel(path, sheet_name=0 if sheet in ("", "first") else sheet,
                                  header=None, dtype=str, keep_default_na=False)
        rows = frame.values.tolist()
    rows = [row for row in rows if any(str(cell).strip() for cell in row)]
    if len(rows) < 2:
        fail(f"eval_file has no data rows: {path}")
    return rows


def split_by_mode(rows):
    """Return {mode: data rows} from the table's model_type column."""
    header = [str(name).strip().lower() for name in rows[0]]
    columns = [i for i, name in enumerate(header) if name in MODE_COLUMNS]
    if len(columns) > 1:
        fail("eval_file has more than one mode column (model_type/column/chrom_system/mode)")
    if not columns:
        fail("eval_file has no model_type column; add one with RP or HILIC on every row")
    col = columns[0]
    groups = {}
    for row in rows[1:]:
        mode = str(row[col]).strip().upper() if len(row) > col else ""
        groups.setdefault(mode, []).append(row)
    bad = sorted(set(groups) - {"RP", "HILIC"})
    if bad:
        fail(f"model_type must be RP or HILIC on every row; found {bad}")
    return groups


def write_rows(path, header, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        writer.writerows(rows)


def locate_train_outputs(path):
    """Trained models by mode, with the folder holding each mode's
    reserved_test.csv: one folder per mode (result/RP, result/HILIC) or the
    single-model layout of an earlier rtpred_train (result/model)."""
    found = {}
    candidates = [(b / m / "model") for b in (path / "result", path) for m in ("RP", "HILIC")]
    candidates += [path / "result" / "model", path / "model", path]
    for model_dir in candidates:
        manifest = model_dir / "model_manifest.json"
        if not manifest.is_file():
            continue
        try:
            mode = json.loads(manifest.read_text())["model_type"]
        except (OSError, ValueError, KeyError):
            fail(f"cannot read model_type from {manifest}")
        found.setdefault(mode, (model_dir.resolve(), model_dir.parent.resolve()))
    if not found:
        fail(f"no rtpred_train model found in input_dir: {path}")
    return found


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    cpus = resolve_cpus(params["cpus"])

    if params["scope"] not in ("all", "best"):
        fail(f"scope must be all or best: {params['scope']}")
    if not input_dir.is_dir():
        fail(f"input_dir not found: {input_dir}")
    trained = locate_train_outputs(input_dir)
    result_dir = output_dir / "result"

    # Evaluation rows per mode: each mode's reserved_test.csv, or eval_file split by model_type.
    eval_rows, eval_tables, ignored = None, {}, {}
    if params["eval_file"] in ("", "reserved_test"):
        for mode, (_, train_result) in trained.items():
            table = train_result / "reserved_test.csv"
            if not table.is_file():
                fail(f"reserved_test.csv not found in {train_result}; set eval_file")
            eval_tables[mode] = table
    else:
        eval_file = Path(params["eval_file"])
        if not eval_file.is_file():
            fail(f"eval_file not found: {eval_file}")
        if eval_file.suffix.lower() not in TABLE_SUFFIXES:
            fail(f"eval_file must be a *.csv or *.xlsx table: {eval_file}")
        rows = read_rows(eval_file, params["sheet"])
        groups = split_by_mode(rows)
        ignored = {m: len(v) for m, v in groups.items() if m not in trained}
        eval_rows = (rows[0], {m: v for m, v in groups.items() if m in trained})
    check_inputs_outside(result_dir, input_dir, *[d for pair in trained.values() for d in pair],
                         *eval_tables.values(), *([] if eval_rows is None else [Path(params["eval_file"])]))
    if importlib.util.find_spec("mdcc") is None:
        fail(f"mdcc is not importable; run inside {IMAGE}")

    logs = Logs(output_dir)
    log(logs, f"############################## RTpred {MODULE}")
    log(logs, f"Log files: {logs.out.name} (stdout), {logs.err.name} (stderr)")
    log(logs, f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    log(logs)
    log(logs, "parameters:")
    log(logs, f"  input_dir  = {input_dir}")
    for mode, (model_dir, _) in sorted(trained.items()):
        log(logs, f"  user model {mode:<5} = {model_dir}")
    log(logs, f"  eval_file  = {params['eval_file'] or 'reserved_test'}")
    log(logs, f"  output_dir = {output_dir}")
    log(logs, f"  cpus       = {cpus} (requested {params['cpus']}, allocated {allocated_cpus()})")
    for key in ["rt_unit", "sheet", "scope", "title"]:
        log(logs, f"  {key:<10} = {params.get(key) or '<default>'}")
    for mode, n in ignored.items():
        log_err(logs, f"WARNING: {n} eval_file row(s) are {mode}, which was not trained; they are not used")
    log(logs)

    clear_previous_result(logs, output_dir, result_dir)
    summary, tables = [], []
    for mode in ("RP", "HILIC"):
        if mode not in trained:
            continue
        model_dir, _ = trained[mode]
        if eval_rows is None:
            table, n_rows = eval_tables[mode], None
        else:
            header, groups = eval_rows
            if mode not in groups:
                log_err(logs, f"WARNING: eval_file has no {mode} rows; {mode} is not compared")
                summary.append([mode, "0", "no_eval_rows", "", ""])
                continue
            table = result_dir / "inputs" / f"eval_{mode}.csv"
            write_rows(table, header, groups[mode])
            n_rows = len(groups[mode])
        rt_unit = params["rt_unit"]
        if rt_unit in ("", "auto"):
            # mdcc compare stops unless this matches the unit used in training.
            try:
                rt_unit = json.loads((model_dir / "model_manifest.json").read_text())["rt_unit"]
            except (OSError, ValueError, KeyError):
                fail(f"cannot read rt_unit from {model_dir / 'model_manifest.json'}; set rt_unit")
        log(logs, f"=== {mode}: {table} -> {result_dir / mode} (rt_unit {rt_unit})")
        args = [MODULE, "--input", str(table), "--output", str(result_dir / mode),
                "--model", mode, "--user-model", str(model_dir),
                "--rt-unit", rt_unit, "--scope", params["scope"], "--title", f"{params['title']} ({mode})"]
        # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
        if eval_rows is None and params["sheet"] not in ("", "first") and table.suffix.lower() == ".xlsx":
            args += ["--sheet", params["sheet"]]
        code = run_mdcc(logs, args, cpus)
        best = ""
        if code == 0:
            with (result_dir / mode / "comparison.csv").open(encoding="utf-8", newline="") as handle:
                rows = list(csv.reader(handle))
            tables.append((mode, rows))
            best = rows[1][rows[0].index("candidate")] if len(rows) > 1 else ""
            n_rows = n_rows if n_rows is not None else json.loads(
                (result_dir / mode / "manifest.json").read_text()).get("evaluated_rows_per_model", "")
        else:
            log_err(logs, f"WARNING: {mode} was not compared")
        summary.append([mode, str(n_rows if n_rows is not None else ""), "ok" if code == 0 else "failed",
                        best, f"{mode}/" if code == 0 else ""])
        log(logs)

    result_dir.mkdir(parents=True, exist_ok=True)
    with (result_dir / "compare_summary.tsv").open("w", encoding="utf-8", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(["Mode", "Eval_rows", "Status", "Best_candidate", "Output"])
        writer.writerows(summary)
    if tables:
        with (result_dir / "comparison.csv").open("w", encoding="utf-8", newline="") as handle:
            writer = csv.writer(handle)
            writer.writerow(["Mode", *tables[0][1][0]])
            for mode, rows in tables:
                writer.writerows([mode, *row] for row in rows[1:])

    compared = [m for m, _ in tables]
    log(logs, f"Compared modes: {', '.join(compared) or 'none'}")
    log(logs, f"Results: {result_dir}")
    log(logs, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    if not compared:
        log_err(logs, "Error: no mode was compared")
    sys.exit(0 if compared else 1)


if __name__ == "__main__":
    main()
