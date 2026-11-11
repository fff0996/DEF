# 배포 시점 결과 (2026-11-11)

이 배포본(스크립트)으로 CLOSHA에서 실행한 결과를 모듈별 폴더에 올립니다. 원고의 "주요 결과 이미지"에 쓰는 그림과 요약표만 올립니다. 데이터셋·임베딩·모델(`*.h5ad`, `*.pt`, `model/`)은 크기가 크고, 예제 데이터(K-BDS KAP241712)가 승인 사용자 전용이라 올리지 않습니다(`.gitignore`가 막습니다). 환자·공여자 ID가 들어 있는 표(`patients.tsv`, `predictions.tsv` 등)도 올리지 않습니다.

예제: K-BDS KAP241712 심장 단일핵 데이터, Chaffin 2022 좌심실 샘플, DCM 11명 대 HCM 15명, `positive_label=DCM`, `time=all`, 나머지 기본값.

폴더: `results/<모듈 이름>/` (모듈 output_dir의 파일 이름 그대로)

| 모듈 | 올릴 파일 | 상태 |
|---|---|---|
| scgpt_prep | `plots/cells_per_patient.png`, `plots/qc_by_sample.png`, `plots/cell_types_by_patient.png`, `gene_match.tsv` | 받기 전 |
| scgpt_embed | `plots/embedding_umap.png` | 원고에 반영(`portal_images/scgpt_embed/`) |
| scgpt_train | `plots/roc_cv.png`, `plots/training_loss.png`, `cv_metrics.tsv` | 받기 전 |
| scgpt_predict | `plots/predictions.png`, `plots/attention_by_cell_type.png` | 받기 전 |
| scgpt_compare | `plots/roc.png`, `plots/auc.png`, `compare_metrics.tsv`, `compare_delta.tsv`, `summary.md` | 그림은 원고에 반영, 표는 받기 전 |
