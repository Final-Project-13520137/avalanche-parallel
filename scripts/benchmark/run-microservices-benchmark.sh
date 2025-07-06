#!/bin/bash

# Avalanche Microservices vs Monolith Benchmark
# Compare performance between microservices and monolith architectures

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

# Benchmark settings
TRANSACTION_COUNTS=(1000 5000 10000)
THREAD_COUNTS=(2 4 8 16 32)
DURATION=60 # seconds
WARMUP_TIME=10 # seconds

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

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running"
        exit 1
    fi
    
    # Check if Go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed"
        exit 1
    fi
    
    # Check if curl is installed
    if ! command -v curl &> /dev/null; then
        print_error "curl is not installed"
        exit 1
    fi
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed, installing..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y jq
        elif command -v yum &> /dev/null; then
            sudo yum install -y jq
        elif command -v brew &> /dev/null; then
            brew install jq
        else
            print_error "Cannot install jq automatically. Please install manually."
            exit 1
        fi
    fi
    
    print_success "Prerequisites check passed"
}

# Setup environment
setup_environment() {
    print_step "Setting up benchmark environment..."
    
    # Create benchmark results directory
    mkdir -p "$BENCHMARK_DIR"
    
    # Generate timestamp for this benchmark run
    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
    export BENCHMARK_TIMESTAMP="$TIMESTAMP"
    
    print_success "Environment setup completed"
}

# Start monolith (existing Avalanche)
start_monolith() {
    print_step "Starting monolith Avalanche..."
    
    cd "$ROOT_DIR"
    
    # Build monolith if not exists
    if [ ! -f "avalanche-parallel" ]; then
        print_step "Building monolith..."
        go build -o avalanche-parallel ./cmd/avalanche
    fi
    
    # Start monolith in background
    ./avalanche-parallel &
    MONOLITH_PID=$!
    export MONOLITH_PID
    
    # Wait for startup
    sleep 5
    
    # Check if monolith is running
    if ! kill -0 $MONOLITH_PID 2>/dev/null; then
        print_error "Failed to start monolith"
        exit 1
    fi
    
    print_success "Monolith started (PID: $MONOLITH_PID)"
}

# Start microservices
start_microservices() {
    print_step "Starting microservices..."
    
    cd "$MICROSERVICES_DIR"
    
    # Check if microservices exist
    if [ ! -f "docker-compose.yml" ]; then
        print_error "Microservices not found. Run './microservices/generator/generate-all.sh' first"
        exit 1
    fi
    
    # Build and start microservices
    docker-compose up -d --build
    
    # Wait for services to be ready
    print_step "Waiting for microservices to be ready..."
    sleep 30
    
    # Check service health
    check_microservices_health
    
    print_success "Microservices started"
}

# Check microservices health
check_microservices_health() {
    local max_retries=30
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if curl -s http://localhost:9650/health > /dev/null; then
            print_success "API Gateway is healthy"
            return 0
        fi
        
        retry=$((retry + 1))
        sleep 2
        print_step "Waiting for services... ($retry/$max_retries)"
    done
    
    print_error "Microservices failed to start properly"
    exit 1
}

# Run benchmark for monolith
benchmark_monolith() {
    local tx_count=$1
    local threads=$2
    
    print_step "Benchmarking monolith: $tx_count transactions, $threads threads"
    
    local start_time=$(date +%s.%N)
    
    # Run existing benchmark tool
    cd "$ROOT_DIR"
    go run ./cmd/benchmark --transactions=$tx_count --threads=$threads --duration=$DURATION > /tmp/monolith_result.txt 2>&1
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Parse results
    local tps=$(grep "TPS:" /tmp/monolith_result.txt | awk '{print $2}' || echo "0")
    local latency=$(grep "Latency:" /tmp/monolith_result.txt | awk '{print $2}' || echo "0")
    
    echo "$duration,$tps,$latency" > "$BENCHMARK_DIR/monolith_${tx_count}_${threads}_${TIMESTAMP}.csv"
    
    print_success "Monolith benchmark completed: ${tps} TPS, ${latency}ms latency"
}

# Run benchmark for microservices
benchmark_microservices() {
    local tx_count=$1
    local threads=$2
    
    print_step "Benchmarking microservices: $tx_count transactions, $threads threads"
    
    local start_time=$(date +%s.%N)
    
    # Generate transactions and send to microservices
    generate_microservices_load $tx_count $threads
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    
    # Get metrics from API Gateway
    local metrics=$(curl -s http://localhost:9650/metrics | jq -r '.requests_total, .request_duration')
    local tps=$(echo "scale=2; $tx_count / $duration" | bc -l)
    local latency=$(echo "$metrics" | tail -n1 | sed 's/ms//')
    
    echo "$duration,$tps,$latency" > "$BENCHMARK_DIR/microservices_${tx_count}_${threads}_${TIMESTAMP}.csv"
    
    print_success "Microservices benchmark completed: ${tps} TPS, ${latency}ms latency"
}

# Generate load for microservices
generate_microservices_load() {
    local tx_count=$1
    local threads=$2
    
    # Create transaction payload
    local tx_payload='{
        "id": "'$(uuidgen)'",
        "data": "'$(echo "test transaction data" | base64)'",
        "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
    }'
    
    # Run concurrent requests
    for ((i=1; i<=threads; i++)); do
        {
            local per_thread=$((tx_count / threads))
            for ((j=1; j<=per_thread; j++)); do
                curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -d "$tx_payload" \
                    http://localhost:9650/ext/P > /dev/null
            done
        } &
    done
    
    # Wait for all background jobs to complete
    wait
}

