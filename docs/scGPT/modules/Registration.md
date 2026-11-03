scGPT 환자 단위 예측 파이프라인 모듈 등록 정보 (스크립트 최신 버전 기준)

작성일: 2026-11-03

CLOSHA에 scGPT 파이프라인 모듈을 등록할 때 쓰는 Input / Output / Option과 자원 정리다. 기준은 `scripts/scGPT/`의 모듈별 최신 버전(아래 표)이고, 모든 스크립트는 `key=value` 인자를 받는다. 설계는 `docs/scGPT/scGPT_Pipeline_Design.md`.

| 모듈 | 작업 파일 | 배포 번호 | 실행 이미지 | Computing Environment |
|---|---|---|---|---|
| scgpt_prep | `scgpt_prep.1.0.py` | 1.0 | `bx_scgpt.1.0` | HPC |
| scgpt_embed | `scgpt_embed.1.0.py` | 1.0 | `bx_scgpt_gpu.1.0` | **GPU** |
| scgpt_train | `scgpt_train.1.0.py` | 1.0 | `bx_scgpt.1.0` | HPC |
| scgpt_predict | `scgpt_predict.1.0.py` | 1.0 | `bx_scgpt.1.0` | HPC |
| scgpt_compare | `scgpt_compare.1.0.py` | 1.0 | `bx_scgpt.1.0` | HPC |

실행 명령은 모두 `python3 <스크립트> key=value ...`이다. GPU 모듈은 apptainer 실행에 `--nv`가 필요하다(CLOSHA GPU 환경에서 붙는지 첫 실행 로그로 확인: 로그의 `device (resolved) = cuda <GPU 이름>`).

## 0. 파이프라인 흐름
```
행렬 폴더 + 샘플 시트 ─> [scgpt_prep] ─output_dir─> [scgpt_embed](GPU) ─output_dir─┬─> [scgpt_train] ─output_dir(모델)─┐
                                                                                 ├─> [scgpt_predict] <───────────────┤
                                                                                 └─> [scgpt_compare] <───────────────┘
```
- train, predict, compare는 모두 embed의 output_dir를 `input_dir`로 받는다. predict와 compare는 train의 output_dir를 `model`/`models`로 받는다.
- 새 환자 예측: 새 데이터로 prep → embed를 돌리고, predict에 학습된 모델(train output_dir)을 준다.

