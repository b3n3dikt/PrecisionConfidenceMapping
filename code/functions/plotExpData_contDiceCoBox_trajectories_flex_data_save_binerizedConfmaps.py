#!/usr/bin/env python3
import os
import numpy as np
import argparse
import pickle
import csv
import re

NETWORK_ORDER = [
    'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO',
    'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'
]

# List of special files that apply to all networks
SPECIAL_METRICS = [
    "Average_muI_whole", "STDEV_muI_whole", "muI_Matrix_whole",
    "Average_VIn_whole", "STDEV_VIn_whole", "VIn_Matrix_whole",
    "Average_MIn_whole", "STDEV_MIn_whole", "MIn_Matrix_whole",
    "Average_muI_cortical", "STDEV_muI_cortical", "muI_Matrix_cortical",
    "Average_VIn_cortical", "STDEV_VIn_cortical", "VIn_Matrix_cortical",
    "Average_MIn_cortical", "STDEV_MIn_cortical", "MIn_Matrix_cortical",
    "Average_muI_subcortical", "STDEV_muI_subcortical", "muI_Matrix_subcortical",
    "Average_VIn_subcortical", "STDEV_VIn_subcortical", "VIn_Matrix_subcortical",
    "Average_MIn_subcortical", "STDEV_MIn_subcortical", "MIn_Matrix_subcortical"
]

def load_data(filepath):
    """
    Load data from a text file containing multiple rows, each with a single float.
    Returns a 1D numpy array or None if there's an error.
    """
    try:
        data = np.loadtxt(filepath, delimiter=',')  # delimiter=',' in case
        if data.ndim == 0:
            # Means only one value in file, convert to an array of length 1
            data = np.array([data])
        elif data.ndim > 1:
            # Means file has more than one column
            data = data[:, 0]  # Just take the first column or handle otherwise
        return data
    except Exception as e:
        print(f"Failed to load data from {filepath}. Error: {e}")
        return None

def save_exp_data(exp_data, save_path):
    """
    Save experimental data to a pickle file and a CSV file.
    Row format in CSV: [ExpTime, Network, Metric, Value]
    """
    # Save a pickle file (dictionary)
    with open(save_path, 'wb') as f:
        pickle.dump(exp_data, f)
    print(f"Saved experimental data to {save_path}")

    # Save a CSV file
    csv_path = save_path.replace('.pkl', '.csv')
    with open(csv_path, 'w', newline='') as csvfile:
        csvwriter = csv.writer(csvfile)
        csvwriter.writerow(['ExpTime', 'Network', 'Metric', 'Value'])

        for exp_time, networks in exp_data.items():
            for network_name, metrics_dict in networks.items():
                for metric_name, value in metrics_dict.items():
                    csvwriter.writerow([exp_time, network_name, metric_name, value])
    print(f"Saved experimental data summary to {csv_path}")

def load_exp_data(load_path):
    """Load experimental data from a pickle file."""
    with open(load_path, 'rb') as f:
        exp_data = pickle.load(f)
    print(f"Loaded experimental data from {load_path}")
    return exp_data

def parse_threshold_from_path(path):
    """
    Given a directory name like 'Figures_BootstrapExp2StandardRef_Threshold-0.1',
    return '0.1' as the threshold (a string).
    If not found, return None.
    """
    match = re.search(r'Threshold-([\d\.]+)$', path)
    return match.group(1) if match else None

def parse_exp_time(dir_name):
    """
    Given something like 'ExpData-10m_to_RefData-70m',
    parse out 'ExpData-10m'.
    """
    return dir_name.split('_to_')[0] if '_to_' in dir_name else dir_name

