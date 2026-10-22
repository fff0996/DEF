#!/usr/bin/env Rscript
# Spatial module (Visium HD): joint clustering of all slides on their sketches, then
# cluster labels for every bin.
#
# Usage:
#   Rscript spatial_hd_cluster.1.0.R input_dir="..." output_dir="..."
#       [dims="30"] [resolution="0.8"] [integration="auto"] [nfeatures="2000"]
#       [k_transfer="10"] [marker_min_pct="0.25"] [marker_logfc="0.25"] [marker_topn="5"]
#       [features=""] [pt_size="4"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.0.sif Rscript spatial_hd_cluster.1.0.R \
#       input_dir="/out/spatial_hd_prep" output_dir="/out/spatial_hd_cluster"
#
# Arguments (key=value):
#   input_dir      (required) - Visium HD prep folder: <slide>/<slide>_hd_prep.rds per slide
#                               (Seurat object with the binned assay Spatial.<NNN>um and a
#                               'sketch' assay), as written by spatial_hd_prep.
#   output_dir     (required) - Output directory.
#   dims           (optional) - Principal components used. default: 30
#   resolution     (optional) - Clustering resolution (Louvain). default: 0.8
#   integration    (optional) - auto (harmony when there are two or more slides), harmony,
#                               or none. default: auto
#   nfeatures      (optional) - Variable genes of the joint sketch. default: 2000
#   k_transfer     (optional) - Nearest sketched bins used to label each bin. default: 10
#   marker_min_pct (optional) - FindAllMarkers min.pct. default: 0.25
#   marker_logfc   (optional) - FindAllMarkers logfc.threshold. default: 0.25
#   marker_topn    (optional) - Top markers per cluster in the dot plot. default: 5
#   features       (optional) - Genes to draw on the tissue, comma separated. default: empty
#   pt_size        (optional) - Bin size in the tissue plots (Seurat pt.size.factor); 4 fills
#                               the gaps between bins at the default figure size. default: 4
#   seed           (optional) - Random seed. default: 1234
#
# Method:
#   1. The sketched bins of all slides are merged (cell names <slide>_<barcode>),
#      log-normalised, scaled on the joint variable genes, PCA; with integration, Harmony
#      corrects the slides; FindNeighbors, FindClusters and UMAP run on the sketch, and
#      FindAllMarkers (presto) gives cluster markers.
#   2. Every bin of a slide is projected onto the joint PCA (same gene means, standard
#      deviations and loadings, values clipped at 10 like ScaleData) and gets the majority
#      cluster of its k_transfer nearest sketched bins of the same slide (Annoy, Euclidean);
#      Cluster_score is the fraction of neighbours with that cluster. Sketched bins keep
#      their own cluster. Clusters therefore mean the same in every slide.
#
# Outputs (output_dir):
#   joint/hd_sketch_joint.rds, cluster_markers.tsv, top_markers.tsv, cluster_by_slide.tsv
#   joint/plots/ umap_clusters, umap_slides, marker_dotplot, cluster_by_slide (.png, .pdf)
#   <slide>/<slide>_hd_clustered.rds  all bins with seurat_clusters and Cluster_score
#   <slide>/plots/<slide>_clusters_spatial (.png, .pdf), <slide>_feature_<gene> (.png, .pdf)
#   hd_slides.tsv  Slide, RDS (relative to output_dir), Assay, Bins: read by
#                  spatial_condition_de
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# The previous output_dir content except logs/ is removed at the start, so no input may
# be inside output_dir.

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
defaults <- list(input_dir = "", output_dir = "", dims = "30", resolution = "0.8", integration = "auto",
		nfeatures = "2000", k_transfer = "10", marker_min_pct = "0.25", marker_logfc = "0.25", marker_topn = "5",
		features = "", pt_size = "4", seed = "1234")
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
dims <- as_num("dims", 2, 100, TRUE)
resolution <- as_num("resolution", 0.01)
nfeatures <- as_num("nfeatures", 100, integer = TRUE)
k_transfer <- as_num("k_transfer", 1, 100, TRUE)
marker_min_pct <- as_num("marker_min_pct", 0, 1)
marker_logfc <- as_num("marker_logfc", 0)
marker_topn <- as_num("marker_topn", 1, integer = TRUE)
seed <- as_num("seed", 0, integer = TRUE)
pt_size <- as_num("pt_size", 0.1, 50)
if (!params$integration %in% c("auto", "harmony", "none")) stop_err("integration must be auto, harmony, or none: ", params$integration)
features <- unique(trimws(strsplit(params$features, ",", fixed = TRUE)[[1]]))
features <- features[nzchar(features)]
input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
out_norm <- normalizePath(output_dir, mustWork = FALSE)
in_norm <- normalizePath(input_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
if (in_norm == out_norm || startsWith(in_norm, paste0(out_norm, "/"))) {
	stop_err("input_dir ", input_dir, " is inside output_dir ", output_dir, ", which is cleaned at the start")
}

rds <- list.files(input_dir, pattern = "_hd_prep\\.rds$", recursive = TRUE, full.names = TRUE)
names(rds) <- sub("_hd_prep\\.rds$", "", basename(rds))
if (length(rds) == 0) {
	emit_err(paste0("ERROR: no <slide>_hd_prep.rds found in input_dir: ", input_dir, "\n",
					"Expected the output folder of spatial_hd_prep (<slide>/<slide>_hd_prep.rds).\n"))
	quit(status = 1)
}
if (anyDuplicated(names(rds))) stop_err("duplicate slide names in input_dir: ", paste(names(rds)[duplicated(names(rds))], collapse = ", "))
integration <- if (params$integration == "auto") (if (length(rds) > 1) "harmony" else "none") else params$integration
pkgs <- c("Seurat", "SeuratObject", "ggplot2", "patchwork", "RcppAnnoy", "Matrix")
if (integration == "harmony") pkgs <- c(pkgs, "harmony")
for (pkg in pkgs) if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)

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
set.seed(seed)
joint_dir <- file.path(output_dir, "joint")
dir.create(file.path(joint_dir, "plots"), recursive = TRUE, showWarnings = FALSE)
save_gg <- function(p, path_no_ext, width, height) {
	ggsave(paste0(path_no_ext, ".pdf"), p, width = width, height = height, limitsize = FALSE)
	ggsave(paste0(path_no_ext, ".png"), p, width = width, height = height, dpi = 200, limitsize = FALSE)
}

