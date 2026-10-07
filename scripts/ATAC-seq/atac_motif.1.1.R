#!/usr/bin/env Rscript

# Version 1.1 (changes from atac_motif.1.0.R):
#   stdout and stderr are kept apart: progress goes to stdout and
#   logs/<stamp>.log; errors, warnings, and package messages go to stderr
#   and logs/<stamp>.error.log.
#   threads defaults to auto: the CPU cores allocated to the job
#   (parallel::mcaffinity()); a number is capped by the allocation.
#   The run stops if output_dir is or contains an input path.
#   A local data-frame variable was renamed to col_data (site command
#   blacklist).

# Required:
#   input_dir="..." OR da_csv="..."
#   output_dir="..."
#   genome_fasta="/path/to/reference.fa"
#   motif_db="/path/to/motifs.meme"
#
# Optional:
#   norm="TMM"                         # TMM | EDASeq | CQN
#   chrs=""
#   fdr_filter=""
#   n_per_bin="400"
#   min_abs_logfc="0.3"
#   padj_cutoff="4.0"
#   kmer_len="6"
#   min_motif_score="10.0"
#   stabsel_cutoff="0.8"
#   seed="123"
#   threads="auto"                     # auto = allocated CPU cores
#   run_kmer="TRUE"
#   run_regression="TRUE"

DEBUG_SCRIPT_VERSION <- "NBIS_MOTIF_SEQLOGO_PNG_20260629"

# Errors and warnings go to stderr and logs/<stamp>.error.log (err_con is
# opened together with the log file); progress goes to stdout and
# logs/<stamp>.log.
err_con <- NULL
emit_err <- function(txt) {
	cat(txt, file = stderr())
	if (!is.null(err_con)) {
		cat(txt, file = err_con)
		flush(err_con)
	}
}

stop_err <- function(...) {
	msg <- paste(..., collapse = "")
	emit_err(paste0("ERROR: ", msg, "\n"))
	quit(status = 1)
}

