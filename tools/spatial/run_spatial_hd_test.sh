#!/bin/bash
# Codespace test of the Visium HD scripts (spatial_hd_prep, spatial_hd_cluster,
# spatial_condition_de 1.1) with the bx_spatial package set.
#
# Usage: bash tools/spatial/run_spatial_hd_test.sh <work_dir> <env_dir>
#   work_dir: scratch folder (about 5 GB during the download, 1 GB after)
#   env_dir:  conda environment with the bx_spatial packages and r-arrow, for example
#             the one made by tools/spatial/run_spatial_test.sh (<its work_dir>/env)
#
# Downloads the 10x Visium HD mouse brain (FFPE) binned outputs (4.6 GB stream; only
# the 16 um bins and the tissue images are kept). Codespace has about 3 GB of free
# memory, so for this test only the 16 um data is split into four quarter slides
# (brain_left_top, brain_left_bottom, brain_right_top, brain_right_bottom; about 25,000
# bins each) with the 6000 most often detected genes, and left and right are compared
# as two conditions with two slides each (the pseudobulk DESeq2 path). condition_de draws
# 3 genes on the tissue instead of 6 (spatial_genes=3), again for Codespace memory.
set -u
W=${1:?work_dir is required}
E=${2:?env_dir is required}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
M=$REPO/scripts/Spatial_Transcriptomics_Analysis_Pipeline
export PATH=$E/bin:/usr/local/bin:/usr/bin:/bin
mkdir -p "$W"
cd "$W" || exit 1
Rscript -e 'if (!requireNamespace("arrow", quietly = TRUE)) quit(status = 1)' ||
    { echo "r-arrow is missing in $E (conda install r-arrow=21.0.0)" >&2; exit 1; }

cat > measure.py <<'PY'
import resource, subprocess, sys, time
t = time.time()
code = subprocess.call(sys.argv[2:])
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss / 1024 / 1024
print(f"[measure] {sys.argv[1]}: exit={code} elapsed={time.time()-t:.0f}s peak_rss={peak:.2f}GB", file=sys.stderr, flush=True)
sys.exit(code)
PY
cat > split_hd.R <<'RS'
# Test-only: split one Visium HD bin folder into four quarter slides with the
# 6000 most often detected genes, keeping the parquet positions and images. The h5 is
# read in chunks of 5 million entries (detection counts first, then only the kept
# entries), because reading it whole goes over the Codespace memory limit.
suppressPackageStartupMessages({library(hdf5r); library(Matrix); library(arrow)})
a <- commandArgs(TRUE); src <- a[1]; out <- a[2]; bin <- a[3]
f <- H5File$new(file.path(src, "filtered_feature_bc_matrix.h5"), mode = "r")
genes <- f[["matrix/features/name"]][]
barcodes <- f[["matrix/barcodes"]][]
shape <- as.integer(f[["matrix/shape"]][])
indptr <- as.numeric(f[["matrix/indptr"]][])
nnz <- indptr[length(indptr)]
chunks <- split(seq(0, nnz - 1, by = 5e6), seq_len(ceiling(nnz / 5e6)))
detected <- integer(shape[1])
for (s0 in unlist(chunks)) {
    s1 <- min(s0 + 5e6, nnz)
    detected <- detected + tabulate(as.integer(f[["matrix/indices"]][(s0 + 1):s1]) + 1L, nbins = shape[1])
}
# Kept genes stay in file order, so the entries remain in column-major, row-sorted
# order and the compressed-column matrix is built directly (no triplet sort).
keep_rows <- sort(order(detected, decreasing = TRUE)[1:6000])
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
         Dim = c(6000L, shape[2]), Dimnames = list(make.unique(genes[keep_rows]), barcodes))
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
}
RS
printf 'SliceID,Condition\nbrain_left_top,left\nbrain_left_bottom,left\nbrain_right_top,right\nbrain_right_bottom,right\n' > slides.csv

URL=https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_binned_outputs.tar.gz
if [ ! -f raw/binned_outputs/square_016um/spatial/tissue_lowres_image.png ]; then
    mkdir -p raw
    # The 8 and 16 um image files are hard links to the 2 um ones in this archive, so the
    # 2 um images are extracted too. Depending on the tar version the links are made or
    # skipped; images still missing in the 16 um folder are copied from the 2 um folder.
    curl -s -f "$URL" | tar -xz -C raw --wildcards 'binned_outputs/square_016um/*' \
        'binned_outputs/square_002um/spatial/*.png' 'binned_outputs/square_002um/spatial/*.jpg' 2> tar.log
    for f in raw/binned_outputs/square_002um/spatial/*.png raw/binned_outputs/square_002um/spatial/*.jpg; do
        t=raw/binned_outputs/square_016um/spatial/$(basename "$f")
        [ -e "$t" ] || cp "$f" "$t"
    done
    [ -f raw/binned_outputs/square_016um/spatial/tissue_lowres_image.png ] &&
        [ -f raw/binned_outputs/square_016um/filtered_feature_bc_matrix.h5 ] ||
        { echo "Visium HD download failed" >&2; exit 1; }
fi
rm -rf slides16 out
Rscript split_hd.R raw/binned_outputs/square_016um slides16 square_016um || exit 1
mkdir -p out
python3 measure.py hd_prep Rscript "$M/spatial_hd_prep.1.0.R" input_dir="$W/slides16" output_dir="$W/out/prep" \
    bin_size=16 sketch_cells=5000 > out/prep.stdout 2> out/prep.stderr || { echo "hd_prep failed" >&2; exit 1; }
python3 measure.py hd_cluster Rscript "$M/spatial_hd_cluster.1.0.R" input_dir="$W/out/prep" output_dir="$W/out/cluster" \
    features=Prox1,Mbp > out/cluster.stdout 2> out/cluster.stderr || { echo "hd_cluster failed" >&2; exit 1; }
python3 measure.py hd_de Rscript "$M/spatial_condition_de.1.1.R" input_dir="$W/out/cluster" sample_data="$W/slides.csv" \
    output_dir="$W/out/de" reference=left spatial_genes=3 > out/de.stdout 2> out/de.stderr
echo "condition_de exit=$?"
grep -h measure out/*.stderr
