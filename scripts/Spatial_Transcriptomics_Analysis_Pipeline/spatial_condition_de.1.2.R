#!/usr/bin/env Rscript
# Version 1.2 (changes from spatial_condition_de.1.1.R):
#   Plots are saved on a white background (the log2FC heatmap was transparent).
# Version 1.1 (changes from spatial_condition_de.1.0.R):
#   Visium HD input: input_dir may be a spatial_hd_cluster output folder (hd_slides.tsv
#   and one <slide>_hd_clustered.rds per slide). Slides are read one at a time; counts
#   are summed per slide and group for the pseudobulk test, so all bins are never held
#   in memory together. New option spot_level_max: bins per slide and group used by the
#   spot-level fallback test (sampled when there are more). Visium input
#   (spatial_merge output) is analysed as in 1.0.
# Spatial module: differences between conditions (for example control and treated)
# in a merged multi-slice Visium object.
#
# Usage:
#   Rscript spatial_condition_de.1.2.R input_dir="..." sample_data="..." output_dir="..."
#       [group_by="seurat_clusters"] [reference=""] [min_spots="20"] [min_slices="2"]
#       [padj_cutoff="0.05"] [lfc_cutoff="0.5"] [top_genes="20"] [spatial_genes="6"]
#       [spot_level="auto"] [spot_level_max="3000"] [seed="1234"]
#
# Example:
#   apptainer exec <spatial image> Rscript spatial_condition_de.1.2.R \
#       input_dir="/out/spatial_merge" sample_data="/data/slices.csv" \
#       output_dir="/out/spatial_condition_de" reference="control"
#
# Arguments (key=value):
#   input_dir     (required) - Either a merged Visium folder: merged/merged_clustered.rds (or
#                              merged_clustered.rds directly in input_dir), a Seurat object
#                              with the raw Spatial counts, a 'slice' metadata column and
#                              cluster labels, as written by spatial_merge; or a Visium HD
#                              folder with hd_slides.tsv (Slide, RDS, Assay) and one Seurat
#                              object per slide with cluster labels, as written by
#                              spatial_hd_cluster.
#   sample_data   (required) - Slice sheet (CSV): SliceID (slice name as in the object, the
#                              slice folder name given to spatial_prep), Condition, optional
#                              Patient (paired design: the same patient in each condition).
#   output_dir    (required) - Output directory.
#   group_by      (optional) - Metadata column that defines the spot groups compared within
#                              (clusters, or a cell-type column). default: seurat_clusters
#   reference     (optional) - Reference condition; every other condition is compared with
#                              it. Empty: the first Condition in sample_data. default: empty
#   min_spots     (optional) - A slice enters a group's test only with at least this many
#                              spots in the group. default: 20
#   min_slices    (optional) - Slices needed per condition for the pseudobulk test. default: 2
#   padj_cutoff   (optional) - Adjusted p-value cutoff for significant genes. default: 0.05
#   lfc_cutoff    (optional) - Absolute log2 fold change for significant genes. default: 0.5
#   top_genes     (optional) - Genes labelled per volcano panel and shown in the log2FC
#                              heatmap (per group). default: 20
#   spatial_genes (optional) - Top genes drawn on the tissue sections. default: 6
#   spot_level    (optional) - auto: when a group has too few slices per condition, compare
#                              its spots with a Wilcoxon test instead (exploratory: spots of
#                              one slice are not independent replicates). no: skip such
#                              groups. default: auto
#   spot_level_max (optional) - Bins (spots) per slide and group used by the spot-level test;
#                              more are sampled down. default: 3000
#   seed          (optional) - Random seed. default: 1234
#
# Method:
#   1. Spot counts of each group per slice -> composition per slice; for each group the
#      logit proportion is compared between conditions (Welch t-test, BH; exploratory
#      with few slices).
#   2. Pseudobulk: raw Spatial counts are summed per slice and group. For each group and
#      comparison with at least min_slices slices per condition, DESeq2 tests
#      ~ Condition (~ Patient + Condition when Patient pairs the slices). Genes need at
#      least 10 counts in as many slices as the smaller condition has.
#
# Outputs (output_dir):
#   01_composition/composition_by_slice.tsv, composition_test.tsv
#   02_de/de_<test>_vs_<reference>.tsv   all groups, one row per group and gene
#   03_plots/ composition_stacked, composition_by_condition, volcano_<test>_vs_<ref>,
#             de_counts, lfc_heatmap_<test>_vs_<ref>, spatial_<gene> (.pdf and .png)
#   04_summary/de_summary.tsv  group, comparison, slices per condition, method
#             (pseudobulk_DESeq2, spot_level_wilcoxon), genes tested, up, down, status
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# Groups that cannot be tested (too few slices or spots) are data results: they are
# listed with a status and the run ends with exit code 0. The run fails only when no
# group can be tested at all. The previous output_dir content except logs/ is removed
# at the start, so no input may be inside output_dir.

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
		input_dir = "", sample_data = "", output_dir = "", group_by = "seurat_clusters", reference = "",
		min_spots = "20", min_slices = "2", padj_cutoff = "0.05", lfc_cutoff = "0.5", top_genes = "20",
		spatial_genes = "6", spot_level = "auto", spot_level_max = "3000", seed = "1234"
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
for (k in c("input_dir", "sample_data", "output_dir")) {
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
min_spots <- as_num("min_spots", 1, integer = TRUE)
min_slices <- as_num("min_slices", 2, integer = TRUE)
padj_cutoff <- as_num("padj_cutoff", 0, 1)
lfc_cutoff <- as_num("lfc_cutoff", 0)
top_genes <- as_num("top_genes", 1, integer = TRUE)
spatial_genes <- as_num("spatial_genes", 0, integer = TRUE)
seed <- as_num("seed", 0, integer = TRUE)
spot_level_max <- as_num("spot_level_max", 10, integer = TRUE)
if (!params$spot_level %in% c("auto", "no")) stop_err("spot_level must be auto or no: ", params$spot_level)

input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (!file.exists(params$sample_data)) stop_err("sample_data not found: ", params$sample_data)
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
						"Expected: merged/merged_clustered.rds (spatial_merge output) or hd_slides.tsv ",
						"(spatial_hd_cluster output)\n"))
		quit(status = 1)
	}
}

