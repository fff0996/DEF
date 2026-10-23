# CLOSHA 3.0 RTpred 배포 (2026-10-23)

RTpred(머무름 시간 예측)는 CLOSHA 3.0에서 처음 배포하는 파이프라인입니다. 서울대 식품대사체학 연구실이 개발한 mdcc 코드와 기본 RP·HILIC 모델을 KOBIC 래퍼 스크립트(`key=value` 인자, 로그 분리)로 감쌌습니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 다음 배포는 새 날짜 폴더로 만듭니다.

## 배포 스크립트

CLOSHA 3.0 신규 파이프라인이므로 세 모듈 모두 1.0입니다. 각 파일 맨 위 주석에 모듈이 하는 일이 있습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 |
|---|---|---|---|---|
| rtpred_predict | `rtpred_predict.1.0.py` | (3.0 신규) | `scripts/RTpred/rtpred_predict.1.2.py` | bx_rtpred_predict 1.0 (`defs/RTpred/bx_rtpred_predict.1.0.def`) |
| rtpred_train | `rtpred_train.1.0.py` | (3.0 신규) | `scripts/RTpred/rtpred_train.1.1.py` | bx_rtpred_train 1.0 (`defs/RTpred/bx_rtpred_train.1.0.def`) |
| rtpred_compare | `rtpred_compare.1.0.py` | (3.0 신규) | `scripts/RTpred/rtpred_compare.1.1.py` | bx_rtpred_compare 1.0 (`defs/RTpred/bx_rtpred_compare.1.0.def`) |

- 작업 파일 기준 커밋: `165704a`
- 실행 이미지는 세 개 모두 `defs/RTpred/`에서 빌드합니다(`%files`가 `mdcc`를 상대 경로로 넣음). 이미지 안의 mdcc 코드와 기본 모델은 서울대가 준 그대로입니다.
- 파이프라인 두 개: 기본 모델 예측(rtpred_predict만), 사용자 모델(rtpred_train → rtpred_predict, rtpred_train → rtpred_compare)

## 서울대와 정한 동작 (2026-10-21~23)

- 학습: 한 표에 RP와 HILIC가 섞여도 되며, 모드마다 따로 모델을 만듭니다(`result/RP/`, `result/HILIC/`).
- 예측: 사용자 모델로 예측하면 행마다 그 모드의 학습 모델을 씁니다. 학습하지 않은 모드의 행은 예측하지 않고 `parse_status=no_trained_model`로 표시합니다(기본 모델로 채우지 않음).
- 비교: 학습한 모드마다 그 모드의 기본 모델과 비교합니다.
- 모드는 입력 표의 `model_type` 열(행마다 RP 또는 HILIC)로만 정합니다. 모드를 고르는 인자는 없습니다.
- RT 단위: 기본 모델은 분(min)이며, 학습의 `rt_unit` 기본값도 min입니다.

## 만든 방법과 확인

- `build_release.py`가 작업 파일에서 배포 파일을 만듭니다. 맨 위 변경 이력을 "CLOSHA 3.0 첫 배포" 한 블록으로 바꾸고, 파일 안의 자기 이름을 배포 이름으로 바꿉니다. 다른 줄은 바꾸지 않습니다. 원고, 포탈 이미지, 파이프라인 그림도 이 스크립트가 복사합니다.
- `python3 tools/check_release.py release/CLOSHA3/RTpred/2026-10-23`로 배포 파일이 작업 파일과 (맨 위 주석과 파일 이름을 빼고) 같은지 확인했습니다. 3개 모두 일치합니다.
- `release.tsv`는 같은 대응표를 기계가 읽는 형식으로 둔 것입니다.
- CLOSHA 테스트는 사용자가 진행했습니다.

## 함께 넣은 것

- `docs/`: 배포 시점의 모듈 원고(`Portal_Content.md`, `.docx`), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`)
- `docs/pipeline/`: 파이프라인 페이지 원고(`Portal_Content.md`, `.docx`)와 분석 흐름·개념 그림(PNG, 원본 SVG)
- `portal_images/`: 포탈에 올리는 PNG(모듈별, 파이프라인)
- `results/`: 배포본으로 실행한 결과를 올리는 곳(올릴 파일 목록은 `results/README.md`)
