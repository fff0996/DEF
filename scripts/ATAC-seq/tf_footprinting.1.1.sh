#!/bin/bash
# Version 1.1 (changes from tf_footprinting.1.0.sh):
#   stdout and stderr are kept apart: progress goes to stdout and
#   logs/<stamp>.log, errors and warnings (with their diagnostic lines) to
#   stderr and logs/<stamp>.error.log.
#   cores defaults to auto: the CPU cores allocated to the job (nproc); a
#   number is capped by the allocation (1.0 defaulted to 1).
#   A single-BAM condition is sorted straight into the merged BAM path
#   (no temporary copy and rename).
#   The run stops if output_dir is or contains an input path.
#
# Usage:
#   ./tf_footprinting.1.1.sh \
#     input_dir="..." \
#     metadata="..." \
#     macs_dir="..." \
#     genome_fasta="..." \
#     motif_db="..." \
#     output_dir="..." \
#     [peak_file="..."] \
#     [sample_col="SampleID"] \
#     [condition_col="Condition"] \
#     [cores="auto"]
#
# Required:
#   input_dir      - Directory containing BAM files. BAM filenames must include SampleID.
#   metadata       - Metadata TSV/CSV with SampleID and Condition columns.
#   macs_dir       - MACS output directory. Used only when peak_file is not provided.
#   genome_fasta   - Reference genome FASTA.
#   motif_db       - Motif DB file. Plant/animal/custom motif DB can be used.
#   output_dir     - Output directory.
#
# Optional:
#   peak_file      - Pre-merged/common peak BED/narrowPeak/broadPeak file.
#                   If omitted, peaks are merged internally from macs_dir.
#   sample_col     - Metadata sample column name. Default: SampleID
#   condition_col  - Metadata condition column name. Default: Condition
#   cores          - CPU cores: auto (allocated cores) or a number capped by
#                    them. Default: auto
#
# Metadata example:
#   SampleID	Condition	Replicate
#   SRR17296554	ctrl	1
#   SRR17296555	ctrl	2
#   SRR17296556	KO_Batf	1
#   SRR17296557	KO_Batf	2
#
# Workflow:
#   1. Check input data shape
#   2. Read metadata
#   3. Resolve BAM files by SampleID
#   4. Merge BAMs by Condition
#   5. Create merged/common peak BED from MACS outputs if peak_file is not provided
#   6. Run TOBIAS ATACorrect per condition
#   7. Run TOBIAS ScoreBigwig per condition
#   8. Run TOBIAS BINDetect comparative mode
#   9. Produce HTML outputs similar to NBIS tutorial

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
			echo "Invalid argument format: $arg"
			echo "Arguments must be key=value format."
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

if [ -z "${metadata:-}" ]; then
	echo "Error: Required parameter 'metadata' is missing" >&2
	exit 1
fi

if [ -z "${genome_fasta:-}" ]; then
	echo "Error: Required parameter 'genome_fasta' is missing" >&2
	exit 1
fi

if [ -z "${motif_db:-}" ]; then
	echo "Error: Required parameter 'motif_db' is missing" >&2
	exit 1
fi

if [ -z "${output_dir:-}" ]; then
	echo "Error: Required parameter 'output_dir' is missing" >&2
	exit 1
fi

sample_col="${sample_col:-SampleID}"
condition_col="${condition_col:-Condition}"
cores="${cores:-auto}"
macs_dir="${macs_dir:-}"
peak_file="${peak_file:-}"

# ------------------------------------------------------------
# Cores: the CPU cores allocated to this job (nproc honors the affinity
# mask and cgroup cpuset); a requested number is capped by the allocation.
# ------------------------------------------------------------
cores_requested="$cores"
allocated_cores="$(nproc 2>/dev/null || echo 1)"
if [ -z "$cores" ] || [ "$cores" = "auto" ]; then
	cores="$allocated_cores"
elif [[ "$cores" =~ ^[0-9]+$ ]] && [ "$cores" -gt "$allocated_cores" ]; then
	cores="$allocated_cores"
fi
export OMP_NUM_THREADS="$cores" OPENBLAS_NUM_THREADS="$cores" MKL_NUM_THREADS="$cores"

