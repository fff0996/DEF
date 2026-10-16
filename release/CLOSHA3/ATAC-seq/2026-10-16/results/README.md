# 배포 시점 결과 (2026-10-16)

이 배포본(스크립트)으로 CLOSHA에서 실행한 결과를 모듈별 폴더에 올립니다. 원고의 "주요 결과 이미지"에 쓰는 파일과 요약표만 올리고, 큰 파일은 올리지 않습니다(`.gitignore`가 막습니다).

폴더: `results/<모듈 이름>/` (모듈의 output_dir 구조를 그대로 둡니다)

| 모듈 | 올릴 파일 |
|---|---|
| bowtie2 | `<sample>_bowtie.log` |
| GATK_MarkDuplicates | `<sample>_duplicate_metrics.txt` |
| organellar_filter | `04_summary/organellar_filter_summary.tsv` |
| ATAC_QC | `01_fragment_size/<sample>/<sample>.fragSizeDist.pdf`, `07_tss_enrichment/<sample>.tss_enrichment.pdf`, `05_metadata/atac_qc_metrics.tsv` |
| ATAC_QC_plot | `01_tss_signal/<sample>.Heatmap_splitbam.pdf`, `01_tss_signal/<sample>.TSSprofile_splitbam.pdf` |
| MACS3_callpeak_ATAC | `frip_summary.tsv` |
| peak_annotation | `plots/annotation_summary_percent_barplot.pdf`, `plots/<sample>.annotation_upset.pdf`, `plots/<sample>.distance_to_tss.pdf`, `plots/<sample>.tss_profile.pdf` |
| differential_accessibility | `04_plots/PCA_plot.pdf`, `04_plots/sample_correlation_heatmap.pdf`, `04_plots/MD_plot.pdf`, `04_plots/logFC_by_GC_bin_*.pdf` |
| atac_motif | `02_binned_enrichment/binned_motif_heatmap.pdf`, `01_qc/bin_density.pdf`, `04_regression/selection_probability.pdf`, `03_kmer/kmer_motif_similarity.pdf` |
| tf_footprinting | `04_BINDetect/bindetect_figures.pdf` (4쪽 맨 위 volcano plot, 3쪽 정규화 후 점수 분포) |
| functional_enrichment | `03_plots/<list>.GO_BP.dotplot.pdf`, `03_plots/<list>.GO_BP.barplot.pdf`, `04_summary/enrichment_summary.tsv` |
| replicate_consistency | `02_idr/<condition>/<repA>_vs_<repB>.idr.txt.png`, `04_summary/idr_summary.tsv` |

각 모듈 폴더에 `logs/`(실행 로그 `.log`, `.error.log`)도 같이 올리면 실행 조건(파라미터)이 함께 남습니다.
