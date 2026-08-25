import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from glob import glob
import argparse

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
    'SCAN': '#800080'   # Purple
}

def load_and_aggregate_csv(csv_dir):
    """Load and aggregate all subject-level CSV files."""
    all_files = glob(os.path.join(csv_dir, "*.csv"))
    dataframes = [pd.read_csv(file) for file in all_files]
    aggregated_data = pd.concat(dataframes, ignore_index=True)
    print(f"Aggregated {len(all_files)} CSV files into one DataFrame.")
    return aggregated_data

def preprocess_exp_times(data):
    """Preprocess and convert ExpTime to numeric time values."""
    data['NumericExpTime'] = data['ExpTime'].str.extract(r'ExpData-(\d+)m').astype(float)
    return data
def plot_trajectories(data, metric, output_dir, network=None, max_time=None, y_limits=None):
    """Plot trajectories for each network or a specific network."""
    os.makedirs(output_dir, exist_ok=True)

    # Clean up metric name for plotting
    metric_clean = metric.replace("_", " ")

    # Filter for the specified metric
    data = data[data['Metric'] == metric]
    if data.empty:
        print(f"No data available for the specified metric: {metric}")
        return

    # Preprocess times
    data = preprocess_exp_times(data)
    if max_time is None:
        max_time = data['NumericExpTime'].max()

    # Group by NumericExpTime and Network
    grouped = data.groupby(['NumericExpTime', 'Network'])['Value'].agg(['mean', 'std']).reset_index()

    if network:
        # Filter for the specific network
        grouped = grouped[grouped['Network'] == network]
        if grouped.empty:
            print(f"No data available for the specified network: {network}")
            return

        # Plot specific network
        plt.figure(figsize=(10, 6))
        plt.errorbar(
            grouped['NumericExpTime'], grouped['mean'], yerr=grouped['std'],
            fmt='-o', label=network, color=color_map.get(network, 'gray'), linewidth=4, markersize=12, capsize=6
        )
        plt.title(f"{network} - {metric_clean}", fontsize=20)
        plt.xlabel('Time (minutes)', fontsize=20)
        plt.ylabel(metric_clean, fontsize=18)
        plt.xlim(0, max_time + 5)
        plt.xticks(fontsize=16)  # Adjust font size for x-axis ticks
        plt.yticks(fontsize=16)  # Adjust font size for y-axis ticks    
        plt.tight_layout()
        if y_limits:
            plt.ylim(y_limits)

        # Save plot
        plot_path = os.path.join(output_dir, f"{network}_{metric}_trajectory.png")
        plt.savefig(plot_path, dpi=300)
        plt.close()
        print(f"Saved trajectory plot for {network} to {plot_path}")

    else:
        # Plot all networks individually
        for net in grouped['Network'].unique():
            net_data = grouped[grouped['Network'] == net]
            plt.figure(figsize=(10, 6))
            plt.errorbar(
                net_data['NumericExpTime'], net_data['mean'], yerr=net_data['std'],
                fmt='-o', label=net, color=color_map.get(net, 'gray'), linewidth=4, capsize=6,markersize=12
            )
            plt.title(f"{net} - {metric_clean}", fontsize=20)
            plt.xlabel('Time (minutes)', fontsize=20)
            plt.ylabel(metric_clean, fontsize=18)
            plt.xlim(0, max_time + 5)
            plt.xticks(fontsize=16)  # Adjust font size for x-axis ticks
            plt.yticks(fontsize=16)  # Adjust font size for y-axis ticks    
            plt.tight_layout()

            # Save plot
            plot_path = os.path.join(output_dir, f"{net}_{metric}_trajectory.png")
            plt.savefig(plot_path, dpi=300)
            plt.close()
            print(f"Saved trajectory plot for {net} to {plot_path}")

def plot_combined_with_error_bars(data, metric, output_dir, max_time=None, y_limits=None, save_csv=True):
    """Plot combined trajectories with error bars for all networks and save statistics."""
    os.makedirs(output_dir, exist_ok=True)

    # Clean up metric name for plotting
    metric_clean = metric.replace("_", " ")

    # Filter for the specified metric
    data = data[data['Metric'] == metric]
    if data.empty:
        print(f"No data available for the specified metric: {metric}")
        return

    # Sort by NumericExpTime
    data = preprocess_exp_times(data)
    if max_time is None:
        max_time = data['NumericExpTime'].max()

    # Group by NumericExpTime and Network
    grouped = data.groupby(['NumericExpTime', 'Network'])['Value'].agg(['mean', 'std']).reset_index()

    # Exclude the temporal pole
    grouped = grouped[grouped['Network'] != 'Tpole']

    # Pivot for plotting
    pivot_mean = grouped.pivot(index='NumericExpTime', columns='Network', values='mean')
    pivot_std = grouped.pivot(index='NumericExpTime', columns='Network', values='std')

    # Save summary statistics if requested
    if save_csv:
        stats_csv_path = os.path.join(output_dir, f"{metric}_summary_statistics.csv")
        stats = grouped.groupby(['NumericExpTime']).agg({'mean': 'mean', 'std': 'mean'}).reset_index()
        stats.to_csv(stats_csv_path, index=False)
        print(f"Saved summary statistics to {stats_csv_path}")

    # Plot combined trajectories
    plt.figure(figsize=(12, 8))
    for network in pivot_mean.columns:
        color = color_map.get(network, 'gray')  # Use color map or default to gray
        plt.errorbar(
            pivot_mean.index, pivot_mean[network], yerr=pivot_std[network],
            fmt='-o', label=network, color=color, linewidth=4, capsize=6, markersize=12
        )

    plt.title(f"Combined Trajectories - {metric_clean}", fontsize=20)
    plt.xlabel('Time (minutes)', fontsize=20)
    plt.ylabel(metric_clean, fontsize=20)
    plt.xlim(0, max_time + 5)  # Add padding
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=18)
    plt.tight_layout()
    if y_limits:
        plt.ylim(y_limits)
    plt.xticks(fontsize=16)  # Adjust font size for x-axis ticks
    plt.yticks(fontsize=16)  # Adjust font size for y-axis ticks    

    # Save plot
    plot_path = os.path.join(output_dir, f"{metric}_combined_trajectory_with_error_bars.png")
    plt.savefig(plot_path, dpi=300)
    plt.close()
    print(f"Saved combined plot with error bars to {plot_path}")

