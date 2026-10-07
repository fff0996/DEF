#!/usr/bin/env Rscript

# Usage:
# Rscript ATAC_QC_plot.R \
#   input_dir="..." \
#   tss_bed="..." \
#   output_dir="..." \
#   [upstream="1010"] \
#   [downstream="1010"] \
#   [ntile="101"] \
#   [tss_filter="0.5"] \
#   [harmonize_mode="auto"]
#
# input_dir:
#   ATAC_QC output directory
#
# Required:
#   input_dir/05_metadata/atac_qc_manifest.tsv
#   (legacy: input_dir/04_metadata/atac_qc_manifest.tsv)
#
# harmonize_mode:
#   "auto"   = if tss_bed seqnames disagree with the BAM-side seqnames
#              recorded in the manifest, rename tss_bed in-memory.
#              Renames are logged and recorded in summary.
#   "strict" = if tss_bed seqnames disagree, fail with a diagnostic.
#
# Notes:
#   - Does NOT require genome_fasta. Splitting was done in ATAC_QC.R
#     and this module only operates on pre-computed split BAMs.
#   - If ATAC_QC was run without genome_fasta, split BAMs do not exist
#     and those samples are skipped cleanly.
#   - A class whose split BAM is empty (e.g. no trinucleosome fragments
#     when long fragments were not kept as proper pairs, so ATAC_QC marks
#     the sample "empty_split:trinucleosome") is left out of the plots.
#     A sample is skipped only if NucleosomeFree or mononucleosome is
#     empty or missing. Used and dropped classes are logged and written
#     to the summary tables.
#
# NOTE on namespaces:
#   These functions look like they all belong to ATACseqQC because the
#   ATACseqQC vignette uses them after attaching both ATACseqQC and
#   ChIPpeakAnno. With explicit :: prefixes the distinction matters:
#     ChIPpeakAnno::estLibSize
#     ATACseqQC::enrichedFragments
#     ChIPpeakAnno::featureAlignedHeatmap
#     ChIPpeakAnno::featureAlignedDistribution
#     ChIPpeakAnno::reCenterPeaks
#   Mixing them up yields:
#     "X is not an exported object from 'namespace:Y'"

stop_err <- function(...) {
	cat("ERROR:", paste(..., collapse = ""), "\n", file = stderr())
	quit(status = 1)
}

warn_msg <- function(...) {
	cat("WARNING:", paste(..., collapse = ""), "\n")
}

msg <- function(...) {
	cat(..., "\n")
}

# ------------------------------------------------------------
# Parse key=value args
# ------------------------------------------------------------
args <- commandArgs(TRUE)

for (arg in args) {
	if (!grepl("=", arg, fixed = TRUE)) {
		stop_err("Invalid argument format: ", arg, " / must be key=value")
	}
	
	parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
	key <- parts[1]
	value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
	
	value <- sub('^"(.*)"$', "\\1", value)
	value <- sub("^'(.*)'$", "\\1", value)
	
	if (!grepl("^[A-Za-z_][A-Za-z0-9_]*$", key)) {
		stop_err("Invalid key: ", key)
	}
	
	assign(key, value)
}

required_args <- c("input_dir", "tss_bed", "output_dir")

for (x in required_args) {
	if (!exists(x)) {
		stop_err("Required parameter missing: ", x)
	}
}

if (!exists("upstream")) upstream <- "1010"
if (!exists("downstream")) downstream <- "1010"
if (!exists("ntile")) ntile <- "101"
if (!exists("tss_filter")) tss_filter <- "0.5"
if (!exists("harmonize_mode")) harmonize_mode <- "auto"

if (!harmonize_mode %in% c("auto", "strict")) {
	stop_err("harmonize_mode must be 'auto' or 'strict', got: ", harmonize_mode)
}

if (exists("genome_fasta") && nzchar(genome_fasta)) {
	warn_msg("genome_fasta argument is ignored by ATAC_QC_plot (only used by ATAC_QC).")
}

upstream <- as.integer(upstream)
downstream <- as.integer(downstream)
ntile <- as.integer(ntile)
tss_filter <- as.numeric(tss_filter)

if (is.na(upstream) || upstream < 1) stop_err("upstream must be positive integer")
if (is.na(downstream) || downstream < 1) stop_err("downstream must be positive integer")
if (is.na(ntile) || ntile < 1) stop_err("ntile must be positive integer")
if (is.na(tss_filter)) stop_err("tss_filter must be numeric")

