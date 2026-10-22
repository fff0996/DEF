# RTpred (Retip) 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고입니다. 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/Retip/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따르고, 내용은 서울대 식품대사체학 연구실이 준 자료(`docs/Retip/CONTENT_KO.md`, `USER_GUIDE_KO.md`)를 바탕으로 했습니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다.
- 코어 수 옵션(`cpus`)은 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택이 곧 코어 수입니다(스크립트가 `auto`로 할당된 코어 수를 읽습니다).
- 선택(Optional) 입력 중 `model_dir`는 `default`, `eval_file`은 `reserved_test`가 기본값이며, 비워 두어도 같은 뜻입니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다. 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값입니다. 기반 이미지(From)는 세 모듈 모두 Debian 12 bookworm(`python:3.13.15-slim-bookworm`)이며, 서울대가 준 DEF를 따라 conda 대신 pip을 씁니다.
- RTpred는 CLOSHA 3.0에서 처음 배포하므로 모든 모듈의 버전은 1.0입니다.
- 모든 모듈은 결과를 `output_dir/result/`에, 로그를 `output_dir/logs/`에 남기며, 다시 실행하면 `result/`만 지우고 새로 만듭니다.
- 카테고리: CLOSHA 프로그램 목록에 맞는 중분류가 없어 Omics / Metabolite_Identification(신규)을 제안합니다. 머무름 시간 예측은 비표적 대사체 분석에서 후보 화합물을 거르는 데 쓰이며, 다른 대사체 동정 도구도 담을 수 있는 일반 이름입니다.
- 분석 개념 이미지와 주요 결과 이미지는 서울대가 만든 그림(`docs/Retip/images/`)입니다. 결과 그림은 서울대 예제 실행 결과이며, 학습·비교 예제의 RT는 기능 확인용 합성값입니다.
- 등록 메모: 결과 그림은 우리 래퍼(`key=value`)로 CLOSHA에서 실측 데이터를 돌린 뒤 바꿀 수 있습니다. 그림 형식은 mdcc가 그리므로 같습니다.

---

## 1. retip_predict

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | retip_predict | retip_predict |
| 서브 타이틀 | 머무름 시간 예측 | Retention time prediction |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Metabolite_Identification (신규) | Metabolite_Identification (new) |
| 태그 | retention time, RT prediction, RP, HILIC, SMILES, RDKit, AutoGluon, metabolomics | |
| 레퍼런스 URL | https://doi.org/10.1021/acs.analchem.9b05765 | |
| 컨테이너 이미지 | bx_retip_predict.1.0 | |
| 실행 스크립트 파일 | retip_predict.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 8GB | 4 cores, 8 GB of memory |

등록 메모: 작업 파일 `scripts/Retip/retip_predict.1.1.py`를 배포 번호 1.0으로 올립니다.

### 실행 이미지
이미지: bx_retip_predict 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Retip/bx_retip_predict.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Debian 12 bookworm (`python:3.13.15-slim-bookworm`) |
| 설치 도구 / installer | pip(해시 고정), apt (conda 사용 안 함) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| Python | 3.13.15 | https://www.python.org/ |
| RDKit | 2026.3.1 | https://www.rdkit.org/ |
| AutoGluon Tabular | 1.5.0 | https://auto.gluon.ai/ |
| scikit-learn | 1.7.1 | https://scikit-learn.org/ |
| SciPy | 1.16.3 | https://scipy.org/ |
| NumPy | 2.3.5 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| LightGBM | 4.6.0 | https://lightgbm.readthedocs.io/ |
| CatBoost | 1.2.10 | https://catboost.ai/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| openpyxl | 3.1.5 | https://openpyxl.readthedocs.io/ |
| mdcc (RTpred 코드, 서울대 식품대사체학 연구실) | Revision 2 | - |

- **태그(키워드):** 머무름시간예측, 대사체동정, RDKit, AutoGluon
- **내용(국문):** 화합물 구조(SMILES)로 액체크로마토그래피 머무름 시간(RT)을 예측하는 실행 환경입니다. RDKit으로 구조 descriptor를 계산하고 AutoGluon 모델로 예측·학습합니다. RP·HILIC 기본 모델(best: WeightedEnsemble_L3)이 이미지 안 `/opt/mdcc/models`에 들어 있습니다. 실행 중 인터넷과 GPU를 쓰지 않습니다.
- **내용(영문):** Runtime environment for predicting liquid chromatography retention time (RT) from compound structures (SMILES). RDKit computes structure descriptors and AutoGluon models predict and train. The default RP and HILIC models (best: WeightedEnsemble_L3) are bundled in `/opt/mdcc/models`. No internet access or GPU is used at run time.

