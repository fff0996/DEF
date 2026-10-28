#!/usr/bin/env Rscript
# Version 1.1 (changes from spatial_hd_svf.1.0.R):
#   The top genes (plot, svf_summary.tsv Top_genes, log) are the significant genes with the
#   highest Moran's I. 1.0 sorted the table but picked the genes with the significance flags of
#   the unsorted table, so the plotted genes were significant but not the top ones. The gene
#   table (<slide>_hd_svf.tsv) was already right.
# Spatial module (Visium HD): spatially variable genes per slide (Moran's I).
#
# Usage:
#   Rscript spatial_hd_svf.1.1.R input_dir="..." output_dir="..."
#       [svf_topn="500"] [max_bins="4000"] [svf_show="6"] [padj_cutoff="0.05"]
#       [pt_size="4"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.1.sif Rscript spatial_hd_svf.1.1.R \
#       input_dir="/out/spatial_hd_cluster" output_dir="/out/spatial_hd_svf"
#
# Arguments (key=value):
#   input_dir   (required) - Visium HD cluster folder: hd_slides.tsv (Slide, RDS, Assay) and one
#                            Seurat object per slide with the binned assay, as written by
#                            spatial_hd_cluster.
#   output_dir  (required) - Output directory.
#   svf_topn    (optional) - Most variable genes of each slide tested. default: 500
#   max_bins    (optional) - Bins per slide used for Moran's I, sampled at random; the cost
#                            grows with the square of this number. default: 4000
#   svf_show    (optional) - Top genes drawn on the tissue. default: 6
#   padj_cutoff (optional) - Adjusted p-value (BH) for calling a gene spatially variable.
#                            default: 0.05
#   pt_size     (optional) - Bin size in the tissue plots (Seurat pt.size.factor). default: 4
#   seed        (optional) - Random seed for the bin sample. default: 1234
#
# Method: for each slide, the svf_topn most variable genes (vst on all bins) are tested on
# max_bins randomly sampled bins: Moran's I (Seurat RunMoransI, inverse-distance weights,
# ape) on the log-normalised data and the tissue coordinates. Genes are ranked by Moran's I
# among those with an adjusted p-value below padj_cutoff. The top svf_show genes are drawn
# on all bins.
#
# Outputs (output_dir):
#   <slide>/<slide>_hd_svf.tsv     Gene, Morans_I, P_value, P_adj, Rank (all tested genes)
#   <slide>/plots/<slide>_top_svf.png and .pdf
#   svf_all_slides.tsv             the per-slide tables stacked, with a Slide column
#   svf_summary.tsv                Slide, Bins, Bins_tested, Genes_tested, Significant,
#                                  Top_genes, Seconds, Status
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# A slide without significant genes is a data result (warning, status no_significant_genes,
# exit 0). The run fails only when every slide fails. The previous output_dir content except
# logs/ is removed at the start, so no input may be inside output_dir.

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
defaults <- list(input_dir = "", output_dir = "", svf_topn = "500", max_bins = "4000", svf_show = "6",
		padj_cutoff = "0.05", pt_size = "4", seed = "1234")
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
as_num <- function(name, lo = -Inf, hi = Inf, integer = FALSE) {
	v <- suppressWarnings(as.numeric(params[[name]]))
	if (is.na(v) || v < lo || v > hi || (integer && v != round(v))) {
		stop_err(name, " must be ", if (integer) "an integer" else "a number", " in [", lo, ", ", hi, "]: ", params[[name]])
	}
	v
}
svf_topn <- as_num("svf_topn", 10, 5000, TRUE)
max_bins <- as_num("max_bins", 100, 20000, TRUE)
svf_show <- as_num("svf_show", 0, 24, TRUE)
padj_cutoff <- as_num("padj_cutoff", 0, 1)
pt_size <- as_num("pt_size", 0.1, 50)
seed <- as_num("seed", 0, integer = TRUE)
input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
input_dir <- normalizePath(input_dir)
out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
if (input_dir == out_norm || startsWith(input_dir, paste0(out_norm, "/"))) {
	stop_err("input_dir ", input_dir, " is inside output_dir ", output_dir, ", which is cleaned at the start")
}
slides_tsv <- file.path(input_dir, "hd_slides.tsv")
if (!file.exists(slides_tsv)) {
	emit_err(paste0("ERROR: hd_slides.tsv not found in input_dir: ", input_dir, "\n",
					"Expected the output folder of spatial_hd_cluster (hd_slides.tsv and <slide>/<slide>_hd_clustered.rds).\n"))
	quit(status = 1)
}
hd <- utils::read.delim(slides_tsv, stringsAsFactors = FALSE)
if (!all(c("Slide", "RDS", "Assay") %in% names(hd))) stop_err("hd_slides.tsv needs the columns Slide, RDS, Assay: ", slides_tsv)
hd$Path <- ifelse(startsWith(hd$RDS, "/"), hd$RDS, file.path(input_dir, hd$RDS))
missing <- hd$Path[!file.exists(hd$Path)]
if (length(missing)) stop_err("slide object(s) listed in hd_slides.tsv not found: ", paste(missing, collapse = ", "))
for (pkg in c("Seurat", "SeuratObject", "ggplot2", "patchwork", "Matrix", "ape")) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}

