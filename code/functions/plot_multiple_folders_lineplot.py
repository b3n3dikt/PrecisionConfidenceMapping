#!/usr/bin/env python3

"""
plot_multiple_folders_lineplot.py

This script takes multiple folder paths (each presumably containing .txt files
like "<metric>_<ExpMin>min_with_<RefMin>min.txt>"), averages data across 
multiple subjects, and produces a line plot (with error bars = std. dev) for
each network.

In other words, each folder path corresponds to some group or threshold, 
and you want to see how the metric changes across different ExpMin (x-axis) 
when comparing to ref_min (y-axis = metric value).

By default, it searches each folder for files named:
   <metric>_<ExpMin>min_with_<RefMin>min.txt
Inside each file, we expect either 15 rows (one for each of the standard 
networks) or 1 row (e.g., 'whole-brain' version).

Well gather data across user-specified subjects (i.e., the script looks
for a sub-XXXX pattern in the file pathif found and matches your 
--subjects list, that file is included). If you do not specify any subjects,
it will include all .txt files in that folder.

Finally, for each folder (one line on the plot), we compute mean ± std 
across subjects, at each ExpMin, for each network, and produce a line plot.
One figure per network, saved in --output_dir.

Usage (minimal):
  python3 plot_multiple_folders_lineplot.py \
    --folders /path/one /path/two ...
    --labels  labelOne  labelTwo ...
    --subjects subID1 subID2 ...
    --metric  PPV_whole
    --ref_min 70
    --exp_minutes 2 5 10 30 ...
    --output_dir line_plots

Multiple metrics can be specified with repeated --metric flags:
    --metric PPV_whole --metric cDC_whole --metric ...
"""
#!/usr/bin/env python3

import os
import re
import glob
import argparse
import numpy as np
import pandas as pd
import matplotlib.pyplot as plt

NETWORK_LABELS_15 = [
    "DMN","Vis","FP","DAN","VAN","Sal","CO","SMd","SMl",
    "Aud","Tpole","MTL","PMN","PON","SCAN"
]

def parse_txt_file(txt_path, metric, ref_min, subjects_filter):
    base = os.path.basename(txt_path)
    if not base.startswith(metric + "_"):
        return []
    mm = re.search(r"_(\d+)min_with_(\d+)min", base)
    if not mm:
        return []
    exp_min_num = int(mm.group(1))
    ref_min_num = int(mm.group(2))
    if ref_min_num != ref_min:
        return []

    subj_match = re.search(r"sub-([A-Za-z0-9]+)", txt_path)
    subject_found = subj_match.group(1) if subj_match else None
    if subjects_filter and subject_found not in subjects_filter:
        return []

    arr = np.loadtxt(txt_path, ndmin=2)
    rows, cols = arr.shape
    if cols == 0:
        return []

    out_data = []
    for r in range(rows):
        val = arr[r, 0]
        if rows == 15:
            net = NETWORK_LABELS_15[r] if r < len(NETWORK_LABELS_15) else f"row{r}"
        elif rows == 1:
            net = "whole-or-1row"
        else:
            net = f"row{r}"
        out_data.append({
            "Subject": subject_found,
            "ExpMin": exp_min_num,
            "Network": net,
            "Value": val
        })
    return out_data

