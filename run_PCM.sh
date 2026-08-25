#!/bin/bash -l

#SBATCH -J PCM_launcher
#SBATCH -c 1
#SBATCH --mem=20G
#SBATCH -t 1:00:00
#SBATCH -p ag2tb,agsmall
#SBATCH -A faird

# =============================================================================
# run_PCM.sh  —  PrecisionConfidenceMapping Entry Point
# =============================================================================
# This is the only file you need to edit to run PCM on your data.
# Submit with:
#   sbatch run_PCM.sh
# Or pass flags directly:
#   sbatch run_PCM.sh --dtseries /path/to/bold.dtseries.nii --motion /path/to/motion.mat ...
#
# Run  bash run_PCM.sh --help  for full usage.
#
# TIP: run_PCM.sh can live anywhere — in PrecisionConfidenceMapping/ OR in a separate
# study directory. Just set PCM_DIR below when running from outside PrecisionConfidenceMapping/.
# =============================================================================

# ─────────────────────────────────────────────────────────────────────────────
# USER SETTINGS — edit everything in this section
# ─────────────────────────────────────────────────────────────────────────────

# ── PCM installation path ─────────────────────────────────────────────────────
# If run_PCM.sh is inside PrecisionConfidenceMapping/ (the default), leave this empty.
# If you keep run_PCM.sh in a separate study directory, set this to the full
# path of your PrecisionConfidenceMapping installation, e.g.:
#   PCM_DIR="/path/to/PrecisionConfidenceMapping"
# On the FAIRD server, PrecisionConfidenceMapping is installed at:
#   PCM_DIR="/projects/standard/faird/shared/code/internal/analytics/PrecisionConfidenceMapping"
PCM_DIR=""

# ── REQUIRED inputs ──────────────────────────────────────────────────────────
dtseries=""     # full path to your .dtseries.nii file
motion_file=""  # .mat (DCAN) | .hdf5 (XCP-D, auto-converted) | .txt (0/1 mask)
surf_L=""       # full path to left midthickness .surf.gii
surf_R=""       # full path to right midthickness .surf.gii
BASEDIR=""      # output root directory (created if it doesn't exist)

# ── OPTIONAL — subject/session/task labels ────────────────────────────────────
# Auto-parsed from the dtseries filename (BIDS format) if left empty.
# Set explicitly if your filename is not BIDS-formatted.
SUB=""
SES=""
TASK=""

# ── OPTIONAL — analysis settings ─────────────────────────────────────────────
METHOD="matlab_tm"         # matlab_tm | reprotm; set via --method
NUM=100                    # number of permutations; set via --num
FD=0.2                     # framewise-displacement threshold in mm (.mat motion files only); set via --fd
intrp_noise=0              # 1 = run spatial noise interpolation on dtseries first; set via --interp-noise
shuffle_option="bootstrap" # set via --shuffle
shuffle_chunk_size=5       # set via --shuffle-chunk-size
SPLITPCT=1                 # main analysis mode (shuffle+aggregate); set via --splitpct
# STANDARDTM (matlab_tm only): also compute the standard, non-permuted
# template-matching map alongside the permutations. Default off — set to 1
# to enable. Set via --standardtm.
STANDARDTM=0
SPLITHALF=0                # deprecated split-half mode; no CLI flag, use SPLITPCT for new analyses
percent_holdout=100        # percent of shuffled data used per permutation; set via --percent-holdout
MIN=""                     # leave empty to auto-compute from scan length (recommended); set via --minutes
# FISHER_Z: whether the dconn's correlations are Fisher-z transformed (wb_command's
# -fisher-z) before the sectional Zscore_dconn step. Both methods build their dconn
# via the same cifti_connectivity call, so this applies to both. Default on (1),
# matching matlab_tm's original always-on behavior; set to 0 for plain Pearson r
# into Zscore_dconn instead. Set via --fisher-z.
FISHER_Z=1
# REMOVE_OUTLIERS: whether cifti_connectivity's standard-deviation-based outlier
# removal (isthisanoutlier, median method) runs on top of the FD-based motion
# censoring already done upstream in the shared bagging/shuffle step -- it can
# drop additional frames purely for having outlier BOLD-signal variance. Applies
# to both methods, same as FISHER_Z above. Default on (1), matching matlab_tm's
# original always-on behavior. Set via --remove-outliers.
REMOVE_OUTLIERS=1

# ── OPTIONAL — network template ───────────────────────────────────────────────
# matlab_tm:  "scan" (default) | "abcd_full" | "abcd_surf" | /full/path/to/template.mat
# reprotm:    leave empty to use the bundled ABCC seedmap template, or set to
#             "scan" | "abcd_full" | "abcd_surf" (reuses the matlab_tm templates
#             with matching network lists), or a /full/path/to/seedmap_template.mat
#             (a .mat with a "seed_matrix" variable). If you supply a custom
#             template, also set REPROTM_NETWORKS below (or --reprotm-networks)
#             to the matching network-name list.
TEMPLATE=""

# ── OPTIONAL — debug scratch directory ───────────────────────────────────────
# Leave empty to use /tmp (node-local, fast, deleted after job — default).
# Set to a persistent path (e.g. your scratch dir) to keep all intermediate
# files (shuffled dtseries, dconn, masks) for inspection.
# WARNING: each permutation's dconn is tens of GB.
# Only set this when debugging a small number of permutations (NUM=1 or 2).
# Set via --scratch-dir.
SCRATCH_DIR=""

# ── OPTIONAL — dconn smoothing (applies to both methods) ─────────────────────
SMOOTHING_KERNEL=2.25      # geodesic surface + subcortical smoothing (sigma mm); set to 0 to skip; set via --smoothing-kernel

# ── OPTIONAL — ReproTM settings (METHOD=reprotm only) ─────────────────────────
# REPROTM_NETWORKS: space-separated network names matching the template's
#   seed_matrix columns. Leave empty to use the default that ships with the
#   bundled ABCC template (REPROTM_NETWORKS_DEFAULT in config.sh). REQUIRED if
#   you pass a custom --template .mat whose columns differ from the default.
#   Set via --reprotm-networks.
REPROTM_NETWORKS=""
REPROTM_MINSIZE=30                 # min cluster size (greyordinates) for cleanup; set via --reprotm-minsize
REPROTM_TEMPLATE_MINTHRESH=1       # template seedmap thresholding minimum; set via --reprotm-minthresh
REPROTM_REFINESCAN=1               # 1 = re-match SMd/SMl/SCAN at a higher threshold (needs those nets in the template); set via --reprotm-refinescan
REPROTM_REFINESCAN_MINTHRESH=3     # threshold used during SCAN/SMd/SMl refinement; set via --reprotm-refinescan-minthresh
REPROTM_DSCALAR_TEMPLATE=""        # override for ReproTM's output-header dscalar (leave blank; only needed for non-standard-resolution templates)
TEMPLATE_LABEL="" # auto-set for built-in templates; required for custom --template paths

