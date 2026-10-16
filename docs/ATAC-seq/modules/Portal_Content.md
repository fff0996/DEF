# ATAC-seq 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고입니다. 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/ATAC-seq/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`, `/ref/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다. 예시 경로가 그대로 넘어가면 스크립트가 "not found"로 멈춥니다.
- 스레드·코어 수 옵션(`threads`, `cores`)은 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택이 곧 스레드 수이며(스크립트가 `auto`로 할당된 코어 수를 읽습니다), 같은 값을 두 번 고르다 엇갈리는 일을 막습니다.
- 선택(Optional) 입력은 빈 값이 "사용 안 함"입니다. 경로를 넣어 두면 그 경로를 실제로 찾으므로 Value를 비워 둡니다.
- 스크립트 사용 예제는 모든 옵션을 기본값으로 적었습니다(기본값이 없는 옵션은 제외). 예시 값은 애기장대(TAIR10, 유전체 약 1.2e8 bp) 기준입니다.
- 형식(Type)은 포탈 목록에 맞춰 고릅니다. 원고에는 Directory, File, String, Integer, Float, List로 적었습니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)이며 bowtie2와 GATK_MarkDuplicates를 뺀 모든 모듈이 같습니다. 이 두 모듈은 WGS 파이프라인과 같이 쓰는 이미지라 Rocky Linux 9(`rockylinux/rockylinux:9`)와 Miniforge3 26.5.3-0을 씁니다.
- 버전은 각 실행 스크립트 파일 이름에 적힌 버전을 씁니다(예: organellar_filter.1.1.sh → 1.1).
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지웁니다.
- 카테고리는 기능(분석 단계) 기준의 대분류·중분류로 정했습니다(`docs/CLOSHA_Portal_Guide_v1.md` 5.2). 아이콘은 대분류마다 하나입니다.
- 주요 결과 이미지는 모듈 결과 중 등록할 파일 이름만 적습니다(`output_dir` 기준). 그림은 등록할 때 실제 결과를 캡처해 올립니다.

---

