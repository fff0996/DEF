#!/usr/bin/env Rscript
# Version 1.2 (changes from spatial_rctd.1.1.R):
#   reference_rds may be empty: the module writes output_dir/skipped.txt and ends without
#   error, so the pipeline runs without a reference (spatial_condition_de skips on such
#   a folder). reference_label_col is still needed with a reference, but it is checked
#   after the reference is read: when it is empty or not in the reference, the run stops
#   before any analysis and lists the cell-type column candidates (categorical, 2-100
#   categories, as check_reference tags them) with their first categories.
#   Analysis results are otherwise unchanged.
# Version 1.1 (changes from spatial_rctd.1.0.R, CLOSHA 2.0):
#   max_cores defaults to auto (the cores allocated to the job, nproc); a number is
#   capped by them with a warning (1.0 used 8 regardless of the allocation).
#   Script rules (docs/CLOSHA_Script_Rules_v1.md 5-7, 10): progress goes to stdout and
#   output_dir/logs/<stamp>.log; warnings and errors (log lines starting with WARNING or
#   [ERROR], R messages and warnings) go to stderr and output_dir/logs/<stamp>.error.log.
#   output_dir is required (no ./bx_spatial_out default), and the run stops when
#   input_dir is output_dir or inside it (it would be cleaned).
#   Plots are saved on a white background (ggsave bg = "white"); some were transparent.
#   The dominant cell-type plot is drawn again: SpatialDimPlot of Seurat 5 has no na.value
#   argument, so 1.0 always skipped it with a warning.
#   Analysis results are otherwise unchanged.

# ==============================================================================
# spatial_rctd.r   [OPTIONAL - BATCH multi-slice]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
# Robust Cell Type Decomposition (RCTD) using a labelled scRNA-seq reference.
#
# Recommended pipeline position:
#   spatial_prep -> spatial_cluster
#                     |-- spatial_svf
#                     |-- spatial_labeltransfer   [optional]
#                     |-- spatial_rctd            [optional; this module]
#                     `-- spatial_merge
#
# RCTD itself does NOT require clustering. However, this module consumes the
# *_clustered.rds objects so that it fits the existing Bio-EXPRESS module layout
# and preserves all cluster metadata / tissue images in the output object.
#
# Input layout (output of spatial_cluster.r):
#   input_dir/
#     control/control_clustered.rds
#     treated/treated_clustered.rds
#
# Required scRNA-seq reference:
#   - Seurat RDS
#   - raw counts retained in an assay (normally RNA)
#   - metadata column containing cell-type labels
#
# Output layout:
#   output_dir/
#     logs/                                  <- preserved on rerun
#     control/
#       control_rctd.rds                     <- Seurat object + RCTD assay/meta
#       control_rctd_object.rds              <- native spacexr RCTD object
#       control_rctd_weights.csv              <- spot x cell-type weights
#       control_rctd_mean_abundance.csv       <- mean weight per cell type
#       plots/
#         control_rctd_dominant_celltype.png
#         control_rctd_top_abundance.png
#     treated/
#       ...
#     summary/
#       rctd_celltype_by_slice.csv
#       rctd_celltype_by_slice_long.csv
#       plots/
#         rctd_celltype_by_slice_heatmap.png
#         rctd_celltype_by_slice_stackedbar.png
#
# Bio-Express argument format:
#   input_dir=/path/to/cluster_output
#   reference_rds=/path/to/sc_reference.rds
#   reference_label_col=celltype
#   output_dir=/path/to/output   (required)
#   spatial_assay=Spatial
#   reference_assay=RNA
#   max_cores=auto   (auto = allocated cores)
#   min_shared_features=200
#   min_cells_per_type=25
#   plot_topn=12
#   seed=1234
#
# Notes:
#   - RCTD requires RAW COUNTS, not SCT/log-normalized expression.
#   - This module uses doublet_mode='full' because Visium spots may contain
#     mixtures of more than two cell types and full mode returns continuous
#     cell-type weights for every spot.
# ==============================================================================

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message(
			"[USAGE] Rscript spatial_rctd.r ",
			"input_dir=/path/to/cluster_output ",
			"reference_rds=/path/to/reference.rds ",
			"reference_label_col=celltype ",
			"output_dir=/path/to/output"
	)
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

