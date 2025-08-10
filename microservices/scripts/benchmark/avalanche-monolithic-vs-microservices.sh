#!/bin/bash

# AvalancheGo Monolithic vs Microservices Benchmark Script
# Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"
RESULTS_DIR="$PROJECT_ROOT/benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BENCHMARK_NAME="monolithic-vs-microservices-$TIMESTAMP"

# Default benchmark parameters
DURATION=300  # 5 minutes
TPS_TARGET=1000
CONCURRENT_USERS=50
RAMP_UP_TIME=30

# Function to print status
print_header() {
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}🚀 AvalancheGo Benchmark: Monolithic vs Microservices${NC}"
    echo -e "${BLUE}==========================================${NC}"
}

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_section() {
    echo -e "${PURPLE}[SECTION]${NC} $1"
}

# Function to show help
show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Benchmark Options:"
    echo "  --duration SECONDS       Benchmark duration in seconds [default: 300]"
    echo "  --tps TARGET            Target transactions per second [default: 1000]"
    echo "  --users COUNT           Concurrent users [default: 50]"
    echo "  --ramp-up SECONDS       Ramp-up time in seconds [default: 30]"
    echo ""
    echo "System Options:"
    echo "  --monolithic-only       Run only monolithic benchmark"
    echo "  --microservices-only    Run only microservices benchmark"
    echo "  --skip-build           Skip building binaries"
    echo "  --clean                Clean up processes after benchmark"
    echo ""
    echo "Output Options:"
    echo "  --results-dir DIR       Results directory [default: ./benchmark-results]"
    echo "  --name NAME            Benchmark name [default: auto-generated]"
    echo "  --format FORMAT        Output format (json, csv, both) [default: both]"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Run full benchmark with defaults"
    echo "  $0 --duration 600 --tps 2000         # 10-minute benchmark with 2000 TPS"
    echo "  $0 --monolithic-only --duration 120  # Only monolithic for 2 minutes"
    echo "  $0 --clean                          # Clean up and run benchmark"
    echo ""
}

# Function to setup environment
setup_environment() {
    print_section "Setting up benchmark environment"
    
    # Create results directory
    mkdir -p "$RESULTS_DIR"
    mkdir -p "$RESULTS_DIR/$BENCHMARK_NAME"
    
    # Check dependencies
    print_status "Checking dependencies..."
    
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed"
        exit 1
    fi
    
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi
    
    print_status "✅ Dependencies check passed"
}

# Function to build binaries
build_systems() {
    print_section "Building systems"
    
    cd "$PROJECT_ROOT"
    
    # Build monolithic system
    print_status "Building monolithic system..."
    if ! "$PROJECT_ROOT/scripts/run-monolithic.sh" build; then
        print_error "Failed to build monolithic system"
        exit 1
    fi
    
    # Build microservices system
    print_status "Building microservices system..."
    cd "$PROJECT_ROOT/microservices"
    if ! docker-compose -f docker-compose.benchmark.yml build; then
        print_error "Failed to build microservices system"
        exit 1
    fi
    
    print_status "✅ Systems built successfully"
}

# Function to start monolithic system
start_monolithic() {
    print_status "Starting AvalancheGo Monolithic System..."
    
    # Start monolithic in background
    cd "$PROJECT_ROOT"
    nohup "$PROJECT_ROOT/bin/avalanche-monolithic" \
        --log-level info \
        --http-port 9650 \
        --network-port 9651 \
        > "$RESULTS_DIR/$BENCHMARK_NAME/monolithic.log" 2>&1 &
    
    MONOLITHIC_PID=$!
    echo $MONOLITHIC_PID > "$RESULTS_DIR/$BENCHMARK_NAME/monolithic.pid"
    
    # Wait for startup
    print_status "Waiting for monolithic system to start..."
    for i in {1..30}; do
        if curl -s http://localhost:9650/ext/health &>/dev/null; then
            print_status "✅ Monolithic system is ready"
            return 0
        fi
        sleep 2
    done
    
    print_error "❌ Monolithic system failed to start"
    return 1
}

