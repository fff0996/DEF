#!/usr/bin/env Rscript
# Download an OrgDb (gene annotation database) from Bioconductor AnnotationHub
# into a shared reference directory, for use by the functional enrichment
# module (orgdb_file argument). Run once per species on a machine with
# internet access; analysis runs then read the saved file offline.
#
# Usage:
#   Rscript download_orgdb.R species="Arabidopsis thaliana" out_dir="/path/to/REF/annotation/OrgDb" [ah_id="AH..."]
#
# Arguments:
#   species  (required) - Species name as in AnnotationHub, e.g. "Arabidopsis thaliana"
#   out_dir  (required) - Directory where the OrgDb file and its record are written
#   ah_id    (optional) - AnnotationHub ID to download when several OrgDb records match
#                         (the script lists the candidates and stops if it is needed)
#
# Outputs (out_dir):
#   <Species_name>.<AH id>.OrgDb.sqlite   the OrgDb file (pass as orgdb_file)
#   <Species_name>.<AH id>.OrgDb.txt      record: AH id, title, dates, keytypes, SHA256
#   .annotationhub_cache/                 AnnotationHub download cache (may be removed)
#
# Requirements: R with AnnotationHub and AnnotationDbi (Bioconductor), and
# internet access. The AnnotationHub cache is kept under out_dir, not in the
# user's home directory.

stop_err <- function(...) {
	cat("ERROR:", paste(..., collapse = ""), "\n", file = stderr())
	quit(status = 1)
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
	if (!key %in% c("species", "out_dir", "ah_id")) stop_err("Unknown parameter: ", key)
	assign(key, value)
}

if (!exists("species") || !nzchar(species)) stop_err("Required parameter 'species' is missing")
if (!exists("out_dir") || !nzchar(out_dir)) stop_err("Required parameter 'out_dir' is missing")
if (!exists("ah_id")) ah_id <- ""

for (pkg in c("AnnotationHub", "AnnotationDbi")) {
	if (!requireNamespace(pkg, quietly = TRUE)) stop_err("required R package not found: ", pkg)
}

dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_dir <- normalizePath(out_dir, mustWork = TRUE)
cache_dir <- file.path(out_dir, ".annotationhub_cache")
dir.create(cache_dir, showWarnings = FALSE)

msg("############################## Download OrgDb")
msg("species   =", species)
msg("out_dir   =", out_dir)
msg("cache_dir =", cache_dir)
msg("")

# ------------------------------------------------------------
# Find OrgDb records for the species
# ------------------------------------------------------------
ah <- AnnotationHub::AnnotationHub(cache = cache_dir, ask = FALSE)
hits <- AnnotationHub::query(ah, c("OrgDb", species))
hits <- hits[hits$rdataclass == "OrgDb" & tolower(hits$species) == tolower(species)]

if (length(hits) == 0) {
	stop_err("no OrgDb record for species '", species, "' in AnnotationHub. Check the spelling, ",
			"e.g. AnnotationHub::query(AnnotationHub(), 'OrgDb') lists available species.")
}

candidates <- data.frame(
		ah_id = names(hits),
		title = hits$title,
		species = hits$species,
		date_added = as.character(hits$rdatadateadded),
		stringsAsFactors = FALSE
)
msg("OrgDb records found:")
print(candidates, row.names = FALSE)
msg("")

if (!nzchar(ah_id)) {
	if (length(hits) > 1) {
		stop_err("several OrgDb records match; rerun with ah_id=\"<one of the ah_id values above>\"")
	}
	ah_id <- names(hits)[1]
}
if (!ah_id %in% names(hits)) stop_err("ah_id ", ah_id, " is not among the records above")

# ------------------------------------------------------------
# Download and copy the OrgDb SQLite file
# ------------------------------------------------------------
orgdb <- ah[[ah_id]]
cached_file <- AnnotationHub::cache(ah[ah_id])

base <- paste0(gsub("[^A-Za-z0-9]+", "_", species), ".", ah_id, ".OrgDb")
out_file <- file.path(out_dir, paste0(base, ".sqlite"))
if (file.exists(out_file)) stop_err("output already exists: ", out_file)
if (!file.copy(cached_file, out_file)) stop_err("could not copy ", cached_file, " to ", out_file)

# Check that the copy loads as an OrgDb.
loaded <- AnnotationDbi::loadDb(out_file)
keytypes <- AnnotationDbi::keytypes(loaded)

sha256 <- tryCatch(
		sub(" .*$", "", system2("sha256sum", out_file, stdout = TRUE)),
		error = function(e) NA_character_
)

record <- c(
		paste0("species: ", species),
		paste0("ah_id: ", ah_id),
		paste0("title: ", hits[ah_id]$title),
		paste0("date_added: ", as.character(hits[ah_id]$rdatadateadded)),
		paste0("annotationhub_snapshot: ", as.character(AnnotationHub::snapshotDate(ah))),
		paste0("annotationhub_package_version: ", as.character(utils::packageVersion("AnnotationHub"))),
		paste0("downloaded: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S")),
		paste0("file: ", out_file),
		paste0("sha256: ", sha256),
		paste0("keytypes: ", paste(keytypes, collapse = ", "))
)
writeLines(record, file.path(out_dir, paste0(base, ".txt")))

msg("saved:")
msg("  ", out_file)
msg("  ", file.path(out_dir, paste0(base, ".txt")))
msg("keytypes (use one as gene_keytype):", paste(keytypes, collapse = ", "))
