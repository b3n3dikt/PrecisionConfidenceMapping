#!/bin/bash
# =============================================================================
# config.sh  —  PrecisionConfidenceMapping Configuration
# =============================================================================
# This file is sourced by all PCM scripts. It computes CODE_DIR dynamically
# from its own location, so the entire PrecisionConfidenceMapping/ folder can be moved to
# any server without editing individual scripts.
#
# WHAT TO EDIT HERE:
#   - Cluster settings live in cluster.conf (copy that to your project folder)
#   - WB_CMD if wb_command is not on your PATH (uncomment the override line)
# =============================================================================

# Compute the root of this standalone package from this file's own location.
# Exported so that all child sbatch jobs (orchestrate_PCM.sh, run_permutation.sh,
# run_standard_TM.sh) inherit it via SLURM's default --export=ALL, instead of
# relying on BASH_SOURCE[0] which resolves to the SLURM spool copy path.
export CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Internal code directories ────────────────────────────────────────────────
# These are fixed relative paths within PCM_standalone/. Do not change.
FUNCTIONS_DIR="${CODE_DIR}/code/functions"
OVERRIDES_DIR="${CODE_DIR}/code/overrides"
TM_CODE_DIR="${CODE_DIR}/template_matching"

# ─── External dependencies (bundled in deps/) ────────────────────────────────
CIFTI_MATLAB_DIR="${CODE_DIR}/deps/cifti-matlab"
CIFTI_CONN_DIR="${CODE_DIR}/deps/cifti_connectivity/src"
XCPD2DCAN_DIR="${CODE_DIR}/deps/xcpd2dcanmotion"
INTERP_NOISE_DIR="${CODE_DIR}/deps/interpolate_noise_for_timeseries"
# FieldTrip fileio module + its gifti/@xmltree/utilities helper dependencies.
# FieldTrip is independently-licensed third-party code (GPLv2 — see
# fileio/COPYING). Only interpolate_noise_for_timeseries.m needs this —
# Zscore_dconn.m uses cifti-matlab's diminfo instead and doesn't need FieldTrip.
FIELDTRIP_FILEIO_DIR="${CODE_DIR}/deps/fieldtrip_fileio"
FIGURE_MAKER_DIR="${CODE_DIR}/deps/figure_maker"
CONTE69_L="${CODE_DIR}/deps/Conte69_surfaces/Conte69.L.very_inflated.32k_fs_LR.surf.gii"
CONTE69_R="${CODE_DIR}/deps/Conte69_surfaces/Conte69.R.very_inflated.32k_fs_LR.surf.gii"

# ─── Zscore_dconn (bundled in deps/Zscore_dconn/) ────────────────────────────
# Sectional dconn z-scoring, shared by matlab_tm (called inside
# template_matching_RH via Zscore_dconn()) and reprotm (explicit step in
# run_permutation.sh).
ZSCORE_DCONN_DIR="${CODE_DIR}/deps/Zscore_dconn"

# ─── matlab_tm dependency (external — fetched, NOT bundled) ──────────────────
# Template matching core algorithm (template_matching_RH.m et al.), authored by
# R. Hermosillo / UMN and published at:
#   https://github.com/DCAN-Labs/compare_matrices_to_assign_networks
# Its LICENSE.txt (UMN provisional patent, non-profit/research use only, no
# redistribution without approval) is why PCM does not vendor this code in its
# own git history. Instead: `code/setup_matlab_tm.sh` clones it to MATLAB_TM_DIR
# at a pinned commit and applies `patches/template_matching_RH.patch` (fixes a
# cifti-matlab struct-vs-gifti incompatibility + a repmat dimension bug + strips
# hardcoded server addpaths — see patches/template_matching_RH.patch for the
# full explanation of each hunk). Same external-dependency pattern as
# REPROTM_DIR below. Run code/setup_matlab_tm.sh once before METHOD=matlab_tm.
MATLAB_TM_DIR="${CODE_DIR}/deps/matlab_tm"
MATLAB_TM_PINNED_COMMIT="4e32763d80a14697e9dab92b90287632ef655a84"

# ─── ReproTM dependency (external — fetched OR bring-your-own, NOT bundled) ──
# Godfrey et al. python template matching (METHOD=reprotm). PCM does not vendor a
# copy of this code in its own git history — same external-dependency pattern as
# MATLAB_TM_DIR above, but reprotm has no license restriction forcing a pin, so
# code/setup_reprotm.sh offers two modes instead of one:
#   --pinned (default): clone at REPROTM_PINNED_COMMIT, apply patches/reprotm_*.patch
#   --latest: clone current upstream HEAD; each patch is tried with `git apply
#     --check` first and skipped (with a message) if it no longer applies — e.g.
#     because Kate already fixed it upstream. See patches/reprotm_*.patch and
#     deps/reprotm/COMPATIBILITY_NOTES.md for what each patch does and why.
# If you'd rather manage your own ReproTM install by hand instead of using
# setup_reprotm.sh, that still works — just set REPROTM_DIR in cluster.conf and
# it overrides the fetched default below. See deps/reprotm/README.md.
REPROTM_FETCHED_DIR="${CODE_DIR}/deps/reprotm_fetched"
REPROTM_PINNED_COMMIT="bf0d0c6f93828d5cfa52af83b26c7eb81ba3f50e"
REPROTM_DIR="${REPROTM_DIR:-${REPROTM_FETCHED_DIR}}"
# NOTE: Kate's repo nests both scripts under code/ (verified against a real clone
# at both REPROTM_PINNED_COMMIT and current HEAD) — REPROTM_DIR itself should still
# point at the repo root (matches deps/reprotm/README.md's "folder you cloned").
REPROTM_SCRIPT="${REPROTM_DIR}/code/ReproTM/ReproTM_v1.0.0.py"
REPROTM_MINSIZE_SCRIPT="${REPROTM_DIR}/code/minsize/minsize_v1.0.0.py"
# Python interpreter for ReproTM. It needs nibabel + scipy + numpy, which the
# cluster's default `python3` often lacks, so make the interpreter configurable:
# set REPROTM_PYTHON in cluster.conf to a python that has the deps (e.g. a conda
# env's python), or `pip install --user nibabel scipy numpy` for the default.
REPROTM_PYTHON="${REPROTM_PYTHON:-python3}"
export REPROTM_DIR REPROTM_SCRIPT REPROTM_MINSIZE_SCRIPT REPROTM_PYTHON

