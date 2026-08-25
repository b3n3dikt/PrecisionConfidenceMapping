#!/usr/bin/env bash
# dscalar2seed.sh
# Build a binary seed mask from a dscalar (thr/percent/range),
# run dscalar2ptseries.sh, then write helper .conc files.
# Tolerant: if ctx files are absent, warn and continue with wb.

set -euo pipefail
set -x
trap 'echo "ERROR in dscalar2seed.sh at line $LINENO"; exit 1' ERR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -------- argument parsing --------
DSCALAR="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
OUTDIR="" LABEL_BASE="Clusters" THR=""
MOTION_CONC="" REGION_FLAG="all"

MODE="" WHICH="" PERCENT="" RANGE_STR="" MASK_TAG=""

argv=("$@")
i=0
while (( i < ${#argv[@]} )); do
  case "${argv[i]}" in
    --dscalar|--confmap) DSCALAR="${argv[i+1]}"; ((i+=2)); continue;;
    --dtseries)          DTSERIES="${argv[i+1]}"; ((i+=2)); continue;;
    --left_surf)         LEFT_SURF="${argv[i+1]}"; ((i+=2)); continue;;
    --right_surf)        RIGHT_SURF="${argv[i+1]}"; ((i+=2)); continue;;
    --outdir)            OUTDIR="${argv[i+1]}"; ((i+=2)); continue;;
    --label_base)        LABEL_BASE="${argv[i+1]}"; ((i+=2)); continue;;
    --thr)               THR="${argv[i+1]}"; ((i+=2)); continue;;
    --motion_conc)       MOTION_CONC="${argv[i+1]}"; ((i+=2)); continue;;
    --region)            REGION_FLAG="${argv[i+1]}"; ((i+=2)); continue;;
    --mode)              MODE="${argv[i+1]}"; ((i+=2)); continue;;
    --which)             WHICH="${argv[i+1]}"; ((i+=2)); continue;;
    --percent)           PERCENT="${argv[i+1]}"; ((i+=2)); continue;;
    --range)             RANGE_STR="${argv[i+1]}"; ((i+=2)); continue;;
    --mask_tag)          MASK_TAG="${argv[i+1]}"; ((i+=2)); continue;;
    -h|--help)
      cat <<'USAGE'
Usage:
  dscalar2seed.sh --confmap X.dscalar.nii --dtseries Y.dtseries.nii \
    --left_surf L.surf.gii --right_surf R.surf.gii \
    --outdir OUT --label_base NAME [--mode percent|thr|range ...]
USAGE
      exit 0;;
    *) echo "ERROR: unknown arg '${argv[i]}'"; exit 1;;
  esac
done

echo "dscalar2seed.sh: inputs:"
echo "  dscalar:    $DSCALAR"
echo "  dtseries:   $DTSERIES"
echo "  left_surf:  $LEFT_SURF"
echo "  right_surf: $RIGHT_SURF"
echo "  outdir:     $OUTDIR"
echo "  label_base: $LABEL_BASE"
echo "  mode:       $MODE"
echo "  which:      $WHICH"
echo "  percent:    $PERCENT"
echo "  range:      $RANGE_STR"
echo "  mask_tag:   $MASK_TAG"

# -------- preflight --------
for v in DSCALAR DTSERIES LEFT_SURF RIGHT_SURF OUTDIR; do
  [[ -n "${!v}" ]] || { echo "ERROR: --${v,,} is required"; exit 1; }
done
[[ -f "$DSCALAR"    ]] || { echo "ERROR: dscalar not found: $DSCALAR"; exit 1; }
[[ -f "$DTSERIES"   ]] || { echo "ERROR: dtseries not found: $DTSERIES"; exit 1; }
[[ -f "$LEFT_SURF"  ]] || { echo "ERROR: left_surf not found: $LEFT_SURF"; exit 1; }
[[ -f "$RIGHT_SURF" ]] || { echo "ERROR: right_surf not found: $RIGHT_SURF"; exit 1; }
[[ -d "$OUTDIR"     ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }
[[ -w "$OUTDIR"     ]] || { echo "ERROR: outdir not writable: $OUTDIR"; exit 1; }

ADV="${SCRIPT_DIR}/dscalar2seed_advanced.sh"
PT="${SCRIPT_DIR}/dscalar2ptseries.sh"
[[ -x "$ADV" ]] || { echo "ERROR: missing executable: $ADV"; exit 1; }
[[ -x "$PT"  ]] || { echo "ERROR: missing executable: $PT"; exit 1; }

# -------- region selection --------
if [[ "$REGION_FLAG" == "all" ]]; then
  REGIONS=(wb ctx)
else
  REGIONS=("$REGION_FLAG")
fi
echo "Regions: ${REGIONS[*]}"

# -------- 1) Build mask (thr/percent/range) --------
SEED_MASK="${OUTDIR}/${LABEL_BASE}_seed_mask.dscalar.nii"
TAG=""

echo "Seed mask will be: $SEED_MASK"
if [[ -n "$MODE" ]]; then
  case "$MODE" in
    percent)
      [[ -n "$WHICH" && -n "$PERCENT" ]] || { echo "ERROR: --which and --percent required for --mode percent"; exit 1; }
      [[ -n "$MASK_TAG" ]] || MASK_TAG="perc-${WHICH}${PERCENT}"
      TAG="$MASK_TAG"
      "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
             --mode percent --which "$WHICH" --percent "$PERCENT"
      ;;
    range)
      [[ -n "$RANGE_STR" ]] || { echo "ERROR: --range low,high required for --mode range"; exit 1; }
      if [[ -z "$MASK_TAG" ]]; then
        lo="${RANGE_STR%%,*}"; hi="${RANGE_STR##*,}"
        MASK_TAG="range-${lo}_${hi}"
      fi
      TAG="$MASK_TAG"
      "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
             --mode range --range "$RANGE_STR"
      ;;
    thr)
      [[ -n "$THR" ]] || { echo "ERROR: --thr required for --mode thr"; exit 1; }
      TAG="thr${THR}"
      "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
             --mode thr --thr "$THR"
      ;;
    *)
      echo "ERROR: unknown --mode '$MODE' (use thr|percent|range)"; exit 1;;
  esac
