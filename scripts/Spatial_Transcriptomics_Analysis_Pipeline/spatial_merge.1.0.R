#!/usr/bin/env Rscript

# ==============================================================================
# spatial_merge.r   [Multi-slice joint analysis]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
#
# Merges every per-slice object into ONE Seurat object and re-runs the
# dimensional reduction and clustering jointly, so that cluster identities are
# directly comparable between sections instead of being independent per-slice
# numberings.
#
# Existing outputs are preserved and extended with:
#   - cluster-by-slice composition plots
#   - joint marker analysis
#
# Input layout (output of spatial_cluster.r):
#   input_dir/
#     anterior/anterior_clustered.rds
#     posterior/posterior_clustered.rds
#
# Output layout:
#   output_dir/
#     merged/
#       merged_clustered.rds
#       merged_cluster_by_slice.csv
#       merged_cluster_markers.csv
#       merged_cluster_top_markers.csv
#       plots/
#         merged_umap.png
#         merged_umap_by_cluster.png
#         merged_spatialdim_all.png
#         merged_spatialdim_<slice>.png
#         merged_features.png
#         merged_feature_<gene>.png
#         merged_cluster_by_slice_stackedbar.png
#         merged_cluster_by_slice_heatmap.png
#         merged_marker_heatmap.png
#         merged_marker_dotplot.png
#     merge_report.txt
#
# Bio-Express argument format:
#   input_dir=/path/to/cluster_output
#   output_dir=/path/to/output
#   npcs=30
#   resolution=0.8
#   integration=none
#   assay=SCT
#   features=Hpca,Plp1
#   marker_topn=5
#   marker_min_pct=0.25
#   marker_logfc=0.25
#   plot_width=8
#   plot_height=6
#   dpi=300
#   seed=1234
# ==============================================================================


args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message("[USAGE] Rscript spatial_merge.r input_dir=... output_dir=...")
	quit(status = 1)
}


