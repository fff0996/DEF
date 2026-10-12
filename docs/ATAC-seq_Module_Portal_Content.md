# ATAC-seq 모듈 포탈 등록 콘텐츠

KOBIC 포탈의 "파이프라인 모듈" 등록 화면에 들어갈 모듈별 원고다. 항목 순서는 등록 화면을 따른다. 인자 정의는 `docs/ATAC-seq_Module_Registration.md`와 같다.

등록 화면 공통 안내:
- 모든 스크립트는 `key=value` 형식 인자를 받는다. 등록 화면의 Name은 인자 이름, Value는 기본값이다(빈칸은 기본값 없음).
- 형식(Type)은 포탈 목록에 맞춰 고른다. 원고에는 Directory, File, String, Integer, Float, List로 적었다.
- 기반 이미지 출처(Bootstrap)는 `Apptainer`다(작업이 SIF로 실행되므로). 기반 이미지(From)는 DEF의 `rockylinux/rockylinux:9.8` (digest `sha256:8101994123cf3d0a8fee517bee7f39e555c7d92bd2d9eb3303cc988a0eeed00f`)이며 모든 모듈이 같다.
- 버전은 각 실행 스크립트 파일 이름에 적힌 버전을 쓴다(예: organellar_filter.1.1.sh → 1.1).
- 모든 모듈은 `output_dir/logs/`에 실행 로그(`.log`)와 오류 로그(`.error.log`)를 남기고, 실행할 때마다 `output_dir`에서 `logs/`를 뺀 나머지를 지운다.
- 카테고리와 아이콘은 포탈 목록에서 고른다. 원고의 카테고리는 제안이다.

---

## 1. organellar_filter

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | organellar_filter | organellar_filter |
| 서브 타이틀 | 세포소기관 read 제거 | Organellar read removal |
| 버전 | 1.1 | |
| 카테고리 (제안) | Quality Control / Read Filtering | |
| 태그 | ATAC-seq, mitochondria, chloroplast, samtools, BAM filtering | |
| 레퍼런스 URL | https://www.htslib.org/ | |
| 컨테이너 이미지 | bx_organellar_filter.1.0 | |
| 실행 스크립트 파일 | organellar_filter.1.1.sh | |

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
| Input | Required | Directory | input_dir | | 좌표 정렬된 BAM 폴더(*.unsorted.bam 제외). 인덱스가 없으면 BAM 옆에 생성 | Folder of coordinate-sorted BAM files (*.unsorted.bam excluded); missing indexes are created beside the BAM |
| Output | Required | Directory | output_dir | | 결과 폴더. ATAC_QC의 input_dir | Output folder; input_dir of ATAC_QC |
| Option | Optional | String | threads | auto | 스레드 수. auto는 할당된 코어 수 | Threads; auto uses the allocated cores |
| Option | Optional | String | organellar_pattern | (^chrM$\|^MT$\|^Mt$\|mitochond\|mitochondrion\|mitochondrial\|chloroplast\|plastid\|^Pt$\|^PT$\|^chrC$) | 세포소기관 염색체 이름 정규식(대소문자 무시) | Regular expression for organellar contig names (case-insensitive) |

### 주요 사항
| 국문 | 영문 |
|---|---|
| BAM 파일은 좌표 순으로 정렬되어 있어야 합니다. | BAM files must be coordinate-sorted. |
| 세포소기관 염색체 이름이 일반적이지 않은 종은 organellar_pattern을 지정해 주세요. 결과의 contig 목록에서 제거된 염색체를 확인할 수 있습니다. | For species with unusual organellar contig names, set organellar_pattern. The contig list in the results shows which contigs were removed. |

### 스크립트 사용 예제
```
bash organellar_filter.1.1.sh input_dir=/data/bam output_dir=/data/organellar_filter
```

### 주요 결과 이미지 (제안)
제거 전후 read 수 요약표(TSV)를 표 이미지로 캡처해 등록한다.

---

