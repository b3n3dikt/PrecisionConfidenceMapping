#!/usr/bin/env bash
# dscalar2ptseries.sh
# ---------------------------------------------------------------------------
# Build whole-brain and (if present) cortex-only masks & clusters, then
# parcellate dtseries to ptseries for each family.
#
# Minimal change from your working version:
#   * Detects when the cortex mask is empty and SKIPS all ctx steps.
#   * Parcellation is tolerant: warns and continues if a label has no parcels.
#
# Requires: wb_command >= 1.5
# ---------------------------------------------------------------------------

set -euo pipefail

print_help () {
cat <<EOF
USAGE:
  $(basename "$0") --dtseries F.dtseries.nii \\
                   --left_surf F_L.surf.gii --right_surf F_R.surf.gii \\
                   [--confmap F.dscalar.nii --thr 0.8 [--min_thr 0.1] [--min_area 100]] \\
                   [--confmask BIN.dscalar.nii [--mask_tag TAG] [--min_thr 0.1] [--min_area 100]] \\
                   [--outdir DIR] [--label_base NAME]

Notes:
  - Use EITHER (--confmap + --thr) OR (--confmask).
  - Output filenames use suffix:
       * thr<THR>    when --confmap/--thr are used
       * <MASK_TAG>  when --confmask is used (default: "mask")
EOF
}

# ---------- arguments ----------
THR=0.8
MIN_THR=0.1
MIN_AREA=100
OUTDIR=""
LABEL_BASE="Clusters"
CONFMAP=""
CONFMASK=""
MASK_TAG="mask"
DTSERIES=""
LEFT_SURF=""
RIGHT_SURF=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --confmap)    CONFMAP=$2; shift 2;;
    --confmask)   CONFMASK=$2; shift 2;;
    --mask_tag)   MASK_TAG=$2; shift 2;;
    --dtseries)   DTSERIES=$2; shift 2;;
    --left_surf)  LEFT_SURF=$2; shift 2;;
    --right_surf) RIGHT_SURF=$2; shift 2;;
    --thr)        THR=$2; shift 2;;
    --min_thr)    MIN_THR=$2; shift 2;;
    --min_area)   MIN_AREA=$2; shift 2;;
    --outdir)     OUTDIR=$2; shift 2;;
    --label_base) LABEL_BASE=$2; shift 2;;
    -h|--help)    print_help; exit 0;;
    *) echo "Unknown option $1"; exit 1;;
  esac
done

# Required common args
for req in DTSERIES LEFT_SURF RIGHT_SURF; do
  [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} required"; exit 1; }
done

# wb helper
wb() { command -v wb_command >/dev/null 2>&1 || { echo "ERROR: wb_command not on PATH"; exit 2; }; wb_command "$@"; }

