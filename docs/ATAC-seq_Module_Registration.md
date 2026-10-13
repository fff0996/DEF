ATAC-seq 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-10-07

CLOSHA에 ATAC-seq 모듈을 등록할 때 쓰는 Input / Output / Option 정리다. 기준은 `scripts/ATAC-seq/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 모든 모듈은 `output_dir/logs/`에 `<시각>_<PID>.log`(stdout)와 `<시각>_<PID>.error.log`(stderr)를 남기며, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지우고 시작한다. 입력이 `output_dir` 안에 있으면 지우기 전에 멈춘다.

## 0. 파이프라인 흐름
```
[organellar_filter] ─output_dir─> [ATAC_QC] ─output_dir─┬─> [ATAC_QC_plot]
                                                         ├─> [MACS3_callpeak] ─output_dir─┬─> [peak_annotation] ─output_dir─> [functional_enrichment] (input_dir)
                                                         │                                ├─> [differential_accessibility] ─output_dir─┬─> [atac_motif]
                                                         │                                │                                            └─> [functional_enrichment] (da_dir)
                                                         │                                └─> [tf_footprinting] (macs_dir)
                                                         ├─> [differential_accessibility] (input_dir)
                                                         ├─> [tf_footprinting] (input_dir)
                                                         └─> [replicate_consistency] (input_dir)
