#!/usr/bin/env Rscript

# ==============================================================================
# spatial_cluster.r   [Module 2/6 - BATCH multi-slice]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
#
# Per-slice analysis:
#   1. PCA
#   2. FindNeighbors
#   3. FindClusters
#   4. RunUMAP
#   5. Cluster marker analysis
#
# Input layout (output of spatial_prep.r):
#
#   input_dir/
#     control/
#       control_prep.rds
#     treated/
#       treated_prep.rds
#
# Output layout:
#
#   output_dir/
#     logs/                                  <- preserved on rerun
#
#     control/
#       control_clustered.rds
#       control_cluster_summary.csv
#       control_cluster_markers.csv
#       control_cluster_top_markers.csv
#
#       plots/
#         control_clusters_umap_spatial.png
#         control_clusters_spatial_highlight.png
#         control_marker_heatmap.png
#         control_marker_dotplot.png
#
#     treated/
#       ...
#
# All slices use the SAME clustering / marker parameters.
#
# Bio-Express argument format:
#
#   input_dir=/path/to/prep_output
#   output_dir=/path/to/output
#
#   resolution=0.8
#   npcs=30
#
#   marker_topn=5
#   marker_min_pct=0.25
#   marker_logfc=0.25
#
#   seed=1234
#
# ==============================================================================


# ------------------------------------------------------------------------------
# 1. Parse arguments
# ------------------------------------------------------------------------------

args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	
	message("[FATAL] No arguments provided.")
	
	message(
			"[USAGE] Rscript spatial_cluster.r ",
			"input_dir=/path/to/prep_output ",
			"output_dir=/path/to/output"
	)
	
	quit(status = 1)
}


parse_key_value_args <- function(args) {
	
	params <- list()
	
	for (arg in args) {
		
		arg <- sub("^--", "", arg)
		
		if (!grepl("=", arg, fixed = TRUE)) {
			
			message(
					sprintf(
							"[FATAL] Invalid argument format: %s",
							arg
					)
			)
			
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
			
			message(
					sprintf(
							"[FATAL] Empty parameter name: %s",
							arg
					)
			)
			
			quit(status = 1)
		}
		
		params[[key]] <- value
	}
	
	params
}


params <- parse_key_value_args(args)


# ------------------------------------------------------------------------------
# 2. Parameters
# ------------------------------------------------------------------------------

input_dir <- params$input_dir


output_dir <- if (
				!is.null(params$output_dir) &&
				nzchar(params$output_dir)
				) {
			
			params$output_dir
			
		} else {
			
			"./bx_spatial_out"
		}


resolution <- if (
				!is.null(params$resolution) &&
				nzchar(params$resolution)
				) {
			
			suppressWarnings(
					as.numeric(params$resolution)
			)
			
		} else {
			
			0.8
		}


npcs <- if (
				!is.null(params$npcs) &&
				nzchar(params$npcs)
				) {
			
			suppressWarnings(
					as.integer(params$npcs)
			)
			
		} else {
			
			30L
		}


# ------------------------------------------------------------------------------
# Marker parameters
# ------------------------------------------------------------------------------

marker_topn <- if (
				!is.null(params$marker_topn) &&
				nzchar(params$marker_topn)
				) {
			
			suppressWarnings(
					as.integer(params$marker_topn)
			)
			
		} else {
			
			5L
		}


marker_min_pct <- if (
				!is.null(params$marker_min_pct) &&
				nzchar(params$marker_min_pct)
				) {
			
			suppressWarnings(
					as.numeric(params$marker_min_pct)
			)
			
		} else {
			
			0.25
		}


marker_logfc <- if (
				!is.null(params$marker_logfc) &&
				nzchar(params$marker_logfc)
				) {
			
			suppressWarnings(
					as.numeric(params$marker_logfc)
			)
			
		} else {
			
			0.25
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
	
	message(
			sprintf(
					"[FATAL] input_dir not found: %s",
					input_dir
			)
	)
	
	quit(status = 1)
}


if (is.na(resolution) || resolution <= 0) {
	
	message(
			"[FATAL] resolution must be a positive number."
	)
	
	quit(status = 1)
}


