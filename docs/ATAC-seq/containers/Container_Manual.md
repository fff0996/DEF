# ATAC-seq 파이프라인 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 ATAC-seq 실행 이미지 설명이다. 각 이미지는 `defs/ATAC-seq/<이미지>.def`로 만든다. DEF 작성 규칙은 `docs/CLOSHA_DEF_Generator_Agent_v1.md`, 스크립트 규칙은 `docs/CLOSHA_Script_Rules_v1.md`를 따른다.

등록 메모: 버전과 도구 목록은 2026-10-14 기준 DEF 파일에서 옮겼다. DEF를 고치면 이 문서도 함께 고친다.

---

## 1. 공통 사항

### 국문
ATAC-seq 파이프라인의 각 모듈은 분석 도구를 미리 설치한 Apptainer 이미지(SIF) 안에서 실행됩니다. 이미지는 모듈 또는 같은 도구를 쓰는 모듈 묶음마다 하나씩 있습니다.
- **기반 운영체제:** Rocky Linux 9.8 공식 이미지(`rockylinux/rockylinux:9.8.20260525.0`)를 고유 식별값(digest)으로 고정하여, 언제 만들어도 같은 기반을 씁니다. 단, WGS 파이프라인과 같이 쓰는 bowtie2, gatk 이미지는 `rockylinux/rockylinux:9`(Rocky Linux 9 최신)를 씁니다.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **도구 설치:** Miniforge로 conda-forge와 bioconda 채널에서만 설치합니다. Anaconda 저장소(defaults 채널, repo.anaconda.com)는 사용하지 않습니다.
- **버전 고정:** 모든 도구는 버전을 지정해 설치하고, 설치된 전체 패키지 목록을 이미지 안에 기록합니다(`/opt/bio/share/<이미지 이름>/conda-explicit.txt`, 이름의 `_`는 `-`로 씀. 예: `/opt/bio/share/bx-atac-qc/conda-explicit.txt`).
- **도구 위치:** 모든 도구는 이미지 안의 `/opt/bio/bin`에 있으며 실행 경로(PATH)에 들어 있습니다.
- **분석 스크립트:** 이미지에 넣지 않고, 실행할 때 연결합니다. 그래서 스크립트를 고쳐도 이미지를 다시 만들 필요가 없습니다.
- **인터넷:** 실행 중에는 인터넷에 접속하지 않습니다. 필요한 도구는 이미지를 만들 때 모두 설치합니다.

### English
Each module of the ATAC-seq pipeline runs inside an Apptainer image (SIF) with its analysis tools preinstalled. There is one image per module, or per group of modules that use the same tools.
- **Base OS:** the official Rocky Linux 9.8 image (`rockylinux/rockylinux:9.8.20260525.0`), pinned by its digest so every build starts from the same base. The bowtie2 and gatk images, shared with the WGS pipeline, use `rockylinux/rockylinux:9` (latest Rocky Linux 9) instead.
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
| bowtie2 (`bx_bowtie2_1.0.def`) | 1.0 | bowtie2 (bowtie2.1.1.sh) | bowtie2 2.5.4, SAMtools 1.24 |
| gatk (`bx_gatk_1.0.def`) | 1.0 | GATK_MarkDuplicates (GATK_MarkDuplicates_1.0.sh) | GATK 4.6.2.0, SAMtools 1.24, OpenJDK 17 |
| bx_organellar_filter | 1.0 | organellar_filter (organellar_filter.1.1.sh) | SAMtools 1.23.1 |
| bx_atac_qc | 1.0 | ATAC_QC (ATAC_QC.1.1.R), ATAC_QC_plot (ATAC_QC_plot.1.1.R) | R 4.5.3, ATACseqQC 1.34.0, ChIPpeakAnno 3.44.0 |
| bx_macs3_callpeak_atac | 1.0 | MACS3_callpeak_ATAC (MACS3_callpeak_ATAC.1.1.sh) | MACS3 3.0.4, SAMtools 1.23.1 |
| bx_peak_annotation | 1.0 | peak_annotation (peak_annotation.1.1.R) | R 4.5.3, ChIPseeker 1.46.1 |
| bx_differential_accessibility | 1.0 | differential_accessibility (differential_accessibility.1.3.R) | R 4.5.3, edgeR 4.8.2, EDASeq 2.44.0, cqn 1.56.0 |
| bx_atac_motif | 1.0 | atac_motif (atac_motif.1.2.R) | R 4.5.3, monaLisa 1.16.0 |
| bx_tf_footprinting | 1.0 | tf_footprinting (tf_footprinting.1.1.sh) | TOBIAS 0.17.5, bedtools 2.31.1, SAMtools 1.24 |
| bx_functional_enrichment | 1.0 | functional_enrichment (functional_enrichment.1.0.R) | R 4.5.3, clusterProfiler 4.18.4 |
| bx_replicate_consistency | 1.0 | replicate_consistency (replicate_consistency.1.0.sh) | IDR 2.0.4.2, MACS3 3.0.4, SAMtools 1.23.1 |