# Function to start microservices system
start_microservices() {
    print_status "Starting Microservices System..."
    
    cd "$PROJECT_ROOT/microservices"
    
    # Start microservices
    docker-compose -f docker-compose.benchmark.yml up -d
    
    # Wait for startup
    print_status "Waiting for microservices to start..."
    for i in {1..60}; do
        if curl -s http://localhost:8080/health &>/dev/null; then
            print_status "✅ Microservices system is ready"
            return 0
        fi
        sleep 3
    done
    
    print_error "❌ Microservices system failed to start"
    return 1
}

# Function to run benchmark test
run_benchmark_test() {
    local system_name=$1
    local endpoint=$2
    local results_file=$3
    
    print_status "Running benchmark for $system_name..."
    print_status "Target: $TPS_TARGET TPS, Duration: ${DURATION}s, Users: $CONCURRENT_USERS"
    
    # Create benchmark configuration
    local config_file="$RESULTS_DIR/$BENCHMARK_NAME/${system_name}_config.json"
    cat > "$config_file" << EOF
{
    "endpoint": "$endpoint",
    "duration": $DURATION,
    "tps_target": $TPS_TARGET,
    "concurrent_users": $CONCURRENT_USERS,
    "ramp_up_time": $RAMP_UP_TIME,
    "test_scenarios": [
        {
            "name": "transaction_processing",
            "weight": 70,
            "requests": [
                {
                    "method": "POST",
                    "path": "/ext/bc/X",
                    "payload": {
                        "jsonrpc": "2.0",
                        "method": "avm.createAddress",
                        "params": {},
                        "id": 1
                    }
                }
            ]
        },
        {
            "name": "balance_queries",
            "weight": 20,
            "requests": [
                {
                    "method": "GET",
                    "path": "/ext/health"
                }
            ]
        },
        {
            "name": "consensus_queries",
            "weight": 10,
            "requests": [
                {
                    "method": "POST",
                    "path": "/ext/info",
                    "payload": {
                        "jsonrpc": "2.0",
                        "method": "info.getNodeVersion",
                        "params": {},
                        "id": 1
                    }
                }
            ]
        }
    ]
}
EOF

    # Run actual benchmark (simplified version - would use proper load testing tool)
    print_status "Executing benchmark test..."
    
    local start_time=$(date +%s)
    local request_count=0
    local error_count=0
    local total_response_time=0
    
    # Simple benchmark loop
    for ((i=1; i<=DURATION; i++)); do
        local iteration_start=$(date +%s%3N)
        
        # Simulate concurrent requests
        for ((j=1; j<=TPS_TARGET/DURATION; j++)); do
            if curl -s -w "%{time_total}" "$endpoint/ext/health" >/dev/null 2>&1; then
                ((request_count++))
            else
                ((error_count++))
            fi
        done
        
        local iteration_end=$(date +%s%3N)
        local iteration_time=$((iteration_end - iteration_start))
        total_response_time=$((total_response_time + iteration_time))
        
        if ((i % 30 == 0)); then
            print_status "Progress: ${i}/${DURATION}s (Requests: $request_count, Errors: $error_count)"
        fi
        
        sleep 1
    done
    
    local end_time=$(date +%s)
    local duration_actual=$((end_time - start_time))
    local avg_response_time=$((total_response_time / request_count))
    local tps_actual=$((request_count / duration_actual))
    local error_rate=$(echo "scale=2; $error_count * 100 / ($request_count + $error_count)" | bc -l 2>/dev/null || echo "0")
    
    # Generate results
    cat > "$results_file" << EOF
{
    "system": "$system_name",
    "timestamp": "$(date -Iseconds)",
    "configuration": {
        "duration": $DURATION,
        "target_tps": $TPS_TARGET,
        "concurrent_users": $CONCURRENT_USERS,
        "ramp_up_time": $RAMP_UP_TIME
    },
    "results": {
        "duration_actual": $duration_actual,
        "total_requests": $request_count,
        "total_errors": $error_count,
        "tps_actual": $tps_actual,
        "avg_response_time_ms": $avg_response_time,
        "error_rate_percent": $error_rate,
        "success_rate_percent": $(echo "100 - $error_rate" | bc -l 2>/dev/null || echo "100")
    }
}
EOF

    print_status "✅ Benchmark completed for $system_name"
    print_status "Results: $tps_actual TPS, ${avg_response_time}ms avg response, ${error_rate}% error rate"
}

