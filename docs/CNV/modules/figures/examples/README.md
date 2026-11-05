`gene_oncoprint.png` / `.pdf`: cnv_summary oncoprint 예시(2026-11-05). **TCGA 폐선암(LUAD, PanCancer Atlas) 공개 데이터 10명**(cBioPortal 공개 API, TCGA, Cell 2018)을 `tools/cnv/make_tcga_example.py`로 받아 cnvkit_call 출력 형태로 바꾼 뒤, **bx_cnvkit 1.0 SIF 안에서** `scripts/CNV/cnv_summary.1.0.py`(공개 모듈과 같은 `--cleanenv`, `*_NUM_THREADS=1`)로 실행한 실제 출력(`03_plots/gene_oncoprint.png`)이다.

- 칸 바탕: 유전자 복제수 판정 = **TCGA GISTIC2 판정**(-2 DEEPDEL, -1 LOSS, 1 GAIN, 2 AMP). 안쪽 막대: **TCGA MC3 체세포 돌연변이**(`tcga_luad_mutations.maf`, Missense 초록, Truncating 검정). 우리 CNVkit 모듈이 만든 판정이 아니다. 그림을 쓸 때는 "TCGA LUAD 10명(cBioPortal; GISTIC2 복제수, MC3 돌연변이)"이라고 밝힌다.
- 주석 줄: 병기, 성별, 생존 상태, Fraction genome altered (`tcga_luad_sample_data.csv`). 샘플 목록과 출처는 `tcga_luad_SOURCE.txt`.
- 재현: `python3 tools/cnv/make_tcga_example.py <dir> 10 7` 후 `cnv_summary.1.0.py input_dir=<dir>/cnvkit_call genes=<dir>/genes.txt sample_data=<dir>/sample_data.csv maf=<dir>/mutations.maf genome=hg19 output_dir=<out>`.

모의 데이터 입력(`tools/cnv/make_simulated_cohort.py`)은 테스트용으로만 쓴다.
