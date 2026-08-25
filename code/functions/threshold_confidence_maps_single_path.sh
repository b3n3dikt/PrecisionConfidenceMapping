#!/bin/bash
#SBATCH -J PCM_threshold_maps
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=25gb
#SBATCH -t 00:30:00
# Partition and account are passed at submission time (from cluster.conf).

# =============================================================================
# threshold_confidence_maps_single_path.sh  —  PCM Confidence Map Thresholding
# =============================================================================
# Thresholds per-network probability dscalars at each level in THRESHOLDS and
# writes combined all-networks and per-network binary dscalar + dlabel files.
#
# Usage: $0 FIGDIR [--thresholds "0.3 0.6 ..."] [--combined-only]
#
#   FIGDIR         Path to the ciftis/ directory
#                  (e.g. .../figures/Percent_Holdout-100/ciftis)
#   --thresholds   Optional space-separated list. Default: 0 0.1 ... 0.9 0.99
#   --combined-only  Only write the combined all-networks map (no Individual_Networks).
# =============================================================================

# Resolve CODE_DIR: inherited from SLURM environment, or detected from script location.
if [[ -z "${CODE_DIR}" ]]; then
    CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
fi
source "${CODE_DIR}/config.sh"

module load "${WORKBENCH_MODULE}"
module load "${MATLAB_MODULE}"

###############################################################################
# PARSE ARGUMENTS
###############################################################################
usage() {
  echo "Usage: $0 FIGDIR [--thresholds \"0.3 0.6 ...\"] [--combined-only]"
  exit 1
}

if [[ $# -lt 1 ]]; then usage; fi

FIGDIR="$1"; shift

USER_THRESH=""
MAKE_INDIV=1
while [[ $# -gt 0 ]]; do
  case "$1" in
    --thresholds)   USER_THRESH="$2"; shift 2 ;;
    --combined-only) MAKE_INDIV=0;   shift 1 ;;
    -h|--help)      usage ;;
    *)              echo "Unknown argument: $1"; usage ;;
  esac
done

###############################################################################
# BUILD THRESHOLD ARRAY
###############################################################################
if [[ ! -d "$FIGDIR" ]]; then
  echo "ERROR: $FIGDIR does not exist"; exit 2
fi

if [[ -z "$USER_THRESH" ]]; then
  THRESHOLDS=($(seq 0 0.1 0.9 | xargs printf "%.1f\n") 0.99)
else
  THRESHOLDS=($USER_THRESH)
fi

echo "------------------------------------------------------------"
echo "  Working directory : $FIGDIR"
echo "  Threshold(s)      : ${THRESHOLDS[*]}"
echo "  Individuals       : ${MAKE_INDIV}"
echo "------------------------------------------------------------"

###############################################################################
# RUN MATLAB FOR EACH THRESHOLD
###############################################################################
if [[ $(ls -1 "${FIGDIR}"/*.dscalar.nii 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "No .dscalar.nii files found in $FIGDIR"; exit 3
fi

LOG_DIR="${FIGDIR}/logs"
mkdir -p "${LOG_DIR}"

for THR in "${THRESHOLDS[@]}"; do
  THR_STR="$(printf "%g" "$THR")"
  OUT_DSC="${FIGDIR}/Thresholded-${THR_STR}/PCM_confidence_map_to_bin_all-networks_thresh-${THR_STR}.dscalar.nii"
  mkdir -p "$(dirname "$OUT_DSC")"

  if [[ -f "$OUT_DSC" ]]; then
    echo "  -> Skip ${THR_STR} (already exists)"
    continue
  fi

  echo "  -> Threshold ${THR_STR}"
  matlab -nodisplay -nosplash -r \
    "try; \
       ${MATLAB_ADDPATH} \
       threshold_confidence_maps('${FIGDIR}', 100, ${THR}, ${MAKE_INDIV}); \
     catch ME; disp(getReport(ME,'extended')); exit(1); \
     end; \
     exit;" \
    >> "${LOG_DIR}/matlab_threshold_${THR_STR}.log" 2>&1
done

echo "Finished all thresholds"
