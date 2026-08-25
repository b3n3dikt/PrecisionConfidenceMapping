#!/bin/bash -l

#SBATCH -J PCM_standardTM
#SBATCH --ntasks=1
#SBATCH --tmp=100gb
#SBATCH --mem=110gb
#SBATCH -t 10:00:00
# Partition and account are passed by orchestrate_PCM.sh at submission time (from cluster.conf).
#SBATCH -o /tmp/StandardTM_%A.out
#SBATCH -e /tmp/StandardTM_%A.err

# =============================================================================
# run_standard_TM.sh  —  Standard (non-shuffled) Template Matching
# =============================================================================
# Runs template matching on the real (unshuffled) dtseries. Produces a single
# network assignment map that serves as the "ground truth" reference — useful
# for comparing against the PCM confidence maps. Triggered when STANDARDTM=1.
# =============================================================================

# Use CODE_DIR exported by run_PCM.sh (inherited via SLURM --export=ALL).
# Fall back to BASH_SOURCE path detection only when running from the script's
# actual location (e.g., manual testing), not from a SLURM spool copy.
if [[ -z "${CODE_DIR}" ]]; then
    CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "${CODE_DIR}/config.sh"

SUB=${1}; SES=${2}; TASK=${3}; FD=${4}; NUM=${5}; MIN=${6}; S_KERNEL=${7}
dtseries_in=${8}; BASEDIR=${9}; surf_L=${10}; surf_R=${11}; motion_file=${12}
TEMPLATE_PATH=${13}; SURF_ONLY=${14}; intrp_noise=${15}
shuffle_option=${16}; percent_chunk_size=${17}; percent_holdout=${18}
SPLITHALF=${19}; SPLITPCT=${20}; STANDARDTM=${21}; TR=${22}

module load "${WORKBENCH_MODULE}"
_real_wb="$(command -v wb_command)"
module load "${MATLAB_MODULE}"

if [[ -z "${TR}" ]]; then
    TR=$(${WB_CMD} -file-information "${dtseries_in}" -only-step-interval)
fi

if [[ -n "${SCRATCH_DIR}" ]]; then
    work_dir="${SCRATCH_DIR}/sub-${SUB}/ses-${SES}/${TASK}/standard"
    echo "[StandardTM] SCRATCH_DIR set — intermediates will persist at: ${work_dir}"
else
    work_dir="/tmp/sub-${SUB}/ses-${SES}/${TASK}/standard"
fi
mkdir -p "${work_dir}"

cat > "${work_dir}/wb_command" << 'WBEOF'
#!/bin/bash
_ld=$(printf '%s' "${LD_LIBRARY_PATH}" | tr ':' '\n' | grep -Ev '/(matlab|MATLAB)/' | tr '\n' ':' | sed 's/:$//')
exec env LD_LIBRARY_PATH="${_ld}" __REAL_WB__ "$@"
WBEOF
sed -i "s|__REAL_WB__|${_real_wb}|" "${work_dir}/wb_command"
chmod +x "${work_dir}/wb_command"
export PATH="${work_dir}:${PATH}"
out_dir="${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/standard"
mkdir -p "${out_dir}"

pushd "${work_dir}" || exit 1

# ── Derive label from SURF_ONLY for output directory naming ───────────────────
# dtseries_in, surf_L, surf_R, motion_file, TEMPLATE_PATH all come from args.
if [[ "${SURF_ONLY}" == "0" ]]; then
    SURF_ONLY_LABEL="subcort_included"; TEMPLATE_LABEL="abcd"
elif [[ "${SURF_ONLY}" == "1" ]]; then
    SURF_ONLY_LABEL="surfonly"; TEMPLATE_LABEL="abcd"
else
    SURF_ONLY_LABEL="SCAN_network"; TEMPLATE_LABEL="abcd-SCAN"
fi

# ── Handle motion file for TM wrapper ─────────────────────────────────────────
case "${motion_file}" in
    *.txt)
        cp "${motion_file}" "${work_dir}/"
        motion_for_tm="${work_dir}/$(basename "${motion_file}")"
        ;;
    *.mat)
        cp "${motion_file}" "${work_dir}/"
        motion_for_tm="${work_dir}/$(basename "${motion_file}")"
        ;;
    *)
        echo "[ERROR StandardTM] Unexpected motion file extension: ${motion_file}"; exit 1
        ;;
esac

OUTDIR="${work_dir}/standard"
OUTSAVE="${out_dir}"
mkdir -p "${OUTDIR}" "${OUTSAVE}"

# Run template matching on the unshuffled dtseries (mask="none" = use all frames)
"${TM_WRAPPER}" \
    "${TR}" "${FD}" \
    "${dtseries_in}" \
    "${motion_for_tm}" \
    "${surf_L}" "${surf_R}" \
    "sub-${SUB}_ses-${SES}_${TEMPLATE_LABEL}_TM_standard" \
    "${OUTDIR}" "${TEMPLATE_PATH}" "${SURF_ONLY}" "0" "${OUTDIR}" \
    "${dtseries_in}" "none"

cp "${OUTDIR}"/*.dscalar.nii "${OUTSAVE}/" 2>/dev/null
cp "${OUTDIR}"/*.mat "${OUTSAVE}/" 2>/dev/null
ls "${OUTSAVE}"/*recolored.dscalar.nii >> \
    "${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/standard_recolored.conc" 2>/dev/null

popd
echo "[StandardTM] Done. Outputs in ${out_dir}"
