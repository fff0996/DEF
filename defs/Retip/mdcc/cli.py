"""Independent offline applications: default prediction, user training, comparison."""
import argparse
import html
from pathlib import Path
from datetime import datetime, timezone
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

from .core import (ROOT, check_runtime, output_dir, load_table, infer, write_json, digest,
                   canonical, structure_hash, load_model, model_features, metrics)


def save_plot(fig, out, name):
    fig.savefig(out / f"{name}.png", dpi=160, bbox_inches="tight")
    fig.savefig(out / f"{name}.svg", bbox_inches="tight")
    plt.close(fig)


def report_html(out, title, text, table, image, links):
    anchors = " · ".join(f'<a href="{html.escape(p, quote=True)}">{html.escape(p)}</a>' for p in links)
    (out / "report.html").write_text('<!doctype html><html lang="ko"><meta charset="utf-8">'
        f'<title>{html.escape(title)}</title><style>body{{font-family:sans-serif;max-width:1150px;margin:35px auto}}'
        'img{max-width:100%}td,th{padding:8px;border:1px solid #ddd}table{border-collapse:collapse}</style>'
        f'<h1>{html.escape(title)}</h1><p>{html.escape(text)}</p><img src="{image}" alt="Results">'
        f'<p>{anchors}</p>{table.to_html(index=False, escape=True)}</html>', encoding="utf-8")


def predict(args):
    env = check_runtime()
    frame = load_table(args.input, args.model, args.sheet)
    frame["predicted_rt"] = np.nan
    frame["parse_status"] = "pending"
    frame["warning_message"] = ""
    frame["best_model"] = ""
    model_records = {}
    for mode in frame.model_type.unique():
        rows = frame.index[frame.model_type.eq(mode)]
        root = ROOT / "models" / f"{mode.lower()}_model"
        values, status, manifest, best = infer(frame.loc[rows], root, mode)
        frame.loc[rows, "predicted_rt"] = values
        frame.loc[rows, ["parse_status", "warning_message"]] = status
        frame.loc[rows, "best_model"] = best
        model_records[mode] = {"best_model": best, "manifest_sha256": digest(root / "model_manifest.json")}
    frame["delta_rt"] = frame.experimental_rt - frame.predicted_rt
    out = output_dir(args.output)
    frame.to_csv(out / "predictions.csv", index=False)
    fig, axes = plt.subplots(1, 2, figsize=(11, 4), constrained_layout=True)
    counts = frame.parse_status.value_counts()
    axes[0].bar(counts.index, counts.values, color="#197c91")
    axes[0].set(title="Prediction coverage", ylabel="Compounds")
    for mode in frame.model_type.unique():
        values = frame.loc[frame.model_type.eq(mode), "predicted_rt"].dropna()
        if len(values):
            axes[1].hist(values, alpha=.6, bins=min(15, len(values)), label=mode)
    axes[1].set(title="Default best-model RT", xlabel="RT (model unit)", ylabel="Compounds")
    if axes[1].get_legend_handles_labels()[0]:
        axes[1].legend()
    save_plot(fig, out, "prediction")
    report_html(out, "기본 best model 예측", "로컬 내장 모델로 계산했습니다. RT 단위는 원래 모델 단위입니다. 처음 100행을 표시합니다.",
                frame.head(100), "prediction.png", ["predictions.csv", "manifest.json"])
    write_json(out / "manifest.json", {"module": "predict", "schema_version": 2, "runtime": env,
        "models": model_records, "input_sha256": digest(args.input), "rows": len(frame), "network_required": False})


def split_groups(frame, test_size, validation_size, seed):
    from sklearn.model_selection import GroupShuffleSplit
    if not (0 < test_size < .5 and 0 < validation_size < .5 and test_size + validation_size < .8):
        raise ValueError("test/validation sizes must be in (0, .5) and sum to less than .8.")
    splitter = GroupShuffleSplit(n_splits=1, test_size=test_size, random_state=seed)
    development, test = next(splitter.split(frame, groups=frame.canonical_smiles))
    dev = frame.iloc[development]
    splitter = GroupShuffleSplit(n_splits=1, test_size=validation_size/(1-test_size), random_state=seed+1)
    train, validation = next(splitter.split(dev, groups=dev.canonical_smiles))
    return dev.iloc[train].index, dev.iloc[validation].index, frame.iloc[test].index


