#!/usr/bin/env Rscript

# Usage:
#   Rscript functional_enrichment.1.0.R \
#     input_dir="..."            # peak_annotation output_dir, or gene_file="...",
#                                # or da_dir="..." / da_file="..." with genome_gff="..."
#     output_dir="..." \
#     orgdb_file="..."           # or go_table="..."
#     [gene_keytype="auto"] \
#     [ont="BP"] \
#     [max_distance_to_tss="3000"] \
#     [universe="auto"] \
#     [pvalue_cutoff="0.05"] \
#     [qvalue_cutoff="0.2"] \
#     [p_adjust_method="BH"] \
#     [min_gs_size="10"] \
#     [max_gs_size="500"] \
#     [min_mapped_fraction="0.5"] \
#     [show_category="20"] \
#     [da_norm="TMM"] [da_fdr="0.05"] [da_min_abs_logfc="0"]
#
# Arguments:
#   input_dir           (required*) - peak_annotation output_dir; every
#                                     gene_lists/*.annotated_gene_list.tsv is analysed
#   gene_file           (required*) - Alternative to input_dir: one gene list (TSV/CSV
#                                     with a geneId/gene_id/gene column, or one ID per line)
#   da_dir              (required*) - Alternative: differential_accessibility output_dir;
#                                     reads 03_results/diff_accessibility_<da_norm>.csv
#   da_file             (required*) - Alternative: one differential accessibility table
#                                     (CSV/TSV with seqnames or chr, start, end, logFC, FDR)
#   genome_gff          (required with da_dir/da_file) - GFF3/GTF (.gz allowed) used to
#                                     assign each peak to its nearest gene TSS
#   output_dir          (required)  - Output directory (cleaned except logs/ on each run)
#   orgdb_file          (required**) - OrgDb SQLite file saved by tools/download_orgdb.R
#   go_table            (required**) - Gene-to-GO table instead of an OrgDb: a GAF file,
#                                     or a TSV/CSV with gene and GO ID columns (optional
#                                     ontology column P/F/C or BP/MF/CC)
#   gene_keytype        (optional) - OrgDb key type of the gene IDs (TAIR, ENTREZID,
#                                    SYMBOL, ENSEMBL, GID, ...); auto picks the key type
#                                    that matches the most IDs, default: auto
#   ont                 (optional) - GO ontology: BP, MF, CC, or ALL, default: BP
#   max_distance_to_tss (optional) - Keep genes whose nearest peak is within this distance
#                                    of the TSS (bp); NA keeps all genes, default: 3000
#   universe            (optional) - Background genes: auto (input_dir's
#                                    gene_lists/txdb_gene_universe.tsv if present, else all
#                                    annotated genes), all, or a file of gene IDs, default: auto
#   pvalue_cutoff       (optional) - default: 0.05
#   qvalue_cutoff       (optional) - default: 0.2
#   p_adjust_method     (optional) - BH, bonferroni, holm, BY, fdr, none, default: BH
#   min_gs_size         (optional) - Minimum genes per GO term, default: 10
#   max_gs_size         (optional) - Maximum genes per GO term, default: 500
#   min_mapped_fraction (optional) - Stop if fewer input IDs than this fraction are found
#                                    in the annotation, default: 0.5
#   show_category       (optional) - GO terms shown in the plots, default: 20
#   da_norm             (optional) - With da_dir: TMM, EDASeq, or CQN result, default: TMM
#   da_fdr              (optional) - With da_dir/da_file: FDR cutoff for up/down peaks,
#                                    default: 0.05
#   da_min_abs_logfc    (optional) - With da_dir/da_file: minimum |logFC|, default: 0
#   * one of input_dir, gene_file, da_dir, or da_file;  ** one of orgdb_file or go_table
#
# With da_dir/da_file, two gene lists are analysed: <name>.up (peaks more
# accessible in the treated condition, logFC > 0) and <name>.down (logFC < 0);
# <name> is da_norm with da_dir and the file name with da_file.
# Each peak is assigned to the gene with the nearest TSS; max_distance_to_tss
# applies to that distance. universe=auto uses the genes nearest to all tested
# peaks (same distance filter).
#
# Outputs (output_dir):
#   01_gene_lists/  gene IDs used per list (after the distance filter); with da_dir/
#                   da_file also da_peak_to_gene.tsv (each peak, nearest gene, distance)
#   02_enrichment/  <list>.GO_<ont>.tsv (all tested terms with adjusted p-values)
#   03_plots/       <list>.GO_<ont>.dotplot.pdf and .barplot.pdf (significant terms)
#   04_summary/     enrichment_summary.tsv (genes, mapped fraction, significant terms)
#   logs/           <stamp>.log (stdout) and <stamp>.error.log (stderr)
#
# Notes:
#   - Runs offline: the OrgDb or GO table is read from a file; KEGG (online) is not used.
#   - Gene IDs are matched as given and, if needed, with a leading "gene:"/"gene-"
#     prefix and a trailing transcript/version suffix (".1") removed.

