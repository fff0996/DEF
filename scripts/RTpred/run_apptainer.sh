#!/usr/bin/env bash
# Independent application launcher, not a mandatory serial pipeline.
set -euo pipefail
if [[ $# -lt 1 ]]; then
    echo 'Usage: run_apptainer.sh predict|train|compare [module options using /work paths]' >&2
    exit 2
fi
mdcc_module=$1
shift
case "$mdcc_module" in
    predict|train|compare) ;;
    *) echo 'Unknown module' >&2; exit 2 ;;
esac
mdcc_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# The current directory is the job workspace. Inputs/outputs use /work/... paths.
exec apptainer run --cleanenv --containall --bind "$PWD:/work" \
    "$mdcc_root/containers/$mdcc_module.sif" "$@"
