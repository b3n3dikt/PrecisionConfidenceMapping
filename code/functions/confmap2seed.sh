#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ARGS_PT=()
MOTION_CONC=""
REGION_FLAG="all"          # default = generate *all* families

argv=("$@")
for ((i=0; i<${#argv[@]}; i++)); do
    arg="${argv[$i]}"
    case "$arg" in
        --motion_conc)
            MOTION_CONC="${argv[$((i+1))]}"
            ((i++))
            ;;
        --region)
            REGION_FLAG="${argv[$((i+1))]}"
            ((i++))
            ;;
        *) ARGS_PT+=("$arg") ;;
    esac
done

############################################################################
# 1.  Run the Workbench mini-pipeline (v3)
#     IMPORTANT: forward --region so ctx isn't attempted when REGION_FLAG=wb
############################################################################
"${SCRIPT_DIR}/confmap_to_ptseries_v3.sh" "${ARGS_PT[@]}" --region "${REGION_FLAG}"

############################################################################
# 2.  Parse *all* flags a second time so we know where outputs live
############################################################################
DTSERIES="" OUTDIR="" LABEL_BASE="Clusters" THR="" L_SURF="" R_SURF=""
for ((i=0; i<${#argv[@]}; i++)); do
    case "${argv[$i]}" in
        --dtseries)    DTSERIES="${argv[$((i+1))]}"; ((i++));;
        --outdir)      OUTDIR="${argv[$((i+1))]}";   ((i++));;
        --label_base)  LABEL_BASE="${argv[$((i+1))]}"; ((i++));;
        --thr)         THR="${argv[$((i+1))]}";      ((i++));;
        --left_surf)   L_SURF="${argv[$((i+1))]}";   ((i++));;
        --right_surf)  R_SURF="${argv[$((i+1))]}";   ((i++));;
    esac
done

