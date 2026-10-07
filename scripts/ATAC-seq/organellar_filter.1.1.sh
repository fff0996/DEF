#!/bin/bash
# Version 1.1 (changes from organellar_filter.1.0.sh):
#   threads defaults to auto: the CPU cores allocated to the job (nproc);
#   a number is capped by the allocation. The run stops if output_dir is
#   input_dir or one of its parents, because output_dir is cleaned first.
#
# Usage:
#   ./organellar_filter.1.1.sh input_dir="..." output_dir="..." [threads="auto"] [organellar_pattern="..."]
#
# Arguments:
#   input_dir           (required) - Directory containing BAM files
#   output_dir          (required) - Output directory
#   threads             (optional) - Number of processors: auto (allocated cores)
#                                    or a number capped by them, default: auto
#   organellar_pattern  (optional) - Regex pattern for organellar contigs
#
# Default organellar_pattern:
#   (^chrM$|^MT$|^Mt$|mitochond|mitochondrion|mitochondrial|chloroplast|plastid|^Pt$|^PT$|^chrC$)

set -u
set -o pipefail

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------
error_msg() {
	echo "Error: $*" >&2
}

warn_msg() {
	echo "Warning: $*" >&2
}

info_msg() {
	echo "$*"
}

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
				IFS|UID|EUID|PPID|BASHOPTS|BASHPID)
					echo "Refusing to set protected var: $key" >&2
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

threads="${threads:-auto}"
organellar_pattern="${organellar_pattern:-(^chrM$|^MT$|^Mt$|mitochond|mitochondrion|mitochondrial|chloroplast|plastid|^Pt$|^PT$|^chrC$)}"

# ------------------------------------------------------------
# Threads: the CPU cores allocated to this job (nproc honors the affinity
# mask and cgroup cpuset); a requested number is capped by the allocation.
# ------------------------------------------------------------
threads_requested="$threads"
allocated_threads="$(nproc 2>/dev/null || echo 1)"
if [ -z "$threads" ] || [ "$threads" = "auto" ]; then
	threads="$allocated_threads"
elif ! [[ "$threads" =~ ^[0-9]+$ ]] || [ "$threads" -lt 1 ]; then
	echo "Error: threads must be auto or a positive integer: $threads" >&2
	exit 1
elif [ "$threads" -gt "$allocated_threads" ]; then
	threads="$allocated_threads"
fi
export OMP_NUM_THREADS="$threads" OPENBLAS_NUM_THREADS="$threads" MKL_NUM_THREADS="$threads"

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

echo "############################## Organellar Filter"
echo "Log file: $log_file"
echo "Error log file: $err_file"
echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

echo "parameters:"
echo "  input_dir           = ${input_dir}"
echo "  output_dir          = ${output_dir}"
echo "  threads             = ${threads} (requested ${threads_requested}, allocated ${allocated_threads})"
echo "  organellar_pattern  = ${organellar_pattern}"
echo ""

# ------------------------------------------------------------
# Input validation
# ------------------------------------------------------------
if [ ! -d "$input_dir" ]; then
	error_msg "input_dir not found: $input_dir"
	exit 1
fi

for cmd in samtools awk grep sort comm cut wc head find xargs basename date tee cp; do
	if ! command -v "$cmd" >/dev/null 2>&1; then
		error_msg "required command not found in PATH: $cmd"
		exit 1
	fi
done

# ------------------------------------------------------------
# Find BAM files from input_dir
# ------------------------------------------------------------
echo "searching BAM files in input_dir..."

mapfile -t bam_candidates < <(
	find "$input_dir" -type f \
		-name "*.bam" \
		! -name "*.bai" \
		! -name "*.unsorted.bam" \
		| sort
)

if [ "${#bam_candidates[@]}" -eq 0 ]; then
	error_msg "No BAM file found in input_dir: $input_dir"
	error_msg "Accepted file pattern: *.bam"
	exit 1
fi

echo "found BAM files: ${#bam_candidates[@]}"
printf '  %s\n' "${bam_candidates[@]}"
echo ""

# ------------------------------------------------------------
# Prepare output subdirectories
# ------------------------------------------------------------
stats_dir="${output_dir}/01_stats"
contig_dir="${output_dir}/02_contigs"
filtered_dir="${output_dir}/03_filtered_bam"
summary_dir="${output_dir}/04_summary"

mkdir -p "$stats_dir" "$contig_dir" "$filtered_dir" "$summary_dir"

summary_tsv="${summary_dir}/organellar_filter_summary.tsv"
echo -e "sample\tinput_bam\tall_contigs\torganellar_contigs\tkeep_contigs\tfiltered_bam\tfiltered_bai\tstatus" > "$summary_tsv"

