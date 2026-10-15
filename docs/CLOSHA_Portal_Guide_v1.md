# CLOSHA 포탈 원고 작성 방법 v1

KOBIC 포탈의 파이프라인 페이지와 모듈 등록 화면에 넣을 원고를 쓰는 방법이다. 실제 적용 예는 ATAC-seq(`docs/ATAC-seq/`)이다. 그림을 그리는 규칙은 `docs/CLOSHA_Figure_Guide_v1.md`를 따른다.

작성일: 2026-10-14

## 1. 만드는 파일

| 파일 | 내용 |
|---|---|
| `docs/<파이프라인>/modules/Registration.md` | 모듈별 Input / Output / Option 정의와 모듈 연결. 원고의 기준 |
| `docs/<파이프라인>/modules/Portal_Content.md` | 모듈 등록 화면 원고(모듈마다 한 절) |
| `docs/<파이프라인>/pipeline/Portal_Content.md` | 파이프라인 상세 페이지 원고 |
| 위 두 원고의 `.docx` | 포탈에 붙여 넣을 Word 파일(md에서 생성, 6절) |
| `docs/<파이프라인>/pipeline/figures/`, `modules/figures/` | 노선도, 개념도(Figure Guide 참고) |

포탈에는 편집기가 없고 Word에서 붙여 넣은 서식(굵게, 표)이 그대로 들어간다. 그래서 원고는 md로 쓰고, 붙여 넣을 때는 md에서 만든 Word 파일을 쓴다.

## 2. 쓰는 순서

1. **Registration.md**: 스크립트(`scripts/<파이프라인>/`)의 최신 버전을 읽고 인자, 기본값, 출력 폴더, 모듈 연결을 정리한다.
2. **모듈 원고**: 모듈마다 3절의 항목을 채운다.
3. **파이프라인 원고**: 4절의 항목을 채운다.
4. **그림**: 노선도, 파이프라인 개념도, 모듈 개념도를 만든다(Figure Guide).
5. **Word 생성**: 두 원고를 Word로 만든다(6절).
6. **포탈 등록**: Word에서 항목별로 복사해 붙여 넣는다.

## 3. 공통 규칙

- **국문과 영문을 모두 쓴다.** 영문은 번역투가 아니라 같은 내용을 영어로 다시 쓴다.
- **문체**
  - 원고의 모든 문장은 경어체("~합니다", "~습니다", "~입니다")로 통일한다. 본문(소개, 내용, 주요 사항), 레전드, 등록 메모, 공통 안내 모두 같다. "~한다", "~이다"로 끝나는 문장은 쓰지 않는다.
  - 표의 Description처럼 짧은 항목 설명은 명사형(개조식)으로 써도 된다. 예: "결과 폴더", "쓰기 권한이 필요".
- **사실은 스크립트로 확인한다.** 버전, 기본값, 출력 파일 이름, 지원 범위(예: paired-end만)는 스크립트에 적힌 대로 쓴다. 기억이나 다른 파이프라인에서 옮겨 쓰지 않는다.
- **버전은 실행 스크립트 파일 이름의 버전을 쓴다.** 예: `organellar_filter.1.1.sh` → 1.1
- **내부 메모를 구분한다.** 포탈에 넣지 않을 설명은 아래 문구로 시작한다. Word에서 회색 "붙여넣지 않음" 표시로 나온다.
  - 내부 메모로 인식되는 시작 문구: `KOBIC 포탈의`, `포탈 스타일`, `포탈의 현재`, `그림:`, `등록 메모:`, `등록 화면 공통 안내`
  - 이 목록은 `docs/tools/make_portal_docx.js`의 `NOTE_PREFIXES`에 있다.
- **설명은 칸마다 완결되게 쓴다.** 모듈 페이지는 따로 보이므로, "~와 같음", "ATAC_QC와 같은 파일", "그대로 써도 됨"처럼 다른 모듈이나 다른 칸을 가리키지 않고 같은 내용이라도 다시 쓴다.
- **용어:** 도구 이름(MACS3, edgeR), 파일 형식(BAM, narrowPeak), 분석 용어(peak, FRiP, TSS)는 국문에서도 영문 그대로 쓴다.

## 4. 파이프라인 페이지

| 순서 | 항목 | 쓰는 법 |
|---|---|---|
| 1 | 파이프라인 소개 | 한 문단. 무엇을 측정하는 분석인지 → 입력 → 처리 단계 → 주요 도구와 결과 |
| 2 | 분석 목표 | 질문형 3~4개: `01 어떤 …인가` + 두세 문장 설명. 영문도 질문형 |
| 3 | 분석 흐름 | 노선도 그림 + 대체 텍스트(국문·영문 한 줄씩) |
| 4 | 분석 개념 | 개념도 그림 + 레전드(국문·영문) + 대체 텍스트 + 출처(5절) |
| 5 | 주요 사항 | 파이프라인 전체에 해당하는 사용 조건만 번호 목록으로 쓴다 |

