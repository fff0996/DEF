CLOSHA scGPT 환자 단위 예측 파이프라인 설계안 0.1

작성일: 2026-11-03
상태: 설계 초안. 스크립트, DEF, 이미지 빌드, 테스트는 아직 없다. 이 문서를 확정한 뒤 작업 번호 1.0으로 스크립트를 만든다.
파이프라인 이름(가칭): `scGPT_Patient_Prediction_Pipeline`

## 1. 목표
사전학습된 단일세포 파운데이션 모델 **scGPT**를 가져와, 사용자가 가진 단일세포 데이터와 환자 단위 라벨로 **더 나은 예측 모델을 만들고, 실제로 나아졌는지 확인까지** 하는 범용 파이프라인이다.
- 범용: 질환·라벨을 고정하지 않는다. 환자(또는 공여자) 단위 이진 라벨이면 받는다(예: 면역항암제 반응, 재발, 아형).
- 예제: K-BDS 폐암 코호트(KAP241028) 78명의 치료 전 혈액 단일세포와 면역항암제 반응(PR/PD). 원자료 근거 Sim et al., eLife 2024(RP96951).
- "나아졌다"는 말이 아니라 compare 모듈의 숫자로 보인다(6절). 나아지지 않으면 그 결과도 그대로 보인다.
- 다른 파운데이션 모델(Geneformer 등)은 이 파이프라인에 넣지 않고 별도 파이프라인으로 만든다(2026-11-03 사용자 결정).
- 실행 중 인터넷을 쓰지 않는다. scGPT 가중치는 이미지에 넣는다(라이선스 확인 후, 9절).

## 2. 지원 범위
| 항목 | 지원 |
|---|---|
| 종 | 사람(scGPT 어휘가 사람 유전자 기호) |
| 데이터 | 단일세포 RNA count 행렬. 10x h5(Cell Ranger), h5ad, 10x mtx 폴더 |
| 라벨 | 환자 단위 이진 라벨. 양성 클래스는 옵션으로 지정(예: PR). 다중 분류는 다음 버전 |
| 코호트 | 여러 코호트를 한 번에 받는다. 코호트 열로 구분한다 |
| 조직 | 한 학습에는 한 조직만(예: 혈액). 섞이면 경고하고 멈춘다(옵션으로 허용 가능) |
| 시점 | 예측 입력은 지정한 시점(기본 Before)만. 다른 시점 샘플은 학습 입력에서 뺀다 |

## 3. RTpred와 같은 역할 나눔
RTpred의 train(선택) → predict(기본 또는 학습 모델) → compare(선택) 구조를 따른다.

| 모듈 | 필수 | 하는 일 |
|---|---|---|
| `scgpt_prep` | 필수 | 샘플 시트와 원본 행렬로 AI-ready 데이터셋을 만든다. QC, 유전자 이름 맞춤, 코호트별 라벨 분포 확인, 환자 단위 fold |
| `scgpt_train` | 선택 | 사용자 데이터로 모델을 학습한다. 기존 모델에서 이어서 학습할 수 있다 |
| `scgpt_predict` | 필수 | 기본 모델 또는 사용자 모델로 환자별 확률과 기여 세포를 낸다 |
| `scgpt_compare` | 선택 | 같은 평가 환자에서 여러 모델과 기준선을 비교해 "더 좋아졌는지" 보인다 |

흐름:
```
샘플 시트 + 원본 행렬
  → scgpt_prep ──→ (선택) scgpt_train ──→ 모델(+모델 카드)
              │                              │
              └──────→ scgpt_predict ←───────┘ (없으면 기본 모델)
              └──────→ (선택) scgpt_compare ← 기본 모델, 사용자 모델, 기준선
```

## 4. 입력 규격: 샘플 시트
CSV 한 장. 한 줄이 샘플(행렬 파일) 하나다.