# ------------------------------------------------------------
# output_dir is cleaned below, so it must not be or contain an input.
# ------------------------------------------------------------
output_real="$(realpath -m -- "$output_dir")"
for input_path in "$input_dir" "$metadata" "$genome_fasta" "$motif_db" "$macs_dir" "$peak_file"; do
	[ -n "$input_path" ] || continue
	input_real="$(realpath -m -- "$input_path")"
	case "$input_real/" in
		"$output_real"/*)
			echo "Error: input $input_path is inside output_dir $output_dir, which is cleaned on each run" >&2
			exit 1
			;;
	esac
done

# ------------------------------------------------------------
# Prepare output and log
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

echo "############################## TOBIAS TF Footprinting with Metadata"
echo "Log file: $log_file"
echo "Error log file: $err_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "parameters:"
echo "  input_dir     = $input_dir"
echo "  metadata      = $metadata"
echo "  macs_dir      = ${macs_dir:-not_provided}"
echo "  peak_file     = ${peak_file:-auto_from_macs_dir}"
echo "  genome_fasta  = $genome_fasta"
echo "  motif_db      = $motif_db"
echo "  output_dir    = $output_dir"
echo "  sample_col    = $sample_col"
echo "  condition_col = $condition_col"
echo "  cores         = $cores (requested $cores_requested, allocated $allocated_cores)"
echo ""

# ------------------------------------------------------------
# Validate files and tools
# ------------------------------------------------------------
if [ ! -d "$input_dir" ]; then
	echo "Error: input_dir not found: $input_dir" >&2
	exit 1
fi

if [ ! -f "$metadata" ]; then
	echo "Error: metadata file not found: $metadata" >&2
	exit 1
fi

if [ ! -f "$genome_fasta" ]; then
	echo "Error: genome FASTA not found: $genome_fasta" >&2
	exit 1
fi

if [ ! -f "$motif_db" ]; then
	echo "Error: motif DB not found: $motif_db" >&2
	exit 1
fi

if [ -n "$peak_file" ] && [ ! -f "$peak_file" ]; then
	echo "Error: peak_file not found: $peak_file" >&2
	exit 1
fi

if [ -z "$peak_file" ]; then
	if [ -z "$macs_dir" ]; then
		echo "Error: Either peak_file or macs_dir must be provided." >&2
		exit 1
	fi

	if [ ! -d "$macs_dir" ]; then
		echo "Error: macs_dir not found: $macs_dir" >&2
		exit 1
	fi
fi

if ! [[ "$cores" =~ ^[0-9]+$ ]] || [ "$cores" -lt 1 ]; then
	echo "Error: cores must be a positive integer" >&2
	exit 1
fi

required_cmds=(TOBIAS samtools awk sed sort cut head wc find du basename dirname tr grep)

for cmd in "${required_cmds[@]}"; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Error: required command not found in PATH: $cmd" >&2
		exit 1
	fi
done

if [ -z "$peak_file" ]; then
	if ! command -v bedtools >/dev/null 2>&1; then
		echo "Error: bedtools not found in PATH" >&2
		echo "bedtools is required when peak_file is not provided and peaks must be merged internally." >&2
		exit 1
	fi
fi

# ------------------------------------------------------------
# Output directories
# ------------------------------------------------------------
metadata_dir="${output_dir}/00_metadata"
peak_merge_dir="${output_dir}/01_peak_merge"
merged_bam_dir="${output_dir}/02_merged_bam_by_condition"
tracks_dir="${output_dir}/03_tobias_tracks"
bindetect_dir="${output_dir}/04_BINDetect"
summary_dir="${output_dir}/summary"

mkdir -p "$metadata_dir" "$peak_merge_dir" "$merged_bam_dir" "$tracks_dir" "$bindetect_dir" "$summary_dir"

# ------------------------------------------------------------
# Resolve BAM search directory
# ------------------------------------------------------------
# If input_dir is an ATAC_QC output directory, use only shifted BAMs from
# input_dir/03_shifted_bam. This prevents TOBIAS from accidentally using
# 02_bam_qc/*.clean.bam or 04_split_bam/*.bam when the whole previous-module
# output directory is passed by the workflow engine.
if [ -d "${input_dir}/03_shifted_bam" ]; then
	bam_search_dir="${input_dir}/03_shifted_bam"
	bam_find_pattern="*.shifted.bam"
	echo "Detected ATAC_QC output directory."
	echo "  BAM search directory = ${bam_search_dir}"
	echo "  BAM search pattern   = ${bam_find_pattern}"
	echo ""
else
	bam_search_dir="${input_dir}"
	bam_find_pattern="*.bam"
	echo "Using input_dir directly as BAM search directory."
	echo "  BAM search directory = ${bam_search_dir}"
	echo "  BAM search pattern   = ${bam_find_pattern}"
	echo ""
fi

# ------------------------------------------------------------
# Input data shape check
# ------------------------------------------------------------
echo "############################## Input data shape check"
echo ""

echo "[metadata]"
echo "  path: $metadata"
echo "  size: $(du -h "$metadata" | awk '{print $1}')"
echo "  preview:"
head -n 10 "$metadata" | sed 's/^/    /'
echo ""

echo "[input_dir BAM candidates]"
bam_count=$(find "$bam_search_dir" -type f -name "$bam_find_pattern" ! -name "*.bai" | wc -l | awk '{print $1}')
echo "  input_dir: $input_dir"
echo "  bam_search_dir: $bam_search_dir"
echo "  bam_find_pattern: $bam_find_pattern"
echo "  BAM count: $bam_count"
find "$bam_search_dir" -type f -name "$bam_find_pattern" ! -name "*.bai" | sort | head -n 20 | sed 's/^/    /'
echo ""

if [ "$bam_count" -eq 0 ]; then
	echo "Error: No BAM files matching ${bam_find_pattern} found in BAM search directory: $bam_search_dir" >&2
	echo "Available BAM files under input_dir:" >&2
	{ find "$input_dir" -type f -name "*.bam" ! -name "*.bai" | sort | sed 's/^/  /' || true; } >&2
	exit 1
fi

echo "[genome_fasta]"
echo "  path: $genome_fasta"
echo "  size: $(du -h "$genome_fasta" | awk '{print $1}')"

if [ ! -f "${genome_fasta}.fai" ]; then
	echo "  fasta index: not found; creating ${genome_fasta}.fai"
	samtools faidx "$genome_fasta"
else
	echo "  fasta index: found"
fi

genome_contigs=$(cut -f1 "${genome_fasta}.fai" | wc -l | awk '{print $1}')
genome_total_bp=$(awk '{sum += $2} END {print sum}' "${genome_fasta}.fai")

echo "  contigs/scaffolds: $genome_contigs"
echo "  total bp: $genome_total_bp"
echo ""

echo "[motif_db]"
echo "  path: $motif_db"
echo "  size: $(du -h "$motif_db" | awk '{print $1}')"
echo "  preview:"
head -n 8 "$motif_db" | sed 's/^/    /'
echo ""

# ------------------------------------------------------------
# Detect metadata delimiter
# ------------------------------------------------------------
header_line=$(head -n 1 "$metadata" | tr -d '\r')

if echo "$header_line" | grep -q $'\t'; then
	delim=$'\t'
	delim_name="tab"
else
	delim=","
	delim_name="comma"
fi

echo "metadata delimiter detected: $delim_name"
echo ""

# ------------------------------------------------------------
# Find metadata column indexes
# ------------------------------------------------------------
get_col_index() {
	local col_name="$1"
	local file="$2"
	local delimiter="$3"

	awk -v target="$col_name" -v FS="$delimiter" '
		NR==1 {
			for (i=1; i<=NF; i++) {
				gsub(/\r/, "", $i)
				gsub(/^[ \t]+|[ \t]+$/, "", $i)
				if ($i == target) {
					print i
					exit
				}
			}
		}
	' "$file"
}

sample_idx=$(get_col_index "$sample_col" "$metadata" "$delim")
condition_idx=$(get_col_index "$condition_col" "$metadata" "$delim")

if [ -z "$sample_idx" ]; then
	echo "Error: sample_col not found in metadata: $sample_col" >&2
	echo "Header:" >&2
	echo "  $header_line" >&2
	exit 1
fi

if [ -z "$condition_idx" ]; then
	echo "Error: condition_col not found in metadata: $condition_col" >&2
	echo "Header:" >&2
	echo "  $header_line" >&2
	exit 1
fi

echo "metadata columns:"
echo "  ${sample_col}    = column ${sample_idx}"
echo "  ${condition_col} = column ${condition_idx}"
echo ""

# ------------------------------------------------------------
# Normalize metadata: sample_id, condition
# ------------------------------------------------------------
mapping_tsv="${metadata_dir}/metadata_sample_condition.tsv"

awk -v FS="$delim" -v OFS="\t" \
	-v sample_idx="$sample_idx" \
	-v condition_idx="$condition_idx" '
	NR==1 { next }
	{
		sample=$sample_idx
		condition=$condition_idx

		gsub(/\r/, "", sample)
		gsub(/\r/, "", condition)

		gsub(/^[ \t]+|[ \t]+$/, "", sample)
		gsub(/^[ \t]+|[ \t]+$/, "", condition)

		if (sample == "" || condition == "") {
			next
		}

		print sample, condition
	}
' "$metadata" > "$mapping_tsv"

echo "normalized metadata:"
echo "  $mapping_tsv"
echo "  rows: $(wc -l < "$mapping_tsv" | awk '{print $1}')"
echo "  preview:"
cat "$mapping_tsv" | sed 's/^/    /'
echo ""

if [ ! -s "$mapping_tsv" ]; then
	echo "Error: normalized metadata is empty" >&2
	exit 1
fi

condition_count=$(cut -f2 "$mapping_tsv" | sort -u | wc -l | awk '{print $1}')

if [ "$condition_count" -lt 2 ]; then
	echo "Error: Need at least 2 unique conditions for comparative BINDetect." >&2
	echo "Found condition count: $condition_count" >&2
	cut -f2 "$mapping_tsv" | sort -u | sed 's/^/  /' >&2
	exit 1
fi

# ------------------------------------------------------------
# Resolve BAM by SampleID
# ------------------------------------------------------------
resolved_tsv="${metadata_dir}/resolved_sample_condition_bam.tsv"
: > "$resolved_tsv"

echo "############################## Resolving BAM paths by SampleID"

while IFS=$'\t' read -r sample condition
do
	mapfile -t candidates < <(
		find "$bam_search_dir" -type f \
			-name "$bam_find_pattern" \
			! -name "*.bai" \
			| awk -v s="$sample" 'index($0, s) > 0' \
			| sort
	)

	if [ "${#candidates[@]}" -eq 0 ]; then
		echo "Error: BAM not found for SampleID: $sample" >&2
		echo "  searched input_dir = $input_dir" >&2
		echo "  searched bam_search_dir = $bam_search_dir" >&2
		echo "  expected BAM pattern = $bam_find_pattern" >&2
		echo "  expected BAM filename containing SampleID" >&2
		exit 1
	fi

	if [ "${#candidates[@]}" -gt 1 ]; then
		echo "Error: Multiple BAM files matched SampleID: $sample" >&2
		printf '  %s\n' "${candidates[@]}" >&2
		echo "" >&2
		echo "Please make BAM filenames unique per SampleID or use separated input_dir." >&2
		exit 1
	fi

	bam="${candidates[0]}"
	echo -e "${sample}\t${condition}\t${bam}" >> "$resolved_tsv"

done < "$mapping_tsv"

echo "resolved table:"
echo "  $resolved_tsv"
cat "$resolved_tsv" | sed 's/^/    /'
echo ""

# ------------------------------------------------------------
# BAM shape check and indexing
# ------------------------------------------------------------
echo "############################## BAM shape check"

while IFS=$'\t' read -r sample condition bam
do
	echo "[$sample / $condition]"
	echo "  bam: $bam"
	echo "  size: $(du -h "$bam" | awk '{print $1}')"

	if [ ! -f "${bam}.bai" ] && [ ! -f "${bam%.*}.bai" ]; then
		echo "  index: not found; creating"
		samtools index "$bam"
	else
		echo "  index: found"
	fi

	echo "  header SQ preview:"
	samtools view -H "$bam" | grep '^@SQ' | head -n 3 | sed 's/^/    /' || true

	total_count=$(samtools view -c "$bam" 2>/dev/null || echo "NA")
	mapped_count=$(samtools view -c -F 4 "$bam" 2>/dev/null || echo "NA")

	echo "  total alignments : $total_count"
	echo "  mapped alignments: $mapped_count"
	echo ""

done < "$resolved_tsv"

# ------------------------------------------------------------
# Resolve or create merged/common peak file
# ------------------------------------------------------------
echo "############################## Resolving peak file"

if [ -n "$peak_file" ]; then
	echo "Using provided peak_file:"
	echo "  $peak_file"

else
	echo "peak_file not provided."
	echo "Creating merged/common peak BED internally from macs_dir:"
	echo "  $macs_dir"

	peak_file="${peak_merge_dir}/merged_common_peaks.bed"

	mapfile -t narrow_candidates < <(
		find "$macs_dir" -type f \
			-name "*_peaks.narrowPeak" \
			! -name "*summits*" \
			! -name "*summit*" \
			! -name "*blacklist*" \
			! -name "*background*" \
			| sort
	)

	mapfile -t broad_candidates < <(
		find "$macs_dir" -type f \
			-name "*_peaks.broadPeak" \
			! -name "*summits*" \
			! -name "*summit*" \
			! -name "*blacklist*" \
			! -name "*background*" \
			| sort
	)

	mapfile -t bed_candidates < <(
		find "$macs_dir" -type f \( \
			-name "*_peaks.bed" -o \
			-name "*peaks*.bed" -o \
			-name "*peak*.bed" \
		\) \
			! -name "*summits*" \
			! -name "*summit*" \
			! -name "*blacklist*" \
			! -name "*background*" \
			| sort
	)

	if [ "${#narrow_candidates[@]}" -gt 0 ]; then
		echo "Using narrowPeak files:"
		printf '  %s\n' "${narrow_candidates[@]}"

		cat "${narrow_candidates[@]}" \
			| awk 'BEGIN{OFS="\t"} NF>=3 {print $1,$2,$3}' \
			| sort -k1,1 -k2,2n \
			| bedtools merge \
			> "$peak_file"

	elif [ "${#broad_candidates[@]}" -gt 0 ]; then
		echo "Using broadPeak files:"
		printf '  %s\n' "${broad_candidates[@]}"

		cat "${broad_candidates[@]}" \
			| awk 'BEGIN{OFS="\t"} NF>=3 {print $1,$2,$3}' \
			| sort -k1,1 -k2,2n \
			| bedtools merge \
			> "$peak_file"

	elif [ "${#bed_candidates[@]}" -gt 0 ]; then
		echo "Using BED peak files:"
		printf '  %s\n' "${bed_candidates[@]}"

		cat "${bed_candidates[@]}" \
			| awk 'BEGIN{OFS="\t"} NF>=3 {print $1,$2,$3}' \
			| sort -k1,1 -k2,2n \
			| bedtools merge \
			> "$peak_file"

	else
		echo "Error: No MACS peak files found in macs_dir." >&2
		echo "Accepted:" >&2
		echo "  *_peaks.narrowPeak" >&2
		echo "  *_peaks.broadPeak" >&2
		echo "  *_peaks.bed" >&2
		echo "  *peaks*.bed" >&2
		echo "" >&2
		echo "Summits are intentionally excluded." >&2
		exit 1
	fi

	if [ ! -s "$peak_file" ]; then
		echo "Error: merged peak file was created but is empty: $peak_file" >&2
		exit 1
	fi
fi

echo ""
echo "[peak_file]"
echo "  path: $peak_file"
echo "  size: $(du -h "$peak_file" | awk '{print $1}')"
peak_rows=$(wc -l < "$peak_file" | awk '{print $1}')
peak_cols=$(awk 'BEGIN{FS="\t"} NF>0 {print NF; exit}' "$peak_file")

echo "  rows: $peak_rows"
echo "  columns first row: $peak_cols"
echo "  preview:"
head -n 5 "$peak_file" | sed 's/^/    /'
echo ""

if [ "$peak_cols" -lt 3 ]; then
	echo "Error: peak_file must have at least 3 columns: chrom, start, end" >&2
	exit 1
fi

# ------------------------------------------------------------
# Merge BAMs by condition
# ------------------------------------------------------------
echo "############################## Merging BAMs by condition"

declare -a conditions
mapfile -t conditions < <(cut -f2 "$resolved_tsv" | sort -u)

declare -a signal_files
declare -a cond_names

for condition in "${conditions[@]}"; do
	safe_condition="${condition//[^a-zA-Z0-9_]/_}"
	condition_bam_list="${merged_bam_dir}/${safe_condition}.bam.list"

	awk -v c="$condition" -F '\t' '$2 == c {print $3}' "$resolved_tsv" > "$condition_bam_list"

	n_bams=$(wc -l < "$condition_bam_list" | awk '{print $1}')

	echo "condition: $condition"
	echo "  safe condition: $safe_condition"
	echo "  BAM count: $n_bams"
	echo "  BAM list:"
	sed 's/^/    /' "$condition_bam_list"

	merged_bam="${merged_bam_dir}/${safe_condition}.merged.sorted.bam"

	if [ "$n_bams" -eq 1 ]; then
		only_bam=$(cat "$condition_bam_list")
		echo "  only one BAM; sorting it into the merged BAM path"
		samtools sort -@ "$cores" -o "$merged_bam" "$only_bam"
	else
		echo "  merging BAMs"
		samtools merge -@ "$cores" -f "$merged_bam.unsorted.bam" $(cat "$condition_bam_list")
		echo "  sorting merged BAM"
		samtools sort -@ "$cores" -o "$merged_bam" "$merged_bam.unsorted.bam"
		rm -f "$merged_bam.unsorted.bam"
	fi

	samtools index "$merged_bam"

	echo "  merged BAM: $merged_bam"
	echo ""

	cond_names+=("$safe_condition")

	# ------------------------------------------------------------
	# TOBIAS ATACorrect + ScoreBigwig per condition
	# ------------------------------------------------------------
	cond_track_dir="${tracks_dir}/${safe_condition}"
	atacorrect_dir="${cond_track_dir}/ATACorrect"
	score_dir="${cond_track_dir}/ScoreBigwig"

	mkdir -p "$atacorrect_dir" "$score_dir"

	corrected_bw="${score_dir}/${safe_condition}_corrected.bw"
	footprint_bw="${score_dir}/${safe_condition}_footprints.bw"

	echo "############################## TOBIAS for condition: $safe_condition"
	echo ""

	echo "[Step 1] TOBIAS ATACorrect"
	TOBIAS ATACorrect \
		--bam "$merged_bam" \
		--genome "$genome_fasta" \
		--peaks "$peak_file" \
		--outdir "$atacorrect_dir" \
		--cores "$cores"

	mapfile -t corrected_candidates < <(
		find "$atacorrect_dir" -type f \( \
			-name "*corrected*.bw" -o \
			-name "*.bw" \
		\) | sort
	)

	if [ "${#corrected_candidates[@]}" -eq 0 ]; then
		echo "Error: ATACorrect corrected bigWig not found for condition: $safe_condition" >&2
		exit 1
	fi

	cp -f "${corrected_candidates[0]}" "$corrected_bw"

	echo "  corrected BW: $corrected_bw"
	echo ""

	echo "[Step 2] TOBIAS ScoreBigwig"
	TOBIAS ScoreBigwig \
		--signal "$corrected_bw" \
		--regions "$peak_file" \
		--output "$footprint_bw" \
		--cores "$cores"

	if [ ! -f "$footprint_bw" ]; then
		echo "Error: ScoreBigwig footprint bigWig not found: $footprint_bw" >&2
		exit 1
	fi

	echo "  footprint BW: $footprint_bw"
	echo ""

	signal_files+=("$footprint_bw")
done

# ------------------------------------------------------------
# BINDetect comparative analysis
# ------------------------------------------------------------
echo "############################## TOBIAS BINDetect comparative analysis"
echo ""

if [ "${#signal_files[@]}" -lt 2 ]; then
	echo "Error: BINDetect comparative analysis requires at least 2 condition signal files." >&2
	exit 1
fi

echo "conditions:"
printf '  %s\n' "${cond_names[@]}"
echo ""

echo "signals:"
printf '  %s\n' "${signal_files[@]}"
echo ""

TOBIAS BINDetect \
	--motifs "$motif_db" \
	--signals "${signal_files[@]}" \
	--genome "$genome_fasta" \
	--peaks "$peak_file" \
	--cond_names "${cond_names[@]}" \
	--outdir "$bindetect_dir" \
	--cores "$cores"
# ------------------------------------------------------------
# Collect BINDetect HTML/PDF figures for Bio-Express output
# ------------------------------------------------------------
echo ""
echo "############################## Collecting BINDetect report figures"

report_dir="${summary_dir}/bindetect_reports"
mkdir -p "$report_dir"

mapfile -t bindetect_htmls < <(
	find "$bindetect_dir" -type f \
		-name "*.html" \
		| sort
)

mapfile -t bindetect_pdfs < <(
	find "$bindetect_dir" -type f \
		-name "*.pdf" \
		| sort
)

mapfile -t bindetect_pngs < <(
	find "$bindetect_dir" -type f \
		-name "*.png" \
		| sort
)

if [ "${#bindetect_htmls[@]}" -gt 0 ]; then
	echo "BINDetect HTML files found:"
	printf '  %s\n' "${bindetect_htmls[@]}"

	for f in "${bindetect_htmls[@]}"; do
		cp -f "$f" "$report_dir/"
	done
else
	echo "WARNING: No BINDetect HTML files found under:" >&2
	echo "  $bindetect_dir" >&2
fi

if [ "${#bindetect_pdfs[@]}" -gt 0 ]; then
	echo "BINDetect PDF files found:"
	printf '  %s\n' "${bindetect_pdfs[@]}"

	for f in "${bindetect_pdfs[@]}"; do
		cp -f "$f" "$report_dir/"
	done
else
	echo "WARNING: No BINDetect PDF files found under:" >&2
	echo "  $bindetect_dir" >&2
fi

if [ "${#bindetect_pngs[@]}" -gt 0 ]; then
	echo "BINDetect PNG files found:"
	printf '  %s\n' "${bindetect_pngs[@]}"

	for f in "${bindetect_pngs[@]}"; do
		cp -f "$f" "$report_dir/"
	done
fi

echo "Collected BINDetect reports:"
find "$report_dir" -type f | sort | sed 's/^/  /' || true
echo ""
# ------------------------------------------------------------
# Collect outputs
# ------------------------------------------------------------
echo ""
echo "############################## Collecting outputs"

html_count=$(find "$bindetect_dir" -type f -name "*.html" | wc -l | awk '{print $1}')
txt_count=$(find "$bindetect_dir" -type f -name "*.txt" | wc -l | awk '{print $1}')
bed_count=$(find "$bindetect_dir" -type f -name "*.bed" | wc -l | awk '{print $1}')
bw_count=$(find "$tracks_dir" -type f -name "*.bw" | wc -l | awk '{print $1}')

echo "output counts:"
echo "  bigWig tracks = $bw_count"
echo "  HTML plots    = $html_count"
echo "  TXT files     = $txt_count"
echo "  BED files     = $bed_count"
echo ""

echo "HTML outputs:"
find "$bindetect_dir" -type f -name "*.html" | sort | sed 's/^/  /' || true
echo ""

echo "Main result files:"
find "$bindetect_dir" -type f \( \
	-name "*results.txt" -o \
	-name "*overview*.txt" -o \
	-name "*bindetect*.txt" \
\) | sort | sed 's/^/  /' || true
echo ""

summary_file="${summary_dir}/tf_footprinting_summary.tsv"

{
	echo -e "key\tvalue"
	echo -e "metadata\t${metadata}"
	echo -e "input_dir\t${input_dir}"
	echo -e "macs_dir\t${macs_dir:-not_used}"
	echo -e "peak_file\t${peak_file}"
	echo -e "genome_fasta\t${genome_fasta}"
	echo -e "motif_db\t${motif_db}"
	echo -e "conditions\t$(IFS=','; echo "${cond_names[*]}")"
	echo -e "signals\t$(IFS=','; echo "${signal_files[*]}")"
	echo -e "merged_bam_dir\t${merged_bam_dir}"
	echo -e "tracks_dir\t${tracks_dir}"
	echo -e "bindetect_dir\t${bindetect_dir}"
	echo -e "html_count\t${html_count}"
	echo -e "log_file\t${log_file}"
} > "$summary_file"

echo "summary:"
echo "  $summary_file"
echo ""

echo "done:"
echo "  metadata table = $mapping_tsv"
echo "  resolved BAMs  = $resolved_tsv"
echo "  peak file      = $peak_file"
echo "  merged BAM dir = $merged_bam_dir"
echo "  TOBIAS tracks  = $tracks_dir"
echo "  BINDetect dir  = $bindetect_dir"
echo "  HTML plots     = $html_count"
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"