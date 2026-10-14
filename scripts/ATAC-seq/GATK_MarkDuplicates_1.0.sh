#!/bin/bash

# v1.1  Changes from v1.0
#
#   1) Tool paths moved from the legacy /opt/apps/<tool>/current/... layout to
#      the paths the Apptainer images actually provide (/opt/bio/bin/... , and a
#      tool-specific prefix where the tool needs its own environment). The old
#      layout does not exist on the host, and the standard `apptainer exec` line
#      binds -B /opt/apps:/opt/apps, which would shadow the tools inside the
#      image wherever the host does have /opt/apps.
#
#   2) A threads= argument is accepted for call-site uniformity, but GATK MarkDuplicates
#      exposes no thread option so there is nothing to apply it to. Passing it
#      changes nothing.
#
#   3) A file-level processing failure now makes the script exit non-zero.
#      Until now the script ended with exit 0 even when it had processed 0 of N
#      inputs, so a failed stage was silently carried over by any caller that
#      chained these scripts together.

# Usage: ./GATK_MarkDuplicates.sh <parameter1> <parameter2> ...
# Example: ./GATK_MarkDuplicates.sh input="value" output="result"
# Arguments:
#   Input parameters:
#     input_dir (Input, required) - Directory containing input BAM files
#   Output parameters:
#     output_dir (Output, required) - Directory for output marked BAM files
#   Option parameters:
#     threads (Option, optional) - Thread count (default: 4)
#     ref_genome (Option, required) - Reference genome FASTA file

# Process all arguments (key=value format)





# ???? ???? ???? ???? ???? - 2026.02.06 10:30
#ulimit -n 500000

for arg in "$@"
do
	# Check if argument is in key=value format
	case $arg in
		*=*)
			# Parse key=value using IFS for better performance
			IFS='=' read -r key value <<< "$arg"
			
			# Remove surrounding quotes if present
			value="${value%\"}"  # Remove trailing quote
			value="${value#\"}"  # Remove leading quote
			value="${value%\'}"  # Remove trailing single quote
			value="${value#\'}"  # Remove leading single quote
			
			# Key validation
			if [[ ! $key =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
				echo "Invalid key: $key" >&2
				exit 1
			fi
			
			# Block protected variables
			case "$key" in IFS|UID|EUID|PPID|BASHOPTS|BASHPID)
				echo "Refusing to set protected var: $key" >&2
				exit 1
				;;
			esac
			
			# Declare variable
			declare "$key=$value"
			;;
		*)
			echo "Invalid argument format: $arg (must be key=value format)"
			exit 1
			;;
	esac
done

