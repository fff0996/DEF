#!/usr/bin/env Rscript
# Spatial module: gene set enrichment of condition comparisons. For every group (cluster or cell
# type) tested by spatial_condition_de, genes are ranked by the test statistic and gene sets are
# tested with fgsea (preranked GSEA), so that each group shows which pathways go up or down
# between conditions.
#
# Usage:
#   Rscript spatial_de_enrichment.1.0.R input_dir="..." output_dir="..."
#       [gene_sets=""] [collection="H"] [species="auto"] [min_size="10"] [max_size="500"]
#       [padj_cutoff="0.05"] [top_sets="20"] [seed="1234"]
#
# Example:
#   apptainer exec bx_spatial.1.2.sif Rscript spatial_de_enrichment.1.0.R \
#       input_dir="/out/spatial_condition_de" output_dir="/out/spatial_de_enrichment"
#
# Arguments (key=value):
#   input_dir   (required) - Condition comparison folder: 02_de/de_<test>_vs_<reference>.tsv (columns
#                            Comparison, Group, Method, Gene, Log2FC, Stat, PValue, Padj) and
#                            04_summary/de_summary.tsv, as written by spatial_condition_de. A folder
#                            with skipped.txt is skipped as well.
#   output_dir  (required) - Output directory.
#   gene_sets   (optional) - Own gene sets instead of the built-in collection: a GMT file (name ending
#                            in .gmt) or a two-column table (.tsv or .csv: set name, gene symbol).
#                            default: empty
#   collection  (optional) - Built-in MSigDB 7.5.1 collection (msigdbr, bundled in the image): H
#                            (Hallmark), C2:CP:KEGG, C2:CP:REACTOME or C5:GO:BP. default: H
#   species     (optional) - Species of the built-in sets: human, mouse, or auto (mouse when most gene
#                            symbols are not upper case). default: auto
#   min_size    (optional) - Smallest gene set tested (genes found in the ranking). default: 10
#   max_size    (optional) - Largest gene set tested. default: 500
#   padj_cutoff (optional) - Adjusted p-value cutoff for significant sets. default: 0.05
#   top_sets    (optional) - Gene sets shown in the NES heatmap (smallest adjusted p over the groups).
#                            default: 20
#   seed        (optional) - Random seed for fgsea. default: 1234
#
# Method: within each comparison and group, genes are ranked by the DESeq2 Wald statistic
# (pseudobulk groups) or, where it is missing (spot-level groups), by sign(log2FC) x -log10(p).
# fgsea (fgseaMultilevel) gives the normalised enrichment score (NES; > 0: higher in the test
# condition) and BH-adjusted p per group. Groups tested spot by spot keep their Method so their
# results can be read as exploratory.
#
# Outputs (output_dir):
#   01_gsea/gsea_<test>_vs_<reference>.tsv  Comparison, Group, Method, Set, Size, NES, PValue, Padj,
#                                           Leading_edge (first 15 genes)
#   02_summary/enrichment_summary.tsv       per comparison and group: genes ranked, sets tested,
#                                           significant up and down, status
#   03_plots/ gsea_nes_<test>_vs_<reference> (heatmap: sets x groups), gsea_top_<test>_vs_<reference>
#             (the group with the most significant sets) (.png, .pdf)
#   gene_sets_used.tsv
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# The previous output_dir content except logs/ is removed at the start, so no input may be inside
# output_dir.

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
		input_dir = "", output_dir = "", gene_sets = "", collection = "H", species = "auto", min_size = "10",
		max_size = "500", padj_cutoff = "0.05", top_sets = "20", seed = "1234"
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
min_size <- as_num("min_size", 1, integer = TRUE)
max_size <- as_num("max_size", min_size, integer = TRUE)
padj_cutoff <- as_num("padj_cutoff", 0, 1)
top_sets <- as_num("top_sets", 1, integer = TRUE)
seed <- as_num("seed", 0, integer = TRUE)
if (!params$species %in% c("auto", "human", "mouse")) stop_err("species must be auto, human or mouse: ", params$species)
collections <- list(H = c("H", NA), "C2:CP:KEGG" = c("C2", "CP:KEGG"), "C2:CP:REACTOME" = c("C2", "CP:REACTOME"),
		"C5:GO:BP" = c("C5", "GO:BP"))
