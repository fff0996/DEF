# Spatial_Transcriptomics_Visium_Pipeline 포탈 등록 콘텐츠

KOBIC 포탈의 Visium 공간 전사체 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. Visium HD 파이프라인은 따로 등록하며 원고는 `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/pipeline/Portal_Content.md`에 있습니다. spatial_condition_de와 check_reference는 두 파이프라인이 같이 쓰는 모듈입니다. 모듈별 입력·옵션·결과는 `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/Registration.md`, 두 파이프라인 공통 작업 기록은 `docs/Spatial_Transcriptomics_Shared/Spatial_Notes.md`에 있습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

등록 메모: Reference는 파이프라인을 구성할 때 따른 Seurat 공식 안내입니다. Visium은 SCTransform·군집·공간 가변 유전자, Visium HD는 bin 불러오기·sketch 군집 흐름을 그대로 따랐습니다.

---

## 0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `Spatial_Transcriptomics_Visium_Pipeline` |
| 서브 타이틀(국문) | Visium 공간 발현 영역 분석 |
| 서브 타이틀(영문) | Spatial expression regions with Visium |
| 구성 모듈 | spatial_prep, spatial_cluster, spatial_svf, spatial_merge, spatial_condition_de, spatial_labelTransfer, spatial_rctd (세포 유형 2개는 참조를 줄 때 실행) |
| 파이프라인 입력 | Space Ranger 슬라이스 폴더(필수), 슬라이스 정보 CSV(필수), 단일세포 참조 RDS `reference_rds`와 세포 유형 열 `reference_label_col`(선택) |
| Version | 1.1 (CLOSHA 2.0 파이프라인 버전 + 1. 등록 메모: 2.0 파이프라인 버전이 1.0이라는 전제이며, 다르면 그 번호 + 1로 고칩니다) |
| Reference | https://satijalab.org/seurat/articles/spatial_vignette |
| Keyword(태그) | spatial transcriptomics, Visium, clustering, spatially variable genes, multi-slice integration, differential expression, cell type deconvolution, label transfer |
| 대분류 / 중분류 | Transcriptomics / Spatial_Transcriptomics (포탈 파이프라인 목록에 없으면 신규로 제안) |
| 대표 이미지 | 등록 메모: 결과 그림을 본 뒤 고릅니다(후보: spatial_merge 조직 위 통합 군집). |

## 1. 파이프라인 소개 / Introduction

### 국문
Visium 공간 전사체 파이프라인은 10x Genomics Visium으로 얻은 조직 절편의 spot별 유전자 발현을 분석하여, 조직 안의 영역 구성과 공간적인 발현 패턴, 조건에 따른 변화를 확인하는 분석 도구입니다. 슬라이스별 Space Ranger 결과와 슬라이스 정보를 입력하면, Seurat으로 spot을 거르고 SCTransform으로 정규화한 뒤, 슬라이스별 군집과 마커, 공간 가변 유전자를 찾고, 여러 슬라이스를 합쳐(Harmony 선택) 같은 기준의 군집을 만들고, 조건 사이에서 군집 조성과 군집별 발현을 pseudobulk DESeq2로 비교합니다. 같은 조직의 단일세포 참조 자료를 함께 주면 spot마다 세포 유형 예측 점수(Seurat label transfer)와 세포 유형 비율(RCTD)도 계산합니다.

### English
The Visium spatial transcriptomics pipeline analyses per-spot gene expression of tissue sections from 10x Genomics Visium to reveal how the tissue is organised into regions, which genes follow spatial patterns, and what changes between conditions. From the Space Ranger output of each slice and a slice sheet, it filters spots and normalises them with SCTransform in Seurat, finds clusters, markers and spatially variable genes per slice, merges the slices (optionally with Harmony) into common clusters, and compares cluster composition and per-cluster expression between conditions with pseudobulk DESeq2. Given a single-cell reference of the same tissue, it also computes cell-type prediction scores (Seurat label transfer) and cell-type proportions (RCTD) for every spot.

## 2. 분석 목표 / Analysis goals