## 2. ATAC_QC

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | ATAC_QC | ATAC_QC |
| 서브 타이틀 | ATAC-seq 품질 평가와 Tn5 보정 | ATAC-seq QC and Tn5 shift |
| 버전 | 1.2 | |
| 카테고리 (제안) | Quality Control / ATAC-seq QC | |
| 태그 | ATAC-seq, ATACseqQC, fragment size, TSS enrichment, Tn5 shift, bigWig | |
| 레퍼런스 URL | https://bioconductor.org/packages/ATACseqQC/ | |
| 컨테이너 이미지 | bx_atac_qc.1.0 | |
| 실행 스크립트 파일 | ATAC_QC.1.2.R | |

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
| Input | Required | Directory | input_dir | | shift 전 BAM 폴더. organellar_filter의 output_dir 권장 | Folder of pre-shift BAM files; the organellar_filter output_dir is recommended |
| Input | Required | File | sample_data | | 샘플 정보 CSV(SampleID, Condition, Replicate) | Sample sheet CSV (SampleID, Condition, Replicate) |
| Input | Required | File | txs_bed | | 전사체/TSS 영역 BED(6열 권장: chr start end name score strand) | Transcript/TSS BED (6 columns recommended: chr start end name score strand) |
| Input | Required | File | genome_fasta | | 참조 유전체 FASTA. .fai가 없으면 옆에 생성 | Reference genome FASTA; a missing .fai is created beside it |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | String | seqlev | auto | 사용할 염색체(쉼표 구분). auto는 BAM과 txs_bed에 공통인 염색체 전부 | Chromosomes to use (comma-separated); auto uses all chromosomes shared by the BAM and txs_bed |
| Option | Optional | Integer | tss_flank | 1000 | TSS enrichment 계산 범위(TSS 앞뒤 bp, 200 이상) | Flank around each TSS for the TSS enrichment score (bp, at least 200) |
| Option | Optional | List | make_bigwig | TRUE | 샘플별 coverage bigWig(CPM) 생성 여부(TRUE/FALSE) | Write a CPM coverage bigWig per sample (TRUE/FALSE) |

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): 쉼표로 구분한 CSV 파일이며 SampleID, Condition, Replicate 컬럼이 필요합니다. BAM 파일 이름에 SampleID가 포함되어 있어야 자동으로 연결됩니다. replicate_consistency 모듈에도 같은 파일을 사용합니다.
- 본문(영문): A comma-separated CSV with the SampleID, Condition, and Replicate columns. Each BAM file name must contain its SampleID for automatic matching. The same file is used by replicate_consistency.
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
| clean BAM은 proper pair만 남기므로 긴 fragment가 적은 데이터에서는 trinucleosome 분할이 비어 있을 수 있습니다. ATAC_QC_plot은 빈 분할을 빼고 그립니다. | The clean BAM keeps proper pairs only, so the trinucleosome split can be empty when long fragments are rare; ATAC_QC_plot skips empty classes. |

### 스크립트 사용 예제
```
Rscript ATAC_QC.1.2.R input_dir=/data/organellar_filter sample_data=/data/sample_data.csv txs_bed=/ref/genes.bed genome_fasta=/ref/genome.fa output_dir=/data/atac_qc
```

### 주요 결과 이미지 (제안)
`01_fragment_size/<sample>/<sample>.fragSizeDist.pdf`(fragment 크기 분포)와 `07_tss_enrichment/<sample>.tss_enrichment.pdf`를 PNG로 변환해 등록한다.

---

## 3. ATAC_QC_plot

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | ATAC_QC_plot | ATAC_QC_plot |
| 서브 타이틀 | TSS 주변 신호 시각화 | TSS signal visualization |
| 버전 | 1.1 | |
| 카테고리 (제안) | Quality Control / ATAC-seq QC | |
| 태그 | ATAC-seq, ATACseqQC, TSS, heatmap, nucleosome | |
| 레퍼런스 URL | https://bioconductor.org/packages/ATACseqQC/ | |
| 컨테이너 이미지 | bx_atac_qc.1.0 | |
| 실행 스크립트 파일 | ATAC_QC_plot.1.1.R | |

### 내용(국문)
ATAC_QC가 만든 fragment 종류별 BAM으로 TSS 주변 신호의 heatmap과 평균 profile을 그립니다. 좋은 ATAC-seq 데이터에서는 NFR 신호가 TSS 바로 위에 모이고, mononucleosome 신호는 TSS 양옆에 나타납니다.
- 종류별(NFR, mononucleosome 등) TSS 주변 신호 heatmap과 profile을 PDF와 TSV로 저장합니다.
- 비어 있는 종류는 빼고 그리며, 샘플별로 사용한 종류와 제외한 종류를 요약합니다.

### 내용(영문)
Plots heatmaps and average profiles of the signal around TSSs from the fragment-class BAM files made by ATAC_QC. In good ATAC-seq data, the NFR signal concentrates on the TSS and the mononucleosome signal flanks it.
- TSS heatmaps and profiles per class (NFR, mononucleosome, and so on) are saved as PDF and TSV.
- Empty classes are skipped, and the used and skipped classes are summarized per sample.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | | ATAC_QC의 output_dir | ATAC_QC output_dir |
| Input | Required | File | tss_bed | | TSS 위치 BED | TSS BED |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | Integer | upstream | 1010 | TSS 상류 범위(bp) | Upstream range from the TSS (bp) |
| Option | Optional | Integer | downstream | 1010 | TSS 하류 범위(bp) | Downstream range from the TSS (bp) |
| Option | Optional | Integer | ntile | 101 | 구간을 나누는 칸 수 | Number of bins |
| Option | Optional | Float | tss_filter | 0.5 | TSS 신호 필터 기준(ATACseqQC TSS.filter) | TSS signal filter (ATACseqQC TSS.filter) |
| Option | Optional | List | harmonize_mode | auto | auto: 염색체 이름이 다르면 자동으로 맞춤, strict: 다르면 중단 | auto: harmonize chromosome names; strict: stop if they differ |