get_chr <- function(key, default = NULL) {
	v <- params[[key]]
	if (is.null(v) || !nzchar(v)) default else v
}

get_int <- function(key, default) {
	v <- params[[key]]
	if (is.null(v) || !nzchar(v)) return(default)
	suppressWarnings(as.integer(v))
}

input_dir             <- get_chr("input_dir")
reference_rds         <- get_chr("reference_rds")
reference_label_col   <- get_chr("reference_label_col")
output_dir            <- get_chr("output_dir", { message("[FATAL] output_dir is required."); quit(status = 1) })
spatial_assay         <- get_chr("spatial_assay", "Spatial")
reference_assay_param <- get_chr("reference_assay", "RNA")
# max_cores: auto (default) = cores allocated to the job (nproc); a number is capped by them.
allocated_cores <- tryCatch(as.integer(system("env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc", intern = TRUE)), error = function(e) NA_integer_)
if (is.na(allocated_cores) || allocated_cores < 1) allocated_cores <- length(parallel::mcaffinity())
max_cores_arg <- tolower(get_chr("max_cores", "auto"))
max_cores <- if (max_cores_arg == "auto") allocated_cores else suppressWarnings(as.integer(max_cores_arg))
max_cores_capped <- !is.na(max_cores) && max_cores_arg != "auto" && max_cores > allocated_cores
if (max_cores_capped) max_cores <- allocated_cores
min_shared_features   <- get_int("min_shared_features", 200L)
min_cells_per_type    <- get_int("min_cells_per_type", 25L)
plot_topn             <- get_int("plot_topn", 12L)
seed                  <- get_int("seed", 1234L)

if (is.null(input_dir) || !nzchar(input_dir)) {
	message("[FATAL] input_dir is required.")
	quit(status = 1)
}
if (!dir.exists(input_dir)) {
	message(sprintf("[FATAL] input_dir not found: %s", input_dir))
	quit(status = 1)
}

