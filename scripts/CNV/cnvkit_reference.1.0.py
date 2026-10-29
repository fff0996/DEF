#!/usr/bin/env python3
"""CNV module 1: CNVkit copy-number reference from normal samples.

Usage:
    python cnvkit_reference.1.0.py input_dir="..." sample_data="..." genome_fasta="..." output_dir="..."
        [seq_method="hybrid"] [targets_bed="..."] [annotation="..."] [access_bed="..."]
        [target_avg_size="auto"] [antitarget_avg_size="auto"] [bam_suffix=""] [threads="auto"]

Example:
    apptainer exec bx_cnvkit.1.0.sif python cnvkit_reference.1.0.py \
        input_dir="/data/bam" \
        sample_data="/data/samples.csv" \
        genome_fasta="/ref/GRCh38.fa" \
        output_dir="/out/cnvkit_reference" \
        seq_method="hybrid" \
        targets_bed="/ref/exome_targets.bed" \
        annotation="/ref/refFlat.txt"

Arguments (key=value):
    input_dir           (required) - Directory with coordinate-sorted, duplicate-marked
                                     BAM files and their indexes (.bai); searched
                                     recursively.
    sample_data         (required) - Sample sheet (CSV). Columns: SampleID (tumor),
                                     NormalID (matched normal; empty for tumor-only),
                                     optional Sex (female, male, or empty).
    genome_fasta        (required) - Reference FASTA used for the alignment, with its
                                     .fai index next to it.
    output_dir          (required) - Output directory.
    seq_method          (optional) - hybrid (exome or capture panel), wgs, or
                                     amplicon. default: hybrid
    targets_bed         (optional) - Capture target BED. Required for hybrid and
                                     amplicon; for wgs it limits the analysed regions.
    annotation          (optional) - Gene annotation in UCSC refFlat format; bins are
                                     labelled with gene names. Empty: no gene names.
    access_bed          (optional) - Accessible genome regions (BED). Empty: computed
                                     from genome_fasta (runs of N excluded).
    target_avg_size     (optional) - Average target bin size in bp; auto lets CNVkit
                                     choose (wgs: from the normal BAMs). default: auto
    antitarget_avg_size (optional) - Average off-target bin size in bp (hybrid only).
                                     default: auto
    bam_suffix          (optional) - Only BAM files whose name ends with this text are
                                     used (for example _marked.bam). default: empty
    threads             (optional) - auto uses the cores allocated to the job; a number
                                     is capped by them. default: auto

Normal samples are the distinct non-empty NormalID values. With no normal, a flat
reference is built (tumor-only analysis; copy ratios are then relative to a
uniform expected coverage and are noisier).

Outputs (output_dir):
    01_reference/   reference.cnn, targets.bed, antitargets.bed, access.bed
    02_normal_coverage/<NormalID>.targetcoverage.cnn, .antitargetcoverage.cnn
    03_qc/          <NormalID>.cnr and normal_qc.tsv (noise of each normal against
                    the reference)
    04_metadata/    reference_info.tsv (read by cnvkit_call)
    logs/           <stamp>.log (stdout) and <stamp>.error.log (stderr)

The previous output_dir content except logs/ is removed at the start, so no input
may be inside output_dir.
"""
import csv
import datetime
import os
from pathlib import Path
import re
import shutil
import statistics
import subprocess
import sys
import threading

MODULE = "cnvkit_reference"
REQUIRED = ["input_dir", "sample_data", "genome_fasta", "output_dir"]
OPTIONAL = {"seq_method": "hybrid", "targets_bed": "", "annotation": "", "access_bed": "",
            "target_avg_size": "auto", "antitarget_avg_size": "auto", "bam_suffix": "",
            "threads": "auto"}
SEQ_METHODS = ("hybrid", "wgs", "amplicon")
ID_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*$")


# ---------------------------------------------------------------- messages and logs
class Tee:
    """Write to a console stream and a log file (thread-safe)."""

    def __init__(self, stream, path):
        self.stream = stream
        self.file = open(path, "a", encoding="utf-8")
        self.lock = threading.Lock()

    def write(self, text):
        with self.lock:
            self.stream.write(text)
            self.stream.flush()
            self.file.write(text)
            self.file.flush()

    def flush(self):
        with self.lock:
            self.stream.flush()
            self.file.flush()


