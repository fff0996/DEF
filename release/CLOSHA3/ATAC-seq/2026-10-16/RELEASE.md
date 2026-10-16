# CLOSHA 3.0 ATAC-seq 배포 (2026-10-16)

CLOSHA 2.0의 ATAC-seq 파이프라인을 CLOSHA 3.0으로 옮긴 첫 배포입니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 다음 배포는 새 날짜 폴더로 만듭니다.

## 배포 스크립트

배포 번호는 CLOSHA 2.0 운영 번호 + 1이고, 3.0에서 새로 생긴 모듈은 1.0입니다. 각 파일 맨 위 주석에 CLOSHA 2.0 대비 변경이 있습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 |
|---|---|---|---|---|
| bowtie2 | `bowtie2.1.1.sh` | 1.0 | `scripts/ATAC-seq/bowtie2.1.5.sh` | bowtie2 1.0 (bx_bowtie2_1.0.def) |
| organellar_filter | `organellar_filter.1.1.sh` | 1.0 | `scripts/ATAC-seq/organellar_filter.1.2.sh` | bx_organellar_filter 1.0 |
| ATAC_QC | `ATAC_QC.1.1.R` | 1.0 | `scripts/ATAC-seq/ATAC_QC.1.2.R` | bx_atac_qc 1.0 |
| ATAC_QC_plot | `ATAC_QC_plot.1.1.R` | 1.0 | `scripts/ATAC-seq/ATAC_QC_plot.1.2.R` | bx_atac_qc 1.0 |
| MACS3_callpeak_ATAC | `MACS3_callpeak_ATAC.1.1.sh` | 1.0 | `scripts/ATAC-seq/MACS3_callpeak_ATAC.1.4.sh` | bx_macs3_callpeak_atac 1.0 |
| peak_annotation | `peak_annotation.1.1.R` | 1.0 | `scripts/ATAC-seq/peak_annotation.1.2.R` | bx_peak_annotation 1.0 |
| differential_accessibility | `differential_accessibility.1.3.R` | 1.2 | `scripts/ATAC-seq/differential_accessibility.1.4.R` | bx_differential_accessibility 1.0 |
| atac_motif | `atac_motif.1.2.R` | 1.1 | `scripts/ATAC-seq/atac_motif.1.5.R` | bx_atac_motif 1.0 |
| tf_footprinting | `tf_footprinting.1.1.sh` | 1.0 | `scripts/ATAC-seq/tf_footprinting.1.4.sh` | bx_tf_footprinting 1.0 |
| functional_enrichment | `functional_enrichment.1.0.R` | (3.0 신규) | `scripts/ATAC-seq/functional_enrichment.1.2.R` | bx_functional_enrichment 1.0 |
| replicate_consistency | `replicate_consistency.1.0.sh` | (3.0 신규) | `scripts/ATAC-seq/replicate_consistency.1.1.sh` | bx_replicate_consistency 1.0 |

- 작업 파일 기준 커밋: `2fbd958`
- GATK_MarkDuplicates는 받은 스크립트(`GATK_MarkDuplicates_1.0.sh`, 이미지 `gatk 1.0`, `defs/ATAC-seq/bx_gatk_1.0.def`)를 그대로 쓰므로 이 폴더에 넣지 않았습니다.
- 실행 순서: bowtie2 → GATK_MarkDuplicates → organellar_filter → ATAC_QC → (ATAC_QC_plot, MACS3_callpeak_ATAC, replicate_consistency) → (peak_annotation, differential_accessibility, tf_footprinting) → (atac_motif, functional_enrichment)

## 만든 방법과 확인

- `build_release.py`가 작업 파일에서 배포 파일을 만듭니다. 맨 위 변경 이력을 "CLOSHA 2.0 대비" 한 블록으로 바꾸고, 파일 안의 자기 이름을 배포 이름으로 바꿉니다. 다른 줄은 바꾸지 않습니다.
- `python3 tools/check_release.py release/CLOSHA3/ATAC-seq/2026-10-16`로 배포 파일이 작업 파일과 (맨 위 주석과 파일 이름을 빼고) 같은지 확인했습니다. 11개 모두 일치합니다.
- `release.tsv`는 같은 대응표를 기계가 읽는 형식으로 둔 것입니다.

## 함께 넣은 것

- `docs/pipeline/`: 파이프라인 페이지 원고(`Portal_Content.md`, `.docx`)와 대표 이미지(분석 흐름 `pipeline.png`, 분석 개념 `concept.png`, 원본 SVG)
- `docs/`: 배포 시점의 모듈 원고(`Portal_Content.md`, `.docx`), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`)
- `results/`: 배포본으로 실행한 결과를 올리는 곳(올릴 파일 목록은 `results/README.md`)
