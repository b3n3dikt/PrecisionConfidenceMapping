# PrecisionConfidenceMapping

**Precision Confidence Mapping (PCM)** — a bootstrap-based method for
quantifying per-vertex network assignment confidence in fMRI data.

This package supports multiple community detection methods and is fully
self-contained: copy the entire `PrecisionConfidenceMapping/` folder to any HPC server
and run. No server-specific paths to edit.

---

## What PCM does

PCM runs community detection N times (bootstrap permutations) on shuffled fMRI
time series. Each permutation assigns each brain vertex to a network. By
aggregating across permutations, PCM produces:

- **Probability maps** — per-vertex probability of belonging to each network
- **Mode map** — the most commonly assigned network per vertex across permutations

These confidence maps reveal which parts of a subject's brain have stable,
reliable network assignments (high confidence) versus ambiguous ones (low).

PCM supports two community detection methods, selected via the `METHOD`
parameter in `run_PCM.sh`:

| Method | Description |
|---|---|
| `matlab_tm` | MATLAB template matching — the original PCM method (default) |
| `reprotm` | Python template matching (ReproTM, Godfrey et al.) on a z-scored dconn, with min-size cleanup |

---

## Requirements

- **SLURM** — job scheduler (tested on MSI)
- **MATLAB** — loaded via `module load matlab`
- **Workbench** (`wb_command`) — loaded via `module load workbench`
- **Python 3** — for permutation status checking
- fMRI data with a `.dtseries.nii`, a motion file, and midthickness `.surf.gii` files

**Additional requirements for `METHOD=matlab_tm` (the default):**
- **Its core code is fetched, not bundled** — `template_matching_RH.m` (R. Hermosillo / UMN) is licensed for non-profit/research use only, so PCM fetches it at setup time instead of vendoring a copy. Run once, before your first `matlab_tm` run, on a machine with internet access (not inside a SLURM job): `bash code/setup_matlab_tm.sh`. See `patches/template_matching_RH.patch` for exactly what's patched and why. `run_PCM.sh` fails fast with a reminder if you forget.

**Additional requirements for `METHOD=reprotm`:**
- **ReproTM's core code is fetched, not bundled either** — run `bash code/setup_reprotm.sh` once before your first `reprotm` run. Unlike matlab_tm there's no license forcing a pin, so you get a choice: `--pinned` (default — a known-good commit, compatibility fixes applied) or `--latest` (current upstream HEAD, fixes applied only if still needed). See `deps/reprotm/README.md`. Prefer to manage your own ReproTM install instead? Set `REPROTM_DIR` in `cluster.conf` to override the fetched default. (PCM's own default ABCC template *is* bundled, in `templates/reprotm/`.)
- A Python with **`nibabel`, `scipy`, and `numpy`**. The cluster's default `python3`
  often lacks `nibabel`. Either `pip install --user nibabel scipy numpy` for `python3`, or set
  `REPROTM_PYTHON` in `cluster.conf` to a python that has them (e.g. a conda env). A fast
  preflight check fails the job in seconds (before the dconn build) if they are missing.

---

## Quick start

### 1. Copy to your server

```bash
scp -r PrecisionConfidenceMapping/ yourserver:/path/to/destination/
```

### 2. Fetch matlab_tm (required — one time)

`matlab_tm` is the default method, but its core code isn't bundled in this repo (see
Requirements above). Run this once, on a machine with internet access, before your
first run:

```bash
bash code/setup_matlab_tm.sh
```

Planning to use `reprotm` instead (or as well)? Also run `bash code/setup_reprotm.sh`
(see Requirements above for the `--pinned`/`--latest` choice).

### 3. Configure your cluster

Edit `cluster.conf` (or copy it to your study directory and edit there):

```bash
SLURM_PARTITION="msismall,ag2tb"   # check: sinfo -s
SLURM_ACCOUNT="yourgroup"           # check: sacctmgr show user
MATLAB_MODULE="matlab/R2019a"       # check: module avail matlab
WORKBENCH_MODULE="workbench"        # check: module avail workbench
PYTHON_MODULE="python3"             # check: module avail python

# For METHOD=reprotm — OPTIONAL, only if you want your own install instead of the
# one `code/setup_reprotm.sh` fetches for you:
# REPROTM_DIR="/path/to/your/ReproTM" # https://github.com/KateJGodfrey/ReproTM

# For METHOD=reprotm — python with nibabel/scipy/numpy (default python3 often lacks nibabel):
REPROTM_PYTHON="python3"            # or e.g. /home/.../miniconda3/envs/pcm/bin/python
```

