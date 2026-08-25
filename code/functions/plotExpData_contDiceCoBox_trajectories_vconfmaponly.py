import os
import numpy as np
import matplotlib.pyplot as plt
import argparse

def load_data(filepath):
    """Load data from a text file."""
    try:
        data = np.loadtxt(filepath, delimiter=',')
        print(f"Loaded data from {filepath} successfully.")
        return data
    except Exception as e:
        print(f"Failed to load data from {filepath}. Error: {e}")
        return None

# Define the color map for networks
color_map = {
    'Aud': '#c783fe',   # Purple
    'DMN': '#d62728',   # Red
    'PMN': '#0846fa',   # Blue
    'SMd': '#7ef8fe',   # Cyan
    'VAN': '#3497ac',   # Teal
    'CO': '#70319f',    # Orange
    'FP': '#e9e82a',    # Yellow
    'PON': '#07f5e1',   # White (adjust as needed)
    'SMl': '#ff9828',   # Orange
    'Vis': '#2a28ad',   # Blue
    'DAN': '#2acd27',   # Green
    'MTL': '#7cfe7c',   # Yellowish-green
    'Sal': '#000000',   # Black
    'Tpole': '#025289', # Navy
    'SCAN': '#800080'   # Purple (as per your second image)
}

def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8', summary_only=False):
    networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
                'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
    exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
    network_data = {net: [] for net in networks}

    # Organize data by network
    for time in exp_times:
        for net in networks:
            if net in exp_data[time]:
                if coefficient_type in exp_data[time][net]:
                    network_data[net].append(exp_data[time][net][coefficient_type])
                else:
                    network_data[net].append(np.nan)
            else:
                network_data[net].append(np.nan)

    # Determine ylim based on the maximum data value
    all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
    max_value = max(all_values) if all_values else 1
    if max_value <= 1:
        ylim = (0, 1)
    else:
        # Round up to the nearest power of 10
        ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

    # Plot data
    if not summary_only:
        for net in networks:
            data = network_data[net]
            x_positions = list(range(len(data)))

            if plot_type == 'bar':
                plt.figure()
                plt.bar(x_positions, data, color=color_map.get(net, 'grey'), capsize=5)
                plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
                plt.xlabel('Exploratory Time Bins')
                plt.ylabel(coefficient_type)
                plt.xticks(x_positions, exp_times, rotation=45)
                plt.ylim(ylim)
                plt.tight_layout()
                plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
                plt.close()
            elif plot_type == 'line' and net == networks[0]:
                plt.figure(figsize=(10, 5))

    if plot_type == 'line':
        for net in networks:
            data = network_data[net]
            x_positions = list(range(len(data)))
            plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
        
        plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
        plt.xlabel('Experimental Time Bins')
        plt.ylabel(coefficient_type)
        plt.xticks(x_positions, exp_times, rotation=45)
        plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
        plt.ylim(ylim)
        plt.tight_layout()
        plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
        plt.close()

def main(base_dir, fig_dir, ref_data, thresholds, summary_only=False):
    exp_data = {}
    print(f"Checking in figure directory: {fig_dir}")
    # Loop through directories and load data
    for dir_name in os.listdir(fig_dir):
        if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
            exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
            exp_data[exp_time] = {}

            for threshold in thresholds:
                network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
                for network_dir in network_dirs:
                    network_name = network_dir.split('-thresh-')[0]

                    # File paths for various metrics
                    metrics_files = [
                        'Average_DiceCoefficient',
                        'Average_continuousDiceCoefficient',
                        'FalseNegative',
                        'FalsePositive',
                        'NPV',
                        'PPV',
                        'TrueNegative',
                        'TruePositive'
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
                                    exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
                            else:
                                print(f"File not found for {dir_name}. Checked path: {file_path}")

    if exp_data:
        print("Data loaded for times:", exp_data.keys())
        for threshold in thresholds:
            for metric in metrics_files:
                for region in ['cortical', 'subcortical', 'whole']:
                    coefficient_type = f'{metric}_{region}_thresh_{threshold}'
                    plot_data(exp_data, fig_dir, 'line', coefficient_type, threshold, summary_only)
                    if not summary_only:
                        plot_data(exp_data, fig_dir, 'bar', coefficient_type, threshold, summary_only)
    else:
        print("No data loaded. Please check directory paths and file existence.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
    parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
    parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
    parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
    parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
    parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
    args = parser.parse_args()

    main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.summary_only)
### Works but ylim is hard coded to 0-1 so doesn't work for PPV etc. 
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse


# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None


# # Define the color map for networks
# color_map = {
#     'Aud': '#c783fe',   # Purple
#     'DMN': '#d62728',   # Red
#     'PMN': '#0846fa',   # Blue
#     'SMd': '#7ef8fe',   # Cyan
#     'VAN': '#3497ac',   # Teal
#     'CO': '#70319f',    # Orange
#     'FP': '#e9e82a',    # Yellow
#     'PON': '#07f5e1',   # White (adjust as needed)
#     'SMl': '#ff9828',   # Orange
#     'Vis': '#2a28ad',   # Blue
#     'DAN': '#2acd27',   # Green
#     'MTL': '#7cfe7c',   # Yellowish-green
#     'Sal': '#000000',   # Black
#     'Tpole': '#025289', # Navy
#     'SCAN': '#800080'   # Purple (as per your second image)
# }

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8', summary_only=False):
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     if not summary_only:
#         for net in networks:
#             data = network_data[net]
#             x_positions = list(range(len(data)))

#             if plot_type == 'bar':
#                 plt.figure()
#                 plt.bar(x_positions, data, color=color_map.get(net, 'grey'), capsize=5)
#                 plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#                 plt.xlabel('Exploratory Time Bins')
#                 plt.ylabel(coefficient_type)
#                 plt.xticks(x_positions, exp_times, rotation=45)
#                 plt.ylim(0, 1)
#                 plt.tight_layout()
#                 plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#                 plt.close()
#             elif plot_type == 'line' and net == networks[0]:
#                 plt.figure(figsize=(10, 5))
        
#     if plot_type == 'line':
#         for net in networks:
#             data = network_data[net]
#             x_positions = list(range(len(data)))
#             plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
        
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data, thresholds, summary_only=False):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     # File paths for various metrics
#                     metrics_files = [
#                         'Average_DiceCoefficient',
#                         'Average_continuousDiceCoefficient',
#                         'FalseNegative',
#                         'FalsePositive',
#                         'NPV',
#                         'PPV',
#                         'TrueNegative',
#                         'TruePositive'
#                     ]

