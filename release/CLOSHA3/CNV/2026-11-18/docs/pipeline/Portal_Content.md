# Somatic_CNV_Pipeline 포탈 등록 콘텐츠

KOBIC 포탈의 CNV 파이프라인 상세 페이지에 들어갈 국문/영문 원고입니다. 종양-정상 쌍과 종양 단독 분석을 **한 파이프라인**(`Somatic_CNV_Pipeline`)으로 등록합니다(2026-11-17 결정). 샘플 정보 파일의 `NormalID`가 모드를 정합니다: `NormalID`가 있으면 FACETS 순도·배수성 보정까지 하고, 모든 행에서 비어 있으면 cnv_facets가 헤더만 있는 요약표를 쓰고 정상 종료하며 CNVkit은 flat 기준으로 보정 없이 판정합니다. 모듈별 입력·옵션·결과는 `docs/CNV/modules/Registration.md`에 있습니다. 작성 방법은 `docs/CLOSHA_Portal_Guide_v1.md`를 따릅니다.

포탈 스타일: 주 폰트 Pretendard, 포인트 폰트 GmarketSans, 주 폰트 컬러 #222222, 보조 #3A3A3A, 포인트 #32549C, 배경 #FFFFFF.

등록 메모: Reference는 파이프라인 설계에 실제로 참고한 SEQC2 CNV 벤치마크 논문입니다(Masood D. et al., Genome Biol 25, 163 (2024)). 도구 간 차이가 주로 배수성 추정에서 생기고, CNVkit은 알려진 배수성으로 재중심화할 때 결과가 좋아진다는 결론을 따라 FACETS 순도·배수성으로 CNVkit을 보정하도록 구성했습니다.

---

## 0. 파이프라인 등록 항목 / Registration

| 항목 | 값 |
|---|---|
| Pipeline Name | `Somatic_CNV_Pipeline` |
| 구성 모듈 | cnv_facets, cnvkit_reference, cnvkit_call, cnv_summary |
| Version | 1.0 (CLOSHA 3.0 첫 배포) |
| Reference | https://doi.org/10.1186/s13059-024-03294-8 |
| Keyword(태그) | somatic CNV, copy number variation, tumor purity, ploidy, LOH, tumor-only, cancer genomics, WES, WGS |
| 대분류 / 중분류 | 등록 메모: 포탈 파이프라인 목록에서 가장 가까운 것을 고릅니다(후보: Genomics / Variant analysis). |
| 대표 이미지 | 등록 메모: 결과 그림을 본 뒤 고릅니다(후보: cnv_facets allele_specific, cnvkit_call genome_profile). |

## 1. 파이프라인 소개 / Introduction

### 국문
Somatic CNV 파이프라인은 종양 시퀀싱 데이터에서 체세포 복제수 변이(CNV)를 찾는 분석 도구입니다. 같은 환자의 정상 시료가 있으면 종양-정상 쌍으로, 없으면 종양만으로 분석합니다. 중복 표시를 마친 BAM, 참조 유전체, 캡처 타깃 BED, 일반 SNP 목록, 샘플 정보를 입력하면, FACETS로 종양 순도·배수성과 대립유전자별 복제수(LOH 포함)를 추정하고, CNVkit으로 정상 기준 대비 복제수 비를 구한 뒤 FACETS 값으로 보정해 구간과 유전자마다 증폭·결실을 판정합니다. 짝 정상이 없으면 FACETS를 건너뛰고, 같은 키트의 정상 시료 묶음이나 균일한 기대값(flat)으로 만든 기준으로 판정합니다. 마지막으로 코호트 표와 그림, IGV·GISTIC2용 SEG, 모든 결과를 모은 HTML 리포트를 만듭니다.

### English
The Somatic CNV pipeline finds somatic copy-number variations (CNV) in tumor sequencing data. With a normal sample of the same patient it runs as a tumor-normal pair; without one it analyses the tumor alone. From duplicate-marked BAM files, a reference genome, a capture target BED, common SNP sites and sample information, it estimates tumor purity, ploidy and allele-specific copy number (including LOH) with FACETS, computes copy ratios against a normal reference with CNVkit, corrects them with the FACETS values, and calls amplifications and deletions per segment and gene. Without a matched normal, FACETS is skipped and calls are made against a reference built from a pool of normals sequenced with the same kit or from a uniform (flat) expectation. It ends with cohort tables and figures, SEG files for IGV and GISTIC2, and an HTML report of all results.