# ── OPTIONAL — Combined figures across all methods ────────────────────────────
# Set COMBINED_FIGS=1 (or pass --combined-figs) to scan all task-TASK_*
# folders under the subject directory, concatenate their successful_perms.conc
# files, and generate one set of confidence-map figures from the full pool of
# dscalars.  Only --basedir is required; --dtseries is optional (used only for
# auto-parsing --sub/--ses/--task if those are not set explicitly).
#
# By default every task-TASK_* folder is included. To combine only specific
# folders (e.g. to exclude test runs without deleting them), pass --includefolder
# one or more times; each value may be an absolute path or just the task-folder
# name (resolved under sub-/ses-). To name the output folder, pass --combined-name
# NAME → task-TASK_combined_NAME (default: task-TASK_combined).
COMBINED_FIGS=0
COMBINED_INCLUDE=()
COMBINED_NAME=""

# ── OPTIONAL — SLURM resources (empty = method-appropriate default) ───────────
# matlab_tm default: ntasks=1   mem=128gb  tmpspace=100gb  time=10:00:00
# reprotm default:   ntasks=1   mem=200gb  tmpspace=100gb  time=12:00:00
JobName="PCM"
ntasks=""
mem=""
tmpspace=""
time=""
mail="NONE"

# ── OPTIONAL — time truncation ────────────────────────────────────────────────
# Leave all empty to run on the full dataset (default — recommended).
# STARTMINS   Truncate the scan to this many minutes before running PCM.
# ENDMINS     End of a minutes range (requires STARTMINS + INCREMENT).
# INCREMENT   Step size in minutes when iterating from STARTMINS to ENDMINS.
# KEEP_FROM   Which end of the scan to extract from: 'start' (default) or 'end'.
#
# Examples:
#   First 10 min only:        STARTMINS=10
#   Last 10 min only:         STARTMINS=10  KEEP_FROM=end
#   Loop 5, 10, 15 min:       STARTMINS=5   INCREMENT=5   ENDMINS=15
STARTMINS=""
ENDMINS=""
INCREMENT=""
KEEP_FROM=""

# ─────────────────────────────────────────────────────────────────────────────
# END OF USER SETTINGS — do not edit below this line
# ─────────────────────────────────────────────────────────────────────────────

# ── Help function ─────────────────────────────────────────────────────────────
_pcm_help() {
cat <<'HELP'
Usage: sbatch run_PCM.sh [FLAGS]
       bash  run_PCM.sh --help

Required flags (or set the matching variable in the USER SETTINGS section):
  --dtseries PATH       Full path to .dtseries.nii file
  --motion PATH         Motion file: .mat (DCAN) | .hdf5 (XCP-D) | .txt (binary mask)
  --surf-l PATH         Left midthickness .surf.gii
  --surf-r PATH         Right midthickness .surf.gii
  --basedir PATH        Output root directory

Optional subject/session/task labels (auto-parsed from BIDS filename if omitted):
  --sub ID              Subject ID (e.g. 1004101)
  --ses ID              Session ID (e.g. combined)
  --task NAME           Task name (e.g. restMENORDICrmnoisevols)

Optional analysis settings:
  --method METHOD       matlab_tm (default) | reprotm
  --template VALUE      matlab_tm: scan (default) | abcd_full | abcd_surf | /path/to.mat
                        reprotm:  leave empty for bundled default (ABCC) | scan | abcd_full
                                  | abcd_surf | /path/to_seedmap.mat
  --num N               Number of permutations (default: 100)
  --fd VALUE            Framewise-displacement threshold in mm for .mat motion files
                        (default: 0.2; ignored for .txt binary masks)
  --fisher-z 0|1        Fisher-z transform the dconn's correlations before z-scoring
                        (default: 1/on, both methods). Set to 0 for plain Pearson r.
  --remove-outliers 0|1 Standard-deviation-based outlier frame removal on top of FD
                        motion censoring (default: 1/on, both methods).
  --percent-holdout N   Percent of shuffled data used per permutation (default: 100)
  --splitpct 0|1        Main analysis mode: shuffle + percent_holdout + aggregate across
                        --num perms into confidence/probability maps (default: 1/on)
  --standardtm 0|1      matlab_tm only: also compute one standard (non-permuted)
                        template-matching map as a ground-truth reference (default: 0/off)
  --scratch-dir PATH    Keep intermediate files (shuffled dtseries, dconn, masks) here
                        instead of node-local /tmp (which is deleted after the job).
                        Default: empty (use /tmp). Only set this for a small --num
                        (1-2) when debugging -- each perm's dconn is tens of GB.

Optional time truncation:
  --startmins N         Truncate scan to N minutes before running PCM
  --endmins N           End of minutes range (requires --startmins + --increment)
  --increment N         Step size in minutes
  --keepfrom start|end  Which end of scan to extract from (default: start)

Optional advanced:
  --smoothing-kernel N  Pre-dconn smoothing sigma in mm (default: 2.25; 0 to skip)
  --minutes N           Override the auto-computed MIN (minimum minutes per half)
  --interp-noise 0|1    Run MATLAB spatial noise interpolation on the dtseries before
                        anything else (default: 0/off, unchanged from prior behavior).
                        Skipped automatically if a sibling *_spatially_interpolated.dtseries.nii
                        already exists next to --dtseries (reused instead of recomputing).
                        If left at 0 and --dtseries doesn't end in that suffix, an [INFO]
                        line suggests --interp-noise 1 -- it does NOT turn on automatically.
  --template-label NAME Override the template label used in the output folder name.
                        Required when using a custom --template path; auto-set
                        for built-in templates (scan, abcd_full, abcd_surf, abcc18).
  --combined-figs       Scan all task-TASK_* folders under the subject directory,
                        concatenate their successful_perms.conc files, and generate
                        one set of confidence-map figures from the combined dscalar
                        pool. Can be re-run any time to include new methods.
                        Output goes to task-TASK_combined/. Only --basedir is
                        required; --sub/--ses/--task auto-parsed from --dtseries
                        or set explicitly.
  --includefolder PATH  (with --combined-figs; repeatable) Include only these task
                        folders instead of auto-scanning all of them. PATH may be an
                        absolute path or just the task-folder name (resolved under
                        sub-/ses-). Lets you exclude test runs without deleting them.
  --combined-name NAME  (with --combined-figs) Suffix the output folder:
                        task-TASK_combined_NAME (e.g. combined_matlabtm-reprotm).
                        Default is task-TASK_combined.

Shuffle options (--shuffle OPTION):
  Resampling (with replacement):
  bootstrap             Resample individual TRs with replacement; output = full scan
                        length (default)
  bagging               Resample individual TRs with replacement; output fixed at
                        --shuffle-chunk-size MINUTES (can up- or down-sample the scan)
                        (token: sh-bagging<N>m)
  bootstrap_variable    Resample individual TRs with replacement, then keep a random
                        amount per perm, from --shuffle-chunk-size minutes up to the
                        full scan (--shuffle-chunk-size = minimum minutes)
                        (token: sh-bsvar<N>m)

  Reordering (no replacement; keeps all good frames, full length):
  TRs                   Randomly reorder individual TRs
  run                   Randomly reorder whole-run blocks
  minutes               Randomly reorder --shuffle-chunk-size-minute blocks
                        (token: sh-min<N>)
  percent               Randomly reorder blocks each --shuffle-chunk-size percent of
                        the scan (token: sh-pct<N>)

  Real-data window (no resampling):
  subsample             One contiguous segment of the real data, random length
                        (--shuffle-chunk-size min up to full) at a random start
                        (token: sh-subsample<N>m)

  --shuffle-chunk-size N  Meaning depends on --shuffle option:
                          minutes for bagging/minutes, MINIMUM minutes for
                          bootstrap_variable/subsample, percent for percent;
                          ignored for bootstrap/TRs/run

ReproTM settings (METHOD=reprotm):
  --template VALUE        empty=bundled ABCC default | scan | abcd_full | abcd_surf | /path.mat
  --reprotm-networks STR  Space-separated network names matching the template's
                          seed_matrix columns. Auto-set for built-in templates;
                          REQUIRED for a custom --template .mat whose columns differ.
  --reprotm-minsize N            Min cluster size in greyordinates for cleanup (default: 30)
  --reprotm-minthresh VALUE      Template seedmap thresholding minimum (default: 1)
  --reprotm-refinescan 0|1       1=re-match SMd/SMl/SCAN at a higher threshold (default: 1)
  --reprotm-refinescan-minthresh VALUE  Threshold for the SCAN/SMd/SMl refinement (default: 3)
  REPROTM_PYTHON          Python with nibabel/scipy/numpy (set in cluster.conf;
                          default python3 often lacks nibabel). A preflight check
                          fails fast if the deps are missing.

Examples:
  sbatch run_PCM.sh --dtseries /data/sub-01/bold.dtseries.nii \
                    --motion /data/sub-01/motion.mat \
                    --surf-l /data/sub-01/hemi-L.surf.gii \
                    --surf-r /data/sub-01/hemi-R.surf.gii \
                    --basedir /out/PCM/sub-01

  sbatch run_PCM.sh --method matlab_tm --template abcd_full
  sbatch run_PCM.sh --method reprotm --startmins 70
  sbatch run_PCM.sh --method reprotm --fd 0.3 --reprotm-minsize 15
HELP
}

