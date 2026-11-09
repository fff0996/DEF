# scGPT 파이프라인 포탈 등록 콘텐츠

파이프라인: `scGPT_Single_Cell_Phenotype_Classification_Pipeline`
모듈: scgpt_prep → scgpt_embed (GPU) → scgpt_train → scgpt_predict, scgpt_compare
작성: 2026-11-09. 소개, 등록 항목, 주요 사항은 아직 작성 전.

## 분석 목표 / Analysis goals

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

## 분석 흐름 / Analysis workflow

그림: `docs/scGPT/pipeline/figures/pipeline.png` (원본 `pipeline.svg`, `make_pipeline_map.py`)

### 대체 텍스트 (alt)
- 국문: scGPT 파이프라인 흐름도. 단일세포 행렬과 샘플 시트를 scgpt_prep이 정리하고, scgpt_embed가 GPU에서 세포 임베딩을 만들며, scgpt_train이 분류 모델을 학습하고, scgpt_predict와 scgpt_compare가 임베딩과 모델로 예측과 비교를 함.
- English: scGPT pipeline workflow. scgpt_prep prepares the single-cell matrices and sample sheet, scgpt_embed makes cell embeddings on a GPU, scgpt_train trains the classifier, and scgpt_predict and scgpt_compare use the embeddings and the model for prediction and comparison.

## 분석 개념 / Analysis concept

그림: `docs/scGPT/pipeline/figures/concept.png` (원본 `concept.svg`, `make_concept.py`)

### 국문 (그림 설명)
**그림. 사전학습 모델로 세포를 읽고, 세포를 모아 개체를 분류합니다.** (A) 세포마다 발현량이 높은 유전자(최대 1,200개)를 사전학습된 scGPT에 넣어 512개의 숫자(임베딩)로 바꿉니다. scGPT의 가중치는 바뀌지 않으며, 비슷한 세포는 비슷한 임베딩을 갖습니다. (B) 한 개체의 세포 임베딩마다 attention 가중치를 매겨 가중 평균한 개체 임베딩(표준화)에서 양성 라벨의 확률을 계산합니다. 학습은 이 부분만 합니다. scgpt_compare는 같은 개체와 분할에서 세포 유형 비율, 변이 유전자 PCA, scGPT 임베딩 평균과 학습 모델의 AUC를 비교합니다. 값은 모식적인 값입니다.

### English (figure legend)
**Figure. A pretrained model reads the cells, and pooled cells classify each individual.** (A) The most expressed genes of each cell (up to 1,200) go into pretrained scGPT, which turns the cell into 512 numbers (an embedding). The scGPT weights do not change, and similar cells get similar embeddings. (B) Each cell embedding of an individual gets an attention weight, and the weighted average (standardized) gives the probability of the positive label. Only this part is trained. scgpt_compare compares the AUC of cell-type fractions, PCA of variable genes, the mean scGPT embedding and the trained model on the same individuals and folds. Values are schematic.

### 대체 텍스트 (alt)
- 국문: scGPT 개념도. 위: 세포의 유전자 발현이 고정된 scGPT를 거쳐 임베딩이 되고 비슷한 세포끼리 모임. 아래: 개체마다 세포 임베딩에 attention을 주어 개체 임베딩과 예측 확률을 만들고, 같은 분할에서 다른 방법과 AUC를 비교함.
- English: scGPT concept. Top: a cell's gene expression passes through frozen scGPT into an embedding, and similar cells group together. Bottom: attention over each individual's cell embeddings gives an individual embedding and a predicted probability, compared with other methods by AUC on the same folds.

### 출처 / Reference
- (A) 직접 작성한 모식도. scGPT 원 논문(Cui et al., Nat Methods 2024)은 공개 라이선스가 없어 그림을 쓰지 않음.
- (B) Do M, Lähdesmäki H. Incorporating hierarchical information into multiple instance learning for patient phenotype prediction with single-cell RNA-sequencing data. *Bioinformatics* 2025;41(Suppl 1). doi:10.1093/bioinformatics/btaf241. Figure 1을 다시 그리고 단순화함(세포 유형 단계 제거, 라벨과 비교 상자 추가). CC BY 4.0.
