#!/bin/bash -l

# SLURM headers below are defaults — all are overridden at submission time
# by orchestrate_PCM.sh via sbatch command-line flags.
#SBATCH -J PCM_perm
#SBATCH --ntasks=1
#SBATCH --tmp=100gb
#SBATCH --mem=110gb
#SBATCH -t 10:00:00
# Partition and account are passed by orchestrate_PCM.sh at submission time (from cluster.conf).
#SBATCH -o /tmp/PCM_%A_%a.out
#SBATCH -e /tmp/PCM_%A_%a.err

# =============================================================================
# run_permutation.sh  —  Single PCM Permutation Job
# =============================================================================
# One instance of this script runs per bootstrap permutation. It is submitted
# N times by orchestrate_PCM.sh (one per permutation number).
#
# What it does:
#   1. Sets up a /tmp working directory to hold the 36GB .dconn.nii intermediate
#   2. Copies the motion file to /tmp (handling both .mat and .txt formats)
#   3. Calls MATLAB shuffle function → writes shuffled dtseries + masks to /tmp
#   4. Calls template matching wrapper → assigns each brain vertex to a network
#   5. Copies outputs from /tmp to persistent BASEDIR storage
#
# WHY /tmp: The dense connectivity matrix (dconn) computed during template
# matching is ~36GB. Using /tmp (node-local scratch) avoids saturating the
# shared filesystem. Data is copied to BASEDIR only after completion.
# =============================================================================

# Use CODE_DIR exported by run_PCM.sh (inherited via SLURM --export=ALL).
# Fall back to BASH_SOURCE path detection only when running from the script's
# actual location (e.g., manual testing), not from a SLURM spool copy.
if [[ -z "${CODE_DIR}" ]]; then
    CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "${CODE_DIR}/config.sh"

# ── Parse arguments (passed by orchestrate_PCM.sh) ────────────────────────────
SUB=${1}
SES=${2}
TASK=${3}
FD=${4}
NUM=${5}        # This permutation's number (1..N)
MIN=${6}
S_KERNEL=${7}
dtseries_in=${8}
BASEDIR=${9}
surf_L=${10}
surf_R=${11}
motion_file=${12}
TEMPLATE_PATH=${13}
SURF_ONLY=${14}
intrp_noise=${15}
shuffle_option=${16}
percent_chunk_size=${17}
percent_holdout=${18}
SPLITHALF=${19}
SPLITPCT=${20}
TR=${21}

echo "[perm-${NUM}] $(date '+%Y-%m-%d %H:%M:%S') Starting sub-${SUB} ses-${SES} task-${TASK}"
echo "[perm-${NUM}] shuffle=${shuffle_option} SPLITPCT=${SPLITPCT} SPLITHALF=${SPLITHALF}"

module load "${WORKBENCH_MODULE}"
# Capture the real wb_command path before MATLAB modifies LD_LIBRARY_PATH.
_real_wb="$(command -v wb_command)"

module load "${MATLAB_MODULE}"

# ── Get TR if not provided ────────────────────────────────────────────────────
if [[ -z "${TR}" ]]; then
    TR=$(${WB_CMD} -file-information "${dtseries_in}" -only-step-interval)
fi

# ── Set up working directory ──────────────────────────────────────────────────
# Default: /tmp (node-local scratch, fast, deleted after job).
# If SCRATCH_DIR is set, use it instead so intermediates persist for debugging.
# WARNING: each perm's dconn is tens of GB — only set SCRATCH_DIR for a small NUM.
if [[ -n "${SCRATCH_DIR}" ]]; then
    work_dir="${SCRATCH_DIR}/sub-${SUB}/ses-${SES}/${TASK}/${NUM}"
    echo "[perm-${NUM}] SCRATCH_DIR set — intermediates will persist at: ${work_dir}"
else
    work_dir="/tmp/sub-${SUB}/ses-${SES}/${TASK}/${NUM}"
fi
mkdir -p "${work_dir}"
echo "[perm-${NUM}] work_dir: ${work_dir}"
df -h "${work_dir}"