# ------------------------------------------------------------
# Validate paths
# ------------------------------------------------------------
if (!dir.exists(input_dir)) stop_err("input_dir not found: ", input_dir)
if (!file.exists(tss_bed)) stop_err("tss_bed not found: ", tss_bed)

input_dir <- normalizePath(input_dir, mustWork = TRUE)
tss_bed <- normalizePath(tss_bed, mustWork = TRUE)

manifest_candidates <- c(
		file.path(input_dir, "05_metadata", "atac_qc_manifest.tsv"),
		file.path(input_dir, "04_metadata", "atac_qc_manifest.tsv")
)

manifest_file <- manifest_candidates[file.exists(manifest_candidates)][1]

if (is.na(manifest_file)) {
	stop_err(
			"ATAC_QC manifest not found. Tried:\n",
			paste(manifest_candidates, collapse = "\n")
	)
}

# ------------------------------------------------------------
# Clean output except logs/
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

log_file <- file.path(
		logs_dir,
		paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid(), ".log")
)

log_con <- file(log_file, open = "at")
sink(log_con, append = TRUE, split = TRUE)

on.exit({
			try(sink(), silent = TRUE)
			try(close(log_con), silent = TRUE)
		}, add = TRUE)

msg("############################## ATAC_QC_plot")
msg("Log file       : ", log_file)
msg("Start time     : ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))
msg("")
msg("parameters:")
msg("  input_dir       = ", input_dir)
msg("  manifest_file   = ", manifest_file)
msg("  tss_bed         = ", tss_bed)
msg("  output_dir      = ", output_dir)
msg("  upstream        = ", upstream)
msg("  downstream      = ", downstream)
msg("  ntile           = ", ntile)
msg("  tss_filter      = ", tss_filter)
msg("  harmonize_mode  = ", harmonize_mode)
msg("")

# ------------------------------------------------------------
# Package loading
# ------------------------------------------------------------
required_pkgs <- c(
		"ATACseqQC",
		"ChIPpeakAnno",
		"GenomicRanges",
		"GenomeInfoDb",
		"IRanges",
		"Rsamtools"
)

for (pkg in required_pkgs) {
	if (!requireNamespace(pkg, quietly = TRUE)) {
		stop_err("required R package not found: ", pkg)
	}
}

suppressPackageStartupMessages(library(ATACseqQC))
suppressPackageStartupMessages(library(ChIPpeakAnno))
suppressPackageStartupMessages(library(GenomicRanges))
suppressPackageStartupMessages(library(GenomeInfoDb))
suppressPackageStartupMessages(library(IRanges))
suppressPackageStartupMessages(library(Rsamtools))

# ------------------------------------------------------------
# Output dirs
# ------------------------------------------------------------
tss_dir <- file.path(output_dir, "01_tss_signal")
matrix_dir <- file.path(output_dir, "02_signal_matrices")
summary_dir <- file.path(output_dir, "03_summary")

dir.create(tss_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(matrix_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(summary_dir, recursive = TRUE, showWarnings = FALSE)

harmonization_log <- file.path(summary_dir, "harmonization_log.tsv")

# ------------------------------------------------------------
# Seqname harmonization helpers (mirror of ATAC_QC.R)
# ------------------------------------------------------------
suggest_seqname_map <- function(from_names, to_names) {
	if (length(intersect(from_names, to_names)) > 0) {
		return(setNames(from_names, from_names))
	}
	
	prefix_transforms <- list(
			identity = function(v) v,
			strip_Chr = function(v) sub("^Chr", "", v),
			strip_chr = function(v) sub("^chr", "", v),
			add_Chr = function(v) ifelse(grepl("^Chr|^chr", v), v, paste0("Chr", v)),
			add_chr = function(v) ifelse(grepl("^Chr|^chr", v), v, paste0("chr", v))
	)
	
	organelle_fixes <- list(
			identity = function(v) v,
			to_MtPt = function(v) {
				v[v %in% c("M", "MT", "ChrM", "chrM", "ChrMT", "chrMT", "Mito")] <- "Mt"
				v[v %in% c("C", "Cp", "ChrC", "chrC", "Chloro")] <- "Pt"
				v
			},
			to_MC = function(v) {
				v[v %in% c("Mt", "ChrMt", "chrMt", "Mito", "MT")] <- "M"
				v[v %in% c("Pt", "Cp", "ChrPt", "chrPt", "Chloro")] <- "C"
				v
			},
			to_MTupper = function(v) {
				v[v %in% c("M", "Mt", "ChrM", "ChrMt", "chrM", "chrMt", "Mito")] <- "MT"
				v
			}
	)
	
	best <- NULL
	best_hits <- 0
	
	for (pt in prefix_transforms) {
		for (of in organelle_fixes) {
			candidate <- of(pt(from_names))
			hits <- sum(candidate %in% to_names)
			if (hits > best_hits) {
				best <- candidate
				best_hits <- hits
			}
		}
	}
	
	if (best_hits == 0) return(NULL)
	setNames(best, from_names)
}

format_mapping <- function(map, max_show = 6) {
	if (is.null(map)) return("(none)")
	keep <- names(map) != unname(map)
	if (!any(keep)) return("(identity)")
	pairs <- paste0(names(map)[keep], "->", unname(map)[keep])
	if (length(pairs) > max_show) {
		pairs <- c(pairs[seq_len(max_show)], paste0("(+", length(pairs) - max_show, " more)"))
	}
	paste(pairs, collapse = ", ")
}

harmonize_tss_to_target <- function(tss, target_seq, mode) {
	tss_seq <- as.character(unique(seqnames(tss)))
	
	if (length(intersect(tss_seq, target_seq)) > 0) {
		return(list(tss = tss, mapping = NULL, changed = FALSE))
	}
	
	map <- suggest_seqname_map(seqlevels(tss), target_seq)
	
	if (is.null(map)) {
		stop_err(
				"tss_bed seqnames cannot be matched to manifest BAM seqnames.\n",
				"  manifest preview : ", paste(head(target_seq, 10), collapse = ","), "\n",
				"  tss preview      : ", paste(head(tss_seq, 10), collapse = ",")
		)
	}
	
	if (mode == "strict") {
		stop_err(
				"harmonize_mode='strict': tss_bed seqnames disagree with manifest.\n",
				"  Suggested mapping: ", format_mapping(map), "\n",
				"  Re-run with harmonize_mode='auto' to apply, or fix tss_bed manually."
		)
	}
	
	warn_msg("auto-harmonizing tss_bed seqnames to manifest: ", format_mapping(map))
	tss <- renameSeqlevels(tss, map)
	list(tss = tss, mapping = map, changed = TRUE)
}

# ------------------------------------------------------------
# Existing helpers
# ------------------------------------------------------------
read_tss_bed <- function(path) {
	bed <- read.table(
			path,
			sep = "\t",
			header = FALSE,
			stringsAsFactors = FALSE,
			quote = "",
			comment.char = ""
	)
	
	if (ncol(bed) < 3) {
		stop_err("tss_bed must have at least 3 columns: chr, start, end")
	}
	
	colnames(bed)[1:3] <- c("chr", "start", "end")
	
	if (ncol(bed) >= 6) {
		strand <- as.character(bed[[6]])
		strand[!strand %in% c("+", "-", "*")] <- "*"
	} else {
		strand <- rep("*", nrow(bed))
	}
	
	# BED 0-based. TSS width 1.
	tss_pos <- ifelse(strand == "-", as.integer(bed$end), as.integer(bed$start) + 1L)
	
	gr <- GRanges(
			seqnames = as.character(bed$chr),
			ranges = IRanges(start = tss_pos, end = tss_pos),
			strand = strand
	)
	
	unique(sort(gr))
}

range01 <- function(x) {
	if (all(is.na(x))) return(x)
	mn <- min(x, na.rm = TRUE)
	mx <- max(x, na.rm = TRUE)
	if (mx == mn) return(rep(0, length(x)))
	(x - mn) / (mx - mn)
}

safe_call <- function(expr, label) {
	tryCatch(
			expr,
			error = function(e) {
				stop_err(label, " failed: ", e$message)
			}
	)
}

file_exists_non_na <- function(x) {
	!is.na(x) && nzchar(x) && file.exists(x)
}

count_mapped_reads <- function(bam) {
	tryCatch(
			sum(Rsamtools::idxstatsBam(bam)$mapped),
			error = function(e) NA_real_
	)
}

# ------------------------------------------------------------
# Read inputs
# ------------------------------------------------------------
msg("############################## Step 1: Read manifest and TSS")

manifest <- read.table(
		manifest_file,
		header = TRUE,
		sep = "\t",
		stringsAsFactors = FALSE,
		check.names = FALSE
)

need_cols <- c(
		"SampleID",
		"Condition",
		"Replicate",
		"NucleosomeFreeBAM",
		"MononucleosomeBAM",
		"DinucleosomeBAM",
		"TrinucleosomeBAM",
		"SplitObjectsRDS",
		"Seqlevels"
)

miss <- setdiff(need_cols, colnames(manifest))

if (length(miss) > 0) {
	stop_err("manifest missing columns: ", paste(miss, collapse = ", "))
}

if (!"SplitStatus" %in% colnames(manifest)) {
	manifest$SplitStatus <- ifelse(
			file.exists(manifest$SplitObjectsRDS),
			"done",
			"unknown"
	)
}

TSS <- read_tss_bed(tss_bed)

if (length(TSS) == 0) {
	stop_err("No TSS loaded from tss_bed")
}

msg("manifest rows: ", nrow(manifest))
msg("TSS count    : ", length(TSS))
msg("TSS seqlevels preview: ", paste(head(unique(as.character(seqnames(TSS))), 20), collapse = ", "))
msg("")

# ------------------------------------------------------------
# Harmonize TSS against manifest Seqlevels
# ------------------------------------------------------------
msg("############################## Step 1.5: Harmonize tss_bed")

# Union of seqlevels recorded in manifest (these are BAM-side names, already
# corrected by ATAC_QC if harmonize_mode=auto was used there).
all_manifest_seq <- unique(unlist(strsplit(manifest$Seqlevels, ",")))
all_manifest_seq <- trimws(all_manifest_seq)
all_manifest_seq <- all_manifest_seq[nzchar(all_manifest_seq)]

msg("manifest Seqlevels (union, preview): ", paste(head(all_manifest_seq, 20), collapse = ", "))

tss_harm <- harmonize_tss_to_target(TSS, all_manifest_seq, harmonize_mode)
TSS <- tss_harm$tss
tss_mapping <- tss_harm$mapping

if (!is.null(tss_mapping)) {
	harm_df <- data.frame(
			Source = "tss_bed",
			OriginalPath = tss_bed,
			Mapping = format_mapping(tss_mapping, max_show = 100),
			stringsAsFactors = FALSE
	)
	write.table(harm_df, file = harmonization_log, sep = "\t", quote = FALSE, row.names = FALSE)
	msg("harmonization log written: ", harmonization_log)
} else {
	msg("no harmonization needed (tss_bed and manifest agree on seqnames)")
}

msg("")

# ------------------------------------------------------------
# Process each sample
# ------------------------------------------------------------
all_profile_files <- character(0)
all_sample_summaries <- data.frame()

class_names <- c(
		"NucleosomeFree",
		"mononucleosome",
		"dinucleosome",
		"trinucleosome"
)

for (i in seq_len(nrow(manifest))) {
	sample_id <- manifest$SampleID[i]
	condition <- manifest$Condition[i]
	replicate <- manifest$Replicate[i]
	
	msg("############################## Processing sample: ", sample_id)
	
	obj_rds <- manifest$SplitObjectsRDS[i]
	
	bamfiles <- c(
			manifest$NucleosomeFreeBAM[i],
			manifest$MononucleosomeBAM[i],
			manifest$DinucleosomeBAM[i],
			manifest$TrinucleosomeBAM[i]
	)
	
	names(bamfiles) <- class_names
	
	# A class is usable when its split BAM exists and has mapped reads.
	# Plot the usable classes as long as the two core classes,
	# NucleosomeFree and mononucleosome, are among them.
	class_reads <- vapply(bamfiles, function(b) {
		if (file_exists_non_na(b)) count_mapped_reads(b) else NA_real_
	}, numeric(1))
	classes_use <- class_names[!is.na(class_reads) & class_reads > 0]
	classes_dropped <- setdiff(class_names, classes_use)
	reads_text <- paste(
			class_names,
			ifelse(is.na(class_reads), "missing", format(class_reads, scientific = FALSE, trim = TRUE)),
			sep = ":",
			collapse = ","
	)
	
	split_status <- manifest$SplitStatus[i]
	can_plot <- (split_status == "done" || grepl("^empty_split", split_status)) &&
			file_exists_non_na(obj_rds) &&
			all(c("NucleosomeFree", "mononucleosome") %in% classes_use)
	
	if (!can_plot) {
		reason <- paste0(
				"SplitStatus=", split_status,
				"; SplitObjectsRDS exists=", file_exists_non_na(obj_rds),
				"; split BAM reads=", reads_text
		)
		
		warn_msg("sample skipped: ", sample_id, " / ", reason)
		
		sample_summary <- data.frame(
				SampleID = sample_id,
				Condition = condition,
				Replicate = replicate,
				Status = "skipped",
				Reason = reason,
				UsedClasses = NA_character_,
				DroppedClasses = NA_character_,
				HeatmapPDF = NA_character_,
				ProfilePDF = NA_character_,
				ProfileTSV = NA_character_,
				SigsRDS = NA_character_,
				stringsAsFactors = FALSE
		)
		
		write.table(
				sample_summary,
				file = file.path(summary_dir, paste0(sample_id, ".plot_summary.tsv")),
				sep = "\t",
				quote = FALSE,
				row.names = FALSE
		)
		
		all_sample_summaries <- rbind(all_sample_summaries, sample_summary)
		next
	}
	
	objs <- readRDS(obj_rds)
	
	msg("split BAM reads: ", reads_text)
	if (length(classes_dropped) > 0) {
		warn_msg(
				sample_id, " plotted without empty class(es): ",
				paste(classes_dropped, collapse = ","),
				" (SplitStatus=", split_status, ")"
		)
	}
	msg("classes used: ", paste(classes_use, collapse = ","))
	
	missing_objs <- setdiff(classes_use, names(objs))
	
	if (length(missing_objs) > 0) {
		stop_err(
				"split objects missing for sample ", sample_id, ": ",
				paste(missing_objs, collapse = ", ")
		)
	}
	
	seqlev_use <- trimws(unlist(strsplit(manifest$Seqlevels[i], ",")))
	seqlev_use <- intersect(seqlev_use, unique(as.character(seqnames(TSS))))
	
	if (length(seqlev_use) == 0) {
		stop_err(
				"No seqlevels overlap between manifest and TSS for sample: ", sample_id, "\n",
				"  manifest Seqlevels : ", manifest$Seqlevels[i], "\n",
				"  TSS seqlevels      : ", paste(head(unique(as.character(seqnames(TSS))), 10), collapse = ",")
		)
	}
	
	TSS_use <- keepSeqlevels(TSS, seqlev_use, pruning.mode = "coarse")
	
	msg("seqlev used: ", paste(seqlev_use, collapse = ","))
	msg("TSS used   : ", length(TSS_use))
	
	# NBIS-style library size normalization
	# NOTE: estLibSize is exported by ChIPpeakAnno, not ATACseqQC.
	librarySize <- safe_call(
			ChIPpeakAnno::estLibSize(bamfiles[classes_use]),
			paste0(sample_id, " estLibSize")
	)
	
	# NBIS-style signal calculation
	# NOTE: enrichedFragments IS in ATACseqQC (unlike estLibSize /
	# featureAlignedHeatmap / featureAlignedDistribution which are in
	# ChIPpeakAnno). The ATACseqQC vignette loads both packages so the
	# distinction is invisible without ::, but it matters here.
	sigs <- safe_call(
			ATACseqQC::enrichedFragments(
					gal = objs[classes_use],
					TSS = TSS_use,
					librarySize = librarySize,
					seqlev = seqlev_use,
					TSS.filter = tss_filter,
					n.tile = ntile,
					upstream = upstream,
					downstream = downstream
			),
			paste0(sample_id, " enrichedFragments")
	)
	
	sigs_rds <- file.path(matrix_dir, paste0(sample_id, ".sigs.rds"))
	saveRDS(sigs, sigs_rds)
	
	sigs_log2 <- lapply(sigs, function(x) log2(x + 1))
	
	centered_TSS <- ChIPpeakAnno::reCenterPeaks(TSS_use, width = upstream + downstream)
	
	# Heatmap
	# NOTE: featureAlignedHeatmap is exported by ChIPpeakAnno, not ATACseqQC.
	heatmap_pdf <- file.path(tss_dir, paste0(sample_id, ".Heatmap_splitbam.pdf"))
	
	pdf(heatmap_pdf, width = 8, height = 7)
	safe_call(
			ChIPpeakAnno::featureAlignedHeatmap(
					sigs_log2,
					centered_TSS,
					zeroAt = 0.5,
					n.tile = ntile,
					upper.extreme = 2
			),
			paste0(sample_id, " featureAlignedHeatmap")
	)
	dev.off()
	
	# Profile / distribution
	# NOTE: featureAlignedDistribution is exported by ChIPpeakAnno, not ATACseqQC.
	profile_pdf <- file.path(tss_dir, paste0(sample_id, ".TSSprofile_splitbam.pdf"))
	
	pdf(profile_pdf, width = 7, height = 5)
	out <- safe_call(
			ChIPpeakAnno::featureAlignedDistribution(
					sigs,
					centered_TSS,
					zeroAt = 0.5,
					n.tile = ntile,
					type = "l",
					ylab = "Averaged coverage"
			),
			paste0(sample_id, " featureAlignedDistribution")
	)
	
	out01 <- apply(out, 2, range01)
	
	matplot(
			out01,
			type = "l",
			xaxt = "n",
			xlab = "Position (bp)",
			ylab = "Fraction of signal",
			main = paste0(sample_id, " TSS signal")
	)
	
	axis(
			1,
			at = seq(0, ntile - 1, length.out = 11) + 1,
			labels = c("-1K", seq(-800, 800, by = 200), "1K"),
			las = 2
	)
	
	abline(v = seq(0, ntile - 1, length.out = 11) + 1, lty = 2, col = "gray")
	legend(
			"topright",
			legend = colnames(out01),
			col = seq_len(ncol(out01)),
			lty = 1,
			cex = 0.8
	)
	dev.off()
	
	profile_tsv <- file.path(tss_dir, paste0(sample_id, ".TSSprofile_splitbam.tsv"))
	
	profile_df <- data.frame(
			Tile = seq_len(nrow(out01)),
			out01,
			check.names = FALSE
	)
	
	write.table(
			profile_df,
			file = profile_tsv,
			sep = "\t",
			quote = FALSE,
			row.names = FALSE
	)
	
	sample_summary <- data.frame(
			SampleID = sample_id,
			Condition = condition,
			Replicate = replicate,
			Status = "done",
			Reason = if (length(classes_dropped) > 0) paste0("empty class(es) not plotted: ", paste(classes_dropped, collapse = ",")) else NA_character_,
			UsedClasses = paste(classes_use, collapse = ","),
			DroppedClasses = if (length(classes_dropped) > 0) paste(classes_dropped, collapse = ",") else NA_character_,
			HeatmapPDF = heatmap_pdf,
			ProfilePDF = profile_pdf,
			ProfileTSV = profile_tsv,
			SigsRDS = sigs_rds,
			stringsAsFactors = FALSE
	)
	
	write.table(
			sample_summary,
			file = file.path(summary_dir, paste0(sample_id, ".plot_summary.tsv")),
			sep = "\t",
			quote = FALSE,
			row.names = FALSE
	)
	
	all_profile_files <- c(all_profile_files, profile_tsv)
	all_sample_summaries <- rbind(all_sample_summaries, sample_summary)
	
	msg("outputs:")
	msg("  heatmap = ", heatmap_pdf)
	msg("  profile = ", profile_pdf)
	msg("  tsv     = ", profile_tsv)
	msg("")
}

# ------------------------------------------------------------
# Final summary
# ------------------------------------------------------------
summary_table <- data.frame(
		ProfileTSV = all_profile_files,
		stringsAsFactors = FALSE
)

write.table(
		summary_table,
		file = file.path(summary_dir, "all_profile_files.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

write.table(
		all_sample_summaries,
		file = file.path(summary_dir, "all_plot_summary.tsv"),
		sep = "\t",
		quote = FALSE,
		row.names = FALSE
)

n_total <- nrow(all_sample_summaries)
n_done <- sum(all_sample_summaries$Status == "done")
n_skipped <- sum(all_sample_summaries$Status == "skipped")

msg("############################## Summary")
msg("  total samples : ", n_total)
msg("  plotted       : ", n_done)
msg("  skipped       : ", n_skipped)

msg("")
msg("############################## Done")
msg("input_dir  = ", input_dir)
msg("tss_bed    = ", tss_bed)
msg("output_dir = ", output_dir)
msg("End time   = ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"))