# ─── Network template files ────────────────────────────────────────────────────
# SURF_ONLY=0  →  full brain (cortex + subcortex), ABCD network template
TEMPLATE_ABCD_FULL="${CODE_DIR}/templates/template_matching/seedmaps_ABCD164template_SMOOTHED_dtseries_all_networksZscored.mat"
# SURF_ONLY=1  →  cortical surface only, ABCD template
TEMPLATE_ABCD_SURF="${CODE_DIR}/templates/template_matching/seedmaps_ABCD161template_SMOOTHED_dtseries_SurfOnly_all_networks.mat"
# SURF_ONLY=2  →  full brain, ABCD-SCAN network template (default)
TEMPLATE_SCAN="${CODE_DIR}/templates/template_matching/seedmaps_subs_withsmoothed_dtseries_n141_all_networksZscored.mat"
# ReproTM: bundled ABCC seedmap template (.mat, z-scored, 91k) — default for METHOD=reprotm.
# This is PCM's own default template (not part of the external ReproTM codebase above),
# so it lives under templates/ and isn't affected by REPROTM_DIR.
# The accompanying network-names string MUST match this template's seed_matrix columns.
export TEMPLATE_REPROTM_DEFAULT="${CODE_DIR}/templates/reprotm/tpl-ABCC2026-a3-9to16_space-fsLR_den-91k_desc-seedmap_stat-zscored.mat"
export REPROTM_NETWORKS_DEFAULT="DMN Vis FP NaN DAN NaN VAN Sal AMN SMd SMl Aud Tpole MTL PMN PON NaN SCAN"
# Network names for the matlab_tm templates reused by METHOD=reprotm:
#   scan      → 18 columns (same canonical ordering as REPROTM_NETWORKS_DEFAULT, incl. SCAN)
#   abcd_full / abcd_surf → 16 columns (the same ordering minus the trailing NaN + SCAN)
export REPROTM_NETWORKS_SCAN="${REPROTM_NETWORKS_DEFAULT}"
export REPROTM_NETWORKS_ABCD16="DMN Vis FP NaN DAN NaN VAN Sal AMN SMd SMl Aud Tpole MTL PMN PON"

# ─── Key script paths ──────────────────────────────────────────────────────────
TM_WRAPPER="${FUNCTIONS_DIR}/matlab_tm_wrapper.sh"
CHECK_PERMS_SCRIPT="${FUNCTIONS_DIR}/Check_sucessful_perms_percent_holdout.py"
MAKE_FIGS_SCRIPT="${FUNCTIONS_DIR}/make_figs.sh"
RUN_PERMUTATION_SCRIPT="${CODE_DIR}/code/run_permutation.sh"

# ─── MATLAB addpath setup string ──────────────────────────────────────────────
# Used at the start of every matlab -r "..." call to make all code findable.
# Order matters: addpath() prepends to the path, so the LAST call wins.
# MATLAB_TM_DIR is added FIRST (lowest precedence) so PCM's own template_matching/
# files (TM_CODE_DIR, added after it) win any accidental name collision with the
# fetched upstream code. If MATLAB_TM_DIR doesn't exist yet (setup_matlab_tm.sh
# hasn't been run), genpath('') on a missing dir is a harmless no-op — the error
# only surfaces later, clearly, when METHOD=matlab_tm actually tries to call
# template_matching_RH and MATLAB can't find it.
# CIFTI_MATLAB_DIR (deps/cifti-matlab) must be added LAST so it takes precedence
# over any copy of cifti-matlab bundled inside FUNCTIONS_DIR (e.g. BED/cifti-matlab).
# FIELDTRIP_FILEIO_DIR is the extracted fileio/gifti/@xmltree/utilities subset
# that interpolate_noise_for_timeseries.m needs.
MATLAB_ADDPATH="addpath(genpath('${MATLAB_TM_DIR}')); addpath(genpath('${TM_CODE_DIR}')); addpath(genpath('${FUNCTIONS_DIR}')); addpath(genpath('${CIFTI_CONN_DIR}')); if exist('${CIFTI_CONN_DIR}/temp','dir'), rmpath(genpath('${CIFTI_CONN_DIR}/temp')); end; addpath(genpath('${FIELDTRIP_FILEIO_DIR}')); addpath(genpath('${CIFTI_MATLAB_DIR}')); addpath(genpath('${ZSCORE_DCONN_DIR}')); addpath(genpath('${OVERRIDES_DIR}'));"

# ─── wb_command ────────────────────────────────────────────────────────────────
# We assume wb_command is on your PATH (e.g., via `module load workbench`).
# If wb_command is NOT on PATH, uncomment the line below and set the full path:
# WB_CMD="/path/to/workbench/bin_rh_linux64/wb_command"
WB_CMD="wb_command"
