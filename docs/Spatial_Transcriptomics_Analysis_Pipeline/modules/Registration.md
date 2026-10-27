Spatial transcriptomics 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22, 갱신: 2026-10-27 (세포 유형 가지, 자원, CLOSHA 테스트 예제)

CLOSHA에 공간 전사체 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/Spatial_Transcriptomics_Analysis_Pipeline/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 실행 이미지는 모두 `bx_spatial.1.1`(`defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def`)이다. 1.0에는 svf의 Moran's I에 필요한 ape가 없어 1.1에서 더했다.

등록 메모:
- 받은 스크립트(prep, cluster, svf, merge, labelTransfer, rctd, check_reference)는 CLOSHA 2.0에 배포된 것이다. 배포 번호는 고친 스크립트만 2.0 번호 + 1이고, 이번에 모두 스크립트 규칙에 맞춰 고쳐 1.1이다. 새 모듈은 1.0이다(아래 표).
- 받은 스크립트의 규칙 차이(경고가 stdout으로 나감, `logs/`의 .log/.error.log 분리 없음, output_dir 기본값 `./bx_spatial_out`, merge가 이전 결과를 지우지 않음, 투명 배경 그림)는 새 버전에서 고쳤다(2026-10-22).

## 0. 파이프라인 흐름
```
Visium (spot 55µm):
  Space Ranger 슬라이스 폴더들 ─> [spatial_prep] ─output_dir─> [spatial_cluster] ─output_dir─┬─> [spatial_svf]
                                                                                            ├─> [spatial_labelTransfer] (참조가 있을 때)
                                                                                            ├─> [spatial_rctd] (참조가 있을 때)
                                                                                            └─> [spatial_merge] ─output_dir─> [spatial_condition_de]

Visium HD (bin 8·16µm):
  Space Ranger HD 슬라이드 폴더들 ─> [spatial_hd_prep] ─output_dir─> [spatial_hd_cluster] ─output_dir─┬─> [spatial_condition_de]
                                                                                                    ├─> [spatial_hd_svf]
                                                                                                    └─> [spatial_hd_rctd] (참조가 있을 때) ─output_dir─> [spatial_condition_de] (group_by=rctd_first_type)

참조 확인(보조): 단일세포 참조 RDS ─> [check_reference] (reference_label_col로 쓸 열 확인)
```
세포 유형 모듈(labelTransfer, rctd, hd_rctd)은 파이프라인 안에 두고, 참조는 파이프라인의 선택 입력(`reference_rds`, `reference_label_col`)으로 받는다(사용자 결정, 2026-10-27).
- 참조를 주지 않으면 세 모듈은 `output_dir/skipped.txt`를 남기고 정상 종료한다. 그 결과를 받는 spatial_condition_de도 같은 방식으로 건너뛴다.
- CLOSHA 입력은 필수/선택 둘뿐이라 `reference_rds`와 `reference_label_col` 모두 선택으로 등록한다. 참조를 주면 `reference_label_col`도 필요하다. 비었거나 참조에 없는 열이면 참조를 읽은 직후 멈추고, 세포 유형 후보 열(범주 2~100개)과 첫 범주들을 오류 로그에 보여 준다. 사용자가 확인하고 열 이름을 넣어 다시 실행한다. 자동으로 고르지 않는다(틀린 열로 조용히 분석되는 것을 막는다).
| 모듈 | 작업 파일 | 배포 번호 | 비고 |
|---|---|---|---|
| spatial_prep | `spatial_prep.1.1.R` | 1.1 | 2.0의 1.0에 스크립트 규칙(로그 분리, output_dir 필수, 흰 배경 그림) 적용 |
| spatial_cluster | `spatial_cluster.1.1.R` | 1.1 | 같음 |
| spatial_svf | `spatial_svf.1.1.R` | 1.1 | 같음. bx_spatial 1.1(ape) 필요 |
| spatial_merge | `spatial_merge.1.2.R` | 1.1 | harmony 인자 수정(작업 1.1) + 규칙 적용, 이전 결과 정리 |
| spatial_labelTransfer | `spatial_labelTransfer.1.2.R` | 1.1 | 규칙 적용. 참조가 없으면 건너뜀(작업 1.2). Seurat 5에서 참조 SCT 모델로 다시 정규화가 멈추던 문제와 작은 참조의 k.weight 오류 수정 |
| spatial_rctd | `spatial_rctd.1.2.R` | 1.1 | 규칙 적용. 참조가 없으면 건너뜀(작업 1.2). max_cores 기본값 auto. 그려지지 않던 dominant 세포 유형 그림 수정 |
| check_reference | `check_reference.1.1.R` | 1.1 | output_dir(로그, reference_columns.tsv) 추가 |
| spatial_condition_de | `spatial_condition_de.1.4.R` | 1.0 | 새 모듈. Visium과 Visium HD 입력. 앞 모듈이 건너뛰면 같이 건너뜀 |
| spatial_hd_prep | `spatial_hd_prep.1.1.R` | 1.0 | 새 모듈 |
| spatial_hd_cluster | `spatial_hd_cluster.1.1.R` | 1.0 | 새 모듈 |
| spatial_hd_svf | `spatial_hd_svf.1.0.R` | 1.0 | 새 모듈 |
| spatial_hd_rctd | `spatial_hd_rctd.1.2.R` | 1.0 | 새 모듈. 참조가 없으면 건너뜀 |

