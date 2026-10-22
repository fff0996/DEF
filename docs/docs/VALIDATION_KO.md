# 실행 검증 및 운영 확인

## 확인된 기능

Python 3.13.15, RDKit 2026.3.1, AutoGluon Tabular 1.5.0 환경에서 다음 기능을 확인했습니다.

| 항목 | 확인 내용 |
|---|---|
| 기본 모델 예측 | RP/HILIC 기본 모델을 사용해 유효 SMILES를 예측하고 invalid SMILES를 결과 표에 보존 |
| 사용자 모델 학습 | 구조 그룹 기준 train/validation/reserved test 분할, 모델 저장 및 재로딩 |
| 모델 비교 | 기본 모델과 사용자 후보 모델을 동일 평가 행에서 비교하고 RMSE/MAE/R² 생성 |
| 데이터 누수 차단 | 학습/validation 구조와 겹치는 평가 구조를 거부 |
| 입력·출력 보호 | 모호한 열, 부정확한 RT, 비어 있지 않은 출력 폴더를 거부 |
| 오프라인 실행 | 분석 실행 중 외부 모델 다운로드나 GitHub clone이 필요하지 않음 |

소규모 통합 테스트 16개가 통과했으며 상세 로그는 [test_results.txt](test_results.txt)에 있습니다. 예제 재생성 로그는 [example_run_log.txt](example_run_log.txt)에 있습니다.

## 예제의 범위

학습·비교 예제의 RT는 합성값입니다. 예제는 모듈 간 입력·출력 연결과 오류 처리를 검증하기 위한 것이며, 실제 LC 조건에서의 예측 정확도를 주장하지 않습니다. 실제 성능 평가는 독립된 실측 RT 데이터, 동일 RT 단위, 비교 가능한 LC 조건을 사용해야 합니다.

## Apptainer 운영 인수 시험

Apptainer가 설치된 Linux x86_64 환경에서 아래 순서로 확인합니다.

```bash
cd MDCC_v1
bash scripts/build_apptainer.sh
apptainer test containers/predict.sif
apptainer test containers/train.sif
apptainer test containers/compare.sif
```

그 뒤 `docs/OPERATIONS_KO.md`의 predict, train, compare 예제를 각각 실행합니다. 생성된 SIF의 SHA-256, Apptainer 버전, SIF 내부 `pip-freeze.txt`·`os-packages.txt`, 성공 로그를 운영 기록으로 보관합니다.

