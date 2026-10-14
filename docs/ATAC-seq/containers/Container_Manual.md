# ATAC-seq 파이프라인 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 ATAC-seq 실행 이미지 설명이다. 각 이미지는 `defs/ATAC-seq/<이미지>.def`로 만든다. DEF 작성 규칙은 `docs/CLOSHA_DEF_Generator_Agent_v1.md`, 스크립트 규칙은 `docs/CLOSHA_Script_Rules_v1.md`를 따른다.

등록 메모: 버전과 도구 목록은 2026-10-14 기준 DEF 파일에서 옮겼다. DEF를 고치면 이 문서도 함께 고친다.

---

## 1. 공통 사항

### 국문
ATAC-seq 파이프라인의 각 모듈은 분석 도구를 미리 설치한 Apptainer 이미지(SIF) 안에서 실행됩니다. 이미지는 모듈 또는 같은 도구를 쓰는 모듈 묶음마다 하나씩 있습니다.
- **기반 운영체제:** Rocky Linux 9.8 공식 이미지(`rockylinux/rockylinux:9.8.20260525.0`)를 고유 식별값(digest)으로 고정하여, 언제 만들어도 같은 기반을 씁니다.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **도구 설치:** Miniforge로 conda-forge와 bioconda 채널에서만 설치합니다. Anaconda 저장소(defaults 채널, repo.anaconda.com)는 사용하지 않습니다.
- **버전 고정:** 모든 도구는 버전을 지정해 설치하고, 설치된 전체 패키지 목록을 이미지 안에 기록합니다(`/opt/bio/share/<이미지 이름>/conda-explicit.txt`, 이름의 `_`는 `-`로 씀. 예: `/opt/bio/share/bx-atac-qc/conda-explicit.txt`).
- **도구 위치:** 모든 도구는 이미지 안의 `/opt/bio/bin`에 있으며 실행 경로(PATH)에 들어 있습니다.
- **분석 스크립트:** 이미지에 넣지 않고, 실행할 때 연결합니다. 그래서 스크립트를 고쳐도 이미지를 다시 만들 필요가 없습니다.
- **인터넷:** 실행 중에는 인터넷에 접속하지 않습니다. 필요한 도구는 이미지를 만들 때 모두 설치합니다.

### English
Each module of the ATAC-seq pipeline runs inside an Apptainer image (SIF) with its analysis tools preinstalled. There is one image per module, or per group of modules that use the same tools.
- **Base OS:** the official Rocky Linux 9.8 image (`rockylinux/rockylinux:9.8.20260525.0`), pinned by its digest so every build starts from the same base.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **Tool installation:** Miniforge, from the conda-forge and bioconda channels only. Anaconda repositories (the defaults channel, repo.anaconda.com) are not used.
- **Pinned versions:** Every tool is installed at a fixed version, and the full list of installed packages is recorded in the image (`/opt/bio/share/<image name>/conda-explicit.txt`, with `_` written as `-`; for example `/opt/bio/share/bx-atac-qc/conda-explicit.txt`).
- **Tool location:** All tools are in `/opt/bio/bin` inside the image and on the PATH.
- **Analysis scripts:** Not stored in the image; they are bound at run time, so a script update does not need a new image.
- **Internet:** No internet access at run time; everything needed is installed when the image is built.

---

## 2. 이미지 목록 / Images

| 이미지 | 버전 | 사용하는 모듈 (스크립트) | 주요 도구 |
|---|---|---|---|
| bx_organellar_filter | 1.0 | organellar_filter (organellar_filter.1.2.sh) | SAMtools 1.23.1 |
| bx_atac_qc | 1.0 | ATAC_QC (ATAC_QC.1.2.R), ATAC_QC_plot (ATAC_QC_plot.1.2.R) | R 4.5.3, ATACseqQC 1.34.0, ChIPpeakAnno 3.44.0 |
| bx_macs3_callpeak_atac | 1.0 | MACS3_callpeak_ATAC (MACS3_callpeak_ATAC.1.3.sh) | MACS3 3.0.4, SAMtools 1.23.1 |
| bx_peak_annotation | 1.0 | peak_annotation (peak_annotation.1.2.R) | R 4.5.3, ChIPseeker 1.46.1 |
| bx_differential_accessibility | 1.0 | differential_accessibility (differential_accessibility.1.2.R) | R 4.5.3, edgeR 4.8.2, EDASeq 2.44.0, cqn 1.56.0 |
| bx_atac_motif | 1.0 | atac_motif (atac_motif.1.4.R) | R 4.5.3, monaLisa 1.16.0 |
| bx_tf_footprinting | 1.0 | tf_footprinting (tf_footprinting.1.3.sh) | TOBIAS 0.17.5, bedtools 2.31.1, SAMtools 1.24 |
| bx_functional_enrichment | 1.0 | functional_enrichment (functional_enrichment.1.1.R) | R 4.5.3, clusterProfiler 4.18.4 |
| bx_replicate_consistency | 1.0 | replicate_consistency (replicate_consistency.1.1.sh) | IDR 2.0.4.2, MACS3 3.0.4, SAMtools 1.23.1 |

