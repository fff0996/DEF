# Spatial transcriptomics 파이프라인 포탈 등록 콘텐츠

KOBIC 포탈의 공간 전사체 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. CLOSHA에는 두 파이프라인으로 등록하며, 포탈에서 페이지가 따로이므로 파이프라인마다 등록 항목부터 주요 사항까지 완결되게 적었습니다(파트 A: Visium, 파트 B: Visium HD). spatial_condition_de는 두 파이프라인이 같이 쓰는 모듈입니다. 모듈별 입력·옵션·결과는 `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/Registration.md`에 있습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

등록 메모: Reference는 파이프라인을 구성할 때 따른 Seurat 공식 안내입니다. Visium은 SCTransform·군집·공간 가변 유전자, Visium HD는 bin 불러오기·sketch 군집 흐름을 그대로 따랐습니다.

---

# 파트 A. Spatial_Transcriptomics_Visium_Pipeline

## A0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `Spatial_Transcriptomics_Visium_Pipeline` |
| 구성 모듈 | spatial_prep, spatial_cluster, spatial_svf, spatial_merge, spatial_condition_de |
| Version | 1.1 (CLOSHA 2.0 파이프라인 버전 + 1. 등록 메모: 2.0 파이프라인 버전이 1.0이라는 전제이며, 다르면 그 번호 + 1로 고칩니다) |
| Reference | https://satijalab.org/seurat/articles/spatial_vignette |
| Keyword(태그) | spatial transcriptomics, Visium, clustering, spatially variable genes, multi-slice integration, differential expression |
| 대분류 / 중분류 | 등록 메모: 포탈 파이프라인 목록에서 가장 가까운 것을 고릅니다(후보: Transcriptomics / Spatial transcriptomics). |
| 대표 이미지 | 등록 메모: 결과 그림을 본 뒤 고릅니다(후보: spatial_merge 조직 위 통합 군집). |

## A1. 파이프라인 소개 / Introduction

### 국문
Visium 공간 전사체 파이프라인은 10x Genomics Visium으로 얻은 조직 절편의 spot별 유전자 발현을 분석하여, 조직 안의 영역 구성과 공간적인 발현 패턴, 조건에 따른 변화를 확인하는 분석 도구입니다. 슬라이스별 Space Ranger 결과와 슬라이스 정보를 입력하면, Seurat으로 spot을 거르고 SCTransform으로 정규화한 뒤, 슬라이스별 군집과 마커, 공간 가변 유전자를 찾고, 여러 슬라이스를 합쳐(Harmony 선택) 같은 기준의 군집을 만들고, 조건 사이에서 군집 조성과 군집별 발현을 pseudobulk DESeq2로 비교합니다.

### English
The Visium spatial transcriptomics pipeline analyses per-spot gene expression of tissue sections from 10x Genomics Visium to reveal how the tissue is organised into regions, which genes follow spatial patterns, and what changes between conditions. From the Space Ranger output of each slice and a slice sheet, it filters spots and normalises them with SCTransform in Seurat, finds clusters, markers and spatially variable genes per slice, merges the slices (optionally with Harmony) into common clusters, and compares cluster composition and per-cluster expression between conditions with pseudobulk DESeq2.

## A2. 분석 목표 / Analysis goals

### 국문
**Visium 공간 전사체 분석으로 확인할 수 있는 네 가지 분석 목표**

**01 조직은 어떤 발현 영역으로 나뉘는가**
spot을 발현이 비슷한 군집으로 나누고 조직 위에 그려, 피질 층이나 해마처럼 해부학적 영역과 그 경계를 확인합니다.

**02 각 영역을 특징짓는 유전자는 무엇인가**
군집마다 다른 군집보다 높게 발현하는 마커 유전자를 찾아 영역의 정체를 해석합니다.

**03 어떤 유전자가 공간적으로 몰려 발현하는가**
군집과 상관없이 조직의 특정 위치에 몰려 발현하는 유전자(공간 가변 유전자)를 Moran's I로 찾습니다.

**04 조건에 따라 영역 구성과 영역 안 발현이 어떻게 달라지는가**
여러 슬라이스를 같은 기준으로 군집한 뒤, 조건 사이에서 군집 비율과 군집별 유전자 발현을 비교합니다. 조건마다 슬라이스가 2장 이상이면 통계 검정을 합니다.