parse_key_value_args <- function(args) {
	params <- list()
	for (arg in args) {
		arg <- sub("^--", "", arg)
		if (!grepl("=", arg, fixed = TRUE)) {
			message(sprintf("[FATAL] Invalid argument format: %s", arg))
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


get_chr <- function(key, default) {
	v <- params[[key]]
	if (is.null(v) || !nzchar(v)) default else v
}

get_int <- function(key, default) {
	v <- params[[key]]
	if (is.null(v) || !nzchar(v)) return(default)
	suppressWarnings(as.integer(v))
}

get_num <- function(key, default) {
	v <- params[[key]]
	if (is.null(v) || !nzchar(v)) return(default)
	suppressWarnings(as.numeric(v))
}


input_dir   <- params$input_dir
output_dir  <- get_chr("output_dir", "./bx_spatial_out")
assay_name  <- get_chr("assay", "SCT")
integration <- tolower(get_chr("integration", "none"))
npcs        <- get_int("npcs", 30L)
resolution  <- get_num("resolution", 0.8)
plot_width  <- get_num("plot_width", 8)
plot_height <- get_num("plot_height", 6)
plot_dpi    <- get_int("dpi", 300L)
seed        <- get_int("seed", 1234L)

# Existing optional feature plot arguments
features_arg <- get_chr("features", "")
plot_features <- unique(trimws(strsplit(features_arg, "[,;[:space:]]+")[[1]]))
plot_features <- plot_features[nzchar(plot_features)]

# Added marker parameters
marker_topn    <- get_int("marker_topn", 5L)
marker_min_pct <- get_num("marker_min_pct", 0.25)
marker_logfc   <- get_num("marker_logfc", 0.25)


if (is.null(input_dir) || !nzchar(input_dir)) {
	message("[FATAL] input_dir is required.")
	quit(status = 1)
}
if (!dir.exists(input_dir)) {
	message(sprintf("[FATAL] input_dir not found: %s", input_dir))
	quit(status = 1)
}
if (!(integration %in% c("none", "harmony"))) {
	message(sprintf("[FATAL] integration must be 'none' or 'harmony' (got '%s').", integration))
	quit(status = 1)
}
if (is.na(npcs) || npcs < 2) {
	message("[FATAL] npcs must be an integer >= 2.")
	quit(status = 1)
}
if (is.na(resolution) || resolution <= 0) {
	message("[FATAL] resolution must be a positive number.")
	quit(status = 1)
}
if (is.na(plot_width) || plot_width <= 0 || is.na(plot_height) || plot_height <= 0) {
	message("[FATAL] plot_width and plot_height must be positive numbers.")
	quit(status = 1)
}
if (is.na(plot_dpi) || plot_dpi < 50) {
	message("[FATAL] dpi must be an integer >= 50.")
	quit(status = 1)
}
if (is.na(seed)) {
	message("[FATAL] seed must be an integer.")
	quit(status = 1)
}
if (is.na(marker_topn) || marker_topn < 1) {
	message("[FATAL] marker_topn must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(marker_min_pct) || marker_min_pct < 0 || marker_min_pct > 1) {
	message("[FATAL] marker_min_pct must be between 0 and 1.")
	quit(status = 1)
}
if (is.na(marker_logfc) || marker_logfc < 0) {
	message("[FATAL] marker_logfc must be >= 0.")
	quit(status = 1)
}


log_msg <- function(...) {
	cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(...)))
}


required_pkgs <- c("Seurat", "ggplot2", "patchwork", "Matrix")
missing_pkgs <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(missing_pkgs) > 0) {
	message(sprintf("[FATAL] Missing package(s): %s", paste(missing_pkgs, collapse = ", ")))
	quit(status = 1)
}

suppressPackageStartupMessages({
			library(Seurat)
			library(ggplot2)
			library(patchwork)
		})

options(future.globals.maxSize = 16 * 1024^3)
set.seed(seed)


if (integration == "harmony" && !requireNamespace("harmony", quietly = TRUE)) {
	log_msg("WARNING: integration=harmony requested but the 'harmony' package is not installed.")
	log_msg("         Falling back to integration=none.")
	integration <- "none"
}


safe_name <- function(x) {
	x <- gsub("[^A-Za-z0-9]+", "_", x)
	x <- gsub("^_+|_+$", "", x)
	x
}


# ------------------------------------------------------------------------------
# Helper functions for added marker/composition outputs
# ------------------------------------------------------------------------------

get_top_markers <- function(markers, cluster_levels, topn) {
	
	if (nrow(markers) == 0) {
		return(markers)
	}
	
	fc_candidates <- c("avg_log2FC", "avg_logFC")
	fc_col <- fc_candidates[fc_candidates %in% colnames(markers)][1]
	
	if (length(fc_col) == 0 || is.na(fc_col)) {
		stop("FindAllMarkers output has no avg_log2FC/avg_logFC column.")
	}
	
	markers$cluster <- factor(as.character(markers$cluster), levels = cluster_levels)
	
	markers <- markers[
			order(markers$cluster, -markers[[fc_col]]),
			,
			drop = FALSE
	]
	
	split_markers <- split(markers, markers$cluster, drop = TRUE)
	
	top_list <- lapply(split_markers, function(df) {
				df <- df[order(df[[fc_col]], decreasing = TRUE), , drop = FALSE]
				utils::head(df, topn)
			})
	
	top_markers <- do.call(rbind, top_list)
	rownames(top_markers) <- NULL
	top_markers$cluster <- as.character(top_markers$cluster)
	
	top_markers
}


make_marker_heatmap <- function(obj, top_markers, assay_name, title_text) {
	
	if (nrow(top_markers) == 0) {
		return(NULL)
	}
	
	top_genes <- unique(as.character(top_markers$gene))
	top_genes <- intersect(top_genes, rownames(obj[[assay_name]]))
	
	if (length(top_genes) == 0) {
		return(NULL)
	}
	
	expr <- GetAssayData(obj, assay = assay_name, layer = "data")
	expr <- expr[top_genes, , drop = FALSE]
	
	cluster_factor <- Idents(obj)
	cluster_levels <- levels(cluster_factor)
	
	avg_list <- lapply(cluster_levels, function(cl) {
				cells_use <- names(cluster_factor)[cluster_factor == cl]
				if (length(cells_use) == 1) {
					as.numeric(expr[, cells_use, drop = FALSE])
				} else {
					Matrix::rowMeans(expr[, cells_use, drop = FALSE])
				}
			})
	
	avg_mat <- do.call(cbind, avg_list)
	rownames(avg_mat) <- top_genes
	colnames(avg_mat) <- cluster_levels
	
	if (ncol(avg_mat) > 1) {
		z_mat <- t(scale(t(avg_mat)))
	} else {
		z_mat <- avg_mat
		z_mat[,] <- 0
	}
	
	z_mat[!is.finite(z_mat)] <- 0
	
	heat_df <- as.data.frame(as.table(z_mat), stringsAsFactors = FALSE)
	colnames(heat_df) <- c("gene", "cluster", "zscore")
	
	gene_order <- unique(as.character(top_markers$gene))
	gene_order <- gene_order[gene_order %in% top_genes]
	
	heat_df$gene <- factor(heat_df$gene, levels = rev(gene_order))
	heat_df$cluster <- factor(heat_df$cluster, levels = cluster_levels)
	
	ggplot(heat_df, aes(x = cluster, y = gene, fill = zscore)) +
			geom_tile() +
			labs(
					title = title_text,
					x = "Cluster",
					y = "Gene",
					fill = "Z-score"
			) +
			theme_bw() +
			theme(
					axis.text.x = element_text(angle = 0, hjust = 0.5),
					panel.grid = element_blank()
			)
}


# ------------------------------------------------------------------------------
# Discover slices
# ------------------------------------------------------------------------------

slice_table <- list()

subdirs <- list.dirs(input_dir, recursive = FALSE, full.names = TRUE)

for (sd in subdirs) {
	rds <- list.files(sd, pattern = "_clustered\\.rds$", full.names = TRUE)
	if (length(rds) >= 1) {
		slice_table[[basename(sd)]] <- rds[1]
	}
}

if (length(slice_table) == 0) {
	rds <- list.files(input_dir, pattern = "_clustered\\.rds$", full.names = TRUE)
	for (f in rds) {
		slice_table[[sub("_clustered\\.rds$", "", basename(f))]] <- f
	}
}

if (length(slice_table) < 2) {
	message(sprintf("[FATAL] Found %d slice(s) under %s - merging needs at least 2.",
					length(slice_table), input_dir))
	message("        For a single slice, use the per-slice clustering output directly.")
	quit(status = 1)
}


log_msg("===== Spatial Multi-slice Merge =====")
log_msg("input_dir      : %s", input_dir)
log_msg("output_dir     : %s", output_dir)
log_msg("assay          : %s", assay_name)
log_msg("npcs           : %d", npcs)
log_msg("resolution     : %s", format(resolution))
log_msg("integration    : %s", integration)
log_msg("marker_topn    : %d", marker_topn)
log_msg("marker_min_pct : %.3f", marker_min_pct)
log_msg("marker_logfc   : %.3f", marker_logfc)
log_msg("Discovered %d slice(s): %s", length(slice_table), paste(names(slice_table), collapse = ", "))


merged_out <- file.path(output_dir, "merged")
plot_dir   <- file.path(merged_out, "plots")
dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)