for v in DTSERIES OUTDIR THR MOTION_CONC; do
  [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
done
[[ -d "$OUTDIR" ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }

if [[ "$REGION_FLAG" == "all" ]]; then
    REGIONS=(wb ctx)
else
    REGIONS=("$REGION_FLAG")
fi

for region in "${REGIONS[@]}"; do
    CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-thr${THR}.ptseries.nii"
    BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-thr${THR}.ptseries.nii"

    for f in "$CLUST_PTSERIES" "$BIN_PTSERIES"; do
        [[ -f "$f" ]] || { echo "ERROR: missing $f  check --thr / --region"; exit 1; }
    done

    echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
    echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"

    if [[ "${#REGIONS[@]}" -eq 1 ]]; then
        echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt.conc"
        echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt.conc"
    fi
done

echo "$DTSERIES"    > "${OUTDIR}/dt.conc"
echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"
[[ -n "$L_SURF" ]] && echo "$L_SURF" > "${OUTDIR}/left_surf.conc"
[[ -n "$R_SURF" ]] && echo "$R_SURF" > "${OUTDIR}/right_surf.conc"


# #!/usr/bin/env bash
# # ----------------------------------------------------------------------
# # confmap2seed_v3.sh      conf-map  clusters  ptseries  helper .conc files
# #    compatible with confmap_to_ptseries_v3.sh
# #
# #   DEFAULT: build helper files for wb, ctx families
# #   OPTIONAL: --region <wb|ctx>   build only that family
# # ----------------------------------------------------------------------
# set -euo pipefail
# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ############################################################################
# # 0.  First pass over argv
# #     " build ARGS_PT  (what we send to confmap_to_ptseries_v3.sh)
# #     " capture MOTION_CONC and REGION, drop them from ARGS_PT
# ############################################################################
# ARGS_PT=()
# MOTION_CONC=""
# REGION_FLAG="all"          # default = generate *all* families

# argv=("$@")                # make an indexable copy
# for ((i=0; i<${#argv[@]}; i++)); do
#     arg="${argv[$i]}"
#     case "$arg" in
#         --motion_conc)
#             MOTION_CONC="${argv[$((i+1))]}"
#             ((i++))                      # skip its value
#             ;;
#         --region)
#             REGION_FLAG="${argv[$((i+1))]}"
#             ((i++))
#             ;;
#         *) ARGS_PT+=("$arg") ;;
#     esac
# done

# ############################################################################
# # 1.  Run the Workbench mini-pipeline (v3)
# ############################################################################
# "${SCRIPT_DIR}/confmap_to_ptseries_v3.sh" "${ARGS_PT[@]}"

# ############################################################################
# # 2.  Parse *all* flags a second time so we know where outputs live
# ############################################################################
# DTSERIES="" OUTDIR="" LABEL_BASE="Clusters" THR="" L_SURF="" R_SURF=""
# for ((i=0; i<${#argv[@]}; i++)); do
#     case "${argv[$i]}" in
#         --dtseries)    DTSERIES="${argv[$((i+1))]}"; ((i++));;
#         --outdir)      OUTDIR="${argv[$((i+1))]}";   ((i++));;
#         --label_base)  LABEL_BASE="${argv[$((i+1))]}"; ((i++));;
#         --thr)         THR="${argv[$((i+1))]}";      ((i++));;
#         --left_surf)   L_SURF="${argv[$((i+1))]}";   ((i++));;
#         --right_surf)  R_SURF="${argv[$((i+1))]}";   ((i++));;
#     esac
# done

# # ----------------------------------------------------------------------
# # 3.  Sanity checks
# # ----------------------------------------------------------------------
# for v in DTSERIES OUTDIR THR MOTION_CONC; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# [[ -d "$OUTDIR" ]] || { echo "ERROR: outdir $OUTDIR not found"; exit 1; }

# ############################################################################
# # 4.  Decide which region families to process
# ############################################################################
# if [[ "$REGION_FLAG" == "all" ]]; then
#     REGIONS=(wb ctx)
# else
#     REGIONS=("$REGION_FLAG")
# fi

# ############################################################################
# # 5.  For each requested region family &
# #      verify ptseries exist
# #      write region-specific .conc files
# #      if only one region was requested, also write the legacy
# #       clust_pt.conc / bin_pt.conc names for backward-compatibility
# ############################################################################
# for region in "${REGIONS[@]}"; do
#     CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_clust-thr${THR}.ptseries.nii"
#     BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_${region}_bin-thr${THR}.ptseries.nii"

#     for f in "$CLUST_PTSERIES" "$BIN_PTSERIES"; do
#         [[ -f "$f" ]] || { echo "ERROR: missing $f  check --thr / --region"; exit 1; }
#     done

#     echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt_${region}.conc"
#     echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt_${region}.conc"

#     # If *only* one region requested, also create the traditional names.
#     if [[ "${#REGIONS[@]}" -eq 1 ]]; then
#         echo "$CLUST_PTSERIES" > "${OUTDIR}/clust_pt.conc"
#         echo "$BIN_PTSERIES"   > "${OUTDIR}/bin_pt.conc"
#     fi
# done

# ############################################################################
# # 6.  Always-needed helper conc files
# ############################################################################
# echo "$DTSERIES"    > "${OUTDIR}/dt.conc"
# echo "$MOTION_CONC" > "${OUTDIR}/motion.conc"

# # optional surf concs for downstream Fair-lab wrappers
# [[ -n "$L_SURF" ]] && echo "$L_SURF" > "${OUTDIR}/left_surf.conc"
# [[ -n "$R_SURF" ]] && echo "$R_SURF" > "${OUTDIR}/right_surf.conc"

# echo " Helper .conc files written to $OUTDIR"
# [[ "$REGION_FLAG" == "all" ]] \
#     && echo "  (families: wb, ctx)" \
#     || echo "  (family:  $REGION_FLAG)"




 
    
#     #!/usr/bin/env bash
# # ----------------------------------------------------------------------
# # confmap2seed.sh    confidence-map  clusters  seed-connectivity maps
# # ----------------------------------------------------------------------
# set -euo pipefail

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ############################################################################
# # 0.  Separate argv into:
# #       " ARGS_PT    passed to confmap_to_ptseries.sh   (no motion flag)
# #       " ARGS_SELF  used later for seed-map generation (keeps everything)
# ############################################################################
# ############################################################################
# # 0.  Split argv  (a) args for Workbench  (b) everything for seed step
# ############################################################################
# ARGS_PT=()              #  forwarded to confmap_to_ptseries.sh
# MOTION_CONC=""

# skip_next=false
# for arg in "$@"; do
#     if $skip_next; then        # skip the *value* of --motion_conc
#         skip_next=false
#         continue
#     fi

#     case "$arg" in
#         --motion_conc)
#             skip_next=true     # drop flag AND next token
#             ;;
#         *)
#             ARGS_PT+=("$arg")  # keep all other args
#             ;;
#     esac
# done

# ############################################################################
# # 1. Run Workbench pipeline with filtered arguments
# ############################################################################
# "${SCRIPT_DIR}/confmap_to_ptseries_v3.sh" "${ARGS_PT[@]}"

# ############################################################################
# # 2. Parse **all** flags (including --motion_conc) for seed-map step
# ############################################################################
# THR="" OUTDIR="" LABEL_BASE="Clusters" DTSERIES="" L_SURF="" R_SURF=""
# while [[ $# -gt 0 ]]; do
#   case "$1" in
#       --dtseries)     DTSERIES=$2;    shift 2;;
#       --outdir)       OUTDIR=$2;      shift 2;;
#       --left_surf)    L_SURF=$2;      shift 2;;
#       --right_surf)   R_SURF=$2;      shift 2;;
#       --label_base)   LABEL_BASE=$2;  shift 2;;
#       --thr)          THR=$2;         shift 2;;
#       --motion_conc)  MOTION_CONC=$2; shift 2;;
#       *) shift 1;;
#   esac
# done

# # ----------------------------------------------------------------------
# # 3. Sanity checks
# # ----------------------------------------------------------------------
# for v in THR OUTDIR DTSERIES L_SURF R_SURF MOTION_CONC; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# CLUST_PTSERIES="${OUTDIR}/${LABEL_BASE}_clust-thr${THR}.ptseries.nii"
# [[ -f "${CLUST_PTSERIES}" ]] || { echo "ERROR: missing ptseries ${CLUST_PTSERIES}"; exit 1; }

# BIN_PTSERIES="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.ptseries.nii"
# [[ -f "${BIN_PTSERIES}" ]] || { echo "ERROR: missing ptseries ${BIN_PTSERIES}"; exit 1; }

# #SEEDMAP_DIR="${OUTDIR}/seedMaps"
# #mkdir -p "${SEEDMAP_DIR}"

# # ----------------------------------------------------------------------
# # 4. Helper .conc files (Fair-lab utilities expect single-line lists)
# # ----------------------------------------------------------------------
# echo "${DTSERIES}"   > "${OUTDIR}/dt.conc"
# echo "${CLUST_PTSERIES}"   > "${OUTDIR}/clust_pt.conc"
# echo "${BIN_PTSERIES}"   > "${OUTDIR}/bin_pt.conc"
# echo "${MOTION_CONC}" > "${OUTDIR}/motion.conc"
# echo "${L_SURF}"     > "${OUTDIR}/left_surf.conc"
# echo "${R_SURF}"     > "${OUTDIR}/right_surf.conc"

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


# #!/usr/bin/env bash
# # ----------------------------------------------------------------------
# # confmap2seed.sh    confidence-map  clusters  seed-connectivity maps
# # ----------------------------------------------------------------------
# set -euo pipefail

# SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ############################################################################
# # 0.  Separate argv into:
# #       " ARGS_PT    passed to confmap_to_ptseries.sh   (no motion flag)
# #       " ARGS_SELF  used later for seed-map generation (keeps everything)
# ############################################################################
# ############################################################################
# # 0.  Split argv  (a) args for Workbench  (b) everything for seed step
# ############################################################################
# ARGS_PT=()              #  forwarded to confmap_to_ptseries.sh
# MOTION_CONC=""

# skip_next=false
# for arg in "$@"; do
#     if $skip_next; then        # skip the *value* of --motion_conc
#         skip_next=false
#         continue
#     fi

#     case "$arg" in
#         --motion_conc)
#             skip_next=true     # drop flag AND next token
#             ;;
#         *)
#             ARGS_PT+=("$arg")  # keep all other args
#             ;;
#     esac
# done

# ############################################################################
# # 1. Run Workbench pipeline with filtered arguments
# ############################################################################
# "${SCRIPT_DIR}/confmap_to_ptseries.sh" "${ARGS_PT[@]}"

# ############################################################################
# # 2. Parse **all** flags (including --motion_conc) for seed-map step
# ############################################################################
# THR="" OUTDIR="" LABEL_BASE="Clusters" DTSERIES="" L_SURF="" R_SURF=""
# while [[ $# -gt 0 ]]; do
#   case "$1" in
#       --dtseries)     DTSERIES=$2;    shift 2;;
#       --outdir)       OUTDIR=$2;      shift 2;;
#       --left_surf)    L_SURF=$2;      shift 2;;
#       --right_surf)   R_SURF=$2;      shift 2;;
#       --label_base)   LABEL_BASE=$2;  shift 2;;
#       --thr)          THR=$2;         shift 2;;
#       --motion_conc)  MOTION_CONC=$2; shift 2;;
#       *) shift 1;;
#   esac
# done

# # ----------------------------------------------------------------------
# # 3. Sanity checks
# # ----------------------------------------------------------------------
# for v in THR OUTDIR DTSERIES L_SURF R_SURF MOTION_CONC; do
#   [[ -z "${!v}" ]] && { echo "ERROR: --${v,,} is required"; exit 1; }
# done
# PTSERIES="${OUTDIR}/${LABEL_BASE}_thr${THR}.ptseries.nii"
# [[ -f "${PTSERIES}" ]] || { echo "ERROR: missing ptseries ${PTSERIES}"; exit 1; }

# SEEDMAP_DIR="${OUTDIR}/seedMaps"
# mkdir -p "${SEEDMAP_DIR}"

# # ----------------------------------------------------------------------
# # 4. Helper .conc files (Fair-lab utilities expect single-line lists)
# # ----------------------------------------------------------------------
# echo "${DTSERIES}"   > "${OUTDIR}/dt.conc"
# echo "${PTSERIES}"   > "${OUTDIR}/pt.conc"
# echo "${MOTION_CONC}" > "${OUTDIR}/motion.conc"
# echo "${L_SURF}"     > "${OUTDIR}/left_surf.conc"
# echo "${R_SURF}"     > "${OUTDIR}/right_surf.conc"

# # ----------------------------------------------------------------------
# # 5. Headless MATLAB call
# # ----------------------------------------------------------------------
# # Default FD threshold in make_seedmap is already 0.2; override by adding
# # ... 'FdThresh',0.25, ... inside the call if you need another value.
# matlab -batch "addpath('${SCRIPT_DIR}'); \
# make_seedmap('${PTSERIES}', '${OUTDIR}/dt.conc', '${OUTDIR}/motion.conc', \
# '${OUTDIR}/left_surf.conc', '${OUTDIR}/right_surf.conc', \
# 'OutDir', '${SEEDMAP_DIR}');"

# echo "  Seed-maps written to ${SEEDMAP_DIR}"
# #!/usr/bin/env bash
# #
# # confmap_to_ptseries.sh    generic Workbench mini-pipeline
# #
# # (1) binarise a confidence map at a chosen threshold
# # (2) find surface-based clusters in that binary map
# # (3) convert clusters to a .dlabel
# # (4) parcellate a dtseries  ptseries
# #
# # Requires:  wb_command e v1.5  |  bash e 4
# # Usage:     ./confmap_to_ptseries.sh --confmap scan_conf.dscalar.nii \
# #               --dtseries rest_8m.dtseries.nii \
# #               --left_surf sub-01_L.midthickness.gii \
# #               --right_surf sub-01_R.midthickness.gii \
# #               --thr 0.99  --outdir results/scan_thr-0.99
# # ---------------------------------------------------------------------------

# set -euo pipefail

# ##############################################################################
# #  Argument parsing
# ##############################################################################
# print_help () {
# cat <<EOF
# USAGE:
#   $(basename "$0") --confmap  PATH.dscalar.nii  \\
#                    --dtseries PATH.dtseries.nii \\
#                    --left_surf PATH_L.surf.gii  \\
#                    --right_surf PATH_R.surf.gii \\
#                    [--thr 0.99]                 \\
#                    [--min_thr 0.1]              \\
#                    [--min_area 100]             \\
#                    [--outdir PATH]              \\
#                    [--label_base NAME]          \\
#                    [--help]

# OPTIONS
#   --confmap     Confidence-map dscalar to threshold
#   --dtseries    Dense time-series you want to parcellate
#   --left_surf   Subject-specific (or atlas) L midthickness
#   --right_surf  Subject-specific (or atlas) R midthickness
#   --thr         Binarisation threshold           (default: 0.99)
#   --min_thr     min-threshold for wb_command -cifti-find-clusters
#   --min_area    min-area     for wb_command -cifti-find-clusters
#   --label_base  Stem used to name intermediate files
#   --outdir      Where outputs go (default: <confmap_dir>/Thresholded-<thr>)
# EOF
# }

# # defaults
# THR=0.99
# MIN_THR=0.1
# MIN_AREA=100
# OUTDIR=""
# LABEL_BASE="Clusters"

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
#     --help|-h)    print_help; exit 0;;
#     *) echo "Unknown option $1"; print_help; exit 1;;
#   esac
# done

# ##############################################################################
# #  Sanity checks
# ##############################################################################
# for req in CONFMAP DTSERIES LEFT_SURF RIGHT_SURF; do
#   [[ -z "${!req:-}" ]] && { echo "ERROR: --${req,,} is required"; exit 1; }
#   [[ -f "${!req}" ]]   || { echo "ERROR: file not found: ${!req}"; exit 1; }
# done
# command -v wb_command &>/dev/null || { echo "ERROR: wb_command not on PATH"; exit 1; }

# [[ -z "$OUTDIR" ]] && OUTDIR="$(dirname "$CONFMAP")/Thresholded-${THR}"
# mkdir -p "$OUTDIR"

# ##############################################################################
# #  Derived file names
# ##############################################################################
# BIN_DSCAL="${OUTDIR}/${LABEL_BASE}_bin-thr${THR}.dscalar.nii"
# CLUST_DSC="${OUTDIR}/${LABEL_BASE}_thr${THR}.dscalar.nii"
# CLUST_DLAB="${OUTDIR}/${LABEL_BASE}_thr${THR}.dlabel.nii"
# PTSERIES="${OUTDIR}/${LABEL_BASE}_thr${THR}.ptseries.nii"

# ##############################################################################
# #  1. Binarise
# ##############################################################################
# echo "Step 1  |  Binarising ${CONFMAP} at > ${THR}"
# wb_command -cifti-math "x > ${THR}" "$BIN_DSCAL" -var x "$CONFMAP"

# ##############################################################################
# #  2. Find clusters
# ##############################################################################
# echo "Step 2  |  Finding clusters  (min_thr=${MIN_THR}, min_area=${MIN_AREA})"
# wb_command -cifti-find-clusters "$BIN_DSCAL" \
#             "$MIN_THR" "$MIN_AREA" "$MIN_THR" "$MIN_AREA" COLUMN \
#             "$CLUST_DSC" \
#             -left-surface  "$LEFT_SURF" \
#             -right-surface "$RIGHT_SURF"

# ##############################################################################
# #  3. Label import
# ##############################################################################
# echo "Step 3  |  Converting to dlabel"
# wb_command -cifti-label-import "$CLUST_DSC" /dev/null "$CLUST_DLAB"

# ##############################################################################
# #  4. Parcellate dtseries
# ##############################################################################
# echo "Step 4  |  Parcellating dtseries  ptseries"
# wb_command -cifti-parcellate "$DTSERIES" "$CLUST_DLAB" COLUMN "$PTSERIES"

# echo -e "\n  Finished!  Output ptseries:\n    $PTSERIES"