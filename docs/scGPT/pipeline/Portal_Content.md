# scGPT 파이프라인 포탈 등록 콘텐츠

KOBIC 포탈의 scGPT 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. 모듈별 입력·옵션·결과는 `docs/scGPT/modules/Registration.md`와 `docs/scGPT/modules/Portal_Content.md`에 있습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

---

## 0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `scGPT_Phenotype_Classification_Pipeline` |
| 서브 타이틀(국문) | 단일세포 표현형 분류 |
| 서브 타이틀(영문) | Single-cell phenotype classification |
| 구성 모듈 | scgpt_prep → scgpt_embed (GPU) → scgpt_train → scgpt_predict, scgpt_compare |
| Version | 1.0 (CLOSHA 3.0 첫 배포) |
| Reference | https://doi.org/10.1038/s41592-024-02201-0 |
| Keyword(태그) | single-cell RNA-seq, single-cell foundation model, cell embedding, phenotype classification, patient classification, multiple instance learning, attention pooling, machine learning, deep learning, disease classification, AI-ready dataset |
| 대분류 / 중분류 | Bio-AI / Single_Cell_Foundation_Model (중분류 신규) |
| 대표 이미지 | `docs/scGPT/pipeline/figures/thumbnail.png`: scgpt_compare의 ROC 곡선(K-BDS KAP241712 심장, DCM 대 HCM 26명) |

등록 메모:
- Reference는 파이프라인이 쓰는 사전학습 모델의 원논문입니다: Cui H, Wang C, Maan H, Pang K, Luo F, Duan N, Wang B. scGPT: toward building a foundation model for single-cell multi-omics using generative AI. *Nat Methods* 21, 1470-1480 (2024)(Europe PMC로 서지 확인, 2026-11-10).
- 대표 이미지는 2026-11-09 CLOSHA 실행의 `scgpt_compare/plots/roc.png`를 그대로 쓴 것입니다. scGPT 임베딩 평균(0.939)과 학습 모델(0.927)이 PCA(0.824)와 세포 유형 비율(0.697)보다 위에 있는 그림이라 파이프라인의 목적(사전학습 모델이 단순한 방법보다 나은지)을 한눈에 보여 줍니다.
- Keyword에는 도구 이름(scGPT)을 넣지 않았습니다. 모듈 태그에 있습니다.
- 이름은 2026-11-11에 `scGPT_Single_Cell_Phenotype_Classification_Pipeline`에서 줄였습니다(scGPT가 단일세포 모델이라 Single_Cell이 겹침). 단일세포라는 말은 서브 타이틀에 있습니다.
- 분류는 AI 파이프라인을 모으는 대분류 Bio-AI 아래, 사전학습 단일세포 모델을 쓰는 파이프라인 칸으로 정했습니다(2026-11-11). 다른 단일세포 foundation model 파이프라인도 같은 칸에 둡니다.

---

## 1. 파이프라인 소개 / Introduction

### 국문
scGPT 단일세포 표현형 분류 파이프라인은 단일세포 전사체 데이터로 개체(환자·공여자)의 표현형, 예를 들어 질환이나 치료 반응을 분류하는 AI 분석 도구입니다. 샘플별 count 행렬과 샘플 시트를 받아 세포 품질 확인, 유전자 이름 맞춤, 라벨 점검, 개체 단위 교차검증 분할로 AI 학습용 데이터셋을 만들고(scgpt_prep), 인체 세포 3,300만 개로 사전학습된 scGPT를 고정한 채 GPU에서 세포마다 임베딩을 만듭니다(scgpt_embed). 이어서 개체의 세포 임베딩을 attention으로 모아 분류 모델을 학습하고(scgpt_train), 새 개체의 표현형을 예측하며(scgpt_predict), 같은 개체와 분할에서 세포 유형 비율, 고변동 유전자 PCA 같은 단순한 방법과 성능을 비교합니다(scgpt_compare). 결과로 학습에 쓰지 않은 개체에서의 AUC와 신뢰구간, 개체별 예측 확률, 판정에 크게 기여한 세포 유형, 모델 카드를 얻습니다.