### 주요 사항
| 국문 | 영문 |
|---|---|
| ATAC_QC 1.1 이상의 결과를 입력으로 사용해 주세요. | Use the output of ATAC_QC 1.1 or later as input. |

### 스크립트 사용 예제
```
Rscript ATAC_QC_plot.1.1.R input_dir=/data/atac_qc tss_bed=/ref/tss.bed output_dir=/data/atac_qc_plot
```

### 주요 결과 이미지 (제안)
`01_tss_signal`의 NFR·mononucleosome heatmap과 profile PDF를 PNG로 변환해 등록한다.

---

## 4. MACS3_callpeak_ATAC

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | MACS3_callpeak_ATAC | MACS3_callpeak_ATAC |
| 서브 타이틀 | ATAC-seq peak 검출 | ATAC-seq peak calling |
| 버전 | 1.2 | |
| 카테고리 (제안) | Epigenomics / Peak Calling | |
| 태그 | ATAC-seq, MACS3, peak calling, narrowPeak, FRiP | |
| 레퍼런스 URL | https://github.com/macs3-project/MACS | |
| 컨테이너 이미지 | bx_macs3_callpeak_atac.1.0 | |
| 실행 스크립트 파일 | MACS3_callpeak_ATAC.1.2.sh | |

### 내용(국문)
MACS3 callpeak의 paired-end 모드(BAMPE)로 Tn5 보정 BAM에서 열린 염색질 peak를 검출합니다.
- peak_type으로 atac(기본), narrow, broad, tf 설정을 고릅니다.
- CONTROL_로 시작하는 BAM이 있으면 같은 이름의 처리군과 짝지어 실행합니다.
- 샘플별 FRiP(peak 안에 들어간 read 비율)를 계산해 frip_summary.tsv에 정리합니다.
- 결과는 peak_annotation, differential_accessibility, tf_footprinting의 입력으로 사용합니다.

### 내용(영문)
Calls open-chromatin peaks from Tn5-corrected BAM files with MACS3 callpeak in paired-end mode (BAMPE).
- peak_type selects the atac (default), narrow, broad, or tf preset.
- BAM files starting with CONTROL_ are paired with the treatment of the same name.
- FRiP (fraction of reads in peaks) is computed per sample and written to frip_summary.tsv.
- The outputs feed peak_annotation, differential_accessibility, and tf_footprinting.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Required | Directory | input_dir | | Tn5 보정 BAM 폴더. ATAC_QC의 output_dir이면 03_shifted_bam만 검색 | Folder of Tn5-shifted BAM files; for an ATAC_QC output_dir only 03_shifted_bam is searched |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Required | String | genome_size | | 유효 유전체 크기. hs, mm, ce, dm 또는 숫자 | Effective genome size: hs, mm, ce, dm, or a number |
| Option | Optional | List | peak_type | atac | atac, narrow, broad, tf | atac, narrow, broad, tf |
| Option | Optional | String | alignment_suffix | .shifted.bam | 검색할 BAM 파일 이름 끝부분 | BAM file name suffix to search |
| Option | Optional | Float | qvalue | 0.05 | q-value 기준 | q-value cutoff |
| Option | Optional | Float | broad_cutoff | 0.1 | broad peak 기준(peak_type=broad일 때) | Broad peak cutoff (peak_type=broad) |

### 주요 사항
| 국문 | 영문 |
|---|---|
| genome_size는 분석 종에 맞게 입력해야 합니다. 사람 hs, 생쥐 mm, 그 외 종은 유효 유전체 크기를 숫자로 입력합니다(예: 애기장대 약 119000000). | Set genome_size for the species: hs for human, mm for mouse, or the effective genome size as a number for other species (for example about 119000000 for Arabidopsis). |
| FRiP는 ENCODE ATAC-seq 기준 0.3 초과 양호, 0.2 초과 허용입니다. | FRiP above 0.3 is good and above 0.2 is acceptable (ENCODE ATAC-seq). |
| 일부 샘플만 실패하면 경고를 남기고 나머지 결과로 정상 종료합니다. | If only some samples fail, the run warns and finishes with the remaining samples. |

### 스크립트 사용 예제
```
bash MACS3_callpeak_ATAC.1.2.sh input_dir=/data/atac_qc output_dir=/data/macs3 genome_size=hs
```

### 주요 결과 이미지 (제안)
frip_summary.tsv를 표 이미지로 캡처하거나, peak 수와 FRiP를 막대그래프로 만들어 등록한다.

---

