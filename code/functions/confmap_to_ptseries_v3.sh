#!/usr/bin/env bash
#
# confmap_to_ptseries_v3.sh
# ---------------------------------------------------------------------------
# Builds whole-brain and/or cortex-only, clusters them,
# then parcellates a dtseries -> ptseries for each family.
#
# Requires: wb_command 1.5
# ---------------------------------------------------------------------------

set -euo pipefail

print_help () {
cat <<EOF
USAGE:
  $(basename "$0") --confmap F.dscalar.nii --dtseries F.dtseries.nii           \\
                   --left_surf F_L.surf.gii --right_surf F_R.surf.gii          \\
                   [--thr 0.8] [--min_thr 0.1] [--min_area 100]               \\
                   [--outdir DIR] [--label_base NAME]                         \\
                   [--region wb|ctx|all]
EOF
}

THR=0.8; MIN_THR=0.1; MIN_AREA=100; OUTDIR=""; LABEL_BASE="Clusters"
REGION_FLAG="all"

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
    --region)     REGION_FLAG=$2; shift 2;;
    --help|-h)    print_help; exit 0;;
    *) echo "Unknown option $1"; exit 1;;
  esac
done

for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
  [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} required"; exit 1; }
done

case "$REGION_FLAG" in
  all|wb|ctx) ;;
  *) echo "ERROR: --region must be one of: all, wb, ctx (got '$REGION_FLAG')"; exit 1;;
esac

