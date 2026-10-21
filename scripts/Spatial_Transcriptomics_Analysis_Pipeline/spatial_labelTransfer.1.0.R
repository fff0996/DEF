#!/usr/bin/env Rscript

# ==============================================================================
# spatial_labeltransfer.r   [Module 4/6 - BATCH multi-slice, OPTIONAL]
#
# BiO-EXPRESS spatial transcriptomics pipeline (10x Visium)
# Vignette: "Integration with single-cell data"
#
# Anchor-based label transfer from an scRNA-seq reference onto EACH slice.
# The reference is prepared ONCE (the heavy step) and reused across all
# slices, then anchors are found per slice.
#
# The reference is classified into one of two modes:
#
#   RECOMPUTE - the object still carries raw counts, so SCT + PCA are built
#               here from scratch.
#   FROZEN    - the object has no counts (Azimuth-style refAssay + refDR, or
#               any stripped reference). The baked-in assay and reduction are
#               used as-is; nothing can be recomputed.
#
# Input layout (output of spatial_cluster.r):
#   input_dir/
#     control/control_clustered.rds
#     treated/treated_clustered.rds
#
# Output layout:
#   output_dir/
#     control/
#       control_labeltransfer.rds
#       control_predicted_celltype_scores.csv
#       plots/control_predicted_<celltype>.png   (one per cell type)
#     treated/ ...
#
#     summary/
#       labeltransfer_celltype_by_slice.csv
#       labeltransfer_celltype_by_slice_long.csv
#       plots/
#         labeltransfer_celltype_by_slice_heatmap.png
#
# Bio-Express argument format:
#   input_dir=/path/to/cluster_output
#   reference_rds=/path/to/reference.rds
#   reference_label_col=celltype_major
#   output_dir=/path/to/output
#   reference_ncells=3000
#   npcs=30
#   min_shared_features=200
#   seed=1234
# ==============================================================================


args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
	message("[FATAL] No arguments provided.")
	message("[USAGE] Rscript spatial_labeltransfer.r input_dir=... reference_rds=... reference_label_col=... output_dir=...")
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


input_dir           <- params$input_dir
reference_rds       <- params$reference_rds
reference_label_col <- params$reference_label_col

output_dir <- if (!is.null(params$output_dir) && nzchar(params$output_dir)) {
			params$output_dir
		} else {
			"./bx_spatial_out"
		}

reference_ncells <- if (!is.null(params$reference_ncells) && nzchar(params$reference_ncells)) {
			suppressWarnings(as.integer(params$reference_ncells))
		} else {
			3000L
		}

npcs <- if (!is.null(params$npcs) && nzchar(params$npcs)) {
			suppressWarnings(as.integer(params$npcs))
		} else {
			30L
		}

min_shared_features <- if (!is.null(params$min_shared_features) && nzchar(params$min_shared_features)) {
			suppressWarnings(as.integer(params$min_shared_features))
		} else {
			200L
		}

seed <- if (!is.null(params$seed) && nzchar(params$seed)) {
			suppressWarnings(as.integer(params$seed))
		} else {
			1234L
		}


if (is.null(input_dir) || !nzchar(input_dir)) {
	message("[FATAL] input_dir is required.")
	quit(status = 1)
}
if (!dir.exists(input_dir)) {
	message(sprintf("[FATAL] input_dir not found: %s", input_dir))
	quit(status = 1)
}
if (is.null(reference_rds) || !nzchar(reference_rds)) {
	message("[FATAL] reference_rds is required.")
	quit(status = 1)
}
if (!file.exists(reference_rds)) {
	message(sprintf("[FATAL] reference_rds not found: %s", reference_rds))
	quit(status = 1)
}
if (is.null(reference_label_col) || !nzchar(reference_label_col)) {
	message("[FATAL] reference_label_col is required.")
	message("[FATAL] Run check_reference first to see available columns.")
	quit(status = 1)
}
if (is.na(reference_ncells) || reference_ncells < 1) {
	message("[FATAL] reference_ncells must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(npcs) || npcs < 2) {
	message("[FATAL] npcs must be an integer >= 2.")
	quit(status = 1)
}
if (is.na(min_shared_features) || min_shared_features < 1) {
	message("[FATAL] min_shared_features must be an integer >= 1.")
	quit(status = 1)
}
if (is.na(seed)) {
	message("[FATAL] seed must be an integer.")
	quit(status = 1)
}


log_msg <- function(...) {
	cat(sprintf("[%s] %s\n", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), sprintf(...)))
}


