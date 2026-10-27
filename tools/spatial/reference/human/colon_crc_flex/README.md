# 사람 대장암 단일세포 참조 (human_colon_crc_flex_300pertype.rds)

Visium HD 예제(사람 대장암, 종양 3장 vs 정상 2장)의 세포 유형 모듈(spatial_hd_rctd, spatial_labelTransfer, spatial_rctd)에 쓰는 참조다. 같은 연구의 단일세포 자료라 HD 예제와 환자·조직이 맞는다.

## 무엇인가
| 항목 | 값 |
|---|---|
| 형식 | Seurat 객체(.rds), assay `RNA`(raw count + log 정규화) |
| 크기 | 세포 10,333개, 유전자 18,082개(Chromium Human Transcriptome Probe Set v1.0.1), 약 50MB |
| 세포 유형 열 | `Level1`(9종: Tumor, Fibroblast, Smooth Muscle, Myeloid, T cells, B cells, Endothelial, Neuronal, Intestinal Epithelial), `Level2`(38종: Tumor I~V, CAF, CD4/CD8 T cell, Plasma, Goblet 등) |
| 다른 열 | `Patient`(P1CRC, P2CRC, P3CRC, P4CRC, P5CRC, P2NAT, P3NAT, P5NAT) |
| 뽑은 방법 | 저자 QC 통과(`QCFilter == Keep`) 세포 26만 개 중 `Level2` 유형마다 최대 300개(seed 1234) |

## 출처
- 논문: Oliveira, M.F. et al. High-definition spatial transcriptomic profiling of immune cell populations in colorectal cancer. Nat Genet (2025). https://doi.org/10.1038/s41588-025-02193-3
- count: 10x 공개 자료 `HumanColonCancer_Flex_Multiplex` (Chromium Flex, cellranger 8.0.0)
  https://cf.10xgenomics.com/samples/cell-exp/8.0.0/HumanColonCancer_Flex_Multiplex/HumanColonCancer_Flex_Multiplex_count_filtered_feature_bc_matrix.h5
- 세포 유형: 저자 저장소 `10XGenomics/HumanColonCancer_VisiumHD`(MIT)의 `MetaData/SingleCell_MetaData.csv.gz`
- 포탈 예제로 올리기 전에 10x 공개 자료 이용 조건을 확인한다.

## 만드는 법 (bx_spatial 이미지 안에서)
```bash
wget -O flex.h5 https://cf.10xgenomics.com/samples/cell-exp/8.0.0/HumanColonCancer_Flex_Multiplex/HumanColonCancer_Flex_Multiplex_count_filtered_feature_bc_matrix.h5
wget -O SingleCell_MetaData.csv.gz https://raw.githubusercontent.com/10XGenomics/HumanColonCancer_VisiumHD/main/MetaData/SingleCell_MetaData.csv.gz
Rscript make_reference.R flex.h5 SingleCell_MetaData.csv.gz human_colon_crc_flex_300pertype.rds
```
Codespace(메모리 약 3GB)에서 1분 안에 만들어졌다(2026-10-27). rds는 git에 넣지 않는다(`.gitignore`).

## 쓰는 법
| 구분 | 이름 | 값 |
|---|---|---|
| Input | reference_rds | `human_colon_crc_flex_300pertype.rds` |
| Option | reference_label_col | `Level1`(큰 분류, 예제 기본) 또는 `Level2`(세밀한 분류) |

`min_shared_features`는 기본값(200)으로 둔다. HD와 같은 probe set이라 공유 유전자가 충분하다.
