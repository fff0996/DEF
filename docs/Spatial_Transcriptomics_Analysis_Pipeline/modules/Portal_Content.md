# Spatial transcriptomics 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고입니다. 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다. 예시 경로가 그대로 넘어가면 스크립트가 "not found"로 멈춥니다.
- 선택(Optional) 입력은 빈 값이 "사용 안 함"입니다.
- 스크립트 사용 예제는 등록하는 인자를 모두 적었고, 기본값이 있는 옵션은 기본값으로 적었습니다. 예시 값은 마우스 뇌 Visium·Visium HD 기준입니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 모든 모듈이 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)입니다.
- 모든 모듈은 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지우고 시작합니다(spatial_merge는 지우지 않고 덮어씁니다).
- 카테고리는 기능(분석 단계) 기준의 대분류·중분류로 정했습니다(`docs/CLOSHA_Portal_Guide_v1.md` 5.2). 공간 전사체 군집은 기존 목록에 맞는 중분류가 없어 Omics / Clustering(신규)을 제안합니다. 단일세포 RNA-seq 군집 모듈도 담을 수 있는 일반 이름입니다.
- 버전은 배포 번호입니다. CLOSHA 2.0에서 받은 스크립트 중 고친 것만 2.0 번호 + 1(spatial_merge 1.1)이고, 고치지 않은 것은 그대로(spatial_prep, spatial_cluster, spatial_svf 1.0)입니다. 3.0에서 새로 만든 모듈은 1.0입니다.
- 등록 메모: spatial_labelTransfer, spatial_rctd, check_reference는 단일세포 참조 자료로 실행을 확인한 뒤 추가합니다.
- 등록 메모: 모듈 개념도는 아직 만들지 않았습니다. `docs/CLOSHA_Figure_Guide_v1.md`에 따라 만든 뒤 각 모듈의 "분석 개념 이미지" 절에 넣습니다.

---

## 1. spatial_prep

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_prep | spatial_prep |
| 서브 타이틀 | 공간 전사체 불러오기와 정규화 | Loading and normalisation of spatial data |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Expression_Quantification | Expression_Quantification |
| 태그 | spatial transcriptomics, Visium, Seurat, SCTransform, QC | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_prep.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 16GB(슬라이스 1장 기준) | 4 cores, 16 GB of memory (per slice) |

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
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
Rscript spatial_prep.1.0.R \
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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_prep_result_1.png`

- 레전드(국문): **슬라이스의 spot별 UMI 수.** 왼쪽은 spot별 UMI 수(nCount_Spatial) 분포(violin, 점은 spot)이고, 오른쪽은 같은 값을 조직 이미지 위에 칠한 것입니다(파랑이 적고 빨강이 많음). 조직 밖이나 손상된 부분에 UMI가 매우 낮은 spot이 몰려 있으면 min_counts로 거릅니다. 예시 데이터(spot 2,695개)에서는 UMI 수가 대부분 1만~4만이고 중앙값이 약 2만 5천이었으며, 조직 가장자리와 일부 영역에서 낮았습니다. 기본값(min_counts=0)으로 거르지 않았습니다.
- 레전드(영문): **UMI counts per spot of a slice.** Left: distribution of UMI counts per spot (nCount_Spatial; violin, points are spots); right: the same values on the tissue image (blue low, red high). If spots with very low counts gather outside the tissue or in damaged areas, filter them with min_counts. In the example data (2,695 spots) most spots had 10,000-40,000 UMIs with a median of about 25,000, lower at the tissue edge and in some regions; the default (min_counts=0) kept all spots.

---

## 2. spatial_cluster

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_cluster | spatial_cluster |
| 서브 타이틀 | 슬라이스별 군집과 마커 | Clustering and markers per slice |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Clustering (신규) | Clustering (new) |
| 태그 | spatial transcriptomics, Visium, clustering, UMAP, marker genes | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_cluster.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 16GB | 4 cores, 16 GB of memory |

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
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
Rscript spatial_cluster.1.0.R \
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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_cluster_result_1.png`

