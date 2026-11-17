#!/usr/bin/env python3
"""Public example input for the BulkFormer pipeline: TCGA lung adenocarcinoma (LUAD) vs lung squamous
cell carcinoma (LUSC) RNA-seq from the GDC open-access tier (STAR - Counts, Primary Tumor).

For each project, n patients are drawn at random (fixed seed; one primary tumour file per patient) and
their GDC STAR count files are downloaded. Written to <output folder>:
  rawdata/<SampleID>.star_counts.tsv   GDC augmented_star_gene_counts files, renamed by sample barcode
  sample_data.csv                      SampleID, PatientID, Cohort, Label (LUAD or LUSC)
  SOURCE.txt                           query, date, and SampleID -> GDC file_id / file_name / md5

Usage: python3 tools/bulkformer/fetch_tcga_luad_lusc.py <output folder> [n_per_project=100] [seed=7]
Standard library only; downloads from https://api.gdc.cancer.gov (no login).
"""
import csv
import datetime
import hashlib
import io
import json
import os
import random
import sys
import tarfile
import urllib.request

API = "https://api.gdc.cancer.gov"
PROJECTS = {"TCGA-LUAD": "LUAD", "TCGA-LUSC": "LUSC"}


def post(endpoint, body, raw=False):
    req = urllib.request.Request(f"{API}/{endpoint}", data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=600) as r:
        data = r.read()
    return data if raw else json.loads(data)


def list_files(project):
    filters = {"op": "and", "content": [
        {"op": "in", "content": {"field": "cases.project.project_id", "value": [project]}},
        {"op": "in", "content": {"field": "data_type", "value": ["Gene Expression Quantification"]}},
        {"op": "in", "content": {"field": "analysis.workflow_type", "value": ["STAR - Counts"]}},
        {"op": "in", "content": {"field": "access", "value": ["open"]}},
        {"op": "in", "content": {"field": "cases.samples.sample_type", "value": ["Primary Tumor"]}}]}
    fields = "file_id,file_name,md5sum,cases.submitter_id,cases.samples.submitter_id,cases.samples.sample_type"
    hits = post("files", {"filters": filters, "fields": fields, "size": 5000, "format": "JSON"})["data"]["hits"]
    by_patient = {}
    for h in hits:
        case = h["cases"][0]
        samples = [s for s in case["samples"] if s["sample_type"] == "Primary Tumor"]
        if len(h["cases"]) != 1 or len(samples) != 1:
            continue
        rec = {"PatientID": case["submitter_id"], "SampleID": samples[0]["submitter_id"],
               "file_id": h["file_id"], "file_name": h["file_name"], "md5": h["md5sum"]}
        by_patient.setdefault(rec["PatientID"], []).append(rec)
    # One file per patient: the lowest sample barcode, then file_id (stable across runs).
    return [sorted(v, key=lambda r: (r["SampleID"], r["file_id"]))[0] for _, v in sorted(by_patient.items())], len(hits)


def download(records, outdir):
    for i in range(0, len(records), 50):
        chunk = records[i:i + 50]
        data = post("data", {"ids": [r["file_id"] for r in chunk]}, raw=True)
        by_id = {r["file_id"]: r for r in chunk}
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tar:
            for m in tar.getmembers():
                if not m.isfile() or not m.name.endswith(".tsv"):
                    continue
                fid = m.name.split("/")[0]
                rec = by_id.get(fid)
                if rec is None:
                    continue
                content = tar.extractfile(m).read()
                if hashlib.md5(content).hexdigest() != rec["md5"]:
                    sys.exit(f"md5 mismatch for {fid}")
                with open(os.path.join(outdir, "rawdata", f"{rec['SampleID']}.star_counts.tsv"), "wb") as fh:
                    fh.write(content)
                rec["done"] = True
        missing = [r["file_id"] for r in chunk if not r.get("done")]
        if missing:
            sys.exit(f"files missing from the GDC archive: {missing}")
        print(f"downloaded {i + len(chunk)}/{len(records)}", flush=True)


def main():
    outdir = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 100
    seed = int(sys.argv[3]) if len(sys.argv) > 3 else 7
    os.makedirs(os.path.join(outdir, "rawdata"), exist_ok=True)
    chosen, totals = [], {}
    for project, label in PROJECTS.items():
        recs, n_files = list_files(project)
        totals[project] = (n_files, len(recs))
        pick = random.Random(f"{seed}-{project}").sample(recs, min(n, len(recs)))
        for r in sorted(pick, key=lambda r: r["SampleID"]):
            r.update(Cohort=project, Label=label)
            chosen.append(r)
        print(f"{project}: {n_files} files, {len(recs)} patients, {len(pick)} chosen", flush=True)
    download(chosen, outdir)
    with open(os.path.join(outdir, "sample_data.csv"), "w", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["SampleID", "PatientID", "Cohort", "Label"])
        for r in chosen:
            w.writerow([r["SampleID"], r["PatientID"], r["Cohort"], r["Label"]])
    with open(os.path.join(outdir, "SOURCE.txt"), "w") as fh:
        fh.write("TCGA LUAD vs LUSC RNA-seq, GDC open access (https://portal.gdc.cancer.gov), "
                 "data_type Gene Expression Quantification, workflow STAR - Counts, Primary Tumor.\n")
        fh.write(f"Downloaded {datetime.date.today()} with tools/bulkformer/fetch_tcga_luad_lusc.py "
                 f"(n_per_project={n}, seed={seed}).\n")
        for p, (nf, npat) in totals.items():
            fh.write(f"{p}: {nf} files, {npat} patients available\n")
        fh.write("Citation: The Cancer Genome Atlas Research Network (TCGA); NCI Genomic Data Commons.\n\n")
        fh.write("SampleID\tCohort\tfile_id\tfile_name\tmd5\n")
        for r in chosen:
            fh.write(f"{r['SampleID']}\t{r['Cohort']}\t{r['file_id']}\t{r['file_name']}\t{r['md5']}\n")
    print(f"done: {len(chosen)} samples in {outdir}")


if __name__ == "__main__":
    main()