def gather_data_for_folder(folder, metric, ref_min, exp_minutes, subjects_filter):
    all_txts = glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True)
    data_rows = []
    for txt_file in all_txts:
        parsed = parse_txt_file(txt_file, metric, ref_min, subjects_filter)
        data_rows.extend(parsed)
    df = pd.DataFrame(data_rows)
    if df.empty:
        return df
    if exp_minutes:
        df = df[df["ExpMin"].isin(exp_minutes)]
    return df

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--folders", nargs="+", required=True)
    parser.add_argument("--labels", nargs="+", required=True)
    parser.add_argument("--subjects", nargs="*", default=[])
    parser.add_argument("--metric", nargs="+", required=True)
    parser.add_argument("--ref_min", type=int, default=70)
    parser.add_argument("--exp_minutes", type=int, nargs="*", default=[])
    parser.add_argument("--output_dir", default="line_plots")
    parser.add_argument("--linewidth", type=float, default=2.0)
    parser.add_argument("--colors", nargs="+", default=[])
    parser.add_argument("--capsize", type=float, default=3.0)
    parser.add_argument("--alpha", type=float, default=1.0)

    # New: Optional y-axis limits
    parser.add_argument("--vmin", type=float, default=None,
                        help="Optional lower bound of y-axis. If not provided, auto-scale.")
    parser.add_argument("--vmax", type=float, default=None,
                        help="Optional upper bound of y-axis. If not provided, auto-scale.")

    # Optional figure size
    parser.add_argument("--figsize", type=float, nargs=2, default=[6.0, 5.0],
        help="Figure size in inches: width height (default=6 5).")

    args = parser.parse_args()

    if len(args.folders) != len(args.labels):
        raise ValueError("Number of --folders must match number of --labels.")
    if args.colors and (len(args.colors) != len(args.folders)):
        raise ValueError("If --colors is provided, must match the number of --folders & --labels.")

    os.makedirs(args.output_dir, exist_ok=True)

    for met in args.metric:
        print(f"\n=== Processing metric: {met} ===")
        combined = []
        for folder, label in zip(args.folders, args.labels):
            df_folder = gather_data_for_folder(
                folder=folder,
                metric=met,
                ref_min=args.ref_min,
                exp_minutes=args.exp_minutes,
                subjects_filter=args.subjects
            )
            if df_folder.empty:
                print(f"  [WARNING] No data found in '{folder}' for {met} (ref={args.ref_min})")
                continue
            df_folder["LineLabel"] = label
            combined.append(df_folder)

        if not combined:
            print("No data for this metric. Skipping.")
            continue

        bigDF = pd.concat(combined, ignore_index=True)

        NETWORK_LABELS_15_IN_DATA = [n for n in NETWORK_LABELS_15 if n in bigDF["Network"].unique()]
        leftover_nets = sorted(set(bigDF["Network"].unique()) - set(NETWORK_LABELS_15_IN_DATA))
        net_order = NETWORK_LABELS_15_IN_DATA + leftover_nets

        for net in net_order:
            sub_net = bigDF[bigDF["Network"] == net]
            if sub_net.empty:
                continue

            g1 = sub_net.groupby(["LineLabel","ExpMin","Subject"])["Value"].mean().reset_index()
            stats = g1.groupby(["LineLabel","ExpMin"])["Value"].agg(["mean","std"]).reset_index()

            line_label_order = [lbl for lbl in args.labels if lbl in stats["LineLabel"].values]

            # Create figure with user-defined size
            fig, ax = plt.subplots(figsize=(args.figsize[0], args.figsize[1]))

            for i, line_label in enumerate(line_label_order):
                sub_line = stats[stats["LineLabel"] == line_label]
                xvals = sub_line["ExpMin"].values
                yvals = sub_line["mean"].values
                yerr = sub_line["std"].values

                color = None
                if args.colors:
                    color = args.colors[i]

                ax.errorbar(
                    xvals, yvals,
                    yerr=yerr,
                    label=line_label,
                    linewidth=args.linewidth,
                    color=color,
                    alpha=args.alpha,
                    capsize=args.capsize
                )

            ax.set_title(f"{net} (Metric={met}, RefMin={args.ref_min})")
            ax.set_xlabel("ExpMin")
            ax.set_ylabel("Value")

            # If user specified y-limits, apply them
            if args.vmin is not None:
                ax.set_ylim(bottom=args.vmin)
            if args.vmax is not None:
                ax.set_ylim(top=args.vmax)

            # Place legend above plot
            ax.legend(
                loc="lower center",
                bbox_to_anchor=(0.5, 1.02),
                borderaxespad=2,
                #ncol=len(line_label_order)
            )
            fig.tight_layout()

            out_png = os.path.join(args.output_dir, f"{met}_{net}_lineplot.png")
            plt.savefig(out_png, dpi=150)
            plt.close()
            print(f"Saved line plot -> {out_png}")

    print("Done. All metrics processed.")

