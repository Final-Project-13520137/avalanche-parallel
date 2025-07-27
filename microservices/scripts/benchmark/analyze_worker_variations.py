#!/usr/bin/env python3
"""
Avalanche Worker Variation Analysis
Menganalisis performa benchmark dengan berbagai konfigurasi worker
"""

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import json
import glob
import os
import sys
from datetime import datetime
import numpy as np

def load_worker_variation_results(results_dir):
    """Load hasil benchmark dengan variasi worker"""
    json_files = glob.glob(os.path.join(results_dir, "benchmark_results_*.json"))
    
    all_results = []
    for file_path in json_files:
        try:
            with open(file_path, 'r') as f:
                data = json.load(f)
                if isinstance(data, list):
                    # Filter only results with worker configuration
                    for result in data:
                        if 'worker_config' in result or '_Workers_' in result.get('test_case', {}).get('name', ''):
                            all_results.append(result)
                else:
                    if 'worker_config' in data or '_Workers_' in data.get('test_case', {}).get('name', ''):
                        all_results.append(data)
        except Exception as e:
            print(f"Error loading {file_path}: {e}")
    
    return all_results

def create_worker_variation_analysis(results, output_dir):
    """Analisis komprehensif variasi worker"""
    
    # Convert to DataFrame
    df_data = []
    for result in results:
        # Extract worker config
        worker_config = result.get('worker_config', {})
        if not worker_config:
            # Parse dari nama test case jika tidak ada worker_config
            test_name = result['test_case']['name']
            if '_Workers_' in test_name:
                parts = test_name.split('_Workers_')[1].split('_')
                if len(parts) >= 3:
                    worker_config = {
                        'validator_workers': int(parts[0]),
                        'consensus_workers': int(parts[1]),
                        'dag_state_workers': int(parts[2])
                    }
        
        if not worker_config:
            continue
            
        validator_workers = worker_config.get('validator_workers', worker_config.get('ValidatorWorkers', 1))
        consensus_workers = worker_config.get('consensus_workers', worker_config.get('ConsensusWorkers', 1))
        dag_state_workers = worker_config.get('dag_state_workers', worker_config.get('DagStateWorkers', 1))
        
        # Extract base test scenario
        test_name = result['test_case']['name']
        base_scenario = test_name.split('_Workers_')[0] if '_Workers_' in test_name else test_name
        
        df_data.append({
            'test_scenario': base_scenario,
            'architecture': result['architecture'],
            'validator_workers': validator_workers,
            'consensus_workers': consensus_workers,
            'dag_state_workers': dag_state_workers,
            'total_workers': validator_workers + consensus_workers + dag_state_workers,
            'transaction_count': result['test_case']['transaction_count'],
            'throughput_tps': result['throughput_tps'],
            'avg_latency_ms': result['average_latency_ms'] / 1e6,
            'p95_latency_ms': result['p95_latency_ms'] / 1e6,
            'cpu_usage_percent': result['cpu_usage_percent'],
            'memory_usage_mb': result['memory_usage_mb'],
            'network_bandwidth_mb': result['network_bandwidth_mb'],
            'error_rate_percent': result['error_rate_percent'],
            'timestamp': result['timestamp']
        })
    
    if not df_data:
        print("No worker variation data found!")
        return None
        
    df = pd.DataFrame(df_data)
    
    # Create comprehensive analysis
    plt.style.use('seaborn-v0_8')
    
    # 1. Worker Scaling Analysis
    plt.figure(figsize=(16, 12))
    
    # Throughput vs Total Workers by Scenario
    plt.subplot(2, 3, 1)
    microservices_df = df[df['architecture'] == 'microservices']
    monolith_df = df[df['architecture'] == 'monolith']
    
    scenarios = microservices_df['test_scenario'].unique()
    colors = plt.cm.Set3(np.linspace(0, 1, len(scenarios)))
    
    for i, scenario in enumerate(scenarios):
        scenario_data = microservices_df[microservices_df['test_scenario'] == scenario]
        if not scenario_data.empty:
            plt.scatter(scenario_data['total_workers'], scenario_data['throughput_tps'], 
                       alpha=0.8, s=80, label=f'{scenario}', color=colors[i])
            
            # Trend line
            if len(scenario_data) > 1:
                z = np.polyfit(scenario_data['total_workers'], scenario_data['throughput_tps'], 1)
                p = np.poly1d(z)
                plt.plot(scenario_data['total_workers'].sort_values(), 
                        p(scenario_data['total_workers'].sort_values()), 
                        "--", alpha=0.7, color=colors[i])
    
    # Add monolith baseline
    if not monolith_df.empty:
        plt.axhline(y=monolith_df['throughput_tps'].mean(), color='red', 
                   linestyle='-', alpha=0.8, linewidth=2, label='Monolith Baseline')
    
    plt.xlabel('Total Workers')
    plt.ylabel('Throughput (TPS)')
    plt.title('Throughput Scaling by Scenario')
    plt.legend(bbox_to_anchor=(1.05, 1), loc='upper left')
    plt.grid(True, alpha=0.3)
    
    # 2. Latency vs Workers
    plt.subplot(2, 3, 2)
    for i, scenario in enumerate(scenarios):
        scenario_data = microservices_df[microservices_df['test_scenario'] == scenario]
        if not scenario_data.empty:
            plt.scatter(scenario_data['total_workers'], scenario_data['avg_latency_ms'], 
                       alpha=0.8, s=80, label=f'{scenario}', color=colors[i])
    
    if not monolith_df.empty:
        plt.axhline(y=monolith_df['avg_latency_ms'].mean(), color='red', 
                   linestyle='-', alpha=0.8, linewidth=2, label='Monolith Baseline')
    
    plt.xlabel('Total Workers')
    plt.ylabel('Average Latency (ms)')
    plt.title('Latency vs Workers')
    plt.grid(True, alpha=0.3)
    
    # 3. CPU Efficiency
    plt.subplot(2, 3, 3)
    for i, scenario in enumerate(scenarios):
        scenario_data = microservices_df[microservices_df['test_scenario'] == scenario]
        if not scenario_data.empty:
            plt.scatter(scenario_data['total_workers'], scenario_data['cpu_usage_percent'], 
                       alpha=0.8, s=80, label=f'{scenario}', color=colors[i])
    
    if not monolith_df.empty:
        plt.axhline(y=monolith_df['cpu_usage_percent'].mean(), color='red', 
                   linestyle='-', alpha=0.8, linewidth=2, label='Monolith Baseline')
    
    plt.xlabel('Total Workers')
    plt.ylabel('CPU Usage (%)')
    plt.title('CPU Usage vs Workers')
    plt.grid(True, alpha=0.3)
    
    # 4. Validator Worker Impact
    plt.subplot(2, 3, 4)
    validator_impact = microservices_df.groupby('validator_workers').agg({
        'throughput_tps': 'mean',
        'avg_latency_ms': 'mean',
        'cpu_usage_percent': 'mean'
    }).reset_index()
    
    plt.plot(validator_impact['validator_workers'], validator_impact['throughput_tps'], 
             'o-', linewidth=2, markersize=8, label='Throughput (TPS)', color='blue')
    plt.xlabel('Validator Workers')
    plt.ylabel('Average Throughput (TPS)')
    plt.title('Validator Worker Impact on Throughput')
    plt.grid(True, alpha=0.3)
    
    # 5. Scaling Efficiency
    plt.subplot(2, 3, 5)
    efficiency_data = microservices_df.copy()
    efficiency_data['efficiency'] = efficiency_data['throughput_tps'] / efficiency_data['total_workers']
    
    plt.scatter(efficiency_data['total_workers'], efficiency_data['efficiency'], 
               alpha=0.7, s=60, c=efficiency_data['validator_workers'], 
               cmap='viridis')
    plt.colorbar(label='Validator Workers')
    plt.xlabel('Total Workers')
    plt.ylabel('Efficiency (TPS per Worker)')
    plt.title('Scaling Efficiency')
    plt.grid(True, alpha=0.3)
    
    # 6. Worker Configuration Heatmap
    plt.subplot(2, 3, 6)
    
    # Create pivot table for heatmap
    heatmap_data = microservices_df.pivot_table(
        values='throughput_tps', 
        index='validator_workers', 
        columns='consensus_workers', 
        aggfunc='mean'
    )
    
    sns.heatmap(heatmap_data, annot=True, fmt='.0f', cmap='YlOrRd', 
                cbar_kws={'label': 'Throughput (TPS)'})
    plt.title('Throughput Heatmap\n(Validator vs Consensus Workers)')
    plt.xlabel('Consensus Workers')
    plt.ylabel('Validator Workers')
    
    plt.tight_layout()
    plt.savefig(os.path.join(output_dir, 'worker_variation_analysis.png'), 
                dpi=300, bbox_inches='tight')
    plt.close()
    
    # Create detailed comparison table
    create_worker_comparison_table(df, output_dir)
    
    # Generate comprehensive report
    generate_worker_variation_report(df, output_dir)
    
    return df

