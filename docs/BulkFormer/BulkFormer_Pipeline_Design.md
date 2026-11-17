CLOSHA BulkFormer 샘플 단위 예측 파이프라인 설계안 0.1

작성일: 2026-11-17
상태: 설계 초안. 스크립트, DEF, 이미지 빌드는 아직 없다. Codespace CPU에서 BulkFormer-Atlas 실행 가능성만 확인했다(2026-11-17, 11절). 이 문서를 확정한 뒤 작업 번호 1.0으로 스크립트를 만든다.
파이프라인 이름(안): `BulkFormer_Phenotype_Classification_Pipeline` (scGPT 파이프라인 `scGPT_Phenotype_Classification_Pipeline`과 짝)

## 1. 목표
사전학습된 bulk RNA-seq 파운데이션 모델 **BulkFormer-Atlas**로 샘플 임베딩을 만들고, 사용자가 가진 샘플 단위 라벨로 예측 모델을 만들어 **단순 기준선보다 나은지 숫자로 확인**하는 범용 파이프라인이다. scGPT 파이프라인의 bulk 짝이다.
- 범용: 질환과 라벨을 고정하지 않는다. 샘플(환자) 단위 이진 라벨이면 받는다(예: 아형, 치료 반응, 재발).
- 예제: **TCGA 폐선암(LUAD) vs 폐편평상피암(LUSC)**, GDC 공개 RNA-seq(STAR counts). 공개 자료라 Codespace와 git에서 그대로 다룰 수 있다(8절).
- 실행 중 인터넷을 쓰지 않는다. 가중치는 이미지에 넣는다(9절).

## 2. scGPT 파이프라인과 다른 점
| 항목 | scGPT | BulkFormer |
|---|---|---|
| 입력 | 단일세포 count(세포 × 유전자) | bulk 발현(샘플 × 유전자) |
| 임베딩 단위 | 세포(512차원) | **샘플 하나에 하나**(CLS 1,024차원) |
| 환자 단위로 모으기 | attention 또는 평균 pooling(MIL) | **필요 없음**(샘플 = 환자) |
| 유전자 이름 | 유전자 기호 | **Ensembl ID**(버전 접미사 제거) |
| 정규화 | scGPT 자체(51구간) | 41,623개 정규화 어휘로 TPM 계산 → log2(TPM+1) |
| 입력 유전자 | 세포당 최대 1,200개 | 코호트 고정 패널 4,096개(분산 큰 단백질 코딩 유전자) |
| 기준선 A | 세포 유형 비율 | 같은 4,096개 유전자 log2(TPM+1) + 로지스틱 회귀 |

## 3. 모듈
scGPT와 같은 역할 나눔(train 선택 → predict → compare 선택)이다. GPU가 필요한 일은 `bulkformer_embed` 하나에만 둔다.

| 모듈 | 필수 | 등록 자원 | 하는 일 |
|---|---|---|---|
| `bulkformer_prep` | 필수 | HPC | 샘플 시트와 발현 파일로 AI-ready 데이터를 만든다. Ensembl ID 맞춤, TPM과 log2(TPM+1), 4,096개 패널 선택(또는 받은 패널 적용), 라벨 연결·점검, 샘플 단위 stratified fold |
| `bulkformer_embed` | 필수 | **GPU** | Atlas로 샘플 CLS 임베딩(1,024차원)을 만든다. GPU가 없으면 CPU(fp32)로 돈다(샘플당 약 41초, Codespace) |
| `bulkformer_train` | 선택 | HPC | 임베딩 위에 분류기(로지스틱 회귀 L2 또는 작은 MLP)를 학습. fold 교차검증 후 전체로 최종 모델 |
| `bulkformer_predict` | 필수 | HPC | 학습 모델로 샘플별 확률을 낸다 |
| `bulkformer_compare` | 선택 | HPC | 같은 fold에서 모델들과 기준선을 비교해 "더 좋아졌는지" 보인다 |

흐름:
```
샘플 시트 + 발현 파일
  → bulkformer_prep(HPC) → bulkformer_embed(GPU) ──→ (선택) bulkformer_train(HPC) ──→ 모델(+모델 카드, 패널)
                                                 ├──→ bulkformer_predict(HPC) ←──────┘
                                                 └──→ (선택) bulkformer_compare(HPC)
```
새 샘플 예측은 prep(학습 때 패널을 `panel` 입력으로 받아 그대로 적용) → embed → predict 순서다.

## 4. 입력 규격
**샘플 시트**(`sample_data`, CSV): 한 줄이 샘플 하나다.

| 열 | 필수 | 설명 |
|---|---|---|
| `SampleID` | 필수 | 샘플 이름. 중복 불가. 발현 파일 또는 행렬 열 이름과 같아야 함 |
| `PatientID` | 필수 | 환자 이름. 같은 환자의 여러 샘플은 같은 fold에 넣는다 |
| `Cohort` | 필수 | 코호트 이름(예: TCGA-LUAD) |
| `Label` | 열은 필수, 값은 비워도 됨 | 라벨. 예측할 샘플은 비움 |

