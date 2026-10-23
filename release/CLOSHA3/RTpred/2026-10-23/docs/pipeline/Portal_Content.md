# RTpred 파이프라인 포탈 등록 콘텐츠

KOBIC 포탈의 RTpred 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. 서울대 식품대사체학 연구실의 답변(2026-10-21)에 따라 두 파이프라인(기본 모델 예측, 사용자 모델)으로 등록하는 것을 제안합니다. 모듈별 입력·옵션·결과는 `docs/RTpred/modules/Registration.md`에 있습니다. 서울대 원문 자료는 `docs/RTpred/CONTENT_KO.md`, `USER_GUIDE_KO.md`입니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

---

## 0. 파이프라인 등록 항목 / Registration

| 항목 | 기본 모델 예측 | 사용자 모델 |
|---|---|---|
| Pipeline Name | `RTpred_Default_Prediction` | `RTpred_User_Model` |
| 구성 모듈 | rtpred_predict | rtpred_train, rtpred_predict, rtpred_compare |
| Version | 1.0 (CLOSHA 3.0 첫 배포) | 1.0 (CLOSHA 3.0 첫 배포) |
| Reference | https://doi.org/10.1021/acs.analchem.9b05765 | https://doi.org/10.1021/acs.analchem.9b05765 |
| Keyword(태그) | retention time prediction, metabolomics, untargeted metabolomics, metabolite annotation, LC-MS, reversed phase, HILIC, machine learning, cheminformatics | 같음 + model training, model comparison |
| 대분류 / 중분류 | Metabolomics / Cheminformatics (서울대 제안 "대사체 분석 / 화학정보학 / 머신러닝"을 옮김. 머신러닝은 Keyword로) | 같음 |
| 대표 이미지 | rtpred_predict 결과 그림(`docs/RTpred/images/module1_result.png`) | rtpred_compare 결과 그림(`docs/RTpred/images/module3_result.png`) |

등록 메모:
- Reference는 RTpred가 바탕으로 하는 Retip 원논문입니다: Bonini P, Kind T, Tsugawa H, Barupal DK, Fiehn O. Retip: Retention Time Prediction for Compound Annotation in Untargeted Metabolomics. *Anal Chem* 92, 7515-7522 (2020).
- 서울대가 제안한 파이프라인 이름은 "RTpred", 부제목은 "내장 best model의 RT 예측부터 사용자 실험 자료 기반 모델 생성, 기본·사용자 모델 성능 비교까지 제공하는 분석 도구"입니다(`CONTENT_KO.md` 1~5).

---

## 1. 파이프라인 소개 / Introduction

### 국문 (기본 모델 예측)
RTpred 기본 모델 예측 파이프라인은 화합물 구조(SMILES)만으로 액체크로마토그래피의 머무름 시간(RT)을 예측하는 분석 도구입니다. 화합물 표를 입력하면 RDKit으로 구조 특성(descriptor)을 계산하고, 이미지에 들어 있는 사전 학습 RP(역상)·HILIC 기본 모델로 화합물마다 RT를 예측합니다. 비표적 대사체 분석에서 같은 질량을 가진 후보 화합물 가운데 측정 RT와 예측 RT가 맞는 것을 고르는 데 쓸 수 있습니다.

### English (default prediction)
The RTpred default prediction pipeline predicts liquid chromatography retention time (RT) from compound structures (SMILES) alone. From a compound table it computes RDKit structure descriptors and predicts the RT of each compound with the pre-trained RP (reversed phase) and HILIC default models bundled in the image. In untargeted metabolomics it helps to choose, among candidates of the same mass, those whose predicted RT matches the measured RT.

### 국문 (사용자 모델)
RTpred 사용자 모델 파이프라인은 사용자가 자기 LC 조건에서 측정한 RT 표로 RT 예측 모델을 직접 학습하고, 그 모델로 예측하며, 기본 모델과 성능을 비교하는 분석 도구입니다. 학습 표를 구조 단위로 train, validation, 예약 test로 나눠 AutoGluon 후보 모델을 학습하고 validation 오차로 best 모델을 고릅니다. 학습한 모델로 새 화합물의 RT를 예측하고, 학습에 쓰지 않은 예약 test 화합물에서 기본 모델과 사용자 모델의 RMSE, MAE, R²를 비교합니다.