# ------------------------------------------------------------------------------
# Load slices, make identifiers unique
# ------------------------------------------------------------------------------

objs <- list()
var_features <- character(0)
slice_stats <- list()

for (slice_name in names(slice_table)) {
	
	log_msg("---- loading '%s' ----", slice_name)
	
	obj <- readRDS(slice_table[[slice_name]])
	
	if (!inherits(obj, "Seurat")) {
		message(sprintf("[FATAL] '%s' is not a Seurat object.", slice_name))
		quit(status = 1)
	}
	if (!(assay_name %in% Assays(obj))) {
		message(sprintf("[FATAL] slice '%s' has no '%s' assay (available: %s).",
						slice_name, assay_name, paste(Assays(obj), collapse = ", ")))
		quit(status = 1)
	}
	
	DefaultAssay(obj) <- assay_name
	
	obj$orig.ident <- slice_name
	obj$slice      <- slice_name
	Idents(obj)    <- "slice"
	
	# Unique image names + keys
	img_names <- Images(obj)
	if (length(img_names) > 0) {
		new_names <- if (length(img_names) == 1) {
					slice_name
				} else {
					paste0(slice_name, "_", seq_along(img_names))
				}
		for (i in seq_along(img_names)) {
			tryCatch({
						Key(slot(obj, "images")[[img_names[i]]]) <- paste0(safe_name(new_names[i]), "_")
					}, error = function(e) invisible(NULL))
		}
		names(slot(obj, "images")) <- new_names
		log_msg("  image(s) renamed: %s -> %s",
				paste(img_names, collapse = ", "), paste(new_names, collapse = ", "))
	} else {
		log_msg("  WARNING: no image found; spatial plots will be unavailable for this slice.")
	}
	
	vf <- VariableFeatures(obj)
	var_features <- c(var_features, vf)
	
	log_msg("  %d spots, %d variable feature(s)", ncol(obj), length(vf))
	
	slice_stats[[slice_name]] <- c(spots = ncol(obj), varfeat = length(vf))
	
	objs[[slice_name]] <- obj
}

