# 공간 전사체 예제 입력

CLOSHA 테스트와 포탈 예제에 쓰는 입력 정리. 모듈별 입력값은 `docs/Spatial_Transcriptomics_Visium_Pipeline/modules/Registration.md`, `docs/Spatial_Transcriptomics_Visium_HD_Pipeline/modules/Registration.md`의 CLOSHA 테스트 절.

## 예제 데이터 (10x Genomics 공개 자료)
| 파이프라인 | 데이터 | 조건 | 참조 |
|---|---|---|---|
| Visium | **사람 심장 8장**: 정상 4장(P1, P7, P8, P17) / 심근경색 허혈 구역(IZ) 4장(P3, P10, P15, P16) (Kuppe et al., Nature 2022, Zenodo 6580069, CC BY 4.0) | **control vs ischemic** (실제 비교, 조건마다 4장) | 같은 연구 단일핵 RNA-seq로 만들 예정(아직 없음). 그 전에는 참조 없이 돌린다(세포 유형 모듈은 건너뜀) |
| Visium HD | **사람 대장암 FFPE 5장**: 종양 P1, P2, P5 / 정상 인접 조직 P3, P5 (Oliveira et al., Nat Genet 2025) | **tumor vs normal** (실제 비교, 조건마다 2장 이상) | `../reference/human/colon_crc_flex/`(같은 연구 단일세포 10,333개, `Level1`/`Level2`) |

이전 Visium 예제(쥐 뇌 4장, section1 vs section2)는 조건이 연속 절편이라 비교에 의미가 없어 바꿨다(2026-10-27). 쥐 해마 참조 `../reference/reference.rds`는 동작 확인용으로 남긴다.

## 파일
| 파일 | 쓰는 곳 |
|---|---|
| `visium_slices.csv` | Visium spatial_condition_de `sample_data` (`reference=control`) |
| `download_visium_mi.sh` | Visium 심장 8장 받기(wget, tar, unzip; 지정 폴더에만 씀) |
| `hd_slides.csv` | Visium HD spatial_condition_de `sample_data` (`reference=normal`) |
| `download_hd_crc.sh` | HD 대장암 5장 받기(wget + tar, 지정 폴더에만 씀) |
| `split_hd_slide.R` | (예전 HD 예제용) 쥐 뇌 HD 1장을 4등분. 대장암 예제에는 필요 없다 |

## Visium 받기
```bash
bash download_visium_mi.sh <BASE>/visium_mi
```
- 약 4.8GB를 내려받고 슬라이스마다 h5와 `spatial/`만 남긴다(약 0.3GB).
- 압축 안의 h5 이름(`spatial_<id>_filtered_feature_bc_matrix.h5`)을 `filtered_feature_bc_matrix.h5`로 바꾸고, `spatial` zip은 저자 컴퓨터 경로가 들어 있어 경로 없이(`unzip -j`) 푼다.
- 결과: `<BASE>/visium_mi/{ctrl_p1,ctrl_p7,ctrl_p8,ctrl_p17,iz_p3,iz_p10,iz_p15,iz_p16}/`. spatial_prep `input_dir`은 `<BASE>/visium_mi`.
- 슬라이스 1장(ctrl_p17)으로 spatial_prep이 돌아가는 것을 확인했다(36,601 유전자 × 2,049 spot, 2026-10-27).

## Visium HD 받기
```bash
bash download_hd_crc.sh <BASE>/hd_crc            # 16µm만
bash download_hd_crc.sh <BASE>/hd_crc "008 016"  # 8µm도
```
- 슬라이드마다 압축 10~17GB(5장 약 67GB)를 내려받지만, 고른 bin 폴더만 디스크에 풀린다(2µm는 풀지 않음).
- 결과: `<BASE>/hd_crc/{crc_p1,crc_p2,crc_p5,normal_p3,normal_p5}/binned_outputs/square_016um/`
- spatial_hd_prep의 `input_dir`은 `<BASE>/hd_crc`.
- 압축 파일 경로 구조(`binned_outputs/square_NNNum/...`)는 2026-10-27에 확인했다. 전체 받기는 Codespace 용량 때문에 해 보지 않았다.

## 참조
- 쥐(Visium): `../reference/reference.rds`, 저장소에 있다.
- 사람 대장암(HD): `../reference/human/colon_crc_flex/README.md`의 명령으로 만든다(50MB라 git에 넣지 않음). Codespace에서 만든 사본: `_incoming/spatial_test/human_colon_crc_flex_300pertype.rds`.

## 볼 것
- Visium 심장: 경색 부위에서 심근세포 영역이 줄고 섬유화·면역 영역이 늘어나는 조성 변화, 군집별 차등 발현. 조건마다 4장이라 pseudobulk(DESeq2)로 검정된다.
- HD 대장암: 종양과 정상의 군집 조성 차이(종양 상피, CAF, 면역세포 영역), 군집별·세포 유형별 차등 발현. 조건마다 2장 이상이라 pseudobulk(DESeq2) 경로로 검정된다. P5는 종양과 정상이 같은 환자지만 다른 환자는 한쪽만 있어 짝 설계(`Patient`)는 쓰지 않는다.
