CLOSHA 분석 스크립트 작성 규칙 1.0

작성일: 2026-10-07

이 문서는 CLOSHA 파이프라인 노드에서 실행되는 분석 스크립트(Bash, R, Python)의 작성 규칙이다. 기준은 운영에서 쓰고 있는 `scripts/ATAC-seq/`의 1.0 스크립트(organellar_filter, ATAC_QC, ATAC_QC_plot, MACS3_callpeak_ATAC, peak_annotation, differential_accessibility, atac_motif, tf_footprinting)의 공통 형식이다. 실행 이미지(DEF) 규칙은 docs/CLOSHA_DEF_Generator_Agent_v1.md를 따른다.

참고 예: Bash는 `organellar_filter.1.0.sh`, R은 `ATAC_QC.1.0.R`, `differential_accessibility.1.0.R`.

## 1. 위치, 이름, 버전
- 위치: `scripts/{파이프라인명}/`. 예: `scripts/ATAC-seq/`.
- 이름: `{모듈명}.{주버전}.{부버전}.{확장자}`. 예: `ATAC_QC.1.0.R`, `organellar_filter.1.0.sh`, `retip_predict.1.0.py`.
- 지원 언어: Bash(`.sh`), R(`.R`), Python(`.py`).
- 첫 줄: `#!/bin/bash`, `#!/usr/bin/env Rscript`, `#!/usr/bin/env python3`.
- 한 파이프라인 노드에 스크립트 하나. 같은 실행 이미지를 여러 스크립트가 함께 쓸 수 있다(예: bx_atac_qc 이미지 = ATAC_QC + ATAC_QC_plot).
- 업체가 준 보조 스크립트(빌드, 예제 재현, 그림 생성 등)는 `scripts/`에 두지 않고 `defs/{파이프라인명}/` 아래 원본 보관 위치에 둔다.

### 1.1 버전 관리
- 동작(입력 해석, 필터 기준, 결과 내용, 출력 구조)이 바뀌면 기존 파일을 고치지 않고 **새 버전 파일**을 만든다. 예: `ATAC_QC.1.0.R` → `ATAC_QC.1.1.R`.
- 이전 버전은 지우지 않는다. 이전 결과를 같은 조건으로 다시 만들 수 있어야 한다.
- 새 버전 파일의 맨 위(첫 줄 바로 아래)에 이전 버전과의 차이를 적는다.
  ```
  # Version 1.1 (changes from ATAC_QC.1.0.R):
  #   Tn5 shift and nucleosome splitting read the bamQC clean BAM ...
  ```
- 부버전: 같은 실행 이미지에서 돌아가는 변경. 주버전: 입력·출력 형식이 호환되지 않거나 실행 이미지(DEF)를 바꿔야 하는 변경.
- 오타, 주석, 로그 문구만 고친 경우는 같은 버전에서 고칠 수 있다.
- 새 패키지나 도구가 필요하면 DEF도 새 버전으로 만든다. 같은 이미지로 충분하면 DEF는 두고 DEF 주석의 대상 스크립트 목록만 갱신한다.

## 2. 실행 환경
- 실행 형태: `apptainer exec <sif> bash <스크립트> key=value ...`, `apptainer exec <sif> Rscript <스크립트> key=value ...`. 스크립트는 이미지에 넣지 않고 실행할 때 연결된다.
- 도구는 **이름으로만** 호출한다(`samtools`, `macs3`, `TOBIAS`, `bedtools`). 이미지 내부 절대 경로(`/opt/bio/bin/...`)를 쓰지 않는다.
- 필요한 명령과 패키지는 시작할 때 확인한다.
  - Bash: `for cmd in samtools awk ...; do command -v "$cmd" ...` → 없으면 `Error: required command not found in PATH: <cmd>`
  - R: `requireNamespace(pkg)` 반복 → 없으면 `ERROR: required R package not found: <pkg>`
- 실행 중 외부 네트워크에 접속하지 않는다. 패키지 설치와 데이터 다운로드를 하지 않는다(필요한 것은 DEF에서 설치).
- R은 패키지를 붙인 뒤에도 다른 패키지와 이름이 겹치는 함수는 `pkg::function`으로 부른다(예: `ChIPpeakAnno::estLibSize`, `ATACseqQC::enrichedFragments`).

