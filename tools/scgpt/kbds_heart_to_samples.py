#!/usr/bin/env python3
"""Split the K-BDS heart atlas (KAP241712, Heart_atlas_scRNA_seq.tsv.gz) into one 10x matrix
folder per sample for scgpt_prep, keeping the cells of Chaffin et al. 2022 (SCP1303), whose
sample, donor and disease come from the SCP1303 cell metadata (DCM_HCM_MetaData_V1.txt).

K-BDS cell names are the SCP1303 NAME (barcode-1-sample index) followed by "sample<n>"
suffixes added when the atlas was assembled; the suffixes are removed to match the names.
Needs numpy and scipy. Prints counts and category values only.

Usage:
  python3 kbds_heart_to_samples.py metadata=DCM_HCM_MetaData_V1.txt
      Lists disease values and counts of samples and donors, writes nothing.
  gzcat Heart_atlas_scRNA_seq.tsv.gz | python3 kbds_heart_to_samples.py \
      metadata=DCM_HCM_MetaData_V1.txt labels="normal=NF,dilated cardiomyopathy=DCM" \
      output_dir=kap241712_lv
      Reads the matrix from standard input (gzcat on macOS, zcat on Linux).

Arguments:
  metadata    SCP1303 cell metadata (tab separated, second line is the TYPE row)
  labels      disease value=label pairs, comma separated; samples of other diseases are left out
  output_dir  new folder: matrices/<SampleID>/ (matrix.mtx.gz, features.tsv.gz,
              barcodes.tsv.gz) and samples.csv for scgpt_prep
  column      metadata column with the disease. default: disease__ontology_label
"""
import csv
import gzip
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

SUFFIX = re.compile(r"(?:sample\d+)+$")
FLUSH_ROWS = 500


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def parse_args(argv):
    args = {}
    for arg in argv:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        args[key] = value.strip().strip("'\"")
    unknown = sorted(set(args) - {"metadata", "labels", "output_dir", "column"})
    if unknown:
        fail(f"Unknown parameter: {', '.join(unknown)}")
    if not args.get("metadata"):
        fail("Required parameter 'metadata' is missing")
    return args


def read_metadata(path, column):
    p = Path(path)
    if not p.is_file():
        fail(f"metadata not found: {path}")
    with p.open(newline="", encoding="utf-8", errors="replace") as fh:
        reader = csv.reader(fh, delimiter="\t")
        header = next(reader)
        for col in ("NAME", "biosample_id", "donor_id", column):
            if col not in header:
                fail(f"column {col} not in metadata; columns: {', '.join(header)}")
        i_name, i_bio, i_don, i_dis = (header.index(c) for c in ("NAME", "biosample_id", "donor_id", column))
        cells = {}
        for row in reader:
            if not row or row[0] == "TYPE":
                continue
            cells[row[i_name]] = (row[i_bio], row[i_don], row[i_dis])
    return cells


def safe_id(text):
    return re.sub(r"[^A-Za-z0-9_.-]", "_", text)


class SampleWriter:
    """Collects sparse rows per sample and writes 10x mtx folders at the end."""

    def __init__(self, np, sp, out, genes):
        self.np, self.sp, self.out, self.genes = np, sp, out, genes
        self.rows = defaultdict(list)       # sample -> list of (indices, values)
        self.barcodes = defaultdict(list)
        self.parts = defaultdict(list)      # sample -> list of temporary .npz paths
        (out / "tmp").mkdir(parents=True)

    def add(self, sample, barcode, indices, values):
        self.rows[sample].append((indices, values))
        self.barcodes[sample].append(barcode)
        if len(self.rows[sample]) >= FLUSH_ROWS:
            self._flush(sample)

    def _block(self, sample):
        np, sp = self.np, self.sp
        rows = self.rows.pop(sample)
        indptr = np.cumsum([0] + [len(r[0]) for r in rows])
        idx = np.concatenate([r[0] for r in rows]) if rows else np.zeros(0, dtype=np.int32)
        val = np.concatenate([r[1] for r in rows]) if rows else np.zeros(0, dtype=np.float32)
        return sp.csr_matrix((val, idx, indptr), shape=(len(rows), len(self.genes)))

    def _flush(self, sample):
        path = self.out / "tmp" / f"{safe_id(sample)}_{len(self.parts[sample])}.npz"
        self.sp.save_npz(path, self._block(sample))
        self.parts[sample].append(path)

    def finish(self):
        from scipy.io import mmwrite
        for sample in sorted(set(self.parts) | set(self.rows)):
            blocks = [self.sp.load_npz(p) for p in self.parts[sample]]
            if self.rows.get(sample):
                blocks.append(self._block(sample))
            m = self.sp.vstack(blocks).tocsr()
            d = self.out / "matrices" / safe_id(sample)
            d.mkdir(parents=True)
            with gzip.open(d / "matrix.mtx.gz", "wb") as fh:
                mmwrite(fh, m.T.tocoo().astype(self.np.int32), field="integer")
            with gzip.open(d / "features.tsv.gz", "wt") as fh:
                fh.writelines(f"{g}\t{g}\tGene Expression\n" for g in self.genes)
            with gzip.open(d / "barcodes.tsv.gz", "wt") as fh:
                fh.writelines(f"{b}\n" for b in self.barcodes[sample])
            for p in self.parts[sample]:
                p.unlink()
        (self.out / "tmp").rmdir()


