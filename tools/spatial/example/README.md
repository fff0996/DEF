# 공간 전사체 예제 입력

CLOSHA 테스트와 포탈 예제에 쓰는 입력 정리. 모듈별 입력값은 `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/Registration.md` 14절.

## 예제 데이터 (10x Genomics 공개 자료)
| 파이프라인 | 데이터 | 조건 | 참조 |
|---|---|---|---|
| Visium | 쥐 뇌 시상 절편 4장(Section 1, 2 × Anterior, Posterior). 신선 동결 | section1 vs section2 (테스트용, 같은 뇌의 연속 절편) | `../reference/reference.rds`(쥐 해마 510세포, `celltype`) |
| Visium HD | **사람 대장암 FFPE 5장**: 종양 P1, P2, P5 / 정상 인접 조직 P3, P5 (Oliveira et al., Nat Genet 2025) | **tumor vs normal** (실제 비교, 조건마다 2장 이상) | `../reference/human/colon_crc_flex/`(같은 연구 단일세포 10,333개, `Level1`/`Level2`) |

Visium 4장 구성: 뇌가 capture area보다 커서 한 절편을 앞(Anterior: 대뇌피질, 후각망울, 선조체)과 뒤(Posterior: 해마, 소뇌, 중뇌)로 나눠 찍었고, 이런 절편 2벌이다.

## 파일
| 파일 | 쓰는 곳 |
|---|---|
| `visium_slices.csv` | Visium spatial_condition_de `sample_data` (`reference=section1`) |
| `hd_slides.csv` | Visium HD spatial_condition_de `sample_data` (`reference=normal`) |
| `download_hd_crc.sh` | HD 대장암 5장 받기(wget + tar, 지정 폴더에만 씀) |
| `split_hd_slide.R` | (예전 HD 예제용) 쥐 뇌 HD 1장을 4등분. 대장암 예제에는 필요 없다 |

## Visium 받기
```bash
mkdir -p visium/sec1_anterior visium/sec2_anterior visium/sec1_posterior visium/sec2_posterior
U=https://cf.10xgenomics.com/samples/spatial-exp/1.1.0
for p in sec1_anterior:V1_Mouse_Brain_Sagittal_Anterior sec2_anterior:V1_Mouse_Brain_Sagittal_Anterior_Section_2 \
         sec1_posterior:V1_Mouse_Brain_Sagittal_Posterior sec2_posterior:V1_Mouse_Brain_Sagittal_Posterior_Section_2; do
  d=visium/${p%%:*}; s=${p#*:}
  wget -O $d/filtered_feature_bc_matrix.h5 $U/$s/${s}_filtered_feature_bc_matrix.h5
  wget -O $d/spatial.tar.gz $U/$s/${s}_spatial.tar.gz
  tar -xzf $d/spatial.tar.gz -C $d --no-same-owner && rm $d/spatial.tar.gz
done
```

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
- Visium: 조건이 테스트용이라 파이프라인이 끝까지 도는지만 본다.
- HD 대장암: 종양과 정상의 군집 조성 차이(종양 상피, CAF, 면역세포 영역), 군집별·세포 유형별 차등 발현. 조건마다 2장 이상이라 pseudobulk(DESeq2) 경로로 검정된다. P5는 종양과 정상이 같은 환자지만 다른 환자는 한쪽만 있어 짝 설계(`Patient`)는 쓰지 않는다.