| 열 | 필수 | 설명 |
|---|---|---|
| `sample_id` | 필수 | 샘플 이름. 중복 불가 |
| `patient_id` | 필수 | 환자 이름. 같은 환자의 여러 샘플은 같은 값 |
| `cohort` | 필수 | 코호트 이름(예: KBDS_KAP241028) |
| `tissue` | 필수 | 조직(예: blood, tumor) |
| `time` | 필수 | 채취 시점(예: Before, After) |
| `file` | 필수 | 행렬 파일 또는 폴더 경로(입력 폴더 기준 상대 경로) |
| `label` | train·compare에 필수 | 환자 라벨(예: PR, PD). predict에서는 비워도 됨 |

- 라벨은 환자 단위다. 같은 환자의 샘플은 라벨이 같아야 하며, 다르면 멈춘다.
- 임상 변수(약물, 치료 라인 등)는 시트에 열을 더해 두면 데이터셋에 그대로 옮긴다(모델 입력에는 넣지 않음).

## 5. 모듈 상세

### 5.1 scgpt_prep
- 입력: `sample_sheet`, `input_dir`, `output_dir`
- 옵션: `time=Before`, `tissue=auto`(하나뿐이면 그것), `positive_label`(예: PR), `min_genes`, `max_mito`, `min_cells_per_sample`, `folds=5`, `repeats=3`, `seed`
- 처리:
  1. 파일을 읽고 샘플·환자·코호트 ID를 모든 세포에 붙인다.
  2. 세포 QC(유전자 수, UMI, 미토콘드리아 비율). **원래 count는 바꾸지 않는다**(scGPT가 자기 방식으로 정규화).
  3. 유전자 이름을 scGPT 어휘에 맞춘다(Ensembl이면 기호로 변환). 코호트별로 맞은 유전자 비율을 보고한다.
  4. 코호트별 라벨 분포를 표로 낸다. 한 코호트가 한 라벨만 가지면 경고한다(코호트 차이를 라벨로 배울 위험).
  5. 환자 단위 fold를 만든다. 라벨 비율을 맞추고(stratified), 한 환자는 한 fold에만 들어간다. 코호트가 2개 이상이면 "코호트 하나 빼기" 분할도 만든다.
- 출력: `dataset.h5ad`(count, obs에 ID), `patients.tsv`, `samples.tsv`, `cells_qc.tsv.gz`, `splits.tsv`, `gene_match.tsv`, `cohort_labels.tsv`, `data_dictionary.tsv`, `plots/`(환자별 세포 수, QC 분포, 라벨 구성), `logs/`

### 5.2 scgpt_train (선택)
- 입력: `input_dir`(prep 결과), `output_dir`, 선택 `init_model`(이어서 학습할 기존 모델)
- 옵션: `mode=frozen|adapt`, `checkpoint=whole_human`(9절), `pooling=attention|mean`, `epochs`, `learning_rate`, `max_cells_per_patient`, `seed`
- 방식:
  - `frozen`(기본, CPU 가능): scGPT는 고정하고 세포 임베딩을 뽑는다. 그 위의 **환자 단위 pooling(attention 또는 평균) + 분류기**만 학습한다. 학습할 값이 적어 환자 수십 명에도 맞는다.
  - `adapt`(GPU 필요, 다음 단계): 라벨 없이 scGPT 사전학습 방식(가린 발현 맞히기)으로 사용자 세포에 scGPT를 더 학습한 뒤 `frozen`과 같이 분류기를 붙인다. 라벨이 필요 없어 다른 시점·라벨 없는 환자의 세포도 쓸 수 있다. 평가 때는 각 fold의 평가 환자 세포를 적응 학습에서 뺀다.
- 평가: prep의 fold로 교차검증한다(fold마다 평가 환자는 학습에 쓰지 않음). 마지막에 전체 환자로 최종 모델을 학습한다.
- 출력: `model/`(가중치, 설정, 유전자 목록), `model_card.json`·`model_card.md`(10절), `cv_predictions.tsv`(환자별 교차검증 확률), `cv_metrics.tsv`(fold별 AUC 등), `plots/`(ROC, 학습 곡선), `logs/`

