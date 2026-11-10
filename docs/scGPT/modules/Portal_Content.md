# scGPT 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고입니다. 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/scGPT/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다(`--key value`, `--key=value`도 받으며, CLOSHA는 Python 모듈에 `--key value`로 넘깁니다). 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다.
- 선택(Optional) 옵션은 빈 값이면 스크립트의 기본값을 씁니다. 선택 입력(`init_model`, `models`, `checkpoint_dir`)은 빈 값이 "사용 안 함" 또는 "이미지 안 기본값"이므로 Value를 비워 둡니다.
- 코어 수 옵션은 없습니다. 스크립트가 실행 환경에서 할당된 코어 수를 읽습니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 모든 모듈이 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)입니다.
- scGPT 파이프라인은 CLOSHA 3.0에서 처음 배포하므로 모든 모듈의 버전은 1.0입니다.
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지웁니다.
- 카테고리: CLOSHA 프로그램 목록에 기계학습 단계가 없어 대분류 Machine_Learning(신규)을 만들고, 중분류는 작업별로 Embedding, Model_Training, Prediction, Model_Evaluation(모두 신규)으로 둡니다. scgpt_prep은 데이터를 다음 단계 입력으로 바꾸는 단계라 Preprocessing / Data_Preparation(신규)입니다. 다른 기계학습 파이프라인(예: 다른 foundation model)의 모듈도 담을 수 있는 일반 이름입니다.
- 결과 그림의 예시 데이터: K-BDS KAP241712 심장 단일핵 아틀라스 중 Chaffin 외(Nature 2022) 좌심실 샘플을 원 논문 메타데이터(Broad Single Cell Portal SCP1303)로 연결한 데이터입니다. 확장성 심근병증(DCM) 11명과 비후성 심근병증(HCM) 15명, 모두 26명이며 `positive_label=DCM`, `time=all`로 실행했습니다(2026-11-09, CLOSHA).

---

## 1. scgpt_prep

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | scgpt_prep | scgpt_prep |
| 서브 타이틀 | AI 학습용 단일세포 데이터셋 | AI-ready single-cell dataset |
| 버전 | 1.0 | |
| 카테고리 대분류 | Preprocessing | Preprocessing |
| 카테고리 중분류 | Data_Preparation (신규) | Data_Preparation (new) |
| 태그 | single-cell RNA-seq, AI-ready dataset, cell QC, cross-validation, sample sheet | |
| 레퍼런스 URL | https://github.com/bowang-lab/scGPT | |
| 컨테이너 이미지 | bx_scgpt.1.0 | |
| 실행 스크립트 파일 | scgpt_prep.1.0.py | |
| Processor Core (제안) | 1코어, 메모리 64GB | 1 core, 64 GB of memory |

### 실행 이미지
이미지: bx_scgpt 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| scGPT | 0.2.4 | https://github.com/bowang-lab/scGPT |
| scGPT whole-human checkpoint | - | https://github.com/bowang-lab/scGPT |
| PyTorch (CPU) | 2.6.0 | https://pytorch.org/ |
| torchtext | 0.18.0 | https://github.com/pytorch/text |
| Python | 3.11.18 | https://www.python.org/ |
| Scanpy | 1.10.4 | https://scanpy.readthedocs.io/ |
| anndata | 0.10.9 | https://anndata.readthedocs.io/ |
| scikit-learn | 1.9.1 | https://scikit-learn.org/ |
| NumPy | 2.2.6 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| SciPy | 1.14.1 | https://scipy.org/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| h5py | 3.16.0 | https://www.h5py.org/ |

- **태그(키워드):** single-cell foundation model, cell embedding, scGPT, PyTorch
- **내용(국문):** 사전학습 단일세포 모델 scGPT 0.2.4로 데이터셋을 만들고, 환자 단위 분류 모델을 학습·예측·비교하는 CPU 실행 환경입니다. 인체 세포 3,300만 개로 학습된 whole-human 체크포인트가 이미지 안에 들어 있어 실행 중 인터넷을 쓰지 않습니다. 세포 임베딩은 GPU 이미지(bx_scgpt_gpu)에서 만듭니다.
- **내용(영문):** CPU runtime for building datasets and for training, applying and comparing patient-level classifiers on top of the pretrained single-cell model scGPT 0.2.4. The whole-human checkpoint, trained on 33 million human cells, is inside the image, so no internet access is needed at run time. Cell embeddings are made in the GPU image (bx_scgpt_gpu).

### 내용(국문)
샘플별 단일세포 count 행렬과 샘플 시트로 AI 학습에 바로 쓸 수 있는 데이터셋을 만듭니다. 모델이 배울 라벨과 평가에 쓸 환자 분할을 이 단계에서 고정해, 이후 모든 학습과 비교가 같은 환자로 채점되게 합니다.
- 샘플마다 검출 유전자 수와 미토콘드리아 비율로 세포를 거르고, 유전자 이름을 scGPT 어휘(vocab)와 맞춰 일치 비율을 기록합니다.
- 샘플 시트의 라벨이 개체마다 하나인지, 양성 라벨이 무엇인지 확인합니다. 라벨을 만들지는 않으며, 라벨이 빈 개체는 예측 대상으로 남깁니다.
- 라벨 있는 개체로 개체 단위 교차검증 분할(기본 5-fold × 3회)을 만들고, 코호트가 둘 이상이면 코호트 하나 빼기 분할도 만듭니다.
- 마커 유전자로 대략의 세포 유형(혈액·종양 미세환경 세포)을 붙여 기준 비교와 attention 해석에 씁니다.

