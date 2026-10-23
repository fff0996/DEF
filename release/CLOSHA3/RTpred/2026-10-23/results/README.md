# 배포 시점 결과 (2026-10-23)

이 배포본(스크립트)으로 CLOSHA에서 실행한 결과를 모듈별 폴더에 올립니다. 원고의 "주요 결과 이미지"에 쓰는 파일과 요약표만 올리고, 학습 모델(`model/`)처럼 큰 파일은 올리지 않습니다(`.gitignore`가 막습니다).

폴더: `results/<모듈 이름>/` (모듈의 `output_dir/result/` 구조를 그대로 둡니다)

| 모듈 | 올릴 파일 |
|---|---|
| rtpred_predict | `prediction.png`, `predictions.csv`, `manifest.json` |
| rtpred_train | `train_summary.tsv`, `<MODE>/training.png`, `<MODE>/validation_leaderboard.csv`, `<MODE>/split_assignments.csv` |
| rtpred_compare | `compare_summary.tsv`, `comparison.csv`, `<MODE>/comparison.png` |