### 국문
**Visium 공간 전사체 분석으로 확인할 수 있는 다섯 가지 분석 목표**

**01 조직은 어떤 발현 영역으로 나뉘는가**
spot을 발현이 비슷한 군집으로 나누고 조직 위에 그려, 심근, 섬유화 부위, 혈관 주변처럼 조직 영역과 그 경계를 확인합니다.

**02 각 영역을 특징짓는 유전자는 무엇인가**
군집마다 다른 군집보다 높게 발현하는 마커 유전자를 찾아 영역의 정체를 해석합니다.

**03 어떤 유전자가 공간적으로 몰려 발현하는가**
군집과 상관없이 조직의 특정 위치에 몰려 발현하는 유전자(공간 가변 유전자)를 Moran's I로 찾습니다.

**04 조건에 따라 영역 구성과 영역 안 발현이 어떻게 달라지는가**
여러 슬라이스를 같은 기준으로 군집한 뒤, 조건 사이에서 군집 비율과 군집별 유전자 발현을 비교합니다. 조건마다 슬라이스가 2장 이상이면 통계 검정을 합니다.

**05 각 위치에는 어떤 세포가 있는가**
같은 조직의 단일세포 참조 자료가 있으면, spot마다 세포 유형 예측 점수와 spot 안의 세포 유형 비율을 계산합니다. spot 하나에 세포가 여러 개 들어 있어 비율로 봅니다. 참조가 없으면 이 단계는 건너뛰고 군집 마커로 해석합니다.

### English
**Five questions Visium spatial transcriptomics analysis can answer**

**01 Which expression regions make up the tissue?**
Spots are clustered by similar expression and drawn on the tissue, revealing tissue regions such as myocardium, fibrotic areas and perivascular zones and their borders.

**02 Which genes characterise each region?**
Marker genes expressed more highly in each cluster than in the others are found to interpret the identity of the regions.

**03 Which genes are expressed in spatial patterns?**
Genes concentrated in particular places of the tissue, regardless of clusters (spatially variable genes), are found with Moran's I.

**04 How do region composition and expression within regions change between conditions?**
After all slices are clustered on a common basis, cluster proportions and per-cluster gene expression are compared between conditions, with statistical testing when each condition has two or more slices.

**05 Which cells are at each position?**
With a single-cell reference of the same tissue, cell-type prediction scores and cell-type proportions within each spot are computed; a spot holds several cells, so types are read as proportions. Without a reference this step is skipped and clusters are read through their marker genes.

## 3. 분석 흐름 / Analysis workflow

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/pipeline/figures/pipeline_visium.png` (원본 `pipeline_visium.svg`)

### 대체 텍스트 (alt)
- 국문: Visium 공간 전사체 파이프라인 흐름도. 슬라이스별 불러오기·정규화(spatial_prep), 군집(spatial_cluster) 뒤 공간 가변 유전자(spatial_svf), 슬라이스 통합 군집(spatial_merge), 단일세포 참조를 쓰는 세포 유형 분석(spatial_labelTransfer, spatial_rctd)으로 갈라지고, 통합 군집이 조건 간 비교(spatial_condition_de)로 이어짐. 세포 유형 분석은 참조를 줄 때만 실행됨.
- English: Visium spatial transcriptomics workflow: per-slice loading and normalisation (spatial_prep) and clustering (spatial_cluster), then spatially variable genes (spatial_svf), joint clustering of slices (spatial_merge) followed by condition comparison (spatial_condition_de), and cell-type analysis with a single-cell reference (spatial_labelTransfer, spatial_rctd), which runs only when a reference is given.

## 4. 분석 개념 / Analysis concept

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/pipeline/figures/concept_williams2022_fig1_arrays.png`

등록 메모: 논문 그림(CC BY 4.0)을 먼저 씁니다. 그림 1은 Fig. 1에서 시퀀싱 기반(Arrays) 부분만 잘랐고, 그림 2는 Fig. 3 그대로입니다. 논문 그림에 없는 내용(군집, 조건 비교, 세포 유형)은 직접 그린 그림 3으로 보탭니다.