# def plot_combined_with_error_bars(data, metric, output_dir, max_time=None, y_limits=None):
#     """Plot combined trajectories with error bars for all networks."""
#     os.makedirs(output_dir, exist_ok=True)

#     # Clean up metric name for plotting
#     metric_clean = metric.replace("_", " ")

#     # Filter for the specified metric
#     data = data[data['Metric'] == metric]
#     if data.empty:
#         print(f"No data available for the specified metric: {metric}")
#         return

#     # Sort by NumericExpTime
#     data = preprocess_exp_times(data)
#     if max_time is None:
#         max_time = data['NumericExpTime'].max()

#     # Group by NumericExpTime and Network
#     grouped = data.groupby(['NumericExpTime', 'Network'])['Value'].agg(['mean', 'std']).reset_index()

#     # Pivot for plotting
#     pivot_mean = grouped.pivot(index='NumericExpTime', columns='Network', values='mean')
#     pivot_std = grouped.pivot(index='NumericExpTime', columns='Network', values='std')

#     plt.figure(figsize=(12, 8))
#     for network in pivot_mean.columns:
#         color = color_map.get(network, 'gray')  # Use color map or default to gray
#         plt.errorbar(
#             pivot_mean.index, pivot_mean[network], yerr=pivot_std[network],
#             fmt='-o', label=network, color=color, linewidth=4, capsize=6,markersize=12
#         )

#     plt.title(f"Combined Trajectories - {metric_clean}", fontsize=20)
#     plt.xlabel('Time (minutes)', fontsize=20)
#     plt.ylabel(metric_clean, fontsize=20)
#     plt.xlim(0, max_time + 5)  # Add padding
#     plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left', fontsize=18)
#     plt.tight_layout()
#     if y_limits:
#         plt.ylim(y_limits)
#     plt.xticks(fontsize=16)  # Adjust font size for x-axis ticks
#     plt.yticks(fontsize=16)  # Adjust font size for y-axis ticks    

#     # Save plot
#     plot_path = os.path.join(output_dir, f"{metric}_combined_trajectory_with_error_bars.png")
#     plt.savefig(plot_path, dpi=300)
#     plt.close()
#     print(f"Saved combined plot with error bars to {plot_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Plot trajectories from aggregated data.")
    parser.add_argument("csv_dir", type=str, help="Directory containing CSV files.")
    parser.add_argument("output_dir", type=str, help="Directory to save the trajectory plots.")
    parser.add_argument("metric", type=str, help="Metric of interest (e.g., Average_DiceCoefficient_cortical_thresh_0.5).")
    parser.add_argument("--networks", nargs="*", help="List of specific networks to plot. Leave empty for all networks.")
    parser.add_argument("--max_time", type=int, default=None, help="Maximum time for the x-axis. Leave empty to auto-detect.")
    parser.add_argument("--plot_mode", type=str, choices=["all", "specific", "combined"], default="all",
                        help="Plotting mode: 'all' for all networks, 'specific' for a given network, or 'combined' for only the summary.")
    parser.add_argument("--ymin", type=float, default=None, help="Minimum value for the y-axis.")
    parser.add_argument("--ymax", type=float, default=None, help="Maximum value for the y-axis.")

    args = parser.parse_args()

    # Ensure output directory exists
    os.makedirs(args.output_dir, exist_ok=True)

    # Load and aggregate data
    aggregated_data = load_and_aggregate_csv(args.csv_dir)

    y_limits = (args.ymin, args.ymax) if args.ymin is not None and args.ymax is not None else None

    if args.plot_mode == "all":
        # Plot individual trajectories for all networks
        plot_trajectories(aggregated_data, args.metric, args.output_dir, args.networks, args.max_time, y_limits)

    elif args.plot_mode == "specific":
        if not args.networks or len(args.networks) != 1:
            print("Error: '--networks' must contain exactly one network in 'specific' mode.")
            exit(1)
        # Plot trajectory for a specific network
        plot_trajectories(aggregated_data, args.metric, args.output_dir, args.networks, args.max_time, y_limits)

    elif args.plot_mode == "combined":
        # Plot only the combined summary
        plot_combined_with_error_bars(aggregated_data, args.metric, args.output_dir, args.max_time, y_limits)