## 5. peak_annotation

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | peak_annotation | peak_annotation |
| 서브 타이틀 | Peak 유전체 주석 | Peak annotation |
| 버전 | 1.1 | |
| 카테고리 (제안) | Epigenomics / Annotation | |
| 태그 | ATAC-seq, ChIPseeker, peak annotation, promoter, TSS | |
| 레퍼런스 URL | https://bioconductor.org/packages/ChIPseeker/ | |
| 컨테이너 이미지 | bx_peak_annotation.1.0 | |
| 실행 스크립트 파일 | peak_annotation.1.1.R | |

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
| Input | Required | Directory | input_dir | | peak 파일 폴더(하위 폴더 포함). MACS3의 output_dir | Folder of peak files (searched recursively); MACS3 output_dir |
| Input | Required | File | genome_gff | | 유전자 주석 GFF3/GTF(.gz 가능) | Gene annotation GFF3/GTF (.gz allowed) |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | String | genome_label | custom_genome | 로그와 그림에 쓰는 유전체 이름 | Genome name shown in logs and plots |
| Option | Optional | String | peak_suffix | .narrowPeak | peak 파일 이름 끝부분 | Peak file name suffix |
| Option | Optional | Integer | tss_upstream | 3000 | 프로모터 상류 범위(bp) | Promoter upstream range (bp) |
| Option | Optional | Integer | tss_downstream | 3000 | 프로모터 하류 범위(bp) | Promoter downstream range (bp) |
| Option | Optional | String | max_files | NA | 처리할 최대 peak 파일 수. NA는 전부 | Maximum number of peak files; NA processes all |

### 주요 사항
| 국문 | 영문 |
|---|---|
| genome_gff는 BAM과 같은 유전체 버전이어야 하고 염색체 이름 표기도 같아야 합니다. | genome_gff must match the genome version and chromosome naming of the BAM files. |
| 유전자 ID는 genome_gff의 ID를 그대로 사용합니다. GO 분석의 OrgDb와 ID 체계가 맞는지 확인해 주세요. | Gene IDs come from genome_gff as is; check that they match the ID type of the OrgDb used for GO analysis. |

### 스크립트 사용 예제
```
Rscript peak_annotation.1.1.R input_dir=/data/macs3 genome_gff=/ref/genes.gff3 output_dir=/data/peak_annotation genome_label=TAIR10
```

### 주요 결과 이미지 (제안)
`plots/`의 기능 영역 분포(annotation bar/pie)와 TSS 거리 분포 그림을 등록한다.

---

## 6. differential_accessibility

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | differential_accessibility | differential_accessibility |
| 서브 타이틀 | 조건 간 차등 접근성 분석 | Differential accessibility |
| 버전 | 1.2 | |
| 카테고리 (제안) | Epigenomics / Differential Analysis | |
| 태그 | ATAC-seq, edgeR, differential accessibility, GC bias, PCA | |
| 레퍼런스 URL | https://bioconductor.org/packages/edgeR/ | |
| 컨테이너 이미지 | bx_differential_accessibility.1.0 | |
| 실행 스크립트 파일 | differential_accessibility.1.2.R | |

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
| Input | Required | File | sample_data | | 샘플 정보 CSV. (A) SampleID,Condition,bamReads,Peaks 또는 (B) SampleID,Condition | Sample sheet CSV: (A) SampleID,Condition,bamReads,Peaks or (B) SampleID,Condition |
| Input | Required | File | genome_fasta | | 참조 유전체 FASTA(peak GC 계산) | Reference genome FASTA (peak GC content) |
| Input | Optional | Directory | input_dir | | (B) 형식일 때 필수. BAM 폴더(ATAC_QC의 output_dir이면 03_shifted_bam 사용) | Required for format (B): BAM folder (03_shifted_bam of an ATAC_QC output_dir) |
| Input | Optional | Directory | peak_dir | | (B) 형식일 때 필수. MACS3의 output_dir | Required for format (B): MACS3 output_dir |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | String | control_name | control | 기준(분모) 조건 이름. logFC = log2(비교 조건 / 기준 조건) | Baseline (denominator) condition; logFC = log2(other / baseline) |
| Option | Optional | Float | fdr | 0.05 | 유의 기준 FDR | FDR cutoff |
| Option | Optional | String | gc_bin_chr | | GC 편향 그림에 쓸 염색체. 비우면 가장 긴 염색체 | Chromosome for the GC bias plot; empty uses the longest |
| Option | Optional | Integer | tile_width | 5000 | GC 편향 그림의 구간 크기(bp) | Bin size for the GC bias plot (bp) |
| Option | Optional | List | paired | TRUE | paired-end로 read 계산(TRUE/FALSE) | Count reads as paired-end (TRUE/FALSE) |
| Option | Optional | List | run_edaseq | TRUE | EDASeq GC 보정 실행(TRUE/FALSE) | Run EDASeq GC normalization (TRUE/FALSE) |
| Option | Optional | List | run_cqn | TRUE | CQN GC 보정 실행(TRUE/FALSE) | Run CQN GC normalization (TRUE/FALSE) |

