Spatial transcriptomics pipeline: 작업 기록

작성일: 2026-10-22

## 1. 구성
| 모듈 | 파일 | 상태 |
|---|---|---|
| spatial_prep | `spatial_prep.1.0.R` | 받은 스크립트 |
| spatial_cluster | `spatial_cluster.1.0.R` | 받은 스크립트 |
| spatial_svf | `spatial_svf.1.0.R` | 받은 스크립트 |
| spatial_labelTransfer | `spatial_labelTransfer.1.0.R` | 받은 스크립트(Azimuth 없이 동작하는 분기 있음) |
| spatial_rctd | `spatial_rctd.1.0.R` | 받은 스크립트 |
| spatial_merge | `spatial_merge.1.1.R` | harmony 인자 수정(아래 4절) |
| check_reference | `check_reference.1.0.R` | 받은 스크립트 |
| spatial_condition_de | `spatial_condition_de.1.0.R` | 새 모듈: 조건 간 비교 |

실행 이미지: `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.0.def`(빌드 전).

## 2. 실행 이미지 패키지 결정
- 대상 버전: R 4.3.3, Seurat 5.3.0, SeuratObject 5.2.0, presto 1.0.0, spacexr 2.2.1, DESeq2 1.42.0, harmony 1.2.3, glmGamPoi 1.14.0, hdf5r 1.3.12, ggplot2 3.5.2, patchwork 1.3.2, Matrix 1.6-5. 모두 conda-forge 또는 bioconda에서 받는다.
- R 4.3인 이유: bioconda spacexr(RCTD)은 R 4.3용만 있고 presto는 R 4.4까지다. R 4.4.3과 4.5.3에서는 이 조합이 풀리지 않는다(2026-10-21 dry-run).
- Azimuth: bioconda r-azimuth 0.5.0은 의존성(ensembldb 등)이 어느 R 버전에서도 풀리지 않아 넣지 않는다. spatial_labelTransfer는 Azimuth가 없을 때 Azimuth 형식 참조의 SCT 모델 대신 query 자신의 SCT를 쓰도록 이미 작성되어 있다.
- presto 필수: 없으면 Seurat의 FindAllMarkers가 매우 느리다(슬라이스 1장 마커 분석 10분 이상). 넣은 뒤에는 spatial_cluster가 슬라이스당 약 75초.

## 3. 테스트(2026-10-21, Codespace 2코어, 약 3GB 여유)
자료: 10x 공개 마우스 뇌 Visium 4장(Sagittal Anterior/Posterior, Section 1/2). Section 1과 2를 조건(section1, section2)으로 두었다. 조건마다 2장이다.

Codespace는 남은 메모리가 1GB 아래로 내려가면 프로세스를 종료한다. 그래서 테스트용으로만 입력을 줄였다. 스크립트는 바꾸지 않았다.
- prep과 cluster: 슬라이스마다 따로 실행하고, 유전자를 검출 비율이 높은 6000개로 줄였다(원본 32,285개).
- merge와 조건 비교: 군집 결과에서 슬라이스마다 spot 600개를 뽑았다.

| 단계 | 시간 | 최대 메모리 | 비고 |
|---|---|---|---|
| prep (슬라이스 1장, 6000 유전자) | 51~56초 | 2.2~2.5GB | 1.2만 유전자 2.7~2.9GB. 원본 전체 유전자면 3~4GB로 추정 |
| cluster (슬라이스 1장) | 71~78초 | 1.7~1.9GB | presto 사용 |
| merge 1.1 (4장 × 600 spot, harmony) | 74초 | 2.9GB | 4장 × 1,200 spot은 Codespace 한계로 PrepSCTFindMarkers에서 종료 |
| condition_de (4장 × 600 spot) | 64초 | 2.0GB | |

조건 비교 결과(section2 vs section1, 군집 17개):
- pseudobulk DESeq2: 조건마다 2장씩 충분한 군집 6개. 이 중 3개에서 유의 유전자(padj < 0.05, |log2FC| ≥ 0.5)가 나왔다. 같은 조직의 다른 절편이라 차이가 거의 없는 것이 예상과 맞다.
- spot 단위 Wilcoxon(탐색용): spot을 600개로 줄여 한쪽 조건에 slice가 1장뿐인 군집 8개. spot 단위라 유의 유전자가 많이 나온다(위양성 경향). 경고로 알린다.
- 검정 불가: 3개 군집(spot 부족). 상태로 기록하고 종료 코드 0.
- 그림(조성, volcano, log2FC heatmap, 유의 유전자 수, 조직 위 유전자 분포)은 만들어졌지만, Codespace 재시작으로 지워져 아직 직접 보지 못했다.

## 4. 받은 스크립트에서 찾은 문제
- **spatial_merge 1.0, integration=harmony에서 항상 실패:** `RunHarmony(..., reduction = "pca", assay.use = ...)`가 harmony 1.0 이상에서 "argument 3 matches multiple formal arguments"로 멈춘다. harmony 1.0부터 `reduction`이 `reduction.use`와 `reduction.save`로 나뉘었기 때문이다. 1.1에서 `reduction.use = "pca"`로 고치고 `assay.use`는 뺐다.
- **스크립트 규칙과 다른 점**(DEF 동작에는 영향 없음, 다음 버전에서 맞출 것):
  - 경고와 슬라이스별 오류가 stdout으로 나간다.
  - `logs/`의 `.log`/`.error.log` 분리가 없다.
  - `output_dir` 기본값이 `./bx_spatial_out`이다(필수가 아님).
  - merge에는 이전 결과 정리가 없다.
  - merge의 `save_plot` 결과(`[1] TRUE`)가 stdout에 찍힌다.

## 5. 권장 자원(포탈: 코어 1/4/8/16, 메모리 8~128GB)
| 모듈 | Visium | Core |
|---|---|---|
| spatial_prep | 16GB | 4 |
| spatial_cluster | 16GB | 4 |
| spatial_svf | 16GB | 4 |
| spatial_labelTransfer | 32~64GB(참조 크기에 따라) | 4 |
| spatial_rctd | 16~32GB | 8 |
| spatial_merge | 슬라이스 4장 32GB, 8장 이상 64GB | 4 |
| spatial_condition_de | 16GB | 4 |

## 6. 남은 일
1. 테스트를 다시 돌려 그림 확인(조건 비교)
2. Visium HD 지원(prep, cluster, svf, rctd, merge 1.1: bin_size, sketch)
3. bx_spatial, bx_cnvkit, bx_facets 검증 빌드
4. 원고