# if __name__ == "__main__":
#     parser = argparse.ArgumentParser(description="Plot trajectories from aggregated data.")
#     parser.add_argument("csv_dir", type=str, help="Directory containing CSV files.")
#     parser.add_argument("output_dir", type=str, help="Directory to save the trajectory plots.")
#     parser.add_argument("metric", type=str, help="Metric of interest (e.g., Average_DiceCoefficient_cortical_thresh_0.5).")
#     parser.add_argument("--networks", nargs="*", help="List of specific networks to plot. Leave empty for all networks.")
#     parser.add_argument("--max_time", type=int, default=None, help="Maximum time for the x-axis. Leave empty to auto-detect.")

#     args = parser.parse_args()

#     # Ensure output directory exists
#     os.makedirs(args.output_dir, exist_ok=True)

#     # Load and aggregate data
#     aggregated_data = load_and_aggregate_csv(args.csv_dir)

#     # Plot individual trajectories
#     plot_trajectories(aggregated_data, args.metric, args.output_dir, args.networks, args.max_time)

#     # Plot combined trajectories
#     plot_combined_with_error_bars(aggregated_data, args.metric, args.output_dir, args.max_time)


# if __name__ == "__main__":
#     # Inputs
#     csv_dir = "/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bagged_reliability_curves_percent_split-100/figures/TestingExps"  # Replace with your CSV directory
#     output_dir = "/home/smnelson/shared/projects/PFM3T7T/analyses/PCM/outputs/3T/2mm/bagged_reliability_curves_percent_split-100/figures/TestingExps/figures"  # Replace with your desired output directory
#     metric = "Average_DiceCoefficient_cortical_thresh_0.5"  # Replace with your metric of interest
#     networks = None  # Set to a list of specific networks or None for all
#     max_time = None  # Set a specific max time (e.g., 70) or None to auto-detect

#     # Load and aggregate data
#     aggregated_data = load_and_aggregate_csv(csv_dir)

#     # Plot individual trajectories
#     plot_trajectories(aggregated_data, metric, output_dir, networks, max_time)

#     # Plot combined trajectories
#     plot_combined_with_error_bars(aggregated_data, metric, output_dir, max_time)


# import os
# import pickle
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_exp_data(filepath):
#     """Load experimental data from a pickle file."""
#     with open(filepath, 'rb') as f:
#         return pickle.load(f)

# def aggregate_data(pickle_files):
#     """Aggregate data across multiple subjects."""
#     aggregated_data = {}

#     for pickle_file in pickle_files:
#         print(f"Loading data from {pickle_file}...")
#         subject_data = load_exp_data(pickle_file)

#         for exp_time, networks in subject_data.items():
#             if exp_time not in aggregated_data:
#                 aggregated_data[exp_time] = {}

#             for network, metrics in networks.items():
#                 if network not in aggregated_data[exp_time]:
#                     aggregated_data[exp_time][network] = {}

#                 for metric, value in metrics.items():
#                     if metric not in aggregated_data[exp_time][network]:
#                         aggregated_data[exp_time][network][metric] = []
#                     aggregated_data[exp_time][network][metric].append(value)

#                     # Include the pickle file and metric in the warning
#                     if np.isnan(value).all():
#                         print(f"Warning: All NaN values for {metric} in {network} at {exp_time} "
#                               f"from {pickle_file}.")

#     return aggregated_data
    
# def plot_aggregated_data(aggregated_data, fig_dir, coefficient_type, networks):
#     """Generate plots for aggregated data."""
#     exp_times = sorted(aggregated_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))

#     # Plot mean and standard deviation for each network
#     for network in networks:
#         means = []
#         stds = []
#         for exp_time in exp_times:
#             if network in aggregated_data[exp_time]:
#                 values = aggregated_data[exp_time][network].get(coefficient_type, [])
#                 if not np.isnan(values).all():
#                     means.append(np.nanmean(values))
#                     stds.append(np.nanstd(values))
#                 else:
#                     print(f"Warning: All NaN values for {coefficient_type} in {network} at {exp_time}. Skipping.")
#                     means.append(np.nan)
#                     stds.append(np.nan)
#             else:
#                 means.append(np.nan)
#                 stds.append(np.nan)

#         if not all(np.isnan(means)):  # Skip plotting if all values are NaN
#             plt.figure(figsize=(10, 5))
#             plt.errorbar(range(len(exp_times)), means, yerr=stds, fmt='-o', label=network)
#             plt.title(f'{coefficient_type} - {network}')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(range(len(exp_times)), exp_times, rotation=45)
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{network}_{coefficient_type}_aggregated.png'))
#             plt.close()

#     # Plot aggregated mean across all networks
#     overall_means = []
#     overall_stds = []
#     for exp_time in exp_times:
#         all_network_values = []
#         for network in networks:
#             if network in aggregated_data[exp_time]:
#                 values = aggregated_data[exp_time][network].get(coefficient_type, [])
#                 all_network_values.extend(values)
#         if not all(np.isnan(all_network_values)):
#             overall_means.append(np.nanmean(all_network_values))
#             overall_stds.append(np.nanstd(all_network_values))
#         else:
#             overall_means.append(np.nan)
#             overall_stds.append(np.nan)