### English (user model)
The RTpred user model pipeline trains an RT prediction model from retention times measured under the user's own LC conditions, predicts with it, and compares it with the default model. The training table is split by structure into train, validation and a reserved test, AutoGluon candidate models are trained, and the best is chosen by validation error. The trained model predicts the RT of new compounds, and the default and user models are compared by RMSE, MAE and R² on reserved test compounds that were not used in training.

---

## 2. 분석 목표 / Analysis goals

### 국문
**RTpred로 확인할 수 있는 세 가지 분석 목표**

**01 이 화합물은 LC에서 언제 용출되는가**
화합물 구조로 RP 또는 HILIC 조건의 머무름 시간을 예측합니다. 측정 RT가 있으면 측정과 예측의 차이(ΔRT)도 계산합니다.

**02 내 LC 조건에 맞는 예측 모델은 어떻게 만드는가**
내 실험실에서 측정한 RT 표로 사용자 모델을 학습합니다. 한 표에 RP와 HILIC가 섞여 있으면 모드마다 모델을 만듭니다. 같은 구조가 학습과 평가에 섞이지 않게 나누고, validation 오차로 모델을 고릅니다.

**03 내 모델이 기본 모델보다 나은가**
학습에 쓰지 않은 같은 평가 화합물에서 기본 모델과 사용자 모델의 오차(RMSE, MAE)와 설명력(R²)을 비교합니다.

### English
**Three questions RTpred can answer**

**01 When does this compound elute in LC?**
The retention time under RP or HILIC conditions is predicted from the compound structure; with a measured RT, the difference between measured and predicted RT (ΔRT) is also given.

**02 How do I build a model for my own LC conditions?**
A user model is trained from RTs measured in your lab (one model per mode when a table mixes RP and HILIC), with structures kept apart between training and evaluation, and the model is chosen by validation error.

**03 Is my model better than the default model?**
The errors (RMSE, MAE) and explained variance (R²) of the default and user models are compared on the same evaluation compounds that were not used for training.

---

## 3. 분석 흐름 / Analysis workflow

그림: `docs/RTpred/pipeline/figures/pipeline_default.png` (기본 모델 예측, 원본 `pipeline_default.svg`)

그림: `docs/RTpred/pipeline/figures/pipeline_user_model.png` (사용자 모델, 원본 `pipeline_user_model.svg`)

등록 메모: 서울대 흐름도(docs/RTpred/images/pipeline_flow.png)는 "예측은 사용자 학습과 무관"으로 그려져 있습니다. 서울대 답변에 따라 예측 모듈에 학습 모델 입력(model_dir)을 더했으므로 노선도는 새로 그렸습니다.

### 대체 텍스트 (alt)
- 국문(기본 모델 예측): RTpred 기본 모델 예측 흐름도. 화합물 표(SMILES)가 이미지 안 기본 RP·HILIC 모델과 함께 rtpred_predict로 들어가 예측표와 그림, 보고서가 만들어짐.
- English (default prediction): RTpred default prediction workflow: a compound table (SMILES) goes into rtpred_predict with the bundled RP and HILIC models, producing a prediction table, plots and a report.
- 국문(사용자 모델): RTpred 사용자 모델 흐름도. 측정 RT 표로 rtpred_train이 모델을 학습하고, 학습 결과 폴더가 rtpred_predict(새 화합물 예측)와 rtpred_compare(예약 test로 기본 모델과 비교)로 각각 이어짐.
- English (user model): RTpred user model workflow: rtpred_train learns a model from a measured RT table, and its output folder feeds rtpred_predict (prediction of new compounds) and rtpred_compare (comparison with the default model on the reserved test).

---

## 4. 분석 개념 / Analysis concept