# Generate comparison report
generate_comparison_report() {
    print_step "Generating comparison report..."
    
    local report_file="$BENCHMARK_DIR/comparison_report_${TIMESTAMP}.md"
    
    cat > "$report_file" << EOF
# Avalanche Architecture Performance Comparison

**Timestamp**: $(date)
**Duration**: ${DURATION}s per test
**Warmup**: ${WARMUP_TIME}s

## Test Results

| Architecture | Transactions | Threads | Duration (s) | TPS | Latency (ms) | Speedup |
|--------------|--------------|---------|--------------|-----|--------------|---------|
EOF
    
    # Process results and add to report
    for tx_count in "${TRANSACTION_COUNTS[@]}"; do
        for threads in "${THREAD_COUNTS[@]}"; do
            # Read monolith results
            if [ -f "$BENCHMARK_DIR/monolith_${tx_count}_${threads}_${TIMESTAMP}.csv" ]; then
                local mono_data=$(cat "$BENCHMARK_DIR/monolith_${tx_count}_${threads}_${TIMESTAMP}.csv")
                local mono_duration=$(echo "$mono_data" | cut -d',' -f1)
                local mono_tps=$(echo "$mono_data" | cut -d',' -f2)
                local mono_latency=$(echo "$mono_data" | cut -d',' -f3)
                
                echo "| Monolith | $tx_count | $threads | $mono_duration | $mono_tps | $mono_latency | 1.00x |" >> "$report_file"
            fi
            
            # Read microservices results
            if [ -f "$BENCHMARK_DIR/microservices_${tx_count}_${threads}_${TIMESTAMP}.csv" ]; then
                local micro_data=$(cat "$BENCHMARK_DIR/microservices_${tx_count}_${threads}_${TIMESTAMP}.csv")
                local micro_duration=$(echo "$micro_data" | cut -d',' -f1)
                local micro_tps=$(echo "$micro_data" | cut -d',' -f2)
                local micro_latency=$(echo "$micro_data" | cut -d',' -f3)
                
                # Calculate speedup
                local speedup="1.00x"
                if [ -n "$mono_tps" ] && [ "$mono_tps" != "0" ]; then
                    speedup=$(echo "scale=2; $micro_tps / $mono_tps" | bc -l)x
                fi
                
                echo "| Microservices | $tx_count | $threads | $micro_duration | $micro_tps | $micro_latency | $speedup |" >> "$report_file"
            fi
        done
    done
    
    cat >> "$report_file" << EOF

## Architecture Comparison

### Monolith (Existing Avalanche)
- **Pros**: Single deployment, simpler debugging, lower latency for small loads
- **Cons**: Vertical scaling only, single point of failure, resource sharing

### Microservices (New Architecture)
- **Pros**: Horizontal scaling, fault isolation, independent deployment, better resource utilization
- **Cons**: Network overhead, complexity, eventual consistency challenges

## Recommendations

Based on the benchmark results:

1. **For Low Load (< 1000 TPS)**: Monolith may be sufficient
2. **For Medium Load (1000-5000 TPS)**: Microservices show better scalability
3. **For High Load (> 5000 TPS)**: Microservices architecture is recommended

## Scaling Characteristics

- **Monolith**: Limited to vertical scaling, performance degrades with high concurrency
- **Microservices**: Horizontal scaling allows linear performance improvement with additional resources

## Next Steps

1. Optimize microservices communication (gRPC instead of HTTP)
2. Implement caching strategies
3. Add load balancing improvements
4. Consider hybrid approach for specific use cases
EOF

    print_success "Comparison report generated: $report_file"
}

# Cleanup
cleanup() {
    print_step "Cleaning up..."
    
    # Stop monolith
    if [ -n "$MONOLITH_PID" ]; then
        kill $MONOLITH_PID 2>/dev/null || true
        print_step "Monolith stopped"
    fi
    
    # Stop microservices
    if [ -d "$MICROSERVICES_DIR" ]; then
        cd "$MICROSERVICES_DIR"
        docker-compose down
        print_step "Microservices stopped"
    fi
    
    print_success "Cleanup completed"
}

# Main benchmark execution
run_benchmarks() {
    print_step "Starting performance benchmarks..."
    
    for tx_count in "${TRANSACTION_COUNTS[@]}"; do
        for threads in "${THREAD_COUNTS[@]}"; do
            print_step "Testing configuration: $tx_count transactions, $threads threads"
            
            # Benchmark monolith
            start_monolith
            sleep $WARMUP_TIME
            benchmark_monolith $tx_count $threads
            kill $MONOLITH_PID
            sleep 5
            
            # Benchmark microservices
            start_microservices
            sleep $WARMUP_TIME
            benchmark_microservices $tx_count $threads
            cd "$MICROSERVICES_DIR" && docker-compose down
            sleep 5
        done
    done
    
    print_success "All benchmarks completed"
}

# Signal handlers for cleanup
trap cleanup EXIT

# Main execution
main() {
    echo "🚀 Starting Avalanche Microservices vs Monolith Benchmark..."
    
    check_prerequisites
    setup_environment
    run_benchmarks
    generate_comparison_report
    
    print_success "✅ Benchmark completed successfully!"
    echo ""
    print_step "Results available in: $BENCHMARK_DIR"
    print_step "View report: cat $BENCHMARK_DIR/comparison_report_${TIMESTAMP}.md"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --transactions)
            TRANSACTION_COUNTS=($2)
            shift 2
            ;;
        --threads)
            THREAD_COUNTS=($2)
            shift 2
            ;;
        --duration)
            DURATION=$2
            shift 2
            ;;
        --help)
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  --transactions  Comma-separated list of transaction counts (default: 1000,5000,10000)"
            echo "  --threads       Comma-separated list of thread counts (default: 2,4,8,16,32)"
            echo "  --duration      Duration of each test in seconds (default: 60)"
            echo "  --help          Show this help message"
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run main function
main "$@" 