required_pkgs <- c("Seurat", "ggplot2", "patchwork")
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

options(future.globals.maxSize = 8 * 1024^3)
set.seed(seed)


safe_name <- function(x) {
	x <- gsub("[^A-Za-z0-9]+", "_", x)
	x <- gsub("^_+|_+$", "", x)
	x
}


# ------------------------------------------------------------------------------
# Assay inspection helpers
#
# An assay is judged by whether it actually HOLDS counts, not by its name.
# Name matching alone misses 'originalexp' (converted AnnData), v5 multi-layer
# objects, and other non-standard layouts.
# ------------------------------------------------------------------------------

count_layers_of <- function(assay_obj) {
	
	lyr <- tryCatch(SeuratObject::Layers(assay_obj), error = function(e) character(0))
	lyr <- lyr[grepl("^counts", lyr)]
	
	if (length(lyr) == 0) return(character(0))
	
	populated <- vapply(lyr, function(l) {
				d <- tryCatch(dim(SeuratObject::LayerData(assay_obj, layer = l)),
						error = function(e) NULL)
				!is.null(d) && length(d) == 2L && all(d > 0)
			}, logical(1))
	
	lyr[populated]
}


has_sct_model <- function(assay_obj) {
	tryCatch(length(slot(assay_obj, "SCTModel.list")) > 0, error = function(e) FALSE)
}


# ------------------------------------------------------------------------------
# strip_foreign_s4
#
# Azimuth references carry an AzimuthData S4 object in @tools / @misc. Any
# operation that copies or revalidates the object makes R resolve that class,
# and methods:::.requirePackage() then aborts with
#   "unable to find required package 'Azimuth'"
# on containers where Azimuth is not installed.
#
# None of that payload is needed for anchor transfer, so elements whose
# defining package is unavailable are dropped. Everything Seurat actually
# uses (SCTModel.list, loadings, embeddings) lives in other slots and is
# left untouched.
# ------------------------------------------------------------------------------

drop_unavailable <- function(lst, where) {
	
	if (!is.list(lst) || length(lst) == 0) return(lst)
	
	keep <- vapply(seq_along(lst), function(i) {
				
				pkg <- attr(class(lst[[i]]), "package")
				
				if (is.null(pkg) || pkg %in% c(".GlobalEnv", "base", "methods")) return(TRUE)
				
				ok <- requireNamespace(pkg, quietly = TRUE)
				
				if (!ok) {
					nm <- if (!is.null(names(lst))) names(lst)[i] else sprintf("[[%d]]", i)
					log_msg("  dropped %s$%s (class '%s' from uninstalled package '%s')",
							where, nm, class(lst[[i]])[1], pkg)
				}
				
				ok
			}, logical(1))
	
	lst[keep]
}


strip_foreign_s4 <- function(obj) {
	
	slot(obj, "tools") <- drop_unavailable(slot(obj, "tools"), "@tools")
	slot(obj, "misc")  <- drop_unavailable(slot(obj, "misc"),  "@misc")
	
	for (a in Assays(obj)) {
		m <- tryCatch(slot(obj[[a]], "misc"), error = function(e) NULL)
		if (is.list(m) && length(m) > 0) {
			slot(obj[[a]], "misc") <- drop_unavailable(m, sprintf("assay '%s' @misc", a))
		}
	}
	
	for (r in Reductions(obj)) {
		m <- tryCatch(slot(obj[[r]], "misc"), error = function(e) NULL)
		if (is.list(m) && length(m) > 0) {
			slot(obj[[r]], "misc") <- drop_unavailable(m, sprintf("reduction '%s' @misc", r))
		}
	}
	
	obj
}