## 3. 머리 주석
스크립트 맨 위에 아래 형식으로 쓴다. 이 내용이 CLOSHA 모듈 등록(Input/Output/Option 설명)의 근거가 된다.
```
# Usage:
#   ./organellar_filter.sh input_dir="..." output_dir="..." [threads="4"] [organellar_pattern="..."]
#
# Arguments:
#   input_dir           (required) - Directory containing BAM files
#   output_dir          (required) - Output directory
#   threads             (optional) - Number of processors, default: 4
#   organellar_pattern  (optional) - Regex pattern for organellar contigs
```
- 선택 인자는 `[key="기본값"]`으로 Usage에 표시하고, Arguments에 `default:`를 적는다.
- 필요하면 Examples, 입력 표(sample sheet) 형식, 처리 단계(Method), 주의할 동작(입력 옆 인덱스 생성, 이전 결과 삭제)을 덧붙인다.

## 4. 인자
- 형식은 **`key=value`**다. 그 외 형식은 `Invalid argument format: <arg> (must be key=value format)`로 멈춘다(종료 코드 1).
- 값 양끝의 따옴표(`"`, `'`)를 제거한다. 값 안의 `=`는 유지한다(R: `paste(parts[-1], collapse = "=")`).
- 키는 `^[a-zA-Z_][a-zA-Z0-9_]*$`만 허용한다.
- Bash는 `declare "$key=$value"`로 변수를 만들되 보호 변수(`IFS`, `UID`, `EUID`, `PPID`, `BASHOPTS`, `BASHPID`)를 막는다. R은 `assign(key, value)`.
- 필수 인자가 없으면 `Error: Required parameter '<key>' is missing`(R은 `ERROR: ...`)로 멈춘다.
- 선택 인자는 기본값을 준다(Bash `threads="${threads:-4}"`, R `if (!exists("seqlev")) seqlev <- "auto"`).
- 인자 이름:
  | 용도 | 이름 |
  |---|---|
  | 입력 폴더 | `input_dir` |
  | 입력 파일 1개 | `input_file` |
  | 결과 폴더 | `output_dir` |
  | 샘플 시트(CSV) | `sample_data` |
  | 참조 파일 | 내용을 드러내는 이름(`genome_fasta`, `txs_bed`, `tss_bed`, `motif_db`) |
  | 스레드 수 | `threads` |
- 앞 노드의 결과를 받을 때는 앞 노드의 `output_dir`를 `input_dir`로 그대로 받고, 스크립트가 그 안의 정해진 위치(예: `05_metadata/atac_qc_manifest.tsv`, `03_shifted_bam/`)를 찾는다.

## 5. 메시지 함수
```bash
error_msg() { echo "Error: $*" >&2; }
warn_msg()  { echo "Warning: $*" >&2; }
info_msg()  { echo "$*"; }
```
```r
stop_err <- function(...) { cat("ERROR:", paste(..., collapse = ""), "\n", file = stderr()); quit(status = 1) }
warn_msg <- function(...) { cat("WARNING:", paste(..., collapse = ""), "\n") }
msg      <- function(...) { cat(..., "\n") }
```
- 오류는 stderr로 내보내고 종료 코드 1로 끝낸다.
- 오류 메시지에는 무엇이 문제인지와 실제 값(경로, 미리보기)을 함께 적는다. 예: `No common seqlevels between BAM and txs_bed. BAM preview: ... txs preview: ...`

## 6. 출력 폴더와 재실행
- 처리 순서: 인자 확인 → **`output_dir`에서 `logs/`를 뺀 나머지 삭제** → `output_dir`, `logs/` 생성 → 로그 시작 → 입력 검사 → 처리.
- 삭제는 `output_dir`가 `/`가 아닐 때만 한다.
  - Bash: `find "$output_dir" -mindepth 1 -maxdepth 1 ! -name "logs" -print0 | xargs -0 rm -rf`
  - R: `list.files(output_dir, all.files = TRUE, no.. = TRUE, full.names = TRUE)`에서 `logs`를 빼고 `unlink(..., recursive = TRUE)`
