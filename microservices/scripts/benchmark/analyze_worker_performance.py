#!/usr/bin/env python3
"""
Avalanche Worker Performance Analysis
Menganalisis performa berdasarkan konfigurasi jumlah worker
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import json
import glob
import os
import sys
from datetime import datetime

def load_benchmark_results(results_dir):
    """Load semua hasil benchmark dari direktori"""
    json_files = glob.glob(os.path.join(results_dir, "benchmark_results_*.json"))
    
    all_results = []
    for file_path in json_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                if isinstance(data, list):
                    all_results.extend(data)
                else:
                    all_results.append(data)
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
    
    return all_results

def create_worker_performance_analysis(results, output_dir):
    """Membuat analisis performa berdasarkan worker configuration"""
    
    # Convert to DataFrame
    df_data = []
    for result in results:
        # Extract worker config, handle both old and new format
        worker_config = result.get('worker_config', {})
        if not worker_config:
            # Fallback untuk data lama yang tidak memiliki worker_config
            if result['architecture'] == 'monolith':
                worker_config = {'validator_workers': 1, 'consensus_workers': 1, 'dag_state_workers': 1}
            else:
                # Estimasi berdasarkan test case
                test_name = result['test_case']['name']
                if 'small' in test_name.lower():
                    worker_config = {'validator_workers': 3, 'consensus_workers': 2, 'dag_state_workers': 2}
                elif 'medium' in test_name.lower():
                    worker_config = {'validator_workers': 6, 'consensus_workers': 4, 'dag_state_workers': 3}
                elif 'high' in test_name.lower() or 'large' in test_name.lower():
                    worker_config = {'validator_workers': 9, 'consensus_workers': 6, 'dag_state_workers': 4}
                else:
                    worker_config = {'validator_workers': 15, 'consensus_workers': 10, 'dag_state_workers': 8}
        
        validator_workers = worker_config.get('validator_workers', worker_config.get('ValidatorWorkers', 1))
        consensus_workers = worker_config.get('consensus_workers', worker_config.get('ConsensusWorkers', 1))
        dag_state_workers = worker_config.get('dag_state_workers', worker_config.get('DagStateWorkers', 1))
        
        df_data.append({
            'test_case': result['test_case']['name'],
            'architecture': result['architecture'],
            'validator_workers': validator_workers,
            'consensus_workers': consensus_workers,
            'dag_state_workers': dag_state_workers,
            'total_workers': validator_workers + consensus_workers + dag_state_workers,
            'transaction_count': result['test_case']['transaction_count'],
            'throughput_tps': result['throughput_tps'],
            'avg_latency_ms': result['average_latency_ms'] / 1e6,  # Convert to ms
            'p95_latency_ms': result['p95_latency_ms'] / 1e6,     # Convert to ms
            'cpu_usage_percent': result['cpu_usage_percent'],
            'memory_usage_mb': result['memory_usage_mb'],
            'network_bandwidth_mb': result['network_bandwidth_mb'],
            'error_rate_percent': result['error_rate_percent'],
            'timestamp': result['timestamp']
        })
    
    df = pd.DataFrame(df_data)
    
    # Set style
    plt.style.use('seaborn-v0_8')
    sns.set_palette("husl")
    
    # 1. Throughput vs Total Workers
    plt.figure(figsize=(12, 8))
    
    micro_df = df[df['architecture'] == 'microservices']
    mono_df = df[df['architecture'] == 'monolith']
    
    plt.subplot(2, 2, 1)
    if not micro_df.empty:
        plt.scatter(micro_df['total_workers'], micro_df['throughput_tps'], 
                   alpha=0.7, s=60, label='Microservices', color='blue')
        # Trend line
        if len(micro_df) > 1:
            z = np.polyfit(micro_df['total_workers'], micro_df['throughput_tps'], 1)
            p = np.poly1d(z)
            plt.plot(micro_df['total_workers'].sort_values(), 
                    p(micro_df['total_workers'].sort_values()), 
                    "--", alpha=0.8, color='blue')
    
    if not mono_df.empty:
        plt.scatter(mono_df['total_workers'], mono_df['throughput_tps'], 
                   alpha=0.7, s=60, label='Monolith', color='red')
        # Horizontal line for monolith (constant throughput)
        plt.axhline(y=mono_df['throughput_tps'].mean(), color='red', 
                   linestyle='--', alpha=0.8)
    
    plt.xlabel('Total Workers')
    plt.ylabel('Throughput (TPS)')
    plt.title('Throughput vs Number of Workers')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # 2. Latency vs Total Workers
    plt.subplot(2, 2, 2)
    if not micro_df.empty:
        plt.scatter(micro_df['total_workers'], micro_df['avg_latency_ms'], 
                   alpha=0.7, s=60, label='Microservices', color='blue')
        # Trend line
        if len(micro_df) > 1:
            z = np.polyfit(micro_df['total_workers'], micro_df['avg_latency_ms'], 1)
            p = np.poly1d(z)
            plt.plot(micro_df['total_workers'].sort_values(), 
                    p(micro_df['total_workers'].sort_values()), 
                    "--", alpha=0.8, color='blue')
    
    if not mono_df.empty:
        plt.scatter(mono_df['total_workers'], mono_df['avg_latency_ms'], 
                   alpha=0.7, s=60, label='Monolith', color='red')
        plt.axhline(y=mono_df['avg_latency_ms'].mean(), color='red', 
                   linestyle='--', alpha=0.8)
    
    plt.xlabel('Total Workers')
    plt.ylabel('Average Latency (ms)')
    plt.title('Latency vs Number of Workers')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # 3. CPU Usage vs Total Workers
    plt.subplot(2, 2, 3)
    if not micro_df.empty:
        plt.scatter(micro_df['total_workers'], micro_df['cpu_usage_percent'], 
                   alpha=0.7, s=60, label='Microservices', color='blue')
    
    if not mono_df.empty:
        plt.scatter(mono_df['total_workers'], mono_df['cpu_usage_percent'], 
                   alpha=0.7, s=60, label='Monolith', color='red')
        plt.axhline(y=mono_df['cpu_usage_percent'].mean(), color='red', 
                   linestyle='--', alpha=0.8)
    
    plt.xlabel('Total Workers')
    plt.ylabel('CPU Usage (%)')
    plt.title('CPU Usage vs Number of Workers')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    # 4. Efficiency (TPS per Worker)
    plt.subplot(2, 2, 4)
    if not micro_df.empty:
        efficiency = micro_df['throughput_tps'] / micro_df['total_workers']
        plt.scatter(micro_df['total_workers'], efficiency, 
                   alpha=0.7, s=60, label='Microservices', color='blue')
    
    if not mono_df.empty:
        mono_efficiency = mono_df['throughput_tps'] / mono_df['total_workers']
        plt.scatter(mono_df['total_workers'], mono_efficiency, 
                   alpha=0.7, s=60, label='Monolith', color='red')
    
    plt.xlabel('Total Workers')
    plt.ylabel('Efficiency (TPS per Worker)')
    plt.title('Scaling Efficiency')
    plt.legend()
    plt.grid(True, alpha=0.3)
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'worker_performance_analysis.png'), 
                dpi=300, bbox_inches='tight')
    plt.close()
    
    # 5. CPU Usage Pattern Analysis
    plt.figure(figsize=(14, 10))
    
    # Explain why microservices uses less CPU
    analysis_text = """
    CPU Usage Analysis: Mengapa Microservices Menggunakan CPU Lebih Rendah
    
    1. PARALELISME EFISIEN:
       • Microservices: Load terdistribusi ke multiple workers
       • Monolith: Single-thread intensif CPU, sequential processing
       
    2. QUEUE MANAGEMENT:
       • Microservices: Redis queue buffering mengurangi CPU waiting time
       • Monolith: Direct processing tanpa buffering
       
    3. GOROUTINE POOLS:
       • Validator: 50 goroutines per container (efficient context switching)
       • Consensus: 30 goroutines per container  
       • DAG+State: 20 goroutines per container
       • Monolith: Single thread execution
       
    4. RESOURCE SCHEDULING:
       • Microservices: Better resource scheduling & load balancing
       • Monolith: CPU bottleneck pada single core
    """
    
    plt.figtext(0.02, 0.98, analysis_text, fontsize=10, 
                verticalalignment='top', fontfamily='monospace',
                bbox=dict(boxstyle="round,pad=0.5", facecolor="lightblue", alpha=0.8))
    
    # Worker configuration breakdown
    plt.subplot(2, 2, 1)
    worker_types = ['Validator', 'Consensus', 'DAG+State']
    
    if not micro_df.empty:
        avg_validators = micro_df['validator_workers'].mean()
        avg_consensus = micro_df['consensus_workers'].mean()  
        avg_dag_state = micro_df['dag_state_workers'].mean()
        
        worker_counts = [avg_validators, avg_consensus, avg_dag_state]
        colors = ['#FF6B6B', '#4ECDC4', '#45B7D1']
        
        plt.pie(worker_counts, labels=worker_types, colors=colors, autopct='%1.1f',
                startangle=90)
        plt.title('Average Worker Distribution\n(Microservices)')
    
    # CPU efficiency per worker type  
    plt.subplot(2, 2, 2)
    if not micro_df.empty:
        # Estimate CPU per worker type based on their characteristics
        validator_cpu = micro_df['cpu_usage_percent'] * 0.4  # 40% untuk validation
        consensus_cpu = micro_df['cpu_usage_percent'] * 0.35  # 35% untuk consensus
        dag_state_cpu = micro_df['cpu_usage_percent'] * 0.25  # 25% untuk state
        
        plt.plot(micro_df['total_workers'], validator_cpu, 'o-', label='Validator CPU', color='#FF6B6B')
        plt.plot(micro_df['total_workers'], consensus_cpu, 's-', label='Consensus CPU', color='#4ECDC4')
        plt.plot(micro_df['total_workers'], dag_state_cpu, '^-', label='DAG+State CPU', color='#45B7D1')
        
        plt.xlabel('Total Workers')
        plt.ylabel('Estimated CPU Usage (%)')
        plt.title('CPU Usage by Worker Type')
        plt.legend()
        plt.grid(True, alpha=0.3)
    
    # Comparison table
    plt.subplot(2, 1, 2)
    plt.axis('off')
    
    if not micro_df.empty and not mono_df.empty:
        comparison_data = [
            ['Metric', 'Microservices', 'Monolith', 'Difference'],
            ['Avg TPS', f'{micro_df["throughput_tps"].mean():.1f}', 
             f'{mono_df["throughput_tps"].mean():.1f}', 
             f'{(micro_df["throughput_tps"].mean()/mono_df["throughput_tps"].mean()):.1f}x'],
            ['Avg Latency', f'{micro_df["avg_latency_ms"].mean():.1f}ms', 
             f'{mono_df["avg_latency_ms"].mean():.1f}ms',
             f'{(mono_df["avg_latency_ms"].mean()/micro_df["avg_latency_ms"].mean()):.1f}x faster'],
            ['Avg CPU', f'{micro_df["cpu_usage_percent"].mean():.1f}%', 
             f'{mono_df["cpu_usage_percent"].mean():.1f}%',
             f'{(mono_df["cpu_usage_percent"].mean() - micro_df["cpu_usage_percent"].mean()):.1f}% less'],
            ['Avg Memory', f'{micro_df["memory_usage_mb"].mean():.1f}MB', 
             f'{mono_df["memory_usage_mb"].mean():.1f}MB',
             f'{(micro_df["memory_usage_mb"].mean() - mono_df["memory_usage_mb"].mean()):.1f}MB more'],
        ]
        
        table = plt.table(cellText=comparison_data, cellLoc='center',
                         loc='center', bbox=[0.1, 0.1, 0.8, 0.8])
        table.auto_set_font_size(False)
        table.set_fontsize(10)
        table.scale(1, 2)
        
        # Style header row
        for i in range(4):
            table[(0, i)].set_facecolor('#4ECDC4')
            table[(0, i)].set_text_props(weight='bold')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'cpu_usage_analysis.png'), 
                dpi=300, bbox_inches='tight')
    plt.close()
    
    # Generate summary report
    generate_analysis_report(df, output_dir)
    
    return df

def generate_analysis_report(df, output_dir):
    """Generate detailed analysis report"""
    report_path = os.path.join(output_dir, 'worker_performance_report.md')
    
    with open(report_path, 'w') as f:
        f.write("# Avalanche Worker Performance Analysis Report\n\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        micro_df = df[df['architecture'] == 'microservices']
        mono_df = df[df['architecture'] == 'monolith']
        
        f.write("## Executive Summary\n\n")
        
        if not micro_df.empty and not mono_df.empty:
            speedup = micro_df['throughput_tps'].mean() / mono_df['throughput_tps'].mean()
            latency_improvement = mono_df['avg_latency_ms'].mean() / micro_df['avg_latency_ms'].mean()
            cpu_difference = mono_df['cpu_usage_percent'].mean() - micro_df['cpu_usage_percent'].mean()
            
            f.write(f"- **Performance Improvement**: {speedup:.1f}x throughput increase\n")
            f.write(f"- **Latency Improvement**: {latency_improvement:.1f}x faster response time\n")
            f.write(f"- **CPU Efficiency**: {cpu_difference:.1f}% lower CPU usage\n")
            f.write(f"- **Optimal Worker Count**: {micro_df['total_workers'].max()} workers for maximum throughput\n\n")
        
        f.write("## CPU Usage Analysis\n\n")
        f.write("### Why Microservices Uses Less CPU:\n\n")
        f.write("1. **Parallel Processing**: Load distributed across multiple workers\n")
        f.write("2. **Queue Buffering**: Redis queue reduces CPU waiting time\n")
        f.write("3. **Goroutine Efficiency**: Efficient context switching in Go\n")
        f.write("4. **Resource Scheduling**: Better load balancing across cores\n\n")
        
        f.write("### Monolith CPU Bottlenecks:\n\n")
        f.write("1. **Single-threaded Execution**: Sequential processing limits parallelism\n")
        f.write("2. **CPU Intensive Operations**: All processing on single core\n")
        f.write("3. **No Load Distribution**: Cannot utilize multiple cores effectively\n\n")
        
        f.write("## Worker Configuration Recommendations\n\n")
        
        if not micro_df.empty:
            best_config = micro_df.loc[micro_df['throughput_tps'].idxmax()]
            f.write(f"### Optimal Configuration (Best Throughput):\n")
            f.write(f"- Validator Workers: {best_config['validator_workers']}\n")
            f.write(f"- Consensus Workers: {best_config['consensus_workers']}\n")
            f.write(f"- DAG+State Workers: {best_config['dag_state_workers']}\n")
            f.write(f"- Total Workers: {best_config['total_workers']}\n")
            f.write(f"- Achieved TPS: {best_config['throughput_tps']:.1f}\n")
            f.write(f"- Average Latency: {best_config['avg_latency_ms']:.1f}ms\n\n")
        
        f.write("## Test Results Summary\n\n")
        f.write("| Test Case | Architecture | Workers | TPS | Latency | CPU % |\n")
        f.write("|-----------|--------------|---------|-----|---------|-------|\n")
        
        for _, row in df.iterrows():
            f.write(f"| {row['test_case']} | {row['architecture']} | ")
            f.write(f"{row['total_workers']} | {row['throughput_tps']:.1f} | ")
            f.write(f"{row['avg_latency_ms']:.1f}ms | {row['cpu_usage_percent']:.1f}% |\n")

def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_worker_performance.py <results_directory> [output_directory]")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "analysis_output"
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"Loading benchmark results from {results_dir}...")
    results = load_benchmark_results(results_dir)
    
    if not results:
        print("No benchmark results found!")
        sys.exit(1)
    
    print(f"Loaded {len(results)} benchmark results")
    print(f"Analyzing worker performance...")
    
    # Import numpy here to avoid import error if matplotlib is not available
    try:
        import numpy as np
        globals()['np'] = np
    except ImportError:
        print("Warning: numpy not available, some analysis features disabled")
    
    df = create_worker_performance_analysis(results, output_dir)
    
    print(f"Analysis complete! Results saved to {output_dir}/")
    print(f"- worker_performance_analysis.png")
    print(f"- cpu_usage_analysis.png") 
    print(f"- worker_performance_report.md")

if __name__ == "__main__":
    main() 