if __name__ == "__main__":
    main()

# import os
# import re
# import glob
# import argparse
# import numpy as np
# import pandas as pd
# import matplotlib.pyplot as plt

# NETWORK_LABELS_15 = [
#     "DMN","Vis","FP","DAN","VAN","Sal","CO","SMd","SMl",
#     "Aud","Tpole","MTL","PMN","PON","SCAN"
# ]

# def parse_txt_file(txt_path, metric, ref_min, subjects_filter):
#     base = os.path.basename(txt_path)
#     # Must match "<metric>_<ExpMin>min_with_<RefMin>min.txt"
#     if not base.startswith(metric + "_"):
#         return []
#     mm = re.search(r"_(\d+)min_with_(\d+)min", base)
#     if not mm:
#         return []
#     exp_min_num = int(mm.group(1))
#     ref_min_num = int(mm.group(2))
#     if ref_min_num != ref_min:
#         return []
#     # Attempt to find subject ID
#     subj_match = re.search(r"sub-([A-Za-z0-9]+)", txt_path)
#     subject_found = subj_match.group(1) if subj_match else None
#     # Filter if subjects_filter is non-empty
#     if subjects_filter and subject_found not in subjects_filter:
#         return []

#     arr = np.loadtxt(txt_path, ndmin=2)
#     rows, cols = arr.shape
#     if cols == 0:
#         return []

#     out_data = []
#     for r in range(rows):
#         val = arr[r, 0]
#         if rows == 15:
#             net = NETWORK_LABELS_15[r] if r < len(NETWORK_LABELS_15) else f"row{r}"
#         elif rows == 1:
#             net = "(whole-or-1row)"
#         else:
#             net = f"row{r}"
#         out_data.append({
#             "Subject": subject_found,
#             "ExpMin": exp_min_num,
#             "Network": net,
#             "Value": val
#         })
#     return out_data

# def gather_data_for_folder(folder, metric, ref_min, exp_minutes, subjects_filter):
#     all_txts = glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True)
#     data_rows = []
#     for txt_file in all_txts:
#         parsed = parse_txt_file(txt_file, metric, ref_min, subjects_filter)
#         data_rows.extend(parsed)
#     df = pd.DataFrame(data_rows)
#     if df.empty:
#         return df
#     if exp_minutes:
#         df = df[df["ExpMin"].isin(exp_minutes)]
#     return df

# def main():
#     parser = argparse.ArgumentParser()
#     parser.add_argument("--folders", nargs="+", required=True,
#         help="List of folder paths. Each folder => one line on the plot.")
#     parser.add_argument("--labels", nargs="+", required=True,
#         help="List of labels for each folder (same order).")
#     parser.add_argument("--subjects", nargs="*", default=[],
#         help="Optional. Only files matching sub-<ID> in that list are included.")
#     parser.add_argument("--metric", nargs="+", required=True,
#         help="One or more metric names (e.g. PPV_whole).")
#     parser.add_argument("--ref_min", type=int, default=70,
#         help="Reference minute in filenames (_Xmin_with_<ref_min>min).")
#     parser.add_argument("--exp_minutes", type=int, nargs="*", default=[],
#         help="Which ExpMin to keep. If empty, keep all found.")
#     parser.add_argument("--output_dir", default="line_plots",
#         help="Where to save the output figures.")
#     parser.add_argument("--linewidth", type=float, default=2.0,
#         help="Line width for the plots. Default=2.0")
#     parser.add_argument("--colors", nargs="+", default=[],
#         help="Optional: list of colors for lines in the same order as --folders")
#     parser.add_argument("--capsize", type=float, default=3.0,
#         help="Size of error bar caps. Default=3.0")
#     parser.add_argument("--alpha", type=float, default=1.0,
#         help="Transparency for lines/error bars. 1.0=opaque; default=1.0")