## 2. 분석 목표 / Analysis goals

### 국문
**체세포 CNV 분석으로 확인할 수 있는 네 가지 분석 목표**

**01 종양 유전체의 어느 구간이 늘거나 줄었는가**
종양의 read 깊이를 정상 기준과 비교해 복제수가 다른 구간으로 나누고, 증폭(AMP, GAIN)과 결실(LOSS, DEEPDEL) 구간을 유전체 전체에서 확인합니다.

**02 종양의 순도와 배수성은 얼마인가**
종양과 정상의 SNP 대립유전자 비율과 깊이 비를 함께 맞춰 종양 세포 비율(순도)과 평균 복제수(배수성), 전체 유전체 배가(WGD) 여부를 추정합니다. 이 값으로 복제수 비를 정수 복제수로 바꿉니다(짝 정상이 있을 때).

**03 어떤 암 관련 유전자가 증폭·결실되었거나 이형접합성을 잃었는가**
관심 유전자마다 복제수와 판정, 이형접합성 소실(LOH)을 표와 확대 그림으로 확인합니다.

**04 여러 종양에서 반복되는 변화와 유전체 불안정성은 어떠한가**
코호트에서 위치별 증폭·결실 빈도, 염색체 팔 단위 변화, 변이 유전체 비율(FGA)과 LOH 비율을 비교합니다.

### English
**Four questions somatic CNV analysis can answer**

**01 Which parts of the tumor genome are gained or lost?**
Tumor read depth is compared with a normal reference and split into segments of different copy number, showing amplified (AMP, GAIN) and deleted (LOSS, DEEPDEL) regions across the genome.

**02 What are the tumor purity and ploidy?**
SNP allele fractions and depth ratios of the tumor and normal are fitted together to estimate the fraction of tumor cells (purity), the mean copy number (ploidy), and whole-genome doubling (WGD). These values turn copy ratios into integer copy numbers (with a matched normal).

**03 Which cancer genes are amplified, deleted, or have lost heterozygosity?**
For each gene of interest, the copy number, the call, and loss of heterozygosity (LOH) are shown in tables and zoomed plots.

**04 Which changes recur across tumors, and how unstable are the genomes?**
Across a cohort, gain and loss frequency along the genome, arm-level changes, the fraction of the genome altered (FGA), and the LOH fraction are compared.

## 3. 분석 흐름 / Analysis workflow

그림: `docs/CNV/pipeline/figures/pipeline.png` (원본 `pipeline.svg`)

### 대체 텍스트 (alt)
- 국문: Somatic CNV 파이프라인 흐름도. BAM에서 FACETS로 순도·배수성·대립유전자별 복제수를, CNVkit으로 정상 기준을 만든 뒤, CNVkit 판정을 FACETS 값으로 보정하고 코호트 요약과 리포트로 이어짐. 짝 정상이 없으면 FACETS 단계는 비고 보정 없이 이어짐.
- English: Somatic CNV pipeline workflow. From BAM files, FACETS estimates purity, ploidy and allele-specific copy number and CNVkit builds a normal reference; CNVkit calls corrected with the FACETS values lead to a cohort summary and report. Without a matched normal the FACETS step is empty and the calls are not corrected.

## 4. 분석 개념 / Analysis concept

그림: `docs/CNV/pipeline/figures/concept.png` (원본 `concept.svg`)

