#!/usr/bin/env Rscript

suppressPackageStartupMessages({
			library(optparse)
			library(ChIPseeker)
			library(GenomicFeatures)
			library(txdbmaker)
			library(GenomicRanges)
			library(rtracklayer)
			library(ggplot2)
			library(readr)
			library(dplyr)
		})

# ==============================================================================
# Convert Bio-Express key=value arguments to optparse style
# ==============================================================================

convert_key_value_args <- function(args) {
	converted_args <- character(0)
	
	for (arg in args) {
		if (grepl("^[A-Za-z_][A-Za-z0-9_]*=", arg)) {
			key <- sub("=.*$", "", arg)
			value <- sub("^[^=]*=", "", arg)
			
			value <- sub('^"', "", value)
			value <- sub('"$', "", value)
			value <- sub("^'", "", value)
			value <- sub("'$", "", value)
			
			converted_args <- c(converted_args, paste0("--", key), value)
		} else {
			converted_args <- c(converted_args, arg)
		}
	}
	
	return(converted_args)
}

# ==============================================================================
# Options
# ==============================================================================

option_list <- list(
		make_option(
				c("--input_dir"),
				type = "character",
				help = "Directory containing peak files from MACS2/MACS3"
		),
		make_option(
				c("--output_dir"),
				type = "character",
				help = "Directory for ChIPseeker annotation results"
		),
		make_option(
				c("--genome_gff"),
				type = "character",
				help = "Genome annotation file in GFF3/GTF format"
		),
		make_option(
				c("--genome_label"),
				type = "character",
				default = "custom_genome",
				help = "Genome/species label used for logs [default: %default]"
		),
		make_option(
				c("--peak_suffix"),
				type = "character",
				default = ".narrowPeak",
				help = "Peak file suffix: .narrowPeak, .broadPeak, .bed, etc. [default: %default]"
		),
		make_option(
				c("--tss_upstream"),
				type = "integer",
				default = 3000,
				help = "TSS upstream region [default: %default]"
		),
		make_option(
				c("--tss_downstream"),
				type = "integer",
				default = 3000,
				help = "TSS downstream region [default: %default]"
		),
		make_option(
				c("--max_files"),
				type = "character",
				default = "NA",
				help = "Maximum number of peak files to process. NA means all files [default: %default]"
		)
)

raw_args <- commandArgs(trailingOnly = TRUE)
converted_args <- convert_key_value_args(raw_args)

opt <- parse_args(
		OptionParser(option_list = option_list),
		args = converted_args
)

# ==============================================================================
# Helper functions
# ==============================================================================

log_msg <- function(..., log_file = NULL) {
	txt <- paste0(...)
	message(txt)
	if (!is.null(log_file)) {
		cat(txt, "\n", file = log_file, append = TRUE)
	}
}

stop_if_missing <- function(x, name) {
	if (is.null(x) || is.na(x) || x == "") {
		stop("[ERROR] Missing required option: ", name, call. = FALSE)
	}
}

parse_integer_or_na <- function(x, name) {
	if (is.null(x) || is.na(x) || x == "" || toupper(as.character(x)) == "NA") {
		return(NA_integer_)
	}
	
	out <- suppressWarnings(as.integer(x))
	
	if (is.na(out)) {
		stop("[ERROR] ", name, " must be integer or NA: ", x, call. = FALSE)
	}
	
	return(out)
}

sanitize_sample_name <- function(x) {
	x <- basename(x)
	
	x <- sub("\\.narrowPeak$", "", x)
	x <- sub("\\.broadPeak$", "", x)
	x <- sub("\\.bed$", "", x)
	
	x <- sub("_peaks$", "", x)
	x <- sub("_summits$", "", x)
	x <- sub("_treat_pileup$", "", x)
	x <- sub("_control_lambda$", "", x)
	
	x <- gsub("[^A-Za-z0-9_.-]", "_", x)
	
	return(x)
}

detect_gff_format <- function(genome_gff) {
	ext <- tolower(basename(genome_gff))
	
	if (grepl("\\.gtf$|\\.gtf\\.gz$", ext)) {
		return("gtf")
	}
	
	if (grepl("\\.gff$|\\.gff3$|\\.gff\\.gz$|\\.gff3\\.gz$", ext)) {
		return("gff3")
	}
	
	return("auto")
}