# ── Check for --help/-h before anything else ──────────────────────────────────
for _arg in "$@"; do
    case "${_arg}" in
        --help|-h) _pcm_help; exit 0 ;;
    esac
done

# ── Flag parser ────────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
    case "$1" in
        --dtseries)   dtseries="$2";    shift 2 ;;
        --motion)     motion_file="$2"; shift 2 ;;
        --surf-l)     surf_L="$2";      shift 2 ;;
        --surf-r)     surf_R="$2";      shift 2 ;;
        --basedir)    BASEDIR="$2";     shift 2 ;;
        --sub)        SUB="$2";         shift 2 ;;
        --ses)        SES="$2";         shift 2 ;;
        --task)       TASK="$2";        shift 2 ;;
        --method)     METHOD="$2";      shift 2 ;;
        --template)   TEMPLATE="$2";    shift 2 ;;
        --num)        NUM="$2";         shift 2 ;;
        --startmins)  STARTMINS="$2";   shift 2 ;;
        --endmins)    ENDMINS="$2";     shift 2 ;;
        --increment)  INCREMENT="$2";   shift 2 ;;
        --keepfrom)         KEEP_FROM="$2";       shift 2 ;;
        --smoothing-kernel) SMOOTHING_KERNEL="$2"; shift 2 ;;
        --minutes)          MIN="$2";              shift 2 ;;
        --interp-noise)     intrp_noise="$2";     shift 2 ;;
        --fd)               FD="$2";              shift 2 ;;
        --fisher-z)         FISHER_Z="$2";        shift 2 ;;
        --remove-outliers)  REMOVE_OUTLIERS="$2"; shift 2 ;;
        --splitpct)         SPLITPCT="$2";        shift 2 ;;
        --standardtm)       STANDARDTM="$2";      shift 2 ;;
        --percent-holdout)  percent_holdout="$2"; shift 2 ;;
        --scratch-dir)      SCRATCH_DIR="$2";     shift 2 ;;
        --reprotm-networks) REPROTM_NETWORKS="$2"; shift 2 ;;
        --reprotm-minsize)  REPROTM_MINSIZE="$2";  shift 2 ;;
        --reprotm-minthresh) REPROTM_TEMPLATE_MINTHRESH="$2"; shift 2 ;;
        --reprotm-refinescan) REPROTM_REFINESCAN="$2"; shift 2 ;;
        --reprotm-refinescan-minthresh) REPROTM_REFINESCAN_MINTHRESH="$2"; shift 2 ;;
        --shuffle)          shuffle_option="$2";      shift 2 ;;
        --shuffle-chunk-size) shuffle_chunk_size="$2"; shift 2 ;;
        --template-label)   TEMPLATE_LABEL="$2";      shift 2 ;;
        --combined-figs)    COMBINED_FIGS=1;           shift ;;
        --includefolder)    COMBINED_INCLUDE+=("$2");  shift 2 ;;
        --combined-name)    COMBINED_NAME="$2";        shift 2 ;;
        --help|-h)          _pcm_help; exit 0 ;;
        *) echo "[WARN] Unknown argument ignored: $1"; shift ;;
    esac
done

