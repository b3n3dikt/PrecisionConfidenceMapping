#!/usr/bin/env bash
#
# confmap_to_ptseries.sh    generic Workbench mini-pipeline
#
# (1) binarise a confidence map at a chosen threshold
# (2) find surface-based clusters in that binary map
# (3) convert clusters to a .dlabel
# (4) parcellate a dtseries  ptseries
#
# Requires:  wb_command e v1.5  |  bash e 4
# Usage:     ./confmap_to_ptseries.sh --confmap scan_conf.dscalar.nii \
#               --dtseries rest_8m.dtseries.nii \
#               --left_surf sub-01_L.midthickness.gii \
#               --right_surf sub-01_R.midthickness.gii \
#               --thr 0.99  --outdir results/scan_thr-0.99
# ---------------------------------------------------------------------------

set -euo pipefail

##############################################################################
#  Argument parsing
##############################################################################
print_help () {
cat <<EOF
USAGE:
  $(basename "$0") --confmap  PATH.dscalar.nii  \\
                   --dtseries PATH.dtseries.nii \\
                   --left_surf PATH_L.surf.gii  \\
                   --right_surf PATH_R.surf.gii \\
                   [--thr 0.99]                 \\
                   [--min_thr 0.1]              \\
                   [--min_area 100]             \\
                   [--outdir PATH]              \\
                   [--label_base NAME]          \\
                   [--help]

OPTIONS
  --confmap     Confidence-map dscalar to threshold
  --dtseries    Dense time-series you want to parcellate
  --left_surf   Subject-specific (or atlas) L midthickness
  --right_surf  Subject-specific (or atlas) R midthickness
  --thr         Binarisation threshold           (default: 0.99)
  --min_thr     min-threshold for wb_command -cifti-find-clusters
  --min_area    min-area     for wb_command -cifti-find-clusters
  --label_base  Stem used to name intermediate files
  --outdir      Where outputs go (default: <confmap_dir>/Thresholded-<thr>)
EOF
}

# defaults
THR=0.8
MIN_THR=0.1
MIN_AREA=100
OUTDIR=""
LABEL_BASE="Clusters"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --confmap)    CONFMAP=$2; shift 2;;
    --dtseries)   DTSERIES=$2; shift 2;;
    --left_surf)  LEFT_SURF=$2; shift 2;;
    --right_surf) RIGHT_SURF=$2; shift 2;;
    --thr)        THR=$2; shift 2;;
    --min_thr)    MIN_THR=$2; shift 2;;
    --min_area)   MIN_AREA=$2; shift 2;;
    --outdir)     OUTDIR=$2; shift 2;;
    --label_base) LABEL_BASE=$2; shift 2;;
    --help|-h)    print_help; exit 0;;
    *) echo "Unknown option $1"; print_help; exit 1;;
  esac
done

##############################################################################
#  Sanity checks
##############################################################################
for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
  [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} is required"; exit 1; }
  [[ -f "${!req}" ]]   || { echo "ERROR: file not found: ${!req}"; exit 1; }
done
command -v wb_command &>/dev/null || { echo "ERROR: wb_command not on PATH"; exit 1; }

[[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
mkdir -p "$OUTDIR"

##############################################################################
#  Derived file names
##############################################################################
BIN_DSCAL="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.dscalar.nii"
BIN_DLAB="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.dlabel.nii"
BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.ptseries.nii"
CLUST_DSCAL="${OUTDIR}/${LABEL_BASE}_clust-thr${THR}.dscalar.nii"
CLUST_DLAB="${OUTDIR}/${LABEL_BASE}_clust-thr${THR}.dlabel.nii"
CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_clust-thr${THR}.ptseries.nii"
LEFTGII="${OUTDIR}/left.func.gii"
RIGHTGII="${OUTDIR}/right.func.gii"
LEFTROI="${OUTDIR}/left_roi.func.gii"
RIGHTROI="${OUTDIR}/right_roi.func.gii"

##############################################################################
#  1. Binarise
##############################################################################
echo "Step 1  |  Binarising ${CONFMAP} at > ${THR}"
wb_command -cifti-math "x > ${THR}" "$BIN_DSCAL" -var x "$CONFMAP"

##############################################################################
#  2a. Find clusters
##############################################################################
echo "Step 2a  |  Finding clusters  (min_thr=${MIN_THR}, min_area=${MIN_AREA})"
wb_command -cifti-find-clusters "$BIN_DSCAL" \
            "$MIN_THR" "$MIN_AREA" "$MIN_THR" "$MIN_AREA" COLUMN \
            "$CLUST_DSCAL" \
            -left-surface  "$LEFT_SURF" \
            -right-surface "$RIGHT_SURF"
            
##############################################################################
#  2b. Mask out subcortex on binary file
##############################################################################
echo "Step 2b  |  Mask out subcortex in binary cluster"
##split it
wb_command -cifti-separate "$BIN_DSCAL" COLUMN -metric CORTEX_LEFT "${LEFTGII}"
wb_command -cifti-separate "$BIN_DSCAL" COLUMN -metric CORTEX_RIGHT "${RIGHTGII}"

##binarize again
wb_command -metric-math 'x != 0' "${LEFTROI}" -var x "${LEFTGII}"
wb_command -metric-math 'x != 0' "${RIGHTROI}" -var x "${RIGHTGII}"

##re-make dscalar
wb_command -cifti-create-dense-scalar "${BIN_DSCAL}" -left-metric ${LEFTROI} -right-metric ${RIGHTROI}


##############################################################################
#  3. Label import
##############################################################################
echo "Step 3  |  Converting to dlabel"
wb_command -cifti-label-import "$BIN_DSCAL" /dev/null "$BIN_DLAB"
wb_command -cifti-label-import "$CLUST_DSCAL" /dev/null "$CLUST_DLAB"
#wb_command -cifti-label-import "$CORTEX_DSCAL" /dev/null "$CORTEX_DLAB"

##############################################################################
#  4. Parcellate dtseries
##############################################################################
echo "Step 4  |  Parcellating dtseries  ptseries"
wb_command -cifti-parcellate "$DTSERIES" "$BIN_DLAB" COLUMN "$BIN_PTSERIES"
wb_command -cifti-parcellate "$DTSERIES" "$CLUST_DLAB" COLUMN "$CLUST_PTSERIES"
#wb_command -cifti-parcellate "$DTSERIES" "$BIN_DLAB" COLUMN "$BIN_PTSERIES"

echo -e "\n  Finished!  Output ptseries:\n    $BIN_PTSERIES"
echo -e "\n  Finished!  Output ptseries:\n    $CLUST_PTSERIES"