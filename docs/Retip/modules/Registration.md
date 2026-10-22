RTpred (Retip) 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22

CLOSHA에 RTpred 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/Retip/`의 KOBIC 래퍼 스크립트 최신 버전(아래 표)이고, 래퍼는 서울대 식품대사체학 연구실이 준 mdcc 코드와 기본 모델(실행 이미지 안 `/opt/mdcc`)을 부른다. 모든 래퍼는 `key=value` 인자를 받는다. 서울대 원문 자료는 같은 폴더의 `CONTENT_KO.md`, `USER_GUIDE_KO.md`, `OPERATIONS_KO.md`, `VALIDATION_KO.md`다.

모든 모듈은 결과를 `output_dir/result/`에, 로그를 `output_dir/logs/<시각>_<PID>.log`(stdout)와 `.err`(stderr)에 남긴다. 다시 실행하면 `output_dir/result/`만 지우고 새로 만든다(`logs/`는 남긴다).

등록 메모:
- RTpred는 CLOSHA 3.0에서 처음 배포하므로 배포 번호는 모두 1.0이다(작업 파일 retip_predict.1.1.py → 배포 retip_predict.1.0.py).
- `retip_predict.1.2.py`(다른 모드 행을 건너뛰는 버전)는 서울대 의도와 달라 쓰지 않아 지웠다(2026-10-22).
- `cpus`는 포탈에 등록하지 않는다(Processor Core 선택으로 결정, 스크립트가 `auto`로 할당 코어를 읽음).

## 0. 파이프라인 흐름
서울대 답변(2026-10-21)에 따른 흐름: train(선택) → predict(기본 모델 또는 학습 모델) → compare(선택, train을 쓸 때만).
```
기본 모델 예측 (RTpred_Default_Prediction):
  화합물 표 ─> [retip_predict] (model_dir 비움 = 이미지 안 기본 모델)

사용자 모델 (RTpred_User_Model):
  학습 표 ─> [retip_train] ─output_dir─┬─> [retip_predict] (model_dir) <── 화합물 표
                                       └─> [retip_compare] (input_dir) <── 평가 표(선택, 비우면 reserved_test.csv)