[[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
mkdir -p "$OUTDIR"

# Track which DSCs we should label/parcellate
DSC_LIST=()

# -------- 1. whole-brain mask & clusters ----------
if [[ "$REGION_FLAG" == "all" || "$REGION_FLAG" == "wb" ]]; then
  WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-thr${THR}.dscalar.nii"
  wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"
  DSC_LIST+=( "$WB_BIN_DSC" )

  WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-thr${THR}.dscalar.nii"
  wb_command -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
              "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
              -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"
  DSC_LIST+=( "$WB_CLUST_DSC" )
fi

# -------- 2. cortex-only mask & clusters ----------
# We can only derive CTX from WB_BIN_DSC, so if user asked ctx-only, we still
# need WB_BIN_DSC computed as an intermediate. We'll compute it but not output
# wb clusters unless requested.
if [[ "$REGION_FLAG" == "ctx" ]]; then
  WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-thr${THR}.dscalar.nii"
  if [[ ! -f "$WB_BIN_DSC" ]]; then
    wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"
  fi
fi

if [[ "$REGION_FLAG" == "all" || "$REGION_FLAG" == "ctx" ]]; then
  LEFT_GII="${OUTDIR}/tmp_left.func.gii"
  RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
  wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
  wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

  LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
  RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
  wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
  wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

  CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-thr${THR}.dscalar.nii"
  wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
              -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI"
  DSC_LIST+=( "$CTX_BIN_DSC" )

  CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-thr${THR}.dscalar.nii"
  wb_command -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
              "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
              -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"
  DSC_LIST+=( "$CTX_CLUST_DSC" )

  rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI"
fi

# -------- 3. label-import & ptseries ----------
for DSC in "${DSC_LIST[@]}"; do
  base=${DSC%.dscalar.nii}
  LAB="${base}.dlabel.nii"
  PTS="${base}.ptseries.nii"

  wb_command -cifti-label-import "$DSC" /dev/null "$LAB"
  wb_command -cifti-parcellate     "$DTSERIES" "$LAB" COLUMN "$PTS"
done

echo "Finished. Outputs written to $OUTDIR (region=$REGION_FLAG)"

# #!/usr/bin/env bash
# #
# # confmap_to_ptseries_v3.sh
# # ---------------------------------------------------------------------------
# # Builds whole-brain, cortex-only, clusters them,
# # then parcellates a dtseries  ptseries for each family.
# #
# # Requires: wb_command e 1.5
# # ---------------------------------------------------------------------------

# set -euo pipefail
# #  0. argument parsing
# print_help () {
# cat <<EOF
# USAGE:
#   $(basename "$0") --confmap F.dscalar.nii --dtseries F.dtseries.nii           \\
#                    --left_surf F_L.surf.gii --right_surf F_R.surf.gii          \\
#                    [--thr 0.8] [--min_thr 0.1] [--min_area 100]               \\
#                    [--outdir DIR] [--label_base NAME]
# EOF
# }
# # -------- arguments ----------

# THR=0.8; MIN_THR=0.1; MIN_AREA=100; OUTDIR=""; LABEL_BASE="Clusters"
# while [[ $# -gt 0 ]]; do
#   case "$1" in
#     --confmap)    CONFMAP=$2; shift 2;;
#     --dtseries)   DTSERIES=$2; shift 2;;
#     --left_surf)  LEFT_SURF=$2; shift 2;;
#     --right_surf) RIGHT_SURF=$2; shift 2;;
#     --thr)        THR=$2; shift 2;;
#     --min_thr)    MIN_THR=$2; shift 2;;
#     --min_area)   MIN_AREA=$2; shift 2;;
#     --outdir)     OUTDIR=$2; shift 2;;
#     --label_base) LABEL_BASE=$2; shift 2;;
#     *) echo "Unknown option $1"; exit 1;;
#   esac
# done
# for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
#   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} required"; exit 1; }
# done
# [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# mkdir -p "$OUTDIR"

# # -------- 1. whole-brain mask & clusters ----------
# WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-thr${THR}.dscalar.nii"
# wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"

# WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-thr${THR}.dscalar.nii"
# wb_command -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # -------- 2. cortex-only mask & clusters ----------
# LEFT_GII="${OUTDIR}/tmp_left.func.gii"
# RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
# wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

# LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
# RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
# wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
# wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-thr${THR}.dscalar.nii"
# wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
#             -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI"

# CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-thr${THR}.dscalar.nii"
# wb_command -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
#             "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
#             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # -------- 3. label-import & ptseries ----------

# for DSC in "$WB_BIN_DSC" "$WB_CLUST_DSC" "$CTX_BIN_DSC" "$CTX_CLUST_DSC"; do
#   base=${DSC%.dscalar.nii}          # strip full suffix
#   LAB="${base}.dlabel.nii"          # dot before extension
#   PTS="${base}.ptseries.nii"

#   wb_command -cifti-label-import "$DSC" /dev/null "$LAB"
#   wb_command -cifti-parcellate     "$DTSERIES" "$LAB" COLUMN "$PTS"
# done
# # cleanup
# rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI"
# echo " cortex-only and whole-brain outputs written to $OUTDIR"

# # #!/usr/bin/env bash
# # #
# # # confmap_to_ptseries_v3.sh
# # # ---------------------------------------------------------------------------
# # # Builds whole-brain, cortex-only and sub-cortex masks, clusters them,
# # # then parcellates a dtseries  ptseries for each family.
# # #
# # # Requires: wb_command e 1.5
# # # ---------------------------------------------------------------------------

# # set -euo pipefail

# # #  0. argument parsing 
# # print_help () {
# # cat <<EOF
# # USAGE:
# #   $(basename "$0") --confmap F.dscalar.nii --dtseries F.dtseries.nii           \\
# #                    --left_surf F_L.surf.gii --right_surf F_R.surf.gii          \\
# #                    [--thr 0.8] [--min_thr 0.1] [--min_area 100]               \\
# #                    [--outdir DIR] [--label_base NAME]
# # EOF
# # }

# # THR=0.8; MIN_THR=0.1; MIN_AREA=100; OUTDIR=""; LABEL_BASE="Clusters"

# # while [[ $# -gt 0 ]]; do
# #   case "$1" in
# #     --confmap)    CONFMAP=$2; shift 2;;
# #     --dtseries)   DTSERIES=$2; shift 2;;
# #     --left_surf)  LEFT_SURF=$2; shift 2;;
# #     --right_surf) RIGHT_SURF=$2; shift 2;;
# #     --thr)        THR=$2; shift 2;;
# #     --min_thr)    MIN_THR=$2; shift 2;;
# #     --min_area)   MIN_AREA=$2; shift 2;;
# #     --outdir)     OUTDIR=$2; shift 2;;
# #     --label_base) LABEL_BASE=$2; shift 2;;
# #     --help|-h)    print_help; exit 0;;
# #     *) echo "Unknown option $1"; print_help; exit 1;;
# #   esac
# # done

# # for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
# #   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} is required"; exit 1; }
# #   [[ -f "${!req}" ]]   || { echo "ERROR: file not found: ${!req}"; exit 1; }
# # done
# # command -v wb_command &>/dev/null || { echo "ERROR: wb_command not on PATH"; exit 1; }

# # [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# # mkdir -p "$OUTDIR"

# # #1. whole-brain mask & clusters
# # echo "Step 1 | Whole-brain binarise (> $THR)"
# # WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"

# # echo "Step 2 | Whole-brain clusters"
# # WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-thr${THR}.dscalar.nii"
# # wb_command -cifti-find-clusters "$WB_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
# #             "$MIN_THR" "$MIN_AREA" COLUMN "$WB_CLUST_DSC" \
# #             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # #  2. cortex-only & sub-cortex masks 
# # echo "Step 3 | Building cortex-only & sub-cortex masks"
# # LEFT_GII="${OUTDIR}/tmp_left.func.gii"
# # RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

# # LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
# # RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
# # wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
# # wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# # # -- zero-filled sub-cortex volume on WB grid (DATA volume) -----------------
# # ZERO_VOL="${OUTDIR}/tmp_zero_subc_data.nii.gz"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -volume-all "$ZERO_VOL"
# # wb_command -volume-math '0' "$ZERO_VOL" -var v "$ZERO_VOL"

# # # -- label version (LABEL volume) ------------------------------------------
# # ZERO_LAB="${OUTDIR}/tmp_zero_subc_label.nii.gz"
# # cat > "${OUTDIR}/tmp_zero_table.txt" <<EOF
# # 0 BACKGROUND 0 0 0 0
# # 1 SUBC       18 142 44 255
# # EOF
# # wb_command -volume-label-import "$ZERO_VOL" "${OUTDIR}/tmp_zero_table.txt" "$ZERO_LAB"

# # # -- cortex-only dense-scalar (padded) -------------------------------------
# # CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
# #             -left-metric "$LEFT_ROI" -right-metric "$RIGHT_ROI" \
# #             -volume "$ZERO_VOL" "$ZERO_LAB"

# # # -- sub-cortex mask = whole-brain  cortex-only ---------------------------
# # SUBC_BIN_DSC="${OUTDIR}/${LABEL_BASE}_subc_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-math "x - y" "$SUBC_BIN_DSC" \
# #            -var x "$WB_BIN_DSC" -var y "$CTX_BIN_DSC"

# # #  3. clusters for ctx & subc 
# # echo "Step 4 | Cortex-only clusters"
# # CTX_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_ctx_clust-thr${THR}.dscalar.nii"
# # wb_command -cifti-find-clusters "$CTX_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
# #             "$MIN_THR" "$MIN_AREA" COLUMN "$CTX_CLUST_DSC" \
# #             -left-surface "$LEFT_SURF" -right-surface "$RIGHT_SURF"

# # echo "Step 5 | Sub-cortex clusters"
# # SUBC_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_subc_clust-thr${THR}.dscalar.nii"
# # wb_command -cifti-find-clusters "$SUBC_BIN_DSC" "$MIN_THR" "$MIN_AREA" \
# #             "$MIN_THR" "$MIN_AREA" COLUMN "$SUBC_CLUST_DSC"

# # #  4. label-import & ptseries 
# # echo "Step 6 | dscalar  dlabel  ptseries"
# # for DSC in "$WB_BIN_DSC" "$WB_CLUST_DSC" "$CTX_BIN_DSC" "$CTX_CLUST_DSC" \
# #            "$SUBC_BIN_DSC" "$SUBC_CLUST_DSC"; do
# #   LAB="${DSC/.dscalar/_dlabel.nii}"
# #   wb_command -cifti-label-import "$DSC" /dev/null "$LAB"
# #   PTS="${LAB/.dlabel/_ptseries.nii}"
# #   wb_command -cifti-parcellate "$DTSERIES" "$LAB" COLUMN "$PTS"
# # done

# # #  5. cleanup & report 
# # rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI" \
# #       "$ZERO_VOL" "$ZERO_LAB" "${OUTDIR}/tmp_zero_table.txt"

# # echo -e "\n Finished! Key outputs:"
# # printf '  " Whole-brain : %s | %s\n' "$(basename "$WB_BIN_DSC")"   "$(basename "$WB_CLUST_DSC")"
# # printf '  " Cortex-only : %s | %s\n' "$(basename "$CTX_BIN_DSC")"  "$(basename "$CTX_CLUST_DSC")"
# # printf '  " Sub-cortex  : %s | %s\n' "$(basename "$SUBC_BIN_DSC")" "$(basename "$SUBC_CLUST_DSC")"
# # #!/usr/bin/env bash
# # #
# # #  confmap_to_ptseries_v3.sh
# # #
# # #  Outputs three parallel sets of files:
# # #    " Whole-brain     (_wb_&)
# # #    " Cortex-only     (_ctx_&)
# # #    " Sub-cortex-only (_subc_&)
# # #
# # #  Each set gets:
# # #    (a) binarised dscalar / dlabel
# # #    (b) cluster dscalar / dlabel
# # #    (c) ptseries extracted from the input dtseries
# # #
# # #  Requires: wb_command e 1.5
# # # ---------------------------------------------------------------------------

# # set -euo pipefail

# # ##############################################################################
# # #  0.  Argument parsing  (unchanged except for long-help blurb)
# # ##############################################################################
# # print_help () {
# # cat <<EOF
# # USAGE:
# #   $(basename "$0") --confmap  PATH.dscalar.nii  \\
# #                    --dtseries PATH.dtseries.nii \\
# #                    --left_surf PATH_L.surf.gii  \\
# #                    --right_surf PATH_R.surf.gii \\
# #                    [--thr 0.8]                  \\
# #                    [--min_thr 0.1]              \\
# #                    [--min_area 100]             \\
# #                    [--outdir PATH]              \\
# #                    [--label_base NAME]          \\
# #                    [--help]

# # Outputs (_wb / _ctx / _subc):
# #   *_bin-thr<THR>.{dscalar,dlabel,ptseries}.nii
# #   *_clust-thr<THR>.{dscalar,dlabel,ptseries}.nii
# # EOF
# # }

# # THR=0.8; MIN_THR=0.1; MIN_AREA=100; OUTDIR=""; LABEL_BASE="Clusters"

# # while [[ $# -gt 0 ]]; do
# #   case "$1" in
# #     --confmap)    CONFMAP=$2; shift 2;;
# #     --dtseries)   DTSERIES=$2; shift 2;;
# #     --left_surf)  LEFT_SURF=$2; shift 2;;
# #     --right_surf) RIGHT_SURF=$2; shift 2;;
# #     --thr)        THR=$2; shift 2;;
# #     --min_thr)    MIN_THR=$2; shift 2;;
# #     --min_area)   MIN_AREA=$2; shift 2;;
# #     --outdir)     OUTDIR=$2; shift 2;;
# #     --label_base) LABEL_BASE=$2; shift 2;;
# #     --help|-h)    print_help; exit 0;;
# #     *) echo "Unknown option $1"; print_help; exit 1;;
# #   esac
# # done

# # for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
# #   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} is required"; exit 1; }
# #   [[ -f "${!req}" ]]   || { echo "ERROR: file not found: ${!req}"; exit 1; }
# # done
# # command -v wb_command &>/dev/null || { echo "ERROR: wb_command not on PATH"; exit 1; }

# # [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# # mkdir -p "$OUTDIR"

# # ##############################################################################
# # #  1.  Whole-brain binarise & cluster  .......................................
# # ##############################################################################
# # echo "Step 1 | Whole-brain binarise (> ${THR})"
# # WB_BIN_DSC="${OUTDIR}/${LABEL_BASE}_wb_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-math "x > ${THR}" "$WB_BIN_DSC" -var x "$CONFMAP"

# # echo "Step 2 | Whole-brain clusters"
# # WB_CLUST_DSC="${OUTDIR}/${LABEL_BASE}_wb_clust-thr${THR}.dscalar.nii"
# # wb_command -cifti-find-clusters "$WB_BIN_DSC" \
# #             "$MIN_THR" "$MIN_AREA" "$MIN_THR" "$MIN_AREA" COLUMN \
# #             "$WB_CLUST_DSC" \
# #             -left-surface  "$LEFT_SURF" \
# #             -right-surface "$RIGHT_SURF"

# # ##############################################################################
# # #  2.  Split into cortex vs sub-cortex binarised maps  ......................
# # ##############################################################################
# # echo "Step 3 | Splitting cortex vs sub-cortex"
# # # a) Left / right cortical metrics
# # LEFT_GII="${OUTDIR}/tmp_left.func.gii"
# # RIGHT_GII="${OUTDIR}/tmp_right.func.gii"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_LEFT  "$LEFT_GII"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -metric CORTEX_RIGHT "$RIGHT_GII"

# # # b) Binarise those metrics again (1 where cortex survives)
# # LEFT_ROI="${OUTDIR}/tmp_left_roi.func.gii"
# # RIGHT_ROI="${OUTDIR}/tmp_right_roi.func.gii"
# # wb_command -metric-math 'x != 0' "$LEFT_ROI"  -var x "$LEFT_GII"
# # wb_command -metric-math 'x != 0' "$RIGHT_ROI" -var x "$RIGHT_GII"

# # # ---- NEW single step to create cortex-only dscalar with zero sub-cortex ----
# # echo "Step 3c | Building ctx_bin with zero-filled sub-cortex"
# # CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-thr${THR}.dscalar.nii"
# # ZERO_VOL="${OUTDIR}/tmp_zero_subc.nii.gz"

# # # copy the WB voxel grid then zero it
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -volume-all "$ZERO_VOL"
# # # either zero with FSL ...
# # if command -v fslmaths &>/dev/null; then
# #     fslmaths "$ZERO_VOL" -mul 0 "$ZERO_VOL"
# # # ...or purely in Workbench
# # else
# #     wb_command -volume-math '0*var' "$ZERO_VOL" -var var "$ZERO_VOL"
# # fi

# # wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
# #             -left-metric  "$LEFT_ROI" \
# #             -right-metric "$RIGHT_ROI" \
# #             -volume       "$ZERO_VOL" "$ZERO_VOL"

# # # d) Sub-cortex = whole-brain minus cortex
# # SUBC_BIN_DSC="${OUTDIR}/${LABEL_BASE}_subc_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-math "x - y" "$SUBC_BIN_DSC" \
# #            -var x "$WB_BIN_DSC" -var y "$CTX_BIN_DSC"


# # ##############################################################################
# # #  3c.  Build cortex-only dense-scalar padded with zero sub-cortex
# # ##############################################################################
# # echo "Step 3c | Building ctx_bin with zero-filled sub-cortex"

# # CTX_BIN_DSC="${OUTDIR}/${LABEL_BASE}_ctx_bin-thr${THR}.dscalar.nii"

# # # -- 1) copy WB voxel grid & zero it ----------------------------------------
# # ZERO_VOL="${OUTDIR}/tmp_zero_subc_data.nii.gz"
# # wb_command -cifti-separate "$WB_BIN_DSC" COLUMN -volume-all "$ZERO_VOL"
# # wb_command -volume-math '0*var' "$ZERO_VOL" -var var "$ZERO_VOL"   # zeros

# # # -- 2) convert to LABEL intent (Workbench needs data + label volumes) -------
# # ZERO_LAB="${OUTDIR}/tmp_zero_subc_label.nii.gz"
# # echo '0 UNKNOWN' > "${OUTDIR}/tmp_zero_table.txt"
# # wb_command -volume-label-import "$ZERO_VOL" "${OUTDIR}/tmp_zero_table.txt" "$ZERO_LAB"

# # # -- 3) assemble cortex-only dscalar with padded sub-cortex ------------------
# # wb_command -cifti-create-dense-scalar "$CTX_BIN_DSC" \
# #             -left-metric  "$LEFT_ROI" \
# #             -right-metric "$RIGHT_ROI" \
# #             -volume        "$ZERO_VOL" "$ZERO_LAB"

# # # -- 4) make sub-cortex mask = wb  cortex -----------------------------------
# # SUBC_BIN_DSC="${OUTDIR}/${LABEL_BASE}_subc_bin-thr${THR}.dscalar.nii"
# # wb_command -cifti-math "x - y" "$SUBC_BIN_DSC" \
# #            -var x "$WB_BIN_DSC" -var y "$CTX_BIN_DSC"

# # ##############################################################################
# # #  4.  Label import for every map  ..........................................
# # ##############################################################################
# # declare -A DSC2LAB=(
# #   [$WB_BIN_DSC]  ="${WB_BIN_DSC/.dscalar/_dlabel.nii}"
# #   [$WB_CLUST_DSC]="${WB_CLUST_DSC/.dscalar/_dlabel.nii}"
# #   [$CTX_BIN_DSC] ="${CTX_BIN_DSC/.dscalar/_dlabel.nii}"
# #   [$CTX_CLUST_DSC]="${CTX_CLUST_DSC/.dscalar/_dlabel.nii}"
# #   [$SUBC_BIN_DSC]="${SUBC_BIN_DSC/.dscalar/_dlabel.nii}"
# #   [$SUBC_CLUST_DSC]="${SUBC_CLUST_DSC/.dscalar/_dlabel.nii}"
# # )
# # echo "Step 6 | Converting all dscalars  dlabels"
# # for DSC in "${!DSC2LAB[@]}"; do
# #   wb_command -cifti-label-import "$DSC" /dev/null "${DSC2LAB[$DSC]}"
# # done

# # ##############################################################################
# # #  5.  Parcellate dtseries  ptseries  ......................................
# # ##############################################################################
# # echo "Step 7 | Parcellating dtseries"
# # for LAB in "${DSC2LAB[@]}"; do
# #   PTS="${LAB/_dlabel/_ptseries}"
# #   PTS="${PTS/dlabel.nii/ptseries.nii}"
# #   wb_command -cifti-parcellate "$DTSERIES" "$LAB" COLUMN "$PTS"
# # done


# # # ----------------------------------------------------
# # #  6.  Cleanup & report
# # # ----------------------------------------------------
# # rm -f "$LEFT_GII" "$RIGHT_GII" "$LEFT_ROI" "$RIGHT_ROI" "$ZERO_VOL"

# # echo -e "\n  Finished!  Key outputs:"
# # printf '  " Whole-brain : %s | %s\n' "$(basename "$WB_BIN_DSC")"   "$(basename "$WB_CLUST_DSC")"
# # printf '  " Cortex-only : %s | %s\n' "$(basename "$CTX_BIN_DSC")"  "$(basename "$CTX_CLUST_DSC")"
# # printf '  " Sub-cortex  : %s | %s\n' "$(basename "$SUBC_BIN_DSC")" "$(basename "$SUBC_CLUST_DSC")"
