CLOSHA 분석 스크립트 작성 규칙 1.0

작성일: 2026-10-07

개정 (2026-10-17): 작업 번호와 배포 번호(1.2절), 데이터 결과로 끝나는 경우의 종료 코드(9절), BAM read group(8절), 메모리 규칙(11절)을 추가했다.

이 문서는 CLOSHA 파이프라인 노드에서 실행되는 분석 스크립트(Bash, R, Python)의 작성 규칙이다. 기준은 CLOSHA 2.0 운영에서 쓰던 `scripts/ATAC-seq/`의 원본 스크립트(organellar_filter, ATAC_QC, ATAC_QC_plot, MACS3_callpeak_ATAC, peak_annotation, tf_footprinting은 1.0, differential_accessibility는 1.2, atac_motif는 1.1)의 공통 형식이다. 실행 이미지(DEF) 규칙은 docs/CLOSHA_DEF_Generator_Agent_v1.md를 따른다.

참고 예: Bash는 `organellar_filter.1.0.sh`, R은 `ATAC_QC.1.0.R`, `differential_accessibility.1.2.R`.

원본 스크립트 중 일부는 이 문서의 7절(stdout/stderr 구분)과 11절(스레드 자동 결정)을 따르지 않는다. 규칙에 맞춘 첫 버전은 원본 다음 번호다(2026-10-07): `organellar_filter.1.1.sh`, `MACS3_callpeak_ATAC.1.1.sh`, `tf_footprinting.1.1.sh`, `ATAC_QC.1.1.R`, `ATAC_QC_plot.1.1.R`, `peak_annotation.1.1.R`, `differential_accessibility.1.3.R`, `atac_motif.1.2.R`. 각 파일 맨 위에 이전 버전과의 차이가 적혀 있다.

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
- 번호는 CLOSHA 2.0 운영 버전을 이어서 쓴다. 받은 원본은 운영에서 쓰던 번호 그대로 저장하고(예: 운영 differential_accessibility 1.2 → `differential_accessibility.1.2.R`), 고친 것은 그다음 번호로 만든다. 같은 번호를 다른 내용에 다시 쓰지 않는다.
- 새 버전 파일의 맨 위(첫 줄 바로 아래)에 이전 버전과의 차이를 적는다.
  ```
  # Version 1.1 (changes from ATAC_QC.1.0.R):
  #   Tn5 shift and nucleosome splitting read the bamQC clean BAM ...
  ```
- 부버전: 같은 실행 이미지에서 돌아가는 변경. 주버전: 입력·출력 형식이 호환되지 않거나 실행 이미지(DEF)를 바꿔야 하는 변경.
- 오타, 주석, 로그 문구만 고친 경우는 같은 버전에서 고칠 수 있다.
- 새 패키지나 도구가 필요하면 DEF도 새 버전으로 만든다. 같은 이미지로 충분하면 DEF는 두고 DEF 주석의 대상 스크립트 목록만 갱신한다.
- 다른 팀에서 받은 스크립트(예: `GATK_MarkDuplicates_1.0.sh`)는 고치지 않는 것을 먼저 생각한다. 받은 스크립트가 요구하는 조건은 앞 단계의 우리 스크립트에서 맞춘다(예: GATK 4.6이 요구하는 @RG를 bowtie2에서 붙임).

### 1.2 배포 번호와 배포 폴더
`scripts/`의 번호(작업 번호)는 개발 중 바뀔 때마다 올라가므로, 사용자에게 나가는 번호(배포 번호)와 따로 관리한다.
- **작업 번호**: `scripts/{파이프라인}/`의 파일 번호. 1.1절대로 고칠 때마다 올리고 다시 쓰지 않는다. 배포되지 않은 중간 번호도 그대로 둔다.
- **배포 번호**: 이전 플랫폼(CLOSHA 2.0) 운영 번호 + 1. 한 번 배포할 때 모듈마다 하나만 올린다. 이번 플랫폼에서 새로 만든 모듈은 1.0이다.
  - 예(2026-10-16 배포): differential_accessibility 작업 1.4 → 배포 1.3(2.0은 1.2), atac_motif 작업 1.5 → 배포 1.2(2.0은 1.1), bowtie2 작업 1.5 → 배포 1.1, functional_enrichment 작업 1.2 → 배포 1.0(새 모듈).