if (!nzchar(params$gene_sets) && !params$collection %in% names(collections)) {
	stop_err("collection must be one of ", paste(names(collections), collapse = ", "), ": ", params$collection)
}

input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (nzchar(params$gene_sets) && !file.exists(params$gene_sets)) stop_err("gene_sets not found: ", params$gene_sets)
# The comparison before this one was skipped (no reference for the cell-type branch).
if (file.exists(file.path(input_dir, "skipped.txt"))) {
	dir.create(file.path(output_dir, "logs"), recursive = TRUE, showWarnings = FALSE)
	txt <- paste0("input_dir was skipped by the previous module (", paste(readLines(file.path(input_dir, "skipped.txt")),
					collapse = " "), "), so the enrichment was skipped.")
	writeLines(txt, file.path(output_dir, "skipped.txt"))
	writeLines(txt, file.path(output_dir, "logs", paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")))
	msg(txt)
	quit(status = 0)
}
de_files <- list.files(file.path(input_dir, "02_de"), pattern = "^de_.+_vs_.+\\.tsv$", full.names = TRUE)
if (!length(de_files)) {
	emit_err(paste0("ERROR: no result table in ", file.path(input_dir, "02_de"), "\n",
					"Expected de_<test>_vs_<reference>.tsv, as written by spatial_condition_de\n"))
	quit(status = 1)
}
out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (x in c(input_dir, params$gene_sets)) {
	if (!nzchar(x)) next
	inp <- normalizePath(x, mustWork = FALSE)
	if (inp == out_norm || startsWith(inp, paste0(out_norm, "/"))) {
		stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned at the start")
	}
}
for (pkg in c("fgsea", "ggplot2", if (!nzchar(params$gene_sets)) "msigdbr")) {
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
gsea_dir <- file.path(output_dir, "01_gsea")
summary_dir <- file.path(output_dir, "02_summary")
plot_dir <- file.path(output_dir, "03_plots")
for (d in c(gsea_dir, summary_dir, plot_dir)) dir.create(d, showWarnings = FALSE)
suppressPackageStartupMessages(library(ggplot2))

msg("############################## spatial_de_enrichment")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) msg(sprintf("  %-11s = %s", k, params[[k]]))
msg("  tables      = ", paste(basename(de_files), collapse = ", "))
msg("")

save_gg <- function(p, name, width, height) {
	ggsave(file.path(plot_dir, paste0(name, ".pdf")), p, bg = "white", width = width, height = height, limitsize = FALSE)
	ggsave(file.path(plot_dir, paste0(name, ".png")), p, bg = "white", width = width, height = height, dpi = 200, limitsize = FALSE)
}

# ------------------------------------------------------------
# Step 1: result tables and gene sets
# ------------------------------------------------------------
msg("############################## Step 1: tables and gene sets")
need <- c("Comparison", "Group", "Method", "Gene", "Log2FC", "PValue")
tabs <- lapply(de_files, function(f) {
	t <- utils::read.delim(f, check.names = FALSE, stringsAsFactors = FALSE, colClasses = c(Group = "character"))
	miss <- setdiff(need, names(t))
	if (length(miss)) stop_err(basename(f), " lacks column(s): ", paste(miss, collapse = ", "))
	if (!"Stat" %in% names(t)) t$Stat <- NA_real_
	t
})
genes_all <- unique(unlist(lapply(tabs, `[[`, "Gene")))
species <- params$species
if (species == "auto") {
	g <- genes_all[grepl("^[A-Za-z][A-Za-z0-9-]*$", genes_all)]
	species <- if (mean(g == toupper(g)) >= 0.5) "human" else "mouse"
	msg("  species = ", species, " (auto, from gene symbol case)")
}
sets <- list()
if (nzchar(params$gene_sets)) {
	if (grepl("\\.gmt$", tolower(params$gene_sets))) {
		lines <- readLines(params$gene_sets, warn = FALSE)
		fields <- strsplit(lines[nzchar(trimws(lines))], "\t", fixed = TRUE)
		if (any(lengths(fields) < 3)) stop_err("a GMT line needs name, description and genes (tab separated): ", params$gene_sets)
		for (f in fields) sets[[trimws(f[1])]] <- unique(trimws(f[-(1:2)]))
	} else {
		sep <- if (grepl("\\.csv$", tolower(params$gene_sets))) "," else "\t"
		tab <- utils::read.table(params$gene_sets, sep = sep, header = FALSE, colClasses = "character", quote = "\"",
				strip.white = TRUE, fill = TRUE)
		if (ncol(tab) < 2) stop_err("gene_sets table needs two columns (set name, gene symbol): ", params$gene_sets)
		if (!any(tab[1, 2] %in% genes_all)) tab <- tab[-1, , drop = FALSE]
		for (nm in unique(tab[[1]])) sets[[nm]] <- unique(tab[[2]][tab[[1]] == nm])
	}
	source_txt <- params$gene_sets
} else {
	cc <- collections[[params$collection]]
	h <- if (is.na(cc[2])) msigdbr::msigdbr(species = if (species == "human") "Homo sapiens" else "Mus musculus", category = cc[1]) else
				msigdbr::msigdbr(species = if (species == "human") "Homo sapiens" else "Mus musculus", category = cc[1], subcategory = cc[2])
	sets <- split(h$gene_symbol, h$gs_name)
	sets <- lapply(sets, unique)
	source_txt <- paste0("MSigDB 7.5.1 ", params$collection, " (msigdbr)")
}
used <- data.frame(Set = names(sets), Source = source_txt, Genes = lengths(sets),
		Genes_in_results = vapply(sets, function(g) sum(g %in% genes_all), integer(1)))
utils::write.table(used, file.path(output_dir, "gene_sets_used.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
msg("  ", length(sets), " gene sets from ", source_txt, "; ", sum(used$Genes_in_results >= min_size),
		" with at least min_size genes in the results")
if (!any(used$Genes_in_results >= min_size)) stop_err("no gene set has min_size (", min_size, ") genes in the results; check species")

# ------------------------------------------------------------
# Step 2: GSEA per comparison and group
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: GSEA")
summary_rows <- list()
for (t in tabs) {
	comparison <- t$Comparison[1]
	groups <- unique(t$Group)
	num <- suppressWarnings(as.numeric(groups))
	groups <- if (all(!is.na(num))) groups[order(num)] else sort(groups)
	res <- list()
	for (g in groups) {
		d <- t[t$Group == g & !is.na(t$PValue) & !is.na(t$Log2FC), ]
		method <- if (nrow(d)) d$Method[1] else ""
		st <- ifelse(is.finite(d$Stat), d$Stat, sign(d$Log2FC) * -log10(pmax(d$PValue, 1e-300)))
		names(st) <- d$Gene
		st <- st[is.finite(st) & !duplicated(names(st))]
		row <- list(Comparison = comparison, Group = g, Method = method, Genes_ranked = length(st), Sets_tested = 0L, Up = 0L,
				Down = 0L, Status = "ok")
		if (length(st) < 2 * min_size) {
			row$Status <- "too_few_genes"
		} else {
			set.seed(seed)
			fg <- tryCatch(suppressWarnings(fgsea::fgseaMultilevel(sets, sort(st, decreasing = TRUE), minSize = min_size,
									maxSize = max_size, eps = 0)),
					error = function(e) {
						warn_msg(comparison, " group ", g, ": fgsea failed: ", conditionMessage(e))
						NULL
					})
			if (is.null(fg) || !nrow(fg)) {
				row$Status <- "no_set_tested"
			} else {
				le <- vapply(fg$leadingEdge, function(x) paste(head(x, 15), collapse = ","), character(1))
				r <- data.frame(Comparison = comparison, Group = g, Method = method, Set = fg$pathway, Size = fg$size,
						NES = round(fg$NES, 4), PValue = signif(fg$pval, 4), Padj = signif(fg$padj, 4), Leading_edge = le,
						stringsAsFactors = FALSE)
				res[[g]] <- r
				sig <- !is.na(r$Padj) & r$Padj < padj_cutoff
				row$Sets_tested <- nrow(r)
				row$Up <- sum(sig & r$NES > 0)
				row$Down <- sum(sig & r$NES < 0)
				if (method == "spot_level_wilcoxon") row$Status <- "ok_exploratory"
			}
		}
		summary_rows[[length(summary_rows) + 1]] <- as.data.frame(row, stringsAsFactors = FALSE)
		msg(sprintf("  %-22s group %-22s %-20s genes %6d  sets %4d  up %3d  down %3d  %s", comparison, g, method,
						row$Genes_ranked, row$Sets_tested, row$Up, row$Down, row$Status))
	}
	if (!length(res)) next
	all_res <- do.call(rbind, res)
	all_res <- all_res[order(all_res$Group, all_res$Padj), ]
	utils::write.table(all_res, file.path(gsea_dir, paste0("gsea_", comparison, ".tsv")), sep = "\t", quote = FALSE,
			row.names = FALSE, na = "NA")

	# NES heatmap: the sets with the smallest adjusted p over the groups.
	best <- tapply(all_res$Padj, all_res$Set, min, na.rm = TRUE)
	show <- head(names(sort(best)), top_sets)
	hm <- all_res[all_res$Set %in% show, ]
	hm$Group <- factor(hm$Group, levels = groups)
	hm$Set <- factor(hm$Set, levels = rev(show))
	hm$Sig <- !is.na(hm$Padj) & hm$Padj < padj_cutoff
	lim <- max(abs(hm$NES), na.rm = TRUE)
	p <- ggplot(hm, aes(Group, Set, fill = NES)) + geom_tile(colour = "white") +
			geom_point(data = hm[hm$Sig, ], size = 0.9) +
			scale_fill_gradient2(low = "#2166AC", mid = "white", high = "#B2182B", limits = c(-lim, lim), na.value = "grey92") +
			labs(title = paste0(sub("_vs_", " vs ", comparison), ": gene set enrichment (dot: padj < ", padj_cutoff, ")"),
					x = "Group", y = NULL) +
			theme_minimal(base_size = 9) + theme(axis.text.x = element_text(angle = 45, hjust = 1), panel.grid = element_blank())
	save_gg(p, paste0("gsea_nes_", comparison), max(6, 0.32 * length(groups) + 5), 0.18 * length(show) + 1.8)

	# Bar plot of the group with the most significant sets.
	sm <- do.call(rbind, summary_rows)
	sm <- sm[sm$Comparison == comparison & sm$Group %in% names(res), ]
	top_group <- sm$Group[which.max(sm$Up + sm$Down)]
	tg <- all_res[all_res$Group == top_group, ]
	tg <- tg[order(tg$Padj), ]
	tg <- head(tg, 20)
	tg$Set <- factor(tg$Set, levels = tg$Set[order(tg$NES)])
	p <- ggplot(tg, aes(NES, Set, fill = NES > 0)) + geom_col() +
			scale_fill_manual(values = c(`TRUE` = "#B2182B", `FALSE` = "#2166AC"), guide = "none") +
			geom_text(aes(label = ifelse(Padj < padj_cutoff, "*", "")), hjust = ifelse(tg$NES > 0, -0.3, 1.3)) +
			labs(title = paste0(sub("_vs_", " vs ", comparison), ", group ", top_group, " (*: padj < ", padj_cutoff, ")"),
					x = "NES (> 0: higher in the test condition)", y = NULL) +
			theme_bw(base_size = 9)
	save_gg(p, paste0("gsea_top_", comparison), 8, 0.22 * nrow(tg) + 1.6)
}
sm <- do.call(rbind, summary_rows)
utils::write.table(sm, file.path(summary_dir, "enrichment_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

msg("")
msg("############################## Summary")
msg("Groups with results: ", sum(grepl("^ok", sm$Status)), " of ", nrow(sm), "; significant sets (padj < ", padj_cutoff,
		"): up ", sum(sm$Up), ", down ", sum(sm$Down))
if (any(sm$Status == "ok_exploratory")) {
	warn_msg("groups tested spot by spot in spatial_condition_de (Method spot_level_wilcoxon) are exploratory: ",
			paste(unique(sm$Group[sm$Status == "ok_exploratory"]), collapse = ", "))
}
msg("")
msg("############################## Done")
msg("Summary: ", file.path(summary_dir, "enrichment_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
if (!any(grepl("^ok", sm$Status))) stop_err("no group could be tested; see ", file.path(summary_dir, "enrichment_summary.tsv"))