주요 사항에 들어갈 것과 빠질 것:
- **들어갈 것:** 지원 데이터(예: paired-end만), 반복 실험 수, 샘플 정보 파일 형식, 참조 자료의 종·버전 일치, 확인할 품질 지표, 인터넷 없이 실행되는지
- **빠질 것:** 모듈 하나에만 해당하는 내용(모듈 페이지로), 도구 설치 안내(작업이 SIF로 실행되므로 사용자가 설치할 것이 없다)

## 5. 모듈 페이지

### 5.1 항목
| 항목 | 쓰는 법 |
|---|---|
| 기본 정보 | 모듈명, 서브 타이틀(국문·영문), 버전, 카테고리(5.2), 태그, 레퍼런스 URL(도구 홈페이지), 컨테이너 이미지(DEF 이름), 실행 스크립트 파일, Processor Core(제안) |
| 실행 이미지 | 이미지 이름과 버전, DEF 정보 표(DEF 파일, DEF Bootstrap, DEF From, conda 설치 도구), 이미지 설명(국문·영문), 설치 도구와 버전 표(5.5) |
| 내용(국문/영문) | 첫 문단에 무엇을 왜 하는지, 이어서 bullet 3~4개(방법, 만드는 결과, 다음 모듈) |
| 입출력 / 파라미터 | 표: 탭(Input/Output/Option), 필수, 형식, Name(인자 이름), Value(기본값), Description(국문), English Description |
| 샘플시트 | 샘플 정보 파일을 받는 모듈만. 열 이름, 필수 여부, 예시 |
| 주요 사항 | 국문·영문 두 열 표. 사용자가 실수하기 쉬운 입력 조건 위주 |
| 분석 개념 이미지 | 그림 + 레전드(국문·영문) + 출처(5.3) |
| 스크립트 사용 예제 | `key=value` 형식. 포탈에 등록하는 인자와 기본값이 있는 옵션을 모두 적고 한 줄에 인자 하나 |
| 주요 결과 이미지 | 등록할 결과 파일 + 레전드(국문·영문)(5.4) |

등록 화면의 공통 값:
- **기반 이미지 출처(Bootstrap):** `Apptainer`(작업이 SIF로 실행되므로). DEF 파일 안의 `Bootstrap: docker`와 다르니 섞지 않는다.
- **기반 이미지(From):** DEF의 `From` 값
- **형식(Type):** 포탈 목록에서 고른다. 원고에는 Directory, File, String, Integer, Float, List로 적는다.
- **필수 입력·출력의 Value:** 비어 있으면 등록이 안 되므로 예시 경로(`/data/<모듈>`, `/ref/genome.fa` 등)를 넣는다. 스크립트 사용 예제와 같은 경로를 쓴다. 기본값이 아니라 캔버스에서 실제 경로로 바꿀 자리이며, 그대로 넘어가면 스크립트가 "not found"로 멈춘다.
- **선택 입력의 Value:** 스크립트는 빈 값을 "사용 안 함"으로 읽는다. 경로를 넣으면 그 경로를 실제로 쓰려 하므로 비워 둔다.

### 5.2 카테고리와 아이콘
카테고리는 오믹스 종류가 아니라 **분석 단계(기능)**로 나눈다. 그래야 다른 파이프라인의 모듈도 같은 목록에 넣을 수 있다. "ATAC-seq QC", "Epigenomics"처럼 특정 분석이나 연구 분야 이름은 쓰지 않는다.

| 대분류 (국문) | 중분류 (국문) | ATAC-seq 모듈 |
|---|---|---|
| Quality Control (품질 관리) | Raw Data QC (원시 데이터 품질 평가) | (fastqc) |
| | Alignment QC (정렬 품질 평가) | ATAC_QC, ATAC_QC_plot |
| | Reproducibility (재현성 평가) | replicate_consistency |
| Preprocessing (전처리) | Read Trimming (read 다듬기) | (fastp) |
| Alignment (정렬) | Read Alignment (read 정렬) | bowtie2 |
| | Alignment Processing (정렬 결과 처리) | organellar_filter, (GATK_MarkDuplicates) |
| Feature Detection (특징 검출) | Peak Calling (peak 검출) | MACS3_callpeak_ATAC |
| | Variant Calling (변이 검출) | — |
| Annotation (주석) | Genomic Feature Annotation (유전체 영역 주석) | peak_annotation |
| | Gene Annotation (유전자 주석), Taxonomic Classification (분류군 판별) | — |
| Statistical Analysis (통계 분석) | Differential Analysis (차등 분석) | differential_accessibility |
| Gene Regulation (유전자 조절) | Motif Analysis (모티프 분석) | atac_motif |
| | TF Footprinting (전사인자 footprint) | tf_footprinting |
| | Regulatory Network (조절 네트워크) | — |
| Functional Analysis (기능 분석) | Enrichment Analysis (농축 분석) | functional_enrichment |
| | Pathway Analysis (경로 분석), Functional Profiling (기능 프로파일링) | — |
| Visualization (시각화) | Plotting (그림) | — |