```
| 모듈 | 스크립트 | 실행 이미지 | 실행 명령 |
|---|---|---|---|
| retip_predict | `retip_predict.1.1.py` | bx_retip_predict.1.0 | `python retip_predict.1.1.py key=value ...` |
| retip_train | `retip_train.1.0.py` | bx_retip_train.1.0 | `python retip_train.1.0.py key=value ...` |
| retip_compare | `retip_compare.1.0.py` | bx_retip_compare.1.0 | `python retip_compare.1.0.py key=value ...` |

공통 입력 표(CSV 또는 XLSX, 한 행이 화합물 하나):
| 열 | predict | train | compare | 규칙 |
|---|---|---|---|---|
| `SMILES`(`smiles`, `structure`) | 필수 | 필수 | 필수 | 분자 구조 문자열 |
| `model_type`(`Column`, `mode`, `chrom_system`) | 조건부 | 선택 | 선택 | `RP` 또는 `HILIC`. `model` 인자와 다르면 멈춤 |
| `RT`(`experimental_rt`, `retention_time`) | 선택 | 필수 | 필수 | 0 이상 숫자 |
| `compound_id`, `Name`, `InChIKey` | 선택 | 선택 | 선택 | 추적용 |

## 1. retip_predict
기본 모델(RP·HILIC) 또는 retip_train으로 만든 모델로 머무름 시간(RT)을 예측한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_file` | File (CSV/XLSX) | 필수 | | 화합물 표. SMILES 열 필수, RT 열이 있으면 ΔRT 계산 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`) |
| Input | `model_dir` | Directory | 선택 | `default` | `default` 또는 빈 값 = 이미지 안 기본 모델. 그 밖에는 retip_train의 output_dir(그 안 `result/model/` 사용) |
| Option | `model` | List (`auto`, `RP`, `HILIC`) | 선택 | `auto` | 기본 모델: auto = 표의 model_type 열(행마다 RP/HILIC, 섞어도 됨). 학습 모델: auto = 모델의 모드, RP/HILIC은 모델과 같아야 함 |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름. first 또는 빈 값 = 첫 시트. CSV는 무시 |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): `predictions.csv`, `prediction.png/.svg`, `report.html`, `manifest.json`(사용한 모델: default 또는 user, 모델 경로와 체크섬).

## 2. retip_train
사용자 실험 RT 표로 RT 예측 모델을 학습한다(pyRetip 방식, AutoGluon).

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_file` | File (CSV/XLSX) | 필수 | | 학습 표. SMILES와 측정 RT 필수. 정제 후 25행·고유 구조 15개 이상 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`). 폴더 전체가 retip_predict의 `model_dir`, retip_compare의 `input_dir` |
| Option | `model` | List (`auto`, `RP`, `HILIC`) | 선택 | `auto` | auto = 표의 model_type 열의 한 모드. 열이 없거나 모드가 섞이면 멈춤 |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름 |
| Option | `rt_unit` | String | 선택 | `auto` | RT 단위 이름(값은 바꾸지 않음). auto = "model unit" |
| Option | `time_limit` | Integer | 선택 | `1200` | AutoGluon 학습 시간 예산(초) |
| Option | `algorithms` | String | 선택 | `GBM,CAT,RF,XT,KNN` | 후보 알고리즘(쉼표 구분 부분집합) |
| Option | `test_size` | Float | 선택 | `0.2` | 예약 test 비율(구조 그룹 기준) |
| Option | `validation_size` | Float | 선택 | `0.2` | validation 비율 |
| Option | `seed` | Integer | 선택 | `42` | 난수 시드 |
| Option | `max_missing_fraction` | Float | 선택 | `0.2` | descriptor 결측 비율 상한 |
| Option | `correlation_threshold` | Float | 선택 | `0.995` | descriptor 상관 제거 기준 |
| Option | `method_label` | String | 선택 | `user method` | 사용자 LC 분석법 이름 |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): `model/`(학습 모델과 manifest), `reserved_test.csv`, `validation_leaderboard.csv`, `split_assignments.csv`, `rejected_rows.csv`, `training.png/.svg`, `report.html`, `manifest.json`.

## 3. retip_compare
같은 평가 화합물에서 기본 모델과 사용자 모델의 성능을 비교한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | retip_train의 output_dir(그 안 `result/model/`, `result/reserved_test.csv`) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`) |
| Option | `model` | List (`RP`, `HILIC`) | 필수 | | 사용자 모델의 모드와 같아야 함 |
| Input | `eval_file` | File (CSV/XLSX) | 선택 | `reserved_test` | 평가 표(SMILES와 측정 RT). reserved_test 또는 빈 값 = retip_train의 reserved_test.csv |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름 |
| Option | `rt_unit` | String | 선택 | `auto` | RT 단위 이름. auto = 사용자 모델의 단위. 학습 때와 같아야 함 |
| Option | `scope` | List (`all`, `best`) | 선택 | `all` | all = 사용자 모델의 모든 후보, best = 저장된 best만 |
| Option | `title` | String | 선택 | `Default and user model comparison` | 보고서 제목 |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): `comparison.csv`, `predictions_long.csv`, `comparison.png/.svg`, `report.html`, `manifest.json`.

## 4. 권장 자원 (포탈: 코어 1/4/8/16, 메모리 8~128GB)
서울대 초기 권장값(성능 시험으로 정한 최소 사양 아님)을 포탈 선택지에 맞췄다.

| 모듈 | 서울대 권장 | 포탈 선택 |
|---|---|---|
| retip_predict | 2 CPU / 8GB | 4코어 / 8GB |
| retip_train | 4 CPU / 16GB, 디스크 10GB 이상 | 4코어 / 16GB |
| retip_compare | 2 CPU / 8GB | 4코어 / 8GB |
