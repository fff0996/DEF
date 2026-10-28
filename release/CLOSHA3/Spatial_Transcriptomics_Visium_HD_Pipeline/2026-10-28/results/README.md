# 배포 시점 결과 (2026-10-28)

이 배포본(스크립트)으로 CLOSHA에서 실행한 결과를 모듈별 폴더에 올립니다. 원고의 "주요 결과 이미지"에 쓰는 PNG와 요약표, 로그만 올리고, Seurat 객체(`*.rds`), PDF, 큰 표는 올리지 않습니다(`.gitignore`가 막습니다).

폴더: `results/<모듈 이름>/` (모듈의 `output_dir` 구조를 그대로 둡니다)

| 모듈 | 올릴 파일 |
|---|---|
| spatial_hd_prep | `hd_prep_summary.tsv`, `<slide>/plots/<slide>_qc.png`, `logs/` |
| spatial_hd_cluster | `joint/cluster_by_slide.tsv`, `joint/top_markers.tsv`, `joint/plots/*.png`, `<slide>/plots/<slide>_clusters_spatial.png`, `logs/` |
| spatial_hd_svf | `svf_summary.tsv`, `<slide>/<slide>_hd_svf.tsv`, `<slide>/plots/<slide>_top_svf.png`, `logs/` |
| spatial_condition_de | `04_summary/de_summary.tsv`, `01_composition/*.tsv`, `03_plots/*.png`, `logs/` |
| spatial_hd_rctd | `rctd_summary.tsv`, `celltype_by_slide.tsv`, `plots/celltype_by_slide.png`, `<slide>/plots/<slide>_rctd_first_type.png`, `logs/` |
| check_reference | `reference_columns.tsv`, `logs/` |

원고의 결과 그림은 배포 전(2026-10-27~28) 같은 내용의 작업 파일로 CLOSHA에서 실행한 결과입니다.