### English
The scGPT single-cell phenotype classification pipeline is an AI tool that classifies the phenotype of individuals (patients or donors), such as a disease or a treatment response, from single-cell transcriptome data. From per-sample count matrices and a sample sheet it builds an AI-ready dataset with cell quality control, gene name matching, label checks and individual-level cross-validation splits (scgpt_prep), and makes an embedding for every cell on a GPU with scGPT, pretrained on 33 million human cells and kept fixed (scgpt_embed). It then trains a classifier that pools each individual's cell embeddings with attention (scgpt_train), predicts the phenotype of new individuals (scgpt_predict), and compares performance with simpler methods such as cell type fractions and PCA of highly variable genes on the same individuals and splits (scgpt_compare). The results are the AUC with confidence intervals on individuals not used for training, predicted probabilities per individual, the cell types that weigh most in the decision, and a model card.

---

## 2. 분석 목표 / Analysis goals

### 국문
**단일세포 데이터로 개체의 표현형을 분류할 때 확인할 수 있는 네 가지 분석 목표**

**01 내 단일세포 데이터를 AI 학습에 바로 쓸 수 있는가**
샘플마다 세포 품질을 거르고, 유전자 이름을 scGPT 어휘와 맞추고, 샘플 시트의 라벨이 개체마다 하나인지 확인합니다. 환자 단위 교차검증 분할을 미리 정해 이후 모든 모듈이 같은 환자로 평가하게 합니다.

**02 사전학습 모델은 세포를 어떻게 표현하는가**
인체 세포 3,300만 개로 사전학습된 scGPT를 고정한 채로 세포마다 512차원 임베딩을 만들고, UMAP으로 라벨·코호트·세포 유형에 따른 분포를 확인합니다.

**03 개체의 표현형을 얼마나 잘 분류하는가**
개체의 세포 임베딩을 attention으로 모아 개체마다 하나의 예측 확률을 내는 분류 모델을 학습합니다. 학습에 쓰지 않은 개체로 채점한 AUC와 신뢰구간, 그리고 새 개체의 예측값과 판정에 크게 기여한 세포 유형을 확인합니다.

**04 사전학습 모델이 단순한 방법보다 나은가**
같은 개체와 같은 분할에서 세포 유형 비율, 변이 유전자의 PCA, scGPT 임베딩 평균과 학습 모델을 비교합니다. 차이와 신뢰구간, 순열 검정으로 나아졌는지를 숫자로 보여 주며, 나아지지 않으면 그 결과도 그대로 보여 줍니다.

### English
**Four questions single-cell phenotype classification can answer**

**01 Is my single-cell data ready for AI training?**
Cells are filtered per sample, gene names are matched to the scGPT vocabulary, and the sample sheet is checked so that each individual has one label. Patient-level cross-validation folds are fixed so that every later module evaluates on the same patients.

**02 How does the pretrained model represent the cells?**
scGPT, pretrained on 33 million human cells and kept frozen, gives each cell a 512-dimensional embedding, and UMAPs show how cells spread by label, cohort and cell type.

**03 How well can the phenotype of each individual be classified?**
A model pools each individual's cell embeddings with attention into one predicted probability per individual. AUC with confidence intervals on individuals not used in training, predictions for new individuals, and the cell types that weigh most are reported.

**04 Is the pretrained model better than simpler methods?**
On the same individuals and folds, cell-type fractions, PCA of variable genes and the mean scGPT embedding are compared with the trained model. Differences with confidence intervals and a permutation test show whether it is better; when it is not, that result is shown as well.

---

## 3. 분석 흐름 / Analysis workflow

그림: `docs/scGPT/pipeline/figures/pipeline.png` (원본 `pipeline.svg`, `make_pipeline_map.py`)

### 대체 텍스트 (alt)
- 국문: scGPT 파이프라인 흐름도. 단일세포 행렬과 샘플 시트를 scgpt_prep이 정리하고, scgpt_embed가 GPU에서 세포 임베딩을 만들며, scgpt_train이 분류 모델을 학습하고, scgpt_predict와 scgpt_compare가 임베딩과 모델로 예측과 비교를 함.
- English: scGPT pipeline workflow. scgpt_prep prepares the single-cell matrices and sample sheet, scgpt_embed makes cell embeddings on a GPU, scgpt_train trains the classifier, and scgpt_predict and scgpt_compare use the embeddings and the model for prediction and comparison.

