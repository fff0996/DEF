# Spatial transcriptomics 파이프라인 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 공간 전사체 실행 이미지 설명입니다. 이미지는 `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def`로 만듭니다. 1.0에 svf(Moran's I)용 ape를 더한 것이 1.1이며, 배포는 1.1만 합니다. DEF 작성 규칙은 `docs/CLOSHA_DEF_Generator_Agent_v1.md`, 스크립트 규칙은 `docs/CLOSHA_Script_Rules_v1.md`를 따릅니다.

등록 메모: 버전과 도구 목록은 2026-10-22 기준 DEF 파일에서 옮겼습니다. DEF를 고치면 이 문서도 함께 고칩니다.

---

## 1. 공통 사항

### 국문
공간 전사체 파이프라인의 모든 모듈은 분석 도구를 미리 설치한 Apptainer 이미지(SIF) 하나(bx_spatial) 안에서 실행됩니다.
- **기반 운영체제:** Rocky Linux 9.8 공식 이미지(`rockylinux/rockylinux:9.8.20260525.0`)를 고유 식별값(digest)으로 고정하여, 언제 만들어도 같은 기반을 씁니다.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **도구 설치:** Miniforge로 conda-forge와 bioconda 채널에서만 설치합니다. Anaconda 저장소(defaults 채널, repo.anaconda.com)는 사용하지 않습니다.
- **버전 고정:** 모든 도구는 버전을 지정해 설치하고, 설치된 전체 패키지 목록을 이미지 안에 기록합니다(`/opt/bio/share/bx-spatial/conda-explicit.txt`).
- **R 버전:** R 4.3.3입니다. 세포 유형 분해(RCTD)용 spacexr이 bioconda에 R 4.3용만 있고, 마커 계산을 빠르게 하는 presto가 R 4.4까지라 이 조합이 맞는 R 4.3을 썼습니다.
- **도구 위치:** 모든 도구는 이미지 안의 `/opt/bio/bin`에 있으며 실행 경로(PATH)에 들어 있습니다.
- **분석 스크립트:** 이미지에 넣지 않고, 실행할 때 연결합니다. 그래서 스크립트를 고쳐도 이미지를 다시 만들 필요가 없습니다.
- **인터넷:** 실행 중에는 인터넷에 접속하지 않습니다.

### English
Every module of the spatial transcriptomics pipeline runs inside one Apptainer image (SIF), bx_spatial, with its analysis tools preinstalled.
- **Base OS:** the official Rocky Linux 9.8 image (`rockylinux/rockylinux:9.8.20260525.0`), pinned by its digest so every build starts from the same base.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **Tool installation:** Miniforge, from the conda-forge and bioconda channels only. Anaconda repositories (the defaults channel, repo.anaconda.com) are not used.
- **Pinned versions:** Every tool is installed at a fixed version, and the full list of installed packages is recorded in the image (`/opt/bio/share/bx-spatial/conda-explicit.txt`).
- **R version:** R 4.3.3. spacexr (RCTD cell-type deconvolution) is available on bioconda for R 4.3 only, and presto (fast marker testing) supports R up to 4.4, so R 4.3 is the version where both fit.
- **Tool location:** All tools are in `/opt/bio/bin` inside the image and on the PATH.
- **Analysis scripts:** Not stored in the image; they are bound at run time, so a script update does not need a new image.
- **Internet:** No internet access at run time.

---

## 2. 이미지 목록 / Images

| 이미지 | 버전 | 사용하는 모듈 (스크립트) | 주요 도구 |
|---|---|---|---|
| bx_spatial | 1.1 | spatial_prep (spatial_prep.1.0.R), spatial_cluster (spatial_cluster.1.0.R), spatial_svf (spatial_svf.1.0.R), spatial_merge (spatial_merge.1.1.R), spatial_condition_de (spatial_condition_de.1.0.R, 작업 파일 1.1), spatial_hd_prep (spatial_hd_prep.1.0.R), spatial_hd_cluster (spatial_hd_cluster.1.0.R), spatial_labelTransfer, spatial_rctd, check_reference | R 4.3.3, Seurat 5.3.0, spacexr 2.2.1, DESeq2 1.42.0, harmony 1.2.3 |

