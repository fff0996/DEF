CLOSHA 체세포 CNV 파이프라인 설계안 0.3

작성일: 2026-10-21
상태: 설계 단계. 스크립트, DEF, 원고는 아직 없다.

## 1. 목표
암 연구자가 종양 시료의 복제수 변이(CNV)를 분석하고, 결과를 바로 논문 그림과 표, 후속 분석(IGV, GISTIC2)에 쓸 수 있게 한다.
- 유전체 전체 복제수 그림, 순도와 배수성, 유전자별 증폭·결실 표, 코호트 빈도 그림을 만든다.
- 도구 하나에 의존하지 않는다. 두 방법(CNVkit, FACETS)의 결과를 함께 내고 서로 맞는지 표시한다.
- 실행 중 인터넷을 쓰지 않는다. 참조 자료는 사용자가 준비하거나 이미지에 포함한다.

## 2. 지원 범위
| 항목 | 지원 |
|---|---|
| 종, 참조 유전체 | 사람. 기본 GRCh38(hg38). BAM과 같은 참조 FASTA를 쓰면 hg19도 가능 |
| 데이터 | WGS, WES, 타깃 패널 (`seq_method`: wgs, hybrid, amplicon) |
| 대조군 | 종양-정상 쌍(기본), 종양만(tumor-only) |
| 시작점 | 중복 표시(MarkDuplicates)를 마친 정렬 BAM과 인덱스 |

정렬 단계는 이 파이프라인에 넣지 않는다. 사람 암 유전체는 BWA-MEM 계열 정렬이 표준이며, 기존 정렬 모듈(bowtie2, GATK MarkDuplicates)을 쓸지는 따로 정한다.

## 3. 도구 선택 근거
- **CNVkit**: WGS, WES, 패널을 모두 지원하고, 종양만 있는 데이터도 처리한다. 그림과 표준 출력(.cns, SEG)이 있다. nf-core/sarek의 CNV 도구(ASCAT, CNVkit, Control-FREEC) 중 하나다.
- **FACETS**: 종양-정상 쌍에서 순도, 배수성, 대립유전자별 복제수(LOH 포함)를 추정한다.
- **조합하는 이유**:
  - SEQC2 벤치마크(Genome Biology 2024, PMC11188507)의 결론: 도구 간 차이는 주로 배수성 추정에서 생긴다. CNVkit은 알려진 배수성으로 재중심화했을 때 증폭 검출이 좋았고, WGS와 WES 사이의 일치도가 가장 높았다.
  - 다른 연구(Open Bioinformatics Journal 2026)는 FACETS와 Sequenza를 권장하고, 도구 하나에 의존하지 말고 합의 방식을 쓰라고 했다.
  - 그래서 FACETS가 순도와 배수성을 정하고, CNVkit은 그 값으로 보정해 구간을 판정하며, 두 결과의 일치를 표시한다.

## 4. 흐름
```
종양-정상 쌍:
  BAM 폴더 ─┬─▶ cnv_facets ─────────────(순도·배수성)───┐
            ├─▶ cnvkit_reference(정상 BAM) ─▶ cnvkit_call ◀┘ ─▶ cnv_summary
            └────────────(종양 BAM)──────────▶┘
종양만:
  BAM 폴더 ─▶ cnvkit_reference(정상 묶음 또는 flat) ─▶ cnvkit_call ─▶ cnv_summary
```
CLOSHA에는 두 파이프라인("종양-정상 쌍", "종양만")으로 등록한다.

## 5. 모듈
공통: `docs/CLOSHA_Script_Rules_v1.md` 규칙을 따른다(`key=value` 인자, 입력은 폴더, stdout과 stderr 분리, 코어 수 자동, 데이터 결과와 오류 구분).

샘플 시트(CSV) 필수 열은 `SampleID`(종양)와 `NormalID`(정상, 종양만 분석이면 빈칸)이고, 선택 열은 `Sex`(female, male, 비우면 추정)이다. BAM은 이름이 ID로 시작하는 파일을 입력 폴더에서 찾는다.

