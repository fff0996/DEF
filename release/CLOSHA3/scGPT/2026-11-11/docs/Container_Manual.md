# scGPT 파이프라인 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 scGPT 실행 이미지 설명입니다. 각 이미지는 `defs/scGPT/<이미지>.def`로 만듭니다. DEF 작성 규칙은 `docs/CLOSHA_DEF_Generator_Agent_v1.md`, 스크립트 규칙은 `docs/CLOSHA_Script_Rules_v1.md`를 따릅니다.

등록 메모: 버전과 도구 목록은 2026-11-10 기준 DEF 파일에서 옮겼습니다. DEF를 고치면 이 문서도 함께 고칩니다.

---

## 1. 공통 사항

### 국문
scGPT 파이프라인의 각 모듈은 분석 도구와 사전학습 모델을 미리 넣은 Apptainer 이미지(SIF) 안에서 실행됩니다. 세포 임베딩은 GPU가 필요하고 나머지는 CPU로 충분하므로, GPU용 PyTorch(CUDA 12.6)를 넣은 이미지와 CPU용 PyTorch를 넣은 가벼운 이미지로 나눴습니다. 두 이미지의 다른 도구와 버전은 같습니다.
- **기반 운영체제:** Rocky Linux 9.8 공식 이미지(`rockylinux/rockylinux:9.8.20260525.0`)를 고유 식별값(digest)으로 고정하여, 언제 만들어도 같은 기반을 씁니다.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **도구 설치:** Miniforge로 conda-forge 채널에서만 설치합니다. Anaconda 저장소(defaults 채널, repo.anaconda.com)는 사용하지 않습니다. conda-forge에 없는 scGPT 0.2.4는 PyPI의 순수 Python 배포 파일을 SHA256으로 확인한 뒤 의존성 없이 설치합니다.
- **사전학습 모델:** scGPT 저자가 공개한 whole-human 체크포인트(인체 세포 3,300만 개로 학습; args.json, best_model.pt, vocab.json)를 이미지를 만들 때 SHA256으로 확인해 `/opt/bio/share/scgpt/checkpoints/whole_human`에 넣습니다.
- **버전 고정:** 모든 도구는 버전을 지정해 설치하고, 설치된 전체 패키지 목록을 이미지 안에 기록합니다(`/opt/bio/share/bx-scgpt/conda-explicit.txt`, `pip-freeze.txt`).
- **도구 위치:** 모든 도구는 이미지 안의 `/opt/bio/bin`에 있으며 실행 경로(PATH)에 들어 있습니다.
- **분석 스크립트:** 이미지에 넣지 않고, 실행할 때 연결합니다. 그래서 스크립트를 고쳐도 이미지를 다시 만들 필요가 없습니다.
- **인터넷:** 실행 중에는 인터넷에 접속하지 않습니다.

### English
Each module of the scGPT pipeline runs inside an Apptainer image (SIF) with its tools and the pretrained model preinstalled. Cell embedding needs a GPU while the rest runs well on CPUs, so there are two images: one with GPU PyTorch (CUDA 12.6) and a lighter one with CPU PyTorch. All other tools and versions are the same in both.
- **Base OS:** the official Rocky Linux 9.8 image (`rockylinux/rockylinux:9.8.20260525.0`), pinned by its digest so every build starts from the same base.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **Tool installation:** Miniforge, from the conda-forge channel only. Anaconda repositories (the defaults channel, repo.anaconda.com) are not used. scGPT 0.2.4, which is not on conda-forge, is installed without dependencies from its pure-Python PyPI file after a SHA256 check.
- **Pretrained model:** the whole-human checkpoint published by the scGPT authors (trained on 33 million human cells; args.json, best_model.pt, vocab.json) is checked by SHA256 at build time and placed in `/opt/bio/share/scgpt/checkpoints/whole_human`.
- **Pinned versions:** Every tool is installed at a fixed version, and the full list of installed packages is recorded in the image (`/opt/bio/share/bx-scgpt/conda-explicit.txt`, `pip-freeze.txt`).
- **Tool location:** All tools are in `/opt/bio/bin` inside the image and on the PATH.
- **Analysis scripts:** Not stored in the image; they are bound at run time, so a script update does not need a new image.
- **Internet:** No internet access at run time.

---

## 2. 이미지 목록 / Images

| 이미지 | 버전 | 사용하는 모듈 (스크립트) | 주요 도구 |
|---|---|---|---|
| bx_scgpt | 1.0 | scgpt_prep (scgpt_prep.1.0.py), scgpt_train (scgpt_train.1.0.py), scgpt_predict (scgpt_predict.1.0.py), scgpt_compare (scgpt_compare.1.0.py) | scGPT 0.2.4, PyTorch 2.6.0 (CPU), Python 3.11.18, Scanpy 1.10.4 |
| bx_scgpt_gpu | 1.0 | scgpt_embed (scgpt_embed.1.0.py) | scGPT 0.2.4, PyTorch 2.6.0 (CUDA 12.6), Python 3.11.18, Scanpy 1.10.4 |

두 이미지 모두 Bootstrap `docker`, From `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8), Miniforge3 26.7.2-0 (conda-forge)입니다.

---

## 3. 이미지별 상세 / Image details

### 3.1 bx_scgpt 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

- **설명(국문):** scGPT 0.2.4와 CPU용 PyTorch 2.6으로 단일세포 데이터셋을 만들고, 세포 임베딩 위의 개체 단위 분류 모델을 학습·예측·비교하는 환경입니다. Scanpy와 anndata로 행렬을 읽고, scikit-learn으로 기준 방법(로지스틱 회귀, PCA)과 평가 지표를 계산합니다. whole-human 체크포인트가 들어 있습니다.
- **Description (English):** Environment for building single-cell datasets and for training, applying and comparing individual-level classifiers on cell embeddings with scGPT 0.2.4 and CPU PyTorch 2.6. Scanpy and anndata read the matrices, and scikit-learn computes the baselines (logistic regression, PCA) and evaluation metrics. The whole-human checkpoint is included.

**포탈 등록 (컨테이너) / Portal registration**

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

### 3.2 bx_scgpt_gpu 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/scGPT/bx_scgpt_gpu.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge) |

- **설명(국문):** scGPT 0.2.4와 GPU용 PyTorch 2.6(CUDA 12.6)으로 세포마다 scGPT 임베딩을 만드는 환경입니다. 실행할 때 GPU를 연결해야 하며(apptainer `--nv`), GPU가 없으면 CPU로 돌지만 매우 느립니다. whole-human 체크포인트가 들어 있습니다. 이미지 크기는 약 5.3GB입니다.
- **Description (English):** Environment for making scGPT embeddings of every cell with scGPT 0.2.4 and GPU PyTorch 2.6 (CUDA 12.6). A GPU must be attached at run time (apptainer `--nv`); without one it falls back to the CPU, which is very slow. The whole-human checkpoint is included. The image is about 5.3 GB.

**포탈 등록 (컨테이너) / Portal registration**

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
