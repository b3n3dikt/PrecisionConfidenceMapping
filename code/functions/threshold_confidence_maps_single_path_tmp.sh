#!/bin/bash
#SBATCH -J threshmaps_simple
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=25gb
#SBATCH -t 00:30:00
#SBATCH -p msismall
#SBATCH -o output_logs/threshmaps_simple_%A_%a.out
#SBATCH -e output_logs/threshmaps_simple_%A_%a.err
#SBATCH -A smnelson

module load workbench/1.5.0
module load matlab

###############################################################################
# 1) HELP MESSAGE
###############################################################################
usage() {
  echo "Usage: $0 FIGDIR [--thresholds \"0.3 0.6 ...\"]"
  echo ""
  echo "  FIGDIR            Path to the *ciftis* directory you want to process"
  echo "                    (e.g. /.../ExpData-70m/figures/Percent_Holdout-100/ciftis)"
  echo ""
  echo "  --thresholds      Optional space-separated list of thresholds to run."
  echo "                    Default: 0 0.1 0.2 & 0.9"
  echo ""
  exit 1
}
###############################################################################
# 0) PATH TO THE CONVERTER & TOGGLE
###############################################################################
CONVERTER="/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/dscalar2dlabel.sh"
CONVERT_TO_DLABEL=true        # set to false to skip the extra step
###############################################################################

###############################################################################
# 2) PARSE ARGUMENTS
###############################################################################
if [[ $# -lt 1 ]]; then usage; fi

FIGDIR="$1" ; shift

USER_THRESH=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --thresholds)
      USER_THRESH=$2
      shift 2
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1"; usage ;;
  esac
done

###############################################################################
# 3) VERIFY FIGDIR AND BUILD THRESH ARRAY
###############################################################################
if [[ ! -d "$FIGDIR" ]]; then
  echo "ERROR: $FIGDIR does not exist"; exit 2
fi

if [[ -z "$USER_THRESH" ]]; then
  THRESHOLDS=$(seq 0 0.1 0.9 | xargs printf "%.1f\n")
else
  THRESHOLDS=(${USER_THRESH})
fi

echo "------------------------------------------------------------"
echo "  Working directory : $FIGDIR"
echo "  Threshold(s)      : ${THRESHOLDS[@]}"
echo "------------------------------------------------------------"

###############################################################################
# 4) FUNCTION TO RUN MATLAB ON ONE THRESHOLD
###############################################################################
run_threshold_matlab () {
  local DIR=$1
  local THR=$2

  local OUT_DSC="${DIR}/Thresholded-${THR}/PCM_confidence_map_to_bin_all-networks_thresh-${THR}.dscalar.nii"
  local LOG_DIR="${DIR}/logs"          # <-- define once
  mkdir -p "$(dirname "$OUT_DSC")" "$LOG_DIR"

  if [[ -f "$OUT_DSC" ]]; then
    echo "  -> Skip ${THR} (already exists)"
  else
    echo "  -> Threshold ${THR}"
    matlab -nodisplay -nosplash -r \
      "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions'); \
       addpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files'); \
       addpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'); \
       threshold_confidence_maps('${DIR}', 100, ${THR}); \
       exit;" \
      >> "${LOG_DIR}/matlab_threshold_${THR}.log" 2>&1
  fi

  # optional .dlabel conversion 
  if $CONVERT_TO_DLABEL && [[ -f "$OUT_DSC" ]]; then
    echo "     ³ Converting to .dlabel"
    "${CONVERTER}" "${OUT_DSC}" \
      >> "${LOG_DIR}/dscalar2dlabel_${THR}.log" 2>&1
  fi
}

###############################################################################
# 5) MAIN LOOP (just one directory)
###############################################################################
# quick sanity check that there is at least one dscalar file to work on
if [[ $(ls -1 "${FIGDIR}"/*.dscalar.nii 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "No .dscalar.nii files found in $FIGDIR"; exit 3
fi

for T in ${THRESHOLDS[@]}; do
  run_threshold_matlab "$FIGDIR" "$T"
done

echo "Finished all thresholds"
