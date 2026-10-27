# Visium HD 공간 전사체 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 Visium HD 파이프라인 모듈의 원고입니다. spatial_condition_de와 check_reference는 두 파이프라인이 같이 쓰는 모듈이라 `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/Portal_Content.md`에도 같은 내용이 있습니다(고칠 때 양쪽을 함께 고친다). 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다. 예시 경로가 그대로 넘어가면 스크립트가 "not found"로 멈춥니다.
- 선택(Optional) 입력은 빈 값이 "사용 안 함"입니다.
- 스크립트 사용 예제는 등록하는 인자를 모두 적었고, 기본값이 있는 옵션은 기본값으로 적었습니다. 예시 값은 Visium HD 기준입니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 모든 모듈이 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)입니다.
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류·경고 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지웁니다.
- 카테고리는 대분류 = 분석 단계, 중분류 = 구체적 작업으로 정했습니다(사용자 결정, 2026-10-27). 데이터 종류는 모듈 이름(spatial_*)이 보여 줍니다. spatial_prep·spatial_hd_prep은 Preprocessing(신규) / Normalization(신규), 군집 모듈은 Clustering(신규) / Spatial_Clustering(신규; 묶는 대상별 중분류로 나중에 Cell_Clustering, Sample_Clustering 등을 둔다), 공간 통계량(Moran's I 등)을 계산하는 spatial_svf·spatial_hd_svf(hd_svf는 p값과 BH 보정까지 냄)와 p값을 내는 검정인 spatial_condition_de(DESeq2)는 Statistics_and_Visualization 아래 Spatial_Statistics(신규)와 Differential_Analysis(신규)에 둡니다. 세포 유형 모듈과 check_reference는 기존 Annotation의 "무엇에 주석을 다는가" 방식에 맞춰 Cell_Type_Annotation(신규)입니다. 포탈의 현재 이름 Statisitcs_and_Visualization은 오타라 Statistics_and_Visualization으로 적었습니다.
- 버전은 배포 번호입니다. CLOSHA 2.0 모듈은 2.0 번호 + 1(이번에 모두 스크립트 규칙에 맞춰 고쳐 1.1)이고, 3.0에서 새로 만든 모듈은 1.0입니다.

---

## 1. spatial_hd_prep

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_prep | spatial_hd_prep |
| 서브 타이틀 | Visium HD 불러오기와 정규화 | Loading and normalisation of Visium HD |
| 버전 | 1.0 | |
| 카테고리 대분류 | Preprocessing (신규) | Preprocessing (new) |
| 카테고리 중분류 | Normalization (신규) | Normalization (new) |
| 태그 | spatial transcriptomics, Visium HD, Seurat, sketch, QC | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_prep.1.0.R | |
| Processor Core (제안) | 8코어, 메모리 64GB | 8 cores, 64 GB of memory |

등록 메모: 작업 파일 `spatial_hd_prep.1.1.R`을 배포 번호 1.0으로 올립니다.

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
10x Visium HD 슬라이드를 정한 크기의 bin(8 또는 16µm)으로 불러와 거르고 정규화한 뒤, 군집에 쓸 대표 bin 표본(sketch)을 만듭니다. Visium HD는 슬라이드 한 장에 bin이 수십만 개라, 모든 bin으로 군집을 계산하는 대신 정보가 많은 bin을 골라 계산합니다.
- Space Ranger의 binned_outputs에서 bin 크기에 맞는 count 행렬과 위치(parquet), 조직 이미지를 불러옵니다.
- UMI 수와 검출 유전자 수로 bin을 거르고, log 정규화와 가변 유전자 선택을 합니다(SCTransform은 bin이 너무 많아 쓰지 않습니다).
- leverage score로 슬라이드마다 sketch_cells개 bin을 뽑아 sketch assay를 만듭니다.
- bin별 UMI·유전자 수 분포와 조직 위 분포를 그리고, 슬라이드별 요약표를 만듭니다. 결과 폴더는 spatial_hd_cluster의 입력입니다.

### 내용(영문)
Loads 10x Visium HD slides at a chosen bin size (8 or 16 um), filters and normalises the bins, and draws a representative sample of bins (sketch) for clustering. A Visium HD slide has hundreds of thousands of bins, so clustering runs on informative sampled bins instead of all of them.
- The count matrix, positions (parquet) and tissue image of the chosen bin size are read from the Space Ranger binned_outputs.
- Bins are filtered by UMI counts and detected genes, log-normalised, and variable genes are selected (SCTransform is not used because there are too many bins).
- Leverage-score sampling keeps sketch_cells bins per slide in a sketch assay.
- Counts and genes per bin are drawn as violins and on the tissue, and a per-slide summary table is written. The output folder is the input of spatial_hd_cluster.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/visium_hd | Visium HD 슬라이드 폴더 모음. 슬라이드마다 하위 폴더 하나(폴더 이름 = 슬라이드 이름)이고, 각 폴더에 binned_outputs/(또는 outs/binned_outputs/)와 그 안의 square_<NNN>um/filtered_feature_bc_matrix.h5, spatial/(tissue_positions.parquet, 이미지)이 있어야 함. 슬라이드 폴더 하나를 직접 줘도 됨 | Folder of Visium HD slides: one subfolder per slide (folder name = slide name), each with binned_outputs/ (or outs/binned_outputs/) holding square_<NNN>um/filtered_feature_bc_matrix.h5 and spatial/ (tissue_positions.parquet, images). One slide folder can also be given directly |
| Output | Required | Directory | output_dir | /data/spatial_hd_prep | 결과 폴더. 슬라이드마다 <slide>/<slide>_hd_prep.rds(모든 bin과 sketch assay), <slide>/plots/<slide>_qc.png·.pdf, hd_prep_summary.tsv | Output folder: per slide <slide>/<slide>_hd_prep.rds (all bins and the sketch assay), <slide>/plots/<slide>_qc.png and .pdf, and hd_prep_summary.tsv |
| Option | Optional | List | bin_size | 8 | bin 크기(µm): 8(권장) 또는 16. 2µm는 메모리 때문에 지원하지 않음 | Bin size (um): 8 (recommended) or 16; 2 um is not supported (memory) |
| Option | Optional | Integer | min_counts | 10 | UMI 수가 이보다 적은 bin 제거 | Bins with fewer UMI counts are removed |
| Option | Optional | Integer | min_features | 0 | 검출 유전자 수가 이보다 적은 bin 제거. 0이면 거르지 않음 | Bins with fewer detected genes are removed; 0 keeps all |
| Option | Optional | Integer | nfeatures | 2000 | 슬라이드별 가변 유전자 수 | Variable genes per slide |
| Option | Optional | Integer | sketch_cells | 50000 | 슬라이드마다 sketch에 남기는 bin 수(leverage score 추출). 군집은 sketch로 계산 | Bins kept per slide in the sketch (leverage-score sampling); clustering runs on the sketch |
| Option | Optional | Float | pt_size | 4 | 조직 QC 그림의 bin 크기(Seurat pt.size.factor) | Bin size in the tissue QC plot (Seurat pt.size.factor) |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| Space Ranger 결과에서 binned_outputs 폴더를 통째로 올려 주세요. 8·16µm 폴더의 조직 이미지는 2µm 폴더 이미지의 하드링크라, 일부 폴더만 압축을 풀거나 복사하면 이미지가 빠질 수 있습니다. | Upload the whole binned_outputs folder of Space Ranger. The tissue images of the 8 and 16 um folders are hard links to those of the 2 um folder, so extracting or copying only some folders can lose the images. |
| 8µm가 세포 크기에 가까워 권장 크기입니다. 16µm는 메모리와 시간이 4분의 1 정도로 줄어 큰 슬라이드나 빠른 확인에 씁니다. | 8 um is close to cell size and recommended; 16 um needs about a quarter of the memory and time, for large slides or quick checks. |
| 메모리는 bin 수에 비례합니다. 8µm는 슬라이드당 32~64GB를 권장합니다. 메모리가 부족하면 bin_size=16이나 min_counts를 올려 다시 실행합니다. | Memory grows with the number of bins; 32-64 GB per slide is recommended for 8 um. When memory runs out, rerun with bin_size=16 or a higher min_counts. |
| 한 슬라이드가 실패해도 나머지는 계속 처리하며, hd_prep_summary.tsv에 상태로 남습니다. 모든 슬라이드가 실패할 때만 종료 코드 1입니다. | A failed slide does not stop the others and is listed with its status in hd_prep_summary.tsv; the exit code is 1 only when every slide fails. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/spatial_hd_prep_concept.png`

- 레전드(국문): **그림. Visium HD bin 불러오기와 sketch.** (A) Space Ranger가 2µm 사각형을 8µm 또는 16µm bin으로 묶은 binned_outputs에서 bin_size에 맞는 행렬과 위치(parquet)를 읽습니다. 2µm는 메모리 때문에 지원하지 않습니다. (B) bin별 UMI·유전자 수로 거르고(min_counts, min_features) log 정규화합니다. (C) leverage score로 정보가 많은 bin(진한 파랑)을 슬라이드마다 sketch_cells개 뽑아 sketch assay를 만듭니다. 군집은 이 sketch로 계산합니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Loading Visium HD bins and sketching.** (A) The matrix and positions (parquet) of the chosen bin_size are read from the Space Ranger binned_outputs, where 2 um squares are grouped into 8 or 16 um bins; 2 um is not supported (memory). (B) Bins are filtered by UMI counts and genes (min_counts, min_features) and log-normalised. (C) Leverage-score sampling keeps sketch_cells informative bins (dark blue) per slide in a sketch assay, on which clustering runs. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_hd_prep.1.0.R \
  input_dir=/data/visium_hd \
  output_dir=/data/spatial_hd_prep \
  bin_size=8 \
  min_counts=10 \
  min_features=0 \
  nfeatures=2000 \
  sketch_cells=50000 \
  pt_size=4 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 Visium HD 마우스 뇌(FFPE) 한 장의 16µm bin입니다. Codespace 메모리 때문에 4분면으로 잘라 슬라이드 4장(각 약 2만 2천~2만 7천 bin)으로 쓰고, 유전자는 6,000개로 줄였습니다. 대표 슬라이드는 brain_left_top입니다.

**결과 1. bin별 UMI·유전자 수 QC(대표 그림)**
- 결과 파일: `<slide>/plots/<slide>_qc.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_prep_result_1.png`

- 레전드(국문): **bin별 UMI 수와 검출 유전자 수.** 왼쪽 두 violin은 bin별 UMI 수(nCount_Spatial.016um)와 검출 유전자 수(nFeature_Spatial.016um) 분포이고, 오른쪽은 UMI 수를 조직 위에 칠한 것입니다. 조직 밖이나 UMI가 매우 낮은 bin이 많으면 min_counts, min_features를 올립니다. 예시 데이터에서는 bin당 UMI 중앙값이 711, 유전자 중앙값이 570이었고, 피질에서 높고 백질(뇌량)에서 낮았습니다. 분석에 쓰지 않은 4분면 바깥은 조직 이미지만 보입니다. 두 violin의 제목이 붙어 보이는 것은 그림 배치 문제로, 다음 버전에서 고칩니다.
- 레전드(영문): **UMI counts and detected genes per bin.** The two violins show UMI counts (nCount_Spatial.016um) and detected genes (nFeature_Spatial.016um) per bin; the right panel shows UMI counts on the tissue. With many bins outside the tissue or with very low counts, raise min_counts or min_features. In the example data the median bin had 711 UMIs and 570 genes, higher in the cortex and lower in the white matter (corpus callosum); outside the quadrant only the tissue image shows. The two violin titles run together, a layout issue to be fixed in the next version.

**결과 2. 슬라이드별 요약표**
- 결과 파일: `hd_prep_summary.tsv` (표를 그림으로 만들었습니다)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_prep_result_2.png`

- 레전드(국문): **슬라이드별 bin 수와 sketch.** 거르기 전·후 bin 수(Bins_raw, Bins), bin당 UMI·유전자 중앙값, sketch에 남긴 bin 수, 상태와 걸린 시간(초)입니다. 예시 데이터에서는 슬라이드 4장이 2만 2,477~2만 6,981 bin이었고, Space Ranger가 이미 조직 밖 bin을 걸러 min_counts=10으로 빠진 bin은 없었으며, 슬라이드마다 5,000 bin을 sketch로 뽑았습니다(테스트 설정, 기본값 5만).
- 레전드(영문): **Bins and sketch per slide.** Bins before and after filtering (Bins_raw, Bins), median UMIs and genes per bin, sketched bins, status and seconds. In the example data the four slides had 22,477-26,981 bins; Space Ranger had already removed bins outside the tissue, so min_counts=10 removed none, and 5,000 bins per slide were sketched (test setting; the default is 50,000).

---

## 2. spatial_hd_cluster

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_cluster | spatial_hd_cluster |
| 서브 타이틀 | Visium HD 통합 군집 | Joint clustering of Visium HD slides |
| 버전 | 1.0 | |
| 카테고리 대분류 | Clustering (신규) | Clustering (new) |
| 카테고리 중분류 | Spatial_Clustering (신규) | Spatial_Clustering (new) |
| 태그 | spatial transcriptomics, Visium HD, clustering, Harmony, sketch, marker genes | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_cluster.1.0.R | |
| Processor Core (제안) | 8코어, 메모리 128GB | 8 cores, 128 GB of memory |

등록 메모: 작업 파일 `spatial_hd_cluster.1.1.R`을 배포 번호 1.0으로 올립니다.

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
모든 Visium HD 슬라이드의 sketch bin을 합쳐 군집을 만들고, 각 슬라이드의 모든 bin에 그 군집을 붙입니다. 군집을 함께 계산하므로 군집 번호가 모든 슬라이드에서 같은 뜻이고, 조건 비교에 바로 쓸 수 있습니다.
- sketch bin을 합쳐 정규화, PCA, 슬라이드 보정(Harmony), 군집, UMAP, 마커(presto)를 계산합니다.
- 각 슬라이드의 모든 bin을 같은 PCA에 투영하고, 같은 슬라이드에서 가장 가까운 sketch bin k_transfer개의 다수결로 군집을 붙입니다. 이웃 중 같은 군집의 비율을 Cluster_score로 남깁니다.
- 통합 UMAP, 슬라이드별 UMAP, 마커 dot plot, 군집×슬라이드 조성, 슬라이드별 조직 위 군집과 유전자 그림을 만듭니다.
- hd_slides.tsv에 슬라이드별 객체 목록을 남기며, 결과 폴더는 spatial_condition_de의 입력입니다.

### 내용(영문)
Clusters the sketched bins of all Visium HD slides together and labels every bin of each slide with those clusters. Because clustering is joint, cluster numbers mean the same in every slide and can be used directly to compare conditions.
- The sketched bins are merged, normalised, reduced by PCA, corrected for slides (Harmony), clustered, embedded with UMAP, and markers are found (presto).
- Every bin of a slide is projected onto the same PCA and gets the majority cluster of its k_transfer nearest sketched bins of the same slide; the fraction of neighbours with that cluster is kept as Cluster_score.
- A joint UMAP, a UMAP by slide, a marker dot plot, cluster-by-slide composition, and per-slide tissue cluster and gene plots are drawn.
- hd_slides.tsv lists the per-slide objects, and the output folder is the input of spatial_condition_de.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_hd_prep | Visium HD 전처리 폴더. 슬라이드마다 <slide>/<slide>_hd_prep.rds(bin assay Spatial.<NNN>um과 sketch assay가 있는 Seurat 객체)가 있어야 함 | Visium HD prep folder: <slide>/<slide>_hd_prep.rds per slide (Seurat object with the binned assay Spatial.<NNN>um and a sketch assay) |
| Output | Required | Directory | output_dir | /data/spatial_hd_cluster | 결과 폴더. joint/(통합 sketch 객체, 마커 표, 군집×슬라이드 표, UMAP·dot plot), 슬라이드별 <slide>_hd_clustered.rds와 plots/, hd_slides.tsv | Output folder: joint/ (joint sketch object, marker tables, cluster-by-slide table, UMAP and dot plot), per slide <slide>_hd_clustered.rds and plots/, and hd_slides.tsv |
| Option | Optional | Integer | dims | 30 | 사용할 주성분 수 | Number of principal components |
| Option | Optional | Float | resolution | 0.8 | 군집 해상도. 클수록 군집이 많아짐 | Clustering resolution; larger gives more clusters |
| Option | Optional | List | integration | auto | 슬라이드 보정. auto = 2장 이상이면 harmony, harmony, none | Slide correction: auto (harmony with two or more slides), harmony, or none |
| Option | Optional | Integer | nfeatures | 2000 | 합친 sketch의 가변 유전자 수 | Variable genes of the joint sketch |
| Option | Optional | Integer | k_transfer | 10 | 각 bin의 군집을 정할 때 보는 같은 슬라이드의 가장 가까운 sketch bin 수 | Nearest sketched bins of the same slide used to label each bin |
| Option | Optional | Float | marker_min_pct | 0.25 | 마커 검정 최소 발현 비율 | Minimum fraction of expressing bins for marker testing |
| Option | Optional | Float | marker_logfc | 0.25 | 마커 검정 최소 log fold change | Minimum log fold change for marker testing |
| Option | Optional | Integer | marker_topn | 5 | 군집마다 dot plot에 넣는 마커 수 | Markers per cluster in the dot plot |
| Option | Optional | String | features |  | 조직 위에 발현을 그릴 유전자(쉼표 구분). 비우면 그리지 않음 | Genes drawn on the tissue (comma separated). Empty: none |
| Option | Optional | Float | pt_size | 4 | 조직 그림의 bin 크기(Seurat pt.size.factor). 4이면 bin 사이 빈틈이 메워짐 | Bin size in the tissue plots (Seurat pt.size.factor); 4 fills the gaps between bins |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 모든 bin의 군집은 sketch bin에서 옮겨 붙인 것입니다. Cluster_score가 낮은(예: 0.5 미만) bin은 군집 경계에 있어 배정이 불확실합니다. | Clusters of all bins are transferred from the sketched bins; bins with a low Cluster_score (for example below 0.5) lie at cluster borders and their labels are uncertain. |
| 메모리는 슬라이드 수와 bin 수에 비례합니다. 8µm 슬라이드 여러 장은 64~128GB를 권장합니다. | Memory grows with the number of slides and bins; 64-128 GB is recommended for several 8 um slides. |
| 슬라이드가 한 장이면 integration=auto는 보정을 하지 않습니다. | With one slide, integration=auto applies no correction. |
| 입력은 모두 같은 bin 크기로 전처리한 슬라이드여야 합니다. | All input slides must be prepared with the same bin size. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/spatial_hd_cluster_concept.png`

- 레전드(국문): **그림. Visium HD 통합 군집과 모든 bin 배정.** (A) 모든 슬라이드의 sketch bin을 합쳐 Harmony로 슬라이드 차이를 보정하고 군집, UMAP, 마커를 계산합니다. (B) 각 bin(흰 사각형)을 같은 PCA에 투영하고, 같은 슬라이드에서 가장 가까운 sketch bin k_transfer개의 다수결로 군집을 붙입니다. 같은 군집인 이웃의 비율이 Cluster_score입니다. (C) 모든 bin에 군집이 붙은 슬라이드 객체와 hd_slides.tsv를 만들며, 조건 비교, 공간 가변 유전자, RCTD 모듈의 입력이 됩니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Joint Visium HD clustering and labels for every bin.** (A) The sketched bins of all slides are merged, slide differences corrected with Harmony, and clusters, UMAP and markers computed. (B) Each bin (white square) is projected onto the same PCA and labelled by majority vote of its k_transfer nearest sketched bins of the same slide; the fraction of agreeing neighbours is Cluster_score. (C) Slide objects with a cluster on every bin and hd_slides.tsv are written; they are the input of the condition comparison, spatially variable gene and RCTD modules. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_hd_cluster.1.0.R \
  input_dir=/data/spatial_hd_prep \
  output_dir=/data/spatial_hd_cluster \
  dims=30 \
  resolution=0.8 \
  integration=auto \
  nfeatures=2000 \
  k_transfer=10 \
  marker_min_pct=0.25 \
  marker_logfc=0.25 \
  marker_topn=5 \
  pt_size=4 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 Visium HD 마우스 뇌(FFPE) 한 장의 16µm bin입니다. Codespace 메모리 때문에 4분면으로 잘라 슬라이드 4장(각 약 2만 2천~2만 7천 bin)으로 쓰고, 유전자는 6,000개로 줄였습니다. 조직 그림의 대표 슬라이드는 해마가 들어 있는 brain_right_top입니다.

**결과 1. 통합 sketch UMAP**
- 결과 파일: `joint/plots/umap_clusters.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_cluster_result_1.png`

- 레전드(국문): **모든 슬라이드의 sketch bin으로 만든 통합 군집.** UMAP 위 점이 sketch bin이고 색과 숫자가 군집입니다. 이 군집이 모든 bin에 옮겨 붙습니다. 예시 데이터(sketch 2만 bin, Harmony, dims 30, resolution 0.8)에서는 군집 18개가 나왔습니다.
- 레전드(영문): **Joint clusters from the sketched bins of all slides.** Points on the UMAP are sketched bins; colours and numbers are clusters, which are then transferred to every bin. In the example data (20,000 sketched bins, Harmony, dims 30, resolution 0.8) 18 clusters appeared.

**결과 2. 모든 bin의 조직 위 군집(대표 그림)**
- 결과 파일: `<slide>/plots/<slide>_clusters_spatial.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_cluster_result_2.png`

- 레전드(국문): **슬라이드의 모든 bin에 붙인 통합 군집.** sketch에서 만든 군집을 가까운 sketch bin 10개(k_transfer)의 다수결로 모든 bin에 붙여 조직 위에 칠한 것입니다. 군집 번호는 모든 슬라이드에서 같은 뜻입니다. 예시 데이터에서는 해마의 CA 피라미드 세포층(군집 13)과 치아이랑 과립세포층(군집 17)이 가는 띠로 뚜렷이 나뉘었고, 위쪽 피질과 아래쪽 큰 영역도 서로 다른 군집으로 구분되었습니다. 16µm bin이라 세포 하나 크기의 경계까지 보입니다.
- 레전드(영문): **Joint clusters on every bin of a slide.** Clusters made on the sketch are transferred to every bin by majority vote of its 10 nearest sketched bins (k_transfer) and painted on the tissue; cluster numbers mean the same in every slide. In the example data the hippocampal CA pyramidal layer (cluster 13) and the dentate gyrus granule layer (cluster 17) separate as thin bands, and the cortex above and the large region below form distinct clusters. With 16 um bins, borders close to single-cell size are visible.

**결과 3. 유전자의 조직 위 발현**
- 결과 파일: `<slide>/plots/<slide>_feature_<gene>.png` (PDF도 있음, features를 줄 때)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_cluster_result_3.png`

- 레전드(국문): **features로 지정한 유전자의 bin별 발현.** 색은 log 정규화 발현입니다(파랑 낮음, 빨강 높음). 군집의 정체를 알려진 표지 유전자로 확인하는 데 씁니다. 예시 데이터에서 치아이랑 과립세포 표지 Prox1은 군집 17과 같은 띠에서만 높게 나와, 군집이 해부학적 구조와 맞음을 보여 줍니다.
- 레전드(영문): **Bin expression of genes given in features.** Colour is log-normalised expression (blue low, red high); it checks cluster identity with known markers. In the example data the dentate gyrus granule cell marker Prox1 is high only in the band of cluster 17, showing that the clusters match the anatomy.

**결과 4. 슬라이드로 칠한 UMAP**
- 결과 파일: `joint/plots/umap_slides.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_cluster_result_4.png`

- 레전드(국문): **통합 sketch UMAP을 슬라이드로 칠한 그림.** 같은 영역이 여러 슬라이드에 있으면 색이 섞여야 하며, 한 슬라이드 색만 따로 모이면 그 슬라이드에만 있는 영역이거나 보정이 부족한 것입니다. 예시 데이터에서는 왼쪽 두 슬라이드끼리, 오른쪽 두 슬라이드끼리 주로 섞이고 왼쪽과 오른쪽은 따로 모였습니다. 같은 절편의 왼쪽과 오른쪽이 서로 다른 뇌 영역을 담고 있기 때문입니다.
- 레전드(영문): **The joint sketch UMAP coloured by slide.** When a region is present in several slides their colours should mix; a slide colour gathering alone means a region present only there, or too little correction. In the example data the two left slides mixed mostly with each other, as did the two right slides, while left and right gathered apart, because the left and right halves of the section contain different brain regions.

**결과 5. 슬라이드별 군집 조성**
- 결과 파일: `joint/plots/cluster_by_slide.png` (PDF도 있음), 표 `joint/cluster_by_slide.tsv`

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_hd_cluster_result_5.png`

- 레전드(국문): **슬라이드마다 모든 bin에서 군집이 차지하는 비율(Fraction of bins).** 같은 부위의 슬라이드는 비슷해야 하며, 조건 비교 전에 조성 차이를 확인합니다. 예시 데이터에서는 4분면마다 포함한 영역이 달라 조성이 달랐고, 해마 군집(13, 17)은 오른쪽 위 슬라이드에서 가장 많았습니다.
- 레전드(영문): **Fraction of all bins per cluster in each slide (Fraction of bins).** Slides of the same part should look alike; check composition differences before comparing conditions. In the example data the quadrants contain different regions and their compositions differ, and the hippocampal clusters (13, 17) are most frequent in the top-right slide.

---

## 3. spatial_hd_svf

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_svf | spatial_hd_svf |
| 서브 타이틀 | Visium HD 공간 가변 유전자 | Spatially variable genes of Visium HD slides |
| 버전 | 1.0 | |
| 카테고리 대분류 | Statistics_and_Visualization | Statistics_and_Visualization |
| 카테고리 중분류 | Spatial_Statistics (신규) | Spatial_Statistics (new) |
| 태그 | spatial transcriptomics, Visium HD, spatially variable genes, Moran's I | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_svf.1.0.R | |
| Processor Core (제안) | 8코어, 메모리 64GB | 8 cores, 64 GB of memory |

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
Visium HD 슬라이드마다 조직 위에서 뭉쳐서 발현하는 유전자(공간 가변 유전자)를 Moran's I로 찾습니다. 군집과 상관없이 해부학적 구조나 경계를 따라 발현하는 유전자를 찾는 데 씁니다.
- 슬라이드마다 가변 유전자 svf_topn개를 검정합니다.
- bin이 수십만 개라 모두 쓰면 계산량이 bin 수의 제곱으로 늘어나므로, max_bins개를 무작위로 뽑아 Moran's I(Seurat RunMoransI, ape)를 계산합니다.
- 보정 p값(BH)이 padj_cutoff보다 작은 유전자를 Moran's I 순으로 순위를 매기고, 상위 svf_show개를 모든 bin 위에 그립니다.
- 슬라이드별 표와 모든 슬라이드를 합친 표, 요약 표를 만듭니다.

### 내용(영문)
Finds genes expressed in spatial patches on each Visium HD slide (spatially variable genes) with Moran's I, for genes that follow anatomical structures or borders regardless of clusters.
- The svf_topn most variable genes of each slide are tested.
- Slides have hundreds of thousands of bins and the cost grows with the square of the bin count, so Moran's I (Seurat RunMoransI, ape) is computed on max_bins randomly sampled bins.
- Genes with an adjusted p-value (BH) below padj_cutoff are ranked by Moran's I, and the top svf_show genes are drawn on all bins.
- Per-slide tables, a table of all slides and a summary table are written.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_hd_cluster | Visium HD 군집 결과 폴더. hd_slides.tsv와 슬라이드별 객체 | Visium HD cluster folder: hd_slides.tsv and the per-slide objects |
| Output | Required | Directory | output_dir | /data/spatial_hd_svf | 결과 폴더. 슬라이드마다 <slide>_hd_svf.tsv와 plots/<slide>_top_svf, 그리고 svf_all_slides.tsv, svf_summary.tsv | Output folder: per slide <slide>_hd_svf.tsv and plots/<slide>_top_svf, plus svf_all_slides.tsv and svf_summary.tsv |
| Option | Optional | Integer | svf_topn | 500 | 슬라이드마다 검정할 가변 유전자 수 | Most variable genes of each slide tested |
| Option | Optional | Integer | max_bins | 4000 | 슬라이드마다 Moran's I에 쓰는 무작위 bin 수. 계산량이 이 값의 제곱으로 늘어남 | Random bins per slide used for Moran's I; the cost grows with its square |
| Option | Optional | Integer | svf_show | 6 | 조직 위에 그릴 상위 유전자 수 | Top genes drawn on the tissue |
| Option | Optional | Float | padj_cutoff | 0.05 | 공간 가변 유전자로 부를 보정 p값(BH) 기준 | Adjusted p-value (BH) for calling a gene spatially variable |
| Option | Optional | Float | pt_size | 4 | 조직 그림의 bin 크기(Seurat pt.size.factor) | Bin size in the tissue plots (Seurat pt.size.factor) |
| Option | Optional | Integer | seed | 1234 | bin 표본 난수 시드 | Random seed for the bin sample |

### 주요 사항
| 국문 | 영문 |
|---|---|
| Moran's I는 무작위로 뽑은 max_bins개 bin으로 계산합니다. 작은 구조(가는 띠 등)는 표본에 bin이 적게 들어가 놓칠 수 있으니 필요하면 max_bins를 올리세요. 계산 시간은 제곱으로 늘어납니다. | Moran's I uses max_bins random bins; small structures (thin bands) may get few bins in the sample and be missed, so raise max_bins if needed; the time grows with its square. |
| 유의한 유전자가 없는 슬라이드는 실패가 아니라 경고와 상태 no_significant_genes로 남습니다. | A slide without significant genes is reported with a warning and the status no_significant_genes, not as a failure. |
| 군집 결과(spatial_hd_cluster)를 입력으로 받지만 군집은 쓰지 않습니다. 정규화 값과 조직 좌표만 씁니다. | The cluster output (spatial_hd_cluster) is the input, but the clusters are not used; only normalised values and tissue coordinates are. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/spatial_hd_svf_concept.png`

- 레전드(국문): **그림. Visium HD 공간 가변 유전자.** (A) 슬라이드마다 bin을 max_bins개 무작위로 뽑습니다(파란 칸). Moran's I 계산량이 bin 수의 제곱으로 늘어나기 때문입니다. (B) 가변 유전자 svf_topn개마다 Moran's I와 p값, BH 보정 p값을 계산해 순위를 매깁니다. (C) 상위 유전자의 발현을 모든 bin 위에 그리고, 슬라이드별 표와 요약 표를 남깁니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Spatially variable genes of Visium HD slides.** (A) max_bins bins are sampled at random per slide (blue squares), because the cost of Moran's I grows with the square of the bin count. (B) For each of the svf_topn variable genes, Moran's I, its p-value and the BH-adjusted p-value are computed and the genes are ranked. (C) The top genes are drawn on all bins, and per-slide and summary tables are written. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_hd_svf.1.0.R \
  input_dir=/data/spatial_hd_cluster \
  output_dir=/data/spatial_hd_svf \
  svf_topn=500 \
  max_bins=4000 \
  svf_show=6 \
  padj_cutoff=0.05 \
  pt_size=4 \
  seed=1234
```

### 주요 결과 이미지
등록 메모: SIF 테스트 결과 그림을 넣을 자리입니다(Codespace 재실행 중).

---

## 4. spatial_condition_de

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_condition_de | spatial_condition_de |
| 서브 타이틀 | 조건 간 공간 발현 비교 | Spatial expression comparison between conditions |
| 버전 | 1.0 | |
| 카테고리 대분류 | Statistics_and_Visualization | Statistics_and_Visualization |
| 카테고리 중분류 | Differential_Analysis (신규) | Differential_Analysis (new) |
| 태그 | spatial transcriptomics, Visium, Visium HD, differential expression, pseudobulk, DESeq2 | |
| 레퍼런스 URL | https://bioconductor.org/packages/DESeq2/ | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_condition_de.1.0.R | |
| Processor Core (제안) | 8코어, 메모리 64GB | 8 cores, 64 GB of memory |

등록 메모: 작업 파일 `spatial_condition_de.1.4.R`을 배포 번호 1.0으로 올립니다.

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
조건(예: 대조군과 처리군) 사이에서 군집별 spot 조성과 유전자 발현을 비교합니다. 같은 군집(같은 조직 영역) 안에서 비교하므로, 영역 구성의 차이와 영역 안 발현 변화를 나눠 볼 수 있습니다.
- 슬라이스마다 군집 조성을 계산하고, 군집별 비율을 조건 사이에서 비교합니다(logit 비율, Welch t-test).
- 군집마다 슬라이스별로 원래 count를 합친 pseudobulk를 DESeq2로 비교합니다. Patient 열이 있으면 짝 설계(~ Patient + Condition)로 검정합니다.
- 조건별 슬라이스가 부족한 군집은 spot 단위 Wilcoxon 검정(탐색용)으로 비교하거나 건너뜁니다.
- 조성 그림, volcano, 유의 유전자 수, log2FC heatmap, 조직 위 유전자 분포를 그립니다. Visium HD는 슬라이드를 하나씩 읽어 메모리를 아낍니다.

### 내용(영문)
Compares the spot composition of clusters and the gene expression within clusters between conditions (for example control and treated). Comparing within the same cluster (the same tissue region) separates changes in region composition from expression changes inside a region.
- The cluster composition of each slice is computed and cluster proportions are compared between conditions (logit proportion, Welch t-test).
- For each cluster, raw counts are summed per slice into pseudobulk samples and compared with DESeq2; with a Patient column the paired design (~ Patient + Condition) is used.
- Clusters with too few slices per condition are compared with a spot-level Wilcoxon test (exploratory) or skipped.
- Composition plots, volcano plots, significant gene counts, a log2FC heatmap and gene expression on the tissue are drawn. Visium HD slides are read one at a time to save memory.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_merge | 군집 결과 폴더. Visium: merged/merged_clustered.rds(원래 Spatial count, slice 열, 군집 열이 있는 Seurat 객체). Visium HD: hd_slides.tsv(Slide, RDS, Assay)와 슬라이드별 <slide>/<slide>_hd_clustered.rds | Clustered folder. Visium: merged/merged_clustered.rds (Seurat object with raw Spatial counts, a slice column and cluster labels). Visium HD: hd_slides.tsv (Slide, RDS, Assay) and <slide>/<slide>_hd_clustered.rds per slide |
| Input | Required | File | sample_data | /data/slices.csv | 슬라이스 시트(CSV). 열: SliceID(객체의 슬라이스 이름), Condition, 선택 Patient(짝 설계) | Slice sheet (CSV): SliceID (slice name in the object), Condition, optional Patient (paired design) |
| Output | Required | Directory | output_dir | /data/spatial_condition_de | 결과 폴더(01_composition/, 02_de/de_<test>_vs_<reference>.tsv, 03_plots/, 04_summary/de_summary.tsv) | Output folder (01_composition/, 02_de/de_<test>_vs_<reference>.tsv, 03_plots/, 04_summary/de_summary.tsv) |
| Option | Optional | String | group_by | seurat_clusters | 안에서 조건을 비교할 spot 묶음의 메타데이터 열(군집 또는 세포 유형 열) | Metadata column defining the spot groups compared within (clusters or a cell-type column) |
| Option | Optional | String | reference |  | 기준 조건. 나머지 조건을 이것과 비교. 비우면 sample_data의 첫 Condition | Reference condition that the others are compared with. Empty: the first Condition in sample_data |
| Option | Optional | Integer | min_spots | 20 | 군집 안 spot이 이보다 적은 슬라이스는 그 군집 검정에서 뺌 | Slices with fewer spots in a group are left out of that group's test |
| Option | Optional | Integer | min_slices | 2 | pseudobulk 검정에 필요한 조건별 슬라이스 수 | Slices per condition needed for the pseudobulk test |
| Option | Optional | Float | padj_cutoff | 0.05 | 유의 유전자 보정 p값 기준 | Adjusted p-value cutoff for significant genes |
| Option | Optional | Float | lfc_cutoff | 0.5 | 유의 유전자 log2FC 절대값 기준 | Absolute log2 fold change cutoff for significant genes |
| Option | Optional | Integer | top_genes | 20 | 군집마다 volcano에 이름을 붙이고 log2FC heatmap에 넣는 유전자 수 | Genes labelled per volcano and shown in the log2FC heatmap (per group) |
| Option | Optional | Integer | spatial_genes | 6 | 조직 위에 그릴 상위 유전자 수 | Top genes drawn on the tissue |
| Option | Optional | List | spot_level | auto | 슬라이스가 부족한 군집 처리. auto = spot 단위 Wilcoxon(탐색용), no = 검정하지 않음 | Groups with too few slices: auto = spot-level Wilcoxon (exploratory), no = not tested |
| Option | Optional | Integer | spot_level_max | 3000 | spot 단위 검정에 쓰는 슬라이스·군집당 최대 spot(bin) 수. 넘으면 무작위 추출 | Maximum spots (bins) per slide and group in the spot-level test; more are sampled |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SliceID | 필수 | 슬라이스 이름(spatial_prep 또는 spatial_hd_prep에 준 슬라이스 폴더 이름) | crc_p1 |
| Condition | 필수 | 조건 이름 | tumor |
| Patient | 선택 | 짝 설계의 개체 ID(같은 개체가 각 조건에 있을 때) | P1 |

예제 데이터(Visium HD 사람 대장암, 종양 3장과 정상 인접 조직 2장)의 샘플시트입니다. `reference=normal`로 실행합니다.
```
SliceID,Condition
crc_p1,tumor
crc_p2,tumor
crc_p5,tumor
normal_p3,normal
normal_p5,normal
```

같은 개체가 각 조건에 있으면 Patient 열을 더해 짝 설계로 검정합니다(예: 같은 환자의 종양과 정상).
```
SliceID,Condition,Patient
tumor_1,tumor,P1
tumor_2,tumor,P2
normal_1,normal,P1
normal_2,normal,P2
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 조건마다 슬라이스(생물학적 반복)가 2장 이상이어야 pseudobulk 검정을 합니다. 한 슬라이스 안의 spot은 독립 반복이 아니므로, 슬라이스가 부족해 spot 단위로 검정한 결과(spot_level_wilcoxon)는 가설을 세우는 데만 써 주세요. | Pseudobulk testing needs two or more slices (biological replicates) per condition. Spots of one slice are not independent replicates, so spot-level results (spot_level_wilcoxon) are for generating hypotheses only. |
| SliceID는 객체 안의 슬라이스 이름과 같아야 합니다. spatial_prep·spatial_hd_prep에 준 슬라이스 폴더 이름입니다. | SliceID must match the slice names in the object: the slice folder names given to spatial_prep or spatial_hd_prep. |
| 검정할 수 없는 군집(슬라이스나 spot 부족)은 오류가 아니라 de_summary.tsv에 상태로 남고 종료 코드 0으로 끝납니다. 검정할 수 있는 군집이 하나도 없을 때만 실패합니다. | Groups that cannot be tested (too few slices or spots) are listed with a status in de_summary.tsv and the run ends with exit code 0; it fails only when no group can be tested. |
| 방향은 reference 기준입니다. log2FC가 양수이면 비교 조건에서 높습니다. reference를 비우면 sample_data의 첫 Condition이 기준입니다. | Directions are relative to reference: a positive log2FC is higher in the compared condition. With reference empty, the first Condition in sample_data is the reference. |
| 같은 조직의 연속 절편처럼 실제 차이가 없는 비교에서도 spot 단위 검정은 미토콘드리아·리보솜 유전자 같은 기술적 차이를 유의하게 낼 수 있습니다. | Even without real differences (for example serial sections of one tissue), spot-level tests can flag technical differences such as mitochondrial and ribosomal genes. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/spatial_condition_de_concept.png`

- 레전드(국문): **그림. 조건 간 군집별 비교.** (A) 슬라이스마다 한 군집 spot의 count를 합친 pseudobulk를 만들고, 슬라이스를 반복으로 삼아 DESeq2(~ Condition, 짝 설계면 ~ Patient + Condition)로 검정합니다. 조건마다 슬라이스가 한 장뿐이면 spot 단위 Wilcoxon(탐색용)으로 비교합니다. (B) 군집마다 volcano를 그립니다(x축 log2 fold change, y축 -log10 adjusted p, 빨강 기준보다 높음, 파랑 낮음, 점선은 lfc_cutoff와 padj_cutoff). (C) de_summary.tsv에 군집별 검정 방법과 상태(ok, ok_exploratory, insufficient_slices)를 남깁니다. Visium merge 결과와 Visium HD 결과(hd_slides.tsv)를 모두 받으며, group_by로 세포 유형 열을 쓸 수도 있습니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Comparison between conditions per cluster.** (A) For each slice, the counts of one cluster's spots are summed into a pseudobulk sample, and DESeq2 (~ Condition, or ~ Patient + Condition when paired) tests the condition with slices as replicates; with one slice per condition a spot-level Wilcoxon test (exploratory) is used. (B) A volcano per cluster (x log2 fold change, y -log10 adjusted p; red higher than the reference, blue lower; dashed lines lfc_cutoff and padj_cutoff). (C) de_summary.tsv records the method and status per cluster (ok, ok_exploratory, insufficient_slices). Visium merge output and Visium HD output (hd_slides.tsv) are both accepted, and group_by may name a cell-type column. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_condition_de.1.0.R \
  input_dir=/data/spatial_hd_cluster \
  sample_data=/data/slices.csv \
  output_dir=/data/spatial_condition_de \
  group_by=seurat_clusters \
  min_spots=20 \
  min_slices=2 \
  padj_cutoff=0.05 \
  lfc_cutoff=0.5 \
  top_genes=20 \
  spatial_genes=6 \
  spot_level=auto \
  spot_level_max=3000 \
  seed=1234
```

### 주요 결과 이미지
등록 메모: 예시 데이터를 사람 대장암 Visium HD(종양 3장, 정상 2장)로 바꿨습니다. 아래 그림은 이전 예시(마우스 뇌 Visium HD를 좌우로 나눈 4장) 결과이며, CLOSHA 결과로 바꿉니다.

**결과 1. 군집별 volcano (Visium HD 입력)**
- 결과 파일: `03_plots/volcano_<test>_vs_<reference>.png` (Visium HD 입력)

그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/results/spatial_condition_de_result_1.png`

- 레전드(국문): **Visium HD 결과(spatial_hd_cluster 출력)를 넣은 조건 비교.** HD 입력에서는 슬라이드를 하나씩 읽어 pseudobulk를 합칩니다. 예시 데이터(right vs left, 조건마다 슬라이드 2장)에서는 군집 12개를 pseudobulk DESeq2로 검정했고, 군집 2(Gad1, Sst 등 감소)처럼 유의 유전자가 많이 나왔습니다. 왼쪽과 오른쪽은 서로 다른 뇌 영역을 담고 있어 해부학적 차이가 나오는 것이 정상이며, 실제 조건 비교가 아닙니다.
- 레전드(영문): **Condition comparison with Visium HD input (spatial_hd_cluster output).** With HD input the slides are read one at a time and summed into pseudobulk samples. In the example data (right vs left, two slides per condition) twelve clusters were tested with pseudobulk DESeq2, and some, such as cluster 2 (Gad1, Sst and others lower), had many significant genes. The left and right halves contain different brain regions, so anatomical differences are expected; this is not a real condition comparison.

---

## 5. spatial_hd_rctd

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_rctd | spatial_hd_rctd |
| 서브 타이틀 | HD bin 세포 유형 추정 | Cell types of Visium HD bins with RCTD |
| 버전 | 1.0 | |
| 카테고리 대분류 | Annotation | Annotation |
| 카테고리 중분류 | Cell_Type_Annotation (신규) | Cell_Type_Annotation (new) |
| 태그 | spatial transcriptomics, Visium HD, RCTD, deconvolution, cell type | |
| 레퍼런스 URL | https://github.com/dmcable/spacexr | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_rctd.1.0.R | |
| Processor Core (제안) | 8코어, 메모리 128GB | 8 cores, 128 GB of memory |

등록 메모: 작업 파일 `spatial_hd_rctd.1.2.R`을 배포 번호 1.0으로 올립니다.

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
Visium HD의 모든 bin에 단일세포 참조의 세포 유형을 RCTD(spacexr)로 붙입니다. 8µm bin은 세포 하나 크기에 가까워 bin마다 세포 유형 1~2개로 볼 수 있고(doublet 모드), 16µm bin은 여러 세포가 섞인 비율로 봅니다(full 모드).
- 슬라이드를 chunk_bins개씩 나눠 RCTD를 돌려 메모리를 일정하게 유지합니다.
- doublet 모드는 bin마다 첫째·둘째 세포 유형과 분류(singlet, doublet_certain, doublet_uncertain, reject)를 줍니다. full 모드는 모든 세포 유형의 weight를 주고, 가장 큰 weight가 첫째 세포 유형입니다.
- UMI 수가 umi_min보다 적은 bin은 계산하지 않고 not_scored로 남깁니다.
- 슬라이드별 조직 위 세포 유형 그림, 슬라이드×세포 유형 비율 표와 그림을 만들며, 결과 폴더는 spatial_condition_de의 입력(group_by=rctd_first_type)이 됩니다.

### 내용(영문)
Labels every bin of Visium HD slides with the cell types of a single-cell reference using RCTD (spacexr). An 8 um bin is close to one cell, so each bin is seen as one or two cell types (doublet mode); a 16 um bin is seen as a mixture of cells (full mode).
- Slides are processed in chunks of chunk_bins bins to keep memory bounded.
- doublet mode gives each bin a first and second cell type and a class (singlet, doublet_certain, doublet_uncertain, reject); full mode gives weights of all cell types, and the highest weight is the first type.
- Bins with fewer UMIs than umi_min are not scored and are marked not_scored.
- Tissue maps of the cell types per slide and a slide-by-cell-type table and plot are made; the output folder is the input of spatial_condition_de (group_by=rctd_first_type).

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_hd_cluster | Visium HD 군집 결과 폴더. hd_slides.tsv와 슬라이드별 객체(bin assay에 raw count) | Visium HD cluster folder: hd_slides.tsv and the per-slide objects (raw counts in the binned assay) |
| Input | Optional | File | reference_rds | /ref/brain_reference.rds | 단일세포 참조 자료(Seurat .rds). raw count와 세포 유형 열이 있어야 함. 비우면 이 모듈은 건너뜀(skipped.txt) | Single-cell reference (Seurat .rds) with raw counts and a cell-type column. Empty: the module is skipped (skipped.txt) |
| Option | Optional | String | reference_label_col | celltype | 참조 자료에서 세포 유형이 든 메타데이터 열 이름. 참조를 주면 반드시 입력. 비었거나 참조에 없는 열이면 세포 유형 후보 열을 보여 주고 멈춤 | Metadata column of the reference holding the cell types; required when a reference is given. When empty or not in the reference, the run stops and lists the cell-type column candidates |
| Output | Required | Directory | output_dir | /data/spatial_hd_rctd | 결과 폴더. 슬라이드마다 <slide>_hd_rctd.rds, <slide>_rctd_weights.tsv.gz, plots/, 그리고 hd_slides.tsv, celltype_by_slide.tsv, rctd_summary.tsv | Output folder: per slide <slide>_hd_rctd.rds, <slide>_rctd_weights.tsv.gz and plots/, plus hd_slides.tsv, celltype_by_slide.tsv and rctd_summary.tsv |
| Option | Optional | String | reference_assay | RNA | 참조 객체에서 raw count가 든 assay | Assay of the reference holding raw counts |
| Option | Optional | List | rctd_mode | doublet | doublet = bin마다 세포 유형 1~2개(8µm에 맞음), full = 모든 세포 유형의 섞인 비율(16µm에 맞음) | doublet = one or two cell types per bin (suits 8 um), full = mixture of all cell types (suits 16 um) |
| Option | Optional | Integer | chunk_bins | 20000 | RCTD 한 번에 넣는 bin 수. 줄이면 메모리가 줄고 시간이 조금 늘어남 | Bins per RCTD run; smaller uses less memory and a little more time |
| Option | Optional | Integer | umi_min | 100 | UMI 수가 이보다 적은 bin은 계산하지 않음(not_scored) | Bins with fewer UMIs are not scored (not_scored) |
| Option | Optional | Integer | min_cells_per_type | 25 | 세포 수가 이보다 적은 참조 세포 유형은 뺌 | Reference cell types with fewer cells are left out |
| Option | Optional | Integer | min_shared_features | 200 | 참조와 슬라이드가 공유해야 하는 최소 유전자 수 | Minimum genes shared by the reference and the slides |
| Option | Optional | Float | pt_size | 4 | 조직 그림의 bin 크기(Seurat pt.size.factor) | Bin size in the tissue plots (Seurat pt.size.factor) |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 참조 자료(reference_rds)를 주지 않으면 이 모듈은 건너뛰고(결과 폴더에 skipped.txt) 정상 종료하므로, 참조가 없어도 파이프라인은 끝까지 실행됩니다. 참조를 주면 세포 유형 열 이름(reference_label_col)도 넣어 주세요. 열 이름을 모르면 비워 두고 한 번 실행하면, 분석 전에 멈추고 오류 로그에 세포 유형 후보 열과 그 값들을 보여 줍니다. 확인한 열 이름을 넣어 다시 실행하세요. | Without a reference (reference_rds) the module is skipped (skipped.txt in the output folder) and ends without error, so the pipeline still runs to the end. With a reference, also give its cell-type column (reference_label_col). If the column name is unknown, leave it empty and run once: the run stops before the analysis and the error log lists the cell-type column candidates with their values. Run again with the chosen column. |
| bin 크기에 맞춰 rctd_mode를 고르세요. 기본값 doublet은 8µm용이고, 16µm는 full을 권장합니다. | Choose rctd_mode by bin size: the default doublet is for 8 um, and full is recommended for 16 um. |
| 16µm bin은 UMI가 많아 umi_min=100에서 대부분 계산되지만, 8µm bin은 UMI가 적어 not_scored가 많을 수 있습니다. rctd_summary.tsv의 Bins_scored를 확인하세요. | 16 um bins have many UMIs and are mostly scored at umi_min=100, but 8 um bins have fewer and many may be not_scored; check Bins_scored in rctd_summary.tsv. |
| 참조에 없는 조직은 가장 비슷한 세포 유형으로 칠해집니다. 슬라이드 조직 전체를 담은 참조를 권장합니다. | Tissue missing from the reference is painted with the most similar cell types; a reference covering the whole tissue is recommended. |
| 코어 수에 따라 메모리가 늘어납니다(작업자마다 자료를 복사). 병렬 작업자 수는 할당한 코어 수를 따르므로, 메모리가 모자라면 코어 수나 chunk_bins를 낮춰 주세요. | Memory grows with the cores (each worker copies the data); the number of workers follows the allocated cores, so lower the cores or chunk_bins if memory runs short. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/spatial_hd_rctd_concept.png`

- 레전드(국문): **그림. Visium HD bin의 세포 유형(RCTD).** (A) 슬라이드의 bin을 chunk_bins개씩 나눠 단일세포 참조(raw count와 세포 유형 열)와 함께 RCTD에 넣습니다. (B) doublet 모드는 bin마다 세포 유형 하나(singlet), 둘(doublet_certain), 판정 불가(reject) 등으로 분류하고 첫째·둘째 세포 유형을 줍니다. 16µm에 쓰는 full 모드는 weight를 주고 가장 큰 weight를 첫째 세포 유형으로 씁니다. (C) 모든 bin에 세포 유형이 붙은 슬라이드 객체, weight 표, 슬라이드×세포 유형 비율을 만들고, hd_slides.tsv로 spatial_condition_de(group_by=rctd_first_type)에 넘깁니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Cell types of Visium HD bins with RCTD.** (A) The bins of a slide are passed to RCTD in chunks of chunk_bins together with the single-cell reference (raw counts and a cell-type column). (B) doublet mode classifies each bin as one cell type (singlet), two (doublet_certain) or undecided (reject) and gives a first and second type; full mode, used for 16 um, gives weights and the highest weight is the first type. (C) Slide objects with a cell type on every bin, weight tables and slide-by-cell-type proportions are written, and hd_slides.tsv passes them to spatial_condition_de (group_by=rctd_first_type). Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_hd_rctd.1.0.R \
  input_dir=/data/spatial_hd_cluster \
  reference_rds=/ref/brain_reference.rds \
  reference_label_col=celltype \
  output_dir=/data/spatial_hd_rctd \
  reference_assay=RNA \
  rctd_mode=doublet \
  chunk_bins=20000 \
  umi_min=100 \
  min_cells_per_type=25 \
  min_shared_features=200 \
  pt_size=4 \
  seed=1234
```

### 주요 결과 이미지
등록 메모: SIF 테스트 결과 그림을 넣을 자리입니다(Codespace 재실행 중).
## 6. check_reference

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | check_reference | check_reference |
| 서브 타이틀 | 단일세포 참조 자료 열 확인 | Column check of a single-cell reference |
| 버전 | 1.1 | |
| 카테고리 대분류 | Annotation | Annotation |
| 카테고리 중분류 | Cell_Type_Annotation (신규) | Cell_Type_Annotation (new) |
| 태그 | single-cell reference, Seurat, metadata, cell type | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | check_reference.1.1.R | |
| Processor Core (제안) | 4코어, 메모리 64GB | 4 cores, 64 GB of memory |

### 실행 이미지
이미지: bx_spatial 1.1

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
spatial_labelTransfer, spatial_rctd, spatial_hd_rctd에 넣을 단일세포 참조 자료(Seurat RDS)의 메타데이터 열을 살펴, 세포 유형 열(reference_label_col)로 쓸 수 있는 열을 알려 줍니다. 참조 자료마다 세포 유형 열 이름이 달라(celltype, cell_type, subclass 등) 분석 전에 확인하는 단계입니다.
- 열마다 형식(범주형, 숫자형)과, 범주형이면 범주 수와 가장 많은 값을 로그에 적습니다.
- 범주가 2~100개인 범주형 열에 [CELLTYPE?] 표시를 붙여 후보로 알려 줍니다.
- 같은 내용을 reference_columns.tsv 표로 남깁니다.
- 세포 유형처럼 보이는 열이 없어도 실패가 아니라 경고로 끝납니다.

### 내용(영문)
Inspects the metadata columns of a single-cell reference (Seurat RDS) for spatial_labelTransfer, spatial_rctd and spatial_hd_rctd, and reports which columns can serve as the cell-type column (reference_label_col). References name this column differently (celltype, cell_type, subclass and so on), so it is checked before the analysis.
- For each column the log lists its type (categorical or numeric) and, for categorical columns, the number of categories and the most frequent values.
- Categorical columns with 2-100 categories are tagged [CELLTYPE?] as candidates.
- The same report is written as the table reference_columns.tsv.
- A reference without a cell-type-like column ends with a warning, not a failure.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | File | reference_rds | /ref/brain_reference.rds | 단일세포 참조 자료. 세포 유형 열이 있는 Seurat 객체(.rds) | Single-cell reference: Seurat object (.rds) with a cell-type column |
| Output | Required | Directory | output_dir | /data/check_reference | 결과 폴더. reference_columns.tsv(열 보고서)와 logs/ | Output folder: reference_columns.tsv (column report) and logs/ |

### 주요 사항
| 국문 | 영문 |
|---|---|
| [CELLTYPE?]는 범주 수만 보고 붙이는 후보 표시입니다. 표본 이름, 배치 같은 열도 후보로 나올 수 있으니 값을 보고 세포 유형 열을 고르세요. | [CELLTYPE?] is a candidate tag based only on the number of categories; columns such as sample names or batches can also appear, so choose the cell-type column by its values. |
| spatial_rctd와 spatial_hd_rctd는 참조에 raw count가 있어야 합니다(보통 RNA assay). 로그의 assay 정보를 함께 확인하세요. | spatial_rctd and spatial_hd_rctd need raw counts in the reference (usually the RNA assay); check the assay information in the log as well. |
| 세포 수가 min_cells_per_type(기본 25)보다 적은 세포 유형은 RCTD에서 빠집니다. 범주별 세포 수로 미리 확인할 수 있습니다. | Cell types with fewer cells than min_cells_per_type (default 25) are left out of RCTD; the cell counts per category show this in advance. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/figures/module_concepts/check_reference_concept.png`

- 레전드(국문): **그림. 단일세포 참조 자료의 세포 유형 열 확인.** (A) 참조 자료는 세포마다 메타데이터(세포 유형, 배치, UMI 수 등)를 가진 Seurat 객체입니다. (B) 열마다 형식과 범주 수, 가장 많은 값을 로그에 적고, 범주가 2~100개인 범주형 열에 [CELLTYPE?]를 붙입니다. 숫자형 열과 범주가 너무 많은 열은 후보에서 뺍니다(SKIP). (C) reference_columns.tsv에서 후보를 보고 세포 유형 열을 골라 spatial_labelTransfer, spatial_rctd, spatial_hd_rctd의 reference_label_col에 넣습니다. 값은 모식적인 값입니다.
- 레전드(영문): **Figure. Checking the cell-type column of a single-cell reference.** (A) The reference is a Seurat object with per-cell metadata (cell type, batch, UMI counts and so on). (B) For each column the log lists its type, number of categories and most frequent values; categorical columns with 2-100 categories are tagged [CELLTYPE?], while numeric columns and columns with too many categories are skipped. (C) The cell-type column is chosen from the candidates in reference_columns.tsv and given as reference_label_col to spatial_labelTransfer, spatial_rctd and spatial_hd_rctd. Values are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript check_reference.1.1.R \
  reference_rds=/ref/brain_reference.rds \
  output_dir=/data/check_reference
```

### 주요 결과 이미지
등록 메모: SIF 테스트 결과 그림을 넣을 자리입니다(Codespace 재실행 중).

---

