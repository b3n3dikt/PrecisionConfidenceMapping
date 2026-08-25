#!/usr/bin/env bash
#SBATCH -J threshmaps_priority_indiv
#SBATCH --nodes=1
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=25gb
#SBATCH -t 01:30:00
#SBATCH -p msismall
#SBATCH -o output_logs/threshmaps_priority_indiv_%A_%a.out
#SBATCH -e output_logs/threshmaps_priority_indiv_%A_%a.err
#SBATCH -A faird

set -euo pipefail

module load workbench/1.5.0
module load matlab

###############################################################################
# PATHS
###############################################################################
MATLAB_FUN_DIR="/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions"
SUPPORT_DIR="/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files"
CIFTI_DIR="/projects/standard/faird/shared/code/external/utilities/cifti-matlab"
NETWORK_NAMES_MAT="/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat"

###############################################################################
# HELP
###############################################################################
usage() {
  cat <<'EOF'
run_threshold_confidence_maps_priority_and_individuals.sh

USAGE
  sbatch run_threshold_confidence_maps_priority_and_individuals.sh FIGDIR [options]

REQUIRED
  FIGDIR
    Path to the *ciftis* directory that contains Probability_Maps_*.dscalar.nii files.
    Example:
      /.../ExpData-fullm/figures/Percent_Holdout-100/ciftis

OPTIONS
  --thresholds "0.0 0.1 0.2"     Space-separated thresholds (quote it)
                                Default: 0 0.1 ... 0.9

  --priority "{'SCAN'}"         MATLAB literal defining priority order (names or IDs)
  --priority "[9 1 2]"          Example: CO then DMN then VIS
  --priority "[]"               Explicitly no priority (default)

  --combined-only               Only write combined all-networks outputs (no Individual_Networks)

  --force                        Re-run even if outputs already exist

  --list-networks               Print network_names index mapping (1..N)

OUTPUTS (per threshold T)
  If no priority:
    FIGDIR/Thresholded-T/
  If priority provided:
    FIGDIR/Thresholded-T_<TAG>_priority/

  Inside output folder:
    PCM_confidence_map_to_bin_all-networks_thresh-T.dscalar.nii
    PCM_confidence_map_to_bin_all-networks_thresh-T.dlabel.nii
    Individual_Networks/ (unless --combined-only)
      network-<ABBR>.dscalar.nii   (0/1)
      network-<ABBR>.dlabel.nii
      label-<ABBR>.txt

EOF
  exit 1
}

###############################################################################
# LIST NETWORKS
###############################################################################
list_networks() {
  matlab -nodisplay -nosplash -r "
    try
      load('${NETWORK_NAMES_MAT}');
      for i = 1:numel(network_names)
        fprintf('%2d  %s\n', i, network_names{i});
      end
    catch ME
      disp(getReport(ME,'extended'));
      exit(1);
    end
    exit(0);
  "
}

###############################################################################
# MAKE TAG FOR PRIORITY FOLDER NAME (human readable)
# - If priority is names: {'SCAN','CO'} -> SCAN-CO
# - If numeric: [18 9] -> 18-9
###############################################################################
priority_tag() {
  local p="$1"
  if [[ -z "$p" || "$p" == "[]" ]]; then
    echo ""
    return
  fi
  # strip spaces
  p="${p//[[:space:]]/}"
  # remove braces/brackets
  p="${p//\{ /}"
  p="${p//\}/}"
  p="${p//\{/}"
  p="${p//\}/}"
  p="${p//\[/}"
  p="${p//\]/}"
  # remove quotes
  p="${p//\'/}"
  p="${p//\"/}"
  # commas -> dash
  p="${p//,/ -}"
  p="${p//,/}"
  p="${p// /-}"
  # cleanup common artifacts
  p="${p//;/}"
  echo "$p"
}