# ── wb_command Qt shim ────────────────────────────────────────────────────────
# MATLAB R2019a prepends its own Qt5 libs to LD_LIBRARY_PATH. wb_command 2.x
# links against a newer Qt5.15 that has symbols missing from MATLAB's Qt5,
# causing a "symbol lookup error" when wb_command is called via system() from
# inside MATLAB. Fix: put a wrapper first on PATH that strips the MATLAB Qt5
# entries before exec-ing the real binary.
cat > "${work_dir}/wb_command" << 'WBEOF'
#!/bin/bash
_ld=$(printf '%s' "${LD_LIBRARY_PATH}" | tr ':' '\n' | grep -Ev '/(matlab|MATLAB)/' | tr '\n' ':' | sed 's/:$//')
exec env LD_LIBRARY_PATH="${_ld}" __REAL_WB__ "$@"
WBEOF
sed -i "s|__REAL_WB__|${_real_wb}|" "${work_dir}/wb_command"
chmod +x "${work_dir}/wb_command"
export PATH="${work_dir}:${PATH}"

_perm_pad=$(printf '%04d' "${NUM}")
out_dir="${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/perms/perm-${_perm_pad}"
mkdir -p "${out_dir}"

pushd "${work_dir}" || exit 1

# ── Derive motion type from file extension ────────────────────────────────────
# hdf5 was already converted to .mat in run_PCM.sh before job submission.
case "${motion_file}" in
    *.mat) MOTION_TYPE="mat" ;;
    *.txt) MOTION_TYPE="txt" ;;
    *) echo "[ERROR perm-${NUM}] Unexpected motion file extension: ${motion_file}"; exit 1 ;;
esac

# ── Copy motion file to work_dir ──────────────────────────────────────────────
if [[ "${MOTION_TYPE}" == "txt" ]]; then
    cp "${motion_file}" "${work_dir}/"
    motion_txt_arg="'${work_dir}/$(basename "${motion_file}")'"
    echo "[perm-${NUM}] Using binary txt motion mask: ${motion_file}"
else
    # Copy .mat to work_dir with the canonical name that
    # motion_and_dtseries_bagging_cleaned.m expects.
    cp "${motion_file}" \
        "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-dcan_qc_power_2014_FD_only.mat"
    motion_txt_arg="''"
    echo "[perm-${NUM}] Motion file: ${motion_file}"
fi

# ── MATLAB: shuffle time series and create masks ───────────────────────────────
# motion_and_dtseries_bagging_cleaned.m does three things:
#   a) Filters out high-motion frames (FD > threshold)
#   b) Resamples the remaining frames according to the chosen shuffle method
#   c) Writes the shuffled dtseries and binary TR-selection masks to /tmp
echo "[perm-${NUM}] $(date '+%H:%M:%S') Running MATLAB shuffle..."
matlab -nodisplay -nosplash -r \
    "${MATLAB_ADDPATH} \
     motion_and_dtseries_bagging_cleaned( \
         '${SUB}', '${SES}', ${FD}, '${TASK}', ${TR}, ${MIN}, ${NUM}, \
         '${work_dir}', '${dtseries_in}', '${BASEDIR}', ${intrp_noise}, \
         '${shuffle_option}', ${percent_chunk_size}, ${percent_holdout}, ${motion_txt_arg}); exit;"