#     args = parser.parse_args()

#     if len(args.folders) != len(args.labels):
#         raise ValueError("Number of --folders must match number of --labels.")
#     if args.colors and (len(args.colors) != len(args.folders)):
#         raise ValueError("If --colors is provided, must match number of --folders & --labels.")

#     os.makedirs(args.output_dir, exist_ok=True)

#     for met in args.metric:
#         print(f"\n=== Processing metric: {met} ===")
#         combined = []
#         for folder, label in zip(args.folders, args.labels):
#             df_folder = gather_data_for_folder(
#                 folder=folder,
#                 metric=met,
#                 ref_min=args.ref_min,
#                 exp_minutes=args.exp_minutes,
#                 subjects_filter=args.subjects
#             )
#             if df_folder.empty:
#                 print(f"  [WARNING] No data found in '{folder}' for {met} (ref={args.ref_min})")
#                 continue
#             df_folder["LineLabel"] = label
#             combined.append(df_folder)

#         if not combined:
#             print("No data for this metric. Skipping.")
#             continue

#         bigDF = pd.concat(combined, ignore_index=True)
#         # bigDF has: [Subject, ExpMin, Network, Value, LineLabel]

#         # Reorder networks to the standard 15 first, then extras
#         net_order = []
#         for net in NETWORK_LABELS_15:
#             if net in bigDF["Network"].values:
#                 net_order.append(net)
#         leftover_nets = sorted(set(bigDF["Network"].unique()) - set(net_order))
#         net_order.extend(leftover_nets)

#         for net in net_order:
#             sub_net = bigDF[bigDF["Network"] == net]
#             if sub_net.empty:
#                 continue

#             # group => mean, std across subjects
#             g1 = sub_net.groupby(["LineLabel","ExpMin","Subject"])["Value"].mean().reset_index()
#             stats = g1.groupby(["LineLabel","ExpMin"])["Value"].agg(["mean","std"]).reset_index()

#             # Force plotting in the order the user gave in --labels
#             line_label_order = [lbl for lbl in args.labels if lbl in stats["LineLabel"].values]

#             fig, ax = plt.subplots()

#             for i, line_label in enumerate(line_label_order):
#                 sub_line = stats[stats["LineLabel"] == line_label]
#                 xvals = sub_line["ExpMin"].values
#                 yvals = sub_line["mean"].values
#                 yerr = sub_line["std"].values

#                 color = None
#                 if args.colors:
#                     color = args.colors[i]

#                 ax.errorbar(
#                     xvals, yvals, yerr=yerr,
#                     label=line_label,
#                     linewidth=args.linewidth,
#                     color=color,
#                     alpha=args.alpha,
#                     capsize=args.capsize
#                 )

#             ax.set_title(f"{net} (Metric={met}, RefMin={args.ref_min})")
#             ax.set_xlabel("ExpMin")
#             ax.set_ylabel("Value")

#             # Put legend on the right
#             #ax.legend(bbox_to_anchor=(1.02, 1), loc="upper left", borderaxespad=0)
#             ax.legend(
#                 loc="lower center",
#                 bbox_to_anchor=(0.5, 1.02),  # (x_center, y_topOffset)
#                 borderaxespad=2,
#                 #ncol=len(line_label_order),   # number of columns = #lines, or your choice
#             )
#             fig.tight_layout()

#             out_png = os.path.join(args.output_dir, f"{met}_{net}_lineplot.png")
#             plt.savefig(out_png, dpi=150)
#             plt.close()
#             print(f"Saved line plot -> {out_png}")

#     print("Done. All metrics processed.")

# if __name__ == "__main__":
#     main()

