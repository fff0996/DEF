#!/bin/bash
# Codespace test of the Visium HD phase-2 modules (spatial_hd_svf, spatial_hd_rctd) and of
# spatial_condition_de on the RCTD output (group_by=rctd_first_type).
#
# Usage: bash tools/spatial/run_spatial_hd_ext_test.sh <work_dir> <env_dir> <hd_cluster_dir> <reference_rds> <slides_csv>
#   work_dir:       scratch folder
#   env_dir:        folder whose bin/ has Rscript (conda environment or apptainer exec wrapper)
#   hd_cluster_dir: spatial_hd_cluster output of tools/spatial/run_spatial_hd_test.sh
#                   (<its work_dir>/out/cluster)
#   reference_rds:  single-cell reference made by tools/spatial/run_spatial_ref_test.sh
#                   (<its work_dir>/hippocampus_reference.rds; 307 genes, so
#                   min_shared_features is lowered to 100 here)
#   slides_csv:     slide sheet of the HD test (<its work_dir>/slides.csv)
#
# For Codespace speed and memory: hd_svf tests 200 genes on 2,000 bins per slide, and
# condition_de draws no genes on the tissue (spatial_genes=0), and hd_rctd runs on one core
# (max_cores=1): parallel workers each copy the data.
set -u
W=${1:?work_dir is required}
E=${2:?env_dir is required}
C=${3:?hd_cluster_dir is required}
R=${4:?reference_rds is required}
S=${5:?slides_csv is required}
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
rm -rf out
mkdir -p out
python3 measure.py hd_svf Rscript "$M/spatial_hd_svf.1.0.R" input_dir="$C" output_dir="$W/out/hd_svf" \
    svf_topn=200 max_bins=2000 > out/svf.stdout 2> out/svf.stderr
echo "hd_svf exit=$?"
python3 measure.py hd_rctd Rscript "$M/spatial_hd_rctd.1.0.R" input_dir="$C" reference_rds="$R" \
    reference_label_col=celltype output_dir="$W/out/hd_rctd" rctd_mode=full min_shared_features=100 max_cores=1 \
    > out/rctd.stdout 2> out/rctd.stderr || { echo "hd_rctd failed" >&2; exit 1; }
python3 measure.py hd_de_celltype Rscript "$M/spatial_condition_de.1.2.R" input_dir="$W/out/hd_rctd" sample_data="$S" \
    output_dir="$W/out/de_celltype" reference=left group_by=rctd_first_type spatial_genes=0 \
    > out/de.stdout 2> out/de.stderr
echo "condition_de (cell types) exit=$?"
grep -h measure out/*.stderr
