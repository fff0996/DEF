CLOSHA 체세포 CNV 파이프라인 설계안 0.1

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