# ── Locate and source config.sh ───────────────────────────────────────────────
if [[ -z "${PCM_DIR}" ]]; then
    # Under sbatch, SLURM copies this script to a per-job spool dir (e.g.
    # /var/spool/slurmd/jobNNNN) and runs the copy, so BASH_SOURCE points there
    # instead of the real install. Ask SLURM for the original submitted path.
    if [[ -n "${SLURM_JOB_ID:-}" ]]; then
        _orig="$(scontrol show job "${SLURM_JOB_ID}" 2>/dev/null \
                 | sed -n 's/.*Command=\([^ ]*\).*/\1/p' | head -1)"
        if [[ -n "${_orig}" && -f "${_orig}" ]]; then
            PCM_DIR="$(cd "$(dirname "${_orig}")" && pwd)"
        fi
    fi
    # Fallback for non-sbatch runs (plain `bash run_PCM.sh`).
    if [[ -z "${PCM_DIR}" ]]; then
        PCM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    fi
fi
if [[ ! -f "${PCM_DIR}/config.sh" ]]; then
    echo "[ERROR] Cannot find config.sh in PCM_DIR=${PCM_DIR}"
    echo "        Set PCM_DIR at the top of run_PCM.sh to your PrecisionConfidenceMapping/ path."
    exit 1
fi
source "${PCM_DIR}/config.sh"

# ── Load cluster settings ─────────────────────────────────────────────────────
_submit_dir="${SLURM_SUBMIT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
if [[ -f "${_submit_dir}/cluster.conf" && "${_submit_dir}" != "${PCM_DIR}" ]]; then
    echo "[INFO] Using cluster config: ${_submit_dir}/cluster.conf"
    source "${_submit_dir}/cluster.conf"
else
    source "${PCM_DIR}/cluster.conf"
fi
partitions="${SLURM_PARTITION}"
group="${SLURM_ACCOUNT}"
# Export module names so child SLURM jobs can call 'module load' without
# needing to re-source cluster.conf themselves.
export WORKBENCH_MODULE MATLAB_MODULE PYTHON_MODULE

# REPROTM_DIR/REPROTM_SCRIPT/REPROTM_MINSIZE_SCRIPT were derived in config.sh
# BEFORE cluster.conf (just sourced above) had a chance to set it — recompute them
# now that REPROTM_DIR holds its final value, so both this script's own validation
# below and the exported values SLURM child jobs inherit are correct. Re-apply the
# fetched-dir fallback defensively too, in case cluster.conf still has an old
# `export REPROTM_DIR=""` line from before the auto-fetch option existed.
REPROTM_DIR="${REPROTM_DIR:-${REPROTM_FETCHED_DIR}}"
REPROTM_SCRIPT="${REPROTM_DIR}/code/ReproTM/ReproTM_v1.0.0.py"
REPROTM_MINSIZE_SCRIPT="${REPROTM_DIR}/code/minsize/minsize_v1.0.0.py"
export REPROTM_DIR REPROTM_SCRIPT REPROTM_MINSIZE_SCRIPT

# ── Validate required inputs ──────────────────────────────────────────────────
_missing=()
[[ -z "${BASEDIR}" ]] && _missing+=("BASEDIR   (--basedir or set in USER SETTINGS)")
if [[ "${COMBINED_FIGS}" != "1" ]]; then
    [[ -z "${dtseries}" ]] && _missing+=("dtseries  (--dtseries or set in USER SETTINGS)")
    [[ -z "${motion_file}" ]] && _missing+=("motion_file (--motion or set in USER SETTINGS)")
    [[ -z "${surf_L}"      ]] && _missing+=("surf_L      (--surf-l or set in USER SETTINGS)")
    [[ -z "${surf_R}"      ]] && _missing+=("surf_R      (--surf-r or set in USER SETTINGS)")
