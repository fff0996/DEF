# RTpred (Retip) 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 RTpred 실행 이미지 설명입니다. 이미지는 `defs/Retip/bx_retip_<module>.1.0.def`로 만듭니다. 이 DEF는 서울대 식품대사체학 연구실이 준 DEF와 mdcc 코드·기본 모델을 CLOSHA DEF 규칙(`docs/CLOSHA_DEF_Generator_Agent_v1.md`)의 격리·검사 블록에 맞춘 것이며, 기반 이미지와 설치 방식(Debian, pip)은 서울대 구성을 따릅니다. 서울대 원문 설명은 `docs/Retip/CONTENT_KO.md` 12절과 `OPERATIONS_KO.md`입니다.

등록 메모: 버전과 도구 목록은 2026-10-22 기준 DEF 파일에서 옮겼습니다. DEF를 고치면 이 문서도 함께 고칩니다.

---

## 1. 공통 사항

### 국문
RTpred의 세 모듈은 각자의 Apptainer 이미지(SIF) 안에서 실행됩니다. 세 이미지는 같은 Python 패키지를 쓰고, 기본 모델은 예측·비교 이미지에만 들어 있습니다.
- **기반 운영체제:** 공식 Python 이미지 `python:3.13.15-slim-bookworm`(Debian 12)을 고유 식별값(digest)으로 고정합니다.
  - Bootstrap: `docker`
  - From: `python@sha256:2325bb286ec344af3e5898cc224b5844e2707ac6e26b1632516fd3edc84a5e26`
- **도구 설치:** 서울대 구성을 따라 conda 대신 pip(패키지 해시 고정)과 apt(`libgomp1`, `libstdc++6`, `fonts-dejavu-core`)를 씁니다.
- **분석 코드와 모델:** 서울대 mdcc 코드는 `/opt/mdcc/mdcc`, 기본 RP·HILIC 모델은 `/opt/mdcc/models`(예측·비교 이미지)에 있습니다. 모델 파일은 SHA256 목록으로 확인합니다.
- **KOBIC 래퍼 스크립트:** `retip_predict`, `retip_train`, `retip_compare` 래퍼는 이미지에 넣지 않고 실행할 때 연결합니다.
- **인터넷:** 실행 중에는 인터넷과 GPU를 쓰지 않습니다.

### English
Each of the three RTpred modules runs inside its own Apptainer image (SIF). The three images share the same Python packages, and the default models are only in the prediction and comparison images.
- **Base OS:** the official Python image `python:3.13.15-slim-bookworm` (Debian 12), pinned by its digest.
  - Bootstrap: `docker`
  - From: `python@sha256:2325bb286ec344af3e5898cc224b5844e2707ac6e26b1632516fd3edc84a5e26`
- **Tool installation:** following the SNU setup, pip (hash-pinned packages) and apt (`libgomp1`, `libstdc++6`, `fonts-dejavu-core`) are used instead of conda.
- **Analysis code and models:** the SNU mdcc code is in `/opt/mdcc/mdcc` and the default RP and HILIC models in `/opt/mdcc/models` (prediction and comparison images); model files are checked against a SHA256 list.
- **KOBIC wrapper scripts:** the `retip_predict`, `retip_train` and `retip_compare` wrappers are not stored in the images; they are bound at run time.
- **Internet:** no internet access or GPU at run time.

---

## 2. 이미지 목록 / Images

| 이미지 | 버전 | 사용하는 모듈 (스크립트) | 기본 모델 | SIF 크기 |
|---|---|---|---|---|
| bx_retip_predict | 1.0 | retip_predict (retip_predict.1.0.py, 작업 파일 1.2) | 포함 | 605MB |
| bx_retip_train | 1.0 | retip_train (retip_train.1.0.py, 작업 파일 1.1) | 없음 | 381MB |
| bx_retip_compare | 1.0 | retip_compare (retip_compare.1.0.py, 작업 파일 1.1) | 포함 | 605MB |

공통 도구(세 이미지 같음):

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

---

## 3. 이미지별 포탈 등록 / Portal registration

### 3.1 bx_retip_predict 1.0
- **태그(키워드):** 머무름시간예측, 대사체동정, RDKit, AutoGluon
- **내용(국문):** 화합물 구조(SMILES)로 액체크로마토그래피 머무름 시간(RT)을 예측하는 실행 환경입니다. RDKit으로 구조 descriptor를 계산하고 AutoGluon 모델로 예측합니다. RP·HILIC 기본 모델(best: WeightedEnsemble_L3)이 들어 있어 실행 중 인터넷과 GPU를 쓰지 않습니다.
- **내용(영문):** Runtime environment for predicting liquid chromatography retention time (RT) from compound structures (SMILES). RDKit computes structure descriptors and AutoGluon models predict. The default RP and HILIC models (best: WeightedEnsemble_L3) are bundled, so no internet access or GPU is used at run time.

### 3.2 bx_retip_train 1.0
- **태그(키워드):** 머무름시간예측, 모델학습, AutoGluon, RDKit
- **내용(국문):** 사용자가 측정한 머무름 시간 표로 RT 예측 모델을 학습하는 실행 환경입니다. RDKit descriptor와 AutoGluon(LightGBM, CatBoost, RandomForest, ExtraTrees, KNeighbors)으로 CPU에서 학습하며, 기본 모델은 넣지 않았습니다. 학습 자료 크기에 따라 메모리 16GB와 디스크 10GB 이상을 권장합니다.
- **내용(영문):** Runtime environment for training an RT prediction model from the user's measured retention times. It trains on CPU with RDKit descriptors and AutoGluon (LightGBM, CatBoost, RandomForest, ExtraTrees, KNeighbors); the default models are not included. 16 GB of memory and 10 GB of disk or more are recommended, depending on the data size.

### 3.3 bx_retip_compare 1.0
- **태그(키워드):** 머무름시간예측, 모델비교, RMSE, AutoGluon
- **내용(국문):** 같은 평가 화합물에서 기본 RT 모델과 사용자 모델의 오차(RMSE, MAE, R²)를 비교하는 실행 환경입니다. RP·HILIC 기본 모델이 들어 있으며, 사용자 모델은 bx_retip_train 1.0으로 학습한 것만 읽습니다. 실행 중 인터넷과 GPU를 쓰지 않습니다.
- **내용(영문):** Runtime environment for comparing the errors (RMSE, MAE, R²) of the default RT model and a user model on the same evaluation compounds. The default RP and HILIC models are bundled, and only user models trained with bx_retip_train 1.0 are read. No internet access or GPU is used at run time.

---

## 4. 검증 빌드 / Verification build

2026-10-07 Codespace에서 root 권한 빌드로 확인했습니다(root·--fakeroot 모두 성공, `%test` "runtime dependency checks passed"). 빌드 시간은 predict 5분, compare 5분, train 3분이었습니다. 호스트의 `/proc`·`/sys` 쓰기와 sysctl 변화는 없었습니다. 운영 빌드는 격리 검사를 통과한 뒤, 올라간 `mdcc/__pycache__`를 DEF가 설계대로 거부해 멈췄습니다(커밋 59857a9). 나머지 `%post`는 운영 환경에서 아직 실행되지 않았습니다.