check_peak_file_shape <- function(peak_file) {
	if (!file.exists(peak_file)) {
		return(list(valid = FALSE, reason = "file does not exist"))
	}
	
	if (file.info(peak_file)$size == 0) {
		return(list(valid = FALSE, reason = "empty file"))
	}
	
	first_line <- readLines(peak_file, n = 1, warn = FALSE)
	
	if (length(first_line) == 0) {
		return(list(valid = FALSE, reason = "no readable line"))
	}
	
	col_count <- length(strsplit(first_line, "\t")[[1]])
	line_count <- length(readLines(peak_file, warn = FALSE))
	
	preview <- tryCatch({
				read.table(
						peak_file,
						header = FALSE,
						sep = "\t",
						quote = "",
						comment.char = "",
						nrows = 3,
						fill = TRUE
				)
			}, error = function(e) {
				NULL
			})
	
	if (is.null(preview)) {
		return(list(
						valid = FALSE,
						reason = "failed to read table",
						lines = line_count,
						columns = col_count
				))
	}
	
	if (ncol(preview) < 3) {
		return(list(
						valid = FALSE,
						reason = "fewer than 3 columns",
						lines = line_count,
						columns = ncol(preview),
						preview = preview
				))
	}
	
	return(list(
					valid = TRUE,
					reason = "ok",
					lines = line_count,
					columns = ncol(preview),
					preview = preview
			))
}

check_gff_shape <- function(genome_gff) {
	if (!file.exists(genome_gff)) {
		return(list(valid = FALSE, reason = "file does not exist"))
	}
	
	if (file.info(genome_gff)$size == 0) {
		return(list(valid = FALSE, reason = "empty file"))
	}
	
	preview <- tryCatch({
				if (grepl("\\.gz$", genome_gff)) {
					con <- gzfile(genome_gff, open = "rt")
					on.exit(close(con), add = TRUE)
					lines <- readLines(con, n = 200, warn = FALSE)
				} else {
					lines <- readLines(genome_gff, n = 200, warn = FALSE)
				}
				
				lines <- lines[!grepl("^#", lines)]
				lines <- lines[nchar(lines) > 0]
				head(lines, 5)
			}, error = function(e) {
				NULL
			})
	
	if (is.null(preview) || length(preview) == 0) {
		return(list(valid = FALSE, reason = "no readable feature lines"))
	}
	
	col_counts <- sapply(strsplit(preview, "\t"), length)
	
	if (all(col_counts < 8)) {
		return(list(
						valid = FALSE,
						reason = "feature lines do not look like GFF/GTF",
						preview = preview,
						columns = paste(col_counts, collapse = ",")
				))
	}
	
	return(list(
					valid = TRUE,
					reason = "ok",
					preview = preview,
					columns = paste(col_counts, collapse = ",")
			))
}

build_txdb_from_gff <- function(genome_gff, log_file = NULL) {
	format <- detect_gff_format(genome_gff)
	
	log_msg("[setup] Building TxDb from genome_gff: ", genome_gff, log_file = log_file)
	log_msg("[setup] Detected annotation format: ", format, log_file = log_file)
	
	txdb <- tryCatch({
				if (format == "auto") {
					txdbmaker::makeTxDbFromGFF(genome_gff)
				} else {
					txdbmaker::makeTxDbFromGFF(genome_gff, format = format)
				}
			}, error = function(e) {
				log_msg("[ERROR] makeTxDbFromGFF failed: ", e$message, log_file = log_file)
				NULL
			})
	
	if (is.null(txdb)) {
		stop("[ERROR] Failed to build TxDb from genome_gff.", call. = FALSE)
	}
	
	return(txdb)
}