**발현 입력**(`input_dir`): 둘 중 하나.
1. 샘플별 GDC STAR 파일 `<SampleID>*.tsv`(`augmented_star_gene_counts` 형식, `unstranded` 열)
2. 행렬 하나 `expression.tsv`(또는 .csv): 행 Ensembl ID, 열 SampleID

옵션 `input_scale=counts|tpm|log2tpm`(기본 counts). counts면 BulkFormer가 배포한 유전자 길이로 TPM을 계산한다. **분모는 41,623개 정규화 어휘에서 관측된 전체 유전자**이고(lncRNA 포함), 패널 4,096개만으로 정규화하지 않는다(개발사 input guide).

## 5. 모듈 상세

### 5.1 bulkformer_prep
- 입력: `sample_data`, `input_dir`, `output_dir`, 선택 `panel`(기존 패널 파일; 비우면 새로 고름)
- 옵션: `input_scale`, `positive_label`, `n_genes=4096`, `folds=5`, `repeats=3`, `seed`
- 처리: 1) 발현 읽기, Ensembl 버전 접미사 제거, 중복 ID 합침 2) TPM과 log2(TPM+1) 3) 어휘 일치율(샘플별 관측 유전자 수, 빠진 비율) 보고 4) 패널: `panel`이 없으면 **입력 코호트 전체에서 라벨을 보지 않고** 분산 큰 단백질 코딩 유전자 4,096개를 고른다(개발사 기본 선택기, 어휘 순서 유지). 이 비지도 선택이 교차검증 평가 샘플도 보는 점(transductive)은 결과와 모델 카드에 적는다 5) 라벨 점검, 코호트별 라벨 분포 6) 환자 단위 stratified fold
- 출력: `expression_log2tpm.tsv.gz`(샘플 × 41,623 어휘), `panel.tsv`(Ensembl ID, 순서), `samples.tsv`, `gene_coverage.tsv`, `splits.tsv`, `cohort_labels.tsv`, `plots/`(라이브러리 크기, 일치율, 라벨 구성, 발현 PCA), `logs/`

### 5.2 bulkformer_embed (GPU)
- 입력: `input_dir`(prep 결과), `output_dir`
- 옵션: `batch_size`, `device=auto`, `precision=auto`(GPU는 bf16, CPU는 fp32; CPU에서 bf16은 오류), `seed`
- 처리: 가중치를 한 번 불러 패널 4,096개 입력으로 CLS 임베딩을 만든다. 개발사 `extract_atlas`와 같은 계산.
- 출력: `embeddings.tsv.gz`(샘플 × 1,024), `embed_info.json`(체크포인트 ID `atlas-infonce-epoch10-update320000`, model.pt SHA256, 패널 SHA256, 장치, 정밀도), `plots/`(임베딩 UMAP/PCA, 라벨·코호트 색), `logs/`

### 5.3 bulkformer_train (선택)
- 입력: `input_dir`(embed 결과), `output_dir`
- 옵션: `classifier=logistic|mlp`(기본 logistic, L2 세기는 내부 교차검증), `seed`
- 평가: prep의 fold로 교차검증 → 전체 샘플로 최종 모델.
- 출력: `model/`(분류기, 표준화 값, 패널 사본), `model_card.json`·`.md`, `cv_predictions.tsv`, `cv_metrics.tsv`, `plots/`(ROC), `logs/`

### 5.4 bulkformer_predict
- 입력: `input_dir`(embed 결과), `output_dir`, `model`(필수 여부는 11절)
- 처리: 임베딩의 체크포인트 SHA256과 **패널 SHA256이 모델 카드와 같은지** 확인하고 다르면 멈춘다(패널이 다르면 임베딩 의미가 달라짐).
- 출력: `predictions.tsv`(SampleID, 확률, 예측 라벨), `plots/`, `logs/`

### 5.5 bulkformer_compare (선택)
- 비교(같은 fold, 같은 평가 샘플):
  1. **기준선 A**: 같은 4,096개 유전자 log2(TPM+1) + 로지스틱 회귀(L2)
  2. **기준선 B**: 고변동 유전자 PCA(50성분) + 로지스틱 회귀
  3. **BulkFormer 그대로**: CLS 임베딩 + 로지스틱 회귀
  4. 지정한 모델들
- 판단 규칙은 scGPT와 같다: 짝지은 부트스트랩(2,000번) AUC 차이의 95% 신뢰구간으로 better / worse / not clearly different(`compare_delta.tsv`), 순열 검정 p, 샘플 100개 미만이면 불확실 문장.
- 출력: `compare_metrics.tsv`, `compare_delta.tsv`, `compare_predictions.tsv`, `plots/`(ROC 겹쳐 그리기, AUC 막대), `summary.md`, `logs/`