실행 명령은 모두 `Rscript <스크립트> key=value ...`이다.

## 1. spatial_prep
슬라이스마다 Space Ranger 결과를 불러와 spot을 거르고 SCTransform으로 정규화한다.
자원(코어, 메모리): 8코어, 32GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 하위 폴더 하나. 각 폴더에 `outs/`(또는 `filtered_feature_bc_matrix.h5`와 `spatial/`). 하위 폴더 이름이 슬라이스 이름. 슬라이스 하나의 outs를 직접 줘도 됨 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `<slice>/<slice>_prep.rds`, `<slice>/plots/` |
| Option | `h5_filename` | String | 선택 | `filtered_feature_bc_matrix.h5` | 슬라이스 폴더에서 찾을 h5 파일 이름 |
| Option | `min_counts` | Integer | 선택 | `0` | UMI 수가 이보다 적은 spot 제거. 0이면 거르지 않음 |
| Option | `feature_genes` | String | 선택 | | 조직 위에 그릴 유전자(쉼표 구분). 비우면 그리지 않음 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 2. spatial_cluster
슬라이스마다 PCA, 군집, UMAP, 군집 마커를 계산한다.
자원(코어, 메모리): 8코어, 32GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_prep.rds`(SCT assay가 있는 Seurat 객체) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `<slice>/<slice>_clustered.rds`, 군집 요약, 마커 표, `plots/` |
| Option | `resolution` | Float | 선택 | `0.8` | 군집 해상도. 클수록 군집이 많음 |
| Option | `npcs` | Integer | 선택 | `30` | 사용할 주성분 수 |
| Option | `marker_topn` | Integer | 선택 | `5` | 군집마다 그림에 넣는 마커 수 |
| Option | `marker_min_pct` | Float | 선택 | `0.25` | 마커 검정 최소 발현 비율 |
| Option | `marker_logfc` | Float | 선택 | `0.25` | 마커 검정 최소 log fold change |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 3. spatial_svf
슬라이스마다 공간적으로 몰려 발현하는 유전자(spatially variable features)를 찾는다.
자원(코어, 메모리): 8코어, 32GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds` |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `<slice>/<slice>_svf.rds`, `<slice>_svf_<method>.csv`(rank, gene), `plots/` |
| Option | `svf_method` | List (`moransi`, `markvariogram`) | 선택 | `moransi` | 공간 자기상관 방법 |
| Option | `svf_topn` | Integer | 선택 | `1000` | 검정할 가변 유전자 수 |
| Option | `svf_show` | Integer | 선택 | `6` | 조직 위에 그릴 상위 유전자 수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 4. spatial_merge
슬라이스 객체를 하나로 합쳐 다시 차원 축소와 군집을 해서, 군집 번호가 슬라이스 사이에서 같은 뜻이 되게 한다.
자원(코어, 메모리): 8코어, 64GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds`(또는 input_dir 바로 아래 `*_clustered.rds`) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `merged/merged_clustered.rds`, 군집×슬라이스 표, 마커 표, `merged/plots/`, `merge_report.txt` |
| Option | `integration` | List (`none`, `harmony`) | 선택 | `none` | 슬라이스 보정. harmony = Harmony로 슬라이스 차이 보정 |
| Option | `npcs` | Integer | 선택 | `30` | 사용할 주성분 수 |
| Option | `resolution` | Float | 선택 | `0.8` | 군집 해상도 |
| Option | `assay` | String | 선택 | `SCT` | 합칠 assay |
| Option | `features` | String | 선택 | | 조직 위에 그릴 유전자(쉼표 구분). 비우면 그리지 않음 |
| Option | `marker_topn` | Integer | 선택 | `5` | 군집마다 그림에 넣는 마커 수 |
| Option | `marker_min_pct` | Float | 선택 | `0.25` | 마커 검정 최소 발현 비율 |
| Option | `marker_logfc` | Float | 선택 | `0.25` | 마커 검정 최소 log fold change |
| Option | `plot_width` | Float | 선택 | `8` | 그림 너비(inch) |
| Option | `plot_height` | Float | 선택 | `6` | 그림 높이(inch) |
| Option | `dpi` | Integer | 선택 | `300` | 그림 해상도 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 5. spatial_condition_de
조건(예: control, treated) 사이에서 군집 조성과 군집별 유전자 발현을 비교한다. Visium(spatial_merge 결과)과 Visium HD(spatial_hd_cluster 결과)를 모두 받는다.
자원(코어, 메모리): 8코어, 64GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | Visium: `merged/merged_clustered.rds`(또는 input_dir 바로 아래). Visium HD: `hd_slides.tsv`와 슬라이드별 `<slide>/<slide>_hd_clustered.rds` |
| Input | `sample_data` | File (CSV) | 필수 | | 슬라이스 시트. 열: `SliceID`(객체의 슬라이스 이름 = 입력 폴더 이름), `Condition`, 선택 `Patient`(짝 설계) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `group_by` | String | 선택 | `seurat_clusters` | 안에서 비교할 spot 묶음의 메타데이터 열(군집 또는 세포 유형 열) |
| Option | `reference` | String | 선택 | | 기준 조건. 비우면 sample_data의 첫 Condition |
| Option | `min_spots` | Integer | 선택 | `20` | 군집 안 spot이 이보다 적은 슬라이스는 그 군집 검정에서 뺌 |
| Option | `min_slices` | Integer | 선택 | `2` | pseudobulk 검정에 필요한 조건별 슬라이스 수 |
| Option | `padj_cutoff` | Float | 선택 | `0.05` | 유의 유전자 보정 p값 기준 |
| Option | `lfc_cutoff` | Float | 선택 | `0.5` | 유의 유전자 log2FC 절대값 기준 |
| Option | `top_genes` | Integer | 선택 | `20` | volcano 이름 표시와 log2FC heatmap 유전자 수(군집마다) |
| Option | `spatial_genes` | Integer | 선택 | `6` | 조직 위에 그릴 상위 유전자 수 |
| Option | `spot_level` | List (`auto`, `no`) | 선택 | `auto` | auto = 슬라이스가 부족한 군집은 spot 단위 Wilcoxon(탐색용), no = 건너뜀 |
| Option | `spot_level_max` | Integer | 선택 | `3000` | spot 단위 검정에 쓰는 슬라이스·군집당 최대 spot(bin) 수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

결과: `01_composition/`, `02_de/de_<test>_vs_<reference>.tsv`, `03_plots/`, `04_summary/de_summary.tsv`, `logs/`. `input_dir`에 `skipped.txt`가 있으면(앞의 세포 유형 모듈이 참조 없이 건너뜀) 비교도 건너뛰고 `skipped.txt`를 남긴다.

## 6. spatial_hd_prep
Visium HD 슬라이드를 bin 크기(8·16µm)로 불러와 거르고 정규화한 뒤 sketch(대표 bin 표본)를 만든다.
자원(코어, 메모리): 8코어, 64GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이드마다 하위 폴더 하나. 각 폴더에 `binned_outputs/`(또는 `outs/binned_outputs/`)와 그 안의 `square_<NNN>um/filtered_feature_bc_matrix.h5`, `spatial/` |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `<slide>/<slide>_hd_prep.rds`, `<slide>/plots/`, `hd_prep_summary.tsv` |
| Option | `bin_size` | List (`8`, `16`) | 선택 | `8` | bin 크기(µm). 2µm는 지원하지 않음 |
| Option | `min_counts` | Integer | 선택 | `10` | UMI 수가 이보다 적은 bin 제거 |
| Option | `min_features` | Integer | 선택 | `0` | 검출 유전자 수가 이보다 적은 bin 제거. 0이면 거르지 않음 |
| Option | `nfeatures` | Integer | 선택 | `2000` | 슬라이드별 가변 유전자 수 |
| Option | `sketch_cells` | Integer | 선택 | `50000` | 슬라이드마다 sketch에 남기는 bin 수 |
| Option | `pt_size` | Float | 선택 | `4` | 조직 QC 그림의 bin 크기 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 7. spatial_hd_cluster
모든 슬라이드의 sketch를 합쳐 군집을 만들고, 각 슬라이드의 모든 bin에 군집을 붙인다.
자원(코어, 메모리): 8코어, 128GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이드마다 `<slide>/<slide>_hd_prep.rds`(bin assay `Spatial.<NNN>um`과 `sketch` assay) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `joint/`, 슬라이드별 `<slide>_hd_clustered.rds`와 `plots/`, `hd_slides.tsv` |
| Option | `dims` | Integer | 선택 | `30` | 사용할 주성분 수 |
| Option | `resolution` | Float | 선택 | `0.8` | 군집 해상도 |
| Option | `integration` | List (`auto`, `harmony`, `none`) | 선택 | `auto` | auto = 슬라이드 2장 이상이면 harmony |
| Option | `nfeatures` | Integer | 선택 | `2000` | 합친 sketch의 가변 유전자 수 |
| Option | `k_transfer` | Integer | 선택 | `10` | 각 bin의 군집을 정할 때 보는 가까운 sketch bin 수 |
| Option | `marker_min_pct` | Float | 선택 | `0.25` | 마커 검정 최소 발현 비율 |
| Option | `marker_logfc` | Float | 선택 | `0.25` | 마커 검정 최소 log fold change |
| Option | `marker_topn` | Integer | 선택 | `5` | 군집마다 dot plot에 넣는 마커 수 |
| Option | `features` | String | 선택 | | 조직 위에 그릴 유전자(쉼표 구분). 비우면 그리지 않음 |
| Option | `pt_size` | Float | 선택 | `4` | 조직 그림의 bin 크기 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 8. check_reference
단일세포 참조 자료(Seurat RDS)의 메타데이터 열을 살펴 세포 유형 열(reference_label_col) 후보를 알려 준다.
자원(코어, 메모리): 4코어, 64GB (큰 참조 RDS를 통째로 읽는다)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `reference_rds` | File (RDS) | 필수 | | 단일세포 참조 자료(Seurat 객체) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `reference_columns.tsv`, `logs/` |

## 9. spatial_labelTransfer
단일세포 참조의 세포 유형을 Visium spot으로 옮겨 spot마다 세포 유형별 예측 점수를 계산한다(Seurat anchor).
자원(코어, 메모리): 8코어, 128GB (참조 전체로 anchor를 찾아 큰 참조에서 메모리가 가장 많이 든다)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds`(SCT assay와 pca) |
| Input | `reference_rds` | File (RDS) | 선택 | | 단일세포 참조 자료(Seurat 객체). 비우면 건너뜀(`skipped.txt`) |
| Option | `reference_label_col` | String | 선택 | | 참조의 세포 유형 열 이름. **참조를 주면 반드시 입력.** 비었거나 틀리면 후보 열을 보여 주고 멈춤 (CLOSHA에는 조건부 필수가 없어 선택으로 등록) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. 슬라이스별 `<slice>_labeltransfer.rds`, `<slice>_predicted_celltype_scores.csv`, `plots/`, `summary/` |
| Option | `reference_ncells` | Integer | 선택 | `3000` | 참조 SCTransform 모델을 맞출 때 쓰는 세포 수(참조에 SCT 모델이 없을 때만) |
| Option | `npcs` | Integer | 선택 | `30` | anchor 탐색과 예측에 쓰는 주성분 수 |
| Option | `min_shared_features` | Integer | 선택 | `200` | 참조와 슬라이스의 최소 공유 유전자 수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 10. spatial_rctd
RCTD(spacexr, full 모드)로 Visium spot마다 세포 유형 비율(weight)을 추정한다.
자원(코어, 메모리): 8코어, 64GB (코어마다 자료를 복사해 코어 수만큼 메모리가 는다)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds`(raw count assay `Spatial`) |
| Input | `reference_rds` | File (RDS) | 선택 | | 단일세포 참조 자료(raw count와 세포 유형 열). 비우면 건너뜀(`skipped.txt`) |
| Option | `reference_label_col` | String | 선택 | | 참조의 세포 유형 열 이름. **참조를 주면 반드시 입력.** 비었거나 틀리면 후보 열을 보여 주고 멈춤 (CLOSHA에는 조건부 필수가 없어 선택으로 등록) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. 슬라이스별 `<slice>_rctd.rds`, `_rctd_object.rds`, `_rctd_weights.csv`, `_rctd_mean_abundance.csv`, `plots/`, `summary/` |
| Option | `spatial_assay` | String | 선택 | `Spatial` | 슬라이스 객체의 raw count assay |
| Option | `reference_assay` | String | 선택 | `RNA` | 참조 객체의 raw count assay |
| Option | `max_cores` | String | 선택 | `auto` | 병렬 코어 수. auto = 할당 코어 수, 숫자는 할당 코어 수로 제한 |
| Option | `min_shared_features` | Integer | 선택 | `200` | 참조와 슬라이스의 최소 공유 유전자 수 |
| Option | `min_cells_per_type` | Integer | 선택 | `25` | 세포 수가 이보다 적은 참조 세포 유형은 뺌 |
| Option | `plot_topn` | Integer | 선택 | `12` | 조직 위 weight 그림에 넣는 상위 세포 유형 수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 11. spatial_hd_svf
Visium HD 슬라이드마다 무작위 bin 표본으로 Moran's I를 계산해 공간 가변 유전자를 찾는다.
자원(코어, 메모리): 8코어, 64GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | spatial_hd_cluster 결과 폴더(`hd_slides.tsv`와 슬라이드별 객체) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. 슬라이드별 `<slide>_hd_svf.tsv`와 `plots/`, `svf_all_slides.tsv`, `svf_summary.tsv` |
| Option | `svf_topn` | Integer | 선택 | `500` | 슬라이드마다 검정할 가변 유전자 수 |
| Option | `max_bins` | Integer | 선택 | `4000` | Moran's I에 쓰는 무작위 bin 수(계산량은 제곱) |
| Option | `svf_show` | Integer | 선택 | `6` | 조직 위에 그릴 상위 유전자 수 |
| Option | `padj_cutoff` | Float | 선택 | `0.05` | 공간 가변 유전자 보정 p값(BH) 기준 |
| Option | `pt_size` | Float | 선택 | `4` | 조직 그림의 bin 크기 |
| Option | `seed` | Integer | 선택 | `1234` | bin 표본 난수 시드 |

## 12. spatial_hd_rctd
Visium HD의 모든 bin에 RCTD(spacexr)로 단일세포 참조의 세포 유형을 붙인다.
자원(코어, 메모리): 8코어, 128GB (코어마다 자료를 복사해 코어 수만큼 메모리가 는다)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | spatial_hd_cluster 결과 폴더(`hd_slides.tsv`와 슬라이드별 객체, bin assay에 raw count) |
| Input | `reference_rds` | File (RDS) | 선택 | | 단일세포 참조 자료(raw count와 세포 유형 열). 비우면 건너뜀(`skipped.txt`) |
| Option | `reference_label_col` | String | 선택 | | 참조의 세포 유형 열 이름. **참조를 주면 반드시 입력.** 비었거나 틀리면 후보 열을 보여 주고 멈춤 (CLOSHA에는 조건부 필수가 없어 선택으로 등록) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. 슬라이드별 `<slide>_hd_rctd.rds`, `_rctd_weights.tsv.gz`, `plots/`, `hd_slides.tsv`, `celltype_by_slide.tsv`, `rctd_summary.tsv` |
| Option | `reference_assay` | String | 선택 | `RNA` | 참조 객체의 raw count assay |
| Option | `rctd_mode` | List (`doublet`, `full`) | 선택 | `doublet` | doublet = bin마다 세포 유형 1~2개(8µm), full = 섞인 비율(16µm) |
| Option | `chunk_bins` | Integer | 선택 | `20000` | RCTD 한 번에 넣는 bin 수 |
| Option | `umi_min` | Integer | 선택 | `100` | UMI 수가 이보다 적은 bin은 계산하지 않음(not_scored) |
| Option | `min_cells_per_type` | Integer | 선택 | `25` | 세포 수가 이보다 적은 참조 세포 유형은 뺌 |
| Option | `min_shared_features` | Integer | 선택 | `200` | 참조와 슬라이드의 최소 공유 유전자 수 |
| Option | `max_cores` | String | 선택 | `auto` | 병렬 코어 수. auto = 할당 코어 수, 숫자는 할당 코어 수로 제한 |
| Option | `pt_size` | Float | 선택 | `4` | 조직 그림의 bin 크기 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

결과 폴더는 spatial_condition_de의 `input_dir`로 쓸 수 있다(`group_by=rctd_first_type`).

## 13. 권장 자원
포탈 선택값(코어 1/4/8/16, 메모리 8~128GB) 안에서 넉넉하게 잡은 값이다(사용자 결정, 2026-10-27). 모듈마다 위 "자원" 줄에도 적었다.

| 모듈 | 코어 | 메모리 | 비고 |
|---|---|---|---|
| spatial_prep | 8 | 32GB |  |
| spatial_cluster | 8 | 32GB |  |
| spatial_svf | 8 | 32GB |  |
| spatial_merge | 8 | 64GB |  |
| spatial_condition_de | 8 | 64GB |  |
| spatial_labelTransfer | 8 | 128GB | 참조 전체로 anchor를 찾아 큰 참조에서 메모리가 가장 많이 든다 |
| spatial_rctd | 8 | 64GB | 코어마다 자료를 복사해 코어 수만큼 메모리가 는다 |
| spatial_hd_prep | 8 | 64GB |  |
| spatial_hd_cluster | 8 | 128GB |  |
| spatial_hd_svf | 8 | 64GB |  |
| spatial_hd_rctd | 8 | 128GB | 코어마다 자료를 복사해 코어 수만큼 메모리가 는다 |
| check_reference | 4 | 64GB | 큰 참조 RDS를 통째로 읽는다 |

근거와 한계:
- 여러 코어를 실제로 쓰는 모듈은 spatial_rctd, spatial_hd_rctd뿐이다(`max_cores=auto`). 나머지는 병렬 설정이 없어 사실상 1코어지만, 공간 전사체 작업 기준에 맞춰 8코어로 통일했다. 결과에는 영향이 없다. rctd 두 모듈은 코어마다 자료를 복사하므로 16코어로 올리지 않았다(128GB를 넘길 수 있음).
- Codespace 테스트는 줄인 데이터(유전자 6,000개, spot 축소, 1코어)와 510세포 예제 참조로 했다. 최대 메모리는 대부분 2~4GB였다(hd_rctd 3.7GB, hd_svf 2.0GB, condition_de 2.0GB).
- 실제 참조(수만~수십만 세포)와 8µm는 측정하지 않았다. 참조 모듈은 `readRDS`로 참조 전체를 올리고, labelTransfer는 참조 전체로 anchor를 찾는다. RCTD는 세포 유형마다 최대 1만 세포만 쓴다(spacexr `n_max_cells` 기본값). CLOSHA에서 `sacct`의 MaxRSS, Elapsed, TotalCPU로 실측한 뒤 이 표를 고친다.

## 14. CLOSHA 테스트 (2026-10-27)
테스트에는 작업 파일 이름을 그대로 쓴다. 배포 이름(위 표의 배포 번호)으로 바꾸는 것은 배포 때 한다. 실행 이미지는 `bx_spatial.1.1`이다.

예제 데이터:
| 용도 | 데이터 | 폴더 구조 |
|---|---|---|
| Visium | 10x Mouse Brain Sagittal 4장: `V1_Mouse_Brain_Sagittal_Anterior`, `_Anterior_Section_2`, `_Posterior`, `_Posterior_Section_2` (https://cf.10xgenomics.com/samples/spatial-exp/1.1.0/, 각각 `*_filtered_feature_bc_matrix.h5`, `*_spatial.tar.gz`) | `/data/visium/<slice>/filtered_feature_bc_matrix.h5`, `/data/visium/<slice>/spatial/` |
| Visium HD | 10x Visium HD Mouse Brain (https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_binned_outputs.tar.gz). 슬라이드가 1장이라, 조건 비교를 보려면 4등분해 4장으로 쓴다(Codespace 테스트와 같은 방식) | `/data/hd/<slide>/binned_outputs/square_016um/...` |
| 참조 | `hippocampus_reference.rds`: spacexr 예제로 만든 Seurat 객체, 세포 510개, 세포 유형 열 `celltype`. Codespace 사본 `/workspaces/.closha_build_test/spatial_rerun/inputs/hippocampus_reference.rds` | |

슬라이스 정보 CSV:
```
# Visium
SliceID,Condition
sec1_anterior,section1
sec1_posterior,section1
sec2_anterior,section2
sec2_posterior,section2