write_log_header <- function(log_file, opt, raw_args, converted_args) {
	cat("############################## ChIPseeker Peak Annotation\n", file = log_file)
	cat("Start time: ", as.character(Sys.time()), "\n\n", file = log_file, append = TRUE)
	
	cat("raw arguments:\n", file = log_file, append = TRUE)
	for (x in raw_args) {
		cat("  ", x, "\n", file = log_file, append = TRUE)
	}
	cat("\n", file = log_file, append = TRUE)
	
	cat("converted arguments:\n", file = log_file, append = TRUE)
	for (x in converted_args) {
		cat("  ", x, "\n", file = log_file, append = TRUE)
	}
	cat("\n", file = log_file, append = TRUE)
	
	cat("parameters:\n", file = log_file, append = TRUE)
	cat("  input_dir      = ", opt$input_dir, "\n", file = log_file, append = TRUE)
	cat("  output_dir     = ", opt$output_dir, "\n", file = log_file, append = TRUE)
	cat("  genome_gff     = ", opt$genome_gff, "\n", file = log_file, append = TRUE)
	cat("  genome_label   = ", opt$genome_label, "\n", file = log_file, append = TRUE)
	cat("  peak_suffix    = ", opt$peak_suffix, "\n", file = log_file, append = TRUE)
	cat("  tss_upstream   = ", opt$tss_upstream, "\n", file = log_file, append = TRUE)
	cat("  tss_downstream = ", opt$tss_downstream, "\n", file = log_file, append = TRUE)
	cat("  max_files      = ", opt$max_files, "\n\n", file = log_file, append = TRUE)
}

safe_close_pdf <- function() {
	try({
				while (dev.cur() > 1) {
					dev.off()
				}
			}, silent = TRUE)
}

remove_empty_pdf <- function(pdf_file, min_size = 1000, log_file = NULL) {
	if (file.exists(pdf_file)) {
		size <- file.info(pdf_file)$size
		if (is.na(size) || size < min_size) {
			unlink(pdf_file, force = TRUE)
			log_msg("[WARN] Removed empty/suspicious PDF: ", pdf_file, log_file = log_file)
			return(TRUE)
		}
	}
	return(FALSE)
}

plot_to_pdf <- function(plot_expr, out_pdf, width = 8, height = 6, log_file = NULL, label = "plot") {
	ok <- FALSE
	
	tryCatch({
				pdf(out_pdf, width = width, height = height)
				force(plot_expr)
				dev.off()
				
				if (file.exists(out_pdf) && file.info(out_pdf)$size >= 1000) {
					log_msg("[output] ", label, ": ", out_pdf, log_file = log_file)
					ok <- TRUE
				} else {
					remove_empty_pdf(out_pdf, log_file = log_file)
				}
			}, error = function(e) {
				safe_close_pdf()
				remove_empty_pdf(out_pdf, log_file = log_file)
				log_msg("[WARN] ", label, " failed: ", e$message, log_file = log_file)
			})
	
	return(ok)
}

extract_gene_table <- function(anno_df) {
	if (!"geneId" %in% colnames(anno_df)) {
		return(data.frame())
	}
	
	gene_df <- anno_df %>%
			filter(!is.na(geneId), geneId != "") %>%
			group_by(geneId) %>%
			summarise(
					peak_count = n(),
					min_distance_to_tss = if ("distanceToTSS" %in% colnames(.)) {
								suppressWarnings(min(abs(distanceToTSS), na.rm = TRUE))
							} else {
								NA_real_
							},
					annotations = paste(sort(unique(annotation)), collapse = ";"),
					.groups = "drop"
			) %>%
			arrange(desc(peak_count), min_distance_to_tss)
	
	return(as.data.frame(gene_df))
}

simplify_annotation_category <- function(x) {
	x <- as.character(x)
	
	dplyr::case_when(
			grepl("^Promoter", x, ignore.case = TRUE) ~ "Promoter",
			grepl("^5' UTR", x, ignore.case = TRUE) ~ "5' UTR",
			grepl("^3' UTR", x, ignore.case = TRUE) ~ "3' UTR",
			grepl("^Exon", x, ignore.case = TRUE) ~ "Exon",
			grepl("^Intron", x, ignore.case = TRUE) ~ "Intron",
			grepl("^Downstream", x, ignore.case = TRUE) ~ "Downstream",
			grepl("^Distal Intergenic", x, ignore.case = TRUE) ~ "Distal Intergenic",
			grepl("Intergenic", x, ignore.case = TRUE) ~ "Intergenic",
			is.na(x) | x == "" ~ "Unknown",
			TRUE ~ "Other"
	)
}

