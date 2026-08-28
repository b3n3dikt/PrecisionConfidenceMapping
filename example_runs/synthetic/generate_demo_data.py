#!/usr/bin/env python3
"""Generate synthetic dtseries + motion mask for a PCM install/smoke-test demo.

This produces RANDOM, NON-SCIENTIFIC data — it exists only to prove PCM is
installed correctly and the pipeline runs end to end. It is not, and should
never be used as, an example of a real analysis. See README.md in this folder.

Usage:
    python3 generate_demo_data.py [--frames 200] [--tr 0.8] [--out-dir .]

Requires: nibabel, numpy (both already required for METHOD=reprotm).
"""
import argparse
import os

import nibabel as nb
import numpy as np

THIS_DIR = os.path.dirname(os.path.abspath(__file__))
SCAFFOLD = os.path.join(
    THIS_DIR, "..", "..", "template_matching", "support_files",
    "91282_Greyordinates_surf_only.dtseries.nii",
)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--frames", type=int, default=200,
                     help="Number of synthetic timepoints (default: 200, "
                          "~2.7 min at --tr 0.8 -- plenty for a smoke test, "
                          "not a real analysis)")
    ap.add_argument("--tr", type=float, default=0.8,
                     help="Repetition time in seconds (default: 0.8)")
    ap.add_argument("--out-dir", default=THIS_DIR,
                     help="Where to write the output files (default: this folder)")
    ap.add_argument("--seed", type=int, default=0,
                     help="Random seed, for reproducible demo data (default: 0)")
    args = ap.parse_args()

    os.makedirs(args.out_dir, exist_ok=True)

    print(f"Loading scaffold (spatial structure only): {SCAFFOLD}")
    scaffold = nb.load(SCAFFOLD)
    brain_model_axis = scaffold.header.get_axis(1)  # BrainModelAxis: CORTEX_LEFT + CORTEX_RIGHT, 59412 greyordinates
    n_greyordinates = scaffold.shape[1]

    print(f"Generating {args.frames} frames x {n_greyordinates} greyordinates "
          f"of random Gaussian noise (seed={args.seed})...")
    rng = np.random.default_rng(args.seed)
    data = rng.standard_normal((args.frames, n_greyordinates)).astype(np.float32)

    series_axis = nb.cifti2.SeriesAxis(start=0, step=args.tr, size=args.frames, unit="SECOND")
    new_img = nb.Cifti2Image(data, header=(series_axis, brain_model_axis))
    new_img.nifti_header.set_intent("NIFTI_INTENT_CONNECTIVITY_DENSE_SERIES")

    dtseries_out = os.path.join(
        args.out_dir,
        "sub-DEMO01_ses-01_task-rest_bold.dtseries.nii",
    )
    new_img.to_filename(dtseries_out)
    print(f"Wrote synthetic dtseries: {dtseries_out}")

    # Motion mask: PCM's .txt format is one 1/0 per frame, "1" = keep.
    # All-1s bypasses FD filtering entirely (see README's Motion options table) --
    # simplest possible valid motion input, no need to fabricate a realistic
    # DCAN .mat or XCP-D .hdf5 motion structure for a synthetic-data smoke test.
    motion_out = os.path.join(
        args.out_dir,
        "sub-DEMO01_ses-01_task-rest_motion_mask.txt",
    )
    with open(motion_out, "w") as f:
        f.write("\n".join(["1"] * args.frames) + "\n")
    print(f"Wrote synthetic motion mask (all frames kept): {motion_out}")

    print("\nDone. See README.md in this folder for how to run PCM on this data.")


if __name__ == "__main__":
    main()