# ------------------------------------------------------------
# Process each BAM
# ------------------------------------------------------------
total_bam="${#bam_candidates[@]}"
success_count=0
fail_count=0

for bam_path in "${bam_candidates[@]}"
do
	sample_name="$(basename "$bam_path" .bam)"

	echo ""
	echo "############################################################"
	echo "Processing sample: ${sample_name}"
	echo "############################################################"
	echo "selected BAM file:"
	echo "  $bam_path"
	echo ""

	idxstats_file="${stats_dir}/${sample_name}.idxstats.tsv"
	flagstat_before="${stats_dir}/${sample_name}.before.flagstat.txt"
	flagstat_after="${stats_dir}/${sample_name}.after.flagstat.txt"

	all_contigs="${contig_dir}/${sample_name}.all_contigs.txt"
	organellar_contigs="${contig_dir}/${sample_name}.organellar_contigs.txt"
	keep_contigs="${contig_dir}/${sample_name}.keep_contigs.txt"

	filtered_bam="${filtered_dir}/${sample_name}.organellar_removed.bam"
	filtered_bai="${filtered_bam}.bai"

	status="SUCCESS"

	# ------------------------------------------------------------
	# Check or create BAM index
	# ------------------------------------------------------------
	echo "############################## Check BAM index"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if [ ! -f "${bam_path}.bai" ] && [ ! -f "${bam_path%.*}.bai" ]; then
		echo "BAM index not found. Creating BAM index..."
		if ! samtools index -@ "$threads" "$bam_path"; then
			error_msg "samtools index failed: $bam_path"
			status="FAILED_INDEX_INPUT"
			echo -e "${sample_name}\t${bam_path}\tNA\tNA\tNA\tNA\tNA\t${status}" >> "$summary_tsv"
			fail_count=$((fail_count + 1))
			continue
		fi
	else
		echo "BAM index found."
	fi

	echo ""

	# ------------------------------------------------------------
	# Step 1. Inspect BAM contig structure
	# ------------------------------------------------------------
	echo "############################## Step 1: Inspect BAM contig structure"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if ! samtools idxstats "$bam_path" > "$idxstats_file"; then
		error_msg "samtools idxstats failed: $bam_path"
		status="FAILED_IDXSTATS"
		echo -e "${sample_name}\t${bam_path}\tNA\tNA\tNA\tNA\tNA\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	cut -f1 "$idxstats_file" | grep -v '^\*$' > "$all_contigs" || true

	echo "idxstats output:"
	echo "  $idxstats_file"
	echo ""

	echo "contig preview:"
	head -50 "$all_contigs" || true
	echo ""

	echo "total contigs:"
	wc -l "$all_contigs"
	echo ""

	# ------------------------------------------------------------
	# Step 2. Detect organellar contigs
	# ------------------------------------------------------------
	echo "############################## Step 2: Detect organellar contigs"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	awk -v pattern="$organellar_pattern" '
	BEGIN { IGNORECASE=1 }
	$1 != "*" && $1 ~ pattern {
		print $1
	}
	' "$idxstats_file" | sort -u > "$organellar_contigs"

	echo "detected organellar contigs:"
	if [ -s "$organellar_contigs" ]; then
		cat "$organellar_contigs"
	else
		echo "  none"
	fi
	echo ""

	echo "organellar contig file:"
	echo "  $organellar_contigs"
	echo ""

	# ------------------------------------------------------------
	# Step 3. Create keep contig list
	# ------------------------------------------------------------
	echo "############################## Step 3: Create keep contig list"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if [ -s "$organellar_contigs" ]; then
		comm -23 <(sort "$all_contigs") <(sort "$organellar_contigs") > "$keep_contigs"
	else
		cp "$all_contigs" "$keep_contigs"
	fi

	echo "keep contig file:"
	echo "  $keep_contigs"
	echo ""

	echo "number of all contigs:"
	wc -l "$all_contigs"

	echo "number of organellar contigs:"
	wc -l "$organellar_contigs"

	echo "number of keep contigs:"
	wc -l "$keep_contigs"
	echo ""

	if [ ! -s "$keep_contigs" ]; then
		error_msg "keep contig list is empty. Please check organellar_pattern."
		status="FAILED_EMPTY_KEEP_CONTIGS"
		echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\tNA\tNA\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	# ------------------------------------------------------------
	# Step 4. Flagstat before filtering
	# ------------------------------------------------------------
	echo "############################## Step 4: BAM flagstat before filtering"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if ! samtools flagstat -@ "$threads" "$bam_path" > "$flagstat_before"; then
		error_msg "samtools flagstat before filtering failed: $bam_path"
		status="FAILED_FLAGSTAT_BEFORE"
		echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\tNA\tNA\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	echo "flagstat before output:"
	echo "  $flagstat_before"
	echo ""

	# ------------------------------------------------------------
	# Step 5. Remove organellar contigs
	# ------------------------------------------------------------
	echo "############################## Step 5: Remove organellar contigs"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if [ ! -s "$organellar_contigs" ]; then
		echo "No organellar contigs detected."
		echo "Creating output BAM by copying input BAM."
		if ! cp "$bam_path" "$filtered_bam"; then
			error_msg "failed to copy input BAM to output BAM: $bam_path"
			status="FAILED_COPY_BAM"
			echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\tNA\tNA\t${status}" >> "$summary_tsv"
			fail_count=$((fail_count + 1))
			continue
		fi
	else
		echo "Filtering BAM by keeping non-organellar contigs..."

		if ! samtools view \
			-@ "$threads" \
			-b \
			"$bam_path" \
			$(cat "$keep_contigs") \
			-o "$filtered_bam"; then

			error_msg "samtools view filtering failed: $bam_path"
			status="FAILED_FILTERING"
			echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\tNA\tNA\t${status}" >> "$summary_tsv"
			fail_count=$((fail_count + 1))
			continue
		fi
	fi

	if [ ! -f "$filtered_bam" ]; then
		error_msg "filtered BAM was not created: $filtered_bam"
		status="FAILED_NO_FILTERED_BAM"
		echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\tNA\tNA\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	echo "filtered BAM:"
	echo "  $filtered_bam"
	echo ""

	# ------------------------------------------------------------
	# Step 6. Index filtered BAM
	# ------------------------------------------------------------
	echo "############################## Step 6: Index filtered BAM"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if ! samtools index -@ "$threads" "$filtered_bam"; then
		error_msg "samtools index for filtered BAM failed: $filtered_bam"
		status="FAILED_INDEX_FILTERED"
		echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\t${filtered_bam}\tNA\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	echo "filtered BAM index:"
	echo "  $filtered_bai"
	echo ""

	# ------------------------------------------------------------
	# Step 7. Flagstat after filtering
	# ------------------------------------------------------------
	echo "############################## Step 7: BAM flagstat after filtering"
	echo "Start time: $(date '+%Y-%m-%d %H:%M:%S')"
	echo ""

	if ! samtools flagstat -@ "$threads" "$filtered_bam" > "$flagstat_after"; then
		error_msg "samtools flagstat after filtering failed: $filtered_bam"
		status="FAILED_FLAGSTAT_AFTER"
		echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\t${filtered_bam}\t${filtered_bai}\t${status}" >> "$summary_tsv"
		fail_count=$((fail_count + 1))
		continue
	fi

	echo "flagstat after output:"
	echo "  $flagstat_after"
	echo ""

	echo -e "${sample_name}\t${bam_path}\t${all_contigs}\t${organellar_contigs}\t${keep_contigs}\t${filtered_bam}\t${filtered_bai}\t${status}" >> "$summary_tsv"
	success_count=$((success_count + 1))

	echo "done sample:"
	echo "  sample                = ${sample_name}"
	echo "  input BAM             = ${bam_path}"
	echo "  idxstats              = ${idxstats_file}"
	echo "  all contigs           = ${all_contigs}"
	echo "  organellar contigs    = ${organellar_contigs}"
	echo "  keep contigs          = ${keep_contigs}"
	echo "  filtered BAM          = ${filtered_bam}"
	echo "  filtered BAI          = ${filtered_bai}"
	echo "  flagstat before       = ${flagstat_before}"
	echo "  flagstat after        = ${flagstat_after}"
done

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
echo ""
echo "############################################################"
echo "Organellar Filter finished"
echo "############################################################"
echo "total BAM files:"
echo "  ${total_bam}"
echo "success:"
echo "  ${success_count}"
echo "failed:"
echo "  ${fail_count}"
echo ""
echo "summary:"
echo "  ${summary_tsv}"
echo ""
echo "output directories:"
echo "  stats        = ${stats_dir}"
echo "  contigs      = ${contig_dir}"
echo "  filtered BAM = ${filtered_dir}"
echo "  summary      = ${summary_dir}"
echo ""
echo "stdout log:"
echo "  ${log_file}"
echo "stderr log:"
echo "  ${err_file}"
echo ""
echo "End time: $(date '+%Y-%m-%d %H:%M:%S')"

if [ "$success_count" -eq 0 ]; then
	error_msg "all BAM files failed."
	exit 1
fi

if [ "$fail_count" -gt 0 ]; then
	warn_msg "some BAM files failed. Check summary TSV and stderr log file."
	exit 0
fi

exit 0