---

## 4. 분석 개념 / Analysis concept

그림: `docs/scGPT/pipeline/figures/concept.png` (원본 `concept.svg`, `make_concept.py`)

### 국문 (그림 설명)
**그림. 사전학습 모델로 세포를 읽고, 세포를 모아 개체를 분류합니다.** (A) 세포마다 발현량이 높은 유전자(최대 1,200개)를 사전학습된 scGPT에 넣어 512개의 숫자(임베딩)로 바꿉니다. scGPT의 가중치는 바뀌지 않으며, 비슷한 세포는 비슷한 임베딩을 갖습니다. (B) 한 개체의 세포 임베딩마다 attention 가중치를 매겨 가중 평균한 개체 임베딩(표준화)에서 양성 라벨의 확률을 계산합니다. 학습은 이 부분만 합니다. scgpt_compare는 같은 개체와 분할에서 세포 유형 비율, 변이 유전자 PCA, scGPT 임베딩 평균과 학습 모델의 AUC를 비교합니다. 값은 모식적인 값입니다.

### English (figure legend)
**Figure. A pretrained model reads the cells, and pooled cells classify each individual.** (A) The most expressed genes of each cell (up to 1,200) go into pretrained scGPT, which turns the cell into 512 numbers (an embedding). The scGPT weights do not change, and similar cells get similar embeddings. (B) Each cell embedding of an individual gets an attention weight, and the weighted average (standardized) gives the probability of the positive label. Only this part is trained. scgpt_compare compares the AUC of cell-type fractions, PCA of variable genes, the mean scGPT embedding and the trained model on the same individuals and folds. Values are schematic.

### 대체 텍스트 (alt)
- 국문: scGPT 개념도. 위: 세포의 유전자 발현이 고정된 scGPT를 거쳐 임베딩이 되고 비슷한 세포끼리 모임. 아래: 개체마다 세포 임베딩에 attention을 주어 개체 임베딩과 예측 확률을 만들고, 같은 분할에서 다른 방법과 AUC를 비교함.
- English: scGPT concept. Top: a cell's gene expression passes through frozen scGPT into an embedding, and similar cells group together. Bottom: attention over each individual's cell embeddings gives an individual embedding and a predicted probability, compared with other methods by AUC on the same folds.

### 출처 / Reference
- (A) 직접 작성한 모식도(외부 그림 사용 안 함). scGPT 원 논문(Cui et al., Nat Methods 2024)은 공개 라이선스가 없어 그림을 쓰지 않음.
- (B) Do C, Lähdesmäki H. Incorporating hierarchical information into multiple instance learning for patient phenotype prediction with single-cell RNA-sequencing data. *Bioinformatics* 41(Suppl 1), i96-i104 (2025). https://doi.org/10.1093/bioinformatics/btaf241, Fig. 1을 수정(다시 그리고 세포 유형 단계를 빼고 라벨과 비교 상자를 더함). CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/). 서지와 라이선스는 Europe PMC로 확인(2026-11-10).

