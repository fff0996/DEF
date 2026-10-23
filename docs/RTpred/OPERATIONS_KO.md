# 빌드 및 독립 기능 실행

## 기관 전달 구조

`MDCC_v1/` 전체를 전달합니다. 기관 분석 실행은 이 폴더의 코드·모델 또는 이를 포함해 빌드한 SIF만 사용합니다. 실행 중 GitHub 접근이 필요하지 않습니다.

- `models/rp_model`, `models/hilic_model`: 제공된 기본 모델 복사본. 각 저장 best는 `WeightedEnsemble_L3`입니다.
- `models/default_registry.json`: 기본 모델 이름·로딩 확인 기록.
- `models/SHA256SUMS`: 기본 모델 배포 파일 체크섬.
- `mdcc/`: 실행 코드와 로컬 학습 인터페이스입니다.
- `containers/`: predict/train/compare def 및 공통 requirements.
- `User_training.ipynb`: 외부 설치·다운로드 없이 로컬 코드로 학습하는 노트북.

앙상블 best는 하위 모델에 의존하므로 `WeightedEnsemble_L3/model.pkl` 한 파일만 추출하면 안 됩니다. 모델 디렉터리 전체를 유지합니다. 사용자 모델도 모듈 2 출력의 `model/` 전체를 전달합니다.

```bash
cd MDCC_v1/models
sha256sum -c SHA256SUMS
```

## 컨테이너 빌드

Linux x86_64 및 Apptainer가 필요합니다. `%files`의 상대 경로는 MDCC 기준입니다.

```bash
cd MDCC_v1
bash scripts/build_apptainer.sh
```

스크립트는 다음 세 명령을 수행합니다.

```bash
apptainer build --fakeroot containers/predict.sif containers/predict.def
apptainer build --fakeroot containers/train.sif containers/train.def
apptainer build --fakeroot containers/compare.sif containers/compare.def
```

fakeroot를 지원하지 않는 서버에서는 관리자가 허용된 빌드 노드 또는 `sudo apptainer build ...` 방식으로 동일 def를 빌드합니다. Docker daemon·podman은 필요하지 않습니다. 빌드 시 공식 Python OCI 이미지·Debian·PyPI 접근이 필요하며 **실행 시 다운로드는 없습니다**.

공통 requirements는 모델 호환성을 위해 고정한 주요 버전입니다. 설치 결과의 간접 의존성·OS 패키지는 SIF 내부 `/opt/mdcc/pip-freeze.txt`, `/opt/mdcc/os-packages.txt`에 기록됩니다. 배포할 SIF 해시와 함께 보관합니다. `conda` 문자열이 있는 부분은 설치 여부를 검사하여 발견하면 실패시키는 코드입니다.

```bash
apptainer exec --cleanenv containers/train.sif cat /opt/mdcc/pip-freeze.txt
apptainer exec --cleanenv containers/train.sif cat /opt/mdcc/os-packages.txt
sha256sum containers/predict.sif containers/train.sif containers/compare.sif
```

