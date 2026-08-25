#!/usr/bin/env bash
# dscalar2seed_advanced.sh
# Build a binary seed mask from a confmap (dscalar.nii) using:
#   (a) absolute threshold (>= thr),
#   (b) percentile selection (top/bottom p%),
#   (c) value range selection ([low, high]).
#
# Requires: wb_command on PATH (HCP Workbench)
#
# Outputs:
#   <outdir>/<base>_seed_mask.dscalar.nii
#   <outdir>/<base>_seed_info.json
#   Optional: <outdir>/<base>_confvals.txt (if --keep_tmp)
#
# Examples:
#   # Classic: threshold >= 0.2
#   dscalar2seed_advanced.sh \
#     --confmap conf.dscalar.nii --outdir out --base SCAN --mode thr --thr 0.2
#
#   # Bottom 25%
#   dscalar2seed_advanced.sh \
#     --confmap conf.dscalar.nii --outdir out --base SCAN --mode percent --which bottom --percent 25
#
#   # Top 10%
#   dscalar2seed_advanced.sh \
#     --confmap conf.dscalar.nii --outdir out --base SCAN --mode percent --which top --percent 10
#
#   # Range [0, 0.1]
#   dscalar2seed_advanced.sh \
#     --confmap conf.dscalar.nii --outdir out --base SCAN --mode range --range 0,0.1
#

set -euo pipefail

# ---------- args ----------
DSCALAR="" OUTDIR="" BASE="Clusters"
MODE="" WHICH="" PERCENT="" RANGE_STR="" THR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --confmap|--dscalar) DSCALAR=$2; shift 2;;
    --outdir)            OUTDIR=$2;  shift 2;;
    --base)              BASE=$2;    shift 2;;
    --mode)              MODE=$2;    shift 2;;
    --which)             WHICH=$2;   shift 2;;
    --percent)           PERCENT=$2; shift 2;;
    --range)             RANGE_STR=$2; shift 2;;
    --thr)               THR=$2;     shift 2;;
    -h|--help)
      cat <<EOF
Usage:
  $0 --dscalar D.dscalar.nii --outdir OUT --base NAME --mode percent --which top|bottom --percent 25
  $0 --dscalar D.dscalar.nii --outdir OUT --base NAME --mode range --range 0.0,0.1
  $0 --dscalar D.dscalar.nii --outdir OUT --base NAME --mode thr --thr 0.6
EOF
      exit 0;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

[[ -n "$DSCALAR" && -f "$DSCALAR" ]] || { echo "ERROR: dscalar missing: $DSCALAR"; exit 1; }
[[ -n "$OUTDIR"  && -d "$OUTDIR"  ]] || { echo "ERROR: outdir missing: $OUTDIR"; exit 1; }
[[ -w "$OUTDIR" ]] || { echo "ERROR: outdir not writable: $OUTDIR"; exit 1; }
[[ -n "$MODE" ]] || { echo "ERROR: --mode required (percent|range|thr)"; exit 1; }

MASK="${OUTDIR}/${BASE}_seed_mask.dscalar.nii"

echo "advanced: dscalar=$DSCALAR"
echo "advanced: outdir=$OUTDIR  base=$BASE  mode=$MODE"

# ---------- helpers ----------
tmpdir="$(mktemp -d "${OUTDIR}/adv.$$.$RANDOM.XXXX")"
cleanup(){ rm -rf "$tmpdir"; }
trap cleanup EXIT

get_percentile_cutoff() {
  local dscalar="$1" which="$2" pct="$3"
  local txt="$tmpdir/vals.txt" srt="$tmpdir/sorted.txt"

  # Dump all values to text, filter numeric, drop NaNs, sort
  wb_command -cifti-convert -to-text "$dscalar" "$txt"
  awk '{if ($1+0==$1) print $1}' "$txt" | grep -v -i nan | sort -g > "$srt"
  local N; N=$(wc -l < "$srt"); N=${N//[[:space:]]/}
  [[ "$N" -gt 0 ]] || { echo "ERROR: no numeric values in dscalar" >&2; return 1; }

  # bottom p% => idx = ceil(p/100 * N)
  # top p%    => idx = ceil((1 - p/100) * N)
  local idx
  if [[ "$which" == "bottom" ]]; then
    idx=$(python - <<PY
import math
N=${N}; p=${pct}
print(max(1, int(math.ceil((p/100.0)*N))))
PY
)
  else
    idx=$(python - <<PY
import math
N=${N}; p=${pct}
print(max(1, int(math.ceil((1.0 - p/100.0)*N))))
PY
)
  fi

  # Clamp idx to [1,N]
  if [[ "$idx" -lt 1 ]]; then idx=1; fi
  if [[ "$idx" -gt "$N" ]]; then idx="$N"; fi

  # Get that value
  sed -n "${idx}p" "$srt"
}

# ---------- build mask ----------
case "$MODE" in
  percent)
    [[ "$WHICH" == "top" || "$WHICH" == "bottom" ]] || { echo "ERROR: --which must be top|bottom"; exit 1; }
    [[ -n "$PERCENT" ]] || { echo "ERROR: --percent required"; exit 1; }
    CUTOFF="$(get_percentile_cutoff "$DSCALAR" "$WHICH" "$PERCENT")"
    [[ -n "$CUTOFF" ]] || { echo "ERROR: failed to compute percentile cutoff"; exit 1; }
    echo "advanced: percentile cutoff (${WHICH} ${PERCENT}%): ${CUTOFF}"

    if [[ "$WHICH" == "bottom" ]]; then
      wb_command -cifti-math "x <= ${CUTOFF}" "$MASK" -var x "$DSCALAR"
    else
      wb_command -cifti-math "x >= ${CUTOFF}" "$MASK" -var x "$DSCALAR"
    fi
    ;;

  range)
    [[ -n "$RANGE_STR" && "$RANGE_STR" == *,* ]] || { echo "ERROR: --range must be low,high"; exit 1; }
    LO="${RANGE_STR%%,*}"; HI="${RANGE_STR##*,}"
    [[ -n "$LO" && -n "$HI" ]] || { echo "ERROR: bad --range '$RANGE_STR'"; exit 1; }
    echo "advanced: range inclusive [${LO}, ${HI}]"
    wb_command -cifti-math "(x >= ${LO}) * (x <= ${HI})" "$MASK" -var x "$DSCALAR"
    ;;

  thr)
    [[ -n "$THR" ]] || { echo "ERROR: --thr required"; exit 1; }
    echo "advanced: threshold >= ${THR}"
    wb_command -cifti-math "x >= ${THR}" "$MASK" -var x "$DSCALAR"
    ;;

  *) echo "ERROR: unknown mode '$MODE'"; exit 1;;
esac

[[ -f "$MASK" ]] || { echo "ERROR: mask not created: $MASK"; exit 1; }
echo "advanced: wrote mask -> $MASK"

