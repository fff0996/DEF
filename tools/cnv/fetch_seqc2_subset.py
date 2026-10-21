#!/usr/bin/env python3
"""Fetch a chromosome subset of the SEQC2 HCC1395 WES pair for CNV pipeline tests.

Writes into <outdir>:
  bam/<sample>.<tag>.bam(.bai)      reads on the chosen chromosomes (full header kept)
  ref/GRCh38.d1.vd1.<tag>.fa(.fai)  the chosen chromosomes cut from the SEQC2 reference
  ref/targets.<tag>.bed             SureSelect V6+UTR targets (hg38 liftover) on those chromosomes
  ref/dbsnp151_common.<tag>.vcf.gz  dbSNP b151 common sites (chr names, INFO dropped), for FACETS
Usage: fetch_seqc2_subset.py <outdir> [chr6,chr13,chr17,chr18,chr21]
Needs pysam (with network support) and curl. The default subset takes about
15 minutes and 4 GB; it holds an amplification (chr6), homozygous deletions
(chr6, chr13), copy-neutral LOH at TP53 (chr17), mixed loss and gain (chr18)
and a mostly diploid control (chr21).
"""
import gzip
import os
import subprocess
import sys
import time
import urllib.request
from multiprocessing import Process

import pysam

FTP = "ftp://ftp-trace.ncbi.nlm.nih.gov/ReferenceSamples/seqc/Somatic_Mutation_WG"
DBSNP = "ftp://ftp.ncbi.nih.gov/snp/organisms/human_9606_b151_GRCh38p7/VCF/00-common_all.vcf.gz"
SAMPLES = ["WES_IL_T_1", "WES_IL_N_1"]


def log(msg):
    print(f"[{time.strftime('%H:%M:%S')}] {msg}", flush=True)


def fetch_bam(sample, chroms, outdir, tag):
    url = f"{FTP}/data/WES/{sample}.bwa.dedup.bam"
    out_path = f"{outdir}/bam/{sample}.{tag}.bam"
    tmp = out_path + ".part"
    src = pysam.AlignmentFile(url, index_filename=url[:-4] + ".bai")
    dst = pysam.AlignmentFile(tmp, "wb", template=src)
    for c in chroms:
        t, n = time.time(), 0
        for read in src.fetch(c):
            dst.write(read)
            n += 1
        log(f"{sample} {c}: {n} reads, {time.time() - t:.0f}s")
    dst.close()
    os.replace(tmp, out_path)
    pysam.index(out_path)
    log(f"{sample} done: {os.path.getsize(out_path) / 1e6:.0f} MB")


def fetch_reference(chroms, outdir, tag):
    """Cut whole chromosomes out of the remote FASTA with byte ranges from its .fai."""
    fai = urllib.request.urlopen(f"{FTP}/technical/reference_genome/GRCh38/GRCh38.d1.vd1.fa.fai").read().decode()
    entries = {f[0]: f for f in (line.split("\t") for line in fai.splitlines())}
    out_path = f"{outdir}/ref/GRCh38.d1.vd1.{tag}.fa"
    lengths = {}
    with open(out_path + ".part", "wb") as out:
        for c in chroms:
            length, offset, bases, width = (int(x) for x in entries[c][1:5])
            nbytes = length // bases * width + (length % bases + (1 if length % bases else 0))
            out.write(f">{c}\n".encode())
            seq = subprocess.run(["curl", "-s", "-r", f"{offset}-{offset + nbytes - 1}",
                                  f"{FTP}/technical/reference_genome/GRCh38/GRCh38.d1.vd1.fa"],
                                 check=True, capture_output=True).stdout
            out.write(seq if seq.endswith(b"\n") else seq + b"\n")
            lengths[c] = length
            log(f"reference {c}: {len(seq) / 1e6:.0f} MB")
    os.replace(out_path + ".part", out_path)
    pysam.faidx(out_path)
    fasta = pysam.FastaFile(out_path)
    for c in chroms:
        if fasta.get_reference_length(c) != lengths[c]:
            sys.exit(f"reference {c}: length differs from the source .fai")
    return lengths


def fetch_targets(chroms, outdir, tag):
    url = f"{FTP}/technical/reference_genome/Exome_Target_bed/S07604624_Covered_human_all_v6_plus_UTR.liftover.to.hg38.bed6.gz"
    data = gzip.decompress(urllib.request.urlopen(url).read()).decode().splitlines()
    keep = [line for line in data if line.split("\t")[0] in chroms]
    with open(f"{outdir}/ref/targets.{tag}.bed", "w") as fh:
        fh.write("\n".join(keep) + "\n")
    log(f"targets: {len(keep)} intervals")


def fetch_dbsnp(chroms, lengths, outdir, tag):
    out = f"{outdir}/ref/dbsnp151_common.{tag}.vcf"
    src = pysam.TabixFile(DBSNP)
    with open(out, "w") as fh:
        for h in src.header:
            if h.startswith("##contig"):
                continue
            if h.startswith("#CHROM"):
                for c in chroms:
                    fh.write(f"##contig=<ID={c},length={lengths[c]}>\n")
            fh.write(h + "\n")
        for c in chroms:
            n = 0
            for line in src.fetch(c.replace("chr", "")):
                f = line.split("\t", 8)
                fh.write(c + "\t" + "\t".join(f[1:7]) + "\t.\n")
                n += 1
            log(f"dbSNP {c}: {n} sites")
    pysam.tabix_index(out, preset="vcf", force=True)


def main():
    outdir = sys.argv[1]
    chroms = (sys.argv[2] if len(sys.argv) > 2 else "chr6,chr13,chr17,chr18,chr21").split(",")
    tag = "sub" + str(len(chroms))
    os.makedirs(f"{outdir}/bam", exist_ok=True)
    os.makedirs(f"{outdir}/ref", exist_ok=True)
    log(f"chromosomes: {chroms}")
    fetch_targets(chroms, outdir, tag)
    lengths = fetch_reference(chroms, outdir, tag)
    fetch_dbsnp(chroms, lengths, outdir, tag)
    jobs = [Process(target=fetch_bam, args=(s, chroms, outdir, tag)) for s in SAMPLES]
    for j in jobs:
        j.start()
    for j in jobs:
        j.join()
    failed = [s for s, j in zip(SAMPLES, jobs) if j.exitcode != 0]
    if failed:
        sys.exit(f"failed: {failed}")
    log("all done")


if __name__ == "__main__":
    main()