#     if not all(np.isnan(overall_means)):  # Skip plotting if all values are NaN
#         plt.figure(figsize=(10, 5))
#         plt.errorbar(range(len(exp_times)), overall_means, yerr=overall_stds, fmt='-o', capsize=5, color='blue')
#         plt.title(f'Aggregated Mean {coefficient_type} Across Networks')
#         plt.xlabel('Exploratory Time Bins')
#         plt.ylabel(coefficient_type)
#         plt.xticks(range(len(exp_times)), exp_times, rotation=45)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'aggregated_mean_{coefficient_type}.png'))
#         plt.close()

# def verify_pickle_files(pickle_files):
#     """Check the content of pickle files for validity."""
#     for pickle_file in pickle_files:
#         print(f"Verifying {pickle_file}...")
#         subject_data = load_exp_data(pickle_file)

#         for exp_time, networks in subject_data.items():
#             for network, metrics in networks.items():
#                 for metric, value in metrics.items():
#                     if np.isnan(value).all():
#                         print(f"Verification Warning: All NaN values in {metric} for {network} at {exp_time} "
#                               f"in {pickle_file}.")

# if __name__ == '__main__':
#     parser = argparse.ArgumentParser(description="Aggregate and plot experimental data across subjects.")
#     parser.add_argument('pickle_dir', type=str, help="Directory containing subject-level pickle files.")
#     parser.add_argument('fig_dir', type=str, help="Directory to save the output figures.")
#     parser.add_argument('coefficient_type', type=str, help="Metric to aggregate (e.g., 'Average_DiceCoefficient_cortical').")
#     parser.add_argument('--networks', type=str, nargs='+', default=[
#         'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#         'Tpole', 'MTL', 'PMN', 'PON', 'SCAN'
#     ], help="List of networks to include in the plots.")

#     args = parser.parse_args()

#     os.makedirs(args.fig_dir, exist_ok=True)

#     # Get all pickle files in the specified directory
#     pickle_files = [
#         os.path.join(args.pickle_dir, f)
#         for f in os.listdir(args.pickle_dir)
#         if f.endswith('_exp_data_confmap.pkl')
#     ]

#     if not pickle_files:
#         print(f"No pickle files found in {args.pickle_dir}. Exiting.")
#         exit(1)

#     # Aggregate data
#     aggregated_data = aggregate_data(pickle_files)

#     # Generate plots
#     plot_aggregated_data(aggregated_data, args.fig_dir, args.coefficient_type, args.networks)



# def plot_data(exp_data, fig_dir, plot_type='line', coefficient_type='DiceCoefficient', threshold='0.8', summary_only=False, data_prefix='ExpData-'):
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
    
#     # Adjust lambda function to extract the numeric time correctly
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace(data_prefix, '').split('m')[0].split('-')[-1]))

#     network_data = {net: [] for net in networks}
    
#     mean_data = []
#     std_data = []

#     for time in exp_times:
#         for net in networks:
#             if net in exp_data[time]:
#                 if coefficient_type in exp_data[time][net]:
#                     network_data[net].append(exp_data[time][net][coefficient_type])
#                 else:
#                     network_data[net].append(np.nan)
#             else:
#                 network_data[net].append(np.nan)

#         all_networks_at_time = [network_data[net][-1] for net in networks if not np.isnan(network_data[net][-1])]
#         mean_data.append(np.mean(all_networks_at_time))
#         std_data.append(np.std(all_networks_at_time))

#     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
#     max_value = max(all_values) if all_values else 1
#     ylim = (0, 1) if max_value <= 1 else (0, 10 ** (int(np.log10(max_value)) + 1))

#     if not summary_only:
#         for net in networks:
#             data = network_data[net]
#             x_positions = list(range(len(data)))

#             plt.figure(figsize=(10, 5))
#             plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(ylim)
#             plt.legend(loc='upper right', bbox_to_anchor=(1.1, 1))
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#             plt.close()

#     plt.figure(figsize=(10, 5))
#     x_positions = list(range(len(mean_data)))
#     plt.errorbar(x_positions, mean_data, yerr=std_data, fmt='-o', capsize=5, color='blue')
#     plt.title(f'Mean {coefficient_type} across Networks (Thresh: {threshold})')
#     plt.xlabel('Exploratory Time Bins')
#     plt.ylabel(f'Mean {coefficient_type}')
#     plt.xticks(x_positions, exp_times, rotation=45)
#     plt.ylim(ylim)
#     plt.tight_layout()
#     plt.savefig(os.path.join(fig_dir, f'mean_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#     plt.close()
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse
# import pickle

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         #print(f"Loaded data from {filepath} successfully.")
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

# def plot_data(exp_data, fig_dir, plot_type='line', coefficient_type='DiceCoefficient', threshold='0.8', summary_only=False):
#     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
#                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
#     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
#     network_data = {net: [] for net in networks}
    
#     # Initialize lists to store means and std deviations
#     mean_data = []
#     std_data = []

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

