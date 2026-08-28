# Attributions

PrecisionConfidenceMapping (PCM) is built on top of several independently-authored
tools and datasets. This file lists everything bundled in or fetched by this repo
that PCM did not originate, where it comes from, and what license governs it. Each
tool's own `LICENSE`/`README` file (kept in place in its subfolder) is the
authoritative source — this file is a convenience index, not a substitute for
reading those.

For citation purposes (papers to cite, as opposed to license compliance), see
**"Citing PCM and its components"** at the end.

## PCM's own code

PrecisionConfidenceMapping's own orchestration, MATLAB, and Python code (i.e.
everything not listed in the tables below) is licensed under BSD 3-Clause — see
the repo-root `LICENSE` file.

**Open question worth raising with UMOTC/legal alongside the matlab_tm patent
question:** `deps/` bundles GPLv2-licensed code directly in this repository
(`cifti-matlab`, `deps/fieldtrip_fileio`'s `fileio` module). GPL's copyleft terms
can have implications for what license the *combined, redistributed* repository
can carry, separate from what license PCM's own original code is offered under.
Not resolved here — flagging so it gets a real answer rather than an assumption.

---

## Fetched at setup time (not stored in this repo's git history)

These are downloaded by a `code/setup_*.sh` script the first time you need them —
see `PrecisionConfidenceMapping_guide.html` Section 2b/2c or the relevant script's
own header comment for why each is handled this way instead of being vendored like
everything below.

| Component | Source | License | Fetched by |
|---|---|---|---|
| Template matching core (`template_matching_RH.m` et al.) | R. Hermosillo / University of Minnesota — [DCAN-Labs/compare_matrices_to_assign_networks](https://github.com/DCAN-Labs/compare_matrices_to_assign_networks) | UMN provisional patent notice — non-profit/research use only, no redistribution without approval (see the fetched copy's own `LICENSE.txt`) | `code/setup_matlab_tm.sh` |
| ReproTM (`ReproTM_v1.0.0.py`, `minsize_v1.0.0.py`) | Kate Godfrey and collaborators — [KateJGodfrey/ReproTM](https://github.com/KateJGodfrey/ReproTM) | **No LICENSE file as of this writing** — used here as attributed, unmodified-except-for-PCM's-own-patches upstream code | `code/setup_reprotm.sh` |

PCM's own two small compatibility patches applied to the above are documented in
`patches/template_matching_RH.patch` and `patches/reprotm_fieldtrip_dconn_fallback.patch`.

---

## Bundled directly in this repo (`deps/`)

| Component | Source | License | Used for | Notes |
|---|---|---|---|---|
| `cifti-matlab` | Washington University School of Medicine (+ Robert Oostenveld, `read_nifti2_hdr.m`) — [Washington-University/cifti-matlab](https://github.com/Washington-University/cifti-matlab) | GPL v2+ | Reading/writing CIFTI files — `ciftiopen`/`ciftisave`, used by every method | Pinned at commit `bcb6da2` (2020-10-14) plus one small local fix (`cifti_read.m`, struct-array indexing) not yet pushed upstream |
| `cifti_connectivity` | DCAN Labs — [DCAN-Labs/cifti-connectivity](https://github.com/DCAN-Labs/cifti-connectivity) | BSD 3-Clause | Building dense connectivity matrices (dconns) for matlab_tm and reprotm | Pinned at commit `70d7957` (2023-07-31) plus several local fixes (a race-condition fix in `cifti_conn_matrix_for_wrapper_continous.m`, better error logging, an optional `FISHER_Z` env-var toggle for the `-fisher-z` correlation flag) not yet pushed upstream |
| `interpolate_noise_for_timeseries` | DCAN Labs — R. Hermosillo (credited directly in the tool's own header comment) — [DCAN-Labs/interpolate_noise_for_timeseries](https://github.com/DCAN-Labs/interpolate_noise_for_timeseries) (private repo) | **No LICENSE file found** | Injecting noise into zeroed-out grayordinates before smoothing | License status not yet confirmed with the author |
| `figure_maker` | DCAN Labs — R. Hermosillo and/or T. Madison | **No LICENSE file found** | Generating Workbench scene images (`.png`) from `.dscalar`/`.dlabel` outputs | Own README, own upstream repo — license status not yet confirmed with the author(s) |
| `Zscore_dconn` | DCAN Labs / PCM lab lineage | Not separately licensed | Sectional (per-hemisphere/subcortex) z-scoring of dconns, used by matlab_tm and reprotm | Uses `cifti-matlab`'s own `diminfo` for its partition boundaries (portable to any resolution) — no FieldTrip dependency |
| FieldTrip `fileio` module (+ `gifti`/`@xmltree`/`utilities` helpers), `deps/fieldtrip_fileio/` | FieldTrip project / Guillaume Flandin and others | `fileio`: **GPLv2** (confirmed — `fileio/COPYING`). `gifti`/`@xmltree`/`utilities`: not individually verified | CIFTI reading (`ft_read_cifti_mod`) needed by `interpolate_noise_for_timeseries.m` | Independent third-party code |
| Conte69 human surfaces | Van Essen Lab / Human Connectome Project | Public HCP release, no bundled LICENSE file | Visualization (figure generation) | See "Citing PCM and its components" below |

---

## What "no LICENSE file found" means here

A few of the tools above (`interpolate_noise_for_timeseries`, `figure_maker`,
and the `gifti`/`@xmltree`/`utilities` pieces of `deps/fieldtrip_fileio/`)
don't ship an explicit license.
That's not the same as "no restrictions" — it just means default copyright applies
and nobody has explicitly granted redistribution rights. ReproTM was in the same
situation until its author was asked directly; the same "can we include this?"
check is still outstanding for the tools listed above.

---

## Citing PCM and its components

If you use PCM in published work, please cite PCM itself (see `CITATION.cff`)
**and** the method(s) you used:

| Method | Cite |
|---|---|
| PCM itself | Ramirez, J.S.B., Hermosillo, R.J.M., Moser, J. et al. Precision Confidence Mapping: An approach to determining individualized network topography with limited data. *bioRxiv* (2026). https://doi.org/10.64898/2026.08.17.744952 |
| `matlab_tm` | Hermosillo, R.J.M., Moore, L.A., Feczko, E. et al. A precision functional atlas of personalized network topography and probabilities. *Nat Neurosci* 27, 1000–1013 (2024). https://doi.org/10.1038/s41593-024-01596-5 |
| `reprotm` | The ReproTM paper (Godfrey et al.) — see [KateJGodfrey/ReproTM](https://github.com/KateJGodfrey/ReproTM) for the current reference |
| Human surface visualization | The HCP minimal preprocessing pipelines paper (Glasser et al., NeuroImage 2013) and/or the Conte69 atlas paper (Van Essen et al.) — verify exact citation before use |

*(That last row is flagged "verify exact citation" deliberately — the precise
journal/year hasn't been double-checked, and getting a citation wrong is worse
than leaving a placeholder.)*