- 재실행할 때 이전 결과가 지워지므로 **입력을 `output_dir` 안에 두면 안 된다.** `output_dir`이 `input_dir`이거나 그 상위 폴더가 아닌지 확인하는 것을 권장한다.
- 결과 하위 구조는 단계 번호를 붙여 고정한다.
  ```
  output_dir/
  ├─ 01_fragment_size/
  ├─ 02_bam_qc/<SampleID>/
  ├─ 03_shifted_bam/<SampleID>/
  ├─ 04_split_bam/<SampleID>/
  ├─ 05_metadata/   (다음 노드가 읽는 manifest, resolved sample sheet)
  ├─ 06_rds/
  └─ logs/
  ```
- 다음 노드가 읽는 파일의 이름과 위치는 바꾸지 않는다. 바꿔야 하면 새 주버전으로 만들고 다음 노드도 함께 맞춘다.
- 샘플별 처리 결과와 상태는 요약 TSV(manifest, summary)에 남긴다(예: `SplitStatus=done|empty_split:...|failed_optional`).

## 7. 로그
- 위치와 이름: `output_dir/logs/<YYYYMMDD_HHMMSS>_<PID>.log`
- 화면과 로그 파일에 같이 남긴다.
  - Bash: stdout은 `.log`, stderr는 `.error.log`로 나눠 남긴다.
    ```bash
    timestamp="$(date '+%Y%m%d_%H%M%S')_$$"
    log_file="${logs_dir}/${timestamp}.log"
    err_file="${logs_dir}/${timestamp}.error.log"
    exec > >(tee -a "$log_file") 2> >(tee -a "$err_file" >&2)
    ```
  - R: stdout만 `sink(log_con, append = TRUE, split = TRUE)`로 로그에 남기고, stderr는 sink하지 않는다(오류는 stderr로 그대로 나감). `on.exit()`에서 sink와 연결을 닫는다.
- 로그 첫 부분:
  ```
  ############################## <모듈 이름>
  Log file: <경로>
  Start time: YYYY-MM-DD HH:MM:SS

  parameters:
    input_dir   = ...
    output_dir  = ...
    threads     = ...
  ```
  기본값이 적용된 **최종값**을 모두 적는다.
- 단계 구분: `############################## Step N: <내용>`, 샘플 구분: `############################## Processing sample: <SampleID>`.
- 로그 끝부분: `############################## Summary`(전체·성공·건너뜀·실패 수), `############################## Done`(주요 출력 경로), `End time: ...`.

## 8. 입력 검사와 샘플 처리
- 입력 폴더·파일·참조 파일이 있는지 확인하고, 경로는 `normalizePath` 등으로 절대 경로로 바꿔 쓴다.
- 샘플 시트는 CSV이고 필수 컬럼(`SampleID`, `Condition`, 필요 시 `Replicate`)을 확인한다. 빈 값이 있으면 멈춘다.
- 입력 파일은 `SampleID`로 찾는다(이름이 `SampleID`로 시작하는 파일 우선, 없으면 포함하는 파일). 여러 개가 맞으면 멈추고 후보를 보여 준다.
- 염색체 이름(seqlevels)이 입력 사이에서 맞는지 확인하고, 맞지 않으면 양쪽 미리보기를 보여 주고 멈춘다.
- 인덱스(.bai, .fai)가 없으면 만들 수 있다. 이 경우 입력 옆에 파일이 생기므로 머리 주석에 적는다.

## 9. 종료 코드
- 성공: 0. 오류: 1.
- 여러 샘플을 처리할 때:
  - 모두 실패: `Error: all ... failed.` 후 종료 코드 1
  - 일부 실패: `Warning: some ... failed. Check summary TSV ...` 후 종료 코드 0, 실패 샘플은 요약 TSV에 기록
  - 일부를 건너뜀: 샘플별 사유를 로그(`WARNING: sample skipped: <SampleID> / <사유>`)와 요약 TSV에 남김
- 외부 명령은 종료 코드를 확인한다(`if ! samtools index ...; then error_msg ...`). Bash는 `set -u`, `set -o pipefail`을 쓴다.