### 내용(영문)
Builds an AI-ready dataset from per-sample single-cell count matrices and a sample sheet. The labels to learn and the patient splits for evaluation are fixed here, so every later training and comparison is scored on the same patients.
- Cells are filtered per sample by detected genes and mitochondrial fraction, and gene names are matched to the scGPT vocabulary with the match rate recorded.
- The sample sheet is checked for one label per individual and for the positive label. No labels are created; individuals without a label are kept for prediction.
- Patient-level cross-validation splits (5 folds × 3 repeats by default) are made from the labeled individuals, and leave-one-cohort-out splits when there are two or more cohorts.
- Coarse cell types (blood and tumor microenvironment cells) are assigned from marker genes for the baseline comparison and for reading attention.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/matrices | 샘플마다 count 행렬 하나가 있는 폴더(하위 폴더 구조 자유). SampleID로 찾음: `<SampleID>.h5`(Cell Ranger), `<SampleID>.h5ad`(raw count), 또는 `<SampleID>/` 폴더 안의 10x 행렬(filtered_feature_bc_matrix.h5 또는 matrix.mtx.gz·features.tsv.gz·barcodes.tsv.gz). Cell Ranger count·multi 결과 폴더를 그대로 넣어도 됨 | Folder with one count matrix per sample in any layout, found by SampleID: `<SampleID>.h5` (Cell Ranger), `<SampleID>.h5ad` (raw counts), or a 10x matrix inside `<SampleID>/` (filtered_feature_bc_matrix.h5 or matrix.mtx.gz, features.tsv.gz, barcodes.tsv.gz). Cell Ranger count and multi output folders work as delivered |
| Input | Required | File | sample_data | /data/samples.csv | 샘플 시트(CSV). 열: SampleID, PatientID, Cohort, Tissue, Time, Label. 예측할 개체는 Label을 비움 | Sample sheet (CSV) with SampleID, PatientID, Cohort, Tissue, Time, Label; leave Label empty for individuals to predict |
| Output | Required | Directory | output_dir | /data/scgpt_prep | 결과 폴더(dataset.h5ad, patients.tsv, samples.tsv, splits.tsv, splits_cohort.tsv, gene_match.tsv, cohort_labels.tsv, data_dictionary.tsv, prep_info.json, plots/) | Output folder (dataset.h5ad, patients.tsv, samples.tsv, splits.tsv, splits_cohort.tsv, gene_match.tsv, cohort_labels.tsv, data_dictionary.tsv, prep_info.json, plots/) |
| Option | Optional | String | positive_label | | 양성(1)으로 볼 라벨 값(예: DCM, PR). 라벨이 있으면 필요(라벨이 이미 1/0이면 생략) | Label value counted as positive (1), e.g. DCM or PR; needed with labels unless they are already 1/0 |
| Option | Optional | String | time | Before | 남길 채취 시점(Time 열 값). all이면 모든 시점 | Time point kept (value of the Time column); all keeps every time point |
| Option | Optional | String | tissue | auto | 남길 조직(Tissue 열 값). auto는 시트에 조직이 하나일 때 그것을 쓰고, 여럿이면 멈춤 | Tissue kept (value of the Tissue column); auto uses the only tissue and stops when there are several |
| Option | Optional | Integer | min_genes | 200 | 세포당 최소 검출 유전자 수 | Minimum detected genes per cell |
| Option | Optional | Float | max_mito | 20 | 세포당 미토콘드리아 UMI 비율(%) 상한 | Maximum mitochondrial UMI percent per cell |
| Option | Optional | Integer | min_cells_per_sample | 50 | QC 뒤 세포가 이보다 적은 샘플은 제외 | Samples with fewer cells after QC are left out |
| Option | Optional | Integer | folds | 5 | 개체 단위 교차검증 fold 수 | Folds of the individual-level cross-validation |
| Option | Optional | Integer | repeats | 3 | 교차검증 반복 수(매번 다른 분할) | Repeats of the cross-validation (different shuffles) |
| Input | Optional | Directory | checkpoint_dir | | scGPT 체크포인트 폴더(vocab.json 사용). 비우면 이미지 안 whole-human 체크포인트 | scGPT checkpoint folder (vocab.json is used); empty uses the whole-human checkpoint in the image |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 샘플시트
- **제목(국문):** 샘플 시트 (sample_data)
- **제목(영문):** Sample sheet (sample_data)
- **본문(국문):** 한 행이 샘플 하나인 CSV 파일입니다. SampleID(필수): input_dir에서 행렬을 찾는 이름이며 영문, 숫자, `.`, `_`, `-`만 씁니다. PatientID(필수): 개체(환자·공여자) ID로, 한 개체의 여러 샘플은 같은 PatientID를 씁니다. 학습과 평가는 개체 단위로 합니다. Cohort(필수): 코호트나 연구 이름으로, 둘 이상이면 코호트 하나 빼기 평가를 합니다. Tissue(필수): 조직 이름으로, tissue 옵션으로 하나를 고릅니다. Time(필수): 채취 시점으로, time 옵션으로 고르며 시점이 하나뿐이면 아무 값이나 쓰고 time=all로 실행합니다. Label(필수 열): 분류할 표현형으로, 한 개체에 한 값이어야 하며 두 종류의 값만 씁니다. 예측만 할 개체는 비웁니다. 그 밖의 열은 메타데이터로만 보관하고 모델 입력에는 쓰지 않습니다.
- **본문(영문):** A CSV file with one row per sample. SampleID (required): the name used to find the matrix in input_dir; letters, digits, `.`, `_` and `-` only. PatientID (required): the individual (patient or donor) ID; samples of one individual share it, and training and evaluation are done per individual. Cohort (required): cohort or study name; with two or more, leave-one-cohort-out evaluation is added. Tissue (required): tissue name, chosen with the tissue option. Time (required): sampling time point, chosen with the time option; with a single time point use any value and run with time=all. Label (required column): the phenotype to classify, one value per individual and two values in total; leave it empty for individuals to predict only. Other columns are kept as metadata and never used as model input.
- **예시 제목:** samples.csv
- **예시 본문:**
```
SampleID,PatientID,Cohort,Tissue,Time,Label
P01_LV1,P01,COHORT_A,LeftVentricle,Baseline,DCM
P01_LV2,P01,COHORT_A,LeftVentricle,Baseline,DCM
P02_LV1,P02,COHORT_A,LeftVentricle,Baseline,HCM
P03_LV1,P03,COHORT_A,LeftVentricle,Baseline,HCM
P04_LV1,P04,COHORT_A,LeftVentricle,Baseline,DCM
P05_LV1,P05,COHORT_A,LeftVentricle,Baseline,
```

등록 메모: 예시 본문은 예제 데이터(K-BDS KAP241712)의 실제 샘플 이름 대신 형식을 보여 주는 이름으로 적었습니다. 원 공여자 ID를 포탈에 그대로 싣지 않기 위해서입니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| 행렬은 정규화하지 않은 정수 count여야 합니다. h5ad는 X 또는 layers["counts"]에 raw count가 있어야 하며, 로그 변환된 값이면 멈춥니다. | Matrices must hold raw integer counts. An h5ad needs raw counts in X or layers["counts"]; log-transformed values stop the run. |
| 기본값은 time=Before라 Time 열에 Before가 없으면 남는 샘플이 없습니다. 시점이 하나뿐인 데이터는 time=all로 실행해 주세요. | The default time=Before keeps no samples when the Time column has no Before; run data with one time point with time=all. |
| Label은 두 종류의 값만 쓸 수 있고 positive_label로 양성을 정합니다. 한 개체의 샘플끼리 Label이 다르면 멈춥니다. | Label takes two values, with the positive one set by positive_label; samples of one individual with different labels stop the run. |
| 평가 단위는 세포가 아니라 개체입니다. 세포가 많아도 라벨 있는 개체가 적으면 교차검증 결과의 신뢰구간이 넓어집니다. 양성·음성 각각 fold 수 이상의 개체가 필요합니다. | The unit of evaluation is the individual, not the cell; with few labeled individuals the cross-validation intervals are wide however many cells there are. Each class needs at least as many individuals as folds. |
| 대략의 세포 유형은 혈액·종양 미세환경 마커(T, NK, B, 형질세포, 단핵구, 수지상세포, 혈소판, 적혈구, 상피, 섬유모세포, 내피)로 붙입니다. 심근세포처럼 목록에 없는 세포는 Unassigned가 됩니다. 분류 모델 자체는 이 이름을 쓰지 않습니다. | Coarse cell types come from blood and tumor microenvironment markers (T, NK, B, plasma, monocytes, dendritic cells, platelets, erythrocytes, epithelial, fibroblast, endothelial); cells outside the list, such as cardiomyocytes, become Unassigned. The classifier itself does not use these names. |
| gene_match.tsv의 scGPT 어휘 일치 비율이 낮으면(예: Ensembl ID만 있는 행렬) 임베딩의 정보가 줄어듭니다. 유전자 기호(gene symbol)가 있는 행렬을 넣어 주세요. | A low scGPT vocabulary match in gene_match.tsv (for example matrices with Ensembl IDs only) leaves less information for the embeddings; use matrices with gene symbols. |

### 분석 개념 이미지
등록 메모: 모듈 개념도는 아직 만들지 않았습니다(샘플 시트 → 세포 QC·유전자 맞춤 → 개체 단위 fold). 파이프라인 개념도(`docs/scGPT/pipeline/figures/concept.png`)와 겹치지 않는 범위로 만듭니다.