bowtie2, gatk: Bootstrap `docker`, From `rockylinux/rockylinux:9` (digest 고정 없음), Miniforge3 26.5.3-0 (conda-forge, bioconda). WGS 파이프라인과 같이 쓰는 이미지다.

나머지(bx_): Bootstrap `docker`, From `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8), Miniforge3 26.7.2-0 (conda-forge, bioconda)

---

## 3. 이미지별 상세 / Image details

### 3.1 bowtie2 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_bowtie2_1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux:9` (Rocky Linux 9, digest 고정 없음) |
| conda 설치 도구 / installer | Miniforge3 26.5.3-0 (conda-forge, bioconda) |

- **설명(국문):** bowtie2로 read를 참조 유전체에 정렬하고 SAMtools로 BAM 변환·정렬·인덱스를 만드는 환경입니다. WGS 파이프라인과 같이 쓰는 이미지입니다.
- **Description (English):** Environment for aligning reads to the reference genome with bowtie2 and converting, sorting, and indexing BAM files with SAMtools. The image is shared with the WGS pipeline.

| 도구 | 버전 |
|---|---|
| bowtie2 | 2.5.4 |
| SAMtools | 1.24 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| bowtie2 | 2.5.4 | https://github.com/BenLangmead/bowtie2 |
| SAMtools | 1.24 | https://www.htslib.org/ |

- **태그(키워드):** 리드정렬, 참조유전체, 시퀀스정렬, BAM
- **내용(국문):** 시퀀싱 리드를 참조 유전체에 정렬하는 실행 환경입니다. bowtie2로 paired-end·single-end 리드를 정렬하고, SAMtools로 결과를 좌표 순으로 정렬한 BAM과 인덱스로 만듭니다. 사람 유전체 기준으로 인덱스를 올리는 데 약 4GB의 메모리를 사용합니다.
- **내용(영문):** Runtime environment for aligning sequencing reads to a reference genome. bowtie2 aligns paired-end and single-end reads, and SAMtools turns the alignments into coordinate-sorted BAM files with an index. Loading a human genome index uses about 4 GB of memory.

### 3.2 gatk 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_gatk_1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux:9` (Rocky Linux 9, digest 고정 없음) |
| conda 설치 도구 / installer | Miniforge3 26.5.3-0 (conda-forge, bioconda) |

- **설명(국문):** GATK(Picard)로 BAM의 중복 read를 표시하는 환경입니다. WGS 파이프라인의 다른 GATK 모듈(BaseRecalibrator, ApplyBQSR, Mutect2 등)과 같이 쓰는 이미지입니다.
- **Description (English):** GATK (Picard) environment for marking duplicate reads in BAM files. The image is shared with the other GATK modules of the WGS pipeline (BaseRecalibrator, ApplyBQSR, Mutect2 and others).

| 도구 | 버전 |
|---|---|
| GATK | 4.6.2.0 |
| SAMtools | 1.24 |
| HTSlib | 1.24 |
| OpenJDK | 17 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| GATK | 4.6.2.0 | https://gatk.broadinstitute.org/ |
| SAMtools | 1.24 | https://www.htslib.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |
| OpenJDK | 17 | https://openjdk.org/ |

- **태그(키워드):** 중복제거, 중복표시, BAM처리, GATK
- **내용(국문):** GATK(Picard)로 정렬된 BAM에서 PCR·광학 중복 read를 찾아 표시하는 실행 환경입니다. 중복 read는 지우지 않고 표시만 하며, 샘플별 중복 통계를 남깁니다. Java로 동작하므로 처리할 BAM 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for finding and marking PCR and optical duplicate reads in aligned BAM files with GATK (Picard). Duplicate reads are marked rather than removed, and duplicate metrics are written per sample. It runs on Java, so it needs memory matched to the BAM size.

### 3.3 bx_organellar_filter 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 세포소기관제거, 미토콘드리아, 엽록체, BAM필터링
- **내용(국문):** 정렬된 BAM에서 미토콘드리아·엽록체 등 세포소기관 염색체의 read를 제거하는 실행 환경입니다. SAMtools로 세포소기관 contig를 찾아 핵 염색체 read만 남기고, 제거 전후 read 수를 요약합니다.
- **내용(영문):** Runtime environment for removing reads on organellar chromosomes, such as mitochondria and chloroplasts, from aligned BAM files. SAMtools finds the organellar contigs, keeps only nuclear reads, and summarises the read counts before and after filtering.