### 5.3 scgpt_predict
- 입력: `input_dir`(prep 결과, 라벨 없어도 됨), `output_dir`, 선택 `model`(비우면 기본 모델)
- 처리: 모델의 유전자 목록에 맞춰 세포 임베딩을 뽑고 환자별 확률을 낸다. 모델 카드의 조직·시점과 입력이 다르면 경고한다.
- 출력: `predictions.tsv`(patient_id, 확률, 예측 라벨, 사용 세포 수), `cell_attention.tsv.gz`(attention pooling일 때 세포별 기여), `plots/`(환자별 확률, 기여 상위 세포 유형), `logs/`
- 기본 모델: 예제 데이터(K-BDS 78명)로 학습한 모델. 공개 모듈에 넣을 수 있는지 K-BDS 이용 조건 확인 필요(11절). 넣을 수 없으면 predict는 `model`을 필수로 받는다.

### 5.4 scgpt_compare (선택)
- 입력: `input_dir`(라벨 있는 prep 결과), `output_dir`, `models`(쉼표 구분, 비우면 기본 모델만)
- 비교 대상(같은 평가 환자, 같은 fold):
  1. **기준선 A**: 세포 유형 비율 + 로지스틱 회귀(세포 유형은 마커 기반 간단 주석)
  2. **기준선 B**: 고변동 유전자 PCA의 환자 평균 + 로지스틱 회귀
  3. **사전학습 scGPT 그대로**: 임베딩 평균 + 로지스틱 회귀
  4. 지정한 모델들(기본 모델, 사용자 모델)
- 평가값: AUC(95% 신뢰구간, 부트스트랩), 정확도, 민감도·특이도, 라벨을 섞은 순열 검정 p. 코호트가 2개 이상이면 "코호트 하나 빼기" 결과를 따로 낸다.
- 출력: `compare_metrics.tsv`, `compare_predictions.tsv`, `plots/`(ROC 겹쳐 그리기, AUC 막대와 신뢰구간), `summary.md`(어느 모델이 기준선보다 나았는지 한 줄 결론), `logs/`
- 독립 벤치마크에서 파운데이션 모델의 파인튜닝 없는 임베딩이 단순 기준선을 못 이기는 경우가 보고되어 있어, 기준선 A·B는 항상 넣는다.

## 6. "더 좋은 모델"의 판단 규칙
- 비교는 학습에 쓰지 않은 환자(교차검증 평가 fold 또는 다른 코호트)에서만 한다. 세포 단위로 나누지 않는다.
- 다음 순서로 판단해 `summary.md`에 적는다.
  1. 사전학습 scGPT 그대로보다 AUC가 높은가
  2. 기준선 A·B보다 높은가
  3. 이전 모델(데이터를 더하기 전)보다 높은가
- 신뢰구간이 겹치면 "차이가 뚜렷하지 않음"으로 적는다. 환자 수가 적으면(예: 100명 미만) 결론이 불확실하다는 문장을 함께 낸다.

## 7. 공통 규칙
- 스크립트는 `docs/CLOSHA_Script_Rules_v1.md`를 따른다: `key=value` 인자, 다시 실행하면 `output_dir/log/`만 남기고 지운 뒤 시작, 로그는 `output_dir/logs/`.
- 코어 수는 `env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc`으로 읽는다(공개 모듈의 `OMP_NUM_THREADS=1` 때문, 규칙 2.1절). PyTorch 스레드 수도 이 값으로 정한다.
- 난수 seed를 모든 단계에 넘겨 같은 입력이면 같은 결과가 나오게 한다.
- 언어: Python(scGPT가 PyTorch 기반).