else
  [[ -n "$THR" ]] || { echo "ERROR: either --thr or --mode is required"; exit 1; }
  TAG="thr${THR}"
  "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
         --mode thr --thr "$THR"
fi
echo "Mask tag: $TAG"
[[ -f "$SEED_MASK" ]] || { echo "ERROR: expected mask not created: $SEED_MASK"; exit 1; }

# -------- 2) Build ptseries (mask mode; tolerant to missing ctx) --------
echo "Running PT (mask->ptseries) ..."
set +e
"$PT" \
  --confmask  "$SEED_MASK" \
  --mask_tag  "$TAG" \
  --dtseries  "$DTSERIES" \
  --left_surf "$LEFT_SURF" \
  --right_surf "$RIGHT_SURF" \
  --outdir    "$OUTDIR" \
  --label_base "$LABEL_BASE"
ec=$?
set -e
if [[ $ec -ne 0 ]]; then
  echo "ERROR: dscalar2ptseries.sh returned non-zero ($ec)"; exit $ec
fi

# -------- 3) Helper .conc files (tolerant) --------
for region in "${REGIONS[@]}"; do
  CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
  BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"

  if [[ ! -f "$CLUST_PTSERIES" || ! -f "$BIN_PTSERIES" ]]; then
    echo "WARNING: Skipping ${region} .conc creation; expected ptseries missing (likely no parcels)."
    continue
  fi

  echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
  echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"
done

# If only one region produced concs, also write generic names
if [[ -f "${OUTDIR}/clust_pt_wb.conc" && ! -f "${OUTDIR}/clust_pt_ctx.conc" ]]; then
  cp -f "${OUTDIR}/clust_pt_wb.conc"  "${OUTDIR}/clust_pt.conc"  || true
  cp -f "${OUTDIR}/bin_pt_wb.conc"    "${OUTDIR}/bin_pt.conc"    || true
fi

