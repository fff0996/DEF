#!/usr/bin/env Rscript
# Spatial module (Visium HD): load binned slides, QC, normalisation and sketching.
#
# Usage:
#   Rscript spatial_hd_prep.1.0.R input_dir="..." output_dir="..."
#       [bin_size="8"] [min_counts="10"] [min_features="0"] [nfeatures="2000"]
#       [sketch_cells="50000"] [pt_size="4"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.0.sif Rscript spatial_hd_prep.1.0.R \
#       input_dir="/data/visium_hd" output_dir="/out/spatial_hd_prep" bin_size="8"
#
# Arguments (key=value):
#   input_dir    (required) - Folder with one subfolder per slide. Each slide folder is a
#                             Space Ranger Visium HD output: it holds binned_outputs/ (or
#                             outs/binned_outputs/) with square_<NNN>um/
#                             filtered_feature_bc_matrix.h5 and spatial/. A single slide
#                             folder can also be given directly (its name is the slide name).
#   output_dir   (required) - Output directory.
#   bin_size     (optional) - Bin size in um: 8 (recommended) or 16. 2 um bins are not
#                             supported (memory). default: 8
#   min_counts   (optional) - Bins with fewer UMI counts are removed. default: 10
#   min_features (optional) - Bins with fewer detected genes are removed. default: 0
#   nfeatures    (optional) - Variable genes per slide. default: 2000
#   sketch_cells (optional) - Bins kept per slide in the sketch (leverage-score sampling);
#                             clustering runs on the sketch. default: 50000
#   pt_size      (optional) - Bin size in the tissue QC plot (Seurat pt.size.factor). default: 4
#   seed         (optional) - Random seed. default: 1234
#
# Method (Seurat Visium HD workflow): Load10X_Spatial(bin.size) -> bin filter ->
# NormalizeData (log) -> FindVariableFeatures -> SketchData (LeverageScore). The full
# bins keep raw counts and log-normalised data; the sketch assay holds the sampled bins.
# SCTransform is not used, because it does not scale to hundreds of thousands of bins.
#
# Outputs (output_dir):
#   <slide>/<slide>_hd_prep.rds   Seurat object: assay Spatial.<NNN>um (all bins),
#                                 assay sketch, image, metadata 'slide'
#   <slide>/plots/<slide>_qc.png and .pdf  counts and genes per bin (violin and tissue)
#   hd_prep_summary.tsv           slide, bins before and after the filter, median
#                                 counts and genes, sketched bins, status
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# A slide that fails is listed in hd_prep_summary.tsv; the run fails (exit 1) only when
# every slide fails. The previous output_dir content except logs/ is removed at the
# start, so no input may be inside output_dir.

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
# Parse key=value arguments
# ------------------------------------------------------------
defaults <- list(input_dir = "", output_dir = "", bin_size = "8", min_counts = "10", min_features = "0",
		nfeatures = "2000", sketch_cells = "50000", pt_size = "4", seed = "1234")
params <- defaults
for (arg in commandArgs(TRUE)) {
	if (!grepl("=", arg, fixed = TRUE)) stop_err("Invalid argument format: ", arg, " (must be key=value format)")
	parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
	key <- parts[1]
	value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
	value <- trimws(sub("^'(.*)'$", "\\1", sub('^"(.*)"$', "\\1", value)))
	if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", key)) stop_err("Invalid key: ", key)
	if (!key %in% names(defaults)) stop_err("Unknown parameter: ", key)
	if (nzchar(value)) params[[key]] <- value
}
for (k in c("input_dir", "output_dir")) if (!nzchar(params[[k]])) stop_err("Required parameter '", k, "' is missing")
as_int <- function(name, lo) {
	v <- suppressWarnings(as.numeric(params[[name]]))
	if (is.na(v) || v < lo || v != round(v)) stop_err(name, " must be an integer >= ", lo, ": ", params[[name]])
	as.integer(v)
}
bin_size <- as_int("bin_size", 1)
if (!bin_size %in% c(8L, 16L)) stop_err("bin_size must be 8 or 16 (2 um bins are not supported): ", params$bin_size)
min_counts <- as_int("min_counts", 0)
min_features <- as_int("min_features", 0)
nfeatures <- as_int("nfeatures", 100)
sketch_cells <- as_int("sketch_cells", 1000)
seed <- as_int("seed", 0)
pt_size <- suppressWarnings(as.numeric(params$pt_size))
if (is.na(pt_size) || pt_size <= 0) stop_err("pt_size must be a positive number: ", params$pt_size)
input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
bin_dir <- sprintf("square_%03dum", bin_size)
assay_name <- sprintf("Spatial.%03dum", bin_size)

