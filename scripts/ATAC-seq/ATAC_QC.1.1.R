#!/usr/bin/env Rscript

# Version 1.1 (changes from ATAC_QC.1.0.R):
#   Tn5 shift and nucleosome splitting read the bamQC clean BAM
#   (02_bam_qc/<sample>/<sample>.clean.bam) instead of the input BAM; the
#   run stops if the clean BAM is missing or has no mapped reads.
#   The clean BAM keeps proper pairs only, so when long fragments were not
#   aligned as proper pairs the trinucleosome split can be empty
#   (SplitStatus=empty_split:trinucleosome). Use ATAC_QC_plot.1.1.R, which
#   plots the non-empty classes.
#   stdout and stderr are kept apart: progress goes to stdout and
#   logs/<stamp>.log; errors, warnings, and package messages go to stderr
#   and logs/<stamp>.error.log. The run stops if output_dir is or contains
#   an input path.

# Usage:
# Rscript ATAC_QC.R \
#   input_dir="..." \
#   sample_data="..." \
#   txs_bed="..." \
#   genome_fasta="..." \
#   output_dir="..." \
#   [seqlev="auto"]
#
# IMPORTANT:
#   input_dir must contain PRE-SHIFT BAM files.
#   Recommended input BAM:
#     *_organellar_removed.bam
#
#   Do NOT use:
#     *.tn5_shifted*.bam
#
# Required sample_data CSV columns:
#   SampleID,Condition,Replicate
#
# Required txs_bed:
#   BED-like file with at least 3 columns.
#   6 columns preferred:
#     chr start end name score strand

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
	emit_err(paste0("ERROR: ", paste(..., collapse = ""), "\n"))
	quit(status = 1)
}

warn_msg <- function(...) {
	emit_err(paste0("WARNING: ", paste(..., collapse = ""), "\n"))
}

msg <- function(...) {
	cat(..., "\n")
}

# ------------------------------------------------------------
# Parse key=value arguments
# ------------------------------------------------------------
args <- commandArgs(TRUE)

for (arg in args) {
	if (!grepl("=", arg, fixed = TRUE)) {
		stop_err("Invalid argument format: ", arg, " / must be key=value")
	}
	
	parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
	key <- parts[1]
	value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
	
	value <- sub('^"(.*)"$', "\\1", value)
	value <- sub("^'(.*)'$", "\\1", value)
	
	if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", key)) {
		stop_err("Invalid key: ", key)
	}
	
	assign(key, value)
}

required_args <- c("input_dir", "sample_data", "txs_bed", "genome_fasta", "output_dir")

for (x in required_args) {
	if (!exists(x)) {
		stop_err("Required parameter missing: ", x)
	}
}

if (!exists("seqlev")) {
	seqlev <- "auto"
}

# ------------------------------------------------------------
# Validate paths
# ------------------------------------------------------------
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (!file.exists(sample_data)) stop_err("sample_data not found: ", sample_data)
if (!file.exists(txs_bed)) stop_err("txs_bed not found: ", txs_bed)
if (!file.exists(genome_fasta)) stop_err("genome_fasta not found: ", genome_fasta)

input_dir <- normalizePath(input_dir, mustWork = TRUE)
sample_data <- normalizePath(sample_data, mustWork = TRUE)
txs_bed <- normalizePath(txs_bed, mustWork = TRUE)
genome_fasta <- normalizePath(genome_fasta, mustWork = TRUE)

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
check_inputs_outside_output(output_dir, c(input_dir, sample_data, txs_bed, genome_fasta))

# ------------------------------------------------------------
# Clean output except logs/
# ------------------------------------------------------------
if (dir.exists(output_dir) && normalizePath(output_dir, mustWork = FALSE) != "/") {
	old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
	old <- old[basename(old) != "logs"]
	if (length(old) > 0) {
		unlink(old, recursive = TRUE, force = TRUE)
	}
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)

logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

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