### 내용(국문)
화합물 구조(SMILES)로 액체크로마토그래피 머무름 시간(RT)을 예측합니다. 비표적 대사체 분석에서 같은 질량의 후보 화합물 중 예측 RT가 실측과 맞는 것을 고르는 데 씁니다.
- 기본으로는 이미지에 들어 있는 RP·HILIC 기본 모델(best: WeightedEnsemble_L3)을 씁니다. model_dir에 사용자 모델 학습 결과 폴더를 주면 그 모델로 예측합니다.
- SMILES를 RDKit 구조 descriptor로 바꾸고 저장된 best 모델로 RT를 계산합니다.
- 입력 행 순서와 행 번호를 그대로 둔 예측표를 만들고, 구조를 읽지 못한 행은 지우지 않고 사유와 함께 남깁니다. 측정 RT가 있으면 ΔRT(측정 - 예측)를 함께 적습니다.
- 처리 성공·실패 행 수와 모드별 예측 RT 분포 그림, HTML 보고서, 사용한 모델과 체크섬을 적은 manifest를 만듭니다.

### 내용(영문)
Predicts liquid chromatography retention time (RT) from compound structures (SMILES). In untargeted metabolomics it helps to choose, among candidates of the same mass, those whose predicted RT matches the measurement.
- By default the RP and HILIC models bundled in the image (best: WeightedEnsemble_L3) are used; with a training output folder in model_dir, that user model predicts instead.
- SMILES are converted into RDKit structure descriptors and the saved best model computes the RT.
- The prediction table keeps the input row order and row numbers; rows whose structure cannot be read are kept with the reason. With a measured RT, ΔRT (measured - predicted) is added.
- Plots of processed and failed rows and the predicted RT per mode, an HTML report, and a manifest of the model used and its checksum are written.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | File | input_file | /data/compounds.csv | 화합물 표(CSV 또는 XLSX, 한 행이 화합물 하나). SMILES 열 필수. model_type 열(RP/HILIC)과 측정 RT 열은 선택 | Compound table (CSV or XLSX, one compound per row) with a SMILES column; model_type (RP/HILIC) and measured RT columns are optional |
| Output | Required | Directory | output_dir | /data/retip_predict | 결과 폴더. result/에 predictions.csv, prediction.png·.svg, report.html, manifest.json, logs/에 로그 | Output folder: result/ holds predictions.csv, prediction.png and .svg, report.html and manifest.json; logs/ holds the logs |
| Input | Optional | Directory | model_dir | default | 예측에 쓸 모델. default 또는 빈 값 = 이미지 안 기본 RP·HILIC 모델. 학습 모델을 쓰려면 사용자 모델 학습 결과 폴더(안에 result/model/model_manifest.json이 있어야 함) | Model used for prediction. default or empty = the bundled default RP and HILIC models. For a trained model, the training output folder (with result/model/model_manifest.json) |
| Option | Optional | List | model | auto | 분리 모드(auto, RP, HILIC). 기본 모델에서 auto = 표의 model_type 열을 행마다 사용(섞어도 됨). 학습 모델에서 auto = 모델의 모드 | Separation mode (auto, RP, HILIC). With the default models, auto uses the model_type column per row (modes may be mixed); with a trained model, auto takes the model's mode |
| Option | Optional | String | sheet | first | XLSX 시트 이름. first 또는 빈 값 = 첫 시트. CSV에는 적용 안 함 | XLSX sheet name; first or empty = the first sheet. Ignored for CSV |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SMILES | 필수 | 분자 구조 문자열(`smiles`, `structure`도 가능) | O=C(O)c1ccccc1 |
| model_type | 조건부 | RP 또는 HILIC. 기본 모델에서 model=auto이면 필수 | RP |
| RT | 선택 | 측정 RT(`experimental_rt`, `retention_time`도 가능). 있으면 ΔRT 계산 | 5.4 |
| compound_id, Name, InChIKey | 선택 | 추적용 정보. 그대로 결과에 남음 | C001 |