#                     for metric in metrics_files:
#                         for region in ['cortical', 'subcortical', 'whole']:
#                             file_name = f'{metric}_{region}.txt'
#                             file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                             if os.path.exists(file_path):
#                                 data = load_data(file_path)
#                                 if data is not None:
#                                     if network_name not in exp_data[exp_time]:
#                                         exp_data[exp_time][network_name] = {}
#                                     exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                             else:
#                                 print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for metric in metrics_files:
#                 for region in ['cortical', 'subcortical', 'whole']:
#                     coefficient_type = f'{metric}_{region}_thresh_{threshold}'
#                     plot_data(exp_data, fig_dir, 'line', coefficient_type, threshold, summary_only)
#                     if not summary_only:
#                         plot_data(exp_data, fig_dir, 'bar', coefficient_type, threshold, summary_only)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.summary_only)

#example python3 plotExpData_contDiceCoBox_trajectories.py /path/to/base_dir /path/to/fig_dir RefData-70m 0.5 0.8 --summary_only

# ## Works but doesn't have option to only do summary figs
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse


# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None


# # Define the color map for networks
# color_map = {
#     'Aud': '#9467bd',   # Purple
#     'DMN': '#d62728',   # Red
#     'PMN': '#1f77b4',   # Blue
#     'Smd': '#17becf',   # Cyan
#     'VAN': '#2ca02c',   # Teal
#     'CO': '#ff7f0e',    # Orange
#     'FP': '#ffbb78',    # Yellow
#     'PON': '#ffbb78',   # White (adjust as needed)
#     'SMI': '#ff7f0e',   # Orange
#     'Vis': '#1f77b4',   # Blue
#     'DAN': '#2ca02c',   # Green
#     'MTL': '#bcbd22',   # Yellowish-green
#     'Sal': '#000000',   # Black
#     'Tpole': '#1f77b4', # Navy
#     'SCAN': '#800080'   # Purple (as per your second image)
# }

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8'):
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'Smd', 'SMI', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, data, color=color_map.get(net, 'grey'), capsize=5)
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data, thresholds):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     # File paths for various metrics
#                     metrics_files = [
#                         'Average_DiceCoefficient',
#                         'Average_continuousDiceCoefficient',
#                         'FalseNegative',
#                         'FalsePositive',
#                         'NPV',
#                         'PPV',
#                         'TrueNegative',
#                         'TruePositive'
#                     ]

#                     for metric in metrics_files:
#                         for region in ['cortical', 'subcortical', 'whole']:
#                             file_name = f'{metric}_{region}.txt'
#                             file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                             if os.path.exists(file_path):
#                                 data = load_data(file_path)
#                                 if data is not None:
#                                     if network_name not in exp_data[exp_time]:
#                                         exp_data[exp_time][network_name] = {}
#                                     exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                             else:
#                                 print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for plot_type in ['bar', 'line']:
#                 for metric in metrics_files:
#                     for region in ['cortical', 'subcortical', 'whole']:
#                         coefficient_type = f'{metric}_{region}_thresh_{threshold}'
#                         plot_data(exp_data, fig_dir, plot_type, coefficient_type, threshold)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds)


## Works but wrong colors

# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse


# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [x for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [x for x in data]
#             plt.plot(x_positions, means, label=net, marker='o')
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data, thresholds):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     # File paths for various metrics
#                     metrics_files = [
#                         'Average_DiceCoefficient',
#                         'Average_continuousDiceCoefficient',
#                         'FalseNegative',
#                         'FalsePositive',
#                         'NPV',
#                         'PPV',
#                         'TrueNegative',
#                         'TruePositive'
#                     ]

