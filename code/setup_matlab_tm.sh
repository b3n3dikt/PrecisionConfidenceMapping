#!/bin/bash
# =============================================================================
# setup_matlab_tm.sh  —  Fetch the matlab_tm (template matching) dependency
# =============================================================================
# METHOD=matlab_tm needs template_matching_RH.m et al. from
# DCAN-Labs/compare_matrices_to_assign_networks (R. Hermosillo / UMN). That
# code's LICENSE.txt (UMN provisional patent, non-profit/research use only, no
# redistribution without approval) is why PCM does not vendor it in its own
# git history — instead this script clones it fresh, at a pinned commit, and
# applies PCM's patch on top.
#
# Run this ONCE, on a machine with internet access (a login node or your own
# workstation) — NOT inside a SLURM job. Compute nodes are frequently
# firewalled off from the internet on HPC clusters, so this can't be a step
# that happens automatically mid-pipeline. run_PCM.sh checks MATLAB_TM_DIR
# exists before submitting any jobs when METHOD=matlab_tm, and will point you
# back here if it's missing.
#
# What this does:
#   1. git clone the upstream repo into MATLAB_TM_DIR (from config.sh)
#   2. git checkout the pinned commit (MATLAB_TM_PINNED_COMMIT in config.sh)
#   3. git apply patches/template_matching_RH.patch — see that file for a
#      full explanation of each hunk (cifti-matlab struct-vs-gifti fix, a
#      repmat dimension fix, and removal of hardcoded server addpaths).
#
# Safe to re-run: if MATLAB_TM_DIR already exists and is already at the
# pinned commit with the patch applied, this exits early without doing
# anything. Use --force to wipe and re-fetch from scratch.
# =============================================================================
set -euo pipefail

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${CODE_DIR}/config.sh"

UPSTREAM_URL="https://github.com/DCAN-Labs/compare_matrices_to_assign_networks.git"
PATCH_FILE="${CODE_DIR}/patches/template_matching_RH.patch"

FORCE=0
if [[ "${1:-}" == "--force" ]]; then
    FORCE=1
fi

if [[ -d "${MATLAB_TM_DIR}" ]]; then
    if [[ "${FORCE}" == "1" ]]; then
        echo "[setup_matlab_tm] --force given, removing existing ${MATLAB_TM_DIR}"
        rm -rf "${MATLAB_TM_DIR}"
    else
        _current_commit="$(git -C "${MATLAB_TM_DIR}" rev-parse HEAD 2>/dev/null || echo "unknown")"
        if [[ "${_current_commit}" == "${MATLAB_TM_PINNED_COMMIT}" ]] && \
           grep -q "ciftisave(saving_template" "${MATLAB_TM_DIR}/template_matching_RH.m" 2>/dev/null; then
            echo "[setup_matlab_tm] ${MATLAB_TM_DIR} already present at the pinned commit with the patch applied. Nothing to do (use --force to re-fetch)."
            exit 0
        else
            echo "[setup_matlab_tm] ERROR: ${MATLAB_TM_DIR} already exists but is not at the expected"
            echo "  pinned commit / patched state. Not touching it automatically — inspect it, or"
            echo "  re-run with --force to wipe and re-fetch from scratch."
            exit 1
        fi
    fi
fi

echo "[setup_matlab_tm] Cloning ${UPSTREAM_URL}"
git clone --quiet "${UPSTREAM_URL}" "${MATLAB_TM_DIR}"

echo "[setup_matlab_tm] Checking out pinned commit ${MATLAB_TM_PINNED_COMMIT}"
git -C "${MATLAB_TM_DIR}" checkout --quiet "${MATLAB_TM_PINNED_COMMIT}"

echo "[setup_matlab_tm] Applying ${PATCH_FILE}"
(cd "${MATLAB_TM_DIR}" && git apply "${PATCH_FILE}")

echo "[setup_matlab_tm] Done. matlab_tm is ready at ${MATLAB_TM_DIR} (commit ${MATLAB_TM_PINNED_COMMIT}, patched)."
echo "[setup_matlab_tm] Its LICENSE.txt (UMN, non-profit/research use only) governs this fetched"
echo "  copy — read it at ${MATLAB_TM_DIR}/LICENSE.txt before using METHOD=matlab_tm."