```
compound_id,SMILES,model_type
C001,O=C(O)c1ccccc1,RP
C002,NCC(=O)O,HILIC
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 기본 모델은 서울대가 학습해 제공한 RP·HILIC 모델입니다. 기본 모델의 학습 LC 조건(컬럼, 이동상, gradient)과 RT 단위는 제공 자료에서 확인되지 않아, 실측 RT와 비교할 때는 같은 조건인지 주의해 주세요. | The default RP and HILIC models were trained and provided by SNU. Their LC conditions (column, mobile phase, gradient) and RT unit are not stated in the provided material, so take care when comparing with your measured RT. |
| 학습 모델로 예측하면 표의 model_type 열이 모델의 모드와 같아야 합니다. 다른 모드가 섞인 표는 서울대 코드가 "Do not mix chromatography modes"로 멈춥니다. 모드별로 표를 나눠 주세요. | With a trained model, the model_type column must match the model's mode; a table mixing modes stops in the SNU code with "Do not mix chromatography modes". Split the table by mode. |
| 잘못되었거나 빈 SMILES 행은 지우지 않고 parse_status=invalid_smiles와 사유를 남기며 예측값은 비웁니다. 오류가 아니라 입력 데이터의 결과입니다. | Invalid or empty SMILES rows are kept with parse_status=invalid_smiles and the reason, with an empty prediction; this reflects the input, not an error. |
| 모델이 낸 RT를 보정하거나 단위를 바꾸지 않습니다. | The RT returned by the model is neither corrected nor converted. |
| 학습 모델은 같은 버전의 이미지(bx_retip_train 1.0)로 학습한 것만 쓸 수 있습니다. 패키지 버전이 다르면 서울대 코드가 멈춥니다. | Only models trained with the matching image (bx_retip_train 1.0) can be used; the SNU code stops on different package versions. |

### 분석 개념 이미지
그림: `docs/Retip/images/module1_concept.png`

- 레전드(국문): **그림. 기본 모델로 머무름 시간 예측.** (Compound input) CSV 또는 XLSX 화합물 표에서 SMILES와 RP·HILIC 모드를 읽으며, 측정 RT는 있어도 되고 없어도 됩니다. (Local best ensemble) 구조를 RDKit descriptor로 바꾸고 이미지에 저장된 best 앙상블(WeightedEnsemble_L3)로 예측합니다. (Predicted RT) 입력 한 행마다 결과 한 행을 내며, 읽지 못한 구조도 결과에 남기고 예측표·QC·분포 그림을 만듭니다.
- 레전드(영문): **Figure. Retention time prediction with the default models.** (Compound input) SMILES and the RP or HILIC mode are read from a CSV or XLSX table; a measured RT is optional. (Local best ensemble) Structures become RDKit descriptors and the best ensemble saved in the image (WeightedEnsemble_L3) predicts. (Predicted RT) Each input row gives one result row; unreadable structures are kept, and a prediction table, QC and distribution plots are written.
- 출처: 서울대 식품대사체학 연구실 제공 모식도(외부 논문 그림 사용 안 함)

### 스크립트 사용 예제
```
python retip_predict.1.0.py \
  input_file=/data/compounds.csv \
  output_dir=/data/retip_predict \
  model_dir=default \
  model=auto \
  sheet=first
