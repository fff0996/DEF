#!/usr/bin/env Rscript
# Version 1.1 (changes from spatial_svf.1.0.R, CLOSHA 2.0):
#   Runs in bx_spatial 1.1, which adds ape for Seurat RunMoransI (1.0 image lacked it).
#   Script rules (docs/CLOSHA_Script_Rules_v1.md 5-7, 10): progress goes to stdout and
#   output_dir/logs/<stamp>.log; warnings and errors (log lines starting with WARNING or
#   [ERROR], R messages and warnings) go to stderr and output_dir/logs/<stamp>.error.log.
#   output_dir is required (no ./bx_spatial_out default), and the run stops when
#   input_dir is output_dir or inside it (it would be cleaned).
#   Plots are saved on a white background (ggsave bg = "white"); some were transparent.
#   Analysis results are otherwise unchanged.

# ==============================================================================
# spatial_svf.r   [Module 3/6 - BATCH multi-slice]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
# FindSpatiallyVariableFeatures (Moran's I / mark variogram),
# run once PER SLICE.
#
# Input layout (output of spatial_cluster.r):
#
# input_dir/
#   anterior/
#     anterior_clustered.rds
#   posterior/
#     posterior_clustered.rds
#
# Output layout:
#
# output_dir/
#   logs/                         <- preserved on rerun
#   anterior/
#     anterior_svf.rds
#     anterior_svf_moransi.csv
#     plots/
#       anterior_top_svf_moransi.png
#   posterior/
#     ...
#
# Bio-Express argument format:
#
# input_dir=/path/to/cluster_output
# output_dir=/path/to/output   (required)
# svf_method=moransi
# svf_topn=1000
# svf_show=6
# seed=1234
# ==============================================================================


# ------------------------------------------------------------------------------
# 1. Parse Bio-Express key=value arguments
# ------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message(
			"[USAGE] Rscript spatial_svf.r ",
			"input_dir=/path/to/cluster_output ",
			"output_dir=/path/to/output"
	)
	quit(status = 1)
}


