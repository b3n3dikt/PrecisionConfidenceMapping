#!/bin/bash
#SBATCH -J threshmaps_only
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=25gb
#SBATCH -t 4:00:00
#SBATCH -p msismall
#SBATCH -o output_logs/threshmaps_only_%A_%a.out
#SBATCH -e output_logs/threshmaps_only_%A_%a.err
#SBATCH -A smnelson

module load workbench/1.5.0
module load matlab

###############################################################################
# 1) HELP MESSAGE
###############################################################################
usage() {
  echo "Usage: $0 [options]"
  echo ""
  echo "Options:"
  echo "  -h, --help               Show this help message and exit."
  echo "  --basedir BASEDIR        Base directory for your PCM outputs."
  echo "  --sub SUB                Subject ID."
  echo "  --ses SES                Session ID."
  echo "  --holdout HOLDOUT        Percent holdout (default: 100)."
  echo "  --figdir1 FIGDIR1        Path to ExpData directory (optional)."
  echo "  --figdir2 FIGDIR2        Path to RefData directory (optional)."
  echo "  --minutes-exp \"M1 M2\"    Space-separated list of ExpData minutes (e.g. \"1m 2m fullm\")."
  echo "  --minutes-ref \"M1 M2\"    Space-separated list of RefData minutes (e.g. \"70m fullm\")."
  echo "  --thresholds \"T1 T2\"    Space-separated thresholds (e.g. \"0.5 0.6 0.7\")."
  echo ""
  echo "Description:"
  echo "  This script simply thresholds and binarizes .dscalar probability maps in one or two directories."
  echo "  If both directories are provided, it will process them separately (no mutual info)."
  echo ""
  echo "Example Usage:"
  echo "  $0 --sub PFM3T7T01 --ses combined --holdout 100 --minutes-exp \"1m 2m fullm\""
  echo "  $0 --figdir1 /my/custom/ExpData/ciftis --thresholds \"0 0.5 0.9\""
  echo "  $0 --figdir2 /my/custom/RefData/ciftis --minutes-ref \"70m fullm\""
  echo "  $0 -h"
  echo ""
  exit 1
}

###############################################################################
# 2) DEFAULT PARAMETERS
###############################################################################
BASEDIR="/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/mo_bagging-20_percent_to_data_length"
SUB="PFM3T7T01"
SES="combined"
percent_holdout=100
FIGDIR1=""
FIGDIR2=""
MINUTES_EXP_LIST=()      # If empty, we can fill in or let user specify
MINUTES_REF_LIST=()
USER_THRESHOLDS=""       # e.g. "0 0.5 0.6"

###############################################################################
# 3) PARSE COMMAND-LINE ARGUMENTS
###############################################################################
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      ;;
    --basedir)
      BASEDIR=$2
      shift 2
      ;;
    --sub)
      SUB=$2
      shift 2
      ;;
    --ses)
      SES=$2
      shift 2
      ;;
    --holdout)
      percent_holdout=$2
      shift 2
      ;;
    --figdir1)
      FIGDIR1=$2
      shift 2
      ;;
    --figdir2)
      FIGDIR2=$2
      shift 2
      ;;
    --minutes-exp)
      # Convert users space-separated string into array
      MINUTES_EXP_LIST=($2)
      shift 2
      ;;
    --minutes-ref)
      MINUTES_REF_LIST=($2)
      shift 2
      ;;
    --thresholds)
      USER_THRESHOLDS=$2
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      ;;
  esac
done

