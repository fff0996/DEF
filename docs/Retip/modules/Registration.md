RTpred (Retip) 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22 (모드별 학습 반영 2026-10-23)

CLOSHA에 RTpred 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/Retip/`의 KOBIC 래퍼 스크립트 최신 버전(아래 표)이고, 래퍼는 서울대 식품대사체학 연구실이 준 mdcc 코드와 기본 모델(실행 이미지 안 `/opt/mdcc`)을 부른다. 모든 래퍼는 `key=value` 인자를 받는다. 서울대 원문 자료는 같은 폴더의 `CONTENT_KO.md`, `USER_GUIDE_KO.md`, `OPERATIONS_KO.md`, `VALIDATION_KO.md`다.

모든 모듈은 결과를 `output_dir/result/`에, 로그를 `output_dir/logs/<시각>_<PID>.log`(stdout)와 `.err`(stderr)에 남긴다. 다시 실행하면 `output_dir/result/`만 지우고 새로 만든다(`logs/`는 남긴다).

등록 메모:
- RTpred는 CLOSHA 3.0에서 처음 배포하므로 배포 번호는 모두 1.0이다(작업 파일 retip_predict.1.2.py, retip_train.1.1.py, retip_compare.1.1.py → 배포 각 1.0).
- 분리 모드(서울대 확인, 2026-10-23): 학습은 한 표의 RP·HILIC를 모드별로 나눠 각각 학습한다. 사용자 모델로 예측하면 행마다 그 모드의 학습 모델을 쓰고, 학습하지 않은 모드의 행은 예측하지 않고 `parse_status=no_trained_model`로 표시한다. 비교는 학습한 모드마다 그 모드의 기본 모델과 한다. mdcc와 이미지는 그대로이고 래퍼만 바뀌었다(mdcc를 모드마다 한 번씩 부름).
- 2026-10-22에 지운 이전 `retip_predict.1.2.py`(학습 모델 한 개에서 다른 모드 행 건너뛰기)와 지금의 1.2는 다른 파일이다. 지금 1.2는 모드별 모델을 읽는다.
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
| retip_predict | `retip_predict.1.2.py` | bx_retip_predict.1.0 | `python retip_predict.1.2.py key=value ...` |
| retip_train | `retip_train.1.1.py` | bx_retip_train.1.0 | `python retip_train.1.1.py key=value ...` |
| retip_compare | `retip_compare.1.1.py` | bx_retip_compare.1.0 | `python retip_compare.1.1.py key=value ...` |

공통 입력 표(CSV 또는 XLSX, 한 행이 화합물 하나):
| 열 | predict | train | compare | 규칙 |
|---|---|---|---|---|
| `SMILES`(`smiles`, `structure`) | 필수 | 필수 | 필수 | 분자 구조 문자열 |
| `model_type`(`Column`, `mode`, `chrom_system`) | 조건부 | 조건부 | 조건부 | 행마다 `RP` 또는 `HILIC`, 한 표에 섞여도 됨. 열이 없으면 `model` 인자로 한 모드를 지정 |
| `RT`(`experimental_rt`, `retention_time`) | 선택 | 필수 | 필수 | 0 이상 숫자 |
| `compound_id`, `Name`, `InChIKey` | 선택 | 선택 | 선택 | 추적용 |

## 1. retip_predict
기본 모델(RP·HILIC) 또는 retip_train으로 만든 모델로 머무름 시간(RT)을 예측한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_file` | File (CSV/XLSX) | 필수 | | 화합물 표. SMILES 열 필수, RT 열이 있으면 ΔRT 계산. 모드가 섞여도 됨 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`) |
| Input | `model_dir` | Directory | 선택 | `default` | `default` 또는 빈 값 = 이미지 안 기본 모델. 그 밖에는 retip_train의 output_dir(`result/RP/model`, `result/HILIC/model`; train 1.0의 `result/model`도 읽음). 행마다 그 모드의 학습 모델로 예측하고, 학습하지 않은 모드의 행은 `no_trained_model`로 표시 |
| Option | `model` | List (`auto`, `RP`, `HILIC`) | 선택 | `auto` | auto = 표의 model_type 열(행마다). 열이 없으면 기본 모델은 RP/HILIC 지정 필요, 학습 모델은 한 모드만 학습했을 때 그 모드. RP/HILIC = 모든 행을 그 모드로 봄 |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름. first 또는 빈 값 = 첫 시트. CSV는 무시 |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): `predictions.csv`(학습 모델이면 `rt_unit` 열 추가), `prediction.png/.svg`, `report.html`, `manifest.json`(사용한 모델: default 또는 user, 모드별 모델 경로와 체크섬, 예측하지 않은 모드의 행 수).

## 2. retip_train
사용자 실험 RT 표로 RT 예측 모델을 학습한다(pyRetip 방식, AutoGluon).

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_file` | File (CSV/XLSX) | 필수 | | 학습 표. SMILES와 측정 RT 필수. model_type 열의 모드마다 따로 학습(섞여도 됨). 모드마다 정제 후 25행·고유 구조 15개 이상 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`). 폴더 전체가 retip_predict의 `model_dir`, retip_compare의 `input_dir` |
| Option | `model` | List (`auto`, `RP`, `HILIC`) | 선택 | `auto` | auto = model_type 열에 있는 모드 전부. RP/HILIC = 그 모드 행만. 열이 없는 표는 RP/HILIC 지정 필요 |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름 |
| Option | `rt_unit` | String | 선택 | `min` | 측정 RT의 단위 이름(값은 바꾸지 않음). 빈 값 = min |
| Option | `time_limit` | Integer | 선택 | `1200` | 모드마다 AutoGluon 학습 시간 예산(초) |
| Option | `algorithms` | String | 선택 | `GBM,CAT,RF,XT,KNN` | 후보 알고리즘(쉼표 구분 부분집합) |
| Option | `test_size` | Float | 선택 | `0.2` | 예약 test 비율(구조 그룹 기준) |
| Option | `validation_size` | Float | 선택 | `0.2` | validation 비율 |
| Option | `seed` | Integer | 선택 | `42` | 난수 시드 |
| Option | `max_missing_fraction` | Float | 선택 | `0.2` | descriptor 결측 비율 상한 |
| Option | `correlation_threshold` | Float | 선택 | `0.995` | descriptor 상관 제거 기준 |
| Option | `method_label` | String | 선택 | `user method` | 사용자 LC 분석법 이름 |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): 모드별 `RP/`, `HILIC/`(각각 `model/`, `reserved_test.csv`, `validation_leaderboard.csv`, `split_assignments.csv`, `rejected_rows.csv`, `training.png/.svg`, `report.html`, `manifest.json`), `train_summary.tsv`(Mode, Rows, Status, Best_model, Output), `inputs/train_<MODE>.csv`. 한 모드가 실패해도 다른 모드는 남고, 모든 모드가 실패할 때만 실패.

## 3. retip_compare
학습한 모드마다 같은 평가 화합물에서 그 모드의 기본 모델과 사용자 모델의 성능을 비교한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | retip_train의 output_dir(모드마다 `model/`과 `reserved_test.csv`; train 1.0 출력도 읽음) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더(`result/`, `logs/`) |
| Option | `model` | List (`auto`, `RP`, `HILIC`) | 선택 | `auto` | auto = 학습된 모드 전부. RP/HILIC = 그 모드만 |
| Input | `eval_file` | File (CSV/XLSX) | 선택 | `reserved_test` | 평가 표(SMILES와 측정 RT, 두 모드면 model_type 열 필요). reserved_test 또는 빈 값 = 모드마다 retip_train의 reserved_test.csv. 학습하지 않은 모드의 행은 쓰지 않음 |
| Option | `sheet` | String | 선택 | `first` | XLSX 시트 이름 |
| Option | `rt_unit` | String | 선택 | `auto` | RT 단위 이름. auto = 모드마다 사용자 모델의 단위. 학습 때와 같아야 함 |
| Option | `scope` | List (`all`, `best`) | 선택 | `all` | all = 사용자 모델의 모든 후보, best = 저장된 best만 |
| Option | `title` | String | 선택 | `Default and user model comparison` | 보고서 제목(모드별 결과에 (RP), (HILIC)가 붙음) |
| Option | `cpus` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

결과(`output_dir/result/`): 모드별 `RP/`, `HILIC/`(각각 `comparison.csv`, `predictions_long.csv`, `comparison.png/.svg`, `report.html`, `manifest.json`), 모드 열이 붙은 통합 `comparison.csv`, `compare_summary.tsv`(Mode, Eval_rows, Status, Best_candidate, Output).

## 4. 권장 자원 (포탈: 코어 1/4/8/16, 메모리 8~128GB)
서울대 초기 권장값(성능 시험으로 정한 최소 사양 아님)을 포탈 선택지에 맞췄다.

| 모듈 | 서울대 권장 | 포탈 선택 |
|---|---|---|
| retip_predict | 2 CPU / 8GB | 4코어 / 8GB |
| retip_train | 4 CPU / 16GB, 디스크 10GB 이상 | 4코어 / 16GB |
| retip_compare | 2 CPU / 8GB | 4코어 / 8GB |
