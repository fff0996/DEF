#!/bin/bash
# Replicate consistency of ATAC-seq peaks with IDR (ENCODE style).
#
# For each condition with two or more replicates:
#   1. MACS3 is run with a relaxed threshold (p-value) on every replicate and
#      on the pooled replicates (same BAMPE options as MACS3_callpeak_ATAC).
#   2. Relaxed peaks are ranked by p-value and capped at max_peaks.
#   3. IDR is run on every replicate pair, with the pooled peaks as the
#      reference peak list.
#   4. Peaks passing idr_threshold are kept per pair; the pair with the most
#      passing peaks gives the condition's conservative peak set.
#
# Usage:
#   bash replicate_consistency.1.0.sh \
#     input_dir="..." sample_data="..." output_dir="..." genome_size="..." \
#     [alignment_suffix=".shifted.bam"] [pvalue="0.01"] [idr_threshold="0.05"] [max_peaks="300000"]
#
# Arguments:
#   input_dir        (required) - Tn5-shifted BAM directory; an ATAC_QC output_dir
#                                 is searched in 03_shifted_bam
#   sample_data      (required) - CSV with SampleID, Condition, Replicate (the ATAC_QC
#                                 sample sheet). BAM files are <SampleID><alignment_suffix>
#   output_dir       (required) - Output directory (cleaned except logs/ on each run)
#   genome_size      (required) - MACS3 genome size: hs, mm, ce, dm, or a number
#   alignment_suffix (optional) - BAM file name suffix, default: .shifted.bam
#   pvalue           (optional) - Relaxed MACS3 p-value threshold, default: 0.01
#   idr_threshold    (optional) - Global IDR cutoff for reproducible peaks, default: 0.05
#   max_peaks        (optional) - Relaxed peaks kept per replicate (by p-value),
#                                 default: 300000
#
# Outputs (output_dir):
#   01_relaxed_peaks/<condition>/  relaxed narrowPeak per replicate and pooled, MACS3 logs
#   02_idr/<condition>/            <repA>_vs_<repB>.idr.txt (all peaks with IDR values),
#                                  .idr_passed.narrowPeak, .idr.png, .idr.log
#   03_reproducible_peaks/         <condition>.conservative_peaks.narrowPeak
#   04_summary/idr_summary.tsv     peaks per replicate, pooled, and passing IDR per pair
#   logs/                          <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Conditions with a single replicate are reported and skipped. Pseudo-
# replicate (self-consistency) analysis is not done.

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

			case "$key" in
				input_dir|sample_data|output_dir|genome_size|alignment_suffix|pvalue|idr_threshold|max_peaks)
					declare "$key=$value"
					;;
				*)
					echo "Error: Unknown parameter: $key" >&2
					exit 1
					;;
			esac
			;;
		*)
			echo "Error: Invalid argument format: $arg (must be key=value format)" >&2
			exit 1
			;;
	esac
done

for required in input_dir sample_data output_dir genome_size; do
	if [ -z "${!required:-}" ]; then
		echo "Error: Required parameter '$required' is missing" >&2
		exit 1
	fi
done

alignment_suffix="${alignment_suffix:-.shifted.bam}"
pvalue="${pvalue:-0.01}"
idr_threshold="${idr_threshold:-0.05}"
max_peaks="${max_peaks:-300000}"

if ! awk -v v="$pvalue" 'BEGIN { exit !(v > 0 && v < 1) }'; then
	echo "Error: pvalue must be between 0 and 1: $pvalue" >&2
	exit 1
fi
if ! awk -v v="$idr_threshold" 'BEGIN { exit !(v > 0 && v < 1) }'; then
	echo "Error: idr_threshold must be between 0 and 1: $idr_threshold" >&2
	exit 1
fi
if [[ ! "$max_peaks" =~ ^[0-9]+$ ]] || [ "$max_peaks" -lt 1000 ]; then
	echo "Error: max_peaks must be an integer >= 1000: $max_peaks" >&2
	exit 1
fi
if [ ! -d "$input_dir" ]; then
	echo "Error: input_dir not found: $input_dir" >&2
	exit 1
fi
if [ ! -f "$sample_data" ]; then
	echo "Error: sample_data not found: $sample_data" >&2
	exit 1
