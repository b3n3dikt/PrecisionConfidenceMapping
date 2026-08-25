#!/usr/bin/env python3
"""
Convert an XCP-D motion hdf5 (*_qc.hdf5, group "dcan_motion") directly to a PCM
binary frame mask .txt (one integer per line, 1 = keep, 0 = remove) at a given
FD threshold -- skips the .mat round-trip for people who just want a mask file.

example:
    python convert_motion_hdf5_to_mask_txt.py sub-X_qc.hdf5 --fd 0.2
    python convert_motion_hdf5_to_mask_txt.py sub-X_qc.hdf5 --fd 0.3 -o sub-X_mask.txt
"""

import argparse
import os

import h5py
import numpy as np


def convert(hdf5_path, fd, out_path=None):
    with h5py.File(hdf5_path, "r") as f:
        group = f["dcan_motion"]
        thresholds = {name: group[name]["threshold"][()] for name in group.keys()}
        match = [name for name, thr in thresholds.items() if np.isclose(thr, fd)]
        if not match:
            available = sorted(thresholds.values())
            raise SystemExit(
                f"No FD threshold {fd} in {hdf5_path}. Available: {available}"
            )
        binary_mask = group[match[0]]["binary_mask"][()]

    # hdf5 binary_mask: 1 = frame removed (bad), 0 = frame kept (good).
    # PCM's .txt mask convention is the opposite: 1 = keep, 0 = remove.
    keep_mask = (1 - binary_mask).astype(int)

    if out_path is None:
        base = os.path.splitext(os.path.basename(hdf5_path))[0]
        out_path = os.path.join(
            os.path.dirname(hdf5_path), f"{base}_fd-{fd}_mask.txt"
        )

    np.savetxt(out_path, keep_mask, fmt="%d")
    print(f"Wrote {len(keep_mask)} frames ({int(keep_mask.sum())} kept) to {out_path}")
    return out_path


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("hdf5_path", help="Input *_qc.hdf5 motion file")
    parser.add_argument("--fd", type=float, default=0.2, help="FD threshold (default: 0.2)")
    parser.add_argument("-o", "--output", default=None, help="Output .txt path (default: alongside input)")
    args = parser.parse_args()

    convert(args.hdf5_path, args.fd, args.output)