#         # Calculate mean and std deviation for this time point across networks
#         all_networks_at_time = [network_data[net][-1] for net in networks if not np.isnan(network_data[net][-1])]
#         mean_data.append(np.mean(all_networks_at_time))
#         std_data.append(np.std(all_networks_at_time))

#     # Determine ylim based on the maximum data value
#     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
#     max_value = max(all_values) if all_values else 1
#     if max_value <= 1:
#         ylim = (0, 1)
#     else:
#         # Round up to the nearest power of 10
#         ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

#     # Plot data
#     if not summary_only:
#         for net in networks:
#             data = network_data[net]
#             x_positions = list(range(len(data)))

#             # Use line plots for individual networks with legends outside the plot
#             plt.figure(figsize=(10, 5))
#             plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
#             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
#             plt.xlabel('Exploratory Time Bins')
#             plt.ylabel(coefficient_type)
#             plt.xticks(x_positions, exp_times, rotation=45)
#             plt.ylim(ylim)
#             plt.legend(loc='upper right', bbox_to_anchor=(1.1, 1))  # Legend outside the plot on the right
#             plt.tight_layout()
#             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#             plt.close()

#     # Plot mean and std deviation across networks
#     plt.figure(figsize=(10, 5))
#     x_positions = list(range(len(mean_data)))
#     plt.errorbar(x_positions, mean_data, yerr=std_data, fmt='-o', capsize=5, color='blue')
#     plt.title(f'Mean {coefficient_type} across Networks (Thresh: {threshold})')
#     plt.xlabel('Exploratory Time Bins')
#     plt.ylabel(f'Mean {coefficient_type}')
#     plt.xticks(x_positions, exp_times, rotation=45)
#     plt.ylim(ylim)
#     plt.tight_layout()
#     plt.savefig(os.path.join(fig_dir, f'mean_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#     plt.close()

# # def plot_data(exp_data, fig_dir, plot_type='line', coefficient_type='DiceCoefficient', threshold='0.8', summary_only=False):
# #     networks = ['DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 'SMd', 'SMl', 'Aud', 
# #                 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']
# #     exp_times = sorted(exp_data.keys(), key=lambda x: int(x.replace('ExpData-', '').replace('m', '')))
# #     network_data = {net: [] for net in networks}
    
# #     # Initialize lists to store means and std deviations
# #     mean_data = []
# #     std_data = []

# #     # Organize data by network
# #     for time in exp_times:
# #         for net in networks:
# #             if net in exp_data[time]:
# #                 if coefficient_type in exp_data[time][net]:
# #                     network_data[net].append(exp_data[time][net][coefficient_type])
# #                 else:
# #                     network_data[net].append(np.nan)
# #             else:
# #                 network_data[net].append(np.nan)

# #         # Calculate mean and std deviation for this time point across networks
# #         all_networks_at_time = [network_data[net][-1] for net in networks if not np.isnan(network_data[net][-1])]
# #         mean_data.append(np.mean(all_networks_at_time))
# #         std_data.append(np.std(all_networks_at_time))

# #     # Determine ylim based on the maximum data value
# #     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
# #     max_value = max(all_values) if all_values else 1
# #     if max_value <= 1:
# #         ylim = (0, 1)
# #     else:
# #         # Round up to the nearest power of 10
# #         ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

# #     # Plot data
# #     if not summary_only:
# #         for net in networks:
# #             data = network_data[net]
# #             x_positions = list(range(len(data)))

# #             # Use line plots for individual networks
# #             plt.figure(figsize=(10, 5))
# #             plt.plot(x_positions, data, label=net, marker='o', color=color_map.get(net, 'grey'))
# #             plt.title(f'{coefficient_type} - {net} (Thresh: {threshold})')
# #             plt.xlabel('Exploratory Time Bins')
# #             plt.ylabel(coefficient_type)
# #             plt.xticks(x_positions, exp_times, rotation=45)
# #             plt.ylim(ylim)
# #             plt.tight_layout()
# #             plt.savefig(os.path.join(fig_dir, f'{net}_{coefficient_type}_line_plot_thresh_{threshold}.png'))
# #             plt.close()

# #     # Plot mean and std deviation across networks
# #     plt.figure(figsize=(10, 5))
# #     x_positions = list(range(len(mean_data)))
# #     plt.errorbar(x_positions, mean_data, yerr=std_data, fmt='-o', capsize=5, color='blue')
# #     plt.title(f'Mean {coefficient_type} across Networks (Thresh: {threshold})')
# #     plt.xlabel('Exploratory Time Bins')
# #     plt.ylabel(f'Mean {coefficient_type}')
# #     plt.xticks(x_positions, exp_times, rotation=45)
# #     plt.ylim(ylim)
# #     plt.tight_layout()
# #     plt.savefig(os.path.join(fig_dir, f'mean_{coefficient_type}_line_plot_thresh_{threshold}.png'))
# #     plt.close()


# def save_exp_data(exp_data, save_path):
#     """Save experimental data to a pickle file."""
#     with open(save_path, 'wb') as f:
#         pickle.dump(exp_data, f)
#     print(f"Saved experimental data to {save_path}")

