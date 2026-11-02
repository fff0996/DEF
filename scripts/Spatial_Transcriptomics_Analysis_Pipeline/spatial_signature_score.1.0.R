#!/usr/bin/env Rscript
# Spatial module: gene set (signature) scores. Each gene set gets a score on every spot (Visium)
# or bin (Visium HD) with Seurat AddModuleScore (mean expression of the set minus that of
# random control genes with similar expression); scores are drawn on the tissue and summarised
# per group (cluster or cell type) and, with a slice sheet, per condition.
#
# Usage:
#   Rscript spatial_signature_score.1.0.R input_dir="..." output_dir="..."
#       [gene_sets=""] [builtin_sets="HALLMARK_HYPOXIA,HALLMARK_EPITHELIAL_MESENCHYMAL_TRANSITION,HALLMARK_INTERFERON_GAMMA_RESPONSE"]
#       [species="auto"] [group_by="auto"] [sample_data=""] [reference=""] [min_genes="5"]
#       [pt_size="auto"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.2.sif Rscript spatial_signature_score.1.0.R \
#       input_dir="/out/spatial_hd_cluster" output_dir="/out/spatial_signature_score" \
#       sample_data="/data/hd_slides.csv" reference="normal"
#
# Arguments (key=value):
#   input_dir    (required) - A Visium HD folder with hd_slides.tsv (Slide, RDS, Assay) and one Seurat
#                             object per slide (spatial_hd_cluster or spatial_hd_rctd output); or a
#                             merged Visium folder with merged/merged_clustered.rds and a 'slice'
#                             metadata column (spatial_merge output).
#   output_dir   (required) - Output directory.
#   gene_sets    (optional) - Own gene sets: a GMT file (name ending in .gmt; per line: set name,
#                             description, genes, tab separated) or a two-column table (.tsv or
#                             .csv: set name, gene symbol; a header line is allowed). default: empty
#   builtin_sets (optional) - MSigDB Hallmark set names (msigdbr 7.5.1, bundled in the image), comma
#                             separated; all_hallmark for all 50; none for no built-in set.
#                             default: HALLMARK_HYPOXIA,HALLMARK_EPITHELIAL_MESENCHYMAL_TRANSITION,
#                             HALLMARK_INTERFERON_GAMMA_RESPONSE
#   species      (optional) - Species of the built-in sets: human, mouse, or auto (mouse when most gene
#                             symbols of the data are not upper case). default: auto
#   group_by     (optional) - Groups for the summary. auto: rctd_first_type when the objects have it,
#                             otherwise seurat_clusters. default: auto
#   sample_data  (optional) - Slice sheet (CSV): SliceID, Condition. With it, slide means are compared
#                             between conditions. default: empty
#   reference    (optional) - Reference condition. Empty: the first Condition in sample_data.
#   min_genes    (optional) - A set is scored only when at least this many of its genes are in the
#                             data. default: 5
#   pt_size      (optional) - Point size on the tissue plots. auto: 4 for Visium HD, 1.6 for Visium.
#   seed         (optional) - Random seed (control genes). default: 1234
#
# Outputs (output_dir):
#   gene_sets_used.tsv                 set, source, genes in the set, genes found in the data, scored
#   <slide>/<slide>_signature_scores.tsv.gz  spot/bin, group, one score column per set
#   signature_by_group.tsv             mean score per slide, group and set
#   signature_by_slide.tsv             mean score per slide and set (with condition)
#   signature_test.tsv                 with sample_data: slide means between conditions (Welch t-test,
#                                      BH; exploratory with few slides)
#   plots/ spatial_<set> (all slides, one colour scale), signature_by_group (heatmap of group means),
#          signature_by_condition (with sample_data) (.png, .pdf)
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# Scores are relative (centred on the control genes) and comparable between groups and slides of
# the same run. The previous output_dir content except logs/ is removed at the start, so no input
# may be inside output_dir.

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
		input_dir = "", output_dir = "", gene_sets = "",
		builtin_sets = "HALLMARK_HYPOXIA,HALLMARK_EPITHELIAL_MESENCHYMAL_TRANSITION,HALLMARK_INTERFERON_GAMMA_RESPONSE",
		species = "auto", group_by = "auto", sample_data = "", reference = "", min_genes = "5", pt_size = "auto",
		seed = "1234"
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
min_genes <- as_num("min_genes", 1, integer = TRUE)
seed <- as_num("seed", 0, integer = TRUE)
pt_size <- if (params$pt_size == "auto") NA_real_ else as_num("pt_size", 0.1, 50)
if (!params$species %in% c("auto", "human", "mouse")) stop_err("species must be auto, human or mouse: ", params$species)
builtin <- trimws(strsplit(params$builtin_sets, ",", fixed = TRUE)[[1]])
builtin <- builtin[nzchar(builtin)]
if (identical(tolower(builtin), "none")) builtin <- character(0)
if (!length(builtin) && !nzchar(params$gene_sets)) stop_err("no gene set: give gene_sets, or builtin_sets other than none")

