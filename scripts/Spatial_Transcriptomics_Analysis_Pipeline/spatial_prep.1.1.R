#!/usr/bin/env Rscript
# Version 1.1 (changes from spatial_prep.1.0.R, CLOSHA 2.0):
#   Script rules (docs/CLOSHA_Script_Rules_v1.md 5-7, 10): progress goes to stdout and
#   output_dir/logs/<stamp>.log; warnings and errors (log lines starting with WARNING or
#   [ERROR], R messages and warnings) go to stderr and output_dir/logs/<stamp>.error.log.
#   output_dir is required (no ./bx_spatial_out default), and the run stops when
#   input_dir is output_dir or inside it (it would be cleaned).
#   Plots are saved on a white background (ggsave bg = "white"); some were transparent.
#   Analysis results are otherwise unchanged.

# ==============================================================================
# spatial_prep.r   [Module 1/6 - BATCH multi-slice]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
#
# Load10X_Spatial + QC + SCTransform, run once PER SLICE.
#
# Input layout (each subfolder under input_dir is one slice):
#   input_dir/
#     control/    outs (or filtered_feature_bc_matrix.h5 + spatial/)
#     treated/    outs ...
#
# Output layout (one subdirectory per slice, results isolated inside):
#   output_dir/
#     control/
#       control_prep.rds
#       control_prep_sessionInfo.txt
#       plots/control_qc_nCount_Spatial.png
#     treated/
#       ...
#
# A single slice still works: put one subfolder under input_dir (or point
# input_dir straight at one slice's outs - auto-detected as a 1-slice batch).
#
# Bio-Express argument format:
#   input_dir=/path/to/slices
#   output_dir=/path/to/output   (required)
#   min_counts=0
#   feature_genes=EPCAM,KRT19        (optional)
#   seed=1234
# ==============================================================================


# ------------------------------------------------------------------------------
# 1. Parse Bio-Express key=value arguments
# ------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message("[USAGE] Rscript spatial_prep.r input_dir=/path/to/slices output_dir=/path/to/output")
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

input_dir <- params$input_dir


output_dir <- if (!is.null(params$output_dir) && nzchar(params$output_dir)) {
			params$output_dir
		} else {
			{ message("[FATAL] output_dir is required."); quit(status = 1) }
		}


h5_filename <- if (!is.null(params$h5_filename) && nzchar(params$h5_filename)) {
			params$h5_filename
		} else {
			"filtered_feature_bc_matrix.h5"
		}


min_counts <- if (!is.null(params$min_counts) && nzchar(params$min_counts)) {
			suppressWarnings(as.integer(params$min_counts))
		} else {
			0L
		}


feature_genes <- if (!is.null(params$feature_genes) && nzchar(params$feature_genes)) {
			params$feature_genes
		} else {
			"none"
		}


seed <- if (!is.null(params$seed) && nzchar(params$seed)) {
			suppressWarnings(as.integer(params$seed))
		} else {
			1234L
		}


# ------------------------------------------------------------------------------
# 3. Parameter validation
# ------------------------------------------------------------------------------

if (is.null(input_dir) || !nzchar(input_dir)) {
	message("[FATAL] input_dir is required.")
	quit(status = 1)
}

if (!dir.exists(input_dir)) {
	message(sprintf("[FATAL] input_dir not found: %s", input_dir))
	quit(status = 1)
}

if (is.na(min_counts) || min_counts < 0) {
	message("[FATAL] min_counts must be an integer >= 0.")
	quit(status = 1)
}

if (is.na(seed)) {
	message("[FATAL] seed must be an integer.")
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# 4. Logging + packages
# ------------------------------------------------------------------------------

err_con <- NULL
log_msg <- function(...) {
	# Warnings and errors go to stderr and the .error.log; progress to stdout (.log).
	txt <- sprintf(...)
	line <- sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), txt)
	if (grepl("^\\s*(\\[ERROR\\]|ERROR|WARNING|\\[WARN)", txt)) {
		cat(line, file = stderr())
		if (!is.null(err_con)) {
			cat(line, file = err_con)
			flush(err_con)
		}
	} else {
		cat(line)
	}
}


required_pkgs <- c("Seurat", "ggplot2", "patchwork")

missing_pkgs <- required_pkgs[
		!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)
]

if (length(missing_pkgs) > 0) {
	message(sprintf("[FATAL] Missing package(s): %s", paste(missing_pkgs, collapse = ", ")))
	quit(status = 1)
}