괄호 안 모듈은 ATAC-seq 원고에 아직 없는 모듈이다. 새 모듈은 이 표에서 대분류·중분류를 고르고, 맞는 것이 없을 때만 중분류를 새로 만든다(대분류는 늘리지 않는 것을 원칙으로 한다).

- 이름을 고른 이유:
  - **Alignment, Mapping 대신:** Alignment가 서열끼리 정렬(MSA)까지 포함하는 넓은 말이다.
  - **Functional Analysis, Pathway Analysis 대신:** GO는 pathway가 아니다.
  - **Gene Regulation, Regulatory Analysis 대신:** scRNA-seq이나 RNA-seq의 조절 네트워크 분석도 담을 수 있다.
- 아이콘은 **대분류마다 하나**를 쓰고, 한 세트(같은 작가, 같은 선 스타일)로 통일한다. 기준은 Shutterstock의 UniconLabs 선 아이콘 세트다.
  - 검은 테두리, 속 비움, 둥근 선 끝
  - 세트에 맞는 것이 없으면 같은 스타일로 직접 그린다: `docs/category_icons/make_category_icons.py`. 예: `gene_regulation.png`
  - Shutterstock 검색 요령: 분석 용어(read, peak, filter)는 일상 뜻으로 검색되므로, `DNA`·`genome`을 붙이고 그림에 들어갈 물체로 검색한다. 예: `DNA checkmark icon`, `DNA graph icon`, `gene network icon`

### 5.3 개념도 레전드와 출처
- 레전드는 논문 figure legend 형식으로 쓴다. 굵은 제목 한 문장 뒤에 "(A) … (B) …" 순서로 설명한다.
- 논문 그림을 수정해 썼으면 레전드 끝에 짧은 출처를 쓴다. 예: `Ou J. et al., BMC Genomics 19, 169 (2018), Fig. 1을 수정(CC BY 4.0).`
- 출처 줄에는 전체 서지 정보를 쓴다. 형식:
  `저자 전원. 제목. *저널* 권, 쪽 (연도). https://doi.org/<DOI>, Fig. N을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).`
- 저자, 제목, 라이선스는 기억으로 쓰지 않는다. Europe PMC에서 조회해 옮긴다.
  `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:"<DOI>"&resultType=core&format=json`
  (`authorString`, `title`, `license` 필드)
- 직접 그린 그림은 출처 줄에 `직접 작성한 모식도(외부 그림 사용 안 함)`이라고 쓴다.

### 5.4 주요 결과 이미지
- 실제 데이터로 실행한 결과에서 가져온다. 개념도처럼 그리지 않는다.
- 결과를 풍부하게 보여 준다. 모듈이 만드는 그림 중 사용자가 결과를 판단하는 데 쓰는 것을 여러 개(보통 2~4개) 고른다. 그림 하나로 끝내지 않는다.
  - 순서: 결과 1이 대표 그림(모듈의 핵심 결과)이고, 그다음 품질 확인·보조 그림, 마지막에 요약표 캡처를 둔다.
  - 그림마다 `**결과 N. 제목**`, 결과 파일, 레전드(국문·영문)를 따로 쓴다.
  - 샘플이나 조건별로 여러 개 나오는 그림은 대표 샘플(조건) 하나만 쓰고, 같은 샘플의 그림끼리 묶는다.
  - 옵션을 켤 때만 나오는 그림은 결과 파일 줄에 조건을 적는다(예: `run_kmer=TRUE일 때`).
- 원고에는 `output_dir` 기준의 정확한 파일 경로를 적는다. 파일 이름은 스크립트에서 확인한다.
- 그림을 만들지 않는 모듈은 요약표(TSV)를 화면 캡처해 등록한다.
- 원고에는 결과 파일 이름만 적는다. 그림 파일은 저장소에 만들지 않고, 등록할 때 실제 결과를 캡처해 올린다.
- 레전드에는 세 가지를 쓴다.
  - 그림 읽는 법: 축, 점·색의 뜻
  - 정상 결과가 어떻게 보이는지
  - 기준값이 있으면 그 값과 출처. 예: FRiP는 ENCODE 기준 0.3 이상이 바람직하고 0.2 이상이면 허용한다.

