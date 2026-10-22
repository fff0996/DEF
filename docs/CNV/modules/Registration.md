CNV 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-22

CLOSHA에 CNV 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/CNV/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 모든 모듈은 `output_dir/logs/`에 `<시각>_<PID>.log`(stdout)와 `<시각>_<PID>.error.log`(stderr)를 남기며, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지우고 시작한다. 입력이 `output_dir` 안에 있으면 지우기 전에 멈춘다.

CNV 파이프라인은 CLOSHA 3.0에서 처음 배포하므로 모든 모듈의 배포 번호는 1.0이다.

## 0. 파이프라인 흐름
```
종양-정상 쌍 (CNV_Tumor_Normal_Pipeline):
  BAM 폴더 ─┬─> [cnv_facets] ──────────── output_dir ─────────┬─> [cnvkit_call] (facets_dir)
            │                                                └─> [cnv_summary] (facets_dir)
            ├─> [cnvkit_reference] ─ output_dir ─> [cnvkit_call] (reference_dir) ─ output_dir ─> [cnv_summary] (input_dir)
            └──────────────────────────────────> [cnvkit_call] (input_dir)

종양만 (CNV_Tumor_Only_Pipeline):
  BAM 폴더 ─> [cnvkit_reference] (정상 없음: flat 기준) ─> [cnvkit_call] ─> [cnv_summary]
```
| 모듈 | 스크립트 | 실행 이미지 | 실행 명령 |
|---|---|---|---|
| cnvkit_reference | `cnvkit_reference.1.0.py` | bx_cnvkit.1.0 | `python cnvkit_reference.1.0.py key=value ...` |
| cnv_facets | `cnv_facets.1.0.R` | bx_facets.1.0 | `Rscript cnv_facets.1.0.R key=value ...` |
| cnvkit_call | `cnvkit_call.1.0.py` | bx_cnvkit.1.0 | `python cnvkit_call.1.0.py key=value ...` |
| cnv_summary | `cnv_summary.1.0.py` | bx_cnvkit.1.0 | `python cnv_summary.1.0.py key=value ...` |

공통 입력:
- BAM: 좌표 정렬과 중복 표시(MarkDuplicates)를 마친 BAM과 인덱스(.bai). 입력 폴더에서 하위 폴더까지 찾고, 파일 이름이 ID로 시작하는 BAM을 쓴다.
- 샘플 시트(CSV): `SampleID`(종양, 필수), `NormalID`(짝 정상, 종양만 분석이면 빈칸), `Sex`(선택: female, male, 빈칸이면 추정).
- 참조: 사람 GRCh38(hg38) 기본, hg19 가능. 모든 참조 파일의 염색체 이름이 BAM과 같아야 한다(chr1 또는 1).

## 1. cnvkit_reference
정상 시료의 커버리지로 CNVkit 기준(reference.cnn)을 만든다. 정상이 없으면 flat 기준을 만든다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 정렬·중복 표시 BAM과 .bai 폴더(하위 폴더 포함) |
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. 정상 시료는 `NormalID` 열의 값(중복 제거). 모두 비어 있으면 flat 기준 |
| Input | `genome_fasta` | File (FASTA) | 필수 | | 정렬에 쓴 참조 FASTA. 옆에 .fai가 있어야 함 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `seq_method` | List (`hybrid`, `wgs`, `amplicon`) | 선택 | `hybrid` | hybrid = WES·캡처 패널, wgs = 전장 유전체, amplicon = 앰플리콘 패널 |
| Input | `targets_bed` | File (BED) | 선택 | | 캡처 타깃 BED. hybrid, amplicon이면 필수. wgs에서 비우면 유전체 전체 |
| Input | `annotation` | File | 선택 | | UCSC refFlat 유전자 주석. bin에 유전자 이름을 붙임. 비우면 유전자 이름 없음(유전자별 표가 비게 됨) |
| Input | `access_bed` | File (BED) | 선택 | | 접근 가능 영역 BED. 비우면 genome_fasta에서 N 구간을 빼고 만듦 |
| Option | `target_avg_size` | String | 선택 | `auto` | 타깃 bin 평균 크기(bp). auto = CNVkit이 정함(wgs는 정상 BAM에서 계산) |
| Option | `antitarget_avg_size` | String | 선택 | `auto` | 반타깃 bin 평균 크기(bp, hybrid만). auto = CNVkit 기본값 |
| Option | `bam_suffix` | String | 선택 | | 이름이 이 글자로 끝나는 BAM만 사용(예: `_marked.bam`). 비우면 모든 BAM |
| Option | `threads` | String | 선택 | `auto` | **포탈에 등록하지 않음**(Processor Core 선택으로 결정) |