fi

# ------------------------------------------------------------
# output_dir is cleaned below, so it must not be or contain an input.
# ------------------------------------------------------------
output_real="$(realpath -m -- "$output_dir")"
for input_path in "$input_dir" "$sample_data"; do
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
if [ -d "$output_dir" ] && [ "$output_real" != "/" ]; then
	find "$output_dir" -mindepth 1 -maxdepth 1 ! -name "logs" -print0 | xargs -0 rm -rf
fi

mkdir -p "$output_dir"
output_dir="$output_real"

logs_dir="${output_dir}/logs"
mkdir -p "$logs_dir"
timestamp="$(date '+%Y%m%d_%H%M%S')_$$"
log_file="${logs_dir}/${timestamp}.log"
err_file="${logs_dir}/${timestamp}.error.log"

# stdout / stderr separate
exec > >(tee -a "$log_file") 2> >(tee -a "$err_file" >&2)

relaxed_root="${output_dir}/01_relaxed_peaks"
idr_root="${output_dir}/02_idr"
repro_dir="${output_dir}/03_reproducible_peaks"
summary_dir="${output_dir}/04_summary"
mkdir -p "$relaxed_root" "$idr_root" "$repro_dir" "$summary_dir"
summary_file="${summary_dir}/idr_summary.tsv"

echo "############################## Replicate consistency (IDR)"
echo "Log file: $log_file"
echo "Error log file: $err_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""
echo "parameters:"
echo "  input_dir        = ${input_dir}"
echo "  sample_data      = ${sample_data}"
echo "  output_dir       = ${output_dir}"
echo "  genome_size      = ${genome_size}"
echo "  alignment_suffix = ${alignment_suffix}"
echo "  pvalue           = ${pvalue}"
echo "  idr_threshold    = ${idr_threshold}"
echo "  max_peaks        = ${max_peaks}"
echo ""

for cmd in macs3 idr samtools; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: $cmd not found in PATH (run inside the bx_replicate_consistency image)" >&2
		exit 1
	fi
done
echo "macs3: $(macs3 --version 2>&1)"
echo "idr:   $(idr --version 2>&1)"
echo ""

if [ -d "${input_dir}/03_shifted_bam" ]; then
	search_bam_dir="${input_dir}/03_shifted_bam"
	echo "Detected ATAC_QC output directory: using ${search_bam_dir}"
else
	search_bam_dir="${input_dir}"
fi
echo ""

# ------------------------------------------------------------
# Step 1: Sample sheet -> condition, replicate, BAM
# ------------------------------------------------------------
echo "############################## Step 1: Read sample_data"

samples_tsv="${summary_dir}/resolved_samples.tsv"
# Simple CSV (no quoted commas); header names are matched case-sensitively.
awk -F',' '
	NR == 1 {
		for (i = 1; i <= NF; i++) { h = $i; gsub(/^[ \t"\r]+|[ \t"\r]+$/, "", h); col[h] = i }
		if (!("SampleID" in col) || !("Condition" in col) || !("Replicate" in col)) {
			print "Error: sample_data needs SampleID, Condition, and Replicate columns" > "/dev/stderr"
			exit 2
		}
		next
	}
	{
		gsub(/\r/, "")
		s = $col["SampleID"]; c = $col["Condition"]; r = $col["Replicate"]
		gsub(/^[ \t"]+|[ \t"]+$/, "", s); gsub(/^[ \t"]+|[ \t"]+$/, "", c); gsub(/^[ \t"]+|[ \t"]+$/, "", r)
		if (s == "" && c == "") next
		if (s == "" || c == "" || r == "") {
			print "Error: empty SampleID, Condition, or Replicate at line " NR > "/dev/stderr"
			exit 2
		}
		print s "\t" c "\t" r
	}
' "$sample_data" > "${samples_tsv}.tmp"

