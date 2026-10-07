#!/bin/bash
# RTpred module 2: train a user retention time model (pyRetip / AutoGluon).
#
# Usage:
#   bash retip_train.1.0.sh input_file="..." output_dir="..." model="RP" [options]
#
# Example:
#   apptainer exec bx_retip_train.1.0.sif bash retip_train.1.0.sh \
#     input_file="/path/to/library.csv" \
#     output_dir="/path/to/output" \
#     model="RP" \
#     time_limit="1200" \
#     cpus="4"
#
# Arguments:
#   input_file            (required) - CSV or XLSX with SMILES and measured RT
#                                      (experimental_rt / rt / retention_time)
#   output_dir            (required) - Output directory. Results go to
#                                      output_dir/result, logs to output_dir/logs.
#   model                 (required) - RP or HILIC
#   sheet                 (optional) - XLSX sheet name. default: first sheet
#   rt_unit               (optional) - RT unit label (values are not converted).
#                                      default: model unit
#   time_limit            (optional) - AutoGluon fit budget in seconds. default: 1200
#   cpus                  (optional) - CPU cores for training. default: 2
#   algorithms            (optional) - Comma-separated subset of GBM,CAT,RF,XT,KNN.
#                                      default: GBM,CAT,RF,XT,KNN
#   test_size             (optional) - Reserved test fraction. default: 0.2
#   validation_size       (optional) - Validation fraction. default: 0.2
#   seed                  (optional) - Random seed. default: 42
#   max_missing_fraction  (optional) - Max missing descriptor fraction. default: 0.2
#   correlation_threshold (optional) - Descriptor correlation cutoff. default: 0.995
#   method_label          (optional) - User LC method identifier. default: user method
#
# Outputs (output_dir/result):
#   model/ (trained models and manifest; input for retip_compare),
#   reserved_test.csv (held-out compounds; default input for retip_compare),
#   validation_leaderboard.csv, split_assignments.csv, rejected_rows.csv,
#   training.png/.svg, report.html, manifest.json
#
# Runs inside bx_retip_train.1.0.sif. Nothing is deleted: output_dir/result
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
				input_file|output_dir|model|sheet|rt_unit|time_limit|cpus|algorithms|\
				test_size|validation_size|seed|max_missing_fraction|correlation_threshold|method_label) ;;
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
for required in input_file output_dir model; do
	if [ -z "${!required:-}" ]; then
		echo "Error: Required parameter '$required' is missing" >&2
		exit 1
	fi
done

if [ "$model" != "RP" ] && [ "$model" != "HILIC" ]; then
	echo "Error: model must be RP or HILIC: $model" >&2
	exit 1
fi

sheet="${sheet:-}"
rt_unit="${rt_unit:-model unit}"
time_limit="${time_limit:-1200}"
cpus="${cpus:-2}"
algorithms="${algorithms:-GBM,CAT,RF,XT,KNN}"
test_size="${test_size:-0.2}"
validation_size="${validation_size:-0.2}"
seed="${seed:-42}"
max_missing_fraction="${max_missing_fraction:-0.2}"
correlation_threshold="${correlation_threshold:-0.995}"
method_label="${method_label:-user method}"

IFS=',' read -r -a algorithm_list <<< "$algorithms"
for a in "${algorithm_list[@]}"; do
	case "$a" in
		GBM|CAT|RF|XT|KNN) ;;
		*)
			echo "Error: unknown algorithm '$a' (use GBM, CAT, RF, XT, KNN)" >&2
			exit 1
			;;
	esac
done

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

echo "############################## RTpred train"
echo "Log file: $log_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "parameters:"
echo "  input_file            = ${input_file}"
echo "  output_dir            = ${output_dir}"
echo "  model                 = ${model}"
echo "  sheet                 = ${sheet:-<first sheet>}"
echo "  rt_unit               = ${rt_unit}"
echo "  time_limit            = ${time_limit}"
echo "  cpus                  = ${cpus}"
echo "  algorithms            = ${algorithms}"
echo "  test_size             = ${test_size}"
echo "  validation_size       = ${validation_size}"
echo "  seed                  = ${seed}"
echo "  max_missing_fraction  = ${max_missing_fraction}"
echo "  correlation_threshold = ${correlation_threshold}"
echo "  method_label          = ${method_label}"
echo ""

if ! command -v python >/dev/null 2>&1; then
	echo "Error: python not found in PATH; run inside bx_retip_train.1.0.sif" >&2
	exit 1
fi

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------
cmd=(python -m mdcc.cli train --input "$input_file" --output "$result_dir"
	--model "$model" --rt-unit "$rt_unit" --time-limit "$time_limit" --cpus "$cpus"
	--algorithms "${algorithm_list[@]}" --test-size "$test_size"
	--validation-size "$validation_size" --seed "$seed"
	--max-missing-fraction "$max_missing_fraction"
	--correlation-threshold "$correlation_threshold" --method-label "$method_label")
[ -n "$sheet" ] && cmd+=(--sheet "$sheet")

echo "Command: ${cmd[*]}"
"${cmd[@]}"

echo ""
echo "Results: $result_dir"
echo "User model for retip_compare: $result_dir/model"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
