#!/usr/bin/env python3
"""Build the CLOSHA 3.0 ATAC-seq release of 2026-10-16 from the work files.

Each release file is the work file in scripts/ATAC-seq/ with
  - the work-version change history at the top replaced by one block that
    describes the changes from the CLOSHA 2.0 version (or, for a module new
    in CLOSHA 3.0, what the module does), and
  - its own work file name replaced by the release file name.
Nothing else is changed; tools/check_release.py verifies that.

Run from the repository root:
  python3 release/CLOSHA3/ATAC-seq/2026-10-16/build_release.py
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
WORK = ROOT / "scripts" / "ATAC-seq"
OUT = Path(__file__).resolve().parent
RELEASE_DATE = "2026-10-16"

# module, work file, release file, CLOSHA 2.0 file (None = new in 3.0), image
MODULES = [
    ("bowtie2", "bowtie2.1.5.sh", "bowtie2.1.1.sh", "bowtie2_1.0.sh", "bowtie2 1.0 (bx_bowtie2_1.0.def)"),
    ("organellar_filter", "organellar_filter.1.2.sh", "organellar_filter.1.1.sh", "organellar_filter.1.0.sh", "bx_organellar_filter 1.0"),
    ("ATAC_QC", "ATAC_QC.1.2.R", "ATAC_QC.1.1.R", "ATAC_QC.1.0.R", "bx_atac_qc 1.0"),
    ("ATAC_QC_plot", "ATAC_QC_plot.1.2.R", "ATAC_QC_plot.1.1.R", "ATAC_QC_plot.1.0.R", "bx_atac_qc 1.0"),
    ("MACS3_callpeak_ATAC", "MACS3_callpeak_ATAC.1.4.sh", "MACS3_callpeak_ATAC.1.1.sh", "MACS3_callpeak_ATAC.1.0.sh", "bx_macs3_callpeak_atac 1.0"),
    ("peak_annotation", "peak_annotation.1.2.R", "peak_annotation.1.1.R", "peak_annotation.1.0.R", "bx_peak_annotation 1.0"),
    ("differential_accessibility", "differential_accessibility.1.4.R", "differential_accessibility.1.3.R", "differential_accessibility.1.2.R", "bx_differential_accessibility 1.0"),
    ("atac_motif", "atac_motif.1.5.R", "atac_motif.1.2.R", "atac_motif.1.1.R", "bx_atac_motif 1.0"),
    ("tf_footprinting", "tf_footprinting.1.4.sh", "tf_footprinting.1.1.sh", "tf_footprinting.1.0.sh", "bx_tf_footprinting 1.0"),
    ("functional_enrichment", "functional_enrichment.1.1.R", "functional_enrichment.1.0.R", None, "bx_functional_enrichment 1.0"),
    ("replicate_consistency", "replicate_consistency.1.1.sh", "replicate_consistency.1.0.sh", None, "bx_replicate_consistency 1.0"),
]

LOGS = ("Logs: progress goes to stdout and logs/<stamp>.log; errors and warnings\n"
        "  (with their explanation lines) go to stderr and logs/<stamp>.error.log.")
SAFETY = "Safety: the run stops if output_dir is or contains an input path, because\n  output_dir is cleaned (except logs/) at the start."

HEADERS = {
    "bowtie2": f"""Tools are called from /opt/bio/bin (bowtie2, bowtie2-build, samtools)
  instead of /opt/apps/<tool>/current/..., which the images do not have.
Threads: bowtie2 -p and samtools sort -@ use the cores allocated to the job
  (threads=auto, nproc) instead of a fixed 4; a larger threads value is
  capped with a warning. threads is not registered on the portal.
Read groups: each sample gets @RG (ID, SM, and LB = sample name,
  PL = ILLUMINA), which GATK MarkDuplicates 4.6 requires.
post_process_bam defaults to yes: coordinate-sorted BAM files with an index
  (.sorted.bam, .bai) are always written; post_process_bam=no keeps SAM only.
{LOGS}
  The per-sample <sample>_bowtie.log keeps the bowtie2 alignment summary.
Alignments are unchanged.""",
    "organellar_filter": f"""Threads: threads defaults to auto (the cores allocated to the job, nproc)
  instead of 4; a larger value is capped with a warning on stderr.
{SAFETY}
Filtering and outputs are unchanged.""",
    "ATAC_QC": f"""Tn5 shift and nucleosome splitting read the bamQC clean BAM
  (02_bam_qc/<sample>/<sample>.clean.bam: duplicates, low-quality and
  improperly paired reads removed) instead of the input BAM; the run stops if
  the clean BAM is missing or empty. Shifted and split BAM files therefore
  differ from CLOSHA 2.0, and the trinucleosome class can be empty
  (SplitStatus=empty_split:trinucleosome).
QC: adds the TSS enrichment score (07_tss_enrichment, tss_flank=1000), a
  CPM-normalised coverage bigWig per sample (08_bigwig, make_bigwig=TRUE), and
  per-sample metrics in 05_metadata/atac_qc_metrics.tsv; the manifest gains
  the TSSEnrichment and BigWig columns.
{LOGS}
{SAFETY}""",
    "ATAC_QC_plot": f"""Samples with an empty split class (for example
  empty_split:trinucleosome from ATAC_QC) are plotted instead of skipped: all
  four classes are passed to ATACseqQC::enrichedFragments in their fixed
  order, and an empty class counts as no reads. The plots show the
  nucleosome-free signal and the nucleosome signal (mono-, di- and
  trinucleosome combined). The summary tables gain UsedClasses and
  DroppedClasses columns.
{LOGS}
{SAFETY}
Samples without an empty class give the same signals as in CLOSHA 2.0.""",
    "MACS3_callpeak_ATAC": f"""QC: FRiP (fraction of reads in peaks) per sample in frip_summary.tsv.