out_norm <- normalizePath(output_dir, mustWork = FALSE)
in_norm <- normalizePath(input_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
if (in_norm == out_norm || startsWith(in_norm, paste0(out_norm, "/"))) {
	stop_err("input_dir ", input_dir, " is inside output_dir ", output_dir, ", which is cleaned at the start")
}

# Slide folders: the folder that holds binned_outputs/<bin_dir>/ is Seurat's data.dir.
find_outs <- function(d) {
	for (cand in c(file.path(d, "outs"), d)) {
		sq <- file.path(cand, "binned_outputs", bin_dir)
		if (file.exists(file.path(sq, "filtered_feature_bc_matrix.h5")) && dir.exists(file.path(sq, "spatial"))) return(cand)
	}
	NA_character_
}
slides <- list()
own <- find_outs(input_dir)
if (!is.na(own)) {
	slides[[basename(in_norm)]] <- own
} else {
	for (d in list.dirs(input_dir, recursive = FALSE)) {
		o <- find_outs(d)
		if (!is.na(o)) slides[[basename(d)]] <- o
	}
}
if (length(slides) == 0) {
	emit_err(paste0("ERROR: no Visium HD slide with binned_outputs/", bin_dir, " found in ", input_dir, "\n",
					"Expected: <slide>/binned_outputs/", bin_dir, "/filtered_feature_bc_matrix.h5 and spatial/ ",
					"(or <slide>/outs/binned_outputs/...)\n",
					"Tip: check bin_size; Space Ranger writes square_002um, square_008um and square_016um.\n"))
	quit(status = 1)
}
bad <- names(slides)[!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", names(slides))]
if (length(bad)) stop_err("slide folder names may hold only letters, digits, '.', '_' and '-': ", paste(bad, collapse = ", "))

for (pkg in c("Seurat", "SeuratObject", "ggplot2", "patchwork", "arrow", "hdf5r")) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}

# ------------------------------------------------------------
# Output directory and logs
# ------------------------------------------------------------
if (dir.exists(output_dir)) {
	old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
	old <- old[basename(old) != "logs"]
	if (length(old) > 0) unlink(old, recursive = TRUE, force = TRUE)
}
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE)
stamp <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
log_file <- file.path(logs_dir, paste0(stamp, ".log"))
err_file <- file.path(logs_dir, paste0(stamp, ".error.log"))
log_con <- file(log_file, open = "at")
err_con <- file(err_file, open = "at")
sink(log_con, append = TRUE, split = TRUE)
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
suppressPackageStartupMessages({
	library(Seurat)
	library(ggplot2)
	library(patchwork)
})
options(future.globals.maxSize = 64 * 1024^3)

msg("############################## spatial_hd_prep")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-12s = %s", k, params[[k]]))
msg("  assay        = ", assay_name)
msg("Slides (", length(slides), "): ", paste(names(slides), collapse = ", "))