msg("############################## spatial_hd_cluster")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-14s = %s", k, params[[k]]))
msg("  integration used = ", integration)
msg("Slides (", length(rds), "): ", paste(names(rds), collapse = ", "))

# ------------------------------------------------------------
# Step 1: joint sketch
# ------------------------------------------------------------
msg("")
msg("############################## Step 1: joint clustering of the sketches")
sketches <- list()
assays <- character(0)
for (s in names(rds)) {
	obj <- readRDS(rds[[s]])
	if (!"sketch" %in% Assays(obj)) stop_err("slide ", s, " has no 'sketch' assay: ", rds[[s]])
	a <- grep("^Spatial\\.[0-9]+um$", Assays(obj), value = TRUE)[1]
	if (is.na(a)) stop_err("slide ", s, " has no binned assay Spatial.<NNN>um: ", rds[[s]])
	assays[s] <- a
	cnt <- SeuratObject::LayerData(obj, assay = "sketch", layer = "counts")
	sk <- CreateSeuratObject(counts = cnt, assay = "sketch")
	sk$slide <- s
	sketches[[s]] <- sk
	msg(sprintf("  %s: %d bins, %d sketched (%s)", s, ncol(obj), ncol(cnt), a))
	rm(obj, cnt)
	invisible(gc(verbose = FALSE))
}
if (length(unique(assays)) > 1) stop_err("slides use different bin sizes: ", paste(unique(assays), collapse = ", "))
joint <- if (length(sketches) > 1) merge(sketches[[1]], sketches[-1], add.cell.ids = names(sketches)) else
			RenameCells(sketches[[1]], add.cell.id = names(sketches)[1])
rm(sketches)
joint <- JoinLayers(joint)
joint <- NormalizeData(joint, verbose = FALSE)
joint <- FindVariableFeatures(joint, nfeatures = nfeatures, verbose = FALSE)
joint <- ScaleData(joint, verbose = FALSE)
joint <- RunPCA(joint, npcs = dims, verbose = FALSE)
red <- "pca"
if (integration == "harmony") {
	joint <- harmony::RunHarmony(joint, group.by.vars = "slide", reduction.use = "pca", reduction.save = "harmony",
			verbose = FALSE)
	red <- "harmony"
}
joint <- FindNeighbors(joint, reduction = red, dims = seq_len(dims), verbose = FALSE)
joint <- FindClusters(joint, resolution = resolution, random.seed = seed, verbose = FALSE)
joint <- RunUMAP(joint, reduction = red, dims = seq_len(dims), seed.use = seed, verbose = FALSE)
levels_cl <- levels(joint$seurat_clusters)
pal <- setNames(scales::hue_pal()(length(levels_cl)), levels_cl)
msg("Joint sketch: ", ncol(joint), " bins, ", length(levels_cl), " clusters (", red, ", dims 1:", dims, ")")

