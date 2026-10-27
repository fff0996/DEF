# 공간 전사체 예제 참조 (reference.rds)

세포 유형 모듈(spatial_labelTransfer, spatial_rctd, spatial_hd_rctd)과 check_reference의 테스트·예제용 단일세포 참조다. **동작 확인용**이며, 실제 분석이나 규모 확인에는 쓰지 않는다.

## 무엇인가
| 항목 | 값 |
|---|---|
| 형식 | Seurat 객체(.rds), assay `RNA`(raw count + log 정규화) |
| 크기 | 세포 510개, 유전자 307개, 282KB |
| 세포 유형 열 | `celltype` (17종 × 30세포) |
| 세포 유형 | Astrocyte, CA1, CA3, Cajal_Retzius, Choroid, Denate, Endothelial_Stalk, Endothelial_Tip, Entorihinal, Ependymal, Interneuron, Microglia_Macrophages, Mural, Neurogenesis, Neuron.Slc17a6, Oligodendrocyte, Polydendrocyte |
| 다른 메타데이터 열 | `orig.ident`(16개 반복 시료), `nCount_RNA`, `nFeature_RNA` |
| 종, 조직 | 쥐 해마와 주변 조직 |

## 출처
- spacexr(RCTD) 패키지에 들어 있는 예제 참조 `inst/extdata/Reference/Visium_Ref`(counts.csv, cell_types.csv), commit `9f5dc33c8060f946c6072a138b70e189636e1435`. 라이선스 GPL-3.0.
- 세포 이름(`P60HippoRep6P2_...`) 형식으로 보아 DropViz 쥐 뇌 단일세포 자료(Saunders et al., 2018, Cell)의 P60 해마 세포를 세포 유형마다 30개씩 뽑은 것으로 보인다. spacexr 저장소에는 출처가 따로 적혀 있지 않다.
- `make_reference.R`로 두 CSV를 Seurat 객체로 바꿨다(CreateSeuratObject, NormalizeData, `celltype` 열 추가). 같은 과정이 `tools/spatial/run_spatial_ref_test.sh` 안에도 있다.

## 쓰는 법
| 구분 | 이름 | 값 |
|---|---|---|
| Input | reference_rds | `reference.rds` |
| Option | reference_label_col | `celltype` |
| Option | min_shared_features | `100` (유전자가 307개뿐이라 공유 유전자가 약 268개) |

## 한계
- 유전자 307개, 유형마다 30세포라 결과 그림은 모양만 확인하는 용도다.
- 해마 참조라서 피질이 많은 슬라이스(Visium anterior 등)는 비슷한 해마 유형으로 칠해진다.
- 실제 규모(수만 세포 이상) 테스트는 별도 참조로 한다(`docs/Spatial_Transcriptomics_Visium_Pipeline/modules/Registration.md`, `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/Registration.md`의 CLOSHA 테스트 절).
