#!/usr/bin/env Rscript
# Version 1.1 (changes from check_reference.1.0.R, CLOSHA 2.0):
#   output_dir (required) holds logs/<stamp>.log (stdout) and logs/<stamp>.error.log
#   (warnings and errors), and reference_columns.tsv, the column report as a table
#   (1.0 only printed it). Warnings and errors go to stderr. The report and the
#   cell-type heuristic are unchanged.
# Spatial module: inspect a single-cell reference before label transfer or RCTD.
#
# Usage:
#   Rscript check_reference.1.1.R reference_rds="..." output_dir="..."
#
# Example:
#   apptainer exec bx_spatial.1.1.sif Rscript check_reference.1.1.R \
#       reference_rds="/ref/brain_reference.rds" output_dir="/out/check_reference"
#
# Arguments (key=value):
#   reference_rds (required) - Single-cell reference: a Seurat object saved as .rds.
#   output_dir    (required) - Output directory.
#
# For each metadata column the log lists its type and, for categorical columns, the
# number of categories and the most frequent values; columns with 2-100 categories are
# tagged [CELLTYPE?] as candidates for reference_label_col (spatial_labelTransfer,
# spatial_rctd).
#
# Outputs (output_dir):
#   reference_columns.tsv  Column, Type, Categories, Candidate, Range_or_top_values
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# A reference without a cell-type-like column is a data result (warning, exit 0). The
# previous output_dir content except logs/ is removed at the start, so the reference
# must not be inside output_dir.

err_con <- NULL
emit_err <- function(txt) {
	cat(txt, file = stderr())
	if (!is.null(err_con)) {
		cat(txt, file = err_con)
		flush(err_con)
	}
}
stop_err <- function(...) {
	emit_err(paste0("ERROR: ", paste0(..., collapse = ""), "\n"))
	quit(status = 1)
}
warn_msg <- function(...) {
	emit_err(paste0("WARNING: ", paste0(..., collapse = ""), "\n"))
}
msg <- function(...) {
	cat(..., "\n", sep = "")
}

# ------------------------------------------------------------
# Arguments
# ------------------------------------------------------------
params <- list()
for (arg in commandArgs(trailingOnly = TRUE)) {
	if (!grepl("=", arg, fixed = TRUE)) stop_err("Invalid argument format: ", arg, " (must be key=value format)")
	key <- trimws(sub("=.*$", "", arg))
	value <- sub("^['\"]", "", sub("['\"]$", "", trimws(sub("^[^=]*=", "", arg))))
	if (!grepl("^[a-zA-Z_][a-zA-Z0-9_]*$", key)) stop_err("Invalid key: ", key)
	if (!key %in% c("reference_rds", "output_dir")) stop_err("Unknown parameter: ", key)
	params[[key]] <- value
}
for (key in c("reference_rds", "output_dir")) {
	if (is.null(params[[key]]) || !nzchar(params[[key]])) stop_err("Required parameter '", key, "' is missing")
}
reference_rds <- normalizePath(params$reference_rds, mustWork = FALSE)
output_dir <- normalizePath(params$output_dir, mustWork = FALSE)
if (!file.exists(reference_rds)) stop_err("reference_rds not found: ", reference_rds)
if (output_dir == "/") stop_err("output_dir must not be /")
if (startsWith(reference_rds, paste0(output_dir, "/"))) {
	stop_err("reference_rds is inside output_dir, which is cleaned on every run: ", reference_rds)
}

# ------------------------------------------------------------
# Output directory (keep logs/) and logs
# ------------------------------------------------------------
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
unlink(old[basename(old) != "logs"], recursive = TRUE, force = TRUE)
logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE)
stamp <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
log_con <- file(file.path(logs_dir, paste0(stamp, ".log")), open = "at")
err_con <- file(file.path(logs_dir, paste0(stamp, ".error.log")), open = "at")
sink(log_con, append = TRUE, split = TRUE)
globalCallingHandlers(
		message = function(m) {
			cat(conditionMessage(m), file = err_con)
			flush(err_con)
		},
		warning = function(w) {
			cat("WARNING: ", conditionMessage(w), "\n", sep = "", file = err_con)
			flush(err_con)
		})

msg("############################## check_reference")
msg("Log files: logs/", stamp, ".log (stdout), logs/", stamp, ".error.log (stderr)")
msg("Start time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
msg("  reference_rds = ", reference_rds)
msg("  output_dir    = ", output_dir)
msg("")

if (!requireNamespace("Seurat", quietly = TRUE)) stop_err("required R package not found: Seurat")
suppressPackageStartupMessages(library(Seurat))

# ------------------------------------------------------------
# Inspect the metadata columns
# ------------------------------------------------------------
msg("############################## Step 1: reference metadata")
ref <- tryCatch(readRDS(reference_rds), error = function(e) stop_err("cannot read reference_rds: ", conditionMessage(e)))
if (!inherits(ref, "Seurat")) stop_err("reference_rds is not a Seurat object (class: ", paste(class(ref), collapse = ", "), ")")
msg("Loaded reference: ", nrow(ref), " genes x ", ncol(ref), " cells; assays: ", paste(Assays(ref), collapse = ", "))
meta <- ref@meta.data
msg("Metadata has ", ncol(meta), " column(s)")

min_categories <- 2L    # at least 2 groups to be a useful label
max_categories <- 100L  # more than this is likely an ID, not a cell type
top_show <- 10L         # category values shown per column

rows <- list()
for (col_name in colnames(meta)) {
	values <- meta[[col_name]]
	if (is.numeric(values)) {
		range_txt <- sprintf("%.3g ~ %.3g", suppressWarnings(min(values, na.rm = TRUE)),
				suppressWarnings(max(values, na.rm = TRUE)))
		msg(sprintf("[SKIP     ] %-20s : numeric (range %s)", col_name, range_txt))
		rows[[col_name]] <- data.frame(Column = col_name, Type = "numeric", Categories = NA, Candidate = "no",
				Range_or_top_values = range_txt)
		next
	}
	counts <- sort(table(as.character(values)), decreasing = TRUE)
	n_cat <- length(counts)
	candidate <- n_cat >= min_categories && n_cat <= max_categories
	n_show <- min(top_show, n_cat)
	preview <- paste(sprintf("%s (%d)", names(counts)[seq_len(n_show)], as.integer(counts[seq_len(n_show)])), collapse = ", ")
	if (n_cat > n_show) preview <- sprintf("%s, ... (+%d more)", preview, n_cat - n_show)
	msg(sprintf("%s %-20s : %d categories -> %s", if (candidate) "[CELLTYPE?]" else "[SKIP     ]", col_name, n_cat, preview))
	rows[[col_name]] <- data.frame(Column = col_name, Type = "categorical", Categories = n_cat,
			Candidate = if (candidate) "yes" else "no", Range_or_top_values = preview)
}
report <- if (length(rows)) do.call(rbind, rows) else
			data.frame(Column = character(0), Type = character(0), Categories = integer(0), Candidate = character(0),
					Range_or_top_values = character(0))
utils::write.table(report, file.path(output_dir, "reference_columns.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "")

msg("")
msg("############################## Summary")
candidates <- report$Column[report$Candidate == "yes"]
if (length(candidates)) {
	msg("Candidate cell-type column(s): ", paste(candidates, collapse = ", "))
} else {
	warn_msg("no categorical column with ", min_categories, "-", max_categories,
			" categories looked like a cell-type annotation; check reference_columns.tsv.")
}
msg("")
msg("############################## Done")
msg("Report: ", file.path(output_dir, "reference_columns.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
