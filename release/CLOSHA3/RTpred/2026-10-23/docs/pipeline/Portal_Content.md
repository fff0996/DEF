# RTpred 파이프라인 포탈 등록 콘텐츠

KOBIC 포탈의 RTpred 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. CLOSHA에는 서울대가 제안한 이름 그대로 `RTpred` 파이프라인 하나로 등록합니다(rtpred_train → rtpred_predict, rtpred_train → rtpred_compare). 학습 자료가 없는 사용자는 rtpred_predict 모듈만 단독으로 실행해 사전 학습 모델로 예측합니다. 모듈별 입력·옵션·결과는 `docs/RTpred/modules/Registration.md`에 있습니다. 서울대 원문 자료는 `docs/RTpred/CONTENT_KO.md`, `USER_GUIDE_KO.md`입니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

---

## 0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `RTpred` |
| 서브 타이틀(국문) | 화합물 구조로 LC 머무름 시간을 예측하고, 내 실험 자료로 모델을 학습해 사전 학습 모델과 성능을 비교하는 분석 도구 |
| 서브 타이틀(영문) | Retention time prediction from compound structures, with user model training and comparison against the pre-trained models |
| 구성 모듈 | rtpred_train, rtpred_predict, rtpred_compare |
| Version | 1.0 (CLOSHA 3.0 첫 배포) |
| Reference | https://doi.org/10.1021/acs.analchem.9b05765 |
| Keyword(태그) | retention time prediction, metabolomics, untargeted metabolomics, metabolite annotation, LC-MS, reversed phase, HILIC, model training, model comparison, machine learning, cheminformatics |
| 대분류 / 중분류 | Metabolomics / Cheminformatics (서울대 제안 "대사체 분석 / 화학정보학 / 머신러닝"을 옮김. 머신러닝은 Keyword로) |
| 대표 이미지 | rtpred_predict 결과 그림(`docs/RTpred/images/module1_result.png`) |

등록 메모:
- Reference는 RTpred가 바탕으로 하는 Retip 원논문입니다: Bonini P, Kind T, Tsugawa H, Barupal DK, Fiehn O. Retip: Retention Time Prediction for Compound Annotation in Untargeted Metabolomics. *Anal Chem* 92, 7515-7522 (2020).
- 서울대가 제안한 파이프라인 이름은 "RTpred", 부제목은 "내장 best model의 RT 예측부터 사용자 실험 자료 기반 모델 생성, 기본·사용자 모델 성능 비교까지 제공하는 분석 도구"입니다(`CONTENT_KO.md` 1~5). 서브 타이틀은 이 제안을 지금 용어(사전 학습 모델)와 흐름(학습 → 예측 → 비교)에 맞게 다듬었습니다.

---

## 1. 파이프라인 소개 / Introduction

### 국문
RTpred 파이프라인은 화합물 구조(SMILES)로 액체크로마토그래피의 머무름 시간(RT)을 예측하는 분석 도구입니다. 사용자가 자기 LC 조건에서 측정한 RT 표로 분리 모드(RP, HILIC)마다 예측 모델을 학습하고(rtpred_train), 그 모델로 새 화합물의 RT를 예측하며(rtpred_predict), 학습에 쓰지 않은 화합물에서 이미지에 들어 있는 사전 학습 모델과 오차를 비교합니다(rtpred_compare). 구조는 RDKit descriptor로 바꾸고 AutoGluon 모델로 학습·예측합니다. 학습 자료가 없으면 rtpred_predict만 단독으로 실행해 사전 학습 RP·HILIC 모델로 예측할 수 있습니다. 비표적 대사체 분석에서 같은 질량을 가진 후보 화합물 가운데 측정 RT와 예측 RT가 맞는 것을 고르는 데 씁니다.