gene_id_style <- function(genes) {
	
	g <- utils::head(as.character(genes), 1000L)
	g <- g[nzchar(g)]
	if (length(g) == 0) return("unknown")
	
	if (mean(grepl("^ENS[A-Z]*[0-9]{6,}", g)) > 0.5) return("Ensembl ID")
	if (mean(grepl("^[0-9]+$", g)) > 0.5)             return("Entrez ID")
	
	alpha <- g[grepl("[A-Za-z]", g)]
	if (length(alpha) == 0) return("unknown")
	
	frac_upper <- mean(alpha == toupper(alpha))
	if (frac_upper > 0.80) return("gene symbol, uppercase (human-like)")
	if (frac_upper < 0.30) return("gene symbol, title-case (mouse-like)")
	"gene symbol (mixed case)"
}


# ------------------------------------------------------------------------------
# Discover slices: each subdir with a *_clustered.rds
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
	if (length(rds) == 1) {
		slice_name <- sub("_clustered\\.rds$", "", basename(rds[1]))
		slice_table[[slice_name]] <- rds[1]
	}
}

if (length(slice_table) == 0) {
	message(sprintf("[FATAL] No *_clustered.rds found under input_dir: %s", input_dir))
	quit(status = 1)
}


log_msg("===== Spatial Label Transfer (batch) =====")
log_msg("input_dir           : %s", input_dir)
log_msg("reference_rds       : %s", reference_rds)
log_msg("reference_label_col : %s", reference_label_col)
log_msg("output_dir          : %s", output_dir)
log_msg("Discovered %d slice(s): %s",
		length(slice_table),
		paste(names(slice_table), collapse = ", "))

# ------------------------------------------------------------------------------
# Clean previous outputs
# Keep only output_dir/logs
# ------------------------------------------------------------------------------

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

log_msg("Cleaning previous outputs under: %s", output_dir)

old_outputs <- list.files(
		output_dir,
		full.names = TRUE,
		all.files = TRUE,
		no.. = TRUE
)

# Preserve pipeline log directory
old_outputs <- old_outputs[basename(old_outputs) != "logs"]

if (length(old_outputs) > 0) {
	unlink(old_outputs, recursive = TRUE, force = TRUE)
}

log_msg("Previous outputs cleaned (logs preserved).")

# ------------------------------------------------------------------------------
# Load reference and decide how to treat it (once)
# ------------------------------------------------------------------------------

log_msg("Loading reference ...")

ref <- readRDS(reference_rds)

if (!inherits(ref, "Seurat")) {
	message(sprintf("[FATAL] reference_rds is not a Seurat object (class: %s).",
					paste(class(ref), collapse = "/")))
	message("        SingleCellExperiment -> ref <- Seurat::as.Seurat(sce, counts = 'counts', data = NULL)")
	message("        AnnData / .h5ad      -> convert via sceasy or zellkonverter, then saveRDS()")
	quit(status = 1)
}

obj_version <- tryCatch(package_version(as.character(ref@version)), error = function(e) NULL)
if (!is.null(obj_version) && obj_version < package_version("5.0.0")) {
	log_msg("Reference was built with Seurat %s; running UpdateSeuratObject().", as.character(obj_version))
	ref <- UpdateSeuratObject(ref)
}

ref <- strip_foreign_s4(ref)

ref_assays <- Assays(ref)


# -- label column is validated BEFORE any expensive work -----------------------

ref_cols <- colnames(ref@meta.data)
if (!(reference_label_col %in% ref_cols)) {
	message(sprintf("[FATAL] reference_label_col '%s' not found in reference.", reference_label_col))
	message(sprintf("        Available columns: %s", paste(ref_cols, collapse = ", ")))
	quit(status = 1)
}

ref_labels   <- ref[[reference_label_col, drop = TRUE]]
label_counts <- table(as.character(ref_labels))
label_levels <- names(sort(label_counts, decreasing = TRUE))

log_msg("Reference: %d features x %d cells | gene ID style: %s",
		nrow(ref), ncol(ref), gene_id_style(rownames(ref)))
log_msg("Label column '%s': %d categories", reference_label_col, length(label_levels))

for (lv in label_levels) {
	log_msg("  %-30s %d cell(s)", lv, as.integer(label_counts[[lv]]))
}

if (min(label_counts) < 10L) {
	log_msg("WARNING: smallest label group has %d cell(s); those predictions will be unreliable.",
			as.integer(min(label_counts)))
}


