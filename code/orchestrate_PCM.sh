#!/bin/bash
#SBATCH -J PCM_orchestrator
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=20gb
#SBATCH -t 48:00:00
# Partition and account are passed by run_PCM.sh at submission time (from cluster.conf).

# =============================================================================
# orchestrate_PCM.sh  —  PCM Job Orchestrator
# =============================================================================
# Submitted by run_PCM.sh. Stays alive as a long-running SLURM job (48h).
# Responsibilities:
#   1. Check which permutations are already complete
#   2. Submit one sbatch job per incomplete permutation using run_permutation.sh
#   3. Poll SLURM until all permutation jobs are done
#   4. Submit the figure-making job
#
# WHY THIS APPROACH vs. the old wrapper:
#   Previously, this script would *copy* run_permutation.sh to BASEDIR and then
#   patch its SLURM headers with sed commands. That was fragile (sed on SLURM
#   headers breaks if the header order changes) and left script copies scattered
#   in every output directory. Instead, we now pass all SLURM resource params
#   directly to sbatch as command-line flags, which always override #SBATCH
#   headers in the script. The script stays in CODE_DIR and is never copied.
# =============================================================================

# Load config
# Use CODE_DIR exported by run_PCM.sh (inherited via SLURM --export=ALL).
# Fall back to BASH_SOURCE path detection only when running from the script's
# actual location (e.g., manual testing), not from a SLURM spool copy.
if [[ -z "${CODE_DIR}" ]]; then
    CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi
source "${CODE_DIR}/config.sh"

# ── Parse arguments ───────────────────────────────────────────────────────────
SUB=${1}
SES=${2}
TASK=${3}
BASEDIR=${4}
dtseries=${5}
surf_L=${6}
surf_R=${7}
motion_file=${8}
TEMPLATE_PATH=${9}
SURF_ONLY=${10}
intrp_noise=${11}
percent_holdout=${12}
FD=${13}
NUM=${14}
shuffle_option=${15}
shuffle_chunk_size=${16}
SPLITHALF=${17}
SPLITPCT=${18}
STANDARDTM=${19}
JobName=${20}
ntasks=${21}
tmpspace=${22}
mem=${23}
time=${24}
mail=${25}
partitions=${26}
group=${27}
MIN=${28}
TR=${29}
MAKEFIGS_MEM=${30:-64gb}
MAKEFIGS_TIME=${31:-1:00:00}

S_KERNEL=2.55   # Smoothing kernel (mm geodesic). Standard value, not user-configurable.
MAKEFIGS=1      # Always make figures after permutations complete.

# ── Compute TASK_DIR and set up task folder ────────────────────────────────────
TASK_DIR="${BASEDIR}/sub-${SUB}/ses-${SES}/${TASK_FOLDER}"
mkdir -p "${TASK_DIR}/logs" "${TASK_DIR}/perms"

echo "[orchestrate_PCM] Starting for sub-${SUB} ses-${SES} task-${TASK}"
echo "[orchestrate_PCM] BASEDIR: ${BASEDIR}"
echo "[orchestrate_PCM] TASK_DIR: ${TASK_DIR}"
echo "[orchestrate_PCM] NUM permutations: ${NUM} | shuffle: ${shuffle_option}"
echo "[orchestrate_PCM] SPLITPCT=${SPLITPCT} SPLITHALF=${SPLITHALF} STANDARDTM=${STANDARDTM}"

# ── Log file paths ─────────────────────────────────────────────────────────────
current_datetime=$(date +"%Y%m%d%H%M%S")
outputlogs="${TASK_DIR}/logs/${SUB}_${SES}_perm_${current_datetime}_%A_%a.out"
errorlogs="${TASK_DIR}/logs/${SUB}_${SES}_perm_${current_datetime}_%A_%a.err"
figures_out="${TASK_DIR}/logs/${SUB}_${SES}_figs_${current_datetime}_%A.out"
figures_err="${TASK_DIR}/logs/${SUB}_${SES}_figs_${current_datetime}_%A.err"