```

### 주요 결과 이미지
서울대 예제(`compounds.csv`, 8행, RP·HILIC 혼합, 기본 모델) 결과입니다.

**결과 1. 예측 처리 현황과 예측 RT 분포**
- 결과 파일: `result/prediction.png` (같은 그림 `prediction.svg`, 표 `predictions.csv`)

그림: `docs/Retip/images/module1_result.png`

- 레전드(국문): **기본 모델 예측 결과 요약.** 왼쪽(Prediction coverage)은 구조를 읽어 예측한 행(ok)과 읽지 못한 행(invalid_smiles)의 화합물 수(Compounds)이고, 오른쪽(Default best-model RT)은 모드별(파랑 RP, 주황 HILIC) 예측 RT 분포입니다. x축은 RT (model unit)로, 모델이 학습된 단위 그대로입니다. 정상 결과는 invalid_smiles가 0이거나 입력에서 의도한 행만 있는 경우입니다. 예시 데이터에서는 8행 중 6행이 예측되었고, 의도적으로 넣은 잘못된·빈 SMILES 2행이 invalid_smiles로 남았습니다. 예측 RT는 HILIC 약 2~7, RP 약 4입니다.
- 레전드(영문): **Summary of the default model prediction.** Left (Prediction coverage): number of compounds predicted (ok) and with unreadable structures (invalid_smiles). Right (Default best-model RT): predicted RT per mode (blue RP, orange HILIC); the x axis is RT (model unit), the unit the model was trained in. A normal result has no invalid_smiles rows or only those expected from the input. In the example data 6 of 8 rows were predicted, and the 2 deliberately invalid or empty SMILES rows remained as invalid_smiles. Predicted RTs are about 2-7 for HILIC and about 4 for RP.

---

## 2. retip_train

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | retip_train | retip_train |
| 서브 타이틀 | 사용자 머무름 시간 모델 학습 | User retention time model training |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Metabolite_Identification (신규) | Metabolite_Identification (new) |
| 태그 | retention time, model training, AutoGluon, pyRetip, RDKit, RP, HILIC, machine learning | |
| 레퍼런스 URL | https://doi.org/10.1021/acs.analchem.9b05765 | |
| 컨테이너 이미지 | bx_retip_train.1.0 | |
| 실행 스크립트 파일 | retip_train.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 16GB | 4 cores, 16 GB of memory |

### 실행 이미지
이미지: bx_retip_train 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Retip/bx_retip_train.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Debian 12 bookworm (`python:3.13.15-slim-bookworm`) |
| 설치 도구 / installer | pip(해시 고정), apt (conda 사용 안 함) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| Python | 3.13.15 | https://www.python.org/ |
| RDKit | 2026.3.1 | https://www.rdkit.org/ |
| AutoGluon Tabular | 1.5.0 | https://auto.gluon.ai/ |
| scikit-learn | 1.7.1 | https://scikit-learn.org/ |
| SciPy | 1.16.3 | https://scipy.org/ |
| NumPy | 2.3.5 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| LightGBM | 4.6.0 | https://lightgbm.readthedocs.io/ |
| CatBoost | 1.2.10 | https://catboost.ai/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| openpyxl | 3.1.5 | https://openpyxl.readthedocs.io/ |
| mdcc (RTpred 코드, 서울대 식품대사체학 연구실) | Revision 2 | - |

- **태그(키워드):** 머무름시간예측, 대사체동정, RDKit, AutoGluon
- **내용(국문):** 화합물 구조(SMILES)로 액체크로마토그래피 머무름 시간(RT)을 예측하는 실행 환경입니다. RDKit으로 구조 descriptor를 계산하고 AutoGluon 모델로 예측·학습합니다. 기본 모델은 넣지 않았습니다(학습 전용). 실행 중 인터넷과 GPU를 쓰지 않습니다.
- **내용(영문):** Runtime environment for predicting liquid chromatography retention time (RT) from compound structures (SMILES). RDKit computes structure descriptors and AutoGluon models predict and train. The default models are not included (training only). No internet access or GPU is used at run time.

### 내용(국문)
사용자가 자기 LC 조건에서 측정한 머무름 시간(RT) 표로 RT 예측 모델을 학습합니다. 기본 모델과 다른 컬럼·이동상·gradient를 쓰는 실험실은 자기 조건에 맞는 모델이 있어야 예측 RT를 후보 거르기에 쓸 수 있습니다.
- 같은 구조가 train, validation, test에 섞이지 않도록 정규화한 구조 단위로 나누고, 먼저 예약 test를 떼어 둡니다.
- RDKit descriptor를 계산하고, 결측·상관 필터는 train에서만 정합니다. pyRetip 방식으로 AutoGluon 후보(LightGBM, CatBoost, RandomForest, ExtraTrees, KNeighbors와 가중 앙상블)를 학습합니다.
- validation RMSE로 best 모델을 고릅니다. test로 고르지 않고, test를 포함해 다시 학습하지도 않으므로 저장된 best는 예약 test를 보지 않은 모델입니다.
- 결과 폴더는 머무름 시간 예측(model_dir)과 모델 성능 비교(input_dir)의 입력입니다.

### 내용(영문)
Trains an RT prediction model from a table of retention times measured under the user's own LC conditions. Labs using a column, mobile phase or gradient different from the default models need a model for their conditions before predicted RTs can filter candidates.
- The data are split by canonical structure so that the same structure never appears in more than one of train, validation and test, and the reserved test is set aside first.
- RDKit descriptors are computed, and missing-value and correlation filters are fitted on train only. AutoGluon candidates (LightGBM, CatBoost, RandomForest, ExtraTrees, KNeighbors and a weighted ensemble) are trained the pyRetip way.
- The best model is chosen by validation RMSE, not by the test, and there is no refit including the test, so the saved best has never seen the reserved test.
- The output folder is the input of RT prediction (model_dir) and of model comparison (input_dir).

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | File | input_file | /data/rt_library.csv | 학습 표(CSV 또는 XLSX). SMILES와 측정 RT 열 필수. 한 분리 모드(RP 또는 HILIC)만, 정제 후 25행·서로 다른 구조 15개 이상 | Training table (CSV or XLSX) with SMILES and measured RT, one separation mode (RP or HILIC), at least 25 rows and 15 distinct structures after cleaning |
| Output | Required | Directory | output_dir | /data/retip_train | 결과 폴더. result/에 model/(학습 모델), reserved_test.csv, validation_leaderboard.csv, split_assignments.csv, rejected_rows.csv, training.png·.svg, report.html, manifest.json | Output folder: result/ holds model/ (trained models), reserved_test.csv, validation_leaderboard.csv, split_assignments.csv, rejected_rows.csv, training.png and .svg, report.html and manifest.json |
| Option | Optional | List | model | auto | 분리 모드(auto, RP, HILIC). auto = 표의 model_type 열에 있는 한 모드. 열이 없거나 모드가 섞이면 멈춤 | Separation mode (auto, RP, HILIC). auto takes the single mode of the model_type column; stops if the column is missing or mixes modes |
| Option | Optional | String | sheet | first | XLSX 시트 이름. first 또는 빈 값 = 첫 시트. CSV에는 적용 안 함 | XLSX sheet name; first or empty = the first sheet. Ignored for CSV |
| Option | Optional | String | rt_unit | auto | RT 단위 이름(예: min). 값은 바꾸지 않고 기록만 함. auto 또는 빈 값 = model unit | RT unit label (for example min); values are not converted. auto or empty = model unit |
| Option | Optional | Integer | time_limit | 1200 | AutoGluon 학습 시간 예산(초). 전처리·저장을 포함한 전체 실행 시간 제한은 아님 | AutoGluon training budget in seconds; not a limit on the whole run including preprocessing and saving |
| Option | Optional | String | algorithms | GBM,CAT,RF,XT,KNN | 학습할 후보 알고리즘(쉼표 구분). GBM = LightGBM, CAT = CatBoost, RF = RandomForest, XT = ExtraTrees, KNN = KNeighbors | Candidate algorithms (comma separated): GBM = LightGBM, CAT = CatBoost, RF = RandomForest, XT = ExtraTrees, KNN = KNeighbors |
| Option | Optional | Float | test_size | 0.2 | 예약 test 비율(구조 그룹 기준, 0 초과 0.5 미만) | Reserved test fraction (by structure group, above 0 and below 0.5) |
| Option | Optional | Float | validation_size | 0.2 | validation 비율(0 초과 0.5 미만, test_size와 합이 0.8 미만) | Validation fraction (above 0 and below 0.5; with test_size below 0.8) |
| Option | Optional | Integer | seed | 42 | 분할과 학습의 난수 시드 | Random seed for the split and training |
| Option | Optional | Float | max_missing_fraction | 0.2 | train에서 결측 비율이 이보다 큰 descriptor 제거(0 이상 1 미만) | Descriptors with a larger missing fraction in train are removed (0 to below 1) |
| Option | Optional | Float | correlation_threshold | 0.995 | train에서 상관 절대값이 이 이상인 descriptor 중 하나 제거(0 초과 1 이하) | One of each descriptor pair with absolute correlation at or above this in train is removed (above 0 to 1) |
| Option | Optional | String | method_label | user method | 사용자 LC 분석법 이름(컬럼, 이동상 등). 모델 manifest에 기록 | Name of the user LC method (column, mobile phase and so on), recorded in the model manifest |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SMILES | 필수 | 분자 구조 문자열 | CCO |
| RT | 필수 | 측정 RT(`experimental_rt`, `retention_time`도 가능). 0 이상 숫자, 모든 행에 필요 | 2.10 |
| model_type | 선택 | RP 또는 HILIC 한 가지. 없으면 model 인자로 지정 | RP |
| compound_id, Name | 선택 | 추적용 정보 | S001 |

```
compound_id,SMILES,RT
S001,CCO,2.10
S002,CCN,2.80
S003,O=C(O)c1ccccc1,5.40
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 한 번 실행에 한 분리 모드(RP 또는 HILIC)만 학습합니다. 두 모드가 섞인 표는 멈추므로 모드별로 나눠 실행해 주세요. | One run trains one separation mode (RP or HILIC); a table mixing modes stops, so run each mode separately. |
| 같은 컬럼, 이동상, gradient, RT 단위로 측정한 자료만 넣어 주세요. 조건이 섞이면 모델이 어느 조건에도 맞지 않습니다. | Use data measured with one column, mobile phase, gradient and RT unit; mixed conditions give a model that fits none. |
| 정제 후 25행과 서로 다른 구조 15개 이상이 필요하며, 분할마다 화합물이 2개 이상이어야 합니다. 같은 구조·같은 RT 중복은 하나로 합치고, 같은 구조의 반복 측정은 같은 분할에 넣습니다. 잘못된 SMILES는 rejected_rows.csv에 남습니다. | At least 25 rows and 15 distinct structures are needed after cleaning, with two or more compounds per split. Duplicates of the same structure and RT are merged, repeated measurements of one structure go to the same split, and invalid SMILES are listed in rejected_rows.csv. |
| validation_leaderboard.csv의 score_val은 음의 RMSE입니다. 0에 가까울수록 좋습니다. | score_val in validation_leaderboard.csv is the negative RMSE; values closer to 0 are better. |
| time_limit 안에 모든 후보가 학습된다는 보장은 없습니다. 실제로 만들어진 모델은 leaderboard로 확인해 주세요. 메모리 16GB 이상과 디스크 10GB 이상을 권장합니다. | There is no guarantee every candidate finishes within time_limit; check the leaderboard for the models built. 16 GB of memory and 10 GB of disk or more are recommended. |
| rt_unit은 이름만 기록하고 값을 바꾸지 않습니다. 이후 비교에서 같은 이름을 써야 합니다. | rt_unit is only recorded and values are not converted; use the same label in the later comparison. |