# import os
# import re
# import glob
# import argparse
# import numpy as np
# import pandas as pd
# import matplotlib.pyplot as plt

# NETWORK_LABELS_15 = [
#     "DMN","Vis","FP","DAN","VAN","Sal","CO","SMd","SMl",
#     "Aud","Tpole","MTL","PMN","PON","SCAN"
# ]

# def parse_txt_file(txt_path, metric, ref_min, subjects_filter):
#     base = os.path.basename(txt_path)

#     # Must match "<metric>_<ExpMin>min_with_<RefMin>min.txt"
#     if not base.startswith(metric + "_"):
#         return []
#     mm = re.search(r"_(\d+)min_with_(\d+)min", base)
#     if not mm:
#         return []
#     exp_min_num = int(mm.group(1))
#     ref_min_num = int(mm.group(2))
#     if ref_min_num != ref_min:
#         return []

#     # Attempt to find subject in path using "sub-XXXX"
#     subj_match = re.search(r"sub-([A-Za-z0-9]+)", txt_path)
#     subject_found = subj_match.group(1) if subj_match else None

#     # Filter by user-supplied subjects
#     if subjects_filter:
#         if subject_found not in subjects_filter:
#             return []

#     arr = np.loadtxt(txt_path, ndmin=2)
#     rows, cols = arr.shape
#     if cols == 0:
#         return []

#     out_data = []
#     for r in range(rows):
#         val = arr[r, 0]
#         if rows == 15:
#             net = NETWORK_LABELS_15[r] if r < len(NETWORK_LABELS_15) else f"row{r}"
#         elif rows == 1:
#             net = "(whole-or-1row)"
#         else:
#             net = f"row{r}"
#         out_data.append({
#             "Subject": subject_found,
#             "ExpMin": exp_min_num,
#             "Network": net,
#             "Value": val
#         })
#     return out_data

# def gather_data_for_folder(folder, metric, ref_min, exp_minutes, subjects_filter):
#     # Recursively find .txt
#     all_txts = glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True)
#     data_rows = []
#     for txt_file in all_txts:
#         parsed = parse_txt_file(txt_file, metric, ref_min, subjects_filter)
#         data_rows.extend(parsed)

#     df = pd.DataFrame(data_rows)
#     if df.empty:
#         return df

#     if exp_minutes:
#         df = df[df["ExpMin"].isin(exp_minutes)]
#     return df

# def main():
#     parser = argparse.ArgumentParser()
#     parser.add_argument("--folders", nargs="+", required=True,
#         help="List of folder paths. Each folder => one line on the plot.")
#     parser.add_argument("--labels", nargs="+", required=True,
#         help="List of labels for each folder (same order).")
#     parser.add_argument("--subjects", nargs="*", default=[],
#         help="Optional. Only files matching sub-<ID> in that list are included.")
#     parser.add_argument("--metric", nargs="+", required=True,
#         help="One or more metric names (e.g. PPV_whole).")
#     parser.add_argument("--ref_min", type=int, default=70,
#         help="Reference minute in filenames (_Xmin_with_<ref_min>min).")
#     parser.add_argument("--exp_minutes", type=int, nargs="*", default=[],
#         help="Which ExpMin to keep. If empty, keep all found.")
#     parser.add_argument("--output_dir", default="line_plots",
#         help="Where to save the output figures.")

#     # NEW: line width and color arguments
#     parser.add_argument("--linewidth", type=float, default=2.0,
#         help="Line width for the plots. Default=2.0")
#     parser.add_argument("--colors", nargs="+", default=[],
#         help="Optional: list of colors (e.g. 'red blue green'). "
#              "One color per folder, same order. If omitted, use matplotlib cycle.")

#     args = parser.parse_args()

#     # Basic checks
#     if len(args.folders) != len(args.labels):
#         raise ValueError("Number of --folders must match number of --labels.")
#     if args.colors and (len(args.colors) != len(args.folders)):
#         raise ValueError("If --colors is provided, must match number of --folders & --labels.")