### English
**Four questions Visium spatial transcriptomics analysis can answer**

**01 Which expression regions make up the tissue?**
Spots are clustered by similar expression and drawn on the tissue, revealing anatomical regions such as cortical layers and the hippocampus and their borders.

**02 Which genes characterise each region?**
Marker genes expressed more highly in each cluster than in the others are found to interpret the identity of the regions.

**03 Which genes are expressed in spatial patterns?**
Genes concentrated in particular places of the tissue, regardless of clusters (spatially variable genes), are found with Moran's I.

**04 How do region composition and expression within regions change between conditions?**
After all slices are clustered on a common basis, cluster proportions and per-cluster gene expression are compared between conditions, with statistical testing when each condition has two or more slices.

## A3. 분석 흐름 / Analysis workflow

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/pipeline_visium.png` (원본 `pipeline_visium.svg`)

### 대체 텍스트 (alt)
- 국문: Visium 공간 전사체 파이프라인 흐름도. 슬라이스별 불러오기·정규화(spatial_prep), 군집(spatial_cluster) 뒤 공간 가변 유전자(spatial_svf)와 슬라이스 통합 군집(spatial_merge)으로 갈라지고, 통합 군집이 조건 간 비교(spatial_condition_de)로 이어짐.
- English: Visium spatial transcriptomics workflow: per-slice loading and normalisation (spatial_prep) and clustering (spatial_cluster), then spatially variable genes (spatial_svf) and joint clustering of slices (spatial_merge), followed by condition comparison (spatial_condition_de).

## A4. 분석 개념 / Analysis concept

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 설명)
**그림. 공간 전사체 분석의 원리.** (A) 조직 절편 위의 격자에서 위치마다 유전자 발현을 셉니다. Visium은 지름 55µm spot(spot마다 세포 1~10개)이고, Visium HD는 2µm 사각형을 8µm 또는 16µm bin으로 묶어 세포 크기에 가까운 해상도로 봅니다. 이 파이프라인은 Visium spot을 분석합니다. (B) 발현이 비슷한 spot을 군집으로 묶어 조직 위에 칠하면 층 구조나 핵 같은 조직 영역이 드러나고, UMAP에서는 군집이 서로 떨어진 점 무리로 보입니다. (C) 조건 비교는 같은 군집(같은 영역) 안에서 합니다. 슬라이스마다 그 군집 spot의 count를 합친 pseudobulk를 만들고, 슬라이스를 반복으로 삼아 DESeq2로 조건 간 차이를 검정합니다. 조건마다 슬라이스가 한 장뿐이면 spot 단위 검정만 할 수 있으며 탐색용입니다. 조직 모양, 군집, count 값은 모식적인 값입니다.

### English (figure legend)
**Figure. Principle of spatial transcriptomics analysis.** (A) Gene expression is counted at each position of a grid over the tissue section: Visium uses 55 um spots (1-10 cells each), and Visium HD groups 2 um squares into 8 or 16 um bins, close to cellular resolution. This pipeline analyses Visium spots. (B) Spots with similar expression are grouped into clusters; painted on the tissue they reveal regions such as layers and nuclei, and in the UMAP they form separate groups of points. (C) Conditions are compared within one cluster (one region). For each slice the counts of that cluster's spots are summed into a pseudobulk sample, and DESeq2 tests the condition with slices as replicates. With one slice per condition only a spot-level test is possible, which is exploratory. Tissue shape, clusters and counts are schematic.

### 대체 텍스트 (alt)
- 국문: 공간 전사체 개념도. 조직 위 Visium spot과 Visium HD bin 격자, 조직 영역을 나타내는 군집과 UMAP, 슬라이스별 pseudobulk count를 DESeq2로 비교하는 과정을 보여 줌.
- English: Concept of spatial transcriptomics: Visium spots and Visium HD bins on a tissue, clusters as tissue regions with a UMAP, and slice-level pseudobulk counts compared with DESeq2.

### 출처 / Reference
직접 작성한 모식도(외부 그림 사용 안 함)

## A5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **입력은 Visium Space Ranger 결과입니다.** 슬라이스마다 `outs/`(filtered_feature_bc_matrix.h5와 spatial/)가 필요합니다. 슬라이스마다 하위 폴더 하나를 두고, 폴더 이름이 슬라이스 이름이 됩니다. Visium HD 데이터는 Visium HD 파이프라인을 써 주세요.
2. **조건 비교에는 조건마다 슬라이스 2장 이상(생물학적 반복)을 준비해 주세요.** 슬라이스가 1장뿐인 조건은 spot 단위 검정만 할 수 있고, 이 결과는 탐색용입니다. 한 슬라이스 안의 spot은 독립 반복이 아니기 때문입니다.
3. **슬라이스 정보 파일(CSV)에 `SliceID`, `Condition`을 적어 주세요.** `SliceID`는 슬라이스 폴더 이름과 같아야 합니다. 같은 개체가 각 조건에 있으면 `Patient` 열로 짝 설계를 씁니다.
4. **같은 종, 같은 참조로 만든 Space Ranger 결과만 함께 분석해 주세요.** 슬라이스마다 유전자 목록이 다르면 합칠 때 일부 유전자가 0이 되어 가짜 차이가 생길 수 있습니다.
5. **결과 해석 전에 QC 그림을 확인해 주세요.** spot별 UMI 수 분포와 조직 위 분포에서 조직 밖이나 UMI가 매우 낮은 spot이 많으면 거르는 기준(`min_counts`)을 올려 다시 실행합니다.
6. **슬라이스가 많을수록 통합 단계의 메모리가 늘어납니다.** 슬라이스 4장은 32GB, 8장 이상은 64GB를 권장합니다.
7. **모든 분석은 인터넷 연결 없이 수행됩니다.**

### English
1. **The input is Visium Space Ranger output.** Each slice needs `outs/` (filtered_feature_bc_matrix.h5 and spatial/). Put one subfolder per slice; the folder name becomes the slice name. Use the Visium HD pipeline for Visium HD data.
2. **For condition comparison prepare two or more slices (biological replicates) per condition.** A condition with one slice allows only spot-level tests, which are exploratory because spots of one slice are not independent replicates.
3. **List `SliceID` and `Condition` in the slice sheet (CSV).** `SliceID` must equal the slice folder name. When the same individual appears in each condition, add a `Patient` column for a paired design.
4. **Analyse together only Space Ranger outputs made for the same species and reference.** Different gene lists between slices zero some genes when merging and can create false differences.
5. **Check the QC plots before interpreting results.** If the UMI counts per spot and their distribution on the tissue show many spots outside the tissue or with very low counts, raise the filter (`min_counts`) and rerun.
6. **Memory of the integration step grows with the number of slices.** 32 GB is recommended for 4 slices and 64 GB for 8 or more.
7. **All analyses run without internet access.**

---

# 파트 B. Spatial_Transcriptomics_Visium_HD_Pipeline

## B0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `Spatial_Transcriptomics_Visium_HD_Pipeline` |
| 구성 모듈 | spatial_hd_prep, spatial_hd_cluster, spatial_condition_de |
| Version | 1.0 (CLOSHA 3.0 첫 배포) |
| Reference | https://satijalab.org/seurat/articles/visiumhd_analysis_vignette |
| Keyword(태그) | spatial transcriptomics, Visium HD, high-resolution spatial, clustering, sketch, differential expression |
| 대분류 / 중분류 | 등록 메모: 포탈 파이프라인 목록에서 가장 가까운 것을 고릅니다(후보: Transcriptomics / Spatial transcriptomics). |
| 대표 이미지 | 등록 메모: 결과 그림을 본 뒤 고릅니다(후보: spatial_hd_cluster 조직 위 군집). |

## B1. 파이프라인 소개 / Introduction

### 국문
Visium HD 공간 전사체 파이프라인은 10x Genomics Visium HD의 세포 크기에 가까운 bin(8·16µm) 단위 발현을 분석하여, 조직 안의 영역 구성과 조건에 따른 변화를 높은 해상도로 확인하는 분석 도구입니다. 슬라이드별 Space Ranger binned_outputs와 슬라이드 정보를 입력하면, bin을 거르고 정규화한 뒤 정보가 많은 bin을 뽑은 sketch로 모든 슬라이드를 함께 군집하고, 그 군집을 모든 bin에 옮겨 붙입니다. 이어서 조건 사이에서 군집 조성과 군집별 발현을 슬라이드 단위 pseudobulk DESeq2로 비교합니다. bin이 수십만 개라도 메모리에 맞게 처리하도록 sketch와 슬라이드별 처리를 씁니다.

### English
The Visium HD spatial transcriptomics pipeline analyses expression in near-cellular bins (8 or 16 um) from 10x Genomics Visium HD to reveal tissue regions and their changes between conditions at high resolution. From the Space Ranger binned_outputs of each slide and a slide sheet, it filters and normalises the bins, clusters all slides together on a sketch of informative bins, and transfers the clusters to every bin. Cluster composition and per-cluster expression are then compared between conditions with slide-level pseudobulk DESeq2. Sketching and slide-by-slide processing keep hundreds of thousands of bins within memory.

## B2. 분석 목표 / Analysis goals

### 국문
**Visium HD 공간 전사체 분석으로 확인할 수 있는 세 가지 분석 목표**

**01 조직은 어떤 발현 영역으로 나뉘는가**
bin을 발현이 비슷한 군집으로 나누고 조직 위에 그려, 피질 층이나 해마처럼 해부학적 영역과 그 경계를 세포 크기에 가까운 해상도로 확인합니다.

**02 각 영역을 특징짓는 유전자는 무엇인가**
군집마다 다른 군집보다 높게 발현하는 마커 유전자를 찾아 영역의 정체를 해석합니다.

**03 조건에 따라 영역 구성과 영역 안 발현이 어떻게 달라지는가**
모든 슬라이드를 같은 기준으로 군집한 뒤, 조건 사이에서 군집 비율과 군집별 유전자 발현을 비교합니다. 조건마다 슬라이드가 2장 이상이면 통계 검정을 합니다.

### English
**Three questions Visium HD spatial transcriptomics analysis can answer**

**01 Which expression regions make up the tissue?**
Bins are clustered by similar expression and drawn on the tissue, revealing anatomical regions such as cortical layers and the hippocampus and their borders at near-cellular resolution.

**02 Which genes characterise each region?**
Marker genes expressed more highly in each cluster than in the others are found to interpret the identity of the regions.

**03 How do region composition and expression within regions change between conditions?**
After all slides are clustered on a common basis, cluster proportions and per-cluster gene expression are compared between conditions, with statistical testing when each condition has two or more slides.

## B3. 분석 흐름 / Analysis workflow

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/pipeline_visium_hd.png` (원본 `pipeline_visium_hd.svg`)