- **배포 폴더**: `release/{플랫폼}/{파이프라인}/{배포일 YYYY-MM-DD}/`. 예: `release/CLOSHA3/ATAC-seq/2026-10-16/`. 안에 두는 것:
  - 배포 스크립트(배포 번호 이름)
  - `RELEASE.md`(배포 ↔ 작업 파일 ↔ 커밋 대응표, 바뀐 점)
  - `release.tsv`(module, release_file, closha2_file, work_file, image)
  - `build_release.py`(작업 파일로 배포 파일을 만드는 스크립트)
  - 포탈 원고 사본(`docs/`), 결과 원본과 결과 PNG(`results/`, `portal_images/`)
- **배포 파일 머리 주석**: 작업 번호별 변경 내역을 지우고 블록 **하나**로 바꾼다. 작업 번호는 배포 파일에 나오지 않는다(대응은 `RELEASE.md`에만).
  ```
  # Version 1.3 (changes from differential_accessibility.1.2, CLOSHA 2.0):
  #   QC: a sample correlation heatmap ... (주제별로 묶어 씀)
  ```
  새 모듈은 `# Version 1.0 (first release in CLOSHA 3.0):` 아래에 모듈이 하는 일을 쓴다.
- 배포 파일은 작업 파일과 **머리 주석과 자기 파일 이름만** 다르다. `build_release.py`로 만들고 `python3 tools/check_release.py <배포 폴더>`로 확인한다. 로그·오류 문구에 버전 번호를 넣지 않는다(넣으면 두 파일이 달라진다).
- **배포 폴더는 사용자가 CLOSHA에서 테스트를 마치고 배포한다고 한 뒤에 만든다.** 테스트 중에는 `scripts/`에서만 고친다.
- 배포한 폴더는 고치지 않는다. 배포 뒤에 고친 것은 `scripts/`에 새 작업 번호로 만들고, 다음 배포 때 새 날짜 폴더와 다음 배포 번호로 낸다.
- 다른 팀 스크립트(GATK_MarkDuplicates)는 우리 배포에 넣지 않는다.

## 2. 실행 환경
- 실행 형태: `apptainer exec <sif> bash <스크립트> key=value ...`, `apptainer exec <sif> Rscript <스크립트> key=value ...`. 스크립트는 이미지에 넣지 않고 실행할 때 연결된다.
- 도구는 **이름으로만** 호출한다(`samtools`, `macs3`, `TOBIAS`, `bedtools`). 이미지 내부 절대 경로(`/opt/bio/bin/...`)를 쓰지 않는다.
- 필요한 명령과 패키지는 시작할 때 확인한다.
  - Bash: `for cmd in samtools awk ...; do command -v "$cmd" ...` → 없으면 `Error: required command not found in PATH: <cmd>`
  - R: `requireNamespace(pkg)` 반복 → 없으면 `ERROR: required R package not found: <pkg>`
- 실행 중 외부 네트워크에 접속하지 않는다. 패키지 설치와 데이터 다운로드를 하지 않는다(필요한 것은 DEF에서 설치).
- R은 패키지를 붙인 뒤에도 다른 패키지와 이름이 겹치는 함수는 `pkg::function`으로 부른다(예: `ChIPpeakAnno::estLibSize`, `ATACseqQC::enrichedFragments`).

### 2.1 운영 실행 명령 (기준)
포탈(Slurm + Apptainer)이 모듈마다 던지는 실제 명령이다(2026-10-14 받은 Amplicon 모듈 예, 사용자 이름은 `<user>`로 바꿈). 스크립트는 이 환경을 기준으로 작성하고 확인한다.

```
apptainer exec \
	--cleanenv \
	--env TZ=Asia/Seoul \
	--env OPENBLAS_NUM_THREADS=1 \
	--env OMP_NUM_THREADS=1 \
	--env MKL_NUM_THREADS=1 \
	--env NUMEXPR_NUM_THREADS=1 \
	-B /BiO/K-BDS/USER/<user>:/<user> \
	-B /BiO/K-BDS/BiO-EXPRESS/script_public:/script_public \
	-B /BiO/K-BDS/USER/bio-hub:/bio-hub \
	-B /BiO/K-BDS/USER/bio-workflow/example:/bio-workflow/example \
	'/BiO/K-BDS/BiO-EXPRESS/apptainer/images/<uuid>.sif' /bin/bash \
	'/script_public/bio-workflow/Omics/<pipeline>/<uuid>.sh' \
	"input_dir"='/bio-hub/...' "output_dir"='/<user>/.../output' "trunc_len_f"='150' ...
```

