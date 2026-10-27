#!/bin/bash
# Codespace test of the spatial pipeline scripts with the bx_spatial package set.
#
# Usage: bash tools/spatial/run_spatial_test.sh <work_dir> [env_dir]
#   work_dir: scratch folder (for example under /tmp; about 3 GB)
#   env_dir:  optional folder whose bin/ has Rscript (an existing conda environment, or
#             wrappers that run Rscript inside the built SIF). Empty: a conda
#             environment is made in <work_dir>/env.
#
# Builds a conda environment with the bx_spatial 1.0 packages, downloads four
# 10x mouse brain Visium sections (Sagittal Anterior/Posterior, Section 1/2),
# and runs prep -> cluster -> svf (one slice) -> merge 1.2 -> condition_de 1.2 with section 1 and 2
# as the two conditions. Codespace stops processes when free memory drops
# below about 1 GB, so the inputs are reduced for this test only: the same
# 6000 genes in every section (most often detected over all sections; a
# per-section choice would zero genes in some sections and fake differences),
# slices run one by one, and 600 spots per slice before merge.
# Timing and peak memory are printed per step ([measure] lines).
set -u
W=${1:?work_dir is required}
E=${2:-}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
M=$REPO/scripts/Spatial_Transcriptomics_Analysis_Pipeline
MINIFORGE=/workspaces/.closha_build_test/Miniforge3-26.7.2-0-Linux-x86_64.sh
mkdir -p "$W"
cd "$W" || exit 1

cat > measure.py <<'PY'
import resource, subprocess, sys, time
t = time.time()
code = subprocess.call(sys.argv[2:])
peak = resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss / 1024 / 1024
print(f"[measure] {sys.argv[1]}: exit={code} elapsed={time.time()-t:.0f}s peak_rss={peak:.2f}GB", file=sys.stderr, flush=True)
sys.exit(code)
PY
cat > pick_genes.R <<'RS'
# Test-only: the 6000 genes detected in the most spots over all sections.
suppressPackageStartupMessages(library(Seurat))
a <- commandArgs(TRUE); out <- a[1]; det <- NULL
for (f in a[-1]) {
    m <- Read10X_h5(f)
    d <- Matrix::rowSums(m > 0)
    det <- if (is.null(det)) d else det[names(d)] + d
}
writeLines(names(sort(det, decreasing = TRUE))[1:6000], out)
RS
cat > shrink_h5.R <<'RS'
# Test-only: keep the genes listed in a[3] (same for every section) and write a 10x h5.
suppressPackageStartupMessages({library(Seurat); library(hdf5r); library(Matrix)})
a <- commandArgs(TRUE); m <- Read10X_h5(a[1])
keep <- readLines(a[3])
m <- as(m[keep, ], "CsparseMatrix")
f <- H5File$new(a[2], mode = "w"); g <- f$create_group("matrix")
g[["barcodes"]] <- colnames(m); g[["data"]] <- as.integer(m@x); g[["indices"]] <- as.integer(m@i)
g[["indptr"]] <- as.integer(m@p); g[["shape"]] <- as.integer(dim(m))
ft <- g$create_group("features"); ft[["id"]] <- rownames(m); ft[["name"]] <- rownames(m)
ft[["feature_type"]] <- rep("Gene Expression", nrow(m)); ft[["genome"]] <- rep("mm10", nrow(m))
ft[["_all_tag_keys"]] <- "genome"; f$close_all()
RS
cat > sub_rds.R <<'RS'
# Test-only: keep 600 random spots of a clustered slice.
suppressPackageStartupMessages(library(Seurat))
a <- commandArgs(TRUE); o <- readRDS(a[1]); set.seed(1)
o <- subset(o, cells = sample(colnames(o), min(600, ncol(o)))); saveRDS(o, a[2])
RS
printf 'SliceID,Condition\nsec1_anterior,section1\nsec1_posterior,section1\nsec2_anterior,section2\nsec2_posterior,section2\n' > slices.csv

if [ -n "$E" ]; then
    export PATH=$E/bin:/usr/local/bin:/usr/bin:/bin