PCM will use a `cluster.conf` in the directory where you run `sbatch` if one
exists there, otherwise it falls back to the copy inside `PrecisionConfidenceMapping/`.

### 4. Edit `run_PCM.sh`

Open `run_PCM.sh` and fill in the **USER SETTINGS** section with your file paths:

```bash
# Required inputs
dtseries="/path/to/sub-001_ses-01_task-rest_bold.dtseries.nii"
motion_file="/path/to/motion.mat"    # .mat | .hdf5 (auto-converted) | .txt (0/1 mask)
surf_L="/path/to/hemi-L_midthickness.surf.gii"
surf_R="/path/to/hemi-R_midthickness.surf.gii"
BASEDIR="/path/to/output/PCM/sub-001/ses-01"

# Optional — auto-parsed from the dtseries filename if BIDS-formatted
SUB=""    # e.g. "001"
SES=""    # e.g. "01"
TASK=""   # e.g. "rest"

METHOD="matlab_tm"   # matlab_tm | reprotm
```

> **Tip:** `run_PCM.sh` can live anywhere — inside `PrecisionConfidenceMapping/` or in a
> separate study directory. If it lives elsewhere, set `PCM_DIR` at the top of
> the file to point to your `PrecisionConfidenceMapping/` installation.

### 5. Submit

```bash
# Edit USER SETTINGS in run_PCM.sh, then:
sbatch run_PCM.sh

# Or pass inputs as named flags:
sbatch run_PCM.sh \
    --dtseries /path/to/bold.dtseries.nii \
    --motion /path/to/motion.mat \
    --surf-l /path/to/hemi-L.surf.gii \
    --surf-r /path/to/hemi-R.surf.gii \
    --basedir /out/PCM/sub-001

# Mix: set most in the file, override one flag at submission time
sbatch run_PCM.sh --method reprotm
sbatch run_PCM.sh --startmins 10
```

Run `bash run_PCM.sh --help` for full usage.

---

## Community detection methods

> **⚠️ In-development notice:** `matlab_tm` is the original PCM method — extensively
> tested and the basis of published results. `reprotm` is a newer addition with less
> cluster-testing history; treat its outputs as provisional and inspect them
> carefully before relying on them.

### `METHOD=matlab_tm` (default)