## 1. scgpt_prep
샘플별 count 행렬과 샘플 시트로 AI-ready 데이터셋을 만든다(세포 QC, scGPT 어휘와 유전자 맞춤, 대략의 세포 유형, 라벨 점검, 환자 단위 fold). 라벨은 만들지 않고 시트의 라벨을 연결·점검한다.
자원(코어, 메모리): 1코어, 64GB (병렬 없음. 메모리는 세포 수에 비례: 78명 × 약 1,500세포 규모 기준 여유값, CLOSHA 실측 후 조정)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 샘플마다 행렬 하나: `<SampleID>.h5`(Cell Ranger), `<SampleID>.h5ad`(raw count), 또는 `<SampleID>/` 폴더(10x mtx) |
| Input | `sample_data` | File (CSV) | 필수 | | 샘플 시트. 열: `SampleID`, `PatientID`, `Cohort`, `Tissue`, `Time`, `Label`(예측할 환자는 비움). 다른 열은 메타데이터로만 보관 |
| Output | `output_dir` | Directory | 필수 | | `dataset.h5ad`, `patients.tsv`, `samples.tsv`, `splits.tsv`, `splits_cohort.tsv`, `gene_match.tsv`, `cohort_labels.tsv`, `data_dictionary.tsv`, `prep_info.json`, `plots/` |
| Option | `positive_label` | String | 선택 | | 양성(1)으로 볼 라벨 값(예: PR). 라벨이 있으면 필요(1/0이면 생략 가능) |
| Option | `time` | String | 선택 | `Before` | 남길 채취 시점. `all`이면 모두 |
| Option | `tissue` | String | 선택 | `auto` | 남길 조직. auto는 시트에 조직이 하나일 때 그것, 여럿이면 멈춤 |
| Option | `min_genes` | Integer | 선택 | `200` | 세포당 최소 검출 유전자 수 |
| Option | `max_mito` | Float | 선택 | `20` | 세포당 미토콘드리아 UMI 비율(%) 상한 |
| Option | `min_cells_per_sample` | Integer | 선택 | `50` | QC 뒤 세포가 이보다 적은 샘플은 제외 |
| Option | `folds` | Integer | 선택 | `5` | 환자 단위 교차검증 fold 수 |
| Option | `repeats` | Integer | 선택 | `3` | 교차검증 반복 수 |
| Option | `checkpoint_dir` | Directory | 선택 | `builtin` | scGPT 체크포인트 폴더(vocab.json 사용). builtin은 이미지 안 whole-human |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 2. scgpt_embed (GPU)
고정된 사전학습 scGPT로 세포마다 512차원 임베딩을 만든다. scGPT 0.2.4 `embed_data`와 같은 계산(Codespace에서 세포별 코사인 0.997 이상 일치 확인).
자원(코어, 메모리): **GPU 환경**, 4코어, 64GB (CLOSHA 실측 후 조정. CPU만 쓰면 세포당 약 2초로 매우 느림)

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | scgpt_prep의 output_dir |
| Output | `output_dir` | Directory | 필수 | | `embeddings.h5ad`, `embed_info.json`, prep 표 복사본, `plots/embedding_umap` |
| Option | `checkpoint_dir` | Directory | 선택 | `builtin` | scGPT 체크포인트 폴더(args.json, best_model.pt, vocab.json). builtin은 whole-human |
| Option | `max_cells_per_patient` | Integer | 선택 | `500` | 환자당 무작위로 쓸 세포 수(0이면 전부) |
| Option | `max_genes` | Integer | 선택 | `1200` | 세포당 모델 입력 유전자 수(모델 학습 길이) |
| Option | `batch_size` | String | 선택 | `auto` | auto = GPU 64, CPU 16 |
| Option | `device` | List (`auto`, `cuda`, `cpu`) | 선택 | `auto` | auto는 GPU가 보이면 GPU |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 3. scgpt_train
임베딩 위에 환자 단위 분류기(gated attention 또는 평균)를 학습한다. prep의 fold로 교차검증하고, 전체 환자로 최종 모델과 모델 카드를 만든다.
자원(코어, 메모리): 4코어, 16GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | scgpt_embed의 output_dir(라벨 있는 환자 필요) |
| Input | `init_model` | Directory | 선택 | | 이어서 학습할 기존 scgpt_train output_dir |
| Output | `output_dir` | Directory | 필수 | | `model/`(model.pt, model_card.json/.md), `cv_predictions.tsv`, `cv_cohort_predictions.tsv`, `cv_metrics.tsv`, `plots/` |
| Option | `pooling` | List (`attention`, `mean`) | 선택 | `attention` | 세포를 환자로 묶는 방법 |
| Option | `hidden` | Integer | 선택 | `64` | attention 층 크기 |
| Option | `epochs` | Integer | 선택 | `200` | 학습 반복 |
| Option | `learning_rate` | Float | 선택 | `0.001` | 학습률 |
| Option | `weight_decay` | Float | 선택 | `0.01` | L2 규제 |
| Option | `dropout` | Float | 선택 | `0.25` | 환자 벡터 dropout |
| Option | `cell_dropout` | Float | 선택 | `0.2` | 학습마다 무작위로 뺄 세포 비율 |
| Option | `model_name` | String | 선택 | `scgpt_<날짜>` | 모델 카드 이름 |
| Option | `data_terms` | String | 선택 | | 학습 데이터 이용 조건(모델 카드에 기록) |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 4. scgpt_predict
학습된 모델로 환자별 양성 확률과 세포별 attention을 낸다. 라벨이 없어도 된다.
자원(코어, 메모리): 1코어, 16GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 예측할 환자의 scgpt_embed output_dir |
| Input | `model` | Directory | 선택 | `builtin` | scgpt_train의 output_dir. builtin은 이미지 안 기본 모델(1.0 이미지에는 없음: 지금은 model을 꼭 줘야 함) |
| Output | `output_dir` | Directory | 필수 | | `predictions.tsv`, `cell_attention.tsv.gz`, `attention_by_cell_type.tsv`, `model_card.json`, `plots/` |
| Option | `threshold` | Float | 선택 | `0.5` | 양성으로 부를 확률 기준 |