#                     for metric in metrics_files:
#                         for region in ['cortical', 'subcortical', 'whole']:
#                             file_name = f'{metric}_{region}.txt'
#                             file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                             if os.path.exists(file_path):
#                                 data = load_data(file_path)
#                                 if data is not None:
#                                     if network_name not in exp_data[exp_time]:
#                                         exp_data[exp_time][network_name] = {}
#                                     exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                             else:
#                                 print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for plot_type in ['bar', 'line']:
#                 for metric in metrics_files:
#                     for region in ['cortical', 'subcortical', 'whole']:
#                         coefficient_type = f'{metric}_{region}_thresh_{threshold}'
#                         plot_data(exp_data, fig_dir, plot_type, coefficient_type, threshold)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds)



#This works but only has some conditions hard coded, and doesn't include the cortical, subcortical and whole brain divisions 
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [x for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [x for x in data]
#             plt.plot(x_positions, means, label=net, marker='o')
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data, thresholds):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     # File paths for various metrics
#                     metrics_files = {
#                         'DiceCoefficient': 'DiceCoefficientsMatrix.txt',
#                         'continuousDiceCoefficient': 'continuousDiceCoefficientsMatrix.txt',
#                         'NegativePredictiveValue': 'NegativePredictiveValue.txt',
#                         'PositivePredictiveValue': 'PositivePredictiveValue.txt'
#                     }

#                     for metric, file_name in metrics_files.items():
#                         file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                         if os.path.exists(file_path):
#                             data = load_data(file_path)
#                             if data is not None:
#                                 if network_name not in exp_data[exp_time]:
#                                     exp_data[exp_time][network_name] = {}
#                                 exp_data[exp_time][network_name][f'{metric}_thresh_{threshold}'] = data.item()  # Assuming single value
#                         else:
#                             print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for plot_type in ['bar', 'line']:
#                 for coefficient_type in [f'DiceCoefficient_thresh_{threshold}', f'continuousDiceCoefficient_thresh_{threshold}', f'NegativePredictiveValue_thresh_{threshold}', f'PositivePredictiveValue_thresh_{threshold}']:
#                     plot_data(exp_data, fig_dir, plot_type, coefficient_type, threshold)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('ref_data', type=str, help="The reference data, e.g., 'RefData-70m'.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds)


# ##Works but no refdata as input    
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [x for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [x for x in data]
#             plt.plot(x_positions, means, label=net, marker='o')
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, thresholds):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     # File paths for various metrics
#                     metrics_files = {
#                         'DiceCoefficient': 'DiceCoefficientsMatrix.txt',
#                         'continuousDiceCoefficient': 'continuousDiceCoefficientsMatrix.txt',
#                         'NegativePredictiveValue': 'NegativePredictiveValue.txt',
#                         'PositivePredictiveValue': 'PostivePredictiveValue.txt'
#                     }


#                     for metric, file_name in metrics_files.items():
#                         file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                         if os.path.exists(file_path):
#                             data = load_data(file_path)
#                             if data is not None:
#                                 if network_name not in exp_data[exp_time]:
#                                     exp_data[exp_time][network_name] = {}
#                                 exp_data[exp_time][network_name][f'{metric}_thresh_{threshold}'] = data.item()  # Assuming single value
#                         else:
#                             print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for plot_type in ['bar', 'line']:
#                 for coefficient_type in [f'DiceCoefficient_thresh_{threshold}', f'continuousDiceCoefficient_thresh_{threshold}', f'NegativePredictiveValue_thresh_{threshold}', f'PositivePredictiveValue_thresh_{threshold}']:
#                     plot_data(exp_data, fig_dir, plot_type, coefficient_type, threshold)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.thresholds)


# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient', threshold='0.8'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [x for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot_thresh_{threshold}.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [x for x in data]
#             plt.plot(x_positions, means, label=net, marker='o')
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins (Thresh: {threshold})')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, thresholds):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                 for network_dir in network_dirs:
#                     network_name = network_dir.split('-thresh-')[0]

#                     matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'DiceCoefficientsMatrix.txt')
#                     cont_matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'continuousDiceCoefficientsMatrix.txt')

#                     print(f"Attempting to load from: {matrix_file} and {cont_matrix_file}")

#                     if os.path.exists(matrix_file):
#                         data = load_data(matrix_file)
#                         if data is not None:
#                             if network_name not in exp_data[exp_time]:
#                                 exp_data[exp_time][network_name] = {}
#                             exp_data[exp_time][network_name][f'DiceCoefficient_thresh_{threshold}'] = data.item()  # Assuming single value
#                     else:
#                         print(f"File not found for {dir_name}. Checked path: {matrix_file}")

#                     if os.path.exists(cont_matrix_file):
#                         cont_data = load_data(cont_matrix_file)
#                         if cont_data is not None:
#                             if network_name not in exp_data[exp_time]:
#                                 exp_data[exp_time][network_name] = {}
#                             exp_data[exp_time][network_name][f'continuousDiceCoefficient_thresh_{threshold}'] = cont_data.item()  # Assuming single value
#                     else:
#                         print(f"File not found for {dir_name}. Checked path: {cont_matrix_file}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for plot_type in ['bar', 'line']:
#                 for coefficient_type in [f'DiceCoefficient_thresh_{threshold}', f'continuousDiceCoefficient_thresh_{threshold}']:
#                     plot_data(exp_data, fig_dir, plot_type, coefficient_type, threshold)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     parser.add_argument('thresholds', type=str, nargs='+', help="List of thresholds to process.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.thresholds)