def fail(*lines):
    """Error (all lines on stderr) and exit 1."""
    sys.stderr.write("Error: " + "\n".join(lines) + "\n")
    sys.stderr.flush()
    sys.exit(1)


def warn(*lines):
    sys.stderr.write("Warning: " + "\n".join(lines) + "\n")
    sys.stderr.flush()


def info(text=""):
    sys.stdout.write(text + "\n")
    sys.stdout.flush()


def start_logs(output_dir):
    logs_dir = output_dir / "logs"
    logs_dir.mkdir(parents=True, exist_ok=True)
    stamp = f"{datetime.datetime.now():%Y%m%d_%H%M%S}_{os.getpid()}"
    sys.stdout = Tee(sys.__stdout__, logs_dir / f"{stamp}.log")
    sys.stderr = Tee(sys.__stderr__, logs_dir / f"{stamp}.error.log")
    return stamp


def run(cmd, label, threads=None):
    """Run a command; its stdout goes to the log, its stderr to the error log."""
    env = dict(os.environ)
    if threads:
        for name in ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS"):
            env[name] = str(threads)
    info("Command: " + " ".join(str(c) for c in cmd))
    proc = subprocess.Popen([str(c) for c in cmd], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            text=True, bufsize=1, env=env)

    def pump(src, dst):
        for line in src:
            dst.write(line)

    readers = [threading.Thread(target=pump, args=(proc.stdout, sys.stdout)),
               threading.Thread(target=pump, args=(proc.stderr, sys.stderr))]
    for r in readers:
        r.start()
    for r in readers:
        r.join()
    proc.wait()
    if proc.returncode != 0:
        fail(f"{label} failed (exit code {proc.returncode}); see the messages above.")


# ---------------------------------------------------------------- arguments
def parse_args(argv):
    params = dict(OPTIONAL)
    for arg in argv:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", key):
            fail(f"Invalid key: {key}")
        if key not in REQUIRED and key not in OPTIONAL:
            fail(f"Unknown parameter: {key}",
                 "Known parameters: " + ", ".join(REQUIRED + list(OPTIONAL)))
        value = value.strip().strip("'\"").strip()
        params[key] = value if (value or key in REQUIRED) else OPTIONAL[key]
    for key in REQUIRED:
        if not params.get(key):
            fail(f"Required parameter '{key}' is missing")
    return params


def allocated_cores():
    """Cores allocated to the job: nproc on the CPU set (OMP_NUM_THREADS removed; public CLOSHA modules set it to 1)."""
    try:
        return max(1, int(subprocess.check_output(["env", "-u", "OMP_NUM_THREADS", "-u", "OMP_THREAD_LIMIT", "nproc"], text=True).strip()))
    except (OSError, ValueError, subprocess.CalledProcessError):
        return max(1, len(os.sched_getaffinity(0)))


def resolve_threads(value):
    allocated = allocated_cores()
    if value == "auto":
        return allocated, allocated
    if not value.isdigit() or int(value) < 1:
        fail(f"threads must be auto or a positive integer: {value}")
    return min(int(value), allocated), allocated


def positive_int_or_auto(name, value):
    if value == "auto":
        return None
    if not value.isdigit() or int(value) < 1:
        fail(f"{name} must be auto or a positive integer (bp): {value}")
    return int(value)


def existing_file(name, value):
    path = Path(value)
    if not path.is_file():
        fail(f"{name} not found: {value}")
    return path.resolve()


# ---------------------------------------------------------------- inputs
def read_sample_sheet(path):
    with open(path, newline="", encoding="utf-8-sig") as fh:
        rows = list(csv.DictReader(fh))
    if not rows:
        fail(f"sample_data has no rows: {path}")
    header = [h.strip() for h in rows[0].keys()]
    if "SampleID" not in header or "NormalID" not in header:
        fail(f"sample_data must have the columns SampleID and NormalID: {path}",
             "Columns found: " + ", ".join(header))
    samples, seen = [], set()
    for i, row in enumerate(rows, start=2):
        row = {k.strip(): (v or "").strip() for k, v in row.items() if k}
        sid, nid, sex = row.get("SampleID", ""), row.get("NormalID", ""), row.get("Sex", "").lower()
        if not sid:
            fail(f"sample_data line {i}: SampleID is empty")
        for value in (sid, nid):
            if value and not ID_PATTERN.match(value):
                fail(f"sample_data line {i}: invalid ID '{value}' "
                     "(use letters, digits, dot, underscore, hyphen)")
        if sid in seen:
            fail(f"sample_data line {i}: duplicate SampleID {sid}")
        if sex not in ("", "female", "male", "f", "m"):
            fail(f"sample_data line {i}: Sex must be female, male, or empty: {row.get('Sex')}")
        seen.add(sid)
        samples.append({"SampleID": sid, "NormalID": nid, "Sex": {"f": "female", "m": "male"}.get(sex, sex)})
    return samples