## 8. 예제 데이터 계획 (K-BDS 폐암)
- 코호트: KAP241028, 치료 전(Before) 혈액 단일세포, 환자 78명(수와 출처는 샘플 시트 확정 시 데이터 사전에 기록), 라벨 PR(양성)·PD.
- 확인할 것:
  - 라벨 정의: eLife 부록 1a에서 PR/PD로 나눈 기준(SD 처리 여부)
  - 약물·병용요법·치료 라인, 검체 처리·시퀀싱 배치가 반응과 겹치는지(배치를 배울 위험)
  - 코호트가 클론성 조혈증 연구로 모은 환자라는 점(CH 부담과 반응의 관계)
- 외부 검증: 메머드 코호트의 치료 전 혈액 단일세포가 확보되면 compare의 "코호트 하나 빼기"로 확인한다.
- 개발 중 데이터 취급: K-BDS 원본은 통제 접근 자료이므로 Codespace와 git에 두지 않는다. 스크립트는 공개 PBMC 데이터에 가짜 라벨을 붙인 작은 예제로 여기서 검증하고, 실제 학습은 승인된 환경(CLOSHA)에서 한다.

## 9. 실행 이미지 계획
- 이름: `bx_scgpt` 1.0 (`defs/scGPT/bx_scgpt.1.0.def`)
- 기반: 다른 이미지와 같이 Rocky Linux 9.8(digest 고정) + Miniforge(conda-forge, bioconda). 버전 고정.
- 주요 도구: Python, PyTorch(우선 CPU판), scGPT(버전 고정), scanpy, anndata, scikit-learn.
- flash-attn은 넣지 않는다(특정 GPU·CUDA 필요). scGPT를 빠른 attention 없이 쓰는 설정으로 실행한다. GPU 판은 CLOSHA GPU가 확인되면 따로 만든다.
- scGPT 가중치: 기본 `whole_human`(사람 세포 약 3,300만 개). 조직별 체크포인트(예: blood, pan-cancer)를 함께 넣을지는 크기와 라이선스를 보고 정한다. 가중치 라이선스를 확인한 뒤 넣는다.
- 빌드: Codespace에서 fakeroot 검증 빌드만 한다. 운영 HPC 빌드와 SIF 배포는 하지 않는다.

## 10. 모델 카드
train이 모델마다 만든다. predict와 compare가 읽어 맞지 않는 입력에 경고한다.

| 항목 | 예 |
|---|---|
| model_id, 만든 날짜, 모듈 버전 | |
| scGPT 체크포인트, mode, pooling | whole_human, frozen, attention |
| 학습 데이터 | 코호트 목록, 환자 수(라벨별), 조직, 시점 |
| 라벨 정의 | positive_label, 원 라벨 값 |
| 유전자 | 사용 유전자 수, 목록 파일 |
| 교차검증 성능 | AUC(신뢰구간), fold 수·반복 수 |
| 이어 학습한 모델 | init_model의 model_id |
| 사용 제한 | 학습 데이터 이용 조건(예: K-BDS 승인 범위) |

## 11. 정할 것
1. CLOSHA에 GPU 노드가 있는가(`adapt` 방식과 GPU 이미지 여부)
2. scGPT 코드·가중치 라이선스: 이미지에 넣어 배포할 수 있는가
3. K-BDS 78명으로 학습한 모델을 공개 기본 모델로 넣을 수 있는가(데이터 이용 조건)
4. 78명 샘플 시트와 임상표 형식(열 이름), 원본이 모두 Cell Ranger h5인가
5. 파이프라인과 모듈의 정식 이름, 포탈 카테고리

## 12. 작업 순서
1. 이 설계 확정
2. `bx_scgpt` 1.0 DEF 작성과 Codespace 검증 빌드(CPU)
3. scgpt_prep → scgpt_train(frozen) → scgpt_predict → scgpt_compare 작성, 공개 PBMC + 가짜 라벨로 Codespace 테스트
4. CLOSHA에서 K-BDS 78명으로 실행(사용자), 결과 확인과 원고 작성
5. GPU가 있으면 `adapt` 방식 추가
