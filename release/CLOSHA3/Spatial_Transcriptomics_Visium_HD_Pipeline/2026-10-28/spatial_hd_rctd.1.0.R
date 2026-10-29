#!/usr/bin/env Rscript
# Version 1.0 (first release in CLOSHA 3.0; work version 1.2):
# Spatial module (Visium HD): cell types of every bin with RCTD and a single-cell reference.
#
# Usage:
#   Rscript spatial_hd_rctd.1.0.R input_dir="..." output_dir="..." [reference_rds="..."]
#       [reference_label_col="..."] [reference_assay="RNA"] [rctd_mode="doublet"] [chunk_bins="20000"]
#       [umi_min="100"] [min_cells_per_type="25"] [min_shared_features="200"]
#       [max_cores="auto"] [pt_size="4"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.1.sif Rscript spatial_hd_rctd.1.0.R \
#       input_dir="/out/spatial_hd_cluster" reference_rds="/ref/brain_reference.rds" \
#       reference_label_col="celltype" output_dir="/out/spatial_hd_rctd"
#
# Arguments (key=value):
#   input_dir           (required) - Visium HD cluster folder: hd_slides.tsv (Slide, RDS, Assay) and
#                                    one Seurat object per slide with raw counts in the binned
#                                    assay, as written by spatial_hd_cluster.
#   reference_rds       (optional) - Single-cell reference: Seurat object (.rds) with raw counts and
#                                    a cell-type column. Empty: the module is skipped
#                                    (output_dir/skipped.txt) and ends without error.
#   reference_label_col (required with reference_rds) - Metadata column of the reference with
#                                    the cell types. Empty or wrong: the run stops and lists
#                                    the candidate columns.
#   output_dir          (required) - Output directory.
#   reference_assay     (optional) - Reference assay holding raw counts. default: RNA
#   rctd_mode           (optional) - doublet (one or two cell types per bin; suits 8 um bins
#                                    close to cell size) or full (any mixture; suits 16 um bins).
#                                    default: doublet
#   chunk_bins          (optional) - Bins per RCTD run; a slide is processed chunk by chunk to
#                                    bound memory. default: 20000
#   umi_min             (optional) - Bins with fewer UMIs are not scored (RCTD UMI_min).
#                                    default: 100
#   min_cells_per_type  (optional) - Reference cell types with fewer cells are left out.
#                                    default: 25
#   min_shared_features (optional) - Genes shared by the reference and the slides needed to run.
#                                    default: 200
#   max_cores           (optional) - auto (default) = cores allocated to the job (nproc); a number
#                                    is capped by them. default: auto
#   pt_size             (optional) - Bin size in the tissue plots (Seurat pt.size.factor). default: 4
#   seed                (optional) - Random seed. default: 1234
#
# Method: RCTD (spacexr) with the reference cell-type profiles, run per slide on chunks of
# chunk_bins bins (raw counts and tissue coordinates). doublet mode gives each bin a first and a
# second cell type and a class (singlet, doublet_certain, doublet_uncertain, reject); full mode
# gives weights only, and the first type is the highest weight. Weights are normalised to sum to 1.
#
# Outputs (output_dir):
#   <slide>/<slide>_hd_rctd.rds        slide object with metadata rctd_first_type,
#                                      rctd_second_type, rctd_spot_class, rctd_first_weight
#   <slide>/<slide>_rctd_weights.tsv.gz bin x cell-type weights
#   <slide>/plots/<slide>_rctd_first_type (.png, .pdf)
#   hd_slides.tsv                       Slide, RDS, Assay, Bins: spatial_condition_de reads this
#                                       folder as input_dir (group_by=rctd_first_type)
#   celltype_by_slide.tsv               fraction of scored bins per first type and slide
#   plots/celltype_by_slide (.png, .pdf)
#   rctd_summary.tsv                    Slide, Bins, Bins_scored, class counts, Seconds, Status
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# Bins below umi_min keep NA cell types (rctd_spot_class = not_scored). A slide that fails is
# listed in rctd_summary.tsv; the run fails only when every slide fails. The previous
# output_dir content except logs/ is removed at the start, so no input may be inside output_dir.

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
defaults <- list(input_dir = "", reference_rds = "", reference_label_col = "", output_dir = "",
		reference_assay = "RNA", rctd_mode = "doublet", chunk_bins = "20000", umi_min = "100",
		min_cells_per_type = "25", min_shared_features = "200", max_cores = "auto", pt_size = "4", seed = "1234")
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
for (k in c("input_dir", "output_dir")) {
	if (!nzchar(params[[k]])) stop_err("Required parameter '", k, "' is missing")
}
as_num <- function(name, lo = -Inf, hi = Inf, integer = FALSE) {
	v <- suppressWarnings(as.numeric(params[[name]]))
	if (is.na(v) || v < lo || v > hi || (integer && v != round(v))) {
		stop_err(name, " must be ", if (integer) "an integer" else "a number", " in [", lo, ", ", hi, "]: ", params[[name]])
	}
	v
}
if (!params$rctd_mode %in% c("doublet", "full")) stop_err("rctd_mode must be doublet or full: ", params$rctd_mode)
chunk_bins <- as_num("chunk_bins", 1000, 200000, TRUE)
umi_min <- as_num("umi_min", 1, integer = TRUE)
min_cells_per_type <- as_num("min_cells_per_type", 1, integer = TRUE)
min_shared_features <- as_num("min_shared_features", 1, integer = TRUE)
pt_size <- as_num("pt_size", 0.1, 50)
seed <- as_num("seed", 0, integer = TRUE)
allocated <- tryCatch(as.integer(system("env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc", intern = TRUE)), error = function(e) NA_integer_)
if (is.na(allocated) || allocated < 1) allocated <- length(parallel::mcaffinity())
max_cores <- if (tolower(params$max_cores) == "auto") allocated else as_num("max_cores", 1, integer = TRUE)
cores_capped <- max_cores > allocated
if (cores_capped) max_cores <- allocated

