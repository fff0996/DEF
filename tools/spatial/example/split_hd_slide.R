#!/usr/bin/env Rscript
# Splits one Visium HD slide into four quarter slides (left/right x top/bottom by tissue
# position), so the 10x example slide can feed spatial_condition_de as two conditions with
# two slides each (left: brain_left_top, brain_left_bottom; right: brain_right_top,
# brain_right_bottom). Example data only: the quarters are parts of one section, not
# biological replicates.
#
# Usage (inside the bx_spatial image; reads src only, writes under out_dir):
#   Rscript split_hd_slide.R <binned_outputs/square_NNNum> <out_dir> [n_genes]
#     n_genes: keep only the n most often detected genes (default: all genes)
# Run once per bin size; each quarter gets out_dir/brain_<quarter>/binned_outputs/square_NNNum/
# with filtered_feature_bc_matrix.h5 and a copy of spatial/ (positions and images).
#
# The h5 is read in chunks of 5 million entries, so memory stays near the size of the
# kept matrix.
suppressPackageStartupMessages({library(hdf5r); library(Matrix); library(arrow)})
a <- commandArgs(TRUE)
if (length(a) < 2) stop("usage: Rscript split_hd_slide.R <square_NNNum folder> <out_dir> [n_genes]")
src <- normalizePath(a[1], mustWork = TRUE); out <- a[2]; bin <- basename(src)
f <- H5File$new(file.path(src, "filtered_feature_bc_matrix.h5"), mode = "r")
genes <- f[["matrix/features/name"]][]
barcodes <- f[["matrix/barcodes"]][]
shape <- as.integer(f[["matrix/shape"]][])
indptr <- as.numeric(f[["matrix/indptr"]][])
nnz <- indptr[length(indptr)]
chunks <- split(seq(0, nnz - 1, by = 5e6), seq_len(ceiling(nnz / 5e6)))
n_genes <- if (length(a) >= 3) as.integer(a[3]) else shape[1]
if (is.na(n_genes) || n_genes < 1) stop("n_genes must be a positive integer")
n_genes <- min(n_genes, shape[1])
if (n_genes < shape[1]) {
    detected <- integer(shape[1])
    for (s0 in unlist(chunks)) {
        s1 <- min(s0 + 5e6, nnz)
        detected <- detected + tabulate(as.integer(f[["matrix/indices"]][(s0 + 1):s1]) + 1L, nbins = shape[1])
    }
    keep_rows <- sort(order(detected, decreasing = TRUE)[seq_len(n_genes)])
} else {
    keep_rows <- seq_len(shape[1])
}
# Kept genes stay in file order, so the entries remain in column-major, row-sorted
# order and the compressed-column matrix is built directly (no triplet sort).
new_row <- integer(shape[1]); new_row[keep_rows] <- seq_along(keep_rows)
rows <- cols <- vals <- vector("list", length(chunks))
for (k in seq_along(chunks)) {
    s0 <- chunks[[k]]; s1 <- min(s0 + 5e6, nnz)
    r <- new_row[as.integer(f[["matrix/indices"]][(s0 + 1):s1]) + 1L]
    keep <- r > 0L
    rows[[k]] <- r[keep]
    cols[[k]] <- findInterval((s0:(s1 - 1))[keep], indptr)
    vals[[k]] <- as.numeric(f[["matrix/data"]][(s0 + 1):s1])[keep]
}
f$close_all()
per_col <- tabulate(unlist(cols), nbins = shape[2]); rm(cols)
m <- new("dgCMatrix", i = unlist(rows) - 1L, p = c(0L, cumsum(per_col)), x = unlist(vals),
         Dim = c(length(keep_rows), shape[2]), Dimnames = list(make.unique(genes[keep_rows]), barcodes))
rm(rows, vals); invisible(gc())
pos <- as.data.frame(read_parquet(file.path(src, "spatial", "tissue_positions.parquet")))
pos <- pos[pos$barcode %in% colnames(m), ]
mid_x <- stats::median(pos$pxl_col_in_fullres)
mid_y <- stats::median(pos$pxl_row_in_fullres)
for (q in c("left_top", "left_bottom", "right_top", "right_bottom")) {
    in_x <- if (startsWith(q, "left")) pos$pxl_col_in_fullres < mid_x else pos$pxl_col_in_fullres >= mid_x
    in_y <- if (endsWith(q, "top")) pos$pxl_row_in_fullres < mid_y else pos$pxl_row_in_fullres >= mid_y
    bc <- pos$barcode[in_x & in_y]
    x <- m[, bc]
    d <- file.path(out, paste0("brain_", q), "binned_outputs", bin)
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    file.copy(file.path(src, "spatial"), d, recursive = TRUE)
    h <- H5File$new(file.path(d, "filtered_feature_bc_matrix.h5"), mode = "w"); g <- h$create_group("matrix")
    g[["barcodes"]] <- colnames(x); g[["data"]] <- as.integer(x@x); g[["indices"]] <- as.integer(x@i)
    g[["indptr"]] <- as.integer(x@p); g[["shape"]] <- as.integer(dim(x))
    ft <- g$create_group("features"); ft[["id"]] <- rownames(x); ft[["name"]] <- rownames(x)
    ft[["feature_type"]] <- rep("Gene Expression", nrow(x)); ft[["genome"]] <- rep("mm10", nrow(x))
    ft[["_all_tag_keys"]] <- "genome"; h$close_all()
    cat(sprintf("brain_%s: %d bins, %d genes -> %s\n", q, ncol(x), nrow(x), d))
}
