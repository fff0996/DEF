#!/bin/bash
# Public example input for the whole CNV pipeline (tumor-only run): WES BAMs of 10 non-small cell
# lung cancer cell lines from the DepMap/CCLE open bucket on AWS (s3://depmap-omics-ccle, no account;
# by downloading you agree to the DepMap Terms and Conditions, https://depmap.org/portal/terms/).
# All 10 use the same bait set (Broad ICE, Illumina coding exome) and are aligned to the Broad hg38
# reference (Homo_sapiens_assembly38.fasta). Cell lines have no matched normal, so sample_data has
# no NormalID: cnvkit_reference builds a flat reference and cnv_facets is skipped.
#
# Writes to <output folder> (about 130 GB):
#   bam/<SampleID>.bam, bam/<SampleID>.bam.bai   10 cell lines (126 GB)
#   ref/Homo_sapiens_assembly38.fasta(.fai)      Broad hg38 reference used by CCLE (3.2 GB)
#   ref/ice_targets.hg38.bed                      ICE targets (Picard interval list -> BED)
#   ref/refFlat.txt                               UCSC hg38 refFlat
#   sample_data.csv, genes.txt
# curl -C - resumes: run the same command again after an interruption.
#
# Usage: bash tools/cnv/fetch_ccle_lung_wes.sh <output folder>
set -euo pipefail
O=${1:?usage: fetch_ccle_lung_wes.sh <output folder>}
S3=https://depmap-omics-ccle.s3.amazonaws.com
GS=https://storage.googleapis.com/gcp-public-data--broad-references/hg38/v0
mkdir -p "$O/bam" "$O/ref"

# SampleID  Sex  OncoTree  CCLE file id (data/wes/bam/<id>.hg38.bam)
SAMPLES="
HCC515     female LUAD  CDS-0wO1Np
HCC461     male   LUAD  CDS-AZW2LJ
A427       male   LUAD  CDS-TQfoys
PC9        male   LUAD  CDS-yPMs5J
HCC827GR5  female LUAD  CDS-pCtF9a
NCIH2887   male   NSCLC CDS-4gXNt3
HCC1195    male   LUAS  CDS-sb8onQ
LC1sqSF    male   LUSC  CDS-BsqCMO
HCC2450    male   LUSC  CDS-dCXlon
LCLC97TM1  male   LCLC  CDS-wXWgLf
"

echo "SampleID,NormalID,Sex,Subtype" > "$O/sample_data.csv"
echo "$SAMPLES" | while read -r sid sex code id; do
	[ -n "$sid" ] || continue
	echo "$sid,,$sex,$code" >> "$O/sample_data.csv"
	echo "== $sid ($id)"
	curl -fL -C - -o "$O/bam/$sid.bam" "$S3/data/wes/bam/$id.hg38.bam"
	curl -fL -C - -o "$O/bam/$sid.bam.bai" "$S3/data/wes/bai/$id.hg38.bai"
done

curl -fL -C - -o "$O/ref/Homo_sapiens_assembly38.fasta" "$GS/Homo_sapiens_assembly38.fasta"
curl -fL -C - -o "$O/ref/Homo_sapiens_assembly38.fasta.fai" "$GS/Homo_sapiens_assembly38.fasta.fai"
curl -fsSL "$GS/HybSelOligos/whole_exome_illumina_coding_v1/whole_exome_illumina_coding_v1.Homo_sapiens_assembly38.targets.interval_list" |
	awk 'BEGIN{OFS="\t"} !/^@/{print $1, $2 - 1, $3}' > "$O/ref/ice_targets.hg38.bed"
curl -fsSL https://hgdownload.soe.ucsc.edu/goldenPath/hg38/database/refFlat.txt.gz | gunzip -c > "$O/ref/refFlat.txt"

printf '%s\n' EGFR KRAS ERBB2 MET MYC NKX2-1 CCND1 MDM2 TERT SOX2 CDKN2A TP53 STK11 RB1 PTEN SMARCA4 > "$O/genes.txt"

echo "BAM files:"; ls -lh "$O/bam"
echo "targets: $(wc -l < "$O/ref/ice_targets.hg38.bed") intervals"
echo "done"