### 스크립트 사용 예제
```
python3 scgpt_prep.1.0.py \
  input_dir=/data/matrices \
  sample_data=/data/samples.csv \
  output_dir=/data/scgpt_prep \
  positive_label= \
  time=Before \
  tissue=auto \
  min_genes=200 \
  max_mito=20 \
  min_cells_per_sample=50 \
  folds=5 \
  repeats=3 \
  checkpoint_dir= \
  seed=1234
```

### 주요 결과 이미지
등록 메모: 예제 데이터(KAP241712 DCM 대 HCM)의 prep 그림(`plots/cells_per_patient.png`, `plots/qc_by_sample.png`, `plots/cell_types_by_patient.png`)과 `samples.tsv`·`gene_match.tsv`를 CLOSHA에서 받아 그림을 직접 본 뒤 결과 1~3을 씁니다.

---

## 2. scgpt_embed

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | scgpt_embed | scgpt_embed |
| 서브 타이틀 | 사전학습 scGPT 세포 임베딩 | Pretrained scGPT cell embedding |
| 버전 | 1.0 | |
| 카테고리 대분류 | Machine_Learning (신규) | Machine_Learning (new) |
| 카테고리 중분류 | Embedding (신규) | Embedding (new) |
| 태그 | scGPT, foundation model, cell embedding, single-cell RNA-seq, GPU | |
| 레퍼런스 URL | https://github.com/bowang-lab/scGPT | |
| 컨테이너 이미지 | bx_scgpt_gpu.1.0 | |
| 실행 스크립트 파일 | scgpt_embed.1.0.py | |
| Processor Core (제안) | GPU 환경, 4코어, 메모리 64GB | GPU environment, 4 cores, 64 GB of memory |

### 실행 이미지
이미지: bx_scgpt_gpu 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt_gpu.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| scGPT | 0.2.4 | https://github.com/bowang-lab/scGPT |
| scGPT whole-human checkpoint | - | https://github.com/bowang-lab/scGPT |
| PyTorch (CUDA 12.6) | 2.6.0 | https://pytorch.org/ |
| CUDA | 12.6 | https://developer.nvidia.com/cuda-toolkit |
| torchtext | 0.18.0 | https://github.com/pytorch/text |
| Python | 3.11.18 | https://www.python.org/ |
| Scanpy | 1.10.4 | https://scanpy.readthedocs.io/ |
| anndata | 0.10.9 | https://anndata.readthedocs.io/ |
| scikit-learn | 1.9.1 | https://scikit-learn.org/ |
| NumPy | 2.2.6 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| SciPy | 1.14.1 | https://scipy.org/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| h5py | 3.16.0 | https://www.h5py.org/ |

- **태그(키워드):** single-cell foundation model, cell embedding, GPU, scGPT
- **내용(국문):** 사전학습 단일세포 모델 scGPT 0.2.4로 세포 임베딩을 GPU에서 만드는 실행 환경입니다(PyTorch 2.6, CUDA 12.6). 인체 세포 3,300만 개로 학습된 whole-human 체크포인트가 이미지 안에 들어 있어 실행 중 인터넷을 쓰지 않습니다. GPU가 없으면 CPU로 돌지만 세포당 약 2초로 매우 느립니다.
- **내용(영문):** Runtime for making cell embeddings on a GPU with the pretrained single-cell model scGPT 0.2.4 (PyTorch 2.6, CUDA 12.6). The whole-human checkpoint, trained on 33 million human cells, is inside the image, so no internet access is needed at run time. Without a GPU it falls back to the CPU at about 2 seconds per cell, which is very slow.

### 내용(국문)
사전학습된 scGPT를 고정한 채로 세포마다 512개의 숫자(임베딩)를 만듭니다. scGPT는 인체 세포 3,300만 개의 유전자 발현으로 미리 학습되어 있어, 비슷한 상태의 세포는 비슷한 임베딩을 갖습니다. 이 임베딩이 이후 분류 모델의 입력입니다.
- 세포마다 발현량이 높은 유전자(기본 최대 1,200개)를 scGPT에 넣고, scGPT 0.2.4의 `embed_data`와 같은 방식으로 임베딩을 계산합니다. scGPT의 가중치는 바꾸지 않습니다(파인튜닝하지 않음).
- 계산 시간을 줄이려고 개체마다 세포를 무작위로 골라 씁니다(기본 개체당 500개).
- 임베딩을 라벨, 코호트, 세포 유형으로 색칠한 UMAP을 그려, 세포가 무엇에 따라 모이는지 확인합니다.
- GPU 환경에서 실행합니다. 같은 데이터는 한 번만 임베딩하면 되고, 이후 학습·예측·비교는 CPU로 반복할 수 있습니다.

### 내용(영문)
Keeps the pretrained scGPT fixed and turns each cell into 512 numbers (an embedding). scGPT was trained beforehand on the gene expression of 33 million human cells, so cells in similar states get similar embeddings. These embeddings are the input of the classifier.
- The most expressed genes of each cell (up to 1,200 by default) go into scGPT, and embeddings are computed the same way as `embed_data` of scGPT 0.2.4. The scGPT weights are not changed (no fine-tuning).
- To save time, cells are sampled at random per individual (500 per individual by default).
- A UMAP of the embeddings colored by label, cohort and cell type shows what the cells group by.
- The module runs on a GPU. A data set needs embedding only once; training, prediction and comparison can then be repeated on CPUs.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/scgpt_prep | AI 학습용 데이터셋 폴더. 안에 dataset.h5ad(raw count, obs에 SampleID·PatientID·Cohort·Tissue·Time·Label·cell_type), patients.tsv, splits.tsv, prep_info.json이 있어야 함 | AI-ready dataset folder holding dataset.h5ad (raw counts; obs with SampleID, PatientID, Cohort, Tissue, Time, Label, cell_type), patients.tsv, splits.tsv and prep_info.json |
| Output | Required | Directory | output_dir | /data/scgpt_embed | 결과 폴더(embeddings.h5ad: 세포 × 512 임베딩, embed_info.json, patients.tsv, splits.tsv, splits_cohort.tsv, prep_info.json, plots/embedding_umap) | Output folder (embeddings.h5ad: cells × 512 embeddings, embed_info.json, patients.tsv, splits.tsv, splits_cohort.tsv, prep_info.json, plots/embedding_umap) |
| Input | Optional | Directory | checkpoint_dir | | scGPT 체크포인트 폴더(args.json, best_model.pt, vocab.json). 비우면 이미지 안 whole-human 체크포인트 | scGPT checkpoint folder (args.json, best_model.pt, vocab.json); empty uses the whole-human checkpoint in the image |
| Option | Optional | Integer | max_cells_per_patient | 500 | 개체당 무작위로 쓸 세포 수. 0이면 전부 | Cells sampled at random per individual; 0 uses all |
| Option | Optional | Integer | max_genes | 1200 | 세포당 모델에 넣을 유전자 수(발현량 순) | Genes per cell given to the model (by expression) |
| Option | Optional | String | batch_size | auto | 한 번에 처리할 세포 수. auto = GPU 64, CPU 16 | Cells per batch; auto = 64 on GPU, 16 on CPU |
| Option | Optional | List | device | auto | 계산 장치(auto, cuda, cpu). auto는 GPU가 보이면 GPU | Compute device (auto, cuda, cpu); auto uses the GPU when one is visible |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| GPU 환경에서 실행해 주세요. 로그의 `device (resolved)`에 `cuda`와 GPU 이름이 나와야 합니다. CPU로 돌면 세포당 약 2초가 걸립니다. | Run on a GPU environment; `device (resolved)` in the log should show `cuda` and the GPU name. On a CPU it takes about 2 seconds per cell. |
| 실행 시간은 임베딩할 세포 수에 비례합니다. 시간이 오래 걸리면 max_cells_per_patient를 줄여 주세요. | Run time grows with the number of cells embedded; lower max_cells_per_patient when it takes too long. |
| 학습할 데이터와 예측할 데이터는 같은 체크포인트로 임베딩해야 합니다. 체크포인트가 다르면 이후 예측에서 멈춥니다(SHA256로 확인). | Training and prediction data must be embedded with the same checkpoint; a different checkpoint stops prediction later (checked by SHA256). |
| embed_info.json에 데이터셋 폴더 경로가 기록되고, 기준 방법 비교(PCA)가 그 폴더의 dataset.h5ad를 다시 읽습니다. 비교를 마칠 때까지 데이터셋 폴더를 지우거나 옮기지 마세요. | embed_info.json records the dataset folder path, and the PCA baseline comparison reads dataset.h5ad there again; keep that folder in place until comparisons are done. |
| UMAP에서 세포가 라벨보다 코호트로 크게 나뉘면 배치 효과가 클 수 있습니다. 이때 분류 성능은 코호트 하나 빼기 평가로 함께 확인해 주세요. | When cells separate by cohort more than by label in the UMAP, batch effects may be strong; check the leave-one-cohort-out evaluation as well. |

