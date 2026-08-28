# Synthetic demo data

**This is random, non-scientific data.** It exists to let you verify PCM is
installed correctly and the pipeline runs end to end — it is **not** an
example of a real analysis, and results from it mean nothing biologically.
The published analysis in [the PCM preprint](../../ATTRIBUTIONS.md) used real
fMRI data, not this.

## Generate it

```bash
python3 generate_demo_data.py
```

Requires `nibabel` and `numpy` (already needed for `METHOD=reprotm` — see the
main README's Requirements section). Produces two files in this folder
(not committed to git — regenerate anytime, they're deterministic):

- `sub-DEMO01_ses-01_task-rest_bold.dtseries.nii` — 200 frames (2.7 min at
  TR=0.8s) of random Gaussian noise, in the standard **surface-only** 59412
  greyordinate space (cortex only, no subcortex).
- `sub-DEMO01_ses-01_task-rest_motion_mask.txt` — a binary frame mask of all
  `1`s (keep every frame). This bypasses FD-based motion censoring entirely
  (see the main README's Motion options table) — there's no reason to
  fabricate a realistic motion structure for a synthetic-data smoke test.

Surfaces aren't generated — reuse the ones already bundled in
`deps/Conte69_surfaces/` (see command below). They're `very_inflated`
surfaces, not `midthickness` like a real run would use; fine for a structural
smoke test, but don't mistake the demo output for anatomically meaningful
results.

## Why surface-only (59412), not full-brain (91282)

PCM's memory footprint is driven by the greyordinate count, not how much data
you feed it — the dense connectivity matrix is always (greyordinates)²
regardless of timeseries length. Surface-only cuts that from ~36GB to ~15GB
(dense) before the z-scoring step's ~2x overhead, meaningfully lowering what
a reviewer needs to get access to in order to run this. **This is why the
template flag below matters**: it must match the demo data's grayordinate
count (59412), not the default full-brain template.

## Run it

```bash
# From this folder, after generating the data above:
sbatch ../../run_PCM.sh \
    --dtseries "$(pwd)/sub-DEMO01_ses-01_task-rest_bold.dtseries.nii" \
    --motion   "$(pwd)/sub-DEMO01_ses-01_task-rest_motion_mask.txt" \
    --surf-l   "$(pwd)/../../deps/Conte69_surfaces/Conte69.L.very_inflated.32k_fs_LR.surf.gii" \
    --surf-r   "$(pwd)/../../deps/Conte69_surfaces/Conte69.R.very_inflated.32k_fs_LR.surf.gii" \
    --basedir  /path/to/some/output/dir \
    --template abcd_surf \
    --num 1
```

`--template abcd_surf` is required — it's the one bundled template whose
network seedmap is also 59412-row (surface-only), matching this synthetic
data. `--num 1` runs a single permutation, which is all a smoke test needs.

Before this will run at all, you still need to do the one-time setup for
whichever `METHOD` you're testing (`bash code/setup_matlab_tm.sh` and/or
`bash code/setup_reprotm.sh` — see the main README).

**Expected resources for this demo run** (measure and update once actually
run, per the main README's install-time caveat): meaningfully less than the
production SLURM resource table (main README) thanks to surface-only mode
and a single permutation, but still needs a real SLURM allocation with
tens of GB of RAM — this is not laptop-scale even for a smoke test, and that
limitation is expected and documented, not a bug.
