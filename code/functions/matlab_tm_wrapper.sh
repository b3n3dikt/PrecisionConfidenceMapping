#!/bin/bash
# =============================================================================
# matlab_tm_wrapper.sh  —  Template Matching Shell Wrapper (METHOD=matlab_tm)
# =============================================================================
# Calls the MATLAB matlab_tm_wrapper() function for one permutation.
# Arguments are passed positionally from run_permutation.sh or
# run_standard_TM.sh. matlab_tm_wrapper.m in turn calls template_matching_RH,
# fetched into deps/matlab_tm/ by code/setup_matlab_tm.sh (run that first if
# this fails with "Undefined function 'template_matching_RH'").
#
# CHANGES FROM ORIGINAL twins_mapping_wrapper_washu_nordic.sh:
#   - Removed hardcoded addpath to server-specific analytics directory.
#     Now uses ${MATLAB_ADDPATH} from config.sh, which points to bundled deps.
#   - Removed hardcoded matlab_exec path (/common/software/.../R2019a/bin/matlab).
#     Now uses system `matlab` (loaded via `module load matlab` in the calling job).
#   - Added source of config.sh for portability.
#   - Renamed from twins_mapping_wrapper_washu_nordic.sh to match the renamed
#     matlab_tm_wrapper.m.
#
# ARGUMENT ORDER (matches matlab_tm_wrapper.m):
#   $1  = TR
#   $2  = FD threshold
#   $3  = dtseries input file
#   $4  = motion file (.mat)
#   $5  = left surface file (.surf.gii)
#   $6  = right surface file (.surf.gii)
#   $7  = output file name (prefix)
#   $8  = cifti output folder
#   $9  = template path (.mat)
#   $10 = surface_only flag (0/1/2)
#   $11 = already_surface_only (0)
#   $12 = output directory
#   $13 = dtseries conc file (same as $3 in PCM usage)
#   $14 = additional mask (path to .txt mask or "none")
#   $15 = run_infomap_too (hardcoded 0 — PCM never runs infomap)
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../config.sh"

X="${MATLAB_ADDPATH} matlab_tm_wrapper('${1}', '${2}', '${3}', '${4}', '${5}', '${6}', '${7}', '${8}', '${9}', '${10}', '${11}', '${12}', '${13}', '${14}', '0')"

RandomHash=$(cat /dev/urandom | tr -cd 'a-f0-9' | head -c 16)
TempCmd="matlab_command_${RandomHash}.m"

echo "${X}" > "${TempCmd}"
cat "${TempCmd}"
matlab -nodisplay -nosplash < "${TempCmd}"
rm -f "${TempCmd}"