이 명령에서 스크립트가 지켜야 할 것:
- **경로는 인자로만 받는다.** 컨테이너 안에서 보이는 호스트 경로는 `-B`로 연결한 네 곳(`/<user>`, `/script_public`, `/bio-hub`, `/bio-workflow/...`)뿐이다. 입력 파일 안에 적힌 경로(예: 샘플 정보 CSV의 BAM 경로)는 이 네 곳 밖이면 열 수 없으므로, 파일과 폴더는 `key=value` 인자로 받는다.
- **앞 모듈이 남긴 절대 경로는 같은 연결 안에서만 유효하다.** 연결 위치가 작업마다 같으므로 앞 모듈이 결과 파일에 적은 경로(예: ATAC_QC의 `05_metadata/atac_qc_manifest.tsv`)를 다음 작업이 그대로 열 수 있다. 위 네 곳 밖을 가리키는 경로는 쓰지 않는다.
- **환경 변수는 넘어오지 않는다(`--cleanenv`).** 필요한 값은 인자나 DEF의 `%environment`로 받는다.
- **`OMP_NUM_THREADS` 등은 포탈이 정한다.** 싱글 코어 작업은 1이다. 코어 수는 11절대로 `nproc`으로 읽는다(`nproc`이 `OMP_NUM_THREADS`를 따른다).
- **스크립트 파일 이름은 바뀐다.** 포탈은 스크립트를 `<uuid>.sh`로 복사해 실행하므로, 스크립트 이름이나 위치(`$0`, `BASH_SOURCE`)로 다른 파일을 찾지 않는다. Bash 스크립트는 `/bin/bash <스크립트>`로 실행된다(실행 권한이나 `#!` 줄에 기대지 않는다).
- **인자는 `"key"='value'` 꼴로 넘어온다.** 셸이 따옴표를 벗겨 스크립트에는 `key=value`로 들어온다. 값에 공백이나 `|`, `$` 같은 문자가 있어도 그대로 전달된다.
- `/opt/apps` 같은 호스트 도구 폴더는 연결되지 않는다. 도구는 이미지 안의 PATH에서 찾는다.

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
- 선택 인자는 기본값을 준다(Bash `pvalue="${pvalue:-0.05}"`, R `if (!exists("seqlev")) seqlev <- "auto"`). 스레드 수는 11절을 따른다.
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
- 진행 메시지는 **stdout**, 오류(`Error:`/`ERROR:`)와 경고(`Warning:`/`WARNING:`)는 **stderr**로 내보낸다(7절).
```bash
error_msg() { echo "Error: $*" >&2; }
warn_msg()  { echo "Warning: $*" >&2; }
info_msg()  { echo "$*"; }
```
```r
err_con <- NULL   # logs/<stamp>.error.log, opened right after logs/ is created (7절)
emit_err <- function(txt) {
	cat(txt, file = stderr())
	if (!is.null(err_con)) { cat(txt, file = err_con); flush(err_con) }
}
stop_err <- function(...) { emit_err(paste0("ERROR: ", paste(..., collapse = ""), "\n")); quit(status = 1) }
warn_msg <- function(...) { emit_err(paste0("WARNING: ", paste(..., collapse = ""), "\n")) }
msg      <- function(...) { cat(..., "\n") }
```
- 오류는 종료 코드 1로 끝낸다.
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

## 7. 로그와 stdout/stderr 구분
### 7.1 두 스트림을 반드시 나눈다
| 스트림 | 내용 | 로그 파일 |
|---|---|---|
| **stdout** | 시작 정보, 파라미터, 단계 진행, 샘플별 처리 결과, 요약, 종료 시각 | `output_dir/logs/<YYYYMMDD_HHMMSS>_<PID>.log` |
| **stderr** | `Error:`/`ERROR:` 오류, `Warning:`/`WARNING:` 경고, 외부 도구와 라이브러리가 stderr로 내는 메시지 | `output_dir/logs/<YYYYMMDD_HHMMSS>_<PID>.error.log` |
- 두 스트림을 합치지 않는다. `2>&1`, `stderr=STDOUT`, R `sink(type = "message")`로 stderr를 stdout 쪽에 섞지 않는다.
- **오류·경고 메시지는 첫 줄부터 마지막 줄까지 모두 stderr로 보낸다.** 오류 뒤에 붙는 설명(예상 폴더 구조, 찾은 파일 목록, 해결 방법 Tip 등)도 오류 메시지의 일부다. 첫 줄만 `>&2`로 보내고 나머지를 stdout으로 보내지 않는다. 여러 줄이면 묶어서 한 번에 보낸다.
  ```bash
  {
  	echo "Error: No BAM files matching '*${suffix}' in $dir"
  	echo "Available BAM files:"
  	find "$dir" -name "*.bam" | sed 's/^/  /'
  	echo "Tip: set alignment_suffix accordingly."
  } >&2
  exit 1
  ```