The original PCM method. MATLAB template matching assigns each vertex to the
network whose seed-map correlation is highest. Fast, well-tested. Its core code
(`template_matching_RH.m` et al., from
[DCAN-Labs/compare_matrices_to_assign_networks](https://github.com/DCAN-Labs/compare_matrices_to_assign_networks))
is fetched, not bundled — run `bash code/setup_matlab_tm.sh` once before your first
run (see Requirements above). Uses the bundled templates in `templates/template_matching/`.

The template is controlled by the `TEMPLATE` setting in `run_PCM.sh`:

| TEMPLATE value | Template | Coverage |
|---|---|---|
| `""` or `"scan"` **(default)** | ABCD-SCAN (n=141) | Cortex + subcortex |
| `"abcd_full"` | ABCD (n=164) | Cortex + subcortex |
| `"abcd_surf"` | ABCD (n=161) | Cortex surface only |
| `/full/path/to/template.mat` | Custom | Depends on template |

### `METHOD=reprotm`

Python template matching from **ReproTM** (Godfrey et al.). Like matlab_tm, its core
code isn't bundled — but unlike matlab_tm, ReproTM has no license restricting
redistribution (just a missing `LICENSE` file), so there's a choice of two fetch modes:

```bash
bash code/setup_reprotm.sh              # --pinned (default): known-good commit,
                                         # compatibility patches applied
bash code/setup_reprotm.sh --latest     # current upstream HEAD instead — patches
                                         # applied only if still needed
```

Run once before your first `reprotm` run; both modes fetch into
`deps/reprotm_fetched/` and PCM picks it up automatically — no `cluster.conf` edit
needed unless you'd rather manage your own install (`REPROTM_DIR`).

See `deps/reprotm/README.md` for the expected folder layout (bring-your-own path) and
`deps/reprotm/COMPATIBILITY_NOTES.md` for known version-compatibility issues and what
each patch fixes. If ReproTM isn't set up correctly, `run_PCM.sh` fails immediately at
submission with a message pointing here, before any SLURM jobs are submitted.

Each permutation:

1. **dconn** — smooth the shuffled dtseries, then dense connectivity via
   `cifti_conn_matrix_for_wrapper_continous` (the same tool matlab_tm uses)
2. **z-score** — sectional (per-hemisphere/subcortex) z-scoring (`Zscore_dconn.m`),
   so the dconn matches the z-scored template
3. **ReproTM** — winner-take-all template matching on the z-scored dconn
   (`ReproTM_v1.0.0.py`), with optional SCAN/SMd/SMl refinement
4. **Min-size cleanup** — small clusters reassigned to the mode of their neighbors
   (`minsize_v1.0.0.py`), published as `*_recolored.dscalar.nii`

The template is a `.mat` with a `seed_matrix` variable. It accepts the same
keywords as `matlab_tm` (they are all ReproTM-compatible), the bundled ABCC
default, or a custom path:

| TEMPLATE value | Template | Networks |
|---|---|---|
| `""` **(default)** | bundled ABCC seedmap | 18 (incl. SCAN) |
| `"scan"` | ABCD-SCAN (n=141) | 18 (incl. SCAN) |
| `"abcd_full"` | ABCD (n=164) | 16 |
| `"abcd_surf"` | ABCD (n=161), surface only | 16 |
| `/full/path/to/seedmap.mat` | Custom | set `REPROTM_NETWORKS` |

> Network names must match the template's `seed_matrix` columns. Built-in
> keywords set them automatically; for a **custom** `.mat` set `REPROTM_NETWORKS`
> to the matching space-separated list, or networks will be mislabeled.

ReproTM settings (all have sensible defaults):

| Parameter | Default | Description |
|---|---|---|
| `REPROTM_NETWORKS` | per-template | Space-separated network names matching the template columns |
| `REPROTM_MINSIZE` | 30 | Minimum cluster size (greyordinates) for cleanup |
| `REPROTM_TEMPLATE_MINTHRESH` | 1 | Template seedmap thresholding minimum |
| `REPROTM_REFINESCAN` | 1 | Re-match SMd/SMl/SCAN at a higher threshold (needs those nets) |
| `REPROTM_REFINESCAN_MINTHRESH` | 3 | Threshold used during SCAN/SMd/SMl refinement |
| `REPROTM_PYTHON` | `python3` | Python interpreter with nibabel/scipy/numpy (set in `cluster.conf`) |

### Shared dconn settings (both methods)

Both methods build their dconn via the same underlying tool, so these apply
to either `METHOD`:

| Parameter | Default | Description |
|---|---|---|
| `SMOOTHING_KERNEL` | 2.25 | Pre-dconn smoothing kernel in mm (0 to skip) |
| `FISHER_Z` | 1 | Fisher-z transform correlations before z-scoring (0 for plain Pearson r) |
| `REMOVE_OUTLIERS` | 1 | Standard-deviation-based outlier frame removal on top of FD motion censoring |

---

## Analysis modes

| Flag | Value | Effect |
|---|---|---|
| `SPLITPCT=1` | **Main PCM mode** | Shuffles data, runs community detection on `percent_holdout`% each permutation |
| `STANDARDTM=1` | **Baseline** | Runs TM on full unshuffled data (matlab_tm method only) |
| `SPLITHALF=1` | Deprecated | Original split-half mode — leave 0 unless specifically needed |

For standard PCM: `SPLITPCT=1 STANDARDTM=1 SPLITHALF=0`.

---

## Shuffle options

| Option | Description |
|---|---|
| `bootstrap` | Sample all TRs with replacement — same length as input **(recommended)** |
| `bootstrap_variable` | Bootstrap + random-length truncation (more stringent) |
| `subsample` | Random-length contiguous window, no shuffling |
| `bagging` | Sample without replacement; `shuffle_chunk_size` sets target length in minutes |
| `TRs` | Randomly reorder individual TRs |
| `minutes` | Randomly reorder minute-length chunks |
| `percent` | Sample a random `percent_holdout`% of TRs |
| `run` | Shuffle run order (multi-run data) |

**Recommended:** `bootstrap` with `percent_holdout=100`.

Use the CLI flags `--shuffle OPTION` and `--shuffle-chunk-size N` to set the
shuffle method and chunk size at submission time without editing `run_PCM.sh`:

```bash
sbatch run_PCM.sh --shuffle bagging --shuffle-chunk-size 5
```

---

## Motion options

Set `motion_file` in `run_PCM.sh` (or `--motion` flag). Three formats are accepted:

| Extension | Format | Notes |
|---|---|---|
| `.mat` | DCAN FD format | Used directly |
| `.hdf5` | XCP-D format | Auto-converted to `.mat` before submission |
| `.txt` | Binary frame mask | One integer per line: `1`=keep, `0`=remove. Bypasses FD filtering entirely. |

The FD threshold is set via `FD` (default: 0.2 mm). A `.txt` mask cannot be
combined with `STARTMINS` (time truncation).

---

## Time truncation

```bash
# First 10 minutes:
sbatch run_PCM.sh --startmins 10

# Last 10 minutes:
sbatch run_PCM.sh --startmins 10 --keepfrom end

# Loop over multiple lengths (5, 10, 15 min):
sbatch run_PCM.sh --startmins 5 --increment 5 --endmins 15
```

Leave `STARTMINS` empty (default) to use the full dataset. Each length gets
its own task folder (`BASEDIR/sub-SUB/ses-SES/task-TASK_method-*_trunc-Xm-start/`).
Truncated input files are stored under `BASEDIR/truncated_inputs/task-TASK/Nm-from-start/`.

---

## Special modes

### Combined figures (`--combined-figs`)

Aggregate all methods' permutation outputs and generate one set of
confidence-map figures from the combined pool.

```bash
bash run_PCM.sh --combined-figs --basedir /out/PCM/sub-01 \
    --dtseries /data/sub-01/bold.dtseries.nii
# Or without dtseries (set SUB/SES/TASK explicitly):
bash run_PCM.sh --combined-figs --basedir /out/PCM/sub-01 \
    --sub 01 --ses baseline --task rest
```

Scans all `task-TASK_*/successful_perms.conc` files, concatenates them, writes
`task-TASK_combined/all_perms.conc`, and submits one figure job. Can be re-run
any time to incorporate new methods.

---

## SLURM resource requirements

Resources are set automatically based on `METHOD`. Override in `run_PCM.sh`:

| Resource | matlab_tm | reprotm | Reason |
|---|---|---|---|
| RAM | 128 GB | 200 GB | Dense connectivity matrix + method overhead (ReproTM loads the dconn as float64 ≈ 66 GB at 91k) |
| Cores | 1 | 1 | Both serial |
| Scratch (`/tmp`) | 100 GB | 100 GB | Intermediate dconn file |
| Time | 10h | 12h | ReproTM's serial per-greyordinate loop needs more wall time |

---

## Output structure

```
BASEDIR/sub-SUB/ses-SES/
├── task-TASK_method-matlabTM_tmpl-scan_sh-bootstrap/
│   ├── run_params.json                 ← method, template, num_perms, FD, datestamp …
│   ├── successful_perms.conc           ← paths to completed perm recolored dscalars
│   ├── perms/
│   │   ├── perm-0001/
│   │   │   └── sub-SUB_ses-SES_task-TASK_perm-0001_recolored.dscalar.nii
│   │   └── perm-0002/ … perm-NNNN/
│   ├── standard/                       ← matlab_tm only; STANDARDTM=1
│   │   └── sub-SUB_ses-SES_task-TASK_standard_recolored.dscalar.nii
│   ├── figures/ciftis/
│   │   ├── Probability_Maps_across_perms_TM_Percent_holdout_*_network_probability.dscalar.nii
│   │   ├── Mode_of_Shuffled_dscalars_Percent_holdout_population_mode.dscalar.nii
│   │   ├── All_surface_networks_confidence_maps_images_with_labels.png
│   │   └── thresholded_confidence_maps/
│   └── logs/
│
├── task-TASK_method-reproTM_tmpl-abcc18_sh-bootstrap/
│   ├── run_params.json
│   ├── successful_perms.conc
│   ├── perms/
│   │   └── perm-0001/ … perm-NNNN/
│   ├── figures/ciftis/
│   └── logs/
│
└── task-TASK_combined/                 ← combined figures across methods (--combined-figs)
    ├── all_perms.conc
    ├── figures/ciftis/
    └── logs/
```

Task folder name encodes all run parameters: method, template, shuffle method,
and optionally FD, percent_holdout, truncation, and split-half. Perm indices
are 4-digit zero-padded (`perm-0001` … `perm-9999`). Logs and the conc file
live inside each task folder (not at BASEDIR level).

---

## Directory layout

```
PrecisionConfidenceMapping/
├── cluster.conf                ← SLURM partition/account/modules — edit this
├── config.sh                   ← central config (paths auto-computed, no edit needed)
├── run_PCM.sh                  ← USER ENTRY POINT — edit this
├── code/
│   ├── orchestrate_PCM.sh      ← long-running SLURM orchestrator
│   ├── run_permutation.sh      ← one per-permutation job (routes matlab_tm vs reprotm)
│   ├── run_standard_TM.sh      ← standard (unshuffled) TM job
│   ├── setup_matlab_tm.sh      ← run once (required): fetches + patches matlab_tm
│   ├── setup_reprotm.sh        ← run once (optional): --pinned/--latest, fetches ReproTM
│   └── functions/              ← MATLAB and Python helper functions
├── patches/                    ← template_matching_RH.patch + reprotm_fieldtrip_dconn_fallback.patch,
│                                  applied by the two setup_*.sh scripts above
├── template_matching/          ← PCM's own matlab_tm code only (matlab_tm_wrapper.m,
│                                  clean_dscalars_by_size_standalone.m, support_files/)
│                                  — the rest is fetched by setup_matlab_tm.sh
├── templates/
│   ├── template_matching/      ← network seedmap .mat files (matlab_tm + reprotm keywords)
│   └── reprotm/                ← PCM's own bundled ABCC default reprotm template
└── deps/
    ├── cifti-matlab/
    ├── cifti_connectivity/     ← dconn-building tool, shared by matlab_tm and reprotm
    ├── Zscore_dconn/           ← sectional dconn z-scoring, shared by both methods
    ├── fieldtrip_fileio/       ← FieldTrip CIFTI I/O, used by interpolate_noise_for_timeseries
    ├── matlab_tm/               ← NOT present until code/setup_matlab_tm.sh runs — fetched
    │                              from DCAN-Labs/compare_matrices_to_assign_networks
    ├── reprotm_fetched/         ← NOT present until code/setup_reprotm.sh runs — fetched
    │                              from KateJGodfrey/ReproTM
    ├── xcpd2dcanmotion/
    ├── interpolate_noise_for_timeseries/
    ├── Conte69_surfaces/
    ├── figure_maker/
    └── reprotm/                ← README.md + COMPATIBILITY_NOTES.md for the fetch/
                                   bring-your-own ReproTM setup (METHOD=reprotm)
```

---

## Troubleshooting

**"Required inputs are missing"** — Check that `dtseries`, `motion_file`, `surf_L`,
`surf_R`, and `BASEDIR` are all set in `run_PCM.sh` or passed as flags.

**"Could not parse SUB/SES/TASK from dtseries filename"** — If your filename is
not BIDS-formatted, set `--sub`, `--ses`, `--task` explicitly (or set `SUB`,
`SES`, `TASK` in USER SETTINGS).

**"dtseries file not found"** — Check the full path set in `dtseries`.

**"motion file not found"** — Check the path in `motion_file`. Accepted extensions:
`.mat`, `.hdf5`, `.txt`.

**`matlab_tm` — "METHOD=matlab_tm requires template_matching_RH.m … which PCM does
not bundle"** — Run `bash code/setup_matlab_tm.sh` once, on a login node/workstation
with internet access (not inside a SLURM job), then retry.

**`reprotm` — "METHOD=reprotm requires ReproTM … which PCM does not bundle"** — Run
`bash code/setup_reprotm.sh` once, same login-node/workstation caveat as above.

**`reprotm` — `setup_reprotm.sh` says "already exists (mode: …), but you asked for
--…"** — You're switching between `--pinned` and `--latest` on an existing fetch. Add
`--force` to wipe and re-fetch in the new mode.

**Permutation jobs failing** — Check `BASEDIR/output_logs/perm_*.out`. Common
causes: insufficient scratch space (`tmpspace`), wrong surface file paths.

**Figures not generated** — The figure job runs after all permutations. Check
`BASEDIR/output_logs/` for the orchestrator log. If it timed out (48h), re-run
`run_PCM.sh` — it skips completed permutations.

**Wrong cluster settings** — Copy `cluster.conf` to your study directory and
edit it there.

---

## Acknowledgments

PCM bundles and fetches several independently-authored tools and datasets — see
**`ATTRIBUTIONS.md`** for the full list, licenses, and citation guidance.