### 국문 (그림 설명)
**그림. 복제수 변이를 읽는 두 가지 신호.** (A) 종양 유전체의 구간마다 두 대립유전자(진한 회색: 많은 쪽, 노랑: 적은 쪽)의 복제 수가 다르며, "총 복제수/적은 쪽 복제수"로 적습니다(예: 3/1은 한쪽 대립유전자만 늘어난 gain, 2/0은 복제수는 같지만 한쪽 대립유전자를 잃은 copy-neutral LOH). (B) CNVkit은 종양의 read 깊이를 정상 기준과 비교한 복제수 비(log2)를 bin(회색 점)마다 구하고, 같은 수준의 구간(선)으로 나눕니다. 2/1 구간이 0이 되도록 기준점을 맞춥니다. (C) FACETS는 정상에서 이형접합인 SNP의 종양 B-allele 빈도(BAF)를 봅니다. 두 대립유전자가 같으면 0.5에 모이고, 불균형이면 두 띠로 갈라지며, 한쪽 대립유전자가 사라진 구간(분홍 음영, LOH)은 0과 1 쪽으로 벌어집니다. 깊이 비만으로는 2/1과 2/0을 구분할 수 없고 BAF가 있어야 구분됩니다. (D) 두 신호를 함께 맞춰 얻은 순도와 배수성으로 구간마다 정수 복제수와 판정(DEEPDEL, LOSS, NEUTRAL, GAIN, AMP)을 정하고, 적은 쪽 복제수가 0이면 LOH로 표시합니다. 색은 결과 그림의 판정 색과 같습니다. 값은 모식적인 값입니다(종양 순도 0.8, 2/1 구간 기준, 기준 복제수 2, AMP는 기준의 2배 이상). 동형 결실(0/0) 구간의 BAF가 0.5 근처에 흩어지는 것은 섞여 있는 정상 세포의 read만 남기 때문입니다. 짝 정상이 없는 종양 단독 분석은 (B)의 깊이 비로 판정하며, (C)의 BAF, 순도·배수성, LOH는 계산하지 않습니다.

### English (figure legend)
**Figure. Two signals that reveal copy-number changes.** (A) In each segment of a tumor genome the two alleles (dark gray: major, yellow: minor) can have different copy numbers, written as "total/minor" (for example 3/1 is a gain of one allele, and 2/0 keeps the copy number but loses one allele: copy-neutral LOH). (B) CNVkit compares tumor read depth with the normal reference to get a copy ratio (log2) per bin (gray points) and splits it into segments of equal level (lines), centred so that the 2/1 state is 0. (C) FACETS looks at the tumor B-allele frequency (BAF) of SNPs heterozygous in the normal. Balanced alleles cluster at 0.5, imbalance splits them into two bands, and segments that lost one allele (pink shading, LOH) move towards 0 and 1. Depth alone cannot tell 2/1 from 2/0; the BAF can. (D) Purity and ploidy fitted from both signals give an integer copy number and a call (DEEPDEL, LOSS, NEUTRAL, GAIN, AMP) per segment, and a minor copy number of 0 is marked as LOH. Colours match the calls in the result plots. Values are schematic (tumor purity 0.8, centred on the 2/1 state, baseline copy number 2, AMP at twice the baseline or more). The BAF of the homozygous deletion (0/0) scatters around 0.5 because only reads of admixed normal cells remain. A tumor-only run calls from the depth ratio in (B); without a matched normal, the BAF in (C), purity, ploidy and LOH are not computed.

### 대체 텍스트 (alt)
- 국문: 복제수 변이 개념도. 구간별 대립유전자 상태, CNVkit 깊이 비, FACETS B-allele 빈도, 정수 복제수와 판정·LOH를 위아래로 맞춰 보여 줌.
- English: Concept of copy-number analysis: allele states per segment aligned with the CNVkit depth ratio, the FACETS B-allele frequency, and the integer copy number with calls and LOH.

### 출처 / Reference
직접 작성한 모식도(외부 그림 사용 안 함)

## 5. 주요 사항 (파이프라인) / Key notes (pipeline)