# Mode selection and naming
if [[ -n "$CONFMASK" ]]; then
  [[ -f "$CONFMASK" ]] || { echo "ERROR: confmask not found: $CONFMASK"; exit 1; }
  SUFFIX="${MASK_TAG}"
  [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMASK")"
elif [[ -n "$CONFMAP" ]]; then
  [[ -f "$CONFMAP" ]] || { echo "ERROR: confmap not found: $CONFMAP"; exit 1; }
  SUFFIX="thr${THR}"
  [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
else
  echo "ERROR: Provide either --confmask or (--confmap and --thr)."; exit 1
fi
mkdir -p "$OUTDIR"

# ---------- 1. whole-brain mask & clusters ----------
WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-${SUFFIX}.dscalar.nii"
if [[ -n "$CONFMASK" ]]; then
  # Use provided binary mask directly
  cp -f "$CONFMASK" "$WB_BIN_DSC"
else
  wb -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"
fi

WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-${SUFFIX}.dscalar.nii"
wb -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
    "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
    -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# ---------- 2. cortex-only mask & clusters (skip if empty) ----------
LEFT_GII="${OUTDIR}/tmp_left.func.gii"
RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
wb -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
wb -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
wb -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
wb -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# Count nonzero cortex vertices; if none, skip all ctx outputs
NZ_L=$(wb -metric-stats "$LEFT_ROI"  -reduce COUNT_NONZERO)
NZ_R=$(wb -metric-stats "$RIGHT_ROI" -reduce COUNT_NONZERO)
NZ_CTX=$((NZ_L + NZ_R))

CTX_BIN_DSC=""
CTX_CLUST_DSC=""
if (( NZ_CTX == 0 )); then
  echo "WARNING: No cortical (ctx) nonzero vertices; skipping ctx outputs."
else
  CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-${SUFFIX}.dscalar.nii"
  wb -cifti-create-dense-scalar "$CTX_BIN_DSC" \
      -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI"

  CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-${SUFFIX}.dscalar.nii"
  wb -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
      "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
      -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"
fi

# ---------- 3. label-import & ptseries (tolerant to empty/none) ----------
parcellate_one () {
  local dsc="$1"
  [[ -f "$dsc" ]] || return 0  # nothing to do

  local base="${dsc%.dscalar.nii}"
  local lab="${base}.dlabel.nii"
  local pts="${base}.ptseries.nii"

  # Build a trivial label map from the scalar (same trick you were using)
  wb -cifti-label-import "$dsc" /dev/null "$lab"

  # Parcellate; tolerate "no parcels" by warning and removing the (empty) outputs
  set +e
  wb -cifti-parcellate "$DTSERIES" "$lab" COLUMN "$pts"
  rc=$?
  set -e
  if [[ $rc -ne 0 ]]; then
    echo "WARNING: parcellate failed (likely no parcels) for: $lab ; skipping."
    rm -f "$lab" "$pts" 2>/dev/null || true
  fi
}

# Whole-brain always attempted
parcellate_one "$WB_BIN_DSC"
parcellate_one "$WB_CLUST_DSC"

# Cortex-only only if we actually made them
[[ -n "$CTX_BIN_DSC"   ]] && parcellate_one "$CTX_BIN_DSC"
[[ -n "$CTX_CLUST_DSC" ]] && parcellate_one "$CTX_CLUST_DSC"

# ---------- cleanup ----------
rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI"

echo "Done. Outputs in $OUTDIR (suffix: ${SUFFIX}). Cortex outputs present: $(( NZ_CTX > 0 ))"
# #!/usr/bin/env bash
# # This one works if spots in cortex but crashes if no cortical areas cuz trying to run ctx only
# # dscalar2ptseries.sh
# # ---------------------------------------------------------------------------
# # Build whole-brain and cortex-only masks & clusters, then parcellate dtseries
# # to ptseries for each family. Can start from either:
# #   (A) confmap + --thr (legacy behavior), or
# #   (B) a precomputed binary mask via --confmask (new).
# #
# # Requires: wb_command >= 1.5
# # ---------------------------------------------------------------------------

# set -euo pipefail

# print_help () {
# cat <<EOF
# USAGE:
#   $(basename "$0") --dtseries F.dtseries.nii \\
#                    --left_surf F_L.surf.gii --right_surf F_R.surf.gii \\
#                    [--confmap F.dscalar.nii --thr 0.8 [--min_thr 0.1] [--min_area 100]] \\
#                    [--confmask BIN.dscalar.nii [--mask_tag TAG] [--min_thr 0.1] [--min_area 100]] \\
#                    [--outdir DIR] [--label_base NAME]

# Notes:
#   - Use EITHER (--confmap + --thr) OR (--confmask).
#   - Output filenames use suffix:
#        * thr<THR>    when --confmap/--thr are used
#        * <MASK_TAG>  when --confmask is used (default: "mask")
# EOF
# }

# # ---------- arguments ----------
# THR=0.8
# MIN_THR=0.1
# MIN_AREA=100
# OUTDIR=""
# LABEL_BASE="Clusters"
# CONFMAP=""
# CONFMASK=""
# MASK_TAG="mask"
# DTSERIES=""
# LEFT_SURF=""
# RIGHT_SURF=""

# while [[ $# -gt 0 ]]; do
#   case "$1" in
#     --confmap)    CONFMAP=$2; shift 2;;
#     --confmask)   CONFMASK=$2; shift 2;;
#     --mask_tag)   MASK_TAG=$2; shift 2;;
#     --dtseries)   DTSERIES=$2; shift 2;;
#     --left_surf)  LEFT_SURF=$2; shift 2;;
#     --right_surf) RIGHT_SURF=$2; shift 2;;
#     --thr)        THR=$2; shift 2;;
#     --min_thr)    MIN_THR=$2; shift 2;;
#     --min_area)   MIN_AREA=$2; shift 2;;
#     --outdir)     OUTDIR=$2; shift 2;;
#     --label_base) LABEL_BASE=$2; shift 2;;
#     -h|--help)    print_help; exit 0;;
#     *) echo "Unknown option $1"; exit 1;;
#   esac
# done

# # Required common args
# for req in DTSERIES LEFT_SURF RIGHT_SURF; do
#   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} required"; exit 1; }
# done

# # Mode selection and naming
# if [[ -n "$CONFMASK" ]]; then
#   [[ -f "$CONFMASK" ]] || { echo "ERROR: confmask not found: $CONFMASK"; exit 1; }
#   SUFFIX="${MASK_TAG}"
#   [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMASK")"
# elif [[ -n "$CONFMAP" ]]; then
#   [[ -f "$CONFMAP" ]] || { echo "ERROR: confmap not found: $CONFMAP"; exit 1; }
#   SUFFIX="thr${THR}"
#   [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# else
#   echo "ERROR: Provide either --confmask or (--confmap and --thr)."; exit 1
# fi
# mkdir -p "$OUTDIR"

# # ---------- 1. whole-brain mask & clusters ----------
# WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-${SUFFIX}.dscalar.nii"
# if [[ -n "$CONFMASK" ]]; then
#   # Use provided binary mask directly
#   cp -f "$CONFMASK" "$WB_BIN_DSC"
# else
#   wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"
# fi

# WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-${SUFFIX}.dscalar.nii"
# wb_command -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # ---------- 2. cortex-only mask & clusters ----------
# LEFT_GII="${OUTDIR}/tmp_left.func.gii"
# RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

# LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
# RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
# wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
# wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-${SUFFIX}.dscalar.nii"
# wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
#             -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI"

# CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-${SUFFIX}.dscalar.nii"
# wb_command -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # ---------- 3. label-import & ptseries ----------
# for DSC in "$WB_BIN_DSC" "$WB_CLUST_DSC" "$CTX_BIN_DSC" "$CTX_CLUST_DSC"; do
#   base=${DSC%.dscalar.nii}
#   LAB="${base}.dlabel.nii"
#   PTS="${base}.ptseries.nii"
#   wb_command -cifti-label-import "$DSC" /dev/null "$LAB"
#   wb_command -cifti-parcellate     "$DTSERIES" "$LAB" COLUMN "$PTS"
# done

# # cleanup
# rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI"
# echo "Outputs written to $OUTDIR (suffix: ${SUFFIX})"

# #Above mostly works, just fails if no info in ctx

#!/usr/bin/env bash
# # dscalar2ptseries.sh
# # Build {wb,ctx} x {bin,clust} dlabel/dscalar + ptseries from a seed mask.
# # Tolerant: if ctx has no parcels, skip ctx outputs with a warning.

# set -euo pipefail

# echo "dscalar2ptseries.sh SAFE-SKIP ctx build v3"

# # --- args ---
# CONFMASK="" MASK_TAG="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters"

# argv=("$@")
# i=0
# while (( i < ${#argv[@]} )); do
#   case "${argv[i]}" in
#     --confmask)   CONFMASK="${argv[i+1]}";   ((i+=2)); continue;;
#     --mask_tag)   MASK_TAG="${argv[i+1]}";   ((i+=2)); continue;;
#     --dtseries)   DTSERIES="${argv[i+1]}";   ((i+=2)); continue;;
#     --left_surf)  LEFT_SURF="${argv[i+1]}";  ((i+=2)); continue;;
#     --right_surf) RIGHT_SURF="${argv[i+1]}"; ((i+=2)); continue;;
#     --outdir)     OUTDIR="${argv[i+1]}";     ((i+=2)); continue;;
#     --label_base) LABEL_BASE="${argv[i+1]}"; ((i+=2)); continue;;
#     -h|--help)
#       cat <<'USAGE'
# Usage:
#   dscalar2ptseries.sh --confmask MASK.dscalar.nii --mask_tag TAG \
#     --dtseries X.dtseries.nii --left_surf L.surf.gii --right_surf R.surf.gii \
#     --outdir OUT --label_base NAME
# USAGE
#       exit 0;;
#     *) echo "ERROR: unknown arg '${argv[i]}'"; exit 1;;
#   esac
# done

# for v in CONFMASK MASK_TAG DTSERIES LEFT_SURF RIGHT_SURF OUTDIR LABEL_BASE; do
#   [[ -n "${!v}" ]] || { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -f "$CONFMASK"  ]] || { echo "ERROR: confmask not found: $CONFMASK"; exit 1; }
# [[ -f "$DTSERIES"  ]] || { echo "ERROR: dtseries not found: $DTSERIES"; exit 1; }
# [[ -f "$LEFT_SURF" ]] || { echo "ERROR: left_surf not found: $LEFT_SURF"; exit 1; }
# [[ -f "$RIGHT_SURF" ]] || { echo "ERROR: right_surf not found: $RIGHT_SURF"; exit 1; }
# [[ -d "$OUTDIR"    ]] || { echo "ERROR: outdir not found: $OUTDIR"; exit 1; }

# wb() { command -v wb_command >/dev/null 2>&1 || { echo "ERROR: wb_command not on PATH"; exit 2; }; wb_command "$@"; }

# # Output stems
# WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.dscalar.nii"
# WB_BIN_LAB="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.dlabel.nii"
# WB_BIN_PTS="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.ptseries.nii"

# WB_CLU_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.dscalar.nii"
# WB_CLU_LAB="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.dlabel.nii"
# WB_CLU_PTS="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.ptseries.nii"

# CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.dscalar.nii"
# CTX_BIN_LAB="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.dlabel.nii"
# CTX_BIN_PTS="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.ptseries.nii"

# CTX_CLU_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.dscalar.nii"
# CTX_CLU_LAB="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.dlabel.nii"
# CTX_CLU_PTS="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.ptseries.nii"

# # thresholds for binary masks (x!=0)
# SURF_THR=0.5
# SURF_MINAREA=0
# VOL_THR=0.5
# VOL_MINSIZE=0

# # 1) Whole-brain binary + clusters
# wb -cifti-math 'x != 0' "$WB_BIN_DSC" -var x "$CONFMASK"

# wb -cifti-find-clusters "$WB_BIN_DSC" \
#   $SURF_THR $SURF_MINAREA $VOL_THR $VOL_MINSIZE \
#   COLUMN "$WB_CLU_DSC" \
#   -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# wb -cifti-create-label "$WB_BIN_LAB" -cifti "$WB_BIN_DSC"
# wb -cifti-create-label "$WB_CLU_LAB" -cifti "$WB_CLU_DSC"

# wb -cifti-parcellate "$DTSERIES" "$WB_BIN_LAB" COLUMN "$WB_BIN_PTS"
# wb -cifti-parcellate "$DTSERIES" "$WB_CLU_LAB" COLUMN "$WB_CLU_PTS"

# # 2) Cortex-only; skip gracefully if empty
# TMP_L="$OUTDIR/_tmp_${LABEL_BASE}_${MASK_TAG}_L.func.gii"
# TMP_R="$OUTDIR/_tmp_${LABEL_BASE}_${MASK_TAG}_R.func.gii"
# trap 'rm -f "$TMP_L" "$TMP_R"' EXIT

# wb -cifti-separate "$WB_BIN_DSC" COLUMN \
#    -metric CORTEX_LEFT  "$TMP_L" \
#    -metric CORTEX_RIGHT "$TMP_R"

# NZ_L=$(wb -metric-stats "$TMP_L" -reduce COUNT_NONZERO)
# NZ_R=$(wb -metric-stats "$TMP_R" -reduce COUNT_NONZERO)
# NZ_CTX=$((NZ_L + NZ_R))

# CTX_OK=0
# if (( NZ_CTX == 0 )); then
#   echo "WARNING: No cortical (ctx) nonzero vertices; skipping ctx outputs."
# else
#   wb -cifti-create-dense-scalar "$CTX_BIN_DSC" \
#      -left-metric "$TMP_L" -right-metric "$TMP_R" \
#      -cifti-template "$WB_BIN_DSC"

#   wb -cifti-find-clusters "$CTX_BIN_DSC" \
#     $SURF_THR $SURF_MINAREA $VOL_THR $VOL_MINSIZE \
#     COLUMN "$CTX_CLU_DSC" \
#     -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

#   wb -cifti-create-label "$CTX_BIN_LAB" -cifti "$CTX_BIN_DSC"
#   wb -cifti-create-label "$CTX_CLU_LAB" -cifti "$CTX_CLU_DSC"

#   set +e
#   wb -cifti-parcellate "$DTSERIES" "$CTX_BIN_LAB" COLUMN "$CTX_BIN_PTS"; rc1=$?
#   wb -cifti-parcellate "$DTSERIES" "$CTX_CLU_LAB" COLUMN "$CTX_CLU_PTS"; rc2=$?
#   set -e

#   if [[ $rc1 -ne 0 || $rc2 -ne 0 ]]; then
#     echo "WARNING: ctx parcellation had no parcels / failed; skipping ctx outputs."
#     CTX_OK=0
#     rm -f "$CTX_BIN_DSC" "$CTX_BIN_LAB" "$CTX_BIN_PTS" "$CTX_CLU_DSC" "$CTX_CLU_LAB" "$CTX_CLU_PTS" 2>/dev/null || true
#   else
#     CTX_OK=1
#   fi
# fi

# echo "ptseries built. wb always present; ctx present: $CTX_OK"
# #!/usr/bin/env bash
# # dscalar2ptseries.sh
# # Build {wb,ctx} x {bin,clust} dlabel/dscalar + ptseries from a seed mask.
# # Now tolerant: if ctx has no parcels, skip ctx outputs with a warning.

# set -euo pipefail

# # --- args ---
# CONFMASK="" MASK_TAG="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters"

# argv=("$@")
# for ((i=0; i<${#argv[@]}; i++)); do
#   case "${argv[$i]}" in
#     --confmask)   CONFMASK="${argv[$((i+1))]}"; ((++i));;
#     --mask_tag)   MASK_TAG="${argv[$((i+1))]}"; ((++i));;
#     --dtseries)   DTSERIES="${argv[$((i+1))]}"; ((++i));;
#     --left_surf)  LEFT_SURF="${argv[$((i+1))]}"; ((++i));;
#     --right_surf) RIGHT_SURF="${argv[$((i+1))]}"; ((++i));;
#     --outdir)     OUTDIR="${argv[$((i+1))]}";   ((++i));;
#     --label_base) LABEL_BASE="${argv[$((i+1))]}"; ((++i));;
#     -h|--help)
#       cat <<USAGE
# Usage:
#   dscalar2ptseries.sh --confmask MASK.dscalar.nii --mask_tag TAG \\
#       --dtseries X.dtseries.nii --left_surf L.surf.gii --right_surf R.surf.gii \\
#       --outdir OUT --label_base NAME
# USAGE
#       exit 0;;
#   esac
# done

# for v in CONFMASK MASK_TAG DTSERIES LEFT_SURF RIGHT_SURF OUTDIR LABEL_BASE; do
#   [[ -n "${!v}" ]] || { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -f "$CONFMASK"  ]] || { echo "ERROR: confmask not found: $CONFMASK"; exit 1; }
# [[ -f "$DTSERIES"  ]] || { echo "ERROR: dtseries not found: $DTSERIES"; exit 1; }
# [[ -f "$LEFT_SURF" ]] || { echo "ERROR: left_surf not found: $LEFT_SURF"; exit 1; }
# [[ -f "$RIGHT_SURF"]] || { echo "ERROR: right_surf not found: $RIGHT_SURF"; exit 1; }
# [[ -d "$OUTDIR"    ]] || { echo "ERROR: outdir not found: $OUTDIR"; exit 1; }

# # --- helpers ---
# wb() { command -v wb_command >/dev/null 2>&1 || { echo "ERROR: wb_command not on PATH"; exit 2; }; wb_command "$@"; }

# # Output stems
# WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.dscalar.nii"
# WB_BIN_LAB="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.dlabel.nii"
# WB_BIN_PTS="${OUTDIR}/${LABEL_BASE}_wb_bin-${MASK_TAG}.ptseries.nii"

# WB_CLU_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.dscalar.nii"
# WB_CLU_LAB="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.dlabel.nii"
# WB_CLU_PTS="${OUTDIR}/${LABEL_BASE}_wb_clust-${MASK_TAG}.ptseries.nii"

# CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.dscalar.nii"
# CTX_BIN_LAB="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.dlabel.nii"
# CTX_BIN_PTS="${OUTDIR}/${LABEL_BASE}_ctx_bin-${MASK_TAG}.ptseries.nii"

# CTX_CLU_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.dscalar.nii"
# CTX_CLU_LAB="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.dlabel.nii"
# CTX_CLU_PTS="${OUTDIR}/${LABEL_BASE}_ctx_clust-${MASK_TAG}.ptseries.nii"

# # --- 1) Split mask into wb and cortex-only views ---
# # Binary mask (nonzero)
# wb -cifti-math 'x != 0' "$WB_BIN_DSC" -var x "$CONFMASK"
# # Cortex-only binary mask
# TMP_L="$OUTDIR/_tmp_${LABEL_BASE}_${MASK_TAG}_L.func.gii"
# TMP_R="$OUTDIR/_tmp_${LABEL_BASE}_${MASK_TAG}_R.func.gii"
# trap 'rm -f "$TMP_L" "$TMP_R"' EXIT

# wb -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$TMP_L" \
#                                  -metric CORTEX_RIGHT "$TMP_R"
# # Count nonzero vertices in cortex
# NZ_L=$(wb -metric-stats "$TMP_L" -reduce COUNT_NONZERO)
# NZ_R=$(wb -metric-stats "$TMP_R" -reduce COUNT_NONZERO)
# NZ_CTX=$((NZ_L + NZ_R))

# # --- 2) Cluster (whole-brain & ctx) and convert to dlabel ---
# # Whole-brain cluster map (connected components on WB_BIN_DSC)
# wb -cifti-find-clusters "$WB_BIN_DSC" 1 1 "$WB_CLU_DSC"
# wb -cifti-create-label "$WB_CLU_LAB" -cifti "$WB_CLU_DSC"

# # Cortex-only artifacts (only if NZ_CTX>0)
# CTX_OK=0
# if (( NZ_CTX > 0 )); then
#   wb -cifti-math 'x' "$CTX_BIN_DSC" -var x "$WB_BIN_DSC" -cifti-resample "$WB_BIN_DSC" CORTEX
#   # CTX cluster map (zero out subcortex by masking with cortex metrics)
#   wb -cifti-find-clusters "$CTX_BIN_DSC" 1 1 "$CTX_CLU_DSC"
#   wb -cifti-create-label "$CTX_CLU_LAB" -cifti "$CTX_CLU_DSC"
#   CTX_OK=1
# else
#   echo "WARNING: No cortical (ctx) parcels found in mask; skipping ctx outputs."
# fi

# # --- 3) ptseries via parcellate (skip ctx if empty) ---
# # wb bin
# wb -cifti-create-label "$WB_BIN_LAB" -cifti "$WB_BIN_DSC"
# wb -cifti-parcellate "$DTSERIES" "$WB_BIN_LAB" COLUMN "$WB_BIN_PTS"
# # wb clust
# wb -cifti-parcellate "$DTSERIES" "$WB_CLU_LAB" COLUMN "$WB_CLU_PTS"

# # ctx bin/clust (only if CTX_OK)
# if (( CTX_OK == 1 )); then
#   wb -cifti-create-label "$CTX_BIN_LAB" -cifti "$CTX_BIN_DSC"
#   wb -cifti-parcellate "$DTSERIES" "$CTX_BIN_LAB"  COLUMN "$CTX_BIN_PTS"
#   wb -cifti-parcellate "$DTSERIES" "$CTX_CLU_LAB"  COLUMN "$CTX_CLU_PTS"
# fi

# echo "ptseries built. wb always present; ctx present: $CTX_OK"


# ##!/usr/bin/env bash
# #
# # dscalar2ptseries.sh
# # ---------------------------------------------------------------------------
# # Build whole-brain and cortex-only masks & clusters, then parcellate dtseries
# # to ptseries for each family. Can start from either:
# #   (A) confmap + --thr (legacy behavior), or
# #   (B) a precomputed binary mask via --confmask (new).
# #
# # Requires: wb_command >= 1.5
# # ---------------------------------------------------------------------------

# set -euo pipefail

# print_help () {
# cat <<EOF
# USAGE:
#   $(basename "$0") --dtseries F.dtseries.nii \\
#                    --left_surf F_L.surf.gii --right_surf F_R.surf.gii \\
#                    [--confmap F.dscalar.nii --thr 0.8 [--min_thr 0.1] [--min_area 100]] \\
#                    [--confmask BIN.dscalar.nii [--mask_tag TAG] [--min_thr 0.1] [--min_area 100]] \\
#                    [--outdir DIR] [--label_base NAME]

# Notes:
#   - Use EITHER (--confmap + --thr) OR (--confmask).
#   - Output filenames use suffix:
#        * thr<THR>    when --confmap/--thr are used
#        * <MASK_TAG>  when --confmask is used (default: "mask")
# EOF
# }

# # ---------- arguments ----------
# THR=0.8
# MIN_THR=0.1
# MIN_AREA=100
# OUTDIR=""
# LABEL_BASE="Clusters"
# CONFMAP=""
# CONFMASK=""
# MASK_TAG="mask"
# DTSERIES=""
# LEFT_SURF=""
# RIGHT_SURF=""

# while [[ $# -gt 0 ]]; do
#   case "$1" in
#     --confmap)    CONFMAP=$2; shift 2;;
#     --confmask)   CONFMASK=$2; shift 2;;
#     --mask_tag)   MASK_TAG=$2; shift 2;;
#     --dtseries)   DTSERIES=$2; shift 2;;
#     --left_surf)  LEFT_SURF=$2; shift 2;;
#     --right_surf) RIGHT_SURF=$2; shift 2;;
#     --thr)        THR=$2; shift 2;;
#     --min_thr)    MIN_THR=$2; shift 2;;
#     --min_area)   MIN_AREA=$2; shift 2;;
#     --outdir)     OUTDIR=$2; shift 2;;
#     --label_base) LABEL_BASE=$2; shift 2;;
#     -h|--help)    print_help; exit 0;;
#     *) echo "Unknown option $1"; exit 1;;
#   esac
# done

# # Required common args
# for req in DTSERIES LEFT_SURF RIGHT_SURF; do
#   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} required"; exit 1; }
# done

# # Mode selection and naming
# if [[ -n "$CONFMASK" ]]; then
#   [[ -f "$CONFMASK" ]] || { echo "ERROR: confmask not found: $CONFMASK"; exit 1; }
#   SUFFIX="${MASK_TAG}"
#   [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMASK")"
# elif [[ -n "$CONFMAP" ]]; then
#   [[ -f "$CONFMAP" ]] || { echo "ERROR: confmap not found: $CONFMAP"; exit 1; }
#   SUFFIX="thr${THR}"
#   [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# else
#   echo "ERROR: Provide either --confmask or (--confmap and --thr)."; exit 1
# fi
# mkdir -p "$OUTDIR"

# # ---------- 1. whole-brain mask & clusters ----------
# WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-${SUFFIX}.dscalar.nii"
# if [[ -n "$CONFMASK" ]]; then
#   # Use provided binary mask directly
#   cp -f "$CONFMASK" "$WB_BIN_DSC"
# else
#   wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"
# fi

# WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-${SUFFIX}.dscalar.nii"
# wb_command -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # ---------- 2. cortex-only mask & clusters ----------
# LEFT_GII="${OUTDIR}/tmp_left.func.gii"
# RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

# LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
# RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
# wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
# wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-${SUFFIX}.dscalar.nii"
# wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
#             -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI"

# CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-${SUFFIX}.dscalar.nii"
# wb_command -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # ---------- 3. label-import & ptseries ----------
# for DSC in "$WB_BIN_DSC" "$WB_CLUST_DSC" "$CTX_BIN_DSC" "$CTX_CLUST_DSC"; do
#   base=${DSC%.dscalar.nii}
#   LAB="${base}.dlabel.nii"
#   PTS="${base}.ptseries.nii"
#   wb_command -cifti-label-import "$DSC" /dev/null "$LAB"
#   wb_command -cifti-parcellate     "$DTSERIES" "$LAB" COLUMN "$PTS"
# done

# # cleanup
# rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI"
# echo "Outputs written to $OUTDIR (suffix: ${SUFFIX})"