import numpy as np
import matplotlib.pyplot as plt
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

def load_data(filepath):
    """Load data from a text file."""
    try:
        data = np.loadtxt(filepath)
        return data
    except Exception as e:
        print(f"Failed to load data from {filepath}. Error: {e}")
        return None

def plot_bar(mean_values, std_values, output_file, ylabel):
    networks = ['Aud', 'DMN', 'PMN', 'SMd', 'VAN', 'CO', 'FP', 'PON', 
                'SMl', 'Vis', 'DAN', 'MTL', 'Sal', 'Tpole', 'SCAN']
    
    # Ensure the lengths of the data match the number of networks
    assert len(mean_values) == len(networks), "Mean data length does not match the number of networks."
    assert len(std_values) == len(networks), "STD data length does not match the number of networks."
    
    x_positions = range(len(networks))
    bar_colors = [color_map[net] for net in networks]

    plt.figure(figsize=(10, 6))
    plt.bar(x_positions, mean_values, yerr=std_values, color=bar_colors, capsize=5)
    
    plt.xticks(x_positions, networks, rotation=45, ha="right")
    plt.ylabel(ylabel)
    plt.title(f'{ylabel} by Network')
    plt.tight_layout()

    plt.savefig(output_file)
    plt.close()
    print(f"Plot saved as {output_file}")

def main(mean_file, std_file, output_file, ylabel):
    mean_values = load_data(mean_file)
    std_values = load_data(std_file)
    
    if mean_values is not None and std_values is not None:
        plot_bar(mean_values, std_values, output_file, ylabel)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="Generate a bar plot for network values with error bars.")
    parser.add_argument('mean_file', type=str, help="File path for the mean values.")
    parser.add_argument('std_file', type=str, help="File path for the standard deviation values.")
    parser.add_argument('output_file', type=str, help="Output file path for the bar plot (e.g., output.png).")
    parser.add_argument('ylabel', type=str, help="Label for the Y-axis (e.g., 'Average Dice Coefficient Cortex').")
    args = parser.parse_args()

    main(args.mean_file, args.std_file, args.output_file, args.ylabel)