### 샘플시트
- 제목(국문): 샘플 정보 파일(sample_data)
- 제목(영문): Sample sheet (sample_data)
- 본문(국문): 두 가지 형식을 지원합니다. (A) SampleID, Condition, bamReads, Peaks 컬럼이 있으면 파일 경로를 그대로 사용합니다(DiffBind 형식). (B) SampleID, Condition만 있으면 input_dir과 peak_dir에서 SampleID로 BAM과 peak 파일을 찾습니다. Condition은 정확히 두 종류여야 합니다.
- 본문(영문): Two formats are supported. (A) With the SampleID, Condition, bamReads, and Peaks columns, the file paths are used as given (DiffBind style). (B) With only SampleID and Condition, BAM and peak files are found by SampleID in input_dir and peak_dir. Condition must have exactly two values.
- 예시 제목: da_sample_data.csv (B 형식)
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

### 스크립트 사용 예제
```
Rscript differential_accessibility.1.2.R sample_data=/data/da_sample_data.csv genome_fasta=/ref/genome.fa input_dir=/data/atac_qc peak_dir=/data/macs3 output_dir=/data/da control_name=control
```

### 주요 결과 이미지 (제안)
`04_plots/MD_plot.pdf`, `PCA_plot.pdf`, `sample_correlation_heatmap.pdf`를 PNG로 변환해 등록한다.

---

## 7. atac_motif

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | atac_motif | atac_motif |
| 서브 타이틀 | 접근성 변화 연관 모티프 분석 | Motif enrichment by accessibility change |
| 버전 | 1.1 | |
| 카테고리 (제안) | Epigenomics / Motif Analysis | |
| 태그 | ATAC-seq, monaLisa, motif enrichment, JASPAR, k-mer | |
| 레퍼런스 URL | https://bioconductor.org/packages/monaLisa/ | |
| 컨테이너 이미지 | bx_atac_motif.1.0 | |
| 실행 스크립트 파일 | atac_motif.1.1.R | |

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
| Input | Optional | Directory | input_dir | | differential_accessibility의 output_dir. input_dir과 da_csv 중 하나는 필수 | differential_accessibility output_dir; one of input_dir or da_csv is required |
| Input | Optional | File | da_csv | | 차등 접근성 결과 CSV를 직접 지정 | Differential accessibility CSV given directly |
| Input | Required | File | genome_fasta | | 참조 유전체 FASTA(.fai 인덱스가 미리 있어야 함) | Reference genome FASTA (the .fai index must exist) |
| Input | Required | File | motif_db | | 모티프 데이터베이스(MEME 형식) | Motif database (MEME format) |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | List | norm | TMM | input_dir에서 읽을 정규화 결과(TMM, EDASeq, CQN) | Normalization result to read from input_dir (TMM, EDASeq, CQN) |
| Option | Optional | String | chrs | | 사용할 염색체(쉼표 구분). 비우면 자동 | Chromosomes to use (comma-separated); empty selects automatically |
| Option | Optional | Float | fdr_filter | | 이 FDR 이하 peak만 사용. 비우면 필터 없음 | Use peaks with FDR at or below this; empty applies no filter |
| Option | Optional | Integer | n_per_bin | 400 | 구간당 peak 수 | Peaks per bin |
| Option | Optional | Float | min_abs_logfc | 0.3 | 구간 나눌 때 쓰는 최소 abs(logFC) | Minimum abs(logFC) used for binning |
| Option | Optional | Float | padj_cutoff | 4.0 | 강하게 농축된 모티프 기준(−log10 조정 p-value) | Strong enrichment cutoff (−log10 adjusted p-value) |
| Option | Optional | Integer | kmer_len | 6 | k-mer 길이 | k-mer length |
| Option | Optional | Float | min_motif_score | 10.0 | 모티프 hit 최소 점수 | Minimum motif hit score |
| Option | Optional | Float | stabsel_cutoff | 0.8 | 안정성 선택 기준(0~1] | Stability selection cutoff (0–1] |
| Option | Optional | Integer | seed | 123 | 난수 시드 | Random seed |
| Option | Optional | String | threads | auto | 스레드 수. auto는 할당된 코어 수 | Threads; auto uses the allocated cores |
| Option | Optional | List | run_kmer | TRUE | k-mer 분석 실행(TRUE/FALSE) | Run k-mer analysis (TRUE/FALSE) |
| Option | Optional | List | run_regression | TRUE | 회귀 분석 실행(TRUE/FALSE) | Run regression analysis (TRUE/FALSE) |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 분석 종에 맞는 JASPAR 분류군(척추동물, 식물 등)의 MEME 파일을 사용해 주세요. | Use a MEME file from the JASPAR taxonomic group of the species (vertebrates, plants, and so on). |
| genome_fasta 옆에 .fai 인덱스가 미리 있어야 합니다. | A .fai index must exist beside genome_fasta. |
| 차등 peak가 적으면 구간 수가 줄어 결과가 불안정할 수 있습니다. n_per_bin과 min_abs_logfc를 조정해 주세요. | With few differential peaks the bins are few and results can be unstable; adjust n_per_bin and min_abs_logfc. |

