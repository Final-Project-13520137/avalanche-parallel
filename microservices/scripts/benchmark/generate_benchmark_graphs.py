#!/usr/bin/env python3
import os
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import argparse
from datetime import datetime

def setup_style():
    """Set up the plotting style."""
    # Use seaborn-v0_8 style which is compatible with newer matplotlib versions
    try:
        plt.style.use('seaborn-v0_8')
    except OSError:
        # Fallback to default style if seaborn style not available
        plt.style.use('default')
        # Manually set seaborn-like appearance
        plt.rcParams['axes.grid'] = True
        plt.rcParams['grid.alpha'] = 0.3
        plt.rcParams['axes.edgecolor'] = 'gray'
        plt.rcParams['axes.linewidth'] = 0.8
        
    sns.set_palette("husl")
    plt.rcParams['figure.figsize'] = [12, 6]
    plt.rcParams['figure.dpi'] = 100
    plt.rcParams['savefig.dpi'] = 150

def plot_latency_comparison(data, output_dir, timestamp):
    """Plot latency comparison graphs."""
    plt.figure()
    sns.barplot(data=data, x='Transaction Size', y='Latency (ms)')
    plt.title('Transaction Latency Comparison')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'latency_comparison_{timestamp}.png'))
    plt.close()

def plot_throughput_comparison(data, output_dir, timestamp):
    """Plot throughput comparison graphs."""
    plt.figure()
    sns.barplot(data=data, x='Transaction Size', y='Transactions/sec')
    plt.title('Transaction Throughput Comparison')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'throughput_comparison_{timestamp}.png'))
    plt.close()

def plot_resource_usage(data, output_dir, timestamp):
    """Plot resource usage graphs."""
    # CPU Usage
    plt.figure()
    sns.lineplot(data=data, x='Time', y='CPU Usage (%)', hue='Component')
    plt.title('CPU Usage Over Time')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'cpu_usage_{timestamp}.png'))
    plt.close()

    # Memory Usage
    plt.figure()
    sns.lineplot(data=data, x='Time', y='Memory Usage (MB)', hue='Component')
    plt.title('Memory Usage Over Time')
    plt.xticks(rotation=45)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, f'memory_usage_{timestamp}.png'))
    plt.close()

def generate_graphs(results_dir, output_dir):
    """Generate all benchmark graphs."""
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)

    # Get the latest timestamp from CSV files
    csv_files = [f for f in os.listdir(results_dir) if f.endswith('.csv')]
    if not csv_files:
        print("No CSV files found in results directory")
        return

    timestamps = set()
    for file in csv_files:
        if '_20' in file:
            timestamp = file.split('_')[-1].replace('.csv', '')
            timestamps.add(timestamp)

    # Process each timestamp's data
    for timestamp in timestamps:
        print(f"Processing graphs for timestamp: {timestamp}")

        # Load data files
        latency_file = os.path.join(results_dir, f'latency_comparison_{timestamp}.csv')
        throughput_file = os.path.join(results_dir, f'throughput_comparison_{timestamp}.csv')
        resource_file = os.path.join(results_dir, f'resource_usage_{timestamp}.csv')

        if os.path.exists(latency_file):
            latency_data = pd.read_csv(latency_file)
            plot_latency_comparison(latency_data, output_dir, timestamp)

        if os.path.exists(throughput_file):
            throughput_data = pd.read_csv(throughput_file)
            plot_throughput_comparison(throughput_data, output_dir, timestamp)

        if os.path.exists(resource_file):
            resource_data = pd.read_csv(resource_file)
            plot_resource_usage(resource_data, output_dir, timestamp)

def main():
    parser = argparse.ArgumentParser(description='Generate benchmark graphs from CSV data')
    parser.add_argument('--results-dir', required=True, help='Directory containing benchmark CSV files')
    parser.add_argument('--output-dir', required=True, help='Directory to save generated graphs')
    args = parser.parse_args()

    setup_style()
    generate_graphs(args.results_dir, args.output_dir)

if __name__ == '__main__':
    main() 