### 3.4 bx_atac_qc 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| ATACseqQC | 1.34.0 | https://bioconductor.org/packages/ATACseqQC/ |
| ChIPpeakAnno | 3.44.0 | https://bioconductor.org/packages/ChIPpeakAnno/ |
| Rsamtools | 2.26.0 | https://bioconductor.org/packages/Rsamtools/ |
| GenomicAlignments | 1.46.0 | https://bioconductor.org/packages/GenomicAlignments/ |
| GenomicRanges | 1.62.1 | https://bioconductor.org/packages/GenomicRanges/ |
| GenomeInfoDb | 1.46.2 | https://bioconductor.org/packages/GenomeInfoDb/ |
| IRanges | 2.44.0 | https://bioconductor.org/packages/IRanges/ |

- **태그(키워드):** ATAC-seq품질평가, Tn5보정, 뉴클레오솜, TSS
- **내용(국문):** ATAC-seq 데이터의 품질을 평가하는 R 실행 환경입니다. ATACseqQC로 fragment 크기 분포와 TSS enrichment를 계산하고, Tn5 삽입 위치를 보정한 뒤 fragment를 뉴클레오솜 위치별로 나눕니다. TSS 주변 신호 heatmap도 같은 환경에서 그립니다.
- **내용(영문):** R runtime environment for assessing ATAC-seq data quality. ATACseqQC computes the fragment size distribution and TSS enrichment, corrects Tn5 insertion positions, and splits fragments by nucleosome position. The TSS signal heatmaps are drawn in the same environment.

### 3.5 bx_macs3_callpeak_atac 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| MACS3 | 3.0.4 | https://github.com/macs3-project/MACS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 피크검출, 열린염색질, MACS3, FRiP
- **내용(국문):** ATAC-seq에서 열린 염색질 영역(peak)을 찾는 실행 환경입니다. MACS3로 paired-end fragment 전체를 이용해 narrow 또는 broad peak를 검출하고, SAMtools로 샘플별 FRiP(peak 안 read 비율)을 계산합니다.
- **내용(영문):** Runtime environment for finding open chromatin regions (peaks) in ATAC-seq data. MACS3 calls narrow or broad peaks from whole paired-end fragments, and SAMtools computes the fraction of reads in peaks (FRiP) per sample.

### 3.6 bx_peak_annotation 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| ChIPseeker | 1.46.1 | https://bioconductor.org/packages/ChIPseeker/ |
| GenomicFeatures | 1.62.0 | https://bioconductor.org/packages/GenomicFeatures/ |
| txdbmaker | 1.6.2 | https://bioconductor.org/packages/txdbmaker/ |
| rtracklayer | 1.70.1 | https://bioconductor.org/packages/rtracklayer/ |
| optparse | 1.8.2 | https://cran.r-project.org/package=optparse |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |
| readr | 2.2.0 | https://readr.tidyverse.org/ |
| dplyr | 1.2.1 | https://dplyr.tidyverse.org/ |
| ggupset | 0.4.1 | https://cran.r-project.org/package=ggupset |

- **태그(키워드):** 피크주석, 유전체영역, 프로모터, 유전자주석
- **내용(국문):** peak가 유전체의 어느 영역(promoter, intron, intergenic 등)에 있는지와 가장 가까운 유전자를 붙이는 R 실행 환경입니다. ChIPseeker로 GFF/GTF 유전자 주석을 이용해 peak를 주석하고, 영역 분포와 TSS 주변 분포 그림을 만듭니다.
- **내용(영문):** R runtime environment for annotating where peaks lie in the genome (promoter, intron, intergenic, and so on) and which gene is nearest. ChIPseeker annotates peaks with a GFF/GTF gene annotation and draws the genomic distribution and the distribution around TSSs.

### 3.7 bx_differential_accessibility 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| edgeR | 4.8.2 | https://bioconductor.org/packages/edgeR/ |
| limma | 3.66.0 | https://bioconductor.org/packages/limma/ |
| EDASeq | 2.44.0 | https://bioconductor.org/packages/EDASeq/ |
| cqn | 1.56.0 | https://bioconductor.org/packages/cqn/ |
| bamsignals | 1.42.0 | https://bioconductor.org/packages/bamsignals/ |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |
| Hmisc | 5.3-0 | https://cran.r-project.org/package=Hmisc |
| hexbin | 1.28.6 | https://cran.r-project.org/package=hexbin |
| wesanderson | 0.3.7 | https://cran.r-project.org/package=wesanderson |

- **태그(키워드):** 차등접근성, 조건비교, 통계검정, GC보정
- **내용(국문):** 두 조건 사이에 접근성이 달라진 peak를 찾는 R 실행 환경입니다. 샘플별 peak를 합친 공통 peak에서 read 수를 세고, edgeR로 통계 검정을 합니다. GC 함량 편향은 EDASeq와 cqn으로 보정할 수 있으며, PCA와 샘플 상관 그림으로 반복 실험을 확인합니다.
- **내용(영문):** R runtime environment for finding peaks whose accessibility differs between two conditions. Reads are counted in a consensus peak set merged from all samples and tested with edgeR. GC-content bias can be corrected with EDASeq and cqn, and replicates are checked with PCA and sample correlation plots.

