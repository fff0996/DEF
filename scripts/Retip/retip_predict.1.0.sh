#!/bin/bash
# RTpred module 1: retention time prediction with the bundled default models.
#
# Usage:
#   bash retip_predict.1.0.sh input_file="..." output_dir="..." [model="RP"] [sheet="..."]
#
# Example:
#   apptainer exec bx_retip_predict.1.0.sif bash retip_predict.1.0.sh \
#     input_file="/path/to/compounds.csv" \
#     output_dir="/path/to/output" \
#     model="RP"
#
# Arguments:
#   input_file (required) - CSV or XLSX compound table with a SMILES column
#                           (smiles or structure). experimental_rt is optional.
#   output_dir (required) - Output directory. Results go to output_dir/result
#                           and logs to output_dir/logs.
#   model      (optional) - RP or HILIC. If omitted, the input must have a
#                           model_type column (RP or HILIC per row).
#   sheet      (optional) - XLSX sheet name. default: first sheet
#
# Outputs (output_dir/result):
#   predictions.csv, prediction.png/.svg, report.html, manifest.json
#
# Runs inside bx_retip_predict.1.0.sif (mdcc and the default models are in
# the image). Nothing is deleted: output_dir/result must be new or empty.

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
				input_file|output_dir|model|sheet) ;;
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
if [ -z "${input_file:-}" ]; then
	echo "Error: Required parameter 'input_file' is missing" >&2
	exit 1
fi

if [ -z "${output_dir:-}" ]; then
	echo "Error: Required parameter 'output_dir' is missing" >&2
	exit 1
fi

model="${model:-}"
sheet="${sheet:-}"

if [ -n "$model" ] && [ "$model" != "RP" ] && [ "$model" != "HILIC" ]; then
	echo "Error: model must be RP or HILIC: $model" >&2
	exit 1
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

echo "############################## RTpred predict"
echo "Log file: $log_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "parameters:"
echo "  input_file = ${input_file}"
echo "  output_dir = ${output_dir}"
echo "  model      = ${model:-<from input model_type>}"
echo "  sheet      = ${sheet:-<first sheet>}"
echo ""

if ! command -v python >/dev/null 2>&1; then
	echo "Error: python not found in PATH; run inside bx_retip_predict.1.0.sif" >&2
	exit 1
fi

# ------------------------------------------------------------
# Run
# ------------------------------------------------------------
cmd=(python -m mdcc.cli predict --input "$input_file" --output "$result_dir")
[ -n "$model" ] && cmd+=(--model "$model")
[ -n "$sheet" ] && cmd+=(--sheet "$sheet")

echo "Command: ${cmd[*]}"
"${cmd[@]}"

echo ""
echo "Results: $result_dir"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"
