#!/bin/bash
# Version 1.1 (changes from MACS3_callpeak_ATAC.1.0.sh):
#   stdout and stderr are kept apart: progress goes to stdout and
#   logs/<stamp>.log, errors and warnings to stderr and
#   logs/<stamp>.error.log. Per-sample MACS3 output is split the same way
#   (<sample>_macs3.log for stdout, <sample>_macs3.stderr.log for stderr;
#   MACS3 writes its progress messages to stderr).
#   If some samples fail but at least one succeeds, the run ends with a
#   warning and exit code 0 (1.0 exited 1); failed samples are listed.
#   The run stops if output_dir is input_dir or one of its parents.
#
# Usage:
#   ./MACS3_callpeak_ATAC.1.1.sh input_dir="..." output_dir="..." genome_size="..." [peak_type="atac"] [alignment_suffix=".shifted.bam"]
#
# Examples:
#   General ATAC-seq:
#     ./MACS3_callpeak_ATAC.1.1.sh \
#       input_dir="/path/to/bam" \
#       output_dir="/path/to/output" \
#       genome_size="hs"
#
#   Broad peak mode:
#     ./MACS3_callpeak_ATAC.1.1.sh \
#       input_dir="/path/to/bam" \
#       output_dir="/path/to/output" \
#       genome_size="hs" \
#       peak_type="broad"
#
#   NBIS tutorial-like broad output:
#     ./MACS3_callpeak_ATAC.1.1.sh \
#       input_dir="/path/to/bam" \
#       output_dir="/path/to/output" \
#       genome_size="195154279" \
#       peak_type="broad" \
#       alignment_suffix=".filt.chr1.bam"
#
# Arguments:
#   input_dir        (required) - Directory containing treatment BAM, or CONTROL_*.bam + treatment BAM pair
#   output_dir       (required) - Output directory
#   genome_size      (required) - MACS3 genome size, e.g. hs, mm, ce, dm, or numeric size
#   peak_type        (optional) - atac, narrow, broad, tf. default: atac
#   alignment_suffix (optional) - BAM suffix to search. default: .shifted.bam
#   qvalue           (optional) - q-value cutoff. default: 0.05
#   broad_cutoff     (optional) - broad cutoff for broad peak calling. default: 0.1

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

			case "$key" in IFS|UID|EUID|PPID|BASHOPTS|BASHPID)
				echo "Refusing to set protected var: $key" >&2
				exit 1
				;;
			esac

			declare "$key=$value"
			;;
		*)
			echo "Invalid argument format: $arg (must be key=value format)"
			exit 1
			;;
	esac
done

# ------------------------------------------------------------
# Required parameters
# ------------------------------------------------------------
if [ -z "${input_dir:-}" ]; then
	echo "Error: Required parameter 'input_dir' is missing" >&2
	exit 1
fi

if [ -z "${output_dir:-}" ]; then
	echo "Error: Required parameter 'output_dir' is missing" >&2
	exit 1
fi

if [ -z "${genome_size:-}" ]; then
	echo "Error: Required parameter 'genome_size' is missing" >&2
	exit 1
fi

# ------------------------------------------------------------
# Optional parameters
# ------------------------------------------------------------
peak_type="${peak_type:-atac}"
alignment_suffix="${alignment_suffix:-.shifted.bam}"
qvalue="${qvalue:-0.05}"
broad_cutoff="${broad_cutoff:-0.1}"