def train(args):
    from .descriptors import calculate_features
    from .preprocess import FeaturePreprocessor
    from .pyretip import Dataset, AutoGluonTrainer
    env = check_runtime()
    if args.time_limit <= 0 or args.cpus <= 0:
        raise ValueError("time-limit and cpus must be positive.")
    if not 0 <= args.max_missing_fraction < 1 or not 0 < args.correlation_threshold <= 1:
        raise ValueError("Invalid feature filtering thresholds.")
    frame = load_table(args.input, args.model, args.sheet, require_rt=True)
    frame["canonical_smiles"] = frame.smiles.map(canonical)
    rejected = frame.loc[frame.canonical_smiles.isna()].copy()
    usable = frame.dropna(subset=["canonical_smiles"]).drop_duplicates(["canonical_smiles", "experimental_rt"]).copy()
    if len(usable) < 25 or usable.canonical_smiles.nunique() < 15:
        raise ValueError("Training requires at least 25 usable rows and 15 distinct canonical structures.")
    train_idx, val_idx, test_idx = split_groups(usable, args.test_size, args.validation_size, args.seed)
    if min(len(train_idx), len(val_idx), len(test_idx)) < 2:
        raise ValueError("Each split must contain at least two compounds.")
    if usable.loc[train_idx, "experimental_rt"].nunique() < 2:
        raise ValueError("Training RT must vary.")
    features, _, summary = calculate_features(usable)
    pre = FeaturePreprocessor(max_missing_fraction=args.max_missing_fraction, correlation_threshold=args.correlation_threshold)
    pre.fit(features.loc[train_idx])
    if not pre.feature_columns:
        raise ValueError("No usable features remain in training split.")
    transformed = pre.transform(features)
    data = transformed.copy()
    data["rt"] = usable.experimental_rt
    out = output_dir(args.output)
    model_root = out / "model"
    model_root.mkdir()
    trainer = AutoGluonTrainer(Dataset(data.loc[train_idx], data.loc[val_idx]), model_root / "autogluon",
                              time_limit=args.time_limit, cpus=args.cpus, algorithms=args.algorithms, seed=args.seed).train()
    predictor = trainer.predictor
    best = predictor.model_best
    lb = predictor.leaderboard(silent=True)
    lb.to_csv(out / "validation_leaderboard.csv", index=False)
    lb.to_csv(model_root / "leaderboard.csv", index=False)
    usable["split"] = ""
    for name, indices in [("train", train_idx), ("validation", val_idx), ("reserved_test", test_idx)]:
        usable.loc[indices, "split"] = name
    usable.to_csv(out / "split_assignments.csv", index=False)
    rejected.to_csv(out / "rejected_rows.csv", index=False)
    # Portable raw table: no internal/reserved columns, suitable as module 3 input.
    usable.loc[test_idx].drop(columns=["row_id", "canonical_smiles", "split"]).to_csv(out / "reserved_test.csv", index=False)
    used_hashes = sorted({structure_hash(s) for s in usable.loc[list(train_idx)+list(val_idx), "canonical_smiles"]})
    manifest = {"artifact_kind": "mdcc_user_model_v2", "model_type": args.model, "best_model": best,
        "runtime_manifest": env, "descriptor_config": {"names": summary["feature_columns"], "fingerprint": {"enabled": False}},
        "preprocessor": pre.to_dict(), "rt_unit": args.rt_unit, "method_label": args.method_label,
        "train_validation_structure_hashes": used_hashes, "source_sha256": digest(args.input),
        "trained_at": datetime.now(timezone.utc).isoformat(),
        "split": {"strategy": "canonical_isomeric_smiles_group", "train_rows": len(train_idx), "validation_rows": len(val_idx), "reserved_test_rows": len(test_idx), "seed": args.seed},
        "training_config": {"algorithms": args.algorithms, "time_limit_seconds": args.time_limit, "num_cpus": args.cpus,
                            "num_gpus": 0, "num_bag_folds": 0, "refit_full": False, "best_selection": "validation RMSE"},
        "implementation": "local pyRetip AutoGluonTrainer adaptation + modern RDKit notebook workflow"}
    write_json(model_root / "model_manifest.json", manifest)
    (model_root / "selected_features.txt").write_text("\n".join(pre.feature_columns)+"\n")
    fig, axes = plt.subplots(1, 2, figsize=(12, 4), constrained_layout=True)
    counts = usable.split.value_counts()
    axes[0].bar(counts.index, counts.values, color="#197c91")
    axes[0].set(title="Structure-group split", ylabel="Rows")
    ranks = lb.loc[lb.can_infer].sort_values("score_val", ascending=False)
    axes[1].barh(ranks.model, -ranks.score_val, color="#d78437")
    axes[1].invert_yaxis()
    axes[1].set(title="Validation model selection", xlabel=f"Validation RMSE ({args.rt_unit})")
    if "data_origin" in frame and frame.data_origin.astype(str).str.contains("SYNTHETIC").any():
        fig.suptitle("SYNTHETIC RT demonstration - not measured performance")
    save_plot(fig, out, "training")
    report_html(out, "사용자 모델 학습", f"Best: {best}. 검증 RMSE로 선택했습니다. reserved_test는 학습·모델 선택에 사용하지 않았습니다.",
                lb, "training.png", ["validation_leaderboard.csv", "split_assignments.csv", "reserved_test.csv", "model/model_manifest.json"])
    write_json(out / "manifest.json", {"module": "train", "schema_version": 2, "best_model": best,
        "model_directory": "model", "runtime": env, "source_sha256": digest(args.input), "rejected_rows": len(rejected),
        "duplicate_rows_removed": len(frame)-len(rejected)-len(usable), "network_required": False})