### 분석 개념 이미지
그림: `docs/scGPT/pipeline/figures/concept.png`

등록 메모: 파이프라인 개념도의 (A) 패널이 이 모듈의 원리입니다. 모듈 전용 그림을 따로 만들지 않고 같은 그림을 씁니다. 필요하면 (A)만 잘라 씁니다.

- 레전드(국문): **그림. 사전학습 모델로 세포를 읽고, 세포를 모아 개체를 분류합니다.** (A) 세포마다 발현량이 높은 유전자(최대 1,200개)를 사전학습된 scGPT에 넣어 512개의 숫자(임베딩)로 바꿉니다. scGPT의 가중치는 바뀌지 않으며, 비슷한 세포는 비슷한 임베딩을 갖습니다. 이 모듈은 (A)를 수행합니다. (B) 한 개체의 세포 임베딩마다 attention 가중치를 매겨 가중 평균한 개체 임베딩(표준화)에서 양성 라벨의 확률을 계산합니다. 값은 모식적인 값입니다.
- 레전드(영문): **Figure. A pretrained model reads the cells, and pooled cells classify each individual.** (A) The most expressed genes of each cell (up to 1,200) go into pretrained scGPT, which turns the cell into 512 numbers (an embedding). The scGPT weights do not change, and similar cells get similar embeddings. This module performs (A). (B) Each cell embedding of an individual gets an attention weight, and the weighted average (standardized) gives the probability of the positive label. Values are schematic.
- 출처: (A) 직접 작성한 모식도(외부 그림 사용 안 함). (B) Do C, Lähdesmäki H. Incorporating hierarchical information into multiple instance learning for patient phenotype prediction with single-cell RNA-sequencing data. *Bioinformatics* 41(Suppl 1), i96-i104 (2025). https://doi.org/10.1093/bioinformatics/btaf241, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

