#!/usr/bin/env python3
"""
Avalanche Benchmark Graph Generator
Generates comprehensive performance comparison graphs between microservices and monolith architectures
"""

import argparse
import json
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import numpy as np
import os
from pathlib import Path
import glob
from datetime import datetime

# Set style for better looking plots
plt.style.use('seaborn-v0_8')
sns.set_palette("husl")

class BenchmarkGraphGenerator:
    def __init__(self, results_dir, output_dir):
        self.results_dir = Path(results_dir)
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        
        # Load all benchmark results
        self.results = self.load_results()
        
    def load_results(self):
        """Load all benchmark results from JSON files"""
        results = []
        
        # Load from JSON files
        json_files = glob.glob(str(self.results_dir / "benchmark_results_*.json"))
        for json_file in json_files:
            try:
                with open(json_file, 'r') as f:
                    data = json.load(f)
                    if isinstance(data, list):
                        results.extend(data)
                    else:
                        results.append(data)
            except Exception as e:
                print(f"Warning: Could not load {json_file}: {e}")
        
        # Load from CSV files if JSON not available
        if not results:
            csv_files = glob.glob(str(self.results_dir / "*_comparison_*.csv"))
            for csv_file in csv_files:
                try:
                    df = pd.read_csv(csv_file)
                    # Convert CSV data to results format
                    for _, row in df.iterrows():
                        results.append(self.csv_row_to_result(row, csv_file))
                except Exception as e:
                    print(f"Warning: Could not load {csv_file}: {e}")
        
        return results
    
    def csv_row_to_result(self, row, filename):
        """Convert CSV row to result format"""
        # This is a simplified conversion - adjust based on actual CSV structure
        return {
            'test_case': {'name': row.get('TestCase', 'Unknown')},
            'architecture': row.get('Architecture', 'unknown'),
            'throughput_tps': row.get('TPS', 0),
            'average_latency_ms': row.get('Avg_Latency_ms', 0),
            'cpu_usage_percent': row.get('CPU_Percent', 0),
            'memory_usage_mb': row.get('Memory_MB', 0)
        }
    
    def generate_all_graphs(self):
        """Generate all performance comparison graphs"""
        if not self.results:
            print("No benchmark results found. Please run the benchmark first.")
            return
        
        print("📈 Generating performance comparison graphs...")
        
        # Convert results to DataFrame for easier manipulation
        df = pd.DataFrame(self.results)
        
        # Generate individual graphs
        self.generate_throughput_comparison(df)
        self.generate_latency_comparison(df)
        self.generate_resource_usage_comparison(df)
        self.generate_scalability_analysis(df)
        self.generate_performance_summary(df)
        self.generate_speedup_analysis(df)
        
        print(f"✅ All graphs generated in {self.output_dir}")
    
    def generate_throughput_comparison(self, df):
        """Generate throughput comparison graph"""
        plt.figure(figsize=(12, 8))
        
        # Group by test case and architecture
        grouped = df.groupby(['test_case', 'architecture'])['throughput_tps'].mean().reset_index()
        
        # Pivot for easier plotting
        pivot_df = grouped.pivot(index='test_case', columns='architecture', values='throughput_tps')
        
        # Create bar plot
        ax = pivot_df.plot(kind='bar', figsize=(12, 8), width=0.8)
        plt.title('Throughput Comparison: Microservices vs Monolith', fontsize=16, fontweight='bold')
        plt.xlabel('Test Case', fontsize=12)
        plt.ylabel('Throughput (Transactions per Second)', fontsize=12)
        plt.legend(title='Architecture', fontsize=10)
        plt.xticks(rotation=45, ha='right')
        plt.grid(True, alpha=0.3)
        
        # Add value labels on bars
        for container in ax.containers:
            ax.bar_label(container, fmt='%.1f', fontsize=9)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'throughput_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Throughput comparison graph generated")
    
    def generate_latency_comparison(self, df):
        """Generate latency comparison graph"""
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 6))
        
        # Average Latency
        grouped = df.groupby(['test_case', 'architecture'])['average_latency_ms'].mean().reset_index()
        pivot_df = grouped.pivot(index='test_case', columns='architecture', values='average_latency_ms')
        
        pivot_df.plot(kind='bar', ax=ax1, width=0.8)
        ax1.set_title('Average Latency Comparison', fontsize=14, fontweight='bold')
        ax1.set_xlabel('Test Case')
        ax1.set_ylabel('Average Latency (ms)')
        ax1.legend(title='Architecture')
        ax1.tick_params(axis='x', rotation=45)
        ax1.grid(True, alpha=0.3)
        
        # P95 Latency (if available)
        if 'p95_latency_ms' in df.columns:
            grouped_p95 = df.groupby(['test_case', 'architecture'])['p95_latency_ms'].mean().reset_index()
            pivot_p95 = grouped_p95.pivot(index='test_case', columns='architecture', values='p95_latency_ms')
            
            pivot_p95.plot(kind='bar', ax=ax2, width=0.8)
            ax2.set_title('P95 Latency Comparison', fontsize=14, fontweight='bold')
            ax2.set_xlabel('Test Case')
            ax2.set_ylabel('P95 Latency (ms)')
            ax2.legend(title='Architecture')
            ax2.tick_params(axis='x', rotation=45)
            ax2.grid(True, alpha=0.3)
        else:
            # Create a latency distribution plot instead
            sns.boxplot(data=df, x='test_case', y='average_latency_ms', hue='architecture', ax=ax2)
            ax2.set_title('Latency Distribution', fontsize=14, fontweight='bold')
            ax2.set_xlabel('Test Case')
            ax2.set_ylabel('Latency (ms)')
            ax2.tick_params(axis='x', rotation=45)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'latency_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Latency comparison graph generated")
    
    def generate_resource_usage_comparison(self, df):
        """Generate resource usage comparison graphs"""
        fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(16, 12))
        
        # CPU Usage
        if 'cpu_usage_percent' in df.columns:
            grouped_cpu = df.groupby(['test_case', 'architecture'])['cpu_usage_percent'].mean().reset_index()
            pivot_cpu = grouped_cpu.pivot(index='test_case', columns='architecture', values='cpu_usage_percent')
            pivot_cpu.plot(kind='bar', ax=ax1, width=0.8)
            ax1.set_title('CPU Usage Comparison', fontsize=14, fontweight='bold')
            ax1.set_ylabel('CPU Usage (%)')
            ax1.tick_params(axis='x', rotation=45)
            ax1.grid(True, alpha=0.3)
        
        # Memory Usage
        if 'memory_usage_mb' in df.columns:
            grouped_mem = df.groupby(['test_case', 'architecture'])['memory_usage_mb'].mean().reset_index()
            pivot_mem = grouped_mem.pivot(index='test_case', columns='architecture', values='memory_usage_mb')
            pivot_mem.plot(kind='bar', ax=ax2, width=0.8)
            ax2.set_title('Memory Usage Comparison', fontsize=14, fontweight='bold')
            ax2.set_ylabel('Memory Usage (MB)')
            ax2.tick_params(axis='x', rotation=45)
            ax2.grid(True, alpha=0.3)
        
        # Network Bandwidth
        if 'network_bandwidth_mb' in df.columns:
            grouped_net = df.groupby(['test_case', 'architecture'])['network_bandwidth_mb'].mean().reset_index()
            pivot_net = grouped_net.pivot(index='test_case', columns='architecture', values='network_bandwidth_mb')
            pivot_net.plot(kind='bar', ax=ax3, width=0.8)
            ax3.set_title('Network Bandwidth Usage', fontsize=14, fontweight='bold')
            ax3.set_ylabel('Network Bandwidth (MB/s)')
            ax3.tick_params(axis='x', rotation=45)
            ax3.grid(True, alpha=0.3)
        
        # Error Rate
        if 'error_rate_percent' in df.columns:
            grouped_err = df.groupby(['test_case', 'architecture'])['error_rate_percent'].mean().reset_index()
            pivot_err = grouped_err.pivot(index='test_case', columns='architecture', values='error_rate_percent')
            pivot_err.plot(kind='bar', ax=ax4, width=0.8)
            ax4.set_title('Error Rate Comparison', fontsize=14, fontweight='bold')
            ax4.set_ylabel('Error Rate (%)')
            ax4.tick_params(axis='x', rotation=45)
            ax4.grid(True, alpha=0.3)
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'resource_usage_comparison.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Resource usage comparison graph generated")
    
    def generate_scalability_analysis(self, df):
        """Generate scalability analysis graph"""
        plt.figure(figsize=(14, 8))
        
        # Extract transaction counts for x-axis
        df['transaction_count'] = df['test_case'].str.extract(r'(\d+)K?').astype(float)
        df.loc[df['test_case'].str.contains('K'), 'transaction_count'] *= 1000
        
        # Plot throughput vs transaction count
        for arch in df['architecture'].unique():
            arch_data = df[df['architecture'] == arch]
            grouped = arch_data.groupby('transaction_count')['throughput_tps'].mean()
            plt.plot(grouped.index, grouped.values, marker='o', linewidth=2, 
                    markersize=8, label=f'{arch.title()}')
        
        plt.title('Scalability Analysis: Throughput vs Transaction Count', fontsize=16, fontweight='bold')
        plt.xlabel('Number of Transactions', fontsize=12)
        plt.ylabel('Throughput (TPS)', fontsize=12)
        plt.legend(fontsize=12)
        plt.grid(True, alpha=0.3)
        plt.xscale('log')
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'scalability_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Scalability analysis graph generated")
    
    def generate_speedup_analysis(self, df):
        """Generate speedup factor analysis"""
        plt.figure(figsize=(12, 8))
        
        # Calculate speedup factor (microservices vs monolith)
        speedup_data = []
        
        for test_case in df['test_case'].unique():
            test_data = df[df['test_case'] == test_case]
            micro_tps = test_data[test_data['architecture'] == 'microservices']['throughput_tps'].mean()
            mono_tps = test_data[test_data['architecture'] == 'monolith']['throughput_tps'].mean()
            
            if mono_tps > 0:
                speedup = micro_tps / mono_tps
                speedup_data.append({'test_case': test_case, 'speedup': speedup})
        
        if speedup_data:
            speedup_df = pd.DataFrame(speedup_data)
            
            bars = plt.bar(range(len(speedup_df)), speedup_df['speedup'], 
                          color=['green' if x > 1 else 'red' for x in speedup_df['speedup']])
            
            plt.axhline(y=1, color='black', linestyle='--', alpha=0.7, label='No improvement')
            plt.title('Performance Speedup: Microservices vs Monolith', fontsize=16, fontweight='bold')
            plt.xlabel('Test Case', fontsize=12)
            plt.ylabel('Speedup Factor', fontsize=12)
            plt.xticks(range(len(speedup_df)), speedup_df['test_case'], rotation=45, ha='right')
            
            # Add value labels on bars
            for i, bar in enumerate(bars):
                height = bar.get_height()
                plt.text(bar.get_x() + bar.get_width()/2., height + 0.01,
                        f'{height:.2f}x', ha='center', va='bottom', fontweight='bold')
            
            plt.grid(True, alpha=0.3)
            plt.legend()
        
        plt.tight_layout()
        plt.savefig(self.output_dir / 'speedup_analysis.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Speedup analysis graph generated")
    
    def generate_performance_summary(self, df):
        """Generate comprehensive performance summary dashboard"""
        fig = plt.figure(figsize=(20, 12))
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        # Throughput comparison
        ax1 = fig.add_subplot(gs[0, :2])
        grouped_tps = df.groupby(['test_case', 'architecture'])['throughput_tps'].mean().reset_index()
        pivot_tps = grouped_tps.pivot(index='test_case', columns='architecture', values='throughput_tps')
        pivot_tps.plot(kind='bar', ax=ax1)
        ax1.set_title('Throughput Comparison', fontsize=14, fontweight='bold')
        ax1.set_ylabel('TPS')
        ax1.tick_params(axis='x', rotation=45)
        
        # Latency comparison
        ax2 = fig.add_subplot(gs[0, 2])
        grouped_lat = df.groupby(['test_case', 'architecture'])['average_latency_ms'].mean().reset_index()
        pivot_lat = grouped_lat.pivot(index='test_case', columns='architecture', values='average_latency_ms')
        pivot_lat.plot(kind='bar', ax=ax2)
        ax2.set_title('Average Latency', fontsize=14, fontweight='bold')
        ax2.set_ylabel('ms')
        ax2.tick_params(axis='x', rotation=45)
        
        # CPU Usage
        ax3 = fig.add_subplot(gs[1, 0])
        if 'cpu_usage_percent' in df.columns:
            grouped_cpu = df.groupby(['test_case', 'architecture'])['cpu_usage_percent'].mean().reset_index()
            pivot_cpu = grouped_cpu.pivot(index='test_case', columns='architecture', values='cpu_usage_percent')
            pivot_cpu.plot(kind='bar', ax=ax3)
        ax3.set_title('CPU Usage', fontsize=14, fontweight='bold')
        ax3.set_ylabel('%')
        ax3.tick_params(axis='x', rotation=45)
        
        # Memory Usage
        ax4 = fig.add_subplot(gs[1, 1])
        if 'memory_usage_mb' in df.columns:
            grouped_mem = df.groupby(['test_case', 'architecture'])['memory_usage_mb'].mean().reset_index()
            pivot_mem = grouped_mem.pivot(index='test_case', columns='architecture', values='memory_usage_mb')
            pivot_mem.plot(kind='bar', ax=ax4)
        ax4.set_title('Memory Usage', fontsize=14, fontweight='bold')
        ax4.set_ylabel('MB')
        ax4.tick_params(axis='x', rotation=45)
        
        # Performance Radar Chart
        ax5 = fig.add_subplot(gs[1, 2], projection='polar')
        self.create_radar_chart(df, ax5)
        
        # Summary Statistics Table
        ax6 = fig.add_subplot(gs[2, :])
        ax6.axis('tight')
        ax6.axis('off')
        
        # Create summary table
        summary_data = []
        for arch in df['architecture'].unique():
            arch_data = df[df['architecture'] == arch]
            summary_data.append([
                arch.title(),
                f"{arch_data['throughput_tps'].mean():.1f}",
                f"{arch_data['average_latency_ms'].mean():.1f}",
                f"{arch_data.get('cpu_usage_percent', pd.Series([0])).mean():.1f}%",
                f"{arch_data.get('memory_usage_mb', pd.Series([0])).mean():.1f} MB"
            ])
        
        table = ax6.table(cellText=summary_data,
                         colLabels=['Architecture', 'Avg TPS', 'Avg Latency (ms)', 'Avg CPU %', 'Avg Memory'],
                         cellLoc='center',
                         loc='center')
        table.auto_set_font_size(False)
        table.set_fontsize(12)
        table.scale(1.2, 1.5)
        ax6.set_title('Performance Summary Statistics', fontsize=14, fontweight='bold', pad=20)
        
        plt.suptitle('Avalanche Performance Comparison Dashboard', fontsize=18, fontweight='bold')
        plt.savefig(self.output_dir / 'performance_summary_dashboard.png', dpi=300, bbox_inches='tight')
        plt.close()
        
        print("✅ Performance summary dashboard generated")
    
    def create_radar_chart(self, df, ax):
        """Create radar chart for performance comparison"""
        categories = ['Throughput', 'Low Latency', 'CPU Efficiency', 'Memory Efficiency']
        
        # Normalize metrics for radar chart
        micro_data = df[df['architecture'] == 'microservices']
        mono_data = df[df['architecture'] == 'monolith']
        
        if len(micro_data) > 0 and len(mono_data) > 0:
            # Calculate normalized scores (higher is better)
            micro_scores = [
                micro_data['throughput_tps'].mean() / max(df['throughput_tps'].max(), 1),
                1 - (micro_data['average_latency_ms'].mean() / max(df['average_latency_ms'].max(), 1)),
                1 - (micro_data.get('cpu_usage_percent', pd.Series([50])).mean() / 100),
                1 - (micro_data.get('memory_usage_mb', pd.Series([500])).mean() / max(df.get('memory_usage_mb', pd.Series([1000])).max(), 1))
            ]
            
            mono_scores = [
                mono_data['throughput_tps'].mean() / max(df['throughput_tps'].max(), 1),
                1 - (mono_data['average_latency_ms'].mean() / max(df['average_latency_ms'].max(), 1)),
                1 - (mono_data.get('cpu_usage_percent', pd.Series([70])).mean() / 100),
                1 - (mono_data.get('memory_usage_mb', pd.Series([600])).mean() / max(df.get('memory_usage_mb', pd.Series([1000])).max(), 1))
            ]
            
            # Create radar chart
            angles = np.linspace(0, 2 * np.pi, len(categories), endpoint=False).tolist()
            angles += angles[:1]  # Complete the circle
            
            micro_scores += micro_scores[:1]
            mono_scores += mono_scores[:1]
            
            ax.plot(angles, micro_scores, 'o-', linewidth=2, label='Microservices', color='blue')
            ax.fill(angles, micro_scores, alpha=0.25, color='blue')
            ax.plot(angles, mono_scores, 'o-', linewidth=2, label='Monolith', color='red')
            ax.fill(angles, mono_scores, alpha=0.25, color='red')
            
            ax.set_xticks(angles[:-1])
            ax.set_xticklabels(categories)
            ax.set_ylim(0, 1)
            ax.set_title('Performance Radar', fontsize=14, fontweight='bold')
            ax.legend(loc='upper right', bbox_to_anchor=(1.3, 1.0))

def main():
    parser = argparse.ArgumentParser(description='Generate Avalanche benchmark comparison graphs')
    parser.add_argument('--results-dir', required=True, help='Directory containing benchmark results')
    parser.add_argument('--output-dir', required=True, help='Directory to save generated graphs')
    
    args = parser.parse_args()
    
    # Check if results directory exists
    if not os.path.exists(args.results_dir):
        print(f"Error: Results directory {args.results_dir} does not exist")
        return 1
    
    # Generate graphs
    generator = BenchmarkGraphGenerator(args.results_dir, args.output_dir)
    generator.generate_all_graphs()
    
    print(f"\n🎉 All benchmark graphs generated successfully!")
    print(f"📁 Check the output directory: {args.output_dir}")
    
    return 0

if __name__ == "__main__":
    exit(main()) 