suppressPackageStartupMessages({
			library(Seurat)
			library(ggplot2)
			library(patchwork)
		})


options(future.globals.maxSize = 4 * 1024^3)

set.seed(seed)


# ------------------------------------------------------------------------------
# 5. Locate the Space Ranger dir inside a given slice folder
#
# Accepts either:
#   <slice>/outs/{h5, spatial/}
#   <slice>/{h5, spatial/}
# Returns the directory that directly contains the h5 + spatial/, or NA.
# ------------------------------------------------------------------------------

find_outs <- function(slice_dir) {
	
	candidates <- c(
			file.path(slice_dir, "outs"),
			slice_dir
	)
	
	for (cand in candidates) {
		h5   <- file.path(cand, h5_filename)
		spat <- file.path(cand, "spatial")
		if (file.exists(h5) && dir.exists(spat)) {
			return(cand)
		}
	}
	
	NA_character_
}


# ------------------------------------------------------------------------------
# 6. Discover slices under input_dir
#
# Each immediate subdirectory that contains a valid Space Ranger output is one
# slice. If input_dir itself is a Space Ranger output (single-slice shortcut),
# treat it as one slice named after input_dir.
# ------------------------------------------------------------------------------

slice_table <- list()

# Case A: input_dir itself is a slice (single-slice shortcut)
self_outs <- find_outs(input_dir)

if (!is.na(self_outs)) {
	
	slice_name <- basename(normalizePath(input_dir, winslash = "/", mustWork = TRUE))
	slice_table[[slice_name]] <- self_outs
	log_msg("input_dir is itself a Space Ranger output; single slice '%s'", slice_name)
	
} else {
	
	subdirs <- list.dirs(input_dir, recursive = FALSE, full.names = TRUE)
	
	for (sd in subdirs) {
		outs <- find_outs(sd)
		if (!is.na(outs)) {
			slice_name <- basename(sd)
			slice_table[[slice_name]] <- outs
		}
	}
}


if (length(slice_table) == 0) {
	message(sprintf(
					"[FATAL] No Space Ranger slices found under input_dir: %s",
					input_dir
			))
	message("[FATAL] Expected each slice as a subfolder with outs/ (h5 + spatial/).")
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# Logs: stdout -> console + logs/<stamp>.log; warnings and errors (log_msg lines
# starting with WARNING or [ERROR], R messages and warnings) -> stderr +
# logs/<stamp>.error.log. logs/ is kept when output_dir is cleaned.
# ------------------------------------------------------------------------------
in_abs <- normalizePath(input_dir, mustWork = FALSE)
out_abs <- normalizePath(output_dir, mustWork = FALSE)
if (identical(in_abs, out_abs) || startsWith(in_abs, paste0(out_abs, "/"))) {
	message(sprintf("[FATAL] input_dir (%s) is output_dir or inside it; output_dir is cleaned on every run.", input_dir))
	quit(status = 1)
}
logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)
log_stamp <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
log_con <- file(file.path(logs_dir, paste0(log_stamp, ".log")), open = "at")
err_con <- file(file.path(logs_dir, paste0(log_stamp, ".error.log")), open = "at")
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
log_msg("Log files: %s (stdout), %s (stderr)",
		file.path(logs_dir, paste0(log_stamp, ".log")), file.path(logs_dir, paste0(log_stamp, ".error.log")))

log_msg("===== Spatial Prep (batch) =====")
log_msg("input_dir     : %s", input_dir)
log_msg("output_dir    : %s", output_dir)
log_msg("min_counts    : %d", min_counts)
log_msg("feature_genes : %s", feature_genes)
log_msg("Discovered %d slice(s): %s",
		length(slice_table),
		paste(names(slice_table), collapse = ", "))


# ------------------------------------------------------------------------------
# 7. Clean output directory
#    Keep output_dir/logs/, remove everything else on every run
# ------------------------------------------------------------------------------

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

existing_outputs <- list.files(
		output_dir,
		full.names = TRUE,
		all.files = TRUE,
		no.. = TRUE
)

# Keep logs/ only
existing_outputs <- existing_outputs[
		basename(existing_outputs) != "logs"
]

if (length(existing_outputs) > 0) {
	log_msg("Cleaning previous outputs under: %s", output_dir)
	unlink(existing_outputs, recursive = TRUE, force = TRUE)
}


# ------------------------------------------------------------------------------
# 8. Per-slice processing
# ------------------------------------------------------------------------------

