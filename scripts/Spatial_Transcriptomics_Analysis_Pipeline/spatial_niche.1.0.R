#!/usr/bin/env Rscript
# Spatial module: cell-type niches. For every spot (Visium) or bin (Visium HD) the labels of
# its nearest neighbours on the tissue are counted; spots with a similar neighbourhood make
# one niche (k-means over all slides together, so niche numbers are shared by the slides).
#
# Usage:
#   Rscript spatial_niche.1.0.R input_dir="..." output_dir="..."
#       [sample_data=""] [reference=""] [group_by="auto"] [neighbors="30"] [niches="6"]
#       [kmeans_max="200000"] [pt_size="auto"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.2.sif Rscript spatial_niche.1.0.R \
#       input_dir="/out/spatial_hd_rctd" output_dir="/out/spatial_niche" \
#       sample_data="/data/hd_slides.csv" reference="normal"
#
# Arguments (key=value):
#   input_dir   (required) - A Visium HD folder with hd_slides.tsv (Slide, RDS, Assay) and one
#                            Seurat object per slide (spatial_hd_rctd output with cell types, or
#                            spatial_hd_cluster output with clusters); or a merged Visium folder
#                            with merged/merged_clustered.rds and a 'slice' metadata column. A
#                            folder with skipped.txt (the cell-type module ran without a
#                            reference) is skipped as well.
#   output_dir  (required) - Output directory.
#   sample_data (optional) - Slice sheet (CSV): SliceID, Condition. With it, slides are ordered
#                            by condition and niche fractions are compared between conditions.
#                            default: empty (no comparison)
#   reference   (optional) - Reference condition for the comparison. Empty: the first Condition
#                            in sample_data. default: empty
#   group_by    (optional) - Labels counted in the neighbourhoods. auto: rctd_first_type when the
#                            objects have it (cell types), otherwise seurat_clusters. default: auto
#   neighbors   (optional) - Nearest spots/bins counted around each one (itself included).
#                            default: 30
#   niches      (optional) - Number of niches (k-means centres). default: 6
#   kmeans_max  (optional) - Spots/bins used to find the niche centres (sampled when there are
#                            more); every spot/bin is then given the nearest centre. default: 200000
#   pt_size     (optional) - Point size on the tissue plots. auto: 4 for Visium HD, 1.6 for
#                            Visium. default: auto
#   seed        (optional) - Random seed. default: 1234
#
# Outputs (output_dir):
#   <slide>/<slide>_niches.tsv.gz      spot/bin, label, niche
#   <slide>/plots/<slide>_niches       niches on the tissue (.png and .pdf)
#   niche_composition.tsv              per niche: spots/bins, dominant label, short name, mean fraction of
#                                      each label in the neighbourhoods
#   niche_by_slide.tsv                 spots/bins and fraction of each niche per slide
#   niche_test.tsv                     with sample_data: niche fractions between conditions
#                                      (Welch t-test on logit fractions, BH; exploratory with few slides)
#   plots/ niche_composition, niche_by_slide, niche_by_condition (with sample_data) (.png, .pdf)
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# Spots/bins without a label (for example bins below umi_min in spatial_hd_rctd) are left out
# of the counts and get no niche. The previous output_dir content except logs/ is removed at
# the start, so no input may be inside output_dir.

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
defaults <- list(
		input_dir = "", output_dir = "", sample_data = "", reference = "", group_by = "auto",
		neighbors = "30", niches = "6", kmeans_max = "200000", pt_size = "auto", seed = "1234"
)
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
	x <- params[[name]]
	v <- suppressWarnings(as.numeric(x))
	if (is.na(v) || v < lo || v > hi || (integer && v != round(v))) {
		stop_err(name, " must be ", if (integer) "an integer" else "a number", " in [", lo, ", ", hi, "]: ", x)
	}
	v
}
neighbors <- as_num("neighbors", 2, 500, integer = TRUE)
n_niches <- as_num("niches", 2, 50, integer = TRUE)
kmeans_max <- as_num("kmeans_max", 1000, integer = TRUE)
seed <- as_num("seed", 0, integer = TRUE)
pt_size <- if (params$pt_size == "auto") NA_real_ else as_num("pt_size", 0.1, 50)

