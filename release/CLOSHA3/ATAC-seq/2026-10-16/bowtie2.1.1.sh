#!/bin/bash

# Version 1.1 (changes from bowtie2_1.0.sh, CLOSHA 2.0):
#   Tools are called from /opt/bio/bin (bowtie2, bowtie2-build, samtools)
#     instead of /opt/apps/<tool>/current/..., which the images do not have.
#   Threads: bowtie2 -p and samtools sort -@ use the cores allocated to the job
#     (threads=auto, nproc) instead of a fixed 4; a larger threads value is
#     capped with a warning. threads is not registered on the portal.
#   Read groups: each sample gets @RG (ID, SM, and LB = sample name,
#     PL = ILLUMINA), which GATK MarkDuplicates 4.6 requires.
#   post_process_bam defaults to yes: coordinate-sorted BAM files with an index
#     (.sorted.bam, .bai) are always written; post_process_bam=no keeps SAM only.
#   Logs: progress goes to stdout and logs/<stamp>.log; errors and warnings
#     (with their explanation lines) go to stderr and logs/<stamp>.error.log.
#     The per-sample <sample>_bowtie.log keeps the bowtie2 alignment summary.
#   Alignments are unchanged.
#
# Usage: ./bowtie2.1.1.sh <parameter1> <parameter2> ...
# Example: ./bowtie2.1.1.sh input_dir="/path/to/fastq" output_dir="/path/to/output" ref_genome="/path/to/index" post_process_bam="yes"
# Arguments:
#   Input parameters:
#     input_dir (Input, required) - Directory containing paired-end or single-end FASTQ files
#   Output parameters:
#     output_dir (Output, required) - Directory for output files
#   Option parameters:
#     ref_genome (Option, required) - Path to reference genome index
#     post_process_bam (Option, optional) - If 'yes', 'y', etc., converts SAM to sorted BAM and performs indexing. Default is 'yes' (since 1.4); not registered on the portal.
#     threads (Option, optional) - auto (default: the allocated cores, nproc) or a smaller number. Not registered on the portal.

# Process all arguments (key=value format)
for arg in "$@"
do
    # Check if argument is in key=value format
    case $arg in
        *=*)
            # Parse key=value using IFS for better performance
            IFS='=' read -r key value <<< "$arg"
            
            # Remove surrounding quotes if present
            value="${value%\"}"    # Remove trailing quote
            value="${value#\"}"    # Remove leading quote
            value="${value%\'}"    # Remove trailing single quote
            value="${value#\'}"    # Remove leading single quote
            
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
            echo "Invalid argument format: $arg (must be key=value format)" >&2
            exit 1
            ;;
    esac
done

# Set default values for optional parameters
if [ -z "${post_process_bam:-}" ]; then
    post_process_bam="yes"
fi

# Required parameter validation
if [ -z "${input_dir:-}" ]; then
    echo "Error: Required parameter 'input_dir' is missing" >&2
    exit 1
fi
if [ -z "${output_dir:-}" ]; then
    echo "Error: Required parameter 'output_dir' is missing" >&2
    exit 1
fi
if [ -z "${ref_genome:-}" ]; then
    echo "Error: Required parameter 'ref_genome' is missing" >&2
    exit 1
fi

set -euo pipefail

# =============================================================================
# Threads: the CPU cores allocated to this job, read with nproc (nproc returns
# OMP_NUM_THREADS when set, which follows the portal's core selection). The
# threads argument is not registered on the portal; a larger requested number
# is capped and reported as a warning.
# =============================================================================
threads="${threads:-auto}"
threads_requested="$threads"
allocated_threads="$(nproc 2>/dev/null || echo 1)"
threads_capped=0
if [ -z "$threads" ] || [ "$threads" = "auto" ]; then
    threads="$allocated_threads"
elif ! [[ "$threads" =~ ^[0-9]+$ ]] || [ "$threads" -lt 1 ]; then
    echo "Error: threads must be auto or a positive integer: $threads" >&2
    exit 1
elif [ "$threads" -gt "$allocated_threads" ]; then
    threads_capped=1
    threads="$allocated_threads"
fi