Bootstrap `docker`, From `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8), Miniforge3 26.7.2-0 (conda-forge, bioconda)입니다.

---

## 3. 이미지 상세 / Image details

### 3.1 bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** Seurat으로 10x Visium과 Visium HD 공간 전사체를 분석하는 환경입니다. 정규화(SCTransform, glmGamPoi), 군집과 마커(presto), 슬라이스 통합(harmony), 세포 유형 분해(spacexr RCTD), 조건 간 pseudobulk 비교(DESeq2), Visium HD 위치 파일(parquet) 읽기(arrow), 공간 가변 유전자의 Moran's I 계산(ape)을 지원합니다.
- **Description (English):** Environment for analysing 10x Visium and Visium HD spatial transcriptomics with Seurat. It supports normalisation (SCTransform, glmGamPoi), clustering and markers (presto), slice integration (harmony), cell-type deconvolution (spacexr RCTD), pseudobulk condition comparison (DESeq2), reading Visium HD position files (parquet) with arrow, and Moran's I for spatially variable genes with ape.

| 도구 | 버전 |
|---|---|
| R | 4.3.3 |
| Seurat | 5.3.0 |
| SeuratObject | 5.2.0 |
| presto | 1.0.0 |
| spacexr | 2.2.1 |
| DESeq2 | 1.42.0 |
| harmony | 1.2.3 |
| glmGamPoi | 1.14.0 |
| hdf5r | 1.3.12 |
| arrow | 21.0.0 |
| ape | 5.8-1 |
| ggplot2 | 3.5.2 |
| patchwork | 1.3.2 |
| Matrix | 1.6-5 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.3.3 | https://www.r-project.org/ |
| Seurat | 5.3.0 | https://satijalab.org/seurat/ |
| SeuratObject | 5.2.0 | https://cran.r-project.org/package=SeuratObject |
| presto | 1.0.0 | https://github.com/immunogenomics/presto |
| spacexr | 2.2.1 | https://github.com/dmcable/spacexr |
| DESeq2 | 1.42.0 | https://bioconductor.org/packages/DESeq2/ |
| harmony | 1.2.3 | https://cran.r-project.org/package=harmony |
| glmGamPoi | 1.14.0 | https://bioconductor.org/packages/glmGamPoi/ |
| hdf5r | 1.3.12 | https://cran.r-project.org/package=hdf5r |
| arrow | 21.0.0 | https://arrow.apache.org/docs/r/ |
| ape | 5.8-1 | https://cran.r-project.org/package=ape |
| ggplot2 | 3.5.2 | https://ggplot2.tidyverse.org/ |
| patchwork | 1.3.2 | https://patchwork.data-imaginist.com/ |
| Matrix | 1.6-5 | https://cran.r-project.org/package=Matrix |

- **태그(키워드):** 공간전사체, Visium, VisiumHD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

---

## 4. 검증 빌드 / Verification build

2026-10-22 Codespace(2코어, 메모리 7GB)에서 root 권한 빌드(`apptainer build`)로 확인했습니다. 운영 HPC에서는 빌드하지 않았고 SIF를 배포하지 않았습니다.

| 이미지 | 결과 | 시간 | SIF 크기 | `%test` |
|---|---|---|---|---|
| bx_spatial 1.0 | 성공 | 8분 | 1.29GB | Seurat 5.3.0 / R 4.3.3 runtime dependency checks passed |
| bx_spatial 1.1 | 성공 | 8분 | 1.29GB | 같은 문구. 1.0 검사에 더해 작은 격자에서 Moran's I 계산 확인 |

- 호스트 영향 확인: 빌드 중 호스트의 `/proc`·`/sys` 쓰기 없음(strace), sysctl 변화 없음, `/__closha_build` 남지 않음. 호스트 `/tmp`·`/var/tmp`의 변화는 빌드와 무관한 프로그램(VS Code, SQLite 임시 파일)뿐이었습니다.
- 빌드 기록: `/workspaces/.closha_build_test/root/logs/bx_spatial.root.summary`, `bx_spatial_1_1.root.summary`(저장소 밖).
- SIF 실행 확인: 1.0으로 Visium(prep, cluster, merge, condition_de)과 Visium HD(hd_prep, hd_cluster, condition_de)를 실행했고, 1.0에서 ape가 없어 실패한 svf는 1.1로 다시 실행해 성공했습니다(`docs/Spatial_Transcriptomics_Analysis_Pipeline/Spatial_Notes.md` 6.1).
