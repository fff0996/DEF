#!/usr/bin/env python3
# scGPT pipeline, module 2: cell embeddings with a pretrained scGPT model (GPU module).
# Reads the scgpt_prep dataset, takes up to max_cells_per_patient cells per patient, and
# writes the scGPT cell embedding of every cell (the <cls> output of the frozen transformer,
# scaled to length 1), the same computation as scgpt.tasks.embed_data in scGPT 0.2.4. The
# model is loaded once and cells are embedded sample by sample, so the whole count matrix is
# never made dense. Runs on a GPU when one is visible; on CPU it is very slow (about 2 s per
# cell on two cores).
#
# Usage:
#   python3 scgpt_embed.1.0.py input_dir="..." output_dir="..."
#       [checkpoint_dir="builtin"] [max_cells_per_patient="500"] [max_genes="1200"]
#       [batch_size="auto"] [device="auto"] [seed="1234"]
#
# Example:
#   apptainer exec --nv bx_scgpt.1.0.sif python3 scgpt_embed.1.0.py \
#       input_dir=/data/scgpt_prep output_dir=/data/scgpt_embed
#
# Arguments:
#   input_dir             (required) - scgpt_prep output folder (dataset.h5ad, patients.tsv, ...)
#   output_dir            (required) - Output directory
#   checkpoint_dir        (optional) - scGPT checkpoint folder with args.json, best_model.pt and
#                                      vocab.json; builtin is the whole-human checkpoint in the
#                                      image (33 million human cells). default: builtin
#   max_cells_per_patient (optional) - Cells drawn per patient (random, with seed); 0 uses all
#                                      cells. Patients with fewer cells keep all. default: 500
#   max_genes             (optional) - Genes per cell given to the model; cells with more
#                                      detected genes get a random subset, as in scGPT.
#                                      default: 1200 (the length the model was trained with)
#   batch_size            (optional) - Cells per batch; auto is 64 on GPU and 16 on CPU.
#                                      default: auto
#   device                (optional) - auto (GPU if visible, otherwise CPU), cuda or cpu.
#                                      default: auto
#   seed                  (optional) - Random seed (cell draw, gene subset, binning ties).
#                                      default: 1234
#
# Outputs (output_dir):
#   embeddings.h5ad   cells x 512 scGPT embeddings; obs as in dataset.h5ad (SampleID, PatientID,
#                     Cohort, Tissue, Time, Label, cell_type)
#   embed_info.json   checkpoint name and SHA256 of best_model.pt, options, device, cells per
#                     patient, path of the scgpt_prep folder (read by later modules)
#   patients.tsv, splits.tsv, splits_cohort.tsv, prep_info.json
#                     copied from scgpt_prep so that later modules read one folder
#   plots/            embedding_umap (UMAP of the embeddings by label, cohort and cell type)
#   logs/             <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Register this module on a GPU node (CLOSHA Computing Environment GPU). Rerunning removes
# everything in output_dir except logs/.

import datetime
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time
import warnings
from pathlib import Path

MODULE = "scgpt_embed"
REQUIRED = ["input_dir", "output_dir"]
OPTIONAL = {"checkpoint_dir": "builtin", "max_cells_per_patient": "500", "max_genes": "1200",
            "batch_size": "auto", "device": "auto", "seed": "1234"}
BUILTIN_CHECKPOINT = "/opt/bio/share/scgpt/checkpoints/whole_human"
COPY_FROM_PREP = ["patients.tsv", "splits.tsv", "splits_cohort.tsv", "prep_info.json"]


# ----------------------------------------------------------------- common (same in every module)
def early_fail(message):
    """Error before the log files exist: stderr only."""
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    params = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            early_fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            early_fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            early_fail(f"Unknown parameter: {key}")
        value = value.strip().strip("'\"")
        params[key] = value if value or key in REQUIRED else OPTIONAL[key]
    for key in REQUIRED:
        if not params.get(key):
            early_fail(f"Required parameter '{key}' is missing")
    return params