parse_key_value_args <- function(args) {
	
	params <- list()
	
	for (arg in args) {
		
		arg <- sub("^--", "", arg)
		
		if (!grepl("=", arg, fixed = TRUE)) {
			message(sprintf(
							"[FATAL] Invalid argument format: %s",
							arg
					))
			message("[FATAL] Expected format: key=value")
			quit(status = 1)
		}
		
		parts <- strsplit(
				arg,
				"=",
				fixed = TRUE
		)[[1]]
		
		key <- trimws(parts[1])
		
		value <- paste(
				parts[-1],
				collapse = "="
		)
		
		value <- trimws(value)
		
		value <- sub("^['\"]", "", value)
		value <- sub("['\"]$", "", value)
		
		if (!nzchar(key)) {
			message(sprintf(
							"[FATAL] Empty parameter name: %s",
							arg
					))
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


output_dir <- if (
				!is.null(params$output_dir) &&
				nzchar(params$output_dir)
				) {
			params$output_dir
		} else {
			{ message("[FATAL] output_dir is required."); quit(status = 1) }
		}


svf_method <- if (
				!is.null(params$svf_method) &&
				nzchar(params$svf_method)
				) {
			params$svf_method
		} else {
			"moransi"
		}


svf_topn <- if (
				!is.null(params$svf_topn) &&
				nzchar(params$svf_topn)
				) {
			suppressWarnings(
					as.integer(params$svf_topn)
			)
		} else {
			1000L
		}


svf_show <- if (
				!is.null(params$svf_show) &&
				nzchar(params$svf_show)
				) {
			suppressWarnings(
					as.integer(params$svf_show)
			)
		} else {
			6L
		}


seed <- if (
				!is.null(params$seed) &&
				nzchar(params$seed)
				) {
			suppressWarnings(
					as.integer(params$seed)
			)
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
	message(sprintf(
					"[FATAL] input_dir not found: %s",
					input_dir
			))
	quit(status = 1)
}


if (!(svf_method %in% c(
					"moransi",
					"markvariogram"
			))) {
	message(sprintf(
					"[FATAL] svf_method must be moransi|markvariogram, got: %s",
					svf_method
			))
	quit(status = 1)
}


if (is.na(svf_topn) || svf_topn < 1) {
	message(
			"[FATAL] svf_topn must be an integer >= 1."
	)
	quit(status = 1)
}


if (is.na(svf_show) || svf_show < 1) {
	message(
			"[FATAL] svf_show must be an integer >= 1."
	)
	quit(status = 1)
}


if (is.na(seed)) {
	message(
			"[FATAL] seed must be an integer."
	)
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


required_pkgs <- c(
		"Seurat",
		"ggplot2"
)


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
					paste(
							missing_pkgs,
							collapse = ", "
					)
			))
	
	quit(status = 1)
}


suppressPackageStartupMessages({
			library(Seurat)
			library(ggplot2)
		})


set.seed(seed)


# ------------------------------------------------------------------------------
# 5. Discover slices
#
# Expected:
#
# input_dir/
#   anterior/
#     anterior_clustered.rds
#   posterior/
#     posterior_clustered.rds
#
# Single-slice shortcut also supported:
#
# input_dir/
#   anterior_clustered.rds
# ------------------------------------------------------------------------------

slice_table <- list()


subdirs <- list.dirs(
		input_dir,
		recursive = FALSE,
		full.names = TRUE
)


for (sd in subdirs) {
	
	rds <- list.files(
			sd,
			pattern = "_clustered\\.rds$",
			full.names = TRUE
	)
	
	if (length(rds) >= 1) {
		
		slice_name <- basename(sd)
		
		slice_table[[slice_name]] <- rds[1]
	}
}


# Single-slice shortcut:
# *_clustered.rds directly under input_dir

if (length(slice_table) == 0) {
	
	rds <- list.files(
			input_dir,
			pattern = "_clustered\\.rds$",
			full.names = TRUE
	)
	
	if (length(rds) == 1) {
		
		slice_name <- sub(
				"_clustered\\.rds$",
				"",
				basename(rds[1])
		)
		
		slice_table[[slice_name]] <- rds[1]
	}
}


if (length(slice_table) == 0) {
	
	message(sprintf(
					"[FATAL] No *_clustered.rds found under input_dir: %s",
					input_dir
			))
	
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# 6. Run information
# ------------------------------------------------------------------------------

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

log_msg(
		"===== Spatial SVF (batch) ====="
)

log_msg(
		"input_dir  : %s",
		input_dir
)

log_msg(
		"output_dir : %s",
		output_dir
)

log_msg(
		"svf_method : %s",
		svf_method
)

log_msg(
		"svf_topn   : %d",
		svf_topn
)

log_msg(
		"svf_show   : %d",
		svf_show
)

log_msg(
		"Discovered %d slice(s): %s",
		length(slice_table),
		paste(
				names(slice_table),
				collapse = ", "
		)
)


# ------------------------------------------------------------------------------
# 7. Clean output directory
#
# On every rerun:
#
# output_dir/logs/   -> KEEP
# everything else   -> DELETE
# ------------------------------------------------------------------------------

dir.create(
		output_dir,
		recursive = TRUE,
		showWarnings = FALSE
)


existing_outputs <- list.files(
		output_dir,
		full.names = TRUE,
		all.files = TRUE,
		no.. = TRUE
)


existing_outputs <- existing_outputs[
		basename(existing_outputs) != "logs"
]


if (length(existing_outputs) > 0) {
	
	log_msg(
			"Cleaning previous outputs under: %s",
			output_dir
	)
	
	unlink(
			existing_outputs,
			recursive = TRUE,
			force = TRUE
	)
}


# ------------------------------------------------------------------------------
# 8. Per-slice SVF analysis
# ------------------------------------------------------------------------------

process_slice <- function(
		slice_name,
		clustered_rds
) {
	
	log_msg(
			"---- slice '%s' ----",
			slice_name
	)
	
	
	# --------------------------------------------------------------------------
	# Output directories
	# --------------------------------------------------------------------------
	
	slice_out <- file.path(
			output_dir,
			slice_name
	)
	
	dir.create(
			slice_out,
			recursive = TRUE,
			showWarnings = FALSE
	)
	
	
	plot_dir <- file.path(
			slice_out,
			"plots"
	)
	
	dir.create(
			plot_dir,
			recursive = TRUE,
			showWarnings = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# Load clustered Seurat object
	# --------------------------------------------------------------------------
	
	log_msg(
			"  input: %s",
			clustered_rds
	)
	
	
	obj <- readRDS(
			clustered_rds
	)
	
	
	if (!inherits(obj, "Seurat")) {
		stop(
				"input is not a Seurat object"
		)
	}
	
	
	log_msg(
			"  loaded: %d genes x %d spots",
			nrow(obj),
			ncol(obj)
	)
	
	
	# --------------------------------------------------------------------------
	# Variable features
	# --------------------------------------------------------------------------
	
	vf <- VariableFeatures(obj)
	
	
	if (length(vf) == 0) {
		stop(
				"no variable features on object"
		)
	}
	
	
	n_test <- min(
			svf_topn,
			length(vf)
	)
	
	
	log_msg(
			"  testing %d / %d variable features",
			n_test,
			length(vf)
	)
	
	
	# --------------------------------------------------------------------------
	# Spatially variable features
	# --------------------------------------------------------------------------
	
	obj <- FindSpatiallyVariableFeatures(
			obj,
			features = vf[seq_len(n_test)],
			selection.method = svf_method
	)
	
	
	svf <- SpatiallyVariableFeatures(
			obj,
			method = svf_method
	)
	
	
	# --------------------------------------------------------------------------
	# Save SVF table + plot
	# --------------------------------------------------------------------------
	
	if (length(svf) == 0) {
		
		log_msg(
				"  WARNING: no SVFs returned for this slice"
		)
		
	} else {
		
		svf_table <- data.frame(
				rank = seq_along(svf),
				gene = svf,
				stringsAsFactors = FALSE
		)
		
		
		svf_csv <- file.path(
				slice_out,
				sprintf(
						"%s_svf_%s.csv",
						slice_name,
						svf_method
				)
		)
		
		
		write.csv(
				svf_table,
				svf_csv,
				row.names = FALSE
		)
		
		
		log_msg(
				"  %d spatially variable features",
				length(svf)
		)
		
		
		# ----------------------------------------------------------------------
		# Plot top SVFs
		# ----------------------------------------------------------------------
		
		top <- head(
				svf,
				svf_show
		)
		
		
		if (length(top) > 0) {
			
			nc <- min(
					3,
					length(top)
			)
			
			
			p <- SpatialFeaturePlot(
							obj,
							features = top,
							ncol = nc,
							alpha = c(0.1, 1)
					) &
					theme(
							plot.margin = grid::unit(
									c(1, 1, 1, 1),
									"mm"
							)
					)
			
			
			ggsave(bg = "white", 
					file.path(
							plot_dir,
							sprintf(
									"%s_top_svf_%s.png",
									slice_name,
									svf_method
							)
					),
					plot = p,
					width = 4 * nc,
					height = 4 * ceiling(
							length(top) / nc
					),
					dpi = 300,
					limitsize = FALSE
			)
		}
	}
	
	
	# --------------------------------------------------------------------------
	# Save Seurat object
	# --------------------------------------------------------------------------
	
	out_rds <- file.path(
			slice_out,
			sprintf(
					"%s_svf.rds",
					slice_name
			)
	)
	
	
	saveRDS(
			obj,
			out_rds
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

ok_slices <- character(0)

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

log_msg(
		"===== SVF batch summary ====="
)


log_msg(
		"Succeeded (%d): %s",
		length(ok_slices),
		if (length(ok_slices)) {
					paste(
							ok_slices,
							collapse = ", "
					)
				} else {
					"-"
				}
)


log_msg(
		"Failed    (%d): %s",
		length(fail_slices),
		if (length(fail_slices)) {
					paste(
							fail_slices,
							collapse = ", "
					)
				} else {
					"-"
				}
)


# Non-zero exit only if every slice failed
if (length(ok_slices) == 0) {
	quit(status = 1)
}


quit(status = 0)