### 분석 개념 이미지
그림: `docs/Retip/images/module2_concept.png`

- 레전드(국문): **그림. 사용자 머무름 시간 모델 학습.** (Measured library) SMILES와 측정 RT 표를 정규화한 구조 단위로 묶고, 학습 전에 예약 test 화합물을 먼저 떼어 둡니다. (Train and select) descriptor 필터는 train에서만 정하고, pyRetip 방식의 학습 인터페이스로 후보 모델을 학습한 뒤 validation RMSE로 best를 고릅니다. (Reusable models) AutoGluon 모델과 manifest, 학습 구조 해시, 학습에 쓰지 않은 예약 test CSV를 저장합니다.
- 레전드(영문): **Figure. Training a user retention time model.** (Measured library) The table of SMILES and measured RT is grouped by canonical structure, and reserved test compounds are set aside before training. (Train and select) Descriptor filters are fitted on train only, candidate models are trained through the pyRetip-style interface, and the best is chosen by validation RMSE. (Reusable models) AutoGluon models with a manifest, training structure hashes and the unused reserved test CSV are saved.
- 출처: 서울대 식품대사체학 연구실 제공 모식도(외부 논문 그림 사용 안 함)

### 스크립트 사용 예제
```
python retip_train.1.0.py \
  input_file=/data/rt_library.csv \
  output_dir=/data/retip_train \
  model=auto \
  sheet=first \
  rt_unit=auto \
  time_limit=1200 \
  algorithms=GBM,CAT,RF,XT,KNN \
  test_size=0.2 \
  validation_size=0.2 \
  seed=42 \
  max_missing_fraction=0.2 \
  correlation_threshold=0.995 \
  method_label=user method
```

