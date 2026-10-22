# CNV 파이프라인 실행 이미지(DEF) 안내

KOBIC 포탈 매뉴얼 웹페이지에 올릴 CNV 실행 이미지 설명입니다. 각 이미지는 `defs/CNV/<이미지>.def`로 만듭니다. DEF 작성 규칙은 `docs/CLOSHA_DEF_Generator_Agent_v1.md`, 스크립트 규칙은 `docs/CLOSHA_Script_Rules_v1.md`를 따릅니다.

등록 메모: 버전과 도구 목록은 2026-10-22 기준 DEF 파일에서 옮겼습니다. DEF를 고치면 이 문서도 함께 고칩니다.

---

## 1. 공통 사항

### 국문
CNV 파이프라인의 각 모듈은 분석 도구를 미리 설치한 Apptainer 이미지(SIF) 안에서 실행됩니다. CNVkit과 FACETS는 요구하는 R 버전이 달라(CNVkit 0.9.14는 R 4.5.3 이상, FACETS 0.6.2는 R 4.4까지) 한 환경에 함께 설치할 수 없으므로 이미지를 둘로 나눴습니다.
- **기반 운영체제:** Rocky Linux 9.8 공식 이미지(`rockylinux/rockylinux:9.8.20260525.0`)를 고유 식별값(digest)으로 고정하여, 언제 만들어도 같은 기반을 씁니다.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **도구 설치:** Miniforge로 conda-forge와 bioconda 채널에서만 설치합니다. Anaconda 저장소(defaults 채널, repo.anaconda.com)는 사용하지 않습니다.
- **버전 고정:** 모든 도구는 버전을 지정해 설치하고, 설치된 전체 패키지 목록을 이미지 안에 기록합니다(`/opt/bio/share/bx-cnvkit/conda-explicit.txt`, `/opt/bio/share/bx-facets/conda-explicit.txt`).
- **도구 위치:** 모든 도구는 이미지 안의 `/opt/bio/bin`에 있으며 실행 경로(PATH)에 들어 있습니다.
- **분석 스크립트:** 이미지에 넣지 않고, 실행할 때 연결합니다. 그래서 스크립트를 고쳐도 이미지를 다시 만들 필요가 없습니다.
- **인터넷:** 실행 중에는 인터넷에 접속하지 않습니다. 염색체 팔 경계를 위한 UCSC cytoband 표(hg38, hg19)는 이미지를 만들 때 SHA256으로 확인해 넣습니다.

### English
Each module of the CNV pipeline runs inside an Apptainer image (SIF) with its analysis tools preinstalled. CNVkit and FACETS need different R versions (CNVkit 0.9.14 needs R 4.5.3 or later, FACETS 0.6.2 supports R up to 4.4), so they cannot share one environment and are split into two images.
- **Base OS:** the official Rocky Linux 9.8 image (`rockylinux/rockylinux:9.8.20260525.0`), pinned by its digest so every build starts from the same base.
  - Bootstrap: `docker`
  - From: `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`
- **Tool installation:** Miniforge, from the conda-forge and bioconda channels only. Anaconda repositories (the defaults channel, repo.anaconda.com) are not used.
- **Pinned versions:** Every tool is installed at a fixed version, and the full list of installed packages is recorded in the image (`/opt/bio/share/bx-cnvkit/conda-explicit.txt`, `/opt/bio/share/bx-facets/conda-explicit.txt`).
- **Tool location:** All tools are in `/opt/bio/bin` inside the image and on the PATH.
- **Analysis scripts:** Not stored in the image; they are bound at run time, so a script update does not need a new image.
- **Internet:** No internet access at run time. The UCSC cytoband tables (hg38, hg19) for chromosome arms are added at build time and checked by SHA256.

---

## 2. 이미지 목록 / Images

| 이미지 | 버전 | 사용하는 모듈 (스크립트) | 주요 도구 |
|---|---|---|---|
| bx_cnvkit | 1.0 | cnvkit_reference (cnvkit_reference.1.0.py), cnvkit_call (cnvkit_call.1.0.py), cnv_summary (cnv_summary.1.0.py) | CNVkit 0.9.14, Python 3.12.15, R 4.5.3, DNAcopy 1.86.0, SAMtools 1.22.1 |
| bx_facets | 1.0 | cnv_facets (cnv_facets.1.0.R) | FACETS 0.6.2, snp-pileup 0.6.2, R 4.4.3, HTSlib 1.24 |