def compare(args):
    env = check_runtime()
    frame = load_table(args.input, args.model, args.sheet, require_rt=True)
    structures = frame.smiles.map(canonical)
    valid = frame.index[structures.notna()]
    if len(valid) < 2:
        raise ValueError("Comparison requires at least two valid structures with measured RT.")
    evaluation_hashes = {structure_hash(s) for s in structures.dropna()}
    roots = [("default", ROOT / "models" / f"{args.model.lower()}_model")]
    supplied = [Path(p).resolve() for p in args.user_model]
    if len(supplied) != len(set(supplied)):
        raise ValueError("Duplicate user model directories.")
    roots.extend((f"user_{i+1}", p) for i, p in enumerate(supplied))
    records, predictions, provenance = [], [], {}
    fig, axes = plt.subplots(1, 2, figsize=(13, 5), constrained_layout=True)
    for label, root in roots:
        manifest, predictor, best = load_model(root, args.model)
        if label != "default":
            if manifest.get("artifact_kind") != "mdcc_user_model_v2":
                raise ValueError("User models must be generated by MDCC train with split provenance.")
            if manifest["rt_unit"] != args.rt_unit:
                raise ValueError("User model and evaluation RT unit do not match; no automatic conversion.")
            overlap = evaluation_hashes & set(manifest["train_validation_structure_hashes"])
            if overlap:
                raise ValueError(f"Evaluation leakage: {label} has {len(overlap)} structures used in training/validation.")
        features, status = model_features(frame, manifest)
        if not status.loc[valid, "parse_status"].eq("ok").all():
            raise ValueError("Models do not have the same valid evaluation rows.")
        candidates = predictor.model_names(can_infer=True) if label != "default" and args.scope == "all" else [best]
        provenance[label] = {"manifest_sha256": digest(root / "model_manifest.json"), "best_model": best,
                             "evaluated_models": candidates, "model_directory": str(root),
                             "training_overlap": "unknown" if label == "default" else "none",
                             "method_label": manifest.get("method_label", "unknown")}
        for candidate in candidates:
            values = np.asarray(predictor.predict(features.loc[valid], model=candidate), dtype=float)
            if not np.isfinite(values).all():
                raise ValueError(f"Nonfinite prediction: {label}/{candidate}")
            name = label + "/" + candidate
            result = frame.copy()
            result["candidate"] = name
            result["predicted_rt"] = np.nan
            result.loc[valid, "predicted_rt"] = values
            result[["parse_status", "warning_message"]] = status
            result["delta_rt"] = result.experimental_rt-result.predicted_rt
            predictions.append(result)
            row = {"candidate": name, "source": label, "selected_best": candidate == best, **metrics(frame.loc[valid, "experimental_rt"], values)}
            records.append(row)
            if candidate == best:
                axes[1].scatter(frame.loc[valid, "experimental_rt"], values, s=18, alpha=.65, label=label+" best")
    table = pd.DataFrame(records).sort_values(["rmse", "mae", "candidate"]).reset_index(drop=True)
    table.insert(0, "rank_on_this_dataset", np.arange(1, len(table)+1))
    out = output_dir(args.output)
    table.to_csv(out / "comparison.csv", index=False)
    pd.concat(predictions, ignore_index=True).to_csv(out / "predictions_long.csv", index=False)
    axes[0].barh(table.candidate, table.rmse, color="#197c91")
    axes[0].invert_yaxis()
    axes[0].set(title="All candidates: same evaluation rows", xlabel=f"RMSE ({args.rt_unit})")
    bounds = [*axes[1].get_xlim(), *axes[1].get_ylim()]
    axes[1].plot([min(bounds), max(bounds)], [min(bounds), max(bounds)], "--", color="gray")
    axes[1].set(title="Selected best models", xlabel=f"Measured RT ({args.rt_unit})", ylabel=f"Predicted RT ({args.rt_unit})")
    axes[1].legend()
    fig.suptitle(args.title)
    save_plot(fig, out, "comparison")
    note = ("동일 평가 행에서 비교했습니다. 사용자 모델의 학습·검증 구조 중복은 검사했습니다. "
            "기본 모델의 학습 구조 목록·RT 단위·상세 LC 조건은 제공 자료만으로 확정할 수 없어 독립성 및 조건 일치를 보증하지 않습니다. "
            "이 순위로 모델을 선택했다면 새 독립 데이터로 재검증하십시오. 기본 모델은 자동 교체하지 않습니다.")
    report_html(out, args.title, note, table, "comparison.png", ["comparison.csv", "predictions_long.csv", "manifest.json"])
    write_json(out / "manifest.json", {"module": "compare", "schema_version": 2, "runtime": env,
        "evaluation_sha256": digest(args.input), "evaluated_rows_per_model": len(valid), "excluded_invalid_rows": len(frame)-len(valid),
        "rt_unit_label": args.rt_unit, "models": provenance, "default_unit_and_method_verified": False,
        "default_training_overlap": "unknown", "network_required": False})


