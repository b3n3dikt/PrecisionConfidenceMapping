#!/bin/bash -l

#SBATCH -J PCM_figs
#SBATCH --ntasks=1
#SBATCH --tmp=10gb
#SBATCH --mem=64gb
#SBATCH -t 1:00:00
# Partition and account are passed by orchestrate_PCM.sh at submission time (from cluster.conf).

# =============================================================================
# make_figs.sh  —  PCM Figure Generation Job
# =============================================================================
# Submitted by orchestrate_PCM.sh after all permutation jobs complete.
# Calls TM_dscalar_compare_across_permutations() to aggregate permutation
# dscalar outputs into probability maps and mode maps, then renders PNGs.
#
# CHANGES FROM ORIGINAL (make_figs_and_dscalars_Percent_holdout.sh):
#   - Removed hardcoded addpath to server TemplateShuffle directory.
#     Now uses ${MATLAB_ADDPATH} from config.sh, which points to bundled deps
#     and code/functions/ where TM_dscalar_compare_across_permutations.m lives.
#   - Uses system `matlab` (loaded via `module load matlab`) instead of
#     hardcoded /common/software path.
#   - Sources config.sh for MATLAB_ADDPATH.
# =============================================================================

source "${CODE_DIR}/config.sh"

echo "[make_figs DEBUG] CODE_DIR=${CODE_DIR}"
echo "[make_figs DEBUG] MATLAB_ADDPATH=${MATLAB_ADDPATH}"

TASK_DIR=${1}
dscalarswithassignments1=${2}
percent_holdout=${3}
make_NetConfMaps=${4}

module load "${WORKBENCH_MODULE}"
_real_wb="$(command -v wb_command)"
module load "${MATLAB_MODULE}"

# wb_command Qt shim — MATLAB R2019a's Qt5 shadows wb_command's Qt5.15.
# Strip MATLAB paths from LD_LIBRARY_PATH before every wb_command call.
_shim_dir="${TASK_DIR}/.wb_shim"
mkdir -p "${_shim_dir}"
cat > "${_shim_dir}/wb_command" << 'WBEOF'
#!/bin/bash
_ld=$(printf '%s' "${LD_LIBRARY_PATH}" | tr ':' '\n' | grep -Ev '/(matlab|MATLAB)/' | tr '\n' ':' | sed 's/:$//')
exec env LD_LIBRARY_PATH="${_ld}" __REAL_WB__ "$@"
WBEOF
sed -i "s|__REAL_WB__|${_real_wb}|" "${_shim_dir}/wb_command"
chmod +x "${_shim_dir}/wb_command"
export PATH="${_shim_dir}:${PATH}"

matlab -nodisplay -nosplash -r \
    "${MATLAB_ADDPATH} \
     TM_dscalar_compare_across_permutations('${TASK_DIR}', '${dscalarswithassignments1}', '${percent_holdout}', ${make_NetConfMaps}); exit;"