결과: `01_reference/`(reference.cnn, targets.bed, antitargets.bed, access.bed), `02_normal_coverage/`, `03_qc/`(정상별 .cnr, normal_qc.tsv), `04_metadata/reference_info.tsv`.

## 2. cnv_facets
종양-정상 쌍에서 FACETS로 순도, 배수성, 대립유전자별 복제수를 추정한다. 종양-정상 쌍 파이프라인만 쓴다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 정렬·중복 표시 BAM과 .bai 폴더(하위 폴더 포함) |
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. `NormalID`가 빈 행은 건너뜀 |
| Input | `snp_vcf` | File (VCF) | 필수 | | 일반 생식세포 SNP 위치(dbSNP common 등). bgzip 또는 일반 VCF. 염색체 이름이 BAM과 같아야 함 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `genome` | List (`hg38`, `hg19`) | 선택 | `hg38` | FACETS 유전체 버전 |
| Option | `cval` | Integer | 선택 | `150` | 본 분절의 임계값. 클수록 구간이 적음 |
| Option | `pre_cval` | Integer | 선택 | `25` | 전처리 분절 임계값(2배체 기준 찾기용) |
| Option | `ndepth` | Integer | 선택 | `35` | SNP를 쓰는 최소 정상 깊이 |
| Option | `snp_nbhd` | Integer | 선택 | `250` | 가까운 SNP를 솎는 창(bp). WES 250, WGS는 1000 정도 |
| Option | `min_map_q` | Integer | 선택 | `15` | snp-pileup 최소 mapping quality |
| Option | `min_base_q` | Integer | 선택 | `20` | snp-pileup 최소 base quality |
| Option | `pseudo_snps` | Integer | 선택 | `100` | N bp마다 가짜 SNP를 넣어 SNP 사이 커버리지도 셈 |
| Option | `min_purity` | Float | 선택 | `0.2` | 이보다 낮거나 정할 수 없는 순도는 low_purity 상태 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드(FACETS가 SNP를 무작위로 솎음) |
| Option | `bam_suffix` | String | 선택 | | 이름이 이 글자로 끝나는 BAM만 사용. 비우면 모든 BAM |
| Option | `threads` | String | 선택 | `auto` | **포탈에 등록하지 않음**. 쌍을 동시에 pileup |

결과: `01_pileup/`, `02_segments/<SampleID>.facets_segments.tsv`, `03_plots/<SampleID>.facets_cncf|allele_specific|baf.pdf/.png`, `04_summary/facets_summary.tsv`(Status: ok, low_purity, fit_failed, pileup_failed).

