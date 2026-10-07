#!/bin/bash
# RTpred module 3: compare the bundled default model with user-trained models
# on the same measured compounds.
#
# Usage:
#   bash retip_compare.1.0.sh user_model="..." output_dir="..." model="RP" [input_file="..."] [options]
#
# Examples:
#   After retip_train (uses its reserved_test.csv as the evaluation set):
#     apptainer exec bx_retip_compare.1.0.sif bash retip_compare.1.0.sh \
#       user_model="/path/to/train_output" \
#       output_dir="/path/to/output" \
#       model="RP"
#
#   With a separate evaluation table and two user models:
#     apptainer exec bx_retip_compare.1.0.sif bash retip_compare.1.0.sh \
#       input_file="/path/to/evaluation.csv" \
#       user_model="/path/to/train_A,/path/to/train_B" \
#       output_dir="/path/to/output" \
#       model="RP"
#
# Arguments:
#   user_model (required) - Comma-separated retip_train output directories
#                           (output_dir, output_dir/result, or result/model)
#   output_dir (required) - Output directory. Results go to output_dir/result
#                           and logs to output_dir/logs.
#   model      (required) - RP or HILIC (must match the user models)
#   input_file (optional) - CSV or XLSX with SMILES and measured RT. default:
#                           reserved_test.csv of the first user_model
#   sheet      (optional) - XLSX sheet name. default: first sheet
#   rt_unit    (optional) - RT unit label for plots. default: model unit
#   scope      (optional) - all (every user-model candidate) or best. default: all
#   title      (optional) - Report title. default: Default and user model comparison
#
# Outputs (output_dir/result):
#   comparison.csv, predictions_long.csv, comparison.png/.svg, report.html,
#   manifest.json
#
# Runs inside bx_retip_compare.1.0.sif. Nothing is deleted: output_dir/result
# must be new or empty.

set -euo pipefail

# ------------------------------------------------------------
# Parse key=value arguments
# ------------------------------------------------------------
for arg in "$@"
do
	case $arg in
		*=*)
			IFS='=' read -r key value <<< "$arg"

			value="${value%\"}"
			value="${value#\"}"
			value="${value%\'}"
			value="${value#\'}"

			if [[ ! $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
				echo "Invalid key: $key" >&2
				exit 1
			fi

			case "$key" in
				input_file|output_dir|model|user_model|sheet|rt_unit|scope|title) ;;
				*)
					echo "Unknown parameter: $key" >&2
					exit 1
					;;
			esac

			declare "$key=$value"
			;;
		*)
			echo "Invalid argument format: $arg (must be key=value format)" >&2
			exit 1
			;;
	esac
done

# ------------------------------------------------------------
# Required and optional parameters
# ------------------------------------------------------------
for required in user_model output_dir model; do
	if [ -z "${!required:-}" ]; then
		echo "Error: Required parameter '$required' is missing" >&2
		exit 1
	fi
done

if [ "$model" != "RP" ] && [ "$model" != "HILIC" ]; then
	echo "Error: model must be RP or HILIC: $model" >&2
	exit 1
fi

input_file="${input_file:-}"
sheet="${sheet:-}"
rt_unit="${rt_unit:-model unit}"
scope="${scope:-all}"
title="${title:-Default and user model comparison}"

if [ "$scope" != "all" ] && [ "$scope" != "best" ]; then
	echo "Error: scope must be all or best: $scope" >&2
	exit 1
fi

# Accept a retip_train output_dir, its result/ directory, or result/model.
model_dirs=()
first_result=""
IFS=',' read -r -a user_model_list <<< "$user_model"
for m in "${user_model_list[@]}"; do
	if [ -f "$m/result/model/model_manifest.json" ]; then
		model_dirs+=("$m/result/model")
		[ -n "$first_result" ] || first_result="$m/result"
	elif [ -f "$m/model/model_manifest.json" ]; then
		model_dirs+=("$m/model")
		[ -n "$first_result" ] || first_result="$m"
	elif [ -f "$m/model_manifest.json" ]; then
		model_dirs+=("$m")
		[ -n "$first_result" ] || first_result="$(dirname "$m")"
	else
		echo "Error: no retip_train model found in: $m" >&2
		exit 1
	fi
done

if [ -z "$input_file" ]; then
	input_file="$first_result/reserved_test.csv"
fi

if [ ! -f "$input_file" ]; then
	echo "Error: input_file not found: $input_file" >&2
	exit 1
fi

result_dir="${output_dir}/result"
if [ -d "$result_dir" ] && [ -n "$(ls -A "$result_dir")" ]; then
	echo "Error: $result_dir is not empty; use a new output_dir" >&2
	exit 1
fi

# ------------------------------------------------------------
# Logging
# ------------------------------------------------------------
logs_dir="${output_dir}/logs"
mkdir -p "$logs_dir"
log_file="${logs_dir}/$(date '+%Y%m%d_%H%M%S')_$$.log"

exec > >(tee -a "$log_file") 2>&1

echo "############################## RTpred compare"
echo "Log file: $log_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "parameters:"
echo "  input_file = ${input_file}"
echo "  user_model = ${model_dirs[*]}"
echo "  output_dir = ${output_dir}"
echo "  model      = ${model}"
echo "  sheet      = ${sheet:-<first sheet>}"
echo "  rt_unit    = ${rt_unit}"
echo "  scope      = ${scope}"
echo "  title      = ${title}"
echo ""

if ! command -v python >/dev/null 2>&1; then
	echo "Error: python not found in PATH; run inside bx_retip_compare.1.0.sif" >&2
	exit 1
fi

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------
cmd=(python -m mdcc.cli compare --input "$input_file" --output "$result_dir"
	--model "$model" --rt-unit "$rt_unit" --scope "$scope" --title "$title")
for d in "${model_dirs[@]}"; do
	cmd+=(--user-model "$d")
done
[ -n "$sheet" ] && cmd+=(--sheet "$sheet")

echo "Command: ${cmd[*]}"
"${cmd[@]}"

echo ""
echo "Results: $result_dir"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