fi
if [[ ${#_missing[@]} -gt 0 ]]; then
    echo "[ERROR] The following required inputs are missing:"
    for _m in "${_missing[@]}"; do echo "  - ${_m}"; done
    echo ""
    echo "Run:  bash run_PCM.sh --help  for full usage."
    exit 1
fi

# ── File existence checks ─────────────────────────────────────────────────────
_bad_files=()
if [[ "${COMBINED_FIGS}" != "1" ]]; then
    [[ ! -f "${dtseries}" ]] && _bad_files+=("dtseries:    ${dtseries}")
    [[ ! -f "${motion_file}" ]] && _bad_files+=("motion_file: ${motion_file}")
    [[ ! -f "${surf_L}"      ]] && _bad_files+=("surf_L:      ${surf_L}")
    [[ ! -f "${surf_R}"      ]] && _bad_files+=("surf_R:      ${surf_R}")
fi
if [[ ${#_bad_files[@]} -gt 0 ]]; then
    echo "[ERROR] The following input files were not found:"
    for _f in "${_bad_files[@]}"; do echo "  ${_f}"; done
    exit 1
fi

BASEDIR="${BASEDIR%/}"    # strip any trailing slash
mkdir -p "${BASEDIR}"

# ── BIDS auto-parse SUB/SES/TASK from dtseries filename ──────────────────────
if [[ "${COMBINED_FIGS}" == "1" && -z "${dtseries}" ]]; then
    # No dtseries provided — require explicit identifiers.
    _cf_id_missing=()
    [[ -z "${SUB}" ]]  && _cf_id_missing+=("--sub")
    [[ -z "${SES}" ]]  && _cf_id_missing+=("--ses")
    [[ -z "${TASK}" ]] && _cf_id_missing+=("--task")
    if [[ ${#_cf_id_missing[@]} -gt 0 ]]; then
        echo "[ERROR] --combined-figs without --dtseries requires explicit subject identifiers."
        echo "        Missing: ${_cf_id_missing[*]}"
        echo "        Either add --dtseries for auto-parsing, or set the flags above."
        exit 1
    fi
else
    _dts_base="$(basename "${dtseries}")"
    if [[ -z "${SUB}" ]]; then
        SUB=$(echo "${_dts_base}" | grep -oP '(?<=sub-)[^_]+')
        if [[ -z "${SUB}" ]]; then
            echo "[ERROR] Could not parse SUB from dtseries filename: ${_dts_base}"
            echo "        Set --sub or the SUB variable in USER SETTINGS."
            exit 1
        fi
    fi
    if [[ -z "${SES}" ]]; then
        SES=$(echo "${_dts_base}" | grep -oP '(?<=ses-)[^_]+')
        if [[ -z "${SES}" ]]; then
            echo "[ERROR] Could not parse SES from dtseries filename: ${_dts_base}"
            echo "        Set --ses or the SES variable in USER SETTINGS."
            exit 1
        fi
    fi
    if [[ -z "${TASK}" ]]; then
        TASK=$(echo "${_dts_base}" | grep -oP '(?<=task-)[^_]+')
        if [[ -z "${TASK}" ]]; then
            echo "[ERROR] Could not parse TASK from dtseries filename: ${_dts_base}"
            echo "        Set --task or the TASK variable in USER SETTINGS."
            exit 1
        fi
    fi
fi
echo "[INFO] sub=${SUB} ses=${SES} task=${TASK}"

# ── Validate METHOD ───────────────────────────────────────────────────────────
case "${METHOD}" in
    matlab_tm|reprotm) ;;
    *) echo "[ERROR] Unknown METHOD='${METHOD}'. Choose: matlab_tm, reprotm"; exit 1 ;;
esac

# ── Validate external dependency (METHOD=matlab_tm only) ───────────────────────
# template_matching_RH.m et al. (R. Hermosillo / UMN) are not bundled with PCM
# either — see config.sh's MATLAB_TM_DIR comment for why. Run
# code/setup_matlab_tm.sh once (on a login node/workstation with internet
# access, not inside a SLURM job) before using this method. Fail fast here,
# before submitting any SLURM jobs, rather than deep inside a permutation job.
if [[ "${METHOD}" == "matlab_tm" ]]; then
    if [[ ! -d "${MATLAB_TM_DIR}" || ! -f "${MATLAB_TM_DIR}/template_matching_RH.m" ]]; then
        echo "[ERROR] METHOD=matlab_tm requires template_matching_RH.m (DCAN-Labs/"
        echo "        compare_matrices_to_assign_networks), which PCM does not bundle."
        echo "        Run code/setup_matlab_tm.sh once to fetch and patch it, then retry."
        exit 1
    fi
fi

# ── Validate external dependency (METHOD=reprotm only) ─────────────────────────
# ReproTM (Godfrey et al.) is not bundled with PCM — auto-fetched by
# code/setup_reprotm.sh (default: REPROTM_FETCHED_DIR), or bring-your-own via
# REPROTM_DIR in cluster.conf. Fail fast here, before submitting any SLURM jobs,
# rather than deep inside a permutation job.
if [[ "${METHOD}" == "reprotm" ]]; then
    if [[ -z "${REPROTM_DIR}" || ! -d "${REPROTM_DIR}" || ! -f "${REPROTM_SCRIPT}" || ! -f "${REPROTM_MINSIZE_SCRIPT}" ]]; then
        echo "[ERROR] METHOD=reprotm requires ReproTM (Godfrey et al.), which PCM does not bundle."
        echo "        Run code/setup_reprotm.sh once to fetch it (pinned + patched by default),"
        echo "        or set REPROTM_DIR in cluster.conf to point at your own local install."
        echo "        See deps/reprotm/README.md for the expected folder layout."
        exit 1
    fi
fi


# ── Validate --interp-noise / --splitpct / --standardtm / --reprotm-refinescan ─
case "${intrp_noise}" in
    0|1) ;;
    *) echo "[ERROR] Invalid --interp-noise='${intrp_noise}'. Must be 0 or 1."; exit 1 ;;
esac
case "${SPLITPCT}" in
    0|1) ;;
    *) echo "[ERROR] Invalid --splitpct='${SPLITPCT}'. Must be 0 or 1."; exit 1 ;;
esac
case "${STANDARDTM}" in
    0|1) ;;
    *) echo "[ERROR] Invalid --standardtm='${STANDARDTM}'. Must be 0 or 1."; exit 1 ;;
esac
case "${REPROTM_REFINESCAN}" in
    0|1) ;;
    *) echo "[ERROR] Invalid --reprotm-refinescan='${REPROTM_REFINESCAN}'. Must be 0 or 1."; exit 1 ;;
esac

# ── Resolve TEMPLATE → TEMPLATE_PATH + SURF_ONLY ────────────────────────────
if [[ "${METHOD}" == "matlab_tm" ]]; then
    case "${TEMPLATE}" in
        ""|"scan")
            TEMPLATE_PATH="${TEMPLATE_SCAN}"
            SURF_ONLY=2
            ;;
        "abcd_full")
            TEMPLATE_PATH="${TEMPLATE_ABCD_FULL}"
            SURF_ONLY=0
            ;;
        "abcd_surf")
            TEMPLATE_PATH="${TEMPLATE_ABCD_SURF}"
            SURF_ONLY=1
            ;;
        *.mat)
            TEMPLATE_PATH="${TEMPLATE}"
            SURF_ONLY=2
            ;;
        *)
            echo "[ERROR] Invalid TEMPLATE for METHOD=matlab_tm: '${TEMPLATE}'"
            echo "        Valid values: scan (default), abcd_full, abcd_surf, or /full/path/to/template.mat"
            exit 1
            ;;
    esac
elif [[ "${METHOD}" == "reprotm" ]]; then
    # ReproTM accepts any .mat with a "seed_matrix" variable. The matlab_tm
    # templates qualify (verified: scan=91282x18, abcd_full=91282x16,
    # abcd_surf=59412x16), so the same keywords are honored here for consistency.
    _reprotm_default_nets="${REPROTM_NETWORKS_DEFAULT}"
    case "${TEMPLATE}" in
        "")
            TEMPLATE_PATH="${TEMPLATE_REPROTM_DEFAULT}"
            # Bundled ABCC template is whole-brain (91k); 0 = no surface-only restriction.
            SURF_ONLY=0
            _reprotm_default_nets="${REPROTM_NETWORKS_DEFAULT}"
            ;;
        "scan")
            TEMPLATE_PATH="${TEMPLATE_SCAN}"
            SURF_ONLY=0
            _reprotm_default_nets="${REPROTM_NETWORKS_SCAN}"
            ;;
        "abcd_full")
            TEMPLATE_PATH="${TEMPLATE_ABCD_FULL}"
            SURF_ONLY=0
            _reprotm_default_nets="${REPROTM_NETWORKS_ABCD16}"
            ;;
        "abcd_surf")
            TEMPLATE_PATH="${TEMPLATE_ABCD_SURF}"
            SURF_ONLY=1
            _reprotm_default_nets="${REPROTM_NETWORKS_ABCD16}"
            ;;
        *.mat)
            TEMPLATE_PATH="${TEMPLATE}"
            SURF_ONLY=0
            _reprotm_default_nets="${REPROTM_NETWORKS_DEFAULT}"
            ;;
        *)
            echo "[ERROR] Invalid TEMPLATE for METHOD=reprotm: '${TEMPLATE}'"
            echo "        Valid: empty (bundled default), scan, abcd_full, abcd_surf,"
            echo "        or /full/path/to/seedmap.mat"
            exit 1
            ;;
    esac
    # Network names must match the template's seed_matrix columns. Fall back to the
    # ordering that matches the chosen template if the user did not set them.
    if [[ -z "${REPROTM_NETWORKS}" ]]; then
        REPROTM_NETWORKS="${_reprotm_default_nets}"
        if [[ "${TEMPLATE}" == *.mat ]]; then
            echo "[WARN] Custom --template given but REPROTM_NETWORKS is empty; using the"
            echo "       default 18-net list. Set REPROTM_NETWORKS to match your template's"
            echo "       seed_matrix columns if they differ, or ReproTM will mislabel networks."
        fi
    fi