### 5.1 cnv_facets (FACETS, 종양-정상 쌍 전용)
- **입력:** BAM 폴더, 샘플 시트, 일반 SNP VCF(dbSNP common 등, bgzip과 tbi)
- **처리:** snp-pileup으로 SNP 위치의 종양·정상 read 수를 세고, FACETS로 분절과 순도·배수성을 맞춘다(fit).
- **출력:**
  - `<SampleID>.facets_segments.tsv`: 구간별 총 복제수(tcn), 작은 쪽 복제수(lcn), 세포 분율
  - `<SampleID>.facets_cncf.png`: 유전체 전체 log ratio, 대립유전자 불균형, 복제수
  - `facets_summary.tsv`: 순도, 배수성, dipLogR, fit 상태, 경고 표시(emflags)
- **주요 인자:** cval(분절 민감도), min_depth, seed, genome(hg38, hg19)
- **데이터 결과:** fit이 수렴하지 않거나 순도가 너무 낮으면 오류가 아니라 상태(`low_purity`, `fit_failed`)로 기록하고, cnvkit_call은 그 샘플을 배수성 보정 없이 처리한다.

### 5.2 cnvkit_reference
- **입력:** BAM 폴더, 샘플 시트(정상 ID), 참조 FASTA, 유전자 주석(refFlat), 타깃 BED(WES, 패널), 선택 사항으로 접근 가능 영역 BED
- **처리:** 타깃과 반타깃 영역을 만들고, 정상 BAM 커버리지로 기준(reference.cnn)을 만든다. 정상이 없으면 flat 기준을 만든다.
- **출력:** `reference.cnn`, 타깃과 반타깃 BED, 정상 시료 QC 표(bin log2 편차)

### 5.3 cnvkit_call
- **입력:** BAM 폴더, 샘플 시트, 기준 폴더(5.2 출력과 같은 구조), 선택 사항으로 FACETS 결과 폴더(5.1 출력과 같은 구조)
- **처리:** 종양 커버리지를 구하고, 기준과 GC로 보정(fix)하고, 분절(segment)하고, 판정(call)한다. FACETS 순도와 배수성이 있으면 재중심화하고 정수 복제수로 바꾼다.
- **출력:**
  - `<SampleID>.cnr`, `<SampleID>.cns`, `<SampleID>.call.cns`
  - `<SampleID>.scatter.png`: 유전체 전체
  - `<SampleID>.diagram.png`: 염색체 그림
  - 유전자별 표(genemetrics)
  - `<SampleID>.seg`
  - `cnvkit_summary.tsv`: 샘플별 노이즈 지표, 사용한 순도·배수성과 출처

### 5.4 cnv_summary (코호트)
- **입력:** cnvkit_call 결과 폴더, 선택 사항으로 FACETS 결과 폴더, 선택 사항으로 관심 유전자 목록(TSV)
- **출력:**
  - 유전자 × 샘플 행렬(AMP, GAIN, NEUTRAL, LOSS, DEEPDEL)과 관심 유전자 표
  - 코호트 heatmap, 유전체 위치별 증폭·결실 빈도 그림
  - 불안정성 지표 표: 변이 유전체 비율(FGA), LOH 비율, 전체 유전체 배가(WGD) 추정
  - CNVkit과 FACETS 구간 일치율(쌍 데이터)
  - 합친 SEG 파일(IGV용), GISTIC2 입력 형식 SEG

## 5.5 시각화 (필수 요구사항)
시각화는 이 파이프라인의 핵심 결과물이다. 암 CNV 논문에서 실제로 쓰는 그림을 모두 만든다.

**공통 형식**
- 그림마다 PDF(벡터, 논문용)와 PNG(200 dpi, 포탈·발표용)를 만든다.
- 실행마다 HTML 리포트 하나(`cnv_report.html`)에 모든 그림과 요약표를 모은다. 샘플을 고르는 목차를 둔다.
- 색 규칙을 모든 그림에서 같게 한다: 증폭·gain은 빨강 계열, 결실·loss는 파랑 계열, LOH는 별도 색, 중립은 회색. 색약 사용자도 구분할 수 있는 팔레트를 쓴다.
- 염색체 순서와 이름(1~22, X, Y), 축 이름, 글꼴을 통일한다. 관심 유전자는 모든 그림에서 같은 방식으로 표시한다.