safe_dev_off <- function() {
	while (dev.cur() != 1L) {
		try(dev.off(), silent = TRUE)
	}
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
# Parameters
# ------------------------------------------------------------
if (!exists("output_dir", inherits = FALSE)) {
	stop_err("Required parameter 'output_dir' is missing")
}

if (!exists("input_dir", inherits = FALSE)) input_dir <- ""
if (!exists("da_csv", inherits = FALSE)) da_csv <- ""

if (nchar(input_dir) == 0 && nchar(da_csv) == 0) {
	stop_err("One of 'input_dir' or 'da_csv' is required")
}

if (!exists("norm", inherits = FALSE)) {
	norm <- "TMM"
}

# ------------------------------------------------------------
# Reference genome FASTA
# ------------------------------------------------------------

if (!exists("genome_fasta", inherits = FALSE) ||
		!nzchar(trimws(genome_fasta))) {
	stop_err("Required parameter 'genome_fasta' is missing")
}

genome_fasta <- normalizePath(
		trimws(genome_fasta),
		mustWork = FALSE
)

if (!file.exists(genome_fasta)) {
	stop_err("Genome FASTA file not found: ", genome_fasta)
}

genome_fai <- paste0(genome_fasta, ".fai")

if (!file.exists(genome_fai)) {
	stop_err(
			"FASTA index file not found: ",
			genome_fai,
			". Create the index using samtools faidx before running this module."
	)
}

# ------------------------------------------------------------
# Motif database (MEME file, provided directly)
# ------------------------------------------------------------

if (!exists("motif_db", inherits = FALSE) ||
		!nzchar(trimws(motif_db))) {
	stop_err("Required parameter 'motif_db' is missing")
}

motif_db <- trimws(motif_db)

if (!file.exists(motif_db)) {
	stop_err("Motif database file not found: ", motif_db)
}

motif_db <- normalizePath(motif_db, mustWork = TRUE)

if (!exists("chrs", inherits = FALSE)) chrs <- ""
if (!exists("fdr_filter", inherits = FALSE)) fdr_filter <- ""
if (!exists("n_per_bin", inherits = FALSE)) n_per_bin <- "400"
if (!exists("min_abs_logfc", inherits = FALSE)) min_abs_logfc <- "0.3"
if (!exists("padj_cutoff", inherits = FALSE)) padj_cutoff <- "4.0"
if (!exists("kmer_len", inherits = FALSE)) kmer_len <- "6"
if (!exists("min_motif_score", inherits = FALSE)) min_motif_score <- "10.0"
if (!exists("stabsel_cutoff", inherits = FALSE)) stabsel_cutoff <- "0.8"
if (!exists("seed", inherits = FALSE)) seed <- "123"
if (!exists("threads", inherits = FALSE)) threads <- "auto"
if (!exists("run_kmer", inherits = FALSE)) run_kmer <- "TRUE"
if (!exists("run_regression", inherits = FALSE)) run_regression <- "TRUE"


norm <- toupper(norm)

if (!norm %in% c("TMM", "EDASEQ", "CQN")) {
	stop_err("norm must be one of: TMM, EDASeq, CQN")
}

norm_filename <- switch(
		norm,
		"TMM" = "TMM",
		"EDASEQ" = "EDASeq",
		"CQN" = "CQN"
)

n_per_bin <- as.integer(n_per_bin)
min_abs_logfc <- as.numeric(min_abs_logfc)
padj_cutoff <- as.numeric(padj_cutoff)
kmer_len <- as.integer(kmer_len)
min_motif_score <- as.numeric(min_motif_score)
stabsel_cutoff <- as.numeric(stabsel_cutoff)
seed <- as.integer(seed)
# threads: the CPU cores allocated to this job (affinity mask / cgroup
# cpuset); a requested number is capped by the allocation.
allocated_threads <- tryCatch(length(parallel::mcaffinity()), error = function(e) NA_integer_)
if (is.na(allocated_threads) || allocated_threads < 1) {
	allocated_threads <- suppressWarnings(as.integer(system("nproc", intern = TRUE)))
}
if (is.na(allocated_threads) || allocated_threads < 1) allocated_threads <- 1L
threads_requested <- threads
threads <- if (threads %in% c("", "auto")) allocated_threads else suppressWarnings(as.integer(threads))
if (!is.na(threads) && threads > allocated_threads) threads <- allocated_threads
Sys.setenv(OMP_NUM_THREADS = threads, OPENBLAS_NUM_THREADS = threads, MKL_NUM_THREADS = threads)

if (is.na(n_per_bin) || n_per_bin <= 0) stop_err("n_per_bin must be positive integer")
if (is.na(min_abs_logfc) || min_abs_logfc < 0) stop_err("min_abs_logfc must be >= 0")
if (is.na(padj_cutoff) || padj_cutoff < 0) stop_err("padj_cutoff must be >= 0")
if (is.na(kmer_len) || kmer_len <= 0) stop_err("kmer_len must be positive integer")
if (is.na(min_motif_score) || min_motif_score <= 0) stop_err("min_motif_score must be positive number")
if (is.na(stabsel_cutoff) || stabsel_cutoff <= 0 || stabsel_cutoff > 1) {
	stop_err("stabsel_cutoff must be in (0, 1]")
}
if (is.na(seed)) stop_err("seed must be integer")
if (is.na(threads) || threads <= 0) stop_err("threads must be auto or a positive integer: ", threads_requested)

fdr_filter_num <- if (nchar(fdr_filter) > 0) as.numeric(fdr_filter) else NA_real_

if (nchar(fdr_filter) > 0 &&
		(is.na(fdr_filter_num) || fdr_filter_num <= 0 || fdr_filter_num > 1)) {
	stop_err("fdr_filter must be a number in (0, 1]")
}

run_kmer_logical <- toupper(run_kmer) %in% c("TRUE", "T", "YES", "1")
run_regression_logical <- toupper(run_regression) %in% c("TRUE", "T", "YES", "1")

# ------------------------------------------------------------
# Resolve DA CSV
# ------------------------------------------------------------
if (nchar(da_csv) > 0) {
	if (!file.exists(da_csv)) {
		stop_err("da_csv not found: ", da_csv)
	}
	da_csv <- normalizePath(da_csv, mustWork = TRUE)
} else {
	if (!dir.exists(input_dir)) {
		stop_err("input_dir not found: ", input_dir)
	}
	
	input_dir <- normalizePath(input_dir, mustWork = TRUE)
	
	primary <- file.path(
			input_dir,
			"03_results",
			paste0("diff_accessibility_", norm_filename, ".csv")
	)
	
	if (file.exists(primary)) {
		da_csv <- primary
	} else {
		cands <- list.files(
				input_dir,
				pattern = paste0("^diff_accessibility_", norm_filename, "\\.csv$"),
				full.names = TRUE,
				recursive = TRUE
		)
		
		if (length(cands) == 0) {
			stop_err(
					"could not locate diff_accessibility_", norm_filename,
					".csv under input_dir: ", input_dir,
					". Expected at: ", primary,
					". Use norm=TMM|EDASeq|CQN or pass da_csv directly."
			)
		}
		
		da_csv <- cands[1]
	}
}

# ------------------------------------------------------------
# output_dir is cleaned below, so it must not be or contain an input.
# ------------------------------------------------------------
check_inputs_outside_output <- function(output_dir, inputs) {
	out <- normalizePath(output_dir, mustWork = FALSE)
	for (x in inputs[nzchar(inputs)]) {
		inp <- normalizePath(x, mustWork = FALSE)
		if (inp == out || startsWith(inp, paste0(out, "/"))) {
			stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned on each run")
		}
	}
}
check_inputs_outside_output(output_dir, c(input_dir, da_csv, genome_fasta, motif_db))

# ------------------------------------------------------------
# Clean output dir except logs
# ------------------------------------------------------------
if (dir.exists(output_dir) && normalizePath(output_dir, mustWork = FALSE) != "/") {
	files_to_remove <- list.files(
			output_dir,
			all.files = TRUE,
			no.. = TRUE,
			full.names = TRUE
	)
	
	files_to_remove <- files_to_remove[basename(files_to_remove) != "logs"]
	
	if (length(files_to_remove) > 0) {
		unlink(files_to_remove, recursive = TRUE, force = TRUE)
	}
}

dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

if (!dir.exists(output_dir)) {
	stop_err("failed to create output_dir: ", output_dir)
}

output_dir <- normalizePath(output_dir, mustWork = TRUE)

logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE, recursive = TRUE)

log_file <- file.path(
		logs_dir,
		paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")
)

log_con <- file(log_file, open = "at")
sink(log_con, append = TRUE, split = TRUE)

err_file <- sub("\\.log$", ".error.log", log_file)
err_con <- file(err_file, open = "at")

# Package messages and warnings (stderr) are also copied to the .error.log.
globalCallingHandlers(
		message = function(m) {
			cat(conditionMessage(m), file = err_con)
			flush(err_con)
		},
		warning = function(w) {
			cat("WARNING: ", conditionMessage(w), "\n", sep = "", file = err_con)
			flush(err_con)
		}
)

on.exit({
			try(sink(), silent = TRUE)
			try(close(log_con), silent = TRUE)
			try(close(err_con), silent = TRUE)
		}, add = TRUE)

