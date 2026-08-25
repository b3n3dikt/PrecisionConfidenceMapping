import os
import numpy as np
import matplotlib.pyplot as plt
import argparse
import pickle
import csv

def load_data(filepath):
    """Load data from a text file."""
    try:
        data = np.loadtxt(filepath, delimiter=',')
        return data
    except Exception as e:
        print(f"Failed to load data from {filepath}. Error: {e}")
        return None

def save_exp_data(exp_data, save_path):
    """Save experimental data to a pickle file and a CSV file."""
    # Save the pickle file
    with open(save_path, 'wb') as f:
        pickle.dump(exp_data, f)
    print(f"Saved experimental data to {save_path}")

    # Save a CSV file for easier inspection
    csv_path = save_path.replace('.pkl', '.csv')
    with open(csv_path, 'w', newline='') as csvfile:
        csvwriter = csv.writer(csvfile)
        # Write the header row
        csvwriter.writerow(['ExpTime', 'Network', 'Metric', 'Value'])

        # Iterate over the data to write rows
        for exp_time, networks in exp_data.items():
            for network, metrics in networks.items():
                for metric, value in metrics.items():
                    csvwriter.writerow([exp_time, network, metric, value])
    print(f"Saved experimental data summary to {csv_path}")
# def save_exp_data(exp_data, save_path):
#     """Save experimental data to a pickle file."""
#     with open(save_path, 'wb') as f:
#         pickle.dump(exp_data, f)
#     print(f"Saved experimental data to {save_path}")

def load_exp_data(load_path):
    """Load experimental data from a pickle file."""
    with open(load_path, 'rb') as f:
        exp_data = pickle.load(f)
    print(f"Loaded experimental data from {load_path}")
    return exp_data

def main(base_dir, fig_dir, data_prefix, ref_data, thresholds, conf_map=False, exp_bins=None, save_path=None, load_path=None):
    if load_path:
        exp_data = load_exp_data(load_path)
    else:
        exp_data = {}

        # Ensure the correct directory naming
        exp_time_dirs = []
        if exp_bins:
            for bin_name in exp_bins:
                matched_dir = f"{bin_name}_to_{ref_data}" if "_to_" not in bin_name else bin_name
                full_path = os.path.join(fig_dir, matched_dir)
                if os.path.isdir(full_path):
                    exp_time_dirs.append(matched_dir)
                else:
                    print(f"Directory not found: {full_path}")
        else:
            exp_time_dirs = [
                d for d in os.listdir(fig_dir)
                if d.startswith(data_prefix) and f"to_{ref_data}" in d
            ]

        if not exp_time_dirs:
            print(f"No matching directories found in {fig_dir}.")
            return

        # Process data for the filtered directories
        for dir_name in exp_time_dirs:
            exp_time = dir_name.split('_to_')[0]
            exp_data[exp_time] = {}

            for threshold in thresholds:
                if conf_map:
                    network_dirs = [
                        d for d in os.listdir(os.path.join(fig_dir, dir_name))
                        if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d
                    ]
                    for network_dir in network_dirs:
                        network_name = network_dir.split('-thresh-')[0]
                        metrics_files = [
                            'Average_DiceCoefficient', 'Average_continuousDiceCoefficient',
                            'FalseNegative', 'FalsePositive', 'NPV', 'PPV',
                            'TrueNegative', 'TruePositive'
                        ]

                        for metric in metrics_files:
                            for region in ['cortical', 'subcortical', 'whole']:
                                file_name = f'{metric}_{region}.txt'
                                file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

                                if os.path.exists(file_path):
                                    data = load_data(file_path)
                                    if data is not None:
                                        if network_name not in exp_data[exp_time]:
                                            exp_data[exp_time][network_name] = {}
                                        exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()
                                else:
                                    print(f"File not found: {file_path}")
                else:
                    combined_folder = f"All-thresh-{threshold}"
                    folder_path = os.path.join(fig_dir, dir_name, combined_folder)

                    if os.path.exists(folder_path):
                        for metric in [
                            'Average_DiceCoefficient', 'Average_continuousDiceCoefficient',
                            'FalseNegative', 'FalsePositive', 'NPV', 'PPV',
                            'TrueNegative', 'TruePositive'
                        ]:
                            for region in ['cortical', 'subcortical', 'whole']:
                                file_name = f'{metric}_{region}.txt'
                                file_path = os.path.join(folder_path, file_name)

                                if os.path.exists(file_path):
                                    data = load_data(file_path)
                                    if data is not None:
                                        for i, net in enumerate([
                                            'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO',
                                            'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'
                                        ]):
                                            if exp_time not in exp_data:
                                                exp_data[exp_time] = {}
                                            if net not in exp_data[exp_time]:
                                                exp_data[exp_time][net] = {}
                                            exp_data[exp_time][net][f'{metric}_{region}_thresh_{threshold}'] = data[i]
                                else:
                                    print(f"File not found: {file_path}")

        if save_path:
            save_exp_data(exp_data, save_path)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
    parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
    parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
    parser.add_argument('data_prefix', type=str, help="The prefix for the data folders, e.g., 'ExpData-' or 'RefData-'.")
    parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
    parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
    parser.add_argument('--ConfMap', action='store_true', help="Use ConfMap mode.")
    parser.add_argument('--exp_bins', type=str, nargs='*', help="Specific ExpData-* bins to process.")
    parser.add_argument('--save_path', type=str, help="Path to save the experimental data.")
    parser.add_argument('--load_path', type=str, help="Path to load previously saved experimental data.")
    args = parser.parse_args()

    main(args.base_dir, args.fig_dir, args.data_prefix, args.ref_data, args.thresholds, args.ConfMap, args.exp_bins, args.save_path, args.load_path)