def create_worker_comparison_table(df, output_dir):
    """Create detailed comparison table"""
    plt.figure(figsize=(14, 10))
    
    microservices_df = df[df['architecture'] == 'microservices']
    monolith_df = df[df['architecture'] == 'monolith']
    
    # Group by worker configuration
    worker_configs = microservices_df.groupby(['validator_workers', 'consensus_workers', 'dag_state_workers']).agg({
        'throughput_tps': 'mean',
        'avg_latency_ms': 'mean',
        'cpu_usage_percent': 'mean',
        'memory_usage_mb': 'mean',
        'test_scenario': 'count'  # Number of test scenarios for this config
    }).round(2).reset_index()
    
    # Create comparison with monolith baseline
    if not monolith_df.empty:
        monolith_avg_tps = monolith_df['throughput_tps'].mean()
        monolith_avg_latency = monolith_df['avg_latency_ms'].mean()
        monolith_avg_cpu = monolith_df['cpu_usage_percent'].mean()
        
        worker_configs['speedup_factor'] = (worker_configs['throughput_tps'] / monolith_avg_tps).round(2)
        worker_configs['latency_improvement'] = (monolith_avg_latency / worker_configs['avg_latency_ms']).round(2)
        worker_configs['cpu_efficiency'] = (monolith_avg_cpu - worker_configs['cpu_usage_percent']).round(1)
    
    # Display as table
    plt.axis('off')
    
    table_data = []
    headers = ['Config (V,C,D)', 'Total', 'TPS', 'Latency (ms)', 'CPU %', 'Speedup', 'Lat. Improve', 'CPU Saved']
    
    for _, row in worker_configs.iterrows():
        config_str = f"({int(row['validator_workers'])},{int(row['consensus_workers'])},{int(row['dag_state_workers'])})"
        total_workers = int(row['validator_workers'] + row['consensus_workers'] + row['dag_state_workers'])
        
        table_row = [
            config_str,
            str(total_workers),
            f"{row['throughput_tps']:.0f}",
            f"{row['avg_latency_ms']:.1f}",
            f"{row['cpu_usage_percent']:.1f}",
            f"{row.get('speedup_factor', 'N/A')}x" if 'speedup_factor' in row else 'N/A',
            f"{row.get('latency_improvement', 'N/A')}x" if 'latency_improvement' in row else 'N/A',
            f"{row.get('cpu_efficiency', 'N/A')}%" if 'cpu_efficiency' in row else 'N/A'
        ]
        table_data.append(table_row)
    
    table = plt.table(cellText=table_data, colLabels=headers, cellLoc='center',
                     loc='center', bbox=[0.1, 0.1, 0.8, 0.8])
    table.auto_set_font_size(False)
    table.set_fontsize(10)
    table.scale(1, 2)
    
    # Style header row
    for i in range(len(headers)):
        table[(0, i)].set_facecolor('#4ECDC4')
        table[(0, i)].set_text_props(weight='bold')
    
    # Color code based on performance
    for i, row in enumerate(table_data, 1):
        try:
            speedup = float(row[5].replace('x', '')) if row[5] != 'N/A' else 0
            if speedup > 5:
                for j in range(len(headers)):
                    table[(i, j)].set_facecolor('#E8F5E8')  # Light green
            elif speedup > 3:
                for j in range(len(headers)):
                    table[(i, j)].set_facecolor('#FFF3E0')  # Light orange
        except:
            pass
    
    plt.title('Worker Configuration Performance Comparison', fontsize=16, fontweight='bold', pad=20)
    plt.savefig(os.path.join(output_dir, 'worker_configuration_table.png'), 
                dpi=300, bbox_inches='tight')
    plt.close()