: > "$samples_tsv"
while IFS=$'\t' read -r sample_id condition replicate; do
	if [[ ! "$sample_id" =~ ^[A-Za-z0-9._-]+$ ]] || [[ ! "$condition" =~ ^[A-Za-z0-9._-]+$ ]]; then
		echo "Error: SampleID and Condition may contain only letters, digits, '.', '_', '-': $sample_id / $condition" >&2
		exit 1
	fi
	mapfile -t hits < <(find "$search_bam_dir" -type f -name "${sample_id}${alignment_suffix}" | sort)
	if [ "${#hits[@]}" -eq 0 ]; then
		echo "Error: BAM not found for SampleID $sample_id (${sample_id}${alignment_suffix} under $search_bam_dir)" >&2
		exit 1
	fi
	if [ "${#hits[@]}" -gt 1 ]; then
		echo "Error: several BAMs found for SampleID $sample_id:" >&2
		printf '  %s\n' "${hits[@]}" >&2
		exit 1
	fi
	if [ ! -f "${hits[0]}.bai" ] && [ ! -f "${hits[0]%.bam}.bai" ]; then
		echo "BAM index not found; creating: ${hits[0]}.bai"
		samtools index "${hits[0]}"
	fi
	printf '%s\t%s\t%s\t%s\n' "$sample_id" "$condition" "$replicate" "${hits[0]}" >> "$samples_tsv"
done < "${samples_tsv}.tmp"
rm -f "${samples_tsv}.tmp"

if [ ! -s "$samples_tsv" ]; then
	echo "Error: no samples in sample_data: $sample_data" >&2
	exit 1
fi

echo "samples (SampleID, Condition, Replicate, BAM):"
sed 's/^/  /' "$samples_tsv"
echo ""

mapfile -t conditions < <(cut -f2 "$samples_tsv" | awk '!seen[$0]++')

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
# MACS3 with a relaxed p-value; writes <name>.relaxed.narrowPeak with the
# top max_peaks peaks by p-value (column 8, -log10 p).
call_relaxed() {
	local out_dir="$1" name="$2"
	shift 2
	local prefix="${out_dir}/${name}"

	if ! macs3 callpeak -t "$@" -f BAMPE -g "$genome_size" -n "$prefix" \
		--keep-dup all --nomodel -p "$pvalue" \
		> "${prefix}_macs3.log" 2> "${prefix}_macs3.stderr.log"; then
		echo "Error: MACS3 failed for $name; see ${prefix}_macs3.stderr.log" >&2
		return 1
	fi
	if [ ! -s "${prefix}_peaks.narrowPeak" ]; then
		echo "Error: MACS3 produced no peaks for $name" >&2
		return 1
	fi
	sort -k8,8gr "${prefix}_peaks.narrowPeak" | awk -v n="$max_peaks" 'NR <= n' > "${prefix}.relaxed.narrowPeak"
	echo "  ${name}: $(wc -l < "${prefix}.relaxed.narrowPeak") relaxed peaks"
}

printf 'condition\treplicate_a\treplicate_b\tpeaks_a\tpeaks_b\tpooled_peaks\tidr_passed\tstatus\n' > "$summary_file"

conditions_done=0
conditions_skipped=0
pairs_failed=0