# Function to stop systems
stop_monolithic() {
    print_status "Stopping monolithic system..."
    if [ -f "$RESULTS_DIR/$BENCHMARK_NAME/monolithic.pid" ]; then
        local pid=$(cat "$RESULTS_DIR/$BENCHMARK_NAME/monolithic.pid")
        if kill -0 $pid 2>/dev/null; then
            kill $pid
            sleep 5
            if kill -0 $pid 2>/dev/null; then
                kill -9 $pid
            fi
        fi
        rm -f "$RESULTS_DIR/$BENCHMARK_NAME/monolithic.pid"
    fi
    print_status "✅ Monolithic system stopped"
}

stop_microservices() {
    print_status "Stopping microservices..."
    cd "$PROJECT_ROOT/microservices"
    docker-compose -f docker-compose.benchmark.yml down
    print_status "✅ Microservices stopped"
}

# Function to generate comparison report
generate_report() {
    print_section "Generating comparison report"
    
    local monolithic_results="$RESULTS_DIR/$BENCHMARK_NAME/monolithic_results.json"
    local microservices_results="$RESULTS_DIR/$BENCHMARK_NAME/microservices_results.json"
    local report_file="$RESULTS_DIR/$BENCHMARK_NAME/comparison_report.md"
    
    cat > "$report_file" << EOF
# AvalancheGo Benchmark Results: Monolithic vs Microservices

**Benchmark Date**: $(date)
**Benchmark ID**: $BENCHMARK_NAME

## Configuration
- **Duration**: ${DURATION} seconds
- **Target TPS**: ${TPS_TARGET}
- **Concurrent Users**: ${CONCURRENT_USERS}
- **Ramp-up Time**: ${RAMP_UP_TIME} seconds

## Results Summary

### Monolithic System
EOF

    if [ -f "$monolithic_results" ]; then
        local mono_tps=$(jq -r '.results.tps_actual' "$monolithic_results" 2>/dev/null || echo "N/A")
        local mono_response=$(jq -r '.results.avg_response_time_ms' "$monolithic_results" 2>/dev/null || echo "N/A")
        local mono_error=$(jq -r '.results.error_rate_percent' "$monolithic_results" 2>/dev/null || echo "N/A")
        
        cat >> "$report_file" << EOF
- **Actual TPS**: $mono_tps
- **Average Response Time**: ${mono_response}ms
- **Error Rate**: ${mono_error}%
- **Success Rate**: $(echo "100 - $mono_error" | bc -l 2>/dev/null || echo "N/A")%

EOF
    else
        echo "- **Status**: Not tested" >> "$report_file"
    fi

    cat >> "$report_file" << EOF
### Microservices System
EOF

    if [ -f "$microservices_results" ]; then
        local micro_tps=$(jq -r '.results.tps_actual' "$microservices_results" 2>/dev/null || echo "N/A")
        local micro_response=$(jq -r '.results.avg_response_time_ms' "$microservices_results" 2>/dev/null || echo "N/A")
        local micro_error=$(jq -r '.results.error_rate_percent' "$microservices_results" 2>/dev/null || echo "N/A")
        
        cat >> "$report_file" << EOF
- **Actual TPS**: $micro_tps
- **Average Response Time**: ${micro_response}ms
- **Error Rate**: ${micro_error}%
- **Success Rate**: $(echo "100 - $micro_error" | bc -l 2>/dev/null || echo "N/A")%

## Performance Comparison

| Metric | Monolithic | Microservices | Winner |
|--------|------------|---------------|---------|
| TPS | $mono_tps | $micro_tps | $([ $(echo "$mono_tps > $micro_tps" | bc -l 2>/dev/null) = 1 ] && echo "Monolithic" || echo "Microservices") |
| Response Time | ${mono_response}ms | ${micro_response}ms | $([ $(echo "$mono_response < $micro_response" | bc -l 2>/dev/null) = 1 ] && echo "Monolithic" || echo "Microservices") |
| Error Rate | ${mono_error}% | ${micro_error}% | $([ $(echo "$mono_error < $micro_error" | bc -l 2>/dev/null) = 1 ] && echo "Monolithic" || echo "Microservices") |

EOF
    else
        echo "- **Status**: Not tested" >> "$report_file"
    fi

    cat >> "$report_file" << EOF

## Files Generated
- Monolithic Results: \`monolithic_results.json\`
- Microservices Results: \`microservices_results.json\`
- Monolithic Logs: \`monolithic.log\`
- Configuration Files: \`*_config.json\`

## Benchmark Environment
- **Host OS**: $(uname -s)
- **Architecture**: $(uname -m)
- **Go Version**: $(go version 2>/dev/null || echo "N/A")
- **Docker Version**: $(docker --version 2>/dev/null || echo "N/A")

Generated on $(date)
EOF

    print_status "✅ Report generated: $report_file"
}

# Parse command line arguments
RUN_MONOLITHIC=true
RUN_MICROSERVICES=true
SKIP_BUILD=false
CLEAN_UP=false
OUTPUT_FORMAT="both"

while [[ $# -gt 0 ]]; do
    case $1 in
        --duration)
            DURATION="$2"
            shift 2
            ;;
        --tps)
            TPS_TARGET="$2"
            shift 2
            ;;
        --users)
            CONCURRENT_USERS="$2"
            shift 2
            ;;
        --ramp-up)
            RAMP_UP_TIME="$2"
            shift 2
            ;;
        --monolithic-only)
            RUN_MICROSERVICES=false
            shift
            ;;
        --microservices-only)
            RUN_MONOLITHIC=false
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --clean)
            CLEAN_UP=true
            shift
            ;;
        --results-dir)
            RESULTS_DIR="$2"
            shift 2
            ;;
        --name)
            BENCHMARK_NAME="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_warning "Unknown option: $1"
            shift
            ;;
    esac
done

# Main execution
main() {
    print_header
    
    # Setup
    setup_environment
    
    # Clean up if requested
    if [ "$CLEAN_UP" = true ]; then
        print_section "Cleaning up existing processes"
        stop_monolithic 2>/dev/null || true
        stop_microservices 2>/dev/null || true
        sleep 5
    fi
    
    # Build systems
    if [ "$SKIP_BUILD" = false ]; then
        build_systems
    fi
    
    # Run monolithic benchmark
    if [ "$RUN_MONOLITHIC" = true ]; then
        print_section "Benchmarking Monolithic System"
        start_monolithic
        sleep 10  # Allow system to stabilize
        run_benchmark_test "monolithic" "http://localhost:9650" "$RESULTS_DIR/$BENCHMARK_NAME/monolithic_results.json"
        stop_monolithic
        sleep 5
    fi
    
    # Run microservices benchmark
    if [ "$RUN_MICROSERVICES" = true ]; then
        print_section "Benchmarking Microservices System"
        start_microservices
        sleep 15  # Allow system to stabilize
        run_benchmark_test "microservices" "http://localhost:8080" "$RESULTS_DIR/$BENCHMARK_NAME/microservices_results.json"
        stop_microservices
        sleep 5
    fi
    
    # Generate report
    generate_report
    
    print_section "Benchmark Complete!"
    print_status "Results available in: $RESULTS_DIR/$BENCHMARK_NAME/"
    print_status "View report: cat $RESULTS_DIR/$BENCHMARK_NAME/comparison_report.md"
}

# Run main function
main "$@" 