# def load_exp_data(load_path):
#     """Load experimental data from a pickle file."""
#     with open(load_path, 'rb') as f:
#         exp_data = pickle.load(f)
#     print(f"Loaded experimental data from {load_path}")
#     return exp_data

# def main(base_dir, fig_dir, ref_data, thresholds, conf_map=False, summary_only=False, save_path=None, load_path=None):
#     if load_path:
#         exp_data = load_exp_data(load_path)
#     else:
#         exp_data = {}
#         #print(f"Checking in figure directory: {fig_dir}")
#         # Loop through directories and load data
#         for dir_name in os.listdir(fig_dir):
#             if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#                 exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#                 exp_data[exp_time] = {}

#                 for threshold in thresholds:
#                     if conf_map:
#                         network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                         for network_dir in network_dirs:
#                             network_name = network_dir.split('-thresh-')[0]

#                             # File paths for various metrics
#                             metrics_files = [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]

#                             for metric in metrics_files:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             if network_name not in exp_data[exp_time]:
#                                                 exp_data[exp_time][network_name] = {}
#                                             exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")
#                     else:
#                         combined_folder = f"All-thresh-{threshold}"
#                         folder_path = os.path.join(fig_dir, dir_name, combined_folder)

#                         if os.path.exists(folder_path):
#                             for metric in [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(folder_path, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             # Assume each file contains data for all networks
#                                             for i, net in enumerate([
#                                                 'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 
#                                                 'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']):
#                                                 if exp_time not in exp_data:
#                                                     exp_data[exp_time] = {}
#                                                 if net not in exp_data[exp_time]:
#                                                     exp_data[exp_time][net] = {}
#                                                 exp_data[exp_time][net][f'{metric}_{region}_thresh_{threshold}'] = data[i]
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")

#         if save_path:
#             save_exp_data(exp_data, save_path)

#     if exp_data:
#         #print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for metric in [
#                 'Average_DiceCoefficient',
#                 'Average_continuousDiceCoefficient',
#                 'FalseNegative',
#                 'FalsePositive',
#                 'NPV',
#                 'PPV',
#                 'TrueNegative',
#                 'TruePositive'
#             ]:
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
#     parser.add_argument('--ConfMap', action='store_true', help="Use ConfMap mode.")
#     parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
#     parser.add_argument('--save_path', type=str, help="Path to save the experimental data.")
#     parser.add_argument('--load_path', type=str, help="Path to load previously saved experimental data.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.ConfMap, args.summary_only, args.save_path, args.load_path)




# ## works but bar plots for individual networks not line plots
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse
# import pickle

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         #print(f"Loaded data from {filepath} successfully.")
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
    
#     # Initialize lists to store means and std deviations
#     mean_data = []
#     std_data = []

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

#         # Calculate mean and std deviation for this time point across networks
#         all_networks_at_time = [network_data[net][-1] for net in networks if not np.isnan(network_data[net][-1])]
#         mean_data.append(np.mean(all_networks_at_time))
#         std_data.append(np.std(all_networks_at_time))

#     # Determine ylim based on the maximum data value
#     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
#     max_value = max(all_values) if all_values else 1
#     if max_value <= 1:
#         ylim = (0, 1)
#     else:
#         # Round up to the nearest power of 10
#         ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

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
#                 plt.ylim(ylim)
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
#         plt.ylim(ylim)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

#     # Plot mean and std deviation across networks
#     plt.figure(figsize=(10, 5))
#     x_positions = list(range(len(mean_data)))
#     plt.errorbar(x_positions, mean_data, yerr=std_data, fmt='-o', capsize=5, color='blue')
#     plt.title(f'Mean {coefficient_type} across Networks (Thresh: {threshold})')
#     plt.xlabel('Exploratory Time Bins')
#     plt.ylabel(f'Mean {coefficient_type}')
#     plt.xticks(x_positions, exp_times, rotation=45)
#     plt.ylim(ylim)
#     plt.tight_layout()
#     plt.savefig(os.path.join(fig_dir, f'mean_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#     plt.close()

# def save_exp_data(exp_data, save_path):
#     """Save experimental data to a pickle file."""
#     with open(save_path, 'wb') as f:
#         pickle.dump(exp_data, f)
#     print(f"Saved experimental data to {save_path}")

# def load_exp_data(load_path):
#     """Load experimental data from a pickle file."""
#     with open(load_path, 'rb') as f:
#         exp_data = pickle.load(f)
#     print(f"Loaded experimental data from {load_path}")
#     return exp_data

# def main(base_dir, fig_dir, ref_data, thresholds, conf_map=False, summary_only=False, save_path=None, load_path=None):
#     if load_path:
#         exp_data = load_exp_data(load_path)
#     else:
#         exp_data = {}
#         #print(f"Checking in figure directory: {fig_dir}")
#         # Loop through directories and load data
#         for dir_name in os.listdir(fig_dir):
#             if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#                 exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#                 exp_data[exp_time] = {}

#                 for threshold in thresholds:
#                     if conf_map:
#                         network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                         for network_dir in network_dirs:
#                             network_name = network_dir.split('-thresh-')[0]

#                             # File paths for various metrics
#                             metrics_files = [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]

