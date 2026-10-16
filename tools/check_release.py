#!/usr/bin/env python3
"""Check that every file of a release folder matches its work file.

A release file may differ from its work file (scripts/<pipeline>/) only in
the version block at the top and in its own file name. Usage:
  python3 tools/check_release.py release/CLOSHA3/ATAC-seq/2026-10-16
Exit code 0 when all files match, 1 otherwise.
"""
import csv
import difflib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def body(lines):
    """Lines after the version block (first '# Version' line to the next '#'/blank after the last one)."""
    idx = [i for i, ln in enumerate(lines[:80]) if ln.startswith("# Version ")]
    if not idx:
        return lines
    end = idx[-1] + 1
    while end < len(lines) and lines[end].strip() not in ("#", ""):
        end += 1
    return lines[:idx[0]] + lines[end + 1:]


def main(release_dir):
    rel = Path(release_dir)
    ok = True
    with open(rel / "release.tsv") as fh:
        for row in csv.DictReader(fh, delimiter="\t"):
            work = ROOT / row["work_file"]
            release = rel / row["release_file"]
            w = body(work.read_text().split("\n"))
            r = body(release.read_text().replace(row["release_file"], work.name).split("\n"))
            if w == r:
                print(f"OK    {row['release_file']}  = {row['work_file']}")
            else:
                ok = False
                print(f"DIFF  {row['release_file']}  != {row['work_file']}")
                for ln in list(difflib.unified_diff(w, r, lineterm="", n=0))[:20]:
                    print("      " + ln)
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