# =============================================================================
# Constants
# =============================================================================
readonly program_bowtie2='/opt/bio/bin/bowtie2'
readonly program_bowtie2_build='/opt/bio/bin/bowtie2-build'
readonly program_samtools='/opt/bio/bin/samtools'
readonly supported_extensions=("fastq" "fastq.gz" "fq" "fq.gz")

# =============================================================================
# Global Variables
# =============================================================================
# CRITICAL: input_dir, output_dir, ref_genome, post_process_bam are set dynamically in argument parsing
# DO NOT re-declare user input variables here - they will overwrite user values!

# Processing variables (set during script execution)
paired_files_r1=()
paired_files_r2=()
single_files=()

# =============================================================================
# Logging Functions
# =============================================================================
setup_logging() {
    local log_file="$1"
    local err_file="${log_file%.log}.error.log"
    local log_dir=$(dirname "$log_file")
    mkdir -p "$log_dir"

    # stdout -> screen + .log; stderr -> screen + .error.log (same stamp)
    exec > >(tee -a "$log_file")
    exec 2> >(tee -a "$err_file" >&2)
}

log_message_header() {
    echo -e "\n[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_message() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

log_error() {
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
    
    # Validate and standardize post_process_bam value
    # Allows yes, no, y, n (case insensitive)
    local lower_case_pp=$(echo "$post_process_bam" | tr '[:upper:]' '[:lower:]')
    
    if [[ "$lower_case_pp" =~ ^(yes|y)$ ]]; then
        post_process_bam="true"
    elif [[ "$lower_case_pp" =~ ^(no|n)$ ]]; then
        post_process_bam="false"
    else
        log_error "Parameter 'post_process_bam' must be one of: yes, no, y, n (case insensitive). Current value: $post_process_bam"
        validation_failed=1
    fi
    
    # Check if input directory exists
    if [ ! -d "$input_dir" ]; then
        log_error "Input directory does not exist: $input_dir"
        validation_failed=1
    fi

    # Check if Bowtie2 program exists
    if [ ! -f "$program_bowtie2" ]; then
        log_error "Bowtie2 program not found: $program_bowtie2"
        validation_failed=1
    fi

    # Check if samtools program exists
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
build_index_if_needed() {
    local ref_path="$1"
    
    # Check if the index files already exist
    if [ -f "${ref_path}.1.bt2" ]; then
        log_message_header "Bowtie2 index already exists. Skipping build step."
        return 0
    fi
    
    # If index doesn't exist, check if the path is a FASTA file
    if [ -f "$ref_path" ]; then
        log_message_header "Bowtie2 index not found. Building index from FASTA file..."
        log_message "FASTA file: $ref_path"
        log_message "Index base name: $ref_path"
        
        if [ ! -f "$program_bowtie2_build" ]; then
            log_error_critical "Bowtie2-build program not found: $program_bowtie2_build. Cannot build index."
        fi

        # Build the index
        if ! "$program_bowtie2_build" -f "$ref_path" "$ref_path"; then
            log_error_critical "Failed to build Bowtie2 index from $ref_path."
        fi

        # Verify the index was built successfully
        if [ ! -f "${ref_path}.1.bt2" ]; then
            log_error_critical "Index build completed, but required files were not found. Check permissions or disk space."
        fi
        
        log_message "Bowtie2 index build successful."
        return 0
    else
        log_error_critical "Provided reference genome path is neither a FASTA file nor a valid Bowtie2 index base name: $ref_path"
    fi
}

get_file_type() {
    local filename="$1"
    if [[ "$filename" =~ \.(fastq|fq|fastq\.gz|fq\.gz)$ ]]; then
        echo "fastq"
    else
        echo "unknown"
    fi
}

# Remove quality filtering suffixes from sample name
# Arguments:
#   $1 - Original sample name
# Returns:
#   Clean sample name without _trimmed, _HQ suffixes
clean_sample_name() {
    local sample_name="$1"
    # Remove _trimmed and _HQ suffixes (case insensitive)
    sample_name=$(echo "$sample_name" | sed -E 's/_(trimmed|HQ)(_R[12])?$//gi')
    sample_name=$(echo "$sample_name" | sed -E 's/_(trimmed|HQ)$//gi')
    echo "$sample_name"
}

# Parse filename to extract base name and paired file information
# Supports various FASTQ naming conventions:
# - Illumina format: sample_S1_L001_R1_001.fastq.gz
# - Simple paired-end: sample_R1.fastq, sample.R1.fastq
# - Basic paired-end: sample_1.fastq
# Returns: "base_name extension parent_dir paired_file" or error code 1
parse_filename() {
    local filepath="$1"
    local file_name=$(basename "$filepath")

    # Pattern matching for R1 files with various formats:
    # - sample_R1.fastq -> sample_R2.fastq
    # - sample.R1.fastq -> sample.R2.fastq
    # - sample_S1_L001_R1_001.fastq.gz -> sample_S1_L001_R2_001.fastq.gz
    # - sample_L001_R1.fastq.gz -> sample_L001_R2.fastq.gz
    if [[ "$file_name" =~ ^(.+)([._])R1(_[0-9]{3})?(\..+)$ ]]; then
        local base_name="${BASH_REMATCH[1]}"
        local separator="${BASH_REMATCH[2]}"    # Store original separator (. or _)
        local suffix="${BASH_REMATCH[3]}"       # Store suffix like _001
        local extension="${BASH_REMATCH[4]}"
        local parent_dir=$(dirname "$filepath")
        # Generate R2 filename using original separator and suffix
        local paired_file="${parent_dir}/${base_name}${separator}R2${suffix}${extension}"

        echo "$base_name $extension $parent_dir $paired_file"
        return 0
    # Pattern matching for _1/_2 format files:
    # - SRR7890824_1.fastq.gz
    # - sample_1.fastq
    elif [[ "$file_name" =~ ^(.+)_1(\.(fq|fastq)(\.gz)?)$ ]]; then
        local base_name="${BASH_REMATCH[1]}"
        local extension="${BASH_REMATCH[2]}"
        local parent_dir=$(dirname "$filepath")
        local paired_file="${parent_dir}/${base_name}_2${extension}"

        echo "$base_name $extension $parent_dir $paired_file"
        return 0
    fi
    return 1
}

# Process SAM file into a sorted, indexed BAM file.
# This function performs SAM-to-BAM conversion, sorting, and indexing.
# It is designed to be reusable for both paired-end and single-end alignment outputs.
#
# Arguments:
#   $1 - Path to the input SAM file generated by the aligner (e.g., Bowtie2).
#   $2 - Path to the log file for appending samtools output.
# Returns:
#   0 on success, 1 on failure
process_sam_to_bam() {
    local input_sam="$1"
    local log_file="$2"
    
    # Define file paths based on the input SAM file name
    # e.g., sample_bowtie_paired.sam -> sample_bowtie_paired.unsorted.bam
    local temp_unsorted_bam="${input_sam%.sam}.unsorted.bam"
    # e.g., sample_bowtie_paired.sam -> sample_bowtie_paired.sorted.bam
    local output_bam="${input_sam%.sam}.sorted.bam"

    log_message_header "Starting SAM/BAM post-processing for $(basename "$input_sam")..."

    # 1. Convert SAM to (Unsorted) BAM
    log_message "Converting SAM to BAM (output: $temp_unsorted_bam)..."
    $program_samtools view -bS -h "$input_sam" -o "$temp_unsorted_bam" 2>>"$log_file"
    local view_exit_code=$?

    if [ $view_exit_code -ne 0 ] || [ ! -f "$temp_unsorted_bam" ]; then
        log_error "SAM to BAM conversion failed (Exit code: $view_exit_code)"
        # Do NOT remove SAM file if conversion failed
        return 1
    fi
    log_message "Converted SAM to unsorted BAM."

    # 2. Sort BAM
    log_message "Sorting BAM file (output: $output_bam)..."
    local temp_prefix="${output_bam%.sorted.bam}.tmp"
    $program_samtools sort -@ "$threads" -T "$temp_prefix" -o "$output_bam" "$temp_unsorted_bam" 2>>"$log_file"
    local sort_exit_code=$?

    if [ $sort_exit_code -ne 0 ] || [ ! -f "$output_bam" ]; then
        log_error "BAM sorting failed (Exit code: $sort_exit_code)"
        return 1
    fi
    log_message "Successfully sorted BAM."

    # 3. Index Sorted BAM
    log_message "Indexing sorted BAM file (output: $output_bam.bai)..."
    "$program_samtools" index "$output_bam" 2>>"$log_file"
    local index_exit_code=$?

    if [ $index_exit_code -ne 0 ] || [ ! -f "$output_bam".bai ]; then
        log_error "BAM indexing failed (Exit code: $index_exit_code)"
        return 1
    fi
    log_message "Successfully created BAM index."
    
    return 0
}


# Execute Bowtie2 paired-end alignment
# Arguments:
#   $1 - R1 file path
#   $2 - R2 file path
#   $3 - Base name for output files
#   $4 - Output directory path
# Returns:
#   0 on success, 1 on failure
execute_paired_alignment() {
    local r1_file="$1"
    local r2_file="$2"
    local base_name="$3"
    local output_dir="$4"

    # Clean sample name by removing quality filtering suffixes
    local clean_name=$(clean_sample_name "$base_name")

    # Set output file paths
    local output_sam="$output_dir/${clean_name}_bowtie_paired.sam"
    local log_file="$output_dir/${clean_name}_bowtie.log"

    # Build Bowtie2 paired-end command
    local command="$program_bowtie2 -x $ref_genome -1 $r1_file -2 $r2_file -S $output_sam -p $threads --rg-id $clean_name --rg SM:$clean_name --rg LB:$clean_name --rg PL:ILLUMINA"

    log_message_header "Processing paired-end alignment for $clean_name..."
    log_message "Input files: $(basename "$r1_file"), $(basename "$r2_file")"

    # Execute command
    if eval "$command >>$log_file 2>&1"; then
        # Validate output file
        if [ -f "$output_sam" ] && [ -s "$output_sam" ]; then
            local file_size=$(stat -f%z "$output_sam" 2>/dev/null || stat -c%s "$output_sam" 2>/dev/null || echo "0")
            log_message "Successfully processed paired-end alignment for $clean_name (output: $file_size bytes)"
            
            # Conditional Post-processing: SAM to BAM conversion, Sorting, Indexing
            if [ "${post_process_bam}" = "true" ]; then
                log_message "Post-processing requested. Converting SAM to sorted BAM and indexing..."
                process_sam_to_bam "$output_sam" "$log_file"
                return $? # Return code from post-processing
            else
                log_message "Post-processing skipped. Final output: $output_sam (SAM file)"
                return 0 # Success, SAM file is the final output
            fi
        else
            log_error "Output SAM file not created or empty: $output_sam"
            return 1
        fi
    else
        log_error "Bowtie2 paired-end alignment failed for $clean_name"
        return 1
    fi
}

# Execute Bowtie2 single-end alignment
# Arguments:
#   $1 - Input file path
#   $2 - Output directory path
# Returns:
#   0 on success, 1 on failure
execute_single_alignment() {
    local input_file="$1"
    local output_dir="$2"

    local file_name=$(basename "$input_file")
    local sample_id="${file_name%%.*}"

    # Check file type
    if [[ "$(get_file_type "$file_name")" != "fastq" ]]; then
        log_error "Invalid file format: $file_name"
        return 1
    fi

    # Clean sample name by removing quality filtering suffixes
    local clean_name=$(clean_sample_name "$sample_id")

    # Set output file paths
    local output_sam="$output_dir/${clean_name}_bowtie_single.sam"
    local log_file="$output_dir/${clean_name}_bowtie.log"

    # Build Bowtie2 single-end command
    local command="$program_bowtie2 -x $ref_genome -U $input_file -S $output_sam -p $threads --rg-id $clean_name --rg SM:$clean_name --rg LB:$clean_name --rg PL:ILLUMINA"

    # Execute command
    if eval "$command >>$log_file 2>&1"; then
        # Validate output file
        if [ -f "$output_sam" ] && [ -s "$output_sam" ]; then
            local file_size=$(stat -f%z "$output_sam" 2>/dev/null || stat -c%s "$output_sam" 2>/dev/null || echo "0")
            log_message "Successfully processed single-end alignment for $clean_name (output: $file_size bytes)"

            # Conditional Post-processing: SAM to BAM conversion, Sorting, Indexing
            if [ "${post_process_bam}" = "true" ]; then
                log_message "Post-processing requested. Converting SAM to sorted BAM and indexing..."
                # Note: process_sam_to_bam handles both single and paired output file names
                process_sam_to_bam "$output_sam" "$log_file"
                return $? # Return code from post-processing
            else
                log_message "Post-processing skipped. Final output: $output_sam (SAM file)"
                return 0 # Success, SAM file is the final output
            fi
        else
            log_error "Output SAM file not created or empty: $output_sam"
            return 1
        fi
    else
        log_error "Bowtie2 single-end alignment failed for $clean_name"
        return 1
    fi
}

# Classify all FASTQ files into paired-end and single-end categories
# Arguments:
#   $1 - Input directory containing FASTQ files
# Returns:
#   Sets global arrays: paired_files_r1, paired_files_r2, single_files
classify_fastq_files() {
    local input_dir="$1"
    
    # Global arrays to store classified files
    paired_files_r1=()
    paired_files_r2=()
    single_files=()
    
    # Find all FASTQ files
    local all_files=()
    for ext in "${supported_extensions[@]}"; do
        while IFS= read -r -d $'\0' file; do
            all_files+=("$file")
        done < <(find "$input_dir" -type f -name "*.$ext" -print0)
    done
    
    # Arrays to track potential pairs and actual files
    local potential_r1_files=()
    local potential_r2_files=()
    local processed_files=()
    
    # First pass: identify potential R1 files with their expected R2 pairs
    for file in "${all_files[@]}"; do
        if parse_result=$(parse_filename "$file"); then
            read -r base_name extension parent_dir paired_file <<< "$parse_result"
            potential_r1_files+=("$file")
            potential_r2_files+=("$paired_file")
        fi
    done
    
    # Second pass: match actual R1-R2 pairs
    for ((i=0; i<${#potential_r1_files[@]}; i++)); do
        local r1_file="${potential_r1_files[$i]}"
        local expected_r2_file="${potential_r2_files[$i]}"
        
        # Check if the expected R2 file actually exists
        if [[ -f "$expected_r2_file" ]]; then
            # Valid pair found
            paired_files_r1+=("$r1_file")
            paired_files_r2+=("$expected_r2_file")
            processed_files+=("$r1_file")
            processed_files+=("$expected_r2_file")
        else
            # R1 file without valid R2 pair - treat as single-end
            single_files+=("$r1_file")
            processed_files+=("$r1_file")
        fi
    done
    
    # Third pass: add remaining unprocessed files as single-end
    for file in "${all_files[@]}"; do
        local is_processed=false
        
        # Only iterate if processed_files is not empty
        if [ ${#processed_files[@]} -gt 0 ]; then
            for processed in "${processed_files[@]}"; do
                if [[ "$file" == "$processed" ]]; then
                    is_processed=true
                    break
                fi
            done
        fi
        
        if [[ "$is_processed" == false ]]; then
            single_files+=("$file")
        fi
    done
}

# Process paired-end FASTQ files with Bowtie2
# Arguments:
#   $1 - Input directory containing FASTQ files
#   $2 - Output directory for results
run_paired_fastq_manager() {
    local input_dir="$1"
    local output_dir="$2"

    # Check if there are paired files to process
    if [ ${#paired_files_r1[@]} -eq 0 ]; then
        log_message "No paired-end FASTQ files found."
        return 0
    fi

    log_message_header "Found ${#paired_files_r1[@]} paired FASTQ file sets to process"

    # Print brief information for each file pair
    log_message "FASTQ file pairs:"
    for ((i=0; i<${#paired_files_r1[@]}; i++)); do
        local r1_file="${paired_files_r1[$i]}"
        local r2_file="${paired_files_r2[$i]}"
        local r1_name=$(basename "$r1_file")
        local r2_name=$(basename "$r2_file")
        log_message "     [$(($i+1))] $r1_name, $r2_name"
    done

    # Process each file pair
    local processed_count=0
    local failed_count=0
    local failed_files=()

    set +e
    for ((i=0; i<${#paired_files_r1[@]}; i++)); do
        local r1_file="${paired_files_r1[$i]}"
        local r2_file="${paired_files_r2[$i]}"
        
        if parse_result=$(parse_filename "$r1_file"); then
            read -r base_name extension parent_dir paired_file <<< "$parse_result"

            # Progress message with file count
            log_message_header "Processing paired FASTQ files $(($processed_count + $failed_count + 1))/${#paired_files_r1[@]}"
            log_message "Input files: $(basename "$r1_file"), $(basename "$r2_file")"

            # Process paired files
            if execute_paired_alignment "$r1_file" "$r2_file" "$base_name" "$output_dir"; then
                ((processed_count++))
            else
                failed_files+=("$(basename "$r1_file")")
                ((failed_count++))
            fi
        else
            log_error "Failed to parse filename: $(basename "$r1_file")"
            failed_files+=("$(basename "$r1_file")")
            ((failed_count++))
        fi
    done
    set -e

    log_message_header "Paired-end processing complete. Processed: $processed_count/${#paired_files_r1[@]} file pairs"
    if [ $failed_count -gt 0 ]; then
        log_message_header "Warning: Some paired files were not processed successfully."
        log_message "Failed file pairs ($failed_count):"
        for failed_file in "${failed_files[@]}"; do
            log_message "     - $failed_file"
        done
    fi
}

# Process single-end FASTQ files with Bowtie2
# Arguments:
#   $1 - Input directory containing FASTQ files
#   $2 - Output directory for results
run_single_fastq_manager() {
    local input_dir="$1"
    local output_dir="$2"

    # Check if there are single files to process
    if [ ${#single_files[@]} -eq 0 ]; then
        log_message "No single-end FASTQ files found."
        return 0
    fi

    log_message_header "Found ${#single_files[@]} single-end FASTQ files to process"

    # Print brief information for each single file
    log_message "Single-end FASTQ files:"
    for ((i=0; i<${#single_files[@]}; i++)); do
        local file="${single_files[$i]}"
        local file_name=$(basename "$file")
        log_message "     [$(($i+1))] $file_name"
    done

    # Process each single file
    local processed_count=0
    local failed_count=0
    local failed_files=()

    set +e
    for ((i=0; i<${#single_files[@]}; i++)); do
        local file="${single_files[$i]}"
        local file_name=$(basename "$file")

        # Progress message with file count
        log_message_header "Processing single-end FASTQ file $(($processed_count + $failed_count + 1))/${#single_files[@]}"
        log_message "Input file: $file_name"

        if execute_single_alignment "$file" "$output_dir"; then
            ((processed_count++))
        else
            failed_files+=("$file_name")
            ((failed_count++))
        fi
    done
    set -e

    log_message_header "Single-end processing complete. Processed: $processed_count/${#single_files[@]} files"
    if [ $failed_count -gt 0 ]; then
        log_message_header "Warning: Some single files were not processed successfully."
        log_message "Failed files ($failed_count):"
        for failed_file in "${failed_files[@]}"; do
            log_message "     - $failed_file"
        done
    fi
}

# Process paired-end and single-end FASTQ files
# Arguments:
#   $1 - Input directory containing FASTQ files
#   $2 - Output directory for results
# Returns:
#   Exits with error code 1 if no input files found
run_manager() {
    local input_dir="$1"
    local output_dir="$2"

    # Classify all FASTQ files
    log_message_header "Classifying FASTQ files..."
    classify_fastq_files "$input_dir"
    
    # Log classification results
    local total_files=$((${#paired_files_r1[@]} + ${#single_files[@]}))
    log_message "Classification complete:"
    log_message "     - Paired-end files: ${#paired_files_r1[@]} pairs"
    log_message "     - Single-end files: ${#single_files[@]} files"
    log_message "     - Total files to process: $total_files files"
    
    # Exit if no files found
    if [ $total_files -eq 0 ]; then
        log_error_critical "No FASTQ files found in $input_dir"
    fi

    # Process paired FASTQ files
    run_paired_fastq_manager "$input_dir" "$output_dir"
    
    # Process single FASTQ files
    run_single_fastq_manager "$input_dir" "$output_dir"
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
    # NOTE: post_process_bam is validated and standardized to 'true' or 'false' in validate_parameters
    log_message "Post-process BAM (Sort/Index): $post_process_bam" 
    log_message "Threads: $threads (requested $threads_requested, allocated $allocated_threads)"
    if [ "$threads_capped" = 1 ]; then
        echo "WARNING: threads=$threads_requested requested, allocated cores: $allocated_threads; using $threads" >&2
    fi

    # Validate parameters
    validate_parameters
    
    # Build index if needed
    build_index_if_needed "$ref_genome"

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

# Execute main function with all arguments passed to the script
main "$@"
