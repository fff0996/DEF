#!/usr/bin/env Rscript
# Builds the example single-cell reference for the human colorectal cancer Visium HD example:
# 10x Chromium Flex data of the same study (Oliveira et al., Nat Genet 2025), with the
# authors' cell-type labels, down-sampled to at most n_per_type cells per Level2 type.
#
# Inputs (public):
#   counts: https://cf.10xgenomics.com/samples/cell-exp/8.0.0/HumanColonCancer_Flex_Multiplex/HumanColonCancer_Flex_Multiplex_count_filtered_feature_bc_matrix.h5
#   labels: https://raw.githubusercontent.com/10XGenomics/HumanColonCancer_VisiumHD/main/MetaData/SingleCell_MetaData.csv.gz
#
# Usage (inside the bx_spatial image):
#   Rscript make_reference.R <counts.h5> <SingleCell_MetaData.csv.gz> <out.rds> [n_per_type=300] [seed=1234]
#
# Cells with QCFilter == "Keep" are used. Metadata columns: Level1 (9 types), Level2 (38 types),
# Patient. The h5 is read in chunks of 5 million entries and only the chosen cells are kept,
# so memory stays near the size of the down-sampled matrix.
suppressPackageStartupMessages({library(hdf5r); library(Matrix); library(Seurat)})
a <- commandArgs(TRUE)
if (length(a) < 3) stop("usage: Rscript make_reference.R <counts.h5> <metadata.csv.gz> <out.rds> [n_per_type] [seed]")
n_per_type <- if (length(a) >= 4) as.integer(a[4]) else 300L
seed <- if (length(a) >= 5) as.integer(a[5]) else 1234L

meta <- utils::read.csv(a[2], stringsAsFactors = FALSE)
meta <- meta[meta$QCFilter == "Keep", ]
set.seed(seed)
pick <- unlist(lapply(split(seq_len(nrow(meta)), meta$Level2), function(i) if (length(i) > n_per_type) sample(i, n_per_type) else i))
meta <- meta[sort(pick), ]

f <- H5File$new(a[1], mode = "r")
genes <- f[["matrix/features/name"]][]
barcodes <- f[["matrix/barcodes"]][]
shape <- as.integer(f[["matrix/shape"]][])
indptr <- as.numeric(f[["matrix/indptr"]][])
keep_col <- match(meta$Barcode, barcodes)
if (anyNA(keep_col)) stop(sum(is.na(keep_col)), " metadata barcodes not in the h5")
new_col <- integer(shape[2]); new_col[sort(keep_col)] <- seq_along(keep_col)
nnz <- indptr[length(indptr)]
rows <- cols <- vals <- list()
for (s0 in seq(0, nnz - 1, by = 5e6)) {
	s1 <- min(s0 + 5e6, nnz)
	col <- findInterval(s0:(s1 - 1), indptr)
	keep <- new_col[col] > 0L
	if (!any(keep)) next
	k <- length(rows) + 1
	rows[[k]] <- as.integer(f[["matrix/indices"]][(s0 + 1):s1])[keep] + 1L
	cols[[k]] <- new_col[col[keep]]
	vals[[k]] <- as.numeric(f[["matrix/data"]][(s0 + 1):s1])[keep]
}
f$close_all()
bc <- barcodes[sort(keep_col)]
m <- sparseMatrix(i = unlist(rows), j = unlist(cols), x = unlist(vals), dims = c(shape[1], length(bc)),
		dimnames = list(make.unique(genes), bc))
rm(rows, cols, vals); invisible(gc())

rownames(meta) <- meta$Barcode
ref <- CreateSeuratObject(m, assay = "RNA", meta.data = meta[colnames(m), c("Patient", "Level1", "Level2")])
ref <- NormalizeData(ref, verbose = FALSE)
saveRDS(ref, a[3])
cat(nrow(ref), "genes x", ncol(ref), "cells;", length(unique(ref$Level1)), "Level1 and",
		length(unique(ref$Level2)), "Level2 types\n")
