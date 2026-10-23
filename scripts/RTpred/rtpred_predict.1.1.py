#!/usr/bin/env python3
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
    python rtpred_predict.1.1.py input_file="..." output_dir="..." [model_dir="default"] [model="auto"] [sheet="..."]

Examples:
    Bundled default models:
        apptainer exec bx_rtpred_predict.1.0.sif python rtpred_predict.1.1.py \
            input_file="/path/to/compounds.csv" \
            output_dir="/path/to/output" \
            model="RP"

    Model trained by rtpred_train:
        apptainer exec bx_rtpred_predict.1.0.sif python rtpred_predict.1.1.py \
            input_file="/path/to/compounds.csv" \
            output_dir="/path/to/output" \
            model_dir="/path/to/train_output"

Arguments (key=value, --key=value, or --key value):
    input_file (required) - Compound table (*.csv or *.xlsx) with a SMILES
                            column (smiles or structure); experimental_rt is
                            optional.
    output_dir (required) - Output directory. Results go to output_dir/result
                            and logs to output_dir/logs.
    model_dir  (optional) - default (or empty) uses the bundled default models.
                            Otherwise a rtpred_train output directory (its
                            output_dir; output_dir/result or result/model
                            also work); its trained model is used.
                            default: default
    model      (optional) - RP, HILIC, or auto. With the default models, auto
                            (or empty) uses the table's model_type column (RP
                            or HILIC per row), so one table may mix both
                            modes. With a trained model, auto takes the
                            model's mode; RP or HILIC must match it. Rows with
                            a model_type column must match the chosen mode.
                            default: auto
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
OPTIONAL = {"model_dir": "default", "model": "auto", "sheet": "first", "cpus": "auto"}
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
# argv: input table, result directory, model directory, mode, sheet ("" = first)
USER_PREDICT = r'''
import sys
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from mdcc.core import check_runtime, output_dir, load_table, infer, write_json, digest
from mdcc.cli import save_plot, report_html

def run(table, result, root, mode, sheet):
    env = check_runtime()
    frame = load_table(table, mode, sheet or None)
    values, status, manifest, best = infer(frame, root, mode)
    if manifest.get("artifact_kind") != "mdcc_user_model_v2":
        raise ValueError("model_dir must hold a model written by rtpred_train.")
    unit = manifest.get("rt_unit", "model unit")
    frame["predicted_rt"] = values
    frame[["parse_status", "warning_message"]] = status
    frame["best_model"] = best
    frame["delta_rt"] = frame.experimental_rt - frame.predicted_rt
    out = output_dir(result)
    frame.to_csv(out / "predictions.csv", index=False)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
    counts = frame.parse_status.value_counts()
    axes[0].bar(counts.index, counts.values, color="#197c91")
    axes[0].set(title="Prediction coverage", ylabel="Compounds")
    predicted = frame.predicted_rt.dropna()
    if len(predicted):
        axes[1].hist(predicted, alpha=.6, bins=min(15, len(predicted)), label=mode)
        axes[1].legend()
    axes[1].set(title="User best-model RT", xlabel=f"RT ({unit})", ylabel="Compounds")
    save_plot(fig, out, "prediction")
    report_html(out, "사용자 학습 모델 예측",
                f"rtpred_train으로 학습한 모델({best}, {manifest.get('method_label', 'user method')})로 계산했습니다. "
                f"RT 단위는 학습 때의 단위({unit})입니다. 처음 100행을 표시합니다.",
                frame.head(100), "prediction.png", ["predictions.csv", "manifest.json"])
    write_json(out / "manifest.json", {"module": "predict", "schema_version": 2, "runtime": env,
        "model_source": "user", "models": {mode: {"best_model": best, "model_directory": str(root),
        "manifest_sha256": digest(root + "/model_manifest.json"), "rt_unit": unit,
        "method_label": manifest.get("method_label", "unknown")}},
        "input_sha256": digest(table), "rows": len(frame), "network_required": False})

try:
    run(*sys.argv[1:6])
except (ValueError, KeyError, FileNotFoundError, RuntimeError) as exc:
    raise SystemExit(f"ERROR: {exc}") from exc
'''


def locate_train_model(path):
    """Accept a rtpred_train output_dir, its result/ directory, or result/model."""
    for model_dir in (path / "result" / "model", path / "model", path):
        if (model_dir / "model_manifest.json").is_file():
            return model_dir
    fail(f"no rtpred_train model (model_manifest.json) found in model_dir: {path}")


def main():
    params = parse_args(sys.argv[1:])
    input_file = Path(params["input_file"])
    output_dir = Path(params["output_dir"])
    # auto (or empty) leaves --model out, so mdcc uses each row's model_type.
    cpus = resolve_cpus(params["cpus"])
    model = "" if params["model"] in ("", "auto") else params["model"]

    if model and model not in ("RP", "HILIC"):
        fail(f"model must be RP, HILIC, or auto: {model}")
    if not input_file.is_file():
        fail(f"input_file not found: {input_file}")
    model_dir = None
    if params["model_dir"] not in ("", "default"):
        given = Path(params["model_dir"])
        if not given.is_dir():
            fail(f"model_dir not found: {given}")
        model_dir = locate_train_model(given).resolve()
        try:
            trained_mode = json.loads((model_dir / "model_manifest.json").read_text())["model_type"]
        except (OSError, ValueError, KeyError):
            fail(f"cannot read model_type from {model_dir / 'model_manifest.json'}")
        if model and model != trained_mode:
            fail(f"model={model} does not match the trained model ({trained_mode}) in {model_dir}")
        model = trained_mode
    if input_file.suffix.lower() not in TABLE_SUFFIXES:
        fail(f"input_file must be a *.csv or *.xlsx table: {input_file}")
    result_dir = output_dir / "result"
    check_inputs_outside(result_dir, input_file, *([model_dir] if model_dir else []))
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
    log(logs, f"  model_dir  = {model_dir or 'default (bundled models)'}")
    if model_dir:
        log(logs, f"  model      = {model} (from the trained model; requested {params['model']})")
    else:
        log(logs, f"  model      = {model or 'auto (input model_type column)'}")
    log(logs, f"  sheet      = {params['sheet'] or 'first'}")
    log(logs)

    # "first" (or an empty value) keeps mdcc's default: the first XLSX sheet.
    sheet = "" if params["sheet"] in ("", "first") else params["sheet"]
    clear_previous_result(logs, output_dir, result_dir)
    if model_dir:
        command = ["-c", USER_PREDICT, str(input_file), str(result_dir), str(model_dir), model, sheet]
        code = run_python(logs, command, cpus, "predict (user model)")
    else:
        args = [MODULE, "--input", str(input_file), "--output", str(result_dir)]
        if model:
            args += ["--model", model]
        if sheet:
            args += ["--sheet", sheet]
        code = run_mdcc(logs, args, cpus)

    log(logs)
    log(logs, f"Results: {result_dir}")
    log(logs, f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    sys.exit(code)


if __name__ == "__main__":
    main()