그림: `docs/RTpred/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 설명)
**그림. 구조로 예측한 머무름 시간으로 대사체 후보 거르기.** (A) 화합물 구조(SMILES)를 RDKit 구조 특성(질량, 극성(logP), 고리 수, 수소결합 주개 등)으로 바꾸고, 학습된 AutoGluon 앙상블 모델(기본 모델 또는 사용자 모델)로 머무름 시간(RT)을 예측합니다. 측정 RT가 있으면 ΔRT(측정 - 예측)를 함께 계산합니다. (B) LC-MS에서 측정한 피크 하나에 같은 질량의 후보 구조가 여러 개 있을 때, 예측 RT가 측정 피크 주변 범위(초록 음영) 안에 드는 후보(초록)는 남기고 벗어나는 후보(빨강)는 뺍니다. RT, 범위, 후보는 모식적인 값입니다(측정 피크 RT 5.2).

### English (figure legend)
**Figure. Filtering metabolite candidates with retention times predicted from structure.** (A) Compound structures (SMILES) are turned into RDKit descriptors (mass, polarity (logP), ring count, hydrogen-bond donors and so on), and a trained AutoGluon ensemble (default or user model) predicts the retention time (RT); with a measured RT, ΔRT (measured - predicted) is also computed. (B) When several candidate structures share the mass of one LC-MS peak, candidates whose predicted RT falls within a window around the measured peak (green shading) are kept (green) and the others are dropped (red). RTs, the window and the candidates are schematic (measured peak RT 5.2).

### 대체 텍스트 (alt)
- 국문: RTpred 개념도. 구조에서 descriptor와 모델을 거쳐 RT를 예측하는 과정과, 예측 RT 범위로 같은 질량의 후보 화합물을 거르는 예를 보여 줌.
- English: RTpred concept: RT prediction from structure through descriptors and a model, and filtering of same-mass candidates by the predicted RT window.

### 출처 / Reference
직접 작성한 모식도(외부 그림 사용 안 함)

---

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **입력은 화합물 표(CSV 또는 XLSX)입니다.** 한 행이 화합물 하나이며 `SMILES` 열이 필요합니다. LC-MS raw 파일이나 샘플 그룹 정보는 필요하지 않습니다. CSV는 UTF-8, 첫 행이 헤더이고 소수점은 `.`입니다. 예전 `.xls`는 지원하지 않습니다.
2. **분리 모드는 RP와 HILIC이며, 입력 표의 `model_type` 열(행마다 RP 또는 HILIC)로 정합니다.** 세 모듈 모두 이 열이 필요하고, 한 표에 두 모드를 섞을 수 있습니다. 학습은 모드마다 따로 모델을 만들고, 사용자 모델로 예측하면 행마다 그 모드의 모델을 씁니다. 학습하지 않은 모드의 행은 예측하지 않고 결과에 `no_trained_model`로 표시합니다.
3. **사용자 모델은 같은 LC 조건과 RT 단위로 측정한 자료로 학습해 주세요.** 컬럼, 이동상, gradient가 섞이면 어느 조건에도 맞지 않는 모델이 됩니다. 모드마다 정제 후 25행·서로 다른 구조 15개 이상이 필요합니다.
4. **성능 비교에는 학습에 쓰지 않은 화합물을 써 주세요.** 학습 결과의 `reserved_test.csv`가 가장 안전합니다. 사용자 모델의 학습·validation 구조와 겹치면 데이터 누수로 멈춥니다.
5. **기본 모델의 RT 단위는 분(min)입니다.** 학습 조건(컬럼, 이동상, gradient)은 제공 자료에서 확인되지 않았으므로, 실측 RT와 비교할 때와 기본·사용자 모델을 비교할 때는 조건 차이를 감안해 주세요. 비교는 같은 모드끼리만 합니다.
6. **잘못된 SMILES는 지우지 않고 결과에 사유와 함께 남깁니다.** 오류가 아니라 입력 데이터의 결과입니다.
7. **모든 분석은 인터넷과 GPU 없이 CPU로 수행됩니다.** 기본 모델은 실행 이미지에 들어 있습니다.

### English
1. **The input is a compound table (CSV or XLSX).** One row is one compound and a `SMILES` column is required; LC-MS raw files and sample group information are not needed. CSV files are UTF-8 with a header row and `.` as the decimal mark; legacy `.xls` is not supported.
2. **The separation modes are RP and HILIC, set per row in the `model_type` column of the input table.** All three modules need this column, and one table may mix both modes. Training builds a model per mode, and prediction with user models uses the model of each row's mode. Rows of a mode that was not trained are not predicted and are marked `no_trained_model` in the results.
3. **Train a user model with data measured under one LC condition and RT unit.** Mixed columns, mobile phases or gradients give a model that fits none of them. Each mode needs at least 25 rows and 15 distinct structures after cleaning.
4. **Compare models on compounds not used for training.** The `reserved_test.csv` of the training output is the safest choice; overlap with the user model's training or validation structures stops the run as leakage.
5. **The default models give RT in minutes.** Their training conditions (column, mobile phase, gradient) are not stated in the provided material, so keep condition differences in mind when comparing with measured RTs and between the default and user models. Models are compared only within a mode.
6. **Invalid SMILES are kept in the results with the reason.** This reflects the input, not an error.
7. **All analyses run on CPU without internet access or GPU.** The default models are in the runtime image.
