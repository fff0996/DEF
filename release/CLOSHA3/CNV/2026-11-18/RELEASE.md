# CLOSHA 3.0 CNV 배포 (2026-11-18)

체세포 복제수 변이 파이프라인 `Somatic_CNV_Pipeline`은 CLOSHA 3.0에서 처음 배포하는 파이프라인입니다. CNVkit 0.9.14로 정상 기준 대비 복제수 비를 구하고, 짝 정상이 있으면 FACETS 0.6.2로 순도·배수성·대립유전자별 복제수(LOH)를 추정해 CNVkit 판정을 보정합니다. 종양-정상 쌍과 종양 단독을 한 파이프라인에서 처리하며, 샘플 정보 파일의 `NormalID`가 모드를 정합니다. 이 폴더는 배포 시점의 기록이므로 **배포 후에는 고치지 않습니다.** 다음 배포는 새 날짜 폴더로 만듭니다.

## 배포 스크립트

CLOSHA 3.0 신규 파이프라인이므로 네 모듈 모두 1.0입니다. cnvkit_call은 작업 번호가 1.1이라(범례 색 수정) 버전 블록을 빼고 1.0 이름으로 배포합니다. 나머지 셋은 작업 파일과 같습니다.

| 모듈 | 배포 파일 | CLOSHA 2.0 | 작업 파일(내용 출처) | 실행 이미지 | 등록 자원 |
|---|---|---|---|---|---|
| cnvkit_reference | `cnvkit_reference.1.0.py` | (3.0 신규) | `scripts/CNV/cnvkit_reference.1.0.py` | bx_cnvkit 1.0 (`defs/CNV/bx_cnvkit.1.0.def`) | 4코어, 16GB |
| cnv_facets | `cnv_facets.1.0.R` | (3.0 신규) | `scripts/CNV/cnv_facets.1.0.R` | bx_facets 1.0 (`defs/CNV/bx_facets.1.0.def`) | 4코어, 32GB |
| cnvkit_call | `cnvkit_call.1.0.py` | (3.0 신규) | `scripts/CNV/cnvkit_call.1.1.py` | bx_cnvkit 1.0 | 4코어, 16GB |
| cnv_summary | `cnv_summary.1.0.py` | (3.0 신규) | `scripts/CNV/cnv_summary.1.0.py` | bx_cnvkit 1.0 | 1코어, 8GB |

- 파이프라인 연결: cnvkit_reference.output_dir → cnvkit_call.reference_dir, cnv_facets.output_dir → cnvkit_call.facets_dir와 cnv_summary.facets_dir, cnvkit_call.output_dir → cnv_summary.input_dir. cnvkit_call.input_dir는 BAM 폴더를 직접 넣습니다.
- **cnv_facets만 bx_facets 이미지**입니다(snp-pileup이 이 이미지에만 있음). 다른 이미지로 등록하면 `required command not found in PATH: snp-pileup`으로 멈춥니다.
- 자원은 WES와 WGS를 모두 덮는 값입니다. 최종 값은 2026-11-30 자원 정리 날 CLOSHA 실측(sacct MaxRSS)으로 다시 맞춥니다.

## 이번 배포에 들어간 주요 결정과 수정

- 파이프라인 하나로 합침(2026-11-17): `NormalID`가 모든 행에서 비면 cnv_facets가 헤더만 있는 `facets_summary.tsv`를 쓰고 종료 코드 0으로 끝나며, cnvkit_call과 cnv_summary는 순도 보정 없이 진행합니다. cnvkit_reference는 정상이 없으면 flat 기준을 만듭니다.
- 인자: Python 모듈 셋은 `key=value`, `--key=value`, `--key value`를 모두 받습니다. CLOSHA 첫 실행(2026-11-17)에서 `Invalid argument format: --input_dir`로 멈춰 고쳤습니다. R 모듈(cnv_facets)은 `key=value`.

## 만든 방법과 확인

- `build_release.py`가 작업 파일을 복사하고(cnvkit_call은 버전 블록 제거, 이름 바꿈), 원고·포탈 이미지·파이프라인 그림을 복사하며, `portal_images.zip`을 만듭니다.
- `python3 tools/check_release.py release/CLOSHA3/CNV/2026-11-18`: 4개 모두 일치. 이 배포에서 검사 도구가 버전 블록 바로 뒤에 빈 줄이 없는 파일(cnvkit_call.1.1.py)을 잘못 읽던 것을 고쳤고, 기존 배포 폴더 다섯 개도 모두 다시 일치를 확인했습니다.
- Codespace(2026-11-17): 두 이미지를 fakeroot로 빌드해 `%test` 통과. SEQC2 HCC1395 WES(염색체 6, 13, 17, 18, 21)로 쌍 실행과 종양 단독 실행 모두 네 모듈 종료 코드 0. 이후 바꾼 인자 해석은 세 형식·빈 값·잘못된 인자를 함수 단위로 확인했고, SIF 안 전체 재실행은 하지 않았습니다.
- CLOSHA(2026-11-17, 사용자): SEQC2 WES 쌍으로 실행. 인자 형식과 cnv_facets 이미지 등록을 바로잡은 뒤 실행 완료.

## 함께 넣은 것

- `docs/`: 모듈 원고(`Portal_Content.md`, `.docx`), 등록 정보(`Registration.md`), 실행 이미지 안내(`Container_Manual.md`), 설계(`CNV_Pipeline_Design.md`)
- `docs/pipeline/`: 파이프라인 원고(`Portal_Content.md`, `.docx`)와 흐름도·개념도(PNG, 원본 SVG)
- `portal_images/`, `portal_images.zip`: 포탈에 올리는 PNG(모듈 개념도 4개, 결과 그림 18개, 파이프라인 흐름도·개념도)

## 남은 일 (다음 배포)

- 예제 데이터와 결과 그림 교체: PRJNA1087680 조기 발병 유방암 종양-혈액 10쌍(`tools/cnv/fetch_prjna1087680_pairs.sh`, 종양 시퀀싱 양 상위 10쌍을 CNV 결과를 보기 전에 고정). CLOSHA에서 정렬 후 전체 실행하고, 대표 샘플 CNV profile과 10명 전체 heatmap·oncoprint로 결과 그림을 바꿉니다. 타깃 BED(IDT xGen v1)는 hg19 좌표라 hg38 변환이 필요합니다.
- 현재 결과 그림은 SEQC2 부분 데이터(1쌍)와 TCGA LUAD 10명 예제(cnv_summary oncoprint, GISTIC2 판정)입니다.
- 파이프라인 대표 이미지(썸네일)