# Errors and warnings go to stderr and logs/<stamp>.error.log (err_con is
# opened together with the log file); progress goes to stdout and
# logs/<stamp>.log.
err_con <- NULL
emit_err <- function(txt) {
	cat(txt, file = stderr())
	if (!is.null(err_con)) {
		cat(txt, file = err_con)
		flush(err_con)
	}
}

stop_err <- function(...) {
	emit_err(paste0("ERROR: ", paste0(...), "\n"))
	quit(status = 1)
}

warn_msg <- function(...) {
	emit_err(paste0("WARNING: ", paste0(...), "\n"))
}

msg <- function(...) {
	cat(..., "\n")
}

# ------------------------------------------------------------
# Parse key=value arguments
# ------------------------------------------------------------
allowed_args <- c(
		"input_dir", "gene_file", "output_dir", "orgdb_file", "go_table", "gene_keytype",
		"ont", "max_distance_to_tss", "universe", "pvalue_cutoff", "qvalue_cutoff",
		"p_adjust_method", "min_gs_size", "max_gs_size", "min_mapped_fraction", "show_category",
		"da_dir", "da_file", "genome_gff", "da_norm", "da_fdr", "da_min_abs_logfc"
)

for (arg in commandArgs(TRUE)) {
	if (!grepl("=", arg, fixed = TRUE)) {
		stop_err("Invalid argument format: ", arg, " (must be key=value format)")
	}
	parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
	key <- parts[1]
	value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
	value <- sub('^"(.*)"$', "\\1", value)
	value <- sub("^'(.*)'$", "\\1", value)
	if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", key)) stop_err("Invalid key: ", key)
	if (!key %in% allowed_args) stop_err("Unknown parameter: ", key)
	assign(key, value)
}

defaults <- list(
		input_dir = "", gene_file = "", orgdb_file = "", go_table = "", gene_keytype = "auto",
		ont = "BP", max_distance_to_tss = "3000", universe = "auto", pvalue_cutoff = "0.05",
		qvalue_cutoff = "0.2", p_adjust_method = "BH", min_gs_size = "10", max_gs_size = "500",
		min_mapped_fraction = "0.5", show_category = "20", da_dir = "", da_file = "",
		genome_gff = "", da_norm = "TMM", da_fdr = "0.05", da_min_abs_logfc = "0"
)
for (k in names(defaults)) {
	if (!exists(k, inherits = FALSE) || !nzchar(get(k))) assign(k, defaults[[k]])
}

# ------------------------------------------------------------
# Required parameters and validation
# ------------------------------------------------------------
if (!exists("output_dir", inherits = FALSE) || !nzchar(output_dir)) {
	stop_err("Required parameter 'output_dir' is missing")
}
n_inputs <- sum(nzchar(c(input_dir, gene_file, da_dir, da_file)))
if (n_inputs == 0) stop_err("One of 'input_dir', 'gene_file', 'da_dir', or 'da_file' is required")
if (n_inputs > 1) stop_err("Give only one of 'input_dir', 'gene_file', 'da_dir', or 'da_file'")
da_mode <- nzchar(da_dir) || nzchar(da_file)
if (da_mode && !nzchar(genome_gff)) stop_err("genome_gff is required with da_dir or da_file")
if (!nzchar(orgdb_file) && !nzchar(go_table)) stop_err("One of 'orgdb_file' or 'go_table' is required")
if (nzchar(orgdb_file) && nzchar(go_table)) stop_err("Give only one of 'orgdb_file' or 'go_table'")

