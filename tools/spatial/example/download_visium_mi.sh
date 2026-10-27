#!/bin/bash
# Downloads the Visium example: human heart after myocardial infarction (Kuppe et al., Nature
# 2022; Zenodo 6580069, CC BY 4.0). Four control hearts and four ischaemic zones (IZ), one
# Space Ranger slice each. Writes only under <out_dir>; needs wget, tar and unzip, no root.
#
# Usage: bash download_visium_mi.sh <out_dir>
# Result: <out_dir>/<slice>/filtered_feature_bc_matrix.h5 and <out_dir>/<slice>/spatial/
#         for ctrl_p1, ctrl_p7, ctrl_p8, ctrl_p17, iz_p3, iz_p10, iz_p15, iz_p16
#         (spatial_prep input_dir = <out_dir>; about 4.8 GB is downloaded, 0.3 GB kept).
#
# The archives name the files spatial_<id>_filtered_feature_bc_matrix.h5 and pack spatial/ in
# a zip whose paths start with the authors' local folders, so the h5 is renamed and the zip
# is extracted without paths (unzip -j).
set -euo pipefail
out=${1:?usage: bash download_visium_mi.sh <out_dir>}
url=https://zenodo.org/records/6580069/files
mkdir -p "$out"
for pair in ctrl_p1:10X001 ctrl_p7:ACH003 ctrl_p8:ACH004 ctrl_p17:ACH002 \
            iz_p3:10X0017 iz_p10:ACH0014 iz_p15:ACH0015 iz_p16:ACH0016; do
    slice=${pair%%:*}; id=${pair#*:}
    echo "== $slice ($id)"
    tmp=$out/.tmp_$id
    rm -rf "$tmp"; mkdir -p "$tmp" "$out/$slice/spatial"
    wget -q -O "$tmp/$id.tar.gz" "$url/10X_Visium_$id.tar.gz?download=1"
    tar -xzf "$tmp/$id.tar.gz" -C "$tmp" --no-same-owner \
        "./$id/outs/spatial_${id}_filtered_feature_bc_matrix.h5" "./$id/outs/spatial_${id}_spatial.zip"
    mv "$tmp/$id/outs/spatial_${id}_filtered_feature_bc_matrix.h5" "$out/$slice/filtered_feature_bc_matrix.h5"
    unzip -q -o -j "$tmp/$id/outs/spatial_${id}_spatial.zip" -d "$out/$slice/spatial"
    rm -rf "$tmp"
    [ -f "$out/$slice/spatial/tissue_positions_list.csv" ] || { echo "missing spatial files in $slice" >&2; exit 1; }
done
echo "done: $out"