# ## Works but doesn't incorp thresh
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [x for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [x for x in data]
#             plt.plot(x_positions, means, label=net, marker='o')
#         elif plot_type == 'box':
#             print("Box plot not applicable for this data structure.")

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d))]
#             for network_dir in network_dirs:
#                 network_name = network_dir.split('-thresh-')[0]

#                 matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'DiceCoefficientsMatrix.txt')
#                 cont_matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'continuousDiceCoefficientsMatrix.txt')

#                 print(f"Attempting to load from: {matrix_file} and {cont_matrix_file}")

#                 if os.path.exists(matrix_file):
#                     data = load_data(matrix_file)
#                     if data is not None:
#                         if network_name not in exp_data[exp_time]:
#                             exp_data[exp_time][network_name] = {}
#                         exp_data[exp_time][network_name]['DiceCoefficient'] = data.item()  # Assuming single value
#                 else:
#                     print(f"File not found for {dir_name}. Checked path: {matrix_file}")

#                 if os.path.exists(cont_matrix_file):
#                     cont_data = load_data(cont_matrix_file)
#                     if cont_data is not None:
#                         if network_name not in exp_data[exp_time]:
#                             exp_data[exp_time][network_name] = {}
#                         exp_data[exp_time][network_name]['continuousDiceCoefficient'] = cont_data.item()  # Assuming single value
#                 else:
#                     print(f"File not found for {dir_name}. Checked path: {cont_matrix_file}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for plot_type in ['bar', 'line']:
#             for coefficient_type in ['DiceCoefficient', 'continuousDiceCoefficient']:
#                 plot_data(exp_data, fig_dir, plot_type, coefficient_type)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)

# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar', coefficient_type='DiceCoefficient'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         matrix = exp_data[time]
#         if matrix.ndim == 1:  # Handle 1D array case
#             for idx, net in enumerate(networks):
#                 network_data[net].append(matrix[idx])
#         else:  # Handle 2D array case
#             for idx, net in enumerate(networks):
#                 network_data[net].append(matrix[:, idx])  # Assuming each column corresponds to a network

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [np.mean(x) for x in data]
#             errors = [np.std(x) for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'{coefficient_type} - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [np.mean(x) for x in data]
#             errors = [np.std(x) for x in data]
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
#         elif plot_type == 'box':
#             if matrix.ndim > 1 and matrix.shape[1] > 1:  # Check if there are multiple columns for box plot
#                 plt.figure()
#                 boxplot = plt.boxplot(data, labels=exp_times, patch_artist=True)
#                 plt.title(f'{coefficient_type} - {net}')
#                 plt.xlabel('Exploratory Time Bins')
#                 plt.ylabel(coefficient_type)
#                 plt.xticks(rotation=45)
#                 plt.ylim(0, 1)

#                 # Customize the box plot appearance
#                 for box in boxplot['boxes']:
#                     box.set(color='black', linewidth=1.5)
#                     box.set(facecolor='#4B0082')  # Dark blue-purple color

#                 for whisker in boxplot['whiskers']:
#                     whisker.set(color='black', linewidth=1.5)

#                 for cap in boxplot['caps']:
#                     cap.set(color='black', linewidth=1.5)

#                 for median in boxplot['medians']:
#                     median.set(color='black', linewidth=1.5)

#                 for flier in boxplot['fliers']:
#                     flier.set(marker='o', color='black', alpha=0.5)

#                 plt.tight_layout()
#                 plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_box_plot.png'))
#                 plt.close()

#     if plot_type == 'line':
#         plt.title(f'{coefficient_type} across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d))]
#             for network_dir in network_dirs:
#                 network_name = network_dir.split('-thresh-')[0]
#                 threshold = network_dir.split('-thresh-')[1]

#                 matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'DiceCoefficientsMatrix.txt')
#                 cont_matrix_file = os.path.join(fig_dir, dir_name, network_dir, 'continuousDiceCoefficientsMatrix.txt')

#                 print(f"Attempting to load from: {matrix_file} and {cont_matrix_file}")

#                 if os.path.exists(matrix_file):
#                     data = load_data(matrix_file)
#                     if data is not None:
#                         if network_name not in exp_data[exp_time]:
#                             exp_data[exp_time][network_name] = {}
#                         exp_data[exp_time][network_name]['DiceCoefficient'] = data
#                 else:
#                     print(f"File not found for {dir_name}. Checked path: {matrix_file}")

#                 if os.path.exists(cont_matrix_file):
#                     cont_data = load_data(cont_matrix_file)
#                     if cont_data is not None:
#                         if network_name not in exp_data[exp_time]:
#                             exp_data[exp_time][network_name] = {}
#                         exp_data[exp_time][network_name]['continuousDiceCoefficient'] = cont_data
#                 else:
#                     print(f"File not found for {dir_name}. Checked path: {cont_matrix_file}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for plot_type in ['bar', 'line', 'box']:
#             for coefficient_type in ['DiceCoefficient', 'continuousDiceCoefficient']:
#                 plot_data(exp_data, fig_dir, plot_type, coefficient_type)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)

# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         matrix = exp_data[time]
#         if matrix.ndim == 1:  # Handle 1D array case
#             for idx, net in enumerate(networks):
#                 network_data[net].append(matrix[idx])
#         else:  # Handle 2D array case
#             for idx, net in enumerate(networks):
#                 network_data[net].append(matrix[:, idx])  # Assuming each column corresponds to a network

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the plots

#         if plot_type == 'bar':
#             means = [np.mean(x) for x in data]
#             errors = [np.std(x) for x in data]
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))
        
#         if plot_type == 'line':
#             means = [np.mean(x) for x in data]
#             errors = [np.std(x) for x in data]
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
#         elif plot_type == 'box':
#             if matrix.ndim > 1 and matrix.shape[1] > 1:  # Check if there are multiple columns for box plot
#                 plt.figure()
#                 boxplot = plt.boxplot(data, labels=exp_times, patch_artist=True)
#                 plt.title(f'Dice Coefficient - {net}')
#                 plt.xlabel('Exploratory Time Bins')
#                 plt.ylabel('Dice Coefficient')
#                 plt.xticks(rotation=45)
#                 plt.ylim(0, 1)

#                 # Customize the box plot appearance
#                 for box in boxplot['boxes']:
#                     box.set(color='black', linewidth=1.5)
#                     box.set(facecolor='#4B0082')  # Dark blue-purple color

#                 for whisker in boxplot['whiskers']:
#                     whisker.set(color='black', linewidth=1.5)

#                 for cap in boxplot['caps']:
#                     cap.set(color='black', linewidth=1.5)

#                 for median in boxplot['medians']:
#                     median.set(color='black', linewidth=1.5)

#                 for flier in boxplot['fliers']:
#                     flier.set(marker='o', color='black', alpha=0.5)

#                 plt.tight_layout()
#                 plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_box_plot.png'))
#                 plt.close()

#     if plot_type == 'line':
#         plt.title('Dice Coefficient across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Dice Coefficient')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, 'all_networks_DiceCoefficient_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             matrix_file = os.path.join(fig_dir, dir_name, 'DiceCoefficientsMatrix.txt')
            
#             print(f"Attempting to load from: {matrix_file}")
            
#             if os.path.exists(matrix_file):
#                 data = load_data(matrix_file)
#                 if data is not None:
#                     exp_data[exp_time] = data
#             else:
#                 print(f"File not found for {dir_name}. Checked path: {matrix_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         for plot_type in ['bar', 'line', 'box']:
#             plot_data(exp_data, fig_dir, plot_type)
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)
    


# #works but doesn't account for cases with only one permutation or comparing mode to mode. 
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append(exp_data[time][:, idx])  # Assuming each column corresponds to a network

#     # Plot data
#     for net in networks:
#         data = network_data[net]
#         x_positions = list(range(len(data)))  # Create a list of x positions for the box plot

#         if plot_type == 'box':
#             plt.figure()
#             boxplot = plt.boxplot(data, labels=exp_times, patch_artist=True)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(rotation=45)
#             plt.ylim(0, 1)

#             # Customize the box plot appearance
#             for box in boxplot['boxes']:
#                 box.set(color='black', linewidth=1.5)
#                 box.set(facecolor='#4B0082')  # Dark blue-purple color

#             for whisker in boxplot['whiskers']:
#                 whisker.set(color='black', linewidth=1.5)

#             for cap in boxplot['caps']:
#                 cap.set(color='black', linewidth=1.5)

#             for median in boxplot['medians']:
#                 median.set(color='black', linewidth=1.5)

#             for flier in boxplot['fliers']:
#                 flier.set(marker='o', color='black', alpha=0.5)

#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_box_plot.png'))
#             plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             matrix_file = os.path.join(fig_dir, dir_name, 'DiceCoefficientsMatrix.txt')
            
#             print(f"Attempting to load from: {matrix_file}")
            
#             if os.path.exists(matrix_file):
#                 exp_data[exp_time] = load_data(matrix_file)
#             else:
#                 print(f"File not found for {dir_name}. Checked path: {matrix_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, fig_dir, 'box')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
#         elif plot_type == 'box':
#             plt.figure()
#             boxplot = plt.boxplot([exp_data[time]['mean'] for time in exp_times], labels=exp_times, patch_artist=True)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(rotation=45)
#             plt.ylim(0, 1)

#             # Customize the box plot appearance
#             for box in boxplot['boxes']:
#                 box.set(color='black', linewidth=1.5)
#                 box.set(facecolor='#4B0082')  # Dark blue-purple color

#             for whisker in boxplot['whiskers']:
#                 whisker.set(color='black', linewidth=1.5)

#             for cap in boxplot['caps']:
#                 cap.set(color='black', linewidth=1.5)

#             for median in boxplot['medians']:
#                 median.set(color='black', linewidth=1.5)

#             for flier in boxplot['fliers']:
#                 flier.set(marker='o', color='black', alpha=0.5)

#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_box_plot.png'))
#             plt.close()

#     if plot_type == 'line':
#         plt.title('Dice Coefficient across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Dice Coefficient')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, 'all_networks_DiceCoefficient_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_DiceCoefficient.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_DiceCoefficient.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#         plot_data(exp_data, fig_dir, 'box')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)

