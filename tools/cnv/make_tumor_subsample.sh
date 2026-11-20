#!/bin/bash
# Subsampled copy of the PRJNA1087680 example (tools/cnv/fetch_prjna1087680_pairs.sh) for the portal
# example data: each tumor FASTQ keeps its first PAIRS reads (default 50,000,000 pairs, about 10 Gb or
# 70-80x on target; read order in a FASTQ is unrelated to genome position, so this is effectively a
# random subsample, and R1/R2 keep the same reads). Blood (normal) files are hard-linked whole.
#
# It can run while the whole files are still downloading: a tumor file is cut once its whole file has
# passed the md5 check (cutting a partial file is unsafe when transfers overlap). Every CHECK seconds it retries the files not done yet, and
# it ends when all 20 tumor files are cut and all 20 blood files have their .md5ok mark.
#
# Usage: bash tools/cnv/make_tumor_subsample.sh <whole-file folder> <subsample folder>
#   environment: PAIRS (default 50000000), CHECK (default 600), JOBS (default 4)
set -euo pipefail
RAW=${1:?usage: make_tumor_subsample.sh <whole-file folder> <subsample folder>}
SUB=${2:?usage: make_tumor_subsample.sh <whole-file folder> <subsample folder>}
PAIRS=${PAIRS:-50000000}; CHECK=${CHECK:-600}; JOBS=${JOBS:-4}
mkdir -p "$SUB/fastq"
[ -f "$RAW/sample_data.csv" ] && cp "$RAW/sample_data.csv" "$SUB/"

cut_one() {
	f=$1; o=$2/fastq/$(basename "$f"); lines=$((4 * $3))
	[ -s "$o.subok" ] && return 0
	# Only cut a whole file that passed its md5 check: a file cut while still downloading could hold
	# bytes written by an overlapping transfer (2026-11-19: three cut tumor files were corrupt).
	[ -s "$f.md5ok" ] || return 0
	( set +o pipefail; zcat "$f" 2>/dev/null | head -n "$lines" | gzip -1 > "$o.tmp" )
	got=$(zcat "$o.tmp" | wc -l)
	if [ "$got" -eq "$lines" ]; then mv "$o.tmp" "$o"; echo "$3 reads" > "$o.subok"; echo "cut   $(basename "$f") ($3 reads)"
	else rm -f "$o.tmp"; fi
}
export -f cut_one

while :; do
	ls "$RAW"/fastq/P*_T_[12].fastq.gz 2>/dev/null | xargs -r -P "$JOBS" -I{} bash -c 'cut_one "$0" "$1" "$2"' {} "$SUB" "$PAIRS"
	for f in "$RAW"/fastq/P*_N_[12].fastq.gz; do
		[ -e "$f" ] || continue
		# Hard link: a regular file to every program (modules that list files with find -type f skip
		# symlinks) and no extra space. On another file system fall back to a relative symlink, which
		# still resolves inside the container where the user folder is mounted under another path.
		o=$SUB/fastq/$(basename "$f")
		if [ -s "$f.md5ok" ] && ! { [ -f "$o" ] && [ ! -L "$o" ]; }; then
			rm -f "$o"
			ln "$f" "$o" 2>/dev/null || { ln -s "$(realpath --relative-to="$SUB/fastq" "$f")" "$o";
				echo "warning: $(basename "$f") linked as a symlink (other file system)"; }
		fi
	done
	t=$(ls "$SUB"/fastq/P*_T_*.subok 2>/dev/null | wc -l)
	n=$(ls "$SUB"/fastq/P*_N_*.fastq.gz 2>/dev/null | wc -l)
	echo "$(date '+%F %T') tumor cut: $t/20, blood linked: $n/20"
	[ "$t" -eq 20 ] && [ "$n" -eq 20 ] && break
	sleep "$CHECK"
done
echo "subsample complete: $SUB"