# Always-needed helper concs
echo "$DTSERIES" > "${OUTDIR}/dt.conc"
[[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"
[[ -n "$LEFT_SURF"  ]] && echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
[[ -n "$RIGHT_SURF" ]] && echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"

# ## This is the oldest version I can find that sorta worked but gives me the -cifti error; 
# #!/usr/bin/env bash
# # dscalar2seed.sh
# # Wrapper to (a) build a binary seed mask using either thr/percent/range
# # and (b) run dscalar2ptseries.sh to produce *_bin-<tag>.ptseries.nii
# # and *_clust-<tag>.ptseries.nii, then write helper .conc files.
# #
# # Requires:
# #   - wb_command
# #   - dscalar2seed_advanced.sh (same directory)
# #   - dscalar2ptseries.sh (updated version)

# set -euo pipefail
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# # -------- argument parsing (kept close to your old flags) --------
# CONFMAP="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters" THR=""
# MOTION_CONC="" REGION_FLAG="all"

# # new optional selection controls
# MODE="" WHICH="" PERCENT="" RANGE_STR="" MASK_TAG=""

# argv=("$@")
# for ((i=0; i<${#argv[@]}; i++)); do
#   case "${argv[$i]}" in
#     --confmap)    CONFMAP="${argv[$((i+1))]}"; ((i+=1));;
#     --dtseries)   DTSERIES="${argv[$((i+1))]}"; ((i+=1));;
#     --left_surf)  LEFT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --right_surf) RIGHT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --outdir)     OUTDIR="${argv[$((i+1))]}";   ((i+=1));;
#     --label_base) LABEL_BASE="${argv[$((i+1))]}"; ((i+=1));;
#     --thr)        THR="${argv[$((i+1))]}";      ((i+=1));;
#     --motion_conc) MOTION_CONC="${argv[$((i+1))]}"; ((i+=1));;
#     --region)     REGION_FLAG="${argv[$((i+1))]}"; ((i+=1));;
#     # new:
#     --mode)       MODE="${argv[$((i+1))]}"; ((i+=1));;
#     --which)      WHICH="${argv[$((i+1))]}"; ((i+=1));;
#     --percent)    PERCENT="${argv[$((i+1))]}"; ((i+=1));;
#     --range)      RANGE_STR="${argv[$((i+1))]}"; ((i+=1));;
#     --mask_tag)   MASK_TAG="${argv[$((i+1))]}"; ((i+=1));;
#     -h|--help)
#       cat <<'USAGE'
# Usage:
#   # Legacy threshold (unchanged behavior):
#   dscalar2seed.sh --confmap F.dscalar.nii --dtseries F.dtseries.nii \
#       --left_surf L.surf.gii --right_surf R.surf.gii \
#       --thr 0.6 --outdir OUT --label_base NAME [--region wb|ctx|all] \
#       --motion_conc motion.conc

#   # New: percentile
#   dscalar2seed.sh ... --mode percent --which top --percent 10 --mask_tag perc-top10

#   # New: range
#   dscalar2seed.sh ... --mode range --range 0,0.1 --mask_tag range-0.0_0.1
# USAGE
#       exit 0;;
#     *) ;;
#   esac
# done

# for v in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF OUTDIR; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -d "$OUTDIR" ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }

# # -------- region selection --------
# if [[ "$REGION_FLAG" == "all" ]]; then
#   REGIONS=(wb ctx)
# else
#   REGIONS=("$REGION_FLAG")
# fi

# # -------- 1) Build mask (or use legacy thr) --------
# SEED_MASK="${OUTDIR}/${LABEL_BASE}_seed_mask.dscalar.nii"
# TAG=""

# if [[ -n "$MODE" ]]; then
#   # Use advanced builder
#   case "$MODE" in
#     percent)
#       [[ -z "$WHICH" || -z "$PERCENT" ]] && { echo "ERROR: --which and --percent required for --mode percent"; exit 1; }
#       [[ -z "$MASK_TAG" ]] && MASK_TAG="perc-${WHICH}${PERCENT}"
#       TAG="$MASK_TAG"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode percent --which "$WHICH" --percent "$PERCENT"
#       ;;
#     range)
#       [[ -z "$RANGE_STR" ]] && { echo "ERROR: --range low,high required for --mode range"; exit 1; }
#       if [[ -z "$MASK_TAG" ]]; then
#         lo="${RANGE_STR%%,*}"; hi="${RANGE_STR##*,}"
#         MASK_TAG="range-${lo}_${hi}"
#       fi
#       TAG="$MASK_TAG"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode range --range "$RANGE_STR"
#       ;;
#     thr)
#       # Allow explicit mode=thr too
#       [[ -z "$THR" ]] && { echo "ERROR: --thr required for --mode thr"; exit 1; }
#       TAG="thr${THR}"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode thr --thr "$THR"
#       ;;
#     *)
#       echo "ERROR: unknown --mode '$MODE' (use thr|percent|range)"; exit 1;;
#   esac
# else
#   # Legacy path: use numeric --thr only
#   [[ -z "$THR" ]] && { echo "ERROR: either --thr or --mode is required"; exit 1; }
#   TAG="thr${THR}"
#   "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#     --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#     --mode thr --thr "$THR"
# fi

# # -------- 2) Run v3 builder in "mask mode" --------
# # This produces:
# #   ${LABEL_BASE}_{wb,ctx}_{bin,clust}-<TAG>.{dscalar,dlabel,ptseries}.nii
# "${SCRIPT_DIR}/dscalar2ptseries.sh" \
#   --confmask  "$SEED_MASK" \
#   --mask_tag  "$TAG" \
#   --dtseries  "$DTSERIES" \
#   --left_surf "$LEFT_SURF" \
#   --right_surf "$RIGHT_SURF" \
#   --outdir    "$OUTDIR" \
#   --label_base "$LABEL_BASE"

# # -------- 3) Write helper .conc files and extras --------
# for region in "${REGIONS[@]}"; do
#   CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
#   BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"

#   for f in "$CLUST_PTSERIES" "$BIN_PTSERIES"; do
#     [[ -f "$f" ]] || { echo "ERROR: missing $f (check tag: ${TAG})"; exit 1; }
#   done

#   echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#   echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"

#   if [[ "${#REGIONS[@]}" -eq 1 ]]; then
#     echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt.conc"
#     echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt.conc"
#   fi
# done

# # Always-needed helper concs
# echo "$DTSERIES" > "${OUTDIR}/dt.conc"
# [[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"

# # Optional surf concs for downstream wrappers
# [[ -n "$LEFT_SURF"  ]] && echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
# [[ -n "$RIGHT_SURF" ]] && echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

# echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"
# # dscalar2seed.sh
# # Build a binary seed mask from a dscalar (thr/percent/range),
# # run dscalar2ptseries.sh, then write helper .conc files.
# # Tolerant: if ctx files are absent, warn and continue with wb.

# set -euo pipefail
# set -x
# trap 'echo "ERROR in dscalar2seed.sh at line $LINENO"; exit 1' ERR

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# # -------- argument parsing --------
# DSCALAR="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters" THR=""
# MOTION_CONC="" REGION_FLAG="all"

# MODE="" WHICH="" PERCENT="" RANGE_STR="" MASK_TAG=""

# argv=("$@")
# i=0
# while (( i < ${#argv[@]} )); do
#   case "${argv[i]}" in
#     --dscalar|--confmap) DSCALAR="${argv[i+1]}"; ((i+=2)); continue;;
#     --dtseries)          DTSERIES="${argv[i+1]}"; ((i+=2)); continue;;
#     --left_surf)         LEFT_SURF="${argv[i+1]}"; ((i+=2)); continue;;
#     --right_surf)        RIGHT_SURF="${argv[i+1]}"; ((i+=2)); continue;;
#     --outdir)            OUTDIR="${argv[i+1]}"; ((i+=2)); continue;;
#     --label_base)        LABEL_BASE="${argv[i+1]}"; ((i+=2)); continue;;
#     --thr)               THR="${argv[i+1]}"; ((i+=2)); continue;;
#     --motion_conc)       MOTION_CONC="${argv[i+1]}"; ((i+=2)); continue;;
#     --region)            REGION_FLAG="${argv[i+1]}"; ((i+=2)); continue;;
#     --mode)              MODE="${argv[i+1]}"; ((i+=2)); continue;;
#     --which)             WHICH="${argv[i+1]}"; ((i+=2)); continue;;
#     --percent)           PERCENT="${argv[i+1]}"; ((i+=2)); continue;;
#     --range)             RANGE_STR="${argv[i+1]}"; ((i+=2)); continue;;
#     --mask_tag)          MASK_TAG="${argv[i+1]}"; ((i+=2)); continue;;
#     -h|--help)
#       cat <<'USAGE'
# Usage:
#   dscalar2seed.sh --confmap X.dscalar.nii --dtseries Y.dtseries.nii \
#     --left_surf L.surf.gii --right_surf R.surf.gii \
#     --outdir OUT --label_base NAME [--mode percent|thr|range ...]
# USAGE
#       exit 0;;
#     *) echo "ERROR: unknown arg '${argv[i]}'"; exit 1;;
#   esac
# done

# echo "dscalar2seed.sh: inputs:"
# echo "  dscalar:    $DSCALAR"
# echo "  dtseries:   $DTSERIES"
# echo "  left_surf:  $LEFT_SURF"
# echo "  right_surf: $RIGHT_SURF"
# echo "  outdir:     $OUTDIR"
# echo "  label_base: $LABEL_BASE"
# echo "  mode:       $MODE"
# echo "  which:      $WHICH"
# echo "  percent:    $PERCENT"
# echo "  range:      $RANGE_STR"
# echo "  mask_tag:   $MASK_TAG"

# # -------- preflight --------
# for v in DSCALAR DTSERIES LEFT_SURF RIGHT_SURF OUTDIR; do
#   [[ -n "${!v}" ]] || { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -f "$DSCALAR"    ]] || { echo "ERROR: dscalar not found: $DSCALAR"; exit 1; }
# [[ -f "$DTSERIES"   ]] || { echo "ERROR: dtseries not found: $DTSERIES"; exit 1; }
# [[ -f "$LEFT_SURF"  ]] || { echo "ERROR: left_surf not found: $LEFT_SURF"; exit 1; }
# [[ -f "$RIGHT_SURF" ]] || { echo "ERROR: right_surf not found: $RIGHT_SURF"; exit 1; }
# [[ -d "$OUTDIR"     ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }
# [[ -w "$OUTDIR"     ]] || { echo "ERROR: outdir not writable: $OUTDIR"; exit 1; }

# ADV="${SCRIPT_DIR}/dscalar2seed_advanced.sh"
# PT="${SCRIPT_DIR}/dscalar2ptseries.sh"
# [[ -x "$ADV" ]] || { echo "ERROR: missing executable: $ADV"; exit 1; }
# [[ -x "$PT"  ]] || { echo "ERROR: missing executable: $PT"; exit 1; }

# # -------- region selection --------
# if [[ "$REGION_FLAG" == "all" ]]; then
#   REGIONS=(wb ctx)
# else
#   REGIONS=("$REGION_FLAG")
# fi
# echo "Regions: ${REGIONS[*]}"

# # -------- 1) Build mask (thr/percent/range) --------
# SEED_MASK="${OUTDIR}/${LABEL_BASE}_seed_mask.dscalar.nii"
# TAG=""

# echo "Seed mask will be: $SEED_MASK"
# if [[ -n "$MODE" ]]; then
#   case "$MODE" in
#     percent)
#       [[ -n "$WHICH" && -n "$PERCENT" ]] || { echo "ERROR: --which and --percent required for --mode percent"; exit 1; }
#       [[ -n "$MASK_TAG" ]] || MASK_TAG="perc-${WHICH}${PERCENT}"
#       TAG="$MASK_TAG"
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode percent --which "$WHICH" --percent "$PERCENT"
#       ;;
#     range)
#       [[ -n "$RANGE_STR" ]] || { echo "ERROR: --range low,high required for --mode range"; exit 1; }
#       if [[ -z "$MASK_TAG" ]]; then
#         lo="${RANGE_STR%%,*}"; hi="${RANGE_STR##*,}"
#         MASK_TAG="range-${lo}_${hi}"
#       fi
#       TAG="$MASK_TAG"
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode range --range "$RANGE_STR"
#       ;;
#     thr)
#       [[ -n "$THR" ]] || { echo "ERROR: --thr required for --mode thr"; exit 1; }
#       TAG="thr${THR}"
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode thr --thr "$THR"
#       ;;
#     *)
#       echo "ERROR: unknown --mode '$MODE' (use thr|percent|range)"; exit 1;;
#   esac
# else
#   [[ -n "$THR" ]] || { echo "ERROR: either --thr or --mode is required"; exit 1; }
#   TAG="thr${THR}"
#   "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#          --mode thr --thr "$THR"
# fi
# echo "Mask tag: $TAG"
# [[ -f "$SEED_MASK" ]] || { echo "ERROR: expected mask not created: $SEED_MASK"; exit 1; }

# # -------- 2) Build ptseries (mask mode; tolerant to missing ctx) --------
# echo "Running PT (mask->ptseries) ..."
# set +e
# "$PT" \
#   --confmask  "$SEED_MASK" \
#   --mask_tag  "$TAG" \
#   --dtseries  "$DTSERIES" \
#   --left_surf "$LEFT_SURF" \
#   --right_surf "$RIGHT_SURF" \
#   --outdir    "$OUTDIR" \
#   --label_base "$LABEL_BASE"
# ec=$?
# set -e
# if [[ $ec -ne 0 ]]; then
#   echo "ERROR: dscalar2ptseries.sh returned non-zero ($ec)"; exit $ec
# fi

# # -------- 3) Helper .conc files (tolerant) --------
# for region in "${REGIONS[@]}"; do
#   CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
#   BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"

#   if [[ ! -f "$CLUST_PTSERIES" || ! -f "$BIN_PTSERIES" ]]; then
#     echo "WARNING: Skipping ${region} .conc creation; expected ptseries missing (likely no parcels)."
#     continue
#   fi

#   echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#   echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"
# done

# # If only one region produced concs, also write generic names
# if [[ -f "${OUTDIR}/clust_pt_wb.conc" && ! -f "${OUTDIR}/clust_pt_ctx.conc" ]]; then
#   cp -f "${OUTDIR}/clust_pt_wb.conc"  "${OUTDIR}/clust_pt.conc"  || true
#   cp -f "${OUTDIR}/bin_pt_wb.conc"    "${OUTDIR}/bin_pt.conc"    || true
# fi

# # Always-needed helper concs
# echo "$DTSERIES" > "${OUTDIR}/dt.conc"
# [[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"
# [[ -n "$LEFT_SURF"  ]] && echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
# [[ -n "$RIGHT_SURF" ]] && echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

# echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"



# #!/usr/bin/env bash
# # dscalar2seed.sh
# # Build a binary seed mask from a dscalar (thr/percent/range),
# # then run dscalar2ptseries.sh to produce {wb,ctx} x {bin,clust} ptseries,
# # and write helper .conc files.
# #
# # Requires (on PATH or same dir):
# #   - wb_command (used by called scripts)
# #   - dscalar2seed_advanced.sh
# #   - dscalar2ptseries.sh


# set -euo pipefail
# # trace everything inside this script, too
# set -x
# trap 'echo "ERROR in dscalar2seed.sh at line $LINENO"; exit 1' ERR

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# # -------- argument parsing --------
# DSCALAR="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters" THR=""
# MOTION_CONC="" REGION_FLAG="all"
# MODE="" WHICH="" PERCENT="" RANGE_STR="" MASK_TAG=""

# argv=("$@")
# for ((i=0; i<${#argv[@]}; i++)); do
#   case "${argv[$i]}" in
#     --dscalar)    DSCALAR="${argv[$((i+1))]}"; ((i+=1));;
#     --confmap)    DSCALAR="${argv[$((i+1))]}"; ((i+=1));;  # backward-compatible alias
#     --dtseries)   DTSERIES="${argv[$((i+1))]}"; ((i+=1));;
#     --left_surf)  LEFT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --right_surf) RIGHT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --outdir)     OUTDIR="${argv[$((i+1))]}";   ((i+=1));;
#     --label_base) LABEL_BASE="${argv[$((i+1))]}"; ((i+=1));;
#     --thr)        THR="${argv[$((i+1))]}";      ((i+=1));;
#     --motion_conc) MOTION_CONC="${argv[$((i+1))]}"; ((i+=1));;
#     --region)     REGION_FLAG="${argv[$((i+1))]}"; ((i+=1));;
#     --mode)       MODE="${argv[$((i+1))]}"; ((i+=1));;
#     --which)      WHICH="${argv[$((i+1))]}"; ((i+=1));;
#     --percent)    PERCENT="${argv[$((i+1))]}"; ((i+=1));;
#     --range)      RANGE_STR="${argv[$((i+1))]}"; ((i+=1));;
#     --mask_tag)   MASK_TAG="${argv[$((i+1))]}"; ((i+=1));;
#     -h|--help)
#       cat <<'USAGE'
# Usage:
#   dscalar2seed.sh --dscalar F.dscalar.nii --dtseries F.dtseries.nii \
#       --left_surf L.surf.gii --right_surf R.surf.gii \
#       [--thr 0.6 | --mode percent --which top|bottom --percent 10 | --mode range --range 0,0.1] \
#       --outdir OUT --label_base NAME [--region wb|ctx|all] --motion_conc motion.conc
#   (Alias --confmap accepted instead of --dscalar)
# USAGE
#       exit 0;;
#     *) ;;
#   esac
# done

# echo "dscalar2seed.sh: inputs:"
# echo "  dscalar:    $DSCALAR"
# echo "  dtseries:   $DTSERIES"
# echo "  left_surf:  $LEFT_SURF"
# echo "  right_surf: $RIGHT_SURF"
# echo "  outdir:     $OUTDIR"
# echo "  label_base: $LABEL_BASE"
# echo "  mode:       ${MODE:-thr(${THR:-unset})}"
# echo "  which:      ${WHICH:-}"
# echo "  percent:    ${PERCENT:-}"
# echo "  range:      ${RANGE_STR:-}"
# echo "  mask_tag:   ${MASK_TAG:-}"

# # -------- preflight --------
# for v in DSCALAR DTSERIES LEFT_SURF RIGHT_SURF OUTDIR; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -f "$DSCALAR"    ]] || { echo "ERROR: dscalar not found: $DSCALAR"; exit 1; }
# [[ -f "$DTSERIES"   ]] || { echo "ERROR: dtseries not found: $DTSERIES"; exit 1; }
# [[ -f "$LEFT_SURF"  ]] || { echo "ERROR: left_surf not found: $LEFT_SURF"; exit 1; }
# [[ -f "$RIGHT_SURF" ]] || { echo "ERROR: right_surf not found: $RIGHT_SURF"; exit 1; }
# [[ -d "$OUTDIR"     ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }
# [[ -w "$OUTDIR"     ]] || { echo "ERROR: outdir not writable: $OUTDIR"; exit 1; }

# ADV="${SCRIPT_DIR}/dscalar2seed_advanced.sh"
# PT="${SCRIPT_DIR}/dscalar2ptseries.sh"
# echo "ADV script: $ADV"
# echo "PT  script: $PT"
# [[ -x "$ADV" ]] || { echo "ERROR: missing executable: $ADV"; exit 1; }
# [[ -x "$PT"  ]] || { echo "ERROR: missing executable: $PT"; exit 1; }

# # -------- region selection --------
# if [[ "$REGION_FLAG" == "all" ]]; then
#   REGIONS=(wb ctx)
# else
#   REGIONS=("$REGION_FLAG")
# fi
# echo "Regions: ${REGIONS[*]}"

# # -------- 1) Build mask (thr/percent/range) --------
# SEED_MASK="${OUTDIR}/${LABEL_BASE}_seed_mask.dscalar.nii"
# TAG=""
# echo "Seed mask will be: $SEED_MASK"

# if [[ -n "$MODE" ]]; then
#   case "$MODE" in
#     percent)
#       [[ -n "$WHICH" && -n "$PERCENT" ]] || { echo "ERROR: --which and --percent required for --mode percent"; exit 1; }
#       [[ -n "$MASK_TAG" ]] || MASK_TAG="perc-${WHICH}${PERCENT}"
#       TAG="$MASK_TAG"
#       echo "Running ADV (percent) ..."
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode percent --which "$WHICH" --percent "$PERCENT"
#       ;;
#     range)
#       [[ -n "$RANGE_STR" ]] || { echo "ERROR: --range low,high required for --mode range"; exit 1; }
#       if [[ -z "$MASK_TAG" ]]; then
#         lo="${RANGE_STR%%,*}"; hi="${RANGE_STR##*,}"
#         MASK_TAG="range-${lo}_${hi}"
#       fi
#       TAG="$MASK_TAG"
#       echo "Running ADV (range) ..."
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode range --range "$RANGE_STR"
#       ;;
#     thr)
#       [[ -n "$THR" ]] || { echo "ERROR: --thr required for --mode thr"; exit 1; }
#       TAG="thr${THR}"
#       echo "Running ADV (thr) ..."
#       "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#              --mode thr --thr "$THR"
#       ;;
#     *)
#       echo "ERROR: unknown --mode '$MODE' (use thr|percent|range)"; exit 1;;
#   esac
# else
#   [[ -n "$THR" ]] || { echo "ERROR: either --thr or --mode is required"; exit 1; }
#   TAG="thr${THR}"
#   echo "Running ADV (legacy thr) ..."
#   "$ADV" --confmap "$DSCALAR" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#          --mode thr --thr "$THR"
# fi
# echo "Mask tag: $TAG"
# [[ -f "$SEED_MASK" ]] || { echo "ERROR: expected mask not found after ADV: $SEED_MASK"; exit 1; }

# # -------- 2) Build ptseries (mask mode) --------
# echo "Running PT (mask->ptseries) ..."
# "$PT" \
#   --confmask  "$SEED_MASK" \
#   --mask_tag  "$TAG" \
#   --dtseries  "$DTSERIES" \
#   --left_surf "$LEFT_SURF" \
#   --right_surf "$RIGHT_SURF" \
#   --outdir    "$OUTDIR" \
#   --label_base "$LABEL_BASE"

# # -------- 3) Helper .conc files --------
# had_any=0
# for region in "${REGIONS[@]}"; do
#   CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
#   BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"

#   if [[ -f "$CLUST_PTSERIES" && -f "$BIN_PTSERIES" ]]; then
#     echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#     echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"
#     had_any=1
#   else
#     echo "WARNING: skipping region ${region}; missing ptseries for this family (likely no parcels)."
#     rm -f "${OUTDIR}/clust_pt_${region}.conc" "${OUTDIR}/bin_pt_${region}.conc" || true
#   fi
# done

# if [[ $had_any -eq 0 ]]; then
#   echo "ERROR: no region produced ptseries. Check your mask selection."
#   exit 1
# fi

# # Always-needed helper concs
# echo "$DTSERIES" > "${OUTDIR}/dt.conc"
# [[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"
# [[ -n "$LEFT_SURF"  ]] && echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
# [[ -n "$RIGHT_SURF" ]] && echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

# echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"



# for region in "${REGIONS[@]}"; do
#   CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
#   BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"
#   [[ -f "$CLUST_PTSERIES" ]] || { echo "ERROR: missing $CLUST_PTSERIES"; exit 1; }
#   [[ -f "$BIN_PTSERIES"   ]] || { echo "ERROR: missing $BIN_PTSERIES"; exit 1; }

#   echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#   echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"

#   if [[ "${#REGIONS[@]}" -eq 1 ]]; then
#     echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt.conc"
#     echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt.conc"
#   fi
# done

# echo "$DTSERIES" > "${OUTDIR}/dt.conc"
# [[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"
# echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
# echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

# echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"



# #!/usr/bin/env bash
# # dscalar2seed.sh
# # Wrapper to (a) build a binary seed mask using either thr/percent/range
# # and (b) run dscalar2ptseries.sh to produce *_bin-<tag>.ptseries.nii
# # and *_clust-<tag>.ptseries.nii, then write helper .conc files.
# #
# # Requires:
# #   - wb_command
# #   - dscalar2seed_advanced.sh (same directory)
# #   - dscalar2ptseries.sh (updated version)

# set -euo pipefail
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# # -------- argument parsing (kept close to your old flags) --------
# CONFMAP="" DTSERIES="" LEFT_SURF="" RIGHT_SURF=""
# OUTDIR="" LABEL_BASE="Clusters" THR=""
# MOTION_CONC="" REGION_FLAG="all"

# # new optional selection controls
# MODE="" WHICH="" PERCENT="" RANGE_STR="" MASK_TAG=""

# argv=("$@")
# for ((i=0; i<${#argv[@]}; i++)); do
#   case "${argv[$i]}" in
#     --confmap)    CONFMAP="${argv[$((i+1))]}"; ((i+=1));;
#     --dtseries)   DTSERIES="${argv[$((i+1))]}"; ((i+=1));;
#     --left_surf)  LEFT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --right_surf) RIGHT_SURF="${argv[$((i+1))]}"; ((i+=1));;
#     --outdir)     OUTDIR="${argv[$((i+1))]}";   ((i+=1));;
#     --label_base) LABEL_BASE="${argv[$((i+1))]}"; ((i+=1));;
#     --thr)        THR="${argv[$((i+1))]}";      ((i+=1));;
#     --motion_conc) MOTION_CONC="${argv[$((i+1))]}"; ((i+=1));;
#     --region)     REGION_FLAG="${argv[$((i+1))]}"; ((i+=1));;
#     # new:
#     --mode)       MODE="${argv[$((i+1))]}"; ((i+=1));;
#     --which)      WHICH="${argv[$((i+1))]}"; ((i+=1));;
#     --percent)    PERCENT="${argv[$((i+1))]}"; ((i+=1));;
#     --range)      RANGE_STR="${argv[$((i+1))]}"; ((i+=1));;
#     --mask_tag)   MASK_TAG="${argv[$((i+1))]}"; ((i+=1));;
#     -h|--help)
#       cat <<'USAGE'
# Usage:
#   # Legacy threshold (unchanged behavior):
#   dscalar2seed.sh --confmap F.dscalar.nii --dtseries F.dtseries.nii \
#       --left_surf L.surf.gii --right_surf R.surf.gii \
#       --thr 0.6 --outdir OUT --label_base NAME [--region wb|ctx|all] \
#       --motion_conc motion.conc

#   # New: percentile
#   dscalar2seed.sh ... --mode percent --which top --percent 10 --mask_tag perc-top10

#   # New: range
#   dscalar2seed.sh ... --mode range --range 0,0.1 --mask_tag range-0.0_0.1
# USAGE
#       exit 0;;
#     *) ;;
#   esac
# done

# for v in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF OUTDIR; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -d "$OUTDIR" ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }

# # -------- region selection --------
# if [[ "$REGION_FLAG" == "all" ]]; then
#   REGIONS=(wb ctx)
# else
#   REGIONS=("$REGION_FLAG")
# fi

# # -------- 1) Build mask (or use legacy thr) --------
# SEED_MASK="${OUTDIR}/${LABEL_BASE}_seed_mask.dscalar.nii"
# TAG=""

# if [[ -n "$MODE" ]]; then
#   # Use advanced builder
#   case "$MODE" in
#     percent)
#       [[ -z "$WHICH" || -z "$PERCENT" ]] && { echo "ERROR: --which and --percent required for --mode percent"; exit 1; }
#       [[ -z "$MASK_TAG" ]] && MASK_TAG="perc-${WHICH}${PERCENT}"
#       TAG="$MASK_TAG"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode percent --which "$WHICH" --percent "$PERCENT"
#       ;;
#     range)
#       [[ -z "$RANGE_STR" ]] && { echo "ERROR: --range low,high required for --mode range"; exit 1; }
#       if [[ -z "$MASK_TAG" ]]; then
#         lo="${RANGE_STR%%,*}"; hi="${RANGE_STR##*,}"
#         MASK_TAG="range-${lo}_${hi}"
#       fi
#       TAG="$MASK_TAG"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode range --range "$RANGE_STR"
#       ;;
#     thr)
#       # Allow explicit mode=thr too
#       [[ -z "$THR" ]] && { echo "ERROR: --thr required for --mode thr"; exit 1; }
#       TAG="thr${THR}"
#       "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#         --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#         --mode thr --thr "$THR"
#       ;;
#     *)
#       echo "ERROR: unknown --mode '$MODE' (use thr|percent|range)"; exit 1;;
#   esac
# else
#   # Legacy path: use numeric --thr only
#   [[ -z "$THR" ]] && { echo "ERROR: either --thr or --mode is required"; exit 1; }
#   TAG="thr${THR}"
#   "${SCRIPT_DIR}/dscalar2seed_advanced.sh" \
#     --confmap "$CONFMAP" --outdir "$OUTDIR" --base "$LABEL_BASE" \
#     --mode thr --thr "$THR"
# fi

# # -------- 2) Run v3 builder in "mask mode" --------
# # This produces:
# #   ${LABEL_BASE}_{wb,ctx}_{bin,clust}-<TAG>.{dscalar,dlabel,ptseries}.nii
# "${SCRIPT_DIR}/dscalar2ptseries.sh" \
#   --confmask  "$SEED_MASK" \
#   --mask_tag  "$TAG" \
#   --dtseries  "$DTSERIES" \
#   --left_surf "$LEFT_SURF" \
#   --right_surf "$RIGHT_SURF" \
#   --outdir    "$OUTDIR" \
#   --label_base "$LABEL_BASE"

# # -------- 3) Write helper .conc files and extras --------
# for region in "${REGIONS[@]}"; do
#   CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-${TAG}.ptseries.nii"
#   BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-${TAG}.ptseries.nii"

#   for f in "$CLUST_PTSERIES" "$BIN_PTSERIES"; do
#     [[ -f "$f" ]] || { echo "ERROR: missing $f (check tag: ${TAG})"; exit 1; }
#   done

#   echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#   echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"

#   if [[ "${#REGIONS[@]}" -eq 1 ]]; then
#     echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt.conc"
#     echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt.conc"
#   fi
# done

# # Always-needed helper concs
# echo "$DTSERIES" > "${OUTDIR}/dt.conc"
# [[ -n "$MOTION_CONC" ]] && echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"

# # Optional surf concs for downstream wrappers
# [[ -n "$LEFT_SURF"  ]] && echo "$LEFT_SURF"  > "${OUTDIR}/left_surf.conc"
# [[ -n "$RIGHT_SURF" ]] && echo "$RIGHT_SURF" > "${OUTDIR}/right_surf.conc"

# echo "Helper .conc files written to $OUTDIR (tag: ${TAG})"