# Visium HD
SliceID,Condition
brain_left_top,left
brain_left_bottom,left
brain_right_top,right
brain_right_bottom,right
```

실행 예:
```bash
# Visium
Rscript spatial_prep.1.1.R    input_dir=/data/visium output_dir=/out/prep
Rscript spatial_cluster.1.1.R input_dir=/out/prep    output_dir=/out/cluster
Rscript spatial_svf.1.1.R     input_dir=/out/cluster output_dir=/out/svf
Rscript spatial_merge.1.2.R   input_dir=/out/cluster output_dir=/out/merge integration=harmony
Rscript spatial_condition_de.1.4.R input_dir=/out/merge sample_data=/data/visium_slices.csv output_dir=/out/de reference=section1
Rscript spatial_labelTransfer.1.2.R input_dir=/out/cluster output_dir=/out/labeltransfer \
        reference_rds=/data/hippocampus_reference.rds reference_label_col=celltype min_shared_features=100
Rscript spatial_rctd.1.2.R input_dir=/out/cluster output_dir=/out/rctd \
        reference_rds=/data/hippocampus_reference.rds reference_label_col=celltype min_shared_features=100

# Visium HD
Rscript spatial_hd_prep.1.1.R    input_dir=/data/hd output_dir=/out/hd_prep bin_size=16
Rscript spatial_hd_cluster.1.1.R input_dir=/out/hd_prep output_dir=/out/hd_cluster features=Prox1,Mbp
Rscript spatial_condition_de.1.4.R input_dir=/out/hd_cluster sample_data=/data/hd_slides.csv output_dir=/out/hd_de reference=left
Rscript spatial_hd_svf.1.0.R  input_dir=/out/hd_cluster output_dir=/out/hd_svf
Rscript spatial_hd_rctd.1.2.R input_dir=/out/hd_cluster output_dir=/out/hd_rctd \
        reference_rds=/data/hippocampus_reference.rds reference_label_col=celltype min_shared_features=100