### English
The RTpred pipeline predicts liquid chromatography retention time (RT) from compound structures (SMILES). From RTs measured under the user's own LC conditions it trains a prediction model for each separation mode (RP, HILIC) (rtpred_train), predicts the RT of new compounds with it (rtpred_predict), and compares its errors with the pre-trained models in the image on compounds not used for training (rtpred_compare). Structures are turned into RDKit descriptors and AutoGluon models train and predict. Without training data, rtpred_predict can run alone with the pre-trained RP and HILIC models. In untargeted metabolomics it helps to choose, among candidates of the same mass, those whose predicted RT matches the measured RT.

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

그림: `docs/RTpred/pipeline/figures/pipeline.png` (원본 `pipeline.svg`)

등록 메모: 서울대 흐름도(docs/RTpred/images/pipeline_flow.png)는 "예측은 사용자 학습과 무관"으로 그려져 있습니다. 서울대 답변에 따라 예측 모듈에 학습 모델 입력(model_dir)을 더했으므로 노선도는 새로 그렸습니다.

### 대체 텍스트 (alt)
- 국문: RTpred 흐름도. 측정 RT 표로 rtpred_train이 RP·HILIC 모델을 학습하고, 학습 결과가 rtpred_predict(새 화합물 예측)와 rtpred_compare(예약 test로 사전 학습 모델과 비교)로 각각 이어짐. rtpred_predict는 사전 학습 모델만으로도 실행됨.
- English: RTpred workflow: rtpred_train learns RP and HILIC models from a measured RT table, and its output feeds rtpred_predict (prediction of new compounds) and rtpred_compare (comparison with the pre-trained models on the reserved test); rtpred_predict also runs with the pre-trained models alone.

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

그림: `docs/RTpred/pipeline/figures/concept_2.png` (그림 2, 원본 `concept_2.svg`)

### 국문 (그림 2 설명)
**그림 2. 구조로 머무름 시간을 예측하는 원리(QSRR).** (A) 구조를 아는 화합물들의 측정 RT를 모읍니다. (B) 구조(SMILES)를 RDKit descriptor(logP, TPSA, 수소결합 받개 수 등)로 바꿉니다. (C) descriptor와 측정 RT의 관계를 머신러닝 모델로 학습하고, (D) 학습에 쓰지 않은 자료로 검증합니다. (E) 학습한 모델이 새 구조의 RT를 예측합니다. RTpred의 rtpred_train이 A~D를(AutoGluon, 모드마다 모델 하나), rtpred_predict가 E를, rtpred_compare가 떼어 둔 자료로 D와 E를 맡으며, 이미지의 사전 학습 모델도 같은 방식으로 만들었습니다. 모식도입니다. Xie 외, J Pharm Anal 2025, Fig. 1을 수정(CC BY 4.0).

### English (figure 2 legend)
**Figure 2. The principle of predicting retention time from structure (QSRR).** (A) Measured RTs of compounds with known structures are collected. (B) Structures (SMILES) are turned into RDKit descriptors (logP, TPSA, hydrogen-bond acceptors and so on). (C) A machine learning model learns the relation between descriptors and measured RT and (D) is validated on data not used for training. (E) The trained model predicts the RT of new structures. In RTpred, rtpred_train covers A-D (AutoGluon, one model per mode), rtpred_predict covers E, and rtpred_compare covers D and E on held-out data; the pre-trained models in the image were built the same way. Schematic. Adapted from Xie et al., J Pharm Anal 2025, Fig. 1 (CC BY 4.0).

### 대체 텍스트 (그림 2)
- 국문: QSRR 원리 흐름도. 측정 RT와 구조, 분자 descriptor, 모델 학습, 검증, RT 예측의 다섯 단계와 각 단계를 맡는 RTpred 모듈.
- English: QSRR principle: measured RTs and structures, molecular descriptors, model training, validation and RT prediction, with the RTpred module for each step.

### 출처 (그림 2)
Xie J, Chen S, Zhao L, Dong X. Application of artificial intelligence to quantitative structure-retention relationship calculations in chromatography. *J Pharm Anal* 15, 101155 (2025). https://doi.org/10.1016/j.jpha.2024.101155, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

