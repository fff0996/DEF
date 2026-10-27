# CLOSHA 포탈 원고 작성 방법 v1

KOBIC 포탈의 파이프라인 페이지와 모듈 등록 화면에 넣을 원고를 쓰는 방법이다. 실제 적용 예는 ATAC-seq(`docs/ATAC-seq/`)이다. 그림을 그리는 규칙은 `docs/CLOSHA_Figure_Guide_v1.md`를 따른다.

작성일: 2026-10-14

개정 (2026-10-17): 배포 번호와 배포 폴더, CLOSHA 프로그램 카테고리, 실제 결과 그림으로 만드는 결과 이미지(그림 확인, PNG 변환, 표 그림, 예시 데이터 값), 다른 모듈을 가리키지 않는 입출력 설명, 사용 예제와 파라미터 표 일치, 컨테이너 등록 항목, 파이프라인 등록 항목을 반영했다.

## 1. 만드는 파일

| 파일 | 내용 |
|---|---|
| `docs/<파이프라인>/modules/Registration.md` | 모듈별 Input / Output / Option 정의와 모듈 연결. 원고의 기준 |
| `docs/<파이프라인>/modules/Portal_Content.md` | 모듈 등록 화면 원고(모듈마다 한 절) |
| `docs/<파이프라인>/pipeline/Portal_Content.md` | 파이프라인 상세 페이지 원고 |
| 위 두 원고의 `.docx` | 포탈에 붙여 넣을 Word 파일(md에서 생성, 6절) |
| `docs/<파이프라인>/containers/Container_Manual.md` | 실행 이미지(컨테이너) 설명과 컨테이너 등록 항목(5.5) |
| `release/<플랫폼>/<파이프라인>/<배포일>/` | 배포 폴더: 배포 스크립트, 원고 사본(`docs/`), 결과 원본(`results/`), 포탈에 올릴 PNG 모음(`portal_images/`, `portal_images.zip`). 배포 후에는 고치지 않는다(`docs/CLOSHA_Script_Rules_v1.md` 1.2) |
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
- **버전은 배포 번호를 쓴다.** 원고(버전 칸, 실행 스크립트 파일, 사용 예제)에는 배포 폴더의 스크립트 이름과 번호를 쓴다(예: 작업 파일 `differential_accessibility.1.4.R` → 배포 `differential_accessibility.1.3.R` → 버전 1.3). 작업 번호는 원고에 쓰지 않는다. "1.3부터", "1.2 이하" 같은 버전 비교도 작업 번호로 쓰지 않고, 필요하면 "CLOSHA 2.0의 <모듈> 1.0"처럼 배포된 번호로 쓴다.
- **입출력 설명은 다른 모듈을 가리키지 않는다.** 모듈은 따로 쓸 수 있으므로 "ATAC_QC의 output_dir", "앞 모듈의 output_dir", "다음 모듈의 input_dir" 대신 그 폴더에 무엇이 어떤 구조로 있어야 하는지 쓴다. 예: "차등 접근성 결과 폴더. 안에 `03_results/diff_accessibility_<norm>.csv`(열: seqnames, start, end, peakID, logFC, FDR)가 있어야 함", "Tn5 보정 BAM 폴더. 폴더 안에 `03_shifted_bam/`이 있으면 그 안에서 찾음". Output은 만들어지는 파일을 쓴다.
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
- **데이터에 따라 결과가 적게 나오는 경우도 쓴다.** 예: 조건 간 차이가 작으면 차등 영역 기반 분석(모티프, footprinting, GO)의 결과가 적거나 "검정할 항목 없음"으로 끝나며, 오류가 아니라 데이터의 결과라는 점.

파이프라인 등록 화면 항목:

