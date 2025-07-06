#!/bin/bash

# Avalanche Performance Comparison Benchmark
# Compares performance between monolithic and microservices architectures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"
BENCHMARK_DIR="$ROOT_DIR/benchmark-results"
MICROSERVICES_DIR="$ROOT_DIR/microservices"
DEFAULT_DIR="$ROOT_DIR/default"

# Benchmark settings
TRANSACTION_COUNTS=(1000 5000 10000 20000)
WORKER_CONFIGURATIONS=(
    "consensus:2,validator:3,dag-state:2"
    "consensus:4,validator:6,dag-state:3"
    "consensus:6,validator:9,dag-state:4"
    "consensus:8,validator:12,dag-state:6"
    "consensus:10,validator:15,dag-state:8"
)
DURATION=120 # seconds
WARMUP_TIME=30 # seconds

# Function to print colored output
print_step() {
    echo -e "${BLUE}📋 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Setup environment
setup_environment() {
    print_step "Setting up benchmark environment..."
    
    # Create benchmark results directory
    mkdir -p "$BENCHMARK_DIR"
    
    # Generate timestamp for this benchmark run
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    export BENCHMARK_TIMESTAMP="$TIMESTAMP"
    
    # Create benchmark working directory
    mkdir -p "$BENCHMARK_DIR/comparison-$TIMESTAMP"
    
    print_success "Environment setup completed"
}

# Run microservices benchmark
run_microservices_benchmark() {
    local tx_count=$1
    local config=$2
    
    print_step "Running microservices benchmark with $tx_count transactions and config $config"
    
    # Start microservices with worker configuration
    cd "$MICROSERVICES_DIR"
    ./scripts/benchmark/worker-pool-benchmark.sh test "$config" "$tx_count"
    
    # Collect metrics
    local metrics_file="$BENCHMARK_DIR/comparison-$TIMESTAMP/microservices_${config//[,:]/_}_${tx_count}.json"
    cp "$BENCHMARK_DIR/worker-pool-$TIMESTAMP/metrics_${config//[,:]/_}_${tx_count}.json" "$metrics_file"
    
    print_success "Microservices benchmark completed"
}

# Run monolithic benchmark
run_monolithic_benchmark() {
    local tx_count=$1
    
    print_step "Running monolithic benchmark with $tx_count transactions"
    
    # Start monolithic Avalanche node
    cd "$DEFAULT_DIR"
    ./build/avalanchego --network-id=local --staking-enabled=false &
    MONOLITHIC_PID=$!
    
    # Wait for node to start
    sleep $WARMUP_TIME
    
    # Generate and send transactions
    local start_time=$(date +%s.%N)
    
    # Use avalanche-cli to send transactions
    avalanche-cli transaction generate --count "$tx_count" --chain-id="11111111111111111111111111111111LpoYY"
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Collect metrics
    local processed_tx=$(curl -s -X POST -H 'Content-Type: application/json' \
        --data '{"jsonrpc":"2.0","id":1,"method":"platform.getTxStatus","params":[]}' \
        http://localhost:9650/ext/P | jq -r '.result.processed')
    
    local tps=$(echo "scale=2; $processed_tx / $duration" | bc -l)
    
    # Save metrics
    local metrics_file="$BENCHMARK_DIR/comparison-$TIMESTAMP/monolithic_${tx_count}.json"
    cat > "$metrics_file" << EOF
{
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "transaction_count": $tx_count,
    "duration": $duration,
    "throughput_tps": $tps,
    "processed": {
        "total_processed": $processed_tx
    }
}
EOF
    
    # Stop monolithic node
    kill $MONOLITHIC_PID
    wait $MONOLITHIC_PID 2>/dev/null || true
    
    print_success "Monolithic benchmark completed: ${tps} TPS"
}

# Generate comparison graphs
generate_graphs() {
    print_step "Generating comparison graphs..."
    
    # Create Python script for graph generation
    cat > "$BENCHMARK_DIR/comparison-$TIMESTAMP/generate_graphs.py" << 'EOF'
import json
import glob
import matplotlib.pyplot as plt
import seaborn as sns
import pandas as pd
import os

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
    directory = os.path.dirname(os.path.abspath(__file__))
    df = load_metrics(directory)
    plot_throughput_comparison(df, directory)
    plot_processing_efficiency(df, directory)
    generate_report(df, directory)

if __name__ == '__main__':
    main()
EOF
    
    # Install required Python packages
    pip install matplotlib seaborn pandas
    
    # Run graph generation script
    python "$BENCHMARK_DIR/comparison-$TIMESTAMP/generate_graphs.py"
    
    print_success "Graphs and report generated in $BENCHMARK_DIR/comparison-$TIMESTAMP/"
}

# Main benchmark function
run_benchmark() {
    print_step "Starting architecture comparison benchmark..."
    
    for tx_count in "${TRANSACTION_COUNTS[@]}"; do
        # Run monolithic benchmark
        run_monolithic_benchmark "$tx_count"
        
        # Run microservices benchmark for each configuration
        for config in "${WORKER_CONFIGURATIONS[@]}"; do
            run_microservices_benchmark "$tx_count" "$config"
        done
    done
    
    # Generate comparison graphs
    generate_graphs
    
    print_success "Benchmark completed"
}

# Main execution
main() {
    setup_environment
    run_benchmark
}

# Run main function
main "$@" 