### 국문
1. **사람 유전체만 지원합니다.** 기본은 GRCh38(hg38)이며 hg19도 쓸 수 있습니다. BAM, 참조 FASTA, 타깃 BED, SNP VCF, 유전자 주석이 모두 같은 버전이고 염색체 이름 표기도 같아야 합니다(`chr1`과 `1`은 서로 다름).
2. **입력은 정렬과 중복 표시를 마친 종양·정상 BAM과 인덱스(.bai)입니다.** 사람 암 유전체는 BWA-MEM 계열로 정렬한 BAM을 권장합니다. BAM 파일 이름은 샘플 ID로 시작해야 합니다.
3. **샘플 정보 파일(CSV)에 `SampleID`(종양)와 `NormalID`(짝 정상)를 적어 주세요.** 짝 정상이 없으면 `NormalID`를 비웁니다. 모든 행이 비면 종양 단독 분석이 되어 FACETS를 건너뛰고, 순도·배수성 보정과 LOH 없이 CNVkit 판정만 냅니다. 같은 키트로 시퀀싱한 정상 시료 묶음이 있으면 짝이 아니어도 기준으로 쓸 수 있습니다. `Sex`(female, male)는 선택이며 비우면 커버리지로 추정합니다.
4. **WES·타깃 패널은 캡처 키트의 타깃 BED가 필요합니다.** 정상 기준에 쓰는 정상 시료는 종양과 같은 키트로 시퀀싱한 것이어야 합니다.
5. **일반 SNP 위치 VCF(dbSNP common 등)가 필요합니다.** FACETS가 이 위치에서 대립유전자 비율을 셉니다(종양 단독 분석에서는 쓰지 않음).
6. **결과는 순도·배수성에 크게 좌우됩니다.** `facets_summary.tsv`의 순도, 배수성, 상태(Status)를 먼저 확인해 주세요. 순도가 낮거나(기본 0.2 미만) 적합이 실패한 샘플은 오류가 아니라 상태로 기록되고, 보정 없이 CNVkit 판정만 남습니다.
7. **판정은 배수성 대비 상대 판정입니다.** 배수성이 2.7 이상이면 기준 복제수를 4로 보므로, 복제수 3도 LOSS로 나옵니다.
8. **종양 단독 분석은 정상 기준의 노이즈가 큽니다.** 정상 시료 묶음이 없으면 flat 기준을 써서 캡처 효율 차이가 변화처럼 보일 수 있고, 판정은 중앙값을 2배체로 가정한 상대 값이라 배수성이 높은 종양에서는 넓은 범위가 결실처럼 보일 수 있습니다.
9. **모든 분석은 인터넷 연결 없이 수행됩니다.** 염색체 팔 경계(UCSC cytoband, hg38·hg19)는 실행 이미지에 들어 있습니다. 관심 유전자 목록(COSMIC Cancer Gene Census 등)은 라이선스 때문에 넣지 않았으므로 필요하면 직접 준비해 주세요.

### English
1. **Only the human genome is supported.** GRCh38 (hg38) is the default and hg19 also works. The BAM files, reference FASTA, target BED, SNP VCF and gene annotation must use the same build and the same chromosome naming (`chr1` and `1` are different).
2. **The input is duplicate-marked, aligned tumor and normal BAM files with indexes (.bai).** For human cancer genomes, BAM files aligned with BWA-MEM or a similar aligner are recommended. Each BAM file name must start with its sample ID.
3. **List `SampleID` (tumor) and `NormalID` (matched normal) in the sample sheet (CSV).** Leave `NormalID` empty when there is no matched normal. When it is empty in every row, the run is tumor-only: FACETS is skipped and CNVkit calls are given without purity and ploidy correction or LOH. Normal samples sequenced with the same kit can still build the reference even if they are not matched. `Sex` (female, male) is optional and is inferred from coverage when empty.
4. **WES and targeted panels need the target BED of the capture kit.** Normal samples used for the reference must be sequenced with the same kit as the tumors.
5. **A VCF of common SNP sites (for example dbSNP common) is needed.** FACETS counts allele fractions at these sites (not used in tumor-only runs).
6. **The results depend strongly on purity and ploidy.** Check purity, ploidy and Status in `facets_summary.tsv` first. Samples with low purity (below 0.2 by default) or a failed fit are recorded with a status rather than as errors, and keep the uncorrected CNVkit calls only.
7. **Calls are relative to ploidy.** With a ploidy of 2.7 or more the baseline copy number is 4, so a copy number of 3 is called LOSS.
8. **Tumor-only runs are noisier.** Without normal samples a flat reference is used, so capture bias can look like copy changes, and calls are relative to a median assumed diploid, so in high-ploidy tumors wide regions can look deleted.
9. **All analyses run without internet access.** Chromosome arm boundaries (UCSC cytoband, hg38 and hg19) are in the runtime image. Gene lists such as the COSMIC Cancer Gene Census are not included because of their license, so prepare your own list of genes of interest if needed.