#     os.makedirs(args.output_dir, exist_ok=True)

#     # For each metric => gather => plot
#     for met in args.metric:
#         print(f"\n=== Processing metric: {met} ===")
#         combined = []
#         for folder, label in zip(args.folders, args.labels):
#             df_folder = gather_data_for_folder(
#                 folder=folder,
#                 metric=met,
#                 ref_min=args.ref_min,
#                 exp_minutes=args.exp_minutes,
#                 subjects_filter=args.subjects
#             )
#             if df_folder.empty:
#                 print(f"  [WARNING] No data found in '{folder}' for {met} (ref={args.ref_min})")
#                 continue
#             df_folder["LineLabel"] = label
#             combined.append(df_folder)

#         if not combined:
#             print("No data for this metric. Skipping.")
#             continue

#         bigDF = pd.concat(combined, ignore_index=True)
#         # columns => [Subject, ExpMin, Network, Value, LineLabel]

#         # Sort networks in standard 15 order if possible
#         net_order = []
#         for net in NETWORK_LABELS_15:
#             if net in bigDF["Network"].values:
#                 net_order.append(net)
#         # add any networks not in the standard list (in sorted order)
#         leftover_nets = sorted(set(bigDF["Network"].unique()) - set(net_order))
#         net_order.extend(leftover_nets)

#         # For each network => compute mean, std across subjects, plot lines
#         for net in net_order:
#             sub_net = bigDF[bigDF["Network"]==net]
#             if sub_net.empty:
#                 continue

#             # group by [LineLabel, ExpMin, Subject] => mean => group by [LineLabel, ExpMin] => mean, std
#             g1 = sub_net.groupby(["LineLabel","ExpMin","Subject"])["Value"].mean().reset_index()
#             stats = g1.groupby(["LineLabel","ExpMin"])["Value"].agg(["mean","std"]).reset_index()

#             fig, ax = plt.subplots()
#             unique_line_labels = stats["LineLabel"].unique()

#             for i, line_label in enumerate(unique_line_labels):
#                 sub_line = stats[stats["LineLabel"]==line_label].copy()
#                 xvals = sub_line["ExpMin"].values
#                 yvals = sub_line["mean"].values
#                 yerr = sub_line["std"].values

#                 color = None
#                 if args.colors:
#                     color = args.colors[i]  # if user gave a list, use that

#                 ax.errorbar(xvals, yvals, yerr=yerr,
#                             label=line_label,
#                             linewidth=args.linewidth,
#                             color=color)

#             ax.set_title(f"{net} (Metric={met}, RefMin={args.ref_min})")
#             ax.set_xlabel("ExpMin")
#             ax.set_ylabel("Value")
#             ax.legend()
#             out_png = os.path.join(args.output_dir, f"{met}_{net}_lineplot.png")
#             plt.savefig(out_png, dpi=150)
#             plt.close()
#             print(f"Saved line plot -> {out_png}")

#     print("Done. All metrics processed.")

# if __name__ == "__main__":
#     main()

 

# import os
# import re
# import glob
# import argparse
# import numpy as np
# import pandas as pd
# import matplotlib.pyplot as plt

# NETWORK_LABELS_15 = [
#     "DMN","Vis","FP","DAN","VAN","Sal","CO","SMd","SMl",
#     "Aud","Tpole","MTL","PMN","PON","SCAN"
# ]

# def parse_txt_file(txt_path, metric, ref_min, subjects_filter):
#     """
#     Parses a .txt file if it matches the pattern:
#       <metric>_<ExpMin>min_with_<RefMin>min.txt
#     Returns a list of dict rows: each row = {
#         'Subject': subjectID (parsed from path or None),
#         'ExpMin': int,
#         'Network': str,
#         'Value': float
#     } 
#     If the path doesn't match or subject doesn't match, returns empty list.
#     """
#     base = os.path.basename(txt_path)
#     # Check if it starts with the metric name
#     if not base.startswith(metric + "_"):
#         return []