def parser():
    p = argparse.ArgumentParser(description="RTpred: predict / train / compare")
    sub = p.add_subparsers(dest="module", required=True)
    for module, function in [("predict", predict), ("train", train), ("compare", compare)]:
        s = sub.add_parser(module)
        s.add_argument("--input", required=True, help="Local CSV/XLSX compound table")
        s.add_argument("--output", required=True, help="New or empty result directory")
        s.add_argument("--model", choices=["RP", "HILIC"], required=module != "predict", help="Chromatography mode; must agree with input")
        s.add_argument("--sheet", help="XLSX sheet name; default first sheet")
        if module in ("train", "compare"):
            s.add_argument("--rt-unit", default="model unit", help="RT unit label; input values are never converted")
        if module == "train":
            s.add_argument("--time-limit", type=int, default=1200, help="AutoGluon fit budget in seconds")
            s.add_argument("--cpus", type=int, default=2)
            s.add_argument("--algorithms", nargs="+", choices=["GBM", "CAT", "RF", "XT", "KNN"], default=["GBM", "CAT", "RF", "XT", "KNN"])
            s.add_argument("--test-size", type=float, default=.2)
            s.add_argument("--validation-size", type=float, default=.2)
            s.add_argument("--seed", type=int, default=42)
            s.add_argument("--max-missing-fraction", type=float, default=.2)
            s.add_argument("--correlation-threshold", type=float, default=.995)
            s.add_argument("--method-label", default="user method", help="User LC method identifier")
        if module == "compare":
            s.add_argument("--user-model", action="append", required=True, help="MDCC train output/model directory; repeat to compare runs")
            s.add_argument("--scope", choices=["all", "best"], default="all", help="User-model candidates; default model always uses its saved best")
            s.add_argument("--title", default="Default and user model comparison")
        s.set_defaults(fn=function)
    return p


def main():
    args = parser().parse_args()
    try:
        args.fn(args)
    except (ValueError, KeyError, FileNotFoundError, RuntimeError) as exc:
        raise SystemExit(f"ERROR: {exc}") from exc


if __name__ == "__main__":
    main()