- **로그 파일을 열기 전(인자 해석, 필수 인자 확인) 단계의 오류도 stderr로 보낸다.** 예: `echo "Invalid argument format: $arg" >&2`.
- `.log`와 `.error.log`는 다른 파일이다. stderr를 `.log`에 함께 쓰지 않는다(`exec 2> >(tee -a "$log_file" >&2)`처럼 같은 파일로 보내지 않는다).
- 화면(플랫폼이 받는 stdout/stderr)과 로그 파일에 **둘 다** 남긴다. 같은 실행의 `.log`와 `.error.log`는 같은 `<stamp>`를 쓴다.
- 외부 도구를 실행할 때도 stdout과 stderr를 따로 받는다. 도구의 진행 출력은 `.log`로, 오류 출력은 `.error.log`로 간다.
- 실패 판단은 종료 코드로 한다(9절). stderr에 경고가 있다는 이유만으로 실패로 보지 않는다(예: AutoGluon의 torch 없음 경고).

### 7.2 언어별 구현
- Bash:
  ```bash
  timestamp="$(date '+%Y%m%d_%H%M%S')_$$"
  log_file="${logs_dir}/${timestamp}.log"
  err_file="${logs_dir}/${timestamp}.error.log"
  # stdout / stderr separate
  exec > >(tee -a "$log_file") 2> >(tee -a "$err_file" >&2)
  ```
  이후 실행하는 외부 도구도 같은 규칙으로 나뉜다. `2>&1`을 붙이지 않는다.
- R:
  ```r
  stamp    <- paste0(format(Sys.time(), "%Y%m%d_%H%M%S"), "_", Sys.getpid())
  log_file <- file.path(logs_dir, paste0(stamp, ".log"))
  err_file <- file.path(logs_dir, paste0(stamp, ".error.log"))
  log_con  <- file(log_file, open = "at")
  err_con  <- file(err_file, open = "at")
  sink(log_con, append = TRUE, split = TRUE)          # stdout -> console + .log
  on.exit({
  	try(sink(), silent = TRUE)
  	try(close(log_con), silent = TRUE)
  	try(close(err_con), silent = TRUE)
  }, add = TRUE)
  ```
  - 오류와 경고는 5절의 `stop_err`, `warn_msg`로 stderr와 `.error.log`에 같이 쓴다.
  - 패키지가 내는 `message()`와 `warning()`은 stderr로 나간다. `.error.log`에도 남기려면 본문을 `withCallingHandlers(..., message = function(m) cat(conditionMessage(m), file = err_con), warning = function(w) cat("WARNING: ", conditionMessage(w), "\n", file = err_con))`로 감싼다.
  - 외부 도구는 `system2(cmd, args, stdout = "", stderr = "")`처럼 두 스트림을 그대로 두거나, 파일로 받을 때도 따로 받는다.
- Python: `print(..., file=sys.stdout)`와 `print(..., file=sys.stderr)`를 나누고, 외부 도구는 `subprocess.Popen(..., stdout=PIPE, stderr=PIPE)`로 따로 읽어 각각 `.log`, `.error.log`에 남긴다(예: `scripts/Retip/retip_*.1.0.py`).

### 7.3 로그 내용
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
- 입력은 인자로 받는 폴더(필수)에서 찾는다. 샘플 시트 안에 파일 경로를 적게 하지 않는다. 같은 입력을 두 인자(폴더와 파일)로 받지 않는다.
- 정렬 결과 BAM에는 read group(@RG: ID, SM, LB, PL)을 붙인다. GATK 4.6 MarkDuplicates는 @RG가 없으면 NullPointerException으로 멈춘다(4.5 이하는 "Unknown Library"로 처리).
- 결과를 실제로 쓰는 데 꼭 필요한 후처리(예: SAM → 정렬 BAM + 인덱스)는 기본값을 켜 둔다. 포탈에 인자를 등록하지 않으면 기본값으로만 실행된다.

