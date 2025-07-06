#!/bin/bash

# Default values
WORKER_COUNTS=(1 2 4 8 16)
TRANSACTION_COUNTS=(1000 5000 10000)
OUTPUT_DIR="benchmark-results"
GENERATE_GRAPHS=true

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Run benchmarks for Avalanche parallel processing"
    echo
    echo "Options:"
    echo "  -w, --workers         Worker counts (space-separated list) [default: 1 2 4 8 16]"
    echo "  -t, --transactions    Transaction counts (space-separated list) [default: 1000 5000 10000]"
    echo "  -o, --output          Output directory [default: benchmark-results]"
    echo "  -n, --no-graphs       Skip graph generation"
    echo "  -h, --help            Show this help message"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -w|--workers)
            IFS=' ' read -r -a WORKER_COUNTS <<< "$2"
            shift 2
            ;;
        -t|--transactions)
            IFS=' ' read -r -a TRANSACTION_COUNTS <<< "$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -n|--no-graphs)
            GENERATE_GRAPHS=false
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Check Python availability
check_python() {
    if ! command -v python &> /dev/null; then
        echo "Error: Python is not installed. Please install Python to generate graphs."
        return 1
    fi
    return 0
}

# Create output directory
initialize_output_directory() {
    mkdir -p "$OUTPUT_DIR"
}

# Run benchmarks and collect results
run_benchmarks() {
    local timestamp
    timestamp=$(date +"%Y%m%d_%H%M%S")
    local results_file="$OUTPUT_DIR/benchmark_results_$timestamp.json"
    
    echo "Running benchmarks..."
    
    # Initialize results JSON
    cat > "$results_file" << EOF
{
    "timestamp": "$timestamp",
    "monolithic": [],
    "parallel": []
}
EOF
    
    # Run monolithic benchmarks
    echo -e "\nRunning monolithic benchmarks..."
    for tx_count in "${TRANSACTION_COUNTS[@]}"; do
        echo "Testing with $tx_count transactions..."
        output=$(go test -bench "BenchmarkMonolithicPayment" -count 5 ./benchmark/...)
        
        # Parse and add results
        time=$(parse_benchmark_output "$output")
        tmp_file=$(mktemp)
        jq --arg tx "$tx_count" --arg time "$time" '.monolithic += [{"transactions": ($tx|tonumber), "time": ($time|tonumber)}]' "$results_file" > "$tmp_file"
        mv "$tmp_file" "$results_file"
    done
    
    # Run parallel benchmarks
    echo -e "\nRunning parallel benchmarks..."
    for workers in "${WORKER_COUNTS[@]}"; do
        for tx_count in "${TRANSACTION_COUNTS[@]}"; do
            echo "Testing with $workers workers and $tx_count transactions..."
            output=$(go test -bench "BenchmarkParallelPayment" -count 5 ./benchmark/...)
            
            # Parse and add results
            time=$(parse_benchmark_output "$output")
            tmp_file=$(mktemp)
            jq --arg w "$workers" --arg tx "$tx_count" --arg time "$time" \
               '.parallel += [{"workers": ($w|tonumber), "transactions": ($tx|tonumber), "time": ($time|tonumber)}]' \
               "$results_file" > "$tmp_file"
            mv "$tmp_file" "$results_file"
        done
    done
    
    echo -e "\nResults saved to: $results_file"
    echo "$results_file"
}

# Parse benchmark output
parse_benchmark_output() {
    local output="$1"
    local times=()
    
    while IFS= read -r line; do
        if [[ $line =~ ns/op ]]; then
            time=$(echo "$line" | awk '{print $3}')
            times+=("$time")
        fi
    done <<< "$output"
    
    # Calculate average
    local sum=0
    for time in "${times[@]}"; do
        sum=$(echo "$sum + $time" | bc)
    done
    
    echo "scale=2; $sum / ${#times[@]}" | bc
}

# Generate comparison graphs
generate_graphs() {
    local results_file="$1"
    local python_script="$OUTPUT_DIR/generate_graphs.py"
    
    cat > "$python_script" << 'EOF'
import json
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime

# Load benchmark results
with open('$1') as f:
    results = json.load(f)

# Create output directory for graphs
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
output_dir = f'$OUTPUT_DIR/graphs_{timestamp}'
import os
os.makedirs(output_dir, exist_ok=True)

# Plot 1: Transaction Count vs Processing Time
plt.figure(figsize=(12, 6))
tx_counts = sorted(set(r['transactions'] for r in results['monolithic']))
mono_times = [next(r['time'] for r in results['monolithic'] if r['transactions'] == tx)
              for tx in tx_counts]

worker_counts = sorted(set(r['workers'] for r in results['parallel']))
for workers in worker_counts:
    parallel_times = [next(r['time'] for r in results['parallel']
                         if r['transactions'] == tx and r['workers'] == workers)
                     for tx in tx_counts]
    plt.plot(tx_counts, parallel_times, marker='o', label=f'Parallel ({workers} workers)')

plt.plot(tx_counts, mono_times, marker='s', label='Monolithic', linewidth=2)
plt.xlabel('Number of Transactions')
plt.ylabel('Processing Time (ns)')
plt.title('Transaction Processing Time Comparison')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/processing_time_comparison.png')
plt.close()

# Plot 2: Speedup Factor vs Worker Count
plt.figure(figsize=(12, 6))
for tx_count in tx_counts:
    mono_time = next(r['time'] for r in results['monolithic']
                    if r['transactions'] == tx_count)
    speedups = [mono_time / next(r['time'] for r in results['parallel']
                               if r['transactions'] == tx_count and r['workers'] == w)
                for w in worker_counts]
    plt.plot(worker_counts, speedups, marker='o', label=f'{tx_count} transactions')

plt.xlabel('Number of Workers')
plt.ylabel('Speedup Factor')
plt.title('Parallel Processing Speedup')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/speedup_factor.png')
plt.close()

# Plot 3: Worker Efficiency
plt.figure(figsize=(12, 6))
for tx_count in tx_counts:
    mono_time = next(r['time'] for r in results['monolithic']
                    if r['transactions'] == tx_count)
    efficiency = [mono_time / (next(r['time'] for r in results['parallel']
                                  if r['transactions'] == tx_count and r['workers'] == w) * w)
                 for w in worker_counts]
    plt.plot(worker_counts, efficiency, marker='o', label=f'{tx_count} transactions')

plt.xlabel('Number of Workers')
plt.ylabel('Efficiency')
plt.title('Worker Efficiency (Speedup/Worker)')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/worker_efficiency.png')
plt.close()

print(f"Graphs generated in: {output_dir}")
EOF
    
    echo -e "\nGenerating comparison graphs..."
    python "$python_script" "$results_file"
    rm "$python_script"
}

# Main execution
{
    initialize_output_directory
    
    if [ "$GENERATE_GRAPHS" = true ] && ! check_python; then
        echo "Cannot generate graphs without Python. Please install Python or run with --no-graphs"
        exit 1
    fi
    
    results_file=$(run_benchmarks)
    
    if [ "$GENERATE_GRAPHS" = true ]; then
        generate_graphs "$results_file"
    fi
    
    echo -e "\nBenchmark completed successfully!"
} || {
    echo "Error during benchmark execution"
    exit 1
} 