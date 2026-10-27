#!/bin/bash
# Codespace test of the reference-based spatial modules (check_reference,
# spatial_labelTransfer, spatial_rctd) with the bx_spatial package set.
#
# Usage: bash tools/spatial/run_spatial_ref_test.sh <work_dir> <env_dir> <cluster_dir>
#   work_dir:    scratch folder
#   env_dir:     folder whose bin/ has Rscript (conda environment or apptainer exec wrapper)
#   cluster_dir: spatial_cluster output of tools/spatial/run_spatial_test.sh
#                (<its work_dir>/out/cluster), with sec1_posterior and sec2_posterior
#
# Reference: the small mouse hippocampus single-cell reference shipped with spacexr for
# its Visium vignette (inst/extdata/Reference/Visium_Ref: 17 cell types x 30 cells,
# 307 genes), fetched from a fixed commit. It is only big enough to check that the
# modules run; the posterior slices hold the hippocampus. Because the reference has
# 307 genes, min_shared_features is lowered to 100 for this test, and rctd runs on one
# core (max_cores=1): parallel workers each copy the data and went over the Codespace memory.
# Also for Codespace memory, the two slices are copied with only the genes shared with the
# reference plus 500 variable genes (all spots kept); the full objects went over it.
set -u
W=${1:?work_dir is required}
E=${2:?env_dir is required}
C=${3:?cluster_dir is required}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
M=$REPO/scripts/Spatial_Transcriptomics_Analysis_Pipeline
export PATH=$E/bin:/usr/local/bin:/usr/bin:/bin
mkdir -p "$W"
W=$(cd -- "$W" && pwd)
cd "$W" || exit 1

cat > measure.py <<'PY'
import resource, subprocess, sys, time
t = time.time()
code = subprocess.call(sys.argv[2:])
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss / 1024 / 1024
print(f"[measure] {sys.argv[1]}: exit={code} elapsed={time.time()-t:.0f}s peak_rss={peak:.2f}GB", file=sys.stderr, flush=True)
sys.exit(code)
PY
cat > make_ref.R <<'RS'
# Test-only: spacexr Visium_Ref CSVs -> Seurat reference with raw counts and 'celltype'.
suppressPackageStartupMessages(library(Seurat))
a <- commandArgs(TRUE)
counts <- as.matrix(read.csv(file.path(a[1], "counts.csv"), row.names = 1, check.names = FALSE))
types <- read.csv(file.path(a[1], "cell_types.csv"), row.names = 1)
ref <- CreateSeuratObject(as(counts, "CsparseMatrix"), assay = "RNA")
ref$celltype <- types[colnames(ref), 1]
ref <- NormalizeData(ref, verbose = FALSE)
saveRDS(ref, a[2])
cat(nrow(ref), "genes x", ncol(ref), "cells,", length(unique(ref$celltype)), "cell types\n")
RS

SHA=9f5dc33c8060f946c6072a138b70e189636e1435
U=https://raw.githubusercontent.com/dmcable/spacexr/$SHA/inst/extdata/Reference/Visium_Ref
if [ ! -s ref_src/counts.csv ]; then
    mkdir -p ref_src
    for f in counts.csv cell_types.csv; do
        curl -s -f -o "ref_src/$f" "$U/$f" || { echo "reference download failed: $f" >&2; exit 1; }
    done
fi
Rscript make_ref.R ref_src hippocampus_reference.rds || exit 1

cat > slim_query.R <<'RS'
# Test-only: keep the genes shared with the reference plus 500 variable genes (all spots).
suppressPackageStartupMessages(library(Seurat))
a <- commandArgs(TRUE)  # clustered_rds reference_rds out_rds
q <- readRDS(a[1]); ref <- readRDS(a[2])
q <- subset(q, features = union(intersect(rownames(ref), rownames(q)), head(VariableFeatures(q), 500)))
saveRDS(q, a[3])
cat(basename(a[3]), ":", nrow(q), "genes x", ncol(q), "spots\n")
RS

rm -rf in out
mkdir -p in out
for sl in sec1_posterior sec2_posterior; do
    mkdir -p "in/$sl"
    Rscript slim_query.R "$C/$sl/${sl}_clustered.rds" hippocampus_reference.rds "in/$sl/${sl}_clustered.rds" \
        2> /dev/null || { echo "slim_query failed: $sl" >&2; exit 1; }
done
python3 measure.py check_reference Rscript "$M/check_reference.1.1.R" reference_rds="$W/hippocampus_reference.rds" \
    output_dir="$W/out/check_reference" > out/check.stdout 2> out/check.stderr || { echo "check_reference failed" >&2; exit 1; }
python3 measure.py labelTransfer Rscript "$M/spatial_labelTransfer.1.2.R" input_dir="$W/in" \
    reference_rds="$W/hippocampus_reference.rds" reference_label_col=celltype output_dir="$W/out/labeltransfer" \
    min_shared_features=100 > out/lt.stdout 2> out/lt.stderr
echo "labelTransfer exit=$?"
python3 measure.py rctd Rscript "$M/spatial_rctd.1.2.R" input_dir="$W/in" \
    reference_rds="$W/hippocampus_reference.rds" reference_label_col=celltype output_dir="$W/out/rctd" \
    min_shared_features=100 max_cores=1 > out/rctd.stdout 2> out/rctd.stderr
echo "rctd exit=$?"
grep -h measure out/*.stderr