### 주요 결과 이미지
서울대 예제(`synthetic_training_RP.csv`, 72개 화합물, RP)의 결과입니다. RT는 기능 확인용 합성값입니다.

**결과 1. 구조 그룹 분할과 validation 성능**
- 결과 파일: `result/training.png` (같은 그림 `training.svg`, 표 `split_assignments.csv`, `validation_leaderboard.csv`)

그림: `docs/Retip/images/module2_result.png`

- 레전드(국문): **학습 자료 분할과 후보 모델의 validation 성능.** 왼쪽(Structure-group split)은 구조 그룹 기준으로 train, reserved_test, validation에 배정된 행 수(Rows)이고, 오른쪽(Validation model selection)은 학습에 성공한 후보 모델의 validation RMSE(model unit)입니다. 막대가 짧을수록 좋으며, 가장 짧은 모델이 best로 저장됩니다. 정상 결과는 세 분할에 모두 화합물이 있고 후보가 여러 개 학습된 경우입니다. 예시 데이터에서는 72행이 train 42, reserved_test 15, validation 15행으로 나뉘었고, ExtraTrees와 WeightedEnsemble_L2의 validation RMSE가 약 0.15로 RandomForest(약 0.18)보다 낮았습니다. 그림 위 문구처럼 합성 RT라 실제 측정 성능이 아닙니다.
- 레전드(영문): **Split of the training data and validation performance of the candidates.** Left (Structure-group split): rows assigned to train, reserved_test and validation by structure group. Right (Validation model selection): validation RMSE (model unit) of the candidates that trained successfully; shorter is better and the shortest is saved as best. A normal result has compounds in all three splits and several trained candidates. In the example data the 72 rows split into 42 train, 15 reserved_test and 15 validation rows, and ExtraTrees and WeightedEnsemble_L2 reached a validation RMSE of about 0.15, below RandomForest (about 0.18). As the figure title says, the RTs are synthetic, so this is not measured performance.

---

## 3. retip_compare

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | retip_compare | retip_compare |
| 서브 타이틀 | 기본·사용자 머무름 시간 모델 성능 비교 | Default and user RT model comparison |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Metabolite_Identification (신규) | Metabolite_Identification (new) |
| 태그 | retention time, model comparison, RMSE, MAE, R-squared, AutoGluon, RP, HILIC | |
| 레퍼런스 URL | https://doi.org/10.1021/acs.analchem.9b05765 | |
| 컨테이너 이미지 | bx_retip_compare.1.0 | |
| 실행 스크립트 파일 | retip_compare.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 8GB | 4 cores, 8 GB of memory |

### 실행 이미지
이미지: bx_retip_compare 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/Retip/bx_retip_compare.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Debian 12 bookworm (`python:3.13.15-slim-bookworm`) |
| 설치 도구 / installer | pip(해시 고정), apt (conda 사용 안 함) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| Python | 3.13.15 | https://www.python.org/ |
| RDKit | 2026.3.1 | https://www.rdkit.org/ |
| AutoGluon Tabular | 1.5.0 | https://auto.gluon.ai/ |
| scikit-learn | 1.7.1 | https://scikit-learn.org/ |
| SciPy | 1.16.3 | https://scipy.org/ |
| NumPy | 2.3.5 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| LightGBM | 4.6.0 | https://lightgbm.readthedocs.io/ |
| CatBoost | 1.2.10 | https://catboost.ai/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| openpyxl | 3.1.5 | https://openpyxl.readthedocs.io/ |
| mdcc (RTpred 코드, 서울대 식품대사체학 연구실) | Revision 2 | - |

