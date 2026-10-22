# CNV 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고입니다. 항목 순서는 등록 화면을 따릅니다. 인자 정의는 `docs/CNV/modules/Registration.md`와 같습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받습니다. 등록 화면의 Name은 인자 이름, Value는 기본값입니다.
- 필수(Required) 입력·출력은 Value가 비어 있으면 포탈에 등록되지 않으므로 예시 경로(`/data/…`, `/ref/…`)를 넣었습니다. 기본값이 아니며, 실행할 때 캔버스에서 실제 경로로 바꿉니다. 예시 경로가 그대로 넘어가면 스크립트가 "not found"로 멈춥니다.
- 스레드 수 옵션(`threads`)은 포탈에 등록하지 않습니다. 실행 환경의 Processor Core 선택이 곧 스레드 수입니다(스크립트가 `auto`로 할당된 코어 수를 읽습니다).
- 선택(Optional) 입력은 빈 값이 "사용 안 함"입니다. 경로를 넣어 두면 그 경로를 실제로 찾으므로 Value를 비워 둡니다.
- 스크립트 사용 예제는 등록하는 인자를 모두 적었고, 기본값이 있는 옵션은 기본값으로 적었습니다. 예시 값은 사람 GRCh38 WES 기준입니다.
- 포탈 등록 화면의 기반 이미지 출처(Bootstrap) 칸은 `Apptainer`입니다(작업이 SIF로 실행되므로). 모듈별 "실행 이미지" 절의 DEF Bootstrap(`docker`)은 이미지를 만들 때 쓴 DEF 파일의 값이라 다릅니다. 기반 이미지(From)는 모든 모듈이 Rocky Linux 9.8(`rockylinux/rockylinux:9.8.20260525.0`)입니다.
- CNV 파이프라인은 CLOSHA 3.0에서 처음 배포하므로 모든 모듈의 버전은 1.0입니다.
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지웁니다.
- 카테고리: CLOSHA 프로그램 목록에 복제수 변이 분석에 맞는 중분류가 없어 Omics / Variant_Calling(신규)을 제안합니다. 이름은 CNV만이 아니라 SNV·indel 검출 모듈도 담을 수 있게 일반 이름으로 지었습니다. cnv_summary는 그림과 표를 만드는 모듈이라 기존 Statistics_and_Visualization / Genomic_Visualization에 둡니다.
- 등록 메모: 모듈 개념도는 아직 만들지 않았습니다. `docs/CLOSHA_Figure_Guide_v1.md`에 따라 만든 뒤 각 모듈의 "분석 개념 이미지" 절에 넣습니다.

---

## 1. cnvkit_reference

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | cnvkit_reference | cnvkit_reference |
| 서브 타이틀 | 정상 시료 복제수 기준 만들기 | Copy-number reference from normal samples |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Variant_Calling (신규) | Variant_Calling (new) |
| 태그 | CNV, copy number, CNVkit, reference, WES, WGS, targeted panel | |
| 레퍼런스 URL | https://cnvkit.readthedocs.io/ | |
| 컨테이너 이미지 | bx_cnvkit.1.0 | |
| 실행 스크립트 파일 | cnvkit_reference.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 8GB(WGS는 16GB) | 4 cores, 8 GB of memory (16 GB for WGS) |

### 실행 이미지
이미지: bx_cnvkit 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_cnvkit.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
정상 시료의 BAM에서 커버리지를 구해 CNVkit 기준(reference.cnn)을 만듭니다. 종양의 커버리지를 이 기준과 비교해야 시퀀싱 깊이, GC 함량, 캡처 효율 차이를 빼고 복제수 변화만 볼 수 있습니다.
- WES·캡처 패널(hybrid)은 타깃 영역과 그 사이의 반타깃(off-target) 영역을 bin으로 나누고, WGS는 유전체 전체를, 앰플리콘은 타깃만 bin으로 나눕니다.
- 샘플 시트의 `NormalID`에 적힌 정상 시료를 모두 모아 기준 하나를 만듭니다. 정상 시료가 없으면 모든 bin의 기대값이 같은 flat 기준을 만듭니다(종양만 분석).
- 정상 시료마다 기준 대비 편차(노이즈)를 계산한 QC 표를 만들어, 기준에 넣기 부적절한 정상 시료를 찾을 수 있습니다.
- 결과 폴더는 cnvkit_call 모듈의 기준 폴더(`reference_dir`)로 씁니다.

### 내용(영문)
Builds a CNVkit copy-number reference (reference.cnn) from the coverage of normal BAM files. Comparing tumor coverage with this reference removes differences in sequencing depth, GC content and capture efficiency, so that only copy-number changes remain.
- For WES and capture panels (hybrid), targets and the off-target regions between them are split into bins; WGS uses the whole genome and amplicon panels use the targets only.
- All normal samples named in the `NormalID` column of the sample sheet are pooled into one reference. Without normal samples a flat reference with the same expected coverage in every bin is built (tumor-only analysis).
- A QC table gives the noise of each normal against the reference, so normals unfit for the reference can be found.
- The output folder is the reference folder (`reference_dir`) of the cnvkit_call module.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/bam | 정렬·중복 표시를 마친 BAM과 인덱스(.bai) 폴더(하위 폴더 포함). 파일 이름이 샘플 ID로 시작해야 함 | Folder of coordinate-sorted, duplicate-marked BAM files with .bai indexes (subfolders included); file names start with the sample ID |
| Input | Required | File | sample_data | /data/samples.csv | 샘플 시트(CSV). 열: SampleID(종양), NormalID(짝 정상, 종양만이면 빈칸), Sex(선택). NormalID가 모두 비면 flat 기준 | Sample sheet (CSV) with SampleID (tumor), NormalID (matched normal; empty for tumor-only), and optional Sex. All NormalID empty gives a flat reference |
| Input | Required | File | genome_fasta | /ref/GRCh38.fa | BAM 정렬에 쓴 참조 FASTA. 같은 폴더에 .fai가 있어야 함 | Reference FASTA used for the alignment, with its .fai index beside it |
| Output | Required | Directory | output_dir | /data/cnvkit_reference | 결과 폴더(01_reference/reference.cnn, 타깃·반타깃 BED, 02_normal_coverage/, 03_qc/normal_qc.tsv, 04_metadata/reference_info.tsv) | Output folder (01_reference/reference.cnn, target and antitarget BED, 02_normal_coverage/, 03_qc/normal_qc.tsv, 04_metadata/reference_info.tsv) |
| Option | Optional | List | seq_method | hybrid | 시퀀싱 방식. hybrid = WES·캡처 패널, wgs = 전장 유전체, amplicon = 앰플리콘 패널 | Sequencing type: hybrid = WES or capture panel, wgs = whole genome, amplicon = amplicon panel |
| Input | Optional | File | targets_bed | | 캡처 타깃 BED. hybrid, amplicon이면 필수. wgs에서 비우면 유전체 전체 분석 | Capture target BED; required for hybrid and amplicon. Empty with wgs: the whole genome |
| Input | Optional | File | annotation | | UCSC refFlat 유전자 주석. bin에 유전자 이름을 붙임. 비우면 유전자 이름이 없어 유전자별 표와 유전자 표시가 빔 | UCSC refFlat gene annotation that labels bins with gene names. Empty: no gene names, so gene tables and gene labels stay empty |
| Input | Optional | File | access_bed | | 접근 가능 영역 BED. 비우면 genome_fasta에서 N 구간을 빼고 만듦 | Accessible regions (BED). Empty: computed from genome_fasta without runs of N |
| Option | Optional | String | target_avg_size | auto | 타깃 bin 평균 크기(bp). auto = CNVkit이 정함(wgs는 정상 BAM 깊이로 계산) | Average target bin size (bp); auto lets CNVkit choose (from normal depth for wgs) |
| Option | Optional | String | antitarget_avg_size | auto | 반타깃 bin 평균 크기(bp, hybrid만). auto = CNVkit 기본값 | Average off-target bin size (bp, hybrid only); auto uses the CNVkit default |
| Option | Optional | String | bam_suffix | | 이름이 이 글자로 끝나는 BAM만 사용(예: _marked.bam). 비우면 폴더의 모든 BAM | Only BAM files whose name ends with this text (for example _marked.bam). Empty: every BAM in the folder |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SampleID | 필수 | 종양 시료 ID. BAM 파일 이름이 이 ID로 시작해야 함. 영문, 숫자, `.`, `_`, `-`만 사용 | TUMOR01 |
| NormalID | 필수(열) | 짝 정상 시료 ID. 종양만 분석하면 빈칸 | NORMAL01 |
| Sex | 선택 | female 또는 male. 비우면 커버리지로 추정 | female |