# ------------------------------------------------------------
# Step 2: Per condition
# ------------------------------------------------------------
for condition in "${conditions[@]}"; do
	echo "############################## Condition: $condition"

	mapfile -t sids < <(awk -F'\t' -v c="$condition" '$2 == c { print $1 }' "$samples_tsv")
	mapfile -t bams < <(awk -F'\t' -v c="$condition" '$2 == c { print $4 }' "$samples_tsv")

	if [ "${#sids[@]}" -lt 2 ]; then
		echo "Warning: condition $condition has ${#sids[@]} replicate; IDR needs two or more. Skipped." >&2
		printf '%s\t%s\tNA\tNA\tNA\tNA\tNA\tskipped_single_replicate\n' "$condition" "${sids[0]}" >> "$summary_file"
		conditions_skipped=$((conditions_skipped + 1))
		echo ""
		continue
	fi

	cond_relaxed="${relaxed_root}/${condition}"
	cond_idr="${idr_root}/${condition}"
	mkdir -p "$cond_relaxed" "$cond_idr"

	echo "relaxed peak calling (p < ${pvalue}):"
	relaxed_ok=1
	for i in "${!sids[@]}"; do
		call_relaxed "$cond_relaxed" "${sids[$i]}" "${bams[$i]}" || relaxed_ok=0
	done
	pooled_name="${condition}_pooled"
	call_relaxed "$cond_relaxed" "$pooled_name" "${bams[@]}" || relaxed_ok=0

	if [ "$relaxed_ok" -eq 0 ]; then
		echo "Warning: relaxed peak calling failed in condition $condition; skipped" >&2
		printf '%s\tNA\tNA\tNA\tNA\tNA\tNA\tfailed_peak_calling\n' "$condition" >> "$summary_file"
		pairs_failed=$((pairs_failed + 1))
		echo ""
		continue
	fi
	pooled_peaks="${cond_relaxed}/${pooled_name}.relaxed.narrowPeak"
	n_pooled="$(wc -l < "$pooled_peaks")"
	echo ""

	# IDR column 12 is -log10(global IDR).
	min_score="$(awk -v t="$idr_threshold" 'BEGIN { printf "%.6f", -log(t) / log(10) }')"
	best_n=-1
	best_file=""
	echo "IDR per replicate pair (passing: global IDR <= ${idr_threshold}):"
	for ((a = 0; a < ${#sids[@]}; a++)); do
		for ((b = a + 1; b < ${#sids[@]}; b++)); do
			ra="${sids[$a]}"
			rb="${sids[$b]}"
			pa="${cond_relaxed}/${ra}.relaxed.narrowPeak"
			pb="${cond_relaxed}/${rb}.relaxed.narrowPeak"
			pair="${ra}_vs_${rb}"
			idr_out="${cond_idr}/${pair}.idr.txt"
			status="done"

			if idr --samples "$pa" "$pb" --peak-list "$pooled_peaks" \
				--input-file-type narrowPeak --rank p.value \
				--soft-idr-threshold "$idr_threshold" --use-best-multisummit-IDR \
				--output-file "$idr_out" --log-output-file "${cond_idr}/${pair}.idr.log" \
				--plot > "${cond_idr}/${pair}.idr.stdout.log" 2> "${cond_idr}/${pair}.idr.stderr.log"; then
				awk -v m="$min_score" 'BEGIN { OFS = "\t" } $12 >= m { print $1, $2, $3, $4, $5, $6, $7, $8, $9, $10 }' \
					"$idr_out" | sort -k1,1 -k2,2n > "${cond_idr}/${pair}.idr_passed.narrowPeak"
				n_pass="$(wc -l < "${cond_idr}/${pair}.idr_passed.narrowPeak")"
				if [ "$n_pass" -gt "$best_n" ]; then
					best_n="$n_pass"
					best_file="${cond_idr}/${pair}.idr_passed.narrowPeak"
				fi
			else
				echo "Warning: IDR failed for ${pair}; see ${cond_idr}/${pair}.idr.stderr.log" >&2
				n_pass="NA"
				status="failed_idr"
				pairs_failed=$((pairs_failed + 1))
			fi
			echo "  ${pair}: ${n_pass} peaks"
			printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$condition" "$ra" "$rb" \
				"$(wc -l < "$pa")" "$(wc -l < "$pb")" "$n_pooled" "$n_pass" "$status" >> "$summary_file"
		done
	done

	if [ -n "$best_file" ]; then
		cp "$best_file" "${repro_dir}/${condition}.conservative_peaks.narrowPeak"
		echo "conservative peak set: ${repro_dir}/${condition}.conservative_peaks.narrowPeak (${best_n} peaks, from $(basename "$best_file" .idr_passed.narrowPeak))"
		conditions_done=$((conditions_done + 1))
	fi
	echo ""
done

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
echo "############################## Summary"
sed 's/^/  /' "$summary_file"
echo ""
echo "  conditions with reproducible peaks = ${conditions_done}"
echo "  conditions skipped (1 replicate)   = ${conditions_skipped}"
echo "  failed pairs or conditions         = ${pairs_failed}"
echo ""
echo "############################## Done"
echo "summary    = ${summary_file}"
echo "output_dir = ${output_dir}"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"

if [ "$conditions_done" -eq 0 ]; then
	echo "Error: no condition produced reproducible peaks (each condition needs two or more replicates)" >&2
	exit 1
fi
if [ "$pairs_failed" -gt 0 ]; then
	echo "Warning: ${pairs_failed} pair(s) or condition(s) failed. Check the stderr log: $err_file" >&2
fi
exit 0
