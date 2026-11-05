scGPT 결과 그림 (2026-11-05)

공개 10x PBMC 3k(scanpy pbmc3k raw)를 가짜 환자 11명(코호트 2개, PR 5, PD 5, 라벨 없음 1)으로 나눈 예제(`tools/scgpt/make_test_data.py`, 반응군에 단핵구를 더 뽑아 신호를 심음)를 `bx_scgpt` 1.0 SIF(CPU)에서 다섯 모듈로 실행한 실제 출력이다. 환자당 40세포. 실제 환자 데이터가 아니다.

| 파일 | 모듈 출력 |
|---|---|
| scgpt_embed_result_1.png | scgpt_embed `plots/embedding_umap.png` (라벨, 코호트, 세포 유형별 scGPT 임베딩 UMAP) |
| scgpt_predict_result_1.png | scgpt_predict `plots/attention_by_cell_type.png` (모델이 무게를 둔 세포 유형: attention 비율 / 세포 비율) |
| scgpt_compare_result_1.png | scgpt_compare `plots/roc.png` (보지 않은 환자에서의 ROC, 기준선과 학습 모델) |

실행 스크립트: `/workspaces/.closha_build_test/scgpt/rerun_for_figures.sh`