# -- find an assay that still carries raw counts -------------------------------

assay_search <- unique(c("RNA", "originalexp", "spliced", ref_assays))
assay_search <- assay_search[assay_search %in% ref_assays]

ref_counts_assay  <- NULL
ref_counts_layers <- character(0)

for (a in assay_search) {
	cl <- count_layers_of(ref[[a]])
	if (length(cl) > 0) {
		ref_counts_assay  <- a
		ref_counts_layers <- cl
		break
	}
}


# -- pick a usable reduction, by preference ------------------------------------

ref_reduction <- NULL
for (r in c("refDR", "spca", "pca", "harmony", "integrated_dr", "mnn")) {
	if (r %in% Reductions(ref)) {
		ref_reduction <- r
		break
	}
}


log_msg("Assays     : %s", paste(ref_assays, collapse = ", "))
log_msg("Reductions : %s",
		if (length(Reductions(ref))) paste(Reductions(ref), collapse = ", ") else "none")
log_msg("Counts     : %s",
		if (is.null(ref_counts_assay)) "NONE FOUND"
				else sprintf("'%s' in assay '%s'", paste(ref_counts_layers, collapse = "', '"), ref_counts_assay))


# ------------------------------------------------------------------------------
# Prepare the reference: RECOMPUTE or FROZEN
# ------------------------------------------------------------------------------

if (!is.null(ref_counts_assay)) {
	
	# ---------------------------- RECOMPUTE ------------------------------------
	
	ref_mode <- "recompute"
	
	if (length(ref_counts_layers) > 1) {
		log_msg("Multi-layer counts detected; running JoinLayers() on '%s'.", ref_counts_assay)
		ref[[ref_counts_assay]] <- JoinLayers(ref[[ref_counts_assay]])
	}
	
	if ("SCT" %in% ref_assays && has_sct_model(ref[["SCT"]])) {
		
		log_msg("Existing SCT assay with a fitted model found; reusing it.")
		
	} else {
		
		log_msg("Running SCTransform on assay '%s' (ncells = %d) ...", ref_counts_assay, reference_ncells)
		
		ref <- SCTransform(
				ref,
				assay   = ref_counts_assay,
				ncells  = reference_ncells,
				verbose = FALSE
		)
	}
	
	DefaultAssay(ref) <- "SCT"
	
	if (!("pca" %in% Reductions(ref))) {
		log_msg("Running PCA on the SCT assay (npcs = %d) ...", npcs)
		ref <- RunPCA(ref, assay = "SCT", npcs = npcs, verbose = FALSE)
	}
	
	ref_assay_use     <- "SCT"
	ref_reduction_use <- NULL
	ref_max_dims      <- ncol(Embeddings(ref[["pca"]]))
	ref_can_recompute <- has_sct_model(ref[["SCT"]])
	
} else {
	
	# ------------------------------ FROZEN -------------------------------------
	
	ref_mode <- "frozen"
	
	if (is.null(ref_reduction)) {
		message("[FATAL] Reference has NO counts layer and NO dimensional reduction.")
		message(sprintf("        assays     : %s", paste(ref_assays, collapse = ", ")))
		message("        reductions : (none)")
		message("        Anchor-based transfer needs one or the other. Supply a reference that")
		message("        retains raw counts, or an Azimuth-style object carrying refDR.")
		quit(status = 1)
	}
	
	ref_assay_use <- if ("refAssay" %in% ref_assays) {
				"refAssay"
			} else if (DefaultAssay(ref) %in% ref_assays) {
				DefaultAssay(ref)
			} else {
				ref_assays[1]
			}
	
	ref_reduction_use <- ref_reduction
	ref_max_dims      <- ncol(Embeddings(ref[[ref_reduction_use]]))
	ref_can_recompute <- has_sct_model(ref[[ref_assay_use]])
	
	# Azimuth-built SCT models pull in S4 classes stamped as belonging to the
	# Azimuth package. Unpacking such a model without Azimuth installed aborts
	# with "unable to find required package 'Azimuth'", so the reference-model
	# path is disabled up front rather than attempted and rolled back once per
	# slice. Anchoring still works through refDR; only the residual space is
	# the query's own.
	if (ref_can_recompute &&
			identical(ref_assay_use, "refAssay") &&
			!requireNamespace("Azimuth", quietly = TRUE)) {
		log_msg("Azimuth-style SCT model found but the Azimuth package is not installed;")
		log_msg("  reference-model normalization disabled - the query's own SCT assay will be used.")
		ref_can_recompute <- FALSE
	}
	
	DefaultAssay(ref) <- ref_assay_use
	
	log_msg("Frozen reference: assay = '%s', reduction = '%s' (%d dims), SCT model = %s.",
			ref_assay_use, ref_reduction_use, ref_max_dims,
			if (ref_can_recompute) "present" else "absent")
}


