#!/bin/bash
# =============================================================================
# setup_reprotm.sh  —  Fetch the ReproTM (Godfrey et al.) dependency
# =============================================================================
# METHOD=reprotm needs ReproTM_v1.0.0.py + minsize_v1.0.0.py from
# KateJGodfrey/ReproTM. Unlike matlab_tm, ReproTM has no license restricting
# redistribution (it's just missing a LICENSE file — see
# release_prep/REPROTM_CHANGES_FOR_KATE.md), so this offers TWO modes instead
# of matlab_tm's one:
#
#   --pinned (DEFAULT): clone at REPROTM_PINNED_COMMIT (config.sh), apply
#     PCM's compatibility patches unconditionally — they were built and
#     verified against this exact commit, so they should always apply. A
#     failure here means the pin/patch pair itself is broken and needs
#     fixing, not something to silently skip. Guaranteed to work; immune to
#     Kate restructuring the codebase out from under PCM's assumptions.
#
#   --latest: clone current upstream HEAD instead. Each patch in
#     patches/reprotm_*.patch is tried with `git apply --check` first and
#     only applied if it still matches — if Kate has already fixed that
#     issue upstream (or changed that part of the code), the patch is
#     skipped with a message instead of failing. Gets you upstream
#     improvements automatically, at the cost of "might need a manual fix if
#     Kate changed a lot" — see deps/reprotm/COMPATIBILITY_NOTES.md.
#
# Run this ONCE, on a machine with internet access (a login node or your own
# workstation) — NOT inside a SLURM job. run_PCM.sh checks REPROTM_DIR exists
# before submitting any jobs when METHOD=reprotm, and will point you back
# here if it's missing.
#
# Known patches (patches/reprotm_*.patch):
#   - reprotm_fieldtrip_dconn_fallback.patch: nb.load() crashes on
#     FieldTrip-written dconns (ValueError: Affine transformation should be
#     a 4x4 array) — falls back to reading the file as a raw NIfTI-2 volume.
#     Still present upstream as of REPROTM_PINNED_COMMIT and current HEAD
#     (verified 2026-08-19).
#   (The OTHER known issue — scipy.stats.mode breaking on scipy>=1.9 — was
#   fixed upstream by Kate herself, commit 3b17c53 "update minsize to ensure
#   backwards scipy compatibility", so there's no PCM patch for it anymore.
#   REPROTM_PINNED_COMMIT is set to a commit AFTER that fix, verified
#   2026-08-19.)
#
# Safe to re-run in the same mode: exits early without doing anything if
# REPROTM_FETCHED_DIR already exists in that mode. Switching modes (or if the
# folder is in an unexpected state) requires --force to wipe and re-fetch.
# =============================================================================
set -euo pipefail

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${CODE_DIR}/config.sh"

UPSTREAM_URL="https://github.com/KateJGodfrey/ReproTM.git"
PATCH_DIR="${CODE_DIR}/patches"
PATCHES=("${PATCH_DIR}/reprotm_fieldtrip_dconn_fallback.patch")
MODE_MARKER="${REPROTM_FETCHED_DIR}/.pcm_setup_mode"

MODE="pinned"
FORCE=0
for arg in "$@"; do
    case "${arg}" in
        --pinned) MODE="pinned" ;;
        --latest) MODE="latest" ;;
        --force)  FORCE=1 ;;
        *)
            echo "[setup_reprotm] Unknown argument: ${arg}"
            echo "Usage: $0 [--pinned|--latest] [--force]"
            exit 1
            ;;
    esac
done

if [[ -d "${REPROTM_FETCHED_DIR}" ]]; then
    if [[ "${FORCE}" == "1" ]]; then
        echo "[setup_reprotm] --force given, removing existing ${REPROTM_FETCHED_DIR}"
        rm -rf "${REPROTM_FETCHED_DIR}"
    else
        _existing_mode="$(cat "${MODE_MARKER}" 2>/dev/null || echo "unknown")"
        if [[ "${_existing_mode}" == "${MODE}" ]]; then
            echo "[setup_reprotm] ${REPROTM_FETCHED_DIR} already set up in --${MODE} mode. Nothing to do (use --force to re-fetch)."
            exit 0
        else
            echo "[setup_reprotm] ERROR: ${REPROTM_FETCHED_DIR} already exists (mode: ${_existing_mode}),"
            echo "  but you asked for --${MODE}. Not switching modes automatically —"
            echo "  re-run with --force to wipe and re-fetch in --${MODE} mode."
            exit 1
        fi
    fi
fi

echo "[setup_reprotm] Cloning ${UPSTREAM_URL}"
git clone --quiet "${UPSTREAM_URL}" "${REPROTM_FETCHED_DIR}"

if [[ "${MODE}" == "pinned" ]]; then
    echo "[setup_reprotm] Mode: --pinned. Checking out ${REPROTM_PINNED_COMMIT}"
    git -C "${REPROTM_FETCHED_DIR}" checkout --quiet "${REPROTM_PINNED_COMMIT}"
else
    _head="$(git -C "${REPROTM_FETCHED_DIR}" rev-parse HEAD)"
    echo "[setup_reprotm] Mode: --latest. Using upstream HEAD (${_head})"
fi

echo "[setup_reprotm] Checking known compatibility patches..."
_applied=0
_skipped=0
for patch in "${PATCHES[@]}"; do
    _name="$(basename "${patch}")"
    if [[ "${MODE}" == "pinned" ]]; then
        git -C "${REPROTM_FETCHED_DIR}" apply "${patch}"
        echo "  [applied]  ${_name}"
        _applied=$((_applied + 1))
    else
        if git -C "${REPROTM_FETCHED_DIR}" apply --check "${patch}" 2>/dev/null; then
            git -C "${REPROTM_FETCHED_DIR}" apply "${patch}"
            echo "  [applied]  ${_name}"
            _applied=$((_applied + 1))
        else
            echo "  [skipped]  ${_name} — doesn't apply cleanly (likely already fixed upstream, or"
            echo "             the surrounding code changed). See deps/reprotm/COMPATIBILITY_NOTES.md"
            echo "             if you hit the issue this patch addresses."
            _skipped=$((_skipped + 1))
        fi
    fi
done

echo "${MODE}" > "${MODE_MARKER}"

echo "[setup_reprotm] Done. ReproTM (--${MODE} mode) is ready at ${REPROTM_FETCHED_DIR}"
echo "  (${_applied} patch(es) applied, ${_skipped} skipped)."
echo "[setup_reprotm] No LICENSE file ships with ReproTM as of this writing — see"
echo "  release_prep/REPROTM_CHANGES_FOR_KATE.md for the outstanding licensing question."
echo "[setup_reprotm] REPROTM_DIR resolves here automatically (config.sh) unless you've set"
echo "  REPROTM_DIR yourself in cluster.conf."
