Spatial transcriptomics pipeline: 작업 기록

작성일: 2026-10-22

## 1. 구성
배포 번호와 작업 파일은 각 파이프라인의 `modules/Registration.md` 표(`docs/Spatial_Transcriptomics_Visium_Pipeline/`, `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/`)를 따른다. 받은 스크립트(CLOSHA 2.0)는 고친 것만 2.0 번호 + 1이고, 새 모듈은 1.0이다(사용자 결정, 2026-10-22).

| 모듈 | 작업 파일(최신) | 배포 번호 | 이전 파일 |
|---|---|---|---|
| spatial_prep | `spatial_prep.1.1.R` | 1.1 | 1.0(받은 스크립트) |
| spatial_cluster | `spatial_cluster.1.1.R` | 1.1 | 1.0(받은 스크립트) |
| spatial_svf | `spatial_svf.1.1.R` | 1.1 | 1.0(받은 스크립트) |
| spatial_labelTransfer | `spatial_labelTransfer.1.2.R` | 1.1 | 1.0(받은 스크립트), 1.1 |
| spatial_rctd | `spatial_rctd.1.2.R` | 1.1 | 1.0(받은 스크립트), 1.1 |
| spatial_merge | `spatial_merge.1.2.R` | 1.1 | 1.0(받은 스크립트), 1.1(harmony 인자) |
| check_reference | `check_reference.1.1.R` | 1.1 | 1.0(받은 스크립트) |
| spatial_condition_de | `spatial_condition_de.1.4.R` | 1.0 | 1.0, 1.1, 1.2, 1.3 |
| spatial_hd_prep | `spatial_hd_prep.1.1.R` | 1.0 | 1.0 |
| spatial_hd_cluster | `spatial_hd_cluster.1.1.R` | 1.0 | 1.0 |
| spatial_hd_svf | `spatial_hd_svf.1.0.R` | 1.0 | - |
| spatial_hd_rctd | `spatial_hd_rctd.1.2.R` | 1.0 | 1.0, 1.1 |

실행 이미지: `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.0.def`(2026-10-22 Codespace 검증 빌드 성공, 8분, 1.29GB, 호스트 변화 없음), `bx_spatial.1.1.def`(r-ape 5.8-1 추가, svf용).

## 2. 실행 이미지 패키지 결정
- 대상 버전: R 4.3.3, Seurat 5.3.0, SeuratObject 5.2.0, presto 1.0.0, spacexr 2.2.1, DESeq2 1.42.0, harmony 1.2.3, glmGamPoi 1.14.0, hdf5r 1.3.12, ggplot2 3.5.2, patchwork 1.3.2, Matrix 1.6-5. 모두 conda-forge 또는 bioconda에서 받는다.
- R 4.3인 이유: bioconda spacexr(RCTD)은 R 4.3용만 있고 presto는 R 4.4까지다. R 4.4.3과 4.5.3에서는 이 조합이 풀리지 않는다(2026-10-21 dry-run).
- Azimuth: bioconda r-azimuth 0.5.0은 의존성(ensembldb 등)이 어느 R 버전에서도 풀리지 않아 넣지 않는다. spatial_labelTransfer는 Azimuth가 없을 때 Azimuth 형식 참조의 SCT 모델 대신 query 자신의 SCT를 쓰도록 이미 작성되어 있다.
- presto 필수: 없으면 Seurat의 FindAllMarkers가 매우 느리다(슬라이스 1장 마커 분석 10분 이상). 넣은 뒤에는 spatial_cluster가 슬라이스당 약 75초.

## 3. 테스트(2026-10-21, Codespace 2코어, 약 3GB 여유)
자료: 10x 공개 마우스 뇌 Visium 4장(Sagittal Anterior/Posterior, Section 1/2). Section 1과 2를 조건(section1, section2)으로 두었다. 조건마다 2장이다.