## 10. 호스트 보호와 금지 명령
- `output_dir` 밖에는 쓰지 않는다(예외: 입력 옆 인덱스. 8절 참고).
- 삭제는 6절의 `output_dir` 정리만 한다. 다른 경로를 지우지 않는다.
- 사이트 명령 차단 목록(Java 정규식, 줄 단위, 주석 줄도 검사)에 걸리지 않게 쓴다. 2026-10-07 기준:
  | 패턴 | 대신 쓰는 방법 |
  |---|---|
  | `\bmv\b` | `cp` 또는 처음부터 최종 위치에 쓰기 |
  | `\bcd\b` | 절대 경로 사용 |
  | `\bkill\b`, `\bkillall\b`, `\bpkill\b` | 사용하지 않음 |
  | `\bhostname\b`, `\bservice\b`, `\bsystemctl\b` | 사용하지 않음. 주석·설명문에서도 이 단어를 피함 |
  | `\bfind\s+/\S*\s.*-exec\s+rm\b`, `\bfind\s+/\S*\s.*-delete\b` | 6절의 정리 방식 사용 |
  | `/BiO/K-BDS/USER/`, `/etc/passwd\b` | 참조하지 않음 |
  | `\bchmod\s+-R\b` | 사용하지 않음 |
  | `\brm\s+(-\S+\s+)*/(mnt\|data\|scratch\|home\|var\|tmp\|etc\|usr\|bin\|opt\|...)` | 절대 경로를 직접 지우지 않음 |
- 목록은 사이트에서 바뀔 수 있으므로 등록 전에 최신 목록으로 스크립트 전체를 검사한다.

## 11. 자원
- 스레드 수는 `threads` 인자로 받고 기본값을 준다(ATAC-seq 기본값 4). 외부 도구에 그대로 넘긴다(`samtools -@ "$threads"`).

## 12. 선택 사항 (Python 모듈 Retip에서 쓴 방식)
아래는 기준은 아니지만 필요할 때 쓸 수 있는 방식이다(`scripts/Retip/retip_*.1.0.py`).
- `--key value`, `--key=value` 형식도 받기(플랫폼이 이 형식으로 넘기는 경우 대비). 빈 값은 기본값으로 처리.
- `auto` 값: 입력에서 정보 읽기(`model=auto`), 할당 CPU 사용(`cpus=auto`), 앞 노드 기록에서 값 읽기(`rt_unit=auto`).
- 재실행 정리 범위를 스크립트가 만드는 결과 폴더(`output_dir/result/`)로 좁히고, 지우기 전에 symlink 여부와 실제 위치, 입력 포함 여부를 확인.
- 외부 프로그램의 stdout과 stderr를 따로 받아 `.log`, `.err`에 나눠 남기기.

## 13. 등록 전 확인 목록
- [ ] 위치와 이름이 `scripts/{파이프라인}/{모듈}.{주}.{부}.{확장자}` 형식이다.
- [ ] 동작이 바뀌었으면 새 버전 파일이고, 맨 위에 변경 내역이 있다.
- [ ] 머리 주석에 Usage와 Arguments(required/optional, default)가 있다.
- [ ] `key=value` 인자를 받고, 필수 인자 누락과 잘못된 형식은 종료 코드 1로 멈춘다.
- [ ] `output_dir`에서 `logs/`만 남기고 정리한 뒤 시작한다(`/` 보호).
- [ ] `logs/<YYYYMMDD_HHMMSS>_<PID>.log`에 시작 시각, 파라미터, 단계, 요약, 종료 시각이 남는다. 오류는 stderr로 나간다.
- [ ] 필요한 명령·패키지를 시작할 때 확인한다.
- [ ] 도구를 이름으로 부르고, 실행 중 설치·다운로드가 없다.
- [ ] 샘플별 상태가 요약 TSV에 남고, 종료 코드 규칙(9절)을 따른다.
- [ ] 사이트 명령 차단 목록에 걸리는 줄이 없다(주석 포함).
- [ ] 실행 이미지에서 실제 입력 또는 예제 입력으로 한 번 이상 실행해 보았다.
