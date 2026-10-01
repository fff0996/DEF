#!/usr/bin/env Rscript

# ============================================================================
# Differential Accessibility Analysis for ATAC-seq
# NBIS Epigenomics Workshop 2025 style (edgeR-based)
# Container: bx_atac_da:0.1.0
# ============================================================================
#
# Usage:
# Rscript differential_accessibility.r \
#   sample_data="..." \
#   genome_fasta="..." \
#   output_dir="..." \
#   [input_dir="..."]              # required only in BX-basic mode
#   [peak_dir="..."]               # required only in BX-basic mode
#   [control_name="..."]           # baseline (denominator/reference) condition; default = "control"
#   [fdr="0.05"] \
#   [gc_bin_chr=""] \
#   [tile_width="5000"] \
#   [paired="TRUE"] \
#   [run_edaseq="TRUE"] \
#   [run_cqn="TRUE"]
#
# Sample sheet (CSV) - either of two formats works:
#
#   (A) DiffBind-compatible: bamReads and Peaks columns present
#       SampleID,Condition,bamReads,Peaks
#       [optional extra columns are ignored: Tissue,Factor,Treatment,ControlID,bamControl,PeakCaller,...]
#       -> file paths used directly from sample sheet
#       -> input_dir / peak_dir not needed
#
#   (B) BX-basic: only metadata, no file paths
#       SampleID,Condition
#       -> input_dir / peak_dir required
#       -> BAMs and peaks matched by SampleID via substring match
#
# Method:
#   1. Merge per-sample peaks -> consensus peak set (GenomicRanges::reduce)
#   2. Count reads per consensus peak per BAM (bamsignals)
#   3. Compute GC content per peak (Biostrings)
#   4. Diagnose GC bias: in genomic bins (smoothScatter) and in peaks (hexbin + lowess)
#   5. edgeR DGEList + filterByExpr + TMM normalisation
#   6. MDS plot, MD plot, log2FC vs GC bin (violin+boxplot, Zissou1)
#   7. (optional) EDASeq full-quantile and CQN GC-aware normalisations
# ============================================================================

stop_err <- function(...) {
	msg <- paste(..., collapse = "")
	cat("ERROR:", msg, "\n", file = stderr())
	quit(status = 1)
}

# ------------------------------------------------------------
# Parse key=value arguments
# ------------------------------------------------------------
args <- commandArgs(TRUE)

for (arg in args) {
	if (grepl("=", arg, fixed = TRUE)) {
		parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
		key <- parts[1]
		value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
		
		value <- sub('^"(.*)"$', "\\1", value)
		value <- sub("^'(.*)'$", "\\1", value)
		
		if (!grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", key)) {
			stop_err("Invalid key: ", key)
		}
		
		assign(key, value)
	} else {
		stop_err("Invalid argument format: ", arg, " (must be key=value format)")
	}
}

# ------------------------------------------------------------
# Required parameters
# ------------------------------------------------------------
if (!exists("sample_data"))  stop_err("Required parameter 'sample_data' is missing")
if (!exists("genome_fasta")) stop_err("Required parameter 'genome_fasta' is missing")
if (!exists("output_dir"))   stop_err("Required parameter 'output_dir' is missing")

# Optional parameters
# input_dir / peak_dir are required ONLY in BX-basic mode (sample sheet without bamReads/Peaks).
# In DiffBind-compatible mode (sample sheet has bamReads/Peaks columns), they are ignored.
if (!exists("input_dir"))           input_dir <- ""
if (!exists("peak_dir"))            peak_dir <- ""
if (!exists("fdr"))                 fdr <- "0.05"
if (!exists("gc_bin_chr"))          gc_bin_chr <- ""
if (!exists("tile_width"))          tile_width <- "5000"
if (!exists("paired"))              paired <- "TRUE"
if (!exists("run_edaseq"))          run_edaseq <- "TRUE"
if (!exists("run_cqn"))             run_cqn <- "TRUE"
# Contrast direction:
#   - control_name = baseline (denominator/reference). Default "control" (matches DESeq2 module).
#   - The other of the two conditions is automatically the contrast (numerator).
#   - logFC = log2(contrast / control_name)
if (!exists("control_name") || is.na(control_name) || control_name == "") {
	control_name <- "control"
}
control_name <- as.character(control_name)

fdr <- as.numeric(fdr)
if (is.na(fdr) || fdr <= 0 || fdr > 1) {
	stop_err("fdr must be a number between 0 and 1")
}

tile_width <- as.integer(tile_width)
if (is.na(tile_width) || tile_width <= 0) {
	stop_err("tile_width must be a positive integer")
}

paired_logical     <- toupper(paired)     %in% c("TRUE", "T", "YES", "1")
run_edaseq_logical <- toupper(run_edaseq) %in% c("TRUE", "T", "YES", "1")
run_cqn_logical    <- toupper(run_cqn)    %in% c("TRUE", "T", "YES", "1")

# ------------------------------------------------------------
# Input path validation
# ------------------------------------------------------------
if (!file.exists(sample_data))  stop_err("sample_data not found: ", sample_data)
if (!file.exists(genome_fasta)) stop_err("genome_fasta not found: ", genome_fasta)

sample_data  <- normalizePath(sample_data, mustWork = TRUE)
genome_fasta <- normalizePath(genome_fasta, mustWork = TRUE)

# input_dir / peak_dir: normalize only if provided; validate later in Step 2 based on mode
if (nchar(input_dir) > 0) {
	if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
	input_dir <- normalizePath(input_dir, mustWork = TRUE)
}
if (nchar(peak_dir) > 0) {
	if (!dir.exists(peak_dir)) stop_err("peak_dir not found: ", peak_dir)
	peak_dir <- normalizePath(peak_dir, mustWork = TRUE)
}

# ------------------------------------------------------------
# Clean output directory first except logs/
# ------------------------------------------------------------
if (dir.exists(output_dir) && normalizePath(output_dir, mustWork = FALSE) != "/") {
	files_to_remove <- list.files(
			output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE
	)
	files_to_remove <- files_to_remove[basename(files_to_remove) != "logs"]
	if (length(files_to_remove) > 0) {
		unlink(files_to_remove, recursive = TRUE, force = TRUE)
	}
}

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
if (!dir.exists(output_dir)) stop_err("failed to create output_dir: ", output_dir)
output_dir <- normalizePath(output_dir, mustWork = TRUE)

logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE, recursive = TRUE)
if (!dir.exists(logs_dir)) stop_err("failed to create logs directory: ", logs_dir)

log_file <- file.path(
		logs_dir,
		paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")
)

# ------------------------------------------------------------
# Logging
# stdout goes to log + console. stderr is not sinked, so ERROR messages
# go to sys.err and remain visible to the qsub wrapper.
# ------------------------------------------------------------
log_con <- file(log_file, open = "at")
sink(log_con, append = TRUE, split = TRUE)

on.exit({
			try(sink(), silent = TRUE)
			try(close(log_con), silent = TRUE)
		}, add = TRUE)