```
SampleID,NormalID,Sex
TUMOR01,NORMAL01,female
TUMOR02,NORMAL02,male
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| 정상 시료는 종양과 같은 캡처 키트, 같은 참조 유전체로 시퀀싱·정렬한 것이어야 합니다. 다른 키트의 정상 시료를 섞으면 기준 노이즈가 커집니다. | Normal samples must use the same capture kit and reference genome as the tumors; mixing normals from other kits makes the reference noisy. |
| hybrid와 amplicon은 targets_bed가 없으면 멈춥니다. 키트 제조사가 준 BED를 BAM과 같은 염색체 이름(chr1 또는 1)으로 맞춰 주세요. | hybrid and amplicon stop without targets_bed. Use the BED from the kit vendor with the same chromosome names as the BAM files (chr1 or 1). |
| 정상 시료가 없으면 flat 기준으로 분석합니다. 이때 복제수 비는 균일한 기대값에 대한 값이라 노이즈가 크고, 캡처 효율 차이가 변화처럼 보일 수 있습니다. | Without normal samples a flat reference is used; copy ratios are then relative to a uniform expectation, are noisier, and capture bias can look like copy changes. |
| `03_qc/normal_qc.tsv`에서 다른 정상보다 노이즈가 크게 높은 시료는 샘플 시트에서 빼고 다시 실행하는 것을 권장합니다. | Normals with much higher noise than the others in `03_qc/normal_qc.tsv` are best removed from the sample sheet before rerunning. |
| annotation을 비우면 bin에 유전자 이름이 붙지 않아, 이후 유전자별 표(genes.tsv)와 관심 유전자 그림이 비게 됩니다. | Without annotation, bins carry no gene names, so the later gene tables (genes.tsv) and gene-of-interest plots stay empty. |

### 분석 개념 이미지
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
python cnvkit_reference.1.0.py \
  input_dir=/data/bam \
  sample_data=/data/samples.csv \
  genome_fasta=/ref/GRCh38.fa \
  output_dir=/data/cnvkit_reference \
  seq_method=hybrid \
  targets_bed=/ref/exome_targets.bed \
  annotation=/ref/refFlat.txt \
  target_avg_size=auto \
  antitarget_avg_size=auto
```

### 주요 결과 이미지
예시 데이터는 SEQC2 기준 세포주 HCC1395(유방암, 종양 WES_IL_T_1)와 HCC1395BL(같은 환자 정상, WES_IL_N_1)의 WES입니다. Codespace 용량 때문에 염색체 6, 13, 17, 18, 21만 잘라 썼고(GRCh38), 타깃은 SureSelect V6+UTR, SNP 위치는 dbSNP b151 common입니다.

**결과 1. 정상 시료 QC 표**
- 결과 파일: `03_qc/normal_qc.tsv` (이 모듈은 그림을 만들지 않으므로 표를 그림으로 만들었습니다)

그림: `docs/CNV/modules/figures/results/cnvkit_reference_result_1.png`

- 레전드(국문): **기준에 넣은 정상 시료의 노이즈.** 정상 시료마다 bin 수(Bins), 기준 대비 bin log2 비의 퍼짐(MAD, IQR, SD)과 상태(Status)를 보여 줍니다. 값이 낮을수록 노이즈가 적고, 정상 시료가 여럿이면 다른 시료보다 크게 높은 시료를 빼는 기준으로 씁니다. 예시 데이터에서는 정상 시료 1개(WES_IL_N_1)로 기준을 만들었고 bin 59,878개, MAD 0.336이었습니다. 타깃 사이의 반타깃 bin은 read가 적어 퍼짐이 커서, 반타깃 bin을 포함한 WES의 MAD는 0.3 안팎이 흔합니다.
- 레전드(영문): **Noise of the normal samples in the reference.** For each normal: number of bins (Bins), spread of bin log2 ratios against the reference (MAD, IQR, SD), and status. Lower values mean less noise; with several normals, a normal much noisier than the others should be left out. In the example data one normal (WES_IL_N_1) built the reference, with 59,878 bins and a MAD of 0.336. Off-target bins between the targets have few reads and spread widely, so a MAD around 0.3 is common for WES including them.

---

## 2. cnv_facets

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | cnv_facets | cnv_facets |
| 서브 타이틀 | 순도·배수성·대립유전자별 복제수 추정 | Purity, ploidy and allele-specific copy number |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Variant_Calling (신규) | Variant_Calling (new) |
| 태그 | CNV, FACETS, tumor purity, ploidy, LOH, allele-specific copy number | |
| 레퍼런스 URL | https://github.com/mskcc/facets | |
| 컨테이너 이미지 | bx_facets.1.0 | |
| 실행 스크립트 파일 | cnv_facets.1.0.R | |
| Processor Core (제안) | 4코어(쌍을 동시에 처리), 메모리 8GB(WGS는 16~32GB) | 4 cores (pairs run in parallel), 8 GB of memory (16-32 GB for WGS) |

### 실행 이미지
이미지: bx_facets 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_facets.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

| 분석도구 | 버전 | 홈페이지 |
|---|---|---|
| FACETS | 0.6.2 | https://github.com/mskcc/facets |
| snp-pileup | 0.6.2 | https://github.com/mskcc/facets |
| R | 4.4.3 | https://www.r-project.org/ |
| HTSlib | 1.24 | https://www.htslib.org/ |

- **태그(키워드):** 종양순도, 배수성, LOH, FACETS
- **내용(국문):** 종양-정상 쌍에서 FACETS로 종양 순도, 배수성, 대립유전자별 복제수(LOH 포함)를 추정하는 실행 환경입니다. snp-pileup으로 SNP 위치의 read 수를 세고, FACETS로 분절과 적합을 합니다. FACETS가 R 4.4까지만 지원해 CNVkit 이미지와 나눴습니다.
- **내용(영문):** Runtime environment for estimating tumor purity, ploidy and allele-specific copy number (including LOH) from tumor-normal pairs with FACETS. snp-pileup counts reads at SNP sites and FACETS segments and fits them. It is separate from the CNVkit image because FACETS supports R up to 4.4.

### 내용(국문)
종양-정상 쌍에서 종양 순도(종양 세포 비율), 배수성(평균 복제수), 구간별 총 복제수와 작은 쪽 대립유전자 복제수를 추정합니다. 순도와 배수성을 알아야 read 깊이의 비를 정수 복제수로 바꿀 수 있고, 작은 쪽 복제수가 0인 구간이 이형접합성 소실(LOH)입니다.
- snp-pileup으로 일반 SNP 위치마다 종양과 정상의 기준·변이 read 수를 셉니다.
- FACETS가 깊이 비(log ratio)와 대립유전자 불균형(BAF)을 함께 분절하고, 순도·배수성과 구간별 복제수를 맞춥니다(EM 적합).
- 샘플별로 FACETS 4단 그림, 대립유전자별 복제수 그림, BAF 그림과 순도·배수성 요약표를 만듭니다.
- 결과 폴더는 cnvkit_call의 `facets_dir`로 써서 CNVkit 결과를 순도·배수성으로 보정하고, cnv_summary의 `facets_dir`로 써서 LOH와 WGD를 요약합니다.