msg("############################## ATAC_QC")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
msg("  input_dir       = ", input_dir)
msg("  expected BAM    = pre-shift BAM, preferably organellar_removed BAM")
msg("  sample_data     = ", sample_data)
msg("  txs_bed         = ", txs_bed)
msg("  seqlev          = ", seqlev)
msg("  genome_fasta    = ", genome_fasta)
msg("  output_dir      = ", output_dir)
msg("")

# ------------------------------------------------------------
# Package loading
# ------------------------------------------------------------
required_pkgs <- c(
		"ATACseqQC",
		"Rsamtools",
		"GenomicAlignments",
		"GenomicRanges",
		"GenomeInfoDb",
		"IRanges"
)

for (pkg in required_pkgs) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		stop_err("required R package not found: ", pkg)
	}
}

suppressPackageStartupMessages(library(ATACseqQC))
suppressPackageStartupMessages(library(Rsamtools))
suppressPackageStartupMessages(library(GenomicAlignments))
suppressPackageStartupMessages(library(GenomicRanges))
suppressPackageStartupMessages(library(GenomeInfoDb))
suppressPackageStartupMessages(library(IRanges))

# ------------------------------------------------------------
# Output dirs
# ------------------------------------------------------------
frag_dir <- file.path(output_dir, "01_fragment_size")
bamqc_dir <- file.path(output_dir, "02_bam_qc")
shift_root <- file.path(output_dir, "03_shifted_bam")
split_root <- file.path(output_dir, "04_split_bam")
metadata_dir <- file.path(output_dir, "05_metadata")
rds_dir <- file.path(output_dir, "06_rds")