# ------------------------------------------------------------
# Per-slide processing
# ------------------------------------------------------------
process_slide <- function(slide, data_dir) {
	t0 <- Sys.time()
	out <- file.path(output_dir, slide)
	dir.create(file.path(out, "plots"), recursive = TRUE, showWarnings = FALSE)
	obj <- Load10X_Spatial(data.dir = data_dir, bin.size = bin_size, slice = slide)
	if (!assay_name %in% Assays(obj)) stop("assay ", assay_name, " not created by Load10X_Spatial")
	DefaultAssay(obj) <- assay_name
	obj$slide <- slide
	n_count <- paste0("nCount_", assay_name)
	n_feat <- paste0("nFeature_", assay_name)
	n0 <- ncol(obj)
	keep <- obj[[n_count]][, 1] >= min_counts & obj[[n_feat]][, 1] >= min_features
	if (sum(keep) < 100) stop(sprintf("only %d bins pass min_counts=%d and min_features=%d", sum(keep), min_counts, min_features))
	obj <- subset(obj, cells = colnames(obj)[keep])
	msg(sprintf("  %s: %d bins, %d after the filter (median counts %.0f, median genes %.0f)", slide, n0, ncol(obj),
					stats::median(obj[[n_count]][, 1]), stats::median(obj[[n_feat]][, 1])))

	p1 <- VlnPlot(obj, features = c(n_count, n_feat), pt.size = 0, ncol = 2) & theme(axis.title.x = element_blank())
	p2 <- SpatialFeaturePlot(obj, features = n_count, pt.size.factor = pt_size) +
			theme(legend.position = "right")
	qc <- wrap_plots(p1, p2, ncol = 2, widths = c(1, 1.2)) + plot_annotation(title = paste0(slide, " (", bin_size, " um bins)"))
	ggsave(file.path(out, "plots", paste0(slide, "_qc.png")), qc, width = 13, height = 5, dpi = 200)
	ggsave(file.path(out, "plots", paste0(slide, "_qc.pdf")), qc, width = 13, height = 5)

	obj <- NormalizeData(obj, verbose = FALSE)
	obj <- FindVariableFeatures(obj, nfeatures = nfeatures, verbose = FALSE)
	n_sketch <- min(sketch_cells, ncol(obj))
	# Variable genes are passed explicitly: Seurat 5.3 stores them for the counts layer,
	# and without them LeverageScore uses every gene and stops with "too slow".
	obj <- SketchData(obj, ncells = n_sketch, method = "LeverageScore", sketched.assay = "sketch", seed = seed,
			features = VariableFeatures(obj), verbose = FALSE)
	DefaultAssay(obj) <- assay_name
	saveRDS(obj, file.path(out, paste0(slide, "_hd_prep.rds")))
	res <- data.frame(Slide = slide, Bins_raw = n0, Bins = ncol(obj), Median_counts = stats::median(obj[[n_count]][, 1]),
			Median_genes = stats::median(obj[[n_feat]][, 1]), Sketch_bins = ncol(obj[["sketch"]]), Status = "ok",
			Seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), stringsAsFactors = FALSE)
	rm(obj)
	invisible(gc(verbose = FALSE))
	res
}

msg("")
msg("############################## Step 1: per-slide load, QC, normalisation, sketch")
summ <- list()
for (s in names(slides)) {
	msg("############################## Processing slide: ", s)
	r <- tryCatch(process_slide(s, slides[[s]]), error = function(e) {
				warn_msg("slide ", s, " failed: ", conditionMessage(e))
				data.frame(Slide = s, Bins_raw = NA, Bins = NA, Median_counts = NA, Median_genes = NA, Sketch_bins = NA,
						Status = paste0("failed: ", conditionMessage(e)), Seconds = NA, stringsAsFactors = FALSE)
			})
	summ[[s]] <- r
}
summ <- do.call(rbind, summ)
utils::write.table(summ, file.path(output_dir, "hd_prep_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")

ok <- summ$Slide[summ$Status == "ok"]
msg("")
msg("############################## Summary")
msg("Slides: ", nrow(summ), ", done: ", length(ok), ", failed: ", nrow(summ) - length(ok))
msg("")
msg("############################## Done")
msg("Summary: ", file.path(output_dir, "hd_prep_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
if (length(ok) == 0) stop_err("all slides failed; see ", file.path(output_dir, "hd_prep_summary.tsv"))
if (length(ok) < nrow(summ)) warn_msg("some slides failed: ", paste(setdiff(summ$Slide, ok), collapse = ", "))