# # works with box plot, but doesn't have color in it. 
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
#         elif plot_type == 'box':
#             plt.figure()
#             plt.boxplot([exp_data[time]['mean'] for time in exp_times], labels=exp_times)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_box_plot.png'))
#             plt.close()

#     if plot_type == 'line':
#         plt.title('Dice Coefficient across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Dice Coefficient')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, 'all_networks_DiceCoefficient_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_DiceCoefficient.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_DiceCoefficient.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#         plot_data(exp_data, fig_dir, 'box')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)



# # This one works, just doesn't have the box plot 
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Dice Coefficient - {net}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel('Dice Coefficient')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_DiceCoefficient_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Dice Coefficient across Networks and Bins')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Dice Coefficient')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, 'all_networks_DiceCoefficient_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_DiceCoefficient.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_DiceCoefficient.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory where figures will be saved.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir)

# # import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully with data shape: {data.shape}.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
    
#     # Sort the keys as integers
#     exp_times = sorted(exp_data.keys(), key=int)
#     network_data = {net: [] for net in networks}

#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))

#         plt.figure(figsize=(10, 5))
#         if plot_type == 'bar':
#             plt.bar(x_positions, means, yerr=errors, capsize=5)
#         else:
#             plt.errorbar(x_positions, means, yerr=errors, fmt='-o', capsize=5, label=net)
        
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.ylim(0, 1)
#         plt.title(f'{net} Stability - {plot_type.title()} Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'{net}_{plot_type}_plot.png'))
#         plt.close()

# def main(fig_dir, ref_prefix, exp_prefix):
#     exp_data = {}
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith(f"{ref_prefix}") and f"to_{exp_prefix}" in dir_name:
#             exp_time = dir_name.split('_to_')[1].split('-')[1][:-1]  # Extracts the time part like '5m', '10m', etc.
#             if not exp_time.isdigit():
#                 exp_time = dir_name.split('_to_')[1].split('-')[1][:-1]
#             print(f"Processing time: {exp_time} from directory: {dir_name}")
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_Network_Stability.txt')
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {'mean': load_data(mean_file), 'std': load_data(std_file)}
#             else:
#                 print(f"Data not found for {exp_time} in {dir_name}")

#     if exp_data:
#         print(f"All keys: {exp_data.keys()}")
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#     else:
#         print("No data found for plotting. Check the input directory and files.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Plot network stability trajectories.")
#     parser.add_argument('fig_dir', type=str, help="Directory with figure data.")
#     parser.add_argument('ref_prefix', type=str, help="Prefix for reference data directories.")
#     parser.add_argument('exp_prefix', type=str, help="Prefix for experimental data directories.")
#     args = parser.parse_args()
#     main(args.fig_dir, args.ref_prefix, args.exp_prefix)


# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully with data shape: {data.shape}.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
    
#     # Debugging: print all keys
#     print("All keys:", exp_data.keys())
    
#     # Safe parsing of experimental times:
#     def parse_time(key):
#         # This tries to extract the minute value and handles cases with both single and double digits.
#         # Assumes format like 'ExpData-XXm_to_RefData-70m' or 'RefData-70m_to_ExpData-XXm'
#         try:
#             # Splitting by '-' and taking the second part, then removing the last character 'm'
#             time_part = key.split('-')[1]
#             # Removing the last character which should be 'm' and converting to integer
#             minutes = int(time_part[:-1])
#             return minutes
#         except Exception as e:
#             print(f"Error parsing key {key}: {e}")
#             return 0  # Default to 0 if parsing fails
        
#     exp_times = sorted(exp_data.keys(), key=parse_time)

#     network_data = {net: [] for net in networks}

#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))

#         plt.figure(figsize=(10, 5))
#         if plot_type == 'bar':
#             plt.bar(x_positions, means, yerr=errors, capsize=5)
#         else:
#             plt.errorbar(x_positions, means, yerr=errors, fmt='-o', capsize=5, label=net)
        
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.ylim(0, 1)
#         plt.title(f'{net} Stability - {plot_type.title()} Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'{net}_{plot_type}_plot.png'))
#         plt.close()
# def extract_exp_time(dir_name, ref_prefix, exp_prefix):
#     # This function should extract the experimental time from the directory name
#     # which could be in either part of the directory name depending on the order
#     if exp_prefix in dir_name:
#         # This handles cases like "ExpData-5m_to_RefData-70m" or "RefData-70m_to_ExpData-10m"
#         parts = dir_name.split('_to_')
#         for part in parts:
#             if exp_prefix in part:
#                 return part.split('-')[1][:-1]  # Remove 'm' and extract time
#     return None  # Return None if no valid time found

# def main(fig_dir, ref_prefix, exp_prefix):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     for dir_name in os.listdir(fig_dir):
#         exp_time = extract_exp_time(dir_name, ref_prefix, exp_prefix)
#         if exp_time:
#             print(f"Processing time: {exp_time} from directory: {dir_name}")
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_Network_Stability.txt')
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {'mean': load_data(mean_file), 'std': load_data(std_file)}
#             else:
#                 print(f"Data not found for {exp_time} in {dir_name}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#     else:
#         print("No data found for plotting. Check the input directory and files.")


# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Plot network stability trajectories.")
#     parser.add_argument('fig_dir', type=str, help="Directory with figure data.")
#     parser.add_argument('ref_prefix', type=str, help="Prefix for reference data directories.")
#     parser.add_argument('exp_prefix', type=str, help="Prefix for experimental data directories.")
#     args = parser.parse_args()
#     main(args.fig_dir, args.ref_prefix, args.exp_prefix)


# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully with data shape: {data.shape}.")  # Corrected print placement
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None
    
# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.split('-')[-1][:-1]))
#     network_data = {net: [] for net in networks}

#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))

#         plt.figure(figsize=(10, 5))
#         if plot_type == 'bar':
#             plt.bar(x_positions, means, yerr=errors, capsize=5)
#         else:
#             plt.errorbar(x_positions, means, yerr=errors, fmt='-o', capsize=5, label=net)
        
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.ylim(0, 1)
#         plt.title(f'{net} Stability - {plot_type.title()} Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'{net}_{plot_type}_plot.png'))
#         plt.close()
# def main(fig_dir, ref_prefix, exp_prefix):
#     exp_data = {}
#     print(f"Checking in figure directory: {fig_dir}")
#     for dir_name in os.listdir(fig_dir):
#         print(f"Found directory: {dir_name}")
#         if dir_name.startswith(f"{ref_prefix}") and f"to_{exp_prefix}" in dir_name:
#             exp_time = dir_name.split('_to_')[1].split('-')[1]
#             mean_file = os.path.join(fig_dir, dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(fig_dir, dir_name, 'STDEV_Network_Stability.txt')
#             print(f"Attempting to load from: {mean_file} and {std_file}")
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {'mean': load_data(mean_file), 'std': load_data(std_file)}
#             else:
#                 print(f"Files not found for {exp_time}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")


#     if exp_data:
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#     else:
#         print("No data found for plotting. Check the input directory and files.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Plot network stability trajectories.")
#     parser.add_argument('fig_dir', type=str, help="Directory with figure data.")
#     parser.add_argument('ref_prefix', type=str, help="Prefix for reference data directories.")
#     parser.add_argument('exp_prefix', type=str, help="Prefix for experimental data directories.")
#     args = parser.parse_args()
#     main(args.fig_dir, args.ref_prefix, args.exp_prefix)



# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, fig_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Network Stability Bar Plot - {net}')
#             plt.xlabel('Experimental Time Bins')
#             plt.ylabel('Network Stability')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Network Stability Line Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, 'all_networks_line_plot.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data):
#     exp_data = {}
#     print(f"Checking in base directory: {base_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(os.path.join(base_dir, 'figures')):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(base_dir, 'figures', dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, 'figures', dir_name, 'STDEV_Network_Stability.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, fig_dir, 'bar')
#         plot_data(exp_data, fig_dir, 'line')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     parser.add_argument('fig_dir', type=str, help="The directory to save figures.")
#     parser.add_argument('ref_data', type=str, help="The reference data name, e.g., 'RefData-70m'.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data)


# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, base_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', 'm').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Network Stability Bar Plot - {net}')
#             plt.xlabel('Experimental Time Bins')
#             plt.ylabel('Network Stability')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(base_dir, 'figures', f'{net}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Network Stability Line Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(base_dir, 'figures', 'all_networks_line_plot.png'))
#         plt.close()


# def main(base_dir):
#     exp_data = {}
#     print(f"Checking in base directory: {base_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(os.path.join(base_dir, 'figures')):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(base_dir, 'figures', dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, 'figures', dir_name, 'STDEV_Network_Stability.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, base_dir, 'bar')
#         plot_data(exp_data, base_dir, 'line')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     args = parser.parse_args()

#     main(args.base_dir)



# def main(base_dir):
#     exp_data = {}
#     # Loop through directories and load data
#     for dir_name in os.listdir(base_dir):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(base_dir, 'figures', dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, 'figures', dir_name, 'STDEV_Network_Stability.txt')
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")

#     plot_data(exp_data, base_dir, 'bar')
#     plot_data(exp_data, base_dir, 'line')

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     args = parser.parse_args()

#     main(args.base_dir)


# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     return np.loadtxt(filepath)

# def plot_data(exp_data, base_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys())
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))
    
#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
        
#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(exp_times, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Network Stability Bar Plot - {net}')
#             plt.xlabel('Experimental Time Bins')
#             plt.ylabel('Network Stability')
#             plt.xticks(rotation=45)
#             plt.tight_layout()
#             plt.savefig(os.path.join(base_dir, 'figures', f'{net}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line':
#             plt.errorbar(exp_times, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Network Stability Line Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.legend(loc='upper left', bbox_to_anchor=(1,1))
#         plt.xticks(rotation=45)
#         plt.tight_layout()
#         plt.savefig(os.path.join(base_dir, 'figures', 'all_networks_line_plot.png'))
#         plt.close()

# def main(base_dir):
#     exp_data = {}
#     # Scan for directories
#     for dir_name in os.listdir(base_dir):
#         if dir_name.startswith('ExpData') and dir_name.endswith('m_to_RefData-70m'):
#             exp_time = dir_name.split('_to_')[0]
#             mean_file = os.path.join(base_dir, dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, dir_name, 'STDEV_Network_Stability.txt')
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }

#     plot_data(exp_data, base_dir, 'bar')
#     plot_data(exp_data, base_dir, 'line')

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     args = parser.parse_args()

