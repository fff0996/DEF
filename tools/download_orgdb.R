#!/usr/bin/env Rscript
# Download OrgDb (gene annotation databases) from Bioconductor AnnotationHub
# into a shared reference directory, for use by the functional enrichment
# module (orgdb_file argument). Run on a machine with internet access; the
# analysis then reads the saved files offline.
#
# Usage:
#   Rscript download_orgdb.R species="Arabidopsis thaliana" out_dir="/path/to/REF/annotation/OrgDb"
#   Rscript download_orgdb.R species="Homo sapiens,Mus musculus" out_dir="..."
#   Rscript download_orgdb.R species_file="species.txt" out_dir="..."
#   Rscript download_orgdb.R list="TRUE" out_dir="..."
#
# Arguments:
#   species      (one of species/species_file/list) - Species name(s) as in AnnotationHub,
#                comma-separated, e.g. "Arabidopsis thaliana,Oryza sativa"
#   species_file (one of species/species_file/list) - Text file with one species per line
#                (empty lines and lines starting with # are ignored)
#   list         (optional) - TRUE writes the list of species that have an OrgDb in
#                AnnotationHub to out_dir/annotationhub_orgdb_species.tsv and stops
#   out_dir      (required) - Directory where OrgDb files and records are written
#   ah_id        (optional) - AnnotationHub ID; only with a single species, when several
#                OrgDb records match (the candidates are listed)
#
# Outputs (out_dir), per species:
#   <Species_name>.<AH id>.OrgDb.sqlite   the OrgDb file (pass as orgdb_file)
#   <Species_name>.<AH id>.OrgDb.txt      record: AH id, title, dates, keytypes, SHA256
# and .annotationhub_cache/ (AnnotationHub download cache; may be removed afterwards).
#
# A species that already has <Species_name>.*.OrgDb.sqlite in out_dir is skipped.
# A species without an OrgDb in AnnotationHub is reported; use a GO table
# (go_table) for it in the enrichment module.
#
# Requirements: R with AnnotationHub and AnnotationDbi (Bioconductor), and
# internet access. The AnnotationHub cache is kept under out_dir, not in the
# user's home directory.

stop_err <- function(...) {
	cat("ERROR: ", paste0(...), "\n", sep = "", file = stderr())
	quit(status = 1)
}

warn_msg <- function(...) {
	cat("WARNING: ", paste0(...), "\n", sep = "", file = stderr())
}

msg <- function(...) cat(..., "\n")

# ------------------------------------------------------------
# Parse key=value arguments
# ------------------------------------------------------------
for (arg in commandArgs(TRUE)) {
	if (!grepl("=", arg, fixed = TRUE)) {
		stop_err("Invalid argument format: ", arg, " (must be key=value format)")
	}
	parts <- strsplit(arg, "=", fixed = TRUE)[[1]]
	key <- parts[1]
	value <- if (length(parts) > 1) paste(parts[-1], collapse = "=") else ""
	value <- sub('^"(.*)"$', "\\1", value)
	value <- sub("^'(.*)'$", "\\1", value)
	if (!key %in% c("species", "species_file", "list", "out_dir", "ah_id")) {
		stop_err("Unknown parameter: ", key)
	}
	assign(key, value)
}

for (x in c("species", "species_file", "list", "ah_id")) {
	if (!exists(x, inherits = FALSE)) assign(x, "")
}
if (!exists("out_dir", inherits = FALSE) || !nzchar(out_dir)) stop_err("Required parameter 'out_dir' is missing")
list_only <- toupper(list) %in% c("TRUE", "T", "YES", "1")

species_list <- character(0)
if (nzchar(species)) {
	species_list <- trimws(strsplit(species, ",", fixed = TRUE)[[1]])
}
if (nzchar(species_file)) {
	if (!file.exists(species_file)) stop_err("species_file not found: ", species_file)
	lines <- trimws(readLines(species_file, warn = FALSE))
	species_list <- c(species_list, lines[nzchar(lines) & !startsWith(lines, "#")])
}
species_list <- unique(species_list[nzchar(species_list)])
if (!list_only && length(species_list) == 0) {
	stop_err("Give species=\"...\", species_file=\"...\", or list=\"TRUE\"")
}
if (nzchar(ah_id) && length(species_list) != 1) {
	stop_err("ah_id can only be used with a single species")
}

for (pkg in c("AnnotationHub", "AnnotationDbi")) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, mustWork = TRUE)
cache_dir <- file.path(out_dir, ".annotationhub_cache")
dir.create(cache_dir, showWarnings = FALSE)

msg("############################## Download OrgDb")
msg("out_dir   =", out_dir)
msg("cache_dir =", cache_dir)
if (!list_only) msg("species   =", paste(species_list, collapse = "; "))
msg("")

ah <- AnnotationHub::AnnotationHub(cache = cache_dir, ask = FALSE)
orgdb_all <- AnnotationHub::query(ah, "OrgDb")
orgdb_all <- orgdb_all[orgdb_all$rdataclass == "OrgDb"]