### 국문 (그림 1 설명)
**그림 1. 공간 전사체가 위치를 기록하는 원리(시퀀싱 기반).** 1. 슬라이드에 위치마다 다른 바코드를 붙인 포획 탐침이 깔려 있습니다. 2. 바코드 위치를 이미지로 확인합니다(Visium과 Visium HD는 바코드 위치가 슬라이드를 만들 때 정해져 있어 이 단계가 없습니다). 3. 조직 절편을 올리면 세포의 mRNA가 바로 아래 탐침에 붙고 그 자리의 바코드가 함께 기록됩니다. 4. 붙잡힌 분자를 시퀀싱해 유전자와 바코드(위치)를 함께 읽어 위치별 발현 표를 만듭니다. Visium은 지름 55µm spot, Visium HD는 2µm 사각형 칸(8·16µm로 묶어 씀)입니다. Williams CG et al., Genome Med 14, 68 (2022), Fig. 1 일부(CC BY 4.0).

### English (Figure 1 legend)
**Figure 1. How spatial transcriptomics records location (sequencing-based).** 1. Capture probes carrying a different barcode at each position cover the slide. 2. Barcode positions are imaged (Visium and Visium HD fix them when the slide is made, so this step is not needed). 3. A tissue section is placed on top; the mRNA of each cell binds the probes directly beneath and is tagged with that position's barcode. 4. Sequencing the captured molecules reads gene and barcode (position) together, giving an expression table per position. Visium uses 55 um spots and Visium HD 2 um squares (grouped into 8 or 16 um bins). Part of Fig. 1 of Williams CG et al., Genome Med 14, 68 (2022) (CC BY 4.0).

### 대체 텍스트 (그림 1)
- 국문: 바코드 탐침 배열 위에 조직 절편을 올려 mRNA를 포획하고 시퀀싱하는 과정 그림.
- English: A barcoded probe array, a tissue section placed on it to capture mRNA, and sequencing of the captured probes.

### 출처 (그림 1)
Williams CG, Lee HJ, Asatsuma T, Vento-Tormo R, Haque A. An introduction to spatial transcriptomics for biomedical research. *Genome Medicine* 14, 68 (2022). https://doi.org/10.1186/s13073-022-01075-1, Fig. 1의 Sequencing methods(Arrays) 부분을 잘라 씀. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). 원 그림은 BioRender.com으로 작성됨.

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/pipeline/figures/concept_williams2022_fig3.png`

### 국문 (그림 2 설명)
**그림 2. 공간 전사체 분석의 일반적인 흐름.** 시퀀싱 기반 자료(오른쪽: Visium, Visium HD)는 정렬과 위치 매핑(Space Ranger, 이 파이프라인의 앞 단계)을 거친 뒤 정규화하고, 군집, 공간 분석, 세포 유형 추정(deconvolution) 같은 하류 분석을 거쳐 차등 발현 같은 생물학적 해석으로 이어집니다. 이 파이프라인은 정규화부터 차등 발현까지를 맡습니다. 이미징 기반 자료(왼쪽)는 이 파이프라인의 입력이 아닙니다. Williams CG et al., Genome Med 14, 68 (2022), Fig. 3(CC BY 4.0).

### English (Figure 2 legend)
**Figure 2. The usual course of a spatial transcriptomics analysis.** Sequencing-based data (right: Visium, Visium HD) are aligned and mapped to positions (Space Ranger, before this pipeline), normalised, and passed to downstream analyses such as clustering, spatial analysis and cell-type deconvolution, leading to biological inference such as differential expression. This pipeline covers normalisation through differential expression; imaging-based data (left) are not its input. Fig. 3 of Williams CG et al., Genome Med 14, 68 (2022) (CC BY 4.0).

### 대체 텍스트 (그림 2)
- 국문: 이미징·시퀀싱 자료가 정규화, 하류 분석, 생물학적 해석으로 이어지는 흐름도.
- English: Flow chart from imaging and sequencing data through normalisation and downstream analysis to biological inference.

### 출처 (그림 2)
Williams CG, Lee HJ, Asatsuma T, Vento-Tormo R, Haque A. An introduction to spatial transcriptomics for biomedical research. *Genome Medicine* 14, 68 (2022). https://doi.org/10.1186/s13073-022-01075-1, Fig. 3을 그대로 씀. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). 원 그림은 BioRender.com으로 작성됨.

그림: `docs/Spatial_Transcriptomics_Visium_Pipeline/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 3 설명)
**그림 3. 이 파이프라인의 분석 원리.** (A) 조직 절편 위의 격자에서 위치마다 유전자 발현을 셉니다. Visium은 지름 55µm spot(spot마다 세포 1~10개)이고, Visium HD는 2µm 사각형을 8µm 또는 16µm bin으로 묶어 세포 크기에 가까운 해상도로 봅니다. 이 파이프라인은 Visium spot을 분석합니다. (B) 발현이 비슷한 spot을 군집으로 묶어 조직 위에 칠하면 층 구조나 핵 같은 조직 영역이 드러나고, UMAP에서는 군집이 서로 떨어진 점 무리로 보입니다. (C) 조건 비교는 같은 군집(같은 영역) 안에서 합니다. 슬라이스마다 그 군집 spot의 count를 합친 pseudobulk를 만들고, 슬라이스를 반복으로 삼아 DESeq2로 조건 간 차이를 검정합니다. 조건마다 슬라이스가 한 장뿐이면 spot 단위 검정만 할 수 있으며 탐색용입니다. (D) 같은 조직의 단일세포 참조 자료가 있으면, 참조의 세포 유형별 발현 특징으로 위치마다 세포 유형을 추정합니다. Visium spot은 세포가 섞여 있어 비율로, Visium HD bin은 세포 하나 크기라 유형으로 붙이고, 그 결과로 세포 유형별 조건 비교도 할 수 있습니다. 참조가 없으면 이 단계는 건너뜁니다. 조직 모양, 군집, count 값은 모식적인 값입니다.