#     # Check if the filename has "_<ExpMin>min_with_<RefMin>min"
#     mm = re.search(r"_(\d+)min_with_(\d+)min", base)
#     if not mm:
#         return []
#     exp_min_num = int(mm.group(1))
#     ref_min_num = int(mm.group(2))
#     if ref_min_num != ref_min:
#         return []  # skip if it's not the desired ref_min

#     # Attempt to parse the subject ID from the path (sub-XXXX). If none found, subject=None
#     # Then filter by the user-supplied subjects_filter (if non-empty).
#     # We'll pick the first sub-XXXX we see, if any.
#     subj_match = re.search(r"sub-([A-Za-z0-9]+)", txt_path)
#     subject_found = subj_match.group(1) if subj_match else None

#     # If user provided a non-empty list of subjects, skip if subject_found not in that list
#     if subjects_filter:
#         if subject_found not in subjects_filter:
#             return []

#     # If user has an empty subject list => accept everything
#     # or if subject is found in the user list => proceed

#     # Load the numeric data
#     arr = np.loadtxt(txt_path, ndmin=2)
#     # arr shape => (#rows, #cols)
#     # Typically these .txt files are Nx1 => 15 rows for each network or 1 row for "whole"
#     rows, cols = arr.shape
#     if cols == 0:
#         return []

#     out_data = []
#     for r in range(rows):
#         val = arr[r,0]  # first column
#         if rows == 15:
#             # map r => network label
#             net = NETWORK_LABELS_15[r] if r < len(NETWORK_LABELS_15) else f"row{r}"
#         elif rows == 1:
#             net = "(whole-or-1row)"
#         else:
#             net = f"row{r}"

#         out_data.append({
#             "Subject": subject_found,
#             "ExpMin": exp_min_num,
#             "Network": net,
#             "Value": val
#         })
#     return out_data

# def gather_data_for_folder(folder, metric, ref_min, exp_minutes, subjects_filter):
#     """
#     Scans 'folder' (recursively) for all .txt that match pattern:
#        <metric>_<ExpMin>min_with_<ref_min>min.txt
#     plus subject filtering.
#     Returns a DataFrame with columns [Subject, ExpMin, Network, Value].
#     Only keeps rows for ExpMin in exp_minutes, if exp_minutes is non-empty.
#     """
#     # We can do a recursive glob to catch possible deeper subfolders
#     # or just do a non-recursive if your structure is consistent:
#     all_txts = glob.glob(os.path.join(folder, "**", "*.txt"), recursive=True)

#     data_rows = []
#     for txt_file in all_txts:
#         parsed = parse_txt_file(txt_file, metric, ref_min, subjects_filter)
#         data_rows.extend(parsed)

#     df = pd.DataFrame(data_rows)
#     if df.empty:
#         return df

#     if exp_minutes:
#         df = df[df["ExpMin"].isin(exp_minutes)]
#     return df

# def main():
#     parser = argparse.ArgumentParser()
#     parser.add_argument("--folders", nargs="+", required=True,
#         help="List of folder paths. Each folder => one line on the plot.")
#     parser.add_argument("--labels", nargs="+", required=True,
#         help="List of labels for each folder (same order).")
#     parser.add_argument("--subjects", nargs="*", default=[],
#         help="Optional. If provided, only files whose paths contain 'sub-<ID>' matching these are included.")
#     parser.add_argument("--metric", nargs="+", required=True,
#         help="One or more metric names, e.g. PPV_whole or cDC_whole, etc.")
#     parser.add_argument("--ref_min", type=int, default=70,
#         help="Reference minute used in the filename pattern (_Xmin_with_<ref_min>min).")
#     parser.add_argument("--exp_minutes", type=int, nargs="*", default=[],
#         help="Which ExpMin to keep (subset). If empty, keep all found.")
#     parser.add_argument("--output_dir", default="line_plots",
#         help="Where to save the output figures.")
#     args = parser.parse_args()

