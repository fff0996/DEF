"""Offline model contracts shared by three independent application modules."""
from pathlib import Path
import hashlib
import json
import platform
from importlib.metadata import version
import numpy as np
import pandas as pd
from rdkit import Chem
from autogluon.tabular import TabularPredictor
from .descriptors import calculate_features

ROOT = Path(__file__).resolve().parents[1]
PACKAGES = {"numpy": "2.3.5", "pandas": "2.3.3", "rdkit": "2026.3.1", "autogluon.tabular": "1.5.0",
            "scikit-learn": "1.7.1", "scipy": "1.16.3", "lightgbm": "4.6.0", "catboost": "1.2.10"}


def digest(path):
    h = hashlib.sha256()
    with Path(path).open("rb") as f:
        for block in iter(lambda: f.read(1048576), b""):
            h.update(block)
    return h.hexdigest()


def read_json(path):
    return json.loads(Path(path).read_text(encoding="utf-8"))


def write_json(path, data):
    Path(path).write_text(json.dumps(data, ensure_ascii=False, indent=2, allow_nan=False) + "\n", encoding="utf-8")


def check_runtime():
    if platform.python_version_tuple()[:2] != ("3", "13"):
        raise ValueError("Python 3.13 is required by the bundled models.")
    for package, expected in PACKAGES.items():
        if version(package) != expected:
            raise ValueError(f"{package}: expected {expected}, found {version(package)}")
    return {"python_version": platform.python_version(), "packages": {p: version(p) for p in PACKAGES}}


def output_dir(path):
    p = Path(path)
    if p.exists() and any(p.iterdir()):
        raise ValueError(f"Output directory must be empty: {p}")
    p.mkdir(parents=True, exist_ok=True)
    return p


def load_table(path, mode=None, sheet=None, require_rt=False):
    p = Path(path)
    if p.suffix.lower() == ".csv":
        # Check literal duplicate headers before pandas mangles their names.
        import csv
        with p.open(encoding="utf-8-sig", newline="") as f:
            headers = next(csv.reader(f), [])
        if len(headers) != len(set(c.strip().lower() for c in headers)):
            raise ValueError("Duplicate input column names.")
        frame = pd.read_csv(p, dtype=str, keep_default_na=False)
    elif p.suffix.lower() == ".xlsx":
        raw = pd.read_excel(p, sheet_name=sheet if sheet is not None else 0, header=None, dtype=str, keep_default_na=False)
        if raw.empty:
            raise ValueError("Empty input table.")
        headers = raw.iloc[0].tolist()
        if len(headers) != len(set(c.strip().lower() for c in headers)):
            raise ValueError("Duplicate input column names.")
        frame = raw.iloc[1:].copy().reset_index(drop=True)
        frame.columns = headers
    else:
        raise ValueError("Use a local UTF-8 CSV or XLSX file.")
    if frame.empty:
        raise ValueError("Empty input table.")
    aliases = {"smiles": ["smiles", "structure"], "model_type": ["model_type", "column", "chrom_system", "mode"],
               "experimental_rt": ["experimental_rt", "rt", "retention_time", "retention time", "experimental rt"],
               "name": ["name", "compound_name"], "inchikey": ["inchikey", "inchikeys", "inchi_key"]}
    rename = {}
    for canonical, names in aliases.items():
        matches = [c for c in frame if str(c).strip().lower() in names]
        if len(matches) > 1:
            raise ValueError(f"Ambiguous columns for {canonical}: {matches}")
        if matches:
            rename[matches[0]] = canonical
    frame = frame.rename(columns=rename)
    reserved = {"row_id", "parse_status", "warning_message", "predicted_rt", "delta_rt", "candidate", "split", "canonical_smiles"}
    if reserved & set(frame):
        raise ValueError(f"Reserved columns: {sorted(reserved & set(frame))}")
    if "smiles" not in frame:
        raise ValueError("Missing SMILES column.")
    if mode:
        if "model_type" in frame and not frame.model_type.str.strip().str.upper().eq(mode).all():
            raise ValueError("Input model_type conflicts with --model. Do not mix chromatography modes.")
        frame["model_type"] = mode
    if "model_type" not in frame:
        raise ValueError("Supply model_type or --model RP/HILIC.")
    frame["model_type"] = frame.model_type.str.strip().str.upper()
    if not frame.model_type.isin(["RP", "HILIC"]).all():
        raise ValueError("model_type must be RP or HILIC.")
    raw_rt = frame.get("experimental_rt", pd.Series("", index=frame.index)).astype(str).str.strip()
    numeric = pd.to_numeric(raw_rt.where(raw_rt.ne("")), errors="coerce")
    if (raw_rt.ne("") & (~np.isfinite(numeric) | numeric.lt(0))).any():
        raise ValueError("RT must be a finite nonnegative number or blank.")
    if require_rt and numeric.isna().any():
        raise ValueError("Training/comparison requires measured RT for every row.")
    frame["experimental_rt"] = numeric
    frame.insert(0, "row_id", np.arange(1, len(frame) + 1))
    return frame


def canonical(smiles):
    mol = Chem.MolFromSmiles(smiles) if isinstance(smiles, str) and smiles.strip() else None
    return Chem.MolToSmiles(mol, isomericSmiles=True) if mol is not None else None


def structure_hash(smiles):
    return hashlib.sha256(smiles.encode()).hexdigest()


def load_model(root, mode):
    root = Path(root)
    manifest = read_json(root / "model_manifest.json")
    if manifest["model_type"] != mode:
        raise ValueError(f"Model mode mismatch: {root}")
    trained = manifest["runtime_manifest"]
    if trained["python_version"].split(".")[:2] != ["3", "13"]:
        raise ValueError("Incompatible model Python version.")
    for p in ["rdkit", "numpy", "pandas", "autogluon.tabular", "scikit-learn"]:
        if trained["packages"].get(p) != PACKAGES[p]:
            raise ValueError(f"Incompatible model package: {p}")
    predictor = TabularPredictor.load(str(root / "autogluon"), verbosity=0)
    best = manifest.get("best_model", predictor.model_best)
    if best != predictor.model_best or best not in predictor.model_names(can_infer=True):
        raise ValueError("Best-model identity disagrees with the manifest or cannot infer.")
    return manifest, predictor, best


def model_features(frame, manifest):
    config = manifest["descriptor_config"]
    features, status, _ = calculate_features(frame, descriptor_names=config.get("names"), fingerprint_config=config.get("fingerprint"))
    selected = manifest["preprocessor"]["feature_columns"]
    if set(selected) - set(features):
        raise ValueError("Model descriptor contract cannot be calculated.")
    return features[selected], status


def infer(frame, model_root, mode, candidate=None):
    manifest, predictor, best = load_model(model_root, mode)
    features, status = model_features(frame, manifest)
    valid = status.index[status.parse_status.eq("ok")]
    values = pd.Series(np.nan, index=frame.index)
    if len(valid):
        predicted = np.asarray(predictor.predict(features.loc[valid], model=candidate or best), dtype=float)
        if not np.isfinite(predicted).all():
            raise ValueError("Nonfinite model predictions.")
        values.loc[valid] = predicted
    return values, status, manifest, best


def metrics(y, pred):
    y, pred = np.asarray(y, dtype=float), np.asarray(pred, dtype=float)
    error = y - pred
    denom = float(((y - y.mean()) ** 2).sum())
    return {"n": len(y), "mae": float(np.abs(error).mean()), "rmse": float(np.sqrt((error**2).mean())),
            "r2": float(1 - (error**2).sum()/denom) if len(y) >= 2 and denom > 0 else None}