if (nzchar(input_dir) && !dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (nzchar(gene_file) && !file.exists(gene_file)) stop_err("gene_file not found: ", gene_file)
if (nzchar(da_dir) && !dir.exists(da_dir)) stop_err("da_dir not found: ", da_dir)
if (nzchar(da_file) && !file.exists(da_file)) stop_err("da_file not found: ", da_file)
if (nzchar(genome_gff) && !file.exists(genome_gff)) stop_err("genome_gff not found: ", genome_gff)
if (!da_norm %in% c("TMM", "EDASeq", "CQN")) stop_err("da_norm must be TMM, EDASeq, or CQN: ", da_norm)
if (nzchar(orgdb_file) && !file.exists(orgdb_file)) stop_err("orgdb_file not found: ", orgdb_file)
if (nzchar(go_table) && !file.exists(go_table)) stop_err("go_table not found: ", go_table)

ont <- toupper(ont)
if (!ont %in% c("BP", "MF", "CC", "ALL")) stop_err("ont must be BP, MF, CC, or ALL: ", ont)
if (!p_adjust_method %in% c("BH", "bonferroni", "holm", "hochberg", "hommel", "BY", "fdr", "none")) {
	stop_err("p_adjust_method is not supported: ", p_adjust_method)
}

as_num <- function(x, name, lo = -Inf, hi = Inf) {
	v <- suppressWarnings(as.numeric(x))
	if (is.na(v) || v < lo || v > hi) stop_err(name, " must be a number in [", lo, ", ", hi, "]: ", x)
	v
}
pvalue_cutoff <- as_num(pvalue_cutoff, "pvalue_cutoff", 0, 1)
qvalue_cutoff <- as_num(qvalue_cutoff, "qvalue_cutoff", 0, 1)
min_mapped_fraction <- as_num(min_mapped_fraction, "min_mapped_fraction", 0, 1)
min_gs_size <- as.integer(as_num(min_gs_size, "min_gs_size", 1))
max_gs_size <- as.integer(as_num(max_gs_size, "max_gs_size", 1))
show_category <- as.integer(as_num(show_category, "show_category", 1))
max_distance <- if (toupper(max_distance_to_tss) == "NA") NA_real_ else as_num(max_distance_to_tss, "max_distance_to_tss", 0)
da_fdr <- as_num(da_fdr, "da_fdr", 0, 1)
da_min_abs_logfc <- as_num(da_min_abs_logfc, "da_min_abs_logfc", 0)

# ------------------------------------------------------------
# output_dir is cleaned below, so it must not be or contain an input.
# ------------------------------------------------------------
check_inputs_outside_output <- function(output_dir, inputs) {
	out <- normalizePath(output_dir, mustWork = FALSE)
	for (x in inputs[nzchar(inputs)]) {
		inp <- normalizePath(x, mustWork = FALSE)
		if (inp == out || startsWith(inp, paste0(out, "/"))) {
			stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned on each run")
		}
	}
}
universe_file <- if (!universe %in% c("auto", "all")) universe else ""
check_inputs_outside_output(output_dir, c(input_dir, gene_file, da_dir, da_file, genome_gff,
				orgdb_file, go_table, universe_file))
if (nzchar(universe_file) && !file.exists(universe_file)) stop_err("universe file not found: ", universe_file)

# ------------------------------------------------------------
# Clean output directory first except logs/
# ------------------------------------------------------------
if (dir.exists(output_dir) && normalizePath(output_dir, mustWork = FALSE) != "/") {
	old <- list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)
	old <- old[basename(old) != "logs"]
	if (length(old) > 0) unlink(old, recursive = TRUE, force = TRUE)
}

dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
output_dir <- normalizePath(output_dir, mustWork = TRUE)
logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, recursive = TRUE, showWarnings = FALSE)

stamp <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
log_file <- file.path(logs_dir, paste0(stamp, ".log"))
err_file <- file.path(logs_dir, paste0(stamp, ".error.log"))
log_con <- file(log_file, open = "at")
err_con <- file(err_file, open = "at")
sink(log_con, append = TRUE, split = TRUE)

# Package messages and warnings (stderr) are also copied to the .error.log.
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

list_dir <- file.path(output_dir, "01_gene_lists")
enrich_dir <- file.path(output_dir, "02_enrichment")
plot_dir <- file.path(output_dir, "03_plots")
summary_dir <- file.path(output_dir, "04_summary")
for (d in c(list_dir, enrich_dir, plot_dir, summary_dir)) dir.create(d, showWarnings = FALSE)

msg("############################## Functional Enrichment (GO)")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
msg("  input_dir           = ", ifelse(nzchar(input_dir), input_dir, "<not used>"))
msg("  gene_file           = ", ifelse(nzchar(gene_file), gene_file, "<not used>"))
msg("  da_dir              = ", ifelse(nzchar(da_dir), da_dir, "<not used>"))
msg("  da_file             = ", ifelse(nzchar(da_file), da_file, "<not used>"))
if (da_mode) {
	msg("  genome_gff          = ", genome_gff)
	msg("  da_norm             = ", da_norm)
	msg("  da_fdr              = ", da_fdr)
	msg("  da_min_abs_logfc    = ", da_min_abs_logfc)
}
msg("  output_dir          = ", output_dir)
msg("  orgdb_file          = ", ifelse(nzchar(orgdb_file), orgdb_file, "<not used>"))
msg("  go_table            = ", ifelse(nzchar(go_table), go_table, "<not used>"))
msg("  gene_keytype        = ", gene_keytype)
msg("  ont                 = ", ont)
msg("  max_distance_to_tss = ", ifelse(is.na(max_distance), "NA (all genes)", max_distance))
msg("  universe            = ", universe)
msg("  pvalue_cutoff       = ", pvalue_cutoff)
msg("  qvalue_cutoff       = ", qvalue_cutoff)
msg("  p_adjust_method     = ", p_adjust_method)
msg("  min_gs_size         = ", min_gs_size)
msg("  max_gs_size         = ", max_gs_size)
msg("  min_mapped_fraction = ", min_mapped_fraction)
msg("  show_category       = ", show_category)
msg("")