---

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **입력은 샘플별 단일세포 count 행렬과 샘플 시트입니다.** 행렬은 Cell Ranger 결과(`.h5`, mtx 폴더)나 raw count가 든 `.h5ad`이며 정규화·로그 변환하지 않은 정수 count여야 합니다. 샘플 시트에는 SampleID, PatientID, Cohort, Tissue, Time, Label 열이 필요합니다. 유전자 이름은 사람 유전자 기호(gene symbol)여야 scGPT 어휘와 맞습니다.
2. **분류는 개체 단위 이진 분류입니다.** 한 개체에 라벨 하나, 전체 두 종류(예: DCM과 HCM, PR과 PD)이며 positive_label로 양성을 정합니다. 학습과 평가의 단위는 세포가 아니라 개체입니다.
3. **라벨 있는 개체 수가 성능 판단을 좌우합니다.** 세포가 수십만 개여도 개체가 수십 명이면 AUC의 신뢰구간이 넓어, 단순한 방법과의 차이가 "차이 불분명"으로 나오기 쉽습니다. 양성·음성 각각 교차검증 fold 수(기본 5) 이상의 개체가 필요하고, 차이를 확정하려면 독립 코호트나 더 많은 개체가 필요합니다.
4. **scgpt_embed는 GPU 환경에서 실행합니다.** 나머지 네 모듈은 CPU로 실행합니다. 같은 데이터는 한 번만 임베딩하면 되고, 라벨이나 옵션을 바꿔 학습·비교를 반복할 때는 CPU 모듈만 다시 실행합니다.
5. **사전학습 모델(scGPT)은 학습하지 않습니다.** scGPT의 가중치는 고정되어 있고, 사용자 데이터로는 그 위의 작은 분류기만 학습합니다(파인튜닝하지 않음).
6. **성능이 낮게 나오는 것도 결과입니다.** 혈액으로 암 치료 반응을 예측하는 것처럼 데이터에 분류할 신호가 약하면 scGPT를 포함한 모든 방법이 AUC 0.5 근처에 머무릅니다. 반대로 정상 대 질환처럼 차이가 큰 문제는 모든 방법이 1.0 근처라 방법 간 차이를 볼 수 없습니다. scgpt_compare는 이런 경우도 숫자로 그대로 보여 줍니다.
7. **예측할 데이터는 학습 데이터와 같은 조직·시점·측정 방식이어야 합니다.** 같은 scGPT 체크포인트로 임베딩해야 하며, 체크포인트가 다르면 예측이 멈추고 조직·시점이 다르면 경고합니다.
8. **사람 데이터로 학습한 모델은 학습 데이터의 이용 조건을 따릅니다.** scgpt_train의 data_terms에 조건을 적으면 모델 카드에 남습니다. 통제 접근 데이터(예: K-BDS 승인 데이터)로 만든 모델은 같은 조건으로만 공유해 주세요.
9. **모든 분석은 인터넷 없이 실행됩니다.** scGPT whole-human 체크포인트가 실행 이미지에 들어 있습니다.

### English
1. **The inputs are per-sample single-cell count matrices and a sample sheet.** Matrices are Cell Ranger output (`.h5`, mtx folders) or `.h5ad` files with raw counts, as integer counts without normalization or log transformation. The sample sheet needs SampleID, PatientID, Cohort, Tissue, Time and Label columns. Gene names must be human gene symbols to match the scGPT vocabulary.
2. **Classification is binary and per individual.** Each individual has one label, with two values in total (for example DCM and HCM, or PR and PD), and positive_label sets the positive one. The unit of training and evaluation is the individual, not the cell.
3. **The number of labeled individuals decides how far the performance can be judged.** With hundreds of thousands of cells but tens of individuals, AUC intervals are wide and differences from simpler methods easily come out as "not clearly different". Each class needs at least as many individuals as cross-validation folds (5 by default), and confirming a difference needs an independent cohort or more individuals.
4. **scgpt_embed runs on a GPU environment;** the other four modules run on CPUs. A data set needs embedding only once; when labels or options change, only the CPU modules are rerun for training and comparison.
5. **The pretrained model (scGPT) is not trained.** Its weights stay fixed, and only a small classifier on top of it is trained with the user's data (no fine-tuning).
6. **Low performance is a result too.** When the data carry little signal, as in predicting cancer treatment response from blood, every method including scGPT stays near AUC 0.5; when the difference is large, as in normal versus disease, every method is near 1.0 and methods cannot be told apart. scgpt_compare reports these cases in numbers as they are.
7. **Data to predict must match the training data in tissue, time point and assay.** They must be embedded with the same scGPT checkpoint; a different checkpoint stops prediction, and a different tissue or time point gives a warning.
8. **Models trained on human data follow the terms of use of their training data.** Terms written in data_terms of scgpt_train are kept in the model card; share models built from controlled-access data (for example approved K-BDS data) only under the same terms.
9. **All analyses run without internet access.** The scGPT whole-human checkpoint is in the runtime image.
