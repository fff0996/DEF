Visium HD 공간 전사체 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22, 갱신: 2026-10-27 (세포 유형 가지, 자원, CLOSHA 테스트 예제)

CLOSHA에 Visium HD 파이프라인 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/Spatial_Transcriptomics_Analysis_Pipeline/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 실행 이미지는 모두 `bx_spatial.1.1`(`defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def`)이다. 1.0에는 svf의 Moran's I에 필요한 ape가 없어 1.1에서 더했다.

등록 메모:
- 받은 스크립트(prep, cluster, svf, merge, labelTransfer, rctd, check_reference)는 CLOSHA 2.0에 배포된 것이다. 배포 번호는 고친 스크립트만 2.0 번호 + 1이고, 이번에 모두 스크립트 규칙에 맞춰 고쳐 1.1이다. 새 모듈은 1.0이다(아래 표).
- 받은 스크립트의 규칙 차이(경고가 stdout으로 나감, `logs/`의 .log/.error.log 분리 없음, output_dir 기본값 `./bx_spatial_out`, merge가 이전 결과를 지우지 않음, 투명 배경 그림)는 새 버전에서 고쳤다(2026-10-22).

## 0. 파이프라인 흐름
```
Visium HD (bin 8·16µm):
  Space Ranger HD 슬라이드 폴더들 ─> [spatial_hd_prep] ─output_dir─> [spatial_hd_cluster] ─output_dir─┬─> [spatial_condition_de]
                                                                                                    ├─> [spatial_hd_svf]
                                                                                                    └─> [spatial_hd_rctd] (참조가 있을 때) ─output_dir─> [spatial_condition_de] (group_by=rctd_first_type)

참조 확인(보조): 단일세포 참조 RDS ─> [check_reference] (reference_label_col로 쓸 열 확인)
```

세포 유형 모듈(hd_rctd)은 파이프라인 안에 두고, 참조는 파이프라인의 선택 입력(`reference_rds`, `reference_label_col`)으로 받는다(사용자 결정, 2026-10-27).
- 참조를 주지 않으면 hd_rctd는 `output_dir/skipped.txt`를 남기고 정상 종료한다. 그 결과를 받는 spatial_condition_de도 같은 방식으로 건너뛴다.
- CLOSHA 입력은 필수/선택 둘뿐이라 `reference_rds`와 `reference_label_col` 모두 선택으로 등록한다. 참조를 주면 `reference_label_col`도 필요하다. 비었거나 참조에 없는 열이면 참조를 읽은 직후 멈추고, 세포 유형 후보 열(범주 2~100개)과 첫 범주들을 오류 로그에 보여 준다. 사용자가 확인하고 열 이름을 넣어 다시 실행한다. 자동으로 고르지 않는다(틀린 열로 조용히 분석되는 것을 막는다).

| 모듈 | 작업 파일 | 배포 번호 | 비고 |
|---|---|---|---|
| check_reference | `check_reference.1.1.R` | 1.1 | output_dir(로그, reference_columns.tsv) 추가 |
| spatial_condition_de | `spatial_condition_de.1.4.R` | 1.0 | 새 모듈. Visium과 Visium HD 입력. 앞 모듈이 건너뛰면 같이 건너뜀 |
| spatial_hd_prep | `spatial_hd_prep.1.1.R` | 1.0 | 새 모듈 |
| spatial_hd_cluster | `spatial_hd_cluster.1.1.R` | 1.0 | 새 모듈 |
| spatial_hd_svf | `spatial_hd_svf.1.1.R` | 1.0 | 새 모듈. 1.1: 그림·요약표의 상위 유전자를 Moran's I 순으로 고름(1.0은 정렬 전 유의 표시로 골라 상위가 아니었음) |
| spatial_hd_rctd | `spatial_hd_rctd.1.2.R` | 1.0 | 새 모듈. 참조가 없으면 건너뜀 |

실행 명령은 모두 `Rscript <스크립트> key=value ...`이다.

## 1. spatial_hd_prep
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

## 2. spatial_hd_cluster
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

## 3. spatial_hd_svf
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

## 4. spatial_condition_de
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

## 5. spatial_hd_rctd
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
| Option | `pt_size` | Float | 선택 | `4` | 조직 그림의 bin 크기 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

결과 폴더는 spatial_condition_de의 `input_dir`로 쓸 수 있다(`group_by=rctd_first_type`).

## 6. check_reference
단일세포 참조 자료(Seurat RDS)의 메타데이터 열을 살펴 세포 유형 열(reference_label_col) 후보를 알려 준다.
자원(코어, 메모리): 4코어, 64GB (큰 참조 RDS를 통째로 읽는다)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `reference_rds` | File (RDS) | 필수 | | 단일세포 참조 자료(Seurat 객체) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. `reference_columns.tsv`, `logs/` |

## 7. 권장 자원
포탈 선택값(코어 1/4/8/16, 메모리 8~128GB) 안에서 넉넉하게 잡은 값이다(사용자 결정, 2026-10-27). 모듈마다 위 "자원" 줄에도 적었다.

| 모듈 | 코어 | 메모리 | 비고 |
|---|---|---|---|
| spatial_condition_de | 8 | 64GB |  |
| spatial_hd_prep | 8 | 64GB |  |
| spatial_hd_cluster | 8 | 128GB |  |
| spatial_hd_svf | 8 | 64GB |  |
| spatial_hd_rctd | 8 | 128GB | 코어마다 자료를 복사해 코어 수만큼 메모리가 는다 |
| check_reference | 4 | 64GB | 큰 참조 RDS를 통째로 읽는다 |

