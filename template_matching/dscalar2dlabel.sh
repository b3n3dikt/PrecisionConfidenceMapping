#!/bin/bash
# Convert a network-assignment .dscalar.nii into a .dlabel.nii (network names and
# colours come from support_files/Gordon_labels_with_scan.txt), written next to the input.
# Usage: dscalar2dlabel.sh <file.dscalar.nii>   (wb_command must be on PATH)
set -e
in_dscalar="$1"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out_dlabel="$(dirname "${in_dscalar}")/$(basename "${in_dscalar}" .dscalar.nii).dlabel.nii"
wb_command -cifti-label-import "${in_dscalar}" "${here}/support_files/Gordon_labels_with_scan.txt" "${out_dlabel}"