**샘플별 그림** (`<SampleID>.<그림>.pdf/png`)
| 그림 | 내용 | 모듈 |
|---|---|---|
| genome_profile | 유전체 전체 bin log2 ratio(점)와 구간(선), gain·loss 색 구분, 관심 유전자 표시 | cnvkit_call |
| allele_specific | 총 복제수와 작은 쪽 복제수를 유전체 위에 표시, LOH 구간 음영, 순도·배수성 표기(ASCAT, PURPLE 스타일) | cnv_facets |
| facets_cncf | FACETS 기본 4단 그림(log ratio, 대립유전자 불균형, 정수 복제수, 세포 분율) | cnv_facets |
| baf | 종양 B-allele 빈도의 유전체 분포 | cnv_facets |
| chromosome_diagram | 염색체 모식도 위 gain·loss 구간 | cnvkit_call |
| chromosomes | 염색체마다 확대한 그림(여러 쪽 PDF), 유전자 이름 표시 | cnvkit_call |
| focal_genes | 관심 유전자 주변 확대 그림(예: ERBB2, MYC, EGFR, CDKN2A) | cnvkit_call |
| cn_state_hist | 구간 log2 또는 복제수 분포(순도·배수성 적합 확인용) | cnvkit_call |
| qc | bin 커버리지, GC 편향, 노이즈 지표 | cnvkit_call |

**코호트 그림** (`cnv_summary`)
| 그림 | 내용 |
|---|---|
| cohort_heatmap | 샘플 × 유전체 위치 복제수 heatmap, 비슷한 샘플끼리 묶음 |
| frequency | 유전체 위치별 gain·loss 샘플 비율(위는 gain, 아래는 loss) |
| arm_heatmap | 염색체 팔(arm) 단위 gain·loss heatmap과 aneuploidy 점수 |
| gene_oncoprint | 관심 유전자 × 샘플 행렬(AMP, GAIN, LOSS, DEEPDEL, LOH) |
| purity_ploidy | 샘플별 순도 대 배수성 산점도, WGD 표시 |
| instability | 샘플별 FGA, LOH 비율, 변이 구간 수 막대그래프(정렬) |
| concordance | CNVkit과 FACETS의 구간별 복제수 비교, 샘플별 일치율 |
| sample_similarity | 샘플 간 복제수 프로파일 상관 heatmap |

**필요한 자료**
- 염색체 팔 경계(cytoband): UCSC cytoBand(GRCh38, hg19)를 이미지에 넣는 것을 검토한다.
- 관심 유전자 목록: 사용자가 제공한다. COSMIC Cancer Gene Census는 라이선스가 필요하므로 이미지에 넣지 않는다. 목록이 없으면 코호트에서 자주 변한 유전자를 자동으로 고른다.

## 6. 참조 자료
| 자료 | 준비 | 비고 |
|---|---|---|
| 참조 FASTA와 .fai | 사용자 | BAM과 같은 참조 |
| 유전자 주석 refFlat | 사용자 또는 이미지 포함 검토 | GRCh38, hg19 |
| 타깃 BED | 사용자 | WES, 패널만 |
| 일반 SNP VCF | 사용자 | FACETS용 |
| 접근 가능 영역 BED | 없으면 FASTA로 생성 | |

## 7. 검증 데이터
SEQC2 체세포 기준 세포주 HCC1395(종양)와 HCC1395BL(정상)을 쓴다. 공개된 WGS, WES 데이터와 CNV 정답 세트가 있어 결과를 정답과 비교할 수 있다. Codespace는 디스크가 작으므로 일부 염색체만 잘라서 쓴다. 원격 BAM에서 구간만 받을 수 있는지는 확인이 필요하다.

### 7.1 첫 검증 결과 (2026-10-21, Codespace 2코어 7GB)
- **자료:** SEQC2 WES `WES_IL_T_1`(종양), `WES_IL_N_1`(정상). BWA-MEM과 중복 제거가 끝났고, 참조는 GRCh38.d1.vd1이다.
  - 염색체는 chr6, chr13, chr17, chr18, chr21만 쓴다. BAM은 종양 1.75GB, 정상 1.95GB이다.
  - 타깃은 SureSelect V6+UTR(hg38)이고, SNP 위치는 dbSNP b151 common이다.
  - 받는 법: `tools/cnv/fetch_seqc2_subset.py <폴더>`(약 15분). Codespace의 `/tmp`는 재시작하면 지워진다.