### 내용(영문)
Estimates tumor purity (the fraction of tumor cells), ploidy (the mean copy number), and per segment the total and minor allele copy number from tumor-normal pairs. Purity and ploidy turn depth ratios into integer copy numbers, and segments with a minor copy number of 0 show loss of heterozygosity (LOH).
- snp-pileup counts reference and alternate reads of the tumor and the normal at common SNP sites.
- FACETS segments the depth ratio (log ratio) and allelic imbalance (BAF) jointly and fits purity, ploidy and the copy number of each segment (EM fit).
- Each sample gets the FACETS four-panel plot, an allele-specific copy-number plot, a BAF plot, and a purity and ploidy summary.
- The output folder is the `facets_dir` of cnvkit_call (purity and ploidy correction of the CNVkit result) and of cnv_summary (LOH and WGD summary).

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/bam | 정렬·중복 표시를 마친 BAM과 인덱스(.bai) 폴더(하위 폴더 포함). 파일 이름이 샘플 ID로 시작해야 함 | Folder of coordinate-sorted, duplicate-marked BAM files with .bai indexes (subfolders included); file names start with the sample ID |
| Input | Required | File | sample_data | /data/samples.csv | 샘플 시트(CSV). 열: SampleID(종양), NormalID(짝 정상). NormalID가 빈 행은 건너뜀 | Sample sheet (CSV) with SampleID (tumor) and NormalID (matched normal); rows without NormalID are skipped |
| Input | Required | File | snp_vcf | /ref/dbsnp_common.vcf.gz | 일반 생식세포 SNP 위치 VCF(dbSNP common 등, bgzip 또는 일반 VCF). 염색체 이름이 BAM과 같아야 함 | Common germline SNP sites (VCF, for example dbSNP common; bgzip or plain), with the same chromosome names as the BAM files |
| Output | Required | Directory | output_dir | /data/cnv_facets | 결과 폴더(01_pileup/, 02_segments/<SampleID>.facets_segments.tsv, 03_plots/, 04_summary/facets_summary.tsv) | Output folder (01_pileup/, 02_segments/<SampleID>.facets_segments.tsv, 03_plots/, 04_summary/facets_summary.tsv) |
| Option | Optional | List | genome | hg38 | 유전체 버전(hg38, hg19) | Genome build (hg38, hg19) |
| Option | Optional | Integer | cval | 150 | 본 분절 임계값. 클수록 구간이 적고 굵어짐 | Critical value of the main segmentation; larger gives fewer, longer segments |
| Option | Optional | Integer | pre_cval | 25 | 전처리 분절 임계값(2배체 기준 찾기용) | Critical value of the pre-processing segmentation (finds the diploid level) |
| Option | Optional | Integer | ndepth | 35 | SNP를 쓰는 최소 정상 깊이 | Minimum normal depth for a SNP to be used |
| Option | Optional | Integer | snp_nbhd | 250 | 가까운 SNP를 솎는 창(bp). WES 250, WGS 1000 권장 | SNP thinning window (bp); 250 for WES, 1000 for WGS |
| Option | Optional | Integer | min_map_q | 15 | snp-pileup 최소 mapping quality | Minimum mapping quality in snp-pileup |
| Option | Optional | Integer | min_base_q | 20 | snp-pileup 최소 base quality | Minimum base quality in snp-pileup |
| Option | Optional | Integer | pseudo_snps | 100 | N bp마다 가짜 SNP를 넣어 SNP 사이 커버리지도 셈 | A pseudo SNP every N bp so coverage between SNPs is counted |
| Option | Optional | Float | min_purity | 0.2 | 이보다 낮거나 정할 수 없는 순도는 low_purity 상태로 기록 | Purity below this (or undetermined) gets the status low_purity |
| Option | Optional | Integer | seed | 1234 | 난수 시드(FACETS가 SNP를 무작위로 솎으므로 결과 재현용) | Random seed (FACETS thins SNPs at random) |
| Option | Optional | String | bam_suffix | | 이름이 이 글자로 끝나는 BAM만 사용(예: _marked.bam). 비우면 폴더의 모든 BAM | Only BAM files whose name ends with this text (for example _marked.bam). Empty: every BAM in the folder |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SampleID | 필수 | 종양 시료 ID. BAM 파일 이름이 이 ID로 시작해야 함 | TUMOR01 |
| NormalID | 필수 | 짝 정상 시료 ID. 빈 행은 이 모듈에서 건너뜀 | NORMAL01 |
| Sex | 선택 | 이 모듈은 쓰지 않음(cnvkit_call에서 사용) | female |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 종양과 정상이 짝을 이룬 시료에서만 실행합니다. 종양만 있는 데이터는 이 모듈을 쓰지 않고 cnvkit_call에서 facets_dir를 비워 둡니다. | Runs on tumor-normal pairs only. For tumor-only data, skip this module and leave facets_dir empty in cnvkit_call. |
| snp_vcf의 염색체 이름(chr1 또는 1)과 참조 버전이 BAM과 같아야 합니다. 다르면 SNP가 잡히지 않아 그 쌍은 실패 상태(pileup_failed 또는 fit_failed)로 끝납니다. | The chromosome names (chr1 or 1) and build of snp_vcf must match the BAM files; otherwise no SNP is counted and the pair ends with a failed status (pileup_failed or fit_failed). |
| 순도가 min_purity보다 낮거나 적합이 수렴하지 않으면 오류가 아니라 상태(low_purity, fit_failed)로 기록하고 종료 코드 0으로 끝납니다. 이 샘플은 cnvkit_call에서 보정 없이 처리됩니다. 모든 쌍이 실패할 때만 실패(종료 코드 1)입니다. | Purity below min_purity or a fit that does not converge is recorded as a status (low_purity, fit_failed) with exit code 0, and cnvkit_call then handles the sample without correction. The run fails (exit code 1) only when no pair is fitted. |
| WGS는 snp_nbhd를 1000 정도로 올려 주세요. 기본값 250은 WES 기준이라 WGS에서는 SNP가 너무 많아 시간이 오래 걸립니다. | For WGS raise snp_nbhd to about 1000; the default of 250 suits WES, and WGS then keeps too many SNPs and runs long. |
| 염색체 일부만 분석하면 배수성이 그 염색체들에 치우쳐 추정되어, 같은 비율이 배수 단위로 다른 정수 복제수로 나올 수 있습니다(예: 6/3 대신 4/2). 전체 유전체로 실행해 주세요. | Analysing only some chromosomes biases the ploidy to them, so the same ratios can come out as integer copy numbers off by a multiple (for example 4/2 instead of 6/3). Run on the whole genome. |

### 분석 개념 이미지
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
Rscript cnv_facets.1.0.R \
  input_dir=/data/bam \
  sample_data=/data/samples.csv \
  snp_vcf=/ref/dbsnp_common.vcf.gz \
  output_dir=/data/cnv_facets \
  genome=hg38 \
  cval=150 \
  pre_cval=25 \
  ndepth=35 \
  snp_nbhd=250 \
  min_map_q=15 \
  min_base_q=20 \
  pseudo_snps=100 \
  min_purity=0.2 \
  seed=1234