cat("############################## Differential Accessibility Analysis (NBIS style)\n")
cat("Log file   :", log_file, "\n")
cat("Start time :", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# ------------------------------------------------------------
# Package check
# ------------------------------------------------------------
cat("checking required R packages...\n")

required_packages <- c(
		"edgeR", "limma", "ggplot2",
		"Biostrings", "GenomicRanges", "IRanges", "GenomeInfoDb",
		"Hmisc", "hexbin", "bamsignals"
)

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		stop_err("required R package not found: ", pkg)
	}
}

suppressMessages(library(edgeR))
suppressMessages(library(limma))
suppressMessages(library(ggplot2))
suppressMessages(library(Biostrings))
suppressMessages(library(GenomicRanges))
suppressMessages(library(IRanges))
suppressMessages(library(GenomeInfoDb))
suppressMessages(library(Hmisc))
suppressMessages(library(hexbin))
suppressMessages(library(bamsignals))

# Optional packages (graceful skip if missing)
has_edaseq      <- requireNamespace("EDASeq", quietly = TRUE)
has_cqn         <- requireNamespace("cqn", quietly = TRUE)
has_wesanderson <- requireNamespace("wesanderson", quietly = TRUE)

if (has_edaseq)      suppressMessages(library(EDASeq))
if (has_cqn)         suppressMessages(library(cqn))
if (has_wesanderson) suppressMessages(library(wesanderson))

cat("optional packages available:\n")
cat("  EDASeq      =", has_edaseq, "\n")
cat("  cqn         =", has_cqn, "\n")
cat("  wesanderson =", has_wesanderson, "\n\n")

cat("All required R packages loaded successfully.\n\n")

cat("parameters:\n")
cat("  input_dir    =", ifelse(nchar(input_dir) == 0, "<unset>", input_dir), "\n")
cat("  peak_dir     =", ifelse(nchar(peak_dir) == 0, "<unset>", peak_dir), "\n")
cat("  sample_data  =", sample_data, "\n")
cat("  genome_fasta =", genome_fasta, "\n")
cat("  output_dir   =", output_dir, "\n")
cat("  fdr          =", fdr, "\n")
cat("  gc_bin_chr   =", ifelse(nchar(gc_bin_chr) == 0, "<auto>", gc_bin_chr), "\n")
cat("  tile_width   =", tile_width, "\n")
cat("  paired       =", paired_logical, "\n")
cat("  run_edaseq   =", run_edaseq_logical && has_edaseq, "\n")
cat("  run_cqn      =", run_cqn_logical && has_cqn, "\n")
cat("  control_name =", control_name, "\n\n")
# ------------------------------------------------------------
# Output subdirectories
# ------------------------------------------------------------
sample_sheet_dir <- file.path(output_dir, "01_sample_sheet")
counts_dir       <- file.path(output_dir, "02_counts")
result_dir       <- file.path(output_dir, "03_results")
plot_dir         <- file.path(output_dir, "04_plots")
rds_dir          <- file.path(output_dir, "05_rds")