# =============================================================================
# Thread count
# =============================================================================
# Optional. When threads= is not supplied the original hard-coded value is used,
# so existing call sites behave exactly as they did in v1.0.
threads="${threads:-4}"
if [[ ! "$threads" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: 'threads' must be a positive integer (got: $threads)" >&2
    exit 1
fi

# =============================================================================
# Failure tracking
# =============================================================================
# v1.1: these scripts used to end with exit 0 even when a per-file step failed.
# Strelka2 actually reported "Processed: 0/1 tumor-normal pairs" and still
# returned 0, so the calling runner logged the step as complete while no result
# VCF existed. Chained into a pipeline, a failed stage is silently carried over.
#
# So log_error now drops a marker file, and the end of the script derives the
# exit status from that marker. The marker is a file rather than a variable
# because log_error is called from inside $( ) and subshells in a few places,
# where an assignment would never reach the parent shell.
SCRIPT_FAILED_FLAG="$(mktemp -u "${TMPDIR:-/tmp}/.$(basename "$0").failed.XXXXXX")"
trap 'rm -f "$SCRIPT_FAILED_FLAG"' EXIT

# Required parameter validation
if [ -z "${input_dir:-}" ]; then
    echo "Error: Required parameter 'input_dir' is missing"
    exit 1
fi
if [ -z "${output_dir:-}" ]; then
    echo "Error: Required parameter 'output_dir' is missing"
    exit 1
fi
if [ -z "${ref_genome:-}" ]; then
    echo "Error: Required parameter 'ref_genome' is missing"
    exit 1
fi

set -euo pipefail

# =============================================================================
# Constants
# =============================================================================
readonly program_gatk='/opt/bio/bin/gatk'
readonly program_samtools='/opt/bio/bin/samtools'
readonly supported_extensions=("sorted.bam")

# =============================================================================
# Logging Functions
# =============================================================================
setup_logging() {
    local log_file="$1"
    local log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"

    # Output stdout and stderr to both console and log file simultaneously
    exec > >(tee -a "$log_file")
    exec 2> >(tee -a "$log_file" >&2)
}

log_message_header() {
    echo -e "\n$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_message() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    # v1.1: drop the failure marker. See the Failure tracking section above.
    : > "$SCRIPT_FAILED_FLAG"
    log_message_header "ERROR: $1" >&2
}

log_error_critical() {
    log_message_header "CRITICAL ERROR: $1" >&2
    exit 1
}

# =============================================================================
# Parameter Validation Functions
# =============================================================================
validate_non_empty() {
    local value="$1"
    local name="$2"
    if [ -z "$(echo "$value" | tr -d '[:space:]')" ]; then
        log_error "$name cannot be empty."
        return 1
    fi
}

validate_parameters() {
    local validation_failed=0

    # Validate parameter emptiness
    if ! validate_non_empty "$input_dir" "input_dir"; then
        validation_failed=1
    fi

    if ! validate_non_empty "$output_dir" "output_dir"; then
        validation_failed=1
    fi

    # Check if input directory exists
    if [ ! -d "$input_dir" ]; then
        log_error "Input directory does not exist: $input_dir"
        validation_failed=1
    fi

    # Check if GATK program exists
    if [ ! -f "$program_gatk" ]; then
        log_error "GATK program not found: $program_gatk"
        validation_failed=1
    fi

    # Check if SAMtools program exists
    if [ ! -f "$program_samtools" ]; then
        log_error "SAMtools program not found: $program_samtools"
        validation_failed=1
    fi

    # Exit script if validation fails
    if [ $validation_failed -eq 1 ]; then
        log_error_critical "Parameter validation failed."
    fi
}

# =============================================================================
# File Processing Functions
# =============================================================================
execute_mark_duplicates() {
    local input_bam="$1"
    local output_dir="$2"
    local input_dir="$3"

    local file_name=$(basename "$input_bam")
    local sample_id="${file_name%.*}"

    # Set output file paths
    local output_bam="$output_dir/${sample_id}_marked.bam"
    local output_index="$output_dir/${sample_id}_marked.bam.bai"
    local metrics_file="$output_dir/${sample_id}_duplicate_metrics.txt"
    local log_file="$output_dir/${sample_id}_markduplicates.log"

    # Create temporary directory
    local sample_tmp_dir="$input_dir/temp_${sample_id}_$$_$(date +%s%N)"
    mkdir -p "$sample_tmp_dir"

    # Construct GATK MarkDuplicates command (non-Spark version)
    local command="$program_gatk MarkDuplicates \
        -I $input_bam \
        -O $output_bam \
        -M $metrics_file \
        -R $ref_genome \
        --TMP_DIR $sample_tmp_dir \
        --MAX_FILE_HANDLES_FOR_READ_ENDS_MAP 1000\
        --java-options '-Xmx20g'"

    log_message_header "Processing mark duplicates for $sample_id..."
    log_message "Command: $command"


  
#################################################
    # Execute GATK MarkDuplicates command
	if eval "$command >>$log_file 2>&1"; then
		log_message "Successfully marked duplicates for $sample_id"

        # Generate BAM index file
        local index_command="$program_samtools index $output_bam"
        log_message "Generating index file: $index_command"
        
        if eval "$index_command >>$log_file 2>&1"; then
            log_message "Successfully created index file for $sample_id"
            # Clean up temporary directory on success
            rm -rf "$sample_tmp_dir" 2>/dev/null || true
            return 0
        else
            log_error "Index file generation failed for $sample_id"
            rm -rf "$sample_tmp_dir" 2>/dev/null || true
            return 1
        fi
    else
        log_error "Mark duplicates failed for $sample_id"
        rm -rf "$sample_tmp_dir" 2>/dev/null || true
        return 1
    fi
    
    
}

run_manager() {
    local input_dir="$1"
    local output_dir="$2"

    # Search for BAM files
    local file_list=()
    for ext in "${supported_extensions[@]}"; do
        while IFS= read -r -d $'\0' file; do
            file_list+=("$file")
        done < <(find "$input_dir" -type f -name "*$ext" ! -name "*unsorted.bam" -print0)
    done

    # Check if files exist
    if [ ${#file_list[@]} -eq 0 ]; then
        log_error_critical "No BAM files found in $input_dir"
    fi

    log_message_header "Found ${#file_list[@]} BAM files to process"

    # Display list of files to be processed
    log_message "File list:"
    for file in "${file_list[@]}"; do
        log_message "  - $(basename "$file")"
    done

    # Process each file
    local processed_count=0
    local failed_count=0
    local failed_files=()

    # Process each file
    set +e  # Don't exit on individual file failures
    for file in "${file_list[@]}"; do
        if execute_mark_duplicates "$file" "$output_dir" "$input_dir"; then
            ((processed_count++))
        else
            ((failed_count++))
            failed_files+=("$(basename "$file")")
            log_message "FAILED: $(basename "$file")"
        fi
    done
    set -e

    # Clean up any remaining temporary directories
    find "$input_dir" -type d -name "temp_*_$$_*" -exec rm -rf {} \; 2>/dev/null || true

    log_message_header "Mark duplicates processing complete. Processed: $processed_count/${#file_list[@]} files"
    if [ $failed_count -gt 0 ]; then
        log_message_header "Warning: Some files were not processed successfully."
        log_message "Failed files ($failed_count):"
        for failed_file in "${failed_files[@]}"; do
            log_message "  - $failed_file"
        done
    fi
}

# =============================================================================
# Main Script
# =============================================================================
main() {
    # Clean output directory (excluding logs directory)
    if [ -d "$output_dir" ] && [ "$output_dir" != "/" ]; then
        find "$output_dir" -mindepth 1 -maxdepth 1 ! -name "logs" -print0 | xargs -0 rm -rf 2>/dev/null || true
    fi

    # Create output directory
    mkdir -p "$output_dir"

    # Setup logging
    local logs_dir="${output_dir}/logs"
    mkdir -p "$logs_dir"
    local log_file="${logs_dir}/$(date '+%Y%m%d_%H%M%S')_$$.log"
    setup_logging "$log_file"

    # Log header and parameters
    log_message_header "Start"
    log_message_header "Log file: $log_file"
    log_message_header "> Parameters"
    log_message "Input Directory: $input_dir"
    log_message "Output Directory: $output_dir"
    log_message "Reference Genome: $ref_genome"

    # Validate parameters
    validate_parameters

    # Actual processing (with time measurement)
    local start_time=$(date +%s)
    run_manager "$input_dir" "$output_dir"
    local end_time=$(date +%s)
    local execution_time=$((end_time - start_time))

    # Completion logging
    log_message_header "Script Execution Time: $execution_time seconds"
    log_message_header "Processing complete. Output files saved to $output_dir"
    log_message_header "End"
}

# Execute main function
main_rc=0
main "$@" || main_rc=$?

# v1.1: surface per-file processing failures in the exit status. Even when main
# itself returns 0, finish with a failure if log_error was called along the way.
if [ -e "$SCRIPT_FAILED_FLAG" ] && [ "$main_rc" -eq 0 ]; then
    main_rc=1
fi
exit "$main_rc"