# ------------------------------------------------------------
# Output directory and logs
# ------------------------------------------------------------
if (dir.exists(output_dir)) {
	old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
	unlink(old[basename(old) != "logs"], recursive = TRUE, force = TRUE)
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
save_gg <- function(p, path_no_ext, width, height) {
	ggsave(paste0(path_no_ext, ".pdf"), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(paste0(path_no_ext, ".png"), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}

msg("############################## spatial_hd_svf")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-12s = %s", k, params[[k]]))
msg("Slides (", nrow(hd), "): ", paste(hd$Slide, collapse = ", "))

# ------------------------------------------------------------
# Moran's I per slide
# ------------------------------------------------------------
summary_rows <- list()
all_tables <- list()
for (i in seq_len(nrow(hd))) {
	s <- hd$Slide[i]
	a <- hd$Assay[i]
	msg("")
	msg("############################## Processing slide: ", s)
	t0 <- Sys.time()
	row <- tryCatch({
		obj <- readRDS(hd$Path[i])
		if (!a %in% Assays(obj)) stop("assay ", a, " not in the slide object")
		DefaultAssay(obj) <- a
		if (!"data" %in% SeuratObject::Layers(obj[[a]])) obj <- NormalizeData(obj, assay = a, verbose = FALSE)
		img <- Images(obj)
		if (length(img) == 0) stop("the slide object has no image (tissue coordinates)")
		coords <- GetTissueCoordinates(obj, image = img[1])
		if (!"cell" %in% names(coords)) coords$cell <- rownames(coords)
		coords <- coords[coords$cell %in% colnames(obj), ]
		obj <- FindVariableFeatures(obj, assay = a, nfeatures = svf_topn, verbose = FALSE)
		genes <- head(VariableFeatures(obj, assay = a), svf_topn)
		set.seed(seed)
		bins <- if (nrow(coords) > max_bins) sample(coords$cell, max_bins) else coords$cell
		pos <- as.matrix(coords[match(bins, coords$cell), c("x", "y")])
		rownames(pos) <- bins
		mat <- as.matrix(SeuratObject::LayerData(obj, assay = a, layer = "data")[genes, bins, drop = FALSE])
		keep <- apply(mat, 1, function(v) stats::var(v) > 0)
		mat <- mat[keep, , drop = FALSE]
		msg(sprintf("  %d bins, testing %d genes on %d sampled bins", ncol(obj), nrow(mat), length(bins)))
		mi <- RunMoransI(data = mat, pos = pos, verbose = FALSE)
		tab <- data.frame(Gene = rownames(mi), Morans_I = round(mi$observed, 5), P_value = signif(mi$p.value, 4))
		tab$P_adj <- signif(stats::p.adjust(tab$P_value, "BH"), 4)
		sig <- tab$P_adj < padj_cutoff
		tab <- tab[order(!sig, -tab$Morans_I), ]
		# 1.1: sig follows the new row order, so the top genes are the highest Moran's I ones
		sig <- tab$P_adj < padj_cutoff
		tab$Rank <- ifelse(sig, cumsum(sig), NA)
		dir.create(file.path(output_dir, s, "plots"), recursive = TRUE, showWarnings = FALSE)
		utils::write.table(tab, file.path(output_dir, s, paste0(s, "_hd_svf.tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
		all_tables[[s]] <- cbind(Slide = s, tab)
		top <- head(tab$Gene[sig], svf_show)
		status <- "ok"
		if (length(top) == 0) {
			status <- "no_significant_genes"
			warn_msg(s, ": no gene has a Moran's I adjusted p-value below ", padj_cutoff,
					"; the tested genes show no spatial pattern at this sample size (max_bins).")
		} else {
			p <- SpatialFeaturePlot(obj, features = top, images = img[1], pt.size.factor = pt_size, ncol = min(3, length(top))) +
					plot_annotation(title = paste0(s, ": top spatially variable genes (Moran's I)"))
			save_gg(p, file.path(output_dir, s, "plots", paste0(s, "_top_svf")), 4.2 * min(3, length(top)),
					4 * ceiling(length(top) / 3) + 0.6)
		}
		secs <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
		msg(sprintf("  %d of %d genes significant (padj < %s); top: %s; %d s", sum(sig), nrow(tab), padj_cutoff,
						paste(head(top, 6), collapse = ", "), secs))
		res <- data.frame(Slide = s, Bins = ncol(obj), Bins_tested = length(bins), Genes_tested = nrow(tab),
				Significant = sum(sig), Top_genes = paste(head(top, 6), collapse = ","), Seconds = secs, Status = status)
		rm(obj, mat)
		invisible(gc(verbose = FALSE))
		res
	}, error = function(e) {
		warn_msg("slide ", s, " failed: ", conditionMessage(e))
		data.frame(Slide = s, Bins = NA, Bins_tested = NA, Genes_tested = NA, Significant = NA, Top_genes = "",
				Seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))), Status = "failed")
	})
	summary_rows[[s]] <- row
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
summary_df <- do.call(rbind, summary_rows)
utils::write.table(summary_df, file.path(output_dir, "svf_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
if (length(all_tables)) {
	utils::write.table(do.call(rbind, all_tables), file.path(output_dir, "svf_all_slides.tsv"), sep = "\t", quote = FALSE,
			row.names = FALSE)
}
msg("")
msg("############################## Summary")
for (i in seq_len(nrow(summary_df))) {
	msg(sprintf("  %-20s %-22s significant %s  top: %s", summary_df$Slide[i], summary_df$Status[i],
					summary_df$Significant[i], summary_df$Top_genes[i]))
}
failed <- summary_df$Slide[summary_df$Status == "failed"]
if (length(failed) == nrow(summary_df)) stop_err("all slides failed; see the warnings above")
if (length(failed)) warn_msg("some slides failed: ", paste(failed, collapse = ", "), ". Check svf_summary.tsv.")
msg("")
msg("############################## Done")
msg("Summary: ", file.path(output_dir, "svf_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