## 1. bowtie2

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | bowtie2 | bowtie2 |
| 서브 타이틀 | 참조 유전체 정렬 | Read alignment to the reference genome |
| 버전 | 1.1 | |
| 카테고리 대분류 | 정렬 | Alignment |
| 카테고리 아이콘 | 선택 예정(Alignment 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | read 정렬 | Read Alignment |
| 태그 | ATAC-seq, bowtie2, alignment, SAM, BAM, samtools | |
| 레퍼런스 URL | https://bowtie-bio.sourceforge.net/bowtie2/ | |
| 컨테이너 이미지 | bowtie2.1.0 | |
| 실행 스크립트 파일 | bowtie2.1.1.sh | |
| Processor Core (제안) | 최대 4코어 (bowtie2, samtools sort가 여러 코어 사용) | Up to 4 cores (bowtie2 and samtools sort are multi-threaded) |

### 실행 이미지
이미지: bowtie2 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_bowtie2_1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9 (`rockylinux/rockylinux:9`) |
| conda 설치 도구 / installer | Miniforge3 26.5.3-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| bowtie2 | 2.5.4 | https://github.com/BenLangmead/bowtie2 |
| SAMtools | 1.24 | https://www.htslib.org/ |

- **태그(키워드):** 리드정렬, 참조유전체, 시퀀스정렬, BAM
- **내용(국문):** 시퀀싱 리드를 참조 유전체에 정렬하는 실행 환경입니다. bowtie2로 paired-end·single-end 리드를 정렬하고, SAMtools로 결과를 좌표 순으로 정렬한 BAM과 인덱스로 만듭니다. 사람 유전체 기준으로 인덱스를 올리는 데 약 4GB의 메모리를 사용합니다.
- **내용(영문):** Runtime environment for aligning sequencing reads to a reference genome. bowtie2 aligns paired-end and single-end reads, and SAMtools turns the alignments into coordinate-sorted BAM files with an index. Loading a human genome index uses about 4 GB of memory.

### 내용(국문)
FASTQ read를 bowtie2로 참조 유전체에 정렬합니다. 폴더 안의 FASTQ 파일 이름에서 R1/R2 짝을 찾아 paired-end로 정렬하고, 짝이 없는 파일은 single-end로 정렬합니다.
- 참조 유전체는 bowtie2 인덱스 이름(prefix)이나 FASTA 파일로 지정합니다. 인덱스가 없으면 FASTA 옆에 인덱스를 만듭니다.
- samtools로 정렬 결과를 좌표 순 BAM으로 바꾸고 인덱스(.bai)를 만듭니다.
- 샘플별 정렬 요약(전체 정렬률 등)을 로그로 남깁니다.
- 샘플마다 read group(ID, SM, LB = 샘플 이름, PL = ILLUMINA)을 붙입니다. GATK_MarkDuplicates는 read group이 있어야 실행됩니다.
- 결과 BAM은 GATK_MarkDuplicates 모듈의 입력으로 사용합니다.

### 내용(영문)
Aligns FASTQ reads to the reference genome with bowtie2. R1/R2 pairs are found from the FASTQ file names in the folder and aligned as paired-end; files without a mate are aligned as single-end.
- The reference is given as a bowtie2 index prefix or a FASTA file. If no index exists, one is built beside the FASTA.
- samtools converts the alignments to a coordinate-sorted BAM and builds its index (.bai).
- An alignment summary per sample (overall alignment rate and so on) is written to a log.
- Each sample gets a read group (ID, SM, and LB = the sample name, PL = ILLUMINA); GATK_MarkDuplicates needs read groups.
- The BAM files are the input of the GATK_MarkDuplicates module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/fastq | FASTQ 폴더(.fastq, .fq, .gz; 하위 폴더 포함). R1/R2 짝은 _R1/_R2, .R1/.R2, _1/_2 이름으로 찾음 | FASTQ folder (.fastq, .fq, .gz; subfolders included); pairs are matched by _R1/_R2, .R1/.R2, or _1/_2 |
| Output | Required | Directory | output_dir | /data/bowtie2 | 결과 폴더. 샘플마다 좌표 순 BAM(<sample>_bowtie_paired.sorted.bam)과 .bai, SAM, 정렬 로그 | Output folder: a coordinate-sorted BAM (<sample>_bowtie_paired.sorted.bam) with .bai, the SAM file, and the alignment log per sample |
| Option | Required | File | ref_genome | /ref/genome.fa | bowtie2 인덱스 이름(prefix) 또는 FASTA. 인덱스가 없으면 FASTA 옆에 생성 | bowtie2 index prefix or FASTA; a missing index is built beside the FASTA |

등록 메모: post_process_bam은 포탈에 등록하지 않습니다. 스크립트 기본값이 yes라 항상 좌표 순 BAM과 .bai를 만듭니다(CLOSHA 2.0의 bowtie2 1.0은 기본값이 no라 인자 없이 실행하면 SAM만 남았습니다).

### 주요 사항
| 국문 | 영문 |
|---|---|
| 샘플마다 좌표 순 BAM(<sample>_bowtie_paired.sorted.bam)과 인덱스(.bai)를 만듭니다. 다음 단계(GATK_MarkDuplicates)는 *.sorted.bam만 읽습니다. | Each sample gets a coordinate-sorted BAM (<sample>_bowtie_paired.sorted.bam) with its index (.bai). The next step (GATK_MarkDuplicates) reads *.sorted.bam only. |
| bowtie2 기본 설정(end-to-end, 짝 read 사이 최대 500 bp)으로 정렬합니다. 500 bp보다 긴 fragment는 정상 짝으로 정렬되지 않아, 뉴클레오솜 2~3개 길이의 fragment가 적게 잡힐 수 있습니다. | Alignment uses the bowtie2 defaults (end-to-end, pairs up to 500 bp apart). Fragments longer than 500 bp are not aligned as concordant pairs, so di- and trinucleosome fragments may be under-represented. |
| 인덱스가 없으면 FASTA와 같은 폴더에 만들므로 그 폴더에 쓰기 권한이 필요하고, 큰 유전체는 시간이 오래 걸립니다. 미리 만든 인덱스 이름을 지정하는 것을 권장합니다. | Without an index, one is built in the FASTA folder, which must be writable, and a large genome takes long. Giving a prebuilt index prefix is recommended. |
| 샘플 이름은 FASTQ 이름에서 R1/R2 표시와 _trimmed, _HQ를 뺀 것입니다. 이후 모듈이 SampleID로 BAM을 찾으므로, 샘플 정보 파일의 SampleID가 이 이름에 들어 있어야 합니다. | The sample name is the FASTQ name without the R1/R2 tag and _trimmed or _HQ. Later modules find BAM files by SampleID, so each SampleID in the sample sheet must appear in this name. |
| 스레드 수는 실행 환경의 Processor Core 선택(싱글 코어 또는 최대 4코어)을 따릅니다. 최대 4코어를 고르면 정렬이 빨라집니다. | The thread count follows the Processor Core selection (single core or up to 4 cores); choosing up to 4 cores speeds up alignment. |
| 결과 폴더에 SAM과 정렬 전 BAM(.unsorted.bam)도 남아 용량을 차지합니다. | SAM files and unsorted BAM files (.unsorted.bam) also remain in the output folder and take up space. |
| 샘플마다 read group(@RG; ID, SM, LB = 샘플 이름, PL = ILLUMINA)을 붙입니다. GATK_MarkDuplicates(GATK 4.6)는 read group이 없는 BAM에서 멈추므로, CLOSHA 2.0의 bowtie2 1.0으로 만든 BAM은 이 버전으로 다시 정렬해 주세요. | Each sample gets a read group (@RG; ID, SM, and LB = the sample name, PL = ILLUMINA). GATK_MarkDuplicates (GATK 4.6) stops on BAM files without read groups, so realign BAM files made with bowtie2 1.0 of CLOSHA 2.0 using this version. |

### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/bowtie2_concept.png`

- 레전드(국문): **그림. bowtie2 정렬.** (A) 참조 유전체 FASTA로 bowtie2 인덱스(.bt2 파일 6개)를 만듭니다. 인덱스가 이미 있으면 그대로 씁니다. (B) 짝을 이룬 두 read(R1, R2)를 참조 유전체에 서로 마주 보는 방향으로 정렬하며, 두 read 바깥 끝 사이가 fragment 길이입니다. bowtie2 기본 설정에서는 500 bp까지의 짝만 정상 짝(concordant)으로 봅니다. (C) 샘플마다 SAM 파일이 만들어지고, samtools로 정렬 전 BAM을 거쳐 좌표 순 BAM과 인덱스가 만들어집니다. 샘플마다 read group(@RG; ID, SM, LB = 샘플 이름, PL = ILLUMINA)이 붙습니다. 정렬 요약은 샘플별 로그에 남습니다(숫자는 예시).
- 레전드(영문): **Figure. Alignment with bowtie2.** (A) A bowtie2 index (six .bt2 files) is built from the reference FASTA; an existing index is used as is. (B) The two reads of a pair (R1, R2) align to the reference facing each other, and the span between their outer ends is the fragment length. With the bowtie2 defaults only pairs up to 500 bp are concordant. (C) Each sample gives a SAM file, then with samtools an unsorted BAM and a coordinate-sorted BAM with its index. Each sample gets a read group (@RG; ID, SM, and LB = the sample name, PL = ILLUMINA). The alignment summary is written to a per-sample log (numbers are illustrative).
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
bash bowtie2.1.1.sh \
  input_dir=/data/fastq \
  output_dir=/data/bowtie2 \
  ref_genome=/ref/genome.fa
```

### 주요 결과 이미지

**결과 1. 정렬 요약**
- 결과 파일: 화면 캡처 `<sample>_bowtie.log`의 정렬 요약 부분 (이 모듈은 그림을 만들지 않습니다)
- 레전드(국문): **샘플별 bowtie2 정렬 요약.** 전체 read 쌍 중 정상 짝으로 한 곳에 정렬된 비율(aligned concordantly exactly 1 time), 여러 곳에 정렬된 비율(>1 times), 정렬되지 않은 비율(0 times)과 전체 정렬률(overall alignment rate)을 보여 줍니다. ENCODE ATAC-seq 기준은 전체 정렬률 95% 이상이 바람직하고 80% 이상이면 허용하며, 여러 곳에 정렬된 비율이 높으면 반복 서열이나 오염을 의심할 수 있습니다.
- 레전드(영문): **bowtie2 alignment summary per sample.** The log shows the fractions of read pairs aligned concordantly exactly once, more than once, and not at all, and the overall alignment rate. The ENCODE ATAC-seq standard prefers an overall alignment rate of 95% or more and accepts 80% or more; a high multi-mapping fraction points to repeats or contamination.

---

## 2. GATK_MarkDuplicates

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | GATK_MarkDuplicates | GATK_MarkDuplicates |
| 서브 타이틀 | 중복 read 표시 | Duplicate read marking |
| 버전 | 1.0 | |
| 카테고리 대분류 | 정렬 | Alignment |
| 카테고리 아이콘 | 선택 예정(Alignment 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 정렬 결과 처리 | Alignment Processing |
| 태그 | ATAC-seq, GATK, Picard, MarkDuplicates, PCR duplicates, BAM | |
| 레퍼런스 URL | https://gatk.broadinstitute.org/ | |
| 컨테이너 이미지 | gatk.1.0 | |
| 실행 스크립트 파일 | GATK_MarkDuplicates_1.0.sh | |
| Processor Core (제안) | 싱글 코어 (MarkDuplicates는 한 코어로 실행) | Single core (MarkDuplicates runs on one core) |

등록 메모: 스크립트 파일 이름은 1.0이지만 내용은 v1.1입니다(도구 경로 /opt/bio/bin, 실패 시 종료 코드 1). Java 힙이 20GB로 고정(-Xmx20g)되어 있으므로 실행 메모리는 24GB 이상을 고릅니다. 스크립트가 받는 threads 인자는 쓰이지 않으므로 포탈에 등록하지 않습니다.

### 실행 이미지
이미지: gatk 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_gatk_1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9 (`rockylinux/rockylinux:9`) |
| conda 설치 도구 / installer | Miniforge3 26.5.3-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| GATK | 4.6.2.0 | https://gatk.broadinstitute.org/ |
| SAMtools | 1.24 | https://www.htslib.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |
| OpenJDK | 17 | https://openjdk.org/ |

- **태그(키워드):** 중복제거, 중복표시, BAM처리, GATK
- **내용(국문):** GATK(Picard)로 정렬된 BAM에서 PCR·광학 중복 read를 찾아 표시하는 실행 환경입니다. 중복 read는 지우지 않고 표시만 하며, 샘플별 중복 통계를 남깁니다. Java로 동작하므로 처리할 BAM 크기에 맞춰 충분한 메모리가 필요합니다.
- **내용(영문):** Runtime environment for finding and marking PCR and optical duplicate reads in aligned BAM files with GATK (Picard). Duplicate reads are marked rather than removed, and duplicate metrics are written per sample. It runs on Java, so it needs memory matched to the BAM size.

### 내용(국문)
정렬된 BAM에서 PCR·광학 중복 read를 찾아 표시합니다. 같은 위치에서 시작하고 같은 방향인 read 쌍을 중복으로 보고, 그중 염기 품질 합이 가장 높은 쌍 하나만 남기고 나머지에 중복 표시(flag 0x400)를 붙입니다.
- read는 지우지 않고 표시만 합니다. 이후 모듈은 이 표시를 보고 중복을 뺄 수 있습니다.
- 샘플마다 중복 표시된 BAM과 인덱스(.bai), 중복 통계(duplicate metrics)를 만듭니다.
- 입력 폴더에서 *sorted.bam을 모두 찾아(하위 폴더 포함, *unsorted.bam 제외) 차례로 처리합니다.
- 결과 BAM은 organellar_filter 모듈의 입력으로 사용합니다.

### 내용(영문)
Finds and marks PCR and optical duplicate reads in aligned BAM files. Read pairs that start at the same position in the same orientation are duplicates; the pair with the highest sum of base qualities is kept and the others get the duplicate flag (0x400).
- Reads are marked, not removed, so later modules can exclude them by the flag.
- Each sample gives a duplicate-marked BAM with its index (.bai) and duplicate metrics.
- All *sorted.bam files in the input folder (subfolders included, *unsorted.bam excluded) are processed one after another.
- The BAM files are the input of the organellar_filter module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/bowtie2 | 좌표 정렬된 BAM 폴더(*sorted.bam; 하위 폴더 포함, *unsorted.bam 제외). BAM에 read group(@RG)이 있어야 함. 임시 폴더를 이 안에 만들므로 쓰기 권한이 필요 | Folder of coordinate-sorted BAM files (*sorted.bam; subfolders included, *unsorted.bam excluded). The BAM files need read groups (@RG). Temporary folders are made inside it, so it must be writable |
| Output | Required | Directory | output_dir | /data/markdup | 결과 폴더(샘플별 중복 표시 BAM <sample>_marked.bam과 .bai, 중복 통계, 로그) | Output folder (per sample: duplicate-marked BAM <sample>_marked.bam with .bai, duplicate metrics, and logs) |
| Option | Required | File | ref_genome | /ref/genome.fa | 참조 유전체 FASTA. BAM을 정렬할 때 쓴 것과 같은 유전체 | Reference genome FASTA; the same genome the BAM files were aligned to |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 입력 BAM에 read group(@RG)이 있어야 합니다. GATK 4.6은 read group이 없는 BAM에서 NullPointerException으로 멈춥니다. bowtie2 1.1 이상(CLOSHA 3.0)의 결과에는 read group이 들어 있으며, CLOSHA 2.0의 bowtie2 1.0 결과는 다시 정렬해 주세요. | The input BAM files need read groups (@RG). GATK 4.6 stops with a NullPointerException on BAM files without them. bowtie2 1.1 or later (CLOSHA 3.0) writes read groups; realign BAM files from bowtie2 1.0 of CLOSHA 2.0. |
| Java 메모리가 20GB로 고정되어 있습니다. 실행 메모리는 24GB 이상을 골라 주세요. 그보다 작으면 큰 BAM에서 메모리 초과로 중단될 수 있습니다. | The Java heap is fixed at 20 GB. Choose 24 GB of memory or more; with less, a large BAM can be stopped for exceeding memory. |
| 샘플별 임시 폴더(temp_<sample>_...)를 input_dir 안에 만들고 끝나면 지웁니다. input_dir에 쓰기 권한이 있어야 합니다. | A temporary folder per sample (temp_<sample>_...) is made inside input_dir and removed afterwards, so input_dir must be writable. |
| GATK의 실행 기록과 오류는 실행 로그가 아니라 output_dir의 <sample>_markduplicates.log에 남습니다. 샘플이 실패하면 이 파일을 확인해 주세요. 한 샘플이라도 실패하면 모듈은 실패(종료 코드 1)로 끝납니다. | GATK's own output and errors go to <sample>_markduplicates.log in output_dir, not to the run log; check it when a sample fails. If any sample fails, the module ends as failed (exit code 1). |
| SRA에서 받은 데이터는 read 이름(SRR...1)에 좌표가 없어 "read name ... did not start with a parsable number" 경고가 나옵니다. 광학 중복만 구분하지 못할 뿐 중복 표시는 정상입니다. | Data from SRA has read names (SRR...1) without flowcell coordinates, so a "read name ... did not start with a parsable number" warning appears. Only optical duplicates cannot be told apart; duplicate marking works normally. |

### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/GATK_MarkDuplicates_concept.png`

- 레전드(국문): **그림. 중복 read 표시(MarkDuplicates).** (A) 같은 위치에서 같은 방향으로 시작하는 read 쌍(점선)은 PCR·광학 중복으로 봅니다. 그중 염기 품질 합이 가장 높은 쌍만 남기고 나머지는 중복으로 표시하며, 시작 위치가 다른 쌍은 중복이 아니다. (B) 중복 read는 지우지 않고 정렬 정보를 그대로 둔 채 FLAG에 중복 표시(0x400, 1024)만 더합니다(예: 99 → 1123). 이후 단계는 이 표시로 중복을 뺄 수 있습니다. 입력 BAM에는 read group(@RG)이 있어야 합니다. (C) 샘플마다 중복 표시 BAM과 인덱스, 중복 통계(duplicate_metrics.txt), GATK 실행 로그가 만들어집니다(숫자는 예시).
- 레전드(영문): **Figure. Duplicate marking (MarkDuplicates).** (A) Read pairs that start at the same position in the same orientation (dashed line) are PCR or optical duplicates. The pair with the highest base-quality sum is kept and the others are marked; a pair with a different start is not a duplicate. (B) Duplicate reads are not removed: their alignment stays and only the duplicate flag (0x400, 1024) is added to FLAG (for example 99 → 1123), so later steps can exclude them. The input BAM needs read groups (@RG). (C) Each sample gives a duplicate-marked BAM with its index, duplicate metrics (duplicate_metrics.txt), and the GATK log (numbers are illustrative).
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
bash GATK_MarkDuplicates_1.0.sh \
  input_dir=/data/bowtie2 \
  output_dir=/data/markdup \
  ref_genome=/ref/genome.fa
```

### 주요 결과 이미지

**결과 1. 중복 통계**
- 결과 파일: 표 캡처 `<sample>_duplicate_metrics.txt`의 METRICS CLASS 부분 (이 모듈은 그림을 만들지 않습니다)
- 레전드(국문): **샘플별 중복 read 통계.** 검사한 read 쌍 수(READ_PAIRS_EXAMINED), 중복으로 표시된 read 쌍 수(READ_PAIR_DUPLICATES), 그중 광학 중복 수(READ_PAIR_OPTICAL_DUPLICATES), 중복 비율(PERCENT_DUPLICATION, 0~1)과 추정 라이브러리 크기(ESTIMATED_LIBRARY_SIZE)를 보여 줍니다. 중복 비율은 시퀀싱 깊이와 시료 양에 따라 달라지므로, 같은 실험의 샘플끼리 비교해 다른 샘플보다 크게 높은 샘플을 찾는 데 씁니다.
- 레전드(영문): **Duplicate read metrics per sample.** The table gives the read pairs examined (READ_PAIRS_EXAMINED), the pairs marked as duplicates (READ_PAIR_DUPLICATES) and the optical duplicates among them (READ_PAIR_OPTICAL_DUPLICATES), the duplicate fraction (PERCENT_DUPLICATION, 0-1), and the estimated library size (ESTIMATED_LIBRARY_SIZE). The duplicate fraction depends on sequencing depth and input amount, so it is used to compare samples of an experiment and find ones far above the rest.

---

## 3. organellar_filter

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | organellar_filter | organellar_filter |
| 서브 타이틀 | 세포소기관 read 제거 | Organellar read removal |
| 버전 | 1.1 | |
| 카테고리 대분류 | 정렬 | Alignment |
| 카테고리 아이콘 | 선택 예정(Alignment 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 정렬 결과 처리 | Alignment Processing |
| 태그 | ATAC-seq, mitochondria, chloroplast, samtools, BAM filtering | |
| 레퍼런스 URL | https://www.htslib.org/ | |
| 컨테이너 이미지 | bx_organellar_filter.1.0 | |
| 실행 스크립트 파일 | organellar_filter.1.1.sh | |
| Processor Core (제안) | 최대 4코어 (samtools가 여러 코어 사용) | Up to 4 cores (samtools is multi-threaded) |

### 실행 이미지
이미지: bx_organellar_filter 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_organellar_filter.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 세포소기관제거, 미토콘드리아, 엽록체, BAM필터링
- **내용(국문):** 정렬된 BAM에서 미토콘드리아·엽록체 등 세포소기관 염색체의 read를 제거하는 실행 환경입니다. SAMtools로 세포소기관 contig를 찾아 핵 염색체 read만 남기고, 제거 전후 read 수를 요약합니다.
- **내용(영문):** Runtime environment for removing reads on organellar chromosomes, such as mitochondria and chloroplasts, from aligned BAM files. SAMtools finds the organellar contigs, keeps only nuclear reads, and summarises the read counts before and after filtering.

### 내용(국문)
정렬된 BAM 파일에서 미토콘드리아와 엽록체 등 세포소기관 염색체에 정렬된 read를 제거합니다. ATAC-seq에서는 Tn5가 뉴클레오솜이 없는 세포소기관 DNA를 많이 자르기 때문에 이 read의 비율이 높게 나타나며, 그대로 두면 peak 검출과 정규화에 영향을 줍니다.
- 세포소기관 염색체 이름을 정규식으로 찾아 제외합니다(chrM, MT, Pt, chrC 등).
- 제거 전후의 idxstats와 flagstat, 제거한 염색체 목록과 요약표를 함께 만듭니다.
- 결과 BAM은 ATAC_QC 모듈의 입력으로 사용합니다.

### 내용(영문)
Removes reads aligned to organellar chromosomes such as mitochondria and chloroplasts from aligned BAM files. In ATAC-seq, Tn5 cuts nucleosome-free organellar DNA heavily, so these reads are often abundant and can bias peak calling and normalization.
- Organellar chromosomes are matched by a regular expression and excluded (chrM, MT, Pt, chrC, and so on).
- idxstats and flagstat before and after filtering, the list of removed contigs, and a summary table are written.
- The filtered BAM files are the input of the ATAC_QC module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/bam | 좌표 정렬된 BAM 폴더(*.unsorted.bam 제외). BAM 인덱스(.bai)가 없으면 BAM 옆에 만들므로, 인덱스가 없을 때는 그 폴더에 쓰기 권한이 필요 | Folder of coordinate-sorted BAM files (*.unsorted.bam excluded). A missing BAM index (.bai) is built beside the BAM, so the folder must then be writable |
| Output | Required | Directory | output_dir | /data/organellar_filter | 결과 폴더. 세포소기관 read를 뺀 BAM(03_filtered_bam/<sample>.organellar_removed.bam)과 .bai, 통계, 요약표 | Output folder: BAM files without organellar reads (03_filtered_bam/<sample>.organellar_removed.bam) with .bai, statistics, and a summary table |
| Option | Optional | String | organellar_pattern | (^chrM$\|^MT$\|^Mt$\|mitochond\|mitochondrion\|mitochondrial\|chloroplast\|plastid\|^Pt$\|^PT$\|^chrC$) | 세포소기관 염색체 이름 정규식(대소문자 무시) | Regular expression for organellar contig names (case-insensitive) |

등록 메모: 스레드 수(`threads`)는 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택(싱글 코어 또는 최대 4코어)으로 정해지며, 스크립트 기본값 `auto`가 그 코어 수를 씁니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| BAM 파일은 좌표 순으로 정렬되어 있어야 합니다. | BAM files must be coordinate-sorted. |
| 세포소기관 염색체 이름이 일반적이지 않은 종은 organellar_pattern을 지정해 주세요. 결과의 contig 목록에서 제거된 염색체를 확인할 수 있습니다. | For species with unusual organellar contig names, set organellar_pattern. The contig list in the results shows which contigs were removed. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/organellar_filter_concept.png`

- 레전드(국문): **그림. 세포소기관 read 제거.** (A) 핵 DNA는 뉴클레오솜에 감겨 Tn5 절단이 열린 영역에 한정되지만, 미토콘드리아·엽록체 DNA는 뉴클레오솜이 없어 Tn5가 많이 자릅니다. (B) 그 결과 정렬된 read의 상당 부분이 세포소기관 contig(Mt, Pt)에 몰립니다. 모듈은 contig별 read 수(idxstats)와 제거 전후 flagstat을 표로 남기며, 필터 후에는 핵 염색체 read만 남습니다. (C) 세포소기관 contig는 이름 정규식(organellar_pattern)으로 찾아 제외합니다.
- 레전드(영문): **Figure. Removal of organellar reads.** (A) Nuclear DNA is wrapped around nucleosomes, so Tn5 cuts only open regions, whereas mitochondrial and chloroplast DNA lacks nucleosomes and is cut heavily. (B) Many aligned reads therefore fall on organellar contigs (Mt, Pt). The module writes reads per contig (idxstats) and flagstat before and after filtering as tables; after filtering only nuclear reads remain. (C) Organellar contigs are matched by a name pattern (organellar_pattern) and excluded.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
bash organellar_filter.1.1.sh \
  input_dir=/data/bam \
  output_dir=/data/organellar_filter \
  organellar_pattern='(^chrM$|^MT$|^Mt$|mitochond|mitochondrion|mitochondrial|chloroplast|plastid|^Pt$|^PT$|^chrC$)'
```

### 주요 결과 이미지

**결과 1. 세포소기관 read 제거 요약**
- 결과 파일: `01_stats/<sample>.before.flagstat.txt`, `.after.flagstat.txt`, `.idxstats.tsv`의 값을 정리한 표 (이 모듈은 그림을 만들지 않습니다)
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/organellar_filter/portal/organellar_filter_result_1.png`
- 레전드(국문): **샘플별 세포소기관 read 제거 요약.** 샘플마다 제거 전 read 수(Reads before), 엽록체(Pt)와 미토콘드리아(Mt) contig에 정렬된 read 수, 제거 후 read 수(Reads after), 제거된 비율(Removed fraction)을 보여 줍니다. read 수는 flagstat의 primary alignment 수이고, Pt·Mt는 idxstats의 contig별 read 수입니다. 식물 ATAC-seq은 엽록체 DNA가 많아 제거 비율이 10~40%에 이르기도 하며, 샘플 간 비율 차이가 크면 핵 분리 효율이 달랐다는 신호입니다. 예시 데이터(애기장대)에서는 엽록체 read가 10.6~39.4%였고, 미토콘드리아 read는 샘플당 약 2,000개로 적었습니다.
- 레전드(영문): **Organellar read removal per sample.** For each sample the table gives the reads before filtering (Reads before), the reads aligned to the chloroplast (Pt) and mitochondrial (Mt) contigs, the reads after filtering (Reads after), and the removed fraction. Read counts are primary alignments from flagstat, and Pt and Mt counts are per-contig reads from idxstats. Plant ATAC-seq often carries much chloroplast DNA, so 10-40% may be removed; large differences between samples point to uneven nuclei isolation. In the example data (Arabidopsis) chloroplast reads were 10.6-39.4%, and mitochondrial reads were few (about 2,000 per sample).

---

## 4. ATAC_QC

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | ATAC_QC | ATAC_QC |
| 서브 타이틀 | ATAC-seq 품질 평가와 Tn5 보정 | ATAC-seq QC and Tn5 shift |
| 버전 | 1.1 | |
| 카테고리 대분류 | 품질 관리 | Quality Control |
| 카테고리 아이콘 | 선택 예정(Quality Control 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 정렬 품질 평가 | Alignment QC |
| 태그 | ATAC-seq, ATACseqQC, fragment size, TSS enrichment, Tn5 shift, bigWig | |
| 레퍼런스 URL | https://bioconductor.org/packages/ATACseqQC/ | |
| 컨테이너 이미지 | bx_atac_qc.1.0 | |
| 실행 스크립트 파일 | ATAC_QC.1.1.R | |
| Processor Core (제안) | 싱글 코어 (ATACseqQC는 1코어로 계산) | Single core (ATACseqQC runs on one core) |

### 실행 이미지
이미지: bx_atac_qc 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_atac_qc.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| ATACseqQC | 1.34.0 | https://bioconductor.org/packages/ATACseqQC/ |
| ChIPpeakAnno | 3.44.0 | https://bioconductor.org/packages/ChIPpeakAnno/ |
| Rsamtools | 2.26.0 | https://bioconductor.org/packages/Rsamtools/ |
| GenomicAlignments | 1.46.0 | https://bioconductor.org/packages/GenomicAlignments/ |
| GenomicRanges | 1.62.1 | https://bioconductor.org/packages/GenomicRanges/ |
| GenomeInfoDb | 1.46.2 | https://bioconductor.org/packages/GenomeInfoDb/ |
| IRanges | 2.44.0 | https://bioconductor.org/packages/IRanges/ |

- **태그(키워드):** ATAC-seq품질평가, Tn5보정, 뉴클레오솜, TSS
- **내용(국문):** ATAC-seq 데이터의 품질을 평가하는 R 실행 환경입니다. ATACseqQC로 fragment 크기 분포와 TSS enrichment를 계산하고, Tn5 삽입 위치를 보정한 뒤 fragment를 뉴클레오솜 위치별로 나눕니다. TSS 주변 신호 heatmap도 같은 환경에서 그립니다.
- **내용(영문):** R runtime environment for assessing ATAC-seq data quality. ATACseqQC computes the fragment size distribution and TSS enrichment, corrects Tn5 insertion positions, and splits fragments by nucleosome position. The TSS signal heatmaps are drawn in the same environment.

### 내용(국문)
ATACseqQC로 ATAC-seq 데이터의 품질을 평가하고, 이후 분석에 쓸 Tn5 보정 BAM을 만듭니다.
- fragment 크기 분포로 뉴클레오솜 주기 패턴(약 200 bp 간격)을 확인합니다.
- bamQC로 중복, 낮은 매핑 품질, proper pair가 아닌 read를 걸러 clean BAM을 만듭니다.
- Tn5 삽입 위치를 보정(+ 가닥 +4 bp, − 가닥 −5 bp)한 shifted BAM을 만듭니다.
- fragment를 NFR, mononucleosome, dinucleosome, trinucleosome으로 분할합니다.
- 샘플별 TSS enrichment 점수와 CPM 정규화 coverage bigWig를 만듭니다.
- 결과는 ATAC_QC_plot, MACS3_callpeak, differential_accessibility, tf_footprinting, replicate_consistency의 입력으로 사용합니다.

### 내용(영문)
Assesses ATAC-seq data quality with ATACseqQC and prepares Tn5-corrected BAM files for downstream analysis.
- The fragment size distribution shows the nucleosome periodicity (about 200 bp).
- bamQC removes duplicates, low mapping quality reads, and reads that are not in proper pairs to produce a clean BAM.
- A shifted BAM is written with Tn5 insertion positions corrected (+4 bp on the plus strand, −5 bp on the minus strand).
- Fragments are split into NFR, mononucleosome, dinucleosome, and trinucleosome classes.
- A TSS enrichment score and a CPM-normalized coverage bigWig are produced per sample.
- The outputs feed ATAC_QC_plot, MACS3_callpeak, differential_accessibility, tf_footprinting, and replicate_consistency.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/organellar_filter | Tn5 보정 전, 좌표 정렬된 paired-end BAM 폴더(세포소기관 read는 미리 빼 두기를 권장). BAM 인덱스(.bai)가 없으면 BAM 옆에 만들므로, 인덱스가 없을 때는 그 폴더에 쓰기 권한이 필요 | Folder of coordinate-sorted paired-end BAM files before the Tn5 shift (organellar reads removed beforehand is recommended). A missing BAM index (.bai) is built beside the BAM, so the folder must then be writable |
| Input | Required | File | sample_data | /data/sample_data.csv | 샘플 정보 CSV(SampleID, Condition, Replicate) | Sample sheet CSV (SampleID, Condition, Replicate) |
| Input | Required | File | txs_bed | /ref/genes.bed | 전사체/TSS 영역 BED(6열 권장: chr start end name score strand) | Transcript/TSS BED (6 columns recommended: chr start end name score strand) |
| Input | Required | File | genome_fasta | /ref/genome.fa | 참조 유전체 FASTA. .fai가 없으면 FASTA 옆에 만들므로 그 폴더에 쓰기 권한이 필요. 공유 참조는 .fai를 미리 만들어 둘 것(samtools faidx) | Reference genome FASTA. A missing .fai is created beside the FASTA, so the folder must be writable; prepare the .fai in advance for shared references (samtools faidx) |
| Output | Required | Directory | output_dir | /data/atac_qc | 결과 폴더 | Output folder |
| Option | Optional | String | seqlev | auto | 사용할 염색체(쉼표 구분). auto는 BAM과 txs_bed에 공통인 염색체 전부 | Chromosomes to use (comma-separated); auto uses all chromosomes shared by the BAM and txs_bed |
| Option | Optional | Integer | tss_flank | 1000 | TSS enrichment 계산 범위(TSS 앞뒤 bp, 200 이상) | Flank around each TSS for the TSS enrichment score (bp, at least 200) |
| Option | Optional | List | make_bigwig | TRUE | 샘플별 coverage bigWig(CPM) 생성 여부(TRUE/FALSE) | Write a CPM coverage bigWig per sample (TRUE/FALSE) |

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): 쉼표로 구분한 CSV 파일이며 SampleID, Condition, Replicate 컬럼이 필요합니다. BAM 파일 이름에 SampleID가 포함되어 있어야 자동으로 연결됩니다.
- 본문(영문): A comma-separated CSV with the SampleID, Condition, and Replicate columns. Each BAM file name must contain its SampleID for automatic matching.
- 예시 제목: sample_data.csv
- 예시 본문:
```
SampleID,Condition,Replicate
ctrl_1,control,1
ctrl_2,control,2
trt_1,treated,1
trt_2,treated,2
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| Paired-end BAM만 지원합니다. | Only paired-end BAM files are supported. |
| BAM, txs_bed, genome_fasta의 염색체 이름 표기가 같아야 합니다(chr1과 1은 서로 다름). | Chromosome names must match between the BAM, txs_bed, and genome_fasta (chr1 and 1 differ). |
| TSS enrichment는 ENCODE 사람(hg38) 기준 7 초과 양호, 5 미만 주의입니다. 다른 종은 주석 품질에 따라 범위가 다릅니다. | TSS enrichment above 7 is good and below 5 is concerning for human (hg38, ENCODE); the range for other species depends on the annotation. |
| clean BAM은 proper pair만 남기므로 긴 fragment가 적은 데이터에서는 trinucleosome 분할이 비어 있을 수 있습니다. 빈 분할은 read가 없는 것으로 기록됩니다. | The clean BAM keeps proper pairs only, so the trinucleosome split can be empty when long fragments are rare; an empty split is recorded as having no reads. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/ATAC_QC_concept.png`

- 레전드(국문): **그림. ATAC-seq 품질 평가와 Tn5 보정.** (A) Tn5 절단 위치에 따라 뉴클레오솜 사이 열린 DNA에서는 짧은 NFR fragment가, 뉴클레오솜 하나 또는 둘을 사이에 두면 mononucleosome·dinucleosome fragment가 생깁니다. (B) 좋은 라이브러리의 fragment 길이 분포는 NFR 봉우리와 약 200 bp 간격의 뉴클레오솜 주기를 보이며, 약 10.5 bp의 DNA 나선 주기도 나타납니다(작은 그림: 로그 척도). (C) Tn5는 두 가닥에 9 bp 간격으로 삽입되므로 + 가닥 read는 +4 bp, − 가닥 read는 −5 bp 옮겨 실제 삽입 중심을 표시합니다. (B)는 Ou J. et al., BMC Genomics 19, 169 (2018), Fig. 1을 수정(CC BY 4.0).
- 레전드(영문): **Figure. ATAC-seq quality control and Tn5 shift.** (A) Depending on the Tn5 cut sites, open DNA between nucleosomes gives short NFR fragments, and fragments spanning one or two nucleosomes are mononucleosome or dinucleosome fragments. (B) A good library shows an NFR peak and nucleosome periodicity of about 200 bp in the fragment size distribution, with the ~10.5 bp helical pitch visible (inset: log scale). (C) Tn5 inserts into the two strands 9 bp apart, so plus-strand reads are shifted +4 bp and minus-strand reads −5 bp to mark the insertion center. Panel B adapted from Ou J. et al., BMC Genomics 19, 169 (2018), Fig. 1 (CC BY 4.0).
- 출처: Ou J, Liu H, Yu J, Kelliher MA, Castilla LH, Lawson ND, Zhu LJ. ATACseqQC: a Bioconductor package for post-alignment quality assessment of ATAC-seq data. *BMC Genomics* 19, 169 (2018). https://doi.org/10.1186/s12864-018-4559-3, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

### 스크립트 사용 예제
```
Rscript ATAC_QC.1.1.R \
  input_dir=/data/organellar_filter \
  sample_data=/data/sample_data.csv \
  txs_bed=/ref/genes.bed \
  genome_fasta=/ref/genome.fa \
  output_dir=/data/atac_qc \
  seqlev=auto \
  tss_flank=1000 \
  make_bigwig=TRUE
```

### 주요 결과 이미지
결과 그림 3개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. Fragment 크기 분포**
- 결과 파일: `01_fragment_size/<sample>/<sample>.fragSizeDist.pdf` (대표 샘플 1개)
- 레전드(국문): **Fragment 크기 분포.** paired-end fragment의 길이(가로축, bp)별 read 수(세로축)다. 100 bp 이하의 nucleosome-free 봉우리와 약 200 bp(mononucleosome), 약 400 bp(dinucleosome) 간격의 주기적인 봉우리가 보이면 Tn5 절단이 정상적으로 일어난 것입니다. 작은 그림은 같은 분포를 로그 축으로 보여 주며, 짧은 구간의 약 10.5 bp 물결(DNA 나선 주기)도 여기서 보입니다. 봉우리 없이 매끄럽게 줄어들면 Tn5 반응이 과하거나 세포 상태가 나쁜 경우입니다.
- 레전드(영문): **Fragment size distribution.** Read counts (y-axis) by paired-end fragment length (x-axis, bp). A nucleosome-free peak below 100 bp followed by periodic peaks near 200 bp (mononucleosome) and 400 bp (dinucleosome) indicates proper Tn5 cutting. The inset shows the same distribution on a log scale, where the ~10.5 bp helical ripple of short fragments is also visible. A smooth decay without peaks points to over-tagmentation or poor cell condition.

**결과 2. TSS enrichment**
- 결과 파일: `07_tss_enrichment/<sample>.tss_enrichment.pdf` (대표 샘플 1개)
- 레전드(국문): **TSS enrichment.** 가로축은 TSS로부터의 거리(기본 ±1,000 bp), 세로축은 양 끝 구간 대비 신호 비율(aggregate TSS score)입니다. TSS(0 bp, 점선)에서 신호가 뚜렷하게 솟을수록 열린 염색질이 잘 포착된 것이며, 제목에 TSS enrichment score가 표시됩니다. ENCODE는 사람(GRCh38, RefSeq TSS) 기준 7 이상을 이상적, 5~7을 허용으로 둡니다. 값은 유전체와 TSS 주석에 따라 달라지므로 같은 실험의 샘플끼리 비교하는 데 주로 씁니다.
- 레전드(영문): **TSS enrichment.** The x-axis is the distance from the TSS (±1,000 bp by default) and the y-axis the signal relative to the flanking ends (aggregate TSS score). A sharp rise at the TSS (0 bp, dashed line) indicates good capture of open chromatin; the TSS enrichment score is shown in the title. ENCODE considers 7 or more ideal and 5-7 acceptable for human (GRCh38, RefSeq TSS). The value depends on the genome and TSS annotation, so it is mainly used to compare samples within an experiment.

**결과 3. 샘플별 QC 지표**
- 결과 파일: 표 캡처 `05_metadata/atac_qc_metrics.tsv`
- 레전드(국문): **샘플별 QC 지표.** 샘플마다 입력 read 수(InputMappedReads), 정제 후 read 수(CleanMappedReads)와 그 비율(CleanFraction), Tn5 보정 후 read 수(ShiftedReads), TSS enrichment score(TSSEnrichment), fragment 분리 상태(SplitStatus)를 한 줄로 보여 줍니다. CleanFraction이 다른 샘플보다 크게 낮으면 중복·저품질 read가 많은 샘플입니다. SplitStatus가 `empty_split:<분류>`이면 그 길이 분류에 fragment가 없다는 뜻입니다(예: 긴 fragment가 적은 데이터의 trinucleosome).
- 레전드(영문): **QC metrics per sample.** One row per sample with input reads (InputMappedReads), reads after cleaning (CleanMappedReads) and their fraction (CleanFraction), reads after the Tn5 shift (ShiftedReads), the TSS enrichment score (TSSEnrichment) and the fragment split status (SplitStatus). A CleanFraction far below the other samples indicates many duplicate or low-quality reads. `empty_split:<class>` means no fragments fell into that length class (for example trinucleosome in data with few long fragments).

---

## 5. ATAC_QC_plot

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | ATAC_QC_plot | ATAC_QC_plot |
| 서브 타이틀 | TSS 주변 신호 시각화 | TSS signal visualization |
| 버전 | 1.1 | |
| 카테고리 대분류 | 품질 관리 | Quality Control |
| 카테고리 아이콘 | 선택 예정(Quality Control 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 정렬 품질 평가 | Alignment QC |
| 태그 | ATAC-seq, ATACseqQC, TSS, heatmap, nucleosome | |
| 레퍼런스 URL | https://bioconductor.org/packages/ATACseqQC/ | |
| 컨테이너 이미지 | bx_atac_qc.1.0 | |
| 실행 스크립트 파일 | ATAC_QC_plot.1.1.R | |
| Processor Core (제안) | 싱글 코어 | Single core |

### 실행 이미지
이미지: bx_atac_qc 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_atac_qc.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| ATACseqQC | 1.34.0 | https://bioconductor.org/packages/ATACseqQC/ |
| ChIPpeakAnno | 3.44.0 | https://bioconductor.org/packages/ChIPpeakAnno/ |
| Rsamtools | 2.26.0 | https://bioconductor.org/packages/Rsamtools/ |
| GenomicAlignments | 1.46.0 | https://bioconductor.org/packages/GenomicAlignments/ |
| GenomicRanges | 1.62.1 | https://bioconductor.org/packages/GenomicRanges/ |
| GenomeInfoDb | 1.46.2 | https://bioconductor.org/packages/GenomeInfoDb/ |
| IRanges | 2.44.0 | https://bioconductor.org/packages/IRanges/ |

- **태그(키워드):** ATAC-seq품질평가, Tn5보정, 뉴클레오솜, TSS
- **내용(국문):** ATAC-seq 데이터의 품질을 평가하는 R 실행 환경입니다. ATACseqQC로 fragment 크기 분포와 TSS enrichment를 계산하고, Tn5 삽입 위치를 보정한 뒤 fragment를 뉴클레오솜 위치별로 나눕니다. TSS 주변 신호 heatmap도 같은 환경에서 그립니다.
- **내용(영문):** R runtime environment for assessing ATAC-seq data quality. ATACseqQC computes the fragment size distribution and TSS enrichment, corrects Tn5 insertion positions, and splits fragments by nucleosome position. The TSS signal heatmaps are drawn in the same environment.

### 내용(국문)
ATAC_QC가 만든 fragment 종류별 BAM으로 TSS 주변 신호의 heatmap과 평균 profile을 그립니다. 좋은 ATAC-seq 데이터에서는 NFR 신호가 TSS 바로 위에 모이고, mononucleosome 신호는 TSS 양옆에 나타납니다.
- nucleosome-free 신호와 nucleosome 신호(mono, di, trinucleosome을 합친 것) 두 가지의 TSS 주변 heatmap과 profile을 PDF와 TSV로 저장합니다.
- 비어 있는 종류(예: trinucleosome)는 read가 없는 것으로 계산하며, 샘플별로 read가 있던 종류와 비어 있던 종류를 요약합니다.

### 내용(영문)
Plots heatmaps and average profiles of the signal around TSSs from the fragment-class BAM files made by ATAC_QC. In good ATAC-seq data, the NFR signal concentrates on the TSS and the mononucleosome signal flanks it.
- TSS heatmaps and profiles of two signals, nucleosome-free and nucleosome (mono-, di-, and trinucleosome combined), are saved as PDF and TSV.
- An empty class (for example trinucleosome) counts as having no reads, and the classes with and without reads are summarized per sample.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/atac_qc | ATAC-seq QC 결과 폴더. 안에 05_metadata/atac_qc_manifest.tsv와 그 표가 가리키는 nucleosome 분할 BAM(04_split_bam/<sample>/)이 있어야 함 | ATAC-seq QC result folder containing 05_metadata/atac_qc_manifest.tsv and the nucleosome-split BAM files it lists (04_split_bam/<sample>/) |
| Input | Required | File | tss_bed | /ref/tss.bed | TSS 위치 BED | TSS BED |
| Output | Required | Directory | output_dir | /data/atac_qc_plot | 결과 폴더 | Output folder |
| Option | Optional | Integer | upstream | 1010 | TSS 상류 범위(bp) | Upstream range from the TSS (bp) |
| Option | Optional | Integer | downstream | 1010 | TSS 하류 범위(bp) | Downstream range from the TSS (bp) |
| Option | Optional | Integer | ntile | 101 | TSS 창(upstream+downstream)을 나누는 칸 수. 칸 크기 = (upstream+downstream)/ntile. 홀수로 두어야 가운데 칸이 TSS에 옴(기본 2020/101 = 20 bp) | Bins across the TSS window (upstream+downstream); bin size = (upstream+downstream)/ntile. Keep it odd so the middle bin sits on the TSS (default 2020/101 = 20 bp) |
| Option | Optional | Float | tss_filter | 0.5 | 신호가 약한 TSS를 빼는 기준(ATACseqQC TSS.filter). TSS 창의 평균 신호가 이 값보다 커야 그림에 넣음. 0이면 필터 없음 | Drops weak TSSs (ATACseqQC TSS.filter): a TSS is kept when its mean signal over the window exceeds this value; 0 disables the filter |
| Option | Optional | List | harmonize_mode | auto | auto: 염색체 이름이 다르면 자동으로 맞춤, strict: 다르면 중단 | auto: harmonize chromosome names; strict: stop if they differ |

### 주요 사항
| 국문 | 영문 |
|---|---|
| ATAC_QC 1.1 이상의 결과를 입력으로 사용해 주세요. | Use the output of ATAC_QC 1.1 or later as input. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/ATAC_QC_plot_concept.png`

- 레전드(국문): **그림. TSS 주변 신호.** (A) 모든 TSS를 기준으로 정렬한 NucleosomeFree(왼쪽)와 nucleosome(오른쪽) 신호 heatmap. 오른쪽은 결과 그림에 mononucleosome으로 표시되지만 mono, di, trinucleosome fragment를 합친 신호입니다. 각 행은 하나의 TSS다. (B) 평균 신호. 좋은 데이터에서는 NFR 신호가 TSS에 모이고, 뉴클레오솜 신호는 그 양옆(−1, +1 뉴클레오솜)에 나타납니다. Ou J. et al., BMC Genomics 19, 169 (2018), Fig. 1을 수정(CC BY 4.0).
- 레전드(영문): **Figure. Signal around TSSs.** (A) Heatmaps of NucleosomeFree (left) and nucleosome (right) signal aligned at all TSSs; the right panel is labelled mononucleosome in the output but combines mono-, di-, and trinucleosome fragments. Each row is one TSS. (B) Averaged coverage. In good data the NFR signal concentrates at the TSS and the nucleosome signal flanks it (−1 and +1 nucleosomes). Adapted from Ou J. et al., BMC Genomics 19, 169 (2018), Fig. 1 (CC BY 4.0).
- 출처: Ou J, Liu H, Yu J, Kelliher MA, Castilla LH, Lawson ND, Zhu LJ. ATACseqQC: a Bioconductor package for post-alignment quality assessment of ATAC-seq data. *BMC Genomics* 19, 169 (2018). https://doi.org/10.1186/s12864-018-4559-3, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

### 스크립트 사용 예제
```
Rscript ATAC_QC_plot.1.1.R \
  input_dir=/data/atac_qc \
  tss_bed=/ref/tss.bed \
  output_dir=/data/atac_qc_plot \
  upstream=1010 \
  downstream=1010 \
  ntile=101 \
  tss_filter=0.5 \
  harmonize_mode=auto
```

### 주요 결과 이미지
결과 그림 2개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. TSS 주변 신호 heatmap**
- 결과 파일: `01_tss_signal/<sample>.Heatmap_splitbam.pdf` (대표 샘플 1개)
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/ATAC_QC_plot/portal/ATAC_QC_plot_result_1.png`
- 레전드(국문): **TSS 주변의 nucleosome-free 신호와 nucleosome 신호.** 각 행은 TSS 하나이고, 가로축은 TSS 중심 −1,000~+1,000 bp 구간입니다. 왼쪽 패널(NucleosomeFree)은 nucleosome-free fragment, 오른쪽 패널(그림에는 mononucleosome으로 표시)은 mono, di, trinucleosome fragment를 합친 nucleosome 신호입니다. 색은 log2(coverage + 1)을 노랑(0)에서 빨강(2 이상)으로 나타내며, 행은 NucleosomeFree 신호가 강한 TSS가 위로 오도록 정렬됩니다. 정상적인 ATAC-seq에서는 왼쪽 패널의 빨간 띠가 TSS(가운데)에 모이고, 오른쪽 패널은 TSS 바로 위가 옅고 양옆(nucleosome 자리)이 진합니다. 예시 데이터(애기장대, SRR24197771)에서도 이 형태가 뚜렷합니다.
- 레전드(영문): **Nucleosome-free and nucleosome signal around TSSs.** Each row is one TSS and the x-axis spans −1,000 to +1,000 bp around its centre. The left panel (NucleosomeFree) shows nucleosome-free fragments and the right panel (labelled mononucleosome in the plot) the nucleosome signal of mono-, di-, and trinucleosome fragments combined. Colour shows log2(coverage + 1) from yellow (0) to red (2 or more), and rows are ordered with the strongest NucleosomeFree signal on top. In good ATAC-seq data the red band of the left panel sits on the TSS (centre), while the right panel is pale right at the TSS and darker on both sides where nucleosomes sit. The example data (Arabidopsis, SRR24197771) show this pattern clearly.

**결과 2. TSS 주변 평균 신호**
- 결과 파일: `01_tss_signal/<sample>.TSSprofile_splitbam.pdf`의 2쪽(제목 "<sample> TSS signal", 세로축 Fraction of signal) (결과 1과 같은 샘플). 1쪽은 같은 신호를 정규화 전 평균 coverage로 그린 그림입니다.
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/ATAC_QC_plot/portal/ATAC_QC_plot_result_2.png`
- 레전드(국문): **TSS 주변 평균 신호.** 결과 1의 heatmap을 모든 TSS에 대해 평균한 선 그래프입니다. 가로축은 TSS 기준 위치(−1 kb~+1 kb, bp), 세로축은 두 신호를 각각 최댓값 1로 맞춘 값(Fraction of signal)입니다. 검은 실선은 NucleosomeFree, 빨간 점선은 nucleosome 신호(그림에는 mononucleosome으로 표시, mono, di, trinucleosome fragment를 합친 신호)입니다. 정상적인 ATAC-seq에서는 검은 선이 TSS 근처에서 가장 높고, 빨간 점선은 TSS에서 낮아졌다가 양옆(−1, +1 nucleosome 자리)에서 높아집니다. 예시 데이터에서는 검은 선이 TSS 바로 위쪽(약 −50 bp)에서 가장 높고, 빨간 점선은 약 −250 bp(−1 nucleosome)와 +120 bp(+1 nucleosome)에서 높아집니다.
- 레전드(영문): **Average signal around TSSs.** The heatmap of result 1 averaged over all TSSs. The x-axis is the position relative to the TSS (−1 kb to +1 kb, bp) and the y-axis each signal scaled to a maximum of 1 (fraction of signal). The solid black line is NucleosomeFree and the dashed red line the nucleosome signal (labelled mononucleosome in the plot; mono-, di-, and trinucleosome fragments combined). In good ATAC-seq data the black line peaks near the TSS, while the red line dips at the TSS and rises on both sides at the −1 and +1 nucleosome positions. In the example data the black line peaks just upstream of the TSS (about −50 bp), and the red line rises at about −250 bp (−1 nucleosome) and +120 bp (+1 nucleosome).

---

## 6. MACS3_callpeak_ATAC

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | MACS3_callpeak_ATAC | MACS3_callpeak_ATAC |
| 서브 타이틀 | ATAC-seq peak 검출 | ATAC-seq peak calling |
| 버전 | 1.1 | |
| 카테고리 대분류 | 특징 검출 | Feature Detection |
| 카테고리 아이콘 | 선택 예정(Feature Detection 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | peak 검출 | Peak Calling |
| 태그 | ATAC-seq, MACS3, peak calling, narrowPeak, FRiP | |
| 레퍼런스 URL | https://github.com/macs3-project/MACS | |
| 컨테이너 이미지 | bx_macs3_callpeak_atac.1.0 | |
| 실행 스크립트 파일 | MACS3_callpeak_ATAC.1.1.sh | |
| Processor Core (제안) | 싱글 코어 (MACS3는 1코어로 계산) | Single core (MACS3 runs on one core) |

### 실행 이미지
이미지: bx_macs3_callpeak_atac 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_macs3_callpeak_atac.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| MACS3 | 3.0.4 | https://github.com/macs3-project/MACS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 피크검출, 열린염색질, MACS3, FRiP
- **내용(국문):** ATAC-seq에서 열린 염색질 영역(peak)을 찾는 실행 환경입니다. MACS3로 paired-end fragment 전체를 이용해 narrow 또는 broad peak를 검출하고, SAMtools로 샘플별 FRiP(peak 안 read 비율)을 계산합니다.
- **내용(영문):** Runtime environment for finding open chromatin regions (peaks) in ATAC-seq data. MACS3 calls narrow or broad peaks from whole paired-end fragments, and SAMtools computes the fraction of reads in peaks (FRiP) per sample.

### 내용(국문)
MACS3 callpeak의 paired-end 모드(BAMPE)로 Tn5 보정 BAM에서 열린 염색질 peak를 검출합니다.
- peak_type으로 MACS3 peak 모드를 고릅니다. ATAC-seq은 narrow(기본), 넓은 신호는 broad입니다.
- CONTROL_로 시작하는 BAM이 있으면 같은 이름의 처리군과 짝지어 실행합니다.
- 샘플별 FRiP(peak 안에 들어간 read 비율)를 계산해 frip_summary.tsv에 정리합니다.
- 결과는 peak_annotation, differential_accessibility, tf_footprinting의 입력으로 사용합니다.

### 내용(영문)
Calls open-chromatin peaks from Tn5-corrected BAM files with MACS3 callpeak in paired-end mode (BAMPE).
- peak_type selects the MACS3 peak mode: narrow (default) for ATAC-seq, or broad for wide signals.
- BAM files starting with CONTROL_ are paired with the treatment of the same name.
- FRiP (fraction of reads in peaks) is computed per sample and written to frip_summary.tsv.
- The outputs feed peak_annotation, differential_accessibility, and tf_footprinting.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/atac_qc | Tn5 보정 BAM 폴더(*<alignment_suffix>, 기본 *.shifted.bam). 폴더 안에 03_shifted_bam/이 있으면 그 안에서만 찾음. BAM 인덱스(.bai)가 없으면 BAM 옆에 만들므로, 인덱스가 없을 때는 그 폴더에 쓰기 권한이 필요 | Folder of Tn5-shifted BAM files (*<alignment_suffix>, default *.shifted.bam); if it contains 03_shifted_bam/, only that subfolder is searched. A missing BAM index (.bai) is built beside the BAM, so the folder must then be writable |
| Output | Required | Directory | output_dir | /data/macs3 | 결과 폴더 | Output folder |
| Option | Required | String | genome_size | | MACS3에 넘기는 유효 유전체 크기(-g). hs(사람), mm(쥐), ce(예쁜꼬마선충), dm(초파리) 또는 숫자(예: 애기장대 1.2e8) | Effective genome size passed to MACS3 (-g): hs (human), mm (mouse), ce (C. elegans), dm (fruit fly), or a number (for example 1.2e8 for Arabidopsis) |
| Option | Optional | List | peak_type | narrow | MACS3 peak 모드. narrow(기본): 좁은 peak(.narrowPeak), ATAC-seq은 narrow 사용. broad: 넓은 peak(.broadPeak)를 만들며 broad_cutoff를 함께 사용 | MACS3 peak mode. narrow (default): narrow peaks (.narrowPeak), used for ATAC-seq. broad: broad peaks (.broadPeak), used together with broad_cutoff |
| Option | Optional | String | alignment_suffix | .shifted.bam | 검색할 BAM 파일 이름 끝부분 | BAM file name suffix to search |
| Option | Optional | Float | qvalue | 0.05 | peak로 인정하는 q-value 상한(MACS3 -q). 이보다 작은 구간만 peak. 작을수록 엄격 | Upper q-value for a peak (MACS3 -q); only regions below it are peaks. Smaller is stricter |
| Option | Optional | Float | broad_cutoff | 0.1 | peak_type=broad일 때만 사용(narrow면 무시). 강한 구간 주변의 약한 구간을 이어 붙이는 느슨한 q-value 기준(MACS3 --broad-cutoff)으로, qvalue보다 크거나 같아야 함 | Used only with peak_type=broad (ignored for narrow). Looser q-value for linking weaker nearby regions to strong ones (MACS3 --broad-cutoff); must be at least qvalue |

### 주요 사항
| 국문 | 영문 |
|---|---|
| genome_size는 분석 종에 맞게 입력해야 합니다. 사람 hs, 생쥐 mm, 그 외 종은 유효 유전체 크기를 숫자로 입력합니다(예: 애기장대 약 119000000). | Set genome_size for the species: hs for human, mm for mouse, or the effective genome size as a number for other species (for example about 119000000 for Arabidopsis). |
| FRiP는 ENCODE ATAC-seq 기준 0.3 초과 양호, 0.2 초과 허용입니다. | FRiP above 0.3 is good and above 0.2 is acceptable (ENCODE ATAC-seq). |
| 일부 샘플만 실패하면 경고를 남기고 나머지 결과로 정상 종료합니다. | If only some samples fail, the run warns and finishes with the remaining samples. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/MACS3_callpeak_ATAC_concept.png`

- 레전드(국문): **그림. Peak 검출.** (A) Tn5 보정 BAM의 paired-end fragment를 유전체에 쌓으면, 열린 영역에서 주변 배경(local λ)보다 높은 더미가 생깁니다. (B) 각 위치에서 관찰된 fragment 수를 λ로부터 기대되는 값과 Poisson 분포로 비교해 p-value와 q-value를 구하고, 기준을 넘는 구간을 peak(summit 포함)로 기록합니다. (C) 전체 read 중 peak 안에 들어간 비율(FRiP)로 신호 대 잡음을 평가하며, 샘플별 peak 수와 함께 frip_summary.tsv 표로 남깁니다.
- 레전드(영문): **Figure. Peak calling.** (A) Piling up paired-end fragments from Tn5-shifted BAM files gives stacks above the local background (λ) at open regions. (B) Observed fragment counts are compared with those expected from λ under a Poisson model to obtain p- and q-values, and regions passing the threshold are reported as peaks with their summits. (C) The fraction of reads in peaks (FRiP) measures signal to noise and is written with the peak count per sample to frip_summary.tsv.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
bash MACS3_callpeak_ATAC.1.1.sh \
  input_dir=/data/atac_qc \
  output_dir=/data/macs3 \
  genome_size=1.2e8 \
  peak_type=narrow \
  alignment_suffix=.shifted.bam \
  qvalue=0.05 \
  broad_cutoff=0.1
```

### 주요 결과 이미지

**결과 1. 샘플별 peak 수와 FRiP**
- 결과 파일: 표 캡처 `frip_summary.tsv` (이 모듈은 그림을 만들지 않습니다)
- 레전드(국문): **샘플별 peak 수와 FRiP.** 샘플마다 MACS3로 찾은 peak 수(peaks), 전체 read 수(total_reads), peak 안에 들어간 read 수(reads_in_peaks), 그 비율(FRiP)을 보여 줍니다. FRiP는 신호 대 잡음의 지표로, ENCODE ATAC-seq 기준에서는 0.3 이상이 바람직하고 0.2 이상이면 허용합니다.
- 레전드(영문): **Peak count and FRiP per sample.** For each sample the table lists the number of MACS3 peaks (peaks), total reads (total_reads), reads falling in peaks (reads_in_peaks) and their fraction (FRiP). FRiP is a signal-to-noise measure; the ENCODE ATAC-seq standard prefers 0.3 or higher and accepts 0.2 or higher.

---

## 7. peak_annotation

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | peak_annotation | peak_annotation |
| 서브 타이틀 | Peak 유전체 주석 | Peak annotation |
| 버전 | 1.1 | |
| 카테고리 대분류 | 주석 | Annotation |
| 카테고리 아이콘 | 선택 예정(Annotation 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 유전체 영역 주석 | Genomic Feature Annotation |
| 태그 | ATAC-seq, ChIPseeker, peak annotation, promoter, TSS | |
| 레퍼런스 URL | https://bioconductor.org/packages/ChIPseeker/ | |
| 컨테이너 이미지 | bx_peak_annotation.1.0 | |
| 실행 스크립트 파일 | peak_annotation.1.1.R | |
| Processor Core (제안) | 싱글 코어 | Single core |

### 실행 이미지
이미지: bx_peak_annotation 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_peak_annotation.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| ChIPseeker | 1.46.1 | https://bioconductor.org/packages/ChIPseeker/ |
| GenomicFeatures | 1.62.0 | https://bioconductor.org/packages/GenomicFeatures/ |
| txdbmaker | 1.6.2 | https://bioconductor.org/packages/txdbmaker/ |
| rtracklayer | 1.70.1 | https://bioconductor.org/packages/rtracklayer/ |
| optparse | 1.8.2 | https://cran.r-project.org/package=optparse |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |
| readr | 2.2.0 | https://readr.tidyverse.org/ |
| dplyr | 1.2.1 | https://dplyr.tidyverse.org/ |
| ggupset | 0.4.1 | https://cran.r-project.org/package=ggupset |

- **태그(키워드):** 피크주석, 유전체영역, 프로모터, 유전자주석
- **내용(국문):** peak가 유전체의 어느 영역(promoter, intron, intergenic 등)에 있는지와 가장 가까운 유전자를 붙이는 R 실행 환경입니다. ChIPseeker로 GFF/GTF 유전자 주석을 이용해 peak를 주석하고, 영역 분포와 TSS 주변 분포 그림을 만듭니다.
- **내용(영문):** R runtime environment for annotating where peaks lie in the genome (promoter, intron, intergenic, and so on) and which gene is nearest. ChIPseeker annotates peaks with a GFF/GTF gene annotation and draws the genomic distribution and the distribution around TSSs.

### 내용(국문)
ChIPseeker로 peak를 promoter, exon, intron, intergenic 등 유전체 기능 영역으로 분류하고, 가장 가까운 유전자와 TSS까지의 거리를 붙입니다.
- 유전자 주석(GFF3/GTF)으로 TxDb를 만들어 사용하므로 다양한 종에 적용할 수 있습니다.
- 샘플별 주석표와 기능 영역 분포, TSS 거리 분포 그림을 만듭니다.
- 샘플별 연관 유전자 목록(gene_lists)은 functional_enrichment의 입력으로 사용합니다.

### 내용(영문)
Classifies peaks into genomic features such as promoter, exon, intron, and intergenic with ChIPseeker, and adds the nearest gene and the distance to its TSS.
- A TxDb is built from the gene annotation (GFF3/GTF), so the module works for many species.
- Annotation tables and plots of feature distribution and TSS distance are produced per sample.
- The gene lists per sample are the input of functional_enrichment.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/macs3 | peak 파일 폴더(하위 폴더 포함). peak_suffix로 끝나는 파일(기본 .narrowPeak)을 샘플마다 하나씩 읽음 | Folder of peak files (searched recursively); one file per sample ending in peak_suffix (default .narrowPeak) is read |
| Input | Required | File | genome_gff | /ref/genes.gff3 | 유전자 주석 GFF3/GTF(.gz 가능) | Gene annotation GFF3/GTF (.gz allowed) |
| Output | Required | Directory | output_dir | /data/peak_annotation | 결과 폴더 | Output folder |
| Option | Optional | String | genome_label | custom_genome | 로그와 그림에 쓰는 유전체 이름 | Genome name shown in logs and plots |
| Option | Optional | String | peak_suffix | .narrowPeak | peak 파일 이름 끝부분. broad 모드로 찾은 peak면 .broadPeak | Peak file name ending; .broadPeak for peaks called in broad mode |
| Option | Optional | Integer | tss_upstream | 3000 | 프로모터 상류 범위(bp) | Promoter upstream range (bp) |
| Option | Optional | Integer | tss_downstream | 3000 | 프로모터 하류 범위(bp) | Promoter downstream range (bp) |
| Option | Optional | String | max_files | NA | 처리할 최대 peak 파일 수. NA는 전부 | Maximum number of peak files; NA processes all |

### 주요 사항
| 국문 | 영문 |
|---|---|
| genome_gff는 BAM과 같은 유전체 버전이어야 하고 염색체 이름 표기도 같아야 합니다. | genome_gff must match the genome version and chromosome naming of the BAM files. |
| 유전자 ID는 genome_gff의 ID를 그대로 사용합니다. GO 분석의 OrgDb와 ID 체계가 맞는지 확인해 주세요. | Gene IDs come from genome_gff as is; check that they match the ID type of the OrgDb used for GO analysis. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/peak_annotation_concept.png`

- 레전드(국문): **그림. Peak 주석.** (A) 각 peak를 유전자 구조(promoter, exon, intron, downstream, distal intergenic)에 따라 분류하고, 가장 가까운 유전자와 그 TSS까지의 거리(distanceToTSS)를 붙입니다. 주석은 해당 종의 GFF3/GTF로 만든 TxDb를 사용합니다. (B) 샘플별 기능 영역 peak 비율(막대 하나가 샘플 하나). ATAC-seq peak는 보통 promoter에 많이 모입니다.
- 레전드(영문): **Figure. Peak annotation.** (A) Each peak is classified by gene structure (promoter, exon, intron, downstream, distal intergenic), and the nearest gene and the distance to its TSS (distanceToTSS) are added, using a TxDb built from the species' GFF3/GTF. (B) Fraction of peaks per feature for each sample (one bar per sample); ATAC-seq peaks are typically enriched at promoters.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript peak_annotation.1.1.R \
  input_dir=/data/macs3 \
  genome_gff=/ref/genes.gff3 \
  output_dir=/data/peak_annotation \
  genome_label=TAIR10 \
  peak_suffix=.narrowPeak \
  tss_upstream=3000 \
  tss_downstream=3000 \
  max_files=NA
```

### 주요 결과 이미지
결과 그림 4개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. 샘플별 peak 유전체 영역 분포**
- 결과 파일: `plots/annotation_summary_percent_barplot.pdf`
- 레전드(국문): **샘플별 peak의 유전체 영역 분포.** 막대 하나가 샘플 하나이며, peak가 promoter, UTR, exon, intron, distal intergenic 등 각 유전체 영역에 놓인 비율(%)을 색으로 나누어 보여 줍니다. ATAC-seq peak는 보통 promoter와 intron, distal intergenic에 많이 놓이며, 샘플 간 분포가 비슷한지로 데이터의 일관성을 확인할 수 있습니다.
- 레전드(영문): **Genomic distribution of peaks per sample.** Each bar is one sample, split by colour into the percentage of peaks in promoters, UTRs, exons, introns, distal intergenic regions and other features. ATAC-seq peaks are usually enriched in promoters, introns and distal intergenic regions; similar distributions across samples indicate consistent data.

**결과 2. 겹치는 주석 영역(UpSet)**
- 결과 파일: `plots/<sample>.annotation_upset.pdf` (대표 샘플 1개)
- 레전드(국문): **peak가 동시에 걸치는 유전체 영역(UpSet plot).** peak 하나가 여러 영역(예: promoter이면서 exon)에 함께 걸칠 수 있으므로, 영역 조합별 peak 수를 보여 줍니다. 아래 점과 선은 영역 조합, 위 막대는 그 조합에 속한 peak 수입니다. 결과 1의 막대는 우선순위에 따라 영역 하나만 고른 것이고, 이 그림은 겹침까지 보여 줍니다.
- 레전드(영문): **Overlapping genomic features of peaks (UpSet plot).** A peak can fall in several features at once (for example promoter and exon), so the plot shows peak counts per feature combination: the dots and lines below define the combination and the bars above give its peak count. Result 1 assigns each peak to one feature by priority; this plot shows the overlaps.

**결과 3. TSS까지 거리 분포**
- 결과 파일: `plots/<sample>.distance_to_tss.pdf` (결과 2와 같은 샘플)
- 레전드(국문): **peak에서 가장 가까운 TSS까지의 거리 분포.** 가로 막대는 peak의 비율(%)이며, 거리 구간(0~1 kb, 1~3 kb, 3~5 kb, 5~10 kb, 10~100 kb, 100 kb 이상)별로 색을 나누었습니다. 왼쪽(음수)은 유전자 상류, 오른쪽(양수)은 하류에 놓인 peak다. ATAC-seq peak는 TSS 가까이(0~3 kb)에 많이 모이며, 원거리 peak는 enhancer 같은 조절 부위의 후보입니다.
- 레전드(영문): **Distance from peaks to the nearest TSS.** The horizontal bar gives the percentage of peaks in distance bins (0-1 kb, 1-3 kb, 3-5 kb, 5-10 kb, 10-100 kb, over 100 kb), with upstream peaks to the left (negative) and downstream peaks to the right (positive). ATAC-seq peaks concentrate near TSSs (0-3 kb), and distal peaks are candidates for regulatory elements such as enhancers.

**결과 4. TSS 주변 peak 분포**
- 결과 파일: `plots/<sample>.tss_profile.pdf` (결과 2와 같은 샘플)
- 레전드(국문): **TSS 주변 peak 분포.** 가로축은 TSS 기준 위치(기본 −3,000~+3,000 bp, 옵션 tss_upstream·tss_downstream), 세로축은 그 위치를 덮는 peak의 빈도(Peak Count Frequency)다. ATAC-seq에서는 TSS(0 bp) 바로 위에서 가장 높은 봉우리가 나타나며, 이는 promoter가 열려 있다는 뜻입니다.
- 레전드(영문): **Peak distribution around TSSs.** The x-axis is the position relative to the TSS (−3,000 to +3,000 bp by default; options tss_upstream and tss_downstream) and the y-axis how often peaks cover that position (peak count frequency). ATAC-seq data show the highest peak right at the TSS (0 bp), meaning that promoters are open.

---

## 8. differential_accessibility

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | differential_accessibility | differential_accessibility |
| 서브 타이틀 | 조건 간 차등 접근성 분석 | Differential accessibility |
| 버전 | 1.3 | |
| 카테고리 대분류 | 통계 분석 | Statistical Analysis |
| 카테고리 아이콘 | 선택 예정(Statistical Analysis 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 차등 분석 | Differential Analysis |
| 태그 | ATAC-seq, edgeR, differential accessibility, GC bias, PCA | |
| 레퍼런스 URL | https://bioconductor.org/packages/edgeR/ | |
| 컨테이너 이미지 | bx_differential_accessibility.1.0 | |
| 실행 스크립트 파일 | differential_accessibility.1.3.R | |
| Processor Core (제안) | 싱글 코어 | Single core |

### 실행 이미지
이미지: bx_differential_accessibility 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_differential_accessibility.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| edgeR | 4.8.2 | https://bioconductor.org/packages/edgeR/ |
| limma | 3.66.0 | https://bioconductor.org/packages/limma/ |
| EDASeq | 2.44.0 | https://bioconductor.org/packages/EDASeq/ |
| cqn | 1.56.0 | https://bioconductor.org/packages/cqn/ |
| bamsignals | 1.42.0 | https://bioconductor.org/packages/bamsignals/ |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |
| Hmisc | 5.3-0 | https://cran.r-project.org/package=Hmisc |
| hexbin | 1.28.6 | https://cran.r-project.org/package=hexbin |
| wesanderson | 0.3.7 | https://cran.r-project.org/package=wesanderson |

- **태그(키워드):** 차등접근성, 조건비교, 통계검정, GC보정
- **내용(국문):** 두 조건 사이에 접근성이 달라진 peak를 찾는 R 실행 환경입니다. 샘플별 peak를 합친 공통 peak에서 read 수를 세고, edgeR로 통계 검정을 합니다. GC 함량 편향은 EDASeq와 cqn으로 보정할 수 있으며, PCA와 샘플 상관 그림으로 반복 실험을 확인합니다.
- **내용(영문):** R runtime environment for finding peaks whose accessibility differs between two conditions. Reads are counted in a consensus peak set merged from all samples and tested with edgeR. GC-content bias can be corrected with EDASeq and cqn, and replicates are checked with PCA and sample correlation plots.

### 내용(국문)
두 조건의 공통 peak에서 read 수를 세어 edgeR로 접근성이 증가하거나 감소한 영역을 찾습니다.
- 샘플별 peak를 합쳐 공통 peak 집합을 만들고 peak별 read 수와 GC 비율을 계산합니다.
- filterByExpr로 신호가 낮은 peak를 거르고 TMM으로 정규화한 뒤 quasi-likelihood 검정을 합니다.
- GC 편향을 확인하는 그림을 만들고, 선택적으로 EDASeq와 CQN GC 보정 결과도 계산합니다.
- MDS, MD 그림과 함께 샘플 간 상관 heatmap과 PCA로 반복 실험의 일관성을 확인합니다.
- 결과표는 atac_motif와 functional_enrichment의 입력으로 사용합니다.

### 내용(영문)
Counts reads in consensus peaks of two conditions and finds regions with increased or decreased accessibility with edgeR.
- Sample peaks are merged into a consensus set, and read counts and GC content are computed per peak.
- Low-signal peaks are removed with filterByExpr, libraries are TMM-normalized, and quasi-likelihood tests are run.
- GC bias is checked with plots, and EDASeq and CQN GC-aware normalizations are optional.
- Besides MDS and MD plots, a sample correlation heatmap and PCA show replicate consistency.
- The result tables feed atac_motif and functional_enrichment.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | File | sample_data | /data/da_sample_data.csv | 샘플 정보 CSV(SampleID, Condition). BAM과 peak는 input_dir, peak_dir에서 찾음. CSV 안에 파일 경로(bamReads, Peaks 열)를 적는 방식은 포탈에서 쓸 수 없음(인자로 받은 경로만 컨테이너에 연결됨) | Sample sheet CSV (SampleID, Condition); BAM and peak files are found in input_dir and peak_dir. File paths inside the CSV (bamReads, Peaks columns) cannot be used on the portal, because only paths given as arguments are bound into the container |
| Input | Required | File | genome_fasta | /ref/genome.fa | 참조 유전체 FASTA(peak GC 계산) | Reference genome FASTA (peak GC content) |
| Input | Required | Directory | input_dir | /data/atac_qc | Tn5 보정 BAM 폴더. 파일 이름에 SampleID가 들어 있어야 함. 폴더 안에 03_shifted_bam/이 있으면 그 안에서 찾음 | Folder of Tn5-shifted BAM files whose names contain the SampleID; if it contains 03_shifted_bam/, that subfolder is searched |
| Input | Required | Directory | peak_dir | /data/macs3 | 샘플별 peak 파일(.narrowPeak 또는 .broadPeak, .gz 가능) 폴더. 파일 이름에 SampleID가 들어 있어야 함 | Folder of per-sample peak files (.narrowPeak or .broadPeak, .gz allowed) whose names contain the SampleID |
| Output | Required | Directory | output_dir | /data/da | 결과 폴더 | Output folder |
| Option | Optional | String | control_name | control | 기준(분모) 조건 이름. 샘플 정보의 Condition 값 중 하나와 정확히 같아야 함. logFC = log2(다른 조건 / 기준 조건) | Reference (denominator) condition; must match one Condition value exactly. logFC = log2(other condition / reference) |
| Option | Optional | Float | fdr | 0.05 | 유의 기준 FDR | FDR cutoff |
| Option | Optional | String | gc_bin_chr | | GC 편향 그림에만 쓰는 염색체(분석 결과에는 영향 없음). 비우면 가장 긴 염색체 | Chromosome for the GC-bias plot only (no effect on results); empty uses the longest chromosome |
| Option | Optional | Integer | tile_width | 5000 | GC 편향 그림에만 쓰는 구간 크기(bp, 분석 결과에는 영향 없음) | Bin size for the GC-bias plot only (bp; no effect on results) |
| Option | Optional | List | paired | TRUE | paired-end로 read 계산(TRUE/FALSE) | Count reads as paired-end (TRUE/FALSE) |
| Option | Optional | List | run_edaseq | TRUE | EDASeq GC 보정 실행(TRUE/FALSE) | Run EDASeq GC normalization (TRUE/FALSE) |
| Option | Optional | List | run_cqn | TRUE | CQN GC 보정 실행(TRUE/FALSE) | Run CQN GC normalization (TRUE/FALSE) |

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): SampleID와 Condition 두 열을 적습니다. BAM과 peak 파일은 input_dir과 peak_dir에서 SampleID로 찾습니다. Condition은 정확히 두 종류여야 합니다. 파일 경로를 CSV에 직접 적는 방식(bamReads, Peaks 열)은 포탈에서 쓸 수 없습니다.
- 본문(영문): List the SampleID and Condition columns. BAM and peak files are found by SampleID in input_dir and peak_dir. Condition must have exactly two values. File paths in the CSV (bamReads, Peaks columns) cannot be used on the portal.
- 예시 제목: da_sample_data.csv
- 예시 본문:
```
SampleID,Condition
ctrl_1,control
ctrl_2,control
trt_1,treated
trt_2,treated
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 조건은 두 개만 비교합니다. 기준 조건을 control_name으로 지정해 주세요. logFC가 양수이면 비교 조건에서 더 열린 영역입니다. | Exactly two conditions are compared; set the baseline with control_name. A positive logFC means more accessible in the other condition. |
| 조건마다 반복 실험이 2개 이상이어야 p-value와 FDR을 계산합니다. 반복이 없으면 변화량만 보고합니다. | p-values and FDR need two or more replicates per condition; without replicates only fold changes are reported. |
| PCA는 샘플이 3개 이상일 때 만듭니다. | PCA is produced with three or more samples. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/differential_accessibility_concept.png`

- 레전드(국문): **그림. 차등 접근성 분석.** (A) 샘플별 peak를 합쳐 공통 peak 집합을 만듭니다. (B) 공통 peak마다 조건별 read 수를 세어, 접근성이 증가·유지·감소한 peak를 구분합니다. (C) TMM 정규화와 edgeR quasi-likelihood 검정 결과를 MD plot(가로축 평균 log CPM, 세로축 log-fold-change)으로 보면, 유의하게 증가(up, 빨강)·감소(down, 파랑)한 peak가 드러납니다.
- 레전드(영문): **Figure. Differential accessibility.** (A) Sample peaks are merged into a consensus peak set. (B) Reads are counted per consensus peak and condition, separating peaks that gain, keep, or lose accessibility. (C) After TMM normalization and the edgeR quasi-likelihood test, the MD plot (average log CPM against log-fold-change) shows significantly increased (up, red) and decreased (down, blue) peaks.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript differential_accessibility.1.3.R \
  sample_data=/data/da_sample_data.csv \
  genome_fasta=/ref/genome.fa \
  input_dir=/data/atac_qc \
  peak_dir=/data/macs3 \
  output_dir=/data/da \
  control_name=control \
  fdr=0.05 \
  tile_width=5000 \
  paired=TRUE \
  run_edaseq=TRUE \
  run_cqn=TRUE
```
기본값이 없는 옵션(`gc_bin_chr`)은 필요할 때만 넣습니다.


### 주요 결과 이미지

결과 그림 4개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. PCA**
- 결과 파일: `04_plots/PCA_plot.pdf`
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/differential_accessibility/portal/differential_accessibility_result_1.png`
- 레전드(국문): **샘플 PCA.** 변동이 큰 peak 5,000개의 log2 CPM으로 샘플을 2차원에 놓은 그림입니다. 점 하나가 샘플 하나이고 색은 조건이며, 축 이름에 각 주성분이 설명하는 변동(%)이 붙습니다. 같은 조건의 반복 샘플이 모이고 조건끼리 떨어져 있으면 조건 간 차이가 반복 간 차이보다 큽니다. 샘플이 3개 이상일 때 만듭니다. 예시 데이터에서는 DEX 4개가 한데 모였지만 Mock 4개는 흩어져(PC1 41.3%, PC2 18.5%) 반복 간 차이가 조건 간 차이보다 컸고, 이 때문에 유의한 차등 peak가 적게 나왔습니다.
- 레전드(영문): **Sample PCA.** Samples placed in two dimensions by the log2 CPM of the 5,000 most variable peaks. Each point is a sample coloured by condition, and each axis label gives the variance explained (%). Replicates clustering together and conditions separating mean the condition effect exceeds replicate variation. Drawn with three or more samples. In the example data the four DEX samples cluster while the four Mock samples are scattered (PC1 41.3%, PC2 18.5%), so replicate variation exceeds the condition effect and few differential peaks are found.

**결과 2. 샘플 상관 heatmap**
- 결과 파일: `04_plots/sample_correlation_heatmap.pdf`
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/differential_accessibility/portal/differential_accessibility_result_2.png`
- 레전드(국문): **샘플 간 상관 heatmap.** 모든 샘플 쌍의 Pearson 상관계수(log2 CPM 기준)를 칸마다 숫자와 색(연한 파랑 낮음, 진한 남색 높음)으로 보여 줍니다. 비슷한 샘플끼리 가깝게 놓이도록 계층 군집 순서로 정렬했고, 색 범위는 데이터의 최솟값~최댓값입니다. 같은 조건의 반복끼리 상관이 가장 높아야 하며, 한 샘플만 다른 샘플과 상관이 낮으면 이상 샘플을 의심합니다. 예시 데이터에서는 상관계수가 0.952~0.991로 모두 높았고, Mock의 SRR24197773이 다른 샘플과 가장 낮았습니다.
- 레전드(영문): **Sample correlation heatmap.** Pearson correlation (log2 CPM) for every pair of samples, shown as numbers and colour (light blue low, dark navy high), with samples ordered by hierarchical clustering and the colour scale spanning the data's minimum to maximum. Replicates of a condition should correlate most strongly; one sample with low correlation to all others suggests an outlier. In the example data all correlations are high (0.952-0.991), and Mock sample SRR24197773 has the lowest values.

**결과 3. MD plot**
- 결과 파일: `04_plots/MD_plot.pdf`
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/differential_accessibility/portal/differential_accessibility_result_3.png`
- 레전드(국문): **조건 간 접근성 변화(MD plot).** 점 하나가 peak 하나입니다. 가로축은 평균 접근성(Average log CPM), 세로축은 기준 조건(control_name) 대비 다른 조건의 변화(log-fold-change)이며 점선이 0입니다. 제목의 `groups<조건>`이 비교한 조건입니다. 유의하게(FDR ≤ 0.05) 더 열린 peak는 빨강(Up), 더 닫힌 peak는 파랑(Down), 나머지는 검정(NotSig)입니다. 대부분의 peak가 0 근처에 모이고 유의한 peak가 위아래로 갈라지면 정규화가 잘 된 것입니다. 반복 샘플이 없으면 유의성 없이 fold change만 그립니다. 예시 데이터는 control_name=DEX로 실행해 Mock에서 더 열린 peak 14개(Up)가 나왔고, 닫힌 peak(Down)는 없었습니다.
- 레전드(영문): **Accessibility changes between conditions (MD plot).** Each point is a peak, with mean accessibility (average log CPM) on the x-axis and the change in the other condition relative to the reference (control_name) on the y-axis (log fold change); the dashed line is 0. The title `groups<condition>` names the compared condition. Peaks significantly (FDR ≤ 0.05) more accessible are red (Up), less accessible blue (Down), and the rest black (NotSig). Most peaks centred on 0 with significant peaks splitting above and below indicate good normalization. Without replicates only the fold change is drawn. The example data were run with control_name=DEX, giving 14 peaks more accessible in Mock (Up) and none less accessible (Down).

**결과 4. GC 구간별 logFC**
- 결과 파일: `04_plots/logFC_by_GC_bin_TMM.pdf` (EDASeq·CQN을 실행했으면 `_EDASeq`, `_CQN` 그림과 비교)
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/differential_accessibility/portal/differential_accessibility_result_4.png`
- 레전드(국문): **GC 함량 구간별 log2 fold change.** peak를 GC 함량에 따라 20개 구간으로 나누고(가로축), 구간마다 logFC 분포를 바이올린과 상자 그림으로 보여 줍니다. 점선은 logFC 0이고, 세로축은 −1~1로 잘라 보여 줍니다. 구간별 분포가 모두 0 근처에 있으면 GC 편향이 없는 것이고, GC가 높거나 낮은 쪽으로 갈수록 분포가 한쪽으로 기울면 GC 편향이 있다는 뜻입니다. 이때 EDASeq나 CQN으로 보정한 결과를 씁니다. 예시 데이터(TMM)는 GC가 가장 낮은 구간(0.27 미만)만 약간 음수 쪽으로 치우쳤고 나머지는 0 근처였습니다.
- 레전드(영문): **log2 fold change by GC-content bin.** Peaks are split into 20 bins by GC content (x-axis), and the logFC distribution of each bin is shown as a violin and box plot; the dashed line is logFC 0, and the y-axis is clipped to −1 to 1. Bins all centred on 0 mean no GC bias, while distributions drifting with GC content indicate GC bias, in which case the EDASeq or CQN results should be used. In the example data (TMM) only the lowest-GC bin (below 0.27) leans slightly negative, and the rest are centred on 0.

---

## 9. atac_motif

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | atac_motif | atac_motif |
| 서브 타이틀 | 접근성 변화 연관 모티프 분석 | Motif enrichment by accessibility change |
| 버전 | 1.2 | |
| 카테고리 대분류 | 유전자 조절 | Gene Regulation |
| 카테고리 아이콘 | `docs/category_icons/gene_regulation.png` | |
| 카테고리 중분류 | 모티프 분석 | Motif Analysis |
| 태그 | ATAC-seq, monaLisa, motif enrichment, JASPAR, k-mer | |
| 레퍼런스 URL | https://bioconductor.org/packages/monaLisa/ | |
| 컨테이너 이미지 | bx_atac_motif.1.0 | |
| 실행 스크립트 파일 | atac_motif.1.2.R | |
| Processor Core (제안) | 최대 4코어 (모티프 계산을 여러 코어로 나눔) | Up to 4 cores (motif scoring is parallel) |

그림: `docs/category_icons/gene_regulation.png` (카테고리 아이콘)

### 실행 이미지
이미지: bx_atac_motif 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_atac_motif.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| monaLisa | 1.16.0 | https://bioconductor.org/packages/monaLisa/ |
| TFBSTools | 1.48.0 | https://bioconductor.org/packages/TFBSTools/ |
| universalmotif | 1.28.0 | https://bioconductor.org/packages/universalmotif/ |
| ComplexHeatmap | 2.26.1 | https://bioconductor.org/packages/ComplexHeatmap/ |
| circlize | 0.4.18 | https://cran.r-project.org/package=circlize |
| stabs | 0.7-1 | https://cran.r-project.org/package=stabs |
| glmnet | 5.0 | https://cran.r-project.org/package=glmnet |
| KernSmooth | 2.23-27 | https://cran.r-project.org/package=KernSmooth |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |

- **태그(키워드):** 모티프분석, 전사인자, 서열모티프, 유전자조절
- **내용(국문):** 접근성이 변한 peak에서 많이 나타나는 전사인자 결합 모티프를 찾는 R 실행 환경입니다. monaLisa로 peak를 접근성 변화 크기에 따라 구간으로 나누고, 구간마다 모티프와 k-mer 농축을 계산합니다. 회귀 분석으로 핵심 전사인자 후보를 고르며, peak가 많으면 메모리를 넉넉히 사용합니다.
- **내용(영문):** R runtime environment for finding transcription factor binding motifs that are over-represented in peaks with changed accessibility. monaLisa groups peaks into bins by the size of the change and computes motif and k-mer enrichment per bin. A regression step selects core transcription factor candidates; many peaks need ample memory.

### 내용(국문)
monaLisa로 접근성 변화량(logFC)에 따라 peak를 구간으로 나누고, 구간별로 많이 나타나는 전사인자 모티프를 찾습니다.
- 접근성이 증가한 구간과 감소한 구간에서 농축된 모티프를 heatmap과 seqlogo로 보여 줍니다.
- 선택적으로 k-mer 농축 분석과 randomized lasso 안정성 선택 회귀 분석을 수행합니다.

### 내용(영문)
Bins peaks by accessibility change (logFC) with monaLisa and finds transcription factor motifs enriched in each bin.
- Motifs enriched in bins of increased and decreased accessibility are shown as heatmaps with sequence logos.
- k-mer enrichment and stability-selection regression (randomized lasso) are optional.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/da | 차등 접근성 결과 폴더. 안에 03_results/diff_accessibility_<norm>.csv(열: seqnames, start, end, peakID, logFC, FDR)가 있어야 함 | Differential accessibility result folder containing 03_results/diff_accessibility_<norm>.csv (columns: seqnames, start, end, peakID, logFC, FDR) |
| Input | Required | File | genome_fasta | /ref/genome.fa | 참조 유전체 FASTA(.fai 인덱스가 미리 있어야 함) | Reference genome FASTA (the .fai index must exist) |
| Input | Required | File | motif_db | /ref/motifs.meme | 모티프 데이터베이스(MEME 형식) | Motif database (MEME format) |
| Output | Required | Directory | output_dir | /data/atac_motif | 결과 폴더 | Output folder |
| Option | Optional | List | norm | TMM | input_dir에서 읽을 정규화 결과(TMM, EDASeq, CQN) | Normalization result to read from input_dir (TMM, EDASeq, CQN) |
| Option | Optional | String | chrs | | 사용할 염색체(쉼표 구분). 비우면 자동 | Chromosomes to use (comma-separated); empty selects automatically |
| Option | Optional | Float | fdr_filter | | 이 FDR 이하 peak만 사용. 비우면 필터 없음(권장). monaLisa는 전체 peak를 logFC 순으로 구간에 나눠 비교하므로 보통 비워 둡니다. 값을 넣어 남은 peak가 n_per_bin의 약 2배보다 적으면 구간을 만들 수 없어 이유를 알리고 멈춤 | Use peaks with FDR at or below this; empty applies no filter (recommended). monaLisa compares bins of all peaks ordered by logFC, so this is usually left empty; if fewer than about twice n_per_bin peaks remain, no bins can be made and the run stops with the reason |
| Option | Optional | Integer | n_per_bin | 400 | 구간당 peak 수 | Peaks per bin |
| Option | Optional | Float | min_abs_logfc | 0.3 | 구간 나눌 때 쓰는 최소 abs(logFC) | Minimum abs(logFC) used for binning |
| Option | Optional | Float | padj_cutoff | 4.0 | 강하게 농축된 모티프 기준(−log10 조정 p-value) | Strong enrichment cutoff (−log10 adjusted p-value) |
| Option | Optional | Integer | kmer_len | 6 | k-mer 길이. run_kmer=TRUE일 때만 사용 | k-mer length; used only with run_kmer=TRUE |
| Option | Optional | Float | min_motif_score | 10.0 | 모티프 hit 최소 점수 | Minimum motif hit score |
| Option | Optional | Float | stabsel_cutoff | 0.8 | 안정성 선택 기준(0~1]. run_regression=TRUE일 때만 사용 | Stability selection cutoff (0-1]; used only with run_regression=TRUE |
| Option | Optional | Integer | seed | 123 | 회귀 분석(안정성 선택)을 재현하기 위한 난수 시드. run_regression=TRUE일 때만 사용 | Random seed that makes the regression (stability selection) reproducible; used only with run_regression=TRUE |
| Option | Optional | List | run_kmer | TRUE | k-mer 분석 실행(TRUE/FALSE) | Run k-mer analysis (TRUE/FALSE) |
| Option | Optional | List | run_regression | TRUE | 회귀 분석 실행(TRUE/FALSE) | Run regression analysis (TRUE/FALSE) |

등록 메모: 스레드 수(`threads`)는 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택(싱글 코어 또는 최대 4코어)으로 정해지며, 스크립트 기본값 `auto`가 그 코어 수를 씁니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| 분석 종에 맞는 JASPAR 분류군(척추동물, 식물 등)의 MEME 파일을 사용해 주세요. | Use a MEME file from the JASPAR taxonomic group of the species (vertebrates, plants, and so on). |
| genome_fasta 옆에 .fai 인덱스가 미리 있어야 합니다. | A .fai index must exist beside genome_fasta. |
| 차등 peak가 적으면 구간 수가 줄어 결과가 불안정할 수 있습니다. n_per_bin과 min_abs_logfc를 조정해 주세요. | With few differential peaks the bins are few and results can be unstable; adjust n_per_bin and min_abs_logfc. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/atac_motif_concept.png`

- 레전드(국문): **그림. 모티프 농축 분석.** (A) peak를 접근성 변화량(logFC) 순서로 정렬해 여러 구간(bin)으로 나눕니다. (B) 구간마다 전사인자 모티프의 출현을 셉니다. (C) 모티프×구간 heatmap. 왼쪽부터 모티프 이름과 서열 로고, 농축도(log2 enrichment; 빨강은 농축, 파랑은 결핍), 보정 p-value(−log10; 진할수록 유의)다. 접근성이 증가하거나 감소한 구간에만 농축된 모티프가 변화와 함께 움직이는 전사인자 후보입니다.
- 레전드(영문): **Figure. Motif enrichment.** (A) Peaks are ranked by accessibility change (logFC) and split into bins. (B) Transcription factor motif occurrences are counted per bin. (C) Motif-by-bin heatmap with motif names and sequence logos, log2 enrichment (red enriched, blue depleted) and adjusted p-value (−log10; darker is more significant). Motifs enriched only in bins of increased or decreased accessibility point to candidate factors driving the change.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript atac_motif.1.2.R \
  input_dir=/data/da \
  genome_fasta=/ref/genome.fa \
  motif_db=/ref/JASPAR2024_CORE_plants.meme \
  output_dir=/data/atac_motif \
  norm=TMM \
  n_per_bin=400 \
  min_abs_logfc=0.3 \
  padj_cutoff=4.0 \
  kmer_len=6 \
  min_motif_score=10.0 \
  stabsel_cutoff=0.8 \
  seed=123 \
  run_kmer=TRUE \
  run_regression=TRUE
```
기본값이 없는 옵션(`chrs`, `fdr_filter`)은 필요할 때만 넣습니다.


### 주요 결과 이미지
결과 그림 4개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. 구간별 모티프 농축 heatmap**
- 결과 파일: `02_binned_enrichment/binned_motif_heatmap.pdf`
- 레전드(국문): **접근성 변화 구간별 모티프 농축.** peak를 접근성 변화(log2 fold change) 크기에 따라 여러 구간(bin)으로 나누고, 구간마다 각 전사인자 모티프가 배경보다 얼마나 많은지를 색으로 보여 줍니다. 행은 유의하게 농축된 모티프이며, 서로 비슷한 모티프끼리 묶어 정렬했고 왼쪽에 서열 로고와 GC 비율을 붙였습니다. 첫 heatmap은 농축도(log2 enrichment; 빨강 농축, 파랑 결핍), 둘째는 보정 p-value(−log10; 진할수록 유의)다. 열린 쪽 구간에서만 진하게 나타나는 모티프는 조건 변화로 활성이 커진 전사인자의 후보입니다.
- 레전드(영문): **Motif enrichment across bins of accessibility change.** Peaks are grouped into bins by log2 fold change in accessibility, and the colour shows how strongly each transcription factor motif is enriched in each bin relative to background. Rows are significantly enriched motifs, clustered by motif similarity and shown with sequence logos and GC content. The first heatmap is log2 enrichment (red enriched, blue depleted) and the second the adjusted p-value (−log10; darker is more significant). Motifs enriched only in the gained-accessibility bins point to transcription factors that become more active.

**결과 2. logFC 구간 나누기**
- 결과 파일: `01_qc/bin_density.pdf`
- 레전드(국문): **logFC 분포와 구간(bin).** 모든 peak의 log2 fold change 분포(가로축 logFC, 세로축 밀도) 위에 구간 경계를 색으로 나누어 보여 줍니다. 구간마다 peak 수가 같도록 나누며, 변화가 작은 peak(|logFC| < min_abs_logfc)는 가운데 하나의 구간으로 묶습니다. 결과 1의 heatmap 열이 이 구간입니다.
- 레전드(영문): **logFC distribution and bins.** The distribution of log2 fold change over all peaks (x-axis logFC, y-axis density), coloured by bin. Bins hold equal numbers of peaks, and peaks with small changes (|logFC| < min_abs_logfc) are pooled into one central bin. These bins are the columns of the heatmap in result 1.

**결과 3. 모티프 선택 확률(회귀)**
- 결과 파일: `04_regression/selection_probability.pdf` (run_regression=TRUE일 때)
- 레전드(국문): **안정성 선택 회귀로 고른 전사인자.** 모든 모티프를 함께 넣어 peak의 logFC를 설명하는 회귀(randomized lasso stability selection)에서, 각 모티프가 선택된 확률을 막대로 보여 줍니다. 막대 방향은 그 모티프가 접근성 증가(위)와 감소(아래) 중 어느 쪽과 관련되는지이며, 점선은 선택 기준(stabsel_cutoff, 기본 0.8)입니다. 기준을 넘은 모티프는 비슷한 모티프끼리 겹치는 효과를 걸러낸 뒤에도 남은 핵심 전사인자 후보입니다.
- 레전드(영문): **Transcription factors chosen by stability-selection regression.** In a regression that explains peak logFC with all motifs together (randomized lasso stability selection), the bars show how often each motif was selected. Bar direction shows whether the motif is linked to gained (up) or lost (down) accessibility, and the dashed line is the selection cutoff (stabsel_cutoff, default 0.8). Motifs above the cutoff are core candidates that remain after redundancy between similar motifs is removed.

**결과 4. k-mer와 모티프 유사도**
- 결과 파일: `03_kmer/kmer_motif_similarity.pdf` (run_kmer=TRUE일 때)
- 레전드(국문): **농축된 k-mer와 선택된 모티프의 유사도.** 모티프 데이터베이스와 상관없이 접근성 변화 구간에서 농축된 짧은 서열(k-mer, 기본 6 bp)을 찾고, 결과 1의 유의한 모티프와 얼마나 닮았는지를 색(연회색 0, 주황 0.5, 진한 빨강 1)으로 보여 줍니다. 행은 모티프(왼쪽에 서열 로고), 열은 k-mer다. 데이터베이스 모티프와 닮은 k-mer가 많으면 모티프 결과가 서열 자체에서도 지지된다는 뜻이고, 어느 모티프와도 닮지 않은 k-mer는 데이터베이스에 없는 새 서열 후보입니다.
- 레전드(영문): **Similarity between enriched k-mers and selected motifs.** Short sequences (k-mers, 6 bp by default) enriched across bins of accessibility change are found independently of the motif database and compared with the significant motifs of result 1, with similarity in colour (light grey 0, orange 0.5, dark red 1). Rows are motifs (with sequence logos) and columns are k-mers. Many k-mers resembling database motifs support the motif result from the sequence itself, and k-mers resembling no motif are candidates for sequences missing from the database.

---

## 10. tf_footprinting

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | tf_footprinting | tf_footprinting |
| 서브 타이틀 | 전사인자 footprint 분석 | Transcription factor footprinting |
| 버전 | 1.1 | |
| 카테고리 대분류 | 유전자 조절 | Gene Regulation |
| 카테고리 아이콘 | `docs/category_icons/gene_regulation.png` | |
| 카테고리 중분류 | 전사인자 footprint | TF Footprinting |
| 태그 | ATAC-seq, TOBIAS, footprinting, BINDetect, transcription factor | |
| 레퍼런스 URL | https://github.com/loosolab/TOBIAS | |
| 컨테이너 이미지 | bx_tf_footprinting.1.0 | |
| 실행 스크립트 파일 | tf_footprinting.1.1.sh | |
| Processor Core (제안) | 최대 4코어 (TOBIAS가 여러 코어 사용) | Up to 4 cores (TOBIAS is multi-threaded) |

그림: `docs/category_icons/gene_regulation.png` (카테고리 아이콘)

### 실행 이미지
이미지: bx_tf_footprinting 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_tf_footprinting.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| TOBIAS | 0.17.5 | https://github.com/loosolab/TOBIAS |
| MOODS | 1.9.4.2 | https://github.com/jhkorhonen/MOODS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.24 | https://www.htslib.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |
| bedtools | 2.31.1 | https://bedtools.readthedocs.io/ |

- **태그(키워드):** 전사인자결합, 풋프린팅, 유전자조절, TOBIAS
- **내용(국문):** ATAC-seq 신호에서 전사인자가 실제로 결합한 흔적(footprint)을 찾는 실행 환경입니다. TOBIAS로 Tn5 절단 편향을 보정하고 footprint 점수를 계산한 뒤, 두 조건 사이에 결합이 달라진 전사인자를 찾습니다.
- **내용(영문):** Runtime environment for finding the traces of actual transcription factor binding (footprints) in ATAC-seq signal. TOBIAS corrects the Tn5 cutting bias, scores footprints, and finds transcription factors whose binding differs between two conditions.

### 내용(국문)
TOBIAS로 조건별 Tn5 절단 신호를 보정하고 footprint 점수를 계산한 뒤, BINDetect로 조건 간 전사인자 결합 변화를 비교합니다.
- 조건별로 BAM을 합치고, 샘플 peak를 합친 공통 peak 영역을 사용합니다.
- Tn5 서열 편향을 보정한 신호(ATACorrect)와 footprint 점수(ScoreBigwig)를 bigWig로 저장합니다.
- BINDetect로 모티프별 결합 점수와 조건 간 차이를 표와 그림으로 정리합니다.

### 내용(영문)
Corrects Tn5 cleavage signals per condition with TOBIAS, computes footprint scores, and compares transcription factor binding between conditions with BINDetect.
- BAM files are merged per condition, and a consensus peak set from the sample peaks is used.
- Bias-corrected signals (ATACorrect) and footprint scores (ScoreBigwig) are saved as bigWig.
- BINDetect summarizes binding scores per motif and differences between conditions in tables and plots.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/atac_qc | Tn5 보정 BAM 폴더. 파일 이름에 SampleID가 들어 있어야 함. 폴더 안에 03_shifted_bam/이 있으면 그 안에서 찾음 | Folder of Tn5-shifted BAM files whose names contain the SampleID; if it contains 03_shifted_bam/, that subfolder is searched |
| Input | Required | File | sample_data | /data/sample_data.csv | 샘플 정보 CSV/TSV. SampleID(BAM 파일 이름에 들어 있는 샘플 이름), Condition(조건 이름) 열이 필요하고 조건은 2개 이상. 다른 열(Replicate 등)은 있어도 됨 | Sample sheet CSV/TSV with SampleID (the sample name contained in each BAM file name) and Condition (condition name) columns, two or more conditions; other columns such as Replicate may be present |
| Input | Required | File | genome_fasta | /ref/genome.fa | 참조 유전체 FASTA. .fai가 없으면 FASTA 옆에 만들므로 그 폴더에 쓰기 권한이 필요. 공유 참조는 .fai를 미리 만들어 둘 것(samtools faidx) | Reference genome FASTA. A missing .fai is created beside the FASTA, so the folder must be writable; prepare the .fai in advance for shared references (samtools faidx) |
| Input | Required | File | motif_db | /ref/motifs.meme | 모티프 데이터베이스(MEME/JASPAR 형식) | Motif database (MEME/JASPAR format) |
| Input | Required | Directory | macs_dir | /data/macs3 | 샘플별 peak 파일(*_peaks.narrowPeak, 없으면 *_peaks.broadPeak) 폴더(하위 폴더 포함). 모든 peak를 합쳐 공통 peak를 만듦 | Folder of per-sample peak files (*_peaks.narrowPeak, or *_peaks.broadPeak if none; searched recursively); all peaks are merged into a common peak set |
| Output | Required | Directory | output_dir | /data/tf_footprinting | 결과 폴더 | Output folder |

등록 메모: 코어 수(`cores`)는 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택(싱글 코어 또는 최대 4코어)으로 정해지며, 스크립트 기본값 `auto`가 그 코어 수를 씁니다.

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): 쉼표 또는 탭으로 구분한 파일이며 SampleID와 Condition 컬럼이 필요합니다. Replicate 같은 다른 열은 있어도 됩니다. BAM 파일 이름에 SampleID가 포함되어 있어야 합니다.
- 본문(영문): A comma- or tab-separated file with the SampleID and Condition columns; other columns such as Replicate may be present. Each BAM file name must contain its SampleID.
- 예시 제목: sample_data.csv
- 예시 본문:
```
SampleID,Condition,Replicate
ctrl_1,control,1
ctrl_2,control,2
trt_1,treated,1
trt_2,treated,2
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| footprint는 시퀀싱 깊이가 충분해야 신뢰할 수 있습니다. 조건별로 BAM을 합쳐 깊이를 확보합니다. | Footprints need sufficient sequencing depth; BAM files are merged per condition to gain depth. |
| 조건이 2개 이상이어야 BINDetect 비교를 수행합니다. | BINDetect comparisons need two or more conditions. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/tf_footprinting_concept.png`

- 레전드(국문): **그림. 전사인자 footprint 분석.** (A) 단백질이 결합한 DNA는 Tn5가 자르지 못해, 절단 신호에 움푹 패인 footprint가 생깁니다. (B) 관찰된 절단 신호에서 Tn5 서열 선호도로 예측한 기대 신호를 빼서 편향을 보정합니다(ATACorrect). (C) 조건 간 footprint 점수를 비교해(BINDetect), 결합이 늘거나 준 전사인자를 volcano plot(가로축 differential binding score, 세로축 −log10 p-value)으로 보여 줍니다. 조건 이름을 알파벳순으로 놓았을 때 첫 번째 조건에서 결합이 강하면 양수(빨강), 두 번째 조건에서 강하면 음수(파랑)다. Bentsen M. et al., Nat Commun 11, 4267 (2020), Fig. 1을 수정(CC BY 4.0).
- 레전드(영문): **Figure. Transcription factor footprinting.** (A) DNA bound by a protein is protected from Tn5, leaving a footprint in the cut-site signal. (B) Tn5 sequence bias is corrected by subtracting the cutting expected from Tn5 sequence preference from the observed cut sites (ATACorrect). (C) Footprint scores are compared between conditions (BINDetect), and factors with increased or decreased binding are shown in a volcano plot (differential binding score against −log10 p-value). With the condition names in alphabetical order, positive scores (red) mean stronger binding in the first condition and negative scores (blue) in the second. Adapted from Bentsen M. et al., Nat Commun 11, 4267 (2020), Fig. 1 (CC BY 4.0).
- 출처: Bentsen M, Goymann P, Schultheis H, Klee K, Petrova A, Wiegandt R, Fust A, Preussner J, Kuenne C, Braun T, Kim J, Looso M. ATAC-seq footprinting unravels kinetics of transcription factor binding during zygotic genome activation. *Nat Commun* 11, 4267 (2020). https://doi.org/10.1038/s41467-020-18035-1, Fig. 1을 수정. CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).

### 스크립트 사용 예제
```
bash tf_footprinting.1.1.sh \
  input_dir=/data/atac_qc \
  sample_data=/data/sample_data.csv \
  macs_dir=/data/macs3 \
  genome_fasta=/ref/genome.fa \
  motif_db=/ref/JASPAR2024_CORE_plants.meme \
  output_dir=/data/tf_footprinting
```

### 주요 결과 이미지
결과 그림 2개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. BINDetect volcano plot**
- 결과 파일: `04_BINDetect/bindetect_figures.pdf`의 volcano plot 쪽
- 레전드(국문): **조건 간 전사인자 결합 변화(BINDetect volcano plot).** 점 하나가 전사인자(모티프) 하나입니다. 가로축은 두 조건 사이의 결합 점수 차이(differential binding score)다. 조건 이름을 알파벳순으로 놓았을 때 양수(오른쪽, 빨강)는 첫 번째 조건에서, 음수(왼쪽, 파랑)는 두 번째 조건에서 결합이 더 강하다는 뜻입니다. 세로축은 그 차이의 유의성(−log10 p-value)이며, 변화가 크거나 유의한 전사인자는 색과 이름으로 표시됩니다.
- 레전드(영문): **Differential transcription factor binding between conditions (BINDetect volcano plot).** Each point is one transcription factor motif. The x-axis is the differential binding score between the two conditions; with the condition names in alphabetical order, positive scores (right, red) mean stronger binding in the first condition and negative scores (left, blue) in the second. The y-axis is its significance (−log10 p-value), and factors with large or significant changes are coloured and labelled.

**결과 2. 조건별 footprint 점수 분포**
- 결과 파일: `04_BINDetect/bindetect_figures.pdf`의 점수 분포 쪽(정규화 후, Normalized)
- 레전드(국문): **조건별 footprint 점수 분포.** 모든 모티프 결합 후보 자리의 footprint 점수(가로축) 분포를 조건마다 다른 색의 선으로 겹쳐 보여 줍니다. 같은 PDF에 정규화 전(Raw)과 후(Normalized) 분포가 따로 있으며, BINDetect는 조건 간 점수 분포를 맞춘(정규화한) 뒤 결과 1의 차이를 계산합니다. 정규화 뒤 두 조건의 분포가 거의 겹치면 결과 1의 차이가 전체 신호 세기 차이가 아니라 전사인자별 결합 변화를 반영한다는 뜻입니다.
- 레전드(영문): **Footprint score distribution per condition.** The distribution of footprint scores (x-axis) over all candidate motif sites, one coloured line per condition. The PDF holds the distributions before (raw) and after (normalized) normalization; BINDetect normalizes the score distributions between conditions before computing the differences in result 1. Nearly overlapping distributions after normalization mean that the differences in result 1 reflect factor-specific binding changes rather than overall signal strength.

---

## 11. functional_enrichment

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | functional_enrichment | functional_enrichment |
| 서브 타이틀 | GO 기능 농축 분석 | GO enrichment analysis |
| 버전 | 1.0 | |
| 카테고리 대분류 | 기능 분석 | Functional Analysis |
| 카테고리 아이콘 | 선택 예정(Functional Analysis 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 농축 분석 | Enrichment Analysis |
| 태그 | ATAC-seq, clusterProfiler, GO, enrichment, OrgDb | |
| 레퍼런스 URL | https://bioconductor.org/packages/clusterProfiler/ | |
| 컨테이너 이미지 | bx_functional_enrichment.1.0 | |
| 실행 스크립트 파일 | functional_enrichment.1.0.R | |
| Processor Core (제안) | 싱글 코어 | Single core |

### 실행 이미지
이미지: bx_functional_enrichment 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_functional_enrichment.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| R | 4.5.3 | https://www.r-project.org/ |
| clusterProfiler | 4.18.4 | https://bioconductor.org/packages/clusterProfiler/ |
| enrichplot | 1.30.5 | https://bioconductor.org/packages/enrichplot/ |
| AnnotationDbi | 1.72.0 | https://bioconductor.org/packages/AnnotationDbi/ |
| GO.db | 3.22.0 | https://bioconductor.org/packages/GO.db/ |
| ggplot2 | 4.0.3 | https://ggplot2.tidyverse.org/ |

- **태그(키워드):** 기능분석, GO농축분석, 유전자기능, 유전자온톨로지
- **내용(국문):** peak 근처 유전자들이 어떤 생물학적 기능에 모여 있는지 GO 농축 분석을 하는 R 실행 환경입니다. clusterProfiler로 검정하고, 종별 유전자 주석은 OrgDb 파일로 받아 인터넷 연결 없이 수행합니다.
- **내용(영문):** R runtime environment for GO enrichment analysis of which biological functions the genes near peaks share. clusterProfiler runs the tests, and the species gene annotation is read from an OrgDb file, so the analysis runs without internet access.

### 내용(국문)
열린 영역 또는 접근성이 변한 영역 근처 유전자가 어떤 생물학적 기능(GO)에 몰려 있는지 clusterProfiler로 분석합니다.
- 앞 모듈의 결과 폴더(input_dir)를 받아, 안의 파일을 보고 어떤 결과인지 스스로 판단합니다.
- peak_annotation 결과이면 샘플별 연관 유전자 목록을 분석합니다.
- differential_accessibility 결과이면 peak마다 가장 가까운 유전자를 찾아 접근성 증가(up)·감소(down) 유전자 목록을 분석합니다.
- 종별 OrgDb 파일을 사용하며, 유전자 ID 종류는 자동으로 맞춥니다.
- GO 항목별 결과표와 dotplot, barplot을 만듭니다.

### 내용(영문)
Analyzes with clusterProfiler which biological functions (GO) are enriched among genes near open regions or regions with changed accessibility.
- The output folder of the previous module (input_dir) is read, and its contents tell which module produced it.
- For a peak_annotation output, the gene list of each sample is analyzed.
- For a differential_accessibility output, each peak is assigned to the nearest gene and the up and down gene lists are analyzed.
- An OrgDb file for the species is used, and the gene ID type is matched automatically.
- Result tables per GO term, dot plots, and bar plots are produced.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/peak_annotation | 유전자 목록이 들어 있는 결과 폴더. 안의 파일로 종류를 구분: gene_lists/*.annotated_gene_list.tsv가 있으면 파일마다 유전자 목록 하나, 03_results/diff_accessibility_<da_norm>.csv가 있으면 유의하게 열린(up)·닫힌(down) peak의 가장 가까운 유전자 | Result folder holding gene lists, told apart by its files: with gene_lists/*.annotated_gene_list.tsv each file is one gene list; with 03_results/diff_accessibility_<da_norm>.csv the genes nearest to significantly gained (up) and lost (down) peaks are used |
| Input | Required | File | genome_gff | /ref/genes.gff3 | 유전자 주석 GFF3/GTF. input_dir가 차등 접근성 결과(03_results/…)일 때 peak를 가장 가까운 유전자에 연결하는 데 사용 | Gene annotation GFF3/GTF, used to link peaks to their nearest genes when input_dir holds a differential accessibility result (03_results/…) |
| Input | Required | File | orgdb_file | /ref/OrgDb/Arabidopsis_thaliana.AH121945.OrgDb.sqlite | 분석 종의 OrgDb SQLite 파일(tools/download_orgdb.R로 저장) | OrgDb SQLite file of the species (saved with tools/download_orgdb.R) |
| Output | Required | Directory | output_dir | /data/functional_enrichment | 결과 폴더 | Output folder |
| Option | Optional | List | ont | BP | GO 분류(BP, MF, CC, ALL) | GO ontology (BP, MF, CC, ALL) |
| Option | Optional | String | max_distance_to_tss | 3000 | TSS에서 이 거리(bp) 안의 peak에 연결된 유전자만 사용. NA는 전부 | Use genes whose peak is within this distance of the TSS (bp); NA uses all |
| Option | Optional | String | universe | auto | 배경 유전자(auto, all, 또는 파일 경로) | Background genes (auto, all, or a file path) |
| Option | Optional | Float | pvalue_cutoff | 0.05 | 유의 GO 항목의 조정 p-value(p.adjust) 기준. p_adjust_method로 보정한 값에 적용 | Adjusted p-value (p.adjust) cutoff for significant GO terms, after p_adjust_method |
| Option | Optional | Float | qvalue_cutoff | 0.2 | 유의 GO 항목의 q-value 기준. pvalue_cutoff와 둘 다 만족해야 유의 | q-value cutoff for significant GO terms; a term must pass both this and pvalue_cutoff |
| Option | Optional | List | p_adjust_method | BH | 다중검정 보정(BH, bonferroni, holm, hochberg, hommel, BY, fdr, none) | Multiple testing correction (BH, bonferroni, holm, hochberg, hommel, BY, fdr, none) |
| Option | Optional | Integer | min_gs_size | 10 | GO 항목 최소 유전자 수 | Minimum genes per GO term |
| Option | Optional | Integer | max_gs_size | 500 | GO 항목 최대 유전자 수 | Maximum genes per GO term |
| Option | Optional | Float | min_mapped_fraction | 0.5 | 주석에서 찾은 ID 비율이 이보다 낮으면 중단 | Stop if fewer IDs than this fraction are found in the annotation |
| Option | Optional | Integer | show_category | 20 | 그림에 보일 GO 항목 수 | GO terms shown in plots |
| Option | Optional | List | da_norm | TMM | 차등 접근성 결과에서 읽을 정규화 결과(TMM, EDASeq, CQN). input_dir가 차등 접근성 결과일 때만 사용 | Normalization result read from a differential accessibility result (TMM, EDASeq, CQN); used only when input_dir holds one |
| Option | Optional | Float | da_fdr | 0.05 | up/down peak FDR 기준. input_dir가 차등 접근성 결과일 때만 사용 | FDR cutoff for up/down peaks; used only when input_dir holds a differential accessibility result |
| Option | Optional | Float | da_min_abs_logfc | 0 | up/down peak 최소 abs(logFC). input_dir가 차등 접근성 결과일 때만 사용 | Minimum abs(logFC) for up/down peaks; used only when input_dir holds a differential accessibility result |

등록 메모: OrgDb의 ID 종류(`gene_keytype`)는 포탈에 등록하지 않습니다. 스크립트가 입력 유전자 ID와 가장 많이 맞는 종류(TAIR, ENTREZID, SYMBOL 등)를 자동으로 고릅니다.

### 주요 사항
| 국문 | 영문 |
|---|---|
| 분석 종의 OrgDb 파일(tools/download_orgdb.R로 저장)이 필요합니다. | An OrgDb file for the species (saved with tools/download_orgdb.R) is required. |
| 인터넷 연결 없이 수행하므로 KEGG 경로 분석은 지원하지 않습니다. | The analysis runs offline, so KEGG pathway analysis is not supported. |
| genome_gff의 유전자 ID가 OrgDb에서 절반 이상 찾아지지 않으면 중단합니다. 종과 ID 체계를 확인해 주세요. | The run stops if fewer than half of the genome_gff gene IDs are found in the OrgDb; check the species and ID type. |
| 파이프라인에서 peak_annotation 뒤와 differential_accessibility 뒤에 같은 모듈을 쓰며, 앞 모듈의 output_dir만 input_dir에 연결하면 됩니다. | In the pipeline the same module follows peak_annotation and differential_accessibility; connect the previous module's output_dir to input_dir. |
| 두 입력은 서로 다른 질문에 답합니다. peak_annotation 결과는 샘플마다 열린 peak 근처 유전자 전체(수천~수만 개)가 어떤 기능에 모여 있는지, differential_accessibility 결과는 조건 간에 유의하게 열리거나 닫힌 peak 근처 유전자가 어떤 기능과 관련 있는지를 봅니다. | The two inputs answer different questions: a peak_annotation output asks which functions the genes near each sample's open peaks (thousands of genes) share, and a differential_accessibility output asks which functions the genes near peaks that significantly gained or lost accessibility between conditions relate to. |
| differential_accessibility 결과를 넣었는데 유의한 peak가 적으면(예: 수십 개 이하) 검정할 GO term이 없어 결과가 나오지 않습니다. 이때는 오류가 아니라 경고와 함께 정상 종료하며, 요약표 상태가 no_testable_terms(또는 empty)로 남습니다. peak_annotation 결과를 입력으로 쓰거나 da_fdr을 높여 주세요. | With a differential_accessibility input and few significant peaks (for example a few dozen or fewer), no GO term can be tested and no result is produced. The run then ends normally with a warning, and the summary table shows the status no_testable_terms (or empty). Use a peak_annotation output as input, or raise da_fdr. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/functional_enrichment_concept.png`

- 레전드(국문): **그림. GO 기능 농축 분석.** (A) 각 peak를 가장 가까운 TSS의 유전자에 연결합니다(max_distance_to_tss보다 먼 peak는 제외). 차등 접근성 결과에서는 증가·감소 목록을 따로 만듭니다. (B) 배경 유전자(N) 중 GO 항목(M)에 속하는 유전자가 입력 목록(n)에 k개 이상 나올 확률을 초기하분포로 구하고 다중검정을 보정합니다. (C) 유의한 GO 항목의 dot plot(크기: 유전자 수, 색: 유의성).
- 레전드(영문): **Figure. GO enrichment.** (A) Each peak is linked to the gene with the nearest TSS (peaks beyond max_distance_to_tss are dropped); differential results give separate up and down lists. (B) The probability of observing at least k genes of a GO term (M) in the input list (n) out of the background (N) is computed with the hypergeometric test and adjusted for multiple testing. (C) Dot plot of significant GO terms (size: gene count; color: significance).
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
Rscript functional_enrichment.1.0.R \
  input_dir=/data/da \
  genome_gff=/ref/genes.gff3 \
  orgdb_file=/ref/OrgDb/Arabidopsis_thaliana.AH121945.OrgDb.sqlite \
  output_dir=/data/functional_enrichment \
  ont=BP \
  max_distance_to_tss=3000 \
  universe=auto \
  pvalue_cutoff=0.05 \
  qvalue_cutoff=0.2 \
  p_adjust_method=BH \
  min_gs_size=10 \
  max_gs_size=500 \
  min_mapped_fraction=0.5 \
  show_category=20 \
  da_norm=TMM \
  da_fdr=0.05 \
  da_min_abs_logfc=0
```

### 주요 결과 이미지
결과 그림 3개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. GO 농축 dot plot**
- 결과 파일: `03_plots/<list>.GO_BP.dotplot.pdf` (대표 목록 1개; DA 입력이면 `<da_norm>.up`)
- 레전드(국문): **유전자 목록의 GO 생물학적 과정 농축(dot plot).** 행은 유의하게 농축된 GO term입니다. 가로축은 목록 유전자 중 그 term에 속한 비율(GeneRatio), 점의 크기는 해당 유전자 수(Count), 색은 보정된 p-value(p.adjust; 빨강일수록 유의)다. peak 근처 유전자들이 어떤 생물학적 과정에 모여 있는지를 보여 줍니다.
- 레전드(영문): **GO biological process enrichment of a gene list (dot plot).** Rows are significantly enriched GO terms. The x-axis is the fraction of list genes in each term (GeneRatio), point size is the gene count (Count), and colour is the adjusted p-value (p.adjust; redder is more significant). The plot shows which biological processes the genes near the peaks converge on.

**결과 2. GO 농축 bar plot**
- 결과 파일: `03_plots/<list>.GO_BP.barplot.pdf` (결과 1과 같은 목록)
- 레전드(국문): **유전자 목록의 GO 생물학적 과정 농축(bar plot).** 결과 1과 같은 GO term을 막대로 보여 줍니다. 막대 길이는 그 term에 속한 목록 유전자 수(Count), 색은 보정된 p-value(p.adjust)다. 유전자 수가 많은 term과 유의성이 높은 term을 한눈에 비교할 수 있습니다.
- 레전드(영문): **GO biological process enrichment of a gene list (bar plot).** The same GO terms as result 1 shown as bars, with bar length the number of list genes in the term (Count) and colour the adjusted p-value (p.adjust). It compares terms with many genes and terms with strong significance at a glance.

**결과 3. 목록별 농축 요약**
- 결과 파일: 표 캡처 `04_summary/enrichment_summary.tsv`
- 레전드(국문): **유전자 목록별 농축 요약.** 목록마다 유전자 수(genes), 주석에서 찾은 유전자 수(genes_annotated), 검정한 GO term 수(terms_tested), 유의한 term 수(significant_terms), GO 영역(ont), 사용한 주석 파일(annotation)과 ID 형식(keytype), 처리 상태(status)를 보여 줍니다. genes_annotated가 genes보다 크게 적으면 유전자 ID 형식이 주석과 맞지 않는 것입니다.
- 레전드(영문): **Enrichment summary per gene list.** For each list the table gives the number of genes (genes), genes found in the annotation (genes_annotated), GO terms tested (terms_tested) and significant (significant_terms), the GO ontology (ont), the annotation file (annotation), the ID type (keytype) and the status. genes_annotated far below genes means that the gene ID format does not match the annotation.

---

## 12. replicate_consistency

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | replicate_consistency | replicate_consistency |
| 서브 타이틀 | 반복 실험 peak 재현성(IDR) | Replicate consistency (IDR) |
| 버전 | 1.0 | |
| 카테고리 대분류 | 품질 관리 | Quality Control |
| 카테고리 아이콘 | 선택 예정(Quality Control 아이콘, Shutterstock UniconLabs 선 아이콘 세트에서 고름) | |
| 카테고리 중분류 | 재현성 평가 | Reproducibility |
| 태그 | ATAC-seq, IDR, reproducibility, replicate, MACS3 | |
| 레퍼런스 URL | https://github.com/nboley/idr | |
| 컨테이너 이미지 | bx_replicate_consistency.1.0 | |
| 실행 스크립트 파일 | replicate_consistency.1.0.sh | |
| Processor Core (제안) | 싱글 코어 (MACS3, idr은 1코어로 계산) | Single core (MACS3 and idr run on one core) |

### 실행 이미지
이미지: bx_replicate_consistency 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/ATAC-seq/bx_replicate_consistency.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| IDR | 2.0.4.2 | https://github.com/kundajelab/idr |
| MACS3 | 3.0.4 | https://github.com/macs3-project/MACS |
| Python | 3.13 | https://www.python.org/ |
| SAMtools | 1.23.1 | https://www.htslib.org/ |
| HTSlib | 1.23.1 | https://www.htslib.org/ |

- **태그(키워드):** 재현성분석, 반복실험, IDR, 피크검출
- **내용(국문):** 반복 실험 사이에 peak가 얼마나 재현되는지 IDR로 평가하는 실행 환경입니다. MACS3로 반복 실험마다 느슨한 기준의 peak를 찾고, IDR로 두 반복에서 함께 나타나는 재현성 있는 peak 세트를 고릅니다.
- **내용(영문):** Runtime environment for assessing with IDR how reproducible peaks are between replicates. MACS3 calls relaxed peaks for each replicate, and IDR selects the reproducible peak set shared by two replicates.

### 내용(국문)
ENCODE 방식의 IDR(Irreproducible Discovery Rate)로 반복 실험 사이 peak 재현성을 평가합니다.
- 조건별로 각 반복 실험과 합친 BAM에 대해 MACS3를 느슨한 기준(p-value)으로 실행합니다.
- 반복 실험 쌍마다 IDR을 계산하고, 기준을 통과한 peak를 저장합니다.
- 통과 peak가 가장 많은 쌍을 조건의 재현 peak 세트(conservative peak set)로 정리합니다.

### 내용(영문)
Evaluates peak reproducibility between replicates with the ENCODE-style IDR (Irreproducible Discovery Rate).
- For each condition, MACS3 is run with a relaxed p-value threshold on each replicate and on the pooled BAM.
- IDR is computed for every replicate pair, and peaks passing the threshold are saved.
- The pair with the most passing peaks gives the conservative peak set of the condition.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/atac_qc | Tn5 보정 BAM 폴더(<SampleID><alignment_suffix>). 폴더 안에 03_shifted_bam/이 있으면 그 안에서 찾음. BAM 인덱스(.bai)가 없으면 BAM 옆에 만들므로, 인덱스가 없을 때는 그 폴더에 쓰기 권한이 필요 | Folder of Tn5-shifted BAM files (<SampleID><alignment_suffix>); if it contains 03_shifted_bam/, that subfolder is searched. A missing BAM index (.bai) is built beside the BAM, so the folder must then be writable |
| Input | Required | File | sample_data | /data/sample_data.csv | 샘플 정보 CSV. SampleID(BAM 파일 이름에 들어 있는 샘플 이름), Condition(조건 이름), Replicate(반복 번호) 열이 필요. 조건마다 반복 2개 이상 | Sample sheet CSV with SampleID (the sample name contained in each BAM file name), Condition (condition name), and Replicate (replicate number) columns; two or more replicates per condition |
| Output | Required | Directory | output_dir | /data/replicate_consistency | 결과 폴더 | Output folder |
| Option | Required | String | genome_size | | MACS3에 넘기는 유효 유전체 크기(-g). hs(사람), mm(쥐), ce(예쁜꼬마선충), dm(초파리) 또는 숫자(예: 애기장대 1.2e8) | Effective genome size passed to MACS3 (-g): hs (human), mm (mouse), ce (C. elegans), dm (fruit fly), or a number (for example 1.2e8 for Arabidopsis) |
| Option | Optional | String | alignment_suffix | .shifted.bam | BAM 파일 이름 끝부분 | BAM file name suffix |
| Option | Optional | Float | pvalue | 0.01 | 느슨한 peak 기준(p-value) | Relaxed peak threshold (p-value) |
| Option | Optional | Float | idr_threshold | 0.05 | 재현 peak 기준(global IDR) | Reproducible peak threshold (global IDR) |
| Option | Optional | Integer | max_peaks | 300000 | 반복 실험마다 p-value 순으로 남길 최대 peak 수 | Maximum relaxed peaks kept per replicate, by p-value |

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): 쉼표로 구분한 CSV 파일이며 SampleID, Condition, Replicate 컬럼이 필요합니다. BAM 파일 이름에 SampleID가 포함되어 있어야 자동으로 연결됩니다. 조건마다 반복 실험이 2개 이상이어야 재현성을 계산합니다.
- 본문(영문): A comma-separated CSV with the SampleID, Condition, and Replicate columns. Each BAM file name must contain its SampleID for automatic matching. Each condition needs two or more replicates for the reproducibility analysis.
- 예시 제목: sample_data.csv
- 예시 본문:
```
SampleID,Condition,Replicate
ctrl_1,control,1
ctrl_2,control,2
trt_1,treated,1
trt_2,treated,2
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 조건마다 반복 실험이 2개 이상이어야 합니다. 반복이 1개인 조건은 건너뜁니다. | Each condition needs two or more replicates; conditions with one replicate are skipped. |
| 품질 확인용 모듈이며, 결과 peak를 다른 모듈이 이어받지는 않습니다. | This is a QC module; its peaks are not passed to other modules. |
| 의사 반복(pseudo-replicate) 분석은 수행하지 않습니다. | Pseudo-replicate analysis is not performed. |


### 분석 개념 이미지
그림: `docs/ATAC-seq/modules/figures/module_concepts/replicate_consistency_concept.png`

- 레전드(국문): **그림. 반복 실험 재현성(IDR).** (A) 실제 peak는 두 반복 실험에서 신호 순위가 비슷하지만, 잡음 peak는 순위가 어긋납니다. (B) 두 반복의 peak 순위를 비교해 IDR(Irreproducible Discovery Rate)을 계산합니다. idr 결과 그림의 순위 산점도처럼, 기준(IDR ≤ 0.05)을 통과한 peak(검정)는 신호가 강한 쪽(오른쪽 위)에서 두 반복의 순위가 맞고, 통과하지 못한 peak(빨강)는 흩어집니다. (C) 조건과 반복 쌍별로 느슨한 기준의 peak 수와 IDR 통과 peak 수를 idr_summary.tsv로 남기며, 통과 peak가 가장 많은 쌍을 조건의 대표 peak 세트로 정합니다.
- 레전드(영문): **Figure. Replicate consistency (IDR).** (A) True peaks keep similar signal ranks in two replicates, whereas noise peaks do not. (B) Ranks are compared between replicates to compute the Irreproducible Discovery Rate (IDR). As in the rank scatter of the idr plot, peaks passing IDR ≤ 0.05 (black) agree in rank at the strong end (upper right), while failing peaks (red) scatter. (C) Relaxed and passing peak counts per condition and replicate pair are written to idr_summary.tsv, and the pair with the most passing peaks gives the conservative peak set of the condition.
- 출처: 직접 작성한 모식도(외부 그림 사용 안 함)

### 스크립트 사용 예제
```
bash replicate_consistency.1.0.sh \
  input_dir=/data/atac_qc \
  sample_data=/data/sample_data.csv \
  genome_size=1.2e8 \
  output_dir=/data/replicate_consistency \
  alignment_suffix=.shifted.bam \
  pvalue=0.01 \
  idr_threshold=0.05 \
  max_peaks=300000
```

### 주요 결과 이미지

결과 그림 2개를 아래 순서대로 등록합니다. 결과 1이 대표 그림입니다.

**결과 1. IDR 그림**
- 결과 파일: `02_idr/<condition>/<repA>_vs_<repB>.idr.txt.png` (대표 조건의 반복 쌍 1개. 같은 폴더의 `.noalternatesummitpeaks.png`는 같은 그림입니다)
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/replicate_consistency/portal/replicate_consistency_result_1.png`
- 레전드(국문): **반복 샘플 간 peak 재현성(IDR).** 두 반복 샘플의 peak를 짝지어 비교한 4개 패널입니다. 위 왼쪽(Ranks)은 두 반복에서의 peak 순위(0~1, 1이 가장 강함), 위 오른쪽(Log10 Scores)은 두 반복의 peak 점수(log10)를 서로 대응시킨 산점도이며, 검은 점은 IDR 기준(0.05)을 통과한 재현성 있는 peak, 연한 빨간 점은 통과하지 못한 peak입니다. 아래 두 패널은 각 반복의 peak 순위 구간(가로축)별 −log10 IDR(세로축, 클수록 재현성 높음)입니다. 강한 peak일수록 두 반복에서 함께 나타나 대각선에 모이고, 약한 peak(왼쪽 아래)로 갈수록 흩어집니다. 예시 그림은 DEX 조건의 SRR24197771과 SRR24197791 쌍으로, DEX에서 통과 peak가 가장 많은 쌍(17,504개)입니다.
- 레전드(영문): **Peak reproducibility between replicates (IDR).** Four panels comparing matched peaks of two replicates. Top left (Ranks) and top right (Log10 Scores) plot the peak ranks (0-1, 1 strongest) and log10 scores of the two replicates against each other; black points pass the IDR threshold (0.05) and light red points do not. The bottom panels show −log10 IDR (y-axis, higher is more reproducible) across peak-rank bins (x-axis) of each replicate. Strong peaks appear in both replicates and lie on the diagonal, and weaker peaks (bottom left) scatter. The example shows DEX samples SRR24197771 and SRR24197791, the DEX pair with the most passing peaks (17,504).

**결과 2. 조건별 IDR 요약**
- 결과 파일: 표 `04_summary/idr_summary.tsv`
그림: `release/CLOSHA3/ATAC-seq/2026-10-16/results/replicate_consistency/portal/replicate_consistency_result_2.png`
- 레전드(국문): **조건별 반복 쌍 IDR 요약.** 조건과 반복 쌍마다 각 반복의 peak 수(Peaks A, Peaks B), 두 반복을 합쳐 찾은 peak 수(Pooled peaks), IDR 기준을 통과한 peak 수(IDR passed), 처리 상태(Status)를 보여 줍니다. 조건마다 통과 peak가 가장 많은 쌍이 대표 peak 세트(`03_reproducible_peaks/<condition>.conservative_peaks.narrowPeak`)가 됩니다. 두 반복의 peak 수가 크게 다르거나 통과 peak가 각 반복 peak 수보다 크게 적으면 반복 간 재현성이 낮은 것입니다. 예시 데이터에서는 반복당 약 2만~2만 2,600개 peak 중 Mock 13,053~14,956개(62~72%), DEX 16,940~17,504개(75~79%)가 통과했습니다.
- 레전드(영문): **IDR summary per condition and replicate pair.** For each condition and replicate pair the table gives the peaks in each replicate (Peaks A, Peaks B), the peaks called on the pooled replicates (Pooled peaks), the peaks passing the IDR threshold (IDR passed), and the status. For each condition the pair with the most passing peaks gives the representative peak set (`03_reproducible_peaks/<condition>.conservative_peaks.narrowPeak`). Very different peak counts between replicates, or far fewer passing peaks than each replicate's peaks, indicate poor reproducibility. In the example data, of about 20,000-22,600 peaks per replicate, 13,053-14,956 passed in Mock (62-72%) and 16,940-17,504 in DEX (75-79%).