var_features <- unique(var_features)


# ------------------------------------------------------------------------------
# Merge
# ------------------------------------------------------------------------------

log_msg("Merging %d slice(s) ...", length(objs))

merged <- merge(
		x = objs[[1]],
		y = objs[-1],
		add.cell.ids = names(objs),
		merge.data = TRUE
)

rm(objs)
invisible(gc(verbose = FALSE))

DefaultAssay(merged) <- assay_name

log_msg("Merged object: %d features x %d spots", nrow(merged), ncol(merged))
log_msg("Images       : %s", paste(Images(merged), collapse = ", "))


# restore variable features
VariableFeatures(merged) <- var_features
log_msg("Variable features restored: %d (union across slices)", length(var_features))

if (length(var_features) == 0) {
	message("[FATAL] no variable features available after merge; cannot run PCA.")
	message("        Check that spatial_cluster.r stored variable features on the SCT assay.")
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# Joint dimensional reduction + clustering
# ------------------------------------------------------------------------------

log_msg("Running PCA (npcs = %d) ...", npcs)
merged <- RunPCA(merged, assay = assay_name, npcs = npcs, verbose = FALSE)

reduction_use <- "pca"

if (integration == "harmony") {
	log_msg("Running Harmony batch correction on 'slice' ...")
	merged <- harmony::RunHarmony(
			merged,
			group.by.vars = "slice",
			reduction     = "pca",
			assay.use     = assay_name,
			verbose       = FALSE
	)
	reduction_use <- "harmony"
}

avail_dims <- ncol(Embeddings(merged[[reduction_use]]))
if (npcs > avail_dims) {
	log_msg("Requested npcs (%d) exceeds available dims (%d); clamping.", npcs, avail_dims)
	npcs <- avail_dims
}

log_msg("Clustering on '%s' (dims 1:%d, resolution %s) ...", reduction_use, npcs, format(resolution))
merged <- FindNeighbors(merged, reduction = reduction_use, dims = seq_len(npcs), verbose = FALSE)
merged <- FindClusters(merged, resolution = resolution, verbose = FALSE)

log_msg("Running UMAP ...")
merged <- RunUMAP(merged, reduction = reduction_use, dims = seq_len(npcs), verbose = FALSE)

n_clusters <- length(levels(Idents(merged)))
log_msg("Found %d joint cluster(s)", n_clusters)


# ------------------------------------------------------------------------------
# Cluster composition per slice
# ------------------------------------------------------------------------------

comp <- as.data.frame.matrix(table(Idents(merged), merged$slice))
comp <- data.frame(cluster = rownames(comp), comp, row.names = NULL,
		check.names = FALSE, stringsAsFactors = FALSE)

slice_cols <- setdiff(colnames(comp), "cluster")
comp$total <- rowSums(comp[, slice_cols, drop = FALSE])

write.csv(comp, file.path(merged_out, "merged_cluster_by_slice.csv"), row.names = FALSE)

log_msg("Cluster composition by slice:")
for (i in seq_len(nrow(comp))) {
	log_msg("  cluster %-4s %s",
			comp$cluster[i],
			paste(sprintf("%s=%d", slice_cols, unlist(comp[i, slice_cols])), collapse = "  "))
}

slice_specific <- comp$cluster[apply(comp[, slice_cols, drop = FALSE], 1,
				function(r) sum(r > 0) == 1)]

if (length(slice_specific) > 0) {
	log_msg("NOTE: %d cluster(s) occur in only one slice: %s",
			length(slice_specific), paste(slice_specific, collapse = ", "))
	if (integration == "none") {
		log_msg("      With integration=none this may be real anatomy (different sections)")
		log_msg("      or an uncorrected batch effect. Compare against integration=harmony")
		log_msg("      if the slices are meant to cover the same tissue.")
	}
}


# ------------------------------------------------------------------------------
# Plot helpers
# ------------------------------------------------------------------------------

save_plot <- function(p, filename, width = plot_width, height = plot_height) {
	tryCatch({
				ggsave(file.path(plot_dir, filename), plot = p,
						width = width, height = height, dpi = plot_dpi, limitsize = FALSE)
				TRUE
			}, error = function(e) {
				log_msg("  WARNING: could not write %s: %s", filename, conditionMessage(e))
				FALSE
			})
}


log_msg("Writing plots ...")

# Existing UMAP plots
save_plot(
		DimPlot(merged, reduction = "umap", group.by = c("ident", "orig.ident")),
		"merged_umap.png",
		width = plot_width * 2
)

save_plot(
		DimPlot(merged, reduction = "umap", label = TRUE) + ggtitle("Joint clusters"),
		"merged_umap_by_cluster.png"
)

n_img <- length(Images(merged))

if (n_img > 0) {
	
	save_plot(
			SpatialDimPlot(merged, label = TRUE, label.size = 3),
			"merged_spatialdim_all.png",
			width = plot_height * n_img, height = plot_height
	)
	
	for (img in Images(merged)) {
		save_plot(
				SpatialDimPlot(merged, images = img, label = TRUE, label.size = 3) +
						ggtitle(img),
				sprintf("merged_spatialdim_%s.png", safe_name(img)),
				width = plot_height, height = plot_height
		)
	}
	
	if (length(plot_features) > 0) {
		
		found   <- intersect(plot_features, rownames(merged[[assay_name]]))
		missing <- setdiff(plot_features, found)
		
		if (length(missing) > 0) {
			log_msg("  WARNING: feature(s) not found in assay '%s': %s",
					assay_name, paste(missing, collapse = ", "))
		}
		
		if (length(found) > 0) {
			
			log_msg("  drawing feature grid for: %s", paste(found, collapse = ", "))
			
			save_plot(
					SpatialFeaturePlot(merged, features = found),
					"merged_features.png",
					width  = plot_height * n_img,
					height = plot_height * length(found)
			)
			
			for (g in found) {
				save_plot(
						SpatialFeaturePlot(merged, features = g),
						sprintf("merged_feature_%s.png", safe_name(g)),
						width  = plot_height * n_img,
						height = plot_height
				)
			}
		}
	}
}


# ------------------------------------------------------------------------------
# ADDED: cluster-by-slice composition plots
# ------------------------------------------------------------------------------

if (length(slice_cols) > 0 && nrow(comp) > 0) {
	
	# long format
	comp_long <- do.call(
			rbind,
			lapply(slice_cols, function(slc) {
						data.frame(
								cluster = comp$cluster,
								slice   = slc,
								n_spots = comp[[slc]],
								stringsAsFactors = FALSE
						)
					})
	)
	
	# proportions within each slice
	slice_totals <- tapply(comp_long$n_spots, comp_long$slice, sum)
	comp_long$prop <- comp_long$n_spots / slice_totals[comp_long$slice]
	
	comp_long$cluster <- factor(comp_long$cluster, levels = as.character(comp$cluster))
	comp_long$slice   <- factor(comp_long$slice, levels = slice_cols)
	
	# stacked barplot
	p_bar <- ggplot(comp_long, aes(x = slice, y = prop, fill = cluster)) +
			geom_col(position = "stack") +
			labs(
					title = "Cluster composition by slice",
					x = "Slice",
					y = "Proportion"
			) +
			theme_bw() +
			theme(panel.grid = element_blank())
	
	save_plot(
			p_bar,
			"merged_cluster_by_slice_stackedbar.png",
			width = max(plot_width, 1.5 * length(slice_cols) + 4),
			height = plot_height
	)
	
	# heatmap of proportion
	heat_df <- comp_long
	heat_df$cluster <- factor(heat_df$cluster, levels = rev(as.character(comp$cluster)))
	
	p_heat_comp <- ggplot(heat_df, aes(x = slice, y = cluster, fill = prop)) +
			geom_tile() +
			labs(
					title = "Cluster proportion by slice",
					x = "Slice",
					y = "Cluster",
					fill = "Proportion"
			) +
			theme_bw() +
			theme(panel.grid = element_blank())
	
	save_plot(
			p_heat_comp,
			"merged_cluster_by_slice_heatmap.png",
			width = max(plot_width, 1.3 * length(slice_cols) + 3),
			height = max(plot_height, 0.45 * nrow(comp) + 3)
	)
}


# ------------------------------------------------------------------------------
# ADDED: joint marker analysis
# ------------------------------------------------------------------------------

marker_csv     <- file.path(merged_out, "merged_cluster_markers.csv")
top_marker_csv <- file.path(merged_out, "merged_cluster_top_markers.csv")

if (n_clusters < 2) {
	
	log_msg("WARNING: only one joint cluster; marker analysis skipped.")
	write.csv(data.frame(), marker_csv, row.names = FALSE)
	write.csv(data.frame(), top_marker_csv, row.names = FALSE)
	
} else {
	
	log_msg("Running joint marker analysis ...")
	
	marker_ok <- tryCatch({
				
				DefaultAssay(merged) <- assay_name
				
				n_sct_models <- tryCatch(
						length(merged[[assay_name]]@SCTModel.list),
						error = function(e) 0L
				)
				
				if (assay_name == "SCT" && n_sct_models > 1L) {
					log_msg("  %s assay has %d models; running PrepSCTFindMarkers() ...",
							assay_name, n_sct_models)
					merged <- PrepSCTFindMarkers(
							merged,
							assay = assay_name,
							verbose = FALSE
					)
				}
				
				log_msg("  FindAllMarkers (min.pct=%.3f, logfc=%.3f)",
						marker_min_pct, marker_logfc)
				
				markers <- FindAllMarkers(
						merged,
						assay = assay_name,
						only.pos = TRUE,
						min.pct = marker_min_pct,
						logfc.threshold = marker_logfc,
						verbose = FALSE
				)
				
				if (nrow(markers) == 0) {
					log_msg("  WARNING: FindAllMarkers returned no markers.")
					write.csv(markers, marker_csv, row.names = FALSE)
					write.csv(markers, top_marker_csv, row.names = FALSE)
					return(TRUE)
				}
				
				fc_candidates <- c("avg_log2FC", "avg_logFC")
				fc_col <- fc_candidates[fc_candidates %in% colnames(markers)][1]
				
				if (length(fc_col) == 0 || is.na(fc_col)) {
					stop("marker table has no avg_log2FC/avg_logFC column")
				}
				
				cluster_levels <- levels(Idents(merged))
				markers$cluster <- factor(as.character(markers$cluster), levels = cluster_levels)
				markers <- markers[order(markers$cluster, -markers[[fc_col]]), , drop = FALSE]
				markers$cluster <- as.character(markers$cluster)
				
				write.csv(markers, marker_csv, row.names = FALSE)
				log_msg("  markers: %d rows", nrow(markers))
				
				top_markers <- get_top_markers(markers, cluster_levels = cluster_levels, topn = marker_topn)
				write.csv(top_markers, top_marker_csv, row.names = FALSE)
				log_msg("  top markers: %d rows (%d per cluster max)", nrow(top_markers), marker_topn)
				
				if (nrow(top_markers) > 0) {
					
					top_genes <- unique(as.character(top_markers$gene))
					top_genes <- intersect(top_genes, rownames(merged[[assay_name]]))
					
					if (length(top_genes) > 0) {
						
						# marker heatmap
						p_marker_heat <- make_marker_heatmap(
								obj = merged,
								top_markers = top_markers,
								assay_name = assay_name,
								title_text = "Merged object top cluster markers"
						)
						
						if (!is.null(p_marker_heat)) {
							save_plot(
									p_marker_heat,
									"merged_marker_heatmap.png",
									width = max(7, 1.0 * length(cluster_levels) + 3),
									height = max(6, 0.28 * length(top_genes) + 2)
							)
						}
						
						# marker dotplot
						p_marker_dot <- DotPlot(
										merged,
										features = top_genes,
										assay = assay_name
								) +
								RotatedAxis() +
								ggtitle("Merged object top cluster markers") +
								xlab("Marker gene") +
								ylab("Cluster")
						
						save_plot(
								p_marker_dot,
								"merged_marker_dotplot.png",
								width = max(10, 0.38 * length(top_genes) + 5),
								height = max(5, 0.45 * length(cluster_levels) + 3)
						)
					}
				}
				
				TRUE
				
			}, error = function(e) {
				
				log_msg("  WARNING: joint marker analysis failed: %s", conditionMessage(e))
				
				if (!file.exists(marker_csv)) {
					write.csv(data.frame(), marker_csv, row.names = FALSE)
				}
				if (!file.exists(top_marker_csv)) {
					write.csv(data.frame(), top_marker_csv, row.names = FALSE)
				}
				
				FALSE
			})
}


# ------------------------------------------------------------------------------
# Save + report
# ------------------------------------------------------------------------------

out_rds <- file.path(merged_out, "merged_clustered.rds")
saveRDS(merged, out_rds)
log_msg("Saved merged object -> %s", out_rds)


report_lines <- c(
		"==================================================================",
		" MULTI-SLICE MERGE REPORT",
		"==================================================================",
		sprintf("slices            : %s", paste(names(slice_table), collapse = ", ")),
		sprintf("assay             : %s", assay_name),
		sprintf("variable features : %d (union across slices)", length(var_features)),
		sprintf("reduction         : %s (dims 1:%d)", reduction_use, npcs),
		sprintf("integration       : %s", integration),
		sprintf("resolution        : %s", format(resolution)),
		sprintf("joint clusters    : %d", n_clusters),
		sprintf("merged spots      : %d", ncol(merged)),
		sprintf("marker_topn       : %d", marker_topn),
		sprintf("marker_min_pct    : %s", format(marker_min_pct)),
		sprintf("marker_logfc      : %s", format(marker_logfc)),
		"------------------------------------------------------------------"
)

for (s in names(slice_stats)) {
	report_lines <- c(report_lines,
			sprintf("  %-20s %d spots, %d variable features",
					s, slice_stats[[s]]["spots"], slice_stats[[s]]["varfeat"]))
}

report_lines <- c(report_lines,
		"------------------------------------------------------------------",
		sprintf("slice-specific clusters : %s",
				if (length(slice_specific)) paste(slice_specific, collapse = ", ") else "(none)"),
		"",
		"ADDED OUTPUTS:",
		"  - merged_cluster_by_slice_stackedbar.png",
		"  - merged_cluster_by_slice_heatmap.png",
		"  - merged_cluster_markers.csv",
		"  - merged_cluster_top_markers.csv",
		"  - merged_marker_heatmap.png",
		"  - merged_marker_dotplot.png",
		"",
		"NOTE: marker analysis on merged SCT objects requires PrepSCTFindMarkers().",
		"      This script runs it automatically when multiple SCT models are present.",
		"=================================================================="
)

writeLines(report_lines, file.path(output_dir, "merge_report.txt"))

cat("\n")
cat(paste(report_lines, collapse = "\n"), "\n\n", sep = "")

log_msg("DONE.")
quit(status = 0)