Codespace는 남은 메모리가 1GB 아래로 내려가면 프로세스를 종료한다. 그래서 테스트용으로만 입력을 줄였다. 스크립트는 바꾸지 않았다.
- prep과 cluster: 슬라이스마다 따로 실행하고, 모든 슬라이스에서 같은 유전자 6,000개(전체 슬라이스에서 검출 spot이 많은 순)만 남겼다(원본 32,285개).
- merge와 조건 비교: 군집 결과에서 슬라이스마다 spot 600개를 뽑았다.
- 다시 돌리는 법: `bash tools/spatial/run_spatial_test.sh <작업 폴더>`. 약 30분, 3GB.
- 주의: 처음에는 슬라이스마다 따로 유전자를 골랐다. 그러자 어떤 유전자는 일부 슬라이스에서 0이 되어, log2FC ±5~8의 가짜 차이가 생겼다(예: Gabra6가 sec2 소뇌에만 보임). 이 결과는 버렸다.

| 단계 | 시간 | 최대 메모리 | 비고 |
|---|---|---|---|
| prep (슬라이스 1장, 6000 유전자) | 52~77초 | 2.1~2.5GB | 1.2만 유전자 2.7~2.9GB. 원본 전체 유전자면 3~4GB로 추정 |
| cluster (슬라이스 1장) | 72~102초 | 1.7~2.0GB | presto 사용 |
| merge 1.1 (4장 × 600 spot, harmony) | 67초 | 2.5GB | 4장 × 1,200 spot은 Codespace 한계로 PrepSCTFindMarkers에서 종료 |
| condition_de (4장 × 600 spot) | 61초 | 2.0GB | |

조건 비교 결과(section2 vs section1, 같은 조직의 다른 절편이므로 차이가 없어야 정상, 군집 16개):
- pseudobulk DESeq2 7개 군집: 유의 유전자 0개. 반복(슬라이스)을 쓰면 가짜 차이가 나오지 않는다.
- spot 단위 Wilcoxon 7개 군집(탐색용, 한쪽 조건에 슬라이스가 1장뿐): 유의 유전자가 조금 나오며, 대부분 미토콘드리아(mt-Co1, mt-Nd5)와 리보솜(Rps28, Rps29) 유전자다. 절편 간 기술적 차이로 보이며, 이 방식에 경고를 붙인 이유와 맞는다.
- 검정 불가 2개 군집(spot 부족): 상태로 기록하고 종료 코드 0.
- 그림(조성, volcano, log2FC heatmap, 유의 유전자 수, 조직 위 유전자 분포)을 직접 확인했다.

## 4. 받은 스크립트에서 찾은 문제
- **spatial_merge 1.0, integration=harmony에서 항상 실패:** `RunHarmony(..., reduction = "pca", assay.use = ...)`가 harmony 1.0 이상에서 "argument 3 matches multiple formal arguments"로 멈춘다. harmony 1.0부터 `reduction`이 `reduction.use`와 `reduction.save`로 나뉘었기 때문이다. 1.1에서 `reduction.use = "pca"`로 고치고 `assay.use`는 뺐다.
- **스크립트 규칙과 다른 점**(DEF 동작에는 영향 없음, 다음 버전에서 맞출 것):
  - 경고와 슬라이스별 오류가 stdout으로 나간다.
  - `logs/`의 `.log`/`.error.log` 분리가 없다.
  - `output_dir` 기본값이 `./bx_spatial_out`이다(필수가 아님).
  - merge에는 이전 결과 정리가 없다.
  - merge의 `save_plot` 결과(`[1] TRUE`)가 stdout에 찍힌다.
  - 위 차이와 투명 배경 그림은 1.1(merge는 1.2)에서 고쳤다(2026-10-22).