if (is.na(npcs) || npcs < 2) {
	
	message(
			"[FATAL] npcs must be an integer >= 2."
	)
	
	quit(status = 1)
}


if (is.na(marker_topn) || marker_topn < 1) {
	
	message(
			"[FATAL] marker_topn must be an integer >= 1."
	)
	
	quit(status = 1)
}


if (
		is.na(marker_min_pct) ||
		marker_min_pct < 0 ||
		marker_min_pct > 1
		) {
	
	message(
			"[FATAL] marker_min_pct must be between 0 and 1."
	)
	
	quit(status = 1)
}


if (
		is.na(marker_logfc) ||
		marker_logfc < 0
		) {
	
	message(
			"[FATAL] marker_logfc must be >= 0."
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
# 4. Logging
# ------------------------------------------------------------------------------

log_msg <- function(...) {
	
	cat(
			sprintf(
					"[%s] %s\n",
					format(
							Sys.time(),
							"%Y-%m-%d %H:%M:%S"
					),
					sprintf(...)
			)
	)
}


# ------------------------------------------------------------------------------
# 5. Required packages
# ------------------------------------------------------------------------------

required_pkgs <- c(
		"Seurat",
		"ggplot2",
		"patchwork",
		"Matrix"
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
	
	message(
			sprintf(
					"[FATAL] Missing package(s): %s",
					paste(
							missing_pkgs,
							collapse = ", "
					)
			)
	)
	
	quit(status = 1)
}


suppressPackageStartupMessages({
			
			library(Seurat)
			library(ggplot2)
			library(patchwork)
			
		})


# Avoid Seurat/future export limit problems on large objects
options(
		future.globals.maxSize = 16 * 1024^3
)


set.seed(seed)


# ------------------------------------------------------------------------------
# 6. Discover slices
#
# Expected:
#
# input_dir/
#   control/
#     control_prep.rds
#   treated/
#     treated_prep.rds
#
# Single-slice shortcut:
#
# input_dir/
#   control_prep.rds
#
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
			pattern = "_prep\\.rds$",
			full.names = TRUE
	)
	
	if (length(rds) >= 1) {
		
		slice_table[[basename(sd)]] <- rds[1]
	}
}


# single-slice shortcut
if (length(slice_table) == 0) {
	
	rds <- list.files(
			input_dir,
			pattern = "_prep\\.rds$",
			full.names = TRUE
	)
	
	if (length(rds) == 1) {
		
		slice_name <- sub(
				"_prep\\.rds$",
				"",
				basename(rds[1])
		)
		
		slice_table[[slice_name]] <- rds[1]
	}
}


if (length(slice_table) == 0) {
	
	message(
			sprintf(
					"[FATAL] No *_prep.rds found under input_dir: %s",
					input_dir
			)
	)
	
	quit(status = 1)
}


# ------------------------------------------------------------------------------
# 7. Run information
# ------------------------------------------------------------------------------

log_msg(
		"===== Spatial Cluster (batch) ====="
)

log_msg(
		"input_dir      : %s",
		input_dir
)

log_msg(
		"output_dir     : %s",
		output_dir
)

log_msg(
		"resolution     : %.3f",
		resolution
)

log_msg(
		"npcs           : %d",
		npcs
)

log_msg(
		"marker_topn    : %d",
		marker_topn
)

log_msg(
		"marker_min_pct : %.3f",
		marker_min_pct
)

log_msg(
		"marker_logfc   : %.3f",
		marker_logfc
)