## 6. 공통 규칙
- `docs/CLOSHA_Script_Rules_v1.md`를 따른다. Python 모듈은 `key=value`, `--key=value`, `--key value`를 모두 받는다(CLOSHA가 Python에 `--key value`로 넘김).
- 코어 수는 `env -u OMP_NUM_THREADS -u OMP_THREAD_LIMIT nproc`. seed를 모든 단계에 넘긴다.
- 가중치 파일을 결과 폴더에 복사하지 않는다(체크포인트 ID와 SHA256만 기록).

## 7. 가중치 이용 판단 (2026-11-17)
- 코드: MIT(Copyright (c) 2025 Boming Kang). 가중치: 개발자 Google Drive에 링크 공개("Read access is public by link"), 따로 적힌 라이선스나 제한 문구 없음.
- CLOSHA 사용자는 공개 SIF를 받을 수 없어 가중치 사본이 사용자에게 가지 않는다(서버 안 추론). scGPT와 같은 기준으로 사용 가능으로 판단.
- 개발사 요청: 모델 이름, 체크포인트 ID, 평가 방법을 함께 적는다 → 포탈 원고, `embed_info.json`, 모델 카드에 기록. 인용: Kang, Fan et al., Cell Systems 2026.

## 8. 예제 데이터 (TCGA LUAD vs LUSC, 공개)
- 출처: GDC 공개(open access) `Gene Expression Quantification`, workflow `STAR - Counts`, 원발 종양(Primary Tumor). 2026-11-17 GDC API 확인: TCGA-LUAD 540개, TCGA-LUSC 511개, 파일당 약 4MB.
- 사용: 암종별 무작위 100명(seed 고정, 환자당 원발 종양 1개), 라벨 LUSC(양성)·LUAD. 샘플 목록과 GDC file_id를 `SOURCE.txt`에 남긴다.
- 받는 스크립트: `tools/bulkformer/fetch_tcga_luad_lusc.py`(GDC API, 로그인 없음).
- 주의: 두 암종은 발현 차이가 커서 기준선도 AUC가 1에 가까울 수 있다. 그러면 compare 결론은 "not clearly different"가 되기 쉽다. 파이프라인 동작을 보이는 첫 예제로 쓰고, BulkFormer의 이점을 보일 더 어려운 과제(예: 같은 암종 안의 병기, 생존)는 11절에서 정한다.

## 9. 실행 이미지 계획
- `bx_bulkformer` 1.0(CPU)과 `bx_bulkformer_gpu` 1.0(CUDA), scGPT와 같은 구성(Rocky Linux 9.8 digest 고정 + Miniforge, conda-forge).
- 저장소 `bulkformer.yaml`은 Anaconda defaults 채널을 써서 그대로 쓰지 않는다. conda-forge + PyTorch(CPU판은 PyPI CPU wheel 또는 conda-forge, 해시 고정), torch-geometric, performer-pytorch 1.1.4. BulkFormer 패키지는 커밋 고정 소스로 설치.
- 가중치: Atlas `model.pt`(969,530,454 bytes)와 자원 파일(model_config.json, gene_vocab.csv, normalization_vocab.csv, manifest.json)을 빌드 때 받아 저장소 `src/bulkformer/manifests/*.json`의 SHA256으로 확인하고 `/opt/bio/share/bulkformer/atlas`에 둔다.
- 빌드: Codespace fakeroot 검증 빌드만. 운영 HPC 빌드와 SIF 배포는 하지 않는다.

## 10. 실행 가능성 확인 (Codespace CPU, 2026-11-17)
- 개발사 데모 8샘플: 임베딩 (8, 1,024), 샘플당 40.7초, 최대 메모리 2.08GB, 모델 로드 7초, 가중치 다운로드 34초. 샘플당 관측 유전자 22,636개(빠진 비율 0).
- 예제 200샘플이면 CPU로 약 2.3시간. GPU에서는 훨씬 짧을 것으로 보지만 확인 안 함.
- 기록: `/workspaces/.closha_build_test/bulkformer/`.

## 11. 정할 것
1. predict의 기본 모델: LUAD/LUSC 예제 모델을 기본으로 넣을지, `model`을 필수로 할지(제안: 필수)
2. BulkFormer 이점을 보일 두 번째 공개 예제 과제
3. 파이프라인·모듈 정식 이름, 포탈 카테고리(scGPT와 같은 Bio-AI 아래 제안)
4. 개발사 저장소 고정 커밋, Google Drive가 빌드 환경에서 받아지는지

## 12. 작업 순서
1. 이 설계 확정
2. 예제 데이터 받기(`tools/bulkformer/fetch_tcga_luad_lusc.py`), Codespace에서 개발사 함수로 작게 먼저 돌려 기준선과 BulkFormer AUC를 미리 본다
3. 모듈 5개 작성, Codespace CPU로 전체 흐름 확인
4. DEF 2개 작성, 검증 빌드, SIF 안 전체 실행, CLOSHA_Script_Rules 체크리스트
5. CLOSHA에서 GPU 실행(사용자), 결과와 원고
