# CLOSHA 3.0 Visium HD 공간 전사체 배포 (2026-10-28)

Visium HD 공간 전사체 파이프라인(`Spatial_Transcriptomics_Visium_HD_Pipeline`)의 CLOSHA 3.0 첫 배포입니다. 2026-10-27~28에 CLOSHA에서 사람 대장암 Visium HD 5장으로 테스트를 마친 뒤 배포를 확정했습니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 다음 배포는 새 날짜 폴더로 만듭니다.

## 배포 스크립트

배포 번호는 CLOSHA 2.0 운영 번호 + 1이고, 3.0에서 새로 생긴 모듈은 1.0입니다. 새 모듈은 맨 위 주석에 첫 배포라는 한 줄과 작업 번호가 있고, check_reference는 CLOSHA 2.0 대비 변경이 있습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 |
|---|---|---|---|---|
| spatial_hd_prep | `spatial_hd_prep.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_hd_prep.1.1.R` | bx_spatial 1.1 |
| spatial_hd_cluster | `spatial_hd_cluster.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_hd_cluster.1.1.R` | bx_spatial 1.1 |
| spatial_hd_svf | `spatial_hd_svf.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_hd_svf.1.1.R` | bx_spatial 1.1 |
| spatial_condition_de | `spatial_condition_de.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_condition_de.1.4.R` | bx_spatial 1.1 |
| spatial_hd_rctd | `spatial_hd_rctd.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_hd_rctd.1.2.R` | bx_spatial 1.1 |
| check_reference | `check_reference.1.1.R` | 1.0 | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/check_reference.1.1.R` | bx_spatial 1.1 |

- 작업 파일 기준 커밋: `ce6ccbf` (스크립트). 원고와 포탈 이미지는 포탈 등록 전 같은 날 `4704db3` 기준으로 다시 복사했습니다(샘플시트를 포탈 칸 여섯 개 형식으로, 자원 안내를 사용자가 바꿀 수 있는 옵션으로 고침, 참조 열 이름은 파이프라인 전에 check_reference로 확인하도록 안내, 파이프라인 모식도에 check_reference를 점선 사전 확인으로 추가). 스크립트는 바뀌지 않았습니다.
- 실행 이미지: 모든 모듈이 `bx_spatial 1.1` 하나를 씁니다(`defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.1.def`). spatial_hd_prep과 spatial_hd_cluster 사용 예제 주석에는 `bx_spatial.1.0.sif`로 적혀 있지만, 1.1은 1.0에 ape만 더한 이미지라 그대로 실행됩니다.
- spatial_condition_de와 check_reference는 Visium 파이프라인(`Spatial_Transcriptomics_Visium_Pipeline`, 별도 배포 예정)도 같이 쓰는 모듈입니다. 이 배포로 등록한 모듈을 그대로 씁니다.
- 실행 순서: spatial_hd_prep → spatial_hd_cluster → (spatial_hd_svf, spatial_condition_de[군집 기준], spatial_hd_rctd) → spatial_condition_de[세포 유형 기준, `group_by=rctd_first_type`]. 단일세포 참조(`reference_rds`)를 주지 않으면 spatial_hd_rctd와 세포 유형 기준 비교는 `skipped.txt`를 남기고 건너뜁니다. check_reference는 참조의 세포 유형 열을 미리 확인하는 보조 모듈입니다.

## 자원 (CLOSHA 등록값)

| 모듈 | 코어 | 메모리 | CLOSHA 실측(대장암 5장, 16µm): 시간 / 최대 메모리 |
|---|---|---|---|
| spatial_hd_prep | 4 | 64GB | 17분 / 12.2GB |
| spatial_hd_cluster | 4 | 64GB | 36분 / 31.2GB |
| spatial_hd_svf | 4 | 64GB | 4분 / 15.1GB |
| spatial_condition_de | 4 | 64GB | 5분 / 16.0GB |
| spatial_hd_rctd | 8 | 64GB | 4시간 10분 / 17.5GB |
| check_reference | 4 | 64GB | (실행하지 않음) |

실측은 8코어 할당으로 잰 `sacct` 값입니다. hd_rctd 말고는 병렬 처리가 없어 실제로 1코어만 썼습니다(사용자 결정으로 4코어 등록, 2026-10-28). 자세한 근거는 `docs/Registration.md` 7절에 있습니다.

## CLOSHA 테스트 (2026-10-27~28, 사용자 실행)

- 데이터: 사람 대장암 Visium HD FFPE 5장(종양 crc_p1, crc_p2, crc_p5 / 정상 normal_p3, normal_p5; Oliveira et al., Nat Genet 2025), 16µm bin. 참조는 같은 연구의 단일세포 10,333개(`Level1`, 9종).
- 위 작업 파일로 실행했습니다(배포 파일과 내용이 같음). 모든 모듈이 정상 완료됐고, 원고의 결과 그림과 범례 수치가 이 실행 결과입니다.
- 테스트 중 고친 것: spatial_hd_rctd 1.1(첫 세포 유형 가중치 색인 오류), spatial_condition_de 1.3(라벨이 빈 spot 처리), spatial_hd_svf 1.1(그림·요약표의 상위 유전자를 Moran's I 순으로 고름).

## 알려진 한계 (다음 배포에서 다룸)

- spatial_condition_de의 조직 위 유전자 그림(`03_plots/spatial_<gene>.png`)은 전체 군집에서 보정 p가 작은 순으로 유전자를 고릅니다. spot 단위 탐색 검정(spot_level_wilcoxon) 군집이 있으면 p값이 지나치게 작아 그 군집 유전자가 주로 뽑힙니다. 표와 다른 그림에는 영향이 없습니다.
- spatial_hd_prep QC violin의 x축 눈금에 "S"가 표시됩니다(표시만의 문제).
- 아직 CLOSHA에서 확인하지 않은 경로: 참조 없이 실행(건너뛰기), `reference_label_col`을 비우거나 틀리게 넣었을 때 후보 열 안내, 8µm bin.

## 만든 방법과 확인

- `build_release.py`가 작업 파일에서 배포 파일을 만듭니다. 새 모듈은 맨 위 변경 이력을 "CLOSHA 3.0 첫 배포" 한 줄로 바꾸고, 파일 안의 자기 이름을 배포 이름으로 바꿉니다. 다른 줄은 바꾸지 않습니다. check_reference는 그대로 복사합니다. 원고, 포탈 이미지, 파이프라인 그림도 이 스크립트가 복사합니다.
- `python3 tools/check_release.py release/CLOSHA3/Spatial_Transcriptomics_Visium_HD_Pipeline/2026-10-28`로 배포 파일이 작업 파일과 (맨 위 주석과 파일 이름을 빼고) 같은지 확인했습니다. 6개 모두 일치합니다.
- `release.tsv`는 같은 대응표를 기계가 읽는 형식으로 둔 것입니다.

## 함께 넣은 것

- `docs/`: 배포 시점의 모듈 원고(`Portal_Content.md`, `.docx`), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`)
- `docs/pipeline/`: 파이프라인 페이지 원고(`Portal_Content.md`, `.docx`), 분석 흐름·개념 그림(PNG, 원본 SVG), 대표 이미지(`thumbnail.png`)
- `portal_images/`: 포탈에 올리는 PNG(모듈별, 파이프라인)
- `results/`: 배포본으로 실행한 결과를 올리는 곳(올릴 파일 목록은 `results/README.md`)
