from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np
import pandas as pd


@dataclass
class FeaturePreprocessor:
    max_missing_fraction: float = 0.2
    correlation_threshold: float | None = None
    feature_columns: list[str] = field(default_factory=list)
    dropped_missing_columns: list[str] = field(default_factory=list)
    dropped_constant_columns: list[str] = field(default_factory=list)
    dropped_correlated_columns: list[str] = field(default_factory=list)

    def fit(self, features: pd.DataFrame) -> "FeaturePreprocessor":
        working = features.copy()

        missing_fraction = working.isna().mean()
        keep_missing = missing_fraction[missing_fraction <= self.max_missing_fraction].index.tolist()
        self.dropped_missing_columns = [
            column for column in working.columns if column not in keep_missing
        ]
        working = working.loc[:, keep_missing]

        nunique = working.nunique(dropna=False)
        keep_constant = nunique[nunique > 1].index.tolist()
        self.dropped_constant_columns = [
            column for column in working.columns if column not in keep_constant
        ]
        working = working.loc[:, keep_constant]

        self.dropped_correlated_columns = []
        if self.correlation_threshold is not None and not working.empty:
            filled = working.fillna(working.median(numeric_only=True))
            corr = filled.corr().abs()
            upper = corr.where(np.triu(np.ones(corr.shape), k=1).astype(bool))
            self.dropped_correlated_columns = [
                column
                for column in upper.columns
                if (upper[column] > self.correlation_threshold).any()
            ]
            working = working.drop(columns=self.dropped_correlated_columns, errors="ignore")

        self.feature_columns = list(working.columns)
        return self

    def transform(self, features: pd.DataFrame) -> pd.DataFrame:
        if not self.feature_columns:
            raise RuntimeError("FeaturePreprocessor has not been fitted.")
        transformed = features.copy()
        for column in self.feature_columns:
            if column not in transformed.columns:
                transformed[column] = np.nan
        return transformed.loc[:, self.feature_columns]

    def to_dict(self) -> dict[str, Any]:
        return {
            "max_missing_fraction": self.max_missing_fraction,
            "correlation_threshold": self.correlation_threshold,
            "feature_columns": self.feature_columns,
            "dropped_missing_columns": self.dropped_missing_columns,
            "dropped_constant_columns": self.dropped_constant_columns,
            "dropped_correlated_columns": self.dropped_correlated_columns,
        }

    @classmethod
    def from_dict(cls, payload: dict[str, Any]) -> "FeaturePreprocessor":
        instance = cls(
            max_missing_fraction=payload["max_missing_fraction"],
            correlation_threshold=payload.get("correlation_threshold"),
        )
        instance.feature_columns = list(payload["feature_columns"])
        instance.dropped_missing_columns = list(payload.get("dropped_missing_columns", []))
        instance.dropped_constant_columns = list(payload.get("dropped_constant_columns", []))
        instance.dropped_correlated_columns = list(
            payload.get("dropped_correlated_columns", [])
        )
        return instance


def prepare_training_dataset(
    frame: pd.DataFrame,
    features: pd.DataFrame,
    parse_info: pd.DataFrame,
    target_column: str,
    duplicate_subset: list[str],
    preprocessor: FeaturePreprocessor,
) -> tuple[pd.DataFrame, pd.DataFrame, dict[str, Any]]:
    working = frame.copy()
    working[target_column] = pd.to_numeric(working[target_column], errors="coerce")
    working = pd.concat([working, parse_info, features], axis=1)

    initial_rows = len(working)
    invalid_smiles_rows = int((working["parse_status"] != "ok").sum())
    missing_target_rows = int(working[target_column].isna().sum())

    usable = working.loc[
        (working["parse_status"] == "ok") & working[target_column].notna()
    ].copy()
    duplicate_columns = [column for column in duplicate_subset if column in usable.columns]
    rows_before_dedup = len(usable)
    if duplicate_columns:
        usable = usable.drop_duplicates(subset=duplicate_columns, keep="first")
    duplicate_rows_removed = rows_before_dedup - len(usable)

    feature_only = features.loc[usable.index]
    preprocessor.fit(feature_only)
    transformed_features = preprocessor.transform(feature_only)
    model_frame = pd.concat([transformed_features, usable[[target_column]]], axis=1)

    summary = {
        "initial_rows": initial_rows,
        "invalid_smiles_rows": invalid_smiles_rows,
        "missing_target_rows": missing_target_rows,
        "duplicate_rows_removed": duplicate_rows_removed,
        "training_rows_after_cleaning": int(len(model_frame)),
        "retained_feature_count": int(len(preprocessor.feature_columns)),
    }
    return model_frame, usable, summary

