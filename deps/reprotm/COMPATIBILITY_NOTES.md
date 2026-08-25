# ReproTM compatibility notes

If you used `code/setup_reprotm.sh` (see `README.md`), Issue 1 below is already
patched for you automatically (`--pinned`: always; `--latest`: only if it still
applies — see that script's header for how). This doc exists for the bring-your-own
install path, and to explain what each patch does and why. Issue 2 no longer needs
patching at all — Kate fixed it upstream herself (see below).

## Issue 1 — `nb.load()` fails on FieldTrip-written CIFTI dconns — STILL OPEN upstream

**Symptom:** `ValueError: Affine transformation should be a 4x4 array` when ReproTM
loads the dconn.

**Cause:** PCM builds `.dconn.nii` files with MATLAB FieldTrip (`ft_write_cifti_mod`).
FieldTrip's CIFTI-2 writer sets the subcortical volume affine in a way nibabel's
stricter CIFTI-2 axis parser rejects. Dconns written by `wb_command` don't trigger
this — it's specific to FieldTrip-written files. Verified still present as of
`REPROTM_PINNED_COMMIT` (config.sh) and current upstream `HEAD` (checked 2026-08-19).

**If you're on the bring-your-own path:** `code/setup_reprotm.sh` only patches its own
fetched copy — a manually-installed `REPROTM_DIR` doesn't get it. Apply
`patches/reprotm_fieldtrip_dconn_fallback.patch` yourself (`git apply` from inside
your ReproTM checkout), or wrap the `nb.load()` call in a `try/except ValueError` that
falls back to reading the file as a raw NIfTI-2 volume (safe here since ReproTM only
needs the raw N×N matrix, not CIFTI structure metadata) — see the patch file for the
exact fix.

## Issue 2 — `scipy.stats.mode(...)[0][0]` breaking on scipy >= 1.9 — FIXED UPSTREAM

**Used to happen** in the min-size cleanup step (`scipy.stats.mode`'s return shape
changed with the `keepdims` default in scipy 1.9; code written against the pre-1.9
shape broke on newer scipy). **Kate fixed this herself** upstream in commit `3b17c53`
("update minsize to ensure backwards scipy compatibility", 2026-05-12) — switched to
`int((stats.mode(x)).mode)`. `REPROTM_PINNED_COMMIT` is set to a commit after this
fix, so neither `setup_reprotm.sh` mode needs to patch it anymore. If you're on an
old bring-your-own checkout from before this date and still hit it, update your
ReproTM checkout rather than patching around it.

## Not really an "issue" — grayordinate-count assumptions

Both ReproTM scripts hardcode human grayordinate counts (59412 cortex-only, 91282
whole-brain). If you're using PCM's macaque support (`--template macaque`), your
ReproTM install needs to handle the macaque grayordinate count (56522) — either via a
version of ReproTM that's already been generalized for this, or your own local
changes. This isn't a PCM-specific quirk to patch around, just something to be aware
of if you're working with non-human data.

---

Have a fix for something not listed here, or found ReproTM has moved past an issue
`--pinned` still thinks needs patching? `--latest` mode already handles "already
fixed upstream" gracefully — for `--pinned`, update `REPROTM_PINNED_COMMIT` in
`config.sh` and re-verify which patches (if any) are still needed.