### 스크립트 사용 예제
```
python3 scgpt_embed.1.0.py \
  input_dir=/data/scgpt_prep \
  output_dir=/data/scgpt_embed \
  checkpoint_dir= \
  max_cells_per_patient=500 \
  max_genes=1200 \
  batch_size=auto \
  device=auto \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 K-BDS KAP241712 심장 단일핵 데이터의 DCM 11명, HCM 15명(개체당 최대 500세포)입니다.

**결과 1. 세포 임베딩 UMAP**
- 결과 파일: `plots/embedding_umap.png`

그림: `docs/scGPT/modules/figures/results_kap241712/scgpt_embed_result_1.png`

- 레전드(국문): **scGPT 임베딩에서 세포가 모이는 모양.** 세 패널은 같은 UMAP을 라벨(Label), 코호트(Cohort), 세포 유형(cell_type)으로 색칠한 것입니다. 점 하나가 세포 하나이며, 가까운 점일수록 scGPT 임베딩이 비슷합니다. 세포 유형별로 무리가 생기는 것이 정상이며, 라벨에 따른 차이는 무리 안의 위치 차이로 나타나는 경우가 많습니다. 예시 데이터에서는 세포가 유형별로 무리를 이루고 각 무리 안에서 DCM과 HCM 세포가 섞여 있어, 두 질환의 차이가 세포 유형 구성보다 같은 유형 안의 상태 차이에 가깝다는 것을 보여 줍니다. 코호트는 하나라 한 색입니다. 세포 유형 이름은 혈액·종양 미세환경 마커로 붙인 것이라, 심근세포와 평활근·혈관주위세포 같은 심장 고유 세포의 큰 무리는 Unassigned(연두색)로 나왔습니다.
- 레전드(영문): **How cells group in the scGPT embedding.** The three panels color the same UMAP by label, cohort and cell type. Each dot is a cell, and nearby dots have similar scGPT embeddings. Groups by cell type are expected, and label differences often appear as shifts within those groups. In the example data cells form groups by cell type with DCM and HCM cells mixed inside each group, showing that the two diseases differ more in the state of cells within a type than in cell type composition. There is one cohort, so one color. Cell type names come from blood and tumor microenvironment markers, so large groups of heart cells such as cardiomyocytes and smooth muscle or pericytes appear as Unassigned (light green).

등록 메모: 가운데 패널의 코호트 범례 글자(KAP241712_SCP1303)가 오른쪽 패널에 가려 잘렸습니다. 스크립트 그림 배치 문제로, 다음 버전에서 고칩니다.

---

## 3. scgpt_train

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | scgpt_train | scgpt_train |
| 서브 타이틀 | 개체 단위 표현형 분류 학습 | Individual-level classifier training |
| 버전 | 1.0 | |
| 카테고리 대분류 | Machine_Learning (신규) | Machine_Learning (new) |
| 카테고리 중분류 | Model_Training (신규) | Model_Training (new) |
| 태그 | classification, multiple instance learning, attention pooling, cross-validation, model card | |
| 레퍼런스 URL | https://github.com/bowang-lab/scGPT | |
| 컨테이너 이미지 | bx_scgpt.1.0 | |
| 실행 스크립트 파일 | scgpt_train.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 16GB | 4 cores, 16 GB of memory |

### 실행 이미지
이미지: bx_scgpt 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| scGPT | 0.2.4 | https://github.com/bowang-lab/scGPT |
| scGPT whole-human checkpoint | - | https://github.com/bowang-lab/scGPT |
| PyTorch (CPU) | 2.6.0 | https://pytorch.org/ |
| torchtext | 0.18.0 | https://github.com/pytorch/text |
| Python | 3.11.18 | https://www.python.org/ |
| Scanpy | 1.10.4 | https://scanpy.readthedocs.io/ |
| anndata | 0.10.9 | https://anndata.readthedocs.io/ |
| scikit-learn | 1.9.1 | https://scikit-learn.org/ |
| NumPy | 2.2.6 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| SciPy | 1.14.1 | https://scipy.org/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| h5py | 3.16.0 | https://www.h5py.org/ |

- **태그(키워드):** single-cell foundation model, cell embedding, scGPT, PyTorch
- **내용(국문):** 사전학습 단일세포 모델 scGPT 0.2.4로 데이터셋을 만들고, 환자 단위 분류 모델을 학습·예측·비교하는 CPU 실행 환경입니다. 인체 세포 3,300만 개로 학습된 whole-human 체크포인트가 이미지 안에 들어 있어 실행 중 인터넷을 쓰지 않습니다. 세포 임베딩은 GPU 이미지(bx_scgpt_gpu)에서 만듭니다.
- **내용(영문):** CPU runtime for building datasets and for training, applying and comparing patient-level classifiers on top of the pretrained single-cell model scGPT 0.2.4. The whole-human checkpoint, trained on 33 million human cells, is inside the image, so no internet access is needed at run time. Cell embeddings are made in the GPU image (bx_scgpt_gpu).

### 내용(국문)
세포 임베딩을 개체 단위로 모아 표현형(예: 질환, 치료 반응)을 분류하는 모델을 학습합니다. 학습하는 것은 scGPT 뒤에 붙인 작은 분류기뿐이며, scGPT 자체는 바꾸지 않습니다.
- 기본 방식(attention)은 개체의 세포마다 가중치를 매겨 가중 평균한 개체 벡터로 양성 확률을 계산합니다. 어떤 세포가 판정에 크게 기여했는지도 알 수 있습니다. mean 방식은 세포 임베딩의 단순 평균을 씁니다.
- 학습 개체의 평균 임베딩으로 차원마다 평균과 표준편차를 맞춘 뒤 학습합니다(standardize=yes). 이 값은 모델에 저장되어 예측과 비교에서도 똑같이 씁니다.
- 데이터셋에 고정된 개체 단위 분할로 교차검증하여, 학습에 쓰지 않은 개체에서의 AUC와 95% 신뢰구간을 냅니다. 이어서 라벨 있는 모든 개체로 최종 모델을 학습합니다.
- 최종 모델과 함께 무엇으로 어떻게 학습했고 성능이 어땠는지 적은 모델 카드(model_card.json, .md)를 만듭니다.

### 내용(영문)
Trains a model that pools cell embeddings per individual to classify a phenotype (for example a disease or a treatment response). Only a small classifier on top of scGPT is trained; scGPT itself is not changed.
- The default (attention) gives each cell of an individual a weight and computes the positive probability from the weighted average; it also shows which cells weigh most in the decision. The mean option uses the plain average of the cell embeddings.
- Each embedding dimension is scaled by the mean and SD of the training individuals' mean embeddings before training (standardize=yes); the values are saved in the model and used the same way for prediction and comparison.
- Cross-validation on the individual-level splits fixed in the dataset gives the AUC with a 95% confidence interval on individuals not used for training. A final model is then trained on all labeled individuals.
- A model card (model_card.json, .md) records what the model was trained on, how, and how well it did.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/scgpt_embed | 세포 임베딩 폴더. 안에 embeddings.h5ad(세포 × 512, obs에 PatientID·Label), patients.tsv, splits.tsv, embed_info.json이 있어야 하며 라벨 있는 개체가 필요 | Cell embedding folder holding embeddings.h5ad (cells × 512; obs with PatientID and Label), patients.tsv, splits.tsv and embed_info.json, with labeled individuals |
| Input | Optional | Directory | init_model | | 이어서 학습할 기존 모델 폴더. 안에 model/model.pt가 있어야 하며 같은 체크포인트·설정이어야 함. 비우면 처음부터 학습 | Earlier model folder to continue from, holding model/model.pt with the same checkpoint and settings; empty starts from scratch |
| Output | Required | Directory | output_dir | /data/scgpt_train | 결과 폴더(model/model.pt, model/model_card.json·.md, cv_predictions.tsv, cv_cohort_predictions.tsv, cv_metrics.tsv, plots/roc_cv, plots/training_loss) | Output folder (model/model.pt, model/model_card.json and .md, cv_predictions.tsv, cv_cohort_predictions.tsv, cv_metrics.tsv, plots/roc_cv, plots/training_loss) |
| Option | Optional | List | pooling | attention | 세포를 개체로 묶는 방법(attention, mean) | How cells are pooled per individual (attention, mean) |
| Option | Optional | String | standardize | yes | yes면 학습 개체의 평균 임베딩으로 차원마다 평균·표준편차를 맞춤(모델에 저장). no면 임베딩을 그대로 씀 | yes scales each dimension by the mean and SD of the training individuals' mean embeddings (saved in the model); no uses the embeddings as they are |
| Option | Optional | Integer | hidden | 64 | attention 층 크기 | Size of the attention layer |
| Option | Optional | Integer | epochs | 200 | 전체 개체를 학습하는 반복 횟수 | Training passes over all individuals |
| Option | Optional | Float | learning_rate | 0.001 | 학습률(Adam) | Learning rate (Adam) |
| Option | Optional | Float | weight_decay | 0.01 | L2 규제(AdamW) | L2 penalty (AdamW) |
| Option | Optional | Float | dropout | 0.25 | 개체 벡터 dropout 비율 | Dropout on the pooled individual vector |
| Option | Optional | Float | cell_dropout | 0.2 | 학습 반복마다 개체의 세포를 무작위로 뺄 비율 | Fraction of each individual's cells left out at random in every pass |
| Option | Optional | String | model_name | | 모델 카드에 적을 이름. 비우면 scgpt_<날짜> | Name written in the model card; empty gives scgpt_<date> |
| Option | Optional | String | data_terms | | 학습 데이터의 이용 조건(모델 카드에 기록). 예: K-BDS 승인 사용자만 | Terms of use of the training data, written in the model card (e.g. K-BDS approved users only) |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 개체 수가 적으면 교차검증 AUC의 신뢰구간이 넓습니다. 예를 들어 26명이면 AUC 0.9라도 구간이 0.8~1.0 정도로 넓습니다. 성능은 cv_metrics.tsv의 신뢰구간과 함께 보고, 기준 방법과의 비교로 확인해 주세요. | With few individuals the cross-validation AUC has a wide interval; with 26 individuals even an AUC of 0.9 spans about 0.8 to 1.0. Read cv_metrics.tsv with its interval and check against baseline methods. |
| 교차검증에 쓰는 분할은 데이터셋을 만들 때 정해집니다. 같은 데이터셋이면 다시 학습해도 같은 개체로 채점되어 옵션별 결과를 비교할 수 있습니다. | The splits are fixed when the dataset is built; retraining on the same dataset scores the same individuals, so results of different options can be compared. |
| epochs를 늘린다고 성능이 오르지는 않습니다. 데이터에 신호가 약하면 학습 손실만 줄고 교차검증 AUC는 그대로입니다. training_loss 그림으로 학습이 수렴했는지 확인해 주세요. | More epochs do not raise performance by themselves; with a weak signal only the training loss falls while the cross-validation AUC stays. Check convergence in the training_loss plot. |
| init_model로 이어서 학습할 때는 같은 체크포인트, 같은 pooling·standardize 설정이어야 합니다. 다르면 멈춥니다. | Continuing from init_model needs the same checkpoint and the same pooling and standardize settings; otherwise the run stops. |
| 모델은 학습 데이터의 조직, 시점, 측정 방식에 맞춰져 있습니다. 다른 조직이나 시점의 개체에 쓰면 성능을 보장하지 않습니다. 사람 데이터로 학습한 모델은 data_terms에 이용 조건을 적어 주세요. | The model fits the tissue, time point and assay of its training data; performance on other tissues or time points is not assured. For models trained on human data, write the terms of use in data_terms. |

### 분석 개념 이미지
그림: `docs/scGPT/pipeline/figures/concept.png`

등록 메모: 파이프라인 개념도의 (B) 패널이 이 모듈의 원리입니다. 모듈 전용 그림을 따로 만들지 않고 같은 그림을 씁니다. 필요하면 (B)만 잘라 씁니다.

- 레전드(국문): **그림. 사전학습 모델로 세포를 읽고, 세포를 모아 개체를 분류합니다.** (A) 세포마다 발현량이 높은 유전자(최대 1,200개)를 사전학습된 scGPT에 넣어 512개의 숫자(임베딩)로 바꿉니다. scGPT의 가중치는 바뀌지 않습니다. (B) 한 개체의 세포 임베딩마다 attention 가중치를 매겨 가중 평균한 개체 임베딩(표준화)에서 양성 라벨의 확률을 계산합니다. 이 모듈은 (B)의 attention과 분류기를 학습합니다. 값은 모식적인 값입니다.
- 레전드(영문): **Figure. A pretrained model reads the cells, and pooled cells classify each individual.** (A) The most expressed genes of each cell (up to 1,200) go into pretrained scGPT, which turns the cell into 512 numbers (an embedding); the scGPT weights do not change. (B) Each cell embedding of an individual gets an attention weight, and the weighted average (standardized) gives the probability of the positive label. This module trains the attention and the classifier in (B). Values are schematic.
- 출처: (A) 직접 작성한 모식도(외부 그림 사용 안 함). (B) Do C, Lähdesmäki H. Incorporating hierarchical information into multiple instance learning for patient phenotype prediction with single-cell RNA-sequencing data. *Bioinformatics* 41(Suppl 1), i96-i104 (2025). https://doi.org/10.1093/bioinformatics/btaf241, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

### 스크립트 사용 예제
```
python3 scgpt_train.1.0.py \
  input_dir=/data/scgpt_embed \
  init_model= \
  output_dir=/data/scgpt_train \
  pooling=attention \
  standardize=yes \
  hidden=64 \
  epochs=200 \
  learning_rate=0.001 \
  weight_decay=0.01 \
  dropout=0.25 \
  cell_dropout=0.2 \
  model_name= \
  data_terms= \
  seed=1234