### 3.8 bx_atac_motif 1.0

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
| KernSmooth | 2.23-27 |
| ggplot2 | 4.0.3 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| monaLisa | 1.16.0 | https://bioconductor.org/packages/monaLisa/ |
| TFBSTools | 1.48.0 | https://bioconductor.org/packages/TFBSTools/ |
| universalmotif | 1.28.0 | https://bioconductor.org/packages/universalmotif/ |
| ComplexHeatmap | 2.26.1 | https://bioconductor.org/packages/ComplexHeatmap/ |
| circlize | 0.4.18 | https://cran.r-project.org/package=circlize |
| stabs | 0.7-1 | https://cran.r-project.org/package=stabs |
| glmnet | 5.0 | https://cran.r-project.org/package=glmnet |
| KernSmooth | 2.23-27 | https://cran.r-project.org/package=KernSmooth |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |

- **태그(키워드):** 모티프분석, 전사인자, 서열모티프, 유전자조절
- **내용(국문):** 접근성이 변한 peak에서 많이 나타나는 전사인자 결합 모티프를 찾는 R 실행 환경입니다. monaLisa로 peak를 접근성 변화 크기에 따라 구간으로 나누고, 구간마다 모티프와 k-mer 농축을 계산합니다. 회귀 분석으로 핵심 전사인자 후보를 고르며, peak가 많으면 메모리를 넉넉히 사용합니다.
- **내용(영문):** R runtime environment for finding transcription factor binding motifs that are over-represented in peaks with changed accessibility. monaLisa groups peaks into bins by the size of the change and computes motif and k-mer enrichment per bin. A regression step selects core transcription factor candidates; many peaks need ample memory.

### 3.9 bx_tf_footprinting 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| TOBIAS | 0.17.5 | https://github.com/loosolab/TOBIAS |
| MOODS | 1.9.4.2 | https://github.com/jhkorhonen/MOODS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.24 | https://www.htslib.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |
| bedtools | 2.31.1 | https://bedtools.readthedocs.io/ |

- **태그(키워드):** 전사인자결합, 풋프린팅, 유전자조절, TOBIAS
- **내용(국문):** ATAC-seq 신호에서 전사인자가 실제로 결합한 흔적(footprint)을 찾는 실행 환경입니다. TOBIAS로 Tn5 절단 편향을 보정하고 footprint 점수를 계산한 뒤, 두 조건 사이에 결합이 달라진 전사인자를 찾습니다.
- **내용(영문):** Runtime environment for finding the traces of actual transcription factor binding (footprints) in ATAC-seq signal. TOBIAS corrects the Tn5 cutting bias, scores footprints, and finds transcription factors whose binding differs between two conditions.

### 3.10 bx_functional_enrichment 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| clusterProfiler | 4.18.4 | https://bioconductor.org/packages/clusterProfiler/ |
| enrichplot | 1.30.5 | https://bioconductor.org/packages/enrichplot/ |
| AnnotationDbi | 1.72.0 | https://bioconductor.org/packages/AnnotationDbi/ |
| GO.db | 3.22.0 | https://bioconductor.org/packages/GO.db/ |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |

- **태그(키워드):** 기능분석, GO농축분석, 유전자기능, 유전자온톨로지
- **내용(국문):** peak 근처 유전자들이 어떤 생물학적 기능에 모여 있는지 GO 농축 분석을 하는 R 실행 환경입니다. clusterProfiler로 검정하고, 종별 유전자 주석은 OrgDb 파일로 받아 인터넷 연결 없이 수행합니다.
- **내용(영문):** R runtime environment for GO enrichment analysis of which biological functions the genes near peaks share. clusterProfiler runs the tests, and the species gene annotation is read from an OrgDb file, so the analysis runs without internet access.

### 3.11 bx_replicate_consistency 1.0

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

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| IDR | 2.0.4.2 | https://github.com/kundajelab/idr |
| MACS3 | 3.0.4 | https://github.com/macs3-project/MACS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 재현성분석, 반복실험, IDR, 피크검출
- **내용(국문):** 반복 실험 사이에 peak가 얼마나 재현되는지 IDR로 평가하는 실행 환경입니다. MACS3로 반복 실험마다 느슨한 기준의 peak를 찾고, IDR로 두 반복에서 함께 나타나는 재현성 있는 peak 세트를 고릅니다.
- **내용(영문):** Runtime environment for assessing with IDR how reproducible peaks are between replicates. MACS3 calls relaxed peaks for each replicate, and IDR selects the reproducible peak set shared by two replicates.

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
