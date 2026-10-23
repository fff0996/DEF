from __future__ import annotations

from typing import Any

import numpy as np
import pandas as pd
from rdkit import Chem, DataStructs, RDLogger
from rdkit.Chem import Descriptors, rdMolDescriptors

RDLogger.DisableLog("rdApp.*")

DESCRIPTOR_FUNCTIONS = {name: func for name, func in Descriptors.descList}


def get_descriptor_names(requested: list[str] | None = None) -> list[str]:
    if requested:
        unknown = sorted(set(requested) - set(DESCRIPTOR_FUNCTIONS))
        if unknown:
            raise ValueError(f"Unknown RDKit descriptors requested: {unknown}")
        return list(requested)
    return list(DESCRIPTOR_FUNCTIONS.keys())


def _descriptor_value(func, mol) -> float:
    try:
        value = func(mol)
    except Exception:
        return np.nan
    if value is None:
        return np.nan
    try:
        numeric = float(value)
    except (TypeError, ValueError):
        return np.nan
    if np.isfinite(numeric):
        return numeric
    return np.nan


def calculate_features(
    frame: pd.DataFrame,
    smiles_column: str = "smiles",
    descriptor_names: list[str] | None = None,
    fingerprint_config: dict[str, Any] | None = None,
) -> tuple[pd.DataFrame, pd.DataFrame, dict[str, Any]]:
    descriptor_names = get_descriptor_names(descriptor_names)
    fingerprint_config = fingerprint_config or {}
    fp_enabled = bool(fingerprint_config.get("enabled", False))
    fp_radius = int(fingerprint_config.get("radius", 2))
    fp_bits = int(fingerprint_config.get("n_bits", 256))

    feature_rows: list[dict[str, Any]] = []
    parse_rows: list[dict[str, str]] = []
    invalid_count = 0

    for smiles in frame[smiles_column].tolist():
        if not isinstance(smiles, str) or not smiles.strip():
            invalid_count += 1
            feature_row = {name: np.nan for name in descriptor_names}
            if fp_enabled:
                feature_row.update({f"fp_{idx:04d}": np.nan for idx in range(fp_bits)})
            feature_rows.append(feature_row)
            parse_rows.append(
                {
                    "parse_status": "invalid_smiles",
                    "warning_message": "SMILES is missing or empty.",
                }
            )
            continue

        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            invalid_count += 1
            feature_row = {name: np.nan for name in descriptor_names}
            if fp_enabled:
                feature_row.update({f"fp_{idx:04d}": np.nan for idx in range(fp_bits)})
            feature_rows.append(feature_row)
            parse_rows.append(
                {
                    "parse_status": "invalid_smiles",
                    "warning_message": "RDKit failed to parse the SMILES string.",
                }
            )
            continue

        descriptor_values = {
            name: _descriptor_value(DESCRIPTOR_FUNCTIONS[name], mol)
            for name in descriptor_names
        }
        if fp_enabled:
            bit_vector = rdMolDescriptors.GetMorganFingerprintAsBitVect(
                mol,
                radius=fp_radius,
                nBits=fp_bits,
            )
            fp_array = np.zeros((fp_bits,), dtype=float)
            DataStructs.ConvertToNumpyArray(bit_vector, fp_array)
            descriptor_values.update(
                {f"fp_{idx:04d}": float(value) for idx, value in enumerate(fp_array)}
            )

        feature_rows.append(descriptor_values)
        parse_rows.append({"parse_status": "ok", "warning_message": ""})

    features = pd.DataFrame(feature_rows, index=frame.index)
    parse_info = pd.DataFrame(parse_rows, index=frame.index)
    summary = {
        "descriptor_count": len(descriptor_names),
        "fingerprint_enabled": fp_enabled,
        "fingerprint_bits": fp_bits if fp_enabled else 0,
        "invalid_smiles_rows": invalid_count,
        "feature_columns": list(features.columns),
    }
    return features, parse_info, summary

