# CLOSHA 3.0 Visium HD 공간 전사체 배포 (2026-11-03)

Visium HD 공간 전사체 파이프라인(`Spatial_Transcriptomics_Visium_HD_Pipeline`)의 두 번째 배포입니다. 뒷단 분석 모듈 3개를 새로 배포합니다. 2026-11-02~03에 CLOSHA에서 사람 대장암 Visium HD 5장(첫 배포와 같은 데이터)으로 테스트를 마쳤습니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 첫 배포(`../2026-10-28/`)의 모듈 6개는 바뀌지 않았고 그 폴더 파일을 그대로 씁니다.

## 배포 스크립트

세 모듈 모두 CLOSHA 3.0에서 새로 생긴 모듈이라 배포 번호는 1.0입니다. 작업 파일도 1.0이고 변경 이력이 없어 그대로 복사했습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 |
|---|---|---|---|---|
| spatial_niche | `spatial_niche.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_niche.1.0.R` | bx_spatial 1.2 |
| spatial_signature_score | `spatial_signature_score.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_signature_score.1.0.R` | bx_spatial 1.2 |
| spatial_de_enrichment | `spatial_de_enrichment.1.0.R` | (3.0 신규) | `scripts/Spatial_Transcriptomics_Analysis_Pipeline/spatial_de_enrichment.1.0.R` | bx_spatial 1.2 |

- 작업 파일 기준 커밋: `e4486a2`. 파이프라인 그림과 원고는 포탈 등록 전 같은 날 다시 복사했습니다(check_reference를 점선으로 잇지 않고 따로 실행하는 노드로 바꿈, BIO-EXPRESS 로고 뺌, 행 순서를 CLOSHA 캔버스와 같게: svf 위, 세포 유형 줄·niche·signature_score 아래). 스크립트는 바뀌지 않았습니다.
- 실행 이미지: 새 모듈 3개는 `bx_spatial 1.2`를 씁니다(`docs/bx_spatial.1.2.def`, 저장소 `defs/Spatial_Transcriptomics_Analysis_Pipeline/bx_spatial.1.2.def`). 1.2는 1.1에 msigdbr 7.5.1(MSigDB 7.5.1 유전자 세트 내장, 실행 중 인터넷 불필요)과 fgsea 1.28.0을 더한 이미지입니다. 첫 배포 모듈 6개는 1.1에 그대로 둡니다. 다음 공간 배포 때 기존 모듈을 1.2에서 확인한 뒤 이미지를 하나로 합칩니다.
- 카테고리: spatial_niche는 Clustering / Spatial_Clustering, spatial_signature_score는 Statistics_and_Visualization / Spatial_Omics, spatial_de_enrichment는 Statistics_and_Visualization / Functional_Analysis(신규)입니다.
- 실행 순서(파이프라인에 붙는 곳):
  - spatial_niche: spatial_hd_rctd 뒤. 세포 유형(`rctd_first_type`)으로 이웃 구성을 셉니다. 참조가 없어 hd_rctd가 건너뛰면 같이 건너뜁니다.
  - spatial_signature_score: spatial_hd_cluster(또는 spatial_hd_rctd) 뒤.
  - spatial_de_enrichment: spatial_condition_de 뒤. 군집 기준, 세포 유형 기준 비교 각각에 붙습니다. 앞 비교가 건너뛰면 같이 건너뜁니다.

## 자원 (CLOSHA 등록값)

| 모듈 | 코어 | 메모리 | CLOSHA 실측(대장암 5장, 16µm) |
|---|---|---|---|
| spatial_niche | 1 | 64GB | 약 2분 (세포 유형 입력, bin 51만 7천 개) |
| spatial_signature_score | 1 | 64GB | 약 5분 (8세트) |
| spatial_de_enrichment | 1 | 32GB | 약 10초 (사용자 세트 5개) |

세 모듈 모두 병렬 처리가 없어 1코어로 등록합니다. 근거는 `docs/Registration.md` 7절과 9~11절입니다.

## CLOSHA 테스트 (2026-11-02~03, 사용자 실행)