- **비교 기준:** FTP의 `analysis/CNVs/SEQC_CNV_raw_data.zip`에 같은 데이터의 SEQC2 공식 결과(도구 6종)가 있다. 비교에는 `WES/facets/WES_IL_1_fit_cncf.txt`와 `WES/cnvkit/WES_IL_1.call.cns`를 썼다. R write.table 형식이라 데이터 줄에는 행 이름 열이 하나 더 있다.
- **도구 버전:** CNVkit 0.9.14(R 4.5.3 이상 필요), FACETS 0.6.2와 snp-pileup 0.6.2(bioconda는 R 4.4까지). R 요구가 서로 달라 한 환경에 설치되지 않으므로 이미지를 나눈다(8절).

| 단계 | 시간 | 최대 메모리 |
|---|---|---|
| cnvkit.py access | 8초 | 0.18GB |
| cnvkit.py batch(기준, 커버리지, fix, segment, call, 그림) | 474초 | 0.36GB |
| snp-pileup(-g -q15 -Q20 -P100 -r25,0) | 144초 | 작음 |
| FACETS fit(cval 150, ndepth 35, snp.nbhd 250, hg38) | 22초 | 0.76GB |

결과:
- **FACETS:**
  - 순도 0.966, 배수성 3.08(5개 염색체 기준), emflags 없음. 공식 결과의 순도(cf.em)는 0.937이고, 논문의 배수성은 2.85이다.
  - 공식 FACETS와 비교한 일치율(길이 가중): LOH 98.2%, 총 복제수 70.6%.
  - 총 복제수의 차이는 대부분 비율이 같고 배수 단위만 다르다(예: SMAD4가 공식 6/3, 우리 4/2). 배수성을 5개 염색체만으로 추정했기 때문으로 본다.
  - 동형 결실 3곳(chr6 94.1~96.5Mb, chr6 101.7~105.7Mb, chr13 52.7~60.5Mb)과 TP53 LOH(3/0)가 공식 결과와 같았다.
- **CNVkit 기본 판정**(배수성 보정 없음): 공식 CNVkit과 13.5%, 우리 FACETS와 10.8%만 일치했다. 기본 판정은 중앙값을 2배체로 가정하기 때문이다.
- **CNVkit 보정 판정:**
  - FACETS가 2/1로 판정한 구간의 CNVkit log2 길이 가중 중앙값은 -0.275였다.
  - 이 값으로 `cnvkit.py call --center-at -0.2747 -m clonal --purity 0.966`을 실행했다.
  - 일치율이 공식 CNVkit과 63.3%, 우리 FACETS와 79.2%로 올라갔다.
  - TP53 3, ERBB2 2, chr21 2, chr13과 chr6 동형 결실 0이 공식 FACETS와 같았다.
  - 결론: **cnvkit_call은 FACETS 순도와 2/1 구간 기준점으로 재중심화해야 한다.** 이 방식을 기본으로 한다.
- **그림:** CNVkit 기본 scatter는 y축이 -5~1.5로 잘려 chr6 고배수 증폭이 화면 밖으로 나간다. 축 범위를 데이터에 맞추는 자체 그림이 필요하다(5.5절). FACETS 기본 그림(plotSample)은 4단 구성이 잘 나온다.
- **남은 확인:**
  - 전체 염색체로 돌렸을 때 배수성(2.85에 가까운지)
  - 공식 CNVkit과의 남은 차이. 공식 결과는 같은 구간에서 더 높은 복제수(예: 7)를 낸다. 배수성 기준이 다른 것으로 추정한다.

## 8. 실행 이미지
- `bx_cnvkit`: CNVkit, samtools, R(DNAcopy)
- `bx_facets`: R facets, snp-pileup
- `bx_cnv_summary`: Python, R 그림 패키지

모두 Rocky 9와 Miniforge(conda-forge, bioconda) 기반이며 `docs/CLOSHA_DEF_Generator_Agent_v1.md`를 따른다. 버전은 DEF를 쓸 때 bioconda에서 확인해 고정한다.

## 9. 나중에 검토
- HRD 점수(scarHRD: HRD-LOH, TAI, LST): FACETS의 대립유전자별 구간을 쓴다.
- 종양만 분석에서 순도·배수성 추정(PureCN)
- 저심도 WGS(ichorCNA)

## 10. 진행 순서
1. 이 설계안 확정
2. 검증 데이터 준비(일부 염색체)
3. 스크립트: cnvkit_reference, cnvkit_call, cnv_facets, cnv_summary 순
4. DEF와 Codespace 검증 빌드
5. 결과 그림 확인 후 포탈 원고