Rscript spatial_condition_de.1.4.R input_dir=/out/hd_rctd sample_data=/data/hd_slides.csv \
        output_dir=/out/hd_de_celltype reference=left group_by=rctd_first_type

# 보조
Rscript check_reference.1.1.R reference_rds=/data/hippocampus_reference.rds output_dir=/out/check_reference
```
`min_shared_features=100`은 이 예제 참조(공유 유전자 268개)에만 쓴다. 실제 참조는 기본값 200으로 둔다.

확인할 것:
1. 참조 입력을 비운 파이프라인 실행이 정상 완료되는지(세 모듈과 세포 유형 기준 condition_de에 `skipped.txt`)
2. `reference_label_col`을 비우거나 틀리게 넣었을 때 오류 로그에 후보 열이 나오는지
3. hd_rctd 기본값(doublet)으로 결과가 나오는지(Codespace는 full만 확인)
4. 원본 크기 데이터의 시간과 메모리(`sacct -j <작업번호> --format=JobName,AllocCPUS,Elapsed,TotalCPU,MaxRSS`). 13절 값을 이것으로 고친다.
5. 규모 확인: 510세포 예제 참조는 동작 확인용이다. 실제 규모 참조로 한 번 더 돌린다(중간 규모: Seurat 공간 안내의 Allen 피질 참조 `allen_cortex.rds`, 약 1만 4천 세포, 세포 유형 열 `subclass`. 큰 규모: 쥐 뇌 10만 세포 이상 참조).
