#!/usr/bin/env python3
# Version 1.2 (changes from rtpred_predict.1.1.py):
#   Trained models of several modes: model_dir may hold the per-mode models of
#   rtpred_train 1.1 (result/RP/, result/HILIC/) or the single model of
#   rtpred_train 1.0. Each row is predicted with the trained model of its
#   model_type. Rows of a mode that was not trained (for example HILIC rows
#   when only RP was trained) are not predicted, as the developers asked
#   (2026-10-23): they stay in predictions.csv with an empty predicted_rt,
#   parse_status=no_trained_model and a warning message, and stderr gives
#   their number. The run stops only when no row has a trained mode.
#   predictions.csv gains rt_unit (the unit the model was trained in).
#   The mode comes only from the table: the model_type column (RP or HILIC
#   per row) is required and the model option is removed, for the default
#   models too (1.1 also accepted model=RP/HILIC for a table without it).
#
# Version 1.1 (changes from rtpred_predict.1.0.py):
#   Model choice: the new optional model_dir takes a rtpred_train output
#   directory, and the compounds are predicted with that user-trained model
#   (its validation-best model). Empty or "default" keeps the 1.0 behavior:
#   the bundled default RP/HILIC models. This connects rtpred_train to
#   rtpred_predict, as the developers intended (train optional -> predict with
#   the default or the trained model -> compare optional).
#   The image is unchanged: the user-model path uses the mdcc functions that
#   rtpred_compare already uses to load trained models.
#
"""RTpred module 1: retention time prediction with the bundled default models
or a model trained by rtpred_train.

Usage:
    python rtpred_predict.1.2.py input_file="..." output_dir="..." [model_dir="default"] [sheet="..."]

Examples:
    Bundled default models:
        apptainer exec bx_rtpred_predict.1.0.sif python rtpred_predict.1.2.py \
            input_file="/path/to/compounds.csv" \
            output_dir="/path/to/output"

    Model trained by rtpred_train:
        apptainer exec bx_rtpred_predict.1.0.sif python rtpred_predict.1.2.py \
            input_file="/path/to/compounds.csv" \
            output_dir="/path/to/output" \
            model_dir="/path/to/train_output"

Arguments (key=value, --key=value, or --key value):
    input_file (required) - Compound table (*.csv or *.xlsx) with a SMILES
                            column (smiles or structure) and a model_type
                            column (RP or HILIC per row; modes may be mixed);
                            experimental_rt is optional.
    output_dir (required) - Output directory. Results go to output_dir/result
                            and logs to output_dir/logs.
    model_dir  (optional) - default (or empty) uses the bundled default models.
                            Otherwise a rtpred_train output directory (its
                            output_dir or output_dir/result); each row uses
                            the trained model of its mode, and rows of a mode
                            without a trained model are not predicted
                            (parse_status=no_trained_model). default: default
    cpus       (optional) - Threads for numeric libraries: auto uses the cores
                            allocated to the job (Slurm/cgroup); a number is
                            capped by them. default: auto
    sheet      (optional) - XLSX sheet name; first (or empty) reads the first
                            sheet. Ignored for CSV. default: first

Outputs (output_dir/result):
    predictions.csv, prediction.png/.svg, report.html, manifest.json
    (manifest.json records which model was used: default or user, with the
    model directory and its manifest checksum)

Logs (output_dir/logs): <time>_<pid>.log copies stdout (progress) and
<time>_<pid>.err copies stderr (errors and warnings).

Runs inside bx_rtpred_predict.1.0.sif, where mdcc and the default models are
installed. A trained model must come from rtpred_train in an image with the
same Python and package versions (bx_rtpred_train.1.0.sif); mdcc checks this. Rerunning replaces output_dir/result (only that folder is removed;
logs are kept).
"""
import datetime
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading

MODULE = "predict"
IMAGE = "bx_rtpred_predict.1.0.sif"
REQUIRED = ["input_file", "output_dir"]
OPTIONAL = {"model_dir": "default", "sheet": "first", "cpus": "auto"}
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
    return run_python(logs, ["-m", "mdcc.cli", *args], cpus, f"mdcc {args[0]}")