| 항목 | 쓰는 법 | ATAC-seq 예 |
|---|---|---|
| Pipeline Name | 영문, 밑줄 | `ATAC_seq_Pipeline` |
| Version | 이전 플랫폼 버전 + 1. 입력 형식이 바뀌면(예: BAM 시작 → FASTQ 시작) 주버전을 올린다 | 1.3 (CLOSHA 2.0의 1.2 다음) |
| Reference | 파이프라인을 구성할 때 실제로 참고한 자료 하나(DOI 또는 URL) | `https://nbis-workshop-epigenomics.readthedocs.io/en/latest/content/tutorials/atacseq_tutorials.html` |
| Keyword(태그) | 사용자가 검색할 분석 주제. 도구 이름과 종 이름은 넣지 않는다(도구 이름은 모듈 태그에 있음) | ATAC-seq, chromatin accessibility, open chromatin, epigenomics, peak calling, differential accessibility, motif analysis, TF footprinting |
| 대분류 / 중분류 | 포탈 목록에서 가장 가까운 것 | Epigenomics / DNA-binding-protein-based-analysis |
| 대표 이미지 | 실제 분석 결과 중 그 분석을 대표하는 그림(RNA-seq의 volcano plot 같은 것). 노선도나 개념도가 아니다. 데이터에서 실제로 잘 나온 그림을 고른다 | 후보: G-box 서열 로고(atac_motif), TSS heatmap(ATAC_QC_plot), BINDetect volcano(tf_footprinting), fragment 크기 분포(ATAC_QC) |

## 5. 모듈 페이지

### 5.1 항목
| 항목 | 쓰는 법 |
|---|---|
| 기본 정보 | 모듈명, 서브 타이틀(국문·영문), 버전, 카테고리(5.2), 태그, 레퍼런스 URL(도구 홈페이지), 컨테이너 이미지(DEF 이름), 실행 스크립트 파일, Processor Core(제안) |

- **서브 타이틀은 10~20자로 쓴다**(포탈 규칙, 모듈과 파이프라인 모두, 20자를 넘기지 않는다). 무엇을 하는 모듈인지 명사형으로 짧게 쓴다. 예: `참조 유전체 정렬`, `머무름 시간 예측`.
| 실행 이미지 | 이미지 이름과 버전, DEF 정보 표(DEF 파일, DEF Bootstrap, DEF From, conda 설치 도구), 분석도구 표(도구·버전·홈페이지), 태그, 내용(국문·영문)(5.5) |
| 내용(국문/영문) | 첫 문단에 무엇을 왜 하는지, 이어서 bullet 3~4개(방법, 만드는 결과, 파이프라인에서의 위치) |
| 입출력 / 파라미터 | 표: 탭(Input/Output/Option), 필수, 형식, Name(인자 이름), Value(기본값), Description(국문), English Description. 설명은 3절 규칙대로 다른 모듈을 가리키지 않는다 |
| 샘플시트 | 샘플 정보 파일을 받는 모듈만. 열 이름, 필수 여부, 예시 |
| 주요 사항 | 국문·영문 두 열 표. 사용자가 실수하기 쉬운 입력 조건 위주 |
| 분석 개념 이미지 | 그림 + 레전드(국문·영문) + 출처(5.3) |
| 스크립트 사용 예제 | `key=value` 형식. 포탈에 등록하는 인자와 기본값이 있는 옵션을 모두 적고 한 줄에 인자 하나. **값과 순서는 파라미터 표의 Value와 같게** 쓴다(예시 경로도 같은 것을 쓴다). 표를 고치면 예제도 고친다 |
| 주요 결과 이미지 | 결과 그림(PNG) + 결과 파일 + 레전드(국문·영문)(5.4) |

