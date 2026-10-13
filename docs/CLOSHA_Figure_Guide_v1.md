# CLOSHA 파이프라인 그림 작성 규칙 v1

KOBIC 포탈의 파이프라인·모듈 페이지에 넣는 그림을 만드는 규칙이다. 파이프라인 노선도(모식도), 파이프라인 분석 개념도, 모듈 개념도 세 가지를 다룬다. 기준 예시는 `docs/workflow_ex/`의 BIO-EXPRESS 그림들(MAG, scRNA-seq, Exp~CNV+Meth 멀티오믹스, Allele-Specific Expression)이고, 실제 적용 예는 ATAC-seq(`docs/ATAC-seq/`)이다.

작성일: 2026-10-13

## 1. 그림 종류와 위치

| 그림 | 포탈 위치 | 파일 위치 (ATAC-seq 예) | 생성 스크립트 |
|---|---|---|---|
| 파이프라인 노선도 | 파이프라인 페이지 "분석 흐름" | `docs/<파이프라인>/pipeline/figures/pipeline.png` | `pipeline/figures/make_pipeline_map.py` |
| 파이프라인 분석 개념도 | 파이프라인 페이지 "분석 개념" | `docs/<파이프라인>/pipeline/figures/concept.png` | `pipeline/figures/make_concept.py` |
| 모듈 개념도 | 모듈 페이지 "분석 개념 이미지" | `docs/<파이프라인>/modules/figures/module_concepts/<모듈>_concept.png` | `modules/figures/module_concepts/make_module_concepts.py` |

- 그림은 손으로 편집하지 않고 생성 스크립트로 SVG를 만든 뒤 PNG로 변환한다. 고칠 때는 스크립트를 고친다.
- SVG(원본)와 PNG(포탈 등록용)를 함께 커밋한다.
- 레전드와 출처는 그림 안이 아니라 원고 md(`pipeline/Portal_Content.md`, `modules/Portal_Content.md`)에 적는다.

## 2. 파이프라인 노선도 규칙

예시 그림 4장에서 공통으로 쓰는 규칙이다.

### 2.1 구성 요소
| 요소 | 모양 | 값 |
|---|---|---|
| 노드(모듈) | 어두운 알약 모양, 왼쪽에 터미널 아이콘(`>_`) | 색 `#3D3D3D`, 이름은 CLOSHA 모듈 이름 |
| 노선 | 굵은 선, 단계별 색 | 두께 15, 모서리 둥글게 |
| 진행 방향 | 선 위의 흰색 겹화살표(▶▶) | 노드·역 사이 빈칸마다 하나 이상 |
| 입력(중간 데이터) 역 | 흰 원 + 검은 테두리, 점선으로 위 라벨과 연결 | 라벨: 회색 상자 `#EEEEEE` |
| 출력 역 | 흰 원 + 주황 테두리, 점선으로 라벨과 연결 | 라벨: 주황 상자 `#F07800`, 흰 글씨 |
| 참조 입력 | 노드 위에 "라벨 +" 와 아이콘 (역 없음) | 예: `REF.FASTA +` |
| 범례 | 단계 색 3~5개 + Input/Output format | |
| 제목 | BIO-EXPRESS 로고 + 파이프라인 이름 | |

단계 색(ATAC-seq 기준): Preprocessing `#A8509C`, QC & 보정 `#1269FF`, 분석 `#7CC744`, 시각화 `#FFB400`, 출력 `#F07800`. 단계 이름은 파이프라인에 맞게 바꾼다.

### 2.2 라벨
- 중간 데이터 라벨은 **파일 형식만** 쓴다: `FASTQ.GZ`, `BAM`, `narrowPeak`, `TSV`, `CSV`.
- 출력 라벨도 **실제 형식**을 쓴다: `TSV`, `PDF`, `PNG`, `BigWig`, `narrowPeak`. "Figure"처럼 뭉뚱그리지 않고, 스크립트가 실제로 쓰는 형식을 확인해 적는다.
- 출력이 여러 개면 라벨을 나란히 두고 점선 하나로 묶어 출력 역에 연결한다.
- 참조 입력은 형식까지 적는다: `REF.FASTA`, `GFF3/GTF`, `TSS (.bed)`, `Motif DB (.meme)`, `OrgDb (.sqlite)`.
- 샘플 정보 파일(sample_data, metadata)과 숫자 옵션(genome_size 등)은 그리지 않는다(예시들과 같음).

### 2.3 아이콘
예시 그림에서 잘라 낸 아이콘을 그대로 쓴다: `docs/ATAC-seq/pipeline/figures/icons/`. 아이콘은 **파일 형식보다 데이터의 역할**로 고르고, 정확한 형식은 라벨에 적는다.

| 아이콘 | 파일 | 쓰는 데이터 | 출처 |
|---|---|---|---|
| 줄무늬(read) | `fastq.png` | FASTQ | MAG |
| DNA 나선 | `fasta.png` | 참조 서열·주석(FASTA, GFF3/GTF) | MAG |
| 정렬 | `bam.png` | BAM, SAM | MAG |
| 문서 | `doc.png` | 표·peak·BED·결과 파일(TSV, CSV, PDF, PNG, BigWig 등) | MAG |
| 변이 | `vcf.png` | VCF | Allele-Specific Expression |
| 폴더 | `folder.png` | 폴더 단위 결과(count matrix 등) | scRNA-seq |
| 데이터베이스 | `table.png` | 참조 DB(OrgDb, Motif DB), 데이터 객체(h5ad 등) | scRNA-seq |