```
| 모듈 | 스크립트 | 실행 이미지 | 실행 명령 |
|---|---|---|---|
| organellar_filter | `organellar_filter.1.1.sh` | bx_organellar_filter.1.0 | `bash organellar_filter.1.1.sh key=value ...` |
| ATAC_QC | `ATAC_QC.1.2.R` | bx_atac_qc.1.0 | `Rscript ATAC_QC.1.2.R key=value ...` |
| ATAC_QC_plot | `ATAC_QC_plot.1.1.R` | bx_atac_qc.1.0 | `Rscript ATAC_QC_plot.1.1.R key=value ...` |
| MACS3_callpeak | `MACS3_callpeak_ATAC.1.2.sh` | bx_macs3_callpeak_atac.1.0 | `bash MACS3_callpeak_ATAC.1.2.sh key=value ...` |
| peak_annotation | `peak_annotation.1.1.R` | bx_peak_annotation.1.0 | `Rscript peak_annotation.1.1.R key=value ...` |
| differential_accessibility | `differential_accessibility.1.2.R` | bx_differential_accessibility.1.0 | `Rscript differential_accessibility.1.2.R key=value ...` |
| atac_motif | `atac_motif.1.1.R` | bx_atac_motif.1.0 | `Rscript atac_motif.1.1.R key=value ...` |
| tf_footprinting | `tf_footprinting.1.1.sh` | bx_tf_footprinting.1.0 | `bash tf_footprinting.1.1.sh key=value ...` |
| functional_enrichment | `functional_enrichment.1.0.R` | bx_functional_enrichment.1.0 | `Rscript functional_enrichment.1.0.R key=value ...` |
| replicate_consistency | `replicate_consistency.1.0.sh` | bx_replicate_consistency.1.0 | `bash replicate_consistency.1.0.sh key=value ...` |

`ATAC_QC.1.2`(또는 1.1)와 `ATAC_QC_plot.1.1`은 함께 쓴다(1.1 이후 QC는 clean BAM을 쓰므로 trinucleosome이 비어 있을 수 있고, 1.1 plot은 빈 종류를 빼고 그린다). 1.2 버전(ATAC_QC, MACS3, differential_accessibility)은 1.1에 QC 지표만 더한 것이라 같은 이미지에서 돌고, 기존 결과 파일은 그대로다.

## 1. organellar_filter
미토콘드리아·엽록체 등 세포소기관 contig의 read를 BAM에서 제거한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 정렬된 BAM이 있는 폴더. `*.unsorted.bam`은 제외. BAM은 좌표 정렬되어 있어야 함. 인덱스(.bai)가 없으면 BAM 옆에 만든다 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. 다음 모듈(ATAC_QC)의 `input_dir` |
| Option | `threads` | String | 선택 | `auto` | 스레드 수. auto = 실행 환경에 할당된 코어 수. 숫자는 할당량 이하로 줄임. **화면에서 빼도 됨** |
| Option | `organellar_pattern` | String | 선택 | `(^chrM$\|^MT$\|^Mt$\|mitochond\|...\|^Pt$\|^PT$\|^chrC$)` | 세포소기관 contig 이름 정규식(대소문자 무시) |

결과: `03_filtered_bam/*.organellar_removed.bam`(+ .bai), idxstats, flagstat(전/후), contig 목록, 요약 TSV.

## 2. ATAC_QC
fragment 크기 분포, bamQC, Tn5 shift, 뉴클레오솜 위치별 BAM 분할(ATACseqQC). 1.1부터 bamQC clean BAM으로 shift·분할한다. 1.2는 샘플별 TSS enrichment 점수와 CPM 정규화 coverage bigWig를 더한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | shift 전 BAM 폴더. organellar_filter의 `output_dir` 권장(`*_organellar_removed.bam`) |
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. 컬럼: `SampleID`, `Condition`, `Replicate`. BAM 파일 이름에 SampleID가 들어 있어야 함 |
| Input | `txs_bed` | File (BED) | 필수 | | 전사체/TSS 영역 BED(3열 이상, 6열 권장: chr start end name score strand) |
| Input | `genome_fasta` | File (FASTA) | 필수 | | 참조 유전체. .fai가 없으면 FASTA 옆에 만든다 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. ATAC_QC_plot, MACS3, differential_accessibility, tf_footprinting의 `input_dir` |
| Option | `seqlev` | String | 선택 | `auto` | 사용할 염색체(쉼표 구분). auto = BAM과 txs_bed에 공통으로 있는 염색체 전부 |
| Option | `tss_flank` | Integer | 선택 | `1000` | (1.2) TSS enrichment 점수를 계산할 TSS 앞뒤 범위(bp, 200 이상) |
| Option | `make_bigwig` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | (1.2) 샘플별 coverage bigWig(CPM) 생성 |

결과: `01_fragment_size`, `02_bam_qc`, `03_shifted_bam`, `04_split_bam`, `05_metadata/atac_qc_manifest.tsv`, `06_rds`. 1.2는 추가로 `05_metadata/atac_qc_metrics.tsv`(샘플별 read 수, clean 비율, TSS enrichment), `07_tss_enrichment`(샘플별 점수 그림·TSV), `08_bigwig/<sample>.shifted.cpm.bw`(IGV 등에서 바로 열림).

TSS enrichment 참고: ENCODE 사람(hg38) 기준 5 미만 주의, 5~7 허용, 7 초과 좋음. 다른 종은 주석 품질에 따라 범위가 다르다.

## 3. ATAC_QC_plot
분할 BAM으로 TSS 주변 신호 heatmap과 profile을 그린다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | ATAC_QC의 `output_dir`(`05_metadata/atac_qc_manifest.tsv` 사용) |
| Input | `tss_bed` | File (BED) | 필수 | | TSS 위치 BED |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `upstream` | Integer | 선택 | `1010` | TSS 상류 범위(bp) |
| Option | `downstream` | Integer | 선택 | `1010` | TSS 하류 범위(bp) |
| Option | `ntile` | Integer | 선택 | `101` | 구간을 나누는 칸 수 |
| Option | `tss_filter` | Float | 선택 | `0.5` | TSS 신호 필터 기준(ATACseqQC `TSS.filter`) |
| Option | `harmonize_mode` | List (`auto`, `strict`) | 선택 | `auto` | auto: tss_bed 염색체 이름이 BAM과 다르면 자동으로 맞춤. strict: 다르면 오류로 멈춤 |

결과: `01_tss_signal`(PDF/TSV), `02_signal_matrices`(RDS), `03_summary`(샘플별 사용/제외 종류 포함).

## 4. MACS3_callpeak
MACS3 callpeak(paired-end, BAMPE)로 peak를 찾는다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | Tn5 shift된 BAM 폴더. ATAC_QC의 `output_dir`을 주면 `03_shifted_bam`만 검색. `CONTROL_*.bam`이 있으면 처리군과 짝지어 실행 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. peak_annotation, differential_accessibility(`peak_dir`), tf_footprinting(`macs_dir`)의 입력 |
| Option | `genome_size` | String | **필수** | | 유효 유전체 크기. `hs`, `mm`, `ce`, `dm` 또는 숫자(예: 애기장대 약 `119000000`) |
| Option | `peak_type` | List (`atac`, `narrow`, `broad`, `tf`) | 선택 | `atac` | peak 호출 방식 |
| Option | `alignment_suffix` | String | 선택 | `.shifted.bam` | 검색할 BAM 파일 끝부분 |
| Option | `qvalue` | Float | 선택 | `0.05` | q-value 기준 |
| Option | `broad_cutoff` | Float | 선택 | `0.1` | broad peak 기준(`peak_type=broad`일 때) |

결과: `<sample>_peaks.narrowPeak`(broad면 `.broadPeak`) 등 MACS3 출력, `<sample>_macs3.log`/`.stderr.log`. 일부 샘플만 실패하면 경고 후 종료 코드 0. 1.2는 추가로 `frip_summary.tsv`(샘플별 peak 수, 전체 read, peak 안 read, FRiP)를 만든다. FRiP 참고: ENCODE ATAC-seq 기준 0.3 초과 좋음, 0.2 초과 허용.

## 5. peak_annotation
ChIPseeker로 peak 주석(유전자 위치 분류, TSS 거리)과 그림을 만든다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | peak 파일 폴더(하위 폴더까지 검색). MACS3의 `output_dir` |
| Input | `genome_gff` | File (GFF3/GTF, .gz 가능) | 필수 | | 유전자 주석 파일. 여기서 TxDb를 만든다 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `genome_label` | String | 선택 | `custom_genome` | 로그와 그림에 쓰는 유전체 이름 |
| Option | `peak_suffix` | String | 선택 | `.narrowPeak` | peak 파일 끝부분(`.broadPeak`, `.bed` 등) |
| Option | `tss_upstream` | Integer | 선택 | `3000` | 프로모터 상류 범위(bp) |
| Option | `tss_downstream` | Integer | 선택 | `3000` | 프로모터 하류 범위(bp) |
| Option | `max_files` | String | 선택 | `NA` | 처리할 최대 peak 파일 수. NA = 전부 |

결과: `annotation/`(샘플별 TSV/RDS, 요약), `plots/`(PDF), `gene_lists/`.

## 6. differential_accessibility
두 조건 사이 접근성 차이(edgeR)와 GC 편향 점검.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. (A) `SampleID,Condition,bamReads,Peaks` 형식이면 파일 경로를 그대로 사용, (B) `SampleID,Condition`만 있으면 `input_dir`, `peak_dir`에서 SampleID로 찾음 |
| Input | `genome_fasta` | File (FASTA) | 필수 | | 참조 유전체(peak GC 계산) |
| Input | `input_dir` | Directory | 조건부 | | (B) 형식일 때 필수. BAM 폴더. ATAC_QC의 `output_dir`이면 `03_shifted_bam` 사용. BAM 인덱스가 있어야 함 |
| Input | `peak_dir` | Directory | 조건부 | | (B) 형식일 때 필수. MACS3의 `output_dir` |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더. atac_motif의 `input_dir` |
| Option | `control_name` | String | 선택 | `control` | 기준(분모) 조건 이름. logFC = log2(다른 조건 / control_name) |
| Option | `fdr` | Float | 선택 | `0.05` | 유의 기준 FDR |
| Option | `gc_bin_chr` | String | 선택 | (빈 값) | GC 편향 그림에 쓸 염색체. 비우면 가장 긴 염색체 |
| Option | `tile_width` | Integer | 선택 | `5000` | GC 편향 그림의 구간 크기(bp) |
| Option | `paired` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | paired-end로 read를 셀지 |
| Option | `run_edaseq` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | EDASeq GC 보정 정규화 실행 |
| Option | `run_cqn` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | CQN GC 보정 정규화 실행 |

결과: `01_sample_sheet`, `02_counts`, `03_results`(`diff_accessibility_<정규화>.csv` 등), `04_plots`, `05_rds`. 1.2는 추가로 샘플 상관 heatmap(`04_plots/sample_correlation_heatmap.pdf`, `03_results/sample_correlation.tsv`)과 PCA(`04_plots/PCA_plot.pdf`, `03_results/PCA_coordinates.tsv`, 3샘플 이상)를 만든다. 반복 실험이 같은 조건끼리 묶이는지, 튀는 샘플이 있는지 확인하는 용도다.

## 7. atac_motif
차등 접근성 결과로 모티프 농축(monaLisa) 분석.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 조건부 | | differential_accessibility의 `output_dir`. `input_dir`과 `da_csv` 중 하나는 필수 |
| Input | `da_csv` | File (CSV) | 조건부 | | 차등 접근성 결과 CSV를 직접 지정할 때 |
| Input | `genome_fasta` | File (FASTA) | 필수 | | 참조 유전체. **.fai 인덱스가 미리 있어야 함** |
| Input | `motif_db` | File (MEME) | 필수 | | 모티프 데이터베이스(MEME 형식) |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `norm` | List (`TMM`, `EDASeq`, `CQN`) | 선택 | `TMM` | `input_dir`에서 읽을 결과의 정규화 방식(`03_results/diff_accessibility_<norm>.csv`) |
| Option | `chrs` | String | 선택 | (빈 값) | 사용할 염색체(쉼표 구분). 비우면 자동 |
| Option | `fdr_filter` | Float | 선택 | (빈 값) | 이 FDR 이하인 peak만 사용. 비우면 필터 없음 |
| Option | `n_per_bin` | Integer | 선택 | `400` | logFC 구간 하나에 넣을 peak 수 |
| Option | `min_abs_logfc` | Float | 선택 | `0.3` | 구간 나눌 때 쓰는 최소 |logFC| |
| Option | `padj_cutoff` | Float | 선택 | `4.0` | 강하게 농축된 모티프 기준(-log10 조정 p-value) |
| Option | `kmer_len` | Integer | 선택 | `6` | k-mer 분석 길이 |
| Option | `min_motif_score` | Float | 선택 | `10.0` | 모티프 hit 최소 점수 |
| Option | `stabsel_cutoff` | Float | 선택 | `0.8` | randomized lasso 안정성 선택 기준(0~1] |
| Option | `seed` | Integer | 선택 | `123` | 난수 시드 |
| Option | `threads` | String | 선택 | `auto` | 스레드 수. auto = 할당된 코어 수. **화면에서 빼도 됨** |
| Option | `run_kmer` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | k-mer 농축 분석 실행 |
| Option | `run_regression` | List (`TRUE`, `FALSE`) | 선택 | `TRUE` | 안정성 선택 회귀 분석 실행 |

결과: `01_qc`, `02_binned_enrichment`(TSV/RDS/heatmap/seqlogos), `03_kmer`, `04_regression`, `05_rds`, `session_info.txt`.

## 8. tf_footprinting
TOBIAS로 조건별 전사인자 footprint와 비교(BINDetect).

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | BAM 폴더(파일 이름에 SampleID 포함). ATAC_QC의 `output_dir`이면 `03_shifted_bam`의 `*.shifted.bam` 사용. 인덱스가 없으면 BAM 옆에 만든다 |
| Input | `metadata` | File (TSV/CSV) | 필수 | | 샘플 정보. `SampleID`, `Condition` 컬럼, 조건 2개 이상 |
| Input | `genome_fasta` | File (FASTA) | 필수 | | 참조 유전체. .fai가 없으면 FASTA 옆에 만든다 |
| Input | `motif_db` | File | 필수 | | 모티프 데이터베이스 |
| Input | `macs_dir` | Directory | 조건부 | | MACS3의 `output_dir`. `peak_file`이 없을 때 필수(peak를 합쳐 공통 peak 생성) |
| Input | `peak_file` | File | 선택 | | 미리 합친 공통 peak 파일(BED/narrowPeak/broadPeak). 주면 `macs_dir` 대신 사용 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `sample_col` | String | 선택 | `SampleID` | metadata의 샘플 컬럼 이름 |
| Option | `condition_col` | String | 선택 | `Condition` | metadata의 조건 컬럼 이름 |
| Option | `cores` | String | 선택 | `auto` | 코어 수. auto = 할당된 코어 수. **화면에서 빼도 됨** |

결과: `00_metadata`, `01_peak_merge`, `02_merged_bam_by_condition`, `03_tobias_tracks`(bigWig), `04_BINDetect`, `summary/`.

## 9. functional_enrichment
GO 농축 분석(clusterProfiler). 종별 데이터는 이미지에 없고, `tools/download_orgdb.R`로 받은 OrgDb 파일이나 유전자-GO 대응표를 입력으로 받는다. 실행 중 인터넷 접속이 없으므로 KEGG는 쓰지 않는다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 조건부 | | peak_annotation의 `output_dir`. `gene_lists/*.annotated_gene_list.tsv`를 목록별로 분석. 아래 4개 입력 중 하나만 |
| Input | `gene_file` | File (TSV/CSV/TXT) | 조건부 | | 유전자 목록 파일 하나(geneId/gene_id/gene 컬럼, 또는 한 줄에 ID 하나) |
| Input | `da_dir` | Directory | 조건부 | | differential_accessibility의 `output_dir`. `03_results/diff_accessibility_<da_norm>.csv`를 읽어 up/down 영역 근처 유전자를 분석 |
| Input | `da_file` | File (CSV/TSV) | 조건부 | | 차등 접근성 결과 파일 하나(seqnames 또는 chr, start, end, logFC, FDR 컬럼) |
| Input | `genome_gff` | File (GFF3/GTF, .gz 가능) | 조건부 | | `da_dir`/`da_file`일 때 필수. peak마다 가장 가까운 유전자 TSS를 찾는 데 사용 |
| Input | `orgdb_file` | File (SQLite) | 조건부 | | `download_orgdb.R`로 받은 `<종>.<AH id>.OrgDb.sqlite`. `go_table`과 둘 중 하나 |
| Input | `go_table` | File (GAF/TSV/CSV) | 조건부 | | 유전자-GO 대응표. OrgDb가 없는 종에 사용 |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `gene_keytype` | String | 선택 | `auto` | OrgDb의 ID 종류(TAIR, ENTREZID, SYMBOL, ENSEMBL 등). auto = 가장 많이 맞는 종류를 자동 선택 |
| Option | `ont` | List (`BP`, `MF`, `CC`, `ALL`) | 선택 | `BP` | GO 분류 |
| Option | `max_distance_to_tss` | String | 선택 | `3000` | TSS에서 이 거리(bp) 안의 peak에 연결된 유전자만 사용. `NA` = 전부 |
| Option | `universe` | String | 선택 | `auto` | 배경 유전자. auto = peak_annotation의 전체 유전자 목록 또는 DA에서 검정한 전체 peak의 유전자. `all` = 주석 전체. 파일 경로도 가능 |
| Option | `pvalue_cutoff` | Float | 선택 | `0.05` | 조정 p-value 기준 |
| Option | `qvalue_cutoff` | Float | 선택 | `0.2` | q-value 기준 |
| Option | `p_adjust_method` | List (`BH`, `bonferroni`, `holm`, `hochberg`, `hommel`, `BY`, `fdr`, `none`) | 선택 | `BH` | 다중검정 보정 방법 |
| Option | `min_gs_size` | Integer | 선택 | `10` | GO 항목의 최소 유전자 수 |
| Option | `max_gs_size` | Integer | 선택 | `500` | GO 항목의 최대 유전자 수 |
| Option | `min_mapped_fraction` | Float | 선택 | `0.5` | 입력 ID 중 주석에서 찾은 비율이 이보다 낮으면 멈춤(종이나 ID 종류가 다를 때) |
| Option | `show_category` | Integer | 선택 | `20` | 그림에 보일 GO 항목 수 |
| Option | `da_norm` | List (`TMM`, `EDASeq`, `CQN`) | 선택 | `TMM` | `da_dir`에서 읽을 정규화 결과 |
| Option | `da_fdr` | Float | 선택 | `0.05` | up/down peak를 고르는 FDR 기준 |
| Option | `da_min_abs_logfc` | Float | 선택 | `0` | up/down peak의 최소 \|logFC\| |

결과: `01_gene_lists`(목록별 유전자, DA 입력이면 `da_peak_to_gene.tsv`), `02_enrichment/<목록>.GO_<ont>.tsv`, `03_plots`(dotplot·barplot PDF), `04_summary/enrichment_summary.tsv`. DA 입력이면 목록은 `<da_norm>.up`(treated에서 더 열림)과 `<da_norm>.down`이다.

## 10. replicate_consistency
반복 실험 간 peak 재현성(IDR, ENCODE 방식). 조건별로 반복 실험마다, 그리고 합친 BAM으로 MACS3를 느슨한 기준(p-value)으로 돌리고, 반복 실험 쌍마다 IDR을 계산한다. 조건마다 반복 실험이 2개 이상이어야 한다.

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | Tn5 shift된 BAM 폴더. ATAC_QC의 `output_dir`이면 `03_shifted_bam`에서 찾음 |
| Input | `sample_data` | File (CSV) | 필수 | | ATAC_QC와 같은 샘플 시트(`SampleID`, `Condition`, `Replicate`). BAM 이름은 `<SampleID><alignment_suffix>` |
| Output | `output_dir` | Directory | 필수 | | 결과 폴더 |
| Option | `genome_size` | String | **필수** | | 유효 유전체 크기(MACS3와 같음). `hs`, `mm`, `ce`, `dm` 또는 숫자 |
| Option | `alignment_suffix` | String | 선택 | `.shifted.bam` | BAM 파일 이름 끝부분 |
| Option | `pvalue` | Float | 선택 | `0.01` | 느슨한 peak 기준(p-value) |
| Option | `idr_threshold` | Float | 선택 | `0.05` | 재현성 있는 peak 기준(global IDR) |
| Option | `max_peaks` | Integer | 선택 | `300000` | 반복 실험마다 p-value 순으로 남길 최대 peak 수 |

결과: `01_relaxed_peaks/<조건>/`, `02_idr/<조건>/`(쌍별 IDR 표, 통과 peak, 그림), `03_reproducible_peaks/<조건>.conservative_peaks.narrowPeak`(통과 peak가 가장 많은 쌍), `04_summary/idr_summary.tsv`. 반복 실험이 1개인 조건은 건너뛴다. 의사 반복(pseudo-replicate) 분석은 하지 않는다.

## 11. 공통 참고
- `threads`/`cores`는 실행 환경에서 할당한 코어 수를 자동으로 쓰므로 등록 화면에서 빼도 된다. 로그에 `requested`, `allocated`가 함께 남는다.
- 입력 옆에 인덱스(.bai, .fai)를 만드는 모듈(organellar_filter, ATAC_QC, MACS3, tf_footprinting, replicate_consistency)은 입력 위치에 쓰기 권한이 있거나 인덱스가 미리 있어야 한다.
- 빈 값으로 두는 선택 인자는 기본값으로 동작한다.
