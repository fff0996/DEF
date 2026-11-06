#!/usr/bin/env python3
"""Fill the Label column of a scGPT sample sheet from a clinical table.

Standard library only, so it runs anywhere with python3. It never changes the input files and
prints counts, column names and label categories only, never identifiers.

Usage:
  python3 fill_labels.py clinical=clinical.csv
      Lists the column names of the clinical table, then stops.
  python3 fill_labels.py samples=samples.csv clinical=clinical.csv id_col=<column> \
      label_col=<column> keep=PR,PD output=samples_labeled.csv [match=PatientID]

Arguments:
  samples    Sample sheet with the columns SampleID, PatientID, Label
  clinical   Clinical table (.csv, .tsv or .txt; save Excel files as CSV first)
  id_col     Clinical column holding the identifier
  label_col  Clinical column holding the label
  keep       Label values to use, comma separated; other values leave Label empty
  output     New sample sheet; must not exist yet
  match      Sample sheet column matched with id_col. default: PatientID
"""
import csv
import sys
from collections import Counter
from pathlib import Path


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def read_table(path):
    p = Path(path)
    if not p.is_file():
        fail(f"file not found: {path}")
    if p.suffix.lower() in (".xlsx", ".xls"):
        fail(f"{p.name} is an Excel file; save it as CSV first")
    raw = p.read_bytes()
    for encoding in ("utf-8-sig", "cp949"):
        try:
            text = raw.decode(encoding)
            break
        except UnicodeDecodeError:
            continue
    else:
        fail(f"cannot read the text encoding of {p.name}; save it as UTF-8 CSV")
    delimiter = "\t" if p.suffix.lower() in (".tsv", ".txt") else ","
    rows = list(csv.reader(text.splitlines(), delimiter=delimiter))
    rows = [r for r in rows if any(c.strip() for c in r)]
    if not rows:
        fail(f"{p.name} is empty")
    header = [c.strip() for c in rows[0]]
    return header, [dict(zip(header, [c.strip() for c in r])) for r in rows[1:]]


def main():
    args = {}
    for arg in sys.argv[1:]:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        args[key] = value.strip()
    allowed = {"samples", "clinical", "id_col", "label_col", "keep", "output", "match"}
    unknown = sorted(set(args) - allowed)
    if unknown:
        fail(f"Unknown parameter: {', '.join(unknown)}")
    if "clinical" not in args:
        fail("Required parameter 'clinical' is missing")
    clinical_header, clinical = read_table(args["clinical"])
    if set(args) == {"clinical"}:
        print("Columns of the clinical table:")
        for name in clinical_header:
            print(f"  {name}")
        return
    for key in ("samples", "id_col", "label_col", "keep", "output"):
        if not args.get(key):
            fail(f"Required parameter '{key}' is missing")
    match = args.get("match", "PatientID")
    output = Path(args["output"])
    if output.exists():
        fail(f"output already exists: {output}")
    for col in (args["id_col"], args["label_col"]):
        if col not in clinical_header:
            fail(f"column {col} not in the clinical table; columns: {', '.join(clinical_header)}")
    header, samples = read_table(args["samples"])
    for col in ("SampleID", "PatientID", "Label", match):
        if col not in header:
            fail(f"column {col} not in the sample sheet; columns: {', '.join(header)}")
    keep = {v.strip() for v in args["keep"].split(",") if v.strip()}
    if len(keep) != 2:
        fail("keep needs exactly two label values, e.g. keep=PR,PD")

    labels, other, clashes = {}, Counter(), set()
    for row in clinical:
        key, value = row.get(args["id_col"], ""), row.get(args["label_col"], "")
        if not key:
            continue
        if value not in keep:
            other[value or "(empty)"] += 1
            value = ""
        if key in labels and labels[key] != value:
            clashes.add(key)
        labels[key] = value
    if clashes:
        fail(f"{len(clashes)} identifier(s) have different labels in the clinical table; fix the table first")

    filled, unmatched, conflicts = Counter(), 0, 0
    per_patient = {}
    for row in samples:
        key = row[match]
        if key not in labels:
            unmatched += 1
            continue
        value = labels[key]
        if row["Label"] and value and row["Label"] != value:
            conflicts += 1
            continue
        if value:
            row["Label"] = value
            filled[value] += 1
        if row["Label"]:
            per_patient.setdefault(row["PatientID"], set()).add(row["Label"])
    if conflicts:
        fail(f"{conflicts} sample(s) already have a different Label; nothing written")
    mixed = sum(len(v) > 1 for v in per_patient.values())
    if mixed:
        fail(f"{mixed} patient(s) would get two labels; nothing written")
    if not filled:
        fail(f"no sample was labeled; check that {match} and {args['id_col']} hold the same identifiers")

    with output.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(samples)
    print(f"Samples in sheet: {len(samples)}")
    print(f"Labeled samples: {', '.join(f'{k} {v}' for k, v in sorted(filled.items()))}")
    print(f"Samples not found in the clinical table: {unmatched}")
    patients = Counter(next(iter(v)) for v in per_patient.values())
    print(f"Labeled patients: {', '.join(f'{k} {v}' for k, v in sorted(patients.items()))}")
    if other:
        print(f"Clinical rows left empty (value not in keep): {sum(other.values())}")
        print(f"  values: {', '.join(sorted(other))}")
    print(f"Written: {output}")


if __name__ == "__main__":
    main()