#                             for metric in metrics_files:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             if network_name not in exp_data[exp_time]:
#                                                 exp_data[exp_time][network_name] = {}
#                                             exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")
#                     else:
#                         combined_folder = f"All-thresh-{threshold}"
#                         folder_path = os.path.join(fig_dir, dir_name, combined_folder)

#                         if os.path.exists(folder_path):
#                             for metric in [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(folder_path, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             # Assume each file contains data for all networks
#                                             for i, net in enumerate([
#                                                 'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 
#                                                 'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']):
#                                                 if exp_time not in exp_data:
#                                                     exp_data[exp_time] = {}
#                                                 if net not in exp_data[exp_time]:
#                                                     exp_data[exp_time][net] = {}
#                                                 exp_data[exp_time][net][f'{metric}_{region}_thresh_{threshold}'] = data[i]
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")

#         if save_path:
#             save_exp_data(exp_data, save_path)

#     if exp_data:
#         #print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for metric in [
#                 'Average_DiceCoefficient',
#                 'Average_continuousDiceCoefficient',
#                 'FalseNegative',
#                 'FalsePositive',
#                 'NPV',
#                 'PPV',
#                 'TrueNegative',
#                 'TruePositive'
#             ]:
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
#     parser.add_argument('--ConfMap', action='store_true', help="Use ConfMap mode.")
#     parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
#     parser.add_argument('--save_path', type=str, help="Path to save the experimental data.")
#     parser.add_argument('--load_path', type=str, help="Path to load previously saved experimental data.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.ConfMap, args.summary_only, args.save_path, args.load_path)
## works but no mean
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse
# import pickle

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         #print(f"Loaded data from {filepath} successfully.")
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

#     # Determine ylim based on the maximum data value
#     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
#     max_value = max(all_values) if all_values else 1
#     if max_value <= 1:
#         ylim = (0, 1)
#     else:
#         # Round up to the nearest power of 10
#         ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

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
#                 plt.ylim(ylim)
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
#         plt.ylim(ylim)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def save_exp_data(exp_data, save_path):
#     """Save experimental data to a pickle file."""
#     with open(save_path, 'wb') as f:
#         pickle.dump(exp_data, f)
#     print(f"Saved experimental data to {save_path}")

# def load_exp_data(load_path):
#     """Load experimental data from a pickle file."""
#     with open(load_path, 'rb') as f:
#         exp_data = pickle.load(f)
#     print(f"Loaded experimental data from {load_path}")
#     return exp_data

# def main(base_dir, fig_dir, ref_data, thresholds, conf_map=False, summary_only=False, save_path=None, load_path=None):
#     if load_path:
#         exp_data = load_exp_data(load_path)
#     else:
#         exp_data = {}
#         #print(f"Checking in figure directory: {fig_dir}")
#         # Loop through directories and load data
#         for dir_name in os.listdir(fig_dir):
#             if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#                 exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#                 exp_data[exp_time] = {}

#                 for threshold in thresholds:
#                     if conf_map:
#                         network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                         for network_dir in network_dirs:
#                             network_name = network_dir.split('-thresh-')[0]

#                             # File paths for various metrics
#                             metrics_files = [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]

#                             for metric in metrics_files:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             if network_name not in exp_data[exp_time]:
#                                                 exp_data[exp_time][network_name] = {}
#                                             exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")
#                     else:
#                         combined_folder = f"All-thresh-{threshold}"
#                         folder_path = os.path.join(fig_dir, dir_name, combined_folder)

#                         if os.path.exists(folder_path):
#                             for metric in [
#                                 'Average_DiceCoefficient',
#                                 'Average_continuousDiceCoefficient',
#                                 'FalseNegative',
#                                 'FalsePositive',
#                                 'NPV',
#                                 'PPV',
#                                 'TrueNegative',
#                                 'TruePositive'
#                             ]:
#                                 for region in ['cortical', 'subcortical', 'whole']:
#                                     file_name = f'{metric}_{region}.txt'
#                                     file_path = os.path.join(folder_path, file_name)

#                                     if os.path.exists(file_path):
#                                         data = load_data(file_path)
#                                         if data is not None:
#                                             # Assume each file contains data for all networks
#                                             for i, net in enumerate([
#                                                 'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 
#                                                 'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']):
#                                                 if exp_time not in exp_data:
#                                                     exp_data[exp_time] = {}
#                                                 if net not in exp_data[exp_time]:
#                                                     exp_data[exp_time][net] = {}
#                                                 exp_data[exp_time][net][f'{metric}_{region}_thresh_{threshold}'] = data[i]
#                                     else:
#                                         print(f"File not found for {dir_name}. Checked path: {file_path}")

#         if save_path:
#             save_exp_data(exp_data, save_path)

#     if exp_data:
#         #print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for metric in [
#                 'Average_DiceCoefficient',
#                 'Average_continuousDiceCoefficient',
#                 'FalseNegative',
#                 'FalsePositive',
#                 'NPV',
#                 'PPV',
#                 'TrueNegative',
#                 'TruePositive'
#             ]:
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
#     parser.add_argument('--ConfMap', action='store_true', help="Use ConfMap mode.")
#     parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
#     parser.add_argument('--save_path', type=str, help="Path to save the experimental data.")
#     parser.add_argument('--load_path', type=str, help="Path to load previously saved experimental data.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.ConfMap, args.summary_only, args.save_path, args.load_path)
## Works but doesn't save/load data
# import os
# import numpy as np
# import matplotlib.pyplot as plt
# import argparse

