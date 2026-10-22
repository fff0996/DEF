Spatial transcriptomics 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22

CLOSHA에 공간 전사체 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/Spatial_Transcriptomics_Analysis_Pipeline/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 실행 이미지는 모두 `bx_spatial.1.1`(`defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def`)이다. 1.0에는 svf의 Moran's I에 필요한 ape가 없어 1.1에서 더했다.

등록 메모:
- 받은 스크립트(prep, cluster, svf, merge, labelTransfer, rctd, check_reference)는 CLOSHA 2.0에 배포된 것이다. 배포 번호는 고친 스크립트만 2.0 번호 + 1이고, 고치지 않은 스크립트는 2.0 번호 그대로다: spatial_merge 1.1(harmony 수정), 나머지 받은 스크립트 1.0. 새 모듈(spatial_condition_de, spatial_hd_prep, spatial_hd_cluster)은 배포 1.0이다(spatial_condition_de 작업 1.1 → 배포 1.0).
- spatial_labelTransfer, spatial_rctd, check_reference는 단일세포 참조 자료로 Codespace 실행 확인을 한 뒤 이 문서와 원고에 넣는다.
- 받은 스크립트는 `docs/CLOSHA_Script_Rules_v1.md`와 다른 점이 있다(경고가 stdout으로 나감, `logs/`의 .log/.error.log 분리 없음, output_dir 기본값 `./bx_spatial_out`, merge는 이전 결과를 지우지 않음). `docs/Spatial_Transcriptomics_Analysis_Pipeline/Spatial_Notes.md` 4절.

## 0. 파이프라인 흐름
```
Visium (spot 55µm):
  Space Ranger 슬라이스 폴더들 ─> [spatial_prep] ─output_dir─> [spatial_cluster] ─output_dir─┬─> [spatial_svf]
                                                                                            └─> [spatial_merge] ─output_dir─> [spatial_condition_de]

Visium HD (bin 8·16µm):
  Space Ranger HD 슬라이드 폴더들 ─> [spatial_hd_prep] ─output_dir─> [spatial_hd_cluster] ─output_dir─> [spatial_condition_de]
```
| 모듈 | 스크립트 | 실행 명령 | 비고 |
|---|---|---|---|
| spatial_prep | `spatial_prep.1.0.R` | `Rscript spatial_prep.1.0.R key=value ...` | 받은 스크립트 |
| spatial_cluster | `spatial_cluster.1.0.R` | `Rscript spatial_cluster.1.0.R key=value ...` | 받은 스크립트 |
| spatial_svf | `spatial_svf.1.0.R` | `Rscript spatial_svf.1.0.R key=value ...` | 받은 스크립트 |
| spatial_merge | `spatial_merge.1.1.R` | `Rscript spatial_merge.1.1.R key=value ...` | 받은 스크립트 1.0에서 harmony 인자 수정 |
| spatial_condition_de | `spatial_condition_de.1.1.R` | `Rscript spatial_condition_de.1.1.R key=value ...` | 새 모듈. Visium과 Visium HD 입력 모두 받음 |
| spatial_hd_prep | `spatial_hd_prep.1.0.R` | `Rscript spatial_hd_prep.1.0.R key=value ...` | 새 모듈 |
| spatial_hd_cluster | `spatial_hd_cluster.1.0.R` | `Rscript spatial_hd_cluster.1.0.R key=value ...` | 새 모듈 |

## 1. spatial_prep
슬라이스마다 Space Ranger 결과를 불러와 spot을 거르고 SCTransform으로 정규화한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 하위 폴더 하나. 각 폴더에 `outs/`(또는 `filtered_feature_bc_matrix.h5`와 `spatial/`). 하위 폴더 이름이 슬라이스 이름. 슬라이스 하나의 outs를 직접 줘도 됨 |
| Output | `output_dir` | Directory | 필수 | (스크립트 기본 `./bx_spatial_out`) | 결과 폴더. `<slice>/<slice>_prep.rds`, `<slice>/plots/` |
| Option | `h5_filename` | String | 선택 | `filtered_feature_bc_matrix.h5` | 슬라이스 폴더에서 찾을 h5 파일 이름 |
| Option | `min_counts` | Integer | 선택 | `0` | UMI 수가 이보다 적은 spot 제거. 0이면 거르지 않음 |
| Option | `feature_genes` | String | 선택 | | 조직 위에 그릴 유전자(쉼표 구분). 비우면 그리지 않음 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 2. spatial_cluster
슬라이스마다 PCA, 군집, UMAP, 군집 마커를 계산한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_prep.rds`(SCT assay가 있는 Seurat 객체) |
| Output | `output_dir` | Directory | 필수 | (스크립트 기본 `./bx_spatial_out`) | 결과 폴더. `<slice>/<slice>_clustered.rds`, 군집 요약, 마커 표, `plots/` |
| Option | `resolution` | Float | 선택 | `0.8` | 군집 해상도. 클수록 군집이 많음 |
| Option | `npcs` | Integer | 선택 | `30` | 사용할 주성분 수 |
| Option | `marker_topn` | Integer | 선택 | `5` | 군집마다 그림에 넣는 마커 수 |
| Option | `marker_min_pct` | Float | 선택 | `0.25` | 마커 검정 최소 발현 비율 |
| Option | `marker_logfc` | Float | 선택 | `0.25` | 마커 검정 최소 log fold change |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 3. spatial_svf
슬라이스마다 공간적으로 몰려 발현하는 유전자(spatially variable features)를 찾는다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds` |
| Output | `output_dir` | Directory | 필수 | (스크립트 기본 `./bx_spatial_out`) | 결과 폴더. `<slice>/<slice>_svf.rds`, `<slice>_svf_<method>.csv`(rank, gene), `plots/` |
| Option | `svf_method` | List (`moransi`, `markvariogram`) | 선택 | `moransi` | 공간 자기상관 방법 |
| Option | `svf_topn` | Integer | 선택 | `1000` | 검정할 가변 유전자 수 |
| Option | `svf_show` | Integer | 선택 | `6` | 조직 위에 그릴 상위 유전자 수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 4. spatial_merge
슬라이스 객체를 하나로 합쳐 다시 차원 축소와 군집을 해서, 군집 번호가 슬라이스 사이에서 같은 뜻이 되게 한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 슬라이스마다 `<slice>/<slice>_clustered.rds`(또는 input_dir 바로 아래 `*_clustered.rds`) |
| Output | `output_dir` | Directory | 필수 | (스크립트 기본 `./bx_spatial_out`) | 결과 폴더. `merged/merged_clustered.rds`, 군집×슬라이스 표, 마커 표, `merged/plots/`, `merge_report.txt` |
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

결과: `01_composition/`, `02_de/de_<test>_vs_<reference>.tsv`, `03_plots/`, `04_summary/de_summary.tsv`, `logs/`.

## 6. spatial_hd_prep
Visium HD 슬라이드를 bin 크기(8·16µm)로 불러와 거르고 정규화한 뒤 sketch(대표 bin 표본)를 만든다.

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

## 8. 권장 자원
`Spatial_Notes.md` 5절(Visium)과 6절(Visium HD)을 따른다. 8µm는 사용자가 CLOSHA에서 실측한다.
