#!/bin/bash
# Public example input for the Somatic_CNV_Pipeline (tumor-normal): whole-exome FASTQ of 10 early-onset
# breast cancer patients, primary tumor (FFPE, ~200x) and matched blood (~100x), from SRA BioProject
# PRJNA1087680 (open access; ENA mirror, no login). Study: "Mutational landscape of normal breast tissues
# adjacent to invasive breast cancer", Cell Reports Medicine 2026, doi:10.1016/j.xcrm.2025.102543 (CC BY 4.0).
# Capture kit: IDT xGen Exome Research Panel v1.0; the study aligned to GRCh38 with BWA and marked
# duplicates with Picard.
#
# Choice of the 10 pairs (fixed before any CNV result was seen, 2026-11-18): of the 32 patients with both
# a tumor and a blood run, the 10 with the most tumor sequence (base count). Patients are renamed P01-P10
# (P01 = most tumor sequence); _T = tumor, _N = matched blood.
#
# Writes <output folder>/fastq/<ID>_1.fastq.gz, <ID>_2.fastq.gz (about 175 GB), checks each file
# against the ENA md5, and writes <output folder>/sample_data.csv (SampleID,NormalID,Sex) and
# SOURCE.tsv (ID -> SRA run). JOBS=6 files download at the same time.
# Interrupted transfers resume automatically (up to 30 attempts per file).
# curl -C - resumes: run the same command again after an interruption; checked files are skipped.
# Next step: align on CLOSHA (BWA-MEM to GRCh38, sort, MarkDuplicates, index); BAM names must start with
# the ID (for example P01_T.bam), then run the CNV pipeline.
#
# Usage: bash tools/cnv/fetch_prjna1087680_pairs.sh <output folder>
set -euo pipefail
O=${1:?usage: fetch_prjna1087680_pairs.sh <output folder>}
mkdir -p "$O/fastq"
# ENA serves the same files under ftp.sra.ebi.ac.uk and ftp.ebi.ac.uk; some networks resolve only the
# second (CLOSHA login node, 2026-11-18). Override with ENA_HOST=ftp.sra.ebi.ac.uk if needed.
ENA_HOST=${ENA_HOST:-ftp.ebi.ac.uk}
# ID  SRA_run  read1_url  read1_md5  read2_url  read2_md5
TABLE="
P01_T SRR31264126 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/026/SRR31264126/SRR31264126_1.fastq.gz acb42066b9d3e5e76eedddb195d858b8 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/026/SRR31264126/SRR31264126_2.fastq.gz a98d06a8d653dc5d616797c13970e76b
P01_N SRR31264127 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/027/SRR31264127/SRR31264127_1.fastq.gz 9269145da9ff53e1977c92129c8cba41 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/027/SRR31264127/SRR31264127_2.fastq.gz 73c56e4ec5606da972b19ad57e20cbda
P02_T SRR31264115 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/015/SRR31264115/SRR31264115_1.fastq.gz 004cadd276d190f72b1dcbf4493e0b9b ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/015/SRR31264115/SRR31264115_2.fastq.gz a49673b8f468b0c8e66c6608be10d5a3
P02_N SRR31264116 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/016/SRR31264116/SRR31264116_1.fastq.gz a3294bfd7e25921dc7f2bde0d388b440 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/016/SRR31264116/SRR31264116_2.fastq.gz 64b8c8aa92981993be9f5d08af052420
P03_T SRR31264122 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/022/SRR31264122/SRR31264122_1.fastq.gz b6bfea7b1d8ef704e67cf5b676767398 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/022/SRR31264122/SRR31264122_2.fastq.gz 24d6e780650f0e50644ea786bac0d603
P03_N SRR31264123 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/023/SRR31264123/SRR31264123_1.fastq.gz 8680c59ebec36cedd8c28ef00a64934f ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/023/SRR31264123/SRR31264123_2.fastq.gz 1b1e58f95020a26a1a55ce9ae3edb638
P04_T SRR31264089 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/089/SRR31264089/SRR31264089_1.fastq.gz 307769e5e2a824994e73b493baa1f64f ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/089/SRR31264089/SRR31264089_2.fastq.gz 96def19584c67a633ddb6509424f5d5c
P04_N SRR31264090 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/090/SRR31264090/SRR31264090_1.fastq.gz b95d3f9c9da0fa92cc5c98ee860b3ef1 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/090/SRR31264090/SRR31264090_2.fastq.gz 5c456c29b1e3f0febcb2677eacf9e6b9
P05_T SRR31264139 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/039/SRR31264139/SRR31264139_1.fastq.gz 3b12e70235fadcdf3b377e3410552108 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/039/SRR31264139/SRR31264139_2.fastq.gz 0783dc7116cdb85d3deee36253636dc0
P05_N SRR31264140 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/040/SRR31264140/SRR31264140_1.fastq.gz e7c1503607c6be9aadc0bedc025bc74d ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/040/SRR31264140/SRR31264140_2.fastq.gz 646b98717d41b5e954526c0ec372c17b
P06_T SRR31264073 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/073/SRR31264073/SRR31264073_1.fastq.gz 7cb325b79972a6a4e8c436d62313fc76 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/073/SRR31264073/SRR31264073_2.fastq.gz a0c32ec203f134986ab3adae0d2c9710
P06_N SRR31264074 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/074/SRR31264074/SRR31264074_1.fastq.gz a9b0e641d993a5c8e863a49cd0ac7e59 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/074/SRR31264074/SRR31264074_2.fastq.gz f2b8cad4f9b1e97b90fa34832cea5474
P07_T SRR31264137 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/037/SRR31264137/SRR31264137_1.fastq.gz faa3d83293aa6f53f796b92eb43147f4 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/037/SRR31264137/SRR31264137_2.fastq.gz bd13618649232471a297402d474c7398
P07_N SRR31264138 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/038/SRR31264138/SRR31264138_1.fastq.gz a877311d5c63268582917c1a614b275b ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/038/SRR31264138/SRR31264138_2.fastq.gz 22facd3b38e55d70d700290c0d10e618
P08_T SRR31264124 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/024/SRR31264124/SRR31264124_1.fastq.gz d6797491e08bbdc34b4085fe00a632ba ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/024/SRR31264124/SRR31264124_2.fastq.gz 3352886d8ec5296ef123c38e64464ebd
P08_N SRR31264125 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/025/SRR31264125/SRR31264125_1.fastq.gz cdf3f1a69edcdf7ede8e85b115ad7f84 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/025/SRR31264125/SRR31264125_2.fastq.gz ca3eb9ca72ab0eb9e6c0b1097cca291b
P09_T SRR31264131 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/031/SRR31264131/SRR31264131_1.fastq.gz 32ddbf6c664c46da883b59f7583c3083 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/031/SRR31264131/SRR31264131_2.fastq.gz e6d873a482a9cd51f090af3622c03cd0
P09_N SRR31264132 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/032/SRR31264132/SRR31264132_1.fastq.gz 353ddf6fb8d5c016c3c5293cfd43a93f ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/032/SRR31264132/SRR31264132_2.fastq.gz 87150efb1222a894fbcb37d98833491e
P10_T SRR31264111 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/011/SRR31264111/SRR31264111_1.fastq.gz ec70c9f076e7ea86f044672b751a43f2 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/011/SRR31264111/SRR31264111_2.fastq.gz c40077efbb6e962f1d01ed449718a8cc
P10_N SRR31264112 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/012/SRR31264112/SRR31264112_1.fastq.gz 2ca77664f7fdb240ad63afb097bc0896 ftp.sra.ebi.ac.uk/vol1/fastq/SRR312/012/SRR31264112/SRR31264112_2.fastq.gz 3e16b01cf4e15110986ce58e096e5109
"
printf 'ID\tSRA_run\n' > "$O/SOURCE.tsv"
# One line per file: output path, URL path, md5. JOBS files download at the same time (default 4).
JOBS=${JOBS:-6}
# Tumor read pairs to keep while streaming (default 0 = whole file, resumable). A cut stream cannot resume
# and long transfers do get dropped, so the subsample is better made from the whole files afterwards
# (zcat <file> | head -n $((4 * pairs)) | gzip > <out>). Blood (normal) files are always downloaded whole and md5-checked.
TUMOR_PAIRS=${TUMOR_PAIRS:-0}
echo "$TABLE" | while read -r id run u1 m1 u2 m2; do
	[ -n "$id" ] || continue
	printf '%s\t%s\n' "$id" "$run" >> "$O/SOURCE.tsv"
	n=0; case $id in *_T) n=$TUMOR_PAIRS ;; esac
	echo "$O/fastq/${id}_1.fastq.gz ${u1#*/} $m1 $n"
	echo "$O/fastq/${id}_2.fastq.gz ${u2#*/} $m2 $n"