```

### 주요 결과 이미지
예시 데이터는 SEQC2 기준 세포주 HCC1395(유방암, 종양 WES_IL_T_1)와 HCC1395BL(같은 환자 정상, WES_IL_N_1)의 WES입니다. Codespace 용량 때문에 염색체 6, 13, 17, 18, 21만 잘라 썼고(GRCh38), 타깃은 SureSelect V6+UTR, SNP 위치는 dbSNP b151 common입니다.

**결과 1. 대립유전자별 복제수(대표 그림)**
- 결과 파일: `03_plots/<SampleID>.allele_specific.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnv_facets_result_1.png`

- 레전드(국문): **FACETS로 추정한 구간별 총 복제수와 작은 쪽 복제수.** 검은 선은 총 복제수(Total CN), 주황 선은 작은 쪽 대립유전자 복제수(Minor CN)이고, 분홍 음영은 작은 쪽이 0인 이형접합성 소실(LOH) 구간입니다. 제목에 순도와 배수성이 적힙니다. 염색체는 회색·흰색 띠로 번갈아 구분합니다. 예시 데이터에서는 순도 0.97, 배수성 3.08로 추정되었습니다. 6번 짧은 팔 앞쪽에 복제수 6~9의 증폭, 6번(약 94~106Mb)과 13번(약 52~60Mb)에 복제수 0의 동형 결실, 13번·17번 대부분과 18번 끝에 LOH가 보였습니다. SEQC2 공식 FACETS 결과와 LOH 구간이 98.2% 일치했습니다(길이 기준).
- 레전드(영문): **Total and minor copy number per segment estimated by FACETS.** Black lines are the total copy number (Total CN), orange lines the minor allele copy number (Minor CN), and pink shading marks loss of heterozygosity (LOH, minor = 0). The title gives purity and ploidy; chromosomes alternate gray and white bands. In the example data purity was 0.97 and ploidy 3.08. The start of 6p is amplified (copy number 6-9), chromosome 6 (about 94-106 Mb) and 13 (about 52-60 Mb) carry homozygous deletions (copy number 0), and most of chromosomes 13 and 17 and the end of 18 show LOH. LOH segments agreed 98.2% (by length) with the official SEQC2 FACETS result.

**결과 2. FACETS 4단 그림**
- 결과 파일: `03_plots/<SampleID>.facets_cncf.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnv_facets_result_2.png`

- 레전드(국문): **FACETS 기본 그림.** 위에서부터 (1) 종양/정상 깊이 비(log-ratio, 점은 SNP와 가상 SNP, 빨간 선은 구간 값, 보라 선은 2배체 기준(dipLogR), 초록 선은 전체 중앙값), (2) 대립유전자 불균형(log-odds-ratio, 0에서 멀수록 불균형), (3) 정수 복제수(copy number (em), 검정 총 복제수, 빨강 작은 쪽 복제수), (4) 구간별 종양 세포 분율(cf-em)을 색 막대로 나타낸 것입니다. 점 색은 염색체마다 번갈아 바뀝니다. 예시 데이터에서는 13번과 17번에서 log-odds-ratio가 ±4로 크게 벌어져(LOH) 작은 쪽 복제수가 0이고, 18번 앞쪽과 21번은 0 근처(균형)입니다. 6번과 13번의 동형 결실은 log-ratio가 -2 아래로 떨어진 점으로 보입니다.
- 레전드(영문): **Default FACETS plot.** From the top: (1) tumor/normal depth ratio (log-ratio; points are SNPs and pseudo SNPs, red lines segment values, purple line the diploid level (dipLogR), green line the overall median), (2) allelic imbalance (log-odds-ratio; farther from 0 means more imbalance), (3) integer copy number (copy number (em): black total, red minor), and (4) the cellular fraction per segment (cf-em) as a colour bar. Point colours alternate by chromosome. In the example data the log-odds-ratio of chromosomes 13 and 17 spreads to ±4 (LOH, minor copy number 0), while the start of 18 and chromosome 21 stay near 0 (balanced). The homozygous deletions of chromosomes 6 and 13 show as points below a log-ratio of -2.

**결과 3. 이형접합 SNP의 B-allele 빈도**
- 결과 파일: `03_plots/<SampleID>.baf.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnv_facets_result_3.png`

- 레전드(국문): **정상에서 이형접합인 SNP의 종양 B-allele 빈도(Tumor BAF).** 점선은 0.5입니다. 두 대립유전자가 같으면 0.5에 모이고, 불균형이면 0.5 위아래 두 띠로 갈라지며, 한쪽 대립유전자를 잃으면(LOH) 0과 1로 벌어집니다. 순도가 낮으면 벌어짐이 작아집니다. 예시 데이터(이형접합 SNP 4,489개)에서는 6번 가운데, 13번, 17번, 18번 끝이 0과 1에 붙어 LOH이고, 13번 앞쪽은 0.3/0.7(불균형 gain), 18번 앞쪽과 21번은 0.5(균형)였습니다. 순도가 0.97로 높아 LOH 띠가 거의 0과 1에 닿습니다.
- 레전드(영문): **Tumor B-allele frequency (Tumor BAF) of SNPs heterozygous in the normal.** The dashed line is 0.5. Balanced alleles cluster at 0.5, imbalance splits them into two bands around it, and loss of one allele (LOH) moves them to 0 and 1; low purity narrows the split. In the example data (4,489 heterozygous SNPs) the middle of chromosome 6, chromosome 13, 17 and the end of 18 sit at 0 and 1 (LOH), the start of 13 at 0.3/0.7 (unbalanced gain), and the start of 18 and chromosome 21 at 0.5 (balanced). With a purity of 0.97 the LOH bands nearly reach 0 and 1.

**결과 4. 순도·배수성 요약표**
- 결과 파일: `04_summary/facets_summary.tsv` (표를 그림으로 만들었습니다)

그림: `docs/CNV/modules/figures/results/cnv_facets_result_4.png`

- 레전드(국문): **샘플별 FACETS 적합 결과.** 상태(Status: ok, low_purity, fit_failed, pileup_failed), 순도(Purity), 배수성(Ploidy), 2배체 기준 log 비(DipLogR), 구간 수, 이형접합 SNP 수(HetSNPs), LOH 비율, 변이 유전체 비율(FGA), 전체 유전체 배가(WGD)를 보여 줍니다. Status가 ok가 아니면 그 샘플은 CNVkit 판정에서 보정되지 않습니다. 예시 데이터에서는 ok, 순도 0.966, 배수성 3.08, LOH 비율 0.55, FGA 0.81, WGD yes였습니다. 논문에 보고된 HCC1395 배수성은 2.85이며, 염색체 5개만 써서 조금 높게 추정되었습니다.
- 레전드(영문): **FACETS fit per sample.** Status (ok, low_purity, fit_failed, pileup_failed), Purity, Ploidy, the diploid log ratio (DipLogR), segments, heterozygous SNPs (HetSNPs), LOH fraction, fraction of the genome altered (FGA) and whole-genome doubling (WGD). Samples whose status is not ok are not corrected in the CNVkit calls. In the example data: ok, purity 0.966, ploidy 3.08, LOH fraction 0.55, FGA 0.81, WGD yes. The published HCC1395 ploidy is 2.85; using five chromosomes only gives a slightly higher estimate.

---

## 3. cnvkit_call

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | cnvkit_call | cnvkit_call |
| 서브 타이틀 | 종양 복제수 분절과 판정 | Tumor copy-number segmentation and calling |
| 버전 | 1.0 | |
| 카테고리 대분류 | Omics | Omics |
| 카테고리 중분류 | Variant_Calling (신규) | Variant_Calling (new) |
| 태그 | CNV, CNVkit, copy number, segmentation, amplification, deletion | |
| 레퍼런스 URL | https://cnvkit.readthedocs.io/ | |
| 컨테이너 이미지 | bx_cnvkit.1.0 | |
| 실행 스크립트 파일 | cnvkit_call.1.0.py | |
| Processor Core (제안) | 4코어, 메모리 8GB(WGS는 16GB) | 4 cores, 8 GB of memory (16 GB for WGS) |

### 실행 이미지
이미지: bx_cnvkit 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_cnvkit.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
종양 BAM의 커버리지를 정상 기준과 비교해 복제수 비(log2 ratio)를 구하고, 유전체를 같은 복제수의 구간으로 나눈 뒤 구간과 유전자마다 증폭·결실을 판정합니다.
- CNVkit으로 커버리지, 기준·GC 보정(fix), 분절(segment), 판정(call)을 차례로 합니다.
- FACETS 결과가 있으면 FACETS가 2/1(총 복제수 2, 작은 쪽 1)로 본 구간을 기준점으로 재중심화하고, FACETS 순도로 정수 복제수를 계산합니다. 배수성이 2.7 이상이면 기준 복제수를 4로 봅니다.
- 유전자마다 복제수와 판정(AMP, GAIN, NEUTRAL, LOSS, DEEPDEL)을 표로 만들고, FACETS가 있으면 LOH를 함께 적습니다.
- 샘플별로 유전체 전체 그림, 염색체별 그림, 염색체 모식도, 관심 유전자 확대 그림, 복제수 분포, QC 그림과 IGV용 SEG를 만듭니다. 결과 폴더는 cnv_summary의 입력입니다.

### 내용(영문)
Compares tumor BAM coverage with the normal reference to get copy ratios (log2), splits the genome into segments of equal copy number, and calls amplifications and deletions per segment and gene.
- CNVkit computes coverage, corrects it with the reference and GC content (fix), segments it, and calls it.
- With a FACETS result, the ratios are recentred on the regions FACETS calls 2/1 (total copy number 2, minor 1), and integer copy numbers are computed with the FACETS purity. A ploidy of 2.7 or more sets the baseline copy number to 4.
- A gene table lists the copy number and call (AMP, GAIN, NEUTRAL, LOSS, DEEPDEL) of each gene, with LOH when FACETS is given.
- Each sample gets a genome-wide plot, per-chromosome plots, a chromosome diagram, gene-of-interest zooms, a copy-number distribution, QC plots, and a SEG file for IGV. The output folder is the input of cnv_summary.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/bam | 정렬·중복 표시를 마친 BAM과 인덱스(.bai) 폴더(하위 폴더 포함). 파일 이름이 샘플 ID로 시작해야 함 | Folder of coordinate-sorted, duplicate-marked BAM files with .bai indexes (subfolders included); file names start with the sample ID |
| Input | Required | File | sample_data | /data/samples.csv | 샘플 시트(CSV). 열: SampleID(종양), NormalID, Sex(선택; 비우면 추정). 모든 SampleID를 분석 | Sample sheet (CSV) with SampleID (tumor), NormalID, and optional Sex (empty: inferred); every SampleID is analysed |
| Input | Required | Directory | reference_dir | /data/cnvkit_reference | CNVkit 기준 폴더. 안에 01_reference/reference.cnn과 04_metadata/reference_info.tsv가 있어야 함 | CNVkit reference folder holding 01_reference/reference.cnn and 04_metadata/reference_info.tsv |
| Output | Required | Directory | output_dir | /data/cnvkit_call | 결과 폴더(02_calls/ .cnr·.cns·.call.cns·.seg·.segments.tsv, 03_genes/<SampleID>.genes.tsv, 04_plots/, 05_summary/cnvkit_summary.tsv, all_samples.seg) | Output folder (02_calls/ .cnr, .cns, .call.cns, .seg, .segments.tsv; 03_genes/<SampleID>.genes.tsv; 04_plots/; 05_summary/cnvkit_summary.tsv and all_samples.seg) |
| Input | Optional | Directory | facets_dir | | FACETS 결과 폴더. 안에 04_summary/facets_summary.tsv와 02_segments/<SampleID>.facets_segments.tsv가 있어야 함. 비우면 순도·배수성 보정 없이 판정 | FACETS folder with 04_summary/facets_summary.tsv and 02_segments/<SampleID>.facets_segments.tsv. Empty: calls without purity and ploidy correction |
| Input | Optional | File | genes | | 관심 유전자 목록(한 줄에 하나, 또는 TSV 첫 열). 그림에 이름과 확대 패널을 넣음. 비우면 변화가 큰 유전자를 표시 | Genes of interest (one per line, or the first column of a TSV), labelled and zoomed in the plots. Empty: the most strongly altered genes |
| Option | Optional | List | segment_method | cbs | CNVkit 분절 방법(cbs, hmm, haar) | CNVkit segmentation method (cbs, hmm, haar) |
| Option | Optional | Float | amp_ratio | 2 | 복제수가 기준 복제수의 이 배수 이상이면 AMP | AMP when the copy number is at least this times the baseline |
| Option | Optional | String | bam_suffix | | 이름이 이 글자로 끝나는 BAM만 사용(예: _marked.bam). 비우면 폴더의 모든 BAM | Only BAM files whose name ends with this text (for example _marked.bam). Empty: every BAM in the folder |

### 샘플시트
| 열 | 필수 | 설명 | 예시 |
|---|---|---|---|
| SampleID | 필수 | 종양 시료 ID. 모든 행을 분석 | TUMOR01 |
| NormalID | 필수(열) | 짝 정상 시료 ID. 이 모듈은 기준 폴더를 쓰므로 값은 참고용 | NORMAL01 |
| Sex | 선택 | female 또는 male. 비우면 커버리지로 추정(chrX·chrY 판정에 사용) | female |

### 주요 사항
| 국문 | 영문 |
|---|---|
| reference_dir는 같은 캡처 키트·참조 유전체로 만든 기준이어야 합니다. 다른 키트의 기준을 쓰면 타깃이 맞지 않아 결과가 틀어집니다. | reference_dir must come from the same capture kit and reference genome; a reference from another kit misaligns the targets. |
| FACETS 결과가 없으면 CNVkit 기본 판정(중앙값을 2배체로 가정)을 씁니다. 배수성이 높은 종양에서는 복제수가 실제보다 낮게, 넓은 범위가 결실처럼 보일 수 있습니다. 종양-정상 쌍이면 facets_dir를 함께 주는 것을 권장합니다. | Without FACETS, the default CNVkit call (median assumed diploid) is used; in high-ploidy tumors copy numbers come out too low and wide regions can look deleted. For tumor-normal pairs, giving facets_dir is recommended. |
| 판정은 배수성 대비 상대 판정입니다. 배수성이 2.7 이상이면 기준이 4라서 복제수 3도 LOSS로 판정됩니다. 그림에 기준선(baseline CN)이 함께 그려집니다. | Calls are relative to ploidy: with a ploidy of 2.7 or more the baseline is 4, so a copy number of 3 is a LOSS. The plots show the baseline copy number. |
| 관심 유전자 중 자료에 없는 유전자(예: 타깃에 없는 유전자)는 경고로 알리고 계속합니다(종료 코드 0). | Genes of interest missing from the data (for example outside the targets) are reported as warnings and the run continues (exit code 0). |
| 일부 샘플이 실패해도 나머지를 계속 처리하며, 실패한 샘플은 cnvkit_summary.tsv에 상태로 남습니다. 모든 샘플이 실패할 때만 종료 코드 1입니다. | Failed samples do not stop the others and are listed with their status in cnvkit_summary.tsv; the exit code is 1 only when every sample fails. |

### 분석 개념 이미지
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
python cnvkit_call.1.0.py \
  input_dir=/data/bam \
  sample_data=/data/samples.csv \
  reference_dir=/data/cnvkit_reference \
  output_dir=/data/cnvkit_call \
  facets_dir=/data/cnv_facets \
  genes=/data/genes.txt \
  segment_method=cbs \
  amp_ratio=2
```

