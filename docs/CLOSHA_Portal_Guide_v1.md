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
  - 포탈에 보이는 본문(소개, 내용, 주요 사항)은 "~합니다"체로 쓴다.
  - 레전드와 내부 메모는 "~다"체로 쓴다.
- **사실은 스크립트로 확인한다.** 버전, 기본값, 출력 파일 이름, 지원 범위(예: paired-end만)는 스크립트에 적힌 대로 쓴다. 기억이나 다른 파이프라인에서 옮겨 쓰지 않는다.
- **버전은 실행 스크립트 파일 이름의 버전을 쓴다.** 예: `organellar_filter.1.1.sh` → 1.1
- **내부 메모를 구분한다.** 포탈에 넣지 않을 설명은 아래 문구로 시작한다. Word에서 회색 "붙여넣지 않음" 표시로 나온다.
  - 내부 메모로 인식되는 시작 문구: `KOBIC 포탈의`, `포탈 스타일`, `포탈의 현재`, `그림:`, `등록 화면 공통 안내`
  - 이 목록은 `docs/tools/make_portal_docx.js`의 `NOTE_PREFIXES`에 있다.
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
| 기본 정보 | 모듈명, 서브 타이틀(국문·영문), 버전, 카테고리(5.2), 태그, 레퍼런스 URL(도구 홈페이지), 컨테이너 이미지(DEF 이름), 실행 스크립트 파일 |
| 내용(국문/영문) | 첫 문단에 무엇을 왜 하는지, 이어서 bullet 3~4개(방법, 만드는 결과, 다음 모듈) |
| 입출력 / 파라미터 | 표: 탭(Input/Output/Option), 필수, 형식, Name(인자 이름), Value(기본값), Description(국문), English Description |
| 샘플시트 | 샘플 정보 파일을 받는 모듈만. 열 이름, 필수 여부, 예시 |
| 주요 사항 | 국문·영문 두 열 표. 사용자가 실수하기 쉬운 입력 조건 위주 |
| 분석 개념 이미지 | 그림 + 레전드(국문·영문) + 출처(5.3) |
| 스크립트 사용 예제 | `key=value` 형식의 실행 한 줄 |
| 주요 결과 이미지 | 등록할 결과 파일 + 레전드(국문·영문)(5.4) |

등록 화면의 공통 값:
- **기반 이미지 출처(Bootstrap):** `Apptainer`(작업이 SIF로 실행되므로)
- **기반 이미지(From):** DEF의 `From` 값
- **형식(Type):** 포탈 목록에서 고른다. 원고에는 Directory, File, String, Integer, Float, List로 적는다.
- **필수 입력·출력의 Value:** 비어 있으면 등록이 안 되므로 예시 경로(`/data/<모듈>`, `/ref/genome.fa` 등)를 넣는다. 스크립트 사용 예제와 같은 경로를 쓴다. 기본값이 아니라 캔버스에서 실제 경로로 바꿀 자리이며, 그대로 넘어가면 스크립트가 "not found"로 멈춘다.
- **선택 입력의 Value:** 스크립트는 빈 값을 "사용 안 함"으로 읽는다. 경로를 넣으면 그 경로를 실제로 쓰려 하므로 비워 둔다.

### 5.2 카테고리와 아이콘
카테고리는 오믹스 종류가 아니라 **분석 단계(기능)**로 나눈다. 그래야 다른 파이프라인의 모듈도 같은 목록에 넣을 수 있다. "ATAC-seq QC", "Epigenomics"처럼 특정 분석이나 연구 분야 이름은 쓰지 않는다.

| 대분류 | 중분류 예 | ATAC-seq 모듈 |
|---|---|---|
| Quality Control | Raw Data QC, Alignment QC, Reproducibility | ATAC_QC, ATAC_QC_plot, replicate_consistency |
| Preprocessing | Read Trimming | (fastp) |
| Alignment | Read Alignment, Alignment Processing | organellar_filter, (bowtie2, MarkDuplicates) |
| Feature Detection | Peak Calling, Variant Calling | MACS3_callpeak_ATAC |
| Annotation | Genomic Feature Annotation, Gene Annotation, Taxonomic Classification | peak_annotation |
| Statistical Analysis | Differential Analysis | differential_accessibility |
| Gene Regulation | Motif Analysis, TF Footprinting, Regulatory Network | atac_motif, tf_footprinting |
| Functional Analysis | Enrichment Analysis, Pathway Analysis, Functional Profiling | functional_enrichment |
| Visualization | Plotting | — |

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
- 모듈마다 대표 그림 하나를 고른다. 두 그림을 함께 봐야 이해되면 A/B로 나란히 둔다. 샘플이나 조건별로 여러 개 나오는 그림은 대표 하나만 쓴다.
- 원고에는 `output_dir` 기준의 정확한 파일 경로를 적는다. 파일 이름은 스크립트에서 확인한다.
- 그림을 만들지 않는 모듈은 요약표(TSV)를 화면 캡처해 등록한다.
- 다른 그림과 같이 **PNG(포탈 등록용)와 SVG(원본)를 함께 저장**해 커밋한다.
  - 위치와 이름: `docs/<파이프라인>/modules/figures/module_results/<모듈>_result.{png,svg}`
  - A/B 두 그림이면 `<모듈>_result_A`, `<모듈>_result_B`로 나눈다.
- PDF 결과는 PNG와 SVG로 각각 바꾼다. 여러 쪽짜리는 `-f <쪽> -l <쪽>`로 쪽을 고른다.
  ```
  pdftocairo -png -r 200 -singlefile <그림>.pdf <모듈>_result
  pdftocairo -svg <그림>.pdf <모듈>_result.svg
  ```
- 결과가 처음부터 PNG인 그림(예: IDR의 `.idr.png`)과 표 캡처는 SVG를 만들 수 없으니 PNG만 저장한다.
- 레전드에는 세 가지를 쓴다.
  - 그림 읽는 법: 축, 점·색의 뜻
  - 정상 결과가 어떻게 보이는지
  - 기준값이 있으면 그 값과 출처. 예: FRiP는 ENCODE 기준 0.3 이상이 바람직하고 0.2 이상이면 허용한다.

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
- [ ] 결과 그림을 `module_results/`에 PNG와 SVG로 저장했다(PNG만 나오는 그림 제외).
- [ ] Word 파일을 md에서 다시 만들어 함께 커밋했다.
