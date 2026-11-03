# 배포 시점 결과 (2026-11-03)

이 배포본(스크립트)으로 CLOSHA에서 실행한 결과를 모듈별 폴더에 올립니다. 원고의 "주요 결과 이미지"에 쓰는 PNG와 요약표, 로그만 올리고, 큰 표(`*.tsv.gz`), PDF, Seurat 객체는 올리지 않습니다(`.gitignore`가 막습니다).

폴더: `results/<모듈 이름>/` (모듈의 `output_dir` 구조를 그대로 둡니다)

| 모듈 | 올릴 파일 |
|---|---|
| spatial_niche | `niche_composition.tsv`, `niche_by_slide.tsv`, `niche_test.tsv`, `plots/*.png`, `<slide>/plots/<slide>_niches.png`, `logs/` |
| spatial_signature_score | `gene_sets_used.tsv`, `signature_by_group.tsv`, `signature_by_slide.tsv`, `signature_test.tsv`, `plots/*.png`, `logs/` |
| spatial_de_enrichment | `gene_sets_used.tsv`, `01_gsea/*.tsv`, `02_summary/*.tsv`, `03_plots/*.png`, `logs/` |

원고의 결과 그림은 배포 전(2026-11-02~03) 같은 내용의 작업 파일로 CLOSHA에서 실행한 결과입니다.