### 주요 결과 이미지
예시 데이터는 SEQC2 기준 세포주 HCC1395(유방암, 종양 WES_IL_T_1)와 HCC1395BL(같은 환자 정상, WES_IL_N_1)의 WES입니다. Codespace 용량 때문에 염색체 6, 13, 17, 18, 21만 잘라 썼고(GRCh38), 타깃은 SureSelect V6+UTR, SNP 위치는 dbSNP b151 common입니다.

**결과 1. 유전체 전체 복제수(대표 그림)**
- 결과 파일: `04_plots/<SampleID>.genome_profile.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_1.png`

- 레전드(국문): **FACETS로 보정한 CNVkit 유전체 전체 복제수.** 회색 점은 bin별 복제수 비(Copy ratio (log2, centred)), 굵은 선은 구간 값이며 색은 판정(AMP 진빨강, GAIN 주황, NEUTRAL 회색, LOSS 하늘색, DEEPDEL 파랑)입니다. 오른쪽 축은 순도로 환산한 정수 복제수이고, 점선은 기준 복제수(baseline CN, 배수성 2.7 이상이면 4)입니다. 관심 유전자 이름이 위치에 표시되고, 축 아래로 내려가는 동형 결실은 아래 끝에 그립니다. 예시 데이터에서는 FACETS의 2/1 구간으로 재중심화해(기준점 -0.28) 기준 복제수 4로 판정했습니다. 6번 짧은 팔 gain, 6번과 13번 동형 결실(DEEPDEL), 18번 긴 팔 끝의 복제수 1 손실이 보입니다. 배수성 대비 상대 판정이라 복제수 2~3 구간도 LOSS(하늘색)입니다.
- 레전드(영문): **Genome-wide CNVkit copy number corrected with FACETS.** Gray points are bin copy ratios (Copy ratio (log2, centred)); thick lines are segments coloured by call (AMP dark red, GAIN orange, NEUTRAL gray, LOSS light blue, DEEPDEL blue). The right axis gives the integer copy number from purity, and the dashed line the baseline copy number (4 at a ploidy of 2.7 or more). Genes of interest are labelled at their positions, and homozygous deletions below the axis are drawn at the bottom edge. In the example data the ratios were recentred on the FACETS 2/1 regions (centre -0.28) and called against a baseline of 4: a 6p gain, homozygous deletions (DEEPDEL) on chromosomes 6 and 13, and a copy-number-1 loss at the end of 18q. Calls are relative to ploidy, so segments of copy number 2-3 are LOSS (light blue).