###############################################################################
# 4) IF MINUTES LISTS NOT PROVIDED, USE DEFAULTS
###############################################################################
# For example, if you want 1..200 plus "fullm" for ExpData:
if [ ${#MINUTES_EXP_LIST[@]} -eq 0 ]; then
  MINUTES_EXP_LIST=($(seq 1 200 | sed 's/$/m/'))
  MINUTES_EXP_LIST+=("fullm")
fi

# For RefData, you could default to just 70m plus "fullm", etc.
if [ ${#MINUTES_REF_LIST[@]} -eq 0 ]; then
  MINUTES_REF_LIST=("70m" "fullm")
fi

###############################################################################
# 5) DEFINE THRESHOLDS
###############################################################################
if [[ -z "${USER_THRESHOLDS}" ]]; then
  # Default thresholds if none given:
  THRESHOLDS=$(seq 0 0.1 0.9 | xargs printf "%.1f\n")
else
  THRESHOLDS=(${USER_THRESHOLDS})
fi

echo "================================================================"
echo "  BASEDIR      = ${BASEDIR}"
echo "  SUB          = ${SUB}"
echo "  SES          = ${SES}"
echo "  holdout      = ${percent_holdout}"
echo "  minutes-exp  = ${MINUTES_EXP_LIST[@]}"
echo "  minutes-ref  = ${MINUTES_REF_LIST[@]}"
echo "  thresholds   = ${THRESHOLDS[@]}"
echo "================================================================"

###############################################################################
# 6) FUNCTION TO RUN MATLAB FOR A GIVEN DIRECTORY
###############################################################################
run_threshold_matlab() {
  local DIR=$1
  local T=$2

  # If the thresholded .dscalar file already exists, skip
  # (We name it the same as the code does in the MATLAB function)
  local D_OUT="${DIR}/Thresholded-${T}/PCM_confidence_map_to_bin_all-networks_thresh-${T}.dscalar.nii"
  if [[ -f "$D_OUT" ]]; then
    echo "   Already found $D_OUT ... skipping."
    return
  fi

  echo "   Running threshold=$T for $DIR"
  local LOG_FILE="${DIR}/logs/matlab_threshold_${T}.log"
  mkdir -p "$(dirname "$LOG_FILE")"

  matlab -nodisplay -nosplash -r \
    "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); \
     addpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/'); \
     addpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'); \
     threshold_confidence_maps('${DIR}', ${percent_holdout}, ${T}); \
     exit;" \
  >> "${LOG_FILE}" 2>&1
}

###############################################################################
# 7) MAIN LOOPS
###############################################################################
# If user provides neither FIGDIR1 nor FIGDIR2, there's nothing to do:
if [[ -z "$FIGDIR1" && -z "$FIGDIR2" ]]; then
  echo "No figure directories provided. Exiting."
  exit 0
fi

# 7a) Process ExpData
if [[ -n "$FIGDIR1" ]]; then
  for EXP_MIN in "${MINUTES_EXP_LIST[@]}"
  do
    # If the user-supplied FIGDIR1 is *entirely* manual, remove this block:
    # But typically you might construct the directory if user didn't pass the path:
    THIS_FIGDIR1="${FIGDIR1}"
    # Or if user wants "ExpData" directories from BASEDIR:
    # THIS_FIGDIR1="${BASEDIR}/sub-${SUB}/ses-${SES}/ExpData-${EXP_MIN}/figures/Percent_Holdout-${percent_holdout}/ciftis/"
    # if [ ! -d "$THIS_FIGDIR1" ]; then
    #   echo "ExpData directory not found: $THIS_FIGDIR1 ... skipping"
    #   continue
    # fi

    echo "--------------------------------------------------------"
    echo "ExpData: $EXP_MIN -> $THIS_FIGDIR1"
    if [[ ! -d "$THIS_FIGDIR1" ]]; then
      echo "   Directory doesn't exist. Skipping."
      continue
    fi

    # Check for at least one .dscalar:
    found_dscalar=$(ls -1 "${THIS_FIGDIR1}"/*.dscalar.nii 2>/dev/null | wc -l)
    if [[ $found_dscalar -eq 0 ]]; then
      echo "   No .dscalar.nii in $THIS_FIGDIR1. Skipping."
      continue
    fi

    # Now loop thresholds
    for T in ${THRESHOLDS[@]}; do
      run_threshold_matlab "$THIS_FIGDIR1" "$T"
    done
  done
fi

# 7b) Process RefData
if [[ -n "$FIGDIR2" ]]; then
  for REF_MIN in "${MINUTES_REF_LIST[@]}"
  do
    THIS_FIGDIR2="${FIGDIR2}"
    # Or similarly build your path from BASEDIR if thats how you normally do it
    # THIS_FIGDIR2="${BASEDIR}/sub-${SUB}/ses-${SES}/RefData-${REF_MIN}/figures/Percent_Holdout-${percent_holdout}/ciftis/"
    echo "--------------------------------------------------------"
    echo "RefData: $REF_MIN -> $THIS_FIGDIR2"
    if [[ ! -d "$THIS_FIGDIR2" ]]; then
      echo "   Directory doesn't exist. Skipping."
      continue
    fi

    found_dscalar=$(ls -1 "${THIS_FIGDIR2}"/*.dscalar.nii 2>/dev/null | wc -l)
    if [[ $found_dscalar -eq 0 ]]; then
      echo "   No .dscalar.nii in $THIS_FIGDIR2. Skipping."
      continue
    fi

    for T in ${THRESHOLDS[@]}; do
      run_threshold_matlab "$THIS_FIGDIR2" "$T"
    done
  done
fi

echo "All done!"