등록 화면의 공통 값:
- **기반 이미지 출처(Bootstrap):** `Apptainer`(작업이 SIF로 실행되므로). DEF 파일 안의 `Bootstrap: docker`와 다르니 섞지 않는다.
- **기반 이미지(From):** 운영체제 이름과 버전(예: Rocky Linux 9.8). digest는 쓰지 않는다(5.5)
- **형식(Type):** 포탈 목록에서 고른다. 원고에는 Directory, File, String, Integer, Float, List로 적는다.
- **필수 입력·출력의 Value:** 비어 있으면 등록이 안 되므로 예시 경로(`/data/<모듈>`, `/ref/genome.fa` 등)를 넣는다. 스크립트 사용 예제와 같은 경로를 쓴다. 기본값이 아니라 캔버스에서 실제 경로로 바꿀 자리이며, 그대로 넘어가면 스크립트가 "not found"로 멈춘다.
- **선택 입력의 Value:** 스크립트는 빈 값을 "사용 안 함"으로 읽는다. 경로를 넣으면 그 경로를 실제로 쓰려 하므로 비워 둔다.

### 5.2 카테고리와 아이콘
모듈 카테고리는 **CLOSHA 프로그램 목록(대분류 / 중분류)**에서 고른다. 분석 단계(기능) 기준이므로 다른 파이프라인의 모듈도 같은 목록에 넣을 수 있다. 목록은 `docs/ATAC-seq/CLOSHA_program_categories.xlsx`에 있다.

| 대분류 | 중분류 | ATAC-seq 모듈 |
|---|---|---|
| Annotation | Gene_Prediction, Genome_Annotation | — |
| | **Peak_Annotation** (신규) | peak_annotation |
| Assembly | Hybrid_Assembly, Short_Read_Assembly | — |
| Mapping | Short_Read_Alignment | bowtie2, GATK_MarkDuplicates, organellar_filter |
| | Transcript_Alignment | — |
| Omics | Amplicon_sequencing_analysis, Expression_Quantification, Genome_Classification, Genome_binning | — |
| | **Differential_Analysis** (신규) | differential_accessibility |
| | Functional_Analysis | functional_enrichment |
| | **Gene_Regulation** (신규) | atac_motif, tf_footprinting |
| | **Peak_Calling** (신규) | MACS3_callpeak_ATAC, replicate_consistency |
| Quality_Control | **Alignment_QC** (신규) | ATAC_QC, ATAC_QC_plot |
| | Assembly_QC, Raw_Data_QC | — |
| Statistics_and_Visualization | Genomic_Visualization, Mathematical_based_Tool | — |
| Utility | Genomic_data_Utility | — |

- 기존 목록에 맞는 것이 있으면 쓰고, 억지로 끼워 넣지 않는다. 맞는 중분류가 없으면 중분류를, 맞는 대분류가 없으면 대분류도 새로 만든다(사용자 결정, 2026-10-27). 이름은 특정 분석(예: ATAC)이 아니라 일반 이름으로 짓는다(예: Differential_Analysis는 RNA-seq 차등 발현도 담을 수 있다).
- 새로 정하는 분류는 **대분류 = 데이터 분야(Transcriptomics, Epigenomics 등), 중분류 = 작업(Normalization, Clustering, Differential_Expression 등)**으로 짓는다(사용자 결정, 2026-10-27). Galaxy 도구 메뉴(분야 메뉴 + 범용 메뉴)와 bio.tools/EDAM(Topic + Operation)을 참고했고, 사용자가 자기 데이터 분야부터 찾는 순서에 맞춘 것이다. 어느 데이터에나 쓰는 범용 단계(정렬, QC, 형식 변환)는 기존 기능 대분류(Mapping, Quality_Control, Utility)에 둔다.
- 현재 포탈 목록(Omics_Data_Analysis 등)은 업체가 임시로 정한 것이라 바뀔 예정이다. Omics_Data_Analysis는 Transcriptomics, Epigenomics, Metagenomics처럼 분야별로 나누길 제안한다.
- 예: 공간 전사체 모듈 12개는 모두 `Transcriptomics`(신규) 아래 Normalization, Clustering, Spatial_Statistics, Differential_Expression, Cell_Type_Annotation에 둔다. 단일세포·bulk RNA-seq 모듈도 같은 중분류에 넣고 모듈 이름으로 구분한다.
- 목록에 보여도 개인 폴더(공개 아이콘이 아닌 사람 아이콘, 예: `BAM_processing`)는 정식 카테고리가 아니므로 쓰지 않는다. 그래서 GATK_MarkDuplicates, organellar_filter는 Mapping / Short_Read_Alignment에 둔다.
- 기존 이름의 오타는 카테고리를 추가할 때 함께 고친다: `Statisitcs_and_Visualization` → `Statistics_and_Visualization`, `Methmatical_based_Tool` → `Mathematical_based_Tool`.
- 파이프라인 등록 화면의 대분류·중분류는 별도 목록이다(4절 표).
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
**실제 결과 그림을 직접 보고** 고르고 설명한다. 스크립트 코드만 보고 "이렇게 그려질 것"으로 쓰면 실제 그림과 어긋난다(쪽 순서, 선 모양, 색 범위, 축 이름, 파일 이름 등). ATAC-seq 원고에서도 그림을 본 뒤 여러 곳을 고쳤다.