### 스크립트 사용 예제
```
Rscript atac_motif.1.1.R input_dir=/data/da genome_fasta=/ref/genome.fa motif_db=/ref/JASPAR2024_CORE_plants.meme output_dir=/data/atac_motif
```

### 주요 결과 이미지 (제안)
`02_binned_enrichment`의 모티프 농축 heatmap(seqlogo 포함)을 등록한다.

---

## 8. tf_footprinting

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | tf_footprinting | tf_footprinting |
| 서브 타이틀 | 전사인자 footprint 분석 | Transcription factor footprinting |
| 버전 | 1.1 | |
| 카테고리 (제안) | Epigenomics / Footprinting | |
| 태그 | ATAC-seq, TOBIAS, footprinting, BINDetect, transcription factor | |
| 레퍼런스 URL | https://github.com/loosolab/TOBIAS | |
| 컨테이너 이미지 | bx_tf_footprinting.1.0 | |
| 실행 스크립트 파일 | tf_footprinting.1.1.sh | |

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
| Input | Required | Directory | input_dir | | BAM 폴더. ATAC_QC의 output_dir이면 03_shifted_bam 사용 | BAM folder; 03_shifted_bam of an ATAC_QC output_dir |
| Input | Required | File | metadata | | 샘플 정보 TSV/CSV(SampleID, Condition), 조건 2개 이상 | Sample information TSV/CSV (SampleID, Condition) with two or more conditions |
| Input | Required | File | genome_fasta | | 참조 유전체 FASTA. .fai가 없으면 옆에 생성 | Reference genome FASTA; a missing .fai is created beside it |
| Input | Required | File | motif_db | | 모티프 데이터베이스(MEME/JASPAR 형식) | Motif database (MEME/JASPAR format) |
| Input | Optional | Directory | macs_dir | | MACS3의 output_dir. peak_file이 없으면 필수 | MACS3 output_dir; required without peak_file |
| Input | Optional | File | peak_file | | 미리 합친 공통 peak(BED/narrowPeak/broadPeak) | Pre-merged consensus peaks (BED/narrowPeak/broadPeak) |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | String | sample_col | SampleID | metadata의 샘플 컬럼 이름 | Sample column name in metadata |
| Option | Optional | String | condition_col | Condition | metadata의 조건 컬럼 이름 | Condition column name in metadata |
| Option | Optional | String | cores | auto | 코어 수. auto는 할당된 코어 수 | Cores; auto uses the allocated cores |

### 샘플시트
- 제목(국문): 샘플 정보 파일(metadata)
- 제목(영문): Sample information (metadata)
- 본문(국문): 탭 또는 쉼표로 구분한 파일이며 SampleID와 Condition 컬럼이 필요합니다. 컬럼 이름이 다르면 sample_col, condition_col로 지정합니다. BAM 파일 이름에 SampleID가 포함되어 있어야 합니다.
- 본문(영문): A tab- or comma-separated file with the SampleID and Condition columns; set sample_col and condition_col if the names differ. Each BAM file name must contain its SampleID.
- 예시 제목: metadata.tsv
- 예시 본문:
```
SampleID	Condition
ctrl_1	control
ctrl_2	control
trt_1	treated
trt_2	treated
```

### 주요 사항
| 국문 | 영문 |
|---|---|
| footprint는 시퀀싱 깊이가 충분해야 신뢰할 수 있습니다. 조건별로 BAM을 합쳐 깊이를 확보합니다. | Footprints need sufficient sequencing depth; BAM files are merged per condition to gain depth. |
| 조건이 2개 이상이어야 BINDetect 비교를 수행합니다. | BINDetect comparisons need two or more conditions. |

### 스크립트 사용 예제
```
bash tf_footprinting.1.1.sh input_dir=/data/atac_qc metadata=/data/metadata.tsv macs_dir=/data/macs3 genome_fasta=/ref/genome.fa motif_db=/ref/JASPAR2024_CORE_plants.meme output_dir=/data/tf_footprinting
```

### 주요 결과 이미지 (제안)
`04_BINDetect`의 volcano 그림(조건 간 결합 변화)을 등록한다.

---