input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (nzchar(params$gene_sets) && !file.exists(params$gene_sets)) stop_err("gene_sets not found: ", params$gene_sets)
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
						"Expected: hd_slides.tsv (spatial_hd_cluster or spatial_hd_rctd output) or ",
						"merged/merged_clustered.rds (spatial_merge output)\n"))
		quit(status = 1)
	}
}
if (is.na(pt_size)) pt_size <- if (hd_mode) 4 else 1.6

out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (x in c(input_dir, params$sample_data, params$gene_sets)) {
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

for (pkg in c("Seurat", "SeuratObject", "ggplot2", "patchwork", if (length(builtin)) "msigdbr")) {
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

msg("############################## spatial_signature_score")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-12s = %s", k, params[[k]]))
msg("  input        = ", rds, if (hd_mode) " (Visium HD, one object per slide)" else " (merged Visium object)")
if (!is.null(sheet)) msg("  reference    = ", reference, "; compared: ", paste(tests, collapse = ", "))
msg("")

save_gg <- function(p, file_base, width, height) {
	ggsave(paste0(file_base, ".pdf"), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(paste0(file_base, ".png"), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}

# ------------------------------------------------------------
# Units (slides) and their objects
# ------------------------------------------------------------
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
	unit_assay <- function(o, s) hd$Assay[hd$Slide == s][1]
	unit_image <- function(o, s) Images(o)[1]
	unit_cells <- function(o, s) colnames(o)
} else {
	obj <- readRDS(rds)
	if (!inherits(obj, "Seurat")) stop_err("not a Seurat object: ", rds)
	if (!"slice" %in% names(obj[[]])) stop_err("the merged object has no 'slice' metadata column (spatial_merge sets it)")
	units <- intersect(unique(as.character(obj$slice)), Images(obj))
	if (!length(units)) stop_err("no slice of the merged object has an image of the same name")
	if (!is.null(sheet)) {
		missing <- setdiff(sheet$SliceID, units)
		if (length(missing)) stop_err("SliceID not found in the object: ", paste(missing, collapse = ", "))
		units <- sheet$SliceID
	}
	load_unit <- function(s) obj
	unit_assay <- function(o, s) if ("SCT" %in% Assays(o)) "SCT" else "Spatial"
	unit_image <- function(o, s) s
	unit_cells <- function(o, s) colnames(o)[as.character(o$slice) == s]
}

# ------------------------------------------------------------
# Step 1: gene sets
# ------------------------------------------------------------
msg("############################## Step 1: gene sets")
first <- load_unit(units[1])
genes_data <- rownames(first[[unit_assay(first, units[1])]])
species <- params$species
if (species == "auto") {
	letters_only <- genes_data[grepl("^[A-Za-z][A-Za-z0-9-]*$", genes_data)]
	species <- if (mean(letters_only == toupper(letters_only)) >= 0.5) "human" else "mouse"
	msg("  species = ", species, " (auto, from gene symbol case)")
}
group_by <- params$group_by
if (group_by == "auto") {
	group_by <- if ("rctd_first_type" %in% names(first[[]])) "rctd_first_type" else "seurat_clusters"
	msg("  group_by = ", group_by, " (auto)")
}
if (hd_mode) {
	rm(first)
	invisible(gc(verbose = FALSE))
}
sets <- list()
source_of <- character(0)
if (nzchar(params$gene_sets)) {
	if (grepl("\\.gmt$", tolower(params$gene_sets))) {
		lines <- readLines(params$gene_sets, warn = FALSE)
		fields <- strsplit(lines[nzchar(trimws(lines))], "\t", fixed = TRUE)
		if (any(lengths(fields) < 3)) stop_err("a GMT line needs name, description and genes (tab separated): ", params$gene_sets)
		for (f in fields) {
			g <- unique(trimws(f[-(1:2)]))
			sets[[trimws(f[1])]] <- g[nzchar(g)]
		}
	} else {
		sep <- if (grepl("\\.csv$", tolower(params$gene_sets))) "," else "\t"
		tab <- utils::read.table(params$gene_sets, sep = sep, header = FALSE, colClasses = "character", quote = "\"",
				strip.white = TRUE, fill = TRUE)
		if (ncol(tab) < 2) stop_err("gene_sets table needs two columns (set name, gene symbol): ", params$gene_sets)
		if (!any(tab[1, 2] %in% genes_data)) tab <- tab[-1, , drop = FALSE]
		for (nm in unique(tab[[1]])) sets[[nm]] <- unique(tab[[2]][tab[[1]] == nm])
	}
	source_of <- setNames(rep("gene_sets", length(sets)), names(sets))
	msg("  ", length(sets), " set(s) from ", params$gene_sets)
}
if (length(builtin)) {
	h <- msigdbr::msigdbr(species = if (species == "human") "Homo sapiens" else "Mus musculus", category = "H")
	avail <- unique(h$gs_name)
	want <- if (identical(tolower(builtin), "all_hallmark")) avail else builtin
	unknown <- setdiff(want, avail)
	if (length(unknown)) stop_err("unknown builtin_sets (MSigDB Hallmark 7.5.1): ", paste(unknown, collapse = ", "),
				". Example names: ", paste(head(avail, 5), collapse = ", "))
	for (nm in want) {
		if (nm %in% names(sets)) next
		sets[[nm]] <- unique(h$gene_symbol[h$gs_name == nm])
		source_of[nm] <- "MSigDB Hallmark 7.5.1 (msigdbr)"
	}
	msg("  ", length(want), " built-in Hallmark set(s) for ", species)
}
used <- data.frame(Set = names(sets), Source = unname(source_of[names(sets)]), Genes = lengths(sets),
		Genes_found = vapply(sets, function(g) sum(g %in% genes_data), integer(1)), stringsAsFactors = FALSE)
used$Scored <- ifelse(used$Genes_found >= min_genes, "yes", paste0("no (fewer than ", min_genes, " genes found)"))
utils::write.table(used, file.path(output_dir, "gene_sets_used.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
for (i in seq_len(nrow(used))) msg(sprintf("  %-50s %4d genes, %4d found  %s", used$Set[i], used$Genes[i], used$Genes_found[i],
					if (used$Scored[i] == "yes") "" else "not scored"))
sets <- sets[used$Set[used$Scored == "yes"]]
if (!length(sets)) stop_err("no gene set has at least ", min_genes, " genes in the data (min_genes); see gene_sets_used.tsv")
safe <- function(x) gsub("[^A-Za-z0-9._-]", "_", x)
# Tissue plots hold every spot/bin of every slide; draw them for the first sets only.
max_tissue_sets <- 12
if (length(sets) > max_tissue_sets) warn_msg(length(sets), " sets are scored; tissue plots are drawn for the first ",
			max_tissue_sets, " (all scores are in the tables)")

# ------------------------------------------------------------
# Step 2: scores per slide
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: scores")
cond_of <- if (!is.null(sheet)) setNames(sheet$Condition, sheet$SliceID) else NULL
by_group <- list()
plots <- list()
for (s in units) {
	t0 <- Sys.time()
	o <- load_unit(s)
	assay <- unit_assay(o, s)
	DefaultAssay(o) <- assay
	if (!group_by %in% names(o[[]])) stop_err("group_by column '", group_by, "' not in the metadata of ", s)
	if (!"data" %in% SeuratObject::Layers(o[[assay]])) o <- NormalizeData(o, assay = assay, verbose = FALSE)
	cells <- unit_cells(o, s)
	sub <- if (hd_mode) o else subset(o, cells = cells)
	sub <- AddModuleScore(sub, features = unname(sets), assay = assay, name = "SIG_", seed = seed)
	sc <- as.matrix(sub[[]][, paste0("SIG_", seq_along(sets)), drop = FALSE])
	colnames(sc) <- names(sets)
	grp <- as.character(sub[[]][[group_by]])
	dir.create(file.path(output_dir, s), recursive = TRUE, showWarnings = FALSE)
	gz <- gzfile(file.path(output_dir, s, paste0(s, "_signature_scores.tsv.gz")), "w")
	utils::write.table(data.frame(Spot = colnames(sub), Group = grp, round(sc, 5), check.names = FALSE), gz,
			sep = "\t", quote = FALSE, row.names = FALSE, na = "")
	close(gz)
	ok <- !is.na(grp) & nzchar(grp)
	for (nm in names(sets)) {
		m <- tapply(sc[ok, nm], grp[ok], mean)
		by_group[[length(by_group) + 1]] <- data.frame(Slide = s, Condition = if (is.null(cond_of)) NA else cond_of[[s]],
				Group = names(m), Set = nm, Mean = round(as.numeric(m), 5), Spots = as.integer(table(grp[ok])[names(m)]),
				stringsAsFactors = FALSE)
		by_group[[length(by_group) + 1]] <- data.frame(Slide = s, Condition = if (is.null(cond_of)) NA else cond_of[[s]],
				Group = "(all)", Set = nm, Mean = round(mean(sc[, nm]), 5), Spots = nrow(sc), stringsAsFactors = FALSE)
		if (match(nm, names(sets)) > max_tissue_sets) next
		col <- paste0("score_", safe(nm))
		sub[[col]] <- sc[, nm]
		p <- tryCatch(SpatialFeaturePlot(sub, features = col, images = unit_image(o, s), pt.size.factor = pt_size) +
						ggtitle(if (is.null(cond_of)) s else paste0(s, " (", cond_of[[s]], ")")) +
						theme(plot.title = element_text(size = 9)),
				error = function(e) {
					warn_msg("spatial plot failed for ", nm, " on ", s, ": ", conditionMessage(e))
					NULL
				})
		if (!is.null(p)) plots[[nm]][[s]] <- p
	}
	msg(sprintf("  %-20s %d spots/bins, %d s", s, ncol(sub), round(as.numeric(difftime(Sys.time(), t0, units = "secs")))))
	rm(sub)
	if (hd_mode) rm(o)
	invisible(gc(verbose = FALSE))
}
by_group <- do.call(rbind, by_group)
utils::write.table(by_group[by_group$Group != "(all)", ], file.path(output_dir, "signature_by_group.tsv"), sep = "\t",
		quote = FALSE, row.names = FALSE, na = "")
by_slide <- by_group[by_group$Group == "(all)", c("Slide", "Condition", "Set", "Mean", "Spots")]
utils::write.table(by_slide, file.path(output_dir, "signature_by_slide.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "")

# ------------------------------------------------------------
# Step 3: plots
# ------------------------------------------------------------
msg("")
msg("############################## Step 3: plots")
slide_order <- if (is.null(sheet)) units else sheet$SliceID[order(match(sheet$Condition, c(reference, tests)))]
for (nm in names(plots)) {
	pl <- plots[[nm]][intersect(slide_order, names(plots[[nm]]))]
	col <- paste0("score_", safe(nm))
	rng <- range(unlist(lapply(pl, function(p) range(p$data[[col]], na.rm = TRUE))))
	pl <- lapply(pl, function(p) suppressMessages(p + scale_fill_gradientn(colours = c("#2C7BB6", "#FFFFBF", "#D7191C"),
								limits = rng, name = "score")))
	save_gg(patchwork::wrap_plots(pl, nrow = 1, guides = "collect") + patchwork::plot_annotation(title = nm),
			file.path(plot_dir, paste0("spatial_", safe(nm))), 3.4 * length(pl) + 1, 3.8)
}
bg <- by_group[by_group$Group != "(all)", ]
gm <- aggregate(Mean ~ Group + Set, data = bg, FUN = mean)
glev <- unique(gm$Group)
num <- suppressWarnings(as.numeric(glev))
glev <- if (all(!is.na(num))) glev[order(num)] else sort(glev)
gm$Group <- factor(gm$Group, levels = glev)
gm$Set <- factor(gm$Set, levels = rev(names(sets)))
gm$Z <- ave(gm$Mean, gm$Set, FUN = function(v) if (stats::sd(v) > 0) (v - mean(v)) / stats::sd(v) else v * 0)
p <- ggplot(gm, aes(Group, Set, fill = Z)) + geom_tile(colour = "white") +
		scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", name = "z of\nmean score") +
		labs(title = paste0("Gene set scores per ", group_by, " (mean over slides, scaled per set)"), x = group_by, y = NULL) +
		theme_minimal(base_size = 10) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
save_gg(p, file.path(plot_dir, "signature_by_group"), max(5, 0.35 * length(glev) + 4), 0.35 * length(sets) + 1.8)

if (!is.null(sheet)) {
	rows <- list()
	for (tc in tests) {
		for (nm in names(sets)) {
			a <- by_slide$Mean[by_slide$Set == nm & by_slide$Condition == reference]
			b <- by_slide$Mean[by_slide$Set == nm & by_slide$Condition == tc]
			pv <- if (length(a) >= 2 && length(b) >= 2 && stats::sd(c(a - mean(a), b - mean(b))) > 0) {
						tryCatch(stats::t.test(b, a)$p.value, error = function(e) NA_real_)
					} else NA_real_
			rows[[length(rows) + 1]] <- data.frame(Comparison = paste0(tc, "_vs_", reference), Set = nm,
					Mean_reference = round(mean(a), 5), Mean_test = round(mean(b), 5), Difference = round(mean(b) - mean(a), 5),
					Slices_reference = length(a), Slices_test = length(b), PValue = pv, stringsAsFactors = FALSE)
		}
	}
	st <- do.call(rbind, rows)
	st$Padj <- ave(st$PValue, st$Comparison, FUN = function(p) stats::p.adjust(p, "BH"))
	utils::write.table(st, file.path(output_dir, "signature_test.tsv"), sep = "\t", quote = FALSE, row.names = FALSE, na = "NA")
	if (min(table(sheet$Condition)) < 3) warn_msg("signature tests use fewer than three slices per condition; treat their p-values as exploratory.")
	for (i in seq_len(nrow(st))) msg(sprintf("  %-22s %-45s %.4f -> %.4f  padj %s", st$Comparison[i], st$Set[i],
						st$Mean_reference[i], st$Mean_test[i], format(signif(st$Padj[i], 3))))
	bc <- by_slide
	bc$Condition <- factor(bc$Condition, levels = c(reference, tests))
	bc$Set <- factor(bc$Set, levels = names(sets))
	p <- ggplot(bc, aes(Condition, Mean, colour = Condition)) +
			stat_summary(fun = mean, geom = "crossbar", width = 0.6, colour = "#555555", linewidth = 0.3) +
			geom_point(size = 2, position = position_jitter(width = 0.08, height = 0, seed = 1)) +
			facet_wrap(~Set, scales = "free_y", labeller = label_wrap_gen(28)) + scale_colour_brewer(palette = "Set1") +
			labs(title = "Mean gene set score per slide (points: slides, bar: mean)", x = NULL, y = "Mean score") +
			theme_bw(base_size = 9) + theme(legend.position = "none")
	save_gg(p, file.path(plot_dir, "signature_by_condition"), min(14, 2.6 * min(4, length(sets)) + 1),
			2.2 * ceiling(length(sets) / 4) + 1.2)
}

msg("")
msg("############################## Done")
msg("Gene sets: ", file.path(output_dir, "gene_sets_used.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