Threads: samtools index and the FRiP counts use the cores allocated to the
  job (threads=auto, not registered on the portal); MACS3 is single-threaded.
{LOGS}
  Per-sample MACS3 output is split the same way (<sample>_macs3.log and
  <sample>_macs3.stderr.log).
If some samples fail but at least one succeeds, the run ends with a warning
  and exit code 0, listing the failed samples (CLOSHA 2.0 exited 1).
{SAFETY}
MACS3 options and peak files are unchanged.""",
    "peak_annotation": f"""Memory: the TSS profile and heatmap no longer run out of memory on whole
  genomes. The tag matrix is built in chunks of promoters that overlap a
  peak, and the heatmap is drawn as a raster image (in CLOSHA 2.0 the
  <sample>.tss_heatmap.pdf was written empty). The TSS profile is unchanged.
UpSet: the plain UpSet plot needs only ggupset; the vennpie version is drawn
  only when ggplotify and ggimage are also installed.
{LOGS}
  Errors exit with status 1.
{SAFETY}
Annotation tables and gene lists are unchanged.""",
    "differential_accessibility": f"""QC: a sample correlation heatmap (Pearson, log2 CPM) and a PCA plot (top
  variable peaks) in 04_plots, with the correlation matrix and PC coordinates
  as TSV in 03_results.
{LOGS}
{SAFETY}
Differential testing and its result files are unchanged.""",
    "atac_motif": f"""Input: the differential accessibility table is always read from input_dir
  (a differential_accessibility output_dir:
  03_results/diff_accessibility_<norm>.csv); input_dir is required and the
  da_csv argument is no longer accepted.
Checks: the run stops with a clear message when too few peaks remain for the
  logFC bins (after fdr_filter and the chromosome filter), instead of failing
  inside monaLisa; min_abs_logfc=0 means no central bin.
Threads: threads defaults to auto (the cores allocated to the job, nproc)
  instead of 4; a larger value is capped with a warning on stderr.
{LOGS}
{SAFETY}
Motif enrichment results are unchanged.""",
    "tf_footprinting": f"""Input: peaks are always merged from macs_dir (required); peak_file is no
  longer accepted. The sample sheet argument is sample_data (metadata in
  CLOSHA 2.0) with the fixed columns SampleID and Condition; sample_col and
  condition_col are no longer accepted.
Cores: cores defaults to auto (the cores allocated to the job, nproc) instead
  of 1; a larger value is capped with a warning, an invalid value stops the
  run. cores is not registered on the portal.
{LOGS}
A single-BAM condition is sorted straight into the merged BAM path.
{SAFETY}
Footprinting and BINDetect results are unchanged.""",
    "functional_enrichment": """GO enrichment (clusterProfiler) of genes near ATAC-seq peaks. input_dir is
  a peak_annotation output_dir (one gene list per sample) or a
  differential_accessibility output_dir (genes near peaks that gained or lost
  accessibility). Gene annotation comes from an OrgDb file; runs offline.""",
    "replicate_consistency": """Replicate consistency of ATAC-seq peaks with IDR (ENCODE style): relaxed
  MACS3 peaks per replicate and for the pooled replicates, IDR for every
  replicate pair, and a reproducible peak set per condition.""",
}


def git_commit():
    return subprocess.run(["git", "-C", str(ROOT), "rev-parse", "--short", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def strip_history(lines):
    """Return (start, end) of the work-version history block at the top."""
    idx = [i for i, ln in enumerate(lines[:80]) if ln.startswith("# Version ")]
    if not idx:
        raise SystemExit("no version history found")
    end = idx[-1] + 1
    while end < len(lines) and lines[end].strip() not in ("#", ""):
        end += 1
    return idx[0], end + 1  # drop the separator line too


def header_block(module, release, old):
    title = (f"# Version {release.rsplit('.', 1)[0].split('.', 1)[1]} (changes from {old}, CLOSHA 2.0):"
             if old else
             f"# Version {release.rsplit('.', 1)[0].split('.', 1)[1]} (first release in CLOSHA 3.0):")
    body = ["#   " + ln if ln.strip() else "#" for ln in HEADERS[module].split("\n")]
    return [title] + body + ["#"]


def main():
    commit = git_commit()
    rows = []
    for module, work, release, old, image in MODULES:
        lines = (WORK / work).read_text().split("\n")
        start, end = strip_history(lines)
        new = lines[:start] + header_block(module, release, old) + lines[end:]
        text = "\n".join(new).replace(work, release)
        (OUT / release).write_text(text)
        (OUT / release).chmod(0o755 if release.endswith(".sh") else 0o644)
        rows.append((module, release, old or "(new in 3.0)", f"scripts/ATAC-seq/{work}", image))
    with open(OUT / "release.tsv", "w") as fh:
        fh.write("module\trelease_file\tclosha2_file\twork_file\timage\n")
        for r in rows:
            fh.write("\t".join(r) + "\n")
    print(f"built {len(rows)} release files from commit {commit}")


if __name__ == "__main__":
    main()