def run_python(logs, args, cpus, label):
    """Run the image's Python with numeric-library threads set to cpus,
    keeping its stdout and stderr apart."""
    command = [sys.executable, *args]
    env = dict(os.environ, **{name: str(cpus) for name in
               ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS")})
    shown = ["<user-model predict code>" if a == USER_PREDICT else a for a in command]
    log(logs, "Command: " + " ".join(shown))
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
        log_err(logs, f"Error: {label} exited with status {process.returncode}")
    return process.returncode


# Prediction with a rtpred_train model. mdcc's own predict command reads only
# the bundled models, so this runs the same steps (load_table, infer, plot,
# report, manifest) with the trained model directory instead. It runs as a
# separate Python process like the mdcc command, so its stdout and stderr are
# logged the same way.
# argv: input table, result directory, model directories by mode (JSON), sheet ("" = first)
USER_PREDICT = r'''
import json
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mdcc.core import check_runtime, output_dir, load_table, infer, write_json, digest
from mdcc.cli import save_plot, report_html

def run(table, result, roots, sheet):
    env = check_runtime()
    roots = json.loads(roots)
    frame = load_table(table, None, sheet or None)
    frame["predicted_rt"] = np.nan
    frame["parse_status"] = "no_trained_model"
    frame["warning_message"] = ""
    frame["best_model"] = ""
    frame["rt_unit"] = ""
    records, skipped = {}, {}
    for mode in sorted(frame.model_type.unique()):
        rows = frame.index[frame.model_type.eq(mode)]
        if mode not in roots:
            frame.loc[rows, "warning_message"] = f"no trained {mode} model; not predicted"
            skipped[mode] = len(rows)
            continue
        values, status, manifest, best = infer(frame.loc[rows], roots[mode], mode)
        if manifest.get("artifact_kind") != "mdcc_user_model_v2":
            raise ValueError("model_dir must hold models written by rtpred_train.")
        unit = manifest.get("rt_unit", "model unit")
        frame.loc[rows, "predicted_rt"] = values
        frame.loc[rows, ["parse_status", "warning_message"]] = status
        frame.loc[rows, "best_model"] = best
        frame.loc[rows, "rt_unit"] = unit
        records[mode] = {"best_model": best, "model_directory": roots[mode], "rt_unit": unit,
                         "manifest_sha256": digest(roots[mode] + "/model_manifest.json"),
                         "method_label": manifest.get("method_label", "unknown"), "rows": len(rows)}
    if not records:
        raise ValueError(f"no row has a trained mode: the table has {', '.join(sorted(frame.model_type.unique()))}, "
                         f"the trained models are {', '.join(sorted(roots))}. Leave model_dir empty to use the default models.")
    for mode, n in skipped.items():
        print(f"Warning: {n} of {len(frame)} rows are {mode}, which was not trained; they were not predicted "
              f"(parse_status=no_trained_model in predictions.csv).", file=sys.stderr, flush=True)
    units = {r["rt_unit"] for r in records.values()}
    if len(units) > 1:
        print(f"Warning: the trained models use different RT units ({', '.join(sorted(units))}); see the rt_unit column.",
              file=sys.stderr, flush=True)
    frame["delta_rt"] = frame.experimental_rt - frame.predicted_rt
    out = output_dir(result)
    frame.to_csv(out / "predictions.csv", index=False)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
    counts = frame.parse_status.value_counts()
    axes[0].bar(counts.index, counts.values, color="#197c91")
    axes[0].set(title="Prediction coverage", ylabel="Compounds")
    for mode in records:
        predicted = frame.loc[frame.model_type.eq(mode), "predicted_rt"].dropna()
        if len(predicted):
            axes[1].hist(predicted, alpha=.6, bins=min(15, len(predicted)), label=mode)
    if axes[1].get_legend_handles_labels()[0]:
        axes[1].legend()
    axes[1].set(title="User best-model RT", xlabel=f"RT ({', '.join(sorted(units))})", ylabel="Compounds")
    save_plot(fig, out, "prediction")
    note = (f"rtpred_train으로 학습한 모델({', '.join(f'{m}: {r['best_model']}' for m, r in records.items())})로 계산했습니다. "
            f"RT 단위는 학습 때의 단위({', '.join(sorted(units))})입니다.")
    if skipped:
        note += " 학습하지 않은 모드(" + ", ".join(f"{m} {n}행" for m, n in skipped.items()) + ")는 예측하지 않았습니다(parse_status=no_trained_model)."
    report_html(out, "사용자 학습 모델 예측", note + " 처음 100행을 표시합니다.",
                frame.head(100), "prediction.png", ["predictions.csv", "manifest.json"])
    write_json(out / "manifest.json", {"module": "predict", "schema_version": 2, "runtime": env,
        "model_source": "user", "models": records, "rows_not_predicted": skipped,
        "input_sha256": digest(table), "rows": len(frame), "network_required": False})

try:
    run(*sys.argv[1:5])
except (ValueError, KeyError, FileNotFoundError, RuntimeError) as exc:
    raise SystemExit(f"ERROR: {exc}") from exc
'''


# Column names mdcc reads as the chromatography mode (mdcc.core.load_table).
MODE_COLUMNS = {"model_type", "column", "chrom_system", "mode"}


def has_mode_column(path, sheet):
    """Whether the table's header has a mode column; mdcc checks the values."""
    if path.suffix.lower() == ".csv":
        import csv
        with path.open(encoding="utf-8-sig", newline="") as handle:
            header = next(csv.reader(handle), [])
    else:
        import pandas
        top = pandas.read_excel(path, sheet_name=0 if sheet in ("", "first") else sheet,
                                header=None, nrows=1, dtype=str)
        header = top.iloc[0].tolist() if len(top) else []
    return any(str(name).strip().lower() in MODE_COLUMNS for name in header)


def locate_train_models(path):
    """Trained models by mode: one folder per mode (result/RP/model,
    result/HILIC/model) or the single model of an earlier rtpred_train
    (result/model)."""
    found = {}
    bases = [path / "result", path]
    candidates = [b / m / "model" for b in bases for m in ("RP", "HILIC")]
    candidates += [path / "result" / "model", path / "model", path]
    for model_dir in candidates:
        manifest = model_dir / "model_manifest.json"
        if not manifest.is_file():
            continue
        try:
            mode = json.loads(manifest.read_text())["model_type"]
        except (OSError, ValueError, KeyError):
            fail(f"cannot read model_type from {manifest}")
        found.setdefault(mode, model_dir.resolve())
    if not found:
        fail(f"no rtpred_train model (model_manifest.json) found in model_dir: {path}")
    return found


def main():
    params = parse_args(sys.argv[1:])
    input_file = Path(params["input_file"])
    output_dir = Path(params["output_dir"])
    cpus = resolve_cpus(params["cpus"])

    if not input_file.is_file():
        fail(f"input_file not found: {input_file}")
    models = {}
    if params["model_dir"] not in ("", "default"):
        given = Path(params["model_dir"])
        if not given.is_dir():
            fail(f"model_dir not found: {given}")
        models = locate_train_models(given)
    if input_file.suffix.lower() not in TABLE_SUFFIXES:
        fail(f"input_file must be a *.csv or *.xlsx table: {input_file}")
    if not has_mode_column(input_file, params["sheet"]):
        fail("input_file has no model_type column; add one with RP or HILIC on every row")
    result_dir = output_dir / "result"
    check_inputs_outside(result_dir, input_file, *models.values())
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
    log(logs, f"  cpus       = {cpus} (requested {params['cpus']}, allocated {allocated_cpus()})")
    if models:
        log(logs, f"  model_dir  = {params['model_dir']}")
        for mode, path in sorted(models.items()):
            log(logs, f"    trained {mode:<5} = {path}")
    else:
        log(logs, "  model_dir  = default (bundled models)")
    log(logs, f"  sheet      = {params['sheet'] or 'first'}")
    log(logs)

    # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
    sheet = "" if params["sheet"] in ("", "first") else params["sheet"]
    clear_previous_result(logs, output_dir, result_dir)
    if models:
        roots = json.dumps({mode: str(path) for mode, path in models.items()})
        command = ["-c", USER_PREDICT, str(input_file), str(result_dir), roots, sheet]
        code = run_python(logs, command, cpus, "predict (user model)")
    else:
        args = [MODULE, "--input", str(input_file), "--output", str(result_dir)]
        if sheet:
            args += ["--sheet", sheet]
        code = run_mdcc(logs, args, cpus)

    log(logs)
    log(logs, f"Results: {result_dir}")
    log(logs, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