- 레전드(국문): **슬라이스 안의 군집.** 왼쪽은 UMAP 위 군집, 오른쪽은 같은 군집을 조직 위에 칠한 것이며 숫자는 군집 번호입니다. 발현이 비슷한 spot은 UMAP에서 가깝고, 조직에서는 해부학적 영역으로 모입니다. 군집 번호는 슬라이스마다 따로 매겨집니다. 예시 데이터에서는 군집 17개(resolution 0.8)가 나왔고, 대뇌 피질이 표면을 따라 층 모양 띠로, 왼쪽 후각망울이 별도 군집(4, 11)으로 나뉘었습니다.
- 레전드(영문): **Clusters within a slice.** Left: clusters on the UMAP; right: the same clusters on the tissue, labelled by number. Spots with similar expression lie close on the UMAP and gather into anatomical regions on the tissue. Cluster numbers are per slice. In the example data 17 clusters (resolution 0.8) appeared: the cerebral cortex forms layered bands along the surface, and the olfactory bulb on the left forms separate clusters (4, 11).

**결과 2. 군집 마커 dot plot**
- 결과 파일: `<slice>/plots/<slice>_marker_dotplot.png` (heatmap `<slice>_marker_heatmap.png`, 표 `<slice>_cluster_markers.csv`도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_cluster_result_2.png`

- 레전드(국문): **군집별 상위 마커 유전자.** 세로가 군집(Cluster), 가로가 마커 유전자(Marker gene)이며, 점 크기는 발현하는 spot 비율(Percent Expressed), 색 진하기는 평균 발현(Average Expression, 척도화)입니다. 대각선으로 진한 점이 모이면 군집마다 고유한 마커가 있다는 뜻입니다. 예시 데이터에서는 군집마다 marker_topn=5개의 마커가 대각선 모양으로 구분되었습니다(예: 군집 4 Fabp7·Calb2, 군집 15 Ttr·Enpp2). 이 그림은 스크립트가 투명 배경으로 저장해, 포탈용으로 흰 배경을 깔았습니다.
- 레전드(영문): **Top marker genes per cluster.** Rows are clusters (Cluster), columns marker genes (Marker gene); dot size is the fraction of expressing spots (Percent Expressed) and colour the scaled mean expression (Average Expression). Dark dots along a diagonal mean each cluster has its own markers. In the example data the marker_topn=5 markers of each cluster form a diagonal (for example cluster 4 Fabp7 and Calb2, cluster 15 Ttr and Enpp2). The script saves this plot with a transparent background, so a white background was added for the portal.

---

## 3. spatial_svf

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_svf | spatial_svf |
| 서브 타이틀 | 공간 가변 유전자 | Spatially variable genes |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Expression_Quantification | Expression_Quantification |
| 태그 | spatial transcriptomics, Visium, spatially variable genes, Moran's I | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_svf.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 16GB | 4 cores, 16 GB of memory |

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
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
Rscript spatial_svf.1.0.R \
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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_svf_result_1.png`

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
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Clustering (신규) | Clustering (new) |
| 태그 | spatial transcriptomics, Visium, integration, Harmony, multi-slice | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/spatial_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_merge.1.1.R | |
| Processor Core (제안) | 4코어, 메모리 32GB(슬라이스 4장), 64GB(8장 이상) | 4 cores, 32 GB of memory (4 slices), 64 GB (8 or more) |

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
| 슬라이스 수에 따라 메모리가 늘어납니다. 4장은 32GB, 8장 이상은 64GB를 권장합니다. | Memory grows with the number of slices: 32 GB for 4 slices and 64 GB for 8 or more are recommended. |
| 이 모듈은 실행 전에 output_dir를 비우지 않고 같은 이름의 파일을 덮어씁니다. 다른 설정으로 다시 실행할 때는 새 output_dir를 쓰는 것을 권장합니다. | This module does not clear output_dir before running and overwrites files of the same name; use a new output_dir when rerunning with other settings. |

### 분석 개념 이미지
등록 메모: 개념도 작성 예정입니다.

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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_merge_result_1.png`

- 레전드(국문): **모든 슬라이스에서 같은 기준으로 매긴 군집.** 슬라이스마다 조직 이미지 위에 통합 군집을 칠한 것으로, 같은 번호는 모든 슬라이스에서 같은 영역을 뜻합니다. 같은 부위의 슬라이스끼리 같은 영역에 같은 군집이 나와야 정상입니다. 예시 데이터(Harmony 보정, 군집 16개)에서는 section 1과 2의 같은 부위(anterior끼리, posterior끼리)에서 군집 배치가 같았고, 소뇌 과립층(군집 11)은 posterior 슬라이스에만 나왔습니다. spot 600개만 뽑아 써서 점이 듬성듬성합니다.
- 레전드(영문): **Clusters assigned on a common basis in every slice.** The joint clusters are painted on each slice's tissue image; the same number means the same region in every slice. Slices of the same part should show the same clusters in the same regions. In the example data (Harmony, 16 clusters) sections 1 and 2 of the same part (anterior with anterior, posterior with posterior) had the same cluster layout, and the cerebellar granular layer (cluster 11) appeared in the posterior slices only. Only 600 spots per slice were used, so the points are sparse.

**결과 2. 통합 UMAP**
- 결과 파일: `merged/plots/merged_umap.png` (군집별 `merged_umap_by_cluster.png`도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_merge_result_2.png`

- 레전드(국문): **통합 군집(왼쪽, ident)과 슬라이스(오른쪽, orig.ident)로 칠한 UMAP.** 슬라이스 보정이 잘 되면 오른쪽에서 슬라이스 색이 군집 안에 고루 섞이고, 한 슬라이스에만 있는 영역만 따로 모입니다. 예시 데이터에서는 같은 부위의 두 section이 고루 섞였고, anterior와 posterior는 각자에만 있는 영역(예: 후각망울, 소뇌)에서 나뉘었습니다.
- 레전드(영문): **UMAP coloured by joint cluster (left, ident) and slice (right, orig.ident).** With good slice correction, slice colours mix within clusters on the right, and only regions present in one slice stay apart. In the example data the two sections of each part mixed evenly, while anterior and posterior separated at regions present in only one of them (for example the olfactory bulb and cerebellum).

**결과 3. 슬라이스별 군집 조성**
- 결과 파일: `merged/plots/merged_cluster_by_slice_stackedbar.png` (heatmap `merged_cluster_by_slice_heatmap.png`, 표 `merged_cluster_by_slice.csv`도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_merge_result_3.png`

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
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Differential_Analysis | Differential_Analysis |
| 태그 | spatial transcriptomics, Visium, Visium HD, differential expression, pseudobulk, DESeq2 | |
| 레퍼런스 URL | https://bioconductor.org/packages/DESeq2/ | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_condition_de.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 16GB(Visium), 16~32GB(Visium HD 16µm), 32~64GB(8µm) | 4 cores, 16 GB of memory (Visium), 16-32 GB (Visium HD 16 um), 32-64 GB (8 um) |

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

등록 메모: 작업 파일 `spatial_condition_de.1.1.R`(Visium HD 입력 추가)을 배포 번호 1.0으로 올립니다.

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
| SliceID | 필수 | 슬라이스 이름(spatial_prep 또는 spatial_hd_prep에 준 슬라이스 폴더 이름) | ctrl_1 |
| Condition | 필수 | 조건 이름 | control |
| Patient | 선택 | 짝 설계의 개체 ID(같은 개체가 각 조건에 있을 때) | P1 |

```
SliceID,Condition,Patient
ctrl_1,control,P1
ctrl_2,control,P2
trt_1,treated,P1
trt_2,treated,P2
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
등록 메모: 개념도 작성 예정입니다.

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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_1.png`

- 레전드(국문): **군집마다 조건 간 유전자 발현 차이.** 패널 하나가 군집 하나이고, x축은 log2 fold change(기준 조건 대비), y축은 -log10 adjusted p입니다. 빨강은 기준보다 높은(up), 파랑은 낮은(down) 유의 유전자이며, 점선은 |log2FC| = lfc_cutoff와 padj_cutoff입니다. 패널마다 상위 유전자 이름을 붙입니다. 예시 데이터(section2 vs section1)에서는 슬라이스가 조건마다 2장인 군집 7개(pseudobulk DESeq2)에서 유의 유전자가 0개였습니다. 한 조건에 슬라이스가 1장뿐인 군집(spot 단위 검정, 탐색용)에서만 미토콘드리아(mt-Nd5, mt-Co1)와 리보솜(Rps28, Rps29) 유전자가 유의하게 나와, 절편 간 기술적 차이를 보여 줍니다.
- 레전드(영문): **Expression differences between conditions per cluster.** Each panel is a cluster; the x axis is log2 fold change (against the reference condition) and the y axis -log10 adjusted p. Red marks significant genes higher than the reference (up), blue lower (down); dashed lines are |log2FC| = lfc_cutoff and padj_cutoff, and top genes are labelled. In the example data (section2 vs section1) the seven clusters with two slices per condition (pseudobulk DESeq2) had no significant genes. Only clusters with one slice in a condition (spot-level test, exploratory) showed significant mitochondrial (mt-Nd5, mt-Co1) and ribosomal (Rps28, Rps29) genes, a technical difference between sections.

**결과 2. 조건별 군집 비율**
- 결과 파일: `03_plots/composition_by_condition.png` (누적 막대 `composition_stacked.png`, 표 `01_composition/`도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_2.png`

- 레전드(국문): **군집마다 조건별 spot 비율.** 패널 하나가 군집 하나이고, 점은 슬라이스, 가로 막대는 조건 평균입니다(y축 Fraction of spots). 조건 간 비율 검정 결과는 `01_composition/composition_test.tsv`에 있으며, 조건당 슬라이스가 적으면 탐색용입니다. 예시 데이터에서는 같은 조건 안에서도 anterior와 posterior의 비율이 크게 달라 점이 넓게 퍼졌고, 조건 평균의 차이는 그보다 작았습니다.
- 레전드(영문): **Fraction of spots per cluster by condition.** Each panel is a cluster; points are slices and the bar the condition mean (y axis Fraction of spots). The tests between conditions are in `01_composition/composition_test.tsv` and are exploratory with few slices. In the example data anterior and posterior differ widely even within a condition, so the points spread far, while the difference of the condition means is smaller.

**결과 3. 군집별 유의 유전자 수**
- 결과 파일: `03_plots/de_counts.png` (PDF도 있음), 표 `04_summary/de_summary.tsv`

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_3.png`

- 레전드(국문): **군집마다 유의하게 높아진(up, 빨강, 0 위)·낮아진(down, 파랑, 0 아래) 유전자 수.** 어느 군집(영역)에서 조건 차이가 큰지 한눈에 봅니다. 검정 방법(pseudobulk 또는 spot 단위)과 상태는 de_summary.tsv에 있습니다. 예시 데이터에서는 spot 단위 검정을 한 군집 2(up 14, down 12), 8(up 3), 13(up 1), 14(up 10)에만 막대가 있고, pseudobulk 군집은 모두 0이었습니다.
- 레전드(영문): **Number of significantly increased (up, red, above 0) and decreased (down, blue, below 0) genes per cluster.** It shows which clusters (regions) differ most; the test method (pseudobulk or spot-level) and status are in de_summary.tsv. In the example data only the spot-level clusters 2 (14 up, 12 down), 8 (3 up), 13 (1 up) and 14 (10 up) have bars; all pseudobulk clusters have 0.

**결과 4. 상위 유전자 log2FC heatmap**
- 결과 파일: `03_plots/lfc_heatmap_<test>_vs_<reference>.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_4.png`

- 레전드(국문): **군집별 상위 유전자의 log2 fold change.** 세로가 유전자, 가로가 군집이며, 색은 log2FC(빨강 증가, 파랑 감소, ±3에서 자름), 검은 점은 그 군집에서 유의함을 뜻합니다. 한 유전자가 여러 군집에서 같은 방향이면 조직 전체의 변화, 한 군집에만 있으면 영역 특이 변화입니다. 예시 데이터에서는 미토콘드리아 유전자(mt-Co1, mt-Nd 계열)가 군집 14에서 함께 높아졌고, 대부분 군집에서 색이 옅어 차이가 작았습니다. 이 그림은 스크립트가 투명 배경으로 저장해, 포탈용으로 흰 배경을 깔았습니다.
- 레전드(영문): **log2 fold change of top genes per cluster.** Rows are genes and columns clusters; colour is log2FC (red up, blue down, clipped at ±3), and black dots mark significance in that cluster. A gene changing the same way in many clusters points to a tissue-wide change, one in a single cluster to a regional change. In the example data mitochondrial genes (mt-Co1, mt-Nd) rose together in cluster 14, and most cells are pale, meaning small differences. The script saves this plot with a transparent background, so a white background was added for the portal.

**결과 5. 조직 위 유전자 분포**
- 결과 파일: `03_plots/spatial_<gene>.png` (PDF도 있음, spatial_genes개 유전자)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_5.png`

- 레전드(국문): **유의 유전자의 슬라이스별 조직 위 발현.** 기준 조건부터 슬라이스를 나란히 놓고, 모든 슬라이스에 같은 색 범위(파랑 낮음, 빨강 높음)를 써서 직접 비교할 수 있게 합니다. 예시 데이터의 Rps28은 네 슬라이스에서 비슷한 수준으로 고르게 퍼져, spot 단위로 나온 유의 차이가 특정 영역의 변화가 아님을 보여 줍니다. spot 600개만 써서 점이 듬성듬성합니다.
- 레전드(영문): **Tissue expression of significant genes per slice.** Slices are placed side by side from the reference condition with one colour range for all (blue low, red high), so they can be compared directly. In the example data Rps28 spreads evenly at similar levels in all four slices, showing that its spot-level significance is not a regional change. Only 600 spots per slice were used, so the points are sparse.

**결과 6. Visium HD 입력의 volcano**
- 결과 파일: `03_plots/volcano_<test>_vs_<reference>.png` (Visium HD 입력)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_condition_de_result_6.png`

- 레전드(국문): **Visium HD 결과(spatial_hd_cluster 출력)를 넣은 조건 비교.** 읽는 법은 결과 1과 같습니다. HD 입력에서는 슬라이드를 하나씩 읽어 pseudobulk를 합칩니다. 예시 데이터(right vs left, 조건마다 슬라이드 2장)에서는 군집 12개를 pseudobulk DESeq2로 검정했고, 군집 2(Gad1, Sst 등 감소)처럼 유의 유전자가 많이 나왔습니다. 왼쪽과 오른쪽은 서로 다른 뇌 영역을 담고 있어 해부학적 차이가 나오는 것이 정상이며, 실제 조건 비교가 아닙니다.
- 레전드(영문): **Condition comparison with Visium HD input (spatial_hd_cluster output).** Read as result 1. With HD input the slides are read one at a time and summed into pseudobulk samples. In the example data (right vs left, two slides per condition) twelve clusters were tested with pseudobulk DESeq2, and some, such as cluster 2 (Gad1, Sst and others lower), had many significant genes. The left and right halves contain different brain regions, so anatomical differences are expected; this is not a real condition comparison.

---

## 6. spatial_hd_prep

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_prep | spatial_hd_prep |
| 서브 타이틀 | Visium HD 불러오기와 정규화 | Loading and normalisation of Visium HD |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Expression_Quantification | Expression_Quantification |
| 태그 | spatial transcriptomics, Visium HD, Seurat, sketch, QC | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_prep.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 16GB(16µm, 슬라이드당), 32~64GB(8µm, 슬라이드당) | 4 cores, 16 GB of memory (16 um, per slide), 32-64 GB (8 um, per slide) |

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
등록 메모: 개념도 작성 예정입니다.

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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_prep_result_1.png`

- 레전드(국문): **bin별 UMI 수와 검출 유전자 수.** 왼쪽 두 violin은 bin별 UMI 수(nCount_Spatial.016um)와 검출 유전자 수(nFeature_Spatial.016um) 분포이고, 오른쪽은 UMI 수를 조직 위에 칠한 것입니다. 조직 밖이나 UMI가 매우 낮은 bin이 많으면 min_counts, min_features를 올립니다. 예시 데이터에서는 bin당 UMI 중앙값이 711, 유전자 중앙값이 570이었고, 피질에서 높고 백질(뇌량)에서 낮았습니다. 분석에 쓰지 않은 4분면 바깥은 조직 이미지만 보입니다. 두 violin의 제목이 붙어 보이는 것은 그림 배치 문제로, 다음 버전에서 고칩니다.
- 레전드(영문): **UMI counts and detected genes per bin.** The two violins show UMI counts (nCount_Spatial.016um) and detected genes (nFeature_Spatial.016um) per bin; the right panel shows UMI counts on the tissue. With many bins outside the tissue or with very low counts, raise min_counts or min_features. In the example data the median bin had 711 UMIs and 570 genes, higher in the cortex and lower in the white matter (corpus callosum); outside the quadrant only the tissue image shows. The two violin titles run together, a layout issue to be fixed in the next version.

**결과 2. 슬라이드별 요약표**
- 결과 파일: `hd_prep_summary.tsv` (표를 그림으로 만들었습니다)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_prep_result_2.png`

- 레전드(국문): **슬라이드별 bin 수와 sketch.** 거르기 전·후 bin 수(Bins_raw, Bins), bin당 UMI·유전자 중앙값, sketch에 남긴 bin 수, 상태와 걸린 시간(초)입니다. 예시 데이터에서는 슬라이드 4장이 2만 2,477~2만 6,981 bin이었고, Space Ranger가 이미 조직 밖 bin을 걸러 min_counts=10으로 빠진 bin은 없었으며, 슬라이드마다 5,000 bin을 sketch로 뽑았습니다(테스트 설정, 기본값 5만).
- 레전드(영문): **Bins and sketch per slide.** Bins before and after filtering (Bins_raw, Bins), median UMIs and genes per bin, sketched bins, status and seconds. In the example data the four slides had 22,477-26,981 bins; Space Ranger had already removed bins outside the tissue, so min_counts=10 removed none, and 5,000 bins per slide were sketched (test setting; the default is 50,000).

---

## 7. spatial_hd_cluster

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | spatial_hd_cluster | spatial_hd_cluster |
| 서브 타이틀 | Visium HD 통합 군집 | Joint clustering of Visium HD slides |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Clustering (신규) | Clustering (new) |
| 태그 | spatial transcriptomics, Visium HD, clustering, Harmony, sketch, marker genes | |
| 레퍼런스 URL | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette | |
| 컨테이너 이미지 | bx_spatial.1.1 | |
| 실행 스크립트 파일 | spatial_hd_cluster.1.0.R | |
| Processor Core (제안) | 4코어, 메모리 32GB(16µm), 64~128GB(8µm) | 4 cores, 32 GB of memory (16 um), 64-128 GB (8 um) |

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
등록 메모: 개념도 작성 예정입니다.

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

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_cluster_result_1.png`

- 레전드(국문): **모든 슬라이드의 sketch bin으로 만든 통합 군집.** UMAP 위 점이 sketch bin이고 색과 숫자가 군집입니다. 이 군집이 모든 bin에 옮겨 붙습니다. 예시 데이터(sketch 2만 bin, Harmony, dims 30, resolution 0.8)에서는 군집 18개가 나왔습니다.
- 레전드(영문): **Joint clusters from the sketched bins of all slides.** Points on the UMAP are sketched bins; colours and numbers are clusters, which are then transferred to every bin. In the example data (20,000 sketched bins, Harmony, dims 30, resolution 0.8) 18 clusters appeared.

**결과 2. 모든 bin의 조직 위 군집(대표 그림)**
- 결과 파일: `<slide>/plots/<slide>_clusters_spatial.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_cluster_result_2.png`

- 레전드(국문): **슬라이드의 모든 bin에 붙인 통합 군집.** sketch에서 만든 군집을 가까운 sketch bin 10개(k_transfer)의 다수결로 모든 bin에 붙여 조직 위에 칠한 것입니다. 군집 번호는 모든 슬라이드에서 같은 뜻입니다. 예시 데이터에서는 해마의 CA 피라미드 세포층(군집 13)과 치아이랑 과립세포층(군집 17)이 가는 띠로 뚜렷이 나뉘었고, 위쪽 피질과 아래쪽 큰 영역도 서로 다른 군집으로 구분되었습니다. 16µm bin이라 세포 하나 크기의 경계까지 보입니다.
- 레전드(영문): **Joint clusters on every bin of a slide.** Clusters made on the sketch are transferred to every bin by majority vote of its 10 nearest sketched bins (k_transfer) and painted on the tissue; cluster numbers mean the same in every slide. In the example data the hippocampal CA pyramidal layer (cluster 13) and the dentate gyrus granule layer (cluster 17) separate as thin bands, and the cortex above and the large region below form distinct clusters. With 16 um bins, borders close to single-cell size are visible.

**결과 3. 유전자의 조직 위 발현**
- 결과 파일: `<slide>/plots/<slide>_feature_<gene>.png` (PDF도 있음, features를 줄 때)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_cluster_result_3.png`

- 레전드(국문): **features로 지정한 유전자의 bin별 발현.** 색은 log 정규화 발현입니다(파랑 낮음, 빨강 높음). 군집의 정체를 알려진 표지 유전자로 확인하는 데 씁니다. 예시 데이터에서 치아이랑 과립세포 표지 Prox1은 군집 17과 같은 띠에서만 높게 나와, 군집이 해부학적 구조와 맞음을 보여 줍니다.
- 레전드(영문): **Bin expression of genes given in features.** Colour is log-normalised expression (blue low, red high); it checks cluster identity with known markers. In the example data the dentate gyrus granule cell marker Prox1 is high only in the band of cluster 17, showing that the clusters match the anatomy.

**결과 4. 슬라이드로 칠한 UMAP**
- 결과 파일: `joint/plots/umap_slides.png` (PDF도 있음)

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_cluster_result_4.png`

- 레전드(국문): **통합 sketch UMAP을 슬라이드로 칠한 그림.** 같은 영역이 여러 슬라이드에 있으면 색이 섞여야 하며, 한 슬라이드 색만 따로 모이면 그 슬라이드에만 있는 영역이거나 보정이 부족한 것입니다. 예시 데이터에서는 왼쪽 두 슬라이드끼리, 오른쪽 두 슬라이드끼리 주로 섞이고 왼쪽과 오른쪽은 따로 모였습니다. 같은 절편의 왼쪽과 오른쪽이 서로 다른 뇌 영역을 담고 있기 때문입니다.
- 레전드(영문): **The joint sketch UMAP coloured by slide.** When a region is present in several slides their colours should mix; a slide colour gathering alone means a region present only there, or too little correction. In the example data the two left slides mixed mostly with each other, as did the two right slides, while left and right gathered apart, because the left and right halves of the section contain different brain regions.

**결과 5. 슬라이드별 군집 조성**
- 결과 파일: `joint/plots/cluster_by_slide.png` (PDF도 있음), 표 `joint/cluster_by_slide.tsv`

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/figures/results/spatial_hd_cluster_result_5.png`

- 레전드(국문): **슬라이드마다 모든 bin에서 군집이 차지하는 비율(Fraction of bins).** 같은 부위의 슬라이드는 비슷해야 하며, 조건 비교 전에 조성 차이를 확인합니다. 예시 데이터에서는 4분면마다 포함한 영역이 달라 조성이 달랐고, 해마 군집(13, 17)은 오른쪽 위 슬라이드에서 가장 많았습니다.
- 레전드(영문): **Fraction of all bins per cluster in each slide (Fraction of bins).** Slides of the same part should look alike; check composition differences before comparing conditions. In the example data the quadrants contain different regions and their compositions differ, and the hippocampal clusters (13, 17) are most frequent in the top-right slide.