def main():
    parser = argparse.ArgumentParser(description="Process new dice coefficient data with multi-network text files.")
    parser.add_argument('base_dir', type=str, help="Base directory containing the outdirname.")
    parser.add_argument('--save_path', type=str, help="Path to save the final data. Defaults to 'exp_data_new.pkl' in base_dir.")
    parser.add_argument('--load_path', type=str, help="Optional path to load an existing pkl data file (skips processing).")
    args = parser.parse_args()

    base_dir = args.base_dir
    load_path = args.load_path
    save_path = args.save_path

    if not save_path:
        save_path = os.path.join(base_dir, "exp_data_new.pkl")

    if load_path:
        exp_data = load_exp_data(load_path)
        print("No new processing done, loaded existing data.")
        return

    exp_data = {}

    # 1) List all directories matching 'Figures_BootstrapExp2StandardRef_Threshold-*'
    top_dirs = [
        d for d in os.listdir(base_dir)
        if os.path.isdir(os.path.join(base_dir, d)) and 'Threshold-' in d
    ]

    for tdir in top_dirs:
        tdir_full = os.path.join(base_dir, tdir)
        threshold_str = parse_threshold_from_path(tdir)
        if threshold_str is None:
            print(f"Skipping {tdir}: could not parse threshold.")
            continue

        # 2) Find subfolders like 'ExpData-XXm_to_RefData-YYm'
        exp_time_dirs = [
            d for d in os.listdir(tdir_full)
            if os.path.isdir(os.path.join(tdir_full, d)) and '_to_' in d
        ]

        for etdir in exp_time_dirs:
            etdir_full = os.path.join(tdir_full, etdir)
            exp_time = parse_exp_time(etdir)

            if exp_time not in exp_data:
                exp_data[exp_time] = {}

            # 3) Find folders containing metric text files
            subfolders = [
                d for d in os.listdir(etdir_full)
                if os.path.isdir(os.path.join(etdir_full, d))
            ]

            for sf in subfolders:
                sf_full = os.path.join(etdir_full, sf)

                txt_files = [
                    f for f in os.listdir(sf_full)
                    if f.endswith('.txt')
                ]

                for txtf in txt_files:
                    file_path = os.path.join(sf_full, txtf)
                    data = load_data(file_path)
                    if data is None:
                        continue

                    base_name = txtf.replace('.txt', '')
                    parts = base_name.split('_')

                    metric_name = '_'.join(parts[:-1]) if len(parts) >= 2 else base_name
                    region = parts[-1] if len(parts) >= 2 else 'unknown'

                    final_metric_key = f"{metric_name}_{region}_thresh_{threshold_str}"

                    # Check if the file belongs to the "whole" or "cortical/subcortical" category
                    if any(metric in base_name for metric in SPECIAL_METRICS):
                        network_name = "All"  # These metrics apply to all networks as a whole
                        if network_name not in exp_data[exp_time]:
                            exp_data[exp_time][network_name] = {}
                        exp_data[exp_time][network_name][final_metric_key] = data.item() if data.size == 1 else data
                    else:
                        # Standard case: Assign per-network
                        if data.size < len(NETWORK_ORDER):
                            print(f"File {file_path} has only {data.size} rows, expected {len(NETWORK_ORDER)}. Skipping file.")
                            continue

                        for i, net in enumerate(NETWORK_ORDER):
                            if net not in exp_data[exp_time]:
                                exp_data[exp_time][net] = {}
                            exp_data[exp_time][net][final_metric_key] = data[i]

    # Finally, save results
    save_exp_data(exp_data, save_path)

if __name__ == '__main__':
    main()


# #!/usr/bin/env python3
# import os
# import numpy as np
# import argparse
# import pickle
# import csv
# import re

# NETWORK_ORDER = [
#     'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO',
#     'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'
# ]

# def load_data(filepath):
#     """
#     Load data from a text file containing multiple rows, each with a single float.
#     Returns a 1D numpy array or None if there's an error.
#     """
#     try:
#         data = np.loadtxt(filepath, delimiter=',')  # delimiter=',' in case
#         if data.ndim == 0:
#             # Means only one value in file, convert to an array of length 1
#             data = np.array([data])
#         elif data.ndim > 1:
#             # Means file has more than one column
#             data = data[:,0]  # Just take the first column or handle otherwise
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def save_exp_data(exp_data, save_path):
#     """
#     Save experimental data to a pickle file and a CSV file.
#     Row format in CSV: [ExpTime, Network, Metric, Value]
#     """
#     # Save a pickle file (dictionary)
#     with open(save_path, 'wb') as f:
#         pickle.dump(exp_data, f)
#     print(f"Saved experimental data to {save_path}")

#     # Save a CSV file
#     csv_path = save_path.replace('.pkl', '.csv')
#     with open(csv_path, 'w', newline='') as csvfile:
#         csvwriter = csv.writer(csvfile)
#         csvwriter.writerow(['ExpTime', 'Network', 'Metric', 'Value'])

#         for exp_time, networks in exp_data.items():
#             for network_name, metrics_dict in networks.items():
#                 for metric_name, value in metrics_dict.items():
#                     csvwriter.writerow([exp_time, network_name, metric_name, value])
#     print(f"Saved experimental data summary to {csv_path}")

# def load_exp_data(load_path):
#     """Load experimental data from a pickle file."""
#     with open(load_path, 'rb') as f:
#         exp_data = pickle.load(f)
#     print(f"Loaded experimental data from {load_path}")
#     return exp_data

# def parse_threshold_from_path(path):
#     """
#     Given a directory name like 'Figures_BootstrapExp2StandardRef_Threshold-0.1',
#     return '0.1' as the threshold (a string).
#     If not found, return None.
#     """
#     # Regex to match something like '-0.1' or '-0.9' or '-0.99'
#     match = re.search(r'Threshold-([\d\.]+)$', path)
#     if match:
#         return match.group(1)
#     else:
#         return None

# def parse_exp_time(dir_name):
#     """
#     Given something like 'ExpData-10m_to_RefData-70m',
#     parse out 'ExpData-10m'.
#     """
#     if '_to_' in dir_name:
#         return dir_name.split('_to_')[0]
#     return dir_name

