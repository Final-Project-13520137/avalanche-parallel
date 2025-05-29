#!/bin/bash

# Default values
TEST_MODE=0
FULL_TEST=0
TRANSACTION_SIZE="mixed"
TRANSACTION_COUNT=5000
BATCH_SIZE=50
SIMULATE=1  # Default to simulation mode for now

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --test)
            TEST_MODE=1
            shift
            ;;
        --full)
            FULL_TEST=1
            shift
            ;;
        --tx-size=*)
            TRANSACTION_SIZE="${1#*=}"
            shift
            ;;
        --transactions=*)
            TRANSACTION_COUNT="${1#*=}"
            shift
            ;;
        --batch=*)
            BATCH_SIZE="${1#*=}"
            shift
            ;;
        --real)
            SIMULATE=0
            shift
            ;;
        *)
            echo "Unknown option: $1"
            shift
            ;;
    esac
done

# Print header
echo -e "\e[1;36mRunning Avalanche Parallel vs Traditional Consensus Benchmark\e[0m"
echo -e "\e[1;36m=============================================================\e[0m"

# Create results directory if it doesn't exist
RESULTS_DIR="benchmark-results"
if [ ! -d "$RESULTS_DIR" ]; then
    mkdir -p "$RESULTS_DIR"
    echo -e "\e[1;32mCreated results directory: $RESULTS_DIR\e[0m"
fi

# Get timestamp for the results file
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
RESULTS_FILE="$RESULTS_DIR/benchmark-$TIMESTAMP.txt"

# Choose the appropriate script based on simulation flag
if [ $SIMULATE -eq 1 ]; then
    BENCHMARK_SCRIPT="benchmark_sim.go"
else
    BENCHMARK_SCRIPT="transaction_load.go"
fi

# Display test options
echo -e "\e[1;33mBenchmark Options:\e[0m"
if [ $FULL_TEST -eq 1 ]; then
    echo -e "\e[1;33m  Running comprehensive test with multiple scenarios\e[0m"
else
    echo -e "\e[1;33m  Transaction Size: $TRANSACTION_SIZE\e[0m"
    echo -e "\e[1;33m  Transaction Count: $TRANSACTION_COUNT\e[0m"
    echo -e "\e[1;33m  Batch Size: $BATCH_SIZE\e[0m"
    
    if [ $TEST_MODE -eq 1 ]; then
        echo -e "\e[1;33m  Mode: TestParallelConsensus (Go Test)\e[0m"
    else
        if [ $SIMULATE -eq 1 ]; then
            echo -e "\e[1;33m  Mode: Simulated Benchmark\e[0m"
        else
            echo -e "\e[1;33m  Mode: Real Transaction Load Test\e[0m"
        fi
    fi
fi

# Decide which test to run
if [ $FULL_TEST -eq 1 ]; then
    # Run comprehensive benchmark with scenarios
    echo -e "\n\e[1;32mRunning comprehensive scenario tests...\e[0m"
    
    go run ./scripts/$BENCHMARK_SCRIPT --scenarios | tee "$RESULTS_DIR/scenarios-$TIMESTAMP.txt"
    
    echo -e "\e[1;32mRaw results saved to: $RESULTS_DIR/scenarios-$TIMESTAMP.txt\e[0m"
elif [ $TEST_MODE -eq 1 ]; then
    # Run the Go test benchmark
    echo -e "\n\e[1;32mRunning Go test benchmark...\e[0m"
    
    go test -v -run TestParallelConsensus -count=5 ./pkg/blockchain | tee "$RESULTS_DIR/gotest-$TIMESTAMP.txt"
    
    echo -e "\e[1;32mRaw results saved to: $RESULTS_DIR/gotest-$TIMESTAMP.txt\e[0m"
else
    # Run the scaling benchmark using our custom Go script
    echo -e "\n\e[1;32mRunning transaction load test with scaling benchmark...\e[0m"
    
    go run ./scripts/$BENCHMARK_SCRIPT --benchmark --transactions=$TRANSACTION_COUNT --batch=$BATCH_SIZE --tx-size=$TRANSACTION_SIZE
    
    echo -e "\n\e[1;32mResults saved to the benchmark-results directory\e[0m"
fi

# Add visualization generation
echo -e "\n\e[1;36mGenerating visualization graphs...\e[0m"

# Check if go-chart is installed
if ! go list github.com/wcharczuk/go-chart/v2 &>/dev/null; then
    echo -e "\e[1;33mInstalling required dependencies...\e[0m"
    go get github.com/wcharczuk/go-chart/v2
fi

# Run the visualization tool
go run ./scripts/visualize_benchmark.go

echo -e "\n\e[1;36mBenchmark completed!\e[0m" 