### 5.5 실행 이미지
모듈이 도는 Apptainer 이미지 정보를 모듈마다 적는다. 매뉴얼 웹페이지의 이미지 설명도 이 절을 쓴다.

- **값은 DEF 파일에서 옮긴다.** 기억이나 다른 문서에서 쓰지 않는다.

  | 원고 항목 | DEF에서 가져오는 곳 |
  |---|---|
  | 이미지 이름, 버전 | 파일 이름 `<이미지>.<버전>.def`, `%labels`의 `Component`, `Version` |
  | DEF Bootstrap, DEF From | 파일 첫 줄의 `Bootstrap:`, `From:` (From은 digest까지 그대로, 머리 주석의 태그를 괄호로 덧붙임) |
  | conda 설치 도구 | `%labels`의 `CondaInstaller` |
  | 설치 도구와 버전 | `%post`의 `conda create`·`conda install` 목록에서 버전을 지정한 패키지 |
  | 이미지 설명 | `%labels`의 `Description`을 국문·영문으로 풀어 씀 |

- **표 형식**

  | 항목 / Item | 값 / Value |
  |---|---|
  | DEF 파일 | `defs/<파이프라인>/<이미지>.<버전>.def` |
  | DEF Bootstrap | `docker` |
  | DEF From | `rockylinux/rockylinux@sha256:...` (Rocky Linux 9.8, `9.8.20260525.0`) |
  | conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

  그 아래 이미지 설명(국문·영문)과 `| 도구 | 버전 |` 표를 둔다.
- **같은 이미지를 쓰는 모듈에도 각각 다 적는다**(3절 규칙). "ATAC_QC와 같은 이미지" 같은 문장을 쓰지 않는다.
- **Bootstrap을 구분한다.** 포탈 등록 화면의 Bootstrap 칸(`Apptainer`)과 DEF 파일의 `Bootstrap: docker`는 다른 값이다. 원고 표에는 "DEF Bootstrap", "DEF From"으로 적는다.
- **DEF가 저장소에 없으면** 표를 비워 두지 말고 `등록 메모:`로 보류 사유를 적는다.
- **DEF를 고치면** 이 절도 같이 고친다. 분석 스크립트만 바뀐 경우에는 이미지가 같으므로 고치지 않는다.
- 이미지 공통 설명(매뉴얼용): Rocky Linux 9.8을 digest로 고정, Miniforge로 conda-forge·bioconda만 사용(Anaconda 저장소 사용 안 함), 모든 도구 버전 고정과 설치 목록 기록(`/opt/bio/share/<이미지 이름, _는 ->/conda-explicit.txt`), 도구는 `/opt/bio/bin`, 분석 스크립트는 이미지에 넣지 않고 실행할 때 연결, 실행 중 인터넷 없음.

## 6. Word 만들기

```
# docx 패키지는 저장소 밖(scratch 폴더)에 설치한다
mkdir -p <scratch>/docxgen && cd <scratch>/docxgen && npm init -y && npm install docx

cd /workspaces/DEF
NODE_PATH=<scratch>/docxgen/node_modules node docs/tools/make_portal_docx.js \
  docs/<파이프라인>/pipeline/Portal_Content.md docs/<파이프라인>/pipeline/Portal_Content.docx
NODE_PATH=<scratch>/docxgen/node_modules node docs/tools/make_portal_docx.js \
  docs/<파이프라인>/modules/Portal_Content.md docs/<파이프라인>/modules/Portal_Content.docx
```

- 스타일은 포탈에 맞춰져 있다.
  - 본문: Pretendard #222222
  - 제목: GmarketSans #32549C
  - 메모: #3A3A3A
- 원고에 `` `docs/…png` `` 형식으로 적은 그림은 Word에 그림으로 들어간다.
- md를 고치면 Word도 다시 만들어 함께 커밋한다.

## 7. 확인 목록

- [ ] 버전, 기본값, 출력 파일 이름이 스크립트와 같다.
- [ ] 모든 항목에 국문과 영문이 있다.
- [ ] 입출력 표가 `Registration.md`와 같다.
- [ ] 카테고리가 5.2의 대분류 목록에 있다.
- [ ] 개념도와 결과 그림마다 레전드(국문·영문)가 있다.
- [ ] 논문 그림은 CC BY만 썼고, 출처 줄에 전체 서지, DOI, 라이선스 링크가 있다.
- [ ] 주요 사항에 모듈 설치 안내가 들어가지 않았다.
- [ ] 결과 그림을 모듈마다 여러 개(대표 그림, 품질 확인·보조 그림, 요약표) 골랐고 그림마다 레전드가 있다.
- [ ] 모듈마다 실행 이미지 절이 있고, 값이 DEF 파일과 같다.
- [ ] Word 파일을 md에서 다시 만들어 함께 커밋했다.
