#!/usr/bin/env Rscript
# CNV module: tumor purity, ploidy and allele-specific copy number with FACETS.
#
# Usage:
#   Rscript cnv_facets.1.0.R input_dir="..." sample_data="..." snp_vcf="..." output_dir="..."
#       [genome="hg38"] [cval="150"] [pre_cval="25"] [ndepth="35"] [snp_nbhd="250"]
#       [min_map_q="15"] [min_base_q="20"] [pseudo_snps="100"] [min_purity="0.2"]
#       [seed="1234"] [bam_suffix=""] [threads="auto"]
#
# Example:
#   apptainer exec bx_facets.1.0.sif Rscript cnv_facets.1.0.R \
#       input_dir="/data/bam" sample_data="/data/samples.csv" \
#       snp_vcf="/ref/dbsnp_common.vcf.gz" output_dir="/out/cnv_facets"
#
# Arguments (key=value):
#   input_dir    (required) - Directory with coordinate-sorted, duplicate-marked BAM files
#                             (searched recursively).
#   sample_data  (required) - Sample sheet (CSV) with SampleID (tumor) and NormalID
#                             (matched normal). Rows without NormalID are skipped.
#   snp_vcf      (required) - Common germline SNP sites (VCF, bgzip-compressed or plain),
#                             with the same chromosome names as the BAM files
#                             (for example dbSNP common).
#   output_dir   (required) - Output directory.
#   genome       (optional) - Genome build for FACETS: hg38 or hg19. default: hg38
#   cval         (optional) - Segmentation critical value of the main fit; larger
#                             gives fewer segments. default: 150
#   pre_cval     (optional) - Critical value of the pre-processing segmentation
#                             (used to find the diploid level). default: 25
#   ndepth       (optional) - Minimum normal depth for a SNP to be used. default: 35
#   snp_nbhd     (optional) - SNP window (bp) for thinning nearby SNPs; 250 suits
#                             exomes, larger values (for example 1000) suit WGS. default: 250
#   min_map_q    (optional) - Minimum mapping quality in snp-pileup. default: 15
#   min_base_q   (optional) - Minimum base quality in snp-pileup. default: 20
#   pseudo_snps  (optional) - snp-pileup adds a pseudo SNP every N bp so that
#                             coverage is measured between SNPs. default: 100
#   min_purity   (optional) - Fits with a lower (or undetermined) purity get the
#                             status low_purity. default: 0.2
#   seed         (optional) - Random seed (FACETS thins SNPs at random). default: 1234
#   bam_suffix   (optional) - Only BAM files whose name ends with this text are used.
#   threads      (optional) - auto uses the cores allocated to the job; pairs are
#                             piled up in parallel. default: auto
#
# Method:
#   1. snp-pileup counts reference and alternate reads of the normal and tumor
#      BAM at each SNP site (-g -q<min_map_q> -Q<min_base_q> -P<pseudo_snps> -r25,0).
#   2. FACETS: preProcSample (gbuild, ndepth, snp.nbhd, cval=pre_cval),
#      procSample (cval), emcncf: purity, ploidy, and per segment the total (tcn)
#      and minor (lcn) copy number and the cellular fraction.
#
# Outputs (output_dir):
#   01_pileup/<SampleID>.snp_pileup.csv.gz
#   02_segments/<SampleID>.facets_segments.tsv  chrom, start, end, num.mark, nhet,
#       cnlr.median, mafR, cf.em, tcn.em, lcn.em (chromosome names as in the BAM)
#   03_plots/<SampleID>.facets_cncf.pdf/.png      FACETS 4-panel plot
#            <SampleID>.allele_specific.pdf/.png  total and minor copy number, LOH shaded
#            <SampleID>.baf.pdf/.png              tumor B-allele frequency of
#                                                 heterozygous SNPs
#   04_summary/facets_summary.tsv  SampleID, NormalID, Status (ok, low_purity,
#       fit_failed, pileup_failed), Purity, Ploidy, DipLogR, Emflags, Segments,
#       SNPs, HetSNPs, LOH_fraction, FGA, WGD
#   logs/<stamp>.log (stdout), logs/<stamp>.error.log (stderr)
#
# A low or undetermined purity is a data result (status low_purity, exit 0);
# cnvkit_call then leaves that sample without purity correction. The run fails
# (exit 1) only when no pair could be fitted.
# The previous output_dir content except logs/ is removed at the start, so no
# input may be inside output_dir.

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
		input_dir = "", sample_data = "", snp_vcf = "", output_dir = "",
		genome = "hg38", cval = "150", pre_cval = "25", ndepth = "35", snp_nbhd = "250",
		min_map_q = "15", min_base_q = "20", pseudo_snps = "100", min_purity = "0.2",
		seed = "1234", bam_suffix = "", threads = "auto"
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
for (k in c("input_dir", "sample_data", "snp_vcf", "output_dir")) {
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
input_dir <- params$input_dir
output_dir <- params$output_dir
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
for (k in c("sample_data", "snp_vcf")) if (!file.exists(params[[k]])) stop_err(k, " not found: ", params[[k]])
genome <- params$genome
if (!genome %in% c("hg38", "hg19")) stop_err("genome must be hg38 or hg19: ", genome)
cval <- as_num("cval", 1)
pre_cval <- as_num("pre_cval", 1)
ndepth <- as_num("ndepth", 1, integer = TRUE)
snp_nbhd <- as_num("snp_nbhd", 0, integer = TRUE)
min_map_q <- as_num("min_map_q", 0, integer = TRUE)
min_base_q <- as_num("min_base_q", 0, integer = TRUE)
pseudo_snps <- as_num("pseudo_snps", 0, integer = TRUE)
min_purity <- as_num("min_purity", 0, 1)
seed <- as_num("seed", 0, integer = TRUE)

allocated_cores <- function() {
	n <- suppressWarnings(as.integer(tryCatch(system2("env", c("-u", "OMP_NUM_THREADS", "-u", "OMP_THREAD_LIMIT", "nproc"), stdout = TRUE, stderr = FALSE),
							error = function(e) NA)))
	if (length(n) != 1 || is.na(n) || n < 1) n <- max(1L, length(parallel::mcaffinity()))
	n
}
allocated <- allocated_cores()
if (params$threads == "auto") {
	threads <- allocated
} else {
	if (!grepl("^[0-9]+$", params$threads) || as.integer(params$threads) < 1) {
		stop_err("threads must be auto or a positive integer: ", params$threads)
	}
	threads <- min(as.integer(params$threads), allocated)
}

# output_dir is cleaned below, so it must not be / or hold an input.
out_norm <- normalizePath(output_dir, mustWork = FALSE)
if (out_norm == "/") stop_err("output_dir must not be /")
for (x in c(input_dir, params$sample_data, params$snp_vcf)) {
	inp <- normalizePath(x, mustWork = FALSE)
	if (inp == out_norm || startsWith(inp, paste0(out_norm, "/"))) {
		stop_err("input ", x, " is inside output_dir ", output_dir, ", which is cleaned at the start")
	}
}

# ------------------------------------------------------------
# Sample sheet and BAM files
# ------------------------------------------------------------
sheet <- tryCatch(utils::read.csv(params$sample_data, colClasses = "character", check.names = FALSE,
				strip.white = TRUE, fileEncoding = "UTF-8-BOM"),
		error = function(e) stop_err("cannot read sample_data: ", conditionMessage(e)))
names(sheet) <- trimws(names(sheet))
if (!all(c("SampleID", "NormalID") %in% names(sheet))) {
	stop_err("sample_data must have the columns SampleID and NormalID; found: ", paste(names(sheet), collapse = ", "))
}
sheet$SampleID <- trimws(sheet$SampleID)
sheet$NormalID <- trimws(ifelse(is.na(sheet$NormalID), "", sheet$NormalID))
if (any(!nzchar(sheet$SampleID))) stop_err("sample_data has an empty SampleID")
if (anyDuplicated(sheet$SampleID)) stop_err("sample_data has duplicate SampleID: ", sheet$SampleID[duplicated(sheet$SampleID)][1])
bad_id <- c(sheet$SampleID, sheet$NormalID[nzchar(sheet$NormalID)])
bad_id <- bad_id[!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", bad_id)]
if (length(bad_id)) stop_err("invalid ID in sample_data (use letters, digits, dot, underscore, hyphen): ", bad_id[1])
pairs <- sheet[nzchar(sheet$NormalID), c("SampleID", "NormalID")]
skipped <- sheet$SampleID[!nzchar(sheet$NormalID)]
if (nrow(pairs) == 0) {
	stop_err("no tumor-normal pair in sample_data (NormalID is empty in every row); ",
			"FACETS needs a matched normal. Use the tumor-only pipeline (cnvkit_call without facets_dir).")
}

bams <- list.files(input_dir, pattern = "\\.bam$", recursive = TRUE, full.names = TRUE)
if (nzchar(params$bam_suffix)) bams <- bams[endsWith(basename(bams), params$bam_suffix)]
# IDs hold only letters, digits, '.', '_' and '-', so only '.' needs escaping.
re_escape <- function(x) gsub(".", "\\.", x, fixed = TRUE)
find_bam <- function(id) {
	exact <- bams[grepl(paste0("^", re_escape(id), "([._-]|$)"), basename(bams))]
	hits <- if (length(exact)) exact else bams[grepl(paste0("(^|[._-])", re_escape(id), "([._-]|$)"), basename(bams))]
	if (length(hits) == 0) {
		emit_err(paste0("ERROR: No BAM file for ", id, " in ", input_dir,
						if (nzchar(params$bam_suffix)) paste0(" (bam_suffix=", params$bam_suffix, ")") else "", "\n",
						if (length(bams)) paste0("BAM files found:\n", paste0("  ", head(basename(bams), 20), collapse = "\n"), "\n")
						else "No BAM files were found.\n",
						"Tip: the BAM file name must start with the ID followed by '.', '_' or '-'.\n"))
		quit(status = 1)
	}
	if (length(hits) > 1) {
		emit_err(paste0("ERROR: Several BAM files match ", id, ":\n", paste0("  ", hits, collapse = "\n"), "\n",
						"Tip: set bam_suffix (for example bam_suffix=_marked.bam) to pick one.\n"))
		quit(status = 1)
	}
	hits
}
pairs$TumorBAM <- vapply(pairs$SampleID, find_bam, character(1))
pairs$NormalBAM <- vapply(pairs$NormalID, find_bam, character(1))

for (cmd in c("snp-pileup")) {
	if (!nzchar(Sys.which(cmd))) stop_err("required command not found in PATH: ", cmd)
}
for (pkg in c("facets", "parallel", "grDevices", "graphics")) {
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

pileup_dir <- file.path(output_dir, "01_pileup")
seg_dir <- file.path(output_dir, "02_segments")
plot_dir <- file.path(output_dir, "03_plots")
summary_dir <- file.path(output_dir, "04_summary")
for (d in c(pileup_dir, seg_dir, plot_dir, summary_dir)) dir.create(d, showWarnings = FALSE)

suppressPackageStartupMessages(library(facets))

msg("############################## cnv_facets")
msg("Log file       : ", log_file)
msg("Error log file : ", err_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
for (k in names(defaults)) {
	if (k == "threads") {
		msg(sprintf("  %-12s = %d (requested %s, allocated %d)", k, threads, params$threads, allocated))
	} else {
		msg(sprintf("  %-12s = %s", k, params[[k]]))
	}
}
msg("")
msg("FACETS ", as.character(utils::packageVersion("facets")), ", ", R.version.string)
msg("Tumor-normal pairs: ", nrow(pairs))
for (i in seq_len(nrow(pairs))) {
	msg("  ", pairs$SampleID[i], " (", pairs$TumorBAM[i], ") / ", pairs$NormalID[i], " (", pairs$NormalBAM[i], ")")
}
if (length(skipped)) warn_msg("samples without NormalID are skipped by FACETS: ", paste(skipped, collapse = ", "))

# ------------------------------------------------------------
# Step 1: snp-pileup (pairs in parallel)
# ------------------------------------------------------------
msg("")
msg("############################## Step 1: snp-pileup")
run_pileup <- function(i) {
	out <- file.path(pileup_dir, paste0(pairs$SampleID[i], ".snp_pileup.csv.gz"))
	so <- tempfile(tmpdir = pileup_dir, fileext = ".out")
	se <- tempfile(tmpdir = pileup_dir, fileext = ".err")
	args <- c("-g", paste0("-q", min_map_q), paste0("-Q", min_base_q), paste0("-P", pseudo_snps), "-r25,0",
			shQuote(params$snp_vcf), shQuote(out), shQuote(pairs$NormalBAM[i]), shQuote(pairs$TumorBAM[i]))
	t0 <- Sys.time()
	code <- system2("snp-pileup", args, stdout = so, stderr = se)
	list(code = code, out = out, so = so, se = se, args = args,
			secs = as.numeric(difftime(Sys.time(), t0, units = "secs")))
}
res <- parallel::mclapply(seq_len(nrow(pairs)), run_pileup, mc.cores = min(threads, nrow(pairs)),
		mc.preschedule = FALSE)
pairs$Status <- "ok"
for (i in seq_len(nrow(pairs))) {
	r <- res[[i]]
	if (inherits(r, "try-error")) {
		pairs$Status[i] <- "pileup_failed"
		warn_msg("snp-pileup failed for ", pairs$SampleID[i], ": ", as.character(r))
		next
	}
	msg("Command: snp-pileup ", paste(r$args, collapse = " "))
	if (file.exists(r$so)) msg(paste(readLines(r$so, warn = FALSE), collapse = "\n"))
	if (file.exists(r$se) && file.info(r$se)$size > 0) emit_err(paste0(paste(readLines(r$se, warn = FALSE), collapse = "\n"), "\n"))
	unlink(c(r$so, r$se))
	if (r$code != 0 || !file.exists(r$out)) {
		pairs$Status[i] <- "pileup_failed"
		warn_msg("snp-pileup failed for ", pairs$SampleID[i], " (exit code ", r$code, ")")
	} else {
		msg(sprintf("  %s: %.0f s, %.1f MB", pairs$SampleID[i], r$secs, file.info(r$out)$size / 1e6))
	}
}

# ------------------------------------------------------------
# Plots
# ------------------------------------------------------------
save_plot <- function(name, width, height, draw) {
	pdf(file.path(plot_dir, paste0(name, ".pdf")), width = width, height = height, useDingbats = FALSE)
	draw()
	invisible(dev.off())
	png_type <- if (isTRUE(capabilities("cairo"))) "cairo" else NULL
	png(file.path(plot_dir, paste0(name, ".png")), width = width, height = height, units = "in", res = 200,
			type = png_type)
	draw()
	invisible(dev.off())
}

chrom_label <- function(x) ifelse(x == 23, "X", ifelse(x == 24, "Y", as.character(x)))

genome_axis <- function(chrom, start, end) {
	lens <- tapply(end, chrom, max)
	lens <- lens[order(as.integer(names(lens)))]
	offset <- c(0, cumsum(as.numeric(lens)))[seq_along(lens)]
	names(offset) <- names(lens)
	list(offset = offset, lens = lens, total = sum(as.numeric(lens)))
}

draw_chrom_frame <- function(ax, ylim, ylab) {
	plot(NA, xlim = c(0, ax$total), ylim = ylim, xaxs = "i", xaxt = "n", xlab = "", ylab = ylab, las = 1, bty = "l")
	shade <- seq_along(ax$lens) %% 2 == 0
	rect(ax$offset[shade], ylim[1], ax$offset[shade] + ax$lens[shade], ylim[2], col = "#F2F2F2", border = NA)
	abline(v = ax$offset[-1], col = "#BBBBBB", lwd = 0.6)
	axis(1, at = ax$offset + ax$lens / 2, labels = chrom_label(as.integer(names(ax$lens))), tick = FALSE,
			cex.axis = 0.8, line = -0.5)
}

plot_allele_specific <- function(sid, cncf, purity, ploidy) {
	ax <- genome_axis(cncf$chrom, cncf$start, cncf$end)
	x0 <- ax$offset[as.character(cncf$chrom)] + cncf$start
	x1 <- ax$offset[as.character(cncf$chrom)] + cncf$end
	cap <- max(6, min(10, ceiling(max(cncf$tcn.em, na.rm = TRUE))))
	tcn <- pmin(cncf$tcn.em, cap)
	lcn <- pmin(cncf$lcn.em, cap)
	draw <- function() {
		par(mar = c(3, 4.5, 3, 1), mgp = c(2.6, 0.7, 0))
		draw_chrom_frame(ax, c(-0.3, cap + 0.5), "Copy number")
		loh <- !is.na(cncf$lcn.em) & cncf$lcn.em == 0 & cncf$tcn.em > 0
		rect(x0[loh], -0.3, x1[loh], cap + 0.5, col = adjustcolor("#CC79A7", 0.18), border = NA)
		abline(h = 0:cap, col = "#E3E3E3", lwd = 0.5)
		segments(x0, tcn + 0.06, x1, tcn + 0.06, col = "#222222", lwd = 3, lend = 1)
		segments(x0, lcn - 0.06, x1, lcn - 0.06, col = "#D55E00", lwd = 3, lend = 1)
		over <- cncf$tcn.em > cap
		if (any(over, na.rm = TRUE)) {
			text((x0[over] + x1[over]) / 2, cap + 0.3, labels = cncf$tcn.em[over], cex = 0.6, col = "#222222")
		}
		title(main = sprintf("%s   purity %s   ploidy %s", sid,
						ifelse(is.na(purity), "NA", sprintf("%.2f", purity)),
						ifelse(is.na(ploidy), "NA", sprintf("%.2f", ploidy))),
				cex.main = 1, font.main = 1, adj = 0)
		legend("topright", inset = c(0, -0.12), xpd = TRUE, horiz = TRUE, bty = "n", cex = 0.8,
				legend = c("Total CN", "Minor CN", "LOH"),
				col = c("#222222", "#D55E00", adjustcolor("#CC79A7", 0.45)),
				lwd = c(3, 3, NA), pch = c(NA, NA, 15), pt.cex = 1.8)
	}
	save_plot(paste0(sid, ".allele_specific"), 12, 4.2, draw)
}

plot_baf <- function(sid, jointseg) {
	het <- jointseg[!is.na(jointseg$het) & jointseg$het == 1, ]
	if (nrow(het) == 0) return(invisible(FALSE))
	ax <- genome_axis(jointseg$chrom, jointseg$maploc, jointseg$maploc)
	x <- ax$offset[as.character(het$chrom)] + het$maploc
	if (nrow(het) > 150000) {
		keep <- sort(sample.int(nrow(het), 150000))
		het <- het[keep, ]
		x <- x[keep]
	}
	draw <- function() {
		par(mar = c(3, 4.5, 2.5, 1), mgp = c(2.6, 0.7, 0))
		draw_chrom_frame(ax, c(0, 1), "Tumor BAF")
		abline(h = 0.5, col = "#999999", lty = 2)
		points(x, het$vafT, pch = 16, cex = 0.25, col = adjustcolor("#0072B2", 0.35))
		title(main = paste0(sid, "   B-allele frequency of heterozygous SNPs (n = ", nrow(het), ")"),
				cex.main = 1, font.main = 1, adj = 0)
	}
	save_plot(paste0(sid, ".baf"), 12, 3.6, draw)
}

# ------------------------------------------------------------
# Step 2: FACETS fit per pair
# ------------------------------------------------------------
msg("")
msg("############################## Step 2: FACETS fit")
summary_rows <- list()
for (i in seq_len(nrow(pairs))) {
	sid <- pairs$SampleID[i]
	msg("############################## Processing sample: ", sid)
	row <- list(SampleID = sid, NormalID = pairs$NormalID[i], Status = pairs$Status[i], Purity = NA, Ploidy = NA,
			DipLogR = NA, Emflags = "", Segments = NA, SNPs = NA, HetSNPs = NA, LOH_fraction = NA, FGA = NA, WGD = NA)
	if (pairs$Status[i] != "ok") {
		summary_rows[[sid]] <- row
		next
	}
	pileup <- file.path(pileup_dir, paste0(sid, ".snp_pileup.csv.gz"))
	fit_res <- tryCatch({
				set.seed(seed)
				rcmat <- facets::readSnpMatrix(pileup)
				chr_prefix <- grepl("^chr", as.character(rcmat$Chromosome[1]))
				xx <- facets::preProcSample(rcmat, gbuild = genome, ndepth = ndepth, snp.nbhd = snp_nbhd,
						cval = pre_cval)
				oo <- facets::procSample(xx, cval = cval)
				fit <- facets::emcncf(oo)
				list(xx = xx, oo = oo, fit = fit, prefix = chr_prefix)
			}, error = function(e) e)
	if (inherits(fit_res, "error")) {
		row$Status <- "fit_failed"
		warn_msg("FACETS fit failed for ", sid, ": ", conditionMessage(fit_res))
		summary_rows[[sid]] <- row
		next
	}
	fit <- fit_res$fit
	cncf <- fit$cncf
	purity <- if (is.null(fit$purity)) NA_real_ else fit$purity
	ploidy <- if (is.null(fit$ploidy)) NA_real_ else fit$ploidy
	emflags <- if (is.null(fit$emflags) || all(is.na(fit$emflags))) "" else paste(fit$emflags, collapse = "; ")

	# Segment table with the BAM chromosome names.
	seg_out <- cncf[, intersect(c("chrom", "start", "end", "num.mark", "nhet", "cnlr.median", "mafR",
							"cf.em", "tcn.em", "lcn.em"), names(cncf))]
	seg_out$chrom <- paste0(if (fit_res$prefix) "chr" else "", chrom_label(cncf$chrom))
	utils::write.table(seg_out, file.path(seg_dir, paste0(sid, ".facets_segments.tsv")), sep = "\t",
			quote = FALSE, row.names = FALSE)

	len <- as.numeric(cncf$end - cncf$start)
	ok <- !is.na(cncf$tcn.em)
	base_cn <- if (!is.na(ploidy) && ploidy >= 2.7) 4 else 2
	loh <- ok & !is.na(cncf$lcn.em) & cncf$lcn.em == 0 & cncf$tcn.em > 0
	major_ge2 <- ok & !is.na(cncf$lcn.em) & (cncf$tcn.em - cncf$lcn.em) >= 2
	row$Purity <- round(purity, 4)
	row$Ploidy <- round(ploidy, 4)
	row$DipLogR <- round(fit_res$oo$dipLogR, 4)
	row$Emflags <- emflags
	row$Segments <- nrow(cncf)
	row$SNPs <- nrow(fit_res$xx$jointseg)
	row$HetSNPs <- sum(fit_res$xx$jointseg$het == 1, na.rm = TRUE)
	row$LOH_fraction <- round(sum(len[loh]) / sum(len[ok]), 4)
	row$FGA <- round(sum(len[ok & cncf$tcn.em != base_cn]) / sum(len[ok]), 4)
	row$WGD <- if (sum(len[ok & !is.na(cncf$lcn.em)]) > 0 &&
					sum(len[major_ge2]) / sum(len[ok & !is.na(cncf$lcn.em)]) > 0.5) "yes" else "no"
	if (is.na(purity) || purity < min_purity) {
		row$Status <- "low_purity"
		warn_msg(sid, ": purity ", ifelse(is.na(purity), "could not be determined", sprintf("%.3f", purity)),
				" (below min_purity ", min_purity, "). Copy numbers of this sample are unreliable; ",
				"cnvkit_call will not use its purity.")
	}
	if (nzchar(emflags)) warn_msg(sid, ": FACETS flags: ", emflags)
	msg(sprintf("  purity=%s ploidy=%s dipLogR=%.3f segments=%d hetSNPs=%d LOH=%.3f WGD=%s status=%s",
					ifelse(is.na(purity), "NA", sprintf("%.3f", purity)), ifelse(is.na(ploidy), "NA", sprintf("%.3f", ploidy)),
					fit_res$oo$dipLogR, nrow(cncf), row$HetSNPs, row$LOH_fraction, row$WGD, row$Status))

	plot_res <- tryCatch({
				save_plot(paste0(sid, ".facets_cncf"), 10, 9, function() facets::plotSample(x = fit_res$oo, emfit = fit))
				plot_allele_specific(sid, cncf, purity, ploidy)
				plot_baf(sid, fit_res$xx$jointseg)
				TRUE
			}, error = function(e) e)
	if (inherits(plot_res, "error")) warn_msg("plots failed for ", sid, ": ", conditionMessage(plot_res))
	summary_rows[[sid]] <- row
}

summary_df <- do.call(rbind, lapply(summary_rows, function(r) as.data.frame(r, stringsAsFactors = FALSE)))
utils::write.table(summary_df, file.path(summary_dir, "facets_summary.tsv"), sep = "\t", quote = FALSE,
		row.names = FALSE, na = "NA")

# ------------------------------------------------------------
# Summary and exit code
# ------------------------------------------------------------
n_ok <- sum(summary_df$Status %in% c("ok", "low_purity"))
failed <- summary_df$SampleID[summary_df$Status %in% c("fit_failed", "pileup_failed")]
msg("")
msg("############################## Summary")
msg("Pairs: ", nrow(summary_df), ", fitted: ", n_ok, " (low_purity: ", sum(summary_df$Status == "low_purity"),
		"), failed: ", length(failed), ", skipped (no NormalID): ", length(skipped))
msg("")
msg("############################## Done")
msg("Summary: ", file.path(summary_dir, "facets_summary.tsv"))
msg("End time: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
if (n_ok == 0) {
	stop_err("all FACETS pairs failed: ", paste(failed, collapse = ", "), ". See the messages above.")
}
if (length(failed)) {
	warn_msg("some pairs failed: ", paste(failed, collapse = ", "), ". Check ", file.path(summary_dir, "facets_summary.tsv"))
}