# ------------------------------------------------------------
# Packages
# ------------------------------------------------------------
required_pkgs <- c("clusterProfiler", "AnnotationDbi", "GO.db", "enrichplot", "ggplot2")
for (pkg in required_pkgs) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}
suppressPackageStartupMessages({
	library(clusterProfiler)
	library(AnnotationDbi)
	library(enrichplot)
	library(ggplot2)
})
msg("clusterProfiler ", as.character(packageVersion("clusterProfiler")),
		" / GO.db ", as.character(packageVersion("GO.db")))
msg("")

# ------------------------------------------------------------
# Helpers
# ------------------------------------------------------------
# ID variants used for matching: as given, without a "gene:"/"gene-"
# prefix, and without a trailing ".<digits>" suffix.
id_variants <- function(ids) {
	no_prefix <- sub("^gene[:-]", "", ids)
	list(asis = ids, no_prefix = no_prefix, no_suffix = sub("\\.[0-9]+$", "", no_prefix))
}

read_gene_ids <- function(path, apply_distance = TRUE) {
	first <- readLines(path, n = 1, warn = FALSE)
	sep <- if (grepl("\t", first)) "\t" else if (grepl(",", first)) "," else ""
	if (sep == "") {
		ids <- trimws(readLines(path, warn = FALSE))
		# A one-column file may start with a header line.
		ids <- ids[nzchar(ids) & !ids %in% c("geneId", "gene_id", "gene", "GeneID", "Gene")]
		return(unique(ids))
	}
	df <- read.table(path, sep = sep, header = TRUE, quote = "", comment.char = "",
			stringsAsFactors = FALSE, check.names = FALSE)
	col <- intersect(c("geneId", "gene_id", "gene", "GeneID", "Gene"), colnames(df))[1]
	if (is.na(col)) col <- colnames(df)[1]
	if (apply_distance && !is.na(max_distance) && "min_distance_to_tss" %in% colnames(df)) {
		d <- suppressWarnings(as.numeric(df$min_distance_to_tss))
		df <- df[!is.na(d) & d <= max_distance, , drop = FALSE]
	}
	ids <- trimws(as.character(df[[col]]))
	unique(ids[!is.na(ids) & nzchar(ids)])
}

# Gene TSS positions from a GFF3 or GTF file (.gz allowed). Uses "gene"
# features (e.g. gene, ncRNA_gene); if there are none, gene spans are taken
# from transcript/exon rows grouped by gene_id.
read_gene_tss <- function(path) {
	con <- if (grepl("\\.gz$", path)) gzfile(path) else file(path)
	gff <- read.delim(con, header = FALSE, comment.char = "#", quote = "",
			stringsAsFactors = FALSE, colClasses = "character")
	if (ncol(gff) < 9) stop_err("genome_gff needs 9 tab-separated columns: ", path)
	get_attr <- function(attr, key) {
		v <- rep(NA_character_, length(attr))
		m <- regmatches(attr, regexec(paste0("(^|;)\\s*", key, "[= ]\"?([^;\"]+)"), attr))
		hit <- lengths(m) == 3
		v[hit] <- vapply(m[hit], `[`, character(1), 3)
		v
	}
	genes <- gff[grepl("gene$", gff[[3]], ignore.case = TRUE) & !grepl("^pseudogene$", gff[[3]]), ]
	if (nrow(genes) > 0) {
		id <- get_attr(genes[[9]], "ID")
		id[is.na(id)] <- get_attr(genes[[9]][is.na(id)], "gene_id")
		df <- data.frame(chr = genes[[1]], start = as.numeric(genes[[4]]), end = as.numeric(genes[[5]]),
				strand = genes[[7]], gene = id, stringsAsFactors = FALSE)
	} else {
		tx <- gff[gff[[3]] %in% c("transcript", "mRNA", "exon"), ]
		id <- get_attr(tx[[9]], "gene_id")
		tx <- tx[!is.na(id), ]
		id <- id[!is.na(id)]
		if (length(id) == 0) stop_err("genome_gff has no gene features and no gene_id attributes: ", path)
		key <- paste(id, tx[[1]], tx[[7]], sep = "\t")
		df <- data.frame(
				chr = tapply(tx[[1]], key, `[`, 1), start = tapply(as.numeric(tx[[4]]), key, min),
				end = tapply(as.numeric(tx[[5]]), key, max), strand = tapply(tx[[7]], key, `[`, 1),
				gene = tapply(id, key, `[`, 1), stringsAsFactors = FALSE)
	}
	df <- df[!is.na(df$gene) & nzchar(df$gene), ]
	df$gene <- sub("^gene[:-]", "", df$gene)
	df$tss <- ifelse(df$strand == "-", df$end, df$start)
	unique(df[, c("chr", "tss", "gene")])
}