# No reference: cell types are an optional branch of the pipeline, so the module records
# the skip in output_dir/skipped.txt and ends without error (spatial_condition_de skips on
# such a folder). output_dir is not cleaned here; a later run with a reference cleans it.
skip_no_reference <- function(output_dir) {
	dir.create(file.path(output_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
	txt <- "No reference_rds was given, so cell-type annotation was skipped."
	writeLines(txt, file.path(output_dir, "skipped.txt"))
	writeLines(txt, file.path(output_dir, "logs", paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")))
	cat(txt, "\n", sep = "")
	quit(status = 0)
}

# Lines that list the reference metadata columns when reference_label_col is empty or
# wrong: categorical columns with 2-100 categories are the cell-type candidates, as
# check_reference tags them.
label_col_help <- function(meta) {
	cand <- character(0)
	other <- character(0)
	for (col in colnames(meta)) {
		v <- meta[[col]]
		n <- if (is.numeric(v)) 0L else length(unique(stats::na.omit(as.character(v))))
		if (n < 2 || n > 100) {
			other <- c(other, col)
			next
		}
		cnt <- sort(table(as.character(v)), decreasing = TRUE)
		top <- paste(utils::head(names(cnt), 5), collapse = ", ")
		if (n > 5) top <- paste0(top, ", ...")
		cand <- c(cand, sprintf("  %-24s %d categories: %s", col, n, top))
	}
	c("Cell-type column candidates (categorical, 2-100 categories):",
			if (length(cand)) cand else "  (none)",
			paste0("Other columns: ", if (length(other)) paste(other, collapse = ", ") else "(none)"),
			"Set reference_label_col to the cell-type column and run again.")
}

if (is.null(reference_rds) || !nzchar(reference_rds)) skip_no_reference(output_dir)
if (!file.exists(reference_rds)) {
	message(sprintf("[FATAL] reference_rds not found: %s", reference_rds))
	quit(status = 1)
}
if (is.na(max_cores) || max_cores < 1) {
	message("[FATAL] max_cores must be auto or an integer >= 1.")
	quit(status = 1)
}
if (is.na(min_shared_features) || min_shared_features < 1) {
	message("[FATAL] min_shared_features must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(min_cells_per_type) || min_cells_per_type < 1) {
	message("[FATAL] min_cells_per_type must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(plot_topn) || plot_topn < 1) {
	message("[FATAL] plot_topn must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(seed)) {
	message("[FATAL] seed must be an integer.")
	quit(status = 1)
}

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

required_pkgs <- c("Seurat", "SeuratObject", "spacexr", "ggplot2", "Matrix", "patchwork")
missing_pkgs <- required_pkgs[
		!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)
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
			library(SeuratObject)
			library(spacexr)
			library(ggplot2)
			library(Matrix)
			library(patchwork)
		})

set.seed(seed)

safe_name <- function(x) {
	x <- gsub("[^A-Za-z0-9]+", "_", x)
	x <- gsub("^_+|_+$", "", x)
	x
}

# ------------------------------------------------------------------------------
# Helper: inspect and extract raw counts from a Seurat assay
# ------------------------------------------------------------------------------

count_layers_of <- function(assay_obj) {
	lyr <- tryCatch(
			SeuratObject::Layers(assay_obj),
			error = function(e) character(0)
	)
	
	lyr <- lyr[grepl("^counts", lyr)]
	
	if (length(lyr) == 0) {
		return(character(0))
	}
	
	populated <- vapply(
			lyr,
			function(l) {
				d <- tryCatch(
						dim(SeuratObject::LayerData(assay_obj, layer = l)),
						error = function(e) NULL
				)
				!is.null(d) && length(d) == 2L && all(d > 0)
			},
			logical(1)
	)
	
	lyr[populated]
}

prepare_counts_assay <- function(obj, assay_name, object_label) {
	if (!(assay_name %in% Assays(obj))) {
		stop(sprintf(
						"%s has no assay '%s' (available: %s)",
						object_label,
						assay_name,
						paste(Assays(obj), collapse = ", ")
				))
	}
	
	count_layers <- count_layers_of(obj[[assay_name]])
	
	# Compatibility fallback for older Seurat objects.
	if (length(count_layers) == 0) {
		old_counts <- tryCatch(
				GetAssayData(obj, assay = assay_name, slot = "counts"),
				error = function(e) NULL
		)
		
		if (!is.null(old_counts) && all(dim(old_counts) > 0)) {
			return(list(obj = obj, counts = old_counts))
		}
		
		stop(sprintf(
						"%s assay '%s' contains no raw counts. RCTD requires untransformed counts.",
						object_label,
						assay_name
				))
	}
	
	if (length(count_layers) > 1L) {
		log_msg(
				"  %s assay '%s' has %d counts layers; running JoinLayers().",
				object_label,
				assay_name,
				length(count_layers)
		)
		
		obj <- JoinLayers(obj, assay = assay_name)
		count_layers <- count_layers_of(obj[[assay_name]])
	}
	
	if (length(count_layers) < 1L) {
		stop(sprintf(
						"could not obtain a joined counts layer from %s assay '%s'",
						object_label,
						assay_name
				))
	}
	
	counts <- SeuratObject::LayerData(
			obj[[assay_name]],
			layer = count_layers[1]
	)
	
	list(obj = obj, counts = counts)
}

# ------------------------------------------------------------------------------
# Helper: gene-ID style diagnostics
# ------------------------------------------------------------------------------

gene_id_style <- function(genes) {
	g <- utils::head(as.character(genes), 1000L)
	g <- g[nzchar(g)]
	if (length(g) == 0) return("unknown")
	
	if (mean(grepl("^ENS[A-Z]*[0-9]{6,}", g)) > 0.5) return("Ensembl ID")
	if (mean(grepl("^[0-9]+$", g)) > 0.5) return("Entrez ID")
	
	alpha <- g[grepl("[A-Za-z]", g)]
	if (length(alpha) == 0) return("unknown")
	
	frac_upper <- mean(alpha == toupper(alpha))
	if (frac_upper > 0.80) return("gene symbol, uppercase (human-like)")
	if (frac_upper < 0.30) return("gene symbol, title-case (mouse-like)")
	"gene symbol (mixed case)"
}

# ------------------------------------------------------------------------------
# Discover slices: each subdir containing *_clustered.rds
# ------------------------------------------------------------------------------

slice_table <- list()
subdirs <- list.dirs(input_dir, recursive = FALSE, full.names = TRUE)

for (sd in subdirs) {
	rds <- list.files(sd, pattern = "_clustered\\.rds$", full.names = TRUE)
	if (length(rds) >= 1) {
		slice_table[[basename(sd)]] <- rds[1]
	}
}

# Single-slice shortcut.
if (length(slice_table) == 0) {
	rds <- list.files(input_dir, pattern = "_clustered\\.rds$", full.names = TRUE)
	if (length(rds) == 1) {
		slice_name <- sub("_clustered\\.rds$", "", basename(rds[1]))
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

log_msg("===== Spatial RCTD (batch) =====")
log_msg("input_dir           : %s", input_dir)
log_msg("reference_rds       : %s", reference_rds)
log_msg("reference_label_col : %s", if (is.null(reference_label_col)) "(empty)" else reference_label_col)
log_msg("reference_assay     : %s", reference_assay_param)
log_msg("spatial_assay       : %s", spatial_assay)
log_msg("output_dir          : %s", output_dir)
log_msg("max_cores           : %d (requested %s, allocated %d)", max_cores, max_cores_arg, allocated_cores)
if (max_cores_capped) log_msg("WARNING: max_cores=%s requested, allocated cores: %d; using %d", max_cores_arg, allocated_cores, max_cores)
log_msg("min_shared_features : %d", min_shared_features)
log_msg("min_cells_per_type  : %d", min_cells_per_type)
log_msg("plot_topn           : %d", plot_topn)
log_msg("RCTD mode           : full")
log_msg(
		"Discovered %d slice(s): %s",
		length(slice_table),
		paste(names(slice_table), collapse = ", ")
)

# ------------------------------------------------------------------------------
# Clean output directory; preserve output_dir/logs only.
# ------------------------------------------------------------------------------

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

old_outputs <- list.files(
		output_dir,
		full.names = TRUE,
		all.files = TRUE,
		no.. = TRUE
)
old_outputs <- old_outputs[basename(old_outputs) != "logs"]

if (length(old_outputs) > 0) {
	log_msg("Cleaning previous outputs under: %s", output_dir)
	unlink(old_outputs, recursive = TRUE, force = TRUE)
}

# ------------------------------------------------------------------------------
# Prepare scRNA-seq reference ONCE.
# ------------------------------------------------------------------------------

log_msg("Loading scRNA-seq reference ...")
ref <- readRDS(reference_rds)

if (!inherits(ref, "Seurat")) {
	message(sprintf(
					"[FATAL] reference_rds is not a Seurat object (class: %s)",
					paste(class(ref), collapse = "/")
			))
	quit(status = 1)
}

if (is.null(reference_label_col) || !(reference_label_col %in% colnames(ref@meta.data))) {
	if (is.null(reference_label_col)) {
		message("[FATAL] reference_label_col is empty; give the cell-type column of the reference.")
	} else {
		message(sprintf("[FATAL] reference_label_col '%s' not found in reference.", reference_label_col))
	}
	for (line in label_col_help(ref@meta.data)) message("        ", line)
	quit(status = 1)
}

# Prefer the requested assay, then common raw-count assay names.
reference_assay_candidates <- unique(c(
				reference_assay_param,
				"RNA",
				"originalexp",
				"spliced",
				Assays(ref)
		))
reference_assay_candidates <- reference_assay_candidates[
		reference_assay_candidates %in% Assays(ref)
]

reference_assay_use <- NULL
ref_counts_info <- NULL

for (a in reference_assay_candidates) {
	attempt <- tryCatch(
			prepare_counts_assay(ref, a, "reference"),
			error = function(e) NULL
	)
	
	if (!is.null(attempt)) {
		reference_assay_use <- a
		ref <- attempt$obj
		ref_counts_info <- attempt
		break
	}
}

if (is.null(reference_assay_use) || is.null(ref_counts_info)) {
	message("[FATAL] No raw-count assay found in the scRNA-seq reference.")
	message(sprintf("        Available assays: %s", paste(Assays(ref), collapse = ", ")))
	message("        RCTD cannot use SCT-only / normalized-only references.")
	quit(status = 1)
}

ref_counts <- ref_counts_info$counts

labels <- as.character(ref[[reference_label_col, drop = TRUE]])
names(labels) <- Cells(ref)

valid_cells <- Cells(ref)[
		!is.na(labels[Cells(ref)]) & nzchar(labels[Cells(ref)])
]

if (length(valid_cells) == 0) {
	message("[FATAL] No reference cells have valid cell-type labels.")
	quit(status = 1)
}

label_counts <- table(labels[valid_cells])
keep_types <- names(label_counts[label_counts >= min_cells_per_type])
removed_types <- names(label_counts[label_counts < min_cells_per_type])

if (length(keep_types) < 2) {
	message(sprintf(
					"[FATAL] Only %d cell type(s) remain after min_cells_per_type=%d filtering.",
					length(keep_types), min_cells_per_type
			))
	quit(status = 1)
}

if (length(removed_types) > 0) {
	log_msg(
			"Reference: dropping %d cell type(s) with < %d cells: %s",
			length(removed_types),
			min_cells_per_type,
			paste(removed_types, collapse = ", ")
	)
}

valid_cells <- valid_cells[labels[valid_cells] %in% keep_types]
ref_counts <- ref_counts[, valid_cells, drop = FALSE]

cell_types <- factor(labels[valid_cells])
names(cell_types) <- valid_cells

ref_nUMI <- Matrix::colSums(ref_counts)
names(ref_nUMI) <- colnames(ref_counts)

log_msg(
		"Reference ready: %d genes x %d cells | assay='%s' | %d cell types | gene IDs: %s",
		nrow(ref_counts),
		ncol(ref_counts),
		reference_assay_use,
		nlevels(cell_types),
		gene_id_style(rownames(ref_counts))
)

for (lv in names(sort(table(cell_types), decreasing = TRUE))) {
	log_msg("  %-30s %d cell(s)", lv, as.integer(table(cell_types)[[lv]]))
}

reference <- spacexr::Reference(
		ref_counts,
		cell_types,
		ref_nUMI
)

# Reference Seurat object no longer needed after Reference construction.
rm(ref, ref_counts, ref_counts_info)
invisible(gc(verbose = FALSE))

# ------------------------------------------------------------------------------
# Per-slice RCTD.
# ------------------------------------------------------------------------------

mean_abundance_list <- list()
ok_slices <- character(0)
fail_slices <- character(0)

process_slice <- function(slice_name, clustered_rds) {
	
	log_msg("---- slice '%s' ----", slice_name)
	
	slice_out <- file.path(output_dir, slice_name)
	plot_dir <- file.path(slice_out, "plots")
	dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
	
	obj <- readRDS(clustered_rds)
	
	if (!inherits(obj, "Seurat")) {
		stop("input is not a Seurat object")
	}
	
	if (!(spatial_assay %in% Assays(obj))) {
		stop(sprintf(
						"no '%s' assay; available assays: %s",
						spatial_assay,
						paste(Assays(obj), collapse = ", ")
				))
	}
	
	if (length(Images(obj)) == 0) {
		stop("no spatial image/coordinates found in Seurat object")
	}
	
	log_msg("  input: %s", clustered_rds)
	log_msg("  loaded: %d genes x %d spots", nrow(obj), ncol(obj))
	
	# Raw Visium counts.
	spatial_counts_info <- prepare_counts_assay(
			obj,
			spatial_assay,
			sprintf("slice '%s'", slice_name)
	)
	obj <- spatial_counts_info$obj
	spatial_counts <- spatial_counts_info$counts
	
	# Coordinates. Seurat's current RCTD vignette uses GetTissueCoordinates().
	coords <- GetTissueCoordinates(obj)
	
	if (is.null(coords) || nrow(coords) == 0 || ncol(coords) < 2) {
		stop("GetTissueCoordinates() returned fewer than two coordinate columns")
	}
	
	# Keep only the two coordinate dimensions required by SpatialRNA.
	coords <- as.data.frame(coords[, seq_len(2), drop = FALSE])
	colnames(coords) <- c("x", "y")
	
	if (is.null(rownames(coords)) || any(!nzchar(rownames(coords)))) {
		stop("spatial coordinates do not have spot barcodes as row names")
	}
	
	# Align counts and coordinates exactly.
	shared_spots <- intersect(colnames(spatial_counts), rownames(coords))
	
	if (length(shared_spots) == 0) {
		stop("no shared spot barcodes between Spatial counts and coordinates")
	}
	
	spatial_counts <- spatial_counts[, shared_spots, drop = FALSE]
	coords <- coords[shared_spots, , drop = FALSE]
	
	# RCTD requires overlap between reference and spatial genes.
	spatial_genes <- rownames(spatial_counts)
	reference_genes <- rownames(reference@counts)
	shared_genes <- intersect(spatial_genes, reference_genes)
	
	log_msg(
			"  shared genes: %d | spatial=%s | reference=%s",
			length(shared_genes),
			gene_id_style(spatial_genes),
			gene_id_style(reference_genes)
	)
	
	if (length(shared_genes) < min_shared_features) {
		stop(sprintf(
						paste0(
								"only %d shared genes between spatial query and reference (need >= %d). ",
								"Check species and gene-ID convention."
						),
						length(shared_genes),
						min_shared_features
				))
	}
	
	# Keep the original raw spatial count matrix. spacexr performs the shared-gene
	# handling internally, and nUMI should represent the total UMI depth of each
	# Visium spot rather than only the overlapping genes.
	
	spatial_nUMI <- Matrix::colSums(spatial_counts)
	names(spatial_nUMI) <- colnames(spatial_counts)
	
	log_msg("  constructing SpatialRNA object (%d spots)", ncol(spatial_counts))
	
	puck <- spacexr::SpatialRNA(
			coords,
			spatial_counts,
			spatial_nUMI
	)
	
	log_msg("  create.RCTD(max_cores=%d, test_mode=FALSE)", max_cores)
	
	rctd <- spacexr::create.RCTD(
			puck,
			reference,
			max_cores = max_cores,
			test_mode = FALSE,
			CELL_MIN_INSTANCE = min_cells_per_type
	)
	
	log_msg("  run.RCTD(doublet_mode='full')")
	
	rctd <- spacexr::run.RCTD(
			rctd,
			doublet_mode = "full"
	)
	
	if (is.null(rctd@results$weights)) {
		stop("RCTD full mode completed but @results$weights is missing")
	}
	
	weights <- as.data.frame(rctd@results$weights, check.names = FALSE)
	
	if (nrow(weights) == 0 || ncol(weights) == 0) {
		stop("RCTD returned an empty weights matrix")
	}
	
	# Align RCTD result to spots retained by the Seurat object.
	common_result_spots <- intersect(Cells(obj), rownames(weights))
	
	if (length(common_result_spots) == 0) {
		stop("RCTD weights have no spot barcodes matching the Seurat object")
	}
	
	weights <- weights[common_result_spots, , drop = FALSE]
	
	# Normalize tiny numerical deviations so each spot sums to 1 when possible.
	rs <- rowSums(weights)
	valid_rs <- is.finite(rs) & rs > 0
	weights[valid_rs, ] <- weights[valid_rs, , drop = FALSE] / rs[valid_rs]
	
	# --------------------------------------------------------------------------
	# Save native results.
	# --------------------------------------------------------------------------
	
	weights_out <- data.frame(
			barcode = rownames(weights),
			weights,
			check.names = FALSE,
			stringsAsFactors = FALSE
	)
	
	write.csv(
			weights_out,
			file.path(slice_out, sprintf("%s_rctd_weights.csv", slice_name)),
			row.names = FALSE
	)
	
	mean_abundance <- colMeans(weights, na.rm = TRUE)
	mean_df <- data.frame(
			celltype = names(mean_abundance),
			mean_abundance = as.numeric(mean_abundance),
			stringsAsFactors = FALSE
	)
	mean_df <- mean_df[order(-mean_df$mean_abundance), , drop = FALSE]
	
	write.csv(
			mean_df,
			file.path(slice_out, sprintf("%s_rctd_mean_abundance.csv", slice_name)),
			row.names = FALSE
	)
	
	saveRDS(
			rctd,
			file.path(slice_out, sprintf("%s_rctd_object.rds", slice_name))
	)
	
	# --------------------------------------------------------------------------
	# Add RCTD continuous weights back to the Seurat object.
	# --------------------------------------------------------------------------
	
	weight_mat <- t(as.matrix(weights))
	colnames(weight_mat) <- rownames(weights)
	
	rctd_assay <- CreateAssayObject(data = weight_mat)
	
	# Subsetting the assay to only RCTD-retained spots is allowed, but Seurat
	# assays must match the object's cell set. Create a complete matrix and fill
	# non-retained cells with NA-like zero weights.
	if (!setequal(colnames(weight_mat), Cells(obj))) {
		full_weight_mat <- matrix(
				0,
				nrow = nrow(weight_mat),
				ncol = length(Cells(obj)),
				dimnames = list(rownames(weight_mat), Cells(obj))
		)
		full_weight_mat[, colnames(weight_mat)] <- weight_mat
		rctd_assay <- CreateAssayObject(data = full_weight_mat)
	}
	
	obj[["RCTD"]] <- rctd_assay
	
	dominant <- rep(NA_character_, length(Cells(obj)))
	names(dominant) <- Cells(obj)
	
	w_for_dom <- as.matrix(weights)
	dominant_result <- colnames(w_for_dom)[
			max.col(w_for_dom, ties.method = "first")
	]
	names(dominant_result) <- rownames(w_for_dom)
	dominant[names(dominant_result)] <- dominant_result
	
	obj$rctd_dominant_celltype <- dominant[Cells(obj)]
	
	# --------------------------------------------------------------------------
	# Plot: dominant cell type.
	# --------------------------------------------------------------------------
	
	dominant_plot <- tryCatch({
				SpatialDimPlot(
								obj,
								group.by = "rctd_dominant_celltype",
								label = FALSE
						) +
						ggtitle(sprintf("%s RCTD dominant cell type", slice_name))
			}, error = function(e) {
				log_msg("  WARNING: dominant cell-type plot failed: %s", conditionMessage(e))
				NULL
			})
	
	if (!is.null(dominant_plot)) {
		ggsave(bg = "white", 
				file.path(plot_dir, sprintf("%s_rctd_dominant_celltype.png", slice_name)),
				plot = dominant_plot,
				width = 7,
				height = 6,
				dpi = 300,
				limitsize = FALSE
		)
	}
	
	# --------------------------------------------------------------------------
	# Plot: top cell-type abundance spatial maps.
	# --------------------------------------------------------------------------
	
	top_types <- utils::head(mean_df$celltype, plot_topn)
	top_types <- top_types[top_types %in% rownames(obj[["RCTD"]])]
	
	if (length(top_types) > 0) {
		old_assay <- DefaultAssay(obj)
		DefaultAssay(obj) <- "RCTD"
		
		nc <- min(3L, length(top_types))
		
		abundance_plot <- tryCatch({
					SpatialFeaturePlot(
									obj,
									features = top_types,
									ncol = nc,
									crop = TRUE,
									alpha = c(0.1, 1)
							) &
							theme(plot.margin = grid::unit(c(1, 1, 1, 1), "mm"))
				}, error = function(e) {
					log_msg("  WARNING: RCTD abundance plot failed: %s", conditionMessage(e))
					NULL
				})
		
		DefaultAssay(obj) <- old_assay
		
		if (!is.null(abundance_plot)) {
			ggsave(bg = "white", 
					file.path(plot_dir, sprintf("%s_rctd_top_abundance.png", slice_name)),
					plot = abundance_plot,
					width = 5 * nc,
					height = 5 * ceiling(length(top_types) / nc),
					dpi = 300,
					limitsize = FALSE
			)
		}
	}
	
	# Save Seurat object containing the RCTD assay and dominant-cell-type meta.
	out_rds <- file.path(slice_out, sprintf("%s_rctd.rds", slice_name))
	saveRDS(obj, out_rds)
	
	log_msg(
			"  DONE: %d spots x %d cell types -> %s",
			nrow(weights),
			ncol(weights),
			out_rds
	)
	
	invisible(mean_df)
}

for (slice_name in names(slice_table)) {
	result <- tryCatch(
			process_slice(slice_name, slice_table[[slice_name]]),
			error = function(e) {
				log_msg(
						"  [ERROR] slice '%s' failed: %s",
						slice_name,
						conditionMessage(e)
				)
				NULL
			}
	)
	
	if (!is.null(result)) {
		mean_abundance_list[[slice_name]] <- result
		ok_slices <- c(ok_slices, slice_name)
	} else {
		fail_slices <- c(fail_slices, slice_name)
	}
}

# ------------------------------------------------------------------------------
# Cross-slice summary.
# ------------------------------------------------------------------------------

if (length(mean_abundance_list) > 0) {
	
	summary_dir <- file.path(output_dir, "summary")
	summary_plot_dir <- file.path(summary_dir, "plots")
	dir.create(summary_plot_dir, recursive = TRUE, showWarnings = FALSE)
	
	all_celltypes <- unique(unlist(lapply(
							mean_abundance_list,
							function(df) df$celltype
					)))
	
	long_list <- list()
	
	for (slice_name in names(mean_abundance_list)) {
		df <- mean_abundance_list[[slice_name]]
		
		tmp <- data.frame(
				slice = slice_name,
				celltype = all_celltypes,
				mean_abundance = 0,
				stringsAsFactors = FALSE
		)
		
		idx <- match(df$celltype, tmp$celltype)
		tmp$mean_abundance[idx] <- df$mean_abundance
		
		long_list[[slice_name]] <- tmp
	}
	
	long_df <- do.call(rbind, long_list)
	rownames(long_df) <- NULL
	
	write.csv(
			long_df,
			file.path(summary_dir, "rctd_celltype_by_slice_long.csv"),
			row.names = FALSE
	)
	
	wide_df <- reshape(
			long_df,
			idvar = "celltype",
			timevar = "slice",
			direction = "wide"
	)
	
	colnames(wide_df) <- sub("^mean_abundance\\.", "", colnames(wide_df))
	
	# Preserve cell types in descending global abundance.
	global_order <- aggregate(
			mean_abundance ~ celltype,
			data = long_df,
			FUN = mean
	)
	global_order <- global_order[order(-global_order$mean_abundance), , drop = FALSE]
	
	wide_df <- wide_df[
			match(global_order$celltype, wide_df$celltype),
			,
			drop = FALSE
	]
	
	write.csv(
			wide_df,
			file.path(summary_dir, "rctd_celltype_by_slice.csv"),
			row.names = FALSE
	)
	
	# Heatmap.
	long_df$celltype <- factor(
			long_df$celltype,
			levels = rev(global_order$celltype)
	)
	long_df$slice <- factor(
			long_df$slice,
			levels = names(mean_abundance_list)
	)
	
	p_heat <- ggplot(
					long_df,
					aes(x = slice, y = celltype, fill = mean_abundance)
			) +
			geom_tile() +
			labs(
					title = "RCTD cell-type abundance by slice",
					x = "Slice",
					y = "Cell type",
					fill = "Mean weight"
			) +
			theme_bw() +
			theme(
					panel.grid = element_blank(),
					axis.text.x = element_text(angle = 45, hjust = 1)
			)
	
	ggsave(bg = "white", 
			file.path(summary_plot_dir, "rctd_celltype_by_slice_heatmap.png"),
			plot = p_heat,
			width = max(7, 1.2 * length(mean_abundance_list) + 4),
			height = max(6, 0.30 * length(all_celltypes) + 3),
			dpi = 300,
			limitsize = FALSE
	)
	
	# Stacked composition plot.
	p_bar <- ggplot(
					long_df,
					aes(x = slice, y = mean_abundance, fill = celltype)
			) +
			geom_col(position = "stack") +
			labs(
					title = "RCTD cell-type composition by slice",
					x = "Slice",
					y = "Mean RCTD weight",
					fill = "Cell type"
			) +
			theme_bw() +
			theme(
					panel.grid = element_blank(),
					axis.text.x = element_text(angle = 45, hjust = 1)
			)
	
	ggsave(bg = "white", 
			file.path(summary_plot_dir, "rctd_celltype_by_slice_stackedbar.png"),
			plot = p_bar,
			width = max(8, 1.3 * length(mean_abundance_list) + 5),
			height = 6,
			dpi = 300,
			limitsize = FALSE
	)
}

# ------------------------------------------------------------------------------
# Batch summary.
# ------------------------------------------------------------------------------

log_msg("===== RCTD batch summary =====")
log_msg(
		"Succeeded (%d): %s",
		length(ok_slices),
		if (length(ok_slices)) paste(ok_slices, collapse = ", ") else "-"
)
log_msg(
		"Failed    (%d): %s",
		length(fail_slices),
		if (length(fail_slices)) paste(fail_slices, collapse = ", ") else "-"
)

if (length(ok_slices) == 0) {
	quit(status = 1)
}

quit(status = 0)