**고르는 법**
- 모듈이 만드는 그림 중 사용자가 결과를 판단하는 데 쓰는 것을 여러 개 고른다. 그림 하나로 끝내지 않는다. 그림 종류가 많으면 종류마다 하나씩 넣는다(예: peak_annotation 8종).
- 순서: 결과 1이 대표 그림, 그다음 품질 확인·보조 그림, 마지막에 요약표.
- 샘플·조건·목록마다 나오는 그림은 **대표 하나**만 쓰고, 모듈 사이에서 같은 대표 샘플로 맞춘다(ATAC-seq: SRR24197771). 절 첫 줄에 어느 샘플인지 적는다.
- 옵션을 켤 때만 나오는 그림은 결과 파일 줄에 조건을 적는다(예: `run_kmer=TRUE일 때`).
- 그림을 만들지 않는 모듈은 요약표를 표 그림으로 만든다(아래). 요약표에 숫자가 없으면(예: 경로만 있음) 같은 결과 폴더의 통계 파일로 표를 만들고, 결과 파일 줄에 어느 파일에서 만들었는지 적는다(예: organellar_filter의 flagstat·idxstats).

**PNG 만들기** (포탈은 PNG/JPEG만 받는다)
- 결과 원본은 Codespace의 `_incoming/`(git이 무시하는 폴더)에 받는다. GitHub 웹 업로드는 파일당 25MB까지라 쓰지 않는다. 디스크 여유가 작으면 모듈별로 올리고, 처리가 끝나면 그 모듈 파일을 지운다. BAM, bigWig, RDS 같은 큰 파일은 받지 않는다.
- PDF는 200 dpi PNG로 바꾼다: `pdftocairo -png -r 200 -singlefile <그림>.pdf <모듈>_result_<N>`.
  - 여러 쪽 PDF는 쪽마다 내용을 확인하고 `-f <쪽> -l <쪽>`으로 고른다. 결과 파일 줄에 쪽 번호를 적는다(예: BINDetect PDF는 2쪽 정규화 전, 3쪽 정규화 후, 4쪽 volcano + 긴 목록).
  - 아주 긴 쪽은 필요한 부분만 잘라 쓴다(`-x -y -W -H`).
- 표(TSV)는 `docs/tools/tsv_to_png.py`로 포탈 스타일 표 그림을 만든다. 열 고르기·이름 바꾸기(`--cols`), 기준값 색 점(`--flag 열:주의,좋음`), 제목과 아래 설명 줄(`--title`, `--note`)을 쓴다. 기준값 색을 쓰면 아래 설명 줄에 기준과 출처를 적는다.
- 결과 그림이 이미 PNG면 그대로 쓴다.