#     # Basic checks
#     if len(args.folders) != len(args.labels):
#         raise ValueError("Number of --folders must match number of --labels.")

#     os.makedirs(args.output_dir, exist_ok=True)

#     # We will loop over each metric. For each metric => gather data from each folder => store in a big structure
#     # Then we plot one figure per network, with multiple lines (one per folder).
#     for met in args.metric:
#         print(f"\n=== Processing metric: {met} ===")
#         # Gather data from all folders
#         # We'll build a list-of-DataFrame, then add a column "LineLabel"
#         combined = []
#         for folder, label in zip(args.folders, args.labels):
#             df_folder = gather_data_for_folder(
#                 folder=folder,
#                 metric=met,
#                 ref_min=args.ref_min,
#                 exp_minutes=args.exp_minutes,
#                 subjects_filter=args.subjects
#             )
#             if df_folder.empty:
#                 print(f"  [WARNING] No data found in '{folder}' for metric={met} ref_min={args.ref_min}")
#                 continue
#             df_folder["LineLabel"] = label
#             combined.append(df_folder)

#         if not combined:
#             print("No data across all folders for this metric. Skipping to next metric.")
#             continue

#         bigDF = pd.concat(combined, ignore_index=True)
#         # bigDF has columns [Subject, ExpMin, Network, Value, LineLabel]

#         # We'll create one line-plot per network
#         networks = sorted(bigDF["Network"].unique(), key=lambda x: NETWORK_LABELS_15.index(x) if x in NETWORK_LABELS_15 else 999)
#         # This attempts to keep the standard 15 in order, then anything else after.

#         for net in networks:
#             sub_net = bigDF[bigDF["Network"]==net]
#             if sub_net.empty:
#                 continue

#             # We'll do a groupby by [LineLabel, ExpMin, Subject], then average or so. Actually we want mean±std across subjects, so:
#             # group by line label, then ExpMin, then gather all subjects => mean, std
#             # but we already have subject in the DF, so let's do a simpler approach:
#             # groupby [LineLabel, ExpMin, Subject]. There's only 1 row per subject in that grouping => so we can do .mean()
#             # Then we do groupby [LineLabel, ExpMin] => mean => that is the mean across subjects, and .std() => stdev across subjects.
#             # We'll rename them properly.

#             # 1) reduce to one row per (LineLabel, ExpMin, Subject) if duplicates exist:
#             sub_net_g1 = sub_net.groupby(["LineLabel","ExpMin","Subject"])["Value"].mean().reset_index()
#             # 2) now groupby (LineLabel, ExpMin) => get mean, std across Subject
#             stats = sub_net_g1.groupby(["LineLabel","ExpMin"])["Value"].agg(["mean","std"]).reset_index()
#             # => columns: [LineLabel, ExpMin, mean, std]

#             # We'll pivot that so we can quickly plot line by line or just do it in loops
#             fig, ax = plt.subplots()
#             # We'll loop over each lineLabel
#             for line_label in stats["LineLabel"].unique():
#                 sub_line = stats[stats["LineLabel"]==line_label].copy()
#                 xvals = sub_line["ExpMin"].values
#                 yvals = sub_line["mean"].values
#                 yerr = sub_line["std"].values
#                 ax.errorbar(xvals, yvals, yerr=yerr, label=line_label)

#             ax.set_title(f"{net} (Metric={met}, RefMin={args.ref_min})")
#             ax.set_xlabel("ExpMin")
#             ax.set_ylabel("Value")
#             ax.legend()
#             out_png = os.path.join(args.output_dir, f"{met}_{net}_lineplot.png")
#             plt.savefig(out_png, dpi=150)
#             plt.close()
#             print(f"Saved line plot -> {out_png}")

#     print("Done. All metrics processed.")

# if __name__ == "__main__":
#     main()