두 이미지 모두 Bootstrap `docker`, From `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8), Miniforge3 26.7.2-0 (conda-forge, bioconda)입니다.

---

## 3. 이미지별 상세 / Image details

### 3.1 bx_cnvkit 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_cnvkit.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** CNVkit으로 정상 기준을 만들고 종양의 복제수를 분절·판정하며, pandas와 Matplotlib으로 샘플별·코호트 그림과 HTML 리포트를 만드는 환경입니다. CNVkit의 CBS 분절에 쓰는 R DNAcopy와 UCSC cytoband 표(`/opt/bio/share/cnv-data/`, 환경변수 `CNV_DATA_DIR`)가 들어 있습니다.
- **Description (English):** Environment for building normal references and segmenting and calling tumor copy number with CNVkit, and for drawing per-sample and cohort figures and an HTML report with pandas and Matplotlib. It includes R DNAcopy for CNVkit CBS segmentation and the UCSC cytoband tables (`/opt/bio/share/cnv-data/`, environment variable `CNV_DATA_DIR`).

| 도구 | 버전 |
|---|---|
| CNVkit | 0.9.14 |
| Python | 3.12.15 |
| R | 4.5.3 |
| DNAcopy | 1.86.0 |
| SAMtools | 1.22.1 |
| pandas | 3.0.6 |
| NumPy | 2.5.4 |
| SciPy | 1.18.1 |
| Matplotlib | 3.11.2 |
| UCSC cytoBand | hg38, hg19 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| CNVkit | 0.9.14 | https://cnvkit.readthedocs.io/ |
| Python | 3.12.15 | https://www.python.org/ |
| R | 4.5.3 | https://www.r-project.org/ |
| DNAcopy | 1.86.0 | https://bioconductor.org/packages/DNAcopy/ |
| SAMtools | 1.22.1 | https://www.htslib.org/ |
| pandas | 3.0.6 | https://pandas.pydata.org/ |
| NumPy | 2.5.4 | https://numpy.org/ |
| SciPy | 1.18.1 | https://scipy.org/ |
| Matplotlib | 3.11.2 | https://matplotlib.org/ |
| UCSC cytoBand (hg38, hg19) | - | https://hgdownload.soe.ucsc.edu/ |

- **태그(키워드):** 복제수변이, 체세포CNV, CNVkit, 코호트요약
- **내용(국문):** 종양 시료의 체세포 복제수 변이(CNV)를 CNVkit으로 분석하는 실행 환경입니다. 정상 시료로 기준을 만들고, 종양의 커버리지를 보정·분절·판정하며, 샘플별 그림과 코호트 그림, HTML 리포트를 만듭니다. 염색체 팔 경계를 위한 UCSC cytoband 표(hg38, hg19)가 들어 있어 실행 중 인터넷을 쓰지 않습니다.
- **내용(영문):** Runtime environment for somatic copy-number variation (CNV) analysis of tumor samples with CNVkit. It builds a reference from normal samples, corrects, segments and calls tumor coverage, and draws per-sample and cohort figures with an HTML report. UCSC cytoband tables (hg38, hg19) for chromosome arms are bundled, so no internet access is needed at run time.

### 3.2 bx_facets 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_facets.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | `rockylinux/rockylinux@sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f` (Rocky Linux 9.8) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

- **설명(국문):** snp-pileup으로 종양-정상 쌍의 SNP 위치 read 수를 세고, FACETS로 순도, 배수성, 대립유전자별 복제수를 추정하는 환경입니다.
- **Description (English):** Environment for counting reads of tumor-normal pairs at SNP sites with snp-pileup and estimating purity, ploidy and allele-specific copy number with FACETS.

| 도구 | 버전 |
|---|---|
| FACETS | 0.6.2 |
| snp-pileup | 0.6.2 |
| R | 4.4.3 |
| HTSlib | 1.24 |

**포탈 등록 (컨테이너) / Portal registration**

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| FACETS | 0.6.2 | https://github.com/mskcc/facets |
| snp-pileup | 0.6.2 | https://github.com/mskcc/facets |
| R | 4.4.3 | https://www.r-project.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |

- **태그(키워드):** 종양순도, 배수성, LOH, FACETS
- **내용(국문):** 종양-정상 쌍에서 FACETS로 종양 순도, 배수성, 대립유전자별 복제수(LOH 포함)를 추정하는 실행 환경입니다. snp-pileup으로 SNP 위치의 read 수를 세고, FACETS로 분절과 적합을 합니다. FACETS가 R 4.4까지만 지원해 CNVkit 이미지와 나눴습니다.
- **내용(영문):** Runtime environment for estimating tumor purity, ploidy and allele-specific copy number (including LOH) from tumor-normal pairs with FACETS. snp-pileup counts reads at SNP sites and FACETS segments and fits them. It is separate from the CNVkit image because FACETS supports R up to 4.4.

---

## 4. 검증 빌드 / Verification build

2026-10-22 Codespace(2코어, 메모리 7GB)에서 root 권한 빌드(`apptainer build`)로 확인했습니다. 운영 HPC에서는 빌드하지 않았고 SIF를 배포하지 않았습니다.

| 이미지 | 결과 | 시간 | SIF 크기 | `%test` |
|---|---|---|---|---|
| bx_cnvkit 1.0 | 성공 | 6분 | 680MB | CNVkit 0.9.14 / Python 3.12 / R 4.5.3 runtime dependency checks passed |
| bx_facets 1.0 | 성공 | 5분 | 678MB | FACETS 0.6.2 / snp-pileup 0.6.2 / R 4.4.3 runtime dependency checks passed |

- 호스트 영향 확인: 빌드 중 호스트의 `/proc`·`/sys` 쓰기 없음(strace), sysctl 변화 없음, `/__closha_build` 남지 않음. 호스트 `/tmp`·`/var/tmp`의 변화는 빌드와 무관한 프로그램(VS Code, SQLite 임시 파일)뿐이었습니다.
- 빌드 기록: `/workspaces/.closha_build_test/root/logs/bx_cnvkit.root.summary`, `bx_facets.root.summary`(저장소 밖).