def allocated_cores():
    """Cores bound to this job. Public CLOSHA modules run with OMP_NUM_THREADS=1, which nproc
    would follow, so it is removed for this one call (docs/CLOSHA_Script_Rules_v1.md 11)."""
    try:
        out = subprocess.run(["env", "-u", "OMP_NUM_THREADS", "-u", "OMP_THREAD_LIMIT", "nproc"],
                             capture_output=True, text=True, check=True).stdout.strip()
        return max(1, int(out))
    except (OSError, ValueError, subprocess.CalledProcessError):
        return max(1, len(os.sched_getaffinity(0)))


class Log:
    """stdout -> <stamp>.log, stderr -> <stamp>.error.log, both also on screen."""

    def __init__(self, output_dir):
        logs_dir = output_dir / "logs"
        logs_dir.mkdir(parents=True, exist_ok=True)
        stamp = f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{os.getpid()}"
        self.log_file = logs_dir / f"{stamp}.log"
        self.err_file = logs_dir / f"{stamp}.error.log"
        self.out = self.log_file.open("a", encoding="utf-8")
        self.err = self.err_file.open("a", encoding="utf-8")
        warnings.showwarning = self._python_warning

    def msg(self, text=""):
        print(text, flush=True)
        self.out.write(text + "\n")
        self.out.flush()

    def warn(self, text):
        print(f"Warning: {text}", file=sys.stderr, flush=True)
        self.err.write(f"Warning: {text}\n")
        self.err.flush()

    def fail(self, text):
        print(f"Error: {text}", file=sys.stderr, flush=True)
        self.err.write(f"Error: {text}\n")
        self.err.flush()
        sys.exit(1)

    def step(self, text):
        self.msg(f"############################## {text}")

    def _python_warning(self, message, category, filename, lineno, file=None, line=None):
        text = f"Warning: {category.__name__}: {message} ({Path(filename).name}:{lineno})"
        print(text, file=sys.stderr, flush=True)
        self.err.write(text + "\n")
        self.err.flush()


def prepare_output(output_dir, inputs):
    """Remove everything in output_dir except logs/, after checking that no input is inside it."""
    out = Path(output_dir).resolve()
    if str(out) == "/":
        early_fail("output_dir must not be /")
    for p in inputs:
        rp = Path(p).resolve()
        if rp == out or out in rp.parents:
            early_fail(f"input {p} is inside output_dir {out}, which is cleared on each run")
    if out.exists():
        for child in out.iterdir():
            if child.name == "logs":
                continue
            if child.is_dir() and not child.is_symlink():
                shutil.rmtree(child)
            else:
                child.unlink()
    out.mkdir(parents=True, exist_ok=True)
    return out


def positive_int(log, name, value, minimum=1):
    if not re.fullmatch(r"\d+", value) or int(value) < minimum:
        log.fail(f"{name} must be an integer >= {minimum}: {value}")
    return int(value)