# Nearest gene TSS for each peak; distance is 0 when the TSS lies in the peak.
nearest_gene <- function(peaks, tss) {
	out <- data.frame(gene = rep(NA_character_, nrow(peaks)), distance_to_tss = NA_real_,
			stringsAsFactors = FALSE)
	for (chr in intersect(unique(peaks$chr), unique(tss$chr))) {
		ip <- which(peaks$chr == chr)
		t <- tss[tss$chr == chr, ]
		t <- t[order(t$tss), ]
		mid <- (peaks$start[ip] + peaks$end[ip]) / 2
		j <- findInterval(mid, t$tss)
		left <- pmax(j, 1)
		right <- pmin(j + 1, nrow(t))
		pick <- ifelse(abs(t$tss[left] - mid) <= abs(t$tss[right] - mid), left, right)
		tp <- t$tss[pick]
		d <- ifelse(tp >= peaks$start[ip] & tp <= peaks$end[ip], 0,
				pmin(abs(peaks$start[ip] - tp), abs(peaks$end[ip] - tp)))
		out$gene[ip] <- t$gene[pick]
		out$distance_to_tss[ip] <- d
	}
	out
}

read_da_table <- function(path) {
	first <- readLines(path, n = 1, warn = FALSE)
	sep <- if (grepl("\t", first)) "\t" else ","
	df <- read.table(path, sep = sep, header = TRUE, quote = "\"", comment.char = "",
			stringsAsFactors = FALSE, check.names = FALSE)
	chr_col <- intersect(c("seqnames", "chr", "Chr", "chrom", "seqname"), names(df))[1]
	if (is.na(chr_col) || !all(c("start", "end", "logFC", "FDR") %in% names(df))) {
		stop_err("DA table needs seqnames (or chr), start, end, logFC, and FDR columns: ", path)
	}
	data.frame(chr = as.character(df[[chr_col]]), start = as.numeric(df$start), end = as.numeric(df$end),
			peak_id = if ("peakID" %in% names(df)) df$peakID else if ("peak_id" %in% names(df)) df$peak_id else
						paste0(df[[chr_col]], ":", df$start, "-", df$end),
			logFC = suppressWarnings(as.numeric(df$logFC)), FDR = suppressWarnings(as.numeric(df$FDR)),
			stringsAsFactors = FALSE)
}

# ------------------------------------------------------------
# Step 1: Gene lists
# ------------------------------------------------------------
msg("############################## Step 1: Read gene lists")