### English (Figure 3 legend)
**Figure 3. Analysis principle of this pipeline.** (A) Gene expression is counted at each position of a grid over the tissue section: Visium uses 55 um spots (1-10 cells each), and Visium HD groups 2 um squares into 8 or 16 um bins, close to cellular resolution. This pipeline analyses Visium spots. (B) Spots with similar expression are grouped into clusters; painted on the tissue they reveal regions such as layers and nuclei, and in the UMAP they form separate groups of points. (C) Conditions are compared within one cluster (one region). For each slice the counts of that cluster's spots are summed into a pseudobulk sample, and DESeq2 tests the condition with slices as replicates. With one slice per condition only a spot-level test is possible, which is exploratory. (D) With a single-cell reference of the same tissue, cell types are estimated at each position from the reference's per-type expression profiles: as proportions in Visium spots, which hold several cells, and as one type per Visium HD bin, which is about one cell; conditions can then also be compared per cell type. Without a reference this step is skipped. Tissue shape, clusters and counts are schematic.

### 대체 텍스트 (그림 3)
- 국문: 공간 전사체 개념도. 조직 위 Visium spot과 Visium HD bin 격자, 조직 영역을 나타내는 군집과 UMAP, 슬라이스별 pseudobulk count를 DESeq2로 비교하는 과정, 단일세포 참조로 spot의 세포 유형 비율과 bin의 세포 유형을 붙이는 과정을 보여 줌.
- English: Concept of spatial transcriptomics: Visium spots and Visium HD bins on a tissue, clusters as tissue regions with a UMAP, slice-level pseudobulk counts compared with DESeq2, and cell types assigned from a single-cell reference as proportions per spot and one type per bin.