def sha256_file(path):
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for block in iter(lambda: fh.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def use_private_cache(out):
    """Caches of matplotlib, numba, Hugging Face and PyTorch go to output_dir/.cache (removed at
    the end), never to the user's home, which CLOSHA binds from the host. No network access."""
    cache = out / ".cache"
    cache.mkdir(exist_ok=True)
    for var in ("XDG_CACHE_HOME", "MPLCONFIGDIR", "NUMBA_CACHE_DIR", "HF_HOME", "TORCH_HOME"):
        os.environ[var] = str(cache / var.lower())
    os.environ["HF_DATASETS_OFFLINE"] = "1"
    os.environ["HF_HUB_OFFLINE"] = "1"
    return cache

def save_plot(fig, path_stem):
    fig.savefig(f"{path_stem}.png", dpi=150, bbox_inches="tight", facecolor="white")
    fig.savefig(f"{path_stem}.pdf", bbox_inches="tight", facecolor="white")


# ----------------------------------------------------------------- module
def main():
    params = parse_args(sys.argv[1:])
    prep_dir = Path(params["input_dir"])
    if not (prep_dir / "dataset.h5ad").exists():
        early_fail(f"dataset.h5ad not found in input_dir {prep_dir}; give the scgpt_prep output folder")
    out = prepare_output(params["output_dir"], [prep_dir])
    log = Log(out)
    cache = use_private_cache(out)
    start = datetime.datetime.now()

    max_cells = positive_int(log, "max_cells_per_patient", params["max_cells_per_patient"], 0)
    max_genes = positive_int(log, "max_genes", params["max_genes"], 16)
    seed = positive_int(log, "seed", params["seed"], 0)
    if params["device"] not in ("auto", "cuda", "cpu"):
        log.fail(f"device must be auto, cuda or cpu: {params['device']}")
    ckpt = Path(BUILTIN_CHECKPOINT if params["checkpoint_dir"] == "builtin" else params["checkpoint_dir"])
    for f in ("args.json", "best_model.pt", "vocab.json"):
        if not (ckpt / f).exists():
            log.fail(f"{f} not found in checkpoint_dir {ckpt} (needs args.json, best_model.pt, vocab.json)")
    cores = allocated_cores()

    # Known notices that are not problems here: torchtext 0.18 is the last release (scGPT's
    # vocabulary still uses it), flash-attn is optional and not installed (standard attention
    # is used), and PyTorch's nested-tensor prototype note from TransformerEncoder.
    warnings.filterwarnings("ignore", message="flash_attn is not installed")
    warnings.filterwarnings("ignore", message="The PyTorch API of nested tensors")
    try:
        import torchtext
        torchtext.disable_torchtext_deprecation_warning()
    except (ImportError, AttributeError):
        pass
    for name in ("numpy", "pandas", "torch", "scanpy", "anndata", "scgpt", "matplotlib"):
        try:
            __import__(name)
        except ImportError:
            log.fail(f"required Python package not found: {name}")
    import numpy as np
    import pandas as pd
    import scanpy as sc
    import anndata as ad
    import scipy.sparse as sp
    import torch
    from scgpt.model import TransformerModel
    from scgpt.tokenizer import GeneVocab
    from scgpt.utils import load_pretrained
    from scgpt.data_collator import DataCollator
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt

    torch.set_num_threads(cores)
    if params["device"] == "auto":
        device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    else:
        device = torch.device(params["device"])
        if device.type == "cuda" and not torch.cuda.is_available():
            log.fail("device=cuda but no GPU is visible (run on a GPU node; apptainer needs --nv)")
    batch_size = (64 if device.type == "cuda" else 16) if params["batch_size"] == "auto" else \
        positive_int(log, "batch_size", params["batch_size"], 1)
    gpu_name = torch.cuda.get_device_name(0) if device.type == "cuda" else ""

    log.msg(f"############################## {MODULE}")
    log.msg(f"Log file: {log.log_file}")
    log.msg(f"Start time: {start:%Y-%m-%d %H:%M:%S}")
    log.msg("")
    log.msg("parameters:")
    for k in REQUIRED + list(OPTIONAL):
        log.msg(f"  {k:<22}= {params[k]}")
    log.msg(f"  {'checkpoint (resolved)':<22}= {ckpt}")
    log.msg(f"  {'device (resolved)':<22}= {device}{' ' + gpu_name if gpu_name else ''}")
    log.msg(f"  {'batch_size (resolved)':<22}= {batch_size}")
    log.msg(f"  {'threads':<22}= {cores} (allocated {cores})")
    log.msg("")
    if device.type == "cpu":
        log.warn("no GPU in use: scGPT on CPU takes about 2 s per cell per core pair; "
                 "register this module on a GPU node for real data")

    # ------------------------------------------------------------- Step 1: cells
    log.step("Step 1: Read dataset and draw cells")
    adata = sc.read_h5ad(prep_dir / "dataset.h5ad")
    prep_info = json.loads((prep_dir / "prep_info.json").read_text())
    log.msg(f"Dataset: {adata.n_obs} cells, {adata.n_vars} genes, {adata.obs['PatientID'].nunique()} patients")
    rng = np.random.default_rng(seed)
    keep = []
    for pid, idx in adata.obs.groupby("PatientID", observed=True).indices.items():
        idx = np.sort(idx)
        if max_cells and len(idx) > max_cells:
            idx = np.sort(rng.choice(idx, size=max_cells, replace=False))
        keep.append(idx)
    keep = np.sort(np.concatenate(keep))
    adata = adata[keep].copy()
    per_patient = adata.obs["PatientID"].value_counts().sort_index()
    log.msg(f"Cells used: {adata.n_obs} (max {max_cells or 'all'} per patient; "
            f"min {per_patient.min()}, max {per_patient.max()} per patient)")

    # ------------------------------------------------------------- Step 2: model
    log.step("Step 2: Load scGPT")
    vocab = GeneVocab.from_file(ckpt / "vocab.json")
    for tok in ["<pad>", "<cls>", "<eoc>"]:
        if tok not in vocab:
            vocab.append_token(tok)
    vocab.set_default_index(vocab["<pad>"])
    cfg = json.loads((ckpt / "args.json").read_text())
    in_vocab = np.array([g in vocab for g in adata.var_names])
    adata = adata[:, in_vocab].copy()
    gene_ids = np.array(vocab(adata.var_names.tolist()), dtype=int)
    log.msg(f"Genes in vocabulary: {adata.n_vars}")
    model = TransformerModel(
        ntoken=len(vocab), d_model=cfg["embsize"], nhead=cfg["nheads"], d_hid=cfg["d_hid"],
        nlayers=cfg["nlayers"], nlayers_cls=cfg["n_layers_cls"], n_cls=1, vocab=vocab,
        dropout=cfg["dropout"], pad_token=cfg["pad_token"], pad_value=cfg["pad_value"],
        do_mvc=True, do_dab=False, use_batch_labels=False, domain_spec_batchnorm=False,
        explicit_zero_prob=False, use_fast_transformer=False, fast_transformer_backend="flash",
        pre_norm=False)
    load_pretrained(model, torch.load(ckpt / "best_model.pt", map_location=device), verbose=False)
    model.to(device)
    model.eval()
    ckpt_sha = sha256_file(ckpt / "best_model.pt")
    log.msg(f"Checkpoint: {ckpt.name}, best_model.pt SHA256 {ckpt_sha}")
    log.msg(f"Model: {cfg['nlayers']} layers, embedding {cfg['embsize']}, trained length {cfg['max_seq_len']}")
    if max_genes > cfg["max_seq_len"]:
        log.warn(f"max_genes={max_genes} is longer than the training length {cfg['max_seq_len']}")
    collator = DataCollator(do_padding=True, pad_token_id=vocab[cfg["pad_token"]], pad_value=cfg["pad_value"],
                            do_mlm=False, do_binning=True, max_length=max_genes + 1, sampling=True,
                            keep_first_n_tokens=1)
    cls_id = vocab["<cls>"]
    pad_id = vocab[cfg["pad_token"]]

    # ------------------------------------------------------------- Step 3: embed
    log.step("Step 3: Embed cells")
    X = sp.csr_matrix(adata.X)
    emb = np.zeros((adata.n_obs, cfg["embsize"]), dtype=np.float32)
    samples = adata.obs["SampleID"].astype(str).values
    t0 = time.time()
    done = 0
    autocast = torch.autocast(device_type="cuda", dtype=torch.float16) if device.type == "cuda" else None
    for si, sid in enumerate(pd.unique(samples)):
        # Same seed per sample whatever the other samples are.
        np.random.seed(seed + si)
        torch.manual_seed(seed + si)
        rows = np.where(samples == sid)[0]
        nnz = np.diff(X.indptr)[rows]
        order = rows[np.argsort(nnz, kind="stable")]  # similar lengths per batch: less padding
        for b in range(0, len(order), batch_size):
            batch = order[b:b + batch_size]
            items = []
            for r in batch:
                lo, hi = X.indptr[r], X.indptr[r + 1]
                cols, vals = X.indices[lo:hi], X.data[lo:hi]
                nz = vals > 0
                genes = np.insert(gene_ids[cols[nz]], 0, cls_id)
                values = np.insert(vals[nz].astype(np.float32), 0, cfg["pad_value"])
                items.append({"genes": torch.from_numpy(genes).long(), "expressions": torch.from_numpy(values).float()})
            data = collator(items)
            genes_t = data["gene"].to(device)
            with torch.no_grad():
                if autocast is not None:
                    with autocast:
                        h = model._encode(genes_t, data["expr"].to(device), src_key_padding_mask=genes_t.eq(pad_id))
                else:
                    h = model._encode(genes_t, data["expr"].to(device), src_key_padding_mask=genes_t.eq(pad_id))
            emb[batch] = h[:, 0, :].float().cpu().numpy()
            done += len(batch)
        rate = done / max(time.time() - t0, 1e-6)
        log.msg(f"  {sid}: {len(rows)} cells; total {done}/{adata.n_obs} ({rate:.1f} cells/s)")
    emb /= np.linalg.norm(emb, axis=1, keepdims=True)
    elapsed = time.time() - t0
    log.msg(f"Embedded {adata.n_obs} cells in {elapsed / 60:.1f} min")

    # ------------------------------------------------------------- Step 4: write
    log.step("Step 4: Write embeddings")
    obs = adata.obs.copy()
    e = ad.AnnData(X=emb, obs=obs)
    e.var_names = [f"scgpt_{i}" for i in range(emb.shape[1])]
    e.write_h5ad(out / "embeddings.h5ad", compression="gzip")
    for f in COPY_FROM_PREP:
        if (prep_dir / f).exists():
            shutil.copy2(prep_dir / f, out / f)
    info = {"module": MODULE, "created": f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}", "options": params,
            "checkpoint": ckpt.name, "checkpoint_dir": str(ckpt), "checkpoint_sha256": ckpt_sha,
            "embedding_size": int(emb.shape[1]), "cells": int(adata.n_obs), "genes_in_vocab": int(adata.n_vars),
            "device": str(device), "gpu": gpu_name, "minutes": round(elapsed / 60, 2),
            "prep_dir": str(prep_dir.resolve()), "positive_label": prep_info.get("positive_label", ""),
            "negative_label": prep_info.get("negative_label", ""), "tissue": prep_info.get("tissue", ""),
            "time": prep_info.get("options", {}).get("time", ""),
            "splits_sha256": prep_info.get("splits_sha256", ""),
            "cells_per_patient": {k: int(v) for k, v in per_patient.items()}}
    (out / "embed_info.json").write_text(json.dumps(info, indent=2))

    # ------------------------------------------------------------- Step 5: plot
    log.step("Step 5: UMAP of embeddings")
    (out / "plots").mkdir()
    u = e.copy()
    sc.pp.neighbors(u, n_neighbors=min(15, max(2, u.n_obs - 1)), use_rep="X", random_state=seed)
    sc.tl.umap(u, random_state=seed)
    cols = ["Label", "Cohort", "cell_type"]
    fig, axes = plt.subplots(1, 3, figsize=(16, 4.8))
    for ax, c in zip(axes, cols):
        sc.pl.umap(u, color=c, ax=ax, show=False, frameon=False, title=f"scGPT embedding: {c}",
                   size=max(3, 120000 / max(u.n_obs, 1) ** 1.0) if u.n_obs < 20000 else None)
    save_plot(fig, out / "plots" / "embedding_umap")
    plt.close(fig)

    log.step("Summary")
    log.msg(f"Cells: {adata.n_obs}, patients: {len(per_patient)}, device: {device}, minutes: {elapsed / 60:.1f}")
    log.step("Done")
    log.msg(f"Embeddings: {out / 'embeddings.h5ad'}")
    shutil.rmtree(cache, ignore_errors=True)
    log.msg(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
