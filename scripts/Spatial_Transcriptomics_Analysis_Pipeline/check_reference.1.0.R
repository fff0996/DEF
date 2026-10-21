#!/usr/bin/env Rscript

# ==============================================================================
# bx_spatial_ref_inspect.r
#
# BiO-EXPRESS spatial transcriptomics pipeline
#
# Reads a single-cell reference Seurat object (.rds) and prints its metadata
# columns to the log, so users can see which column holds cell-type labels
# before running label transfer.
#
# For each metadata column it reports:
#   - column name
#   - type (categorical / numeric)
#   - for categorical columns: number of categories + top values by frequency
#   - a [CELLTYPE?] tag on columns that look like cell-type annotations
#     (categorical, with a reasonable number of categories)
#
# Bio-Express argument format:
#
#   reference_rds=/path/to/reference.rds
# ==============================================================================


# ------------------------------------------------------------------------------
# 1. Parse Bio-Express key=value arguments
# ------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message("[USAGE] Rscript bx_spatial_ref_inspect.r reference_rds=/path/to/reference.rds")
	quit(status = 1)
}


parse_key_value_args <- function(args) {
	
	params <- list()
	
	for (arg in args) {
		
		arg <- sub("^--", "", arg)
		
		if (!grepl("=", arg, fixed = TRUE)) {
			message(sprintf("[FATAL] Invalid argument format: %s", arg))
			message("[FATAL] Expected format: key=value")
			quit(status = 1)
		}
		
		parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
		
		key <- trimws(parts[1])
		
		value <- paste(parts[-1], collapse = "=")
		value <- trimws(value)
		
		value <- sub("^['\"]", "", value)
		value <- sub("['\"]$", "", value)
		
		if (!nzchar(key)) {
			message(sprintf("[FATAL] Empty parameter name: %s", arg))
			quit(status = 1)
		}
		
		params[[key]] <- value
	}
	
	params
}


params <- parse_key_value_args(args)


# ------------------------------------------------------------------------------
# 2. Parameter assignment
# ------------------------------------------------------------------------------

reference_rds <- params$reference_rds


# ------------------------------------------------------------------------------
# 3. Parameter validation
# ------------------------------------------------------------------------------

if (is.null(reference_rds) || !nzchar(reference_rds)) {
	message("[FATAL] reference_rds is required.")
	quit(status = 1)
}


if (!file.exists(reference_rds)) {
	message(sprintf(
					"[FATAL] reference_rds not found: %s",
					reference_rds
			))
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# 4. Logging helper
# ------------------------------------------------------------------------------

log_msg <- function(...) {
	
	cat(sprintf(
					"[%s] %s\n",
					format(Sys.time(), "%Y-%m-%d %H:%M:%S"),
					sprintf(...)
			))
}


# ------------------------------------------------------------------------------
# 5. Required packages
# ------------------------------------------------------------------------------

required_pkgs <- c("Seurat")

missing_pkgs <- required_pkgs[
		!vapply(
				required_pkgs,
				requireNamespace,
				logical(1),
				quietly = TRUE
		)
]

if (length(missing_pkgs) > 0) {
	message(sprintf(
					"[FATAL] Missing package(s): %s",
					paste(missing_pkgs, collapse = ", ")
			))
	quit(status = 1)
}

suppressPackageStartupMessages({
			library(Seurat)
		})


# ------------------------------------------------------------------------------
# 6. Load reference and inspect metadata
# ------------------------------------------------------------------------------

result <- tryCatch({
			
			log_msg("===== Reference Inspect =====")
			log_msg("reference_rds : %s", reference_rds)
			
			
			ref <- readRDS(reference_rds)
			
			
			if (!inherits(ref, "Seurat")) {
				stop("reference_rds is not a Seurat object.")
			}
			
			
			log_msg(
					"Loaded reference: %d genes x %d cells",
					nrow(ref),
					ncol(ref)
			)
			
			
			meta <- ref@meta.data
			
			n_cols <- ncol(meta)
			
			log_msg(
					"Metadata has %d column(s)",
					n_cols
			)
			
			
			# --------------------------------------------------------------------------
			# Tunable thresholds for the [CELLTYPE?] heuristic
			# --------------------------------------------------------------------------
			
			min_categories <- 2L      # at least 2 groups to be a useful label
			max_categories <- 100L    # more than this is likely an ID, not a cell type
			top_show       <- 10L     # how many category values to print per column
			
			
			cat("\n")
			cat("==================================================================\n")
			cat(" REFERENCE METADATA COLUMNS\n")
			cat("==================================================================\n")
			
			
			celltype_candidates <- character(0)
			
			
			for (col_name in colnames(meta)) {
				
				col_values <- meta[[col_name]]
				
				
				# ---- numeric columns ---------------------------------------------------
				
				if (is.numeric(col_values)) {
					
					cat(sprintf(
									"[SKIP     ] %-20s : numeric (range %.3g ~ %.3g)\n",
									col_name,
									suppressWarnings(min(col_values, na.rm = TRUE)),
									suppressWarnings(max(col_values, na.rm = TRUE))
							))
					
					next
				}
				
				
				# ---- categorical columns ----------------------------------------------
				
				col_values <- as.character(col_values)
				
				value_counts <- sort(
						table(col_values),
						decreasing = TRUE
				)
				
				n_categories <- length(value_counts)
				
				
				# Decide whether this looks like a cell-type annotation column
				is_celltype_like <- (
							n_categories >= min_categories &&
							n_categories <= max_categories
							)
				
				
				tag <- if (is_celltype_like) "[CELLTYPE?]" else "[SKIP     ]"
				
				
				if (is_celltype_like) {
					celltype_candidates <- c(celltype_candidates, col_name)
				}
				
				
				# Build a compact preview of the top category values
				n_preview <- min(top_show, n_categories)
				
				preview_parts <- vapply(
						seq_len(n_preview),
						function(i) {
							sprintf(
									"%s (%d)",
									names(value_counts)[i],
									as.integer(value_counts[i])
							)
						},
						character(1)
				)
				
				preview <- paste(preview_parts, collapse = ", ")
				
				if (n_categories > n_preview) {
					preview <- sprintf(
							"%s, ... (+%d more)",
							preview,
							n_categories - n_preview
					)
				}
				
				
				cat(sprintf(
								"%s %-20s : %d categories -> %s\n",
								tag,
								col_name,
								n_categories,
								preview
						))
			}
			
			
			cat("==================================================================\n\n")
			
			
			# --------------------------------------------------------------------------
			# Summary: candidate cell-type columns
			# --------------------------------------------------------------------------
			
			if (length(celltype_candidates) > 0) {
				
				log_msg(
						"Candidate cell-type column(s): %s",
						paste(celltype_candidates, collapse = ", ")
				)
				
			} else {
				
				log_msg(
						"WARNING: No categorical column looked like a cell-type annotation."
				)
				
				log_msg(
						"         Check the column list above manually."
				)
			}
			
			
			log_msg("DONE.")
			
			
			0L
			
			
		}, error = function(e) {
			
			message(sprintf(
							"[FATAL] ref_inspect failed: %s",
							conditionMessage(e)
					))
			
			1L
		})


quit(status = result)
