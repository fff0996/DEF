#!/bin/bash
# Codespace test of the CNV scripts inside the built images (bx_cnvkit, bx_facets).
#
# Usage: bash tools/cnv/run_cnv_test.sh <work_dir> <bx_cnvkit.sif> <bx_facets.sif>
#   work_dir: scratch folder (about 5 GB; the data download takes about 15 minutes)
#
# Data: SEQC2 HCC1395 (tumor) and HCC1395BL (normal) WES, chromosomes 6, 13, 17, 18
# and 21 (tools/cnv/fetch_seqc2_subset.py, run inside bx_cnvkit for pysam), UCSC hg38
# refFlat on the same chromosomes, and 11 breast cancer genes of interest.
# Runs cnvkit_reference -> cnv_facets -> cnvkit_call (with FACETS) -> cnv_summary.
# Timing and peak memory are printed per step ([measure] lines).
set -u
W=${1:?work_dir is required}
CK=${2:?bx_cnvkit SIF is required}
FC=${3:?bx_facets SIF is required}
REPO=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
M=$REPO/scripts/CNV
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

D=$W/data
if [ ! -f "$D/bam/WES_IL_N_1.sub5.bam.bai" ]; then
    apptainer exec --cleanenv --no-home --bind "$REPO:$REPO:ro,$W:$W" "$CK" python -I "$REPO/tools/cnv/fetch_seqc2_subset.py" "$D" > fetch.log 2>&1 ||
        { echo "SEQC2 download failed; see $W/fetch.log" >&2; exit 1; }
fi
if [ ! -s "$D/ref/refFlat.sub5.txt" ]; then
    curl -s -f https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/refFlat.txt.gz | zcat |
        awk -F'\t' '$3 ~ /^chr(6|13|17|18|21)$/' > "$D/ref/refFlat.sub5.txt" ||
        { echo "refFlat download failed" >&2; exit 1; }
fi
printf 'SampleID,NormalID,Sex\nWES_IL_T_1,WES_IL_N_1,female\n' > "$D/samples.csv"
printf 'TP53\nERBB2\nBRCA1\nNF1\nRB1\nBRCA2\nSMAD4\nRUNX1\nESR1\nCCND3\nMYC\n' > "$D/genes.txt"

O=$W/out
rm -rf "$O"
mkdir -p "$O"
X=(apptainer exec --cleanenv --no-home --bind "$REPO:$REPO:ro,$W:$W")
python3 measure.py cnvkit_reference "${X[@]}" "$CK" python "$M/cnvkit_reference.1.0.py" \
    input_dir="$D/bam" sample_data="$D/samples.csv" genome_fasta="$D/ref/GRCh38.d1.vd1.sub5.fa" \
    output_dir="$O/ref" seq_method=hybrid targets_bed="$D/ref/targets.sub5.bed" \
    annotation="$D/ref/refFlat.sub5.txt" > "$O/ref.stdout" 2> "$O/ref.stderr" || { echo "cnvkit_reference failed" >&2; exit 1; }
python3 measure.py cnv_facets "${X[@]}" "$FC" Rscript "$M/cnv_facets.1.0.R" \
    input_dir="$D/bam" sample_data="$D/samples.csv" snp_vcf="$D/ref/dbsnp151_common.sub5.vcf.gz" \
    output_dir="$O/facets" > "$O/facets.stdout" 2> "$O/facets.stderr" || { echo "cnv_facets failed" >&2; exit 1; }
python3 measure.py cnvkit_call "${X[@]}" "$CK" python "$M/cnvkit_call.1.1.py" \
    input_dir="$D/bam" sample_data="$D/samples.csv" reference_dir="$O/ref" facets_dir="$O/facets" \
    genes="$D/genes.txt" output_dir="$O/call" > "$O/call.stdout" 2> "$O/call.stderr" || { echo "cnvkit_call failed" >&2; exit 1; }
python3 measure.py cnv_summary "${X[@]}" "$CK" python "$M/cnv_summary.1.0.py" \
    input_dir="$O/call" facets_dir="$O/facets" genes="$D/genes.txt" output_dir="$O/summary" \
    > "$O/summary.stdout" 2> "$O/summary.stderr" || { echo "cnv_summary failed" >&2; exit 1; }
grep -h measure "$O"/*.stderr
cat "$O/facets/04_summary/facets_summary.tsv"