def list_bams(input_dir, suffix):
    bams = []
    for root, _dirs, files in os.walk(input_dir):
        for name in files:
            if name.endswith(".bam") and (not suffix or name.endswith(suffix)):
                bams.append(Path(root) / name)
    return sorted(bams)


def find_bam(bams, sample_id, input_dir, suffix):
    """BAM whose name starts with the ID followed by . _ - (or contains it so)."""
    exact = re.compile(rf"^{re.escape(sample_id)}([._-]|$)")
    loose = re.compile(rf"(^|[._-]){re.escape(sample_id)}([._-]|$)")
    hits = [b for b in bams if exact.search(b.name)] or [b for b in bams if loose.search(b.name)]
    if not hits:
        shown = [f"  {b.relative_to(input_dir)}" for b in bams[:20]]
        fail(f"No BAM file for {sample_id} in {input_dir}"
             + (f" (bam_suffix={suffix})" if suffix else ""),
             "BAM files found:" if shown else "No BAM files were found.", *shown,
             "Tip: the BAM file name must start with the ID followed by '.', '_' or '-'.")
    if len(hits) > 1:
        fail(f"Several BAM files match {sample_id}:", *[f"  {h.relative_to(input_dir)}" for h in hits],
             "Tip: set bam_suffix (for example bam_suffix=_marked.bam) to pick one.")
    bam = hits[0]
    if not (Path(str(bam) + ".bai").is_file() or bam.with_suffix(".bai").is_file()):
        fail(f"BAM index (.bai) not found for {bam}",
             "Tip: index the BAM (samtools index) in the alignment step.")
    return bam


def check_outside(output_dir, *inputs):
    """output_dir is cleaned at the start, so it must not be / or hold an input."""
    out = output_dir.resolve()
    if out == Path("/"):
        fail("output_dir must not be /")
    for p in inputs:
        if not p:
            continue
        rp = Path(p).resolve()
        if rp == out or out in rp.parents:
            fail(f"input {p} is inside output_dir {output_dir}, which is cleaned at the start")


def clean_output(output_dir):
    if output_dir.resolve() == Path("/"):
        fail("output_dir must not be /")
    if output_dir.exists():
        for entry in output_dir.iterdir():
            if entry.name == "logs":
                continue
            if entry.is_dir() and not entry.is_symlink():
                shutil.rmtree(entry)
            else:
                entry.unlink()
    output_dir.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------- analysis helpers
def read_tsv(path):
    with open(path, newline="") as fh:
        return list(csv.DictReader(fh, delimiter="\t"))


def noise_metrics(cnr_path):
    """Robust spread of bin log2 ratios (bins with weight > 0)."""
    values = []
    for row in read_tsv(cnr_path):
        try:
            if float(row.get("weight", 1) or 0) > 0:
                values.append(float(row["log2"]))
        except ValueError:
            continue
    if len(values) < 10:
        return {"Bins": len(values), "MAD": "NA", "IQR": "NA", "SD": "NA"}
    med = statistics.median(values)
    mad = 1.4826 * statistics.median(abs(v - med) for v in values)
    q = statistics.quantiles(values, n=4)
    return {"Bins": len(values), "MAD": f"{mad:.4f}", "IQR": f"{q[2] - q[0]:.4f}",
            "SD": f"{statistics.pstdev(values):.4f}"}