# def load_data(filepath):
#     """Load data from a text file."""
#     try:
#         data = np.loadtxt(filepath, delimiter=',')
#         #print(f"Loaded data from {filepath} successfully.")
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

#     # Determine ylim based on the maximum data value
#     all_values = [val for data in network_data.values() for val in data if not np.isnan(val)]
#     max_value = max(all_values) if all_values else 1
#     if max_value <= 1:
#         ylim = (0, 1)
#     else:
#         # Round up to the nearest power of 10
#         ylim = (0, 10 ** (int(np.log10(max_value)) + 1))

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
#                 plt.ylim(ylim)
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
#         plt.ylim(ylim)
#         plt.tight_layout()
#         plt.savefig(os.path.join(fig_dir, f'all_networks_{coefficient_type}_line_plot_thresh_{threshold}.png'))
#         plt.close()

# def main(base_dir, fig_dir, ref_data, thresholds, conf_map=False, summary_only=False):
#     exp_data = {}
#     #print(f"Checking in figure directory: {fig_dir}")
#     # Loop through directories and load data
#     for dir_name in os.listdir(fig_dir):
#         if dir_name.startswith('ExpData') and f'to_{ref_data}' in dir_name:
#             exp_time = dir_name.split('_to_')[0]  # Extracts 'ExpData-XXm'
#             exp_data[exp_time] = {}

#             for threshold in thresholds:
#                 if conf_map:
#                     network_dirs = [d for d in os.listdir(os.path.join(fig_dir, dir_name)) if os.path.isdir(os.path.join(fig_dir, dir_name, d)) and f'-thresh-{threshold}' in d]
#                     for network_dir in network_dirs:
#                         network_name = network_dir.split('-thresh-')[0]

#                         # File paths for various metrics
#                         metrics_files = [
#                             'Average_DiceCoefficient',
#                             'Average_continuousDiceCoefficient',
#                             'FalseNegative',
#                             'FalsePositive',
#                             'NPV',
#                             'PPV',
#                             'TrueNegative',
#                             'TruePositive'
#                         ]

#                         for metric in metrics_files:
#                             for region in ['cortical', 'subcortical', 'whole']:
#                                 file_name = f'{metric}_{region}.txt'
#                                 file_path = os.path.join(fig_dir, dir_name, network_dir, file_name)

#                                 if os.path.exists(file_path):
#                                     data = load_data(file_path)
#                                     if data is not None:
#                                         if network_name not in exp_data[exp_time]:
#                                             exp_data[exp_time][network_name] = {}
#                                         exp_data[exp_time][network_name][f'{metric}_{region}_thresh_{threshold}'] = data.item()  # Assuming single value
#                                 else:
#                                     print(f"File not found for {dir_name}. Checked path: {file_path}")
#                 else:
#                     combined_folder = f"All-thresh-{threshold}"
#                     folder_path = os.path.join(fig_dir, dir_name, combined_folder)

#                     if os.path.exists(folder_path):
#                         for metric in [
#                             'Average_DiceCoefficient',
#                             'Average_continuousDiceCoefficient',
#                             'FalseNegative',
#                             'FalsePositive',
#                             'NPV',
#                             'PPV',
#                             'TrueNegative',
#                             'TruePositive'
#                         ]:
#                             for region in ['cortical', 'subcortical', 'whole']:
#                                 file_name = f'{metric}_{region}.txt'
#                                 file_path = os.path.join(folder_path, file_name)

#                                 if os.path.exists(file_path):
#                                     data = load_data(file_path)
#                                     if data is not None:
#                                         # Assume each file contains data for all networks
#                                         for i, net in enumerate([
#                                             'DMN', 'Vis', 'FP', 'DAN', 'VAN', 'Sal', 'CO', 
#                                             'SMd', 'SMl', 'Aud', 'Tpole', 'MTL', 'PMN', 'PON', 'SCAN']):
#                                             if exp_time not in exp_data:
#                                                 exp_data[exp_time] = {}
#                                             if net not in exp_data[exp_time]:
#                                                 exp_data[exp_time][net] = {}
#                                             exp_data[exp_time][net][f'{metric}_{region}_thresh_{threshold}'] = data[i]
#                                 else:
#                                     print(f"File not found for {dir_name}. Checked path: {file_path}")

#     if exp_data:
#         #print("Data loaded for times:", exp_data.keys())
#         for threshold in thresholds:
#             for metric in [
#                 'Average_DiceCoefficient',
#                 'Average_continuousDiceCoefficient',
#                 'FalseNegative',
#                 'FalsePositive',
#                 'NPV',
#                 'PPV',
#                 'TrueNegative',
#                 'TruePositive'
#             ]:
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
#     parser.add_argument('--ConfMap', action='store_true', help="Use ConfMap mode.")
#     parser.add_argument('--summary_only', action='store_true', help="Generate only the summary line plot and skip individual network bar plots.")
#     args = parser.parse_args()

#     main(args.base_dir, args.fig_dir, args.ref_data, args.thresholds, args.ConfMap, args.summary_only)

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