input_dir <- params$input_dir
output_dir <- params$output_dir
reference_rds <- params$reference_rds
# No reference: cell types are an optional branch of the pipeline, so the module records
# the skip in output_dir/skipped.txt and ends without error (spatial_condition_de skips on
# such a folder). output_dir is not cleaned here; a later run with a reference cleans it.
if (!nzchar(reference_rds)) {
	dir.create(file.path(output_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
	txt <- "No reference_rds was given, so cell-type annotation was skipped."
	writeLines(txt, file.path(output_dir, "skipped.txt"))
	writeLines(txt, file.path(output_dir, "logs", paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")))
	msg(txt)
	quit(status = 0)
}
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (!file.exists(reference_rds)) stop_err("reference_rds not found: ", reference_rds)
input_dir <- normalizePath(input_dir)
reference_rds <- normalizePath(reference_rds)
out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (p in c(input_dir, reference_rds)) {
	if (p == out_norm || startsWith(p, paste0(out_norm, "/"))) stop_err(p, " is inside output_dir ", output_dir, ", which is cleaned at the start")
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
for (pkg in c("Seurat", "SeuratObject", "spacexr", "ggplot2", "patchwork", "Matrix")) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}

# ------------------------------------------------------------
# Output directory and logs
# ------------------------------------------------------------
if (dir.exists(output_dir)) {
	old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
	unlink(old[basename(old) != "logs"], recursive = TRUE, force = TRUE)
}
dir.create(file.path(output_dir, "plots"), recursive = TRUE, showWarnings = FALSE)
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
set.seed(seed)
save_gg <- function(p, path_no_ext, width, height) {
	ggsave(paste0(path_no_ext, ".pdf"), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(paste0(path_no_ext, ".png"), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}

msg("############################## spatial_hd_rctd")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-19s = %s", k, params[[k]]))
msg(sprintf("  max_cores used      = %d (allocated %d)", max_cores, allocated))
if (cores_capped) warn_msg("max_cores=", params$max_cores, " requested, allocated cores: ", allocated, "; using ", allocated)
msg("Slides (", nrow(hd), "): ", paste(hd$Slide, collapse = ", "))

# ------------------------------------------------------------
# Step 1: reference
# ------------------------------------------------------------
msg("")
msg("############################## Step 1: reference")
ref <- tryCatch(readRDS(reference_rds), error = function(e) stop_err("cannot read reference_rds: ", conditionMessage(e)))
if (!inherits(ref, "Seurat")) stop_err("reference_rds is not a Seurat object")
if (!params$reference_assay %in% Assays(ref)) {
	stop_err("reference_assay '", params$reference_assay, "' not in the reference; assays: ", paste(Assays(ref), collapse = ", "))
}
if (!params$reference_label_col %in% colnames(ref@meta.data)) {
	# Categorical columns with 2-100 categories are the cell-type candidates, as check_reference tags them.
	meta <- ref@meta.data
	n_cat <- vapply(meta, function(v) if (is.numeric(v)) 0L else length(unique(stats::na.omit(as.character(v)))), integer(1))
	cand <- names(n_cat)[n_cat >= 2 & n_cat <= 100]
	lines <- vapply(cand, function(col) {
		cnt <- sort(table(as.character(meta[[col]])), decreasing = TRUE)
		sprintf("  %-24s %d categories: %s%s", col, n_cat[[col]], paste(utils::head(names(cnt), 5), collapse = ", "),
				if (n_cat[[col]] > 5) ", ..." else "")
	}, character(1))
	other <- setdiff(names(meta), cand)
	stop_err(if (nzchar(params$reference_label_col)) paste0("reference_label_col '", params$reference_label_col,
						"' not in the reference metadata.") else "reference_label_col is empty; give the cell-type column of the reference.",
			"\nCell-type column candidates (categorical, 2-100 categories):\n",
			if (length(lines)) paste(lines, collapse = "\n") else "  (none)",
			"\nOther columns: ", if (length(other)) paste(other, collapse = ", ") else "(none)",
			"\nSet reference_label_col to the cell-type column and run again.")
}
ref_counts <- tryCatch(SeuratObject::LayerData(ref, assay = params$reference_assay, layer = "counts"),
		error = function(e) NULL)
if (is.null(ref_counts) || ncol(ref_counts) == 0) stop_err("the reference assay has no raw counts layer; RCTD needs raw counts")
if (any(ref_counts@x != round(ref_counts@x))) stop_err("the reference counts are not integers; give the raw counts assay")
labels <- as.character(ref@meta.data[[params$reference_label_col]])
names(labels) <- colnames(ref)
ok <- !is.na(labels) & nzchar(labels)
n_type <- table(labels[ok])
keep_types <- names(n_type)[n_type >= min_cells_per_type]
dropped <- setdiff(names(n_type), keep_types)
if (length(dropped)) warn_msg("reference cell types with fewer than ", min_cells_per_type, " cells left out: ", paste(dropped, collapse = ", "))
if (length(keep_types) < 2) stop_err("fewer than two reference cell types have at least ", min_cells_per_type, " cells")
cells <- names(labels)[ok & labels %in% keep_types]
ref_counts <- ref_counts[, cells, drop = FALSE]
cell_types <- factor(labels[cells])
names(cell_types) <- cells
reference <- spacexr::Reference(ref_counts, cell_types, Matrix::colSums(ref_counts))
ref_genes <- rownames(ref_counts)
msg(sprintf("Reference: %d genes x %d cells, %d cell types", length(ref_genes), length(cells), nlevels(cell_types)))
for (lv in levels(cell_types)) msg(sprintf("  %-28s %d cells", lv, sum(cell_types == lv)))
rm(ref, ref_counts)
invisible(gc(verbose = FALSE))

# ------------------------------------------------------------
# Step 2: RCTD per slide, chunk by chunk
# ------------------------------------------------------------
summary_rows <- list()
comp_rows <- list()
manifest <- list()
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
		img <- Images(obj)
		if (length(img) == 0) stop("the slide object has no image (tissue coordinates)")
		counts <- SeuratObject::LayerData(obj, assay = a, layer = "counts")
		shared <- intersect(rownames(counts), ref_genes)
		if (length(shared) < min_shared_features) {
			stop(length(shared), " genes shared with the reference (min_shared_features=", min_shared_features,
					"); check that both use the same gene symbols and species")
		}
		coords <- GetTissueCoordinates(obj, image = img[1])
		if (!"cell" %in% names(coords)) coords$cell <- rownames(coords)
		rownames(coords) <- coords$cell
		bins <- intersect(colnames(obj), coords$cell)
		msg(sprintf("  %d bins, %d genes shared with the reference, %d chunk(s) of up to %d bins",
						length(bins), length(shared), ceiling(length(bins) / chunk_bins), chunk_bins))
		res_df <- list()
		wts <- list()
		for (start in seq(1, length(bins), by = chunk_bins)) {
			idx <- bins[start:min(length(bins), start + chunk_bins - 1)]
			cnt <- counts[, idx, drop = FALSE]
			puck <- spacexr::SpatialRNA(coords[idx, c("x", "y")], cnt, Matrix::colSums(cnt))
			rctd <- suppressMessages(spacexr::create.RCTD(puck, reference, max_cores = max_cores, UMI_min = umi_min,
							CELL_MIN_INSTANCE = min_cells_per_type))
			rctd <- suppressMessages(spacexr::run.RCTD(rctd, doublet_mode = params$rctd_mode))
			w <- as.matrix(spacexr::normalize_weights(rctd@results$weights))
			wts[[length(wts) + 1]] <- w
			if (params$rctd_mode == "doublet") {
				rd <- rctd@results$results_df
				res_df[[length(res_df) + 1]] <- data.frame(bin = rownames(rd), first = as.character(rd$first_type),
						second = as.character(rd$second_type), class = as.character(rd$spot_class))
			} else {
				ord <- t(apply(w, 1, function(v) names(v)[order(-v)][1:2]))
				res_df[[length(res_df) + 1]] <- data.frame(bin = rownames(w), first = ord[, 1], second = ord[, 2], class = "full")
			}
			msg(sprintf("  bins %d-%d: %d scored", start, start + length(idx) - 1, nrow(w)))
			rm(cnt, puck, rctd)
			invisible(gc(verbose = FALSE))
		}
		rd <- do.call(rbind, res_df)
		w <- do.call(rbind, wts)
		rm(counts)
		first <- setNames(rep(NA_character_, ncol(obj)), colnames(obj))
		second <- first
		class <- setNames(rep("not_scored", ncol(obj)), colnames(obj))
		first[rd$bin] <- rd$first
		second[rd$bin] <- rd$second
		class[rd$bin] <- rd$class
		fw <- setNames(rep(NA_real_, ncol(obj)), colnames(obj))
		fw[rd$bin] <- w[cbind(match(rd$bin, rownames(w)), match(rd$first, colnames(w)))]
		obj$rctd_first_type <- factor(first, levels = colnames(w))
		obj$rctd_second_type <- factor(second, levels = colnames(w))
		obj$rctd_spot_class <- class
		obj$rctd_first_weight <- round(fw, 4)
		dir.create(file.path(output_dir, s, "plots"), recursive = TRUE, showWarnings = FALSE)
		out_rds <- file.path(output_dir, s, paste0(s, "_hd_rctd.rds"))
		saveRDS(obj, out_rds)
		wt <- data.frame(Bin = rownames(w), round(w, 4), check.names = FALSE)
		gz <- gzfile(file.path(output_dir, s, paste0(s, "_rctd_weights.tsv.gz")), "w")
		utils::write.table(wt, gz, sep = "\t", quote = FALSE, row.names = FALSE)
		close(gz)
		scored <- !is.na(first) & (class != "reject")
		frac <- table(factor(first[scored], levels = colnames(w))) / max(1, sum(scored))
		comp_rows[[s]] <- data.frame(Slide = s, Cell_type = names(frac), Fraction = round(as.numeric(frac), 5))
		pal <- setNames(scales::hue_pal()(ncol(w)), colnames(w))
		p <- SpatialDimPlot(obj, group.by = "rctd_first_type", images = img[1], pt.size.factor = pt_size, cols = pal) +
				ggtitle(paste0(s, ": RCTD first cell type")) + guides(fill = guide_legend(override.aes = list(size = 3), ncol = 1))
		save_gg(p, file.path(output_dir, s, "plots", paste0(s, "_rctd_first_type")), 8, 6.5)
		manifest[[s]] <- data.frame(Slide = s, RDS = file.path(s, paste0(s, "_hd_rctd.rds")), Assay = a, Bins = ncol(obj))
		cls <- table(factor(class, levels = c("singlet", "doublet_certain", "doublet_uncertain", "reject", "full", "not_scored")))
		secs <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")))
		top <- names(sort(frac, decreasing = TRUE))[1:min(3, length(frac))]
		msg(sprintf("  scored %d of %d bins; most frequent: %s; %d s", nrow(rd), ncol(obj), paste(top, collapse = ", "), secs))
		res <- data.frame(Slide = s, Bins = ncol(obj), Bins_scored = nrow(rd), Singlet = cls[["singlet"]],
				Doublet_certain = cls[["doublet_certain"]], Doublet_uncertain = cls[["doublet_uncertain"]],
				Reject = cls[["reject"]], Not_scored = cls[["not_scored"]], Seconds = secs, Status = "ok")
		rm(obj, w)
		invisible(gc(verbose = FALSE))
		res
	}, error = function(e) {
		warn_msg("slide ", s, " failed: ", conditionMessage(e))
		data.frame(Slide = s, Bins = NA, Bins_scored = NA, Singlet = NA, Doublet_certain = NA, Doublet_uncertain = NA,
				Reject = NA, Not_scored = NA, Seconds = round(as.numeric(difftime(Sys.time(), t0, units = "secs"))),
				Status = "failed")
	})
	summary_rows[[s]] <- row
}

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
summary_df <- do.call(rbind, summary_rows)
utils::write.table(summary_df, file.path(output_dir, "rctd_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
if (length(manifest)) {
	utils::write.table(do.call(rbind, manifest), file.path(output_dir, "hd_slides.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
}
if (length(comp_rows)) {
	comp <- do.call(rbind, comp_rows)
	utils::write.table(comp, file.path(output_dir, "celltype_by_slide.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
	p <- ggplot(comp, aes(Slide, Fraction, fill = Cell_type)) + geom_col() +
			labs(title = "RCTD first cell type per slide (scored bins)", x = NULL, y = "Fraction of bins", fill = "Cell type") +
			theme_bw(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1))
	save_gg(p, file.path(output_dir, "plots", "celltype_by_slide"), max(5, 0.8 * length(unique(comp$Slide)) + 3), 5)
}
msg("")
msg("############################## Summary")
for (i in seq_len(nrow(summary_df))) {
	msg(sprintf("  %-20s %-7s bins %s, scored %s", summary_df$Slide[i], summary_df$Status[i], summary_df$Bins[i],
					summary_df$Bins_scored[i]))
}
failed <- summary_df$Slide[summary_df$Status == "failed"]
if (length(failed) == nrow(summary_df)) stop_err("all slides failed; see the warnings above")
if (length(failed)) warn_msg("some slides failed: ", paste(failed, collapse = ", "), ". Check rctd_summary.tsv.")
msg("")
msg("############################## Done")
msg("Summary: ", file.path(output_dir, "rctd_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