dir.create(frag_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(bamqc_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(shift_root, recursive = TRUE, showWarnings = FALSE)
dir.create(split_root, recursive = TRUE, showWarnings = FALSE)
dir.create(metadata_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(rds_dir, recursive = TRUE, showWarnings = FALSE)

resolved_sheet <- file.path(metadata_dir, "resolved_sample_sheet.tsv")
manifest_file <- file.path(metadata_dir, "atac_qc_manifest.tsv")

# ------------------------------------------------------------
# Helper functions
# ------------------------------------------------------------
read_sample_data <- function(path) {
	x <- read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
	
	need <- c("SampleID", "Condition", "Replicate")
	miss <- setdiff(need, colnames(x))
	
	if (length(miss) > 0) {
		stop_err("sample_data missing columns: ", paste(miss, collapse = ", "))
	}
	
	x$SampleID <- trimws(x$SampleID)
	x$Condition <- trimws(x$Condition)
	x$Replicate <- trimws(as.character(x$Replicate))
	
	if (any(x$SampleID == "")) stop_err("empty SampleID found")
	if (any(x$Condition == "")) stop_err("empty Condition found")
	if (any(x$Replicate == "")) stop_err("empty Replicate found")
	
	msg("sample_data shape: ", nrow(x), " rows x ", ncol(x), " columns")
	msg("sample_data columns: ", paste(colnames(x), collapse = ", "))
	
	x
}

read_txs_bed <- function(path) {
	bed <- read.table(
			path,
			sep = "\t",
			header = FALSE,
			stringsAsFactors = FALSE,
			quote = "",
			comment.char = ""
	)
	
	if (ncol(bed) < 3) {
		stop_err("txs_bed must have at least 3 columns: chr, start, end")
	}
	
	msg("txs_bed shape: ", nrow(bed), " rows x ", ncol(bed), " columns")
	
	colnames(bed)[1:3] <- c("chr", "start", "end")
	
	if (ncol(bed) >= 6) {
		strand <- as.character(bed[[6]])
		strand[!strand %in% c("+", "-", "*")] <- "*"
	} else {
		strand <- rep("*", nrow(bed))
	}
	
	gr <- GenomicRanges::GRanges(
			seqnames = as.character(bed$chr),
			ranges = IRanges::IRanges(
					start = as.integer(bed$start) + 1L,
					end = as.integer(bed$end)
			),
			strand = strand
	)
	
	if (ncol(bed) >= 4) {
		GenomicRanges::mcols(gr)$name <- as.character(bed[[4]])
	}
	
	sort(gr)
}

resolve_bam <- function(input_dir, sample_id) {
	bams <- list.files(input_dir, pattern = "\\.bam$", recursive = TRUE, full.names = TRUE)
	bams <- bams[!grepl("\\.bai$", bams)]
	bams <- bams[!grepl("unsorted", basename(bams), ignore.case = TRUE)]
	
	# ATAC_QC expects pre-shift BAM.
	bams <- bams[!grepl("tn5[_.-]?shift|shifted", basename(bams), ignore.case = TRUE)]
	
	if (length(bams) == 0) {
		stop_err(
				"No pre-shift BAM files found in input_dir: ", input_dir, "\n",
				"Use organellar_removed BAM directory, not Tn5_shift output."
		)
	}
	
	bnames <- basename(bams)
	
	m1 <- grepl(paste0("^", sample_id, "([._-]|$)"), bnames)
	matches <- bams[m1]
	
	if (length(matches) == 0) {
		m2 <- grepl(sample_id, bnames, fixed = TRUE)
		matches <- bams[m2]
	}
	
	if (length(matches) == 0) {
		stop_err("No BAM matched for SampleID: ", sample_id)
	}
	
	# Prefer organellar_removed BAM if multiple BAMs match.
	if (length(matches) > 1) {
		org <- matches[grepl("organellar_removed", basename(matches), ignore.case = TRUE)]
		if (length(org) == 1) {
			matches <- org
		}
	}
	
	if (length(matches) > 1) {
		stop_err(
				"Multiple pre-shift BAMs matched for SampleID: ", sample_id, "\n",
				"Please set input_dir to the exact organellar filter BAM folder.\n",
				paste(matches, collapse = "\n")
		)
	}
	
	bam <- normalizePath(matches[1], mustWork = TRUE)
	
	if (!file.exists(bam)) {
		stop_err("Resolved BAM does not exist: ", bam)
	}
	
	if (dir.exists(bam)) {
		stop_err("Resolved BAM is a directory, not a BAM file: ", bam)
	}
	
	if (!grepl("\\.bam$", bam, ignore.case = TRUE)) {
		stop_err("Resolved file is not .bam: ", bam)
	}
	
	if (grepl("tn5[_.-]?shift|shifted", basename(bam), ignore.case = TRUE)) {
		stop_err(
				"ATAC_QC input must be pre-shift BAM, but resolved BAM looks already shifted: ", bam, "\n",
				"Use organellar_removed BAM as ATAC_QC input_dir."
		)
	}
	
	bam
}

ensure_bam_index <- function(bam) {
	bai1 <- paste0(bam, ".bai")
	bai2 <- sub("\\.bam$", ".bai", bam, ignore.case = TRUE)
	
	if (!file.exists(bai1) && !file.exists(bai2)) {
		msg("Creating BAM index: ", bam)
		Rsamtools::indexBam(bam)
	}
}

get_bam_idxstats <- function(bam) {
	idx <- Rsamtools::idxstatsBam(bam)
	idx <- idx[idx$seqnames != "*", , drop = FALSE]
	idx <- idx[idx$seqlength > 0, , drop = FALSE]
	idx
}

get_bam_seqlevels <- function(bam) {
	idx <- get_bam_idxstats(bam)
	idx$seqnames
}

get_common_seqlev <- function(bam, txs, seqlev_arg) {
	bam_seq <- get_bam_seqlevels(bam)
	txs_seq <- as.character(unique(GenomicRanges::seqnames(txs)))
	
	common <- intersect(bam_seq, txs_seq)
	
	if (length(common) == 0) {
		stop_err(
				"No common seqlevels between BAM and txs_bed.\n",
				"  BAM preview: ", paste(head(bam_seq, 10), collapse = ","), "\n",
				"  txs preview: ", paste(head(txs_seq, 10), collapse = ",")
		)
	}
	
	if (seqlev_arg != "auto") {
		wanted <- trimws(unlist(strsplit(seqlev_arg, ",")))
		common2 <- intersect(common, wanted)
		
		if (length(common2) == 0) {
			stop_err("Provided seqlev has no overlap with BAM/txs common seqlevels: ", seqlev_arg)
		}
		
		return(common2)
	}
	
	common
}

make_which_gr_from_bam <- function(bam, seqlev_use) {
	idx <- get_bam_idxstats(bam)
	idx <- idx[idx$seqnames %in% seqlev_use, , drop = FALSE]
	
	if (nrow(idx) == 0) {
		stop_err("No BAM idxstats rows left after seqlevel filtering")
	}
	
	GenomicRanges::GRanges(
			seqnames = idx$seqnames,
			ranges = IRanges::IRanges(start = 1L, end = as.integer(idx$seqlength))
	)
}

get_bam_tags <- function(bam) {
	possibleTag <- list(
			integer = c(
					"AM", "AS", "CM", "CP", "FI", "H0", "H1", "H2",
					"HI", "IH", "MQ", "NH", "NM", "OP", "PQ", "SM",
					"TC", "UQ"
			),
			character = c(
					"BC", "BQ", "BZ", "CB", "CC", "CO", "CQ", "CR",
					"CS", "CT", "CY", "E2", "FS", "LB", "MC", "MD",
					"MI", "OA", "OC", "OQ", "OX", "PG", "PT", "PU",
					"Q2", "QT", "QX", "R2", "RG", "RX", "SA", "TS",
					"U2"
			)
	)
	
	x <- tryCatch(
			Rsamtools::scanBam(
					Rsamtools::BamFile(bam, yieldSize = 1000),
					param = Rsamtools::ScanBamParam(tag = unlist(possibleTag))
			)[[1]]$tag,
			error = function(e) list()
	)
	
	tags <- names(x)[lengths(x) > 0]
	tags
}

safe_call <- function(expr, label) {
	tryCatch(
			expr,
			error = function(e) {
				stop_err(label, " failed: ", e$message)
			}
	)
}

optional_call <- function(expr, label) {
	tryCatch(
			expr,
			error = function(e) {
				warn_msg(label, " failed: ", e$message)
				NULL
			}
	)
}

count_mapped_reads <- function(bam) {
	tryCatch(
			sum(Rsamtools::idxstatsBam(bam)$mapped),
			error = function(e) NA_integer_
	)
}

check_genome_fasta_seqlevels <- function(genome_fasta, bam_seq) {
	fai_path <- paste0(genome_fasta, ".fai")
	
	if (!file.exists(fai_path)) {
		msg("indexing genome_fasta: ", genome_fasta)
		Rsamtools::indexFa(genome_fasta)
	}
	
	fa_seq <- as.character(GenomeInfoDb::seqnames(Rsamtools::scanFaIndex(genome_fasta)))
	common <- intersect(fa_seq, bam_seq)
	
	msg("genome_fasta seqlevels preview: ", paste(head(fa_seq, 20), collapse = ", "))
	
	if (length(common) == 0) {
		stop_err(
				"No common seqlevels between BAM and genome_fasta.\n",
				"  BAM preview  : ", paste(head(bam_seq, 10), collapse = ","), "\n",
				"  FASTA preview: ", paste(head(fa_seq, 10), collapse = ",")
		)
	}
	
	common
}

# ------------------------------------------------------------
# Read inputs
# ------------------------------------------------------------
msg("############################## Step 1: Read sample_data and txs_bed")

ss <- read_sample_data(sample_data)
txs <- read_txs_bed(txs_bed)

msg("samples:")
print(ss)
msg("")
msg("transcripts/TSS ranges loaded from txs_bed: ", length(txs))
msg("txs seqlevels preview: ", paste(head(unique(as.character(GenomicRanges::seqnames(txs))), 20), collapse = ", "))
msg("")

# ------------------------------------------------------------
# Resolve BAM files
# ------------------------------------------------------------
msg("############################## Step 2: Resolve pre-shift BAM files")

ss$BAM <- vapply(ss$SampleID, function(sid) resolve_bam(input_dir, sid), character(1))

for (bam in ss$BAM) {
	ensure_bam_index(bam)
}

write.table(
		ss,
		file = resolved_sheet,
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

msg("resolved sample sheet:")
print(ss)
msg("")

# ------------------------------------------------------------
# Seqlevel checks
# ------------------------------------------------------------
msg("############################## Step 2.5: Check seqlevels")

all_bam_seq <- unique(unlist(lapply(ss$BAM, get_bam_seqlevels)))
msg("BAM seqlevels union preview: ", paste(head(all_bam_seq, 20), collapse = ", "))

txs_seq <- unique(as.character(GenomicRanges::seqnames(txs)))
common_bam_txs <- intersect(all_bam_seq, txs_seq)

if (length(common_bam_txs) == 0) {
	stop_err(
			"No common seqlevels between BAM and txs_bed.\n",
			"  BAM preview: ", paste(head(all_bam_seq, 10), collapse = ","), "\n",
			"  txs preview: ", paste(head(txs_seq, 10), collapse = ",")
	)
}

common_bam_fa <- check_genome_fasta_seqlevels(genome_fasta, all_bam_seq)

msg("common BAM/TSS seqlevels: ", paste(head(common_bam_txs, 20), collapse = ", "))
msg("common BAM/FASTA seqlevels: ", paste(head(common_bam_fa, 20), collapse = ", "))
msg("")

# ------------------------------------------------------------
# Open genome FASTA
# ------------------------------------------------------------
genome_fa <- Rsamtools::FaFile(genome_fasta)

try(Rsamtools::open.FaFile(genome_fa), silent = TRUE)

on.exit({
			try(Rsamtools::close.FaFile(genome_fa), silent = TRUE)
		}, add = TRUE)

# ------------------------------------------------------------
# Process each BAM
# ------------------------------------------------------------
manifest <- data.frame()

for (i in seq_len(nrow(ss))) {
	sample_id <- ss$SampleID[i]
	condition <- ss$Condition[i]
	replicate <- ss$Replicate[i]
	bam <- ss$BAM[i]
	
	msg("############################## Processing sample: ", sample_id)
	msg("BAM = ", bam)
	
	if (!file.exists(bam)) {
		stop_err(sample_id, " BAM not found: ", bam)
	}
	
	if (dir.exists(bam)) {
		stop_err(sample_id, " BAM path is directory: ", bam)
	}
	
	raw_reads <- count_mapped_reads(bam)
	msg("input pre-shift BAM mapped reads: ", ifelse(is.na(raw_reads), "?", raw_reads))
	
	sample_bamqc_dir <- file.path(bamqc_dir, sample_id)
	sample_shift_dir <- file.path(shift_root, sample_id)
	sample_split_dir <- file.path(split_root, sample_id)
	sample_frag_dir <- file.path(frag_dir, sample_id)
	sample_rds_dir <- file.path(rds_dir, sample_id)
	
	dir.create(sample_bamqc_dir, recursive = TRUE, showWarnings = FALSE)
	dir.create(sample_shift_dir, recursive = TRUE, showWarnings = FALSE)
	dir.create(sample_split_dir, recursive = TRUE, showWarnings = FALSE)
	dir.create(sample_frag_dir, recursive = TRUE, showWarnings = FALSE)
	dir.create(sample_rds_dir, recursive = TRUE, showWarnings = FALSE)
	
	# ------------------------------------------------------------
	# 1. Fragment size distribution
	# ------------------------------------------------------------
	frag_pdf <- file.path(sample_frag_dir, paste0(sample_id, ".fragSizeDist.pdf"))
	
	pdf(frag_pdf, width = 7, height = 5)
	frag_size <- safe_call(
			ATACseqQC::fragSizeDist(bam, sample_id),
			paste0(sample_id, " fragSizeDist")
	)
	dev.off()
	
	saveRDS(frag_size, file.path(sample_rds_dir, paste0(sample_id, ".fragSizeDist.rds")))
	
	# ------------------------------------------------------------
	# 2. bamQC
	# ------------------------------------------------------------
	clean_bam <- file.path(sample_bamqc_dir, paste0(sample_id, ".clean.bam"))
	bamqc_rds <- file.path(sample_rds_dir, paste0(sample_id, ".bamQC.rds"))
	
	qc_stats <- safe_call(
			ATACseqQC::bamQC(bamfile = bam, outPath = clean_bam),
			paste0(sample_id, " bamQC")
	)
	
	saveRDS(qc_stats, bamqc_rds)
	
	qc_scalar <- qc_stats[vapply(qc_stats, function(v) is.atomic(v) && length(v) == 1, logical(1))]
	
	if (length(qc_scalar) > 0) {
		qc_df <- data.frame(
				metric = names(qc_scalar),
				value = vapply(qc_scalar, function(v) as.character(v), character(1)),
				stringsAsFactors = FALSE
		)
		
		write.table(
				qc_df,
				file = file.path(sample_bamqc_dir, paste0(sample_id, ".bamQC.tsv")),
				sep = "\t",
				quote = FALSE,
				row.names = FALSE
		)
	}
	
if (!file.exists(clean_bam) ||
    is.na(file.info(clean_bam)$size) ||
    file.info(clean_bam)$size == 0) {
    stop_err(sample_id, " clean BAM was not created: ", clean_bam)
}

ensure_bam_index(clean_bam)

clean_reads <- count_mapped_reads(clean_bam)
if (is.na(clean_reads) || clean_reads == 0) {
    stop_err(sample_id, " clean BAM has no mapped reads: ", clean_bam)
}

# ------------------------------------------------------------
# 3. Read cleaned BAM as paired alignments
# ------------------------------------------------------------
analysis_bam <- clean_bam
msg("BAM used for Tn5 shift: ", analysis_bam)
msg("clean BAM mapped reads: ", clean_reads)

tags <- get_bam_tags(analysis_bam)
seqlev_use <- get_common_seqlev(analysis_bam, txs, seqlev)

msg("seqlev used: ", paste(seqlev_use, collapse = ","))

which_gr <- make_which_gr_from_bam(analysis_bam, seqlev_use)
txs_use <- GenomeInfoDb::keepSeqlevels(
    txs, seqlev_use, pruning.mode = "coarse"
)

gal <- safe_call(
    ATACseqQC::readBamFile(
        bamFile = analysis_bam,
        tag = tags,
        which = which_gr,
        asMates = TRUE,
        bigFile = TRUE
    ),
    paste0(sample_id, " readBamFile")
)
	msg("readBamFile object class: ", paste(class(gal), collapse = ","))
	
	# ------------------------------------------------------------
	# 4. Tn5 shift inside ATAC_QC
	# ------------------------------------------------------------
	shifted_bam <- file.path(sample_shift_dir, paste0(sample_id, ".shifted.bam"))
	
	gal_shifted <- safe_call(
			ATACseqQC::shiftGAlignmentsList(gal, outbam = shifted_bam),
			paste0(sample_id, " shiftGAlignmentsList")
	)
	
	msg("shiftGAlignmentsList object class: ", paste(class(gal_shifted), collapse = ","))
	
	if (file.exists(shifted_bam)) {
		try(Rsamtools::indexBam(shifted_bam), silent = TRUE)
	}
	
	shifted_reads <- count_mapped_reads(shifted_bam)
	msg("shifted BAM mapped reads: ", ifelse(is.na(shifted_reads), "?", shifted_reads))
	
	saveRDS(gal_shifted, file.path(sample_rds_dir, paste0(sample_id, ".shifted_gal.rds")))
	
	# ------------------------------------------------------------
	# 5. Split reads using ATACseqQC random forest method
	# ------------------------------------------------------------
	obj_rds <- NA_character_
	split_status <- "not_started"
	
	split_bams <- list(
			NucleosomeFree = NA_character_,
			mononucleosome = NA_character_,
			dinucleosome = NA_character_,
			trinucleosome = NA_character_
	)
	
	objs <- optional_call(
			ATACseqQC::splitGAlignmentsByCut(
					gal_shifted,
					txs = txs_use,
					genome = genome_fa,
					outPath = sample_split_dir
			),
			paste0(sample_id, " splitGAlignmentsByCut")
	)
	
	if (!is.null(objs)) {
		obj_rds <- file.path(sample_rds_dir, paste0(sample_id, ".split_objs.rds"))
		saveRDS(objs, obj_rds)
		
		split_bams <- list(
				NucleosomeFree = file.path(sample_split_dir, "NucleosomeFree.bam"),
				mononucleosome = file.path(sample_split_dir, "mononucleosome.bam"),
				dinucleosome = file.path(sample_split_dir, "dinucleosome.bam"),
				trinucleosome = file.path(sample_split_dir, "trinucleosome.bam")
		)
		
		empty_classes <- character(0)
		
		for (nm in names(split_bams)) {
			b <- split_bams[[nm]]
			
			if (!is.na(b) && file.exists(b)) {
				try(Rsamtools::indexBam(b), silent = TRUE)
				n <- count_mapped_reads(b)
				
				msg("  split BAM ", nm, ": ", ifelse(is.na(n), "?", n), " mapped reads")
				
				if (is.na(n) || n == 0) {
					empty_classes <- c(empty_classes, nm)
				}
			} else {
				empty_classes <- c(empty_classes, paste0(nm, "(missing)"))
			}
		}
		
		if (length(empty_classes) > 0) {
			split_status <- paste0("empty_split:", paste(empty_classes, collapse = ","))
			warn_msg(sample_id, " produced empty/missing split BAMs: ", split_status)
		} else {
			split_status <- "done"
		}
	} else {
		split_status <- "failed_optional"
	}
	
	one <- data.frame(
			SampleID = sample_id,
			Condition = condition,
			Replicate = replicate,
			OriginalBAM = bam,
			InputMappedReads = raw_reads,
			CleanBAM = clean_bam,
			BamQCRDS = bamqc_rds,
			ShiftedBAM = shifted_bam,
			ShiftedReads = shifted_reads,
			SplitStatus = split_status,
			SplitDir = sample_split_dir,
			NucleosomeFreeBAM = split_bams$NucleosomeFree,
			MononucleosomeBAM = split_bams$mononucleosome,
			DinucleosomeBAM = split_bams$dinucleosome,
			TrinucleosomeBAM = split_bams$trinucleosome,
			SplitObjectsRDS = obj_rds,
			Seqlevels = paste(seqlev_use, collapse = ","),
			GenomeFastaUsed = genome_fasta,
			stringsAsFactors = FALSE
	)
	
	manifest <- rbind(manifest, one)
	
	msg("sample done: ", sample_id, " / SplitStatus=", split_status)
	msg("")
}

write.table(
		manifest,
		file = manifest_file,
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
n_total <- nrow(manifest)
n_done <- sum(manifest$SplitStatus == "done")
n_empty <- sum(grepl("^empty_split", manifest$SplitStatus))
n_failed <- sum(grepl("^failed", manifest$SplitStatus))

msg("############################## Summary")
msg("  total samples              : ", n_total)
msg("  split done (non-empty BAMs): ", n_done)
msg("  split empty                : ", n_empty)
msg("  split failed               : ", n_failed)

if (n_done == 0) {
	warn_msg("No sample completed splitGAlignmentsByCut(). Check per-sample warnings above.")
}

msg("")
msg("############################## Done")
msg("resolved sample sheet = ", resolved_sheet)
msg("manifest              = ", manifest_file)
msg("output_dir            = ", output_dir)
msg("End time              = ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))