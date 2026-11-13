# CLOSHA 3.0 scGPT 배포 (2026-11-11)

scGPT 표현형 분류 파이프라인(`scGPT_Phenotype_Classification_Pipeline`)은 CLOSHA 3.0에서 처음 배포하는 파이프라인입니다. 사전학습 단일세포 모델 scGPT 0.2.4(whole-human 체크포인트)를 고정한 채로 세포 임베딩을 만들고, 그 위에 개체 단위 분류 모델을 학습·예측·비교합니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 다음 배포는 새 날짜 폴더로 만듭니다.

## 배포 스크립트

CLOSHA 3.0 신규 파이프라인이므로 다섯 모듈 모두 1.0입니다. 작업 파일도 1.0으로 고정해 고쳐 왔으므로 배포 파일은 작업 파일과 같습니다. 각 파일 맨 위 주석에 모듈이 하는 일이 있습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 | 실행 환경 |
|---|---|---|---|---|---|
| scgpt_prep | `scgpt_prep.1.0.py` | (3.0 신규) | `scripts/scGPT/scgpt_prep.1.0.py` | bx_scgpt 1.0 (`defs/scGPT/bx_scgpt.1.0.def`) | CPU |
| scgpt_embed | `scgpt_embed.1.0.py` | (3.0 신규) | `scripts/scGPT/scgpt_embed.1.0.py` | bx_scgpt_gpu 1.0 (`defs/scGPT/bx_scgpt_gpu.1.0.def`) | **GPU** |
| scgpt_train | `scgpt_train.1.0.py` | (3.0 신규) | `scripts/scGPT/scgpt_train.1.0.py` | bx_scgpt 1.0 | CPU |
| scgpt_predict | `scgpt_predict.1.0.py` | (3.0 신규) | `scripts/scGPT/scgpt_predict.1.0.py` | bx_scgpt 1.0 | CPU |
| scgpt_compare | `scgpt_compare.1.0.py` | (3.0 신규) | `scripts/scGPT/scgpt_compare.1.0.py` | bx_scgpt 1.0 | CPU |

- 작업 파일 기준 커밋: `c2615e3`
- 파이프라인 연결: scgpt_prep → scgpt_embed → scgpt_train, scgpt_predict, scgpt_compare. train의 output_dir는 predict의 `model`, compare의 `models` 포트에 잇습니다.
- 포탈 등록: 이름 `scGPT_Phenotype_Classification_Pipeline`, 분류 Bio-AI / Single_Cell_Foundation_Model. 모듈 카테고리는 Preprocessing / Data_Preparation(prep), Preprocessing / Embedding(embed), Classification / Sample_Classification(train, predict, compare).

## 이번 배포에 들어간 주요 결정과 수정

- 인자: `key=value`, `--key=value`, `--key value`를 모두 받습니다(CLOSHA가 Python 모듈에 `--key value`로 넘김).
- scgpt_embed: 세포가 약 8,000개 이상일 때 UMAP 단계가 멈추던 문제를 고쳤습니다(neighbors 계산을 sklearn으로).
- scgpt_train: `standardize` 옵션(기본 yes)을 더했습니다. 학습 개체의 평균 임베딩으로 차원마다 평균·표준편차를 맞추며, 값은 모델에 저장되어 predict·compare가 같이 씁니다. 이 수정 전후로 심장 DCM 대 HCM 교차검증 AUC가 0.691에서 0.927로 바뀌었습니다.
- scGPT 자체는 파인튜닝하지 않습니다. 적응 학습 모듈(scgpt_adapt)은 다음 버전입니다.

## 만든 방법과 확인

- `build_release.py`가 작업 파일을 복사하고, 원고·포탈 이미지·파이프라인 그림을 복사하며, `portal_images.zip`을 만듭니다.
- `python3 tools/check_release.py release/CLOSHA3/scGPT/2026-11-11`로 배포 파일이 작업 파일과 같은지 확인했습니다. 5개 모두 일치합니다.
- Codespace: 두 이미지를 fakeroot로 빌드해 `%test` 통과, 합성 예제로 다섯 모듈을 SIF 안에서 실행해 종료 코드 0(`docs/scGPT/modules/Registration.md` 6절).
- CLOSHA: 사용자가 K-BDS KAP241712 심장 데이터(DCM 대 HCM 26명)로 다섯 모듈을 실행했습니다(2026-11-09). 결과: scGPT 임베딩 평균 AUC 0.939, 학습 모델 0.927, PCA 0.824, 세포 유형 비율 0.697. 학습 모델과 PCA의 차이는 +0.103(95% CI -0.058~+0.280)으로 26명이라 확정되지 않았습니다.
- `release.tsv`는 같은 대응표를 기계가 읽는 형식으로 둔 것입니다.

## 함께 넣은 것

- `docs/`: 모듈 원고(`Portal_Content.md`, `.docx`), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`), 예제 데이터 출처(`Data_Sources.md`)
- `docs/pipeline/`: 파이프라인 원고(`Portal_Content.md`, `.docx`)와 분석 흐름·개념·대표 그림(PNG, 원본 SVG)
- `portal_images/`, `portal_images.zip`: 포탈에 올리는 PNG(모듈 개념도 5개 포함: prep·predict·compare는 직접 그린 모듈 개념도 `docs/scGPT/modules/figures/module_concepts/`, embed·train은 파이프라인 개념도)
- `results/`: 배포본으로 실행한 결과를 올리는 곳(올릴 파일 목록은 `results/README.md`)

## 제자리 수정 (2026-11-13, 버전 번호 유지)

그림 표시만 바꾼 수정이라 사용자 결정으로 1.0 번호를 그대로 두고 이 폴더의 두 파일을 바꿨습니다. 계산과 결과 파일 내용은 같습니다. 실행 이미지(SIF)는 바꾸지 않습니다.

| 모듈 | 파일 | 바뀐 점 |
|---|---|---|
| scgpt_prep | scgpt_prep.1.0.py | `plots/qc_by_sample`: 자동 간격(constrained layout)으로 오른쪽 패널의 축 이름이 왼쪽 패널과 겹치지 않게 함. 행렬에 미토콘드리아(MT-) 유전자가 없으면 오른쪽 패널에 안내 상자를 넣고, 로그(stdout)에 해당 샘플을 알림 |
| scgpt_embed | scgpt_embed.1.0.py | `plots/embedding_umap`: 자동 간격과 그림 폭 18로 범례(긴 코호트 이름)가 옆 패널로 넘어가지 않게 함 |

확인: Codespace에서 bx_scgpt 1.0(CPU)을 fakeroot로 다시 빌드하고, PBMC 3k 가짜 환자 데이터(원본, MT- 유전자 제거·긴 코호트 이름)로 prep 2회와 embed 1회를 실행했습니다. 모두 종료 코드 0이었고, stderr에는 기존 경고만 나왔으며 그림의 겹침이 없어졌습니다. GPU 이미지와 실제 크기 데이터(49 샘플)로는 확인하지 않았습니다.

## 남은 일 (다음 배포)

- scgpt_prep, scgpt_train, scgpt_predict의 결과 그림과 레전드, scgpt_compare 요약표 그림
- scgpt_prep 세포 유형 마커에 심장 등 비혈액 조직 세포를 더하거나 사용자 세포 유형 열을 받는 방안