comp <- as.data.frame.matrix(table(joint$seurat_clusters, joint$slide))
p <- DimPlot(joint, group.by = "seurat_clusters", cols = pal, label = TRUE, raster = TRUE) + ggtitle("Joint clusters (sketch)")
save_gg(p, file.path(joint_dir, "plots", "umap_clusters"), 7, 6)
p <- DimPlot(joint, group.by = "slide", raster = TRUE, shuffle = TRUE) + ggtitle("Slides (sketch)")
save_gg(p, file.path(joint_dir, "plots", "umap_slides"), 7, 6)

msg("Markers (FindAllMarkers on the sketch) ...")
markers <- tryCatch(FindAllMarkers(joint, only.pos = TRUE, min.pct = marker_min_pct, logfc.threshold = marker_logfc,
				verbose = FALSE), error = function(e) {
			warn_msg("marker analysis failed: ", conditionMessage(e))
			data.frame()
		})
utils::write.table(markers, file.path(joint_dir, "cluster_markers.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
if (nrow(markers)) {
	top <- do.call(rbind, lapply(split(markers, markers$cluster), function(d) head(d[order(-d$avg_log2FC), ], marker_topn)))
	utils::write.table(top, file.path(joint_dir, "top_markers.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
	genes <- unique(top$gene)
	p <- DotPlot(joint, features = genes) + RotatedAxis() + ggtitle("Top cluster markers (sketch)")
	save_gg(p, file.path(joint_dir, "plots", "marker_dotplot"), max(10, 0.3 * length(genes) + 4), max(5, 0.35 * length(levels_cl) + 2))
}

# ------------------------------------------------------------
# Step 2: labels for every bin, slide by slide
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: cluster labels for all bins")
vf <- intersect(VariableFeatures(joint), rownames(Loadings(joint[["pca"]])))
load_mat <- Loadings(joint[["pca"]])[vf, seq_len(dims), drop = FALSE]
jd <- SeuratObject::LayerData(joint, assay = "sketch", layer = "data")[vf, , drop = FALSE]
mu <- Matrix::rowMeans(jd)
sdv <- sqrt(pmax(Matrix::rowMeans(jd^2) - mu^2, 0) * ncol(jd) / max(1, ncol(jd) - 1))
sdv[sdv == 0] <- 1
emb_joint <- Embeddings(joint[["pca"]])[, seq_len(dims), drop = FALSE]
cl_joint <- as.character(joint$seurat_clusters)
names(cl_joint) <- colnames(joint)
slide_of <- joint$slide
saveRDS(joint, file.path(joint_dir, "hd_sketch_joint.rds"))
# Only the projection inputs are kept; the joint object is freed before slides load.
rm(jd, joint)
invisible(gc(verbose = FALSE))

project <- function(data) {
	out <- matrix(0, ncol(data), dims, dimnames = list(colnames(data), colnames(load_mat)))
	present <- vf[vf %in% rownames(data)]
	for (start in seq(1, ncol(data), by = 5000)) {
		idx <- start:min(ncol(data), start + 4999)
		x <- matrix(0, length(vf), length(idx), dimnames = list(vf, NULL))
		x[present, ] <- as.matrix(data[present, idx, drop = FALSE])
		x <- pmin((x - mu) / sdv, 10)
		out[idx, ] <- crossprod(x, load_mat)
		rm(x)
	}
	out
}

manifest <- list()
all_comp <- list()
for (s in names(rds)) {
	msg("############################## Processing slide: ", s)
	t0 <- Sys.time()
	obj <- readRDS(rds[[s]])
	a <- assays[[s]]
	DefaultAssay(obj) <- a
	data <- SeuratObject::LayerData(obj, assay = a, layer = "data")
	emb <- project(data)
	rm(data)
	ref_cells <- names(slide_of)[slide_of == s]
	ref_emb <- emb_joint[ref_cells, , drop = FALSE]
	ref_cl <- cl_joint[ref_cells]
	ann <- new(RcppAnnoy::AnnoyEuclidean, dims)
	for (i in seq_len(nrow(ref_emb))) ann$addItem(i - 1, ref_emb[i, ])
	ann$build(50)
	k <- min(k_transfer, nrow(ref_emb))
	lab <- character(nrow(emb))
	score <- numeric(nrow(emb))
	for (i in seq_len(nrow(emb))) {
		nn <- ann$getNNsByVector(emb[i, ], k) + 1
		tab <- table(ref_cl[nn])
		j <- which.max(tab)
		lab[i] <- names(tab)[j]
		score[i] <- tab[[j]] / k
	}
	own <- paste0(s, "_", colnames(obj))
	in_sketch <- own %in% ref_cells
	lab[in_sketch] <- ref_cl[own[in_sketch]]
	score[in_sketch] <- 1
	obj$seurat_clusters <- factor(lab, levels = levels_cl)
	obj$Cluster_score <- round(score, 3)
	obj$slide <- s
	Idents(obj) <- "seurat_clusters"
	if ("sketch" %in% Assays(obj)) obj[["sketch"]] <- NULL
	dir.create(file.path(output_dir, s, "plots"), recursive = TRUE, showWarnings = FALSE)
	out_rds <- file.path(output_dir, s, paste0(s, "_hd_clustered.rds"))
	saveRDS(obj, out_rds)
	low <- mean(score < 0.5)
	msg(sprintf("  %d bins labelled (%.1f%% with Cluster_score < 0.5), %.0f s", ncol(obj), 100 * low,
					as.numeric(difftime(Sys.time(), t0, units = "secs"))))
	if (low > 0.3) warn_msg(s, ": ", round(100 * low), "% of bins have an ambiguous label (Cluster_score < 0.5); ",
				"consider a lower resolution.")

	pt <- pt_size
	p <- SpatialDimPlot(obj, group.by = "seurat_clusters", cols = pal, pt.size.factor = pt, image.alpha = 0.6) +
			ggtitle(paste0(s, ": joint clusters (all bins)")) + guides(fill = guide_legend(override.aes = list(size = 3), ncol = 2))
	save_gg(p, file.path(output_dir, s, "plots", paste0(s, "_clusters_spatial")), 9, 7)
	for (g in intersect(features, rownames(obj))) {
		p <- SpatialFeaturePlot(obj, features = g, pt.size.factor = pt) + ggtitle(paste0(s, ": ", g))
		save_gg(p, file.path(output_dir, s, "plots", paste0(s, "_feature_", gsub("[^A-Za-z0-9._-]", "_", g))), 7, 6)
	}
	miss <- setdiff(features, rownames(obj))
	if (length(miss)) warn_msg(s, ": features not found: ", paste(miss, collapse = ", "))
	manifest[[s]] <- data.frame(Slide = s, RDS = file.path(s, paste0(s, "_hd_clustered.rds")), Assay = a, Bins = ncol(obj),
			stringsAsFactors = FALSE)
	all_comp[[s]] <- data.frame(Slide = s, Cluster = levels_cl, Bins = as.vector(table(obj$seurat_clusters)[levels_cl]))
	rm(obj, emb, ann)
	invisible(gc(verbose = FALSE))
}
utils::write.table(do.call(rbind, manifest), file.path(output_dir, "hd_slides.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
comp_all <- do.call(rbind, all_comp)
comp_all$Fraction <- round(comp_all$Bins / ave(comp_all$Bins, comp_all$Slide, FUN = sum), 5)
utils::write.table(comp_all, file.path(joint_dir, "cluster_by_slide.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
comp_all$Cluster <- factor(comp_all$Cluster, levels = levels_cl)
p <- ggplot(comp_all, aes(Slide, Fraction, fill = Cluster)) + geom_col(width = 0.85) + scale_fill_manual(values = pal) +
		labs(title = "Cluster composition per slide (all bins)", x = NULL, y = "Fraction of bins") + theme_bw() +
		theme(panel.grid = element_blank(), axis.text.x = element_text(angle = 45, hjust = 1))
save_gg(p, file.path(joint_dir, "plots", "cluster_by_slide"), max(5, 0.8 * length(rds) + 3), 5)

msg("")
msg("############################## Summary")
msg("Slides: ", length(rds), "; clusters: ", length(levels_cl), "; integration: ", integration)
msg("")
msg("############################## Done")
msg("Manifest: ", file.path(output_dir, "hd_slides.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
