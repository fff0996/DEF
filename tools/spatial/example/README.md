# 공간 전사체 예제 입력

CLOSHA 테스트와 포탈 예제에 쓰는 입력 정리. 모듈별 입력값은 `docs/Spatial_Transcriptomics_Analysis_Pipeline/modules/Registration.md` 14절.

## 예제 데이터 (모두 쥐 뇌, 10x Genomics 공개 자료)
| 데이터 | 내용 | 받는 곳 |
|---|---|---|
| Visium | 성체 쥐 뇌 시상(sagittal) 절편 2벌(Section 1, 2). 뇌가 capture area보다 커서 한 절편을 앞(Anterior: 대뇌피질, 후각망울, 선조체)과 뒤(Posterior: 해마, 소뇌, 중뇌)로 나눠 찍었다. 4장 = 2벌 × 앞뒤. 신선 동결, Space Ranger 1.1 | https://cf.10xgenomics.com/samples/spatial-exp/1.1.0/V1_Mouse_Brain_Sagittal_{Anterior,Anterior_Section_2,Posterior,Posterior_Section_2}/ |
| Visium HD | 쥐 뇌 FFPE 절편 1장. 2µm bin과 이를 묶은 8·16µm bin | https://cf.10xgenomics.com/samples/spatial-exp/3.0.0/Visium_HD_Mouse_Brain/Visium_HD_Mouse_Brain_binned_outputs.tar.gz |
| 참조 | 쥐 해마 단일세포 510개(17 유형). `../reference/` | 저장소 |

## 파일
| 파일 | 쓰는 곳 |
|---|---|
| `visium_slices.csv` | Visium 파이프라인의 spatial_condition_de `sample_data` (`reference=section1`) |
| `hd_slides.csv` | Visium HD 파이프라인의 spatial_condition_de `sample_data` (`reference=left`) |
| `split_hd_slide.R` | HD 슬라이드 1장을 조직 위치로 4등분(brain_left_top, brain_left_bottom, brain_right_top, brain_right_bottom) |

## 조건은 테스트용이다
- Visium `section1` vs `section2`: 같은 뇌의 연속 절편 두 벌이라 생물학적 차이가 없다.
- HD `left` vs `right`: 한 절편의 좌우 반쪽이다. 조건마다 2장씩이라 pseudobulk 검정 경로까지 돌아간다.
- 두 경우 모두 유의 유전자가 나와도 의미는 없다. 파이프라인이 끝까지 도는지만 본다.

## HD 4등분 만들기 (bx_spatial 이미지 안에서)
```bash
Rscript split_hd_slide.R <받은 폴더>/binned_outputs/square_016um <BASE>/hd_split          # 16µm, 모든 유전자
Rscript split_hd_slide.R <받은 폴더>/binned_outputs/square_008um <BASE>/hd_split          # 8µm도 쓸 때
```
- 원본은 읽기만 하고 `<BASE>/hd_split/brain_<위치>/binned_outputs/square_NNNum/`에만 쓴다.
- spatial_hd_prep의 `input_dir`은 `<BASE>/hd_split`.
- 세 번째 인자로 유전자 수를 줄일 수 있다(Codespace 테스트는 메모리 때문에 6000). 16µm 6000 유전자 결과: 22,477 / 26,981 / 26,981 / 22,478 bin, 318MB(2026-10-27 확인).
