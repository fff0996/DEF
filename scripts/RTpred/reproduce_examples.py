"""Run actual models with synthetic training targets; output root must be new."""
import argparse
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
p = argparse.ArgumentParser()
p.add_argument("--output-root", required=True)
args = p.parse_args()
out = Path(args.output_root).resolve()
out.mkdir(parents=True, exist_ok=False)
env = dict(os.environ, PYTHONPATH=str(ROOT), PYTHONDONTWRITEBYTECODE="1", MPLCONFIGDIR="/tmp/mdcc-mpl", OMP_NUM_THREADS="2", OPENBLAS_NUM_THREADS="2")


def run(module, source, destination, *extra):
    subprocess.run([sys.executable, "-m", "mdcc.cli", module, "--input", str(source), "--output", str(destination), *extra], env=env, cwd=ROOT, check=True)


run("predict", ROOT / "examples/compounds.csv", out / "01_predict")
for mode in ["RP", "HILIC"]:
    training = out / f"02_train_{mode}"
    options = ["--algorithms", "RF", "XT"] if mode == "RP" else []
    run("train", ROOT / f"examples/synthetic_training_{mode}.csv", training,
        "--model", mode, "--time-limit", "30", "--method-label", "SYNTHETIC_DEMO", *options)
    run("compare", training / "reserved_test.csv", out / f"03_compare_{mode}", "--model", mode,
        "--user-model", str(training / "model"), "--title", f"SYNTHETIC {mode} RT demo - not measured performance")