새 아이콘이 필요하면 `docs/workflow_ex/`의 예시에서 잘라 같은 폴더에 추가한다(라벨이 섞이지 않게 아이콘만 잘라 낼 것).

### 2.4 연결과 배치
- 한 노드에 입력이 두 개면(예: BAM + peak) 두 선이 **각각 노드로 들어가게** 그린다. 한 선이 다른 선 중간에 합쳐지게 그리지 않는다(어디로 가는지 안 보이고, 화살표 방향 때문에 잘못 읽힌다).
- 선이 다른 선을 지나가야 하면, 지나가는 자리에서 아래 선을 살짝 끊어 "교차"로 보이게 한다.
- 같은 모듈을 두 번 쓰면(예: functional_enrichment를 peak_annotation 뒤와 DA 뒤에) 노드를 두 개 그린다.
- 역은 두 노드의 정가운데에 두고, 노드 사이를 충분히 띄워 역 양쪽에 화살표가 들어가게 한다.
- 노선도는 CLOSHA 캔버스의 실제 연결(어느 `output_dir`이 어느 인자로 들어가는지)과 같아야 한다. 그리기 전에 모듈 등록 문서(`modules/Registration.md`)로 연결을 확인한다.

## 3. 개념도 규칙 (파이프라인·모듈 공통)

### 3.1 그림 고르는 순서
1. 모듈의 원리를 잘 보여 주는 **공개 논문 그림**이 있으면 그것을 쓴다.
2. 라이선스가 **CC BY**인 경우만 쓴다. Europe PMC API로 확인한다:
   `https://www.ebi.ac.uk/europepmc/webservices/rest/search?query=DOI:"<DOI>"&resultType=core&format=json` 의 `license` 필드.
   - CC BY: 사용·수정 가능, 출처와 "수정함" 표기
   - CC BY-NC-ND(수정 금지), 표기 없음(일반 저작권): 쓰지 않는다
3. 쓸 수 있는 그림이 없거나, 그림이 우리 모듈 방식과 다르면(예: ChIP-seq용 그림) **직접 그린다**.
4. 논문 그림도 그대로 붙이지 않고 포탈 스타일로 **다시 그린다**(해상도, 폰트, 색 통일).

### 3.2 스타일
- 폰트: Pretendard(본문), GmarketSans(제목이 있을 때)
- 색: 주 `#222222`, 보조 `#3A3A3A`, 포인트 `#32549C`, 배경 `#FFFFFF`. 의미가 있는 색(예: footprint, Tn5 절단 끝)은 그림 안에서 일관되게 쓴다.
- 여러 단계를 보여 줄 때는 A/B/C 패널로 나누고 각 패널에 짧은 제목을 단다.
- 데이터처럼 보이는 값은 모식적인 값임을 레전드에서 밝힌다.

### 3.3 레전드
- 논문 figure legend 형식: 굵은 제목 한 문장 + "(A) … (B) …" 순서로 설명.
- 국문과 영문을 모두 쓴다. 대체 텍스트(alt)도 국문·영문 한 줄씩.
- 논문 그림을 수정했으면 레전드 끝에 출처를 적는다. 예:
  `Bentsen M. et al., Nat Commun 11, 4267 (2020), Fig. 1을 수정(CC BY 4.0).`

## 4. 만들기와 변환

필요한 폰트: Montserrat(노선도), Pretendard, GmarketSans(개념도). 변환 도구: `rsvg-convert`(librsvg).

```
# 노선도
python3 docs/ATAC-seq/pipeline/figures/make_pipeline_map.py
rsvg-convert -w 2700 docs/ATAC-seq/pipeline/figures/pipeline.svg -o docs/ATAC-seq/pipeline/figures/pipeline.png

# 파이프라인 개념도
python3 docs/ATAC-seq/pipeline/figures/make_concept.py
rsvg-convert -w 1800 docs/ATAC-seq/pipeline/figures/concept.svg -o docs/ATAC-seq/pipeline/figures/concept.png

# 모듈 개념도
python3 docs/ATAC-seq/modules/figures/module_concepts/make_module_concepts.py
for f in docs/ATAC-seq/modules/figures/module_concepts/*.svg; do rsvg-convert -w 1600 "$f" -o "${f%.svg}.png"; done

# 포탈 붙여넣기용 Word (그림과 레전드 포함)
node docs/tools/make_portal_docx.js docs/ATAC-seq/pipeline/Portal_Content.md docs/ATAC-seq/pipeline/Portal_Content.docx
node docs/tools/make_portal_docx.js docs/ATAC-seq/modules/Portal_Content.md docs/ATAC-seq/modules/Portal_Content.docx
```

## 5. 확인 목록

- [ ] 노선도의 연결이 CLOSHA 캔버스·모듈 등록 문서와 같다.
- [ ] 모든 노드 사이 빈칸에 진행 방향 화살표가 있다.
- [ ] 입력·출력 라벨이 실제 파일 형식이고, 출력 형식은 스크립트로 확인했다.
- [ ] 아이콘은 `icons/`의 예시 아이콘을 쓰고, 역할 기준 표(2.3)를 따른다.
- [ ] 선이 다른 선 중간에 합쳐지지 않고, 교차는 끊어서 표시했다.
- [ ] 라벨·아이콘·노드가 겹치지 않고, 그림 가장자리에 붙지 않는다.
- [ ] 논문 그림은 CC BY만 썼고, 레전드에 출처와 "수정함"을 적었다.
- [ ] 레전드(국문·영문)와 대체 텍스트를 원고 md에 넣었다.
- [ ] SVG와 PNG를 함께 커밋했다.