### 대체 텍스트 (alt)
- 국문: Visium HD 공간 전사체 파이프라인 흐름도. bin 불러오기·정규화·sketch(spatial_hd_prep), 슬라이드 통합 군집과 모든 bin 배정(spatial_hd_cluster), 조건 간 비교(spatial_condition_de)로 이어짐.
- English: Visium HD spatial transcriptomics workflow: bin loading, normalisation and sketching (spatial_hd_prep), joint clustering of slides with labels for every bin (spatial_hd_cluster), and condition comparison (spatial_condition_de).

## B4. 분석 개념 / Analysis concept

그림: `docs/Spatial_Transcriptomics_Analysis_Pipeline/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 설명)
**그림. 공간 전사체 분석의 원리.** (A) 조직 절편 위의 격자에서 위치마다 유전자 발현을 셉니다. Visium은 지름 55µm spot(spot마다 세포 1~10개)이고, Visium HD는 2µm 사각형을 8µm 또는 16µm bin으로 묶어 세포 크기에 가까운 해상도로 봅니다. 이 파이프라인은 Visium HD bin을 분석합니다. (B) 발현이 비슷한 bin을 군집으로 묶어 조직 위에 칠하면 층 구조나 핵 같은 조직 영역이 드러나고, UMAP에서는 군집이 서로 떨어진 점 무리로 보입니다. (C) 조건 비교는 같은 군집(같은 영역) 안에서 합니다. 슬라이드마다 그 군집 bin의 count를 합친 pseudobulk를 만들고, 슬라이드를 반복으로 삼아 DESeq2로 조건 간 차이를 검정합니다. 조건마다 슬라이드가 한 장뿐이면 bin 단위 검정만 할 수 있으며 탐색용입니다. 조직 모양, 군집, count 값은 모식적인 값입니다.

### English (figure legend)
**Figure. Principle of spatial transcriptomics analysis.** (A) Gene expression is counted at each position of a grid over the tissue section: Visium uses 55 um spots (1-10 cells each), and Visium HD groups 2 um squares into 8 or 16 um bins, close to cellular resolution. This pipeline analyses Visium HD bins. (B) Bins with similar expression are grouped into clusters; painted on the tissue they reveal regions such as layers and nuclei, and in the UMAP they form separate groups of points. (C) Conditions are compared within one cluster (one region). For each slide the counts of that cluster's bins are summed into a pseudobulk sample, and DESeq2 tests the condition with slides as replicates. With one slide per condition only a bin-level test is possible, which is exploratory. Tissue shape, clusters and counts are schematic.

### 대체 텍스트 (alt)
- 국문: 공간 전사체 개념도. 조직 위 Visium spot과 Visium HD bin 격자, 조직 영역을 나타내는 군집과 UMAP, 슬라이드별 pseudobulk count를 DESeq2로 비교하는 과정을 보여 줌.
- English: Concept of spatial transcriptomics: Visium spots and Visium HD bins on a tissue, clusters as tissue regions with a UMAP, and slide-level pseudobulk counts compared with DESeq2.

### 출처 / Reference
직접 작성한 모식도(외부 그림 사용 안 함)

## B5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **입력은 Visium HD Space Ranger 결과입니다.** 슬라이드마다 `binned_outputs/` 폴더 전체가 필요합니다. 8·16µm 폴더의 조직 이미지는 2µm 폴더 이미지의 하드링크라, 일부 폴더만 복사하면 이미지가 빠질 수 있습니다. 슬라이드마다 하위 폴더 하나를 두고, 폴더 이름이 슬라이드 이름이 됩니다. Visium 데이터는 Visium 파이프라인을 써 주세요.
2. **bin 크기는 8µm를 권장합니다.** 16µm는 메모리와 시간이 4분의 1 정도로 줄어 큰 슬라이드나 빠른 확인에 씁니다. 2µm bin은 지원하지 않습니다. 모든 슬라이드를 같은 bin 크기로 분석해 주세요.
3. **조건 비교에는 조건마다 슬라이드 2장 이상(생물학적 반복)을 준비해 주세요.** 슬라이드가 1장뿐인 조건은 bin 단위 검정만 할 수 있고, 이 결과는 탐색용입니다. 한 슬라이드 안의 bin은 독립 반복이 아니기 때문입니다.
4. **슬라이드 정보 파일(CSV)에 `SliceID`, `Condition`을 적어 주세요.** `SliceID`는 슬라이드 폴더 이름과 같아야 합니다. 같은 개체가 각 조건에 있으면 `Patient` 열로 짝 설계를 씁니다.
5. **같은 종, 같은 참조로 만든 Space Ranger 결과만 함께 분석해 주세요.** 슬라이드마다 유전자 목록이 다르면 합칠 때 일부 유전자가 0이 되어 가짜 차이가 생길 수 있습니다.
6. **메모리를 많이 씁니다.** 8µm는 슬라이드당 32~64GB, 여러 장의 통합 군집은 64~128GB를 권장합니다. 메모리가 부족하면 bin 크기 16µm를 쓰거나 `min_counts`를 올려 주세요.
7. **모든 분석은 인터넷 연결 없이 수행됩니다.**

### English
1. **The input is Visium HD Space Ranger output.** Each slide needs its whole `binned_outputs/` folder. The tissue images of the 8 and 16 um folders are hard links to those of the 2 um folder, so copying only some folders can lose the images. Put one subfolder per slide; the folder name becomes the slide name. Use the Visium pipeline for Visium data.
2. **8 um bins are recommended.** 16 um needs about a quarter of the memory and time, for large slides or quick checks; 2 um bins are not supported. Analyse all slides with the same bin size.
3. **For condition comparison prepare two or more slides (biological replicates) per condition.** A condition with one slide allows only bin-level tests, which are exploratory because bins of one slide are not independent replicates.
4. **List `SliceID` and `Condition` in the slide sheet (CSV).** `SliceID` must equal the slide folder name. When the same individual appears in each condition, add a `Patient` column for a paired design.
5. **Analyse together only Space Ranger outputs made for the same species and reference.** Different gene lists between slides zero some genes when merging and can create false differences.
6. **Memory use is high.** 32-64 GB per slide is recommended for 8 um, and 64-128 GB for joint clustering of several slides. When memory runs out, use 16 um bins or a higher `min_counts`.
7. **All analyses run without internet access.**
