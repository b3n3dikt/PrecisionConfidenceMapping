#!/usr/bin/env bash
# ----------------------------------------------------------------------
# confmap2seed.sh    confidence-map  clusters  seed-connectivity maps
# ----------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

############################################################################
# 0.  Separate argv into:
#       " ARGS_PT    passed to confmap_to_ptseries.sh   (no motion flag)
#       " ARGS_SELF  used later for seed-map generation (keeps everything)
############################################################################
############################################################################
# 0.  Split argv  (a) args for Workbench  (b) everything for seed step
############################################################################
ARGS_PT=()              #  forwarded to confmap_to_ptseries.sh
MOTION_CONC=""

skip_next=false
for arg in "$@"; do
    if $skip_next; then        # skip the *value* of --motion_conc
        skip_next=false
        continue
    fi

    case "$arg" in
        --motion_conc)
            skip_next=true     # drop flag AND next token
            ;;
        *)
            ARGS_PT+=("$arg")  # keep all other args
            ;;
    esac
done

############################################################################
# 1. Run Workbench pipeline with filtered arguments
############################################################################
"${SCRIPT_DIR}/confmap_to_ptseries_v2.sh" "${ARGS_PT[@]}"

############################################################################
# 2. Parse **all** flags (including --motion_conc) for seed-map step
############################################################################
THR="" OUTDIR="" LABEL_BASE="Clusters" DTSERIES="" L_SURF="" R_SURF=""
while [[ $# -gt 0 ]]; do
  case "$1" in
      --dtseries)     DTSERIES=$2;    shift 2;;
      --outdir)       OUTDIR=$2;      shift 2;;
      --left_surf)    L_SURF=$2;      shift 2;;
      --right_surf)   R_SURF=$2;      shift 2;;
      --label_base)   LABEL_BASE=$2;  shift 2;;
      --thr)          THR=$2;         shift 2;;
      --motion_conc)  MOTION_CONC=$2; shift 2;;
      *) shift 1;;
  esac
done

# ----------------------------------------------------------------------
# 3. Sanity checks
# ----------------------------------------------------------------------
for v in THR OUTDIR DTSERIES L_SURF R_SURF MOTION_CONC; do
  [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
done
CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_clust-thr${THR}.ptseries.nii"
[[ -f "${CLUST_PTSERIES}" ]] || { echo "ERROR: missing ptseries ${CLUST_PTSERIES}"; exit 1; }

BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.ptseries.nii"
[[ -f "${BIN_PTSERIES}" ]] || { echo "ERROR: missing ptseries ${BIN_PTSERIES}"; exit 1; }

#SEEDMAP_DIR="${OUTDIR}/seedMaps"
#mkdir -p "${SEEDMAP_DIR}"

# ----------------------------------------------------------------------
# 4. Helper .conc files (Fair-lab utilities expect single-line lists)
# ----------------------------------------------------------------------
echo "${DTSERIES}"   > "${OUTDIR}/dt.conc"
echo "${CLUST_PTSERIES}"   > "${OUTDIR}/clust_pt.conc"
echo "${BIN_PTSERIES}"   > "${OUTDIR}/bin_pt.conc"
echo "${MOTION_CONC}" > "${OUTDIR}/motion.conc"
echo "${L_SURF}"     > "${OUTDIR}/left_surf.conc"
echo "${R_SURF}"     > "${OUTDIR}/right_surf.conc"

# ----------------------------------------------------------------------
# 5. Headless MATLAB call
# ----------------------------------------------------------------------
# Default FD threshold in make_seedmap is already 0.2; override by adding
# ... 'FdThresh',0.25, ... inside the call if you need another value.
#matlab -batch "addpath('${SCRIPT_DIR}'); \
#make_seedmap('${PTSERIES}', '${OUTDIR}/dt.conc', '${OUTDIR}/motion.conc', \
#'${OUTDIR}/left_surf.conc', '${OUTDIR}/right_surf.conc', \
#'OutDir', '${SEEDMAP_DIR}');"

#echo "  Seed-maps written to ${SEEDMAP_DIR}"