done > "$O/files.txt"
export ENA_HOST
fetch_one() {
	f=$1; u=$2; m=$3; n=$4
	[ -s "$f.md5ok" ] && return 0
	if [ "$n" -gt 0 ]; then
		# Subsample: stream the file and keep the first n reads (read order in a FASTQ is unrelated to
		# genome position, so this is effectively a random subsample; R1 and R2 keep the same reads).
		# No resume and no md5 (the file is cut); the read count is checked instead.
		[ -s "$f.subok" ] && return 0
		echo "start $(basename "$f") (first $n reads)"
		( set +o pipefail; curl -sS -fL --retry 5 "https://$ENA_HOST/$u" 2>/dev/null | gzip -dc 2>/dev/null |
			head -n $((4 * n)) | gzip -1 > "$f.part" )
		got=$(( $(gzip -dc "$f.part" | wc -l) / 4 ))
		if [ "$got" -eq "$n" ]; then mv "$f.part" "$f"; echo "$n reads" > "$f.subok"; echo "done  $(basename "$f") ($n reads)"
		else echo "FAILED subsample $(basename "$f") ($got of $n reads; run again)"; rm -f "$f.part"; return 1; fi
		return 0
	fi
	echo "start $(basename "$f")"
	# The server drops long transfers now and then: resume (-C -) until the file is complete, up to
	# 30 attempts; a complete file with a wrong md5 is deleted and fetched again.
	for attempt in $(seq 1 30); do
		if curl -sS -fL -C - --retry 5 --retry-delay 20 -o "$f" "https://$ENA_HOST/$u"; then
			if echo "$m  $f" | md5sum -c --status -; then echo ok > "$f.md5ok"; echo "done  $(basename "$f")"; return 0; fi
			echo "md5 mismatch $(basename "$f") (attempt $attempt): fetching again"; rm -f "$f"
		else
			echo "interrupted $(basename "$f") (attempt $attempt): resuming in 30 s"
		fi
		sleep 30
	done
	echo "FAILED download $(basename "$f") after 30 attempts (run again)"; return 1
}
export -f fetch_one
status=0
xargs -P "$JOBS" -L 1 bash -c 'fetch_one "$0" "$1" "$2" "$3"' < "$O/files.txt" || status=1
{
	echo "SampleID,NormalID,Sex"
	for i in $(seq -w 1 10); do echo "P${i}_T,P${i}_N,female"; done
} > "$O/sample_data.csv"
ls -lh "$O/fastq"
[ "$status" = 0 ] || { echo "some files failed: run the same command again" >&2; exit 1; }
echo "all files downloaded and checked"
