`gene_oncoprint.png` / `.pdf`: cnv_summary oncoprint 예시(2026-11-05). **TCGA 폐선암(LUAD, PanCancer Atlas) 공개 데이터 10명**(cBioPortal 공개 API, TCGA, Cell 2018)을 `tools/cnv/make_tcga_example.py`로 받아 cnvkit_call 출력 형태로 바꾼 뒤 `scripts/CNV/cnv_summary.1.0.py`에 그대로 넣어 실행한 실제 출력(`03_plots/gene_oncoprint.png`)이다.

- 유전자 판정은 **TCGA GISTIC2 판정**(-2 DEEPDEL, -1 LOSS, 1 GAIN, 2 AMP)이고 세그먼트는 TCGA hg19 세그먼트다. 우리 CNVkit 모듈이 만든 판정이 아니다. 그림을 쓸 때는 "TCGA LUAD 10명(cBioPortal, GISTIC2 판정)"이라고 밝힌다.
- 주석 줄: 병기, 성별, 생존 상태, Fraction genome altered (`tcga_luad_sample_data.csv`). 샘플 목록과 출처는 `tcga_luad_SOURCE.txt`.
- 재현: `python3 tools/cnv/make_tcga_example.py <dir> 10 7` 후 `python3 scripts/CNV/cnv_summary.1.0.py input_dir=<dir>/cnvkit_call genes=<dir>/genes.txt sample_data=<dir>/sample_data.csv output_dir=<out>`.

모의 데이터 입력(`tools/cnv/make_simulated_cohort.py`)은 테스트용으로만 쓴다.