fi

if [[ ! -f "${TEMPLATE_PATH}" ]]; then
    echo "[ERROR] Template file not found: ${TEMPLATE_PATH}"
    exit 1
fi
echo "[INFO] TEMPLATE_PATH=${TEMPLATE_PATH} SURF_ONLY=${SURF_ONLY}"

# ── Derive TEMPLATE_LABEL ─────────────────────────────────────────────────────
if [[ -z "${TEMPLATE_LABEL}" ]]; then
    if [[ "${METHOD}" == "matlab_tm" ]]; then
        case "${TEMPLATE}" in
            ""|"scan")   TEMPLATE_LABEL="scan" ;;
            "abcd_full") TEMPLATE_LABEL="abcd_full" ;;
            "abcd_surf") TEMPLATE_LABEL="abcd_surf" ;;
            *)           TEMPLATE_LABEL="$(basename "${TEMPLATE_PATH}" .mat)" ;;
        esac
    else  # reprotm
        case "${TEMPLATE}" in
            "")          TEMPLATE_LABEL="abcc18" ;;
            "scan")      TEMPLATE_LABEL="scan" ;;
            "abcd_full") TEMPLATE_LABEL="abcd_full" ;;
            "abcd_surf") TEMPLATE_LABEL="abcd_surf" ;;
            *)           TEMPLATE_LABEL="$(basename "${TEMPLATE_PATH}" .mat)" ;;
        esac
    fi
fi

# ── Build task folder name ─────────────────────────────────────────────────────
case "${METHOD}" in
    matlab_tm) _method_token="matlabTM" ;;
    reprotm)   _method_token="reproTM" ;;
esac

case "${shuffle_option}" in
    bootstrap)          _sh_token="sh-bootstrap" ;;
    TRs)                _sh_token="sh-TRs" ;;
    run)                _sh_token="sh-run" ;;
    bagging)            _sh_token="sh-bagging${shuffle_chunk_size}m" ;;
    bootstrap_variable) _sh_token="sh-bsvar${shuffle_chunk_size}m" ;;
    subsample)          _sh_token="sh-subsample${shuffle_chunk_size}m" ;;
    percent)            _sh_token="sh-pct${shuffle_chunk_size}" ;;
    minutes)            _sh_token="sh-min${shuffle_chunk_size}" ;;
    *)                  _sh_token="sh-${shuffle_option}" ;;
esac

_fd_part="";     [[ "${FD}" != "0.2" ]]         && _fd_part="_fd-${FD}"
_pct_part="";    [[ "${percent_holdout}" != "100" ]] && _pct_part="_pct-${percent_holdout}"
_split_part="";  [[ "${SPLITHALF}" == "1" ]]    && _split_part="_splithalf"

# Base name — trunc suffix added per-submission in the loop below
TASK_FOLDER_BASE="task-${TASK}_method-${_method_token}_tmpl-${TEMPLATE_LABEL}_${_sh_token}${_fd_part}${_pct_part}${_split_part}"
echo "[INFO] TASK_FOLDER_BASE=${TASK_FOLDER_BASE}"
export TASK_FOLDER_BASE TEMPLATE_LABEL