```

### 주요 결과 이미지
등록 메모: 예제 데이터(KAP241712 DCM 대 HCM, 2026-11-09 실행)의 `plots/roc_cv.png`, `plots/training_loss.png`, `cv_metrics.tsv`를 CLOSHA에서 받아 그림을 직접 본 뒤 결과 1~3을 씁니다. 같은 실행의 기준 비교(scgpt_compare)에서 이 모델의 교차검증 AUC는 0.927(95% CI 0.812~1.000)이었습니다.

---

## 4. scgpt_predict

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | scgpt_predict | scgpt_predict |
| 서브 타이틀 | 학습 모델로 표현형 예측 | Phenotype prediction |
| 버전 | 1.0 | |
| 카테고리 대분류 | Machine_Learning (신규) | Machine_Learning (new) |
| 카테고리 중분류 | Prediction (신규) | Prediction (new) |
| 태그 | prediction, classification, attention, single-cell RNA-seq, model card | |
| 레퍼런스 URL | https://github.com/bowang-lab/scGPT | |
| 컨테이너 이미지 | bx_scgpt.1.0 | |
| 실행 스크립트 파일 | scgpt_predict.1.0.py | |
| Processor Core (제안) | 1코어, 메모리 16GB | 1 core, 16 GB of memory |

### 실행 이미지
이미지: bx_scgpt 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| scGPT | 0.2.4 | https://github.com/bowang-lab/scGPT |
| scGPT whole-human checkpoint | - | https://github.com/bowang-lab/scGPT |
| PyTorch (CPU) | 2.6.0 | https://pytorch.org/ |
| torchtext | 0.18.0 | https://github.com/pytorch/text |
| Python | 3.11.18 | https://www.python.org/ |
| Scanpy | 1.10.4 | https://scanpy.readthedocs.io/ |
| anndata | 0.10.9 | https://anndata.readthedocs.io/ |
| scikit-learn | 1.9.1 | https://scikit-learn.org/ |
| NumPy | 2.2.6 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| SciPy | 1.14.1 | https://scipy.org/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| h5py | 3.16.0 | https://www.h5py.org/ |

- **태그(키워드):** single-cell foundation model, cell embedding, scGPT, PyTorch
- **내용(국문):** 사전학습 단일세포 모델 scGPT 0.2.4로 데이터셋을 만들고, 환자 단위 분류 모델을 학습·예측·비교하는 CPU 실행 환경입니다. 인체 세포 3,300만 개로 학습된 whole-human 체크포인트가 이미지 안에 들어 있어 실행 중 인터넷을 쓰지 않습니다. 세포 임베딩은 GPU 이미지(bx_scgpt_gpu)에서 만듭니다.
- **내용(영문):** CPU runtime for building datasets and for training, applying and comparing patient-level classifiers on top of the pretrained single-cell model scGPT 0.2.4. The whole-human checkpoint, trained on 33 million human cells, is inside the image, so no internet access is needed at run time. Cell embeddings are made in the GPU image (bx_scgpt_gpu).

### 내용(국문)
학습된 분류 모델로 개체마다 양성 표현형일 확률을 계산합니다. 라벨이 없는 새 개체를 예측할 때 쓰며, 라벨이 있으면 예측과 함께 비교해 보여 줍니다.
- 개체마다 양성 확률과 판정(threshold 기준)을 냅니다.
- attention 모델이면 세포마다 가중치를 내고, 세포 유형별로 attention 비율과 세포 비율을 비교해 모델이 어떤 세포에 무게를 두었는지 보여 줍니다.
- 임베딩이 모델과 같은 scGPT 체크포인트에서 나왔는지 SHA256으로 확인하고, 조직이나 시점이 학습 데이터와 다르면 경고합니다.
- 사용한 모델의 모델 카드를 결과에 함께 복사해, 어떤 모델로 예측했는지 남깁니다.

### 내용(영문)
Computes, for each individual, the probability of the positive phenotype with a trained classifier. It is used for new individuals without labels; when labels are present, they are shown next to the predictions.
- Each individual gets a positive probability and a call at the threshold.
- With an attention model, each cell gets a weight, and the share of attention per cell type is compared with the share of cells to show which cells the model weighs most.
- The embeddings are checked by SHA256 to come from the same scGPT checkpoint as the model, and a tissue or time point different from the training data gives a warning.
- The model card of the model used is copied into the results to record which model made the predictions.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/scgpt_embed_new | 예측할 개체의 세포 임베딩 폴더. 안에 embeddings.h5ad(세포 × 512, obs에 PatientID), patients.tsv, embed_info.json이 있어야 함. 라벨은 없어도 됨 | Cell embedding folder of the individuals to predict, holding embeddings.h5ad (cells × 512; obs with PatientID), patients.tsv and embed_info.json; labels are optional |
| Input | Required | Directory | model | /data/scgpt_train | 학습된 모델 폴더. 안에 model/model.pt와 model/model_card.json이 있어야 함 | Trained model folder holding model/model.pt and model/model_card.json |
| Output | Required | Directory | output_dir | /data/scgpt_predict | 결과 폴더(predictions.tsv, cell_attention.tsv.gz, attention_by_cell_type.tsv, model_card.json, plots/predictions, plots/attention_by_cell_type) | Output folder (predictions.tsv, cell_attention.tsv.gz, attention_by_cell_type.tsv, model_card.json, plots/predictions, plots/attention_by_cell_type) |
| Option | Optional | Float | threshold | 0.5 | 이 확률 이상이면 양성으로 판정 | Probability at or above which an individual is called positive |

등록 메모: 스크립트는 model을 비우면 이미지 안 기본 모델을 찾지만 1.0 이미지에는 기본 모델이 없어 오류로 멈춥니다. 그래서 포탈에는 model을 필수로 등록합니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| 예측할 데이터는 학습 데이터와 같은 방식으로 데이터셋을 만들고 같은 scGPT 체크포인트로 임베딩해야 합니다. 체크포인트가 다르면 멈춥니다. | Data to predict must be built into a dataset the same way and embedded with the same scGPT checkpoint as the training data; a different checkpoint stops the run. |
| 조직, 채취 시점이 학습 데이터와 다르면 경고만 하고 예측은 진행합니다. 이 경우 확률을 그대로 믿기 어려우니 결과를 조심해서 해석해 주세요. | A tissue or time point different from the training data only gives a warning and prediction goes on; interpret such probabilities with caution. |
| threshold 0.5는 기본값일 뿐입니다. 양성·음성의 비율이나 목적(놓치지 않기, 잘못 부르지 않기)에 따라 predictions.tsv의 확률로 기준을 다시 정할 수 있습니다. | The threshold of 0.5 is only a default; the probabilities in predictions.tsv allow another cut-off depending on class balance or purpose (missing fewer, or calling fewer false positives). |
| attention 비율은 모델이 무게를 둔 세포 유형을 보여 줄 뿐, 그 세포가 표현형의 원인이라는 뜻은 아닙니다. 세포 유형 이름은 혈액·종양 미세환경 마커로 붙인 대략의 이름입니다. | The attention share shows the cell types the model weighs most, not that those cells cause the phenotype. Cell type names are coarse labels from blood and tumor microenvironment markers. |

### 분석 개념 이미지
등록 메모: 모듈 개념도는 아직 만들지 않았습니다(새 개체 임베딩 + 학습 모델 → 개체별 확률과 세포 attention).

### 스크립트 사용 예제
```
python3 scgpt_predict.1.0.py \
  input_dir=/data/scgpt_embed_new \
  model=/data/scgpt_train \
  output_dir=/data/scgpt_predict \
  threshold=0.5