# ------------------------------------------------------------
# output_dir is cleaned below, so it must not be or contain an input.
# ------------------------------------------------------------
output_real="$(realpath -m -- "$output_dir")"
for input_path in "$input_dir"; do
	input_real="$(realpath -m -- "$input_path")"
	case "$input_real/" in
		"$output_real"/*)
			echo "Error: input $input_path is inside output_dir $output_dir, which is cleaned on each run" >&2
			exit 1
			;;
	esac
done

# ------------------------------------------------------------
# Clean output directory first except logs/
# ------------------------------------------------------------
if [ -d "$output_dir" ] && [ "$output_dir" != "/" ]; then
	find "$output_dir" -mindepth 1 -maxdepth 1 ! -name "logs" -print0 | xargs -0 rm -rf 2>/dev/null || true
fi

mkdir -p "$output_dir"

logs_dir="${output_dir}/logs"
mkdir -p "$logs_dir"
timestamp="$(date '+%Y%m%d_%H%M%S')_$$"
log_file="${logs_dir}/${timestamp}.log"
err_file="${logs_dir}/${timestamp}.error.log"

# stdout / stderr separate
exec > >(tee -a "$log_file") 2> >(tee -a "$err_file" >&2)

echo "############################## MACS3 Peak Calling"
echo "Log file: $log_file"
echo "Error log file: $err_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "parameters:"
echo "  input_dir        = ${input_dir}"
echo "  output_dir       = ${output_dir}"
echo "  genome_size      = ${genome_size}"
echo "  peak_type        = ${peak_type}"
echo "  alignment_suffix = ${alignment_suffix}"
echo "  qvalue           = ${qvalue}"
echo "  broad_cutoff     = ${broad_cutoff}"
echo ""

# ------------------------------------------------------------
# Input validation
# ------------------------------------------------------------
if [ ! -d "$input_dir" ]; then
	echo "Error: input_dir not found: $input_dir" >&2
	exit 1
fi

if ! command -v macs3 >/dev/null 2>&1; then
	echo "Error: macs3 not found in PATH" >&2
	echo "Check your MACS3 container/image setting." >&2
	echo "Example:" >&2
	echo "  apptainer exec bx_macs3_callpeak_atac.1.0.sif macs3 --version" >&2
	exit 1
fi

if ! command -v samtools >/dev/null 2>&1; then
	echo "Warning: samtools not found in PATH. BAM index check will be skipped." >&2
fi

case "$peak_type" in
	atac|narrow|broad|tf)
		;;
	*)
		echo "Error: peak_type must be one of: atac, narrow, broad, tf" >&2
		exit 1
		;;
esac

echo "MACS3 version:"
macs3 --version
echo ""

# ------------------------------------------------------------
# Check input data shape before running
# ------------------------------------------------------------
echo "checking input data shape..."
echo ""

echo "[all BAM files]"
find "$input_dir" -type f -name "*.bam" | sort | sed 's/^/  /' || true
echo ""

total_bam_count="$(find "$input_dir" -type f -name "*.bam" | wc -l)"
echo "[BAM count]"
echo "  total BAM files = ${total_bam_count}"
echo ""

if [ "$total_bam_count" -eq 0 ]; then
	echo "Error: No BAM files found in input_dir: $input_dir" >&2
	exit 1
fi

# ------------------------------------------------------------
# MACS3 parameter preset
# ------------------------------------------------------------
get_macs3_params() {
	local peak_type="$1"

	case "$peak_type" in
		atac)
			# General ATAC-seq paired-end mode
			echo "-f BAMPE --keep-dup all --nomodel -q ${qvalue}"
			;;
		narrow)
			# General narrow peak mode
			echo "-f BAMPE --keep-dup all --nomodel -q ${qvalue}"
			;;
		tf)
			# TF ChIP-seq-like narrow peak mode
			echo "-f BAMPE --keep-dup all --nomodel -q ${qvalue}"
			;;
		broad)
			# Broad peak mode
			echo "-f BAMPE --keep-dup all --nomodel --broad --broad-cutoff ${broad_cutoff} -q ${qvalue}"
			;;
	esac
}

# ------------------------------------------------------------
# Find target BAM files
# ------------------------------------------------------------
echo "searching target BAM files..."
echo "  pattern = *${alignment_suffix}"
echo ""

# If input_dir is an ATAC_QC output directory, use only its shifted BAMs.
# This prevents MACS3 from accidentally using 02_bam_qc/*.clean.bam
# or 04_split_bam/*.bam when the whole previous-module output is passed.
if [ -d "${input_dir}/03_shifted_bam" ]; then
	search_bam_dir="${input_dir}/03_shifted_bam"
	echo "Detected ATAC_QC output directory."
	echo "  search_bam_dir = ${search_bam_dir}"
else
	search_bam_dir="${input_dir}"
	echo "Using input_dir directly as BAM search directory."
	echo "  search_bam_dir = ${search_bam_dir}"
fi

echo ""

mapfile -t bam_files < <(
	find "$search_bam_dir" -type f \
		-name "*${alignment_suffix}" \
		! -name "*.bai" \
		! -name "*.unsorted.bam" \
		| sort
)

if [ "${#bam_files[@]}" -eq 0 ]; then
	echo "Error: No BAM files matching '*${alignment_suffix}' found in search_bam_dir: $search_bam_dir" >&2
	echo ""
	echo "Expected ATAC_QC shifted BAM layout:"
	echo "  ATAC_QC/output/03_shifted_bam/<SampleID>/<SampleID>.shifted.bam"
	echo ""
	echo "Available BAM files under input_dir:"
	find "$input_dir" -type f -name "*.bam" | sort | sed 's/^/  /'
	echo ""
	echo "Tip: if using old Tn5_shift output, set alignment_suffix accordingly."
	exit 1
fi

echo "matched BAM files:"
printf '  %s\n' "${bam_files[@]}"
echo ""

find_bam_by_sample_name() {
	local sample_name="$1"

	find "$search_bam_dir" -type f \
		-name "${sample_name}${alignment_suffix}" \
		! -name "*.bai" \
		! -name "*.unsorted.bam" \
		| sort \
		| head -n 1
}

# ------------------------------------------------------------
# Detect control-treatment structure
# ------------------------------------------------------------
control_files=()
treatment_files=()

for bam in "${bam_files[@]}"; do
	base="$(basename "$bam")"

	if [[ "$base" == CONTROL_* ]]; then
		control_files+=("$bam")
	else
		treatment_files+=("$bam")
	fi
done

if [ "${#treatment_files[@]}" -eq 0 ]; then
	echo "Error: No treatment BAM found. Treatment BAM should not start with CONTROL_" >&2
	exit 1
fi

echo "detected sample structure:"
echo "  treatment BAM count = ${#treatment_files[@]}"
echo "  control BAM count   = ${#control_files[@]}"
echo ""

echo "[treatment BAM]"
printf '  %s\n' "${treatment_files[@]}"
echo ""

if [ "${#control_files[@]}" -gt 0 ]; then
	echo "[control BAM]"
	printf '  %s\n' "${control_files[@]}"
	echo ""
fi

# ------------------------------------------------------------
# Run MACS3 for one treatment
# ------------------------------------------------------------
run_macs3_one() {
	local treatment_bam="$1"
	local control_bam="${2:-}"

	local treatment_base
	treatment_base="$(basename "$treatment_bam")"

	local sample_id="${treatment_base%"$alignment_suffix"}"
	local output_prefix="${output_dir}/${sample_id}"
	local sample_log="${output_prefix}_macs3.log"
	local sample_err="${output_prefix}_macs3.stderr.log"

	local macs3_params
	macs3_params="$(get_macs3_params "$peak_type")"

	echo "------------------------------------------------------------"
	echo "Processing sample: $sample_id"
	echo "  treatment BAM = $treatment_bam"

	if [ -n "$control_bam" ]; then
		echo "  control BAM   = $control_bam"
	else
		echo "  control BAM   = none"
	fi

	echo "  output prefix = $output_prefix"
	echo "  MACS3 params  = $macs3_params"
	echo ""

	if command -v samtools >/dev/null 2>&1; then
		if [ ! -f "${treatment_bam}.bai" ] && [ ! -f "${treatment_bam%.*}.bai" ]; then
			echo "BAM index not found for treatment. Creating index..."
			samtools index "$treatment_bam"
		fi

		if [ -n "$control_bam" ] && [ ! -f "${control_bam}.bai" ] && [ ! -f "${control_bam%.*}.bai" ]; then
			echo "BAM index not found for control. Creating index..."
			samtools index "$control_bam"
		fi
	fi

	echo "running MACS3..."
	echo ""

	set +e

	if [ -n "$control_bam" ]; then
		macs3 callpeak \
			-t "$treatment_bam" \
			-c "$control_bam" \
			-g "$genome_size" \
			-n "$output_prefix" \
			$macs3_params \
			> "$sample_log" 2> "$sample_err"
	else
		macs3 callpeak \
			-t "$treatment_bam" \
			-g "$genome_size" \
			-n "$output_prefix" \
			$macs3_params \
			> "$sample_log" 2> "$sample_err"
	fi

	exit_code=$?
	set -e

	if [ "$exit_code" -ne 0 ]; then
		echo "Error: MACS3 failed for $sample_id with exit code $exit_code" >&2
		echo "Check logs: $sample_log, $sample_err" >&2
		return "$exit_code"
	fi

	local peak_file
	if [ "$peak_type" = "broad" ]; then
		peak_file="${output_prefix}_peaks.broadPeak"
	else
		peak_file="${output_prefix}_peaks.narrowPeak"
	fi

	if [ ! -s "$peak_file" ]; then
		echo "Error: peak file not created or empty: $peak_file" >&2
		echo "Check logs: $sample_log, $sample_err" >&2
		return 1
	fi

	echo "MACS3 completed:"
	echo "  peak file = $peak_file"
	echo "  log file  = $sample_log"
	echo "  stderr    = $sample_err"

	if command -v wc >/dev/null 2>&1; then
		echo "  peak count = $(wc -l < "$peak_file")"
	fi

	echo ""

	return 0
}

# ------------------------------------------------------------
# Pairing rule
# ------------------------------------------------------------
processed_count=0
failed_count=0

if [ "${#control_files[@]}" -gt 0 ]; then
	echo "CONTROL_ files detected. Running paired control-treatment mode."
	echo ""

	for control_bam in "${control_files[@]}"; do
		control_base="$(basename "$control_bam")"
		sample_name="${control_base#CONTROL_}"
		sample_name="${sample_name%"$alignment_suffix"}"

		treatment_bam="$(find_bam_by_sample_name "$sample_name")"

		if [ -z "$treatment_bam" ] || [ ! -f "$treatment_bam" ]; then
			echo "Warning: matching treatment BAM not found for control: $control_base" >&2
			echo "Expected pattern under ${search_bam_dir}: ${sample_name}${alignment_suffix}" >&2
			failed_count=$((failed_count + 1))
			continue
		fi

		if run_macs3_one "$treatment_bam" "$control_bam"; then
			processed_count=$((processed_count + 1))
		else
			failed_count=$((failed_count + 1))
		fi
	done
else
	echo "No CONTROL_ files detected. Running treatment-only mode."
	echo ""

	for treatment_bam in "${treatment_files[@]}"; do
		if run_macs3_one "$treatment_bam"; then
			processed_count=$((processed_count + 1))
		else
			failed_count=$((failed_count + 1))
		fi
	done
fi

# ------------------------------------------------------------
# Output summary
# ------------------------------------------------------------
echo ""
echo "output files:"
find "$output_dir" -maxdepth 1 -type f | sort | sed 's/^/  /'
echo ""

echo "done:"
echo "  processed samples = ${processed_count}"
echo "  failed samples    = ${failed_count}"
echo "  output_dir        = ${output_dir}"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"

if [ "$processed_count" -eq 0 ]; then
	echo "Error: no samples were processed successfully." >&2
	exit 1
fi

if [ "$failed_count" -gt 0 ]; then
	echo "Warning: ${failed_count} sample(s) failed. Check the stderr log: $err_file" >&2
fi

exit 0