log_msg(
		"seed           : %d",
		seed
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
# 8. Clean output directory
#
# output_dir/logs/ -> KEEP
# everything else -> DELETE
#
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
# 9. Helper: Top markers
# ------------------------------------------------------------------------------

get_top_markers <- function(
		markers,
		cluster_levels,
		topn
) {
	
	if (nrow(markers) == 0) {
		return(markers)
	}
	
	
	# Seurat v5: avg_log2FC
	# older Seurat: avg_logFC
	
	fc_candidates <- c(
			"avg_log2FC",
			"avg_logFC"
	)
	
	
	fc_col <- fc_candidates[
			fc_candidates %in% colnames(markers)
	][1]
	
	
	if (is.na(fc_col) || length(fc_col) == 0) {
		
		stop(
				"FindAllMarkers output has no avg_log2FC/avg_logFC column."
		)
	}
	
	
	markers$cluster <- factor(
			as.character(markers$cluster),
			levels = cluster_levels
	)
	
	
	markers <- markers[
			order(
					markers$cluster,
					-markers[[fc_col]]
			),
			,
			drop = FALSE
	]
	
	
	split_markers <- split(
			markers,
			markers$cluster,
			drop = TRUE
	)
	
	
	top_list <- lapply(
			split_markers,
			function(df) {
				
				df <- df[
						order(
								df[[fc_col]],
								decreasing = TRUE
						),
						,
						drop = FALSE
				]
				
				utils::head(
						df,
						topn
				)
			}
	)
	
	
	top_markers <- do.call(
			rbind,
			top_list
	)
	
	
	rownames(top_markers) <- NULL
	
	top_markers$cluster <- as.character(
			top_markers$cluster
	)
	
	
	top_markers
}


# ------------------------------------------------------------------------------
# 10. Helper: cluster-average marker heatmap
#
# We calculate mean SCT expression of Top marker genes for each cluster,
# then convert each gene to a Z-score across clusters.
#
# This avoids expanding the full spatial matrix into a dense matrix.
# ------------------------------------------------------------------------------

make_marker_heatmap <- function(
		obj,
		top_markers,
		slice_name
) {
	
	if (nrow(top_markers) == 0) {
		return(NULL)
	}
	
	
	top_genes <- unique(
			as.character(
					top_markers$gene
			)
	)
	
	
	top_genes <- intersect(
			top_genes,
			rownames(obj[["SCT"]])
	)
	
	
	if (length(top_genes) == 0) {
		return(NULL)
	}
	
	
	expr <- GetAssayData(
			obj,
			assay = "SCT",
			layer = "data"
	)
	
	
	expr <- expr[
			top_genes,
			,
			drop = FALSE
	]
	
	
	cluster_factor <- Idents(obj)
	
	cluster_levels <- levels(
			cluster_factor
	)
	
	
	avg_list <- lapply(
			cluster_levels,
			function(cl) {
				
				cells_use <- names(cluster_factor)[
						cluster_factor == cl
				]
				
				if (length(cells_use) == 1) {
					
					as.numeric(
							expr[
									,
									cells_use,
									drop = FALSE
							]
					)
					
				} else {
					
					Matrix::rowMeans(
							expr[
									,
									cells_use,
									drop = FALSE
							]
					)
				}
			}
	)
	
	
	avg_mat <- do.call(
			cbind,
			avg_list
	)
	
	
	rownames(avg_mat) <- top_genes
	colnames(avg_mat) <- cluster_levels
	
	
	# gene-wise Z score across clusters
	if (ncol(avg_mat) > 1) {
		
		z_mat <- t(
				scale(
						t(avg_mat)
				)
		)
		
	} else {
		
		z_mat <- avg_mat
		z_mat[,] <- 0
	}
	
	
	z_mat[
			!is.finite(z_mat)
	] <- 0
	
	
	heat_df <- as.data.frame(
			as.table(z_mat),
			stringsAsFactors = FALSE
	)
	
	
	colnames(heat_df) <- c(
			"gene",
			"cluster",
			"zscore"
	)
	
	
	gene_order <- unique(
			as.character(
					top_markers$gene
			)
	)
	
	
	gene_order <- gene_order[
			gene_order %in% top_genes
	]
	
	
	heat_df$gene <- factor(
			heat_df$gene,
			levels = rev(gene_order)
	)
	
	
	heat_df$cluster <- factor(
			heat_df$cluster,
			levels = cluster_levels
	)
	
	
	ggplot(
					heat_df,
					aes(
							x = cluster,
							y = gene,
							fill = zscore
					)
			) +
			geom_tile() +
			labs(
					title = sprintf(
							"%s Top cluster markers",
							slice_name
					),
					x = "Cluster",
					y = "Gene",
					fill = "Z-score"
			) +
			theme_bw() +
			theme(
					axis.text.x = element_text(
							angle = 0,
							hjust = 0.5
					),
					panel.grid = element_blank()
			)
}


# ------------------------------------------------------------------------------
# 11. Per-slice analysis
# ------------------------------------------------------------------------------

process_slice <- function(
		slice_name,
		prep_rds
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
	# Load object
	# --------------------------------------------------------------------------
	
	log_msg(
			"  input: %s",
			prep_rds
	)
	
	
	obj <- readRDS(
			prep_rds
	)
	
	
	if (!inherits(obj, "Seurat")) {
		
		stop(
				"input is not a Seurat object"
		)
	}
	
	
	if (!("SCT" %in% Assays(obj))) {
		
		stop(
				"no 'SCT' assay; run spatial_prep first"
		)
	}
	
	
	log_msg(
			"  loaded: %d genes x %d spots",
			nrow(obj),
			ncol(obj)
	)
	
	
	# --------------------------------------------------------------------------
	# Determine usable PCA dimensions
	# --------------------------------------------------------------------------
	
	npcs_use <- min(
			npcs,
			ncol(obj) - 1L,
			nrow(obj) - 1L
	)
	
	
	if (npcs_use < 2) {
		
		stop(
				"too few genes/spots for PCA"
		)
	}
	
	
	if (npcs_use != npcs) {
		
		log_msg(
				"  requested npcs=%d; adjusted to %d",
				npcs,
				npcs_use
		)
	}
	
	
	# --------------------------------------------------------------------------
	# PCA
	# --------------------------------------------------------------------------
	
	log_msg(
			"  RunPCA"
	)
	
	
	obj <- RunPCA(
			obj,
			assay = "SCT",
			npcs = npcs_use,
			verbose = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# Neighbors
	# --------------------------------------------------------------------------
	
	log_msg(
			"  FindNeighbors"
	)
	
	
	obj <- FindNeighbors(
			obj,
			reduction = "pca",
			dims = seq_len(npcs_use),
			verbose = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# Clustering
	# --------------------------------------------------------------------------
	
	log_msg(
			"  FindClusters (resolution=%.3f)",
			resolution
	)
	
	
	obj <- FindClusters(
			obj,
			resolution = resolution,
			verbose = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# UMAP
	# --------------------------------------------------------------------------
	
	log_msg(
			"  RunUMAP"
	)
	
	
	obj <- RunUMAP(
			obj,
			reduction = "pca",
			dims = seq_len(npcs_use),
			seed.use = seed,
			verbose = FALSE
	)
	
	
	cluster_ids <- levels(
			Idents(obj)
	)
	
	
	log_msg(
			"  %d clusters",
			length(cluster_ids)
	)
	
	
	# --------------------------------------------------------------------------
	# Plot 1: UMAP + spatial clusters
	# --------------------------------------------------------------------------
	
	p1 <- DimPlot(
					obj,
					reduction = "umap",
					label = TRUE
			) +
			ggtitle(
					sprintf(
							"%s UMAP",
							slice_name
					)
			)
	
	
	p2 <- SpatialDimPlot(
					obj,
					label = TRUE,
					label.size = 3
			) +
			ggtitle(
					"Spatial clusters"
			)
	
	
	ggsave(
			file.path(
					plot_dir,
					sprintf(
							"%s_clusters_umap_spatial.png",
							slice_name
					)
			),
			plot = p1 + p2,
			width = 12,
			height = 6,
			dpi = 300,
			limitsize = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# Plot 2: Per-cluster spatial highlight
	# --------------------------------------------------------------------------
	
	if (length(cluster_ids) > 0) {
		
		nc <- min(
				3,
				length(cluster_ids)
		)
		
		
		p_h <- SpatialDimPlot(
						obj,
						cells.highlight = CellsByIdentities(
								object = obj,
								idents = cluster_ids
						),
						facet.highlight = TRUE,
						ncol = nc
				) &
				theme(
						plot.margin = grid::unit(
								c(1, 1, 1, 1),
								"mm"
						)
				)
		
		
		ggsave(
				file.path(
						plot_dir,
						sprintf(
								"%s_clusters_spatial_highlight.png",
								slice_name
						)
				),
				plot = p_h,
				width = 5 * nc,
				height = 5 * ceiling(
						length(cluster_ids) / nc
				),
				dpi = 300,
				limitsize = FALSE
		)
	}
	
	
	# --------------------------------------------------------------------------
	# Cluster summary
	# --------------------------------------------------------------------------
	
	cs <- as.data.frame(
			table(
					Idents(obj)
			)
	)
	
	
	colnames(cs) <- c(
			"cluster",
			"n_spots"
	)
	
	
	write.csv(
			cs,
			file.path(
					slice_out,
					sprintf(
							"%s_cluster_summary.csv",
							slice_name
					)
			),
			row.names = FALSE
	)
	
	
	# --------------------------------------------------------------------------
	# Cluster marker analysis
	# --------------------------------------------------------------------------
	
	log_msg(
			"  Marker analysis"
	)
	
	
	marker_csv <- file.path(
			slice_out,
			sprintf(
					"%s_cluster_markers.csv",
					slice_name
			)
	)
	
	
	top_marker_csv <- file.path(
			slice_out,
			sprintf(
					"%s_cluster_top_markers.csv",
					slice_name
			)
	)
	
	
	# Marker analysis requires at least two clusters
	if (length(cluster_ids) < 2) {
		
		log_msg(
				"  WARNING: only one cluster; marker analysis skipped"
		)
		
		
		write.csv(
				data.frame(),
				marker_csv,
				row.names = FALSE
		)
		
		
		write.csv(
				data.frame(),
				top_marker_csv,
				row.names = FALSE
		)
		
	} else {
		
		marker_result <- tryCatch({
					
					DefaultAssay(obj) <- "SCT"
					
					
					# --------------------------------------------------------------
					# If SCT contains multiple models, prepare them for marker tests.
					#
					# Normally each slice has only one model, so this is usually
					# skipped. It is included defensively for imported/merged objects.
					# --------------------------------------------------------------
					
					n_sct_models <- tryCatch(
							length(
									obj[["SCT"]]@SCTModel.list
							),
							error = function(e) {
								0L
							}
					)
					
					
					if (n_sct_models > 1L) {
						
						log_msg(
								"  SCT assay has %d models; running PrepSCTFindMarkers",
								n_sct_models
						)
						
						
						obj <- PrepSCTFindMarkers(
								obj,
								assay = "SCT",
								verbose = FALSE
						)
					}
					
					
					# --------------------------------------------------------------
					# Find markers
					# --------------------------------------------------------------
					
					log_msg(
							"  FindAllMarkers (min.pct=%.3f, logfc=%.3f)",
							marker_min_pct,
							marker_logfc
					)
					
					
					markers <- FindAllMarkers(
							obj,
							assay = "SCT",
							only.pos = TRUE,
							min.pct = marker_min_pct,
							logfc.threshold = marker_logfc,
							verbose = FALSE
					)
					
					
					if (nrow(markers) == 0) {
						
						log_msg(
								"  WARNING: FindAllMarkers returned no markers"
						)
						
						
						write.csv(
								markers,
								marker_csv,
								row.names = FALSE
						)
						
						
						write.csv(
								markers,
								top_marker_csv,
								row.names = FALSE
						)
						
						
						return(
								invisible(TRUE)
						)
					}
					
					
					# --------------------------------------------------------------
					# Sort markers
					# --------------------------------------------------------------
					
					fc_candidates <- c(
							"avg_log2FC",
							"avg_logFC"
					)
					
					
					fc_col <- fc_candidates[
							fc_candidates %in% colnames(markers)
					][1]
					
					
					if (
							length(fc_col) == 0 ||
							is.na(fc_col)
							) {
						
						stop(
								"marker table has no avg_log2FC/avg_logFC column"
						)
					}
					
					
					markers$cluster <- factor(
							as.character(markers$cluster),
							levels = cluster_ids
					)
					
					
					markers <- markers[
							order(
									markers$cluster,
									-markers[[fc_col]]
							),
							,
							drop = FALSE
					]
					
					
					markers$cluster <- as.character(
							markers$cluster
					)
					
					
					write.csv(
							markers,
							marker_csv,
							row.names = FALSE
					)
					
					
					log_msg(
							"  markers: %d genes/results",
							nrow(markers)
					)
					
					
					# --------------------------------------------------------------
					# Top N markers per cluster
					# --------------------------------------------------------------
					
					top_markers <- get_top_markers(
							markers = markers,
							cluster_levels = cluster_ids,
							topn = marker_topn
					)
					
					
					write.csv(
							top_markers,
							top_marker_csv,
							row.names = FALSE
					)
					
					
					log_msg(
							"  top markers: %d rows (%d per cluster max)",
							nrow(top_markers),
							marker_topn
					)
					
					
					if (nrow(top_markers) == 0) {
						
						return(
								invisible(TRUE)
						)
					}
					
					
					top_genes <- unique(
							as.character(
									top_markers$gene
							)
					)
					
					
					top_genes <- intersect(
							top_genes,
							rownames(obj[["SCT"]])
					)
					
					
					if (length(top_genes) == 0) {
						
						log_msg(
								"  WARNING: no Top marker genes found in SCT assay"
						)
						
						return(
								invisible(TRUE)
						)
					}
					
					
					# --------------------------------------------------------------
					# Marker heatmap
					# --------------------------------------------------------------
					
					p_heat <- make_marker_heatmap(
							obj = obj,
							top_markers = top_markers,
							slice_name = slice_name
					)
					
					
					if (!is.null(p_heat)) {
						
						heat_width <- max(
								7,
								1.0 * length(cluster_ids) + 3
						)
						
						
						heat_height <- max(
								6,
								0.28 * length(top_genes) + 2
						)
						
						
						ggsave(
								file.path(
										plot_dir,
										sprintf(
												"%s_marker_heatmap.png",
												slice_name
										)
								),
								plot = p_heat,
								width = heat_width,
								height = heat_height,
								dpi = 300,
								limitsize = FALSE
						)
						
						
						log_msg(
								"  marker heatmap written"
						)
					}
					
					
					# --------------------------------------------------------------
					# Marker DotPlot
					# --------------------------------------------------------------
					
					p_dot <- DotPlot(
									obj,
									features = top_genes,
									assay = "SCT"
							) +
							RotatedAxis() +
							ggtitle(
									sprintf(
											"%s Top cluster markers",
											slice_name
									)
							) +
							xlab(
									"Marker gene"
							) +
							ylab(
									"Cluster"
							)
					
					
					dot_width <- max(
							10,
							0.38 * length(top_genes) + 5
					)
					
					
					dot_height <- max(
							5,
							0.45 * length(cluster_ids) + 3
					)
					
					
					ggsave(
							file.path(
									plot_dir,
									sprintf(
											"%s_marker_dotplot.png",
											slice_name
									)
							),
							plot = p_dot,
							width = dot_width,
							height = dot_height,
							dpi = 300,
							limitsize = FALSE
					)
					
					
					log_msg(
							"  marker DotPlot written"
					)
					
					
					invisible(TRUE)
					
				}, error = function(e) {
					
					# Marker failure should not discard successful clustering.
					log_msg(
							"  WARNING: marker analysis failed: %s",
							conditionMessage(e)
					)
					
					
					if (!file.exists(marker_csv)) {
						
						write.csv(
								data.frame(),
								marker_csv,
								row.names = FALSE
						)
					}
					
					
					if (!file.exists(top_marker_csv)) {
						
						write.csv(
								data.frame(),
								top_marker_csv,
								row.names = FALSE
						)
					}
					
					
					invisible(FALSE)
				})
	}
	
	
	# --------------------------------------------------------------------------
	# Save clustered Seurat object
	# --------------------------------------------------------------------------
	
	out_rds <- file.path(
			slice_out,
			sprintf(
					"%s_clustered.rds",
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
# 12. Run all slices
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
# 13. Batch summary
# ------------------------------------------------------------------------------

log_msg(
		"===== Cluster batch summary ====="
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