process_slice <- function(slice_name, outs_dir) {
	
	log_msg("---- slice '%s' ----", slice_name)
	
	slice_out <- file.path(output_dir, slice_name)
	dir.create(slice_out, recursive = TRUE, showWarnings = FALSE)
	
	plot_dir <- file.path(slice_out, "plots")
	dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
	
	# STEP 1: load
	obj <- Load10X_Spatial(
			data.dir = outs_dir,
			filename = h5_filename,
			assay = "Spatial",
			slice = slice_name,
			filter.matrix = TRUE
	)
	
	log_msg(
			"  loaded: %d genes x %d spots",
			nrow(obj),
			ncol(obj)
	)
	
	# Optional spot filtering
	if (min_counts > 0) {
		n0 <- ncol(obj)
		
		obj <- subset(
				obj,
				subset = nCount_Spatial >= min_counts
		)
		
		log_msg(
				"  min_counts >= %d: %d -> %d spots",
				min_counts,
				n0,
				ncol(obj)
		)
	}
	
	# STEP 2: QC plot
	v <- VlnPlot(
					obj,
					features = "nCount_Spatial",
					pt.size = 0.1
			) +
			NoLegend()
	
	sp <- SpatialFeaturePlot(
					obj,
					features = "nCount_Spatial"
			) +
			theme(legend.position = "right")
	
	ggsave(bg = "white", 
			file.path(
					plot_dir,
					sprintf("%s_qc_nCount_Spatial.png", slice_name)
			),
			plot = wrap_plots(v, sp),
			width = 10,
			height = 5,
			dpi = 300
	)
	
	# STEP 3: SCTransform
	obj <- SCTransform(
			obj,
			assay = "Spatial",
			verbose = FALSE
	)
	
	# Optional feature genes plot
	if (feature_genes != "none") {
		
		genes <- trimws(
				strsplit(
						feature_genes,
						",",
						fixed = TRUE
				)[[1]]
		)
		
		genes <- genes[
				genes %in% rownames(obj)
		]
		
		if (length(genes) > 0) {
			
			fp <- SpatialFeaturePlot(
					obj,
					features = genes,
					ncol = min(3, length(genes))
			)
			
			ggsave(bg = "white", 
					file.path(
							plot_dir,
							sprintf(
									"%s_feature_expression.png",
									slice_name
							)
					),
					plot = fp,
					width = 4 * min(3, length(genes)),
					height = 4 * ceiling(length(genes) / 3),
					dpi = 300,
					limitsize = FALSE
			)
			
		} else {
			
			log_msg(
					"  WARNING: none of feature_genes found in this slice"
			)
		}
	}
	
	# Save result
	out_rds <- file.path(
			slice_out,
			sprintf("%s_prep.rds", slice_name)
	)
	
	saveRDS(
			obj,
			out_rds
	)
	
	writeLines(
			capture.output(sessionInfo()),
			file.path(
					slice_out,
					sprintf(
							"%s_prep_sessionInfo.txt",
							slice_name
					)
			)
	)
	
	log_msg(
			"  DONE -> %s",
			out_rds
	)
	
	invisible(TRUE)
}


# ------------------------------------------------------------------------------
# 9. Run all slices
# ------------------------------------------------------------------------------

ok_slices   <- character(0)
fail_slices <- character(0)

for (slice_name in names(slice_table)) {
	
	res <- tryCatch({
				
				process_slice(
						slice_name,
						slice_table[[slice_name]]
				)
				
				TRUE
				
			}, error = function(e) {
				
				log_msg(
						"  [ERROR] slice '%s' failed: %s",
						slice_name,
						conditionMessage(e)
				)
				
				FALSE
			})
	
	if (isTRUE(res)) {
		
		ok_slices <- c(
				ok_slices,
				slice_name
		)
		
	} else {
		
		fail_slices <- c(
				fail_slices,
				slice_name
		)
	}
}


# ------------------------------------------------------------------------------
# 10. Batch summary + exit status
# ------------------------------------------------------------------------------

log_msg("===== Prep batch summary =====")

log_msg(
		"Succeeded (%d): %s",
		length(ok_slices),
		if (length(ok_slices)) {
					paste(ok_slices, collapse = ", ")
				} else {
					"-"
				}
)

log_msg(
		"Failed    (%d): %s",
		length(fail_slices),
		if (length(fail_slices)) {
					paste(fail_slices, collapse = ", ")
				} else {
					"-"
				}
)

# Non-zero exit only if EVERY slice failed
if (length(ok_slices) == 0) {
	quit(status = 1)
}

quit(status = 0)
