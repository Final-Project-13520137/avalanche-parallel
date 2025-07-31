import matplotlib.pyplot as plt
import pandas as pd
import json
import sys
import os

def create_comparison_graphs(results_file, output_dir):
    with open(results_file, 'r') as f:
        data = json.load(f)
    
    # Convert to DataFrame for easier manipulation
    rows = []
    for result in data:
        test_case = result['TestCase']
        worker_count = result['WorkerCount']
        
        # Microservices data
        micro = result['Microservices']
        rows.append({
            'TestCase': test_case,
            'WorkerCount': worker_count,
            'Architecture': 'Microservices',
            'Throughput': micro['Throughput'],
            'Latency': micro['Latency'],
            'CPU': micro['CPU'],
            'Memory': micro['Memory']
        })
        
        # Monolith data
        mono = result['Monolith']
        rows.append({
            'TestCase': test_case,
            'WorkerCount': worker_count,
            'Architecture': 'Monolith',
            'Throughput': mono['Throughput'],
            'Latency': mono['Latency'],
            'CPU': mono['CPU'],
            'Memory': mono['Memory']
        })
    
    df = pd.DataFrame(rows)
    
    # Set up the plotting style
    plt.style.use('default')
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Microservices vs Monolith Performance Comparison', fontsize=16, fontweight='bold')
    
    # Test cases for subplot titles
    test_cases = df['TestCase'].unique()
    
    for idx, test_case in enumerate(test_cases):
        row = idx // 2
        col = idx % 2
        ax = axes[row, col]
        
        case_data = df[df['TestCase'] == test_case]
        
        # Plot throughput
        micro_data = case_data[case_data['Architecture'] == 'Microservices']
        mono_data = case_data[case_data['Architecture'] == 'Monolith']
        
        ax.plot(micro_data['WorkerCount'], micro_data['Throughput'], 
                'o-', label='Microservices', linewidth=2, markersize=8, color='#2E86AB')
        ax.plot(mono_data['WorkerCount'], mono_data['Throughput'], 
                's-', label='Monolith', linewidth=2, markersize=8, color='#A23B72')
        
        ax.set_xlabel('Worker Count')
        ax.set_ylabel('Throughput (TPS)')
        ax.set_title(f'{test_case}')
        ax.legend()
        ax.grid(True, alpha=0.3)
        
        # Add performance improvement annotation
        if len(micro_data) > 0 and len(mono_data) > 0:
            max_micro = micro_data['Throughput'].max()
            max_mono = mono_data['Throughput'].max()
            improvement = ((max_micro - max_mono) / max_mono) * 100
            ax.text(0.05, 0.95, f'Improvement: {improvement:.1f}%', 
                   transform=ax.transAxes, bbox=dict(boxstyle="round,pad=0.3", 
                   facecolor="yellow", alpha=0.7), fontsize=10)
    
    plt.tight_layout()
    plt.savefig(f'{output_dir}/performance-comparison.png', dpi=300, bbox_inches="tight")
    plt.close()
    
    # Create latency comparison
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Latency Comparison: Microservices vs Monolith', fontsize=16, fontweight='bold')
    
    for idx, test_case in enumerate(test_cases):
        row = idx // 2
        col = idx % 2
        ax = axes[row, col]
        
        case_data = df[df['TestCase'] == test_case]
        micro_data = case_data[case_data['Architecture'] == 'Microservices']
        mono_data = case_data[case_data['Architecture'] == 'Monolith']
        
        ax.plot(micro_data['WorkerCount'], micro_data['Latency'], 
                'o-', label='Microservices', linewidth=2, markersize=8, color='#2E86AB')
        ax.plot(mono_data['WorkerCount'], mono_data['Latency'], 
                's-', label='Monolith', linewidth=2, markersize=8, color='#A23B72')
        
        ax.set_xlabel('Worker Count')
        ax.set_ylabel('Latency (ms)')
        ax.set_title(f'{test_case}')
        ax.legend()
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{output_dir}/latency-comparison.png', dpi=300, bbox_inches="tight")
    plt.close()
    
    # Create resource usage comparison
    fig, axes = plt.subplots(2, 2, figsize=(15, 12))
    fig.suptitle('Resource Usage Comparison', fontsize=16, fontweight='bold')
    
    for idx, test_case in enumerate(test_cases):
        row = idx // 2
        col = idx % 2
        ax = axes[row, col]
        
        case_data = df[df['TestCase'] == test_case]
        micro_data = case_data[case_data['Architecture'] == 'Microservices']
        mono_data = case_data[case_data['Architecture'] == 'Monolith']
        
        # CPU Usage
        ax.plot(micro_data['WorkerCount'], micro_data['CPU'], 
                'o-', label='Microservices CPU', linewidth=2, markersize=8, color='#2E86AB')
        ax.plot(mono_data['WorkerCount'], mono_data['CPU'], 
                's-', label='Monolith CPU', linewidth=2, markersize=8, color='#A23B72')
        
        ax.set_xlabel('Worker Count')
        ax.set_ylabel('CPU Usage (%)')
        ax.set_title(f'{test_case}')
        ax.legend()
        ax.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(f'{output_dir}/resource-usage.png', dpi=300, bbox_inches="tight")
    plt.close()
    
    print(f"Graphs generated in: {output_dir}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python script.py <results_file> <output_dir>")
        sys.exit(1)
    
    results_file = sys.argv[1]
    output_dir = sys.argv[2]
    
    create_comparison_graphs(results_file, output_dir)