---

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **학습 자료가 없으면 rtpred_predict만 실행해 주세요.** 측정 RT 자료가 없거나 내 LC 조건의 모델이 필요 없으면, 파이프라인 대신 rtpred_predict 모듈만 단독으로 실행하고 model_dir을 비워 두면 이미지에 들어 있는 사전 학습 RP·HILIC 모델로 예측합니다. 파이프라인은 rtpred_train으로 내 조건의 모델을 만들 때 씁니다.
2. **입력은 화합물 표(CSV 또는 XLSX)입니다.** 한 행이 화합물 하나이며 `SMILES` 열이 필요합니다. LC-MS raw 파일이나 샘플 그룹 정보는 필요하지 않습니다. CSV는 UTF-8, 첫 행이 헤더이고 소수점은 `.`입니다. 예전 `.xls`는 지원하지 않습니다.
3. **분리 모드는 RP와 HILIC이며, 입력 표의 `model_type` 열(행마다 RP 또는 HILIC)로 정합니다.** 세 모듈 모두 이 열이 필요하고, 한 표에 두 모드를 섞을 수 있습니다. 학습은 모드마다 따로 모델을 만들고, 사용자 모델로 예측하면 행마다 그 모드의 모델을 씁니다. 학습하지 않은 모드의 행은 예측하지 않고 결과에 `no_trained_model`로 표시합니다.
4. **사용자 모델은 같은 LC 조건과 RT 단위로 측정한 자료로 학습해 주세요.** 컬럼, 이동상, gradient가 섞이면 어느 조건에도 맞지 않는 모델이 됩니다. 모드마다 정제 후 25행·서로 다른 구조 15개 이상이 필요합니다.
5. **성능 비교에는 학습에 쓰지 않은 화합물을 써 주세요.** 학습 결과의 `reserved_test.csv`가 가장 안전합니다. 사용자 모델의 학습·validation 구조와 겹치면 데이터 누수로 멈춥니다.
6. **기본 모델의 RT 단위는 분(min)입니다.** 학습 조건(컬럼, 이동상, gradient)은 제공 자료에서 확인되지 않았으므로, 실측 RT와 비교할 때와 기본·사용자 모델을 비교할 때는 조건 차이를 감안해 주세요. 비교는 같은 모드끼리만 합니다.
7. **잘못된 SMILES는 지우지 않고 결과에 사유와 함께 남깁니다.** 오류가 아니라 입력 데이터의 결과입니다.
8. **모든 분석은 인터넷과 GPU 없이 CPU로 수행됩니다.** 기본 모델은 실행 이미지에 들어 있습니다.

### English
1. **Without training data, run rtpred_predict alone.** If you have no measured RTs or do not need a model for your own LC conditions, run only the rtpred_predict module with model_dir empty; it predicts with the pre-trained RP and HILIC models in the image. Use the pipeline to build models for your own conditions with rtpred_train.
2. **The input is a compound table (CSV or XLSX).** One row is one compound and a `SMILES` column is required; LC-MS raw files and sample group information are not needed. CSV files are UTF-8 with a header row and `.` as the decimal mark; legacy `.xls` is not supported.
3. **The separation modes are RP and HILIC, set per row in the `model_type` column of the input table.** All three modules need this column, and one table may mix both modes. Training builds a model per mode, and prediction with user models uses the model of each row's mode. Rows of a mode that was not trained are not predicted and are marked `no_trained_model` in the results.
4. **Train a user model with data measured under one LC condition and RT unit.** Mixed columns, mobile phases or gradients give a model that fits none of them. Each mode needs at least 25 rows and 15 distinct structures after cleaning.
5. **Compare models on compounds not used for training.** The `reserved_test.csv` of the training output is the safest choice; overlap with the user model's training or validation structures stops the run as leakage.
6. **The default models give RT in minutes.** Their training conditions (column, mobile phase, gradient) are not stated in the provided material, so keep condition differences in mind when comparing with measured RTs and between the default and user models. Models are compared only within a mode.
7. **Invalid SMILES are kept in the results with the reason.** This reflects the input, not an error.
8. **All analyses run on CPU without internet access or GPU.** The default models are in the runtime image.