공통: Bootstrap `docker`, From `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8), Miniforge3 26.7.2-0 (conda-forge, bioconda)

---

## 3. 이미지별 상세 / Image details

### 3.1 bx_organellar_filter 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_organellar_filter.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** 정렬된 BAM에서 세포소기관(미토콘드리아, 엽록체) read를 제거하는 SAMtools 환경입니다.
- **Description (English):** SAMtools environment for removing organellar (mitochondrial and chloroplast) reads from aligned BAM files.

| 도구 | 버전 |
|---|---|
| SAMtools | 1.23.1 |
| HTSlib | 1.23.1 |

### 3.2 bx_atac_qc 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_atac_qc.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** ATAC-seq 품질 평가(fragment 크기 분포, TSS enrichment, Tn5 보정, 뉴클레오솜 분류)와 TSS 주변 신호 그림을 위한 R 환경입니다. ATAC_QC와 ATAC_QC_plot이 같은 이미지를 씁니다.
- **Description (English):** R environment for ATAC-seq quality control (fragment size distribution, TSS enrichment, Tn5 shift, nucleosome classes) and TSS signal plots; ATAC_QC and ATAC_QC_plot share it.

| 도구 | 버전 |
|---|---|
| R | 4.5.3 |
| ATACseqQC | 1.34.0 |
| ChIPpeakAnno | 3.44.0 |
| Rsamtools | 2.26.0 |
| GenomicAlignments | 1.46.0 |
| GenomicRanges | 1.62.1 |
| GenomeInfoDb | 1.46.2 |
| IRanges | 2.44.0 |

### 3.3 bx_macs3_callpeak_atac 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_macs3_callpeak_atac.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** MACS3로 ATAC-seq peak를 찾고 SAMtools로 FRiP를 계산하는 환경입니다.
- **Description (English):** Environment for calling ATAC-seq peaks with MACS3 and computing FRiP with SAMtools.

| 도구 | 버전 |
|---|---|
| MACS3 | 3.0.4 |
| Python | 3.13 |
| SAMtools | 1.23.1 |
| HTSlib | 1.23.1 |

### 3.4 bx_peak_annotation 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_peak_annotation.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** ChIPseeker로 peak의 유전체 위치와 가까운 유전자를 주석하는 R 환경입니다.
- **Description (English):** R environment for annotating peaks with genomic features and nearby genes using ChIPseeker.

| 도구 | 버전 |
|---|---|
| R | 4.5.3 |
| ChIPseeker | 1.46.1 |
| GenomicFeatures | 1.62.0 |
| txdbmaker | 1.6.2 |
| rtracklayer | 1.70.1 |
| optparse | 1.8.2 |
| ggplot2 | 4.0.3 |
| readr | 2.2.0 |
| dplyr | 1.2.1 |
| ggupset | 0.4.1 |

### 3.5 bx_differential_accessibility 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_differential_accessibility.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** edgeR로 조건 간 차등 접근성을 분석하고, EDASeq와 cqn으로 GC 편향을 보정하는 R 환경입니다.
- **Description (English):** R environment for differential accessibility with edgeR, with GC-bias correction by EDASeq and cqn.

| 도구 | 버전 |
|---|---|
| R | 4.5.3 |
| edgeR | 4.8.2 |
| limma | 3.66.0 |
| EDASeq | 2.44.0 |
| cqn | 1.56.0 |
| bamsignals | 1.42.0 |
| ggplot2 | 4.0.3 |
| Hmisc | 5.3-0 |
| hexbin | 1.28.6 |
| wesanderson | 0.3.7 |

### 3.6 bx_atac_motif 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_atac_motif.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** monaLisa로 접근성 변화 구간별 모티프 농축을 분석하는 R 환경입니다.
- **Description (English):** R environment for motif enrichment across bins of accessibility change with monaLisa.

| 도구 | 버전 |
|---|---|
| R | 4.5.3 |
| monaLisa | 1.16.0 |
| TFBSTools | 1.48.0 |
| universalmotif | 1.28.0 |
| ComplexHeatmap | 2.26.1 |
| circlize | 0.4.18 |
| stabs | 0.7-1 |
| glmnet | 5.0 |
| ggplot2 | 4.0.3 |

### 3.7 bx_tf_footprinting 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_tf_footprinting.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** TOBIAS로 전사인자 footprint를 계산하고 조건 간 결합 변화를 비교하는 환경입니다. peak 병합에 bedtools를 씁니다.
- **Description (English):** Environment for transcription factor footprinting and differential binding with TOBIAS; bedtools merges the peaks.

| 도구 | 버전 |
|---|---|
| TOBIAS | 0.17.5 |
| MOODS | 1.9.4.2 |
| Python | 3.13 |
| SAMtools | 1.24 |
| HTSlib | 1.24 |
| bedtools | 2.31.1 |

### 3.8 bx_functional_enrichment 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_functional_enrichment.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** clusterProfiler로 GO 기능 농축을 분석하는 R 환경입니다. 종별 OrgDb 파일은 이미지에 넣지 않고 입력으로 받습니다.
- **Description (English):** R environment for GO enrichment with clusterProfiler; the species OrgDb file is given as an input, not stored in the image.

| 도구 | 버전 |
|---|---|
| R | 4.5.3 |
| clusterProfiler | 4.18.4 |
| enrichplot | 1.30.5 |
| AnnotationDbi | 1.72.0 |
| GO.db | 3.22.0 |
| ggplot2 | 4.0.3 |

### 3.9 bx_replicate_consistency 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_replicate_consistency.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8, `9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** 반복 실험 간 peak 재현성을 IDR로 평가하는 환경입니다. IDR은 다른 도구와 충돌하지 않도록 별도 Python 3.10 환경에 설치되어 있습니다.
- **Description (English):** Environment for peak reproducibility between replicates with IDR; IDR is installed in its own Python 3.10 environment to avoid conflicts with the other tools.