def는 [Apptainer 공식 정의 파일 문서](https://apptainer.org/docs/user/main/definition_files.html)의 `%files`, `%post`, `%environment`, `%runscript`, `%test` 구성에 맞췄습니다. 이 호스트에는 Apptainer가 없어 실제 SIF 빌드는 수행하지 않았습니다.

## 모듈 1 — 기본 모델 예측만 실행

현재 폴더를 컨테이너 `/work`로 연결합니다. 각 명령의 출력 경로는 새 폴더를 사용하십시오.

```bash
cd MDCC
bash scripts/run_apptainer.sh predict \
  --input /work/examples/compounds.csv --output /work/results/prediction
```

새로운 사용자 모델을 학습할 필요 없이 로컬 default best로 예측합니다. 혼합 RP/HILIC 입력의 각 행을 해당 기본 모델로 처리합니다. 한 모드로만 입력할 때는 `--model RP` 또는 `--model HILIC`를 지정할 수 있으며 입력 열과 충돌하면 오류입니다.

## 모듈 2 — 사용자 모델 생성만 실행

아래 예제는 합성 RT 입력입니다. 실제 사용 시 기관에서 측정한 RT 라이브러리로 바꿉니다.

```bash
bash scripts/run_apptainer.sh train \
  --input /work/examples/synthetic_training_RP.csv --model RP \
  --output /work/results/user_rp --time-limit 1200 --cpus 4 \
  --algorithms GBM CAT RF XT KNN --rt-unit 'model unit' --method-label 'Lab method A'
```

주요 결과는 `results/user_rp/model/`, `validation_leaderboard.csv`, `reserved_test.csv`입니다. `--time-limit`은 초 단위의 fit 예산입니다.

학습 분할은 기본 구조 그룹 기준 60% train / 20% validation / 20% reserved test입니다. train에서만 특성 필터를 fit하고 validation으로 best를 선택합니다. reserved test는 모델 학습·선택·재학습에 사용하지 않습니다.

로컬 Jupyter 사용자는 설치된 동일 Python 3.13 환경에서 `User_training.ipynb`를 열어 INPUT/OUTPUT/MODE를 수정해 실행할 수 있습니다. 이 노트북은 GitHub clone이나 pip install 셀을 포함하지 않습니다.

## 모듈 3 — 성능 비교만 실행

```bash
bash scripts/run_apptainer.sh compare \
  --input /work/results/user_rp/reserved_test.csv --model RP \
  --user-model /work/results/user_rp/model --scope all \
  --output /work/results/comparison --rt-unit 'model unit'
```

기본 best 한 개와 사용자 모델 묶음의 추론 가능한 모든 후보를 같은 평가 행에서 비교합니다. 각 사용자 묶음의 best만 비교하려면 `--scope best`를 사용합니다. 여러 실행의 모델은 `--user-model`을 반복합니다.

```bash
bash scripts/run_apptainer.sh compare \
  --input /work/external_evaluation.csv --model RP \
  --user-model /work/results/run_a/model \
  --user-model /work/results/run_b/model \
  --scope best --output /work/results/comparison_two_runs
```

평가 자료는 **모든 사용자 모델의 train·validation과 겹치지 않아야** 합니다. 서로 다른 split로 학습한 모델을 비교할 때 한 모델의 reserved test가 다른 모델에서는 train이었을 수 있습니다. 이 경우 검사에서 중단하므로 두 모델 모두에서 분리한 공통 외부 자료를 사용합니다. 기본 모델은 비교 결과로 자동 교체하지 않습니다.

모듈 3의 모델 입력은 신뢰된 모듈 2 산출물을 전달하는 포트입니다. AutoGluon 모델 로딩은 pickle을 사용하므로 일반 웹 사용자에게 출처 불명 pickle 업로드를 허용하는 포트로 취급하지 않습니다. [공식 모델 로딩 문서](https://auto.gluon.ai/1.5/api/autogluon.tabular.TabularPredictor.load.html).

## CLOSHA 연동 포트

`pipeline.json`은 플랫폼 중립 참고 명세입니다. 제공되지 않은 CLOSHA 전용 등록 스키마의 구현물이라고 표시하지 않았습니다.

| 노드 | 입력 포트 | 독립 출력 | 연결 |
|---|---|---|---|
| M01 predict | compound_table 파일 | predictions.csv, PNG/SVG, HTML | 다른 모듈 선행 필요 없음 |
| M02 train | training_table 파일 | model 디렉터리, reserved_test.csv, 학습 보고서 | M03 model/evaluation 입력에 연결 가능 |
| M03 compare | evaluation_table 파일, user_models 디렉터리 목록 | 비교 CSV, long table, PNG/SVG, HTML | 내장 default best는 이미지 내부에서 자동 포함 |

디렉터리 포트가 없다면 모듈 2의 `model/` 전체를 동일 구조로 staging합니다. `report.html`은 해당 폴더의 PNG를 함께 전달해야 합니다. 실행 종료코드 0과 마지막에 생성된 작업 `manifest.json`을 성공 조건으로 사용합니다. 실패 시 불완전 출력 폴더를 다음 실행에 전달하지 않고 새 경로로 재실행합니다.

실제 CPU·메모리·네트워크 제한은 CLOSHA 작업 스케줄러에서 설정합니다. 실행 래퍼는 `--cleanenv --containall`을 사용하지만 이 두 옵션을 네트워크 방화벽 기능으로 해석하면 안 됩니다. 현재 폴더 경로의 `:`와 `,`는 Apptainer bind 구분자와 충돌할 수 있으므로 피합니다.

## 테스트와 예제 재생성

```bash
# 아래 python은 containers/requirements.txt가 설치된 Python 3.13입니다.
PYTHONPATH=. MPLCONFIGDIR=/tmp/mdcc-mpl python -m unittest discover -s tests -v
python scripts/reproduce_examples.py --output-root /tmp/mdcc-new-examples
python scripts/make_figures.py
```

테스트는 Python socket의 IPv4/IPv6 연결을 거부한 상태에서 실제 학습·예측·비교를 실행합니다. 이는 실행 코드의 네트워크 불필요성을 확인하는 테스트이며 SIF 내부 또는 기관 방화벽 검증을 대신하지 않습니다.