```

### 주요 결과 이미지
등록 메모: 예제 데이터로 predict를 실행한 `plots/predictions.png`, `plots/attention_by_cell_type.png`를 CLOSHA에서 받아 그림을 직접 본 뒤 결과 1~2를 씁니다. 예제 데이터에서는 학습에 쓴 개체를 다시 예측하게 되므로, 레전드에 "학습한 개체라 확률이 실제 성능보다 좋게 나옴"을 적습니다.

---

## 5. scgpt_compare

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | scgpt_compare | scgpt_compare |
| 서브 타이틀 | 기준 방법과 성능 비교 | Comparison with baselines |
| 버전 | 1.0 | |
| 카테고리 대분류 | Machine_Learning (신규) | Machine_Learning (new) |
| 카테고리 중분류 | Model_Evaluation (신규) | Model_Evaluation (new) |
| 태그 | model evaluation, AUC, ROC, baseline comparison, bootstrap, permutation test | |
| 레퍼런스 URL | https://github.com/bowang-lab/scGPT | |
| 컨테이너 이미지 | bx_scgpt.1.0 | |
| 실행 스크립트 파일 | scgpt_compare.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 32GB | 4 cores, 32 GB of memory |

### 실행 이미지
이미지: bx_scgpt 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| scGPT | 0.2.4 | https://github.com/bowang-lab/scGPT |
| scGPT whole-human checkpoint | - | https://github.com/bowang-lab/scGPT |
| PyTorch (CPU) | 2.6.0 | https://pytorch.org/ |
| torchtext | 0.18.0 | https://github.com/pytorch/text |
| Python | 3.11.18 | https://www.python.org/ |
| Scanpy | 1.10.4 | https://scanpy.readthedocs.io/ |
| anndata | 0.10.9 | https://anndata.readthedocs.io/ |
| scikit-learn | 1.9.1 | https://scikit-learn.org/ |
| NumPy | 2.2.6 | https://numpy.org/ |
| pandas | 2.3.3 | https://pandas.pydata.org/ |
| SciPy | 1.14.1 | https://scipy.org/ |
| Matplotlib | 3.10.9 | https://matplotlib.org/ |
| h5py | 3.16.0 | https://www.h5py.org/ |

- **태그(키워드):** single-cell foundation model, cell embedding, scGPT, PyTorch
- **내용(국문):** 사전학습 단일세포 모델 scGPT 0.2.4로 데이터셋을 만들고, 환자 단위 분류 모델을 학습·예측·비교하는 CPU 실행 환경입니다. 인체 세포 3,300만 개로 학습된 whole-human 체크포인트가 이미지 안에 들어 있어 실행 중 인터넷을 쓰지 않습니다. 세포 임베딩은 GPU 이미지(bx_scgpt_gpu)에서 만듭니다.
- **내용(영문):** CPU runtime for building datasets and for training, applying and comparing patient-level classifiers on top of the pretrained single-cell model scGPT 0.2.4. The whole-human checkpoint, trained on 33 million human cells, is inside the image, so no internet access is needed at run time. Cell embeddings are made in the GPU image (bx_scgpt_gpu).

### 내용(국문)
사전학습 모델을 쓴 분류가 단순한 방법보다 실제로 나은지를 같은 개체, 같은 분할에서 비교합니다. 나아지지 않았다면 그 결과도 그대로 보여 줍니다.
- 기준 방법 세 가지를 같은 교차검증 분할로 학습·평가합니다: 세포 유형 비율, 고변동 유전자(기본 2,000개)의 PCA(기본 30개 주성분) 개체 평균, scGPT 임베딩의 개체 평균(분류기 학습 없이 scGPT를 그대로 쓴 것).
- 학습된 모델이 있으면 그 모델의 교차검증 예측을 같은 분할에서 함께 채점합니다.
- 방법마다 AUC와 95% 신뢰구간, 라벨 순열 검정 p값을 내고, 짝지은 부트스트랩으로 모델과 각 기준 방법의 AUC 차이와 신뢰구간을 계산해 "더 좋음, 차이 불분명, 더 나쁨"으로 요약합니다.
- 코호트가 둘 이상이면 코호트 하나 빼기 평가도 함께 합니다.

### 내용(영문)
Compares, on the same individuals and splits, whether classification with the pretrained model is actually better than simpler methods; when it is not, that result is shown as well.
- Three baselines are trained and scored on the same cross-validation splits: cell type fractions, the individual mean of a PCA (30 components by default) of highly variable genes (2,000 by default), and the individual mean of the scGPT embeddings (scGPT as it is, without a trained classifier).
- With a trained model, its cross-validation predictions are scored on the same splits.
- Each method gets an AUC with a 95% confidence interval and a label permutation p value, and a paired bootstrap gives the AUC difference between the model and each baseline with its interval, summarized as better, not clearly different or worse.
- With two or more cohorts, leave-one-cohort-out evaluation is added.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/scgpt_embed | 라벨 있는 개체의 세포 임베딩 폴더. 안에 embeddings.h5ad, patients.tsv, splits.tsv, embed_info.json이 있어야 함. PCA 기준 방법은 embed_info.json에 적힌 데이터셋 폴더의 dataset.h5ad도 읽음 | Cell embedding folder of labeled individuals holding embeddings.h5ad, patients.tsv, splits.tsv and embed_info.json; the PCA baseline also reads dataset.h5ad in the dataset folder recorded in embed_info.json |
| Input | Optional | Directory | models | | 학습된 모델 폴더. 안에 model/model.pt와 cv_predictions.tsv가 있어야 함. 비우면 기준 방법만 비교 | Trained model folder holding model/model.pt and cv_predictions.tsv; empty compares the baselines only |
| Output | Required | Directory | output_dir | /data/scgpt_compare | 결과 폴더(compare_metrics.tsv, compare_delta.tsv, compare_cohort.tsv, compare_predictions.tsv, summary.md, plots/roc, plots/auc) | Output folder (compare_metrics.tsv, compare_delta.tsv, compare_cohort.tsv, compare_predictions.tsv, summary.md, plots/roc, plots/auc) |
| Option | Optional | Integer | n_hvg | 2000 | PCA 기준 방법의 고변동 유전자 수 | Highly variable genes for the PCA baseline |
| Option | Optional | Integer | n_pcs | 30 | PCA 기준 방법의 주성분 수 | Principal components for the PCA baseline |
| Option | Optional | Integer | permutations | 1000 | AUC 순열 검정 횟수 | Label permutations for the AUC p value |
| Option | Optional | Integer | seed | 1234 | 난수 시드 | Random seed |

등록 메모: 스크립트는 models에 쉼표로 여러 폴더를 받지만(명령줄 실행용) 포탈에는 폴더 하나로 등록합니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| 모든 방법은 학습에 쓰지 않은 개체로 채점합니다. 학습 데이터 안에서의 성능은 보고하지 않습니다. | Every method is scored on individuals not used for its training; performance on the training data is not reported. |
| 개체 수가 적으면 AUC 차이의 신뢰구간이 0을 포함해 "차이 불분명(not clearly different)"이 되기 쉽습니다. 이는 오류가 아니라 표본 크기의 결과이며, 독립 코호트로 확인이 필요하다는 뜻입니다. | With few individuals the interval of the AUC difference easily includes 0, giving "not clearly different". This reflects the sample size, not an error, and calls for confirmation in an independent cohort. |
| 모든 방법이 AUC 1.0 근처면 문제가 쉬워 방법 간 차이를 볼 수 없습니다. 반대로 모든 방법이 0.5 근처면 데이터에 분류할 신호가 약한 것입니다. | When every method is near AUC 1.0 the task is too easy to tell methods apart; when every method is near 0.5 the data carry little signal for the classification. |
| 세포 유형 비율 기준 방법은 혈액·종양 미세환경 마커로 붙인 대략의 세포 유형을 씁니다. 다른 조직에서는 많은 세포가 Unassigned가 되어 이 기준 방법이 불리할 수 있습니다. | The cell type fraction baseline uses coarse cell types from blood and tumor microenvironment markers; in other tissues many cells become Unassigned and this baseline can be at a disadvantage. |
| 학습 모델은 같은 데이터셋(같은 분할)으로 학습한 것이어야 자기 교차검증 예측으로 채점합니다. 다른 데이터셋의 모델이면 모델을 그대로 적용해 채점합니다. | A model trained on the same dataset (same splits) is scored with its own cross-validation predictions; a model from another dataset is applied as it is. |
| PCA 기준 방법은 데이터셋 폴더의 dataset.h5ad를 다시 읽으므로, 그 폴더가 embed_info.json에 적힌 경로에 있어야 합니다. | The PCA baseline reads dataset.h5ad again, so the dataset folder must be at the path recorded in embed_info.json. |

### 분석 개념 이미지
등록 메모: 모듈 개념도는 아직 만들지 않았습니다(같은 개체·같은 분할에서 네 방법 → AUC와 짝지은 차이). 파이프라인 개념도 (B)의 비교 상자와 겹치지 않게 만듭니다.

### 스크립트 사용 예제
```
python3 scgpt_compare.1.0.py \
  input_dir=/data/scgpt_embed \
  models= \
  output_dir=/data/scgpt_compare \
  n_hvg=2000 \
  n_pcs=30 \
  permutations=1000 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 K-BDS KAP241712 심장 단일핵 데이터의 DCM 11명, HCM 15명입니다(positive_label=DCM). 학습 모델(attention, 기본 옵션)을 models에 넣어 실행했습니다.