def main():
    args = parse_args(sys.argv[1:])
    column = args.get("column", "disease__ontology_label")
    cells = read_metadata(args["metadata"], column)
    by_disease = defaultdict(lambda: [set(), set(), 0])
    for bio, donor, dis in cells.values():
        by_disease[dis][0].add(bio)
        by_disease[dis][1].add(donor)
        by_disease[dis][2] += 1
    print(f"Metadata cells: {len(cells)}")
    for dis, (bios, donors, n) in sorted(by_disease.items()):
        print(f"  {dis}: samples {len(bios)}, donors {len(donors)}, cells {n}")
    if not args.get("labels") and not args.get("output_dir"):
        print("Nothing written (list only). Add labels= and output_dir= and give the matrix on standard input.")
        return
    if not args.get("labels") or not args.get("output_dir"):
        fail("give labels and output_dir together")
    labels = {}
    for pair in args["labels"].split(","):
        if "=" not in pair:
            fail(f"labels needs value=label pairs: {pair}")
        value, label = (x.strip() for x in pair.split("=", 1))
        if value not in by_disease:
            fail(f"disease value not in metadata: {value}; values: {', '.join(sorted(by_disease))}")
        labels[value] = label
    if len(set(labels.values())) != 2:
        fail("labels must give exactly two label names")
    out = Path(args["output_dir"])
    if out.exists():
        fail(f"output_dir already exists: {out}")
    if sys.stdin.isatty():
        fail("give the matrix on standard input, e.g. gzcat Heart_atlas_scRNA_seq.tsv.gz | python3 ...")

    import numpy as np
    import scipy.sparse as sp

    header = sys.stdin.readline().rstrip("\n").split("\t")
    genes = header[1:]
    if len(genes) < 1000:
        fail(f"the first line has {len(genes)} gene columns; is this the K-BDS heart matrix?")
    out.mkdir(parents=True)
    writer = SampleWriter(np, sp, out, genes)
    seen = Counter()
    kept_cells = Counter()
    non_integer = 0
    for n, line in enumerate(sys.stdin, 1):
        name, _, rest = line.partition("\t")
        key = SUFFIX.sub("", name)
        info = cells.get(key)
        if info is None:
            seen["not_in_metadata"] += 1
            continue
        bio, donor, dis = info
        if dis not in labels:
            seen["other_disease"] += 1
            continue
        parts = np.array(rest.rstrip("\n").split("\t"))
        if len(parts) != len(genes):
            fail(f"line {n + 1} has {len(parts)} values for {len(genes)} genes")
        nz = np.flatnonzero((parts != "0") & (parts != "0.0"))
        values = parts[nz].astype(np.float32)
        if values.size and np.any(values != np.round(values)):
            non_integer += 1
        writer.add(bio, key, nz.astype(np.int32), values)
        kept_cells[bio] += 1
        if n % 200000 == 0:
            print(f"  lines read: {n}, cells kept: {sum(kept_cells.values())}", flush=True)
    if not kept_cells:
        fail("no cell matched the metadata; check that the matrix is the K-BDS heart atlas")
    if non_integer:
        fail(f"{non_integer} cells have non-integer values; scgpt_prep needs raw counts")
    writer.finish()

    sample_info = {}
    for bio, donor, dis in cells.values():
        if bio in kept_cells:
            sample_info[bio] = (donor, labels[dis])
    with (out / "samples.csv").open("w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SampleID", "PatientID", "Cohort", "Tissue", "Time", "Label"])
        for bio in sorted(sample_info):
            donor, label = sample_info[bio]
            w.writerow([safe_id(bio), safe_id(donor), "KAP241712_SCP1303", "LeftVentricle", "Baseline", label])
    donors = defaultdict(set)
    for donor, label in sample_info.values():
        donors[label].add(donor)
    print(f"Matrix lines not in the SCP1303 metadata: {seen['not_in_metadata']}; other diseases: {seen['other_disease']}")
    print(f"Samples written: {len(sample_info)}, cells: {sum(kept_cells.values())}")
    print("Donors per label: " + ", ".join(f"{k} {len(v)}" for k, v in sorted(donors.items())))
    print(f"Written: {out}/matrices/ and {out}/samples.csv (scgpt_prep: time=all)")


if __name__ == "__main__":
    main()