# ── Community detection ────────────────────────────────────────────────────────
if [[ "${METHOD}" == "reprotm" ]]; then

    # ── ReproTM pipeline (Godfrey et al.) ────────────────────────────────────
    # Builds its dconn the same way matlab_tm does (smooth -> cifti_connectivity
    # -> sectional Zscore), then runs ReproTM template matching (Python) on the
    # z-scored dconn, followed by minimum-size cluster cleanup (Python).

    # ReproTM needs nibabel + scipy + numpy, which the cluster's default python3
    # usually lacks. The interpreter is configurable via REPROTM_PYTHON
    # (config.sh / cluster.conf). Do NOT `module load python3`.
    _reprotm_py="${REPROTM_PYTHON:-python3}"

    # Preflight: verify the interpreter has the deps BEFORE the ~40 min dconn
    # build, so a misconfigured environment fails in seconds with a clear message.
    if ! "${_reprotm_py}" -c "import nibabel, numpy, scipy" 2>/dev/null; then
        echo "[ERROR perm-${NUM}] REPROTM_PYTHON='${_reprotm_py}' cannot import nibabel/numpy/scipy."
        echo "    Fix one of these, then re-run:"
        echo "    - Set REPROTM_PYTHON in cluster.conf to a python that has them (e.g. a conda env's python)"
        echo "    - Or install for the current python:  ${_reprotm_py} -m pip install --user nibabel scipy numpy"
        exit 1
    fi

    shuffled_dts="${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii"
    perm_name="sub-${SUB}_ses-${SES}_task-${TASK}_perm-${NUM}"

    # Step 1a: Smooth dtseries
    dts_for_dconn="${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries_smoothed.dtseries.nii"
    if [[ "${SMOOTHING_KERNEL:-2.25}" == "0" ]]; then
        echo "[perm-${NUM}] Smoothing disabled (SMOOTHING_KERNEL=0)"
        dts_for_dconn="${shuffled_dts}"
    elif [[ -n "${SCRATCH_DIR}" && -f "${dts_for_dconn}" ]]; then
        echo "[perm-${NUM}] Smoothed dtseries found on scratch, skipping: $(basename "${dts_for_dconn}")"
    else
        echo "[perm-${NUM}] $(date '+%H:%M:%S') Smoothing dtseries (${SMOOTHING_KERNEL} mm sigma)..."
        wb_command -cifti-smoothing \
            "${shuffled_dts}" \
            "${SMOOTHING_KERNEL}" "${SMOOTHING_KERNEL}" COLUMN \
            "${dts_for_dconn}" \
            -left-surface "${surf_L}" \
            -right-surface "${surf_R}"
        if [[ ! -f "${dts_for_dconn}" ]]; then
            echo "[ERROR perm-${NUM}] Smoothed dtseries not created: ${dts_for_dconn}"; exit 1
        fi
    fi

    # Step 1b: dconn from (smoothed) dtseries (Pearson r, optionally Fisher-z per FISHER_Z — z-scoring follows).
    dconn_outdir="${work_dir}/dconn"
    mkdir -p "${dconn_outdir}"
    _dts_stem="$(basename "${dts_for_dconn}" .nii)"
    _dts_stem="${_dts_stem%.dtseries}"
    dconn_file="${dconn_outdir}/${_dts_stem}_dconn.dconn.nii"

    if [[ -n "${SCRATCH_DIR}" && -f "${dconn_file}" ]]; then
        echo "[perm-${NUM}] dconn found on scratch, skipping: $(basename "${dconn_file}")"
    else
        echo "[perm-${NUM}] $(date '+%H:%M:%S') Creating dconn via cifti_connectivity (minutes/smoothing already applied upstream, passed as 'none'; motion censoring is a no-op re-check here -- see REMOVE_OUTLIERS below for why a motion file is still passed)..."
        # cifti_connectivity's outlier-removal logic only runs in its
        # "motion file provided" code path (it's not independently reachable
        # with motion_file='none') -- so REMOVE_OUTLIERS=1 requires passing
        # the real post-shuffle filtered mask here, even though FD-based
        # censoring itself is already a no-op (bagging/shuffle already
        # marked every remaining frame "good"). When REMOVE_OUTLIERS=0, skip
        # that branch entirely via motion_file='none', same as before.
        if [[ "${REMOVE_OUTLIERS:-1}" == "1" ]]; then
            _motion_arg="${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat"
            _dtseries_conc_arg="${dts_for_dconn}"
        else
            _motion_arg="none"
            _dtseries_conc_arg="none"
        fi
        matlab -nodisplay -nosplash -r " \
            ${MATLAB_ADDPATH} \
            [dconn_out, ~] = cifti_conn_matrix_for_wrapper_continous('${WB_CMD}', '${dts_for_dconn}', 'dtseries', '${_motion_arg}', ${FD}, ${TR}, 'none', 'none', 'none', 'none', 0, ${REMOVE_OUTLIERS:-1}, 'none', 0, '${dconn_outdir}/', '${_dtseries_conc_arg}', 0, 'none'); \
            movefile(dconn_out, '${dconn_file}'); \
            exit; \
        "
        if [[ ! -f "${dconn_file}" ]]; then
            echo "[ERROR perm-${NUM}] dconn not found: ${dconn_file}"; exit 1
        fi
    fi
    echo "[perm-${NUM}] $(date '+%H:%M:%S') dconn ready: ${dconn_file}"

    # Step 1c: Sectional z-score the dconn (ReproTM expects z-scored units to match
    # the bundled z-scored template). Same method ReproTM's own zscore_dconn uses.
    dconn_file_z="${dconn_file%.dconn.nii}Zscored.dconn.nii"
    if [[ -n "${SCRATCH_DIR}" && -f "${dconn_file_z}" ]]; then
        echo "[perm-${NUM}] Z-scored dconn found on scratch, skipping: $(basename "${dconn_file_z}")"
    else
        echo "[perm-${NUM}] $(date '+%H:%M:%S') Z-scoring dconn (sectional)..."
        matlab -nodisplay -nosplash -r \
            "${MATLAB_ADDPATH} \
             Zscore_dconn('${dconn_file}', 'inferred', ''); \
             exit;"
        if [[ ! -f "${dconn_file_z}" ]]; then
            echo "[ERROR perm-${NUM}] Z-scored dconn not found: ${dconn_file_z}"; exit 1
        fi
    fi
    # Free the raw (pre-Z-score) dconn to reclaim /tmp space -- at 91k
    # grayordinates each dconn is tens of GB, and keeping both the raw and
    # Z-scored copies around can exhaust the /tmp mount.
    if [[ -z "${SCRATCH_DIR}" && -f "${dconn_file_z}" && "${dconn_file}" != "${dconn_file_z}" ]]; then
        rm -f "${dconn_file}"
        echo "[perm-${NUM}] Freed raw pre-Zscore dconn to reclaim /tmp space: $(basename "${dconn_file}")"
    fi
    dconn_file="${dconn_file_z}"
    echo "[perm-${NUM}] $(date '+%H:%M:%S') Z-scored dconn ready: ${dconn_file}"

    # Step 2: ReproTM template matching (Python) → network-assignment dscalar.
    reprotm_outdir="${work_dir}/reprotm"
    mkdir -p "${reprotm_outdir}"
    tm_dscalar="${reprotm_outdir}/${perm_name}_ReproTM.dscalar.nii"
    tm_mat="${reprotm_outdir}/${perm_name}_ReproTM.mat"
    tm_dscalar_refined="${reprotm_outdir}/${perm_name}_ReproTM_refineSCAN.dscalar.nii"

    # ReproTM treats surface_only as a flag; pass it only when SURF_ONLY=1.
    _surf_flag=()
    [[ "${SURF_ONLY}" == "1" ]] && _surf_flag+=(--surface_only)

    # Non-standard-resolution templates need an explicit output-header dscalar
    # override, since ReproTM's built-in surface_only/whole-brain templates
    # are human-dimensioned (59412/91282). Leave REPROTM_DSCALAR_TEMPLATE blank
    # for standard human templates.
    _dscalar_template_flag=()
    [[ -n "${REPROTM_DSCALAR_TEMPLATE:-}" ]] && _dscalar_template_flag+=(--dscalar_template "${REPROTM_DSCALAR_TEMPLATE}")

    # Optional SCAN/SMd/SMl refinement (needs those networks in the template).
    _refine_args=()
    if [[ "${REPROTM_REFINESCAN:-1}" == "1" ]]; then
        _refine_args+=(--refineSCAN \
                       --refineSCAN_minthreshold "${REPROTM_REFINESCAN_MINTHRESH:-3}" \
                       --dscalarSCANrefined_outfile "${tm_dscalar_refined}")
    fi

    echo "[perm-${NUM}] $(date '+%H:%M:%S') Running ReproTM template matching..."
    # REPROTM_NETWORKS is intentionally unquoted: each network name is a separate
    # argument to --template_networks (argparse nargs="*").
    "${_reprotm_py}" "${REPROTM_SCRIPT}" \
        --dconn_infile "${dconn_file}" \
        --template_infile "${TEMPLATE_PATH}" \
        --template_networks ${REPROTM_NETWORKS} \
        --template_thresholding --template_minthreshold "${REPROTM_TEMPLATE_MINTHRESH:-1}" \
        --mat_outfile "${tm_mat}" \
        --dscalar_outfile "${tm_dscalar}" \
        "${_surf_flag[@]}" "${_refine_args[@]}" "${_dscalar_template_flag[@]}"

    # Use the SCAN-refined map when it was produced, otherwise the base map.
    tm_final="${tm_dscalar}"
    if [[ "${REPROTM_REFINESCAN:-1}" == "1" && -f "${tm_dscalar_refined}" ]]; then
        tm_final="${tm_dscalar_refined}"
    fi
    if [[ ! -f "${tm_final}" ]]; then
        echo "[ERROR perm-${NUM}] ReproTM dscalar not produced: ${tm_final}"; exit 1
    fi

    # Step 3: minimum-size cluster cleanup (Python) → cleaned dscalar.
    cleaned_dscalar="${reprotm_outdir}/${perm_name}_ReproTM_minsize${REPROTM_MINSIZE:-30}.dscalar.nii"
    echo "[perm-${NUM}] $(date '+%H:%M:%S') Running ReproTM min-size cleanup (minsize=${REPROTM_MINSIZE:-30})..."
    "${_reprotm_py}" "${REPROTM_MINSIZE_SCRIPT}" \
        --dscalar_infile "${tm_final}" \
        --dscalar_outfile "${cleaned_dscalar}" \
        --minsize "${REPROTM_MINSIZE:-30}"
    if [[ ! -f "${cleaned_dscalar}" ]]; then
        echo "[ERROR perm-${NUM}] Min-size cleanup output not produced: ${cleaned_dscalar}"; exit 1
    fi

    # Step 4: Publish to persistent storage as *_recolored.dscalar.nii so the
    # method-agnostic figure aggregation (globs *recolored.dscalar.nii) picks it
    # up unchanged.
    recolored_out="${out_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_perm-${_perm_pad}_recolored.dscalar.nii"
    cp "${cleaned_dscalar}" "${recolored_out}"
    cp "${tm_mat}" "${out_dir}/" 2>/dev/null
    echo "${recolored_out}" >> \
        "${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/successful_perms.conc" \
        2>/dev/null
    echo "[perm-${NUM}] $(date '+%H:%M:%S') ReproTM perm complete: ${recolored_out}"