**결과 2. 관심 유전자 확대 그림**
- 결과 파일: `04_plots/<SampleID>.focal_genes.png` (PDF도 있음, genes를 줄 때 그 유전자)

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_2.png`

- 레전드(국문): **관심 유전자 주변 ±2Mb 확대.** 패널마다 유전자 이름, 염색체, 복제수(CN), 판정과 LOH 여부를 제목에 적고, 유전자 위치를 노란 음영으로 표시합니다. x축은 Mb, y축은 log2 복제수 비이고, 점선은 기준 복제수입니다. 예시 데이터(관심 유전자 11개)에서는 TP53 CN 3 LOSS·LOH, ERBB2·BRCA1·NF1 CN 2 LOSS·LOH, ESR1 CN 3 LOSS·LOH, BRCA2·CCND3 CN 5 GAIN, RB1·SMAD4 CN 4 NEUTRAL, RUNX1 CN 2 LOSS였습니다. 고른 염색체에 없는 MYC는 경고로 알리고 그리지 않았습니다. TP53 LOH(3/0)는 SEQC2 공식 결과와 같습니다.
- 레전드(영문): **Zoom of ±2 Mb around genes of interest.** Each panel title gives the gene, chromosome, copy number (CN), call and LOH; the gene is shaded yellow. The x axis is Mb, the y axis the log2 copy ratio, and the dashed line the baseline copy number. In the example data (11 genes of interest): TP53 CN 3 LOSS with LOH, ERBB2, BRCA1 and NF1 CN 2 LOSS with LOH, ESR1 CN 3 LOSS with LOH, BRCA2 and CCND3 CN 5 GAIN, RB1 and SMAD4 CN 4 NEUTRAL, and RUNX1 CN 2 LOSS. MYC, outside the selected chromosomes, was reported as a warning and not drawn. The TP53 LOH (3/0) matches the official SEQC2 result.

**결과 3. 염색체별 복제수**
- 결과 파일: `04_plots/<SampleID>.chromosomes.png` (PDF는 염색체마다 한 쪽)

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_3.png`

- 레전드(국문): **염색체마다 확대한 복제수 비.** 염색체별 패널의 x축은 Mb, y축은 log2 복제수 비이며, 점과 구간 색은 유전체 전체 그림과 같습니다. PNG는 한 장에 모든 염색체를 모은 것이고, PDF는 염색체마다 한 쪽입니다. 예시 데이터에서는 6번의 여러 단계 gain과 동형 결실, 13번 가운데(약 52~60Mb) 동형 결실, 18번 긴 팔의 단계적 손실이 뚜렷합니다.
- 레전드(영문): **Copy ratio zoomed per chromosome.** In each chromosome panel the x axis is Mb and the y axis the log2 copy ratio; point and segment colours are as in the genome-wide plot. The PNG gathers all chromosomes on one page, and the PDF has one page per chromosome. In the example data the stepwise gains and homozygous deletions of chromosome 6, the homozygous deletion in the middle of 13 (about 52-60 Mb), and the stepwise loss along 18q are clear.

**결과 4. 염색체 모식도**
- 결과 파일: `04_plots/<SampleID>.chromosome_diagram.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_4.png`

- 레전드(국문): **염색체 위 판정 구간.** 막대 하나가 염색체 하나이고(x축 Position (Mb)), 구간을 판정 색(AMP, GAIN, LOSS, DEEPDEL)으로 칠합니다. 중립(NEUTRAL) 구간은 연한 회색으로 칠합니다. 한눈에 어느 염색체가 얼마나 변했는지 봅니다. 예시 데이터에서는 6번 짧은 팔의 gain과 작은 AMP, 6번·13번의 DEEPDEL, 17번과 21번 대부분의 LOSS(기준 복제수 4 대비)가 보입니다.
- 레전드(영문): **Called segments on the chromosomes.** Each bar is a chromosome (x axis Position (Mb)), painted with the call colours (AMP, GAIN, LOSS, DEEPDEL); neutral (NEUTRAL) segments are light gray. It shows at a glance how much of each chromosome changed. In the example data the 6p gain with a small AMP, the DEEPDEL regions of chromosomes 6 and 13, and LOSS (against a baseline of 4) over most of 17 and 21 stand out.

**결과 5. 구간 복제수 분포(적합 확인)**
- 결과 파일: `04_plots/<SampleID>.cn_state_hist.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_5.png`

- 레전드(국문): **구간 log2 값의 길이 가중 분포.** x축은 구간 복제수 비(Segment copy ratio (log2, centred)), y축은 그 값을 가진 유전체 길이(Mb)입니다. 주황 점선은 순도·배수성으로 기대되는 정수 복제수(0, 1, 2, …)의 위치입니다. 막대가 점선에 모이면 순도와 기준점이 잘 맞은 것이고, 점선 사이에 넓게 퍼지면 순도·배수성이 맞지 않거나 하위 클론이 있다는 뜻입니다. 예시 데이터에서는 막대가 복제수 1, 2, 4, 5 근처에 모이고, 동형 결실(0) 구간은 점선보다 조금 왼쪽(-5.2)에 있습니다. 2와 3 사이에도 막대가 있어, 일부 구간은 정수 복제수에서 조금 벗어납니다.
- 레전드(영문): **Length-weighted distribution of segment log2 values.** The x axis is the segment copy ratio (Segment copy ratio (log2, centred)), the y axis the genome length (Mb) at that value. Orange dashed lines mark the integer copy numbers (0, 1, 2, ...) expected from purity and ploidy. Bars gathered on the lines mean purity and centre fit well; bars spread between lines point to a poor fit or subclones. In the example data the bars gather near copy numbers 1, 2, 4 and 5, and the homozygous deletions (0) sit slightly left of their line (-5.2); bars between 2 and 3 show some segments off the integer levels.

**결과 6. 품질 확인(QC)**
- 결과 파일: `04_plots/<SampleID>.qc.png` (PDF도 있음), 수치는 `05_summary/cnvkit_summary.tsv`

그림: `docs/CNV/modules/figures/results/cnvkit_call_result_6.png`

- 레전드(국문): **커버리지, GC 편향, 노이즈.** 왼쪽(Coverage)은 bin read 깊이(log10) 분포로 타깃 bin(회색)과 반타깃 bin(하늘색)을 나눠 그립니다. 가운데(GC bias after correction)는 bin GC 비율에 따른 log2 값으로, 주황 중앙값 선이 평평하면 GC 보정이 잘 된 것입니다. 오른쪽(Noise)은 bin log2와 구간 log2의 차이 분포이며 제목의 MAD가 노이즈 지표입니다(±2에서 자름). 예시 데이터에서는 타깃 bin이 반타깃보다 약 100배 깊고, GC 보정 후 중앙값 선이 거의 평평하며, MAD는 0.342였습니다.
- 레전드(영문): **Coverage, GC bias and noise.** Left (Coverage): bin read depth (log10), split into target bins (gray) and off-target bins (light blue). Middle (GC bias after correction): log2 against bin GC fraction; a flat orange median line means GC correction worked. Right (Noise): bin log2 minus segment log2 (clipped at ±2), with the MAD in the title as the noise measure. In the example data target bins are about 100 times deeper than off-target bins, the median line is nearly flat after GC correction, and the MAD is 0.342.