cat("############################## ATAC-seq Motif Analysis (NBIS / monaLisa)\n")
cat("DEBUG_SCRIPT_VERSION:", DEBUG_SCRIPT_VERSION, "\n")
cat("Log file   :", log_file, "\n")
cat("Error log  :", err_file, "\n")
cat("Start time :", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("parameters:\n")
cat("  input_dir       =", ifelse(nchar(input_dir) == 0, "<not set>", input_dir), "\n")
cat("  da_csv          =", da_csv, "\n")
cat("  norm            =", norm_filename, "\n")
cat("  output_dir      =", output_dir, "\n")
cat("  genome_fasta    =", genome_fasta, "\n")
cat("  motif_db        =", motif_db, "\n")

cat(
		"  chrs            =",
		ifelse(nchar(chrs) == 0, "<auto>", chrs),
		"\n"
)
cat("  fdr_filter      =", ifelse(nchar(fdr_filter) == 0, "<none>", fdr_filter), "\n")
cat("  n_per_bin       =", n_per_bin, "\n")
cat("  min_abs_logfc   =", min_abs_logfc, "\n")
cat("  padj_cutoff     =", padj_cutoff, "\n")
cat("  kmer_len        =", kmer_len, "\n")
cat("  min_motif_score =", min_motif_score, "\n")
cat("  stabsel_cutoff  =", stabsel_cutoff, "\n")
cat("  seed            =", seed, "\n")
cat("  threads         =", threads, "(requested", threads_requested, "allocated", allocated_threads, ")\n")
cat("  run_kmer        =", run_kmer_logical, "\n")
cat("  run_regression  =", run_regression_logical, "\n\n")

# ------------------------------------------------------------
# Output directories
# ------------------------------------------------------------
qc_dir <- file.path(output_dir, "01_qc")
bin_dir <- file.path(output_dir, "02_binned_enrichment")
kmer_dir <- file.path(output_dir, "03_kmer")
reg_dir <- file.path(output_dir, "04_regression")
rds_dir <- file.path(output_dir, "05_rds")

dir.create(qc_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(bin_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(kmer_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(reg_dir, showWarnings = FALSE, recursive = TRUE)
dir.create(rds_dir, showWarnings = FALSE, recursive = TRUE)

# ------------------------------------------------------------
# Load packages
# ------------------------------------------------------------

cat("############################## Step 0: Load R packages\n")

required_packages <- c(
		"monaLisa",
		"BiocParallel",
		"ggplot2",
		"ComplexHeatmap",
		"circlize",
		"GenomicRanges",
		"GenomeInfoDb",
		"IRanges",
		"Rsamtools",
		"TFBSTools",
		"universalmotif",
		"SummarizedExperiment",
		"Biostrings",
		"grid"
)

for (pkg in required_packages) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		stop_err("Required R package not found: ", pkg)
	}
}

suppressMessages({
			library(monaLisa)
			library(BiocParallel)
			library(ggplot2)
			library(ComplexHeatmap)
			library(circlize)
			library(GenomicRanges)
			library(GenomeInfoDb)
			library(IRanges)
			library(Rsamtools)
			library(TFBSTools)
			library(universalmotif)
			library(SummarizedExperiment)
			library(Biostrings)
			library(grid)
		})

# ------------------------------------------------------------
# Open reference genome FASTA
# ------------------------------------------------------------

genome_fa <- Rsamtools::FaFile(genome_fasta)

tryCatch(
		{
			open(genome_fa)
		},
		error = function(e) {
			stop_err(
					"Failed to open genome FASTA: ",
					conditionMessage(e)
			)
		}
)

on.exit(
		{
			try(close(genome_fa), silent = TRUE)
		},
		add = TRUE
)

genome_index <- tryCatch(
		{
			Rsamtools::scanFaIndex(genome_fa)
		},
		error = function(e) {
			stop_err(
					"Failed to read FASTA index: ",
					conditionMessage(e)
			)
		}
)

genome_seqnames <- unique(
		as.character(GenomicRanges::seqnames(genome_index))
)
# Store reference sequence lengths from the FASTA index
if (inherits(genome_index, "GRangesList")) {
	genome_index <- unlist(
			genome_index,
			use.names = FALSE
	)
}

genome_seqlengths <- setNames(
		IRanges::width(genome_index),
		as.character(GenomicRanges::seqnames(genome_index))
)
cat("Genome FASTA:", genome_fasta, "\n")
cat("Reference sequences:", length(genome_seqnames), "\n\n")


BPPARAM <- BiocParallel::MulticoreParam(threads)

# ------------------------------------------------------------
# Step 1: Read DA CSV and build GRanges
# ------------------------------------------------------------
cat("############################## Step 1: Read DA CSV and build GRanges\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

da <- tryCatch(
		read.csv(da_csv, stringsAsFactors = FALSE, check.names = FALSE),
		error = function(e) stop_err("failed to read da_csv: ", e$message)
)

cat("DA table shape:", nrow(da), "x", ncol(da), "\n")
cat("columns:", paste(colnames(da), collapse = ", "), "\n\n")

required_cols <- c("seqnames", "start", "end", "peakID", "logFC")
missing_cols <- setdiff(required_cols, colnames(da))

if (length(missing_cols) > 0) {
	stop_err(
			"DA CSV missing required columns: ",
			paste(missing_cols, collapse = ", "),
			". Expected ATAC_DA output CSV."
	)
}

if (!"gc" %in% colnames(da)) {
	cat("NOTE: 'gc' column missing - will compute from reference FASTA later\n")
}

n0 <- nrow(da)
da <- da[!is.na(da$logFC), ]
cat("dropped", n0 - nrow(da), "rows with NA logFC\n")

if (!is.na(fdr_filter_num)) {
	if (!"FDR" %in% colnames(da)) {
		stop_err("fdr_filter requested but FDR column not found in DA CSV")
	}
	
	n0 <- nrow(da)
	da <- da[!is.na(da$FDR) & da$FDR <= fdr_filter_num, ]
	
	cat(
			"FDR <= ",
			fdr_filter_num,
			" filter: ",
			nrow(da),
			"/",
			n0,
			" peaks retained\n",
			sep = ""
	)
}

if (nrow(da) < 1000) {
	warning("Fewer than 1000 peaks - monaLisa results may be unreliable")
}

gr <- GenomicRanges::GRanges(
		seqnames = as.character(da$seqnames),
		ranges = IRanges::IRanges(
				start = as.integer(da$start),
				end = as.integer(da$end)
		),
		strand = "*"
)

names(gr) <- da$peakID

mcols_keep <- intersect(
		c("peakID", "logFC", "logCPM", "F", "PValue", "FDR", "gc"),
		colnames(da)
)

for (cl in mcols_keep) {
	mcols(gr)[[cl]] <- da[[cl]]
}

cat("GRanges built:", length(gr), "ranges\n")

# ------------------------------------------------------------
# Chromosome harmonization
# ------------------------------------------------------------
reference_seqs <- genome_seqnames
gr_seqs <- unique(as.character(seqnames(gr)))
# ------------------------------------------------------------
# Harmonize chromosome names
# ------------------------------------------------------------

canonical_seqname <- function(x) {
	x <- sub("^chr", "", x, ignore.case = TRUE)
	x <- toupper(x)
	
	x[x %in% c("M", "MT", "MITO", "MITOCHONDRIA")] <- "MT"
	
	x
}

reference_lookup <- setNames(
		reference_seqs,
		canonical_seqname(reference_seqs)
)

old_levels <- seqlevels(gr)

new_levels <- unname(
		reference_lookup[canonical_seqname(old_levels)]
)

valid_levels <- !is.na(new_levels)

if (!any(valid_levels)) {
	stop_err(
			"Could not reconcile chromosome names between the DA results ",
			"and the reference FASTA."
	)
}

gr <- GenomeInfoDb::keepSeqlevels(
		gr,
		old_levels[valid_levels],
		pruning.mode = "coarse"
)

gr <- GenomeInfoDb::renameSeqlevels(
		gr,
		setNames(
				new_levels[valid_levels],
				old_levels[valid_levels]
		)
)

cat(
		"Chromosomes retained:",
		paste(unique(as.character(seqnames(gr))), collapse = ","),
		"\n"
)
# ------------------------------------------------------------
# Apply optional chromosome filter
# ------------------------------------------------------------

if (nchar(chrs) > 0) {
	requested_raw <- trimws(strsplit(chrs, ",")[[1]])
	
	requested_mapped <- unname(
			reference_lookup[canonical_seqname(requested_raw)]
	)
	
	requested_mapped <- unique(
			requested_mapped[!is.na(requested_mapped)]
	)
	
	if (length(requested_mapped) == 0) {
		stop_err(
				"None of the requested chromosomes were found in the reference FASTA: ",
				paste(requested_raw, collapse = ",")
		)
	}
	
	keep_chrs <- intersect(
			unique(as.character(seqnames(gr))),
			requested_mapped
	)
	
	if (length(keep_chrs) == 0) {
		stop_err(
				"No peaks remained after applying the chromosome filter"
		)
	}
	
	gr <- GenomeInfoDb::keepSeqlevels(
			gr,
			keep_chrs,
			pruning.mode = "coarse"
	)
}

cat(
		"Chromosomes retained:",
		paste(unique(as.character(seqnames(gr))), collapse = ","),
		"\n"
)

cat("After chromosome filter:", length(gr), "ranges\n")
# Assign reference sequence lengths to the GRanges object
current_seqlevels <- GenomeInfoDb::seqlevels(gr)

matched_seqlengths <- genome_seqlengths[current_seqlevels]

if (any(is.na(matched_seqlengths))) {
	missing_seqlevels <- current_seqlevels[is.na(matched_seqlengths)]
	
	stop_err(
			"Sequence lengths were not found for: ",
			paste(missing_seqlevels, collapse = ",")
	)
}

GenomeInfoDb::seqlengths(gr) <- matched_seqlengths

cat(
		"Reference sequence lengths assigned:",
		length(matched_seqlengths),
		"\n"
)
if (!"gc" %in% colnames(mcols(gr))) {
	cat("Computing GC content from reference FASTA ...\n")
	seqs_tmp <- tryCatch(
			{
				Rsamtools::scanFa(
						genome_fa,
						param = gr
				)
			},
			error = function(e) {
				stop_err(
						"Failed to extract sequences for GC calculation: ",
						conditionMessage(e)
				)
			}
	)
	
	freq <- Biostrings::alphabetFrequency(
			seqs_tmp,
			as.prob = TRUE
	)
	
	gr$gc <- freq[, "G"] + freq[, "C"]
	rm(seqs_tmp, freq)
	gc()
}

cat("\nregion width summary BEFORE resize:\n")
print(summary(width(gr)))

target_w <- as.integer(median(width(gr)))
gr <- GenomicRanges::trim(
		GenomicRanges::resize(gr, width = target_w, fix = "center")
)
gr <- gr[width(gr) > 0]

cat("region width summary AFTER resize (target=", target_w, "):\n", sep = "")
print(summary(width(gr)))

saveRDS(gr, file.path(rds_dir, "motif_input_GRanges.rds"))
cat("input GRanges saved:", file.path(rds_dir, "motif_input_GRanges.rds"), "\n\n")

# ------------------------------------------------------------
# Step 2: QC plots
# ------------------------------------------------------------
cat("############################## Step 2: QC plots\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

pdf(file.path(qc_dir, "logFC_vs_GC.pdf"), width = 8, height = 4)
par(mfrow = c(1, 2))

plot(
		gr$gc,
		gr$logFC,
		pch = ".",
		xlab = "GC fraction",
		ylab = "logFC",
		main = "scatter"
)
abline(h = 0, col = "red", lty = 5)

smoothScatter(
		gr$gc,
		gr$logFC,
		xlab = "GC fraction",
		ylab = "logFC",
		main = "smoothScatter"
)
abline(h = 0, col = "red", lty = 5)

dev.off()

p_hist <- ggplot(data.frame(logFC = gr$logFC), aes(x = logFC)) +
		geom_histogram(bins = 100) +
		xlab(paste0("logFC (", norm_filename, ")")) +
		ylab("Count") +
		theme_bw()

ggsave(
		filename = file.path(qc_dir, "logFC_histogram.pdf"),
		plot = p_hist,
		width = 6,
		height = 4
)

cat("QC plots written to:", qc_dir, "\n\n")

# ------------------------------------------------------------
# Step 3: Bin by logFC
# ------------------------------------------------------------
cat("############################## Step 3: Bin by logFC\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

bins <- bin(
		x = gr$logFC,
		binmode = "equalN",
		nElement = n_per_bin,
		minAbsX = min_abs_logfc
)

cat("bin table:\n")
print(table(bins))
cat("\n")

cat("DEBUG: using NBIS tutorial plotting calls for bin density and diagnostics\n")

# ------------------------------------------------------------
# 3-1. Plot binned histogram / density
# NBIS tutorial style
# ------------------------------------------------------------
pdf(file.path(qc_dir, "bin_density.pdf"), width = 7, height = 5)
print(
		plotBinDensity(x = gr$logFC, b = bins) +
				xlab("logFC")
)
dev.off()

# ------------------------------------------------------------
# Extract DNA sequences
# ------------------------------------------------------------
cat("extracting DNA sequences ...\n")
seqs <- tryCatch(
		{
			Rsamtools::scanFa(
					genome_fa,
					param = gr
			)
		},
		error = function(e) {
			stop_err(
					"Failed to extract DNA sequences from the genome FASTA: ",
					conditionMessage(e)
			)
		}
)

names(seqs) <- names(gr)

# ------------------------------------------------------------
# 3-2. GC fraction diagnostics
# NBIS tutorial style
# ------------------------------------------------------------
pdf(file.path(qc_dir, "bin_diagnostics_GCfrac.pdf"), width = 7, height = 5)
plotBinDiagnostics(seqs = seqs, bins = bins, aspect = "GCfrac")
dev.off()

# ------------------------------------------------------------
# 3-3. Dinucleotide diagnostics
# NBIS tutorial style
# ------------------------------------------------------------
pdf(file.path(qc_dir, "bin_diagnostics_dinucfreq.pdf"), width = 7, height = 5)
plotBinDiagnostics(seqs = seqs, bins = bins, aspect = "dinucfreq")
dev.off()

cat("bin diagnostics written.\n\n")

# ------------------------------------------------------------
# Step 4: Load motif database
# ------------------------------------------------------------

cat("############################## Step 4: Load motif database\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

cat("Motif database file:", motif_db, "\n\n")

# Read motifs from the MEME file
motifs <- tryCatch(
		{
			universalmotif::read_meme(motif_db)
		},
		error = function(e) {
			stop_err(
					"Failed to read the MEME motif database: ",
					conditionMessage(e)
			)
		}
)

if (inherits(motifs, "universalmotif")) {
	motifs <- list(motifs)
}

if (length(motifs) == 0) {
	stop_err(
			"No motifs were loaded from: ",
			motif_db
	)
}

# Convert universalmotif objects to TFBSTools PWMatrix objects
pwm_objects <- tryCatch(
		{
			universalmotif::convert_motifs(
					motifs,
					class = "TFBSTools-PWMatrix"
			)
		},
		error = function(e) {
			stop_err(
					"Failed to convert motifs to PWMatrix objects: ",
					conditionMessage(e)
			)
		}
)

if (inherits(pwm_objects, "PWMatrix")) {
	pwm_objects <- list(pwm_objects)
}

if (inherits(pwm_objects, "PWMatrixList")) {
	
	pwms <- pwm_objects
	
} else {
	
	if (!is.list(pwm_objects) || length(pwm_objects) == 0) {
		stop_err(
				"Motif conversion did not return valid PWMatrix objects"
		)
	}
	
	motif_names <- vapply(
			pwm_objects,
			function(x) {
				motif_name <- as.character(x@name)
				motif_id <- as.character(x@ID)
				
				if (length(motif_name) > 0 &&
						!is.na(motif_name[1]) &&
						nzchar(motif_name[1])) {
					return(motif_name[1])
				}
				
				if (length(motif_id) > 0 &&
						!is.na(motif_id[1]) &&
						nzchar(motif_id[1])) {
					return(motif_id[1])
				}
				
				return("unnamed_motif")
			},
			character(1)
	)
	
	names(pwm_objects) <- make.unique(motif_names)
	
	pwms <- do.call(
			TFBSTools::PWMatrixList,
			c(
					pwm_objects,
					list(use.names = TRUE)
			)
	)
}

if (length(pwms) == 0) {
	stop_err(
			"No PWMs were loaded from motif_db: ",
			motif_db
	)
}

# Ensure motif names/IDs are unique - duplicate names cause factor level
# collisions downstream in calcBinnedMotifEnrR (table/factor on motif names).
# monaLisa/TFBSTools use the PWM object's own name()/ID() slots (not just the
# list names) to build rowData, so both must be synchronized.
pwm_names <- names(pwms)

if (is.null(pwm_names) || any(!nzchar(pwm_names))) {
	stop_err("PWM list is missing names after conversion from motif_db")
}

n_dup <- sum(duplicated(pwm_names))

if (n_dup > 0) {
	cat("NOTE:", n_dup, "duplicated motif names found - making unique\n")
}

unique_names <- make.unique(pwm_names)
names(pwms) <- unique_names

pwms <- lapply(seq_along(pwms), function(i) {
			x <- pwms[[i]]
			
			if ("name" %in% slotNames(x)) {
				x@name <- unique_names[i]
			}
			
			if ("ID" %in% slotNames(x)) {
				x@ID <- unique_names[i]
			}
			
			x
		})

names(pwms) <- unique_names

pwms <- do.call(TFBSTools::PWMatrixList, c(pwms, list(use.names = TRUE)))

pwm_ids <- vapply(
		pwms,
		function(x) {
			if ("ID" %in% slotNames(x)) as.character(x@ID) else NA_character_
		},
		character(1)
)

if (any(duplicated(pwm_ids[!is.na(pwm_ids)]))) {
	stop_err(
			"PWM IDs still contain duplicates after make.unique(); ",
			"cannot proceed with calcBinnedMotifEnrR"
	)
}

cat("PWMs loaded:", length(pwms), "\n\n")
# ------------------------------------------------------------
# Step 5: Binned motif enrichment
# ------------------------------------------------------------
cat("############################## Step 5: Binned motif enrichment\n")
cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")

se <- calcBinnedMotifEnrR(
		seqs = seqs,
		bins = bins,
		pwmL = pwms,
		background = "otherBins",
		BPPARAM = BPPARAM
)

saveRDS(se, file.path(bin_dir, "binned_motif_SE.rds"))

log2enr <- assay(se, "log2enr")
negLog10P <- assay(se, "negLog10Padj")

enr_df <- data.frame(
		motif_id = rownames(se),
		motif_name = rowData(se)$motif.name,
		motif_GC = rowData(se)$motif.percentGC,
		stringsAsFactors = FALSE
)

colnames(log2enr) <- paste0("log2enr__", colnames(log2enr))
colnames(negLog10P) <- paste0("negLog10P__", colnames(negLog10P))

enr_df <- cbind(
		enr_df,
		as.data.frame(log2enr),
		as.data.frame(negLog10P)
)

write.table(
		enr_df,
		file.path(bin_dir, "binned_motif_enrichment.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

sel <- apply(
		assay(se, "negLog10Padj"),
		1,
		function(x) max(abs(x), 0, na.rm = TRUE)
) > padj_cutoff

cat("strongly enriched motifs (-log10(padj) >", padj_cutoff, "):", sum(sel), "\n")

if (sum(sel) >= 2) {
	seSel <- se[sel, ]
	
	SimMatSel <- motifSimilarity(rowData(seSel)$motif.pfm)
	hcl <- hclust(as.dist(1 - SimMatSel), method = "average")
	
	pdf(
			file.path(bin_dir, "binned_motif_heatmap.pdf"),
			width = 10,
			height = max(4, 0.18 * sum(sel) + 3)
	)
	
	plotMotifHeatmaps(
			x = seSel,
			which.plots = c("log2enr", "negLog10Padj"),
			width = 1.8,
			cluster = hcl,
			maxEnr = 2,
			maxSig = 10,
			show_dendrogram = TRUE,
			show_seqlogo = TRUE,
			show_motif_GC = TRUE,
			width.seqlogo = 1.2
	)
	
	dev.off()
} else {
	cat("fewer than 2 enriched motifs - heatmap skipped\n")
	seSel <- se[FALSE, ]
}

# ------------------------------------------------------------
# Individual seqLogo PNGs
# - Generate sequence logos using the NBIS tutorial method:
#   seqLogo(x = toICM(pfm))
# - Save each motif logo as an individual PNG file
# - Remove incomplete or corrupted PNG files
# ------------------------------------------------------------

if (sum(sel) >= 1) {
	logo_dir <- file.path(bin_dir, "seqlogos")
	dir.create(logo_dir, showWarnings = FALSE, recursive = TRUE)
	
	n_logos <- min(20L, nrow(seSel))
	
	abs_neglog <- apply(
			assay(seSel, "negLog10Padj"),
			1,
			function(x) max(abs(x), 0, na.rm = TRUE)
	)
	
	logo_order <- order(abs_neglog, decreasing = TRUE)[seq_len(n_logos)]
	
	pfm_list <- rowData(seSel)$motif.pfm
	name_vec <- rowData(seSel)$motif.name
	id_vec   <- rownames(seSel)
	
	written_logos <- 0L
	skipped_logos <- 0L
	
	for (i in logo_order) {
		fname <- gsub(
				"[^A-Za-z0-9._-]+",
				"_",
				paste0(id_vec[i], "_", name_vec[i])
		)
		
		out_png <- file.path(logo_dir, paste0(fname, ".png"))
		
		if (file.exists(out_png)) {
			unlink(out_png, force = TRUE)
		}
		
		logo_ok <- FALSE
		
		tryCatch({
					png(
							filename = out_png,
							width = 1800,
							height = 900,
							res = 300,
							type = "cairo"
					)
					
					# NBIS tutorial style
					seqLogo(x = toICM(pfm_list[[i]]))
					
					dev.off()
					
					if (!file.exists(out_png)) {
						stop("PNG was not created")
					}
					
					if (is.na(file.info(out_png)$size) || file.info(out_png)$size < 1000) {
						unlink(out_png, force = TRUE)
						stop("PNG too small; removed as broken file")
					}
					
					logo_ok <- TRUE
				}, error = function(e) {
					while (dev.cur() != 1L) {
						try(dev.off(), silent = TRUE)
					}
					
					if (file.exists(out_png)) {
						unlink(out_png, force = TRUE)
					}
					
					cat(
							"  [skip] seqLogo for ",
							id_vec[i],
							" / ",
							name_vec[i],
							": ",
							conditionMessage(e),
							"\n",
							sep = ""
					)
				})
		
		if (isTRUE(logo_ok)) {
			written_logos <- written_logos + 1L
		} else {
			skipped_logos <- skipped_logos + 1L
		}
	}
	
	cat(
			"seqLogo PNGs requested: ",
			n_logos,
			" | written: ",
			written_logos,
			" | skipped: ",
			skipped_logos,
			"\n",
			sep = ""
	)
	
	cat("seqLogo PNGs written to: ", logo_dir, "\n", sep = "")
}

cat("\n")

# ------------------------------------------------------------
# Step 6: Binned k-mer enrichment
# ------------------------------------------------------------
if (run_kmer_logical) {
	cat("############################## Step 6: Binned k-mer enrichment\n")
	cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
	
	tryCatch({
				seKmer <- calcBinnedKmerEnr(
						seqs = seqs,
						bins = bins,
						kmerLen = kmer_len,
						includeRevComp = TRUE,
						BPPARAM = BPPARAM
				)
				
				saveRDS(seKmer, file.path(kmer_dir, "binned_kmer_SE.rds"))
				
				selKmer <- apply(
						assay(seKmer, "negLog10Padj"),
						1,
						function(x) max(abs(x), 0, na.rm = TRUE)
				) > padj_cutoff
				
				cat("enriched k-mers:", sum(selKmer), "\n")
				
				if (sum(selKmer) >= 2 && nrow(seSel) >= 2) {
					seKmerSel <- seKmer[selKmer, ]
					pfmSel <- rowData(seSel)$motif.pfm
					
					sims <- motifKmerSimilarity(
							x = pfmSel,
							kmers = rownames(seKmerSel),
							includeRevComp = TRUE
					)
					
					maxwidth <- max(sapply(TFBSTools::Matrix(pfmSel), ncol))
					seqlogoGrobs <- lapply(pfmSel, seqLogoGrob, xmax = maxwidth)
					
					hmSeqlogo <- rowAnnotation(
							logo = annoSeqlogo(seqlogoGrobs, which = "row"),
							annotation_width = unit(1.5, "inch"),
							show_annotation_name = FALSE
					)
					
					pdf(
							file.path(kmer_dir, "kmer_motif_similarity.pdf"),
							width = 11,
							height = max(4, 0.2 * nrow(sims) + 2)
					)
					
					draw(
							Heatmap(
									sims,
									show_row_names = TRUE,
									row_names_gp = gpar(fontsize = 8),
									show_column_names = TRUE,
									column_names_gp = gpar(fontsize = 8),
									name = "Similarity",
									column_title = "Selected TFs vs enriched k-mers",
									col = colorRamp2(
											c(0, 0.5, 1),
											c("#e8eef2", "#fdae61", "#a50026")
									),
									right_annotation = hmSeqlogo
							)
					)
					
					dev.off()
				}
			}, error = function(e) {
				message("k-mer enrichment failed: ", e$message)
			})
	
	cat("\n")
} else {
	cat("############################## Step 6: k-mer enrichment SKIPPED\n\n")
}

# ------------------------------------------------------------
# Step 7: Regression-based motif selection
# ------------------------------------------------------------
if (run_regression_logical) {
	cat("############################## Step 7: Regression (randLassoStabSel)\n")
	cat("Start time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n\n")
	
	reg_ok <- tryCatch({
				cat("scanning motif hits across enhancer sequences ...\n")
				
				hits <- findMotifHits(
						query = pwms,
						subject = seqs,
						min.score = min_motif_score,
						BPPARAM = BPPARAM
				)
				
				cat("total motif hits:", length(hits), "\n")
				
				hits$pwmIdName <- paste0(hits$pwmid, "_", hits$pwmname)
				
				TFBSmatrix <- unclass(table(
								factor(seqnames(hits), levels = seqlevels(hits)),
								factor(hits$pwmIdName, levels = unique(hits$pwmIdName))
						))
				
				zero_TF <- colSums(TFBSmatrix) == 0
				TFBSmatrix <- TFBSmatrix[, !zero_TF, drop = FALSE]
				
				fMono <- oligonucleotideFrequency(seqs, width = 1L, as.prob = TRUE)
				fDi <- oligonucleotideFrequency(seqs, width = 2L, as.prob = TRUE)
				
				fracGC <- fMono[, "G"] + fMono[, "C"]
				oeCpG <- (fDi[, "CG"] + 0.01) / (fMono[, "G"] * fMono[, "C"] + 0.01)
				
				TFBSmatrix <- cbind(
						fracGC = fracGC,
						oeCpG = oeCpG,
						TFBSmatrix
				)
				
				TFBSmatrix <- TFBSmatrix[names(gr), , drop = FALSE]
				
				cat("predictor matrix dim:", paste(dim(TFBSmatrix), collapse = " x "), "\n")
				
				set.seed(seed)
				
				se_reg <- randLassoStabSel(
						x = TFBSmatrix,
						y = gr$logFC,
						cutoff = stabsel_cutoff
				)
				
				saveRDS(se_reg, file.path(reg_dir, "regression_SE.rds"))
				
				sel_TFs <- colnames(se_reg)[se_reg$selected]
				
				cat(
						"selected TFs (",
						length(sel_TFs),
						"): ",
						paste(sel_TFs, collapse = ", "),
						"\n",
						sep = ""
				)
				
				col_data <- as.data.frame(
						colData(se_reg),
						optional = TRUE,
						stringsAsFactors = FALSE
				)
				
				cat(
						"colData columns (",
						ncol(col_data),
						"): ",
						paste(colnames(col_data), collapse = ", "),
						"\n",
						sep = ""
				)
				
				np <- length(colnames(se_reg))
				
				sel_df <- data.frame(
						predictor = colnames(se_reg),
						stringsAsFactors = FALSE
				)
				
				for (cn in colnames(col_data)) {
					v <- col_data[[cn]]
					
					if (length(v) == np) {
						sel_df[[cn]] <- v
					} else {
						cat(
								"  - skipping colData$",
								cn,
								" (length ",
								length(v),
								" != predictors ",
								np,
								")\n",
								sep = ""
						)
					}
				}
				
				if ("selProb" %in% colnames(sel_df)) {
					sel_df <- sel_df[order(-sel_df$selProb), ]
				}
				
				write.table(
						sel_df,
						file.path(reg_dir, "selected_TFs.tsv"),
						sep = "\t",
						quote = FALSE,
						row.names = FALSE
				)
				
				tryCatch({
							pdf(
									file.path(reg_dir, "stability_paths.pdf"),
									width = 8,
									height = 6
							)
							
							invisible(print(plotStabilityPaths(se_reg, labelPaths = TRUE)))
							
							dev.off()
						}, error = function(e) {
							safe_dev_off()
							cat("  [skip] stability_paths.pdf: ", conditionMessage(e), "\n", sep = "")
						})
				
				gc_ok <- tryCatch({
							pdf(
									file.path(reg_dir, "stability_paths_GCpredictors.pdf"),
									width = 8,
									height = 6
							)
							
							invisible(print(plotStabilityPaths(
													se_reg,
													labelPaths = TRUE,
													labelNudgeX = 3,
													labels = c("fracGC", "oeCpG")
											)))
							
							dev.off()
							TRUE
						}, error = function(e) {
							safe_dev_off()
							cat(
									"  plotStabilityPaths(labels=...) failed (",
									conditionMessage(e),
									") - retrying without labels arg\n",
									sep = ""
							)
							FALSE
						})
				
				if (!isTRUE(gc_ok)) {
					tryCatch({
								pdf(
										file.path(reg_dir, "stability_paths_GCpredictors.pdf"),
										width = 8,
										height = 6
								)
								
								invisible(print(plotStabilityPaths(
														se_reg,
														labelPaths = TRUE,
														labelNudgeX = 3
												)))
								
								dev.off()
							}, error = function(e2) {
								safe_dev_off()
								cat(
										"  [skip] stability_paths_GCpredictors.pdf: ",
										conditionMessage(e2),
										"\n",
										sep = ""
								)
							})
				}
				
				if (length(sel_TFs) >= 1) {
					tryCatch({
								pdf(
										file.path(reg_dir, "selection_probability.pdf"),
										width = 8,
										height = 6
								)
								
								invisible(print(plotSelectionProb(
														se_reg,
														directional = TRUE,
														ylimext = 1
												)))
								
								dev.off()
							}, error = function(e) {
								safe_dev_off()
								cat(
										"  [skip] selection_probability.pdf: ",
										conditionMessage(e),
										"\n",
										sep = ""
								)
							})
					
					top_dir <- file.path(reg_dir, "top_enhancers_per_TF")
					dir.create(top_dir, showWarnings = FALSE, recursive = TRUE)
					
					for (TF in sel_TFs) {
						i <- which(assay(se_reg, "x")[, TF] > 0)
						
						if (length(i) == 0) {
							next
						}
						
						o <- order(abs(gr$logFC[i]), decreasing = TRUE)
						top_gr <- gr[i][o]
						
						top_df <- as.data.frame(top_gr)
						top_df$enhancer_id <- names(top_gr)
						
						fname <- gsub("[^A-Za-z0-9._-]+", "_", TF)
						
						write.table(
								top_df,
								file.path(top_dir, paste0(fname, ".tsv")),
								sep = "\t",
								quote = FALSE,
								row.names = FALSE
						)
					}
					
					cat("per-TF top enhancer tables:", top_dir, "\n")
				} else {
					cat(
							"no TFs selected at cutoff ",
							stabsel_cutoff,
							" - plotSelectionProb skipped\n",
							sep = ""
					)
				}
				
				TRUE
			}, error = function(e) {
				cat("######## REGRESSION FAILED ########\n", file = stderr())
				cat("error: ", conditionMessage(e), "\n", file = stderr())
				cat("regression outputs will NOT be produced\n", file = stderr())
				FALSE
			})
	
	cat("regression step OK:", reg_ok, "\n\n")
} else {
	cat("############################## Step 7: regression SKIPPED\n\n")
}

# ------------------------------------------------------------
# Done
# ------------------------------------------------------------
writeLines(
		capture.output(sessionInfo()),
		file.path(output_dir, "session_info.txt")
)

cat("\n############################## Done\n")
cat("  DA CSV used      =", da_csv, "\n")
cat("  norm             =", norm_filename, "\n")
cat("  input GRanges    =", length(gr), "ranges\n")
cat("  QC plots         =", qc_dir, "\n")
cat("  binned enrich    =", bin_dir, "\n")
cat("  k-mer            =", kmer_dir, "\n")
cat("  regression       =", reg_dir, "\n")
cat("End time:", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "\n")