else

    # ── MATLAB template matching (original PCM method — unchanged) ─────────────

    # ── Derive label from SURF_ONLY for output directory naming ───────────────
    # TEMPLATE_PATH and SURF_ONLY are passed as args — no resolution needed here.
    if [[ "${SURF_ONLY}" == "0" ]]; then
        SURF_ONLY_LABEL="subcort_included"; TEMPLATE="abcd"
    elif [[ "${SURF_ONLY}" == "1" ]]; then
        SURF_ONLY_LABEL="surfonly"; TEMPLATE="abcd"
    else
        SURF_ONLY_LABEL="SCAN_network"; TEMPLATE="abcd-SCAN"
    fi

    echo "[perm-${NUM}] Template: ${TEMPLATE} | Label: ${SURF_ONLY_LABEL}"
    df -h "${work_dir}"

    # matlab_tm_wrapper.sh calls the MATLAB template matching code.
    # For each mode (SPLITPCT / SPLITHALF), it runs TM on a different subset of frames.
    # The mask files tell TM which TRs to use.

    if [[ "${SPLITPCT}" == "1" ]]; then
        echo "[perm-${NUM}] Running SPLITPCT template matching..."

        MASK_PATH="${work_dir}/masks_holdout/sub-${SUB}_ses-${SES}_mask_holdout_"*"min.txt"
        files_found=($(ls ${MASK_PATH} 2>/dev/null))
        if [[ "${#files_found[@]}" -ne 1 ]]; then
            echo "[ERROR] Expected 1 holdout mask, found ${#files_found[@]}"; exit 1
        fi
        MASK_PATH="${files_found[0]}"

        OUTDIR="${work_dir}/Percent_holdout-${percent_holdout}"
        OUTSAVE="${out_dir}"
        mkdir -p "${OUTDIR}" "${OUTSAVE}"

        "${TM_WRAPPER}" \
            "${TR}" "${FD}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat" \
            "${surf_L}" "${surf_R}" \
            "sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_holdout_perm-${NUM}" \
            "${OUTDIR}" "${TEMPLATE_PATH}" "${SURF_ONLY}" "0" "${OUTDIR}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${MASK_PATH}"

        cp "${OUTDIR}"/*.dscalar.nii "${OUTSAVE}/" 2>/dev/null
        cp "${OUTDIR}"/*.mat "${OUTSAVE}/" 2>/dev/null
        ls "${OUTSAVE}"/*recolored.dscalar.nii >> \
            "${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/successful_perms.conc" \
            2>/dev/null
    fi

    if [[ "${SPLITHALF}" == "1" ]]; then
        echo "[perm-${NUM}] Running SPLITHALF template matching (Half 1)..."

        MASK_PATH="${work_dir}/masks/sub-${SUB}_ses-${SES}_mask_half1_${MIN}min.txt"
        OUTDIR="${work_dir}/half1"
        OUTSAVE="${out_dir}/half1"
        mkdir -p "${OUTDIR}" "${OUTSAVE}"

        "${TM_WRAPPER}" \
            "${TR}" "${FD}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat" \
            "${surf_L}" "${surf_R}" \
            "sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_half1_perm-${NUM}" \
            "${OUTDIR}" "${TEMPLATE_PATH}" "${SURF_ONLY}" "0" "${OUTDIR}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${MASK_PATH}"

        cp "${OUTDIR}"/*.dscalar.nii "${OUTSAVE}/" 2>/dev/null
        ls "${OUTSAVE}"/*recolored.dscalar.nii >> \
            "${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/successful_perms_half1.conc" 2>/dev/null

        echo "[perm-${NUM}] Running SPLITHALF template matching (Half 2)..."
        MASK_PATH="${work_dir}/masks/sub-${SUB}_ses-${SES}_mask_groundtruth_${MIN}min.txt"
        OUTDIR="${work_dir}/half2"
        OUTSAVE="${out_dir}/half2"
        mkdir -p "${OUTDIR}" "${OUTSAVE}"

        "${TM_WRAPPER}" \
            "${TR}" "${FD}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_desc-filtered_motion_mask.mat" \
            "${surf_L}" "${surf_R}" \
            "sub-${SUB}_ses-${SES}_${TEMPLATE}_TM_half2_perm-${NUM}" \
            "${OUTDIR}" "${TEMPLATE_PATH}" "${SURF_ONLY}" "0" "${OUTDIR}" \
            "${work_dir}/sub-${SUB}_ses-${SES}_task-${TASK}_bold_shuffled_timeseries.dtseries.nii" \
            "${MASK_PATH}"

        cp "${OUTDIR}"/*.dscalar.nii "${OUTSAVE}/" 2>/dev/null
        cp "${OUTDIR}"/*.mat "${OUTSAVE}/" 2>/dev/null
        ls "${OUTSAVE}"/*recolored.dscalar.nii >> \
            "${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}/successful_perms_half2.conc" 2>/dev/null
    fi

fi  # end METHOD routing

df -h "${work_dir}"
popd
echo "[perm-${NUM}] $(date '+%H:%M:%S') Done. Outputs in ${out_dir}"