get_gene_universe <- function(txdb, log_file = NULL) {
	universe <- tryCatch({
				names(genes(txdb))
			}, error = function(e) {
				log_msg("[WARN] Failed to extract gene universe from TxDb: ", e$message, log_file = log_file)
				character(0)
			})
	
	universe <- unique(universe[!is.na(universe) & universe != ""])
	return(universe)
}

# ==============================================================================
# Validation
# ==============================================================================

stop_if_missing(opt$input_dir, "input_dir")
stop_if_missing(opt$output_dir, "output_dir")
stop_if_missing(opt$genome_gff, "genome_gff")

opt$max_files <- parse_integer_or_na(opt$max_files, "max_files")

if (!dir.exists(opt$input_dir)) {
	stop("[ERROR] input_dir does not exist: ", opt$input_dir, call. = FALSE)
}

if (!file.exists(opt$genome_gff)) {
	stop("[ERROR] genome_gff does not exist: ", opt$genome_gff, call. = FALSE)
}

if (is.null(opt$peak_suffix) || is.na(opt$peak_suffix) || opt$peak_suffix == "") {
	stop("[ERROR] peak_suffix is empty", call. = FALSE)
}
# ==============================================================================
# Prepare output directory
# Clean previous run outputs but keep logs/
# ==============================================================================

dir.create(opt$output_dir, recursive = TRUE, showWarnings = FALSE)

clean_output_dir_keep_logs <- function(output_dir, log_dir_name = "logs") {
	if (!dir.exists(output_dir)) {
		dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
		return(invisible(TRUE))
	}
	
	items <- list.files(
			output_dir,
			all.files = TRUE,
			no.. = TRUE,
			full.names = TRUE
	)
	
	if (length(items) == 0) {
		return(invisible(TRUE))
	}
	
	log_dir_path <- normalizePath(
			file.path(output_dir, log_dir_name),
			mustWork = FALSE
	)
	
	items_to_remove <- items[
			normalizePath(items, mustWork = FALSE) != log_dir_path
	]
	
	if (length(items_to_remove) > 0) {
		unlink(items_to_remove, recursive = TRUE, force = TRUE)
	}
	
	invisible(TRUE)
}

clean_output_dir_keep_logs(opt$output_dir)

annotation_dir <- file.path(opt$output_dir, "annotation")
plot_dir <- file.path(opt$output_dir, "plots")
gene_dir <- file.path(opt$output_dir, "gene_lists")
log_dir <- file.path(opt$output_dir, "logs")