---

## 4. cnv_summary

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | cnv_summary | cnv_summary |
| 서브 타이틀 | 코호트 복제수 요약과 리포트 | Cohort copy-number summary and report |
| 버전 | 1.0 | |
| 카테고리 대분류 | Statistics_and_Visualization | Statistics_and_Visualization |
| 카테고리 중분류 | Genomic_Visualization | Genomic_Visualization |
| 태그 | CNV, cohort, oncoprint, GISTIC2, FGA, LOH, WGD, report | |
| 레퍼런스 URL | https://cnvkit.readthedocs.io/ | |
| 컨테이너 이미지 | bx_cnvkit.1.0 | |
| 실행 스크립트 파일 | cnv_summary.1.0.py | |
| Processor Core (제안) | 싱글 코어, 메모리 8GB | Single core, 8 GB of memory |

### 실행 이미지
이미지: bx_cnvkit 1.0

| 항목 / Item | 값 / Value |
|---|---|
| DEF 파일 | `defs/CNV/bx_cnvkit.1.0.def` |
| DEF Bootstrap | `docker` |
| DEF From | Rocky Linux 9.8 (`rockylinux/rockylinux:9.8.20260525.0`) |
| conda 설치 도구 / installer | Miniforge3 26.7.2-0 (conda-forge, bioconda) |

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

### 내용(국문)
샘플별 복제수 판정 결과를 모아 코호트 수준의 표와 그림, 하나의 HTML 리포트를 만듭니다. 여러 종양에서 반복되는 증폭·결실과 유전체 불안정성을 한눈에 보고, 결과를 IGV와 GISTIC2에 바로 넘길 수 있게 합니다.
- 유전자 × 샘플 판정 행렬(AMP, GAIN, NEUTRAL, LOSS, DEEPDEL)과 관심 유전자 표, 염색체 팔 단위 판정을 만듭니다.
- 샘플마다 변이 유전체 비율(FGA)을 계산하고, FACETS가 있으면 순도, 배수성, LOH 비율, 전체 유전체 배가(WGD)를 더합니다.
- 코호트 heatmap, 위치별 gain·loss 빈도, 팔 단위 heatmap, oncoprint, 불안정성 막대그래프를 그리고, FACETS가 있으면 순도-배수성 산점도와 CNVkit-FACETS 일치 그림을 더합니다.
- 합친 SEG(IGV용)와 GISTIC2 입력 형식 SEG, 모든 그림과 표를 모은 cnv_report.html을 만듭니다.

### 내용(영문)
Collects the per-sample copy-number calls into cohort tables, cohort figures and a single HTML report. Recurrent amplifications and deletions and genome instability across tumors can be seen at a glance, and the results go straight to IGV and GISTIC2.
- Builds a gene × sample call matrix (AMP, GAIN, NEUTRAL, LOSS, DEEPDEL), a gene-of-interest table, and chromosome-arm calls.
- Computes the fraction of the genome altered (FGA) per sample and, with FACETS, adds purity, ploidy, LOH fraction and whole-genome doubling (WGD).
- Draws a cohort heatmap, gain and loss frequency along the genome, an arm-level heatmap, an oncoprint and instability bars, and with FACETS a purity-ploidy scatter and a CNVkit-FACETS concordance plot.
- Writes a merged SEG for IGV, a SEG in GISTIC2 input format, and cnv_report.html with all figures and tables.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | /data/cnvkit_call | CNVkit 판정 결과 폴더. 안에 02_calls/<SampleID>.segments.tsv와 .seg, 03_genes/, 04_plots/, 05_summary/cnvkit_summary.tsv가 있어야 함 | CNVkit call folder holding 02_calls/<SampleID>.segments.tsv and .seg, 03_genes/, 04_plots/, and 05_summary/cnvkit_summary.tsv |
| Output | Required | Directory | output_dir | /data/cnv_summary | 결과 폴더(01_tables/, 02_seg/cohort.seg·gistic_segments.txt, 03_plots/, 04_report/cnv_report.html) | Output folder (01_tables/, 02_seg/cohort.seg and gistic_segments.txt, 03_plots/, 04_report/cnv_report.html) |
| Input | Optional | Directory | facets_dir | | FACETS 결과 폴더. 안에 04_summary/facets_summary.tsv, 02_segments/, 03_plots/가 있어야 함. 비우면 CNVkit 결과만 요약(순도, LOH, WGD, 일치 그림 없음) | FACETS folder with 04_summary/facets_summary.tsv, 02_segments/, and 03_plots/. Empty: CNVkit only (no purity, LOH, WGD, or concordance) |
| Input | Optional | File | genes | | 관심 유전자 목록(한 줄에 하나, 또는 TSV 첫 열). 비우면 자주 변한 유전자 top_genes개를 oncoprint에 넣음 | Genes of interest (one per line, or the first column of a TSV). Empty: the top_genes most frequently altered genes go into the oncoprint |
| Option | Optional | List | genome | hg38 | 내장 UCSC cytoband 표 선택(hg38, hg19). 염색체 팔 경계에 사용 | Bundled UCSC cytoband table (hg38, hg19) for chromosome arms |
| Input | Optional | File | cytoband | | 내장 표 대신 쓸 UCSC cytoBand 파일(일반 또는 .gz). 비우면 genome의 내장 표 사용 | UCSC cytoBand file (plain or .gz) used instead of the bundled one. Empty: the bundled table of genome |
| Option | Optional | Integer | bin_size | 1000000 | 코호트 heatmap, 빈도 그림, 샘플 유사도의 bin 크기(bp) | Bin size (bp) of the cohort heatmap, frequency plot and sample similarity |
| Option | Optional | Integer | top_genes | 30 | genes가 비었을 때 oncoprint에 넣는 유전자 수 | Number of genes in the oncoprint when genes is empty |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 코호트 빈도와 샘플 유사도 그림은 샘플이 많을수록 의미가 있습니다. 샘플 유사도 그림은 샘플이 2개 이상일 때만 만들어집니다. | Cohort frequency and sample similarity are meaningful with many samples; the sample similarity plot is drawn only with two or more samples. |
| 순도-배수성, CNVkit-FACETS 일치 그림과 LOH·WGD 값은 facets_dir를 줄 때만 나옵니다. | The purity-ploidy and CNVkit-FACETS concordance plots and the LOH and WGD values appear only with facets_dir. |
| genome은 BAM의 참조 버전과 맞춰 주세요. 팔 경계가 다른 버전이면 팔 단위 판정이 틀어집니다. 사람이 아닌 종이나 다른 버전은 cytoband에 맞는 파일을 주세요. | Set genome to the build of the BAM files; arm boundaries of another build give wrong arm calls. For other builds give a matching cytoband file. |
| GISTIC2 입력(gistic_segments.txt)은 재중심화한 log2 값입니다. GISTIC2는 이 모듈에서 실행하지 않습니다. | The GISTIC2 input (gistic_segments.txt) holds recentred log2 values; GISTIC2 itself is not run by this module. |

### 분석 개념 이미지
등록 메모: 개념도 작성 예정입니다.

### 스크립트 사용 예제
```
python cnv_summary.1.0.py \
  input_dir=/data/cnvkit_call \
  output_dir=/data/cnv_summary \
  facets_dir=/data/cnv_facets \
  genes=/data/genes.txt \
  genome=hg38 \
  bin_size=1000000 \
  top_genes=30
```

### 주요 결과 이미지
예시 데이터는 SEQC2 기준 세포주 HCC1395(유방암, 종양 WES_IL_T_1)와 HCC1395BL(같은 환자 정상, WES_IL_N_1)의 WES입니다. Codespace 용량 때문에 염색체 6, 13, 17, 18, 21만 잘라 썼고(GRCh38), 타깃은 SureSelect V6+UTR, SNP 위치는 dbSNP b151 common입니다. 샘플이 하나라서 코호트 그림은 그 샘플 하나만 보여 줍니다.