def main():
    params = parse_args(sys.argv[1:])
    input_dir = Path(params["input_dir"])
    output_dir = Path(params["output_dir"])
    if not input_dir.is_dir():
        fail(f"input_dir not found: {input_dir}")
    sample_data = existing_file("sample_data", params["sample_data"])
    fasta = existing_file("genome_fasta", params["genome_fasta"])
    if not Path(str(fasta) + ".fai").is_file():
        fail(f"FASTA index not found: {fasta}.fai",
             "Tip: create it with samtools faidx next to the FASTA (the module does not write next to inputs).")
    method = params["seq_method"]
    if method not in SEQ_METHODS:
        fail(f"seq_method must be one of {', '.join(SEQ_METHODS)}: {method}")
    targets = existing_file("targets_bed", params["targets_bed"]) if params["targets_bed"] else None
    if method in ("hybrid", "amplicon") and not targets:
        fail(f"targets_bed is required for seq_method={method}")
    annotation = existing_file("annotation", params["annotation"]) if params["annotation"] else None
    access = existing_file("access_bed", params["access_bed"]) if params["access_bed"] else None
    target_size = positive_int_or_auto("target_avg_size", params["target_avg_size"])
    antitarget_size = positive_int_or_auto("antitarget_avg_size", params["antitarget_avg_size"])
    threads, allocated = resolve_threads(params["threads"])
    check_outside(output_dir, input_dir, sample_data, fasta, targets, annotation, access)

    samples = read_sample_sheet(sample_data)
    normals = sorted({s["NormalID"] for s in samples if s["NormalID"]})
    bams = list_bams(input_dir, params["bam_suffix"])
    normal_bams = {n: find_bam(bams, n, input_dir, params["bam_suffix"]) for n in normals}

    clean_output(output_dir)
    stamp = start_logs(output_dir)
    d_ref, d_cov, d_qc, d_meta = (output_dir / d for d in
                                  ("01_reference", "02_normal_coverage", "03_qc", "04_metadata"))
    for d in (d_ref, d_cov, d_qc, d_meta):
        d.mkdir()

    info(f"############################## {MODULE}")
    info(f"Log files: logs/{stamp}.log (stdout), logs/{stamp}.error.log (stderr)")
    info(f"Start time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")
    info("")
    info("parameters:")
    for key in REQUIRED + list(OPTIONAL):
        if key == "threads":
            info(f"  threads             = {threads} (requested {params['threads']}, allocated {allocated})")
        else:
            info(f"  {key:19s} = {params[key]}")
    info("")
    version = subprocess.run(["cnvkit.py", "version"], capture_output=True, text=True).stdout.strip()
    info(f"CNVkit version: {version}")
    if normals:
        info(f"Normal samples ({len(normals)}): " + ", ".join(normals))
        for n, b in normal_bams.items():
            info(f"  {n}: {b}")
    else:
        warn("No NormalID in sample_data: building a flat reference (tumor-only analysis).",
             "Copy ratios are relative to uniform expected coverage and are noisier than with normals.")
    if method == "wgs" and not normals and target_size is None:
        target_size = 5000
        warn("seq_method=wgs with a flat reference: target_avg_size cannot be estimated without normals; using 5000 bp.")

    info("")
    info("############################## Step 1: accessible regions")
    if access is None and method != "amplicon":
        access = d_ref / "access.bed"
        run(["cnvkit.py", "access", fasta, "-o", access], "cnvkit.py access")
    elif access is not None:
        shutil.copyfile(access, d_ref / "access.bed")
        access = d_ref / "access.bed"
        info(f"Using access_bed: {params['access_bed']}")
    else:
        info("seq_method=amplicon: accessible regions are not used.")

    info("")
    info("############################## Step 2: bins, normal coverage and reference")
    cmd = ["cnvkit.py", "batch", "--method", method, "--fasta", fasta,
           "--output-reference", d_ref / "reference.cnn", "--output-dir", d_cov, "-p", threads]
    if targets:
        cmd += ["--targets", targets]
    if annotation:
        cmd += ["--annotate", annotation]
    if access is not None:
        cmd += ["--access", access]
    if target_size:
        cmd += ["--target-avg-size", target_size]
    if antitarget_size and method == "hybrid":
        cmd += ["--antitarget-avg-size", antitarget_size]
    cmd += ["--normal", *normal_bams.values()]
    run(cmd, "cnvkit.py batch (reference)", threads)

    # Fixed names for the bin files, whatever CNVkit derived from the input names.
    for kind, fixed in (("antitarget", "antitargets.bed"), ("target", "targets.bed")):
        found = [p for p in d_cov.glob(f"*.{kind}.bed")]
        if kind == "target":
            found = [p for p in found if not p.name.endswith(".antitarget.bed")]
        if len(found) == 1:
            shutil.copyfile(found[0], d_ref / fixed)
        elif kind == "target" or method == "hybrid":
            fail(f"expected one *.{kind}.bed from cnvkit.py batch in {d_cov}, found {len(found)}")
    if not (d_ref / "antitargets.bed").exists():
        (d_ref / "antitargets.bed").write_text("")

    # Coverage files named by NormalID.
    for n, b in normal_bams.items():
        stem = b.name[:-4]
        for kind in ("targetcoverage", "antitargetcoverage"):
            src = d_cov / f"{stem}.{kind}.cnn"
            if src.exists() and stem != n:
                src.replace(d_cov / f"{n}.{kind}.cnn")

    info("")
    info("############################## Step 3: normal sample QC")
    qc_rows = []
    for n in normals:
        tcov, acov = d_cov / f"{n}.targetcoverage.cnn", d_cov / f"{n}.antitargetcoverage.cnn"
        if not tcov.exists():
            fail(f"coverage file not found for normal {n}: {tcov}")
        if not acov.exists():
            acov.write_text("chromosome\tstart\tend\tgene\tdepth\tlog2\n")
        cnr = d_qc / f"{n}.cnr"
        run(["cnvkit.py", "fix", tcov, acov, d_ref / "reference.cnn", "-o", cnr], f"cnvkit.py fix ({n})")
        qc_rows.append({"NormalID": n, **noise_metrics(cnr)})
    if qc_rows:
        mads = [float(r["MAD"]) for r in qc_rows if r["MAD"] != "NA"]
        cohort = statistics.median(mads) if mads else None
        for r in qc_rows:
            high = r["MAD"] != "NA" and cohort is not None and len(mads) >= 3 and \
                float(r["MAD"]) > 2 * cohort and float(r["MAD"]) > 0.2
            r["Status"] = "high_noise" if high else ("ok" if r["MAD"] != "NA" else "too_few_bins")
            if high:
                warn(f"normal {r['NormalID']} is much noisier than the others (MAD {r['MAD']} vs median {cohort:.3f});",
                     "  consider removing it from the reference.")
            info(f"  {r['NormalID']}: bins={r['Bins']} MAD={r['MAD']} IQR={r['IQR']} status={r['Status']}")
    with open(d_qc / "normal_qc.tsv", "w", newline="") as fh:
        w = csv.DictWriter(fh, ["NormalID", "Bins", "MAD", "IQR", "SD", "Status"], delimiter="\t")
        w.writeheader()
        w.writerows(qc_rows)
    if not qc_rows:
        info("No normal samples: QC skipped.")

    info("")
    info("############################## Step 4: reference information")
    n_target = sum(1 for line in open(d_ref / "targets.bed") if line.strip())
    n_anti = sum(1 for line in open(d_ref / "antitargets.bed") if line.strip())
    rows = [("seq_method", method), ("reference_type", "pooled" if normals else "flat"),
            ("reference_cnn", "01_reference/reference.cnn"), ("reference_sex", "female"),
            ("genome_fasta", str(fasta)), ("targets_bed", str(targets or "")),
            ("annotation", str(annotation or "")), ("access_bed", "01_reference/access.bed" if access else ""),
            ("normals", ",".join(normals)), ("target_bins", n_target), ("antitarget_bins", n_anti),
            ("cnvkit_version", version), ("created", f"{datetime.datetime.now():%Y-%m-%d %H:%M:%S}")]
    with open(d_meta / "reference_info.tsv", "w") as fh:
        fh.write("key\tvalue\n")
        for k, v in rows:
            fh.write(f"{k}\t{v}\n")
    info(f"Target bins: {n_target}, antitarget bins: {n_anti}")

    info("")
    info("############################## Summary")
    info(f"Reference: {'pooled from ' + str(len(normals)) + ' normal(s)' if normals else 'flat (no normals)'}")
    noisy = [r["NormalID"] for r in qc_rows if r.get("Status") == "high_noise"]
    info(f"Normals flagged high_noise: {', '.join(noisy) if noisy else 'none'}")
    info("")
    info("############################## Done")
    info(f"Reference: {d_ref / 'reference.cnn'}")
    info(f"End time: {datetime.datetime.now():%Y-%m-%d %H:%M:%S}")


if __name__ == "__main__":
    main()