- **spatial_labelTransfer 1.0, 참조에 SCT 모델이 있으면 모든 슬라이스가 실패:** query의 raw assay(Spatial)를 `recompute.residuals = TRUE`로 넘기는데, Seurat 5.3은 이를 "Mixing SCT and non-SCT"로 막는다. 1.1에서 query의 SCT assay를 넘긴다. Seurat가 그 SCT 모델의 count assay(Spatial)로 참조 모델 기준 residual을 다시 계산하므로 원래 의도와 같다.
- **spatial_labelTransfer 1.0, 작은 참조에서 실패:** anchor가 붙은 spot이 50개(TransferData 기본 k.weight)보다 적으면 멈춘다. 1.1에서 k.weight를 anchor spot 수 - 1로 낮추고 WARNING을 남긴다(5개 미만이면 실패).
- **spatial_rctd 1.0, dominant 세포 유형 그림이 항상 빠짐:** Seurat 5의 SpatialDimPlot에 없는 `na.value` 인자를 넘겨 매번 경고로 건너뛴다. 1.1에서 인자를 뺐다.

## 5. 권장 자원(포탈: 코어 1/4/8/16, 메모리 8~128GB)
2026-10-27에 넉넉한 값으로 올렸다(사용자 결정). 표와 근거는 각 파이프라인 `modules/Registration.md`의 권장 자원 절을 따른다.
- 8코어: 공간 전사체 작업 기준에 맞춘 값. 여러 코어를 실제로 쓰는 모듈은 rctd 두 개뿐이다.
- 128GB: spatial_labelTransfer, spatial_hd_cluster, spatial_hd_rctd
- 64GB: spatial_merge, spatial_condition_de, spatial_rctd, spatial_hd_prep, spatial_hd_svf, check_reference(4코어)
- 32GB: spatial_prep, spatial_cluster, spatial_svf
- 실제 규모 참조(수만 세포 이상)와 8µm는 CLOSHA에서 실측해 고친다.

## 6. Visium HD (2026-10-22)
기존 Visium 스크립트 5개는 그대로 두고 HD 전용 모듈을 추가했다(사용자 결정).

흐름: spatial_hd_prep → spatial_hd_cluster → spatial_condition_de 1.1

- **spatial_hd_prep:**
  - `Load10X_Spatial(bin.size = 8 또는 16)`로 불러온 뒤 bin을 거르고, LogNormalize, 가변 유전자, `SketchData`(LeverageScore, 기본 5만 bin) 순으로 처리한다.
  - SCTransform은 수십만 bin에 맞지 않아 쓰지 않는다.
  - 2µm bin은 지원하지 않는다.
- **spatial_hd_cluster:**
  - 모든 슬라이드의 sketch bin을 합쳐 PCA, harmony(슬라이드가 2장 이상일 때), 군집, UMAP, 마커(presto)를 계산한다.
  - 각 슬라이드의 모든 bin을 같은 PCA에 투영한다. 같은 평균·표준편차·loading을 쓰고, ScaleData처럼 10에서 자른다.
  - 같은 슬라이드의 sketch bin 중 가장 가까운 10개(Annoy)로 다수결을 해서 군집을 붙인다.
  - 그래서 군집 번호가 슬라이드 사이에서 같은 뜻이다.
  - `hd_slides.tsv`에 슬라이드별 객체 목록을 남긴다.
- **spatial_condition_de 1.1:**
  - `hd_slides.tsv`가 있으면 슬라이드 객체를 하나씩 읽어 pseudobulk를 합친다. 모든 bin을 한꺼번에 메모리에 올리지 않는다.
  - spot 단위 검정은 슬라이드·군집마다 최대 3,000 bin(`spot_level_max`)만 쓴다.
  - 기존 Visium 입력의 결과는 1.0과 같다(de_summary 비교로 확인).
- **실행 이미지:**
  - bx_spatial에 r-arrow 21.0.0을 추가했다. HD bin 위치가 `tissue_positions.parquet`라서 필요하다.
  - `%test`에 arrow, RcppAnnoy 동작 확인을 추가했다.

찾은 문제와 수정:
- Seurat 5.3.0에서 `FindVariableFeatures` 결과는 counts 층에 저장된다. 그래서 `SketchData`가 data 층에서 가변 유전자를 찾지 못한다. 이때 전체 유전자를 쓰다가 5,000개를 넘으면 "too slow"로 멈춘다.
  - 실제 HD 데이터(약 1만 9천 유전자)에서 항상 일어난다.
  - `features = VariableFeatures(obj)`를 넘겨 해결했다.