#     main(args.base_dir)



# import os
# import numpy as np
# import matplotlib.pyplot as plt

# def load_data(filepath):
#     """Load data from a text file."""
#     return np.loadtxt(filepath)

# def plot_data(exp_data, base_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys())
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))
    
#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
        
#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(exp_times, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Network Stability Bar Plot - {net}')
#             plt.xlabel('Experimental Time Bins')
#             plt.ylabel('Network Stability')
#             plt.xticks(rotation=45)
#             plt.tight_layout()
#             plt.savefig(os.path.join(base_dir, 'figures', f'{net}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line':
#             plt.errorbar(exp_times, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Network Stability Line Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.legend(loc='upper left', bbox_to_anchor=(1,1))
#         plt.xticks(rotation=45)
#         plt.tight_layout()
#         plt.savefig(os.path.join(base_dir, 'figures', 'all_networks_line_plot.png'))
#         plt.close()

# def main(base_dir):
#     exp_data = {}
#     # Assuming subdirectories are named like 'ExpData-5m_to_RefData-70m'
#     for dir_name in os.listdir(base_dir):
#         if dir_name.startswith('ExpData') and dir_name.endswith('m_to_RefData-70m'):
#             exp_time = dir_name.split('_to_')[0]
#             mean_file = os.path.join(base_dir, dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, dir_name, 'STDEV_Network_Stability.txt')
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }

#     plot_data(exp_data, base_dir, 'bar')
#     plot_data(exp_data, base_dir, 'line')

# if __name__ == '__main__':
#     BASEDIR = '/path/to/your/BASEDIR'
#     main(BASEDIR)



# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath)
#         print(f"Loaded data from {filepath} successfully.")
#         return data
#     except Exception as e:
#         print(f"Failed to load data from {filepath}. Error: {e}")
#         return None

# def plot_data(exp_data, base_dir, plot_type='bar'):
#     """Generate plots for each network."""
#     networks = ['DMN', 'VIS', 'FP', 'DAN', 'VAN', 'SAL', 'CO', 'SMD', 'SML', 'AUD', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', 'm').replace('m', '')))
#     print("Experimental times sorted:", exp_times)
#     network_data = {net: [] for net in networks}

#     # Organize data by network
#     for time in exp_times:
#         for idx, net in enumerate(networks):
#             network_data[net].append((exp_data[time]['mean'][idx], exp_data[time]['std'][idx]))

#     # Plot data
#     for net in networks:
#         means = [x[0] for x in network_data[net]]
#         errors = [x[1] for x in network_data[net]]
#         x_positions = list(range(len(means)))  # Create a list of x positions for the bar chart

#         if plot_type == 'bar':
#             plt.figure()
#             plt.bar(x_positions, means, yerr=errors, color='skyblue', capsize=5)
#             plt.title(f'Network Stability Bar Plot - {net}')
#             plt.xlabel('Experimental Time Bins')
#             plt.ylabel('Network Stability')
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(0, 1)
#             plt.tight_layout()
#             plt.savefig(os.path.join(base_dir, 'figures', f'{net}_bar_plot.png'))
#             plt.close()
#         elif plot_type == 'line' and net == networks[0]:  # Start new figure for line plot
#             plt.figure(figsize=(10, 5))

#         if plot_type == 'line':
#             plt.errorbar(x_positions, means, yerr=errors, label=net, fmt='-o', capsize=5)
    
#     if plot_type == 'line':
#         plt.title('Network Stability Line Plot')
#         plt.xlabel('Experimental Time Bins')
#         plt.ylabel('Network Stability')
#         plt.xticks(x_positions, exp_times, rotation=45)
#         plt.legend(loc='upper left', bbox_to_anchor=(1, 1))
#         plt.ylim(0, 1)
#         plt.tight_layout()
#         plt.savefig(os.path.join(base_dir, 'figures', 'all_networks_line_plot.png'))
#         plt.close()


# def main(base_dir):
#     exp_data = {}
#     print(f"Checking in base directory: {base_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(os.path.join(base_dir, 'figures')):
#         if dir_name.startswith('ExpData') and 'to_RefData-70m' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             mean_file = os.path.join(base_dir, 'figures', dir_name, 'Average_Network_Stability.txt')
#             std_file = os.path.join(base_dir, 'figures', dir_name, 'STDEV_Network_Stability.txt')
            
#             print(f"Attempting to load from: {mean_file} and {std_file}")
            
#             if os.path.exists(mean_file) and os.path.exists(std_file):
#                 exp_data[exp_time] = {
#                     'mean': load_data(mean_file),
#                     'std': load_data(std_file)
#                 }
#             else:
#                 print(f"Files not found for {dir_name}. Checked paths: {mean_file}, {std_file}")
#         else:
#             print(f"Directory ignored: {dir_name}")

#     if exp_data:
#         print("Data loaded for times:", exp_data.keys())
#         plot_data(exp_data, base_dir, 'bar')
#         plot_data(exp_data, base_dir, 'line')
#     else:
#         print("No data loaded. Please check directory paths and file existence.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Process network stability data across experimental bins.")
#     parser.add_argument('base_dir', type=str, help="The base directory containing the data folders.")
#     args = parser.parse_args()

#     main(args.base_dir)