**저장과 원고 연결**
- 배포 폴더에 둔다: `release/<플랫폼>/<파이프라인>/<배포일>/results/<모듈>/portal/<모듈>_result_<N>.png`(원본 PDF·TSV·로그는 `results/<모듈>/` 아래), 같은 PNG를 `portal_images/<모듈>/`에 모으고 `portal_images.zip`을 다시 만든다.
- 원고의 결과마다 `그림: `<PNG 경로>`` 줄을 넣는다. Word를 만들면 그림이 들어간다(6절).

**레전드**
- 그림마다 `**결과 N. 제목**`, `- 결과 파일:`, `그림:`, 레전드(국문·영문)를 쓴다. 결과 파일은 `output_dir` 기준의 실제 파일 이름이다.
- 레전드에는 네 가지를 쓴다.
  - 그림 읽는 법: 축 이름(그림에 적힌 그대로), 점·선·색의 뜻(실선/점선, 색 범위 포함), 패널 구성
  - 정상 결과가 어떻게 보이는지
  - 기준값이 있으면 그 값과 출처. 예: FRiP는 ENCODE 기준 0.3 이상이 바람직하고 0.2 이상이면 허용한다.
  - **"예시 데이터에서는 …"**: 이 데이터의 실제 값과 관찰(예: "FRiP가 0.65~0.74로 모두 기준을 넘었습니다"). 데이터 사정으로 그림이 비어 보이거나 일반적인 모양과 다르면 그 이유를 쓴다(예: 유전자가 촘촘한 유전체라 Promoter 비율이 90% 이상, 반복 서열 때문에 뾰족한 봉우리).
- 해석은 결과가 보여 주는 만큼만 쓴다. 예: 모티프가 "변화 없는 구간"에서 농축됐으면 조건 변화와 연결하지 않는다. 방향이 있는 그림(MD plot, volcano)은 기준 조건이 무엇인지(예: `control_name`, 알파벳 순서)를 쓴다.
- 모티프·전사인자 ID만 있는 결과는 JASPAR에서 이름을 확인해 함께 쓴다(예: MA0568.2 = MYC3). 기억으로 쓰지 않는다.

### 5.5 실행 이미지
모듈이 도는 Apptainer 이미지 정보를 모듈마다 적는다. 매뉴얼 웹페이지의 이미지 설명도 이 절을 쓴다.