out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (x in c(input_dir, params$sample_data)) {
	inp <- normalizePath(x, mustWork = FALSE)
	if (inp == out_norm || startsWith(inp, paste0(out_norm, "/"))) {
		stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned at the start")
	}
}

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
has_patient <- "Patient" %in% names(sheet) && all(nzchar(trimws(sheet$Patient)))
conditions <- unique(sheet$Condition)
if (length(conditions) < 2) stop_err("sample_data needs at least two conditions; found: ", paste(conditions, collapse = ", "))
reference <- if (nzchar(params$reference)) params$reference else conditions[1]
if (!reference %in% conditions) stop_err("reference '", reference, "' is not a Condition in sample_data: ", paste(conditions, collapse = ", "))
tests <- setdiff(conditions, reference)

for (pkg in c("Seurat", "SeuratObject", "Matrix", "DESeq2", "ggplot2", "patchwork")) {
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
comp_dir <- file.path(output_dir, "01_composition")
de_dir <- file.path(output_dir, "02_de")
plot_dir <- file.path(output_dir, "03_plots")
summary_dir <- file.path(output_dir, "04_summary")
for (d in c(comp_dir, de_dir, plot_dir, summary_dir)) dir.create(d, showWarnings = FALSE)

suppressPackageStartupMessages({
	library(Seurat)
	library(ggplot2)
	library(patchwork)
})
set.seed(seed)

msg("############################## spatial_condition_de")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-13s = %s", k, params[[k]]))
msg("  input         = ", rds, if (hd_mode) " (Visium HD, one object per slide)" else " (merged object)")
msg("  reference     = ", reference, "; compared: ", paste(tests, collapse = ", "))
msg("  paired design = ", if (has_patient) "yes (Patient column)" else "no")
msg("")

# ------------------------------------------------------------
# Step 1: object, slices, groups
# ------------------------------------------------------------
msg("############################## Step 1: input objects")
# Each unit (a slice of the merged object, or one Visium HD slide object) gives its
# counts and groups; pseudobulk sums and spot-level samples are collected per unit.
get_counts <- function(o, assay) {
	a <- o[[assay]]
	if (inherits(a, "Assay5")) {
		if (length(SeuratObject::Layers(a, search = "counts")) > 1) a <- SeuratObject::JoinLayers(a)
		SeuratObject::LayerData(a, layer = "counts")
	} else {
		SeuratObject::GetAssayData(a, slot = "counts")
	}
}
check_group <- function(meta, where) {
	if (!params$group_by %in% names(meta)) {
		stop_err("group_by column '", params$group_by, "' not in the metadata of ", where, ". Available: ",
				paste(names(meta), collapse = ", "))
	}
}
pb_list <- list()
spot_list <- list()
slice_v <- character(0)
group_v <- character(0)
add_unit <- function(unit, cnt, grp) {
	key <- factor(grp)
	d <- Matrix::sparse.model.matrix(~ 0 + key)
	m <- cnt %*% d
	colnames(m) <- paste(unit, levels(key), sep = "\r")
	pb_list[[unit]] <<- m
	for (g in levels(key)) {
		idx <- which(grp == g)
		if (length(idx) > spot_level_max) idx <- sort(sample(idx, spot_level_max))
		spot_list[[paste(unit, g, sep = "\r")]] <<- cnt[, idx, drop = FALSE]
	}
	slice_v <<- c(slice_v, rep(unit, length(grp)))
	group_v <<- c(group_v, as.character(grp))
}
obj <- NULL
if (hd_mode) {
	missing <- setdiff(sheet$SliceID, hd$Slide)
	if (length(missing)) {
		stop_err("SliceID not found in hd_slides.tsv: ", paste(missing, collapse = ", "), ". Slides: ", paste(hd$Slide, collapse = ", "))
	}
	extra <- setdiff(hd$Slide, sheet$SliceID)
	if (length(extra)) warn_msg("slides not in sample_data are left out: ", paste(extra, collapse = ", "))
	for (s in sheet$SliceID) {
		row <- hd[hd$Slide == s, ][1, ]
		o <- readRDS(row$Path)
		check_group(o[[]], row$RDS)
		add_unit(s, get_counts(o, row$Assay), as.character(o[[]][[params$group_by]]))
		msg(sprintf("  %-20s %-12s %d bins (%s)", s, sheet$Condition[sheet$SliceID == s], ncol(o), row$Assay))
		rm(o)
		invisible(gc(verbose = FALSE))
	}
} else {
	obj <- readRDS(rds)
	if (!inherits(obj, "Seurat")) stop_err("not a Seurat object: ", rds)
	meta <- obj[[]]
	if (!"slice" %in% names(meta)) stop_err("the merged object has no 'slice' metadata column (spatial_merge sets it)")
	check_group(meta, rds)
	if (!"Spatial" %in% Assays(obj)) stop_err("the merged object has no 'Spatial' assay with raw counts")
	obj_slices <- unique(as.character(meta$slice))
	missing <- setdiff(sheet$SliceID, obj_slices)
	if (length(missing)) {
		stop_err("SliceID not found in the object: ", paste(missing, collapse = ", "),
				". Slices in the object: ", paste(obj_slices, collapse = ", "))
	}
	extra <- setdiff(obj_slices, sheet$SliceID)
	if (length(extra)) warn_msg("slices not in sample_data are left out: ", paste(extra, collapse = ", "))
	counts_all <- get_counts(obj, "Spatial")
	for (s in sheet$SliceID) {
		cells <- colnames(obj)[as.character(meta$slice) == s]
		add_unit(s, counts_all[, cells, drop = FALSE], as.character(meta[cells, params$group_by]))
		msg(sprintf("  %-20s %-12s %d spots", s, sheet$Condition[sheet$SliceID == s], length(cells)))
	}
	rm(counts_all)
	invisible(gc(verbose = FALSE))
}
cond_of <- setNames(sheet$Condition, sheet$SliceID)
patient_of <- if (has_patient) setNames(trimws(sheet$Patient), sheet$SliceID) else NULL
msg("Spots/bins: ", length(slice_v), " in ", length(unique(slice_v)), " slices; groups (", params$group_by, "): ",
		length(unique(group_v)))

# ------------------------------------------------------------
# Step 2: composition
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: composition per slice")
group_levels <- unique(group_v)
num <- suppressWarnings(as.numeric(group_levels))
group_levels <- if (all(!is.na(num))) group_levels[order(num)] else sort(group_levels)
tab <- table(factor(slice_v, levels = sheet$SliceID), factor(group_v, levels = group_levels))
prop <- sweep(tab, 1, rowSums(tab), "/")
comp <- data.frame(SliceID = rep(rownames(tab), times = ncol(tab)), Condition = cond_of[rep(rownames(tab), times = ncol(tab))],
		Group = rep(colnames(tab), each = nrow(tab)), Spots = as.vector(tab), Proportion = round(as.vector(prop), 5),
		stringsAsFactors = FALSE)
utils::write.table(comp, file.path(comp_dir, "composition_by_slice.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

logit <- function(p) log((p + 1e-3) / (1 - p + 1e-3))
comp_tests <- list()
for (tc in tests) {
	for (g in group_levels) {
		a <- comp$Proportion[comp$Group == g & comp$Condition == reference]
		b <- comp$Proportion[comp$Group == g & comp$Condition == tc]
		p <- if (length(a) >= 2 && length(b) >= 2 && stats::sd(c(logit(a) - mean(logit(a)), logit(b) - mean(logit(b)))) > 0) {
					tryCatch(stats::t.test(logit(b), logit(a))$p.value, error = function(e) NA_real_)
				} else NA_real_
		comp_tests[[length(comp_tests) + 1]] <- data.frame(Comparison = paste0(tc, "_vs_", reference), Group = g,
				Mean_reference = round(mean(a), 5), Mean_test = round(mean(b), 5), Difference = round(mean(b) - mean(a), 5),
				Slices_reference = length(a), Slices_test = length(b), PValue = p, stringsAsFactors = FALSE)
	}
}
comp_test <- do.call(rbind, comp_tests)
comp_test$Padj <- ave(comp_test$PValue, comp_test$Comparison, FUN = function(p) stats::p.adjust(p, "BH"))
utils::write.table(comp_test, file.path(comp_dir, "composition_test.tsv"), sep = "\t", quote = FALSE, row.names = FALSE,
		na = "NA")
if (min(table(sheet$Condition)) < 3) {
	warn_msg("composition tests use fewer than three slices per condition; treat their p-values as exploratory.")
}

save_gg <- function(p, name, width, height) {
	ggsave(file.path(plot_dir, paste0(name, ".pdf")), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(file.path(plot_dir, paste0(name, ".png")), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}
comp$Condition <- factor(comp$Condition, levels = c(reference, tests))
comp$Group <- factor(comp$Group, levels = group_levels)
comp$SliceID <- factor(comp$SliceID, levels = sheet$SliceID[order(match(sheet$Condition, c(reference, tests)))])
p <- ggplot(comp, aes(SliceID, Proportion, fill = Group)) + geom_col(width = 0.85) +
		facet_grid(. ~ Condition, scales = "free_x", space = "free_x") +
		labs(title = paste0("Composition of ", params$group_by, " per slice"), x = NULL, y = "Fraction of spots") +
		theme_bw(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
save_gg(p, "composition_stacked", max(6, 0.6 * nrow(sheet) + 3), 5)
p <- ggplot(comp, aes(Condition, Proportion, colour = Condition)) +
		stat_summary(fun = mean, geom = "crossbar", width = 0.6, colour = "#555555", linewidth = 0.3) +
		geom_point(size = 2, position = position_jitter(width = 0.08, height = 0, seed = 1)) +
		facet_wrap(~Group, scales = "free_y") + scale_colour_brewer(palette = "Set1") +
		labs(title = "Group proportions by condition (points: slices, bar: mean)", x = NULL, y = "Fraction of spots") +
		theme_bw(base_size = 9) + theme(legend.position = "none")
save_gg(p, "composition_by_condition", min(16, 2.2 * min(6, length(group_levels)) + 1),
		1.9 * ceiling(length(group_levels) / 6) + 1.2)

# ------------------------------------------------------------
# Step 3: pseudobulk and differential expression
# ------------------------------------------------------------
msg("")
msg("############################## Step 3: differential expression between conditions")
genes_common <- Reduce(intersect, lapply(pb_list, rownames))
pb <- do.call(cbind, lapply(pb_list, function(m) m[genes_common, , drop = FALSE]))
pb_slice <- sub("\r.*$", "", colnames(pb))
pb_group <- sub("^.*\r", "", colnames(pb))
spot_tab <- table(factor(paste(slice_v, group_v, sep = "\r"), levels = colnames(pb)))
pb_spots <- as.vector(spot_tab[colnames(pb)])
rm(pb_list)

run_deseq <- function(mat, cond, patient) {
	cd <- data.frame(Condition = factor(cond, levels = unique(c(reference, cond))), row.names = colnames(mat))
	form <- ~Condition
	if (!is.null(patient)) {
		cd$Patient <- factor(patient)
		paired <- all(table(cd$Patient, cd$Condition) <= 1) && any(rowSums(table(cd$Patient, cd$Condition) > 0) > 1)
		if (paired && nlevels(cd$Patient) < ncol(mat)) form <- ~Patient + Condition
	}
	dds <- DESeq2::DESeqDataSetFromMatrix(round(as.matrix(mat)), colData = cd, design = form)
	keep <- rowSums(DESeq2::counts(dds) >= 10) >= min(table(cond))
	dds <- dds[keep, ]
	if (nrow(dds) < 10) return(list(status = "too_few_genes", res = NULL, design = deparse(form)))
	fit <- tryCatch(DESeq2::DESeq(dds, quiet = TRUE), error = function(e) {
				tryCatch(DESeq2::DESeq(dds, quiet = TRUE, fitType = "mean"), error = function(e2) e2)
			})
	if (inherits(fit, "error")) return(list(status = paste0("deseq2_failed: ", conditionMessage(fit)), res = NULL, design = deparse(form)))
	res <- DESeq2::results(fit, contrast = c("Condition", setdiff(levels(cd$Condition), reference)[1], reference))
	list(status = "ok", design = deparse(form), res = data.frame(Gene = rownames(res), BaseMean = res$baseMean,
					Log2FC = res$log2FoldChange, LfcSE = res$lfcSE, Stat = res$stat, PValue = res$pvalue, Padj = res$padj,
					stringsAsFactors = FALSE))
}

run_spot_level <- function(tc, g) {
	parts <- spot_list[paste(sheet$SliceID[sheet$Condition %in% c(reference, tc)], g, sep = "\r")]
	parts <- parts[!vapply(parts, is.null, logical(1))]
	if (length(parts) == 0) return(NULL)
	units <- sub("\r.*$", "", names(parts))
	m <- do.call(cbind, lapply(parts, function(x) x[genes_common, , drop = FALSE]))
	colnames(m) <- paste0("c", seq_len(ncol(m)))
	cond <- rep(cond_of[units], vapply(parts, ncol, integer(1)))
	sub <- CreateSeuratObject(m, meta.data = data.frame(Condition = cond, row.names = colnames(m)))
	sub <- NormalizeData(sub, verbose = FALSE)
	Idents(sub) <- "Condition"
	if (min(table(Idents(sub))) < 3) return(NULL)
	mk <- FindMarkers(sub, ident.1 = tc, ident.2 = reference, test.use = "wilcox", logfc.threshold = 0, min.pct = 0.1,
			verbose = FALSE)
	data.frame(Gene = rownames(mk), BaseMean = NA_real_, Log2FC = mk$avg_log2FC, LfcSE = NA_real_, Stat = NA_real_,
			PValue = mk$p_val, Padj = mk$p_val_adj, stringsAsFactors = FALSE)
}

summary_rows <- list()
all_de <- list()
for (tc in tests) {
	comparison <- paste0(tc, "_vs_", reference)
	de_list <- list()
	for (g in group_levels) {
		cols <- which(pb_group == g & pb_spots >= min_spots & cond_of[pb_slice] %in% c(reference, tc))
		cond <- cond_of[pb_slice[cols]]
		n_ref <- sum(cond == reference)
		n_test <- sum(cond == tc)
		row <- list(Comparison = comparison, Group = g, Slices_reference = n_ref, Slices_test = n_test, Method = "",
				Design = "", Genes_tested = 0, Up = 0, Down = 0, Status = "")
		res <- NULL
		if (n_ref >= min_slices && n_test >= min_slices) {
			out <- run_deseq(pb[, cols, drop = FALSE], unname(cond),
					if (has_patient) unname(patient_of[pb_slice[cols]]) else NULL)
			row$Method <- "pseudobulk_DESeq2"
			row$Design <- out$design
			row$Status <- out$status
			res <- out$res
		} else if (params$spot_level == "auto" && n_ref >= 1 && n_test >= 1) {
			res <- tryCatch(run_spot_level(tc, g), error = function(e) {
						warn_msg("spot-level test failed for group ", g, ": ", conditionMessage(e))
						NULL
					})
			row$Method <- "spot_level_wilcoxon"
			row$Status <- if (is.null(res)) "spot_level_failed" else "ok_exploratory"
		} else {
			row$Status <- sprintf("insufficient_slices (need %d per condition with >= %d spots)", min_slices, min_spots)
		}
		if (!is.null(res)) {
			res <- res[order(res$Padj, res$PValue), ]
			res <- cbind(Comparison = comparison, Group = g, Method = row$Method, res)
			sig <- !is.na(res$Padj) & res$Padj < padj_cutoff & abs(res$Log2FC) >= lfc_cutoff
			res$Significant <- ifelse(sig, ifelse(res$Log2FC > 0, "up", "down"), "no")
			row$Genes_tested <- nrow(res)
			row$Up <- sum(res$Significant == "up")
			row$Down <- sum(res$Significant == "down")
			de_list[[g]] <- res
		}
		msg(sprintf("  %-28s group %-6s slices %d vs %d  %-20s genes %6d  up %5d  down %5d  %s", comparison, g, n_test, n_ref,
						row$Method, row$Genes_tested, row$Up, row$Down, row$Status))
		summary_rows[[length(summary_rows) + 1]] <- as.data.frame(row, stringsAsFactors = FALSE)
	}
	de <- if (length(de_list)) do.call(rbind, de_list) else NULL
	if (!is.null(de)) {
		rownames(de) <- NULL
		utils::write.table(de, file.path(de_dir, paste0("de_", comparison, ".tsv")), sep = "\t", quote = FALSE,
				row.names = FALSE, na = "NA")
		all_de[[comparison]] <- de
	}
}
de_summary <- do.call(rbind, summary_rows)
utils::write.table(de_summary, file.path(summary_dir, "de_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
if (any(de_summary$Method == "spot_level_wilcoxon")) {
	warn_msg("some groups were tested spot by spot (spot_level_wilcoxon) because a condition has fewer than ",
			min_slices, " slices with enough spots. Spots of one slice are not independent replicates, so these p-values ",
			"are optimistic; treat the results as exploratory.")
}

# ------------------------------------------------------------
# Step 4: figures
# ------------------------------------------------------------
msg("")
msg("############################## Step 4: figures")
rm(spot_list, pb)
invisible(gc(verbose = FALSE))
cols_sig <- c(up = "#B2182B", down = "#2166AC", no = "#BDBDBD")
for (comparison in names(all_de)) {
	de <- all_de[[comparison]]
	de$Group <- factor(de$Group, levels = group_levels)
	de$y <- -log10(pmax(de$Padj, 1e-300))
	de <- de[!is.na(de$y) & !is.na(de$Log2FC), ]
	lab <- do.call(rbind, lapply(split(de, de$Group), function(d) head(d[d$Significant != "no", ], 5)))
	n_panels <- length(unique(de$Group))
	p <- ggplot(de, aes(Log2FC, y, colour = Significant)) + geom_point(size = 0.6, alpha = 0.7) +
			geom_vline(xintercept = c(-lfc_cutoff, lfc_cutoff), linetype = 2, linewidth = 0.3, colour = "#777777") +
			geom_hline(yintercept = -log10(padj_cutoff), linetype = 2, linewidth = 0.3, colour = "#777777") +
			scale_colour_manual(values = cols_sig, breaks = c("up", "down", "no")) +
			facet_wrap(~Group, scales = "free") +
			labs(title = paste0(sub("_vs_", " vs ", comparison), " (per ", params$group_by, ")"),
					x = "log2 fold change", y = "-log10 adjusted p", colour = NULL) +
			theme_bw(base_size = 9)
	if (!is.null(lab) && nrow(lab)) p <- p + geom_text(data = lab, aes(label = Gene), size = 2.3, vjust = -0.6,
				check_overlap = TRUE, show.legend = FALSE, colour = "#111111")
	save_gg(p, paste0("volcano_", comparison), min(18, 3 * min(5, n_panels) + 1), 2.8 * ceiling(n_panels / 5) + 1)

	top <- unique(unlist(lapply(split(de, de$Group), function(d) head(d$Gene[d$Significant != "no"], top_genes))))
	if (length(top) > 0) {
		top <- head(top, 60)
		hm <- de[de$Gene %in% top, c("Gene", "Group", "Log2FC", "Significant")]
		hm$Gene <- factor(hm$Gene, levels = rev(top))
		p <- ggplot(hm, aes(Group, Gene, fill = pmax(pmin(Log2FC, 3), -3))) + geom_tile(colour = "white") +
				geom_point(data = hm[hm$Significant != "no", ], size = 0.7, colour = "#111111", show.legend = FALSE) +
				scale_fill_gradient2(low = "#2166AC", mid = "#F7F7F7", high = "#B2182B", limits = c(-3, 3),
						name = "log2FC") +
				labs(title = paste0(sub("_vs_", " vs ", comparison), ": top genes (dot: significant)"),
						x = params$group_by, y = NULL) + theme_minimal(base_size = 9) +
				theme(axis.text.y = element_text(face = "italic"))
		save_gg(p, paste0("lfc_heatmap_", comparison), max(5, 0.35 * length(group_levels) + 3), 0.16 * length(top) + 1.6)
	}
}
if (nrow(de_summary)) {
	dc <- rbind(data.frame(de_summary[, c("Comparison", "Group")], Direction = "up", N = de_summary$Up),
			data.frame(de_summary[, c("Comparison", "Group")], Direction = "down", N = -de_summary$Down))
	dc$Group <- factor(dc$Group, levels = group_levels)
	p <- ggplot(dc, aes(Group, N, fill = Direction)) + geom_col() + geom_hline(yintercept = 0, linewidth = 0.3) +
			scale_fill_manual(values = c(up = "#B2182B", down = "#2166AC")) + facet_wrap(~Comparison, ncol = 1) +
			labs(title = "Significant genes per group", x = params$group_by, y = "Genes (down below 0)") +
			theme_bw(base_size = 9)
	save_gg(p, "de_counts", max(6, 0.35 * length(group_levels) + 3), 2.6 * length(unique(dc$Comparison)) + 1)
}

# Top genes on the tissue sections (same colour scale on every section).
if (spatial_genes > 0 && length(all_de)) {
	de <- do.call(rbind, all_de)
	de <- de[de$Significant != "no", ]
	genes <- head(unique(de$Gene[order(de$Padj)]), spatial_genes)
	order_s <- sheet$SliceID[order(match(sheet$Condition, c(reference, tests)))]
	plots <- list()
	draw_unit <- function(o, s, img, assay) {
		DefaultAssay(o) <- assay
		for (g in intersect(genes, rownames(o))) {
			p <- tryCatch(SpatialFeaturePlot(o, features = g, images = img, pt.size.factor = if (hd_mode) 4 else 1.6) +
							ggtitle(paste0(s, " (", cond_of[[s]], ")")) + theme(plot.title = element_text(size = 9)),
					error = function(e) {
						warn_msg("spatial plot failed for ", g, " on ", s, ": ", conditionMessage(e))
						NULL
					})
			if (!is.null(p)) plots[[g]][[s]] <<- p
		}
	}
	if (hd_mode) {
		for (s in order_s) {
			row <- hd[hd$Slide == s, ][1, ]
			o <- readRDS(row$Path)
			# spatial_hd_cluster objects already hold log-normalised data.
			if (!"data" %in% SeuratObject::Layers(o[[row$Assay]])) o <- NormalizeData(o, assay = row$Assay, verbose = FALSE)
			if (length(Images(o))) draw_unit(o, s, Images(o)[1], row$Assay)
			rm(o)
			invisible(gc(verbose = FALSE))
		}
	} else if (length(Images(obj)) > 0) {
		DefaultAssay(obj) <- if ("SCT" %in% Assays(obj)) "SCT" else "Spatial"
		for (s in intersect(order_s, Images(obj))) draw_unit(obj, s, s, DefaultAssay(obj))
	}
	for (g in names(plots)) {
		pl <- plots[[g]]
		top <- max(vapply(pl, function(p) max(p$data[[g]], na.rm = TRUE), numeric(1)))
		pl <- lapply(pl, function(p) suppressMessages(p + scale_fill_gradientn(colours = c("#2C7BB6", "#FFFFBF", "#D7191C"),
									limits = c(0, top), name = g)))
		save_gg(patchwork::wrap_plots(pl, nrow = 1, guides = "collect") + patchwork::plot_annotation(title = g),
				paste0("spatial_", gsub("[^A-Za-z0-9._-]", "_", g)), 3.4 * length(pl) + 1, 3.8)
	}
	if (length(plots)) msg("Spatial plots: ", paste(names(plots), collapse = ", "))
}

# ------------------------------------------------------------
# Summary and exit code
# ------------------------------------------------------------
tested <- sum(grepl("^ok", de_summary$Status))
msg("")
msg("############################## Summary")
msg("Comparisons: ", paste(paste0(tests, "_vs_", reference), collapse = ", "))
msg("Groups tested: ", tested, " of ", nrow(de_summary), " (pseudobulk: ", sum(de_summary$Method == "pseudobulk_DESeq2" &
						de_summary$Status == "ok"), ", spot level: ", sum(de_summary$Status == "ok_exploratory"), ")")
msg("Significant genes (padj < ", padj_cutoff, ", |log2FC| >= ", lfc_cutoff, "): up ", sum(de_summary$Up), ", down ",
		sum(de_summary$Down))
msg("")
msg("############################## Done")
msg("Summary: ", file.path(summary_dir, "de_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
if (tested == 0) {
	stop_err("no group could be tested. Each condition needs at least ", min_slices, " slices with >= ", min_spots,
			" spots in a group (or spot_level=auto with at least one slice per condition). See ",
			file.path(summary_dir, "de_summary.tsv"))
}
untested <- de_summary$Group[!grepl("^ok", de_summary$Status)]
if (length(untested)) warn_msg("groups not tested (see de_summary.tsv): ", paste(unique(untested), collapse = ", "))