근거와 한계:
- 여러 코어를 실제로 쓰는 모듈은 spatial_rctd, spatial_hd_rctd뿐이다. 두 스크립트의 `max_cores`는 CLOSHA에 등록하지 않는다(사용자 결정, 2026-10-27): 기본값 `auto`가 할당된 코어 수(`nproc`)만큼 작업자를 만들고, 코어 수는 자원 선택 하나로 정한다. 메모리가 모자라면 코어 수를 낮춘다(작업자마다 자료를 복사). 나머지는 병렬 설정이 없어 사실상 1코어지만, 공간 전사체 작업 기준에 맞춰 8코어로 통일했다. 결과에는 영향이 없다. rctd 두 모듈은 코어마다 자료를 복사하므로 16코어로 올리지 않았다(128GB를 넘길 수 있음).
- Codespace 테스트는 줄인 데이터(유전자 6,000개, spot 축소, 1코어)와 510세포 예제 참조로 했다. 최대 메모리는 대부분 2~4GB였다(hd_rctd 3.7GB, hd_svf 2.0GB, condition_de 2.0GB).
- 실제 참조(수만~수십만 세포)와 8µm는 측정하지 않았다. 참조 모듈은 `readRDS`로 참조 전체를 올리고, labelTransfer는 참조 전체로 anchor를 찾는다. RCTD는 세포 유형마다 최대 1만 세포만 쓴다(spacexr `n_max_cells` 기본값). CLOSHA에서 `sacct`의 MaxRSS, Elapsed, TotalCPU로 실측한 뒤 이 표를 고친다.

## 8. CLOSHA 테스트 (2026-10-27)
테스트에는 작업 파일 이름을 그대로 쓴다. 배포 이름(위 표의 배포 번호)으로 바꾸는 것은 배포 때 한다. 실행 이미지는 `bx_spatial.1.1`이다.

예제 데이터와 받는 법은 `tools/spatial/example/README.md`에 있다(사용자 결정, 2026-10-27: Visium은 사람 심장 8장, Visium HD는 사람 대장암 5장으로 예제를 바꿈).
| 용도 | 데이터 | 폴더 구조 |
|---|---|---|
| Visium HD | 10x 사람 대장암 FFPE 5장: 종양 P1, P2, P5, 정상 인접 P3, P5. `tools/spatial/example/download_hd_crc.sh`로 받는다 | `$BASE/hd_crc/<slide>/binned_outputs/square_016um/...` |
| 참조(HD) | `human_colon_crc_flex_300pertype.rds`: 같은 연구 단일세포 10,333개, 열 `Level1`(9종), `Level2`(38종). `tools/spatial/reference/human/colon_crc_flex/`의 명령으로 만든다 | |

슬라이스 정보 CSV(`tools/spatial/example/`):
```
# hd_slides.csv
SliceID,Condition
crc_p1,tumor
crc_p2,tumor
crc_p5,tumor
normal_p3,normal
normal_p5,normal
```

실행 예:
```bash
# Visium HD (사람 대장암)
Rscript spatial_hd_prep.1.1.R    input_dir=$BASE/hd_crc output_dir=$BASE/out/hd_prep bin_size=16
Rscript spatial_hd_cluster.1.1.R input_dir=$BASE/out/hd_prep output_dir=$BASE/out/hd_cluster features=EPCAM,PTPRC,COL1A1
Rscript spatial_condition_de.1.4.R input_dir=$BASE/out/hd_cluster sample_data=$BASE/hd_slides.csv output_dir=$BASE/out/hd_de reference=normal
Rscript spatial_hd_svf.1.1.R  input_dir=$BASE/out/hd_cluster output_dir=$BASE/out/hd_svf
Rscript spatial_hd_rctd.1.2.R input_dir=$BASE/out/hd_cluster output_dir=$BASE/out/hd_rctd \
        reference_rds=$BASE/human_colon_crc_flex_300pertype.rds reference_label_col=Level1
Rscript spatial_condition_de.1.4.R input_dir=$BASE/out/hd_rctd sample_data=$BASE/hd_slides.csv \
        output_dir=$BASE/out/hd_de_celltype reference=normal group_by=rctd_first_type

# 보조
Rscript check_reference.1.1.R reference_rds=$BASE/human_colon_crc_flex_300pertype.rds output_dir=$BASE/out/check_reference
```
HD 예제를 바꿨으므로 모듈 원고의 HD 결과 그림(hd_prep, hd_cluster, hd_svf, hd_rctd, condition_de)은 마우스 뇌 결과다. CLOSHA에서 대장암으로 돌린 결과로 바꾼다.

확인할 것:
1. 참조 입력을 비운 파이프라인 실행이 정상 완료되는지(hd_rctd와 세포 유형 기준 condition_de에 `skipped.txt`)
2. `reference_label_col`을 비우거나 틀리게 넣었을 때 오류 로그에 후보 열이 나오는지
3. hd_rctd 기본값(doublet)으로 결과가 나오는지(Codespace는 full만 확인)
4. 원본 크기 데이터의 시간과 메모리(`sacct -j <작업번호> --format=JobName,AllocCPUS,Elapsed,TotalCPU,MaxRSS`). 7절 값을 이것으로 고친다.
5. 로그 첫머리의 코어 수가 할당 코어 수와 같은지 본다: hd_rctd `max_cores used = N (allocated N)`. 노드 전체 코어 수가 나오면 `SLURM_CPUS_PER_TASK`를 먼저 보도록 스크립트를 고친다.
6. 규모 확인: 510세포 예제 참조는 동작 확인용이다. 실제 규모 참조로 한 번 더 돌린다(중간 규모: Seurat 공간 안내의 Allen 피질 참조 `allen_cortex.rds`, 약 1만 4천 세포, 세포 유형 열 `subclass`. 큰 규모: 쥐 뇌 10만 세포 이상 참조).