- 10x HD 압축 파일에서 8·16µm 폴더의 조직 이미지는 2µm 이미지의 하드링크다. 일부만 풀면 이미지가 빠진다(테스트 스크립트에서 처리).
- 조직 그림의 점 크기: `pt.size.factor` 2~3에서는 bin 사이가 비어 줄무늬가 생긴다. 기본값을 4로 하고 `pt_size` 인자로 바꿀 수 있게 했다.

테스트(10x Visium HD Mouse Brain FFPE, 16µm):
- 테스트용 데이터: Codespace 메모리 때문에 좌우 반으로 나눠 슬라이드 2장(각 약 4만 9천 bin)으로 쓰고, 유전자는 6,000개로 줄였다.
- 다시 돌리는 법: `bash tools/spatial/run_spatial_hd_test.sh <작업 폴더> <환경 폴더>`

| 단계 | 시간 | 최대 메모리 | 결과 |
|---|---|---|---|
| hd_prep (2장, sketch 1만) | 163초 | 2.9GB | 정상 |
| hd_cluster | 291초 | 3.5GB | 군집 22개. 점수 0.5 미만 bin은 1.5~2.5%. 피질 층, 선조체, 해마가 군집으로 나뉨 |
| condition_de 1.1 (1 대 1, spot 단위) | 94초 | 3.4GB | 해마 표지 Prox1이 해마가 있는 오른쪽에만 나옴(해부학과 일치) |

- 처음 실행에서는 hd_cluster와 condition_de가 Codespace 한계(약 4GB)에 걸렸다.
  - hd_cluster: 저장한 통합 객체를 메모리에서 비우고, 투영을 5천 bin 단위로 해서 해결했다.
  - condition_de: 그림 전에 검정용 count를 비우고, 이미 정규화된 HD 객체는 다시 정규화하지 않게 해서 해결했다.
- `pt_size` 기본값을 4로 바꾼 뒤의 전체 재실행은 Codespace 재시작으로 끝까지 확인하지 못했다. 바뀐 것은 그림의 점 크기뿐이다.

권장 자원(추정, CLOSHA에서 실측 필요):

| 모듈 | 16µm | 8µm | Core |
|---|---|---|---|
| spatial_hd_prep | 슬라이드당 16GB | 슬라이드당 32~64GB | 4 |
| spatial_hd_cluster | 32GB | 64~128GB | 4 |
| spatial_condition_de 1.1 | 16~32GB | 32~64GB | 4 |

## 6.1 SIF 실행 확인 (2026-10-22, bx_spatial 1.0)
빌드한 bx_spatial 1.0 SIF 안에서 테스트를 다시 돌렸다(`tools/spatial/run_spatial_test.sh <작업 폴더> <env 폴더>`, env 폴더의 `bin/Rscript`는 `apptainer exec` 래퍼).

| 단계 | 시간 | 최대 메모리 | 결과 |
|---|---|---|---|
| Visium prep (슬라이스 4장, 각각) | 51~64초 | 2.1~2.5GB | 정상 |
| Visium cluster (각각) | 71~79초 | 1.7~2.0GB | 정상 |
| Visium svf (1장) | 9초 | 0.9GB | **실패**: Seurat RunMoransI는 Rfast2나 ape가 필요한데 이미지에 없음 → bx_spatial 1.1에서 r-ape 추가 |
| Visium svf (1장, bx_spatial 1.1) | 447초 | 1.8GB | 정상. 상위: Calb2, Gng4, Ttr, Pcbp3, Fabp7, Gpsm1(후각망울 층, 맥락얼기). ape는 spot 수의 제곱에 비례해 느림 |
| Visium merge 1.1 | 73초 | 2.5GB | 정상 |
| Visium condition_de 1.1 | 71초 | 2.1GB | 정상, 결과는 1.0과 같음 |
| HD prep (4분면 4장) | 197초 | 2.2GB | 정상 |
| HD cluster | 271초 | 2.6GB | 정상, 군집 18개. 해마 CA(13)·치아이랑(17)이 띠로 나뉘고 Prox1이 치아이랑에만 나옴 |
| HD condition_de 1.1 | 82초 | 2.9GB | 검정·요약표·그림 5종까지 정상. 조직 위 유전자 그림 단계에서 Codespace 한계로 종료(슬라이드 객체를 읽는 단계). 같은 그림은 conda 2분할 테스트에서 그려짐을 확인 |