if (npcs > ref_max_dims) {
	log_msg("Requested npcs (%d) exceeds available dims (%d); clamping to %d.",
			npcs, ref_max_dims, ref_max_dims)
	npcs <- ref_max_dims
}

log_msg("Reference ready | mode = %s | assay = '%s' | reduction = %s | dims = %d",
		toupper(ref_mode), ref_assay_use,
		if (is.null(ref_reduction_use)) "(query-projected)" else sprintf("'%s'", ref_reduction_use),
		npcs)


# ------------------------------------------------------------------------------
# Per-slice processing
# ------------------------------------------------------------------------------

process_slice <- function(slice_name, clustered_rds) {
	
	log_msg("---- slice '%s' ----", slice_name)
	
	slice_out <- file.path(output_dir, slice_name)
	dir.create(slice_out, recursive = TRUE, showWarnings = FALSE)
	
	plot_dir <- file.path(slice_out, "plots")
	dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
	
	plot_dir <- file.path(slice_out, "plots")
	dir.create(plot_dir, recursive = TRUE, showWarnings = FALSE)
	
	query <- readRDS(clustered_rds)
	if (!inherits(query, "Seurat")) stop("input is not a Seurat object")
	if (!("SCT" %in% Assays(query))) stop("no 'SCT' assay - run spatial_cluster.r first")
	if (!("pca" %in% Reductions(query))) stop("no 'pca' reduction - run spatial_cluster.r first")
	
	
	# -- choose the query assay ------------------------------------------------
	#
	# When the reference carries its own SCT model, the query is re-normalized
	# against that model (recompute.residuals). Both datasets then live in the
	# same residual space, which maps noticeably better than pairing two
	# independently fitted SCT models. That path needs raw counts, hence the
	# Spatial assay. Without a reference model, fall back to the query's SCT.
	
	query_counts_assay <- NULL
	for (a in unique(c("Spatial", "RNA", Assays(query)))) {
		if (a %in% Assays(query) && length(count_layers_of(query[[a]])) > 0) {
			query_counts_assay <- a
			break
		}
	}
	
	# -- anchor features are ALWAYS explicit -----------------------------------
	#
	# FindTransferAnchors() otherwise defaults to
	# VariableFeatures(reference[[assay]]), which is empty on Azimuth-style
	# references and produces the opaque "No features to use in finding
	# transfer anchors" error. Never rely on that default.
	
	find_anchors <- function(query_assay, use_recompute) {
		
		log_msg("  query assay '%s' | recompute.residuals = %s", query_assay, use_recompute)
		
		ref_features    <- rownames(ref[[ref_assay_use]])
		query_features  <- rownames(query[[query_assay]])
		anchor_features <- intersect(ref_features, query_features)
		
		if (length(anchor_features) < min_shared_features) {
			stop(sprintf(
							paste0(
									"only %d shared feature(s) between reference and query (need >= %d).\n",
									"       reference : %s | %s\n",
									"       query     : %s | %s\n",
									"       This is almost always a species mismatch or a gene-ID convention\n",
									"       mismatch (Ensembl ID vs symbol, human uppercase vs mouse title-case)."
							),
							length(anchor_features), min_shared_features,
							gene_id_style(ref_features),
							paste(utils::head(ref_features, 4), collapse = ", "),
							gene_id_style(query_features),
							paste(utils::head(query_features, 4), collapse = ", ")
					))
		}
		
		log_msg("  %d shared feature(s) available for anchoring", length(anchor_features))
		
		ft_args <- list(
				reference            = ref,
				query                = query,
				normalization.method = "SCT",
				reference.assay      = ref_assay_use,
				query.assay          = query_assay,
				recompute.residuals  = use_recompute,
				features             = anchor_features,
				dims                 = seq_len(npcs),
				verbose              = FALSE
		)
		
		if (identical(ref_mode, "frozen")) {
			# A frozen reference has no expression data to score candidate anchors
			# against, so anchor filtering has to be switched off; leaving the
			# default (k.filter = 200) errors out right after anchors are found.
			ft_args$reference.reduction <- ref_reduction_use
			ft_args$k.filter            <- NA
		}
		
		do.call(FindTransferAnchors, ft_args)
	}
	
	
	use_recompute <- isTRUE(ref_can_recompute) && !is.null(query_counts_assay)
	query_assay   <- if (use_recompute) query_counts_assay else "SCT"
	
	anchors <- tryCatch(
			find_anchors(query_assay, use_recompute),
			error = function(e) {
				
				msg <- conditionMessage(e)
				
				# Some packaged references reach into helper packages that are not
				# part of this container (Azimuth being the common one). Those code
				# paths are only entered when residuals are recomputed against the
				# reference model, so retry once on the query's own SCT assay.
				retryable <- use_recompute &&
						grepl("unable to find required package|Azimuth", msg, ignore.case = TRUE)
				
				if (!retryable) stop(e)
				
				log_msg("  reference-model normalization unavailable (%s)", msg)
				log_msg("  retrying with the query's own SCT assay (recompute.residuals = FALSE)")
				
				find_anchors("SCT", FALSE)
			}
	)
	
	n_anchors <- nrow(slot(anchors, "anchors"))
	log_msg("  found %d anchors", n_anchors)
	
	if (n_anchors < 30L) {
		log_msg("  WARNING: very few anchors (%d); predictions may be unstable.", n_anchors)
	}
	
	
	# -- transfer ---------------------------------------------------------------
	
	transfer_dims <- seq_len(min(npcs, ncol(Embeddings(query[["pca"]]))))
	
	predictions.assay <- TransferData(
			anchorset        = anchors,
			refdata          = ref_labels,
			prediction.assay = TRUE,
			weight.reduction = query[["pca"]],
			dims             = transfer_dims,
			verbose          = FALSE
	)
	
	query[["predictions"]] <- predictions.assay
	DefaultAssay(query) <- "predictions"
	
	pred_features <- rownames(query[["predictions"]])
	celltype_features <- setdiff(pred_features, "max")
	log_msg("  %d cell-type feature(s)", length(celltype_features))
	
	
	# -- per-cell-type spatial score map ---------------------------------------
	
	n_ok <- 0L
	for (ct in celltype_features) {
		plotted <- tryCatch({
					p <- SpatialFeaturePlot(query, features = ct, crop = TRUE) +
							ggtitle(ct) &
							theme(plot.margin = grid::unit(c(1, 1, 1, 1), "mm"))
					ggsave(file.path(plot_dir, sprintf("%s_predicted_%s.png", slice_name, safe_name(ct))),
							plot = p, width = 6, height = 6, dpi = 300, limitsize = FALSE)
					TRUE
				}, error = function(e) {
					log_msg("  WARNING: could not plot '%s': %s", ct, conditionMessage(e))
					FALSE
				})
		if (isTRUE(plotted)) n_ok <- n_ok + 1L
	}
	log_msg("  wrote %d / %d cell-type maps", n_ok, length(celltype_features))
	
	
	# -- mean prediction score per cell type ------------------------------------
	
	score_mat <- GetAssayData(query[["predictions"]], layer = "data")
	score_mat <- score_mat[celltype_features, , drop = FALSE]
	mean_scores <- rowMeans(score_mat)
	score_df <- data.frame(celltype = names(mean_scores),
			mean_prediction_score = as.numeric(mean_scores),
			stringsAsFactors = FALSE)
	score_df <- score_df[order(-score_df$mean_prediction_score), ]
	write.csv(score_df,
			file.path(slice_out, sprintf("%s_predicted_celltype_scores.csv", slice_name)),
			row.names = FALSE)
	
	out_rds <- file.path(slice_out, sprintf("%s_labeltransfer.rds", slice_name))
	saveRDS(query, out_rds)
	log_msg("  DONE -> %s", out_rds)
	
	invisible(TRUE)
}


