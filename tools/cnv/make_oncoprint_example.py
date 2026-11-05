#!/usr/bin/env python3
"""Example of the cnv_summary gene oncoprint with 10 samples, drawn by the plotting code of
scripts/CNV/cnv_summary.1.0.py itself (the constants, plotting(), save_figure() and the
"# Gene oncoprint." block are read from that file and run unchanged).

The gene calls are SIMULATED (fixed seed): they only show what the figure looks like when
10 samples are given. They are not results of any patient or cell line.

Usage: python3 tools/cnv/make_oncoprint_example.py <output folder>
Writes <output folder>/gene_oncoprint.png and .pdf. Needs matplotlib, numpy and pandas.
"""
import ast
import sys
from pathlib import Path

import numpy as np
import pandas as pd

SRC = Path(__file__).resolve().parents[2] / "scripts" / "CNV" / "cnv_summary.1.0.py"


def load_plot_code():
    text = SRC.read_text()
    tree = ast.parse(text)
    keep = [n for n in tree.body
            if (isinstance(n, ast.Assign) and any(getattr(t, "id", "") in
                ("CATEGORY_COLORS", "CATEGORIES", "LOH_COLOR") for t in n.targets))
            or (isinstance(n, ast.FunctionDef) and n.name in ("plotting", "save_figure"))]
    ns = {}
    exec(compile(ast.Module(keep, []), str(SRC), "exec"), ns)
    lines = text.splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip() == "# Gene oncoprint.")
    end = next(i for i in range(start, len(lines)) if '"gene_oncoprint", made)' in lines[i])
    block = "\n".join(l[4:] for l in lines[start:end + 1])   # main() body is indented 4 spaces
    return ns, block


def simulated_calls(rng):
    """10 samples x lung-cancer-relevant genes; per-gene call probabilities."""
    genes = {  # gene: (P(AMP), P(GAIN), P(LOSS), P(DEEPDEL))
        "CDKN2A": (0, 0, .2, .4), "MYC": (.2, .3, 0, 0), "EGFR": (.2, .2, 0, 0),
        "TERT": (.1, .4, 0, 0), "NKX2-1": (.2, .1, 0, 0), "SOX2": (.1, .3, 0, 0),
        "KRAS": (.1, .2, 0, 0), "MDM2": (.1, .1, 0, 0), "CCND1": (.1, .2, 0, 0),
        "TP53": (0, 0, .5, 0), "STK11": (0, 0, .4, .1), "PTEN": (0, 0, .3, .1),
        "RB1": (0, 0, .3, .1), "SMARCA4": (0, 0, .3, 0), "MET": (.1, .1, 0, 0)}
    samples = [f"P{i:02d}" for i in range(1, 11)]
    rows = []
    for g, (amp, gain, loss, dd) in genes.items():
        for s in samples:
            call = rng.choice(["AMP", "GAIN", "LOSS", "DEEPDEL", "NEUTRAL"],
                              p=[amp, gain, loss, dd, 1 - amp - gain - loss - dd])
            loh = "yes" if call in ("LOSS", "DEEPDEL") and rng.random() < .6 else "no"
            rows.append({"SampleID": s, "Gene": g, "Call": call, "LOH": loh})
    return pd.DataFrame(rows), samples, list(genes)


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    ns, block = load_plot_code()
    gl, samples, gene_set = simulated_calls(np.random.default_rng(2026))
    plt = ns["plotting"]()
    made = []
    env = dict(ns, gl=gl, samples=samples, gene_set=gene_set, plt=plt, np=np, made=made,
               d_plot=out, params={"genes": "example_genes.txt"})
    exec(block, env)
    print("written:", ", ".join(str(out / f"{m}.png") for m in made))


if __name__ == "__main__":
    main()