### 출처 (그림 3)
직접 작성한 모식도(외부 그림 사용 안 함)

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **입력은 Visium Space Ranger 결과입니다.** 슬라이스마다 `outs/`(filtered_feature_bc_matrix.h5와 spatial/)가 필요합니다. 슬라이스마다 하위 폴더 하나를 두고, 폴더 이름이 슬라이스 이름이 됩니다. Visium HD 데이터는 Visium HD 파이프라인을 써 주세요.
2. **조건 비교에는 조건마다 슬라이스 2장 이상(생물학적 반복)을 준비해 주세요.** 슬라이스가 1장뿐인 조건은 spot 단위 검정만 할 수 있고, 이 결과는 탐색용입니다. 한 슬라이스 안의 spot은 독립 반복이 아니기 때문입니다.
3. **슬라이스 정보 파일(CSV)에 `SliceID`, `Condition`을 적어 주세요.** `SliceID`는 슬라이스 폴더 이름과 같아야 합니다. 같은 개체가 각 조건에 있으면 `Patient` 열로 짝 설계를 씁니다.
4. **같은 종, 같은 참조로 만든 Space Ranger 결과만 함께 분석해 주세요.** 슬라이스마다 유전자 목록이 다르면 합칠 때 일부 유전자가 0이 되어 가짜 차이가 생길 수 있습니다.
5. **결과 해석 전에 QC 그림을 확인해 주세요.** spot별 UMI 수 분포와 조직 위 분포에서 조직 밖이나 UMI가 매우 낮은 spot이 많으면 거르는 기준(`min_counts`)을 올려 다시 실행합니다.
6. **슬라이스가 많을수록 통합 단계의 메모리가 늘어납니다.** 통합 단계(spatial_merge)는 64GB를 권장하며, 슬라이스가 아주 많으면 128GB로 올려 주세요. 단일세포 참조가 크면(수만 세포 이상) spatial_labelTransfer에 128GB를 권장합니다.
7. **세포 유형은 같은 종, 같은 조직의 단일세포 참조 자료(Seurat RDS)로 붙입니다.** 참조(reference_rds)와 세포 유형 열 이름(reference_label_col)을 주면 spatial_labelTransfer(세포 유형 예측 점수)와 spatial_rctd(spot 안의 세포 유형 비율)가 실행됩니다. 참조를 주지 않으면 두 모듈은 건너뛰고 나머지 분석은 그대로 끝나며, 군집은 마커 유전자와 조직 위치로 해석합니다. 공개 단일세포 아틀라스(예: CELLxGENE, Allen Brain Cell Atlas)를 참조로 쓸 수 있습니다. 열 이름을 모르면 비워 두고 실행하면 분석 전에 멈추고 오류 로그에 후보 열을 보여 줍니다.
8. **모든 분석은 인터넷 연결 없이 수행됩니다.**

### English
1. **The input is Visium Space Ranger output.** Each slice needs `outs/` (filtered_feature_bc_matrix.h5 and spatial/). Put one subfolder per slice; the folder name becomes the slice name. Use the Visium HD pipeline for Visium HD data.
2. **For condition comparison prepare two or more slices (biological replicates) per condition.** A condition with one slice allows only spot-level tests, which are exploratory because spots of one slice are not independent replicates.
3. **List `SliceID` and `Condition` in the slice sheet (CSV).** `SliceID` must equal the slice folder name. When the same individual appears in each condition, add a `Patient` column for a paired design.
4. **Analyse together only Space Ranger outputs made for the same species and reference.** Different gene lists between slices zero some genes when merging and can create false differences.
5. **Check the QC plots before interpreting results.** If the UMI counts per spot and their distribution on the tissue show many spots outside the tissue or with very low counts, raise the filter (`min_counts`) and rerun.
6. **Memory of the integration step grows with the number of slices.** 64 GB is recommended for the integration step (spatial_merge), and 128 GB for very many slices. With a large single-cell reference (tens of thousands of cells or more), 128 GB is recommended for spatial_labelTransfer.
7. **Cell types come from a single-cell reference (Seurat RDS) of the same species and tissue.** Given a reference (reference_rds) and its cell-type column (reference_label_col), spatial_labelTransfer (cell-type prediction scores) and spatial_rctd (cell-type proportions within spots) run. Without a reference both are skipped and the rest of the analysis finishes as usual; clusters are then interpreted by their marker genes and tissue location. Public single-cell atlases (for example CELLxGENE, Allen Brain Cell Atlas) can serve as references. If the column name is unknown, leave it empty: the run stops before the analysis and the error log lists the candidate columns.
8. **All analyses run without internet access.**