## 9. 종료 코드
- 성공: 0. 오류: 1.
- 여러 샘플을 처리할 때:
  - 모두 실패: `Error: all ... failed.` 후 종료 코드 1
  - 일부 실패: `Warning: some ... failed. Check summary TSV ...` 후 종료 코드 0, 실패 샘플은 요약 TSV에 기록
  - 일부를 건너뜀: 샘플별 사유를 로그(`WARNING: sample skipped: <SampleID> / <사유>`)와 요약 TSV에 남김
- **오류와 데이터 결과를 구분한다.** 실행은 정상인데 데이터 때문에 결과가 비는 경우(차등 영역이 적어 유전자 목록이 비거나, 검정할 GO term이 없음 등)는 오류가 아니다. 경고(이유와 확인할 점 포함)를 stderr에 남기고, 요약 TSV에 상태(예: `empty`, `no_testable_terms`)를 적고, 종료 코드 0으로 끝낸다. 종료 코드 1은 입력·인자·도구 실패에만 쓴다.
- 분석에 필요한 최소 조건을 먼저 확인하고, 모자라면 도구 안에서 알 수 없는 오류로 죽지 않게 이유를 적고 멈춘다. 예: atac_motif는 필터 후 남은 피크 수가 logFC 구간을 만들기에 모자라면 남은 피크 수, 걸린 필터(`fdr_filter`, 염색체), 바꿔 볼 인자를 오류 문구에 쓴다.
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
- CPU와 메모리는 CLOSHA 실행 환경 설정(예: 싱글 코어, 4코어)에서 노드마다 **할당된다.** 스크립트는 자원 크기를 고정하지 않는다.
- 스레드 수는 **할당된 코어 수를 스크립트가 직접 확인해서** 쓴다.
  - `threads` 인자는 선택이고 기본값은 `auto`(할당된 코어 수)다. 숫자를 주면 할당된 코어 수를 넘지 않게 줄이고, 줄였으면 로그 파일이 열린 뒤 stderr에 경고를 남긴다(예: `Warning: threads=16 requested, allocated cores: 4; using 4`). 스레드 수는 속도만 바꾸고 결과는 바꾸지 않으므로 멈추지 않는다. `auto`나 양의 정수가 아니면 오류로 멈춘다.
  - 포탈에는 `threads`를 등록하지 않는다. 실행 환경의 Processor Core 선택(싱글 코어 또는 최대 4코어)이 곧 스레드 수다. 둘을 따로 고르게 하면 서로 엇갈린다.
  - 확인 방법(할당 범위를 반영하는 값):
    | 언어 | 방법 | 쓰지 않는 것 |
    |---|---|---|
    | Bash | `nproc` | `/proc/cpuinfo` 줄 수 |
    | R | `as.integer(system("nproc", intern = TRUE))` (실패하면 `length(parallel::mcaffinity())`) | `parallel::detectCores()` (서버 전체 코어 수) |
    | Python | `int(subprocess.check_output(["nproc"]))` (실패하면 `len(os.sched_getaffinity(0))`) | `os.cpu_count()` (서버 전체 코어 수) |
    - 세 언어 모두 `nproc`을 먼저 쓴다. 포탈 선택과 맞는 것이 운영에서 확인된 값이 `nproc`이기 때문이다(아래).
  - `nproc`은 `OMP_NUM_THREADS`가 있으면 그 값을 돌려준다. 싱글 코어 작업의 실행 명령에는 `--env OMP_NUM_THREADS=1`이 들어간다. 2026-10-14 운영 로그에서 Bash 스크립트의 `nproc`은 포탈 선택과 같았다(싱글 `allocated 1`, 최대 4코어 `allocated 4`). 그래서 `env -u OMP_NUM_THREADS nproc`처럼 이 값을 빼지 않는다.
  - 최대 4코어 작업에서 이 4가 `OMP_NUM_THREADS`에서 왔는지 CPU 묶음(affinity)에서 왔는지는 아직 확인하지 않았다. `mcaffinity()`, `sched_getaffinity()`는 `OMP_NUM_THREADS`를 보지 않고 CPU 묶음만 세므로, CPU를 묶지 않는 환경이면 노드 전체 코어 수가 나올 수 있다. 그래서 대체 수단으로만 쓴다. 확인은 `tools/diag/core_check.sh`를 최대 4코어로 실행해서 한다.
  - 도구가 1코어로만 계산하는 모듈(MACS3, idr, ChIPseeker, edgeR, clusterProfiler 등이 중심)도 같은 방식으로 코어 수를 읽어, 스레드를 받는 보조 도구(`samtools -@` 등)에 넘긴다. 포탈 원고에는 모듈마다 권장 Processor Core(싱글 코어 또는 최대 4코어)를 적는다.
  - 결정한 값을 외부 도구에 넘기고(`samtools -@ "$threads"`, `TOBIAS ... --cores "$threads"`), 계산 라이브러리 스레드(`OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS`)도 같은 값으로 맞춘다.
  - 로그의 `parameters:`에 요청값과 실제값을 함께 남긴다. 예: `threads = 4 (requested auto, allocated 4)`