**결과 1. 학습에 쓰지 않은 개체에서의 ROC 곡선**
- 결과 파일: `plots/roc.png`

그림: `docs/scGPT/modules/figures/results_kap241712/scgpt_compare_result_1.png`

- 레전드(국문): **방법별 ROC 곡선.** 가로축은 False positive rate(음성 개체를 양성으로 잘못 부른 비율), 세로축은 True positive rate(양성 개체를 맞게 찾은 비율)입니다. 곡선이 왼쪽 위에 가까울수록 잘 분류한 것이며, 회색 점선 대각선은 무작위 수준(AUC 0.5)입니다. 범례의 괄호 안 숫자가 AUC이고, baseline_celltype은 세포 유형 비율, baseline_pca는 고변동 유전자 PCA, scgpt_mean은 scGPT 임베딩 평균, scgpt_<날짜>(굵은 주황 선)는 학습 모델입니다. 예시 데이터에서는 scGPT 임베딩 평균 0.939, 학습 모델 0.927로 PCA 0.824와 세포 유형 비율 0.697보다 높았습니다. HCM을 약 7%만 DCM으로 잘못 부르는 지점에서 학습 모델은 DCM의 82%를, PCA는 64%를 찾았습니다.
- 레전드(영문): **ROC curves of each method.** The horizontal axis is the false positive rate (negatives called positive) and the vertical axis the true positive rate (positives found). Curves closer to the top left classify better, and the gray dashed diagonal is chance (AUC 0.5). The numbers in the legend are AUCs; baseline_celltype is cell type fractions, baseline_pca the PCA of highly variable genes, scgpt_mean the mean scGPT embedding, and scgpt_<date> (thick orange line) the trained model. In the example data the mean scGPT embedding reached 0.939 and the trained model 0.927, above PCA (0.824) and cell type fractions (0.697). At the point where about 7% of HCM individuals were called DCM, the trained model found 82% of DCM individuals and PCA 64%.

**결과 2. 방법별 AUC와 95% 신뢰구간**
- 결과 파일: `plots/auc.png`

그림: `docs/scGPT/modules/figures/results_kap241712/scgpt_compare_result_2.png`

- 레전드(국문): **학습에 쓰지 않은 개체에서의 AUC.** 막대는 방법별 AUC, 검은 선은 95% 신뢰구간, 회색 점선은 무작위 수준(0.5)입니다. 신뢰구간이 0.5 위에 있으면 무작위보다 낫다는 뜻입니다. 두 방법의 차이는 막대가 아니라 compare_delta.tsv와 summary.md의 짝지은 차이로 판단합니다. 예시 데이터에서는 학습 모델(0.927, 95% CI 0.812~1.000)이 세포 유형 비율보다 유의하게 높았고(차이 +0.230, 95% CI +0.036~+0.461), PCA보다 높았지만 26명이라 차이의 신뢰구간이 0을 포함했습니다(차이 +0.103, 95% CI -0.058~+0.280). 독립 코호트로 확인이 필요합니다.
- 레전드(영문): **AUC on individuals not used for training.** Bars are the AUC of each method, black lines the 95% confidence intervals, and the gray dashed line chance (0.5). An interval above 0.5 means better than chance. Differences between two methods are judged from the paired differences in compare_delta.tsv and summary.md, not from the bars. In the example data the trained model (0.927, 95% CI 0.812-1.000) was clearly above cell type fractions (difference +0.230, 95% CI +0.036 to +0.461) and above PCA, but with 26 individuals the interval of that difference included 0 (difference +0.103, 95% CI -0.058 to +0.280); an independent cohort is needed to confirm it.

등록 메모: 요약표(결과 3, `compare_metrics.tsv`·`compare_delta.tsv`를 `docs/tools/tsv_to_png.py`로 표 그림)는 CLOSHA에서 파일을 받아 만듭니다.