# ── Write run_params.json ──────────────────────────────────────────────────────
cat > "${TASK_DIR}/run_params.json" << PARAMS_EOF
{
  "sub": "${SUB}",
  "ses": "${SES}",
  "task": "${TASK}",
  "task_folder": "${TASK_FOLDER}",
  "method": "${METHOD:-matlab_tm}",
  "template_label": "${TEMPLATE_LABEL}",
  "template_path": "${TEMPLATE_PATH}",
  "surf_only": ${SURF_ONLY},
  "num_perms": ${NUM},
  "fd": ${FD},
  "shuffle_option": "${shuffle_option}",
  "shuffle_chunk_size": ${shuffle_chunk_size:-5},
  "percent_holdout": ${percent_holdout},
  "splithalf": ${SPLITHALF},
  "splitpct": ${SPLITPCT},
  "standardtm": ${STANDARDTM},
  "min": "${MIN}",
  "tr": "${TR}",
  "datestamp": "$(date '+%Y-%m-%d %H:%M:%S')"
}
PARAMS_EOF

# ── Helper: check if a SLURM job has finished ─────────────────────────────────
check_job_completion() {
    local job=$1
    local jobState
    jobState=$(sacct -j "$job" --format=State --noheader | head -n 1 | awk '{print $1}')
    if [[ "$jobState" =~ ^(COMPLETED|FAILED|CANCELLED)$ ]]; then
        return 1  # done
    else
        return 0  # still running
    fi
}

# ── Helper: submit one permutation job ────────────────────────────────────────
submit_permutation() {
    local index=$1
    local splithalf_flag=$2
    local splitpct_flag=$3

    # sbatch command-line flags override the #SBATCH headers in run_permutation.sh.
    # This is how we avoid copying and patching the script for each run.
    local JOBID
    JOBID=$(sbatch \
        --job-name="${JobName}" \
        --ntasks=1 \
        --cpus-per-task="${ntasks}" \
        --tmp="${tmpspace}" \
        --mem="${mem}" \
        --time="${time}" \
        --mail-type="${mail}" \
        --partition="${partitions}" \
        --account="${group}" \
        --output="${outputlogs}" \
        --error="${errorlogs}" \
        "${RUN_PERMUTATION_SCRIPT}" \
            "${SUB}" "${SES}" "${TASK}" "${FD}" "${index}" "${MIN}" "${S_KERNEL}" \
            "${dtseries}" "${BASEDIR}" "${surf_L}" "${surf_R}" "${motion_file}" \
            "${TEMPLATE_PATH}" "${SURF_ONLY}" \
            "${intrp_noise}" "${shuffle_option}" "${shuffle_chunk_size}" \
            "${percent_holdout}" "${splithalf_flag}" "${splitpct_flag}" "${TR}" \
        | awk '{print $4}')
    echo "${JOBID}"
}

# ── Helper: wait for a list of job IDs to finish ──────────────────────────────
wait_for_jobs() {
    local -a jobids=("$@")
    local all_done=0
    while [[ "${all_done}" -eq 0 ]]; do
        all_done=1
        for JOBID in "${jobids[@]}"; do
            check_job_completion "${JOBID}"
            if [[ $? -eq 0 ]]; then
                echo "[orchestrate_PCM] Waiting for job ${JOBID}..."
                all_done=0
                sleep 60
                break
            fi
        done
    done
    echo "[orchestrate_PCM] All submitted jobs completed."
}