# def main():
#     parser = argparse.ArgumentParser(description="Process new dice coefficient data with multi-network text files.")
#     parser.add_argument('base_dir', type=str, help="Base directory containing the outdirname.")
#     parser.add_argument('--save_path', type=str, help="Path to save the final data. Defaults to 'exp_data_new.pkl' in base_dir.")
#     parser.add_argument('--load_path', type=str, help="Optional path to load an existing pkl data file (skips processing).")
#     args = parser.parse_args()

#     base_dir = args.base_dir
#     load_path = args.load_path
#     save_path = args.save_path

#     if not save_path:
#         save_path = os.path.join(base_dir, "exp_data_new.pkl")

#     if load_path:
#         # If user wants to just load an existing data file
#         exp_data = load_exp_data(load_path)
#         print("No new processing done, loaded existing data.")
#         return

#     # Create an empty dictionary to hold results
#     exp_data = {}

#     # 1) List all directories in base_dir that match the pattern 'Figures_BootstrapExp2StandardRef_Threshold-*'
#     top_dirs = [
#         d for d in os.listdir(base_dir)
#         if os.path.isdir(os.path.join(base_dir, d)) and 'Threshold-' in d
#     ]
#     # Example: ['Figures_BootstrapExp2StandardRef_Threshold-0.1', 'Figures_BootstrapExp2StandardRef_Threshold-0.2', ...]

#     for tdir in top_dirs:
#         tdir_full = os.path.join(base_dir, tdir)
#         threshold_str = parse_threshold_from_path(tdir)
#         if threshold_str is None:
#             print(f"Skipping {tdir}: could not parse threshold.")
#             continue

#         # 2) Inside each threshold directory, find subfolders like 'ExpData-XXm_to_RefData-YYm'
#         exp_time_dirs = [
#             d for d in os.listdir(tdir_full)
#             if os.path.isdir(os.path.join(tdir_full, d)) and '_to_' in d
#         ]
#         # e.g. ['ExpData-10m_to_RefData-70m', 'ExpData-5m_to_RefData-70m', ...]

#         for etdir in exp_time_dirs:
#             etdir_full = os.path.join(tdir_full, etdir)
#             exp_time = parse_exp_time(etdir)  # e.g. 'ExpData-10m'

#             # We store all data for that exp_time in a subdict
#             if exp_time not in exp_data:
#                 exp_data[exp_time] = {}

#             # 3) There's presumably an 'All-thresh-0' folder here
#             #    or something similar that actually holds the text files
#             subfolders = [
#                 d for d in os.listdir(etdir_full)
#                 if os.path.isdir(os.path.join(etdir_full, d))
#             ]
#             # Typically we expect e.g. 'All-thresh-0'
#             # If there are multiple, we can parse them all; often there's just one
#             for sf in subfolders:
#                 sf_full = os.path.join(etdir_full, sf)
#                 # 4) In that folder, we have text files like:
#                 #    'Average_continuousDiceCoefficient_cortical.txt'
#                 #    containing 15 rows => DMN..SCAN
#                 txt_files = [
#                     f for f in os.listdir(sf_full)
#                     if f.endswith('.txt')
#                 ]
#                 # Example metric files
#                 # We'll parse them similarly to your old code
#                 for txtf in txt_files:
#                     file_path = os.path.join(sf_full, txtf)
#                     data = load_data(file_path)
#                     if data is None:
#                         continue
#                     # data is a 1D array of length 15 in the known network order

#                     # Parse metric & region from the filename
#                     # e.g. 'Average_continuousDiceCoefficient_cortical.txt'
#                     # We'll split by underscore:
#                     #   -> ['Average','continuousDiceCoefficient','cortical.txt']
#                     #   metric => 'Average_continuousDiceCoefficient'
#                     #   region => 'cortical'
#                     base_name = txtf.replace('.txt','')
#                     parts = base_name.split('_')  # e.g. 3 or 2 parts
#                     if len(parts) >= 2:
#                         metric_name = '_'.join(parts[:-1])  # all but last
#                         region = parts[-1]
#                     else:
#                         # fallback if weird naming
#                         metric_name = base_name
#                         region = 'unknown'

#                     # We'll incorporate threshold into the metric key
#                     # e.g. 'Average_continuousDiceCoefficient_cortical_thresh_0.1'
#                     final_metric_key = f"{metric_name}_{region}_thresh_{threshold_str}"

#                     if data.size < 15:
#                         print(f"File {file_path} has only {data.size} rows, expected 15. Skipping file.")
#                         continue  # Skip this file entirely

#                     # Assign values to networks
#                     for i, net in enumerate(NETWORK_ORDER):
#                         if net not in exp_data[exp_time]:
#                             exp_data[exp_time][net] = {}
#                         # Safely assign data[i]
#                         exp_data[exp_time][net][final_metric_key] = data[i]

#     # Finally, save results
#     save_exp_data(exp_data, save_path)

# if __name__ == '__main__':
#     main()