input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
# The cell-type module before this one had no reference; there are no cell types to count.
if (file.exists(file.path(input_dir, "skipped.txt"))) {
	dir.create(file.path(output_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
	txt <- paste0("input_dir was skipped by the previous module (", paste(readLines(file.path(input_dir, "skipped.txt")),
					collapse = " "), "), so the niche analysis was skipped.")
	writeLines(txt, file.path(output_dir, "skipped.txt"))
	writeLines(txt, file.path(output_dir, "logs", paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")))
	msg(txt)
	quit(status = 0)
}
hd_manifest <- file.path(input_dir, "hd_slides.tsv")
hd_mode <- file.exists(hd_manifest)
if (hd_mode) {
	hd <- utils::read.delim(hd_manifest, colClasses = "character")
	if (!all(c("Slide", "RDS", "Assay") %in% names(hd))) stop_err("hd_slides.tsv must have Slide, RDS and Assay columns: ", hd_manifest)
	hd$Path <- file.path(input_dir, hd$RDS)
	if (any(!file.exists(hd$Path))) stop_err("slide object not found: ", hd$Path[!file.exists(hd$Path)][1])
	rds <- hd_manifest
} else {
	rds <- c(file.path(input_dir, "merged", "merged_clustered.rds"), file.path(input_dir, "merged_clustered.rds"))
	rds <- rds[file.exists(rds)][1]
	if (is.na(rds)) {
		emit_err(paste0("ERROR: no input object in input_dir: ", input_dir, "\n",
						"Expected: hd_slides.tsv (spatial_hd_rctd or spatial_hd_cluster output) or ",
						"merged/merged_clustered.rds (spatial_merge output)\n"))
		quit(status = 1)
	}
}
if (is.na(pt_size)) pt_size <- if (hd_mode) 4 else 1.6

out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (x in c(input_dir, params$sample_data)) {
	if (!nzchar(x)) next
	inp <- normalizePath(x, mustWork = FALSE)
	if (inp == out_norm || startsWith(inp, paste0(out_norm, "/"))) {
		stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned at the start")
	}
}

sheet <- NULL
if (nzchar(params$sample_data)) {
	if (!file.exists(params$sample_data)) stop_err("sample_data not found: ", params$sample_data)
	sheet <- tryCatch(utils::read.csv(params$sample_data, colClasses = "character", check.names = FALSE,
					strip.white = TRUE, fileEncoding = "UTF-8-BOM"),
			error = function(e) stop_err("cannot read sample_data: ", conditionMessage(e)))
	names(sheet) <- trimws(names(sheet))
	if (!all(c("SliceID", "Condition") %in% names(sheet))) {
		stop_err("sample_data must have the columns SliceID and Condition; found: ", paste(names(sheet), collapse = ", "))
	}
	sheet$SliceID <- trimws(sheet$SliceID)
	sheet$Condition <- trimws(sheet$Condition)
	if (any(!nzchar(sheet$SliceID)) || any(!nzchar(sheet$Condition))) stop_err("sample_data has an empty SliceID or Condition")
	if (anyDuplicated(sheet$SliceID)) stop_err("sample_data has duplicate SliceID: ", sheet$SliceID[duplicated(sheet$SliceID)][1])
	conditions <- unique(sheet$Condition)
	reference <- if (nzchar(params$reference)) params$reference else conditions[1]
	if (!reference %in% conditions) stop_err("reference '", reference, "' is not a Condition in sample_data: ", paste(conditions, collapse = ", "))
	tests <- setdiff(conditions, reference)
} else if (nzchar(params$reference)) {
	warn_msg("reference is ignored without sample_data")
}

for (pkg in c("Seurat", "SeuratObject", "Matrix", "RANN", "ggplot2", "patchwork")) {
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
plot_dir <- file.path(output_dir, "plots")
dir.create(plot_dir, showWarnings = FALSE)

suppressPackageStartupMessages({
	library(Seurat)
	library(ggplot2)
	library(patchwork)
})
set.seed(seed)

msg("############################## spatial_niche")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-11s = %s", k, params[[k]]))
msg("  input       = ", rds, if (hd_mode) " (Visium HD, one object per slide)" else " (merged Visium object)")
if (!is.null(sheet)) msg("  reference   = ", reference, "; compared: ", paste(tests, collapse = ", "))
msg("")

save_gg <- function(p, file_base, width, height) {
	ggsave(paste0(file_base, ".pdf"), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(paste0(file_base, ".png"), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}

# ------------------------------------------------------------
# Step 1: neighbourhood label counts of every spot/bin
# ------------------------------------------------------------
msg("############################## Step 1: neighbourhoods")
# Units are Visium HD slides (one object each) or slices of the merged Visium object.
if (hd_mode) {
	units <- hd$Slide
	if (!is.null(sheet)) {
		missing <- setdiff(sheet$SliceID, hd$Slide)
		if (length(missing)) stop_err("SliceID not found in hd_slides.tsv: ", paste(missing, collapse = ", "),
					". Slides: ", paste(hd$Slide, collapse = ", "))
		extra <- setdiff(hd$Slide, sheet$SliceID)
		if (length(extra)) warn_msg("slides not in sample_data are left out: ", paste(extra, collapse = ", "))
		units <- sheet$SliceID
	}
	load_unit <- function(s) readRDS(hd$Path[hd$Slide == s][1])
	unit_image <- function(o, s) Images(o)[1]
} else {
	obj <- readRDS(rds)
	if (!inherits(obj, "Seurat")) stop_err("not a Seurat object: ", rds)
	if (!"slice" %in% names(obj[[]])) stop_err("the merged object has no 'slice' metadata column (spatial_merge sets it)")
	units <- intersect(unique(as.character(obj$slice)), Images(obj))
	if (!length(units)) stop_err("no slice of the merged object has an image of the same name; images: ", paste(Images(obj), collapse = ", "))
	if (!is.null(sheet)) {
		missing <- setdiff(sheet$SliceID, units)
		if (length(missing)) stop_err("SliceID not found in the object: ", paste(missing, collapse = ", "),
					". Slices: ", paste(units, collapse = ", "))
		units <- sheet$SliceID
	}
	load_unit <- function(s) obj
	unit_image <- function(o, s) s
}
group_by <- params$group_by
coords_of <- function(o, img) {
	cc <- GetTissueCoordinates(o, image = img)
	if (!"cell" %in% names(cc)) cc$cell <- rownames(cc)
	cc[, c("cell", "x", "y")]
}
store <- list()
for (s in units) {
	t0 <- Sys.time()
	o <- load_unit(s)
	meta <- o[[]]
	if (group_by == "auto") {
		group_by <- if ("rctd_first_type" %in% names(meta)) "rctd_first_type" else "seurat_clusters"
		msg("  group_by = ", group_by, " (auto)")
	}
	if (!group_by %in% names(meta)) stop_err("group_by column '", group_by, "' not in the metadata of ", s, ". Available: ",
				paste(names(meta), collapse = ", "))
	img <- unit_image(o, s)
	if (is.na(img) || !img %in% Images(o)) stop_err(s, ": the object has no image (tissue coordinates)")
	cc <- coords_of(o, img)
	if (!hd_mode) cc <- cc[cc$cell %in% colnames(o)[as.character(meta$slice) == s], ]
	lab <- as.character(meta[cc$cell, group_by])
	ok <- !is.na(lab) & nzchar(lab)
	if (sum(ok) <= neighbors) stop_err(s, ": only ", sum(ok), " labelled spots/bins, fewer than neighbors (", neighbors, ")")
	if (!all(ok)) msg(sprintf("  %s: %d spots/bins without a %s label are left out", s, sum(!ok), group_by))
	cc <- cc[ok, ]
	lab <- lab[ok]
	nn <- RANN::nn2(as.matrix(cc[, c("x", "y")]), k = neighbors)$nn.idx
	store[[s]] <- list(cell = cc$cell, x = cc$x, y = cc$y, label = lab, nn = nn, image = img)
	msg(sprintf("  %-20s %d spots/bins, %d labelled, %d s", s, nrow(meta), length(lab),
					round(as.numeric(difftime(Sys.time(), t0, units = "secs")))))
	if (hd_mode) {
		rm(o)
		invisible(gc(verbose = FALSE))
	}
}
labels <- sort(unique(unlist(lapply(store, `[[`, "label"))))
num <- suppressWarnings(as.numeric(labels))
if (all(!is.na(num))) labels <- labels[order(num)]
# Label counts among the neighbours of every spot/bin, as fractions (rows sum to 1).
comp_of <- function(u) {
	j <- match(u$label, labels)[as.vector(u$nn)]
	m <- Matrix::sparseMatrix(i = rep(seq_len(nrow(u$nn)), times = ncol(u$nn)), j = j, x = 1,
			dims = c(nrow(u$nn), length(labels)), dimnames = list(NULL, labels))
	as.matrix(m) / ncol(u$nn)
}
for (s in units) store[[s]]$comp <- comp_of(store[[s]])
msg("Labels (", group_by, "): ", length(labels), "; spots/bins: ", sum(vapply(store, function(u) length(u$cell), 1L)))

# ------------------------------------------------------------
# Step 2: niches (k-means on the neighbourhood fractions of all slides)
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: niches")
all_comp <- do.call(rbind, lapply(store, `[[`, "comp"))
set.seed(seed)
fit_rows <- if (nrow(all_comp) > kmeans_max) sort(sample(nrow(all_comp), kmeans_max)) else seq_len(nrow(all_comp))
km <- tryCatch(stats::kmeans(all_comp[fit_rows, , drop = FALSE], centers = n_niches, nstart = 10, iter.max = 100),
		error = function(e) stop_err("k-means with niches=", n_niches, " failed (", conditionMessage(e),
					"); use fewer niches"))
# Every spot/bin gets its nearest centre (the same as the k-means label for the fitted rows).
nearest <- function(m) {
	d <- sapply(seq_len(nrow(km$centers)), function(k) rowSums(sweep(m, 2, km$centers[k, ])^2))
	if (is.null(dim(d))) d <- matrix(d, nrow = 1)
	max.col(-d, ties.method = "first")
}
# Niche numbers follow size (niche 1 is the largest).
raw <- nearest(all_comp)
size_order <- order(-tabulate(raw, nbins = n_niches))
renum <- match(seq_len(n_niches), size_order)
niche_all <- renum[raw]
start <- 0
for (s in units) {
	n <- length(store[[s]]$cell)
	store[[s]]$niche <- niche_all[start + seq_len(n)]
	start <- start + n
}
niche_levels <- as.character(seq_len(n_niches))
mean_comp <- t(sapply(seq_len(n_niches), function(k) colMeans(all_comp[niche_all == k, , drop = FALSE])))
if (is.null(dim(mean_comp))) mean_comp <- matrix(mean_comp, nrow = n_niches)
colnames(mean_comp) <- labels
dominant <- labels[apply(mean_comp, 1, which.max)]
# Short niche names for plots: the top label, plus the second when it is at least 0.2.
niche_name <- vapply(seq_len(n_niches), function(k) {
	o <- order(-mean_comp[k, ])
	if (length(o) > 1 && mean_comp[k, o[2]] >= 0.2) paste(labels[o[1]], "+", labels[o[2]]) else labels[o[1]]
}, character(1))
comp_tab <- data.frame(Niche = niche_levels, Spots = tabulate(niche_all, nbins = n_niches), Dominant = dominant, Name = niche_name,
		round(mean_comp, 4), check.names = FALSE)
utils::write.table(comp_tab, file.path(output_dir, "niche_composition.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
for (k in seq_len(n_niches)) {
	top <- order(-mean_comp[k, ])[1:min(3, length(labels))]
	msg(sprintf("  niche %-3s %8d spots/bins  %s", k, comp_tab$Spots[k],
					paste(sprintf("%s %.2f", labels[top], mean_comp[k, top]), collapse = ", ")))
}

hm <- data.frame(Niche = factor(rep(niche_levels, times = length(labels)), levels = rev(niche_levels)),
		Label = factor(rep(labels, each = n_niches), levels = labels), Fraction = as.vector(mean_comp))
p <- ggplot(hm, aes(Label, Niche, fill = Fraction)) + geom_tile(colour = "white") +
		geom_text(aes(label = ifelse(Fraction >= 0.1, sprintf("%.2f", Fraction), "")), size = 2.8) +
		scale_fill_gradient(low = "#F7FBFF", high = "#08519C", limits = c(0, 1)) +
		labs(title = paste0("Niche composition (mean fraction of ", group_by, " among ", neighbors, " neighbours)"),
				x = group_by, y = "Niche") +
		theme_minimal(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
save_gg(p, file.path(plot_dir, "niche_composition"), max(5, 0.45 * length(labels) + 3), 0.4 * n_niches + 1.8)

# ------------------------------------------------------------
# Step 3: per-slide tables and niche maps
# ------------------------------------------------------------
msg("")
msg("############################## Step 3: niches per slide")
pal <- setNames(grDevices::hcl.colors(n_niches, "Dark 3"), niche_levels)
cond_of <- if (!is.null(sheet)) setNames(sheet$Condition, sheet$SliceID) else NULL
by_slide <- list()
for (s in units) {
	u <- store[[s]]
	dir.create(file.path(output_dir, s, "plots"), recursive = TRUE, showWarnings = FALSE)
	gz <- gzfile(file.path(output_dir, s, paste0(s, "_niches.tsv.gz")), "w")
	utils::write.table(data.frame(Spot = u$cell, Label = u$label, Niche = u$niche), gz, sep = "\t", quote = FALSE,
			row.names = FALSE)
	close(gz)
	cnt <- tabulate(u$niche, nbins = n_niches)
	by_slide[[s]] <- data.frame(Slide = s, Condition = if (is.null(cond_of)) NA else cond_of[[s]], Niche = niche_levels,
			Spots = cnt, Fraction = round(cnt / sum(cnt), 5))
	o <- load_unit(s)
	nv <- rep(NA_character_, ncol(o))
	nv[match(u$cell, colnames(o))] <- as.character(u$niche)
	o$niche <- factor(nv, levels = niche_levels)
	p <- tryCatch(SpatialDimPlot(o, group.by = "niche", images = u$image, pt.size.factor = pt_size, cols = pal) +
					ggtitle(if (is.null(cond_of)) s else paste0(s, " (", cond_of[[s]], ")")),
			error = function(e) {
				warn_msg("niche plot failed on ", s, ": ", conditionMessage(e))
				NULL
			})
	if (!is.null(p)) save_gg(p, file.path(output_dir, s, "plots", paste0(s, "_niches")), 7.5, 6.5)
	msg(sprintf("  %-20s %s", s, paste(sprintf("%s:%.2f", niche_levels, cnt / sum(cnt)), collapse = " ")))
	if (hd_mode) {
		rm(o)
		invisible(gc(verbose = FALSE))
	}
}
by_slide <- do.call(rbind, by_slide)
utils::write.table(by_slide, file.path(output_dir, "niche_by_slide.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "")
slide_order <- if (is.null(sheet)) units else sheet$SliceID[order(match(sheet$Condition, c(reference, tests)))]
bs <- by_slide
bs$Slide <- factor(bs$Slide, levels = slide_order)
bs$Niche <- factor(bs$Niche, levels = niche_levels)
if (!is.null(sheet)) bs$Condition <- factor(bs$Condition, levels = c(reference, tests))
p <- ggplot(bs, aes(Slide, Fraction, fill = Niche)) + geom_col(width = 0.85) + scale_fill_manual(values = pal) +
		labs(title = "Niche fractions per slide", x = NULL, y = "Fraction of spots/bins") +
		theme_bw(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
if (!is.null(sheet)) p <- p + facet_grid(. ~ Condition, scales = "free_x", space = "free_x")
save_gg(p, file.path(plot_dir, "niche_by_slide"), max(5, 0.6 * length(units) + 3), 5)

# ------------------------------------------------------------
# Step 4: niche fractions between conditions (with sample_data)
# ------------------------------------------------------------
if (!is.null(sheet)) {
	msg("")
	msg("############################## Step 4: niches between conditions")
	logit <- function(p) log((p + 1e-3) / (1 - p + 1e-3))
	rows <- list()
	for (tc in tests) {
		for (k in niche_levels) {
			a <- by_slide$Fraction[by_slide$Niche == k & by_slide$Condition == reference]
			b <- by_slide$Fraction[by_slide$Niche == k & by_slide$Condition == tc]
			pv <- if (length(a) >= 2 && length(b) >= 2 && stats::sd(c(logit(a) - mean(logit(a)), logit(b) - mean(logit(b)))) > 0) {
						tryCatch(stats::t.test(logit(b), logit(a))$p.value, error = function(e) NA_real_)
					} else NA_real_
			rows[[length(rows) + 1]] <- data.frame(Comparison = paste0(tc, "_vs_", reference), Niche = k,
					Dominant = dominant[as.integer(k)], Mean_reference = round(mean(a), 5), Mean_test = round(mean(b), 5),
					Difference = round(mean(b) - mean(a), 5), Slices_reference = length(a), Slices_test = length(b),
					PValue = pv, stringsAsFactors = FALSE)
		}
	}
	nt <- do.call(rbind, rows)
	nt$Padj <- ave(nt$PValue, nt$Comparison, FUN = function(p) stats::p.adjust(p, "BH"))
	utils::write.table(nt, file.path(output_dir, "niche_test.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
	if (min(table(sheet$Condition)) < 3) warn_msg("niche tests use fewer than three slices per condition; treat their p-values as exploratory.")
	for (i in seq_len(nrow(nt))) msg(sprintf("  %-22s niche %-3s %-18s %.3f -> %.3f  padj %s", nt$Comparison[i], nt$Niche[i],
						nt$Dominant[i], nt$Mean_reference[i], nt$Mean_test[i], format(signif(nt$Padj[i], 3))))
	bc <- by_slide
	bc$Condition <- factor(bc$Condition, levels = c(reference, tests))
	bc$Panel <- factor(paste0("niche ", bc$Niche, " (", niche_name[as.integer(bc$Niche)], ")"),
			levels = paste0("niche ", niche_levels, " (", niche_name, ")"))
	p <- ggplot(bc, aes(Condition, Fraction, colour = Condition)) +
			stat_summary(fun = mean, geom = "crossbar", width = 0.6, colour = "#555555", linewidth = 0.3) +
			geom_point(size = 2, position = position_jitter(width = 0.08, height = 0, seed = 1)) +
			facet_wrap(~Panel, scales = "free_y") + scale_colour_brewer(palette = "Set1") +
			labs(title = "Niche fractions by condition (points: slices, bar: mean)", x = NULL, y = "Fraction of spots/bins") +
			theme_bw(base_size = 9) + theme(legend.position = "none")
	save_gg(p, file.path(plot_dir, "niche_by_condition"), min(14, 2.4 * min(4, n_niches) + 1), 2.1 * ceiling(n_niches / 4) + 1.2)
}

msg("")
msg("############################## Done")
msg("Niche composition: ", file.path(output_dir, "niche_composition.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