###############################################################################
# ARG PARSING
###############################################################################
if [[ $# -lt 1 ]]; then usage; fi

FORCE=0
MAKE_INDIV=1
PRIORITY="[]"
USER_THRESH=""

# Handle --list-networks anywhere
for arg in "$@"; do
  if [[ "$arg" == "--list-networks" ]]; then
    list_networks
    exit 0
  fi
done

FIGDIR="$1"; shift
[[ -d "$FIGDIR" ]] || { echo "ERROR: FIGDIR not found: $FIGDIR" >&2; exit 2; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --thresholds)
      USER_THRESH="$2"
      shift 2
      ;;
    --priority)
      PRIORITY="$2"
      shift 2
      ;;
    --combined-only)
      MAKE_INDIV=0
      shift 1
      ;;
    --force)
      FORCE=1
      shift 1
      ;;
    -h|--help)
      usage
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      ;;
  esac
done

if [[ -z "$USER_THRESH" ]]; then
  THRESH_SPEC="$(seq 0 0.1 0.9 | xargs printf "%.1f " )"
else
  THRESH_SPEC="$USER_THRESH"
fi

# Support commas too
THRESH_SPEC="${THRESH_SPEC//,/ }"
read -r -a THRESH_LIST <<< "$THRESH_SPEC"
(( ${#THRESH_LIST[@]} > 0 )) || { echo "ERROR: no thresholds provided" >&2; exit 3; }

# quick sanity check that there is at least one dscalar to work on
if [[ $(ls -1 "${FIGDIR}"/*.dscalar.nii 2>/dev/null | wc -l) -eq 0 ]]; then
  echo "No .dscalar.nii files found in $FIGDIR" >&2
  exit 4
fi

PTAG="$(priority_tag "$PRIORITY")"

echo "------------------------------------------------------------"
echo "  Working directory : $FIGDIR"
echo "  Threshold(s)      : ${THRESH_LIST[*]}"
echo "  Individuals       : $MAKE_INDIV"
echo "  Priority literal  : $PRIORITY"
echo "  Priority tag      : ${PTAG:-none}"
echo "  Force             : $FORCE"
echo "------------------------------------------------------------"

###############################################################################
# RUN MATLAB ON ONE THRESHOLD
###############################################################################
run_threshold_matlab() {
  local DIR="$1"
  local THR="$2"
  local PRIORITY_LITERAL="$3"
  local MAKEIND="$4"
  local FORCE_RUN="$5"

  local THR_STR
  THR_STR="$(printf "%g" "$THR")"

  local outfolder
  if [[ -z "$PTAG" ]]; then
    outfolder="${DIR}/Thresholded-${THR_STR}"
  else
    outfolder="${DIR}/Thresholded-${THR_STR}_${PTAG}_priority"
  fi

  local OUT_DSC="${outfolder}/PCM_confidence_map_to_bin_all-networks_thresh-${THR_STR}.dscalar.nii"
  local LOG_DIR="${DIR}/logs"
  mkdir -p "$outfolder" "$LOG_DIR"

  if (( FORCE_RUN == 0 )) && [[ -f "$OUT_DSC" ]]; then
    echo "  -> Skip ${THR_STR} (already exists): $OUT_DSC"
    return 0
  fi

  echo "  -> Run threshold=${THR_STR} outfolder=$(basename "$outfolder")"

  # Append logs per threshold + tag so you can compare runs cleanly
  local LOG_FILE="${LOG_DIR}/matlab_threshold_${THR_STR}_ptag-${PTAG:-none}.log"

  matlab -nodisplay -nosplash -r \
    "try; \
      addpath('${MATLAB_FUN_DIR}'); \
      addpath('${SUPPORT_DIR}'); \
      addpath('${CIFTI_DIR}'); \
      threshold_confidence_maps_with_priority('${DIR}', ${THR}, ${MAKEIND}, ${PRIORITY_LITERAL}); \
     catch ME; disp(getReport(ME,'extended')); exit(1); \
     end; \
     exit(0);" \
    >> "$LOG_FILE" 2>&1
}

for THR in "${THRESH_LIST[@]}"; do
  [[ "$THR" =~ ^[0-9]*\.?[0-9]+$ ]] || { echo "ERROR: Threshold must be numeric (got: $THR)" >&2; exit 5; }
  run_threshold_matlab "$FIGDIR" "$THR" "$PRIORITY" "$MAKE_INDIV" "$FORCE"
done

echo "Done."

# #!/usr/bin/env bash
# # run_threshold_confidence_maps_with_priority.sh
# #
# # Calls: threshold_confidence_maps_with_priority(FIGDIR, priority, threshold)
# #
# # USAGE:
# #   run_threshold_confidence_maps_with_priority.sh --list-networks
# #   run_threshold_confidence_maps_with_priority.sh [--force] /path/to/FIGDIR 0.5
# #   run_threshold_confidence_maps_with_priority.sh [--force] /path/to/FIGDIR "{'CO','DMN','VIS'}" 0.5
# #   run_threshold_confidence_maps_with_priority.sh [--force] /path/to/FIGDIR "[]" 0.5
# #   run_threshold_confidence_maps_with_priority.sh [--force] /path/to/FIGDIR "{'SCAN'}" "0.1 0.2 0.5"
# #   run_threshold_confidence_maps_with_priority.sh [--force] /path/to/FIGDIR "[]" "0.1,0.2,0.5"
# #
# # Notes:
# # - If you pass a MATLAB literal like "{'CO','DMN'}" you MUST quote it.
# # - If you omit PRIORITY, it defaults to [] (no override).
# # - This script supports multiple thresholds (comma/space-separated).
# # - Skip logic is now per-output-file (priority vs no-priority), not just folder existence.
# # - Use --force to rerun even if an output exists.
# #
# # Output location:
# #   FIGDIR/Thresholded-<TSTR>/
# # where TSTR matches MATLAB sprintf('%g') (so 0.0 -> 0, 0.50 -> 0.5)
# #
# # Logs:
# #   FIGDIR/logs/matlab_threshold_<TSTR>_priority-<tag>.log

# set -euo pipefail

# MATLAB_FUN_DIR="/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/"
# SUPPORT_DIR="/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/"
# CIFTI_DIR="/projects/standard/faird/shared/code/external/utilities/cifti-matlab"
# NETWORK_NAMES_MAT="/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat"

# die() { echo "ERROR: $*" >&2; exit 1; }

# usage() {
#   cat <<'EOF'
# run_threshold_confidence_maps_with_priority.sh

# USAGE
#   1) List network name -> ID mapping:
#      run_threshold_confidence_maps_with_priority.sh --list-networks

#   2) Run WITHOUT priority override:
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR 0.5
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "0.1 0.2 0.5"
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "0.1,0.2,0.5"

#   3) Run WITH priority override (MATLAB literal):
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "{'CO','DMN','VIS'}" 0.5
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "[9 1 2]" 0.5
#      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "{'SCAN'}" "0.1 0.2 0.5"

#   4) Force re-run even if outputs exist:
#      run_threshold_confidence_maps_with_priority.sh --force /path/to/FIGDIR "{'SCAN'}" 0.5

# ARGUMENTS
#   FIGDIR     Directory containing per-network Probability_Maps_*.dscalar.nii files
#   PRIORITY   Optional. MATLAB literal for priority list:
#              - "[]" (no override)
#              - "[9 1 2]" (numeric IDs)
#              - "{'CO','DMN','VIS'}" (names; must match network_names.mat)
#   THRESH     Threshold value OR list:
#              - "0.5"
#              - "0.1 0.2 0.5" (quote it)
#              - "0.1,0.2,0.5"

# OUTPUT
#   Writes into: FIGDIR/Thresholded-<TSTR>/
#   TSTR matches MATLAB sprintf('%g') behavior (0.0 -> 0, 0.50 -> 0.5).

# EOF
# }

# list_networks() {
#   matlab -nodisplay -nosplash -r "
#     try
#       load('${NETWORK_NAMES_MAT}');
#       for i = 1:numel(network_names)
#         fprintf('%2d  %s\n', i, network_names{i});
#       end
#     catch ME
#       disp(getReport(ME,'extended'));
#       exit(1);
#     end
#     exit(0);
#   "
# }

# priority_tag_for_log() {
#   local p="$1"
#   if [[ -z "$p" || "$p" == "[]" ]]; then
#     echo "none"
#     return
#   fi
#   # filesystem-friendly-ish tag for log naming
#   p="${p//[[:space:]]/}"
#   p="${p//\'/}"     # remove quotes
#   p="${p//\{/}"
#   p="${p//\}/}"
#   p="${p//,/ -}"
#   p="${p//[/}"
#   p="${p//]/}"
#   echo "$p"
# }

# ###############################################################################
# # FUNCTION TO RUN MATLAB FOR A GIVEN DIRECTORY + THRESHOLD
# ###############################################################################
# run_threshold_matlab() {
#   local DIR="$1"
#   local PRIORITY_LITERAL="$2"
#   local T="$3"

#   # Normalize threshold string to match MATLAB sprintf('%g')
#   local TSTR
#   TSTR="$(printf "%g" "$T")"
#   local OUTDIR="${DIR}/Thresholded-${TSTR}"

#   # Log tag (just for logfile readability)
#   local PTAG
#   PTAG="$(priority_tag_for_log "$PRIORITY_LITERAL")"

#   # -------------------------------------------------------
#   # Skip logic: check for specific output FILES, not folder.
#   # - No-priority run skips only if _priority-none OR legacy (no _priority) exists.
#   # - Priority run skips only if a _priority-<something> exists that is NOT none.
#   # -------------------------------------------------------
#   if (( FORCE == 0 )); then
#     shopt -s nullglob

#     if [[ -z "$PRIORITY_LITERAL" || "$PRIORITY_LITERAL" == "[]" ]]; then
#       # NO PRIORITY: look for exact none (new) or legacy (old)
#       local candidates=(
#         "${OUTDIR}/PCM_confidence_map_to_bin_all-networks_thresh-${TSTR}_priority-none.dscalar.nii"
#         "${OUTDIR}/PCM_confidence_map_to_bin_all-networks_thresh-${TSTR}.dscalar.nii"
#       )
#       local found=0
#       for f in "${candidates[@]}"; do
#         [[ -f "$f" ]] && found=1
#       done
#       if (( found )); then
#         echo "   Found existing NO-PRIORITY output for threshold ${TSTR} ... skipping."
#         for f in "${candidates[@]}"; do
#           [[ -f "$f" ]] && echo "     $f"
#         done
#         shopt -u nullglob
#         return 0
#       fi
#     else
#       # PRIORITY: any _priority-* except _priority-none counts
#       local matches=( "${OUTDIR}/PCM_confidence_map_to_bin_all-networks_thresh-${TSTR}_priority-"*.dscalar.nii )
#       local filtered=()
#       for f in "${matches[@]}"; do
#         [[ "$f" == *"_priority-none.dscalar.nii" ]] && continue
#         filtered+=( "$f" )
#       done
#       if (( ${#filtered[@]} > 0 )); then
#         echo "   Found existing PRIORITY output(s) for threshold ${TSTR} ... skipping."
#         printf "     %s\n" "${filtered[@]}"
#         shopt -u nullglob
#         return 0
#       fi
#     fi

#     shopt -u nullglob
#   fi

#   echo "   Running threshold=${TSTR} for ${DIR} (priority=${PRIORITY_LITERAL})"
#   local LOG_FILE="${DIR}/logs/matlab_threshold_${TSTR}_priority-${PTAG}.log"
#   mkdir -p "$(dirname "$LOG_FILE")"

#   matlab -nodisplay -nosplash -r \
#     "try; \
#        addpath('${MATLAB_FUN_DIR}'); \
#        addpath('${SUPPORT_DIR}'); \
#        addpath('${CIFTI_DIR}'); \
#        threshold_confidence_maps_with_priority('${DIR}', ${PRIORITY_LITERAL}, ${T}); \
#      catch ME; disp(getReport(ME,'extended')); exit(1); \
#      end; \
#      exit(0);" \
#     >> "${LOG_FILE}" 2>&1
# }

# ###############################################################################
# # ARG PARSING
# ###############################################################################
# FORCE=0
# if [[ "${1:-}" == "--force" ]]; then
#   FORCE=1
#   shift
# fi

# if [[ $# -eq 0 ]]; then
#   usage
#   exit 1
# fi

# case "${1:-}" in
#   -h|--help)
#     usage
#     exit 0
#     ;;
#   --list-networks)
#     list_networks
#     exit 0
#     ;;
# esac

# # Forms:
# #   (A) FIGDIR THRESH_OR_LIST
# #   (B) FIGDIR PRIORITY THRESH_OR_LIST
# FIGDIR="${1:-}"
# [[ -d "$FIGDIR" ]] || die "FIGDIR not found: $FIGDIR"

# if [[ $# -eq 2 ]]; then
#   PRIORITY="[]"
#   THRESH_SPEC="${2}"
# elif [[ $# -eq 3 ]]; then
#   PRIORITY="${2}"
#   THRESH_SPEC="${3}"
# else
#   usage
#   die "Expected 2 or 3 arguments (or --list-networks)."
# fi

# # Turn commas into spaces, then read into array
# THRESH_SPEC="${THRESH_SPEC//,/ }"
# read -r -a THRESH_LIST <<< "$THRESH_SPEC"
# (( ${#THRESH_LIST[@]} > 0 )) || die "No thresholds provided."

# # Run each threshold
# for THRESH in "${THRESH_LIST[@]}"; do
#   [[ "$THRESH" =~ ^[0-9]*\.?[0-9]+$ ]] || die "Threshold must be numeric (got: $THRESH)"
#   run_threshold_matlab "$FIGDIR" "$PRIORITY" "$THRESH"
# done

# echo "Done."

# The above Which runs this matlab code
# function threshold_confidence_maps_with_priority(FIGDIR, priority, threshold_value)
# % threshold_confidence_maps(FIGDIR, priority, threshold_value)
# %
# % Thresholds + binarizes per-network .dscalar probability maps in FIGDIR,
# % resolves overlaps (ties), and writes a single combined "label-like" dscalar.
# %
# % DEFAULT tie-break: highest probability wins.
# % OPTIONAL override: if "priority" is provided, ties are resolved by the first
# % network in "priority" that is present at that vertex (even if lower prob).
# %
# % priority can be:
# %   [] or ''                -> no override (default max-prob)
# %   numeric vector          -> network IDs, e.g. [9 1 3]
# %   string/char             -> single network name, e.g. "CO" or 'CO'
# %   cell array of strings   -> e.g. {'CO','DMN','VIS'}
# %
# % Notes:
# % - Requires: network_names.mat and cifti-matlab utilities on your system.

#     % -------------------------------------------------------
#     % Setup paths & load network_names
#     % -------------------------------------------------------
#     load('/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat');
#     addpath(genpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'));
#     addpath(genpath('/projects/standard/faird/shared/code/external/utilities/gifti/'));
#     addpath(genpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/'));
#     wb_command = '/projects/standard/faird/shared/code/external/utilities/workbench/1.5.0/workbench/bin_rh_linux64/wb_command'; %#ok<NASGU>

#     % Indices of the networks you care about
#     network_indices = [1,2,3,5,7:16,18];  % Adjust as needed

#     % Probability & thresholded placeholders
#     probability_matrix = zeros(91282, 18, 'single');
#     thresholded_matrix = zeros(91282, 18, 'single');

#     % -------------------------------------------------------
#     % Loop networks: read probability maps and threshold
#     % -------------------------------------------------------
#     clear dscalar
#     for i = network_indices
#         name = network_names{i};  % e.g. 'DMN'

#         % Probability map name
#         fpath = fullfile(FIGDIR, ...
#             sprintf('Probability_Maps_across_perms_TM_Percent_holdout_%s_network_probability.dscalar.nii', name));

#         % If file missing, fill with zeros
#         if ~exist(fpath, 'file')
#             warning('Network "%s" not found in %s. Filling with zeros.', name, fpath);
#             data_vec = zeros(91282,1,'single');
#         else
#             % read it
#             dscalar = cifti_read(fpath);
#             data_vec = single(dscalar.cdata);
#             if numel(data_vec) ~= 91282
#                 error('Unexpected cdata length for %s: got %d, expected 91282.', fpath, numel(data_vec));
#             end
#         end

#         % store raw probability
#         probability_matrix(:,i) = data_vec;

#         % apply threshold => if above threshold_value, keep "i", else 0
#         temp = data_vec;
#         temp(temp > threshold_value) = i;  % store the network ID
#         temp(temp <=  threshold_value) = 0;
#         thresholded_matrix(:,i) = temp;
#     end

#     % keep only your network_indices columns (subset matrices)
#     thresholded_matrix = thresholded_matrix(:, network_indices);
#     probability_matrix = probability_matrix(:, network_indices);

#     % -------------------------------------------------------
#     % PRIORITY OVERRIDE SETUP
#     % Convert priority (IDs or names) into subset-column indices.
#     % After subsetting, columns are 1..numel(network_indices).
#     % -------------------------------------------------------
#     priority_cols = [];  % subset columns (1..numel(network_indices))

#     if exist('priority','var') && ~isempty(priority)
#         if isnumeric(priority)
#             % priority as network IDs (original indexing)
#             [tf, loc] = ismember(priority(:)', network_indices);
#             priority_cols = loc(tf);  % map IDs -> subset columns
#         elseif ischar(priority) || isstring(priority)
#             % single name
#             pcell = cellstr(priority);
#             ids = zeros(1, numel(pcell));
#             for k = 1:numel(pcell)
#                 idx = find(strcmpi(pcell{k}, network_names), 1);
#                 if isempty(idx)
#                     error('Priority name "%s" not found in network_names.', pcell{k});
#                 end
#                 ids(k) = idx;
#             end
#             [tf, loc] = ismember(ids, network_indices);
#             priority_cols = loc(tf);
#         elseif iscell(priority)
#             % list of names
#             ids = zeros(1, numel(priority));
#             for k = 1:numel(priority)
#                 idx = find(strcmpi(priority{k}, network_names), 1);
#                 if isempty(idx)
#                     error('Priority name "%s" not found in network_names.', priority{k});
#                 end
#                 ids(k) = idx;
#             end
#             [tf, loc] = ismember(ids, network_indices);
#             priority_cols = loc(tf);
#         else
#             error('priority must be numeric IDs, a string/char, or a cell array of strings.');
#         end
#     end

#     % enforce uniqueness & order as provided
#     if ~isempty(priority_cols)
#         priority_cols = unique(priority_cols, 'stable');
#     end

#     % -------------------------------------------------------
#     % tie-break step (SAFE):
#     % - candidates = columns with nonzero thresholded assignment at this vertex
#     % - if any candidates are in the priority list, pick the earliest in priority list
#     %   BUT ONLY if that candidate is truly nonzero at this vertex
#     % - otherwise pick max probability (default behavior)
#     % -------------------------------------------------------
#     for rr = 1:size(thresholded_matrix,1)
#         candidates = find(thresholded_matrix(rr,:) ~= 0);

#         if numel(candidates) > 1
#             bestCol = [];

#             % ---- priority override (only among candidates) ----
#             if ~isempty(priority_cols)
#                 hit = candidates(ismember(candidates, priority_cols)); % guaranteed subset of candidates

#                 if ~isempty(hit)
#                     % choose the one that appears earliest in priority_cols
#                     pos = arrayfun(@(c) find(priority_cols == c, 1), hit);
#                     [~, minpos] = min(pos);
#                     bestCol = hit(minpos);

#                     % SAFETY: if for any reason this isn't actually nonzero, ignore priority
#                     if thresholded_matrix(rr, bestCol) == 0
#                         bestCol = [];
#                     end
#                 end
#             end

#             % ---- fallback: highest probability wins ----
#             if isempty(bestCol)
#                 rawvals = probability_matrix(rr, candidates);
#                 [~, bestIdx] = max(rawvals);
#                 bestCol = candidates(bestIdx);
#             end

#             % keep only bestCol
#             thresholded_matrix(rr, setdiff(candidates, bestCol)) = 0;
#         end
#     end
#     % -------------------------------------------------------
#     % Summation => combined map
#     % After tie-break each vertex is at most one network ID, so sum is 0 or that ID.
#     % -------------------------------------------------------
#     combined_map = sum(thresholded_matrix, 2);

#     % Create output subfolder
#     thresh_str = sprintf('%g', threshold_value); % e.g. "0.5"
#     outdir = fullfile(FIGDIR, ['Thresholded-' thresh_str]);
#     if ~exist(outdir, 'dir'), mkdir(outdir); end

#     % Use the last-read dscalar as a template for writing
#     if exist('dscalar','var')
#         out_cifti = dscalar;
#         out_cifti.cdata = combined_map;
#     else
#         % Minimal fallback (usually you will have at least one file)
#         out_cifti.cdata = combined_map;
#         out_cifti.diminfo{1}.length = 91282;
#         out_cifti.diminfo{1}.maps = [];
#     end

#     % Output name
#     if isempty(priority_cols)
#         pri_str = 'none';
#     else
#         pri_str = sprintf('%d-', network_indices(priority_cols));
#         pri_str(end) = []; % remove trailing '-'
#     end

#     outname = fullfile(outdir, ...
#         ['PCM_confidence_map_to_bin_all-networks_thresh-' thresh_str '_priority-' pri_str '.dscalar.nii']);

#     ciftisave(out_cifti, outname);

#     fprintf('Done threshold=%.3f for directory=%s (priority=%s)\n', threshold_value, FIGDIR, pri_str);
# end
# # set -euo pipefail

# # MATLAB_FUN_DIR="/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/"
# # SUPPORT_DIR="/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/"
# # CIFTI_DIR="/projects/standard/faird/shared/code/external/utilities/cifti-matlab"
# # NETWORK_NAMES_MAT="/projects/standard/faird/shared/projects/MSC_TemplateShuffle/code/network_names.mat"

# # die() { echo "ERROR: $*" >&2; exit 1; }

# # usage() {
# #   cat <<'EOF'
# # run_threshold_confidence_maps_with_priority.sh

# # USAGE
# #   1) List network name -> ID mapping:
# #      run_threshold_confidence_maps_with_priority.sh --list-networks

# #   2) Run WITHOUT priority override:
# #      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR 0.5
# #      (equivalent to passing priority = [])

# #   3) Run WITH priority override (MATLAB literal):
# #      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "{'CO','DMN','VIS'}" 0.5
# #      run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "[9 1 2]" 0.5

# # ARGUMENTS
# #   FIGDIR     Directory containing per-network Probability_Maps_*.dscalar.nii files
# #   PRIORITY   Optional. MATLAB literal for priority list:
# #              - "[]" (no override)
# #              - "[9 1 2]" (numeric IDs)
# #              - "{'CO','DMN','VIS'}" (names; must match network_names.mat)
# #   THRESH     Threshold value (e.g. 0.5)

# # OUTPUT
# #   Writes into: FIGDIR/Thresholded-<THRESH>/
# #   Filename is whatever your MATLAB function generates; this script checks for any
# #   matching output and skips if already present.

# # EOF
# # }

# # list_networks() {
# #   matlab -nodisplay -nosplash -r "
# #     try
# #       load('${NETWORK_NAMES_MAT}');
# #       for i = 1:numel(network_names)
# #         fprintf('%2d  %s\n', i, network_names{i});
# #       end
# #     catch ME
# #       disp(getReport(ME,'extended'));
# #       exit(1);
# #     end
# #     exit(0);
# #   "
# # }

# # ###############################################################################
# # # FUNCTION TO RUN MATLAB FOR A GIVEN DIRECTORY
# # ###############################################################################
# # run_threshold_matlab() {
# #   local DIR="$1"
# #   local PRIORITY_LITERAL="$2"
# #   local T="$3"

# #   # Skip if any output already exists for this threshold (handles priority/no-priority filenames)
# #   local OUTGLOB="${DIR}/Thresholded-${T}/PCM_confidence_map_to_bin_all-networks_thresh-${T}"'*.dscalar.nii'
# #   shopt -s nullglob
# #   local matches=( $OUTGLOB )
# #   shopt -u nullglob
# #   if (( ${#matches[@]} > 0 )); then
# #     echo "   Found existing output(s) for threshold ${T} in ${DIR}/Thresholded-${T}/ ... skipping."
# #     printf "   Existing:\n"
# #     printf "     %s\n" "${matches[@]}"
# #     return 0
# #   fi

# #   echo "   Running threshold=${T} for ${DIR} (priority=${PRIORITY_LITERAL})"
# #   local LOG_FILE="${DIR}/logs/matlab_threshold_${T}.log"
# #   mkdir -p "$(dirname "$LOG_FILE")"

# #   # IMPORTANT: PRIORITY_LITERAL must be a MATLAB expression (e.g., [], [9 1], {'CO','DMN'})
# #   matlab -nodisplay -nosplash -r \
# #     "try; \
# #        addpath('${MATLAB_FUN_DIR}'); \
# #        addpath('${SUPPORT_DIR}'); \
# #        addpath('${CIFTI_DIR}'); \
# #        threshold_confidence_maps_with_priority('${DIR}', ${PRIORITY_LITERAL}, ${T}); \
# #      catch ME; disp(getReport(ME,'extended')); exit(1); \
# #      end; \
# #      exit(0);" \
# #     >> "${LOG_FILE}" 2>&1
# # }

# # ###############################################################################
# # # ARG PARSING
# # ###############################################################################
# # if [[ $# -eq 0 ]]; then
# #   usage
# #   exit 1
# # fi

# # case "${1:-}" in
# #   -h|--help)
# #     usage
# #     exit 0
# #     ;;
# #   --list-networks)
# #     list_networks
# #     exit 0
# #     ;;
# # esac

# # # Two forms:
# # #   (A) FIGDIR THRESH
# # #   (B) FIGDIR PRIORITY THRESH
# # FIGDIR="${1:-}"
# # [[ -d "$FIGDIR" ]] || die "FIGDIR not found: $FIGDIR"

# # if [[ $# -eq 2 ]]; then
# #   PRIORITY="[]"
# #   THRESH="${2}"
# # elif [[ $# -eq 3 ]]; then
# #   PRIORITY="${2}"
# #   THRESH="${3}"
# # else
# #   usage
# #   die "Expected 2 or 3 arguments (or --list-networks)."
# # fi

# # # Basic validation for threshold numeric
# # [[ "$THRESH" =~ ^[0-9]*\.?[0-9]+$ ]] || die "THRESH must be numeric (got: $THRESH)"

# # run_threshold_matlab "$FIGDIR" "$PRIORITY" "$THRESH"
# # echo "Done."


# # ###############################################################################
# # # FUNCTION TO RUN MATLAB FOR A GIVEN DIRECTORY
# # ###############################################################################
# # run_threshold_matlab() {
# #   local DIR=$1
# #   local T=$2

# #   # If the thresholded .dscalar file already exists, skip
# #   # (We name it the same as the code does in the MATLAB function)
# #   local D_OUT="${DIR}/Thresholded-${T}/PCM_confidence_map_to_bin_all-networks_thresh-${T}.dscalar.nii"
# #   if [[ -f "$D_OUT" ]]; then
# #     echo "   Already found $D_OUT ... skipping."
# #     return
# #   fi

# #   echo "   Running threshold=$T for $DIR"
# #   local LOG_FILE="${DIR}/logs/matlab_threshold_${T}.log"
# #   mkdir -p "$(dirname "$LOG_FILE")"

# #   matlab -nodisplay -nosplash -r \
# #     "addpath('/projects/standard/faird/shared/code/internal/analytics/TemplateShuffle/code/functions/'); \
# #      addpath('/projects/standard/faird/shared/code/internal/analytics/compare_matrices_to_assign_networks/support_files/'); \
# #      addpath('/projects/standard/faird/shared/code/external/utilities/cifti-matlab'); \
# #      threshold_confidence_maps_with_priority('${DIR}', ${percent_holdout}, ${T}); \
# #      exit;" \
# #   >> "${LOG_FILE}" 2>&1
# # }
# # #!/usr/bin/env bash
# # # run_threshold_confidence_maps_with_priority.sh
# # #
# # # Usage:
# # #   run_threshold_confidence_maps_with_priority.sh --list-networks
# # #   run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR 0.5
# # #   run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "{'CO','DMN','VIS'}" 0.5
# # #   run_threshold_confidence_maps_with_priority.sh /path/to/FIGDIR "[]" 0.5
# # #
# # # Notes:
# # # - If you pass a MATLAB literal like "{'CO','DMN'}" you MUST quote it.
# # # - To run with no priority override, either omit the priority argument (2-arg form)
# # #   or pass "[]".
# # #
# # # This script calls MATLAB function: threshold_confidence_maps_with_priority(FIGDIR, priority, threshold)