## 3. cnvkit_call
종양 커버리지를 기준으로 보정하고 분절·판정한다. FACETS 결과가 있으면 순도와 2/1 구간으로 재중심화해 정수 복제수로 바꾼다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 정렬·중복 표시 BAM과 .bai 폴더(하위 폴더 포함) |
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. 모든 SampleID를 분석 |
| Input | `reference_dir` | Directory | 필수 | | CNVkit 기준 폴더. `01_reference/reference.cnn`, `04_metadata/reference_info.tsv`가 있어야 함 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Input | `facets_dir` | Directory | 선택 | | FACETS 결과 폴더(`04_summary/facets_summary.tsv`, `02_segments/<SampleID>.facets_segments.tsv`). 비우면 순도·배수성 보정 없음 |
| Input | `genes` | File | 선택 | | 관심 유전자(한 줄에 하나, 또는 TSV 첫 열). 비우면 변화가 큰 유전자를 표시 |
| Option | `segment_method` | List (`cbs`, `hmm`, `haar`) | 선택 | `cbs` | CNVkit 분절 방법 |
| Option | `amp_ratio` | Float | 선택 | `2` | 복제수가 기준의 이 배수 이상이면 AMP |
| Option | `bam_suffix` | String | 선택 | | 이름이 이 글자로 끝나는 BAM만 사용. 비우면 모든 BAM |
| Option | `threads` | String | 선택 | `auto` | **포탈에 등록하지 않음** |

판정(유전자·구간): 기준 복제수 = 2(FACETS 배수성 2.7 이상이면 4, 남성 chrX·chrY는 절반). DEEPDEL CN = 0, LOSS 0 < CN < 기준, NEUTRAL = 기준, GAIN 기준 < CN < amp_ratio × 기준, AMP CN ≥ amp_ratio × 기준.

결과: `01_cnvkit/<SampleID>/`, `02_calls/`(.cnr, .cns, .call.cns, .seg, .segments.tsv), `03_genes/<SampleID>.genes.tsv`, `04_plots/<SampleID>.<그림>.pdf/.png`(genome_profile, chromosomes, chromosome_diagram, focal_genes, cn_state_hist, qc), `05_summary/`(cnvkit_summary.tsv, all_samples.seg).

## 4. cnv_summary
코호트 표, 코호트 그림, HTML 리포트를 만든다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | CNVkit 판정 결과 폴더(`02_calls/<SampleID>.segments.tsv`, `.seg`, `03_genes/`, `04_plots/`, `05_summary/cnvkit_summary.tsv`) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Input | `facets_dir` | Directory | 선택 | | FACETS 결과 폴더(`04_summary/facets_summary.tsv`, `02_segments/`, `03_plots/`). 순도, 배수성, LOH, WGD를 더함. 비우면 CNVkit 결과만 |
| Input | `genes` | File | 선택 | | 관심 유전자 목록. 비우면 자주 변한 유전자 top_genes개 |
| Option | `genome` | List (`hg38`, `hg19`) | 선택 | `hg38` | 이미지에 든 UCSC cytoband 표 선택(염색체 팔 경계) |
| Input | `cytoband` | File | 선택 | | 이미지에 든 표 대신 쓸 UCSC cytoBand 파일. 비우면 genome의 내장 표 |
| Option | `bin_size` | Integer | 선택 | `1000000` | 코호트 heatmap, 빈도 그림, 유사도의 bin 크기(bp) |
| Option | `top_genes` | Integer | 선택 | `30` | genes가 비었을 때 oncoprint에 넣는 유전자 수 |

결과: `01_tables/`(gene_calls.tsv, gene_cn.tsv, interest_genes.tsv, arm_calls.tsv, instability.tsv), `02_seg/`(cohort.seg, gistic_segments.txt), `03_plots/`(cohort_heatmap, frequency, arm_heatmap, gene_oncoprint, instability, purity_ploidy·concordance(FACETS 있을 때), sample_similarity(2개 이상)), `04_report/cnv_report.html`.

## 5. 권장 자원 (포탈: 코어 1/4/8/16, 메모리 8~128GB)
Codespace 측정(WES, 염색체 5개, 쌍 1개)은 모두 1GB 미만이었다. 아래는 전체 유전체 기준 추정이며 CLOSHA에서 실측이 필요하다.

| 모듈 | WES·패널 | WGS | Core |
|---|---|---|---|
| cnvkit_reference | 8GB | 16GB | 4 |
| cnv_facets | 8GB | 16~32GB | 4 (쌍을 동시에 처리) |
| cnvkit_call | 8GB | 16GB | 4 |
| cnv_summary | 8GB | 8GB | 1 |