# ------------------------------------------------------------
# list=TRUE: write the available species and stop
# ------------------------------------------------------------
if (list_only) {
	available <- data.frame(
			species = orgdb_all$species,
			ah_id = names(orgdb_all),
			title = orgdb_all$title,
			date_added = as.character(orgdb_all$rdatadateadded),
			stringsAsFactors = FALSE
	)
	available <- available[order(available$species, available$date_added), ]
	list_file <- file.path(out_dir, "annotationhub_orgdb_species.tsv")
	write.table(available, list_file, sep = "\t", quote = FALSE, row.names = FALSE)
	msg("OrgDb records:", nrow(available), "for", length(unique(available$species)), "species")
	msg("written:", list_file)
	quit(status = 0)
}

# ------------------------------------------------------------
# Download one species
# ------------------------------------------------------------
download_species <- function(sp) {
	msg("############################## Species:", sp)
	base_prefix <- gsub("[^A-Za-z0-9]+", "_", sp)
	existing <- list.files(out_dir, pattern = paste0("^", base_prefix, "\\..*\\.OrgDb\\.sqlite$"))
	if (length(existing) > 0) {
		msg("already present, skipped:", paste(existing, collapse = ", "))
		msg("")
		return("skipped")
	}

	hits <- orgdb_all[tolower(orgdb_all$species) == tolower(sp)]
	if (length(hits) == 0) {
		warn_msg("no OrgDb for '", sp, "' in AnnotationHub; use a GO table (go_table) for this species")
		msg("")
		return("not_available")
	}

	msg("OrgDb records found:")
	print(data.frame(ah_id = names(hits), title = hits$title,
					date_added = as.character(hits$rdatadateadded)), row.names = FALSE)

	id <- ah_id
	if (!nzchar(id)) {
		# Several records: take the most recently added one.
		id <- names(hits)[order(as.character(hits$rdatadateadded), decreasing = TRUE)][1]
		if (length(hits) > 1) msg("several records; using the most recent:", id)
	}
	if (!id %in% names(hits)) {
		warn_msg("ah_id ", id, " is not an OrgDb record for '", sp, "'")
		return("failed")
	}

	result <- tryCatch({
		invisible(ah[[id]])
		cached_file <- AnnotationHub::cache(ah[id])
		out_file <- file.path(out_dir, paste0(base_prefix, ".", id, ".OrgDb.sqlite"))
		if (!file.copy(cached_file, out_file)) stop("could not copy ", cached_file, " to ", out_file)

		# Check that the copy loads as an OrgDb.
		loaded <- AnnotationDbi::loadDb(out_file)
		keytypes <- AnnotationDbi::keytypes(loaded)
		sha256 <- tryCatch(
				sub(" .*$", "", system2("sha256sum", out_file, stdout = TRUE)),
				error = function(e) NA_character_
		)
		record_file <- file.path(out_dir, paste0(base_prefix, ".", id, ".OrgDb.txt"))
		writeLines(c(
						paste0("species: ", sp),
						paste0("ah_id: ", id),
						paste0("title: ", hits[id]$title),
						paste0("date_added: ", as.character(hits[id]$rdatadateadded)),
						paste0("annotationhub_snapshot: ", as.character(AnnotationHub::snapshotDate(ah))),
						paste0("annotationhub_package_version: ", as.character(utils::packageVersion("AnnotationHub"))),
						paste0("downloaded: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
						paste0("file: ", out_file),
						paste0("sha256: ", sha256),
						paste0("keytypes: ", paste(keytypes, collapse = ", "))
				), record_file)
		msg("saved:", out_file)
		msg("keytypes (use one as gene_keytype):", paste(keytypes, collapse = ", "))
		"downloaded"
	}, error = function(e) {
		warn_msg("download failed for '", sp, "' (", id, "): ", conditionMessage(e),
				". AnnotationHub sometimes returns temporary server errors; rerun later.")
		"failed"
	})
	msg("")
	result
}

status <- vapply(species_list, download_species, character(1))

# ------------------------------------------------------------
# Summary
# ------------------------------------------------------------
summary_df <- data.frame(species = species_list, status = unname(status), stringsAsFactors = FALSE)
summary_file <- file.path(out_dir, paste0("download_orgdb_", format(Sys.time(), "%Y%m%d_%H%M%S"), ".tsv"))
write.table(summary_df, summary_file, sep = "\t", quote = FALSE, row.names = FALSE)

msg("############################## Summary")
for (s in c("downloaded", "skipped", "not_available", "failed")) {
	n <- sum(status == s)
	msg(sprintf("  %-13s : %d", s, n))
	if (s %in% c("not_available", "failed") && n > 0) {
		msg("    ", paste(species_list[status == s], collapse = "; "))
	}
}
msg("summary table:", summary_file)

if (any(status == "failed")) quit(status = 1)