dir.create(sample_sheet_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(counts_dir,       showWarnings = FALSE, recursive = TRUE)
dir.create(result_dir,       showWarnings = FALSE, recursive = TRUE)
dir.create(plot_dir,         showWarnings = FALSE, recursive = TRUE)
dir.create(rds_dir,          showWarnings = FALSE, recursive = TRUE)

# Output file paths
prepared_sample_sheet <- file.path(sample_sheet_dir, "prepared_sample_sheet.csv")

consensus_peak_bed <- file.path(counts_dir, "consensus_peaks.bed")
count_table_tsv    <- file.path(counts_dir, "peak_count_matrix.tsv")
peak_gc_tsv        <- file.path(counts_dir, "peak_gc_content.tsv")

diff_csv_tmm       <- file.path(result_dir, "diff_accessibility_TMM.csv")
diff_sig_csv_tmm   <- file.path(result_dir, "diff_accessibility_TMM_significant.csv")
downstream_tsv_tmm <- file.path(result_dir, "diff_accessibility_TMM_for_downstream.tsv")
diff_sig_bed       <- file.path(result_dir, "diff_accessibility_significant.bed")
up_bed             <- file.path(result_dir, "up_accessible_peaks.bed")
down_bed           <- file.path(result_dir, "down_accessible_peaks.bed")
diff_csv_eda       <- file.path(result_dir, "diff_accessibility_EDASeq.csv")
diff_csv_cqn       <- file.path(result_dir, "diff_accessibility_CQN.csv")

gc_bin_pdf     <- file.path(plot_dir, "GC_bias_in_genomic_bins.pdf")
gc_peaks_pdf   <- file.path(plot_dir, "GC_bias_in_peaks.pdf")
mds_pdf        <- file.path(plot_dir, "MDS_plot.pdf")
md_pdf         <- file.path(plot_dir, "MD_plot.pdf")
lfc_gc_tmm_pdf <- file.path(plot_dir, "logFC_by_GC_bin_TMM.pdf")
lfc_gc_eda_pdf <- file.path(plot_dir, "logFC_by_GC_bin_EDASeq.pdf")
lfc_gc_cqn_pdf <- file.path(plot_dir, "logFC_by_GC_bin_CQN.pdf")

dge_tmm_rds <- file.path(rds_dir, "edger_dgelist_tmm.rds")
qlf_tmm_rds <- file.path(rds_dir, "edger_qlf_test_tmm.rds")
qlf_eda_rds <- file.path(rds_dir, "edger_qlf_test_edaseq.rds")
qlf_cqn_rds <- file.path(rds_dir, "edger_qlf_test_cqn.rds")

# ------------------------------------------------------------
# Step 1. Read and validate sample sheet
# ------------------------------------------------------------
cat("############################## Step 1: Read sample sheet\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

ss <- tryCatch(
		read.csv(sample_data, stringsAsFactors = FALSE, check.names = FALSE),
		error = function(e) stop_err("failed to read sample_data: ", e$message)
)

cat("sample_data shape:\n")
cat("  rows x columns:", nrow(ss), "x", ncol(ss), "\n")
cat("  columns:", paste(colnames(ss), collapse = ", "), "\n\n")
cat("preview:\n")
print(head(ss))
cat("\n")

if (nrow(ss) == 0) stop_err("sample_data has zero rows")

required_cols <- c("SampleID", "Condition")
missing_cols <- setdiff(required_cols, colnames(ss))
if (length(missing_cols) > 0) {
	stop_err(
			"sample_data is missing required columns: ",
			paste(missing_cols, collapse = ", "),
			". Required format: SampleID,Condition"
	)
}

if (any(is.na(ss$SampleID)) || any(trimws(ss$SampleID) == "")) {
	stop_err("SampleID contains empty values")
}
if (any(is.na(ss$Condition)) || any(trimws(ss$Condition) == "")) {
	stop_err("Condition contains empty values")
}
if (any(duplicated(ss$SampleID))) {
	dup_ids <- unique(ss$SampleID[duplicated(ss$SampleID)])
	stop_err("duplicated SampleID values found: ", paste(dup_ids, collapse = ", "))
}

cat("condition table:\n")
print(table(ss$Condition))
cat("\n")

n_conditions <- length(unique(ss$Condition))
if (n_conditions != 2) {
	stop_err(
			"exactly 2 conditions are required for differential accessibility analysis, ",
			"but found ", n_conditions,
			" (", paste(unique(ss$Condition), collapse = ", "), "). ",
			"Multi-group ANOVA-style tests are not supported in this module. ",
			"Subset your sample_data to two conditions, or run multiple pairwise comparisons separately."
	)
}

condition_counts <- table(ss$Condition)
has_replicates <- all(condition_counts >= 2)

cat("condition counts:\n")
print(condition_counts)
cat("\n")

if (!has_replicates) {
	cat(
			"WARNING: fewer than 2 samples were found in at least one condition.\n",
			"Biological variability cannot be estimated from this design.\n",
			"Significance testing will be skipped.\n",
			"Descriptive MDS and fold-change analysis will be performed instead.\n\n",
			sep = ""
	)
}

# ------------------------------------------------------------
# Step 2. Resolve BAM and peak files (DiffBind-compat OR BX-basic mode)
# ------------------------------------------------------------
cat("############################## Step 2: Resolve BAM and peak files\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

# Mode detection: DiffBind-compatible if bamReads AND Peaks are both columns
has_diffbind_paths <- all(c("bamReads", "Peaks") %in% colnames(ss))

cat("sample sheet mode:\n")
if (has_diffbind_paths) {
	cat("  DiffBind-compatible: bamReads and Peaks columns detected in sample_data\n")
	cat("  -> file paths from sample_data are used directly\n")
	cat("  -> input_dir / peak_dir (if provided) are ignored\n")
	if ("bamControl" %in% colnames(ss)) {
		cat("  -> bamControl column present but ignored (no input subtraction in this module)\n")
	}
	cat("\n")
	
	resolve_path <- function(x, base_dir) {
		if (is.na(x) || trimws(x) == "") return(NA_character_)
		if (grepl("^/", x)) return(normalizePath(x, mustWork = FALSE))
		normalizePath(file.path(base_dir, x), mustWork = FALSE)
	}
	
	sample_base_dir <- dirname(sample_data)
	cat("  relative paths resolved from:", sample_base_dir, "\n\n")
	
	ss$bamReads <- vapply(ss$bamReads, resolve_path, character(1),
			base_dir = sample_base_dir)
	ss$Peaks <- vapply(ss$Peaks, resolve_path, character(1),
			base_dir = sample_base_dir)
	
	bam_exists  <- file.exists(ss$bamReads)
	peak_exists <- file.exists(ss$Peaks)
	
	cat("file existence check:\n")
	cat("  bamReads exist:", sum(bam_exists),  "/", length(bam_exists),  "\n")
	cat("  Peaks exist   :", sum(peak_exists), "/", length(peak_exists), "\n\n")
	
	if (!all(bam_exists)) {
		cat("missing bamReads files:\n")
		print(ss$bamReads[!bam_exists])
		cat("\n")
		stop_err("missing one or more bamReads files")
	}
	if (!all(peak_exists)) {
		cat("missing Peaks files:\n")
		print(ss$Peaks[!peak_exists])
		cat("\n")
		stop_err("missing one or more Peaks files")
	}
	
	ss$bamReads <- normalizePath(ss$bamReads, mustWork = TRUE)
	ss$Peaks    <- normalizePath(ss$Peaks,    mustWork = TRUE)
	
} else {
	cat("  BX-basic: bamReads / Peaks columns NOT in sample_data\n")
	cat("  -> BAM and peak files will be matched by SampleID from input_dir / peak_dir\n\n")
	
	if (nchar(input_dir) == 0) {
		stop_err("BX-basic mode requires input_dir (sample_data has no bamReads column)")
	}
	if (nchar(peak_dir) == 0) {
		stop_err("BX-basic mode requires peak_dir (sample_data has no Peaks column)")
	}
	
	match_one_file <- function(sample_id, files, file_type) {
		base <- basename(files)
		hit <- files[grepl(paste0("^", sample_id, "([._-]|$)"), base)]
		if (length(hit) == 0) hit <- files[grepl(sample_id, base, fixed = TRUE)]
		if (length(hit) == 0) hit <- files[grepl(sample_id, base, ignore.case = TRUE)]
		
		if (length(hit) == 0) {
			cat("No", file_type, "file matched for SampleID:", sample_id, "\n")
			return(NA_character_)
		}
		if (length(hit) > 1) {
			cat("Multiple", file_type, "files matched for SampleID:", sample_id, "\n")
			print(hit)
			return(NA_character_)
		}
		normalizePath(hit, mustWork = TRUE)
	}
	
	# If input_dir is an ATAC_QC output directory, use only shifted BAMs
	# from input_dir/03_shifted_bam. This prevents DA from accidentally using
	# 02_bam_qc/*.clean.bam or 04_split_bam/*.bam when the whole previous-module
	# output directory is passed by the workflow engine.
	if (dir.exists(file.path(input_dir, "03_shifted_bam"))) {
		bam_search_dir <- normalizePath(file.path(input_dir, "03_shifted_bam"), mustWork = TRUE)
		bam_pattern <- "\\.shifted\\.bam$"
		cat("  Detected ATAC_QC output directory. Using shifted BAMs from:\n")
		cat("   ", bam_search_dir, "\n\n")
	} else {
		bam_search_dir <- input_dir
		bam_pattern <- "\\.bam$"
	}
	
	bam_files <- list.files(
			bam_search_dir, pattern = bam_pattern,
			full.names = TRUE, recursive = TRUE, ignore.case = TRUE
	)
	bam_files <- bam_files[
			!grepl("\\.bai$", bam_files, ignore.case = TRUE) &
					!grepl("unsorted\\.bam$", bam_files, ignore.case = TRUE)
	]
	
	# Accept only narrowPeak / broadPeak (with optional .gz). This intentionally
	# excludes generic .bed files such as MACS *_summits.bed, which would
	# otherwise cause multi-match against the corresponding *_peaks.narrowPeak.
	peak_files <- list.files(
			peak_dir,
			pattern = "(\\.narrowPeak$|\\.narrowPeak\\.gz$|\\.broadPeak$|\\.broadPeak\\.gz$)",
			full.names = TRUE, recursive = TRUE, ignore.case = TRUE
	)
	
	cat("BAM search:\n")
	cat("  input_dir =", input_dir, "\n")
	cat("  bam_search_dir =", bam_search_dir, "\n")
	cat("  BAM files =", length(bam_files), "\n\n")
	if (length(bam_files) > 0) {
		print(bam_files); cat("\n")
	}
	
	cat("Peak search:\n")
	cat("  peak_dir =", peak_dir, "\n")
	cat("  peak files =", length(peak_files), "\n\n")
	if (length(peak_files) > 0) {
		print(peak_files); cat("\n")
	}
	
	if (length(bam_files) == 0) stop_err("No BAM files found in BAM search directory: ", bam_search_dir)
	if (length(peak_files) == 0) {
		stop_err(
				"No peak files found in peak_dir: ", peak_dir,
				". Accepted: *.narrowPeak[.gz], *.broadPeak[.gz]"
		)
	}
	
	ss$bamReads <- vapply(ss$SampleID, match_one_file, character(1),
			files = bam_files, file_type = "BAM")
	ss$Peaks <- vapply(ss$SampleID, match_one_file, character(1),
			files = peak_files, file_type = "peak")
	
	if (any(is.na(ss$bamReads))) {
		cat("failed BAM matching rows:\n")
		print(ss[is.na(ss$bamReads), c("SampleID", "Condition")])
		cat("\n")
		stop_err("failed to match one or more SampleID values to BAM files")
	}
	if (any(is.na(ss$Peaks))) {
		cat("failed peak matching rows:\n")
		print(ss[is.na(ss$Peaks), c("SampleID", "Condition")])
		cat("\n")
		stop_err("failed to match one or more SampleID values to peak files")
	}
}

# BAM index check (common to both modes)
bam_index_exists <- file.exists(paste0(ss$bamReads, ".bai")) |
		file.exists(sub("\\.bam$", ".bai", ss$bamReads, ignore.case = TRUE))
cat("BAM index exist:", sum(bam_index_exists), "/", length(bam_index_exists), "\n\n")
if (!all(bam_index_exists)) {
	cat("missing BAM index files for:\n")
	print(ss$bamReads[!bam_index_exists])
	cat("\n")
	stop_err("missing BAM index files. Please index BAM files first (samtools index).")
}

write.csv(ss, prepared_sample_sheet, row.names = FALSE, quote = FALSE)
cat("prepared sample sheet:\n  ", prepared_sample_sheet, "\n\n")

# ------------------------------------------------------------
# Step 3. Read genome FASTA
# ------------------------------------------------------------
cat("############################## Step 3: Read genome FASTA\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

genome <- tryCatch(
		Biostrings::readDNAStringSet(genome_fasta),
		error = function(e) stop_err("failed to read genome_fasta: ", e$message)
)

# Use first whitespace token as chromosome name
names(genome) <- sub("\\s.*$", "", names(genome))

genome_seqlengths <- width(genome)
names(genome_seqlengths) <- names(genome)

cat("genome sequence count:", length(genome), "\n")
cat("genome sequence name preview (first 20):\n")
print(head(names(genome), 20))
cat("\n")
cat("genome sequence length preview (first 10):\n")
print(head(genome_seqlengths, 10))
cat("\n")

# ------------------------------------------------------------
# Step 4. Build consensus peak set
# ------------------------------------------------------------
cat("############################## Step 4: Build consensus peak set\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

read_peak_file <- function(path) {
	# read.table() accepts a path directly and auto-handles .gz transparently
	# (no manual connection management needed, so connections cannot accumulate)
	df <- tryCatch(
			read.table(path, sep = "\t", header = FALSE, stringsAsFactors = FALSE,
					comment.char = "#", quote = ""),
			error = function(e) stop_err("failed to read peak file: ", path, " | ", e$message)
	)
	if (ncol(df) < 3) stop_err("peak file has fewer than 3 columns: ", path)
	GenomicRanges::GRanges(
			seqnames = as.character(df[, 1]),
			ranges = IRanges::IRanges(
					start = as.integer(df[, 2]) + 1L,
					end = as.integer(df[, 3])
			),
			strand = "*"
	)
}

cat("reading per-sample peak files:\n")
per_sample_peaks <- lapply(seq_len(nrow(ss)), function(i) {
			gr <- read_peak_file(ss$Peaks[i])
			cat("  ", ss$SampleID[i], ":", length(gr), "peaks\n")
			gr
		})
cat("\n")

all_peaks_gr <- do.call(c, per_sample_peaks)
consensus_peaks <- GenomicRanges::reduce(all_peaks_gr)

cat("union of all sample peaks (before chromosome filtering):", length(consensus_peaks), "\n")

# Keep only peaks on chromosomes present in genome
chrom_in_genome <- as.character(seqnames(consensus_peaks)) %in% names(genome)
n_dropped <- sum(!chrom_in_genome)
consensus_peaks <- consensus_peaks[chrom_in_genome]

cat("peaks on assembled chromosomes:", length(consensus_peaks),
		"(dropped", n_dropped, "peaks on unknown chromosomes)\n")

# Clip peak ends to chromosome lengths
seqlevels(consensus_peaks) <- intersect(seqlevels(consensus_peaks), names(genome))
GenomeInfoDb::seqlengths(consensus_peaks) <- genome_seqlengths[seqlevels(consensus_peaks)]
consensus_peaks <- GenomicRanges::trim(consensus_peaks)

# Stable peak IDs
peak_ids <- paste0("peak_", sprintf("%07d", seq_along(consensus_peaks)))
mcols(consensus_peaks)$peakID <- peak_ids
names(consensus_peaks) <- peak_ids

cat("final consensus peak count:", length(consensus_peaks), "\n\n")

if (length(consensus_peaks) == 0) {
	cat("DIAGNOSTIC - chromosome naming check:\n")
	cat("  genome FASTA chromosomes (first 20):\n")
	print(head(names(genome), 20))
	cat("\n  peak file chromosomes (first 20):\n")
	print(head(unique(as.character(seqnames(all_peaks_gr))), 20))
	cat("\n")
	stop_err(
			"no consensus peaks remain after filtering by genome chromosomes. ",
			"Most likely a chromosome naming mismatch between peak files and genome_fasta ",
			"(e.g. peak file uses '1' but genome FASTA uses 'Chr1', or vice versa). ",
			"Compare the two lists above and re-run with matching names."
	)
}

# Export consensus peak BED
bed_df <- data.frame(
		chr = as.character(seqnames(consensus_peaks)),
		start = start(consensus_peaks) - 1L,
		end = end(consensus_peaks),
		name = peak_ids,
		score = 0,
		strand = "."
)
write.table(bed_df, consensus_peak_bed, sep = "\t", quote = FALSE,
		row.names = FALSE, col.names = FALSE)
cat("consensus peak BED:\n  ", consensus_peak_bed, "\n\n")

# ------------------------------------------------------------
# Step 5. Compute GC content per peak
# ------------------------------------------------------------
cat("############################## Step 5: Compute GC content per peak\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

gc_content_for_regions <- function(gr, genome) {
	chrs <- as.character(seqnames(gr))
	st <- start(gr)
	en <- end(gr)
	
	gc <- rep(NA_real_, length(gr))
	uniq_chrs <- unique(chrs)
	
	for (ch in uniq_chrs) {
		if (!ch %in% names(genome)) next
		idx <- which(chrs == ch)
		chrom_seq <- genome[[ch]]
		chrom_len <- length(chrom_seq)
		
		st_i <- pmax(1L, st[idx])
		en_i <- pmin(chrom_len, en[idx])
		valid <- st_i <= en_i
		
		if (any(valid)) {
			views <- Biostrings::Views(chrom_seq,
					start = st_i[valid], end = en_i[valid])
			lf <- Biostrings::letterFrequency(views, "GC", as.prob = TRUE)[, 1]
			gc[idx[valid]] <- lf
		}
	}
	gc
}

peak_gc <- gc_content_for_regions(consensus_peaks, genome)
peak_gc_lookup <- setNames(peak_gc, peak_ids)
mcols(consensus_peaks)$gc <- peak_gc

cat("GC content computed for", sum(!is.na(peak_gc)), "/", length(peak_gc), "peaks\n")
cat("GC content summary:\n")
print(summary(peak_gc))
cat("\n")

gc_df <- data.frame(
		peakID = peak_ids,
		chr = as.character(seqnames(consensus_peaks)),
		start = start(consensus_peaks),
		end = end(consensus_peaks),
		width = width(consensus_peaks),
		gc = peak_gc,
		stringsAsFactors = FALSE
)
write.table(gc_df, peak_gc_tsv, sep = "\t", quote = FALSE, row.names = FALSE)
cat("peak GC table:\n  ", peak_gc_tsv, "\n\n")

# ------------------------------------------------------------
# Step 6. Count reads in consensus peaks (bamsignals)
# ------------------------------------------------------------
cat("############################## Step 6: Count reads in consensus peaks\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

count_reads_in_regions <- function(bam_path, regions, paired) {
	pe_mode <- if (paired) "filter" else "ignore"
	bamsignals::bamCount(
			bam_path, regions,
			paired.end = pe_mode,
			verbose = FALSE
	)
}

cat("counting reads per sample (bamsignals, paired.end =",
		ifelse(paired_logical, "filter", "ignore"), "):\n")

count_list <- lapply(seq_len(nrow(ss)), function(i) {
			t0 <- Sys.time()
			cnts <- count_reads_in_regions(ss$bamReads[i], consensus_peaks, paired_logical)
			dt <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
			cat("  ", ss$SampleID[i], ": total =", sum(cnts),
					"| elapsed =", sprintf("%.1fs", dt), "\n")
			cnts
		})

count_mat <- do.call(cbind, count_list)
colnames(count_mat) <- ss$SampleID
rownames(count_mat) <- peak_ids

cat("\ncount matrix shape:", nrow(count_mat), "x", ncol(count_mat), "\n")
cat("library sizes (sum of counts per sample):\n")
print(colSums(count_mat))
cat("\n")

if (sum(count_mat) == 0) {
	cat("DIAGNOSTIC - all counts are zero. Likely causes:\n")
	cat("  (a) chromosome naming mismatch between BAM and consensus peaks\n")
	cat("      consensus peak chromosomes (first 20):\n")
	print(head(unique(as.character(seqnames(consensus_peaks))), 20))
	cat("      -> compare to BAM header via: samtools view -H <bam> | grep @SQ\n")
	cat("  (b) paired=", paired_logical,
			" but BAM is the other (paired single-end mismatch)\n", sep = "")
	cat("  (c) BAM and peaks were called against different reference assemblies\n\n")
	stop_err("count matrix is all zeros - see diagnostic above")
}

if (any(colSums(count_mat) == 0)) {
	zero_samples <- colnames(count_mat)[colSums(count_mat) == 0]
	stop_err(
			"the following samples have ZERO counts across all peaks: ",
			paste(zero_samples, collapse = ", "),
			". Check BAM <-> peak chromosome naming for these samples."
	)
}

# Export count matrix
count_df <- data.frame(
		peakID = peak_ids,
		chr = as.character(seqnames(consensus_peaks)),
		start = start(consensus_peaks),
		end = end(consensus_peaks),
		gc = peak_gc,
		count_mat,
		check.names = FALSE,
		stringsAsFactors = FALSE
)
write.table(count_df, count_table_tsv, sep = "\t",
		quote = FALSE, row.names = FALSE)
cat("count matrix table:\n  ", count_table_tsv, "\n\n")

# ------------------------------------------------------------
# Step 7. GC bias in genomic bins (smoothScatter, NBIS Fig 1)
# ------------------------------------------------------------
cat("############################## Step 7: GC bias in genomic bins\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

if (nchar(gc_bin_chr) == 0) {
	gc_bin_chr_use <- names(genome_seqlengths)[which.max(genome_seqlengths)]
	cat("auto-selected gc_bin_chr (longest chromosome):", gc_bin_chr_use, "\n")
} else {
	gc_bin_chr_use <- gc_bin_chr
}

if (!gc_bin_chr_use %in% names(genome)) {
	cat("WARNING: gc_bin_chr '", gc_bin_chr_use,
			"' not in genome. Skipping bin-level GC bias plot.\n", sep = "")
} else {
	chr_len <- genome_seqlengths[[gc_bin_chr_use]]
	tile_starts <- seq(1L, chr_len, by = tile_width)
	tile_ends <- pmin(tile_starts + tile_width - 1L, chr_len)
	tiles_gr <- GenomicRanges::GRanges(
			seqnames = gc_bin_chr_use,
			ranges = IRanges::IRanges(start = tile_starts, end = tile_ends),
			strand = "*"
	)
	cat("tiles on", gc_bin_chr_use, ":", length(tiles_gr),
			"bins of width", tile_width, "bp\n")
	
	tile_gc <- gc_content_for_regions(tiles_gr, genome)
	
	n_samp <- nrow(ss)
	ncol_grid <- max(2, ceiling(n_samp / 2))
	nrow_grid <- ceiling(n_samp / ncol_grid)
	
	pdf(gc_bin_pdf, width = 4 * ncol_grid, height = 4 * nrow_grid)
	par(mfrow = c(nrow_grid, ncol_grid),
			mar = c(4, 4, 3, 1), oma = c(0, 0, 2, 0))
	
	for (i in seq_len(nrow(ss))) {
		tile_counts <- tryCatch(
				count_reads_in_regions(ss$bamReads[i], tiles_gr, paired_logical),
				error = function(e) {
					message("tile counting failed for ", ss$SampleID[i], ": ", e$message)
					rep(NA_real_, length(tiles_gr))
				}
		)
		valid <- !is.na(tile_gc) & !is.na(tile_counts)
		if (any(valid)) {
			smoothScatter(
					tile_gc[valid], log2(tile_counts[valid] + 1),
					main = ss$SampleID[i],
					xlab = "GC content",
					ylab = "log2(counts + 1)"
			)
		} else {
			plot.new(); title(main = paste0(ss$SampleID[i], " (no data)"))
		}
	}
	mtext(paste0("Logcounts vs GC in genomic bins (", gc_bin_chr_use,
					", tile_width = ", tile_width, ")"),
			outer = TRUE, cex = 1.0)
	dev.off()
	
	cat("GC bias in bins plot:\n  ", gc_bin_pdf, "\n")
}
cat("\n")

# ------------------------------------------------------------
# Step 8. GC bias in peaks (hexbin + lowess per sample, NBIS Fig 2)
# ------------------------------------------------------------
cat("############################## Step 8: GC bias in peaks\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

valid_gc <- !is.na(peak_gc)

if (sum(valid_gc) < 50) {
	cat("WARNING: not enough peaks with valid GC for hexbin plot. Skipping.\n")
} else {
	# Lowess fit per sample
	lowListGC <- list()
	for (kk in seq_len(ncol(count_mat))) {
		set.seed(kk)
		samp_name <- colnames(count_mat)[kk]
		lowListGC[[samp_name]] <- tryCatch(
				lowess(
						x = peak_gc[valid_gc],
						y = log1p(count_mat[valid_gc, kk]),
						f = 1/10
				),
				error = function(e) {
					message("lowess failed for sample ", samp_name, ": ", e$message)
					NULL
				}
		)
	}
	
	# Build smoothed line dataframe
	dfList <- list()
	for (samp_name in names(lowListGC)) {
		lo <- lowListGC[[samp_name]]
		if (is.null(lo)) next
		oox <- order(lo$x)
		dfList[[samp_name]] <- data.frame(
				x = lo$x[oox], y = lo$y[oox], sample = samp_name,
				stringsAsFactors = FALSE
		)
	}
	dfAll <- do.call(rbind, dfList)
	dfAll$sample <- factor(dfAll$sample)
	
	# Hexbin background of mean counts
	mean_counts <- rowMeans(count_mat)
	hex_df <- data.frame(
			gc = peak_gc,
			mean_count = mean_counts
	)
	hex_df <- hex_df[!is.na(hex_df$gc), ]
	
	p_gc <- ggplot(hex_df, aes(x = gc, y = log(mean_count + 1))) +
			geom_hex(bins = 50) +
			ylab("log(count + 1)") +
			xlab("GC content") +
			labs(fill = "Nr. of peaks") +
			theme_bw() +
			theme(axis.title = element_text(size = 14)) +
			geom_line(
					data = dfAll,
					aes(x = x, y = y, group = sample, color = sample),
					linewidth = 1
			) +
			scale_color_discrete() +
			ggtitle("GC bias in peaks: mean log-counts vs GC content")
	
	ggsave(gc_peaks_pdf, p_gc, width = 10, height = 6)
	cat("GC bias in peaks plot:\n  ", gc_peaks_pdf, "\n")
}
cat("\n")

# ------------------------------------------------------------
# Step 9. edgeR DGEList + filterByExpr + TMM
# ------------------------------------------------------------
cat("############################## Step 9: edgeR DGEList + filterByExpr + TMM\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

groups_sheet_order <- unique(ss$Condition)

# Determine reference and contrast levels
# control_name = reference (denominator). The remaining condition is the contrast.
# Exactly 2 conditions are guaranteed by Step 1.
if (!control_name %in% groups_sheet_order) {
	stop_err(
			"control_name '", control_name,
			"' not found in sample_data Condition column. Available: ",
			paste(groups_sheet_order, collapse = ", "),
			". Set control_name to the condition you want as the baseline (denominator)."
	)
}
ref_level   <- control_name
treat_level <- setdiff(groups_sheet_order, control_name)
cat("baseline set by control_name.\n")

groups <- factor(ss$Condition, levels = c(ref_level, treat_level))

cat("contrast setup:\n")
cat("  reference (baseline) =", ref_level, "\n")
cat("  contrast  (treated)  =", treat_level, "\n")
cat("  -> logFC = log2(", treat_level, " / ", ref_level, ")\n", sep = "")
cat("  -> positive logFC = more accessible in ", treat_level, "\n", sep = "")
cat("  -> negative logFC = more accessible in ", ref_level, "\n\n", sep = "")

design <- model.matrix(~ groups)
rownames(design) <- ss$SampleID
cat("design matrix:\n")
print(design)
cat("\n")

reads_dge <- edgeR::DGEList(counts = count_mat, group = groups)
keep <- edgeR::filterByExpr(reads_dge)

cat("filterByExpr result:\n")
print(summary(keep))
cat("\n")

if (sum(keep) == 0) {
	stop_err(
			"filterByExpr removed ALL peaks (0 retained). ",
			"Possible causes: read counts too low across all samples, ",
			"library sizes too small, or unbalanced groups. ",
			"Inspect peak_count_matrix.tsv to diagnose."
	)
}

reads_dge_filt <- reads_dge[keep, , keep.lib.sizes = FALSE]
cat("after filtering:", nrow(reads_dge_filt), "peaks retained\n\n")

reads_dge_tmm <- edgeR::normLibSizes(reads_dge_filt)
cat("norm factors (TMM):\n")
print(reads_dge_tmm$samples)
cat("\n")

saveRDS(reads_dge_tmm, dge_tmm_rds)
cat("DGEList RDS:\n  ", dge_tmm_rds, "\n\n")

# ------------------------------------------------------------
# Step 10. MDS plot (NBIS Fig 3)
# ------------------------------------------------------------
cat("############################## Step 10: MDS plot\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

if (ncol(reads_dge_tmm) < 3) {
	cat(
			"MDS plot skipped: Only ", ncol(reads_dge_tmm),
			" columns of data; need at least 3 samples.\n\n",
			sep = ""
	)
} else {
	mds_ok <- FALSE
	pdf(mds_pdf, width = 7, height = 6)
	tryCatch({
				col_vec <- as.integer(groups)
				limma::plotMDS(
						reads_dge_tmm,
						labels = colnames(reads_dge_tmm),
						col = col_vec
				)
				legend("topright", legend = levels(groups),
						text.col = seq_along(levels(groups)), bty = "n")
				mds_ok <- TRUE
			},
			error = function(e) {
				message("MDS plot skipped: ", e$message)
			}
	)
	dev.off()
	
	if (mds_ok) {
		cat("MDS plot:\n  ", mds_pdf, "\n\n")
	} else if (file.exists(mds_pdf)) {
		unlink(mds_pdf, force = TRUE)
	}
}

# ------------------------------------------------------------
# Step 11. Statistical or descriptive analysis with TMM
# ------------------------------------------------------------
cat("############################## Step 11: TMM accessibility analysis\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

run_edger_de <- function(dge, design, contrast_coef = 2) {
	dge  <- edgeR::estimateDisp(dge, design)
	fit  <- edgeR::glmQLFit(dge, design, robust = TRUE)
	test <- edgeR::glmQLFTest(fit, coef = contrast_coef)
	tt   <- as.data.frame(edgeR::topTags(test, n = nrow(test$table)))
	tt$peakID <- rownames(tt)
	
	list(
			dge = dge,
			fit = fit,
			test = test,
			tt = tt,
			mode = "statistical"
	)
}

run_descriptive_fc <- function(dge, groups, ref_level, treat_level) {
	log_cpm <- edgeR::cpm(
			dge,
			log = TRUE,
			prior.count = 1,
			normalized.lib.sizes = TRUE
	)
	
	ref_cols   <- which(groups == ref_level)
	treat_cols <- which(groups == treat_level)
	
	ref_mean   <- rowMeans(log_cpm[, ref_cols, drop = FALSE])
	treat_mean <- rowMeans(log_cpm[, treat_cols, drop = FALSE])
	
	tt <- data.frame(
			logFC = treat_mean - ref_mean,
			logCPM = rowMeans(log_cpm),
			PValue = NA_real_,
			FDR = NA_real_,
			peakID = rownames(log_cpm),
			stringsAsFactors = FALSE
	)
	
	tt <- tt[order(abs(tt$logFC), decreasing = TRUE), ]
	
	list(
			dge = dge,
			fit = NULL,
			test = NULL,
			tt = tt,
			mode = "descriptive_no_replicate"
	)
}

if (has_replicates) {
	cat("analysis mode: statistical edgeR QL analysis\n\n")
	
	res_tmm <- run_edger_de(
			reads_dge_tmm,
			design,
			contrast_coef = 2
	)
	
	cat("DA result preview (TMM):\n")
	print(head(res_tmm$tt))
	cat("\n")
	
	cat(
			"number of significant peaks (FDR <= ", fdr, "): ",
			sum(res_tmm$tt$FDR <= fdr, na.rm = TRUE),
			"\n\n",
			sep = ""
	)
	
	saveRDS(res_tmm$test, qlf_tmm_rds)
	
} else {
	cat("analysis mode: descriptive analysis without replicates\n")
	cat("significance testing: skipped\n")
	cat("reported statistics: logCPM and logFC only\n\n")
	
	res_tmm <- run_descriptive_fc(
			reads_dge_tmm,
			groups,
			ref_level,
			treat_level
	)
	
	cat("descriptive result preview (TMM):\n")
	print(head(res_tmm$tt))
	cat("\n")
}
# ------------------------------------------------------------
# Step 12. MD plot (NBIS Fig 4)
# ------------------------------------------------------------
cat("############################## Step 12: MD plot\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

pdf(md_pdf, width = 7, height = 6)

tryCatch({
			if (has_replicates) {
				limma::plotMD(res_tmm$test)
				abline(h = 0, col = "red", lty = 2)
			} else {
				plot(
						res_tmm$tt$logCPM,
						res_tmm$tt$logFC,
						pch = 16,
						cex = 0.4,
						col = rgb(0, 0, 0, 0.25),
						xlab = "Average logCPM",
						ylab = paste0(
								"log2 fold change (",
								treat_level, " / ", ref_level, ")"
						),
						main = "Descriptive fold-change plot\n(no biological replicates)"
				)
				abline(h = 0, col = "red", lty = 2)
			}
		},
		error = function(e) {
			message("MD/fold-change plot skipped: ", e$message)
			plot.new()
			title("MD/fold-change plot skipped")
		})

dev.off()
cat("MD plot:\n  ", md_pdf, "\n\n")

# ------------------------------------------------------------
# Step 13. log2FC vs GC bin plot (TMM, NBIS Fig 5)
# ------------------------------------------------------------
cat("############################## Step 13: log2FC vs GC bin (TMM)\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

plot_lfc_gc_bin <- function(tt, peak_gc_lookup, title_str, outfile, has_wesanderson) {
	df <- tt
	df$gc <- peak_gc_lookup[df$peakID]
	df <- df[!is.na(df$gc) & !is.na(df$logFC), ]
	
	if (nrow(df) < 20) {
		message("not enough peaks with valid GC + logFC for ", title_str)
		return(invisible(NULL))
	}
	
	df$gc_group <- Hmisc::cut2(df$gc, g = 20)
	
	p <- ggplot(df, aes(x = gc_group, y = logFC, color = gc_group)) +
			geom_violin(width = 0.95) +
			geom_boxplot(width = 0.15, color = "grey20") +
			geom_abline(intercept = 0, slope = 0, col = "black", lty = 2) +
			coord_cartesian(ylim = c(-1, 1)) +
			ggtitle(paste0("log2FCs in bins by GC content, normalisation: ", title_str)) +
			xlab("GC-content bin") +
			ylab("logFC") +
			theme_bw() +
			theme(
					axis.text.x = element_text(angle = 45, vjust = .5),
					legend.position = "none",
					axis.title = element_text(size = 14)
			)
	
	if (has_wesanderson) {
		n_bins <- nlevels(df$gc_group)
		p <- p + scale_color_manual(
				values = wesanderson::wes_palette("Zissou1", n_bins, "continuous")
		)
	}
	
	ggsave(outfile, p, width = 10, height = 6)
}

plot_lfc_gc_bin(res_tmm$tt, peak_gc_lookup, "TMM", lfc_gc_tmm_pdf, has_wesanderson)
cat("log2FC vs GC bin plot (TMM):\n  ", lfc_gc_tmm_pdf, "\n\n")

# ------------------------------------------------------------
# Step 14. Export TMM result tables and BED files
# ------------------------------------------------------------
cat("############################## Step 14: Export TMM result tables\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

annotate_da <- function(tt, peak_gr, peak_gc_lookup) {
	gr_df <- data.frame(
			peakID = names(peak_gr),
			seqnames = as.character(seqnames(peak_gr)),
			start = start(peak_gr),
			end = end(peak_gr),
			width = width(peak_gr),
			stringsAsFactors = FALSE
	)
	merged <- merge(gr_df, tt, by = "peakID", all.y = TRUE, sort = FALSE)
	merged$gc <- peak_gc_lookup[merged$peakID]
	# Reorder columns
	front_cols <- c("seqnames", "start", "end", "width", "peakID", "gc")
	other_cols <- setdiff(colnames(merged), front_cols)
	merged[, c(front_cols, other_cols)]
}

da_full_tmm <- annotate_da(res_tmm$tt, consensus_peaks, peak_gc_lookup)
write.csv(da_full_tmm, diff_csv_tmm, row.names = FALSE)

cat("TMM result tables:\n")
cat("  all         =", diff_csv_tmm, "(", nrow(da_full_tmm), "rows )\n")

if (has_replicates) {
	da_sig_tmm <- da_full_tmm[
			!is.na(da_full_tmm$FDR) & da_full_tmm$FDR <= fdr,
	]
	write.csv(da_sig_tmm, diff_sig_csv_tmm, row.names = FALSE)
	cat("  significant =", diff_sig_csv_tmm, "(", nrow(da_sig_tmm), "rows )\n\n")
} else {
	da_sig_tmm <- da_full_tmm[0, ]
	cat("  significant = skipped (no biological replicates)\n\n")
}

# Downstream table
make_downstream_table <- function(da_full, fdr_cutoff) {
	out <- data.frame(
			chr = as.character(da_full$seqnames),
			start = as.integer(da_full$start),
			end = as.integer(da_full$end),
			peak_id = da_full$peakID,
			logFC = da_full$logFC,
			pvalue = da_full$PValue,
			FDR = da_full$FDR,
			GC = da_full$gc,
			stringsAsFactors = FALSE
	)
	out$status <- "not_significant"
	out$status[!is.na(out$FDR) & !is.na(out$logFC) &
					out$FDR <= fdr_cutoff & out$logFC > 0] <- "up"
	out$status[!is.na(out$FDR) & !is.na(out$logFC) &
					out$FDR <= fdr_cutoff & out$logFC < 0] <- "down"
	out
}

downstream_df_tmm <- make_downstream_table(da_full_tmm, fdr)
if (!has_replicates) {
	downstream_df_tmm$status <- "not_tested"
}
write.table(downstream_df_tmm, downstream_tsv_tmm,
		sep = "\t", quote = FALSE, row.names = FALSE)
cat("downstream TSV:\n  ", downstream_tsv_tmm, "\n\n")

# BED files
write_bed <- function(df, outfile) {
	if (is.null(df) || nrow(df) == 0) {
		file.create(outfile)
		return(invisible(NULL))
	}
	bed <- data.frame(
			seqnames = as.character(df$seqnames),
			start = as.integer(df$start) - 1L,
			end = as.integer(df$end),
			name = df$peakID,
			score = 0,
			strand = "."
	)
	write.table(bed, outfile, sep = "\t", quote = FALSE,
			row.names = FALSE, col.names = FALSE)
}

if (has_replicates) {
	write_bed(da_sig_tmm, diff_sig_bed)
	write_bed(da_sig_tmm[!is.na(da_sig_tmm$logFC) & da_sig_tmm$logFC > 0, ], up_bed)
	write_bed(da_sig_tmm[!is.na(da_sig_tmm$logFC) & da_sig_tmm$logFC < 0, ], down_bed)
	
	cat("BED outputs:\n")
	cat("  significant =", diff_sig_bed, "\n")
	cat("  up          =", up_bed, "\n")
	cat("  down        =", down_bed, "\n\n")
} else {
	cat("BED outputs skipped: no biological replicates\n\n")
}

# ------------------------------------------------------------
# Step 15. (Optional) EDASeq full-quantile GC normalisation (NBIS Fig 6)
# ------------------------------------------------------------
if (has_replicates && run_edaseq_logical && has_edaseq) {
	cat("############################## Step 15: EDASeq full-quantile GC normalisation\n")
	cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
	
	tryCatch({
				gc_kept <- peak_gc_lookup[rownames(reads_dge_filt$counts)]
				non_na <- !is.na(gc_kept)
				
				cat("EDASeq input peaks (with non-NA GC):", sum(non_na),
						"/", length(gc_kept), "\n")
				
				counts_eda <- reads_dge_filt$counts[non_na, ]
				gc_eda <- gc_kept[non_na]
				
				exprs_set <- EDASeq::newSeqExpressionSet(counts_eda)
				fd <- data.frame(gc = gc_eda, row.names = rownames(counts_eda))
				Biobase::fData(exprs_set) <- fd
				
				eda_wl <- EDASeq::withinLaneNormalization(
						exprs_set, "gc",
						num.bins = 20, which = "full", offset = TRUE
				)
				eda_bl <- EDASeq::betweenLaneNormalization(
						eda_wl, which = "full", offset = TRUE
				)
				
				reads_dge_eda <- reads_dge_filt[non_na, , keep.lib.sizes = FALSE]
				reads_dge_eda$offset <- -EDASeq::offst(eda_bl)
				
				res_eda <- run_edger_de(reads_dge_eda, design, contrast_coef = 2)
				
				da_full_eda <- annotate_da(res_eda$tt, consensus_peaks, peak_gc_lookup)
				write.csv(da_full_eda, diff_csv_eda, row.names = FALSE)
				
				plot_lfc_gc_bin(res_eda$tt, peak_gc_lookup,
						"GC FQ-FQ (EDASeq)", lfc_gc_eda_pdf, has_wesanderson)
				
				saveRDS(res_eda$test, qlf_eda_rds)
				
				cat("EDASeq outputs:\n")
				cat("  all results =", diff_csv_eda, "\n")
				cat("  GC bin plot =", lfc_gc_eda_pdf, "\n")
				cat("  QLF RDS     =", qlf_eda_rds, "\n\n")
			},
			error = function(e) {
				message("EDASeq normalisation failed: ", e$message)
			})
} else {
	cat("############################## Step 15: EDASeq skipped\n")
	if (!has_replicates) {
		cat("  reason: significance analysis requires biological replication\n\n")
	} else {
		cat("  reason: run_edaseq=", run_edaseq_logical,
				", has_edaseq=", has_edaseq, "\n\n", sep = "")
	}
}

# ------------------------------------------------------------
# Step 16. (Optional) CQN normalisation (NBIS Fig 7)
# ------------------------------------------------------------
if (has_replicates && run_cqn_logical && has_cqn) {
	cat("############################## Step 16: CQN normalisation\n")
	cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
	
	tryCatch({
				gc_kept <- peak_gc_lookup[rownames(reads_dge_filt$counts)]
				width_kept <- width(consensus_peaks)[match(
								rownames(reads_dge_filt$counts), names(consensus_peaks)
						)]
				
				non_na <- !is.na(gc_kept) & !is.na(width_kept)
				
				cat("CQN input peaks (with non-NA GC and width):", sum(non_na),
						"/", length(gc_kept), "\n")
				
				cqn_out <- cqn::cqn(
						counts = reads_dge_filt$counts[non_na, ],
						lengths = width_kept[non_na],
						x = gc_kept[non_na],
						sizeFactors = reads_dge_filt$samples$lib.size,
						verbose = TRUE
				)
				
				reads_dge_cqn <- reads_dge_filt[non_na, , keep.lib.sizes = FALSE]
				reads_dge_cqn$offset <- cqn_out$glm.offset
				
				res_cqn <- run_edger_de(reads_dge_cqn, design, contrast_coef = 2)
				
				da_full_cqn <- annotate_da(res_cqn$tt, consensus_peaks, peak_gc_lookup)
				write.csv(da_full_cqn, diff_csv_cqn, row.names = FALSE)
				
				plot_lfc_gc_bin(res_cqn$tt, peak_gc_lookup,
						"CQN", lfc_gc_cqn_pdf, has_wesanderson)
				
				saveRDS(res_cqn$test, qlf_cqn_rds)
				
				cat("CQN outputs:\n")
				cat("  all results =", diff_csv_cqn, "\n")
				cat("  GC bin plot =", lfc_gc_cqn_pdf, "\n")
				cat("  QLF RDS     =", qlf_cqn_rds, "\n\n")
			},
			error = function(e) {
				message("CQN normalisation failed: ", e$message)
			})
} else {
	cat("############################## Step 16: CQN skipped\n")
	if (!has_replicates) {
		cat("  reason: significance analysis requires biological replication\n\n")
	} else {
		cat("  reason: run_cqn=", run_cqn_logical,
				", has_cqn=", has_cqn, "\n\n", sep = "")
	}
}

# Defensive cleanup: these outputs must not exist when statistical
# EDASeq/CQN analyses were skipped because biological replication is absent.
if (!has_replicates) {
	skipped_stat_outputs <- c(
			diff_sig_csv_tmm,
			diff_sig_bed,
			up_bed,
			down_bed,
			diff_csv_eda,
			diff_csv_cqn,
			lfc_gc_eda_pdf,
			lfc_gc_cqn_pdf,
			qlf_tmm_rds,
			qlf_eda_rds,
			qlf_cqn_rds
	)
	skipped_stat_outputs <- skipped_stat_outputs[file.exists(skipped_stat_outputs)]
	if (length(skipped_stat_outputs) > 0) {
		unlink(skipped_stat_outputs, force = TRUE)
		cat("removed skipped statistical output placeholders:\n")
		cat("  ", paste(skipped_stat_outputs, collapse = "\n  "), "\n\n", sep = "")
	}
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
cat("\n############################## Done\n")
cat("  input_dir              =", input_dir, "\n")
cat("  peak_dir               =", peak_dir, "\n")
cat("  sample_data            =", sample_data, "\n")
cat("  genome_fasta           =", genome_fasta, "\n")
cat("  consensus peaks        =", length(consensus_peaks), "\n")
cat("  peaks after filtering  =", nrow(reads_dge_filt), "\n")
cat("  analysis mode          =", res_tmm$mode, "\n")
cat("  TMM all results        =", diff_csv_tmm, "\n")
cat("  downstream TSV         =", downstream_tsv_tmm, "\n")

if (has_replicates) {
	cat(
			"  TMM significant        =", diff_sig_csv_tmm,
			" (", nrow(da_sig_tmm), " rows)\n",
			sep = ""
	)
	cat("  significant BED        =", diff_sig_bed, "\n")
	cat("  up / down BED          =", up_bed, "/", down_bed, "\n")
} else {
	cat("  significance testing   = skipped (no biological replicates)\n")
	cat("  PValue / FDR            = NA\n")
}
cat("  plot directory         =", plot_dir, "\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")