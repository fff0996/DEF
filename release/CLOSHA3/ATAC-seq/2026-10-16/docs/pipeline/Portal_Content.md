# ATAC-seq 파이프라인 포탈 등록 콘텐츠

KOBIC 포탈의 ATAC-seq Analysis Pipeline 상세 페이지(https://kobic.re.kr/kobic/analysis/pipeline/go_detail?id=73)에 들어갈 국문/영문 원고다. 섹션 순서는 포탈 페이지 구성을 따른다. 모듈별 입력·옵션·결과는 `docs/ATAC-seq/modules/Registration.md`, 그림은 `docs/ATAC-seq/pipeline/figures/`에 있다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따른다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

---

## 1. 파이프라인 소개 / Introduction

### 국문
ATAC-seq 파이프라인은 Tn5 transposase가 접근하기 쉬운 염색질에서 얻은 시퀀싱 데이터를 분석하여, 유전체 전반의 염색질 접근성과 조건에 따른 변화를 확인하는 분석 도구입니다. Paired-end FASTQ, 참조 유전체와 주석 자료, 샘플 정보를 입력하여 품질 관리, 유전체 정렬, 소기관 read 제거, ATAC-seq 품질 평가와 Tn5 삽입 위치 보정, peak 검출을 수행합니다. 검출한 peak에는 유전체 기능 영역과 연관 유전자 정보를 부여합니다. 두 조건의 peak별 read count를 edgeR로 비교하고, 접근성 변화와 연관된 DNA motif를 monaLisa로 분석합니다. TOBIAS 기반 footprinting은 Tn5 절단 신호와 motif 정보를 함께 이용하여 전사인자 결합 후보의 조건별 변화를 탐색합니다.

### English
The ATAC-seq pipeline analyzes sequencing data from chromatin that is accessible to the Tn5 transposase, to identify genome-wide chromatin accessibility and how it changes between conditions. From paired-end FASTQ files, a reference genome with annotation, and sample information, it performs quality control, genome alignment, removal of organellar reads, ATAC-seq quality assessment with correction of Tn5 insertion positions, and peak calling. Detected peaks are annotated with genomic features and associated genes. Read counts per peak are compared between two conditions with edgeR, and DNA motifs associated with accessibility changes are analyzed with monaLisa. TOBIAS-based footprinting combines Tn5 cleavage signals with motif information to explore condition-dependent changes in candidate transcription factor binding.

---

## 2. 분석 목표 / Analysis goals

### 국문
**ATAC-seq 분석으로 확인할 수 있는 네 가지 분석 목표**

**01 어떤 유전체 영역의 염색질이 열려 있는가**
정렬된 ATAC-seq 신호로부터 접근성이 높은 영역을 peak로 검출하여 열린 염색질의 유전체 위치를 확인합니다.

**02 조건 간 접근성이 달라진 영역은 무엇인가**
대조군과 실험군의 공통 peak 영역에서 read count를 비교하여 접근성이 증가하거나 감소한 영역을 확인합니다. 두 조건 모두 생물학적 반복이 2개 이상이면 통계적 유의성을 평가합니다.

**03 접근성 영역은 어떤 유전자와 기능 영역에 위치하는가**
Peak를 promoter, exon, intron, intergenic 등의 영역으로 분류하고, 연관 유전자 ID와 TSS까지의 거리를 확인하여 후속 해석에 활용합니다.

**04 접근성 변화와 연관된 전사인자 후보는 무엇인가**
접근성 변화량에 따른 motif enrichment와 footprinting 결과를 함께 검토하여 조절에 관여할 수 있는 전사인자 후보를 탐색합니다.

### English
**Four questions ATAC-seq analysis can answer**

**01 Which genomic regions have open chromatin?**
Highly accessible regions are called as peaks from the aligned ATAC-seq signal to locate open chromatin across the genome.

**02 Which regions change in accessibility between conditions?**
Read counts in consensus peak regions are compared between control and treatment to find regions with increased or decreased accessibility. Statistical significance is assessed when both conditions have two or more biological replicates.

**03 Which genes and genomic features are the accessible regions associated with?**
Peaks are classified into promoter, exon, intron, intergenic, and other features, and the associated gene IDs and distances to the TSS are reported for downstream interpretation.

**04 Which transcription factors may drive the accessibility changes?**
Motif enrichment along accessibility changes and footprinting results are reviewed together to identify candidate transcription factors involved in regulation.

---

## 3. 분석 흐름 / Analysis workflow

그림: `docs/ATAC-seq/pipeline/figures/pipeline.png` (원본 `pipeline.svg`)

### 대체 텍스트 (alt)
- 국문: ATAC-seq 파이프라인 흐름도. FASTQ 전처리(fastp, bowtie2, GATK MarkDuplicates, organellar_filter) 후 ATAC_QC, MACS3 peak 검출을 거쳐 peak 주석, 차등 접근성, motif, footprinting, 반복 재현성, GO 기능 분석으로 이어짐.
- English: ATAC-seq pipeline workflow. After FASTQ preprocessing (fastp, bowtie2, GATK MarkDuplicates, organellar_filter), ATAC_QC and MACS3 peak calling lead to peak annotation, differential accessibility, motif analysis, footprinting, replicate consistency, and GO enrichment.

---

## 4. 분석 개념 / Analysis concept

그림: `docs/ATAC-seq/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 설명)
**그림. ATAC-seq의 원리와 분석 신호.** (위) 뉴클레오솜(회색 원) 사이의 열린 염색질에서 Tn5 전이효소가 DNA를 자르고 시퀀싱 어댑터를 삽입한다. 꺾인 화살표는 유전자(파란 상자)의 전사 시작점(TSS)이며, 그 상류의 열린 영역에 전사인자(육각형)가 결합해 있다. (NFR fragments density) 뉴클레오솜이 없는 영역(NFR)에서 생성된 fragment의 위치별 밀도로, 점선 사이가 열린 영역이다. (NFR fragments, Mononucleosome fragments) Tn5의 두 절단 지점(주황·초록 끝) 사이 DNA가 하나의 fragment가 된다. 열린 영역 안에서는 짧은 NFR fragment가, 뉴클레오솜 하나를 사이에 두면 약 180–250 bp의 mononucleosome fragment가 생성되며, 본 파이프라인은 fragment 길이로 이를 구분한다. (Peaks) fragment가 집중된 열린 영역을 peak(검은 막대)로 검출한다. 전사인자가 결합한 자리는 Tn5가 절단하지 못해 신호가 국소적으로 감소하며(주황 점선 사이), 이 footprint(파란 구간)로 전사인자 결합 위치를 추정한다. 실제 peak 검출에는 Tn5 보정을 거친 전체 paired-end fragment를 사용한다. Yan F. *et al.*, *Genome Biol* 21, 22 (2020), Fig. 1A를 수정(CC BY 4.0).

### English (figure legend)
**Figure. Principle of ATAC-seq and the signals analyzed.** (Top) Tn5 transposase cuts DNA in open chromatin between nucleosomes (gray circles) and inserts sequencing adapters. The bent arrow marks the transcription start site (TSS) of a gene (blue box), and a transcription factor (hexagon) is bound in the open region upstream of it. (NFR fragments density) Positional density of fragments from nucleosome-free regions (NFRs); open regions lie between the dashed lines. (NFR fragments, Mononucleosome fragments) The DNA between two Tn5 cut sites (orange and green ends) forms one fragment. Short NFR fragments arise within open regions, and mononucleosome fragments of about 180–250 bp span one nucleosome; the pipeline separates them by fragment length. (Peaks) Open regions enriched in fragments are called as peaks (black bars). At transcription factor binding sites Tn5 cannot cut, so the signal dips locally (between the orange dashed lines); this footprint (blue segment) is used to infer binding sites. Peaks are called from all Tn5-corrected paired-end fragments in the pipeline. Adapted from Yan F. *et al.*, *Genome Biol* 21, 22 (2020), Fig. 1A (CC BY 4.0).

### 대체 텍스트 (alt)
- 국문: ATAC-seq 원리 모식도. Tn5가 뉴클레오솜 사이 열린 염색질을 잘라 생긴 NFR·mononucleosome fragment, 이로부터 검출한 peak, 전사인자 결합 자리의 footprint를 보여 줌.
- English: Schematic of ATAC-seq: Tn5 cuts open chromatin between nucleosomes, producing NFR and mononucleosome fragments, from which peaks and transcription factor footprints are identified.

### 출처 / Reference
Yan F, Powell DR, Curtis DJ, Wong NC. From reads to insight: a hitchhiker's guide to ATAC-seq data analysis. *Genome Biol* 21, 22 (2020). https://doi.org/10.1186/s13059-020-1929-3, Fig. 1A를 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

---

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

포탈의 현재 "주요 사항"은 모듈(fastqc)의 설치 안내를 가져온 것이다. 아래는 파이프라인 전체에 해당하는 내용이며, 모듈별 주의 사항은 각 모듈 페이지에 둔다.

### 국문
1. **Paired-end 데이터만 지원합니다.** Fragment 길이로 뉴클레오솜 위치를 구분하고 peak를 찾기 때문에 single-end 데이터는 분석할 수 없습니다.
2. **조건마다 반복 실험을 2개 이상 준비해 주세요.** 반복 실험이 없으면 차등 접근성은 통계 검정 없이 변화량만 계산하며, 반복 재현성 분석(IDR)과 차등 영역 기반 기능 분석은 수행되지 않습니다. 차등 접근성 분석은 두 조건 비교입니다.
3. **샘플 정보 파일(CSV)에 `SampleID`, `Condition`, `Replicate`를 적어 주세요.** BAM 파일 이름에 `SampleID`가 포함되어 있어야 자동으로 연결됩니다.
4. **참조 자료를 한 종, 한 버전으로 맞춰 주세요.** 유전체(FASTA), 유전자 주석(GFF3/GTF), TSS BED, OrgDb, 모티프 DB가 같은 종이어야 하며, 염색체 이름 표기도 같아야 합니다(`chr1`과 `1`은 서로 다름).
5. **결과 해석 전에 품질 지표를 확인해 주세요.** Fragment 크기 분포, TSS enrichment, FRiP, 샘플 상관·PCA를 확인합니다. 기준값은 각 모듈 설명을 참고하세요.
6. **모든 분석은 인터넷 연결 없이 수행됩니다.** KEGG 경로 분석은 지원하지 않으며, GO 분석에는 미리 준비한 OrgDb 파일을 사용합니다.
7. **참조 유전체 FASTA에는 인덱스(.fai)를 미리 만들어 두세요.** 인덱스가 없으면 일부 모듈이 FASTA 옆에 만들려고 하는데, 공유 데이터 폴더는 쓰기가 막혀 있을 수 있어 실패합니다(`samtools faidx genome.fa`).

### English
1. **Only paired-end data are supported.** Fragment lengths are used to resolve nucleosome positions and to call peaks, so single-end data cannot be analyzed.
2. **Prepare two or more replicates per condition.** Without replicates, differential accessibility reports fold changes only, without statistical testing, and replicate consistency (IDR) and enrichment analysis of differential regions are not performed. Differential accessibility compares two conditions.
3. **List `SampleID`, `Condition`, and `Replicate` in the sample sheet (CSV).** Each BAM file name must contain its `SampleID` for automatic matching.
4. **Use reference data from one species and one version.** The genome (FASTA), gene annotation (GFF3/GTF), TSS BED, OrgDb, and motif database must be for the same species with the same chromosome naming (`chr1` and `1` are different).
5. **Check quality metrics before interpreting results.** Review the fragment size distribution, TSS enrichment, FRiP, and sample correlation and PCA. See each module for reference values.
6. **All analyses run without internet access.** KEGG pathway analysis is not supported, and GO analysis uses a prepared OrgDb file.
7. **Prepare the index (.fai) of the reference FASTA in advance.** Without it some modules try to create one beside the FASTA, which fails in shared data folders that are not writable (`samtools faidx genome.fa`).