**결과 1. 관심 유전자 판정(oncoprint)**
- 결과 파일: `03_plots/gene_oncoprint.png` (PDF도 있음), 표 `01_tables/interest_genes.tsv`

그림: `docs/CNV/modules/figures/results/cnv_summary_result_1.png`

- 레전드(국문): **관심 유전자 × 샘플 판정 행렬.** 칸 색은 판정(AMP, GAIN, LOSS, DEEPDEL, 회색은 중립)이고, 분홍 점은 FACETS LOH입니다. genes를 비우면 코호트에서 자주 변한 유전자 top_genes개를 보여 줍니다. 예시 데이터에서는 TP53, ERBB2, BRCA1, NF1, ESR1이 LOSS·LOH, RUNX1이 LOSS, BRCA2와 CCND3가 GAIN, RB1과 SMAD4가 중립이었습니다.
- 레전드(영문): **Gene-of-interest × sample call matrix.** Cell colours are calls (AMP, GAIN, LOSS, DEEPDEL; gray neutral), and pink dots mark FACETS LOH. With genes empty, the top_genes most frequently altered genes are shown. In the example data TP53, ERBB2, BRCA1, NF1 and ESR1 are LOSS with LOH, RUNX1 is LOSS, BRCA2 and CCND3 GAIN, and RB1 and SMAD4 neutral.

**결과 2. 코호트 복제수 heatmap**
- 결과 파일: `03_plots/cohort_heatmap.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnv_summary_result_2.png`

- 레전드(국문): **샘플 × 유전체 위치(bin_size, 기본 1Mb) 복제수 heatmap.** 색은 log2 복제수 비(centred)로 빨강이 증가, 파랑이 감소이며 ±1.5에서 자릅니다. 샘플이 여럿이면 비슷한 샘플끼리 묶여 반복되는 변화가 세로 띠로 보입니다. 예시 데이터에서는 6번 짧은 팔과 17번 끝·18번 앞쪽의 증가(빨강), 6번·13번 결실과 18번 끝 손실(파랑)이 보입니다.
- 레전드(영문): **Copy-number heatmap of samples × genome position (bin_size, 1 Mb by default).** Colour is the centred log2 copy ratio, red for increase and blue for decrease, clipped at ±1.5. With several samples, similar samples are grouped and recurrent changes appear as vertical bands. In the example data increases (red) on 6p, the end of 17 and the start of 18, and decreases (blue) at the chromosome 6 and 13 deletions and the end of 18 are visible.

**결과 3. 위치별 gain·loss 빈도**
- 결과 파일: `03_plots/frequency.png` (PDF도 있음)

그림: `docs/CNV/modules/figures/results/cnv_summary_result_3.png`

- 레전드(국문): **유전체 위치별 변화 샘플 비율.** 위쪽은 gain(AMP 포함, 진빨강은 AMP), 아래쪽은 loss(DEEPDEL 포함, 진파랑은 DEEPDEL)인 샘플의 비율(%)입니다. 코호트에서 반복되는 증폭·결실 위치를 찾는 데 씁니다. 예시 데이터는 샘플이 하나라 변화 구간이 모두 100%로 나옵니다.
- 레전드(영문): **Fraction of samples changed at each position.** Above: samples with gain (AMP included, dark red for AMP); below: samples with loss (DEEPDEL included, dark blue for DEEPDEL), in percent. It finds recurrent amplified and deleted positions in a cohort. The example has one sample, so every changed region reaches 100%.

**결과 4. 염색체 팔 단위 판정**
- 결과 파일: `03_plots/arm_heatmap.png` (PDF도 있음), 표 `01_tables/arm_calls.tsv`

그림: `docs/CNV/modules/figures/results/cnv_summary_result_4.png`

- 레전드(국문): **염색체 팔(p, q)마다 gain·loss 판정과 aneuploidy 점수.** 팔 길이의 대부분이 같은 방향으로 변하면 그 팔을 gain(빨강) 또는 loss(파랑)로 판정하고, 회색은 중립, 흰색은 데이터가 덮지 않은 팔입니다. 오른쪽 막대는 변한 팔 수(aneuploidy 점수)입니다. 예시 데이터에서는 6p gain, 6q·13q·17p·17q·18p·21p·21q loss, 18q 중립, 13p는 데이터 없음으로 aneuploidy 점수 8이었습니다. 21p는 GRCh38에 일부 서열과 타깃이 있어 판정되었습니다.
- 레전드(영문): **Gain or loss per chromosome arm (p, q) and the aneuploidy score.** An arm mostly changed in one direction is called gain (red) or loss (blue); gray is neutral and white an arm without data. The bar on the right counts changed arms (aneuploidy score). In the example data 6p is gain, 6q, 13q, 17p, 17q, 18p, 21p and 21q loss, 18q neutral, and 13p without data, giving an aneuploidy score of 8. 21p is called because GRCh38 has some sequence and targets there.

**결과 5. 순도와 배수성**
- 결과 파일: `03_plots/purity_ploidy.png` (PDF도 있음, facets_dir를 줄 때)

그림: `docs/CNV/modules/figures/results/cnv_summary_result_5.png`

- 레전드(국문): **샘플별 FACETS 순도(x축)와 배수성(y축).** 주황 마름모는 전체 유전체 배가(WGD) 추정 샘플, 파란 원은 WGD가 아닌 샘플입니다. 순도가 낮은 샘플은 복제수 판정을 조심해서 해석합니다. 예시 데이터는 순도 0.97, 배수성 3.08로 WGD 샘플입니다.
- 레전드(영문): **FACETS purity (x axis) and ploidy (y axis) per sample.** Orange diamonds are samples with whole-genome doubling (WGD), blue circles samples without. Copy-number calls of low-purity samples need care. The example sample has purity 0.97 and ploidy 3.08 and is a WGD sample.

**결과 6. 유전체 불안정성**
- 결과 파일: `03_plots/instability.png` (PDF도 있음), 표 `01_tables/instability.tsv`

그림: `docs/CNV/modules/figures/results/cnv_summary_result_6.png`

- 레전드(국문): **샘플별 변이 유전체 비율(FGA)과 LOH 비율.** 위는 판정이 중립이 아닌 유전체 비율(Fraction genome altered (FGA)), 아래는 FACETS LOH 비율로, FGA 순으로 정렬합니다. 두 값이 높을수록 유전체가 불안정한 종양입니다. 예시 데이터에서는 FGA 0.84, LOH 비율 0.55였습니다. 배수성 대비 판정이라 기준 복제수 4보다 낮은 넓은 구간이 FGA에 들어갑니다.
- 레전드(영문): **Fraction of the genome altered (FGA) and LOH fraction per sample.** Top: fraction of the genome whose call is not neutral (Fraction genome altered (FGA)); bottom: FACETS LOH fraction; samples are sorted by FGA. Higher values mean a more unstable genome. In the example data FGA was 0.84 and the LOH fraction 0.55; calls are relative to ploidy, so wide regions below the baseline of 4 count towards FGA.

**결과 7. CNVkit과 FACETS 일치율**
- 결과 파일: `03_plots/concordance.png` (PDF도 있음, facets_dir를 줄 때)

그림: `docs/CNV/modules/figures/results/cnv_summary_result_7.png`

- 레전드(국문): **두 방법의 총 복제수가 같은 유전체 길이 비율.** 샘플마다 CNVkit 정수 복제수와 FACETS 총 복제수가 같은 구간의 길이 비율(Length fraction with the same total copy number)입니다. 값이 낮으면 순도·배수성 적합이나 한쪽 방법의 분절을 확인합니다. 예시 데이터에서는 0.83(83.5%)이었습니다.
- 레전드(영문): **Fraction of the genome where both methods give the same total copy number.** For each sample, the length fraction where the CNVkit integer copy number equals the FACETS total copy number (Length fraction with the same total copy number). Low values call for checking the purity and ploidy fit or the segmentation of either method. In the example data it was 0.83 (83.5%).