dir.create(annotation_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(gene_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(log_dir, recursive = TRUE, showWarnings = FALSE)

log_file <- file.path(
		log_dir,
		paste0("chipseeker_peak_annotation_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".log")
)

write_log_header(log_file, opt, raw_args, converted_args)

if (!requireNamespace("ggupset", quietly = TRUE)) {
	log_msg("[WARN] Package ggupset is not installed. upsetplot(vennpie=TRUE) will be skipped.", log_file = log_file)
}

# ==============================================================================
# Input GFF/GTF shape check
# ==============================================================================

log_msg("[check] Checking genome_gff shape...", log_file = log_file)

gff_shape <- check_gff_shape(opt$genome_gff)

log_msg("  genome_gff : ", opt$genome_gff, log_file = log_file)
log_msg("  status     : ", gff_shape$reason, log_file = log_file)

if (!is.null(gff_shape$columns)) {
	log_msg("  columns    : ", gff_shape$columns, log_file = log_file)
}

if (!is.null(gff_shape$preview)) {
	log_msg("  preview:", log_file = log_file)
	for (line in gff_shape$preview) {
		log_msg("    ", line, log_file = log_file)
	}
}

if (!gff_shape$valid) {
	stop("[ERROR] genome_gff failed shape check: ", gff_shape$reason, call. = FALSE)
}

# ==============================================================================
# Input peak file shape check
# ==============================================================================

log_msg("[check] Searching peak files...", log_file = log_file)

peak_pattern <- paste0("\\", opt$peak_suffix, "$")

peak_files <- list.files(
		opt$input_dir,
		pattern = peak_pattern,
		recursive = TRUE,
		full.names = TRUE
)

peak_files <- sort(peak_files)

if (length(peak_files) == 0) {
	available_files <- list.files(
			opt$input_dir,
			recursive = TRUE,
			full.names = TRUE
	)
	
	log_msg("[ERROR] No peak files found.", log_file = log_file)
	log_msg("        input_dir   : ", opt$input_dir, log_file = log_file)
	log_msg("        peak_suffix : ", opt$peak_suffix, log_file = log_file)
	log_msg("[INFO] Available files:", log_file = log_file)
	
	if (length(available_files) > 0) {
		for (x in head(available_files, 50)) {
			log_msg("  ", x, log_file = log_file)
		}
	} else {
		log_msg("  No files found under input_dir.", log_file = log_file)
	}
	
	stop("[ERROR] No peak files found.", call. = FALSE)
}

if (!is.na(opt$max_files)) {
	peak_files <- head(peak_files, opt$max_files)
}

log_msg("[check] Found ", length(peak_files), " peak file(s):", log_file = log_file)

for (x in peak_files) {
	log_msg("  ", x, log_file = log_file)
}

valid_peak_files <- character(0)
shape_summary <- list()

log_msg("[check] Checking peak file shape...", log_file = log_file)

for (peak_file in peak_files) {
	log_msg("------------------------------------------------------------", log_file = log_file)
	log_msg("[check] File: ", peak_file, log_file = log_file)
	
	shape <- check_peak_file_shape(peak_file)
	
	if (!is.null(shape$lines)) {
		log_msg("  lines   : ", shape$lines, log_file = log_file)
	}
	
	if (!is.null(shape$columns)) {
		log_msg("  columns : ", shape$columns, log_file = log_file)
	}
	
	log_msg("  status  : ", shape$reason, log_file = log_file)
	
	if (!is.null(shape$preview)) {
		log_msg("  preview:", log_file = log_file)
		preview_text <- capture.output(print(shape$preview))
		for (line in preview_text) {
			log_msg("    ", line, log_file = log_file)
		}
	}
	
	shape_summary[[peak_file]] <- data.frame(
			peak_file = peak_file,
			valid = shape$valid,
			reason = shape$reason,
			lines = ifelse(is.null(shape$lines), NA, shape$lines),
			columns = ifelse(is.null(shape$columns), NA, shape$columns),
			stringsAsFactors = FALSE
	)
	
	if (shape$valid) {
		valid_peak_files <- c(valid_peak_files, peak_file)
	}
}

shape_summary_df <- bind_rows(shape_summary)

write.table(
		shape_summary_df,
		file = file.path(annotation_dir, "input_peak_file_shape_summary.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

if (length(valid_peak_files) == 0) {
	stop("[ERROR] No valid peak files remained after shape check.", call. = FALSE)
}

log_msg("[check] Valid peak files: ", length(valid_peak_files), log_file = log_file)

# ==============================================================================
# Build TxDb from GFF/GTF
# ==============================================================================

txdb <- build_txdb_from_gff(opt$genome_gff, log_file = log_file)

txdb_summary <- tryCatch({
			data.frame(
					genome_label = opt$genome_label,
					genome_gff = opt$genome_gff,
					transcript_count = length(transcripts(txdb)),
					gene_count = length(genes(txdb)),
					stringsAsFactors = FALSE
			)
		}, error = function(e) {
			data.frame(
					genome_label = opt$genome_label,
					genome_gff = opt$genome_gff,
					transcript_count = NA,
					gene_count = NA,
					stringsAsFactors = FALSE
			)
		})

write.table(
		txdb_summary,
		file = file.path(annotation_dir, "txdb_summary.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

log_msg("[setup] TxDb summary:", log_file = log_file)
log_msg("  transcript_count : ", txdb_summary$transcript_count, log_file = log_file)
log_msg("  gene_count       : ", txdb_summary$gene_count, log_file = log_file)

# Gene universe

gene_universe <- get_gene_universe(txdb, log_file = log_file)

write.table(
		data.frame(gene_id = gene_universe, stringsAsFactors = FALSE),
		file = file.path(gene_dir, "txdb_gene_universe.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

log_msg("[setup] Gene universe from TxDb: ", length(gene_universe), log_file = log_file)

# ==============================================================================
# Promoter regions for TSS profile
# ==============================================================================

promoter <- tryCatch({
			getPromoters(
					TxDb = txdb,
					upstream = opt$tss_upstream,
					downstream = opt$tss_downstream
			)
		}, error = function(e) {
			log_msg("[WARN] getPromoters() failed: ", e$message, log_file = log_file)
			log_msg("[WARN] TSS profile plots will be skipped.", log_file = log_file)
			NULL
		})

if (!is.null(promoter)) {
	log_msg(
			"[setup] Promoter regions for TSS profile: ", length(promoter),
			" windows (+/-", opt$tss_upstream, "/", opt$tss_downstream, " bp)",
			log_file = log_file
	)
}

# ==============================================================================
# Run ChIPseeker
# ==============================================================================

summary_list <- list()
gene_list_summary <- list()

for (peak_file in valid_peak_files) {
	sample_name <- sanitize_sample_name(peak_file)
	
	log_msg("------------------------------------------------------------", log_file = log_file)
	log_msg("[run] Processing: ", peak_file, log_file = log_file)
	log_msg("[run] Sample name: ", sample_name, log_file = log_file)
	
	peak_anno <- tryCatch({
				annotatePeak(
						peak_file,
						tssRegion = c(-opt$tss_upstream, opt$tss_downstream),
						TxDb = txdb,
						annoDb = NULL,
						verbose = FALSE
				)
			}, error = function(e) {
				log_msg("[ERROR] annotatePeak failed: ", e$message, log_file = log_file)
				NULL
			})
	
	if (is.null(peak_anno)) {
		next
	}
	
	anno_df <- as.data.frame(peak_anno)
	
	log_msg("[run] Annotated peaks: ", nrow(anno_df), log_file = log_file)
	
	anno_tsv <- file.path(annotation_dir, paste0(sample_name, ".annotated_peaks.tsv"))
	anno_rds <- file.path(annotation_dir, paste0(sample_name, ".annotated_peaks.rds"))
	
	write.table(
			anno_df,
			file = anno_tsv,
			sep = "\t",
			quote = FALSE,
			row.names = FALSE
	)
	
	saveRDS(peak_anno, file = anno_rds)
	
	log_msg("[output] Annotation TSV: ", anno_tsv, log_file = log_file)
	log_msg("[output] Annotation RDS: ", anno_rds, log_file = log_file)
	
	# --------------------------------------------------------------------------
	# Gene list output
	# --------------------------------------------------------------------------
	
	gene_df <- extract_gene_table(anno_df)
	
	if (nrow(gene_df) > 0) {
		gene_tsv <- file.path(gene_dir, paste0(sample_name, ".annotated_gene_list.tsv"))
		
		write.table(
				gene_df,
				file = gene_tsv,
				sep = "\t",
				quote = FALSE,
				row.names = FALSE
		)
		
		log_msg("[output] Gene list TSV: ", gene_tsv, log_file = log_file)
		
		gene_list_summary[[sample_name]] <- data.frame(
				sample = sample_name,
				peak_file = peak_file,
				unique_gene_count = nrow(gene_df),
				stringsAsFactors = FALSE
		)
	} else {
		log_msg("[WARN] No gene list generated for sample: ", sample_name, log_file = log_file)
	}
	
	# --------------------------------------------------------------------------
	# Per-sample plots
	# --------------------------------------------------------------------------
	
	plot_to_pdf(
			plot_expr = {
				print(plotAnnoPie(peak_anno))
			},
			out_pdf = file.path(plot_dir, paste0(sample_name, ".annotation_pie.pdf")),
			width = 7,
			height = 7,
			log_file = log_file,
			label = "Annotation pie PDF"
	)
	
	plot_to_pdf(
			plot_expr = {
				print(plotAnnoBar(peak_anno))
			},
			out_pdf = file.path(plot_dir, paste0(sample_name, ".annotation_bar.pdf")),
			width = 9,
			height = 6,
			log_file = log_file,
			label = "Annotation bar PDF"
	)
	
	plot_to_pdf(
			plot_expr = {
				print(plotDistToTSS(
								peak_anno,
								title = paste0(sample_name, " - Distribution of distance to TSS")
						))
			},
			out_pdf = file.path(plot_dir, paste0(sample_name, ".distance_to_tss.pdf")),
			width = 8,
			height = 6,
			log_file = log_file,
			label = "Distance to TSS PDF"
	)
	
	# --------------------------------------------------------------------------
	# NBIS-style annotation upset plot
	# --------------------------------------------------------------------------
	
	tryCatch({
				has_ggupset <- requireNamespace("ggupset", quietly = TRUE)
				
				if (has_ggupset) {
					p_upset_vennpie <- upsetplot(peak_anno, vennpie = TRUE)
					
					out_vennpie_pdf <- file.path(
							plot_dir,
							paste0(sample_name, ".annotation_upset_vennpie.pdf")
					)
					
					plot_to_pdf(
							plot_expr = {
								print(p_upset_vennpie)
							},
							out_pdf = out_vennpie_pdf,
							width = 10,
							height = 7,
							log_file = log_file,
							label = "Annotation upset+vennpie PDF"
					)
				} else {
					log_msg(
							"[WARN] Package ggupset is not installed. Skipping vennpie version for sample: ",
							sample_name,
							log_file = log_file
					)
				}
				
				p_upset <- upsetplot(peak_anno)
				
				out_plain_upset_pdf <- file.path(
						plot_dir,
						paste0(sample_name, ".annotation_upset.pdf")
				)
				
				plot_to_pdf(
						plot_expr = {
							print(p_upset)
						},
						out_pdf = out_plain_upset_pdf,
						width = 10,
						height = 7,
						log_file = log_file,
						label = "Annotation upset PDF"
				)
			}, error = function(e) {
				log_msg("[WARN] upset plot failed: ", e$message, log_file = log_file)
				safe_close_pdf()
			})
	
	# --------------------------------------------------------------------------
	# TSS profile and heatmap
	# --------------------------------------------------------------------------
	
	if (!is.null(promoter)) {
		tryCatch({
					peaks_gr <- readPeakFile(peak_file)
					tagMatrix <- getTagMatrix(peaks_gr, windows = promoter)
					
					out_tss_profile_pdf <- file.path(
							plot_dir,
							paste0(sample_name, ".tss_profile.pdf")
					)
					
					plot_to_pdf(
							plot_expr = {
								print(plotAvgProf(
												tagMatrix,
												xlim = c(-opt$tss_upstream, opt$tss_downstream),
												xlab = "Genomic Region (5'->3')",
												ylab = "Peak Count Frequency"
										))
							},
							out_pdf = out_tss_profile_pdf,
							width = 8,
							height = 6,
							log_file = log_file,
							label = "TSS profile PDF"
					)
					
					out_tss_heatmap_pdf <- file.path(
							plot_dir,
							paste0(sample_name, ".tss_heatmap.pdf")
					)
					
					plot_to_pdf(
							plot_expr = {
								tagHeatmap(tagMatrix)
							},
							out_pdf = out_tss_heatmap_pdf,
							width = 5,
							height = 8,
							log_file = log_file,
							label = "TSS heatmap PDF"
					)
				}, error = function(e) {
					log_msg("[WARN] TSS profile / heatmap plot failed: ", e$message, log_file = log_file)
					safe_close_pdf()
				})
	}
	
	# --------------------------------------------------------------------------
	# Summary table by simplified annotation category
	# --------------------------------------------------------------------------
	
	if ("annotation" %in% colnames(anno_df)) {
		anno_df$annotation_category <- simplify_annotation_category(anno_df$annotation)
		
		anno_summary <- anno_df %>%
				dplyr::count(annotation_category, name = "count") %>%
				dplyr::rename(annotation = annotation_category) %>%
				dplyr::mutate(
						sample = sample_name,
						peak_file = peak_file
				) %>%
				dplyr::select(sample, annotation, count, peak_file)
		
		summary_list[[sample_name]] <- as.data.frame(anno_summary)
	}
}

# ==============================================================================
# Combined summary
# ==============================================================================

if (length(summary_list) > 0) {
	total_summary <- bind_rows(summary_list)
	
	annotation_levels <- c(
			"Promoter",
			"5' UTR",
			"3' UTR",
			"Exon",
			"Intron",
			"Downstream",
			"Distal Intergenic",
			"Intergenic",
			"Other",
			"Unknown"
	)
	
	total_summary$annotation <- factor(
			total_summary$annotation,
			levels = annotation_levels
	)
	
	total_summary <- total_summary %>%
			arrange(sample, annotation)
	
	summary_tsv <- file.path(annotation_dir, "annotation_summary.tsv")
	
	write.table(
			total_summary,
			file = summary_tsv,
			sep = "\t",
			quote = FALSE,
			row.names = FALSE
	)
	
	log_msg("[output] Annotation summary TSV: ", summary_tsv, log_file = log_file)
	
	tryCatch({
				out_summary_pdf <- file.path(plot_dir, "annotation_summary_barplot.pdf")
				
				p <- ggplot(total_summary, aes(x = sample, y = count, fill = annotation)) +
						geom_bar(stat = "identity") +
						theme_bw() +
						theme(
								axis.text.x = element_text(angle = 45, hjust = 1),
								legend.title = element_blank()
						) +
						labs(
								x = "Sample",
								y = "Peak count",
								title = "Peak annotation summary"
						)
				
				plot_to_pdf(
						plot_expr = {
							print(p)
						},
						out_pdf = out_summary_pdf,
						width = 10,
						height = 6,
						log_file = log_file,
						label = "Annotation summary barplot PDF"
				)
			}, error = function(e) {
				log_msg("[WARN] summary barplot failed: ", e$message, log_file = log_file)
				safe_close_pdf()
			})
	
	tryCatch({
				percent_summary <- total_summary %>%
						group_by(sample) %>%
						mutate(percent = count / sum(count) * 100) %>%
						ungroup()
				
				out_summary_percent_pdf <- file.path(plot_dir, "annotation_summary_percent_barplot.pdf")
				
				p_percent <- ggplot(percent_summary, aes(x = sample, y = percent, fill = annotation)) +
						geom_bar(stat = "identity") +
						theme_bw() +
						theme(
								axis.text.x = element_text(angle = 45, hjust = 1),
								legend.title = element_blank()
						) +
						labs(
								x = "Sample",
								y = "Peak percentage (%)",
								title = "Peak annotation summary (%)"
						)
				
				plot_to_pdf(
						plot_expr = {
							print(p_percent)
						},
						out_pdf = out_summary_percent_pdf,
						width = 10,
						height = 6,
						log_file = log_file,
						label = "Annotation summary percent barplot PDF"
				)
			}, error = function(e) {
				log_msg("[WARN] summary percent barplot failed: ", e$message, log_file = log_file)
				safe_close_pdf()
			})
} else {
	log_msg("[WARN] No annotation summary generated.", log_file = log_file)
}

if (length(gene_list_summary) > 0) {
	gene_summary_df <- bind_rows(gene_list_summary)
	
	gene_summary_tsv <- file.path(gene_dir, "annotated_gene_list_summary.tsv")
	
	write.table(
			gene_summary_df,
			file = gene_summary_tsv,
			sep = "\t",
			quote = FALSE,
			row.names = FALSE
	)
	
	log_msg("[output] Gene list summary TSV: ", gene_summary_tsv, log_file = log_file)
}

# ==============================================================================
# Output check
# ==============================================================================

log_msg("------------------------------------------------------------", log_file = log_file)
log_msg("[check] Output files:", log_file = log_file)

output_files <- list.files(opt$output_dir, recursive = TRUE, full.names = TRUE)

for (x in sort(output_files)) {
	log_msg("  ", x, log_file = log_file)
}

log_msg("End time: ", as.character(Sys.time()), log_file = log_file)
log_msg("############################## ChIPseeker Peak Annotation finished", log_file = log_file)