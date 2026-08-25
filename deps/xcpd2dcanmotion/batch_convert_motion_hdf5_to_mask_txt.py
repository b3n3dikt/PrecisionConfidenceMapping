#!/usr/bin/env python3
"""
Run convert_motion_hdf5_to_mask_txt.py on every hdf5 file in a folder, at a
given FD threshold. Each output .txt is written alongside its source hdf5
(same folder), named <hdf5_basename>_fd-<fd>_mask.txt.

example:
    python batch_convert_motion_hdf5_to_mask_txt.py /path/to/folder --fd 0.2
    python batch_convert_motion_hdf5_to_mask_txt.py /path/to/folder --fd 0.3 --pattern "*_qc.hdf5"
"""

import argparse
import glob
import os

from convert_motion_hdf5_to_mask_txt import convert


def batch_convert(folder, fd, pattern="*.hdf5"):
    hdf5_files = sorted(glob.glob(os.path.join(folder, pattern)))
    if not hdf5_files:
        raise SystemExit(f"No files matching '{pattern}' in {folder}")

    n_ok, n_fail = 0, 0
    for hdf5_path in hdf5_files:
        try:
            convert(hdf5_path, fd)
            n_ok += 1
        except Exception as e:
            print(f"SKIPPED {hdf5_path}: {e}")
            n_fail += 1

    print(f"\nDone: {n_ok} converted, {n_fail} skipped, out of {len(hdf5_files)} files.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument("folder", help="Folder containing motion hdf5 files")
    parser.add_argument("--fd", type=float, default=0.2, help="FD threshold (default: 0.2)")
    parser.add_argument("--pattern", default="*.hdf5", help="Glob pattern for input files (default: *.hdf5)")
    args = parser.parse_args()

    batch_convert(args.folder, args.fd, args.pattern)
