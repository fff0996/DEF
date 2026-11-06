#!/usr/bin/env python3
"""Fill the Label column of a scGPT sample sheet from per-sample cell metadata files.

Reads every <SampleID>_metadata.txt.gz below input_dir, takes the values of one column
(default Response) and gives each sample its value. Standard library only. Input files are
not changed. Prints counts and value categories only, never identifiers.

Usage:
  python3 labels_from_metadata.py input_dir=<folder> samples=samples.csv
      Lists the values found and the patients per value, writes nothing.
  python3 labels_from_metadata.py input_dir=<folder> samples=samples.csv keep=PR,PD \
      output=samples_labeled.csv [column=Response]
      Writes a new sample sheet. Values not in keep leave Label empty.
"""
import csv
import gzip
import sys
from collections import Counter
from pathlib import Path

SUFFIX = "_metadata.txt.gz"
EMPTY = {"", "na", "nan", "none", "null"}


def fail(message):
    print(f"Error: {message}", file=sys.stderr, flush=True)
    sys.exit(1)


def values_in(path, column):
    """Distinct non-empty values of one column, or None when the column is missing."""
    with gzip.open(path, "rt", encoding="utf-8", errors="replace", newline="") as fh:
        first = fh.readline()
        delimiter = "\t" if "\t" in first else ","
        header = [c.strip() for c in next(csv.reader([first], delimiter=delimiter), [])]
        # R tables may have one column less in the header than in the rows (row names).
        if column not in header:
            return None
        index = header.index(column)
        found = set()
        for row in csv.reader(fh, delimiter=delimiter):
            if not row:
                continue
            shift = len(row) - len(header)
            position = index + shift if shift > 0 else index
            value = row[position].strip() if position < len(row) else ""
            if value.lower() not in EMPTY:
                found.add(value)
    return found


def main():
    args = {}
    for arg in sys.argv[1:]:
        if "=" not in arg:
            fail(f"Invalid argument format: {arg} (must be key=value format)")
        key, value = arg.split("=", 1)
        args[key] = value.strip()
    unknown = sorted(set(args) - {"input_dir", "samples", "keep", "output", "column"})
    if unknown:
        fail(f"Unknown parameter: {', '.join(unknown)}")
    for key in ("input_dir", "samples"):
        if not args.get(key):
            fail(f"Required parameter '{key}' is missing")
    if bool(args.get("keep")) != bool(args.get("output")):
        fail("give keep and output together, or neither to list the values")
    column = args.get("column", "Response")
    root, sheet = Path(args["input_dir"]), Path(args["samples"])
    if not root.is_dir():
        fail(f"input_dir not found: {root}")
    if not sheet.is_file():
        fail(f"samples not found: {sheet}")
    with sheet.open(newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        header = [c.strip() for c in (reader.fieldnames or [])]
        samples = [{k.strip(): (v or "").strip() for k, v in r.items() if k} for r in reader]
    for col in ("SampleID", "PatientID", "Label"):
        if col not in header:
            fail(f"column {col} not in the sample sheet; columns: {', '.join(header)}")

    files = sorted(root.rglob(f"*{SUFFIX}"))
    if not files:
        fail(f"no *{SUFFIX} file below {root}")
    by_sample, no_column, several = {}, 0, 0
    for path in files:
        found = values_in(path, column)
        if found is None:
            no_column += 1
            continue
        if len(found) > 1:
            several += 1
        by_sample[path.name[: -len(SUFFIX)]] = found
    print(f"Metadata files: {len(files)}")
    if no_column:
        print(f"Files without the column {column}: {no_column}")
    print(f"Files with several values in the column: {several}")
    if not by_sample:
        fail(f"column {column} not found in any metadata file")

    patient_values, no_file = {}, 0
    for row in samples:
        found = by_sample.get(row["SampleID"])
        if found is None:
            no_file += 1
            continue
        patient_values.setdefault(row["PatientID"], set()).update(found)
    mixed = sum(len(v) > 1 for v in patient_values.values())
    counts = Counter(next(iter(v)) for v in patient_values.values() if len(v) == 1)
    print(f"Samples in sheet: {len(samples)}, without a metadata file: {no_file}")
    print(f"Patients: {len(patient_values)}; with no value: {sum(not v for v in patient_values.values())}; "
          f"with several values: {mixed}")
    print("Patients per value:")
    for value, n in sorted(counts.items()):
        print(f"  {value}: {n}")
    if not args.get("keep"):
        print("Nothing written (list only). Add keep= and output= to write a sample sheet.")
        return

    keep = {v.strip() for v in args["keep"].split(",") if v.strip()}
    output = Path(args["output"])
    if len(keep) != 2:
        fail("keep needs exactly two values, e.g. keep=PR,PD")
    if output.exists():
        fail(f"output already exists: {output}")
    if mixed:
        fail(f"{mixed} patient(s) have several values; nothing written")
    if not keep & set(counts):
        fail("no patient has a value in keep; nothing written")
    labeled = Counter()
    for row in samples:
        values = patient_values.get(row["PatientID"], set())
        value = next(iter(values)) if len(values) == 1 else ""
        row["Label"] = value if value in keep else ""
        if row["Label"]:
            labeled[value] += 1
    with output.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=header, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(samples)
    print(f"Labeled samples: {', '.join(f'{k} {v}' for k, v in sorted(labeled.items()))}")
    print(f"Written: {output}")


if __name__ == "__main__":
    main()