else
    [ -x mf/bin/conda ] || bash "$MINIFORGE" -b -p "$W/mf" > mf.log 2>&1 || { echo "Miniforge install failed" >&2; exit 1; }
    [ -x env/bin/Rscript ] || mf/bin/conda create -y -p "$W/env" --override-channels -c conda-forge -c bioconda \
        --strict-channel-priority r-base=4.3.3 r-seurat=5.3.0 r-seuratobject=5.2.0 r-presto=1.0.0 r-spacexr=2.2.1 \
        bioconductor-deseq2=1.42.0 r-harmony=1.2.3 bioconductor-glmgampoi=1.14.0 r-hdf5r=1.3.12 r-ggplot2=3.5.2 \
        r-patchwork=1.3.2 r-matrix=1.6_5 > env.log 2>&1 || { echo "conda environment failed; see $W/env.log" >&2; exit 1; }
    export PATH=$W/env/bin:/usr/local/bin:/usr/bin:/bin
fi

URL=https://cf.10xgenomics.com/samples/spatial-exp/1.1.0
for s in V1_Mouse_Brain_Sagittal_Anterior V1_Mouse_Brain_Sagittal_Anterior_Section_2 \
         V1_Mouse_Brain_Sagittal_Posterior V1_Mouse_Brain_Sagittal_Posterior_Section_2; do
    case $s in
        *Anterior_Section_2) d=sec2_anterior ;;
        *Anterior) d=sec1_anterior ;;
        *Posterior_Section_2) d=sec2_posterior ;;
        *) d=sec1_posterior ;;
    esac
    if [ ! -f "data/$d/filtered_feature_bc_matrix.h5" ]; then
        mkdir -p "data/$d"
        curl -s -f -o "data/$d/filtered_feature_bc_matrix.h5" "$URL/$s/${s}_filtered_feature_bc_matrix.h5" &&
            curl -s -f "$URL/$s/${s}_spatial.tar.gz" | tar -xz -C "data/$d" || { echo "download failed: $s" >&2; exit 1; }
    fi
done
Rscript pick_genes.R genes_6000.txt data/*/filtered_feature_bc_matrix.h5
for d in sec1_anterior sec1_posterior sec2_anterior sec2_posterior; do
    mkdir -p "small/$d"
    cp -r "data/$d/spatial" "small/$d/"
    Rscript shrink_h5.R "data/$d/filtered_feature_bc_matrix.h5" "small/$d/filtered_feature_bc_matrix.h5" genes_6000.txt
done

rm -rf out
mkdir -p out/cluster out/cluster_small out/one
for sl in sec1_anterior sec1_posterior sec2_anterior sec2_posterior; do
    mkdir -p "out/one/in_$sl"
    ln -sfn "$W/small/$sl" "out/one/in_$sl/$sl"
    python3 measure.py "prep_$sl" Rscript "$M/spatial_prep.1.1.R" input_dir="$W/out/one/in_$sl" \
        output_dir="$W/out/one/prep_$sl" > "out/prep_$sl.stdout" 2> "out/prep_$sl.stderr" || { echo "prep $sl failed" >&2; exit 1; }
    mkdir -p "out/one/cin_$sl"
    cp -r "out/one/prep_$sl/$sl" "out/one/cin_$sl/"
    python3 measure.py "cluster_$sl" Rscript "$M/spatial_cluster.1.1.R" input_dir="$W/out/one/cin_$sl" \
        output_dir="$W/out/one/cl_$sl" > "out/cluster_$sl.stdout" 2> "out/cluster_$sl.stderr" || { echo "cluster $sl failed" >&2; exit 1; }
    cp -r "out/one/cl_$sl/$sl" out/cluster/
    mkdir -p "out/cluster_small/$sl"
    Rscript sub_rds.R "out/cluster/$sl/${sl}_clustered.rds" "out/cluster_small/$sl/${sl}_clustered.rds"
done
# Spatially variable features on one slice (default arguments); a failure does not stop the test.
mkdir -p out/svf_in
cp -r out/cluster/sec1_anterior out/svf_in/
python3 measure.py svf Rscript "$M/spatial_svf.1.1.R" input_dir="$W/out/svf_in" output_dir="$W/out/svf" \
    > out/svf.stdout 2> out/svf.stderr || echo "svf failed (see out/svf.stderr)" >&2
python3 measure.py merge Rscript "$M/spatial_merge.1.2.R" input_dir="$W/out/cluster_small" output_dir="$W/out/merge" \
    integration=harmony > out/merge.stdout 2> out/merge.stderr || { echo "merge failed" >&2; exit 1; }
python3 measure.py de Rscript "$M/spatial_condition_de.1.4.R" input_dir="$W/out/merge" sample_data="$W/slices.csv" \
    output_dir="$W/out/de" reference=section1 > out/de.stdout 2> out/de.stderr
echo "condition_de exit=$?"
grep -h measure out/*.stderr