- **태그(키워드):** 머무름시간예측, 대사체동정, RDKit, AutoGluon
- **내용(국문):** 화합물 구조(SMILES)로 액체크로마토그래피 머무름 시간(RT)을 예측하는 실행 환경입니다. RDKit으로 구조 descriptor를 계산하고 AutoGluon 모델로 예측·학습합니다. RP·HILIC 기본 모델(best: WeightedEnsemble_L3)이 이미지 안 `/opt/mdcc/models`에 들어 있습니다. 실행 중 인터넷과 GPU를 쓰지 않습니다.
- **내용(영문):** Runtime environment for predicting liquid chromatography retention time (RT) from compound structures (SMILES). RDKit computes structure descriptors and AutoGluon models predict and train. The default RP and HILIC models (best: WeightedEnsemble_L3) are bundled in `/opt/mdcc/models`. No internet access or GPU is used at run time.

### 내용(국문)
같은 평가 화합물에서 기본 모델과 사용자 모델의 RT 예측 오차를 비교합니다. 사용자 모델을 만든 뒤 기본 모델 대신 쓸 만한지 판단하는 데 씁니다.
- 평가 표는 학습 때 떼어 둔 reserved_test.csv가 기본이며, 별도의 측정 RT 표를 줄 수도 있습니다.
- 사용자 모델의 학습·validation 구조가 평가 표에 있으면 데이터 누수로 보고 멈춥니다. 기본 모델의 학습 구조 목록은 없어 기본 모델과의 중복은 unknown으로 기록합니다.
- 모든 후보를 같은 유효 행으로 평가해 n, RMSE, MAE, R²와 순위를 표로 만들고, 행별 예측을 긴 표로 남깁니다.
- 후보별 RMSE 막대와 best 모델의 측정-예측 산점도, HTML 보고서를 만듭니다. 순위는 저장된 best나 기본 모델을 바꾸지 않습니다.

### 내용(영문)
Compares the RT prediction errors of the default model and a user model on the same evaluation compounds, to judge whether the user model should replace the default.
- The evaluation table is the reserved_test.csv held out in training by default; a separate table of measured RTs can be given.
- If structures used for training or validation of the user model appear in the evaluation table, this is treated as leakage and the run stops. No list of the default model's training structures exists, so its overlap is recorded as unknown.
- All candidates are evaluated on the same valid rows, giving n, RMSE, MAE, R² and a rank, with per-row predictions in a long table.
- An RMSE bar chart of the candidates, a measured-versus-predicted scatter of the best models, and an HTML report are drawn. The ranking does not change the saved best or the default model.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/retip_train | 사용자 모델 학습 결과 폴더. 안에 result/model/(model_manifest.json)과 result/reserved_test.csv가 있어야 함 | Training output folder holding result/model/ (with model_manifest.json) and result/reserved_test.csv |
| Output | Required | Directory | output_dir | /data/retip_compare | 결과 폴더. result/에 comparison.csv, predictions_long.csv, comparison.png·.svg, report.html, manifest.json | Output folder: result/ holds comparison.csv, predictions_long.csv, comparison.png and .svg, report.html and manifest.json |
| Option | Required | List | model | RP | 분리 모드(RP, HILIC). 사용자 모델의 모드와 같아야 함 | Separation mode (RP, HILIC); must match the user model |
| Input | Optional | File | eval_file | reserved_test | 평가 표(CSV 또는 XLSX, SMILES와 측정 RT). reserved_test 또는 빈 값 = 학습 때 떼어 둔 reserved_test.csv | Evaluation table (CSV or XLSX with SMILES and measured RT). reserved_test or empty = the reserved_test.csv held out in training |
| Option | Optional | String | sheet | first | XLSX 시트 이름. first 또는 빈 값 = 첫 시트. CSV에는 적용 안 함 | XLSX sheet name; first or empty = the first sheet. Ignored for CSV |
| Option | Optional | String | rt_unit | auto | RT 단위 이름. auto 또는 빈 값 = 사용자 모델에 기록된 단위. 학습 때와 다르면 멈춤 | RT unit label. auto or empty = the unit recorded in the user model; stops if it differs from training |
| Option | Optional | List | scope | all | 비교 범위. all = 사용자 모델의 모든 후보, best = 저장된 best만(기본 모델은 항상 best 하나) | Comparison scope: all = every user-model candidate, best = the saved best only (the default model is always its best) |
| Option | Optional | String | title | Default and user model comparison | 보고서와 그림 제목 | Title of the report and figure |

### 샘플시트
평가 표(eval_file)를 따로 줄 때의 형식입니다.

| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SMILES | 필수 | 분자 구조 문자열 | CCO |
| RT | 필수 | 측정 RT. 0 이상 숫자 | 2.10 |
| model_type | 선택 | 있으면 model 인자와 같아야 함 | RP |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 평가 화합물은 사용자 모델의 학습·validation에 쓰지 않은 것이어야 합니다. 겹치면 "Evaluation leakage"로 멈춥니다. 가장 안전한 평가 표는 학습 결과의 reserved_test.csv입니다. | Evaluation compounds must not have been used for training or validation of the user model; overlap stops the run with "Evaluation leakage". The safest evaluation table is the reserved_test.csv of the training output. |
| 기본 모델의 학습 자료와 겹치는지는 알 수 없습니다(unknown). 평가 화합물이 기본 모델 학습에 쓰였다면 기본 모델 성능이 실제보다 좋게 보일 수 있습니다. | Overlap with the default model's training data is unknown; if evaluation compounds were used to train the default model, its performance may look better than it is. |
| LC 조건이나 RT 단위가 다른 모델 사이의 수치 비교는 조건을 맞춘 검증이 아닙니다. 사용자 모델과 평가 표의 RT 단위 이름이 다르면 멈춥니다. | Comparing models made under different LC conditions or RT units is not a matched validation; a different RT unit label between the user model and the evaluation stops the run. |
| model은 필수이며 사용자 모델의 모드와 같아야 합니다. 비교는 같은 모드끼리만 합니다. | model is required and must match the user model; only models of the same mode are compared. |
| 잘못된 구조는 지표에서 빠지지만 predictions_long.csv에는 남습니다. 측정 RT의 분산이 0이면 R²는 빈 값입니다. 유효한 평가 구조가 2개 미만이면 멈춥니다. | Invalid structures are excluded from the metrics but kept in predictions_long.csv; R² is empty when the measured RTs have no variance; fewer than two valid evaluation structures stop the run. |

### 분석 개념 이미지
그림: `docs/Retip/images/module3_concept.png`

- 레전드(국문): **그림. 기본 모델과 사용자 모델의 성능 비교.** (Common evaluation set) SMILES와 측정 RT 평가 표에서 사용자 학습 자료와의 중복을 확인하고, 모든 모델을 같은 유효 행으로 평가합니다. (Models to compare) 이미지의 기본 best 모델과 사용자 모델(모든 후보 또는 best)을 비교합니다. (Performance comparison) RMSE, MAE, R²와 순위표, 측정-예측 그림을 만들며, 기본 모델은 바뀌지 않습니다.
- 레전드(영문): **Figure. Comparing the default and user models.** (Common evaluation set) The evaluation table of SMILES and measured RT is checked for overlap with the user training data, and every model is evaluated on the same valid rows. (Models to compare) The default best model of the image is compared with the user model (all candidates or the best). (Performance comparison) RMSE, MAE, R², a rank table and a measured-versus-predicted plot are produced; the default model stays unchanged.
- 출처: 서울대 식품대사체학 연구실 제공 모식도(외부 논문 그림 사용 안 함)

### 스크립트 사용 예제
```
python retip_compare.1.0.py \
  input_dir=/data/retip_train \
  output_dir=/data/retip_compare \
  model=RP \
  eval_file=reserved_test \
  sheet=first \
  rt_unit=auto \
  scope=all \
  title=Default and user model comparison
```

### 주요 결과 이미지
서울대 예제(RP 합성 RT 학습 결과의 reserved_test, scope=all) 결과입니다.

**결과 1. 후보별 오차와 측정-예측 비교**
- 결과 파일: `result/comparison.png` (같은 그림 `comparison.svg`, 표 `comparison.csv`, `predictions_long.csv`)

그림: `docs/Retip/images/module3_result.png`

- 레전드(국문): **같은 평가 행에서 본 모델별 오차.** 왼쪽(All candidates: same evaluation rows)은 기본 모델(default/WeightedEnsemble_L3)과 사용자 모델 후보(user_1/…)의 RMSE(model unit)로, 짧을수록 좋습니다. 오른쪽(Selected best models)은 기본 best(파랑)와 사용자 best(주황)의 측정 RT(Measured RT) 대비 예측 RT(Predicted RT)이며, 점선(y = x)에 가까울수록 정확합니다. 예시 데이터에서는 사용자 후보의 RMSE가 약 0.1, 기본 모델이 약 3.6이었고 기본 모델 점은 점선 위로 크게 벗어났습니다. 사용자 모델의 학습 RT가 합성값이고 기본 모델과 LC 조건·단위가 같지 않으므로, 이 차이는 성능 우열이 아니라 비교 과정이 동작함을 보여 줍니다.
- 레전드(영문): **Errors of each model on the same evaluation rows.** Left (All candidates: same evaluation rows): RMSE (model unit) of the default model (default/WeightedEnsemble_L3) and the user candidates (user_1/...); shorter is better. Right (Selected best models): predicted RT against measured RT for the default best (blue) and the user best (orange); points nearer the dashed y = x line are more accurate. In the example data the user candidates had an RMSE of about 0.1 and the default model about 3.6, with its points far above the line. The user training RTs are synthetic and the LC conditions and units differ from the default model, so the gap shows that the comparison works, not which model is better.