## 5. scgpt_compare
같은 환자, 같은 fold에서 기준선(세포 유형 비율, 고변동 유전자 PCA, scGPT 그대로)과 학습 모델을 비교한다. 짝지은 부트스트랩 AUC 차이로 "더 좋은지" 판단한다.
자원(코어, 메모리): 4코어, 32GB

| 구분 | 이름 | 형식 | 필수 | 기본값 | 설명 |
|---|---|---|---|---|---|
| Input | `input_dir` | Directory | 필수 | | 라벨 있는 scgpt_embed output_dir(PCA 기준선은 embed_info.json에 적힌 prep 폴더도 읽음) |
| Input | `models` | String | 선택 | | scgpt_train output_dir들(쉼표 구분). 비우면 기준선만 |
| Output | `output_dir` | Directory | 필수 | | `compare_metrics.tsv`, `compare_delta.tsv`, `compare_cohort.tsv`, `compare_predictions.tsv`, `summary.md`, `plots/` |
| Option | `n_hvg` | Integer | 선택 | `2000` | PCA 기준선의 고변동 유전자 수 |
| Option | `n_pcs` | Integer | 선택 | `30` | PCA 기준선의 주성분 수 |
| Option | `permutations` | Integer | 선택 | `1000` | AUC 순열 검정 횟수 |
| Option | `seed` | Integer | 선택 | `1234` | 난수 시드 |

## 6. Codespace 테스트 (2026-11-03)
공개 10x PBMC 3k를 가짜 환자 11명(코호트 2개, PR 5·PD 5·라벨 없음 1, 한 환자는 After 샘플 추가, 한 샘플은 mtx 폴더)으로 나눈 예제(`tools/scgpt/make_test_data.py`; 반응군에 단핵구를 더 뽑아 신호를 심음). 개발 환경(같은 conda-forge 패키지, CPU)에서 실행.

| 모듈 | 결과 |
|---|---|
| scgpt_prep | 11/12 샘플 사용(After 제외), 라벨 없는 환자 경고, fold 3×2, 코호트 하나 빼기 2개 |
| scgpt_embed | CPU, 환자당 12세포 132개, 3.9분(0.6 cells/s). scgpt.tasks.embed_data와 세포별 코사인 0.997~0.999 |
| scgpt_train | attention CV AUC 0.76(10명이라 95% CI 0.33~1.0), mean CV AUC 1.0 |
| scgpt_predict | 11명 예측(라벨 없는 P99 포함), attention 가중치가 단핵구(FCGR3A+)에 가장 큼(심은 신호와 일치) |
| scgpt_compare | 기준선 3개 + 모델 2개. 10명이라 모두 "not clearly different", 경고 출력 |

인자 오류(필수 인자 없음, key=value 아님)는 종료 코드 1, stderr로만 나간다. 사이트 차단 명령어 없음.

### 6.1 SIF 실행 확인 (2026-11-03)
Codespace(4코어 16GB) fakeroot 빌드: `bx_scgpt` 1.0 5분, SIF 976MB / `bx_scgpt_gpu` 1.0 7분, SIF 5.3GB, 둘 다 `%test` 통과(실제 가중치로 세포 2개 임베딩; GPU판은 CUDA 12.6 빌드 확인, Codespace에 GPU가 없어 GPU 인식은 False). 공개 모듈과 같은 명령(`--cleanenv`, `OMP_NUM_THREADS=1` 등)으로 위 예제를 SIF 안에서 다섯 모듈 모두 실행해 종료 코드 0. embed는 GPU 이미지가 CPU로 돌아 132세포 2.2분. 로그의 코어 수는 `threads = 4 (allocated 4)`로 OMP_NUM_THREADS=1과 상관없이 할당 코어를 읽었다. 실행 중 사용자 홈에 쓴 파일 없음(바뀐 것은 다른 도구의 `~/.codex` 로그뿐), `output_dir/.cache`는 끝에 지워짐. 실행 스크립트와 로그: `/workspaces/.closha_build_test/scgpt/`(build.sh, run_sif_test.sh). GPU 실행은 CLOSHA에서 확인한다.