- 실행 환경이 코어를 지정하지 않고 사용량만 제한하는 방식(Docker `--cpus`, Kubernetes `limits.cpu`)으로 바뀌면 위 방법은 서버 전체 코어 수를 돌려줄 수 있다. 그때는 cgroup `cpu.max` 값도 읽도록 규칙을 갱신한다.
- 메모리는 할당량을 넘지 않게 샘플 단위로 처리하고, 큰 데이터를 한꺼번에 메모리에 올리지 않는다(예: `readBamFile(..., bigFile = TRUE)`).
  - 유전체 전체 행렬은 나눠서 만든다. 예: peak_annotation의 TSS tag matrix는 피크와 겹치는 promoter만 묶음 단위로 계산한다(1.0은 8GB를 넘어 멈췄고, 고친 뒤 2.8GB, 결과 같음).
  - 점이 많은 heatmap은 래스터로 그린다. 벡터 PDF는 메모리를 많이 쓰고 비어서 저장될 수 있다.
  - 병렬 작업자는 메모리를 작업자 수만큼 늘린다(atac_motif k-mer 단계: 4코어에서 20.5GB). 코어 수를 늘릴 때는 메모리도 함께 늘린다.
  - 샘플마다 만든 큰 객체는 다음 샘플 전에 지운다(`rm()`, `gc()`).
- OOM(메모리 부족)으로 멈추면 먼저 로그에서 어느 단계인지 확인한다. 데이터 크기에 비례하는 정상 사용이면 포탈 메모리를 올리고, 한꺼번에 올리는 코드 때문이면 스크립트를 고친다.
- 포탈 원고에는 모듈마다 권장 Processor Core와 메모리를 적는다. 사람 유전체처럼 큰 유전체도 고려한다(예: bowtie2, atac_motif는 최대 64GB).


## 12. 등록 전 확인 목록
- [ ] 위치와 이름이 `scripts/{파이프라인}/{모듈}.{주}.{부}.{확장자}` 형식이다.
- [ ] 동작이 바뀌었으면 새 버전 파일이고, 맨 위에 변경 내역이 있다.
- [ ] 머리 주석에 Usage와 Arguments(required/optional, default)가 있다.
- [ ] `key=value` 인자를 받고, 필수 인자 누락과 잘못된 형식은 종료 코드 1로 멈춘다.
- [ ] `output_dir`에서 `logs/`만 남기고 정리한 뒤 시작한다(`/` 보호).
- [ ] stdout(진행)과 stderr(오류·경고)가 나뉘어 화면과 `logs/<stamp>.log`, `logs/<stamp>.error.log`에 각각 남는다. `2>&1`로 합치지 않는다.
- [ ] 오류·경고는 여러 줄 설명까지 모두 stderr로 가고, 인자 해석 단계의 오류도 stderr로 간다. 일부러 오류를 내 보고 stdout에 오류 문구가 남지 않는지 확인했다.
- [ ] `.log`에 시작 시각, 파라미터(최종값), 단계, 요약, 종료 시각이 남는다.
- [ ] 스레드 수를 고정하지 않고 할당된 코어 수(`threads=auto`)를 쓰며, 실제값을 로그에 남긴다.
- [ ] 필요한 명령·패키지를 시작할 때 확인한다.
- [ ] 도구를 이름으로 부르고, 실행 중 설치·다운로드가 없다.
- [ ] 샘플별 상태가 요약 TSV에 남고, 종료 코드 규칙(9절)을 따른다. 데이터 때문에 결과가 비는 경우는 경고와 종료 코드 0이다.
- [ ] 사이트 명령 차단 목록에 걸리는 줄이 없다(주석 포함).
- [ ] 실행 이미지에서 실제 입력 또는 예제 입력으로 한 번 이상 실행해 보았고, 사용한 메모리를 확인했다.
- [ ] 배포할 때는 배포 폴더를 만들고 `tools/check_release.py`가 통과한다(1.2절).
