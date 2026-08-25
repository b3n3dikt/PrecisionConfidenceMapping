# ReproTM — external dependency (METHOD=reprotm)

PCM's `reprotm` method runs **ReproTM** (Godfrey et al.) — a separate, independently
maintained codebase. PCM does **not** vendor a copy of it in its own git history.

## 1. Get ReproTM — easiest: let PCM fetch it for you

```bash
bash code/setup_reprotm.sh              # --pinned by default: known-good commit,
                                         # compatibility patches applied
bash code/setup_reprotm.sh --latest     # current upstream HEAD instead — patches are
                                         # only applied if still needed (see below)
```

This clones into `deps/reprotm_fetched/` (gitignored, never committed) and
`REPROTM_DIR` picks it up automatically — nothing else to configure. Run it once, on a
login node/workstation with internet access (not inside a SLURM job).

**`--pinned` vs `--latest`:** `--pinned` clones a specific commit PCM has verified
works, and unconditionally applies the compatibility patches below — the safest
choice, immune to Kate restructuring the codebase later. `--latest` clones whatever is
currently on GitHub and only applies each patch if it still applies cleanly (skipping,
with a message, anything Kate's already fixed upstream) — you get her improvements
automatically, at the cost of "might need a manual fix if something changed a lot."
Switching between modes later requires `--force` (wipes and re-fetches).

## 1b. Or: bring your own install

If you'd rather manage ReproTM yourself instead of using `setup_reprotm.sh` — say, you
already have a working checkout, or want a specific fork/branch — download or clone it
yourself:

**https://github.com/KateJGodfrey/ReproTM**

Any version should work as long as it accepts the CLI arguments PCM calls it with (see
`code/run_permutation.sh`, the `METHOD=reprotm` branch, for the exact invocation). See
`COMPATIBILITY_NOTES.md` in this folder for issues PCM previously hit — worth a skim
if you run into something odd.

## 2. Point PCM at it (only needed for the bring-your-own path above)

Set `REPROTM_DIR` in your `cluster.conf` to the folder you downloaded/cloned — this
overrides the auto-fetched default:

```bash
export REPROTM_DIR="/path/to/your/ReproTM"
```

PCM expects the standard ReproTM repo layout underneath that path (note the `code/`
prefix — easy to miss, PCM's own path construction accounts for it):

```
${REPROTM_DIR}/
└── code/
    ├── ReproTM/ReproTM_v1.0.0.py
    └── minsize/minsize_v1.0.0.py
```

If `REPROTM_DIR` doesn't resolve to a valid install (neither auto-fetched nor
manually set) and doesn't contain those files, `run_PCM.sh` will fail fast at
submission time with a message pointing back here — it won't burn a SLURM allocation
finding out mid-job.

## 3. Python environment

ReproTM needs `nibabel`, `numpy`, and `scipy`. The cluster's default `python3` usually
lacks `nibabel`; set `REPROTM_PYTHON` in `cluster.conf` to a Python that has them (e.g.
a conda environment), or `pip install --user nibabel scipy numpy` for the default
interpreter. PCM preflight-checks this import before starting the (slow) dconn build,
so a misconfigured environment fails in seconds rather than after ~40 minutes.

## Credit

ReproTM is the work of Kate Godfrey and collaborators — please cite the ReproTM
repository/paper (see their README) alongside PCM if you use `METHOD=reprotm` in your
work.