- 데이터: 첫 배포와 같은 사람 대장암 Visium HD FFPE 5장(종양 3, 정상 2), 16µm bin, 참조 단일세포(`Level1`, 9종). 앞 모듈 결과(hd_cluster, hd_rctd, condition_de)에 이어서 실행했습니다.
- 예제 유전자 세트: `docs/example/crc_gene_sets.gmt`(CAF, T_CYTOTOXIC, T_EXHAUSTION, INTESTINAL_STEM, PLASMA_CELL). signature_score에는 기본 Hallmark 3세트와 함께, de_enrichment 결과 1~2에는 이 5세트만(`min_size=5`), 결과 3~4에는 세포 유형 비교에 Hallmark 50세트를 썼습니다.
- 모든 모듈이 정상 완료됐고, 원고의 결과 그림과 범례 수치가 이 실행 결과입니다. 결과는 생물학적으로 맞았습니다(종양에서 면역 니치 약 2배, CAF 점수가 종양 기질에서만 높음, 종양 세포에서 MYC/E2F 증가).
- 테스트 중 고친 것: spatial_niche 니치 이름에 두 번째 세포 유형(20% 이상)을 함께 붙임(번호는 그대로 1.0, 사용자 결정). 고친 뒤 다시 실행한 결과를 원고에 넣었습니다.
- Codespace 확인: bx_spatial 1.2 SIF(fakeroot 빌드, `%test` 통과)에서 쥐 뇌 Visium HD로 세 모듈과 건너뛰기 경로를 확인했습니다(`docs/Registration.md` 12절).

## 알려진 한계 (다음 배포에서 다룸)

- 포탈에서 선택 File 입력(niche·signature_score의 `sample_data`, signature_score·de_enrichment의 `gene_sets`)에 한 번 파일을 넣으면 비울 수 없습니다(플랫폼 문제, 업체에 수정 요청). 모듈을 캔버스에서 지우고 다시 놓으면 초기화됩니다.
- spatial_signature_score의 기본 제공 세트는 Hallmark만 고를 수 있습니다(KEGG, Reactome, GO는 spatial_de_enrichment의 `collection`).
- 아직 CLOSHA에서 확인하지 않은 경로: sample_data 없이 niche·signature_score 실행, Visium(spot) 입력.
- 첫 배포 모듈의 1.2 이미지 실행 확인(이미지 통합 전 필요). spatial_hd_rctd는 Codespace 메모리로는 확인할 수 없어 CLOSHA에서 확인합니다.

## 만든 방법과 확인

- `build_release.py`가 작업 파일을 배포 파일로 복사하고, 원고, 포탈 이미지, 파이프라인 그림, DEF, 예제 유전자 세트도 복사합니다.
- `python3 tools/check_release.py release/CLOSHA3/Spatial_Transcriptomics_Visium_HD_Pipeline/2026-11-03`로 배포 파일이 작업 파일과 같은지 확인했습니다. 3개 모두 일치합니다.
- `release.tsv`는 같은 대응표를 기계가 읽는 형식으로 둔 것입니다.

## 함께 넣은 것

- `docs/`: 배포 시점의 모듈 원고(`Portal_Content.md`, `.docx`, 모듈 9개 전체), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`, 3.2절 bx_spatial 1.2), DEF(`bx_spatial.1.2.def`), 예제 유전자 세트(`example/crc_gene_sets.gmt`)
- `docs/pipeline/`: 파이프라인 페이지 원고(`Portal_Content.md`, `.docx`), 새 모듈을 넣은 분석 흐름 그림(`pipeline.png`, 원본 `pipeline.svg`). 개념 그림과 대표 이미지는 바뀌지 않아 첫 배포 폴더의 것을 씁니다.
- `portal_images/`: 새 모듈 3개의 포탈 PNG와 바뀐 분석 흐름 그림(`pipeline/pipeline.png`), `portal_images.zip`
- `results/`: 배포본으로 실행한 결과를 올리는 곳(올릴 파일 목록은 `results/README.md`)