ok_slices   <- character(0)
fail_slices <- character(0)

for (slice_name in names(slice_table)) {
	res <- tryCatch({
				process_slice(slice_name, slice_table[[slice_name]])
				TRUE
			}, error = function(e) {
				log_msg("  [ERROR] slice '%s' failed: %s", slice_name, conditionMessage(e))
				FALSE
			})
	if (isTRUE(res)) ok_slices <- c(ok_slices, slice_name)
	else fail_slices <- c(fail_slices, slice_name)
}


# ------------------------------------------------------------------------------
# Multi-slice summary
#
# This section does NOT rerun label transfer.
# It only collects the per-slice mean prediction scores already written above.
#
# NOTE:
#   These are mean Seurat label-transfer prediction scores, NOT estimated
#   cell-type proportions. Use RCTD/cell2location when true spot composition
#   estimates are required.
# ------------------------------------------------------------------------------

summary_dir <- file.path(output_dir, "summary")
summary_plot_dir <- file.path(summary_dir, "plots")

dir.create(
		summary_dir,
		recursive = TRUE,
		showWarnings = FALSE
)

dir.create(
		summary_plot_dir,
		recursive = TRUE,
		showWarnings = FALSE
)


if (length(ok_slices) > 0) {
	
	log_msg("Building cell-type x slice label-transfer summary ...")
	
	score_tables <- list()
	
	for (slice_name in ok_slices) {
		
		score_file <- file.path(
				output_dir,
				slice_name,
				sprintf(
						"%s_predicted_celltype_scores.csv",
						slice_name
				)
		)
		
		if (!file.exists(score_file)) {
			log_msg(
					"  WARNING: summary input missing for slice '%s': %s",
					slice_name,
					score_file
			)
			next
		}
		
		score_df <- tryCatch(
				read.csv(
						score_file,
						stringsAsFactors = FALSE,
						check.names = FALSE
				),
				error = function(e) {
					log_msg(
							"  WARNING: could not read summary input for '%s': %s",
							slice_name,
							conditionMessage(e)
					)
					NULL
				}
		)
		
		if (is.null(score_df)) {
			next
		}
		
		required_cols <- c(
				"celltype",
				"mean_prediction_score"
		)
		
		if (!all(required_cols %in% colnames(score_df))) {
			log_msg(
					"  WARNING: summary input for '%s' is missing required column(s): %s",
					slice_name,
					paste(
							setdiff(
									required_cols,
									colnames(score_df)
							),
							collapse = ", "
					)
			)
			next
		}
		
		score_df <- score_df[
				,
				required_cols,
				drop = FALSE
		]
		
		score_df$celltype <- as.character(
				score_df$celltype
		)
		
		score_df$mean_prediction_score <- suppressWarnings(
				as.numeric(
						score_df$mean_prediction_score
				)
		)
		
		score_df$slice <- slice_name
		
		score_df <- score_df[
				!is.na(score_df$mean_prediction_score) &
						nzchar(score_df$celltype),
				,
				drop = FALSE
		]
		
		if (nrow(score_df) == 0) {
			log_msg(
					"  WARNING: no usable prediction scores for slice '%s'",
					slice_name
			)
			next
		}
		
		score_tables[[slice_name]] <- score_df
	}
	
	
	if (length(score_tables) > 0) {
		
		summary_long <- do.call(
				rbind,
				score_tables
		)
		
		rownames(summary_long) <- NULL
		
		
		# ----------------------------------------------------------------------
		# Stable ordering:
		#   cell types -> descending mean score across available slices
		#   slices     -> original batch discovery/success order
		# ----------------------------------------------------------------------
		
		celltype_mean <- tapply(
				summary_long$mean_prediction_score,
				summary_long$celltype,
				mean,
				na.rm = TRUE
		)
		
		celltype_order <- names(
				sort(
						celltype_mean,
						decreasing = TRUE
				)
		)
		
		slice_order <- ok_slices[
				ok_slices %in% unique(
						summary_long$slice
				)
		]
		
		
		# ----------------------------------------------------------------------
		# Long-format summary CSV
		# ----------------------------------------------------------------------
		
		summary_long <- summary_long[
				order(
						match(
								summary_long$celltype,
								celltype_order
						),
						match(
								summary_long$slice,
								slice_order
						)
				),
				,
				drop = FALSE
		]
		
		long_csv <- file.path(
				summary_dir,
				"labeltransfer_celltype_by_slice_long.csv"
		)
		
		write.csv(
				summary_long,
				long_csv,
				row.names = FALSE
		)
		
		
		# ----------------------------------------------------------------------
		# Wide-format summary CSV
		# rows    = cell types
		# columns = slices
		# values  = mean prediction score
		# ----------------------------------------------------------------------
		
		score_matrix <- matrix(
				NA_real_,
				nrow = length(celltype_order),
				ncol = length(slice_order),
				dimnames = list(
						celltype_order,
						slice_order
				)
		)
		
		for (i in seq_len(nrow(summary_long))) {
			
			ct <- summary_long$celltype[i]
			sl <- summary_long$slice[i]
			
			score_matrix[
					ct,
					sl
			] <- summary_long$mean_prediction_score[i]
		}
		
		summary_wide <- data.frame(
				celltype = rownames(score_matrix),
				score_matrix,
				row.names = NULL,
				check.names = FALSE,
				stringsAsFactors = FALSE
		)
		
		wide_csv <- file.path(
				summary_dir,
				"labeltransfer_celltype_by_slice.csv"
		)
		
		write.csv(
				summary_wide,
				wide_csv,
				row.names = FALSE
		)
		
		
		# ----------------------------------------------------------------------
		# Cell type x slice heatmap
		#
		# Raw mean prediction scores are displayed deliberately.
		# They are not relabeled as proportions.
		# ----------------------------------------------------------------------
		
		plot_df <- summary_long
		
		plot_df$slice <- factor(
				plot_df$slice,
				levels = slice_order
		)
		
		plot_df$celltype <- factor(
				plot_df$celltype,
				levels = rev(
						celltype_order
				)
		)
		
		p_summary <- ggplot(
						plot_df,
						aes(
								x = slice,
								y = celltype,
								fill = mean_prediction_score
						)
				) +
				geom_tile() +
				labs(
						title = "Label transfer summary across slices",
						subtitle = "Mean prediction score per cell type",
						x = "Slice",
						y = "Cell type",
						fill = "Mean prediction\nscore"
				) +
				theme_bw() +
				theme(
						panel.grid = element_blank(),
						axis.text.x = element_text(
								angle = 45,
								hjust = 1
						),
						plot.title = element_text(
								hjust = 0.5
						),
						plot.subtitle = element_text(
								hjust = 0.5
						)
				)
		
		heatmap_file <- file.path(
				summary_plot_dir,
				"labeltransfer_celltype_by_slice_heatmap.png"
		)
		
		heatmap_width <- max(
				7,
				1.1 * length(slice_order) + 4
		)
		
		heatmap_height <- max(
				5,
				0.35 * length(celltype_order) + 3
		)
		
		ggsave(
				filename = heatmap_file,
				plot = p_summary,
				width = heatmap_width,
				height = heatmap_height,
				dpi = 300,
				limitsize = FALSE
		)
		
		log_msg(
				"  summary wide CSV -> %s",
				wide_csv
		)
		
		log_msg(
				"  summary long CSV -> %s",
				long_csv
		)
		
		log_msg(
				"  summary heatmap  -> %s",
				heatmap_file
		)
		
	} else {
		
		log_msg(
				"WARNING: no usable per-slice score tables; summary heatmap skipped."
		)
	}
}



log_msg("===== Label transfer batch summary =====")
log_msg("Succeeded (%d): %s", length(ok_slices),
		if (length(ok_slices)) paste(ok_slices, collapse = ", ") else "-")
log_msg("Failed    (%d): %s", length(fail_slices),
		if (length(fail_slices)) paste(fail_slices, collapse = ", ") else "-")

if (length(ok_slices) == 0) quit(status = 1)
quit(status = 0)
