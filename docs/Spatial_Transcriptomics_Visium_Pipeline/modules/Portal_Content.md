# Visium 공간 전사체 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 Visium 파이프라인 모듈의 원고입니다. spatial_condition_de와 check_reference는 두 파이프라인이 같이 쓰는 모듈이라 `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/Portal_Content.md`에도 같은 내용이 있습니다(고칠 때 양쪽을 함께 고친다). 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다. 예시 경로가 그대로 넘어가면 스크립트가 "not found"로 멈춥니다.
- 선택(Optional) 입력은 빈 값이 "사용 안 함"입니다.
- 스크립트 사용 예제는 등록하는 인자를 모두 적었고, 기본값이 있는 옵션은 기본값으로 적었습니다. 예시 값은 Visium 기준입니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 모든 모듈이 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)입니다.
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류·경고 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지웁니다.
- 카테고리는 대분류 = 분석 단계, 중분류 = 구체적 작업으로 정했습니다(사용자 결정, 2026-10-27). 데이터 종류는 모듈 이름(spatial_*)이 보여 줍니다. spatial_prep·spatial_hd_prep은 Preprocessing(신규) / Normalization(신규), 군집 모듈은 Clustering(신규) / Spatial_Clustering(신규; 묶는 대상별 중분류로 나중에 Cell_Clustering, Sample_Clustering 등을 둔다), 공간 통계량(Moran's I 등)을 계산하는 spatial_svf·spatial_hd_svf(hd_svf는 p값과 BH 보정까지 냄)와 p값을 내는 검정인 spatial_condition_de(DESeq2)는 Statistics_and_Visualization 아래 Spatial_Omics(신규)와 Differential_Analysis(신규)에 둡니다. 세포 유형 모듈과 check_reference는 기존 Annotation의 "무엇에 주석을 다는가" 방식에 맞춰 Cell_Type_Annotation(신규)입니다. 포탈의 현재 이름 Statisitcs_and_Visualization은 오타라 Statistics_and_Visualization으로 적었습니다.
- 버전은 배포 번호입니다. CLOSHA 2.0 모듈은 2.0 번호 + 1(이번에 모두 스크립트 규칙에 맞춰 고쳐 1.1)이고, 3.0에서 새로 만든 모듈은 1.0입니다.

---

## 1. spatial_prep

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_prep | spatial_prep |
| 서브 타이틀 | 공간 전사체 불러오기와 정규화 | Loading and normalisation of spatial data |
| 버전 | 1.1 | |
| 카테고리 대분류 | Preprocessing (신규) | Preprocessing (new) |
| 카테고리 중분류 | Normalization (신규) | Normalization (new) |
| 태그 | spatial transcriptomics, Visium, Seurat, SCTransform, QC | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_prep.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 32GB | 8 cores, 32 GB of memory |

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
10x Visium 슬라이스마다 Space Ranger 결과(count 행렬과 조직 이미지)를 불러와 spot을 거르고 SCTransform으로 정규화합니다. 공간 전사체는 spot마다 시퀀싱 깊이가 크게 달라, 정규화를 해야 spot 사이 발현을 비교할 수 있습니다.
- 입력 폴더 아래 하위 폴더를 슬라이스 하나로 보고 모두 같은 설정으로 처리합니다.
- min_counts로 UMI 수가 적은 spot을 거르고, spot별 UMI 수 분포(violin)와 조직 위 분포를 그립니다.
- SCTransform으로 정규화하고, feature_genes를 주면 그 유전자의 조직 위 발현을 그립니다.
- 결과 폴더는 spatial_cluster 모듈의 입력입니다.

### 내용(영문)
Loads the Space Ranger output (count matrix and tissue image) of each 10x Visium slice, filters spots and normalises them with SCTransform. Sequencing depth varies widely between spots, so normalisation is needed before expression can be compared.
- Each subfolder of the input folder is one slice, and all slices are processed with the same settings.
- min_counts removes spots with few UMI counts, and the UMI counts per spot are drawn as a violin and on the tissue.
- SCTransform normalises the counts; with feature_genes, the expression of those genes is drawn on the tissue.
- The output folder is the input of the spatial_cluster module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/visium | 슬라이스 폴더 모음. 슬라이스마다 하위 폴더 하나(폴더 이름 = 슬라이스 이름)이고, 각 폴더에 Space Ranger outs/ 또는 filtered_feature_bc_matrix.h5와 spatial/이 있어야 함. 슬라이스 하나의 outs를 직접 줘도 됨 | Folder of slices: one subfolder per slice (folder name = slice name), each with the Space Ranger outs/ or filtered_feature_bc_matrix.h5 and spatial/. One slice's outs can also be given directly |
| Output | Required | Directory | output_dir | /data/spatial_prep | 결과 폴더. 슬라이스마다 <slice>/<slice>_prep.rds(SCT 정규화 Seurat 객체), sessionInfo, plots/(QC 그림) | Output folder: per slice <slice>/<slice>_prep.rds (SCT-normalised Seurat object), sessionInfo, and plots/ (QC plots) |
| Option | Optional | String | h5_filename | filtered_feature_bc_matrix.h5 | 슬라이스 폴더에서 찾을 count 행렬 h5 파일 이름 | Name of the count matrix h5 file looked up in each slice folder |
| Option | Optional | Integer | min_counts | 0 | UMI 수가 이보다 적은 spot 제거. 0이면 거르지 않음 | Spots with fewer UMI counts are removed; 0 keeps all spots |
| Option | Optional | String | feature_genes |  | 조직 위에 발현을 그릴 유전자(쉼표 구분, 예: Hpca,Plp1). 비우면 그리지 않음 | Genes drawn on the tissue (comma separated, for example Hpca,Plp1). Empty: none |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 슬라이스 폴더 이름이 슬라이스 이름이 되어 이후 모든 결과와 조건 비교의 SliceID로 쓰입니다. 영문, 숫자, 밑줄로 짓는 것을 권장합니다. | The slice folder name becomes the slice name used in every later result and as SliceID in the condition comparison; letters, digits and underscores are recommended. |
| Space Ranger의 filtered_feature_bc_matrix.h5(조직 위 spot만)를 씁니다. raw 행렬을 쓰면 조직 밖 spot이 들어갑니다. | The Space Ranger filtered_feature_bc_matrix.h5 (spots under tissue only) is used; the raw matrix would add spots outside the tissue. |
| 기본값(min_counts=0)은 spot을 거르지 않습니다. QC 그림에서 UMI 수가 매우 낮은 spot이 많으면 값을 올려 다시 실행해 주세요. | The default (min_counts=0) keeps every spot; if the QC plot shows many spots with very low UMI counts, raise the value and rerun. |
| Visium HD 데이터는 이 모듈이 아니라 spatial_hd_prep으로 분석합니다. | Visium HD data are analysed with spatial_hd_prep, not with this module. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_prep_concept.png`

- 레전드(국문): **그림. 슬라이스 불러오기와 정규화.** (A) spot별 UMI 수(nCount_Spatial)를 violin과 조직 위에 그려 확인하고, min_counts를 주면 UMI가 적은 spot을 거릅니다. (B) 슬라이스마다 SCTransform으로 spot 사이 깊이 차이를 보정한 정규화 값을 만들어 <slice>_prep.rds로 저장합니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Loading and normalising slices.** (A) UMI counts per spot (nCount_Spatial) are checked as a violin and on the tissue; min_counts removes low-count spots. (B) SCTransform corrects depth differences between spots per slice, and the result is saved as <slice>_prep.rds. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_prep.1.1.R \
  input_dir=/data/visium \
  output_dir=/data/spatial_prep \
  h5_filename=filtered_feature_bc_matrix.h5 \
  min_counts=0 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 마우스 뇌 Visium 4장(Sagittal Anterior·Posterior, Section 1·2)입니다. Codespace 메모리 때문에 네 슬라이스에서 공통으로 가장 많이 검출된 유전자 6,000개만 썼습니다. 대표 슬라이스는 sec1_anterior입니다.

**결과 1. spot별 UMI 수 QC**
- 결과 파일: `<slice>/plots/<slice>_qc_nCount_Spatial.png`

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_prep_result_1.png`

- 레전드(국문): **슬라이스의 spot별 UMI 수.** 왼쪽은 spot별 UMI 수(nCount_Spatial) 분포(violin, 점은 spot)이고, 오른쪽은 같은 값을 조직 이미지 위에 칠한 것입니다(파랑이 적고 빨강이 많음). 조직 밖이나 손상된 부분에 UMI가 매우 낮은 spot이 몰려 있으면 min_counts로 거릅니다. 예시 데이터(spot 2,695개)에서는 UMI 수가 대부분 1만~4만이고 중앙값이 약 2만 5천이었으며, 조직 가장자리와 일부 영역에서 낮았습니다. 기본값(min_counts=0)으로 거르지 않았습니다.
- 레전드(영문): **UMI counts per spot of a slice.** Left: distribution of UMI counts per spot (nCount_Spatial; violin, points are spots); right: the same values on the tissue image (blue low, red high). If spots with very low counts gather outside the tissue or in damaged areas, filter them with min_counts. In the example data (2,695 spots) most spots had 10,000-40,000 UMIs with a median of about 25,000, lower at the tissue edge and in some regions; the default (min_counts=0) kept all spots.

---

## 2. spatial_cluster

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_cluster | spatial_cluster |
| 서브 타이틀 | 슬라이스별 군집과 마커 | Clustering and markers per slice |
| 버전 | 1.1 | |
| 카테고리 대분류 | Clustering (신규) | Clustering (new) |
| 카테고리 중분류 | Spatial_Clustering (신규) | Spatial_Clustering (new) |
| 태그 | spatial transcriptomics, Visium, clustering, UMAP, marker genes | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_cluster.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 32GB | 8 cores, 32 GB of memory |

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
슬라이스마다 spot을 발현이 비슷한 군집으로 나누고, 군집마다 특징 유전자(마커)를 찾습니다. 군집을 조직 위에 그리면 피질 층, 해마처럼 해부학적 영역이 드러납니다.
- PCA, 이웃 그래프, Louvain 군집, UMAP을 차례로 계산합니다.
- 군집마다 다른 군집보다 높게 발현하는 마커를 찾아(presto 사용) 전체 표와 상위 표를 만듭니다.
- UMAP과 조직 위 군집, 군집별 강조 그림, 마커 heatmap과 dot plot을 그립니다.
- 군집 번호는 슬라이스마다 따로 매겨집니다. 슬라이스 사이 비교는 spatial_merge로 합친 뒤에 합니다.

### 내용(영문)
Splits the spots of each slice into clusters of similar expression and finds marker genes per cluster. Drawn on the tissue, clusters reveal anatomical regions such as cortical layers and the hippocampus.
- PCA, a neighbour graph, Louvain clustering and UMAP are computed in turn.
- Markers expressed more highly in each cluster than in the others are found (with presto), giving a full and a top marker table.
- UMAP and tissue cluster plots, per-cluster highlights, a marker heatmap and a dot plot are drawn.
- Cluster numbers are assigned per slice; compare slices after merging them with spatial_merge.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_prep | 정규화된 슬라이스 폴더. 슬라이스마다 <slice>/<slice>_prep.rds(SCT assay가 있는 Seurat 객체)가 있어야 함 | Folder of normalised slices: <slice>/<slice>_prep.rds per slice (Seurat object with an SCT assay) |
| Output | Required | Directory | output_dir | /data/spatial_cluster | 결과 폴더. 슬라이스마다 <slice>_clustered.rds, 군집 요약, 마커 표(전체, 상위), plots/(UMAP·조직 군집, 마커 heatmap·dot plot) | Output folder: per slice <slice>_clustered.rds, cluster summary, marker tables (all, top), and plots/ (UMAP and tissue clusters, marker heatmap and dot plot) |
| Option | Optional | Float | resolution | 0.8 | 군집 해상도. 클수록 군집이 많아짐 | Clustering resolution; larger gives more clusters |
| Option | Optional | Integer | npcs | 30 | 사용할 주성분 수 | Number of principal components |
| Option | Optional | Integer | marker_topn | 5 | 군집마다 그림에 넣는 마커 수 | Markers per cluster shown in the plots |
| Option | Optional | Float | marker_min_pct | 0.25 | 마커 검정 최소 발현 비율 | Minimum fraction of expressing spots for marker testing |
| Option | Optional | Float | marker_logfc | 0.25 | 마커 검정 최소 log fold change | Minimum log fold change for marker testing |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 군집 번호는 슬라이스마다 따로 매겨지므로, 다른 슬라이스의 같은 번호가 같은 영역을 뜻하지 않습니다. | Cluster numbers are assigned separately per slice, so the same number in two slices does not mean the same region. |
| 군집이 너무 잘게 나뉘거나 뭉치면 resolution을 바꿔 다시 실행합니다(예: 0.4~1.2). | If clusters are too fine or too coarse, rerun with another resolution (for example 0.4-1.2). |
| 입력 객체에 SCT assay가 있어야 합니다(spatial_prep 결과 구조). | The input objects need an SCT assay (the structure written by spatial_prep). |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/clustering_traag2019_fig1.png`

- 레전드(국문): **그림. 군집에 쓰는 Louvain 알고리즘.** (a) 처음에는 이웃 그래프의 점(spot·bin)이 각자 하나의 군집입니다. (b) 군집 안 연결이 촘촘해지도록 점을 이웃 군집으로 옮깁니다. (c) 만든 군집을 점 하나로 합쳐 작은 그래프를 만들고 (d) 다시 옮기기를 반복합니다. Seurat FindClusters의 기본 방법이며, resolution이 클수록 군집이 잘게 나뉩니다. Traag VA et al., Sci Rep 9, 5233 (2019), Fig. 1(CC BY 4.0).
- 레전드(영문): **Figure. The Louvain algorithm used for clustering.** (a) Each point (spot or bin) of the neighbour graph starts as its own community. (b) Points are moved to neighbouring communities to make communities densely connected. (c) Communities are aggregated into single points and (d) moving is repeated. This is the default method of Seurat FindClusters; a larger resolution gives finer clusters. Fig. 1 of Traag VA et al., Sci Rep 9, 5233 (2019) (CC BY 4.0).
- 출처: Traag VA, Waltman L, van Eck NJ. From Louvain to Leiden: guaranteeing well-connected communities. *Scientific Reports* 9, 5233 (2019). https://doi.org/10.1038/s41598-019-41695-z, Fig. 1을 그대로 씀. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_cluster_concept.png`

- 레전드(국문): **그림. 슬라이스별 군집과 마커.** (A) 군집은 UMAP에서 점 무리로, 조직 위에서 해부학적 영역으로 나타납니다. 군집 번호는 슬라이스마다 따로 매겨집니다. (B) 군집마다 presto로 마커를 찾아 dot plot(점 크기: 발현 spot 비율, 색: 평균 발현)과 표로 남깁니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Clusters and markers per slice.** (A) Clusters appear as groups of points on the UMAP and as anatomical regions on the tissue; numbers are per slice. (B) Markers per cluster are found with presto and saved as a dot plot (dot size: fraction of expressing spots; colour: mean expression) and tables. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_cluster.1.1.R \
  input_dir=/data/spatial_prep \
  output_dir=/data/spatial_cluster \
  resolution=0.8 \
  npcs=30 \
  marker_topn=5 \
  marker_min_pct=0.25 \
  marker_logfc=0.25 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 마우스 뇌 Visium 4장(Sagittal Anterior·Posterior, Section 1·2)입니다. Codespace 메모리 때문에 네 슬라이스에서 공통으로 가장 많이 검출된 유전자 6,000개만 썼습니다. 대표 슬라이스는 sec1_anterior입니다.

**결과 1. 군집의 UMAP과 조직 위 분포(대표 그림)**
- 결과 파일: `<slice>/plots/<slice>_clusters_umap_spatial.png` (군집별 강조 그림 `<slice>_clusters_spatial_highlight.png`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_cluster_result_1.png`

- 레전드(국문): **슬라이스 안의 군집.** 왼쪽은 UMAP 위 군집, 오른쪽은 같은 군집을 조직 위에 칠한 것이며 숫자는 군집 번호입니다. 발현이 비슷한 spot은 UMAP에서 가깝고, 조직에서는 해부학적 영역으로 모입니다. 군집 번호는 슬라이스마다 따로 매겨집니다. 예시 데이터에서는 군집 17개(resolution 0.8)가 나왔고, 대뇌 피질이 표면을 따라 층 모양 띠로, 왼쪽 후각망울이 별도 군집(4, 11)으로 나뉘었습니다.
- 레전드(영문): **Clusters within a slice.** Left: clusters on the UMAP; right: the same clusters on the tissue, labelled by number. Spots with similar expression lie close on the UMAP and gather into anatomical regions on the tissue. Cluster numbers are per slice. In the example data 17 clusters (resolution 0.8) appeared: the cerebral cortex forms layered bands along the surface, and the olfactory bulb on the left forms separate clusters (4, 11).

**결과 2. 군집 마커 dot plot**
- 결과 파일: `<slice>/plots/<slice>_marker_dotplot.png` (heatmap `<slice>_marker_heatmap.png`, 표 `<slice>_cluster_markers.csv`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_cluster_result_2.png`

- 레전드(국문): **군집별 상위 마커 유전자.** 세로가 군집(Cluster), 가로가 마커 유전자(Marker gene)이며, 점 크기는 발현하는 spot 비율(Percent Expressed), 색 진하기는 평균 발현(Average Expression, 척도화)입니다. 대각선으로 진한 점이 모이면 군집마다 고유한 마커가 있다는 뜻입니다. 예시 데이터에서는 군집마다 marker_topn=5개의 마커가 대각선 모양으로 구분되었습니다(예: 군집 4 Fabp7·Calb2, 군집 15 Ttr·Enpp2). 이 그림은 스크립트가 투명 배경으로 저장해, 포탈용으로 흰 배경을 깔았습니다.
- 레전드(영문): **Top marker genes per cluster.** Rows are clusters (Cluster), columns marker genes (Marker gene); dot size is the fraction of expressing spots (Percent Expressed) and colour the scaled mean expression (Average Expression). Dark dots along a diagonal mean each cluster has its own markers. In the example data the marker_topn=5 markers of each cluster form a diagonal (for example cluster 4 Fabp7 and Calb2, cluster 15 Ttr and Enpp2). The script saves this plot with a transparent background, so a white background was added for the portal.

---

## 3. spatial_svf

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_svf | spatial_svf |
| 서브 타이틀 | 공간 가변 유전자 탐색 | Spatially variable genes |
| 버전 | 1.1 | |
| 카테고리 대분류 | Statistics_and_Visualization | Statistics_and_Visualization |
| 카테고리 중분류 | Spatial_Omics (신규) | Spatial_Omics (new) |
| 태그 | spatial transcriptomics, Visium, spatially variable genes, Moran's I | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_svf.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 32GB | 8 cores, 32 GB of memory |

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
슬라이스마다 조직의 특정 위치에 몰려 발현하는 유전자(공간 가변 유전자)를 찾습니다. 군집과 상관없이 공간 패턴 자체로 유전자를 고르므로, 층 구조나 경계를 따라 발현하는 유전자를 찾는 데 씁니다.
- 가변성이 높은 유전자 svf_topn개를 골라 공간 자기상관(Moran's I 또는 mark variogram)을 계산합니다.
- 순위 표(rank, gene)를 만들고, 상위 svf_show개 유전자를 조직 위에 그립니다.
- 슬라이스마다 따로 계산합니다.

### 내용(영문)
Finds genes whose expression is concentrated in particular places of the tissue (spatially variable genes) in each slice. Genes are chosen by their spatial pattern itself, regardless of clusters, which finds genes along layers and boundaries.
- Spatial autocorrelation (Moran's I or mark variogram) is computed for the svf_topn most variable genes.
- A rank table (rank, gene) is written, and the svf_show top genes are drawn on the tissue.
- Each slice is analysed separately.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_cluster | 군집 결과 폴더. 슬라이스마다 <slice>/<slice>_clustered.rds(SCT assay, 조직 이미지 포함)가 있어야 함 | Folder of clustered slices: <slice>/<slice>_clustered.rds per slice (with the SCT assay and the tissue image) |
| Output | Required | Directory | output_dir | /data/spatial_svf | 결과 폴더. 슬라이스마다 <slice>_svf.rds, <slice>_svf_<method>.csv(공간 자기상관 순위와 유전자), plots/<slice>_top_svf_<method>.png | Output folder: per slice <slice>_svf.rds, <slice>_svf_<method>.csv (spatial autocorrelation rank and gene), and plots/<slice>_top_svf_<method>.png |
| Option | Optional | List | svf_method | moransi | 공간 자기상관 방법(moransi, markvariogram) | Spatial autocorrelation method (moransi, markvariogram) |
| Option | Optional | Integer | svf_topn | 1000 | 검정할 가변 유전자 수(가변성 상위) | Number of variable genes tested (most variable first) |
| Option | Optional | Integer | svf_show | 6 | 조직 위에 그릴 상위 유전자 수 | Top genes drawn on the tissue |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 검정 대상은 가변성 상위 svf_topn개 유전자뿐입니다. 발현이 낮아 가변 유전자에 들지 못한 유전자는 점수가 없습니다. | Only the svf_topn most variable genes are tested; genes too weakly expressed to be variable get no score. |
| Moran's I 점수는 조직 위 이웃 spot끼리 발현이 비슷할수록 1에 가깝습니다. 점수가 높아도 발현량이 낮을 수 있으니 그림과 함께 확인해 주세요. | Moran's I approaches 1 when neighbouring spots have similar expression; a high score can still come with low expression, so check the plots. |
| Moran's I 계산은 spot 수의 제곱에 비례해 오래 걸립니다(예시: spot 2,695개, 유전자 1,000개에 약 7.5분). 시간이 길면 svf_topn을 줄여 주세요. markvariogram은 더 오래 걸리므로 기본값 moransi를 권장합니다. | Moran's I grows with the square of the number of spots (example: 2,695 spots and 1,000 genes took about 7.5 minutes); lower svf_topn when it runs long. markvariogram takes longer still, so the default moransi is recommended. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_svf_concept.png`

- 레전드(국문): **그림. 공간 가변 유전자.** (A) 이웃 spot끼리 발현이 비슷하게 몰린 유전자는 Moran's I가 크고(왼쪽), 무작위로 흩어진 유전자는 0에 가깝습니다(오른쪽). (B) SCT 가변 유전자 중 상위 svf_topn개에 spot 좌표로 Moran's I를 계산해(ape) 순위를 매깁니다. 계산량은 spot 수의 제곱에 비례합니다. markvariogram은 더 느린 대안입니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Spatially variable genes.** (A) A gene whose expression is similar among neighbouring spots has a high Moran's I (left); a randomly scattered gene is near 0 (right). (B) Moran's I is computed with the spot coordinates (ape) for the svf_topn most variable SCT genes and used to rank them; the cost grows with the square of the number of spots, and markvariogram is a slower alternative. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_svf.1.1.R \
  input_dir=/data/spatial_cluster \
  output_dir=/data/spatial_svf \
  svf_method=moransi \
  svf_topn=1000 \
  svf_show=6 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 마우스 뇌 Visium의 sec1_anterior 한 장(유전자 6,000개, spot 2,695개)이며 기본값(moransi, svf_topn 1000, svf_show 6)으로 실행했습니다.

**결과 1. 공간 가변 유전자 상위 6개의 조직 위 발현(대표 그림)**
- 결과 파일: `<slice>/plots/<slice>_top_svf_moransi.png`, 순위 표 `<slice>/<slice>_svf_moransi.csv`(rank, gene)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_svf_result_1.png`

- 레전드(국문): **Moran's I 순위 상위 유전자의 조직 위 발현.** 패널마다 유전자 하나를 조직 이미지 위에 칠한 것이며(파랑 낮음, 빨강 높음), 색 범위는 패널마다 따로입니다. 공간 가변 유전자는 군집과 상관없이 특정 위치에 몰려 발현하므로, 그림에서 뚜렷한 영역이나 층이 보여야 정상입니다. 예시 데이터에서는 1위 Calb2, 2위 Gng4와 Pcbp3·Gpsm1이 왼쪽 후각망울의 층에, Ttr(3위)이 오른쪽 뇌실의 맥락얼기에, Fabp7(5위)이 후각망울 가장자리에 몰려 있었습니다.
- 레전드(영문): **Tissue expression of the top genes ranked by Moran's I.** Each panel paints one gene on the tissue image (blue low, red high), with its own colour range. Spatially variable genes are concentrated in particular places regardless of clusters, so clear regions or layers should appear. In the example data Calb2 (1st), Gng4 (2nd), Pcbp3 and Gpsm1 sit in layers of the olfactory bulb on the left, Ttr (3rd) in the choroid plexus of the ventricle on the right, and Fabp7 (5th) along the edge of the olfactory bulb.

---

## 4. spatial_merge

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_merge | spatial_merge |
| 서브 타이틀 | 여러 슬라이스 통합 군집 | Joint clustering of multiple slices |
| 버전 | 1.1 | |
| 카테고리 대분류 | Clustering (신규) | Clustering (new) |
| 카테고리 중분류 | Spatial_Clustering (신규) | Spatial_Clustering (new) |
| 태그 | spatial transcriptomics, Visium, integration, Harmony, multi-slice | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_merge.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 64GB | 8 cores, 64 GB of memory |

등록 메모: 작업 파일 `spatial_merge.1.2.R`을 배포 번호 1.1로 올립니다.

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
여러 슬라이스를 하나의 객체로 합쳐 차원 축소와 군집을 다시 계산합니다. 슬라이스마다 따로 매긴 군집 번호와 달리, 합친 군집은 모든 슬라이스에서 같은 뜻이라 슬라이스와 조건 사이를 비교할 수 있습니다.
- 슬라이스별 군집 객체를 합치고 PCA, 군집, UMAP을 다시 계산합니다. integration=harmony이면 Harmony로 슬라이스 차이를 보정합니다.
- 군집×슬라이스 spot 수 표와 조성 그림(누적 막대, heatmap)을 만듭니다.
- 합친 객체에서 군집 마커를 찾고 heatmap과 dot plot을 그립니다.
- 결과 폴더는 spatial_condition_de 모듈의 입력입니다.

### 내용(영문)
Merges several slices into one object and recomputes the dimensional reduction and clustering. Unlike per-slice cluster numbers, the joint clusters mean the same in every slice, so slices and conditions can be compared.
- The clustered slice objects are merged and PCA, clustering and UMAP are recomputed; with integration=harmony, Harmony corrects slice differences.
- A cluster-by-slice spot count table and composition plots (stacked bars, heatmap) are made.
- Cluster markers of the merged object are found and drawn as a heatmap and dot plot.
- The output folder is the input of the spatial_condition_de module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_cluster | 군집 결과 폴더. 슬라이스마다 <slice>/<slice>_clustered.rds(SCT assay)가 있어야 함(input_dir 바로 아래 *_clustered.rds도 찾음) | Folder of clustered slices: <slice>/<slice>_clustered.rds per slice with an SCT assay (*_clustered.rds directly in input_dir also found) |
| Output | Required | Directory | output_dir | /data/spatial_merge | 결과 폴더. merged/merged_clustered.rds, 군집×슬라이스 표, 마커 표, merged/plots/(UMAP, 조직 군집, 조성, 마커), merge_report.txt | Output folder: merged/merged_clustered.rds, cluster-by-slice table, marker tables, merged/plots/ (UMAP, tissue clusters, composition, markers), and merge_report.txt |
| Option | Optional | List | integration | none | 슬라이스 보정. none = 보정 없음, harmony = Harmony로 슬라이스 차이 보정 | Slice correction: none, or harmony (Harmony corrects slice differences) |
| Option | Optional | Integer | npcs | 30 | 사용할 주성분 수 | Number of principal components |
| Option | Optional | Float | resolution | 0.8 | 군집 해상도. 클수록 군집이 많아짐 | Clustering resolution; larger gives more clusters |
| Option | Optional | String | assay | SCT | 합쳐서 분석할 assay | Assay merged and analysed |
| Option | Optional | String | features |  | 조직 위에 발현을 그릴 유전자(쉼표 구분). 비우면 그리지 않음 | Genes drawn on the tissue (comma separated). Empty: none |
| Option | Optional | Integer | marker_topn | 5 | 군집마다 그림에 넣는 마커 수 | Markers per cluster shown in the plots |
| Option | Optional | Float | marker_min_pct | 0.25 | 마커 검정 최소 발현 비율 | Minimum fraction of expressing spots for marker testing |
| Option | Optional | Float | marker_logfc | 0.25 | 마커 검정 최소 log fold change | Minimum log fold change for marker testing |
| Option | Optional | Float | plot_width | 8 | 그림 너비(inch) | Plot width (inch) |
| Option | Optional | Float | plot_height | 6 | 그림 높이(inch) | Plot height (inch) |
| Option | Optional | Integer | dpi | 300 | 그림 해상도 | Plot resolution |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 슬라이스 사이에 배치 차이(다른 날 실험, 다른 조직 처리)가 크면 integration=harmony를 권장합니다. 보정하지 않으면 군집이 슬라이스별로 나뉠 수 있습니다. | With strong batch differences between slices (different days or tissue handling), integration=harmony is recommended; without it clusters may split by slice. |
| 슬라이스 수에 따라 메모리가 늘어납니다. 64GB를 권장하며, 슬라이스가 아주 많으면 128GB로 올려 주세요. | Memory grows with the number of slices: 64 GB is recommended, and 128 GB for very many slices. |
| 실행할 때마다 output_dir에서 logs/를 뺀 나머지를 지웁니다. 입력(군집 결과 폴더)을 output_dir 안에 두지 마세요. | output_dir except logs/ is cleared on every run; do not keep the input (cluster folder) inside it. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/clustering_traag2019_fig1.png`

- 레전드(국문): **그림. 군집에 쓰는 Louvain 알고리즘.** (a) 처음에는 이웃 그래프의 점(spot·bin)이 각자 하나의 군집입니다. (b) 군집 안 연결이 촘촘해지도록 점을 이웃 군집으로 옮깁니다. (c) 만든 군집을 점 하나로 합쳐 작은 그래프를 만들고 (d) 다시 옮기기를 반복합니다. Seurat FindClusters의 기본 방법이며, resolution이 클수록 군집이 잘게 나뉩니다. Traag VA et al., Sci Rep 9, 5233 (2019), Fig. 1(CC BY 4.0).
- 레전드(영문): **Figure. The Louvain algorithm used for clustering.** (a) Each point (spot or bin) of the neighbour graph starts as its own community. (b) Points are moved to neighbouring communities to make communities densely connected. (c) Communities are aggregated into single points and (d) moving is repeated. This is the default method of Seurat FindClusters; a larger resolution gives finer clusters. Fig. 1 of Traag VA et al., Sci Rep 9, 5233 (2019) (CC BY 4.0).
- 출처: Traag VA, Waltman L, van Eck NJ. From Louvain to Leiden: guaranteeing well-connected communities. *Scientific Reports* 9, 5233 (2019). https://doi.org/10.1038/s41598-019-41695-z, Fig. 1을 그대로 씀. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_merge_concept.png`

- 레전드(국문): **그림. 여러 슬라이스 통합 군집.** (A) 슬라이스마다 따로 군집하면 같은 영역도 슬라이스마다 번호(색)가 다릅니다. (B) 슬라이스 객체를 합쳐 다시 군집하면(integration=harmony이면 Harmony로 슬라이스 차이 보정) 같은 번호가 모든 슬라이스에서 같은 영역을 뜻합니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Joint clustering of several slices.** (A) Clustering each slice alone gives the same region different numbers (colours) in different slices. (B) Merging the slices and clustering again (with Harmony correcting slice differences when integration=harmony) makes each number mean the same region in every slice. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_merge.1.1.R \
  input_dir=/data/spatial_cluster \
  output_dir=/data/spatial_merge \
  integration=none \
  npcs=30 \
  resolution=0.8 \
  assay=SCT \
  marker_topn=5 \
  marker_min_pct=0.25 \
  marker_logfc=0.25 \
  plot_width=8 \
  plot_height=6 \
  dpi=300 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 10x Genomics 공개 마우스 뇌 Visium 4장(Sagittal Anterior·Posterior, Section 1·2)입니다. Codespace 메모리 때문에 네 슬라이스에서 공통으로 가장 많이 검출된 유전자 6,000개만 썼습니다. merge에는 슬라이스마다 spot 600개만 뽑아 썼습니다(Codespace 메모리 때문, 실제 분석에서는 모든 spot을 씀).

**결과 1. 통합 군집의 조직 위 분포(대표 그림)**
- 결과 파일: `merged/plots/merged_spatialdim_all.png` (슬라이스별 `merged_spatialdim_<slice>.png`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_merge_result_1.png`

- 레전드(국문): **모든 슬라이스에서 같은 기준으로 매긴 군집.** 슬라이스마다 조직 이미지 위에 통합 군집을 칠한 것으로, 같은 번호는 모든 슬라이스에서 같은 영역을 뜻합니다. 같은 부위의 슬라이스끼리 같은 영역에 같은 군집이 나와야 정상입니다. 예시 데이터(Harmony 보정, 군집 16개)에서는 section 1과 2의 같은 부위(anterior끼리, posterior끼리)에서 군집 배치가 같았고, 소뇌 과립층(군집 11)은 posterior 슬라이스에만 나왔습니다. spot 600개만 뽑아 써서 점이 듬성듬성합니다.
- 레전드(영문): **Clusters assigned on a common basis in every slice.** The joint clusters are painted on each slice's tissue image; the same number means the same region in every slice. Slices of the same part should show the same clusters in the same regions. In the example data (Harmony, 16 clusters) sections 1 and 2 of the same part (anterior with anterior, posterior with posterior) had the same cluster layout, and the cerebellar granular layer (cluster 11) appeared in the posterior slices only. Only 600 spots per slice were used, so the points are sparse.

**결과 2. 통합 UMAP**
- 결과 파일: `merged/plots/merged_umap.png` (군집별 `merged_umap_by_cluster.png`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_merge_result_2.png`

- 레전드(국문): **통합 군집(왼쪽, ident)과 슬라이스(오른쪽, orig.ident)로 칠한 UMAP.** 슬라이스 보정이 잘 되면 오른쪽에서 슬라이스 색이 군집 안에 고루 섞이고, 한 슬라이스에만 있는 영역만 따로 모입니다. 예시 데이터에서는 같은 부위의 두 section이 고루 섞였고, anterior와 posterior는 각자에만 있는 영역(예: 후각망울, 소뇌)에서 나뉘었습니다.
- 레전드(영문): **UMAP coloured by joint cluster (left, ident) and slice (right, orig.ident).** With good slice correction, slice colours mix within clusters on the right, and only regions present in one slice stay apart. In the example data the two sections of each part mixed evenly, while anterior and posterior separated at regions present in only one of them (for example the olfactory bulb and cerebellum).

**결과 3. 슬라이스별 군집 조성**
- 결과 파일: `merged/plots/merged_cluster_by_slice_stackedbar.png` (heatmap `merged_cluster_by_slice_heatmap.png`, 표 `merged_cluster_by_slice.csv`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_merge_result_3.png`

- 레전드(국문): **슬라이스마다 군집이 차지하는 비율(Proportion).** 막대 하나가 슬라이스 하나이고 색이 군집입니다. 같은 부위의 슬라이스는 비슷한 조성을 보여야 하며, 크게 다르면 절편 위치나 품질 차이를 확인합니다. 예시 데이터에서는 sec1·sec2 anterior끼리, posterior끼리 조성이 비슷했고, anterior와 posterior는 포함한 뇌 영역이 달라 조성이 달랐습니다.
- 레전드(영문): **Proportion of each cluster per slice.** Each bar is a slice and each colour a cluster. Slices of the same part should have similar compositions; large differences call for checking section position or quality. In the example data the two anterior slices and the two posterior slices were similar, while anterior and posterior differed because they contain different brain regions.

---

## 5. spatial_condition_de

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
| Processor Core (제안) | 4코어, 메모리 64GB | 4 cores, 64 GB of memory |

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
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
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/condition_de_squair2021_fig2a.png`

- 레전드(국문): **그림. pseudobulk 만들기.** 조건(대조·처리)마다 반복 시료의 세포 발현을 반복별로 합쳐 pseudobulk 열을 만듭니다(오른쪽, 열 = 반복). 이 모듈에서는 세포 대신 한 군집의 spot(bin)을, 반복 대신 슬라이스를 씁니다. 세포를 반복으로 삼으면 거짓 양성이 많아지므로 슬라이스를 단위로 검정합니다. Squair JW et al., Nat Commun 12, 5692 (2021), Fig. 2a(CC BY 4.0).
- 레전드(영문): **Figure. Building pseudobulks.** For each condition (control, treatment), cell expression is summed per replicate into pseudobulk columns (right, one column per replicate). In this module the spots (bins) of one cluster take the place of cells and slices that of replicates; testing with slices as units avoids the false discoveries that treating cells as replicates produces. Fig. 2a of Squair JW et al., Nat Commun 12, 5692 (2021) (CC BY 4.0).
- 출처: Squair JW, Gautier M, Kathe C, Anderson MA, James ND, Hutson TH, Hudelle R, Qaiser T, Matson KJE, Barraud Q, Levine AJ, La Manno G, Skinnider MA, Courtine G. Confronting false discoveries in single-cell differential expression. *Nature Communications* 12, 5692 (2021). https://doi.org/10.1038/s41467-021-25960-2, Fig. 2a 부분만 잘라 씀. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_condition_de_concept.png`

- 레전드(국문): **그림. 조건 간 군집별 비교.** (A) 군집마다 volcano를 그립니다(x축 log2 fold change, y축 -log10 adjusted p, 빨강 기준보다 높음, 파랑 낮음, 점선은 lfc_cutoff와 padj_cutoff). (B) de_summary.tsv에 군집별 검정 방법과 상태(ok, ok_exploratory, insufficient_slices)를 남깁니다. Visium merge 결과와 Visium HD 결과(hd_slides.tsv)를 모두 받으며, group_by로 세포 유형 열을 쓸 수도 있습니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Comparison between conditions per cluster.** (A) A volcano per cluster (x log2 fold change, y -log10 adjusted p; red higher than the reference, blue lower; dashed lines lfc_cutoff and padj_cutoff). (B) de_summary.tsv records the method and status per cluster (ok, ok_exploratory, insufficient_slices). Visium merge output and Visium HD output (hd_slides.tsv) are both accepted, and group_by may name a cell-type column. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_condition_de.1.0.R \
  input_dir=/data/spatial_merge \
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
예시 데이터는 10x Genomics 공개 마우스 뇌 Visium 4장(Sagittal Anterior·Posterior, Section 1·2)입니다. Codespace 메모리 때문에 네 슬라이스에서 공통으로 가장 많이 검출된 유전자 6,000개만 썼습니다. Visium 예시는 section 1(기준)과 section 2를 조건으로 놓고 조건마다 슬라이스 2장(anterior, posterior)을 비교했으며, 슬라이스마다 spot 600개를 썼습니다. 같은 조직의 연속 절편이므로 실제 차이가 없어야 정상인 비교입니다. Visium HD 예시(결과 6)는 한 장을 4분면으로 나눠 왼쪽 2장과 오른쪽 2장을 비교했습니다.

**결과 1. 군집별 volcano(대표 그림)**
- 결과 파일: `03_plots/volcano_<test>_vs_<reference>.png` (PDF도 있음), 표 `02_de/de_<test>_vs_<reference>.tsv`

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_condition_de_result_1.png`

- 레전드(국문): **군집마다 조건 간 유전자 발현 차이.** 패널 하나가 군집 하나이고, x축은 log2 fold change(기준 조건 대비), y축은 -log10 adjusted p입니다. 빨강은 기준보다 높은(up), 파랑은 낮은(down) 유의 유전자이며, 점선은 |log2FC| = lfc_cutoff와 padj_cutoff입니다. 패널마다 상위 유전자 이름을 붙입니다. 예시 데이터(section2 vs section1)에서는 슬라이스가 조건마다 2장인 군집 7개(pseudobulk DESeq2)에서 유의 유전자가 0개였습니다. 한 조건에 슬라이스가 1장뿐인 군집(spot 단위 검정, 탐색용)에서만 미토콘드리아(mt-Nd5, mt-Co1)와 리보솜(Rps28, Rps29) 유전자가 유의하게 나와, 절편 간 기술적 차이를 보여 줍니다.
- 레전드(영문): **Expression differences between conditions per cluster.** Each panel is a cluster; the x axis is log2 fold change (against the reference condition) and the y axis -log10 adjusted p. Red marks significant genes higher than the reference (up), blue lower (down); dashed lines are |log2FC| = lfc_cutoff and padj_cutoff, and top genes are labelled. In the example data (section2 vs section1) the seven clusters with two slices per condition (pseudobulk DESeq2) had no significant genes. Only clusters with one slice in a condition (spot-level test, exploratory) showed significant mitochondrial (mt-Nd5, mt-Co1) and ribosomal (Rps28, Rps29) genes, a technical difference between sections.

**결과 2. 조건별 군집 비율**
- 결과 파일: `03_plots/composition_by_condition.png` (누적 막대 `composition_stacked.png`, 표 `01_composition/`도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_condition_de_result_2.png`

- 레전드(국문): **군집마다 조건별 spot 비율.** 패널 하나가 군집 하나이고, 점은 슬라이스, 가로 막대는 조건 평균입니다(y축 Fraction of spots). 조건 간 비율 검정 결과는 `01_composition/composition_test.tsv`에 있으며, 조건당 슬라이스가 적으면 탐색용입니다. 예시 데이터에서는 같은 조건 안에서도 anterior와 posterior의 비율이 크게 달라 점이 넓게 퍼졌고, 조건 평균의 차이는 그보다 작았습니다.
- 레전드(영문): **Fraction of spots per cluster by condition.** Each panel is a cluster; points are slices and the bar the condition mean (y axis Fraction of spots). The tests between conditions are in `01_composition/composition_test.tsv` and are exploratory with few slices. In the example data anterior and posterior differ widely even within a condition, so the points spread far, while the difference of the condition means is smaller.

**결과 3. 군집별 유의 유전자 수**
- 결과 파일: `03_plots/de_counts.png` (PDF도 있음), 표 `04_summary/de_summary.tsv`

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_condition_de_result_3.png`

- 레전드(국문): **군집마다 유의하게 높아진(up, 빨강, 0 위)·낮아진(down, 파랑, 0 아래) 유전자 수.** 어느 군집(영역)에서 조건 차이가 큰지 한눈에 봅니다. 검정 방법(pseudobulk 또는 spot 단위)과 상태는 de_summary.tsv에 있습니다. 예시 데이터에서는 spot 단위 검정을 한 군집 2(up 14, down 12), 8(up 3), 13(up 1), 14(up 10)에만 막대가 있고, pseudobulk 군집은 모두 0이었습니다.
- 레전드(영문): **Number of significantly increased (up, red, above 0) and decreased (down, blue, below 0) genes per cluster.** It shows which clusters (regions) differ most; the test method (pseudobulk or spot-level) and status are in de_summary.tsv. In the example data only the spot-level clusters 2 (14 up, 12 down), 8 (3 up), 13 (1 up) and 14 (10 up) have bars; all pseudobulk clusters have 0.

**결과 4. 상위 유전자 log2FC heatmap**
- 결과 파일: `03_plots/lfc_heatmap_<test>_vs_<reference>.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_condition_de_result_4.png`

- 레전드(국문): **군집별 상위 유전자의 log2 fold change.** 세로가 유전자, 가로가 군집이며, 색은 log2FC(빨강 증가, 파랑 감소, ±3에서 자름), 검은 점은 그 군집에서 유의함을 뜻합니다. 한 유전자가 여러 군집에서 같은 방향이면 조직 전체의 변화, 한 군집에만 있으면 영역 특이 변화입니다. 예시 데이터에서는 미토콘드리아 유전자(mt-Co1, mt-Nd 계열)가 군집 14에서 함께 높아졌고, 대부분 군집에서 색이 옅어 차이가 작았습니다. 이 그림은 스크립트가 투명 배경으로 저장해, 포탈용으로 흰 배경을 깔았습니다.
- 레전드(영문): **log2 fold change of top genes per cluster.** Rows are genes and columns clusters; colour is log2FC (red up, blue down, clipped at ±3), and black dots mark significance in that cluster. A gene changing the same way in many clusters points to a tissue-wide change, one in a single cluster to a regional change. In the example data mitochondrial genes (mt-Co1, mt-Nd) rose together in cluster 14, and most cells are pale, meaning small differences. The script saves this plot with a transparent background, so a white background was added for the portal.

**결과 5. 조직 위 유전자 분포**
- 결과 파일: `03_plots/spatial_<gene>.png` (PDF도 있음, spatial_genes개 유전자)

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/results/spatial_condition_de_result_5.png`

- 레전드(국문): **유의 유전자의 슬라이스별 조직 위 발현.** 기준 조건부터 슬라이스를 나란히 놓고, 모든 슬라이스에 같은 색 범위(파랑 낮음, 빨강 높음)를 써서 직접 비교할 수 있게 합니다. 예시 데이터의 Rps28은 네 슬라이스에서 비슷한 수준으로 고르게 퍼져, spot 단위로 나온 유의 차이가 특정 영역의 변화가 아님을 보여 줍니다. spot 600개만 써서 점이 듬성듬성합니다.
- 레전드(영문): **Tissue expression of significant genes per slice.** Slices are placed side by side from the reference condition with one colour range for all (blue low, red high), so they can be compared directly. In the example data Rps28 spreads evenly at similar levels in all four slices, showing that its spot-level significance is not a regional change. Only 600 spots per slice were used, so the points are sparse.

---

## 6. spatial_labelTransfer

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_labelTransfer | spatial_labelTransfer |
| 서브 타이틀 | 참조 기반 spot 세포 유형 예측 | Cell-type prediction of spots from a single-cell reference |
| 버전 | 1.1 | |
| 카테고리 대분류 | Annotation | Annotation |
| 카테고리 중분류 | Cell_Type_Annotation (신규) | Cell_Type_Annotation (new) |
| 태그 | spatial transcriptomics, Visium, label transfer, Seurat, cell type | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_labelTransfer.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 128GB | 8 cores, 128 GB of memory |

등록 메모: 작업 파일 `spatial_labelTransfer.1.2.R`을 배포 번호 1.1로 올립니다.

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
단일세포 RNA-seq 참조 자료의 세포 유형을 Visium 슬라이스의 spot으로 옮겨, spot마다 세포 유형별 예측 점수를 계산합니다. Seurat의 anchor 기반 label transfer(FindTransferAnchors, TransferData)를 씁니다.
- 참조 자료는 한 번만 준비해 모든 슬라이스에 씁니다. raw count가 있으면 SCTransform과 PCA를 여기서 계산하고, 없으면(Azimuth형 참조) 들어 있는 assay와 차원 축소를 그대로 씁니다.
- 참조에 SCT 모델이 있으면 슬라이스의 count를 그 모델로 다시 정규화해 같은 공간에서 anchor를 찾습니다.
- spot마다 세포 유형별 예측 점수(0~1)를 붙이고, 세포 유형마다 조직 위 점수 그림을 그립니다.
- 슬라이스×세포 유형 평균 점수 표와 heatmap을 만듭니다.

### 내용(영문)
Transfers the cell types of a single-cell RNA-seq reference to the spots of Visium slices and computes a prediction score per cell type for each spot, using Seurat anchor-based label transfer (FindTransferAnchors, TransferData).
- The reference is prepared once and used for all slices. With raw counts, SCTransform and PCA are computed here; without them (Azimuth-style references), the stored assay and reduction are used as they are.
- When the reference has an SCT model, the slice counts are re-normalised with that model so anchors are found in the same space.
- Each spot gets a prediction score (0-1) per cell type, and the scores of each cell type are drawn on the tissue.
- A table and a heatmap of the mean score per slice and cell type are made.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_cluster | 군집 결과 폴더. 슬라이스마다 <slice>/<slice>_clustered.rds(SCT assay와 pca가 있는 Seurat 객체) | Cluster output folder: per slice <slice>/<slice>_clustered.rds (Seurat object with the SCT assay and pca) |
| Input | Optional | File | reference_rds | /ref/brain_reference.rds | 단일세포 참조 자료(Seurat .rds). 세포 유형 열이 있어야 함. 비우면 이 모듈은 건너뜀(skipped.txt) | Single-cell reference (Seurat .rds) with a cell-type column. Empty: the module is skipped (skipped.txt) |
| Option | Optional | String | reference_label_col | celltype | 참조 자료에서 세포 유형이 든 메타데이터 열 이름. 참조를 주면 반드시 입력. 비었거나 참조에 없는 열이면 세포 유형 후보 열을 보여 주고 멈춤 | Metadata column of the reference holding the cell types; required when a reference is given. When empty or not in the reference, the run stops and lists the cell-type column candidates |
| Output | Required | Directory | output_dir | /data/spatial_labelTransfer | 결과 폴더. 슬라이스마다 <slice>_labeltransfer.rds, <slice>_predicted_celltype_scores.csv, plots/, 그리고 summary/(슬라이스×세포 유형 표와 heatmap) | Output folder: per slice <slice>_labeltransfer.rds, <slice>_predicted_celltype_scores.csv and plots/, and summary/ (slice-by-cell-type table and heatmap) |
| Option | Optional | Integer | reference_ncells | 3000 | 참조 SCTransform 모델을 맞출 때 쓰는 세포 수(참조에 SCT 모델이 없을 때만) | Cells used to fit the reference SCTransform model (only when the reference has no SCT model) |
| Option | Optional | Integer | npcs | 30 | anchor 탐색과 예측에 쓰는 주성분 수 | Principal components used for anchors and prediction |
| Option | Optional | Integer | min_shared_features | 200 | 참조와 슬라이스가 공유해야 하는 최소 유전자 수. 모자라면 그 슬라이스는 실패(종, 유전자 ID 형식 불일치) | Minimum genes shared by the reference and a slice; with fewer, the slice fails (species or gene ID mismatch) |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 참조 자료(reference_rds)를 주지 않으면 이 모듈은 건너뛰고(결과 폴더에 skipped.txt) 정상 종료하므로, 참조가 없어도 파이프라인은 끝까지 실행됩니다. 참조를 주면 세포 유형 열 이름(reference_label_col)도 넣어 주세요. 열 이름을 모르면 비워 두고 한 번 실행하면, 분석 전에 멈추고 오류 로그에 세포 유형 후보 열과 그 값들을 보여 줍니다. 확인한 열 이름을 넣어 다시 실행하세요. | Without a reference (reference_rds) the module is skipped (skipped.txt in the output folder) and ends without error, so the pipeline still runs to the end. With a reference, also give its cell-type column (reference_label_col). If the column name is unknown, leave it empty and run once: the run stops before the analysis and the error log lists the cell-type column candidates with their values. Run again with the chosen column. |
| 참조 자료와 슬라이스는 같은 종, 같은 유전자 이름 형식(예: 마우스 기호 Prox1)이어야 합니다. 공유 유전자가 min_shared_features보다 적으면 로그에 양쪽 유전자 이름 예시가 나옵니다. | The reference and the slices must share species and gene naming (for example mouse symbols such as Prox1); with fewer shared genes than min_shared_features, the log shows examples of both sides. |
| 예측 점수는 참조에 있는 세포 유형 중에서 고른 값입니다. 참조에 없는 조직(예: 해마 참조로 본 소뇌)은 가장 비슷한 유형으로 잘못 칠해질 수 있습니다. | Scores choose among the cell types of the reference; tissue missing from the reference (for example cerebellum with a hippocampus reference) can be painted with the most similar type. |
| 참조 세포가 적어 anchor가 있는 spot이 50개보다 적으면 TransferData의 k.weight를 자동으로 낮추고 경고를 남깁니다. 결과가 불안정할 수 있으니 더 큰 참조를 권장합니다. | When fewer than 50 spots carry anchors (small references), TransferData's k.weight is lowered automatically with a warning; results may be unstable, so a larger reference is recommended. |
| Visium spot(지름 55µm)에는 세포가 여러 개 들어 있어 점수는 섞인 비율이 아니라 닮은 정도입니다. 세포 유형 비율이 필요하면 spatial_rctd를 쓰세요. | A Visium spot (55 um) holds several cells, so scores express similarity rather than proportions; use spatial_rctd for cell-type proportions. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_labelTransfer_concept.png`

- 레전드(국문): **그림. 단일세포 참조에서 spot으로 세포 유형 옮기기.** (A) 세포 유형 열(reference_label_col)이 있는 단일세포 참조 자료입니다. raw count가 있으면 SCTransform과 PCA를 여기서 계산합니다. (B) 참조 세포와 슬라이스 spot 사이에서 서로 닮은 짝(anchor)을 찾고(FindTransferAnchors), anchor를 통해 spot마다 세포 유형별 예측 점수를 계산합니다(TransferData). 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Transferring cell types from a single-cell reference to spots.** (A) A single-cell reference with a cell-type column (reference_label_col); with raw counts, SCTransform and PCA are computed here. (B) Pairs of similar reference cells and slice spots (anchors) are found (FindTransferAnchors), and through them each spot gets a prediction score per cell type (TransferData). Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_labelTransfer.1.1.R \
  input_dir=/data/spatial_cluster \
  reference_rds=/ref/brain_reference.rds \
  reference_label_col=celltype \
  output_dir=/data/spatial_labelTransfer \
  reference_ncells=3000 \
  npcs=30 \
  min_shared_features=200 \
  seed=1234
```

### 주요 결과 이미지
등록 메모: SIF 테스트 결과 그림을 넣을 자리입니다(Codespace 재실행 중).

---

## 7. spatial_rctd

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_rctd | spatial_rctd |
| 서브 타이틀 | spot 세포 유형 비율 추정 | Cell-type proportions of spots with RCTD |
| 버전 | 1.1 | |
| 카테고리 대분류 | Annotation | Annotation |
| 카테고리 중분류 | Cell_Type_Annotation (신규) | Cell_Type_Annotation (new) |
| 태그 | spatial transcriptomics, Visium, RCTD, deconvolution, cell type | |
| 레퍼런스 URL | https://github.com/dmcable/spacexr | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_rctd.1.1.R | |
| Processor Core (제안) | 8코어, 메모리 64GB | 8 cores, 64 GB of memory |

등록 메모: 작업 파일 `spatial_rctd.1.2.R`을 배포 번호 1.1로 올립니다.

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
- **내용(국문):** 10x Visium과 Visium HD 공간 전사체 데이터를 Seurat으로 분석하는 실행 환경입니다. 정규화, 군집, 공간 가변 유전자, 슬라이스 통합(Harmony), 세포 유형 분해(RCTD), 조건 간 비교(DESeq2)에 필요한 도구가 들어 있습니다. Visium HD는 bin 수가 많아 슬라이드와 bin 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for analysing 10x Visium and Visium HD spatial transcriptomics data with Seurat. It holds the tools for normalisation, clustering, spatially variable genes, slice integration (Harmony), cell-type deconvolution (RCTD) and condition comparison (DESeq2). Visium HD has many bins, so it needs memory matched to the slides and the bin size.

### 내용(국문)
Visium spot 하나에는 세포가 여러 개 들어 있습니다. RCTD(spacexr)로 단일세포 참조의 세포 유형별 발현 profile을 써서 spot마다 세포 유형이 섞인 비율(weight)을 추정합니다.
- 참조의 raw count로 세포 유형별 평균 profile을 만들고, 세포 수가 min_cells_per_type보다 적은 유형은 뺍니다.
- spot마다 모든 세포 유형의 weight(합 1)를 계산합니다(doublet_mode=full). spot에 세포가 여러 종류 섞일 수 있는 Visium에 맞는 방식입니다.
- spot별 weight 표, 슬라이스별 평균 비율, 가장 큰 세포 유형(dominant) 그림, 상위 세포 유형의 조직 위 weight 그림을 만듭니다.
- 슬라이스×세포 유형 평균 비율 표와 heatmap, 누적 막대그림을 만듭니다.

### 내용(영문)
A Visium spot holds several cells. RCTD (spacexr) uses the per-cell-type expression profiles of a single-cell reference to estimate the mixture (weights) of cell types in each spot.
- Mean profiles per cell type are built from the raw counts of the reference; types with fewer cells than min_cells_per_type are left out.
- Each spot gets weights for all cell types, summing to 1 (doublet_mode=full), which suits Visium spots holding several kinds of cells.
- A weight table per spot, mean proportions per slice, a dominant cell-type map and tissue weight maps of the top cell types are made.
- A slice-by-cell-type table of mean proportions, a heatmap and a stacked bar plot are made.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/spatial_cluster | 군집 결과 폴더. 슬라이스마다 <slice>/<slice>_clustered.rds(raw count assay Spatial이 있는 Seurat 객체) | Cluster output folder: per slice <slice>/<slice>_clustered.rds (Seurat object with the raw-count assay Spatial) |
| Input | Optional | File | reference_rds | /ref/brain_reference.rds | 단일세포 참조 자료(Seurat .rds). raw count와 세포 유형 열이 있어야 함. 비우면 이 모듈은 건너뜀(skipped.txt) | Single-cell reference (Seurat .rds) with raw counts and a cell-type column. Empty: the module is skipped (skipped.txt) |
| Option | Optional | String | reference_label_col | celltype | 참조 자료에서 세포 유형이 든 메타데이터 열 이름. 참조를 주면 반드시 입력. 비었거나 참조에 없는 열이면 세포 유형 후보 열을 보여 주고 멈춤 | Metadata column of the reference holding the cell types; required when a reference is given. When empty or not in the reference, the run stops and lists the cell-type column candidates |
| Output | Required | Directory | output_dir | /data/spatial_rctd | 결과 폴더. 슬라이스마다 <slice>_rctd.rds, <slice>_rctd_object.rds, <slice>_rctd_weights.csv, <slice>_rctd_mean_abundance.csv, plots/, 그리고 summary/(표, heatmap, 누적 막대) | Output folder: per slice <slice>_rctd.rds, <slice>_rctd_object.rds, <slice>_rctd_weights.csv, <slice>_rctd_mean_abundance.csv and plots/, and summary/ (tables, heatmap, stacked bars) |
| Option | Optional | String | spatial_assay | Spatial | 슬라이스 객체에서 raw count가 든 assay | Assay of the slice objects holding raw counts |
| Option | Optional | String | reference_assay | RNA | 참조 객체에서 raw count가 든 assay | Assay of the reference holding raw counts |
| Option | Optional | Integer | min_shared_features | 200 | 참조와 슬라이스가 공유해야 하는 최소 유전자 수 | Minimum genes shared by the reference and a slice |
| Option | Optional | Integer | min_cells_per_type | 25 | 세포 수가 이보다 적은 참조 세포 유형은 뺌 | Reference cell types with fewer cells are left out |
| Option | Optional | Integer | plot_topn | 12 | 조직 위 weight 그림에 넣는 상위 세포 유형 수 | Top cell types drawn as tissue weight maps |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 참조 자료(reference_rds)를 주지 않으면 이 모듈은 건너뛰고(결과 폴더에 skipped.txt) 정상 종료하므로, 참조가 없어도 파이프라인은 끝까지 실행됩니다. 참조를 주면 세포 유형 열 이름(reference_label_col)도 넣어 주세요. 열 이름을 모르면 비워 두고 한 번 실행하면, 분석 전에 멈추고 오류 로그에 세포 유형 후보 열과 그 값들을 보여 줍니다. 확인한 열 이름을 넣어 다시 실행하세요. | Without a reference (reference_rds) the module is skipped (skipped.txt in the output folder) and ends without error, so the pipeline still runs to the end. With a reference, also give its cell-type column (reference_label_col). If the column name is unknown, leave it empty and run once: the run stops before the analysis and the error log lists the cell-type column candidates with their values. Run again with the chosen column. |
| RCTD는 raw count가 필요합니다. 참조의 정규화 값(SCT, log)만 있으면 실행되지 않습니다. | RCTD needs raw counts; a reference with only normalised values (SCT, log) cannot be used. |
| weight는 참조에 있는 세포 유형 사이의 비율입니다. 참조에 없는 조직은 가장 비슷한 유형의 weight로 나타납니다. 조직 전체를 담은 참조를 권장합니다. | Weights are proportions among the reference cell types; tissue missing from the reference shows up as the most similar types, so a reference covering the whole tissue is recommended. |
| 코어 수에 따라 메모리가 늘어납니다(작업자마다 자료를 복사). 병렬 작업자 수는 할당한 코어 수를 따르므로, 메모리가 모자라면 코어 수를 낮춰 주세요. | Memory grows with the cores, since each worker copies the data; the number of workers follows the allocated cores, so lower the cores if memory runs short. |
| UMI 수가 매우 적은 spot(RCTD 기본 100 미만)은 계산에서 빠져 dominant 그림에서 NA로 나옵니다. | Spots with very few UMIs (below the RCTD default of 100) are not scored and appear as NA in the dominant map. |

### 분석 개념 이미지
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/spatial_rctd_concept.png`

- 레전드(국문): **그림. RCTD로 spot의 세포 유형 비율 추정.** (A) 단일세포 참조의 raw count로 세포 유형별 평균 발현 profile을 만듭니다. 세포 수가 min_cells_per_type 이상인 유형만 씁니다. (B) spot 하나는 여러 세포의 섞임이며, RCTD full 모드는 spot마다 모든 세포 유형의 weight(합 1)를 추정합니다. 값과 조직 모양은 모식적인 값입니다.
- 레전드(영문): **Figure. Estimating cell-type proportions of spots with RCTD.** (A) Mean expression profiles per cell type are built from the raw counts of the single-cell reference, using types with at least min_cells_per_type cells. (B) A spot is a mixture of several cells; RCTD full mode estimates weights of all cell types per spot, summing to 1. Values and tissue shapes are schematic.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript spatial_rctd.1.1.R \
  input_dir=/data/spatial_cluster \
  reference_rds=/ref/brain_reference.rds \
  reference_label_col=celltype \
  output_dir=/data/spatial_rctd \
  spatial_assay=Spatial \
  reference_assay=RNA \
  min_shared_features=200 \
  min_cells_per_type=25 \
  plot_topn=12 \
  seed=1234
```

### 주요 결과 이미지
등록 메모: SIF 테스트 결과 그림을 넣을 자리입니다(Codespace 재실행 중).

---

## 8. check_reference

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

- **태그(키워드):** spatial transcriptomics, Visium, Visium HD, Seurat
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
그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/figures/module_concepts/check_reference_concept.png`

- 레전드(국문): **그림. 단일세포 참조 자료의 세포 유형 열 확인.** (A) 열마다 형식과 범주 수, 가장 많은 값을 로그에 적고, 범주가 2~100개인 범주형 열에 [CELLTYPE?]를 붙입니다. 숫자형 열과 범주가 너무 많은 열은 후보에서 뺍니다(SKIP). (B) reference_columns.tsv에서 후보를 보고 세포 유형 열을 골라 spatial_labelTransfer, spatial_rctd, spatial_hd_rctd의 reference_label_col에 넣습니다. 값은 모식적인 값입니다.
- 레전드(영문): **Figure. Checking the cell-type column of a single-cell reference.** (A) For each column the log lists its type, number of categories and most frequent values; categorical columns with 2-100 categories are tagged [CELLTYPE?], while numeric columns and columns with too many categories are skipped. (B) The cell-type column is chosen from the candidates in reference_columns.tsv and given as reference_label_col to spatial_labelTransfer, spatial_rctd and spatial_hd_rctd. Values are schematic.
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