- **값은 DEF 파일에서 옮긴다.** 기억이나 다른 문서에서 쓰지 않는다.

  | 원고 항목 | DEF에서 가져오는 곳 |
  |---|---|
  | 이미지 이름, 버전 | 파일 이름 `<이미지>.<버전>.def`, `%labels`의 `Component`, `Version` |
  | DEF Bootstrap, DEF From | 파일 첫 줄의 `Bootstrap:`, `From:`. 원고(포탈)에는 From을 운영체제 이름과 버전으로 쓰고 이미지 태그를 괄호로 덧붙인다(예: Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`)). digest(sha256)는 쓰지 않으며, DEF 파일과 Container_Manual에만 둔다 |
  | conda 설치 도구 | `%labels`의 `CondaInstaller` |
  | 설치 도구와 버전 | `%post`의 `conda create`·`conda install` 목록에서 버전을 지정한 패키지 |
  | 이미지 설명 | `%labels`의 `Description`을 국문·영문으로 풀어 씀 |

- **표 형식**

  | 항목 / Item | 값 / Value |
  |---|---|
  | DEF 파일 | `defs/<파이프라인>/<이미지>.<버전>.def` |
  | DEF Bootstrap | `docker` |
  | DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
  | conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

  그 아래 컨테이너 등록 항목을 둔다(아래).
- **컨테이너 등록 항목** (포탈 컨테이너 등록 화면 순서: 버전 → 분석도구 → 태그 → 내용)
  - 분석도구 표 `| 분석도구 | 버전 | 홈페이지 |`: DEF에서 버전을 지정한 도구를 모두 적고(HTSlib, Python처럼 함께 설치된 기반 도구 포함) 공식 홈페이지를 붙인다. Bioconductor는 `https://bioconductor.org/packages/<이름>/`, CRAN은 `https://cran.r-project.org/package=<이름>`. SAMtools와 HTSlib처럼 홈페이지가 같은 도구도 있다.
  - 태그(키워드): 국문 3~4개(예: 피크검출, 열린염색질, MACS3, FRiP).
  - 내용(국문·영문): 2~3문장. 무엇을 하는 환경인지, 주요 도구, 자원상 주의할 점(메모리 등).
  - 같은 내용을 `Container_Manual.md`의 이미지별 "포탈 등록" 블록과 모듈 원고 "실행 이미지" 절 양쪽에 둔다.
- **같은 이미지를 쓰는 모듈에도 각각 다 적는다**(3절 규칙). "ATAC_QC와 같은 이미지" 같은 문장을 쓰지 않는다.
- **Bootstrap을 구분한다.** 포탈 등록 화면의 Bootstrap 칸(`Apptainer`)과 DEF 파일의 `Bootstrap: docker`는 다른 값이다. 원고 표에는 "DEF Bootstrap", "DEF From"으로 적는다.
- **DEF가 저장소에 없으면** 표를 비워 두지 말고 `등록 메모:`로 보류 사유를 적는다.
- **DEF를 고치면** 이 절도 같이 고친다. 분석 스크립트만 바뀐 경우에는 이미지가 같으므로 고치지 않는다.
- 다른 팀과 같이 쓰는 이미지(예: WGS 파이프라인의 bowtie2, gatk)는 받은 DEF 값을 그대로 쓴다(Rocky Linux 9, Miniforge3 26.5.3-0 등). 공통 안내에 다른 점을 적는다.
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
- 원고에 `그림: `` `docs/…png` `` 또는 `` `release/…png` `` 형식으로 적은 그림은 Word에 그림으로 들어간다.
- Word를 GitHub에서 바로 받으면 몇 분 동안 예전 파일이 내려올 수 있다. 확인할 때는 Codespace 탐색기에서 Download로 받는다.
- md를 고치면 Word도 다시 만들어 함께 커밋한다.

## 7. 확인 목록

- [ ] 버전, 기본값, 출력 파일 이름이 스크립트와 같고, 버전과 스크립트 이름은 배포 번호다.
- [ ] 입출력 설명에 다른 모듈 이름("~의 output_dir")이 없다.
- [ ] 스크립트 사용 예제의 값과 순서가 파라미터 표와 같다.
- [ ] 모든 항목에 국문과 영문이 있다.
- [ ] 입출력 표가 `Registration.md`와 같다.
- [ ] 카테고리가 5.2의 CLOSHA 프로그램 목록에 있다.
- [ ] 개념도와 결과 그림마다 레전드(국문·영문)가 있다.
- [ ] 논문 그림은 CC BY만 썼고, 출처 줄에 전체 서지, DOI, 라이선스 링크가 있다.
- [ ] 주요 사항에 모듈 설치 안내가 들어가지 않았다.
- [ ] 결과 그림을 실제 결과로 직접 보고 골랐고, 모듈마다 여러 개(대표, 보조, 요약표) 있으며, 레전드마다 "예시 데이터에서는" 문장이 있다.
- [ ] 결과 PNG가 배포 폴더 `results/<모듈>/portal/`과 `portal_images/`에 있고 원고에 `그림:` 줄로 연결되어 있다.
- [ ] 실행 이미지 절에 분석도구(버전·홈페이지), 태그, 내용(국문·영문)이 있고 From에 digest가 없다.
- [ ] 모듈마다 실행 이미지 절이 있고, 값이 DEF 파일과 같다.
- [ ] Word 파일을 md에서 다시 만들어 함께 커밋했다.
