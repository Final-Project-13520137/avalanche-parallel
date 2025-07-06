import json
import glob
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import os
import sys

# Set style
plt.style.use('seaborn')
sns.set_palette("husl")

def load_metrics(directory):
    data = []
    
    # Load microservices metrics
    for file in glob.glob(os.path.join(directory, "microservices_*.json")):
        with open(file) as f:
            metrics = json.load(f)
            data.append({
                'type': 'Microservices',
                'config': metrics['configuration'],
                'tx_count': metrics['transaction_count'],
                'tps': metrics['throughput_tps'],
                'processed': metrics['processed']['total_processed']
            })
    
    # Load monolithic metrics
    for file in glob.glob(os.path.join(directory, "monolithic_*.json")):
        with open(file) as f:
            metrics = json.load(f)
            data.append({
                'type': 'Monolithic',
                'config': 'N/A',
                'tx_count': metrics['transaction_count'],
                'tps': metrics['throughput_tps'],
                'processed': metrics['processed']['total_processed']
            })
    
    return pd.DataFrame(data)

def plot_throughput_comparison(df, output_dir):
    plt.figure(figsize=(12, 6))
    
    # Plot microservices data
    for config in df[df['type'] == 'Microservices']['config'].unique():
        data = df[(df['type'] == 'Microservices') & (df['config'] == config)]
        plt.plot(data['tx_count'], data['tps'], marker='o', label=f'Micro - {config}')
    
    # Plot monolithic data
    mono_data = df[df['type'] == 'Monolithic']
    plt.plot(mono_data['tx_count'], mono_data['tps'], marker='s', label='Monolithic', linewidth=2)
    
    plt.xlabel('Transaction Count')
    plt.ylabel('Throughput (TPS)')
    plt.title('Throughput Comparison: Microservices vs Monolithic')
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'throughput_comparison.png'))
    plt.close()

def plot_processing_efficiency(df, output_dir):
    plt.figure(figsize=(12, 6))
    
    # Calculate processing efficiency (processed/tx_count)
    df['efficiency'] = df['processed'] / df['tx_count'] * 100
    
    # Plot microservices data
    for config in df[df['type'] == 'Microservices']['config'].unique():
        data = df[(df['type'] == 'Microservices') & (df['config'] == config)]
        plt.plot(data['tx_count'], data['efficiency'], marker='o', label=f'Micro - {config}')
    
    # Plot monolithic data
    mono_data = df[df['type'] == 'Monolithic']
    plt.plot(mono_data['tx_count'], mono_data['efficiency'], marker='s', label='Monolithic', linewidth=2)
    
    plt.xlabel('Transaction Count')
    plt.ylabel('Processing Efficiency (%)')
    plt.title('Processing Efficiency: Microservices vs Monolithic')
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'processing_efficiency.png'))
    plt.close()

def generate_report(df, output_dir):
    report = f"""# Avalanche Architecture Performance Comparison

## Test Results

### Throughput Statistics

{df.groupby(['type', 'config'])['tps'].agg(['mean', 'min', 'max']).round(2).to_markdown()}

### Processing Efficiency

{df.groupby(['type', 'config'])['efficiency'].agg(['mean', 'min', 'max']).round(2).to_markdown()}

## Analysis

1. Throughput Comparison
   - See throughput_comparison.png for detailed visualization
   - Microservices architecture shows {'higher' if df[df['type'] == 'Microservices']['tps'].mean() > df[df['type'] == 'Monolithic']['tps'].mean() else 'lower'} average throughput

2. Processing Efficiency
   - See processing_efficiency.png for detailed visualization
   - Efficiency measured as percentage of transactions successfully processed
   
3. Scaling Characteristics
   - Microservices shows {'better' if df[df['type'] == 'Microservices']['tps'].std() < df[df['type'] == 'Monolithic']['tps'].std() else 'worse'} scaling with increased load
"""
    
    with open(os.path.join(output_dir, 'comparison_report.md'), 'w') as f:
        f.write(report)

def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_graphs.py <metrics_directory>")
        sys.exit(1)
        
    directory = sys.argv[1]
    df = load_metrics(directory)
    plot_throughput_comparison(df, directory)
    plot_processing_efficiency(df, directory)
    generate_report(df, directory)

if __name__ == '__main__':
    main() 