#!/bin/bash
# Downloads the 10x Visium HD human colorectal cancer example (FFPE; Oliveira et al., Nat Genet
# 2025): three tumour slides (P1, P2, P5) and two normal adjacent slides (P3, P5).
# Writes only under <out_dir>; needs wget and tar, no root.
#
# Usage: bash download_hd_crc.sh <out_dir> [bins]
#   bins: bin folders to keep, default "016" (16 um); for example "008 016" keeps 8 and 16 um.
# Result: <out_dir>/<slide>/binned_outputs/square_NNNum/ for slides crc_p1, crc_p2, crc_p5,
#         normal_p3, normal_p5 (spatial_hd_prep input_dir = <out_dir>).
#
# Each archive (10-17 GB) is streamed through tar, so only the kept folders reach the disk.
# The 8 and 16 um tissue images (png, jpg, and in the CRC set cytassist_image.tiff) are
# hard links to the 2 um ones in the archives, so the 2 um images are extracted too and
# copied where a link was not made. Without the tiff, tar stops with "Cannot hard link".
set -euo pipefail
out=${1:?usage: bash download_hd_crc.sh <out_dir> [bins]}
bins=${2:-016}
base=https://cf.10xgenomics.com/samples/spatial-exp/3.0.0
mkdir -p "$out"
for pair in crc_p1:Visium_HD_Human_Colon_Cancer_P1 crc_p2:Visium_HD_Human_Colon_Cancer_P2 \
            crc_p5:Visium_HD_Human_Colon_Cancer_P5 normal_p3:Visium_HD_Human_Colon_Normal_P3 \
            normal_p5:Visium_HD_Human_Colon_Normal_P5; do
    slide=${pair%%:*}; name=${pair#*:}
    mkdir -p "$out/$slide"
    pats=("binned_outputs/square_002um/spatial/*.png" "binned_outputs/square_002um/spatial/*.jpg"
          "binned_outputs/square_002um/spatial/*.tiff")
    for b in $bins; do pats+=("binned_outputs/square_${b}um/*"); done
    echo "== $slide ($name)"
    wget -q -O - "$base/$name/${name}_binned_outputs.tar.gz" |
        tar -xz -C "$out/$slide" --no-same-owner --wildcards "${pats[@]}"
    for b in $bins; do
        d=$out/$slide/binned_outputs/square_${b}um/spatial
        for f in "$out/$slide"/binned_outputs/square_002um/spatial/*.png "$out/$slide"/binned_outputs/square_002um/spatial/*.jpg \
                 "$out/$slide"/binned_outputs/square_002um/spatial/*.tiff; do
            [ -e "$f" ] || continue
            [ -e "$d/$(basename "$f")" ] || cp "$f" "$d/"
        done
        [ -f "$d/tissue_lowres_image.png" ] && [ -f "$out/$slide/binned_outputs/square_${b}um/filtered_feature_bc_matrix.h5" ] ||
            { echo "missing files in $slide square_${b}um" >&2; exit 1; }
    done
    rm -rf "$out/$slide/binned_outputs/square_002um"
done
echo "done: $out"