## 9. functional_enrichment

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | functional_enrichment | functional_enrichment |
| 서브 타이틀 | GO 기능 농축 분석 | GO enrichment analysis |
| 버전 | 1.0 | |
| 카테고리 (제안) | Functional Analysis / Enrichment | |
| 태그 | ATAC-seq, clusterProfiler, GO, enrichment, OrgDb | |
| 레퍼런스 URL | https://bioconductor.org/packages/clusterProfiler/ | |
| 컨테이너 이미지 | bx_functional_enrichment.1.0 | |
| 실행 스크립트 파일 | functional_enrichment.1.0.R | |

### 내용(국문)
열린 영역 또는 접근성이 변한 영역 근처 유전자가 어떤 생물학적 기능(GO)에 몰려 있는지 clusterProfiler로 분석합니다.
- peak_annotation 결과(input_dir)를 주면 샘플별 연관 유전자 목록을 분석합니다.
- differential_accessibility 결과(da_dir)를 주면 peak마다 가장 가까운 유전자를 찾아 접근성 증가(up)·감소(down) 유전자 목록을 분석합니다.
- 종별 OrgDb 파일 또는 유전자–GO 대응표(GAF 등)를 사용하며, 유전자 ID 종류는 자동으로 맞춥니다.
- GO 항목별 결과표와 dotplot, barplot을 만듭니다.

### 내용(영문)
Analyzes with clusterProfiler which biological functions (GO) are enriched among genes near open regions or regions with changed accessibility.
- With a peak_annotation output (input_dir), the gene list of each sample is analyzed.
- With a differential_accessibility output (da_dir), each peak is assigned to the nearest gene and the up and down gene lists are analyzed.
- An OrgDb file for the species or a gene-to-GO table (GAF and others) is used, and the gene ID type is matched automatically.
- Result tables per GO term, dot plots, and bar plots are produced.

### 입출력 / 파라미터
| 탭 | 필수 | 형식 | Name | Value | Description | English Description |
|---|---|---|---|---|---|---|
| Input | Optional | Directory | input_dir | | peak_annotation의 output_dir. 아래 4개 입력 중 하나만 | peak_annotation output_dir; give only one of the four inputs |
| Input | Optional | File | gene_file | | 유전자 목록 파일 하나 | One gene list file |
| Input | Optional | Directory | da_dir | | differential_accessibility의 output_dir | differential_accessibility output_dir |
| Input | Optional | File | da_file | | 차등 접근성 결과 파일 하나(seqnames/chr, start, end, logFC, FDR) | One differential accessibility table (seqnames/chr, start, end, logFC, FDR) |
| Input | Optional | File | genome_gff | | da_dir/da_file일 때 필수. 유전자 주석 GFF3/GTF | Required with da_dir/da_file: gene annotation GFF3/GTF |
| Input | Optional | File | orgdb_file | | OrgDb SQLite 파일. go_table과 둘 중 하나 | OrgDb SQLite file; one of orgdb_file or go_table |
| Input | Optional | File | go_table | | 유전자–GO 대응표(GAF/TSV/CSV) | Gene-to-GO table (GAF/TSV/CSV) |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Optional | String | gene_keytype | auto | OrgDb ID 종류(TAIR, ENTREZID, SYMBOL 등). auto는 자동 선택 | OrgDb key type (TAIR, ENTREZID, SYMBOL, ...); auto selects it |
| Option | Optional | List | ont | BP | GO 분류(BP, MF, CC, ALL) | GO ontology (BP, MF, CC, ALL) |
| Option | Optional | String | max_distance_to_tss | 3000 | TSS에서 이 거리(bp) 안의 peak에 연결된 유전자만 사용. NA는 전부 | Use genes whose peak is within this distance of the TSS (bp); NA uses all |
| Option | Optional | String | universe | auto | 배경 유전자(auto, all, 또는 파일 경로) | Background genes (auto, all, or a file path) |
| Option | Optional | Float | pvalue_cutoff | 0.05 | 조정 p-value 기준 | Adjusted p-value cutoff |
| Option | Optional | Float | qvalue_cutoff | 0.2 | q-value 기준 | q-value cutoff |
| Option | Optional | List | p_adjust_method | BH | 다중검정 보정(BH, bonferroni, holm, hochberg, hommel, BY, fdr, none) | Multiple testing correction (BH, bonferroni, holm, hochberg, hommel, BY, fdr, none) |
| Option | Optional | Integer | min_gs_size | 10 | GO 항목 최소 유전자 수 | Minimum genes per GO term |
| Option | Optional | Integer | max_gs_size | 500 | GO 항목 최대 유전자 수 | Maximum genes per GO term |
| Option | Optional | Float | min_mapped_fraction | 0.5 | 주석에서 찾은 ID 비율이 이보다 낮으면 중단 | Stop if fewer IDs than this fraction are found in the annotation |
| Option | Optional | Integer | show_category | 20 | 그림에 보일 GO 항목 수 | GO terms shown in plots |
| Option | Optional | List | da_norm | TMM | da_dir에서 읽을 정규화 결과(TMM, EDASeq, CQN) | Normalization result to read from da_dir (TMM, EDASeq, CQN) |
| Option | Optional | Float | da_fdr | 0.05 | up/down peak FDR 기준 | FDR cutoff for up/down peaks |
| Option | Optional | Float | da_min_abs_logfc | 0 | up/down peak 최소 abs(logFC) | Minimum abs(logFC) for up/down peaks |

