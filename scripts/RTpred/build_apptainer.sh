#!/usr/bin/env bash
set -euo pipefail
mdcc_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd -- "$mdcc_root"
for mdcc_module in predict train compare; do
    apptainer build --fakeroot "containers/$mdcc_module.sif" "containers/$mdcc_module.def"
done