- HD 테스트는 좌우 반쪽 2장 대신 4분면 4장(각 2만 2천~2만 7천 bin, sketch 5,000)으로 바꿨다. 조건마다 슬라이드가 2장이라 HD pseudobulk DESeq2 경로까지 확인된다(군집 12개 검정).
- HD 테스트용 자료를 나누는 split_hd.R은 h5를 500만 개씩 나눠 읽고, 정렬 없이 압축 열 행렬을 바로 만든다. Read10X_h5로 전체를 읽으면 Codespace 한계를 넘는다.
- Visium 테스트 러너가 condition_de 1.0을 돌리고 있어 1.1로 바꿨다. 조직 위 유전자 그림의 공통 색 범위는 1.1에만 있다.

그림 점검에서 찾은 것(다음 버전에서 고칠 것):
- bx_spatial 1.1 검증 빌드: 8분, 1.29GB, %test(Moran's I 포함) 통과, 호스트 변화 없음.
- 받은 스크립트(spatial_cluster, spatial_merge)의 marker dot plot과 condition_de의 log2FC heatmap이 투명 배경 PNG로 저장된다. 원고용 그림은 흰 배경을 깔았다. ggsave에 `bg = "white"`를 주면 된다.
- spatial_hd_prep QC 그림의 두 violin 제목이 붙어 겹친다.

## 7. 원고 (2026-10-22)
- `modules/Registration.md`, `modules/Portal_Content.md`, `pipeline/Portal_Content.md`, `containers/Container_Manual.md`를 썼다.
- 범위: 12개 모듈 모두. 파이프라인 기본 구성은 Visium(prep, cluster, svf, merge, condition_de)과 Visium HD(hd_prep, hd_cluster, hd_svf, condition_de)이다. 참조가 필요한 labelTransfer, rctd, hd_rctd, check_reference는 선택 모듈로 안내했다(파이프라인 원고 A5·B5). 2026-10-27에 세포 유형 모듈을 파이프라인 안으로 옮겼다(7.1). 세포 유형 모듈 3개의 카테고리는 Annotation / Cell_Type_Annotation(신규), check_reference는 Utility / Genomic_data_Utility(사용자 확인, 2026-10-22). 2026-10-27: svf와 hd_svf는 Omics / Spatial_Analysis(신규), 두 파이프라인은 Transcriptomics / Spatial_Transcriptomics로 정했다(사용자가 결정을 맡김).
- 노선도 2장(`pipeline/figures/pipeline_visium*.png`, 생성 `make_pipeline_map.py`, 그리기 함수는 `docs/tools/metro_map.py`), 파이프라인 개념도(`pipeline/figures/concept.png`, `make_concept.py`).
- 테스트는 이제 빌드한 SIF 안에서 돌린다: `tools/spatial/run_spatial_test.sh <작업 폴더> <env 폴더>`의 env 폴더에 `bin/Rscript`(apptainer exec 래퍼)를 두면 conda 환경을 만들지 않는다.

## 7.1 세포 유형 가지를 파이프라인 안으로 (2026-10-27)
사용자 결정:
- labelTransfer, rctd(Visium)와 hd_rctd → condition_de(세포 유형 기준, HD)를 파이프라인 안에 둔다.
- 참조는 파이프라인의 선택 입력(`reference_rds`, `reference_label_col`)으로 받는다. CLOSHA는 선택 입력을 지원한다.
- 참조가 없으면 세 모듈은 `output_dir/skipped.txt`를 남기고 정상 종료한다. condition_de 1.4는 `input_dir`에 `skipped.txt`가 있으면 같이 건너뛴다.
- 열 이름은 자동으로 고르지 않는다. 참조 기반 어노테이션이 표준이지만 참조마다 열 이름이 달라서, 비었거나 틀리면 참조를 읽은 직후 멈춘다. 그때 세포 유형 후보 열(범주 2~100개, check_reference와 같은 기준)과 첫 범주들을 오류 로그에 보여 준다. 사용자가 확인하고 다시 실행한다.
- check_reference는 2.0에 배포된 모듈이라 그대로 두고, 보조 모듈로 안내한다.

같은 날 고친 버그(Codespace HD 2장 테스트에서 발견):
- hd_rctd 1.1: 첫 세포 유형 가중치를 꺼낼 때 `cbind(bin 이름, 열 번호)`가 열 번호를 문자로 바꿔, 모든 슬라이드가 `subscript out of bounds`로 실패했다.
- condition_de 1.3: hd_rctd에서 UMI가 적어 세포 유형이 NA인 bin 때문에 `non-conformable arguments`로 실패했다. 이제 그 bin은 경고와 함께 뺀다.
- 결과: hd_rctd(full, 16µm, 2장) 1,896초, 최대 3.74GB(1코어). condition_de(세포 유형 17종) 45초, 2.0GB.

확인(bx_spatial 1.1 SIF, 2026-10-27):
| 경우 | labelTransfer 1.2 | rctd 1.2 | hd_rctd 1.2 | condition_de 1.4 |
|---|---|---|---|---|
| 참조 없음 | 건너뜀, exit 0 | 건너뜀, exit 0 | 건너뜀, exit 0 | 앞이 건너뜀 → 건너뜀, exit 0 |
| 열 이름 비었음 | 후보 표시 후 exit 1 | 후보 표시 후 exit 1 | 후보 표시 후 exit 1 | - |
| 열 이름 틀림 | - | 후보 표시 후 exit 1 | - | - |
| 열 이름 맞음 | 열 확인 통과 | 열 확인 통과 | 참조 준비 통과 | - |

참조가 있을 때의 분석 코드는 1.1과 같다. 1.2로 전체 분석은 다시 돌리지 않았다. 확인 시점에 Codespace가 다시 시작돼 슬라이드 객체가 지워졌다.

## 7.2 파이프라인별 폴더로 나눔 (2026-10-27)
사용자 결정: 두 파이프라인은 모듈 구성이 달라 원고를 따로 관리한다.
- `docs/Spatial_Transcriptomics_Visium_Pipeline/`: Visium 파이프라인 원고, 모듈 8개(prep, cluster, svf, merge, condition_de, labelTransfer, rctd, check_reference) 원고와 Registration, 그림
- `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/`: Visium HD 파이프라인 원고, 모듈 6개(hd_prep, hd_cluster, hd_svf, condition_de, hd_rctd, check_reference) 원고와 Registration, 그림
- `docs/Spatial_Transcriptomics_Shared/`: 두 파이프라인 공통. 이 노트, 컨테이너 문서, 그림 생성 스크립트(`figures/make_pipeline_map.py`, `make_concept.py`, `make_module_concepts.py`; 결과를 각 파이프라인 폴더에 쓴다)
- 스크립트(`scripts/Spatial_Transcriptomics_Analysis_Pipeline/`)와 DEF(`defs/Spatial_Transcriptomics_Analysis_Pipeline/`)는 같은 이미지(bx_spatial 1.1)를 쓰므로 나누지 않았다.
- spatial_condition_de와 check_reference는 양쪽 모듈 원고와 Registration에 같은 내용으로 있다. 고칠 때 양쪽을 함께 고친다.
- 7절 이전 기록의 `modules/...`, `pipeline/...` 경로는 나누기 전 `docs/Spatial_Transcriptomics_Analysis_Pipeline/` 기준이다.

## 8. 남은 일
1. 8µm 자원 실측(사용자가 CLOSHA에서 sacct MaxRSS, Elapsed)