| 도구 | 버전 |
|---|---|
| IDR | 2.0.4.2 (Python 3.10, NumPy 1.23.5) |
| MACS3 | 3.0.4 |
| Python | 3.13 |
| SAMtools | 1.23.1 |
| HTSlib | 1.23.1 |

---

## 4. 실행 방법 / How modules run

### 국문
포탈은 모듈마다 아래와 같이 이미지 안에서 스크립트를 실행합니다. 사용자가 직접 입력할 필요는 없으며, 포탈 실행 환경(Processor Core, Memory)과 모듈 인자로 정해집니다.
```
apptainer exec --cleanenv \
  -B <사용자 폴더> -B <스크립트 폴더> -B <데이터 폴더> \
  <이미지>.sif bash <스크립트>.sh key=value ...
```
R 스크립트는 `Rscript <스크립트>.R key=value ...`로 실행됩니다. 파일과 폴더는 인자로 받은 경로만 이미지 안에서 보입니다.

### English
The portal runs each module's script inside its image as shown above; users do not type it. The Processor Core and Memory settings and the module arguments decide the run. R scripts run as `Rscript <script>.R key=value ...`. Only paths given as arguments are visible inside the image.

---

## 5. 이미지 만들기 / Building an image

등록 메모: 관리자용이다. 운영 HPC 노드에서 관리자가 만든다.

```
apptainer build --fakeroot <이미지>.1.0.sif defs/ATAC-seq/<이미지>.1.0.def
```
- 빌드는 호스트를 바꾸지 않도록 만들어져 있습니다. 빌드 중 임시 파일은 컨테이너 안의 별도 공간에만 쓰고, 예상하지 못한 호스트 폴더가 연결되어 있으면 설치 전에 빌드를 멈춥니다.
- 빌드 끝에 `%test`가 도구 버전과 실행을 확인합니다.
- 이미 만든 이미지는 DEF의 설치 내용이 바뀔 때만 다시 만듭니다. 분석 스크립트가 바뀐 경우에는 다시 만들 필요가 없습니다.