gene_lists <- list()
da_universe <- NULL
if (da_mode) {
	da_path <- if (nzchar(da_file)) da_file else
				file.path(da_dir, "03_results", paste0("diff_accessibility_", da_norm, ".csv"))
	if (!file.exists(da_path)) {
		stop_err("DA result not found: ", da_path, " (da_dir must be a differential_accessibility output_dir;",
				" EDASeq/CQN results exist only when that run had run_edaseq/run_cqn=TRUE)")
	}
	da <- read_da_table(da_path)
	msg("DA table: ", da_path, " (", nrow(da), " peaks)")
	if (all(is.na(da$FDR))) {
		stop_err("DA table has no FDR values (the differential_accessibility run had no replicates); ",
				"up/down peaks cannot be selected")
	}
	tss <- read_gene_tss(genome_gff)
	msg("genome_gff: ", nrow(tss), " gene TSS positions on ", length(unique(tss$chr)), " sequences")
	if (length(intersect(da$chr, tss$chr)) == 0) {
		# Try the other chromosome naming style (chr1 <-> 1).
		alt <- ifelse(grepl("^chr", tss$chr), sub("^chr", "", tss$chr), paste0("chr", tss$chr))
		if (length(intersect(da$chr, alt)) > 0) {
			tss$chr <- alt
			msg("chromosome names in genome_gff adjusted to match the DA table (chr prefix)")
		} else {
			stop_err("No common chromosome names between the DA table and genome_gff. DA: ",
					paste(head(unique(da$chr), 5), collapse = ","), " / GFF: ",
					paste(head(unique(tss$chr), 5), collapse = ","))
		}
	}
	near <- nearest_gene(da, tss)
	da <- cbind(da, near)
	da$status <- ifelse(!is.na(da$FDR) & da$FDR <= da_fdr & !is.na(da$logFC) & abs(da$logFC) >= da_min_abs_logfc,
			ifelse(da$logFC > 0, "up", ifelse(da$logFC < 0, "down", "not_significant")), "not_significant")
	write.table(da, file.path(list_dir, "da_peak_to_gene.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)
	keep <- !is.na(da$gene) & (is.na(max_distance) | da$distance_to_tss <= max_distance)
	msg("peaks with a gene within max_distance_to_tss: ", sum(keep), " of ", nrow(da))
	msg("significant peaks: up ", sum(da$status == "up"), ", down ", sum(da$status == "down"),
			" (FDR <= ", da_fdr, ", |logFC| >= ", da_min_abs_logfc, ")")
	list_prefix <- if (nzchar(da_file)) sub("\\.(csv|tsv|txt)$", "", basename(da_file), ignore.case = TRUE) else da_norm
	for (dir_name in c("up", "down")) {
		gene_lists[[paste0(list_prefix, ".", dir_name)]] <- unique(da$gene[keep & da$status == dir_name])
	}
	da_universe <- unique(da$gene[keep])
} else if (nzchar(gene_file)) {
	nm <- sub("\\.(tsv|csv|txt)$", "", basename(gene_file), ignore.case = TRUE)
	gene_lists[[nm]] <- read_gene_ids(gene_file)
} else {
	files <- list.files(file.path(input_dir, "gene_lists"), pattern = "\\.annotated_gene_list\\.tsv$",
			full.names = TRUE)
	if (length(files) == 0) {
		stop_err("No gene_lists/*.annotated_gene_list.tsv in input_dir: ", input_dir,
				" (input_dir must be a peak_annotation output_dir)")
	}
	for (f in sort(files)) {
		gene_lists[[sub("\\.annotated_gene_list\\.tsv$", "", basename(f))]] <- read_gene_ids(f)
	}
}

for (nm in names(gene_lists)) {
	msg("  ", nm, ": ", length(gene_lists[[nm]]), " genes")
	writeLines(gene_lists[[nm]], file.path(list_dir, paste0(nm, ".genes.txt")))
}
empty_lists <- names(gene_lists)[lengths(gene_lists) == 0]
if (length(empty_lists) > 0) warn_msg("empty gene list(s) skipped: ", paste(empty_lists, collapse = ", "))
gene_lists <- gene_lists[lengths(gene_lists) > 0]
if (length(gene_lists) == 0) stop_err("All gene lists are empty after the distance filter")
msg("")

universe_ids <- NULL
if (universe == "auto" && da_mode) {
	universe_ids <- da_universe
} else if (universe == "auto" && nzchar(input_dir)) {
	uf <- file.path(input_dir, "gene_lists", "txdb_gene_universe.tsv")
	if (file.exists(uf)) universe_ids <- read_gene_ids(uf, apply_distance = FALSE)
} else if (nzchar(universe_file)) {
	universe_ids <- read_gene_ids(universe_file, apply_distance = FALSE)
}
msg("universe: ", if (is.null(universe_ids)) "all annotated genes" else paste(length(universe_ids), "genes"))
msg("")

# ------------------------------------------------------------
# Step 2: Annotation source and ID mapping
# ------------------------------------------------------------
msg("############################## Step 2: Annotation source")

all_ids <- unique(c(unlist(gene_lists), universe_ids))
variants <- id_variants(all_ids)

if (nzchar(orgdb_file)) {
	orgdb <- AnnotationDbi::loadDb(orgdb_file)
	msg("OrgDb: ", orgdb_file)
	available <- AnnotationDbi::keytypes(orgdb)
	msg("keytypes: ", paste(available, collapse = ", "))
	candidates <- if (gene_keytype == "auto") {
		intersect(c("TAIR", "ENSEMBL", "GID", "ENTREZID", "SYMBOL", "REFSEQ", "ORF", "FLYBASE",
						"WORMBASE", "SGD", "ZFIN", "MGI", "RGD", "ALIAS"), available)
	} else {
		if (!gene_keytype %in% available) stop_err("gene_keytype ", gene_keytype, " is not in the OrgDb")
		gene_keytype
	}
	best <- list(n = -1)
	for (kt in candidates) {
		keys_kt <- tryCatch(AnnotationDbi::keys(orgdb, keytype = kt), error = function(e) character(0))
		for (vn in names(variants)) {
			n <- sum(variants[[vn]] %in% keys_kt)
			msg(sprintf("  match %-9s / %-9s : %d of %d", kt, vn, n, length(all_ids)))
			if (n > best$n) best <- list(n = n, keytype = kt, variant = vn)
		}
	}
	msg("")
	mapped_fraction <- best$n / length(all_ids)
	if (best$n <= 0 || mapped_fraction < min_mapped_fraction) {
		stop_err("Only ", max(best$n, 0), " of ", length(all_ids), " gene IDs (",
				round(100 * max(mapped_fraction, 0), 1), "%) were found in the OrgDb. ",
				"Check that the OrgDb is for the same species and ID type as genome_gff, ",
				"or use go_table with a gene-to-GO table that uses the same gene IDs.")
	}
	msg("using keytype ", best$keytype, " with IDs ", best$variant, " (",
			round(100 * mapped_fraction, 1), "% of IDs found)")
	keytype_used <- best$keytype
	id_mode <- best$variant
} else {
	msg("GO table: ", go_table)
	head_line <- readLines(go_table, n = 50, warn = FALSE)
	is_gaf <- grepl("\\.gaf(\\.gz)?$", go_table, ignore.case = TRUE) || any(startsWith(head_line, "!gaf"))
	if (is_gaf) {
		gaf <- read.delim(go_table, header = FALSE, comment.char = "!", quote = "",
				stringsAsFactors = FALSE)
		if (ncol(gaf) < 9) stop_err("GAF file needs at least 9 columns: ", go_table)
		term2gene <- data.frame(term = gaf[[5]], gene = gaf[[2]], aspect = gaf[[9]], stringsAsFactors = FALSE)
		# Also accept the gene symbol column (3) as an ID.
		term2gene <- unique(rbind(term2gene,
						data.frame(term = gaf[[5]], gene = gaf[[3]], aspect = gaf[[9]], stringsAsFactors = FALSE)))
	} else {
		sep <- if (grepl("\t", head_line[1])) "\t" else ","
		tab <- read.table(go_table, sep = sep, header = TRUE, quote = "", comment.char = "",
				stringsAsFactors = FALSE, check.names = FALSE)
		go_col <- names(tab)[vapply(tab, function(v) mean(grepl("^GO:[0-9]{7}$", v)) > 0.8, logical(1))][1]
		if (is.na(go_col)) stop_err("go_table has no column of GO IDs (GO:0000000): ", go_table)
		gene_col <- setdiff(intersect(c("gene_id", "geneId", "gene", "Gene stable ID", "GeneID", "Gene"), names(tab)), go_col)[1]
		if (is.na(gene_col)) gene_col <- setdiff(names(tab), go_col)[1]
		ont_col <- intersect(c("ontology", "Ontology", "aspect", "namespace", "GO domain"), names(tab))[1]
		term2gene <- data.frame(term = tab[[go_col]], gene = tab[[gene_col]],
				aspect = if (is.na(ont_col)) NA_character_ else tab[[ont_col]], stringsAsFactors = FALSE)
		msg("columns: gene = ", gene_col, ", GO = ", go_col, ", ontology = ", ifelse(is.na(ont_col), "<from GO.db>", ont_col))
	}
	term2gene <- term2gene[grepl("^GO:", term2gene$term) & nzchar(term2gene$gene), ]
	# Ontology per term: from the table (P/F/C or names) or from GO.db.
	asp <- toupper(as.character(term2gene$aspect))
	asp <- ifelse(asp %in% c("P", "BIOLOGICAL_PROCESS", "BIOLOGICAL PROCESS"), "BP",
			ifelse(asp %in% c("F", "MOLECULAR_FUNCTION", "MOLECULAR FUNCTION"), "MF",
					ifelse(asp %in% c("C", "CELLULAR_COMPONENT", "CELLULAR COMPONENT"), "CC", asp)))
	missing_asp <- is.na(asp) | !asp %in% c("BP", "MF", "CC")
	if (any(missing_asp)) {
		asp[missing_asp] <- suppressWarnings(AnnotationDbi::Ontology(term2gene$term[missing_asp]))
	}
	term2gene$ont <- asp
	if (ont != "ALL") term2gene <- term2gene[!is.na(term2gene$ont) & term2gene$ont == ont, ]
	if (nrow(term2gene) == 0) stop_err("go_table has no GO annotations for ont=", ont)
	term_names <- suppressWarnings(AnnotationDbi::Term(unique(term2gene$term)))
	term2name <- data.frame(term = names(term_names), name = unname(term_names), stringsAsFactors = FALSE)
	msg("GO annotations: ", nrow(term2gene), " gene-term pairs, ", length(unique(term2gene$term)), " terms")

	table_genes <- unique(term2gene$gene)
	best <- list(n = -1)
	for (vn in names(variants)) {
		n <- sum(variants[[vn]] %in% table_genes)
		msg(sprintf("  match %-9s : %d of %d", vn, n, length(all_ids)))
		if (n > best$n) best <- list(n = n, variant = vn)
	}
	msg("")
	mapped_fraction <- best$n / length(all_ids)
	if (best$n <= 0 || mapped_fraction < min_mapped_fraction) {
		stop_err("Only ", max(best$n, 0), " of ", length(all_ids), " gene IDs (",
				round(100 * max(mapped_fraction, 0), 1), "%) were found in go_table. ",
				"Check that the table uses the same gene IDs as genome_gff.")
	}
	msg("using IDs ", best$variant, " (", round(100 * mapped_fraction, 1), "% of IDs found)")
	keytype_used <- "go_table"
	id_mode <- best$variant
}
msg("")

convert_ids <- function(ids) id_variants(ids)[[id_mode]]
if (!is.null(universe_ids)) universe_ids <- unique(convert_ids(universe_ids))

# ------------------------------------------------------------
# Step 3: Enrichment per gene list
# ------------------------------------------------------------
summary_rows <- list()

for (nm in names(gene_lists)) {
	msg("############################## Processing gene list: ", nm)
	genes <- unique(convert_ids(gene_lists[[nm]]))
	tag <- paste0(nm, ".GO_", ont)
	res <- tryCatch({
		if (keytype_used == "go_table") {
			clusterProfiler::enricher(
					gene = genes, TERM2GENE = term2gene[, c("term", "gene")], TERM2NAME = term2name,
					universe = universe_ids, pvalueCutoff = 1, qvalueCutoff = 1,
					pAdjustMethod = p_adjust_method, minGSSize = min_gs_size, maxGSSize = max_gs_size
			)
		} else {
			clusterProfiler::enrichGO(
					gene = genes, OrgDb = orgdb, keyType = keytype_used, ont = ont,
					universe = universe_ids, pvalueCutoff = 1, qvalueCutoff = 1,
					pAdjustMethod = p_adjust_method, minGSSize = min_gs_size, maxGSSize = max_gs_size
			)
		}
	}, error = function(e) {
		warn_msg(nm, ": enrichment failed: ", conditionMessage(e))
		NULL
	})

	n_tested <- 0
	n_sig <- 0
	status <- "failed"
	if (!is.null(res)) {
		tab <- as.data.frame(res)
		n_tested <- nrow(tab)
		write.table(tab, file.path(enrich_dir, paste0(tag, ".tsv")), sep = "\t", quote = FALSE, row.names = FALSE)
		sig <- tab[tab$p.adjust <= pvalue_cutoff & (is.na(tab$qvalue) | tab$qvalue <= qvalue_cutoff), ]
		n_sig <- nrow(sig)
		status <- "done"
		msg("  genes: ", length(genes), " / terms tested: ", n_tested, " / significant: ", n_sig)
		if (n_sig > 0) {
			res_sig <- res
			res_sig@result <- res@result[res@result$ID %in% sig$ID, , drop = FALSE]
			res_sig@pvalueCutoff <- 1
			res_sig@qvalueCutoff <- 1
			for (kind in c("dotplot", "barplot")) {
				pdf_file <- file.path(plot_dir, paste0(tag, ".", kind, ".pdf"))
				ok <- tryCatch({
					p <- if (kind == "dotplot") {
								enrichplot::dotplot(res_sig, showCategory = show_category)
							} else {
								# enrichplot's barplot passes by= to ggplot2 4.x, which only
								# warns that the argument is unused; drop that one warning.
								withCallingHandlers(
										graphics::barplot(res_sig, showCategory = show_category),
										warning = function(w) {
											if (grepl("must be used", conditionMessage(w))) invokeRestart("muffleWarning")
										}
								)
							}
					p <- p + ggplot2::ggtitle(paste0(nm, " (GO ", ont, ")"))
					ggplot2::ggsave(pdf_file, p, width = 8, height = 6 + 0.15 * min(n_sig, show_category))
					TRUE
				}, error = function(e) {
					warn_msg(nm, ": ", kind, " failed: ", conditionMessage(e))
					FALSE
				})
				if (ok) msg("  plot: ", pdf_file)
			}
		} else {
			warn_msg(nm, ": no GO term passed p.adjust <= ", pvalue_cutoff, " and qvalue <= ", qvalue_cutoff)
		}
	}
	summary_rows[[nm]] <- data.frame(
			gene_list = nm, genes = length(gene_lists[[nm]]),
			genes_annotated = if (keytype_used == "go_table") sum(genes %in% term2gene$gene) else
						sum(genes %in% AnnotationDbi::keys(orgdb, keytype = keytype_used)),
			terms_tested = n_tested, significant_terms = n_sig, ont = ont,
			annotation = ifelse(nzchar(orgdb_file), basename(orgdb_file), basename(go_table)),
			keytype = keytype_used, status = status, stringsAsFactors = FALSE
	)
	msg("")
}

summary_df <- do.call(rbind, summary_rows)
write.table(summary_df, file.path(summary_dir, "enrichment_summary.tsv"), sep = "\t", quote = FALSE, row.names = FALSE)

n_done <- sum(summary_df$status == "done")
n_failed <- sum(summary_df$status == "failed")

msg("############################## Summary")
msg("  gene lists         : ", nrow(summary_df))
msg("  analysed           : ", n_done)
msg("  failed             : ", n_failed)
msg("  with significant GO: ", sum(summary_df$significant_terms > 0))
msg("")
msg("############################## Done")
msg("summary    = ", file.path(summary_dir, "enrichment_summary.tsv"))
msg("output_dir = ", output_dir)
msg("End time   = ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))

if (n_done == 0) stop_err("enrichment failed for all gene lists")
if (n_failed > 0) warn_msg(n_failed, " gene list(s) failed. Check the error log: ", err_file)