# ── SPLITPCT mode ─────────────────────────────────────────────────────────────
if [[ "${SPLITPCT}" == "1" ]]; then
    echo "[orchestrate_PCM] Mode: SPLITPCT (percent=${percent_holdout})"

    # Scan existing outputs to find which permutations are complete or missing
    python3 "${CHECK_PERMS_SCRIPT}" \
        "${BASEDIR}" "${SUB}" "${SES}" "${TASK}" "${NUM}" "${TASK_FOLDER}" "${SPLITHALF}"

    FAILED_CONC="${TASK_DIR}/failed_perms.conc"
    if [[ ! -f "${FAILED_CONC}" ]]; then
        echo "[ERROR] Check script did not produce ${FAILED_CONC}"; exit 1
    fi

    declare -a JOBIDS=()
    while read -r index; do
        echo "[orchestrate_PCM] Submitting SPLITPCT permutation ${index}"
        JOBID=$(submit_permutation "${index}" "0" "1")
        JOBIDS+=("${JOBID}")
        echo "[orchestrate_PCM] Submitted job ${JOBID}"
    done < "${FAILED_CONC}"

    if [[ ${#JOBIDS[@]} -eq 0 ]]; then
        echo "[orchestrate_PCM] All SPLITPCT permutations already complete."
    else
        wait_for_jobs "${JOBIDS[@]}"
    fi

    # Re-check after jobs finish (updates the successful .conc file for figure making)
    python3 "${CHECK_PERMS_SCRIPT}" \
        "${BASEDIR}" "${SUB}" "${SES}" "${TASK}" "${NUM}" "${TASK_FOLDER}" "${SPLITHALF}"

    if [[ "${MAKEFIGS}" == "1" ]]; then
        echo "[orchestrate_PCM] Submitting figure-making job for SPLITPCT..."
        module load ffmpeg
        SUCCESSFUL_CONC="${TASK_DIR}/successful_perms.conc"
        sbatch \
            --job-name="PCM_figs_${SUB}" \
            --partition="${partitions}" \
            --account="${group}" \
            --mem="${MAKEFIGS_MEM}" --time="${MAKEFIGS_TIME}" \
            --output="${figures_out}" \
            --error="${figures_err}" \
            "${MAKE_FIGS_SCRIPT}" \
                "${TASK_DIR}" "${SUCCESSFUL_CONC}" "${percent_holdout}" "1"
    fi
fi

# ── SPLITHALF mode ────────────────────────────────────────────────────────────
if [[ "${SPLITHALF}" == "1" ]]; then
    echo "[orchestrate_PCM] Mode: SPLITHALF"

    python3 "${CHECK_PERMS_SCRIPT}" \
        "${BASEDIR}" "${SUB}" "${SES}" "${TASK}" "${NUM}" "${TASK_FOLDER}" "${SPLITHALF}"

    FAILED_CONC="${TASK_DIR}/failed_perms.conc"
    if [[ ! -f "${FAILED_CONC}" ]]; then
        echo "[ERROR] Check script did not produce ${FAILED_CONC}"; exit 1
    fi

    declare -a JOBIDS=()
    while read -r index; do
        echo "[orchestrate_PCM] Submitting SPLITHALF permutation ${index}"
        JOBID=$(submit_permutation "${index}" "1" "0")
        JOBIDS+=("${JOBID}")
    done < "${FAILED_CONC}"

    if [[ ${#JOBIDS[@]} -eq 0 ]]; then
        echo "[orchestrate_PCM] All SPLITHALF permutations already complete."
    else
        wait_for_jobs "${JOBIDS[@]}"
    fi

    python3 "${CHECK_PERMS_SCRIPT}" \
        "${BASEDIR}" "${SUB}" "${SES}" "${TASK}" "${NUM}" "${TASK_FOLDER}" "${SPLITHALF}"

    if [[ "${MAKEFIGS}" == "1" ]]; then
        echo "[orchestrate_PCM] Submitting figure-making job for SPLITHALF..."
        module load ffmpeg
        CONC_H1="${TASK_DIR}/successful_perms_half1.conc"
        CONC_H2="${TASK_DIR}/successful_perms_half2.conc"
        sbatch \
            --job-name="PCM_figs_${SUB}" \
            --partition="${partitions}" \
            --account="${group}" \
            --mem="${MAKEFIGS_MEM}" --time="${MAKEFIGS_TIME}" \
            --output="${figures_out}" \
            --error="${figures_err}" \
            "${MAKE_FIGS_SCRIPT}" \
                "${TASK_DIR}" "${CONC_H1}" "${CONC_H2}" "1"
    fi
fi

# ── STANDARDTM mode ───────────────────────────────────────────────────────────
if [[ "${STANDARDTM}" == "1" ]]; then
    echo "[orchestrate_PCM] Mode: STANDARDTM"
    sbatch \
        --job-name="${JobName}_stdTM" \
        --ntasks="${ntasks}" \
        --tmp="${tmpspace}" \
        --mem="${mem}" \
        --time="${time}" \
        --mail-type="${mail}" \
        --partition="${partitions}" \
        --account="${group}" \
        --output="${outputlogs}" \
        --error="${errorlogs}" \
        "${CODE_DIR}/code/run_standard_TM.sh" \
            "${SUB}" "${SES}" "${TASK}" "${FD}" "1" "${MIN}" "${S_KERNEL}" \
            "${dtseries}" "${BASEDIR}" "${surf_L}" "${surf_R}" "${motion_file}" \
            "${TEMPLATE_PATH}" "${SURF_ONLY}" \
            "${intrp_noise}" "${shuffle_option}" "${shuffle_chunk_size}" \
            "${percent_holdout}" "0" "0" "1" "${TR}"
fi

echo "[orchestrate_PCM] Done. Check ${TASK_DIR}/logs/ for job logs."
