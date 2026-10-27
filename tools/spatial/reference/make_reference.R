#!/usr/bin/env Rscript
# Builds tools/spatial/reference/reference.rds, the example single-cell reference for the
# spatial cell-type modules (spatial_labelTransfer, spatial_rctd, spatial_hd_rctd,
# check_reference). Test and example use only: 510 cells, 307 genes.
#
# Source: spacexr (GPL-3.0) commit 9f5dc33c8060f946c6072a138b70e189636e1435,
#   inst/extdata/Reference/Visium_Ref/counts.csv and cell_types.csv
#   https://github.com/dmcable/spacexr/tree/9f5dc33c8060f946c6072a138b70e189636e1435/inst/extdata/Reference/Visium_Ref
#
# Usage (inside the bx_spatial image):
#   Rscript make_reference.R <folder with counts.csv and cell_types.csv> reference.rds
suppressPackageStartupMessages(library(Seurat))
a <- commandArgs(TRUE)
if (length(a) != 2) stop("usage: Rscript make_reference.R <csv_dir> <out.rds>")
counts <- as.matrix(read.csv(file.path(a[1], "counts.csv"), row.names = 1, check.names = FALSE))
types <- read.csv(file.path(a[1], "cell_types.csv"), row.names = 1)
ref <- CreateSeuratObject(as(counts, "CsparseMatrix"), assay = "RNA")
ref$celltype <- types[colnames(ref), 1]
ref <- NormalizeData(ref, verbose = FALSE)
saveRDS(ref, a[2])
cat(nrow(ref), "genes x", ncol(ref), "cells,", length(unique(ref$celltype)), "cell types\n")