def generate_worker_variation_report(df, output_dir):
    """Generate detailed worker variation report"""
    report_path = os.path.join(output_dir, 'worker_variation_report.md')
    
    microservices_df = df[df['architecture'] == 'microservices']
    monolith_df = df[df['architecture'] == 'monolith']
    
    with open(report_path, 'w') as f:
        f.write("# Avalanche Worker Variation Analysis Report\n\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
        
        f.write("## Executive Summary\n\n")
        
        if not microservices_df.empty and not monolith_df.empty:
            # Find best performing configuration
            best_config = microservices_df.loc[microservices_df['throughput_tps'].idxmax()]
            worst_config = microservices_df.loc[microservices_df['throughput_tps'].idxmin()]
            
            monolith_avg_tps = monolith_df['throughput_tps'].mean()
            best_speedup = best_config['throughput_tps'] / monolith_avg_tps
            
            f.write(f"- **Best Configuration**: {best_config['validator_workers']}V, {best_config['consensus_workers']}C, {best_config['dag_state_workers']}D\n")
            f.write(f"- **Best Performance**: {best_config['throughput_tps']:.1f} TPS ({best_speedup:.1f}x speedup)\n")
            f.write(f"- **Worst Configuration**: {worst_config['validator_workers']}V, {worst_config['consensus_workers']}C, {worst_config['dag_state_workers']}D\n")
            f.write(f"- **Performance Range**: {worst_config['throughput_tps']:.1f} - {best_config['throughput_tps']:.1f} TPS\n\n")
        
        f.write("## Worker Configuration Analysis\n\n")
        
        # Validator worker impact
        validator_impact = microservices_df.groupby('validator_workers')['throughput_tps'].mean()
        f.write("### Validator Worker Impact:\n")
        for workers, tps in validator_impact.items():
            f.write(f"- {workers} Validator Workers: {tps:.1f} TPS average\n")
        f.write("\n")
        
        # Consensus worker impact
        consensus_impact = microservices_df.groupby('consensus_workers')['throughput_tps'].mean()
        f.write("### Consensus Worker Impact:\n")
        for workers, tps in consensus_impact.items():
            f.write(f"- {workers} Consensus Workers: {tps:.1f} TPS average\n")
        f.write("\n")
        
        # DAG State worker impact
        dag_impact = microservices_df.groupby('dag_state_workers')['throughput_tps'].mean()
        f.write("### DAG State Worker Impact:\n")
        for workers, tps in dag_impact.items():
            f.write(f"- {workers} DAG State Workers: {tps:.1f} TPS average\n")
        f.write("\n")
        
        f.write("## Scaling Patterns\n\n")
        
        # Scaling efficiency analysis
        efficiency_data = microservices_df.copy()
        efficiency_data['efficiency'] = efficiency_data['throughput_tps'] / efficiency_data['total_workers']
        
        max_efficiency = efficiency_data.loc[efficiency_data['efficiency'].idxmax()]
        min_efficiency = efficiency_data.loc[efficiency_data['efficiency'].idxmin()]
        
        f.write(f"### Efficiency Analysis:\n")
        f.write(f"- **Most Efficient**: {max_efficiency['validator_workers']}V,{max_efficiency['consensus_workers']}C,{max_efficiency['dag_state_workers']}D ({max_efficiency['efficiency']:.1f} TPS/worker)\n")
        f.write(f"- **Least Efficient**: {min_efficiency['validator_workers']}V,{min_efficiency['consensus_workers']}C,{min_efficiency['dag_state_workers']}D ({min_efficiency['efficiency']:.1f} TPS/worker)\n\n")
        
        f.write("## Recommendations\n\n")
        
        if not microservices_df.empty:
            # Find sweet spot (good performance with reasonable resource usage)
            sweet_spot = microservices_df[
                (microservices_df['total_workers'] <= 15) & 
                (microservices_df['cpu_usage_percent'] <= 80)
            ]
            
            if not sweet_spot.empty:
                optimal = sweet_spot.loc[sweet_spot['throughput_tps'].idxmax()]
                f.write(f"### Recommended Configuration:\n")
                f.write(f"- **Configuration**: {optimal['validator_workers']} Validator, {optimal['consensus_workers']} Consensus, {optimal['dag_state_workers']} DAG State workers\n")
                f.write(f"- **Performance**: {optimal['throughput_tps']:.1f} TPS\n")
                f.write(f"- **Resource Usage**: {optimal['cpu_usage_percent']:.1f}% CPU, {optimal['memory_usage_mb']:.1f} MB Memory\n")
                f.write(f"- **Efficiency**: {optimal['throughput_tps']/optimal['total_workers']:.1f} TPS per worker\n\n")
        
        f.write("## Test Results Details\n\n")
        f.write("| Configuration | Total Workers | TPS | Latency (ms) | CPU % | Memory (MB) | Efficiency |\n")
        f.write("|---------------|---------------|-----|--------------|-------|-------------|------------|\n")
        
        for _, row in microservices_df.iterrows():
            config = f"{row['validator_workers']}V,{row['consensus_workers']}C,{row['dag_state_workers']}D"
            efficiency = row['throughput_tps'] / row['total_workers']
            f.write(f"| {config} | {row['total_workers']} | {row['throughput_tps']:.1f} | {row['avg_latency_ms']:.1f} | {row['cpu_usage_percent']:.1f} | {row['memory_usage_mb']:.1f} | {efficiency:.1f} |\n")

def main():
    if len(sys.argv) < 2:
        print("Usage: python analyze_worker_variations.py <results_directory> [output_directory]")
        sys.exit(1)
    
    results_dir = sys.argv[1]
    output_dir = sys.argv[2] if len(sys.argv) > 2 else "worker_variation_analysis"
    
    # Create output directory
    os.makedirs(output_dir, exist_ok=True)
    
    print(f"Loading worker variation results from {results_dir}...")
    results = load_worker_variation_results(results_dir)
    
    if not results:
        print("No worker variation results found!")
        sys.exit(1)
    
    print(f"Loaded {len(results)} worker variation results")
    print(f"Analyzing worker variations...")
    
    df = create_worker_variation_analysis(results, output_dir)
    
    if df is not None:
        print(f"Analysis complete! Results saved to {output_dir}/")
        print(f"- worker_variation_analysis.png")
        print(f"- worker_configuration_table.png")
        print(f"- worker_variation_report.md")
        
        # Print summary
        microservices_df = df[df['architecture'] == 'microservices']
        if not microservices_df.empty:
            print(f"\nWorker configurations tested: {len(microservices_df['total_workers'].unique())}")
            print(f"Performance range: {microservices_df['throughput_tps'].min():.1f} - {microservices_df['throughput_tps'].max():.1f} TPS")
    else:
        print("No analysis could be performed.")

if __name__ == "__main__":
    main() 