# ── COMBINED_FIGS: aggregate all methods and generate combined confidence maps ─
if [[ "${COMBINED_FIGS}" == "1" ]]; then
    _combined_suffix="combined"
    [[ -n "${COMBINED_NAME}" ]] && _combined_suffix="combined_${COMBINED_NAME}"
    _combined_dir="${BASEDIR}/sub-${SUB}/ses-${SES}/task-${TASK}_${_combined_suffix}"
    mkdir -p "${_combined_dir}/logs"

    _conc_files=()
    if [[ ${#COMBINED_INCLUDE[@]} -gt 0 ]]; then
        echo "[INFO] Including ${#COMBINED_INCLUDE[@]} explicitly listed folder(s)."
        for _f in "${COMBINED_INCLUDE[@]}"; do
            # Accept an absolute/relative path, or a bare task-folder name
            # resolved under sub-/ses-.
            _folder="${_f}"
            [[ ! -d "${_folder}" ]] && _folder="${BASEDIR}/sub-${SUB}/ses-${SES}/${_f}"
            _conc="${_folder%/}/successful_perms.conc"
            if [[ ! -f "${_conc}" ]]; then
                echo "[ERROR] No successful_perms.conc in included folder: ${_f}"
                echo "        Looked for: ${_conc}"
                exit 1
            fi
            _conc_files+=("${_conc}")
        done
    else
        echo "[INFO] Scanning for successful_perms.conc under task-${TASK}_* ..."
        while IFS= read -r -d '' _conc; do
            _conc_files+=("${_conc}")
        done < <(find "${BASEDIR}/sub-${SUB}/ses-${SES}" \
            -maxdepth 2 -name "successful_perms.conc" \
            -path "*/task-${TASK}_*/*" \
            -print0 2>/dev/null | sort -z)
    fi

    if [[ ${#_conc_files[@]} -eq 0 ]]; then
        echo "[ERROR] No successful_perms.conc files found under:"
        echo "        ${BASEDIR}/sub-${SUB}/ses-${SES}/task-${TASK}_*/"
        echo "        Run at least one permutation method first,"
        echo "        or check the --includefolder paths."
        exit 1
    fi

    echo "[INFO] Found ${#_conc_files[@]} conc file(s):"
    for _c in "${_conc_files[@]}"; do echo "  ${_c}"; done

    _combined_conc="${_combined_dir}/all_perms.conc"
    : > "${_combined_conc}"
    for _c in "${_conc_files[@]}"; do
        cat "${_c}" >> "${_combined_conc}"
    done
    _n_perms=$(wc -l < "${_combined_conc}")
    echo "[INFO] Combined: ${_n_perms} dscalars → ${_combined_conc}"

    _dt=$(date +"%Y%m%d%H%M%S")
    _log_dir="${_combined_dir}/logs"
    : "${mem:=${MAKEFIGS_MEM:-64gb}}"
    : "${time:=${MAKEFIGS_TIME:-01:00:00}}"

    echo "[INFO] Submitting combined figures job (mem=${mem} time=${time})..."
    sbatch \
        --job-name="PCM_combined_figs_${SUB}" \
        --partition="${partitions}" \
        --account="${group}" \
        --mem="${mem}" \
        --time="${time}" \
        --output="${_log_dir}/${SUB}_${SES}_combined_figs_${_dt}_%A.out" \
        --error="${_log_dir}/${SUB}_${SES}_combined_figs_${_dt}_%A.err" \
        "${MAKE_FIGS_SCRIPT}" \
            "${_combined_dir}" "${_combined_conc}" "${percent_holdout}" "1"
    echo "[INFO] Combined figures job submitted. Output: ${_combined_dir}/"
    exit 0
fi

export METHOD TEMPLATE_PATH SURF_ONLY SMOOTHING_KERNEL
export FISHER_Z REMOVE_OUTLIERS
export REPROTM_NETWORKS REPROTM_MINSIZE REPROTM_TEMPLATE_MINTHRESH REPROTM_REFINESCAN REPROTM_REFINESCAN_MINTHRESH REPROTM_DSCALAR_TEMPLATE
export SCRATCH_DIR

# ── Method-specific resource defaults ────────────────────────────────────────
# Defaults live in cluster.conf (MATLABTM_*/REPROTM_* — one editable place per
# site) with literal fallbacks here in case an older cluster.conf doesn't
# define them yet. ntasks/mem/tmpspace/time above (USER SETTINGS or CLI flags)
# still take precedence when set for a specific run.
if [[ "${METHOD}" == "reprotm" ]]; then
    # ReproTM is serial Python. Memory is driven by loading the full dconn:
    # nibabel get_fdata() returns float64, so a 91k whole-brain dconn is ~66 GB
    # in RAM (plus the ~33 GB single-precision z-scored dconn on /tmp, and the
    # MATLAB dconn build before it). 200 GB gives headroom; drop to ~96 GB for
    # surface-only (59412) templates. The per-greyordinate matching loop is the
    # slow part — allow generous wall time.
    : "${ntasks:=${REPROTM_NTASKS:-1}}"
    : "${mem:=${REPROTM_MEM:-200gb}}"
    : "${tmpspace:=${REPROTM_TMPSPACE:-100gb}}"
    : "${time:=${REPROTM_TIME:-12:00:00}}"
else
    # 128gb: Zscore_dconn peaks ~99 GB loading+converting the 91k dconn (single)
    # plus MATLAB overhead; 110 GB OOM-killed it, so this adds headroom.
    : "${ntasks:=${MATLABTM_NTASKS:-1}}"
    : "${mem:=${MATLABTM_MEM:-128gb}}"
    : "${tmpspace:=${MATLABTM_TMPSPACE:-100gb}}"
    : "${time:=${MATLABTM_TIME:-10:00:00}}"
fi
echo "[INFO] METHOD=${METHOD} | ntasks=${ntasks} mem=${mem} tmpspace=${tmpspace} time=${time}"

# ── Motion file handling ──────────────────────────────────────────────────────
case "${motion_file}" in
    *.hdf5)
        echo "[INFO] Converting HDF5 motion file to .mat..."
        module load "${MATLAB_MODULE}"
        _motion_out="$(dirname "${motion_file}")"
        _mat_file="${motion_file%.hdf5}_power_2014_FD_only.mat"
        if [[ -f "${_mat_file}" ]]; then
            echo "[INFO] Motion .mat already exists, using it."
        else
            matlab -nodisplay -nosplash -r \
                "${MATLAB_ADDPATH} xcpd2dcanmotion('${motion_file}', '${_motion_out}'); exit;"
        fi
        motion_file="${_mat_file}"
        MOTION_TYPE="mat"
        ;;
    *.mat)
        MOTION_TYPE="mat"
        ;;
    *.txt)
        MOTION_TYPE="txt"
        if [[ -n "${STARTMINS}" ]]; then
            echo "[ERROR] A .txt motion mask and STARTMINS/time truncation cannot be used together."
            echo "        Pre-truncate your data and mask manually, then run without STARTMINS."
            exit 1
        fi
        echo "[INFO] Using binary txt motion mask (bypassing FD filtering): ${motion_file}"
        ;;
    *)
        echo "[ERROR] Unrecognised motion file extension: ${motion_file}"
        echo "        Accepted: .mat (DCAN), .hdf5 (XCP-D, auto-converted), .txt (binary mask)"
        exit 1
        ;;
esac
export motion_file MOTION_TYPE

# ── Spatial interpolation ─────────────────────────────────────────────────────
module load "${WORKBENCH_MODULE}"
if [[ "${intrp_noise}" == "0" && "${dtseries}" != *_spatially_interpolated.dtseries.nii ]]; then
    echo "[INFO] --interp-noise not set and this dtseries doesn't look pre-interpolated"
    echo "       (no _spatially_interpolated.dtseries.nii suffix). Not running it automatically"
    echo "       -- pass --interp-noise 1 if this scan needs spatial noise interpolation."
fi
if [[ "${intrp_noise}" == "1" ]]; then
    _dts_base_noext="${dtseries%.dtseries.nii}"
    interpolated_file="${_dts_base_noext}_spatially_interpolated.dtseries.nii"

    if [[ -f "${interpolated_file}" ]]; then
        echo "[INFO] Interpolated file already exists, skipping interpolation step."
        dtseries="${interpolated_file}"
        intrp_noise=0
    else
        echo "[INFO] Running spatial noise interpolation..."
        matlab -nodisplay -nosplash -r \
            "${MATLAB_ADDPATH} \
             infile='${dtseries}'; WB_CMD='${WB_CMD}'; runLocally=0; \
             interpolate_noise_for_timeseries(infile, WB_CMD, runLocally); exit;"
        intrp_noise=0
        dtseries="${interpolated_file}"
    fi
fi

echo "[INFO] dtseries: ${dtseries}"
ls "${dtseries}" || { echo "[ERROR] dtseries file not found."; exit 1; }

# ── Calculate TR and total scan time ──────────────────────────────────────────
TR=$(${WB_CMD} -file-information "${dtseries}" -only-step-interval)
totalTRs=$(${WB_CMD} -file-information "${dtseries}" -only-number-of-maps)
total_time_seconds=$(echo "${TR} * ${totalTRs}" | bc)
total_time_minutes=$(echo "scale=2; ${total_time_seconds} / 60" | bc)
half_minutes=$(echo "scale=0; ${total_time_minutes} / 2" | bc)

# Compute MIN (ground-truth/holdout cap, in minutes) for a given scan length.
# Mirrors the auto formula: 85% of half the scan (half minus a 15% margin).
_compute_min() {  # $1 = scan length in minutes -> echoes MIN
    local _half _np _npr
    _half=$(echo "scale=0; ${1} / 2" | bc)
    _np=$(echo "${_half} * 0.15" | bc)
    _npr=$(echo "scale=0; ${_np} / 1" | bc)
    echo "$(echo "${_half} - ${_npr}" | bc)"
}

if [[ -z "${MIN}" ]]; then
    _MIN_AUTO=1
    MIN=$(_compute_min "${total_time_minutes}")
    echo "[INFO] Total scan time: ${total_time_minutes} min | Half: ${half_minutes} min | MIN: ${MIN} min (auto)"
else
    _MIN_AUTO=0
    echo "[INFO] Total scan time: ${total_time_minutes} min | Half: ${half_minutes} min | MIN: ${MIN} min (user-specified)"
fi

# ── Resolve time-truncation mode ──────────────────────────────────────────────
if [[ -z "${STARTMINS}" ]]; then
    _run_mode="full"
elif [[ -n "${ENDMINS}" && -n "${INCREMENT}" ]]; then
    _run_mode="loop"
    KEEP_FROM="${KEEP_FROM:-start}"
else
    _run_mode="single"
    KEEP_FROM="${KEEP_FROM:-start}"
fi
echo "[INFO] Time-truncation mode: ${_run_mode}"
[[ "${_run_mode}" != "full" ]] && echo "[INFO] STARTMINS=${STARTMINS} KEEP_FROM=${KEEP_FROM}"
[[ "${_run_mode}" == "loop"  ]] && echo "[INFO] INCREMENT=${INCREMENT} ENDMINS=${ENDMINS}"

# ── Helper: submit the orchestrator ───────────────────────────────────────────
# Args: SUB SES TASK BASEDIR dtseries surf_L surf_R motion_file
_submit_orchestrator() {
    local _sub=$1 _ses=$2 _task=$3 _basedir=$4 \
          _dtseries=$5 _surf_l=$6 _surf_r=$7 _motion=$8
    sbatch --partition="${SLURM_PARTITION}" --account="${SLURM_ACCOUNT}" \
        --mem="${ORCHESTRATOR_MEM:-20gb}" --time="${ORCHESTRATOR_TIME:-48:00:00}" \
        "${CODE_DIR}/code/orchestrate_PCM.sh" \
            "${_sub}" "${_ses}" "${_task}" "${_basedir}" \
            "${_dtseries}" "${_surf_l}" "${_surf_r}" "${_motion}" \
            "${TEMPLATE_PATH}" "${SURF_ONLY}" \
            "${intrp_noise}" "${percent_holdout}" "${FD}" "${NUM}" \
            "${shuffle_option}" "${shuffle_chunk_size}" \
            "${SPLITHALF}" "${SPLITPCT}" "${STANDARDTM}" \
            "${JobName}" "${ntasks:-1}" "${tmpspace}" "${mem}" "${time}" "${mail}" \
            "${partitions}" "${group}" "${MIN}" "${TR}" \
            "${MAKEFIGS_MEM:-64gb}" "${MAKEFIGS_TIME:-1:00:00}"
}

# ── Submit orchestrator ────────────────────────────────────────────────────────
if [[ "${_run_mode}" == "full" ]]; then
    export TASK_FOLDER="${TASK_FOLDER_BASE}"
    echo "[INFO] Submitting PCM for full dataset | TASK_FOLDER=${TASK_FOLDER}"
    _submit_orchestrator "${SUB}" "${SES}" "${TASK}" \
        "${BASEDIR}" "${dtseries}" "${surf_L}" "${surf_R}" "${motion_file}"

else
    if [[ "${_run_mode}" == "single" ]]; then
        _minutes_list="${STARTMINS}"
    else
        _minutes_list=$(seq "${STARTMINS}" "${INCREMENT}" "${ENDMINS}")
    fi

    module load "${MATLAB_MODULE}"
    for minutes in ${_minutes_list}; do
        export TASK_FOLDER="${TASK_FOLDER_BASE}_trunc-${minutes}m-${KEEP_FROM:-start}"
        echo "[INFO] Submitting PCM for ${minutes} min from ${KEEP_FROM} | TASK_FOLDER=${TASK_FOLDER}"

        # Recompute MIN from the truncated length (unless the user fixed it with
        # --minutes). MIN auto-computed above is based on the FULL scan; reusing it
        # for a shorter truncation would exceed the data (e.g. MIN=63 on a 5-min
        # cut) and silently collapse the holdout to "all frames".
        if [[ "${_MIN_AUTO}" == "1" ]]; then
            MIN=$(_compute_min "${minutes}")
            echo "[INFO]   MIN recomputed for ${minutes}-min truncation: ${MIN} min"
        fi

        _trunc_dir="${BASEDIR}/truncated_inputs/task-${TASK}/${minutes}m-from-${KEEP_FROM:-start}"
        mkdir -p "${_trunc_dir}"

        # Copy surface files to the truncated inputs directory.
        cp "${surf_L}" "${_trunc_dir}/"
        cp "${surf_R}" "${_trunc_dir}/"

        # Truncate dtseries and extract the matching motion window.
        matlab -nodisplay -nosplash -r \
            "${MATLAB_ADDPATH} \
             extract_minutes_dtseries_and_motion('${dtseries}', '${motion_file}', \
             '${_trunc_dir}', '${TR}', '${minutes}', '${KEEP_FROM}'); exit;"

        # extract_minutes_dtseries_and_motion.m names its outputs with the
        # minutes appended to the task: task-TASK-Nminutes_truncated_bold...
        _trunc_dts="${_trunc_dir}/sub-${SUB}_ses-${SES}_task-${TASK}-${minutes}minutes_truncated_bold.dtseries.nii"
        _trunc_motion="${_trunc_dir}/sub-${SUB}_ses-${SES}_task-${TASK}-${minutes}minutes_desc-dcan_qc_power_2014_FD_only.mat"
        _trunc_surf_L="${_trunc_dir}/$(basename "${surf_L}")"
        _trunc_surf_R="${_trunc_dir}/$(basename "${surf_R}")"

        if [[ ! -f "${_trunc_dts}" ]]; then
            echo "[ERROR] Truncated dtseries not found: ${_trunc_dts}"; exit 1
        fi
        if [[ ! -f "${_trunc_motion}" ]]; then
            echo "[ERROR] Truncated motion file not found: ${_trunc_motion}"; exit 1
        fi

        _submit_orchestrator "${SUB}" "${SES}" "${TASK}" \
            "${BASEDIR}" \
            "${_trunc_dts}" "${_trunc_surf_L}" "${_trunc_surf_R}" "${_trunc_motion}"
    done
fi