### 주요 사항
| 국문 | 영문 |
|---|---|
| 분석 종의 OrgDb 파일(tools/download_orgdb.R로 저장) 또는 유전자–GO 대응표가 필요합니다. | An OrgDb file for the species (saved with tools/download_orgdb.R) or a gene-to-GO table is required. |
| 인터넷 연결 없이 수행하므로 KEGG 경로 분석은 지원하지 않습니다. | The analysis runs offline, so KEGG pathway analysis is not supported. |
| genome_gff의 유전자 ID가 OrgDb에서 절반 이상 찾아지지 않으면 중단합니다. 종과 ID 체계를 확인해 주세요. | The run stops if fewer than half of the genome_gff gene IDs are found in the OrgDb; check the species and ID type. |
| 입력은 input_dir, gene_file, da_dir, da_file 중 하나만 지정합니다. | Give only one of input_dir, gene_file, da_dir, or da_file. |

### 스크립트 사용 예제
```
Rscript functional_enrichment.1.0.R da_dir=/data/da genome_gff=/ref/genes.gff3 orgdb_file=/ref/OrgDb/Arabidopsis_thaliana.AH121945.OrgDb.sqlite output_dir=/data/functional_enrichment
```

### 주요 결과 이미지 (제안)
`03_plots/<목록>.GO_BP.dotplot.pdf`를 PNG로 변환해 등록한다.

---

## 10. replicate_consistency

### 기본 정보
| 항목 | 국문 | 영문 |
|---|---|---|
| 모듈명 | replicate_consistency | replicate_consistency |
| 서브 타이틀 | 반복 실험 peak 재현성(IDR) | Replicate consistency (IDR) |
| 버전 | 1.0 | |
| 카테고리 (제안) | Quality Control / Reproducibility | |
| 태그 | ATAC-seq, IDR, reproducibility, replicate, MACS3 | |
| 레퍼런스 URL | https://github.com/nboley/idr | |
| 컨테이너 이미지 | bx_replicate_consistency.1.0 | |
| 실행 스크립트 파일 | replicate_consistency.1.0.sh | |

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
| Input | Required | Directory | input_dir | | Tn5 보정 BAM 폴더. ATAC_QC의 output_dir이면 03_shifted_bam에서 찾음 | Folder of Tn5-shifted BAM files; 03_shifted_bam of an ATAC_QC output_dir |
| Input | Required | File | sample_data | | ATAC_QC와 같은 샘플 정보 CSV(SampleID, Condition, Replicate) | Same sample sheet CSV as ATAC_QC (SampleID, Condition, Replicate) |
| Output | Required | Directory | output_dir | | 결과 폴더 | Output folder |
| Option | Required | String | genome_size | | 유효 유전체 크기(MACS3와 같음). hs, mm, ce, dm 또는 숫자 | Effective genome size (as for MACS3): hs, mm, ce, dm, or a number |
| Option | Optional | String | alignment_suffix | .shifted.bam | BAM 파일 이름 끝부분 | BAM file name suffix |
| Option | Optional | Float | pvalue | 0.01 | 느슨한 peak 기준(p-value) | Relaxed peak threshold (p-value) |
| Option | Optional | Float | idr_threshold | 0.05 | 재현 peak 기준(global IDR) | Reproducible peak threshold (global IDR) |
| Option | Optional | Integer | max_peaks | 300000 | 반복 실험마다 p-value 순으로 남길 최대 peak 수 | Maximum relaxed peaks kept per replicate, by p-value |

### 샘플시트
ATAC_QC와 같은 sample_data.csv를 사용한다(2번 모듈의 샘플시트 내용을 그대로 등록).

### 주요 사항
| 국문 | 영문 |
|---|---|
| 조건마다 반복 실험이 2개 이상이어야 합니다. 반복이 1개인 조건은 건너뜁니다. | Each condition needs two or more replicates; conditions with one replicate are skipped. |
| 품질 확인용 모듈이며, 결과 peak를 다른 모듈이 이어받지는 않습니다. | This is a QC module; its peaks are not passed to other modules. |
| 의사 반복(pseudo-replicate) 분석은 수행하지 않습니다. | Pseudo-replicate analysis is not performed. |

### 스크립트 사용 예제
```
bash replicate_consistency.1.0.sh input_dir=/data/atac_qc sample_data=/data/sample_data.csv genome_size=hs output_dir=/data/replicate_consistency
```

### 주요 결과 이미지 (제안)
`02_idr/<조건>/<쌍>.idr.txt.png`(IDR 산점도)를 등록한다.
