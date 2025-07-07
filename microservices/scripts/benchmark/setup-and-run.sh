#!/bin/bash

# Avalanche Benchmark Setup and Runner
# This script sets up the complete environment and runs the benchmark

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] ✅ $1${NC}"
}

log_error() {
    echo -e "${RED}[$(date +'%H:%M:%S')] ❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%H:%M:%S')] ⚠️ $1${NC}"
}

# Function to install Python dependencies
install_python_deps() {
    log "🐍 Installing Python dependencies..."
    
    if command -v pip3 > /dev/null 2>&1; then
        pip3 install -r "$SCRIPT_DIR/requirements.txt"
    elif command -v pip > /dev/null 2>&1; then
        pip install -r "$SCRIPT_DIR/requirements.txt"
    else
        log_warning "pip not found, you may need to install Python dependencies manually"
        return
    fi
    
    log_success "Python dependencies installed"
}

# Function to setup Go dependencies
setup_go_deps() {
    log "🔧 Setting up Go dependencies..."
    
    cd "$SCRIPT_DIR"
    go mod tidy
    go mod download
    
    log_success "Go dependencies ready"
}

# Function to check system requirements
check_system() {
    log "🔍 Checking system requirements..."
    
    # Check available memory
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        TOTAL_MEM=$(free -g | awk '/^Mem:/ {print $2}')
        if [ "$TOTAL_MEM" -lt 4 ]; then
            log_warning "System has less than 4GB RAM. Benchmark may be limited."
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        TOTAL_MEM=$(sysctl -n hw.memsize | awk '{print int($1/1024/1024/1024)}')
        if [ "$TOTAL_MEM" -lt 4 ]; then
            log_warning "System has less than 4GB RAM. Benchmark may be limited."
        fi
    fi
    
    # Check Docker resources
    if command -v docker > /dev/null 2>&1; then
        docker system info | grep -E "CPUs|Total Memory" || true
    fi
    
    log_success "System check completed"
}

# Function to setup local registry
setup_registry() {
    log "🐳 Setting up local Docker registry..."
    
    # Check if registry is already running
    if docker ps | grep -q "registry:2"; then
        log "Local registry already running"
        return
    fi
    
    # Start local registry
    docker run -d -p 5000:5000 --restart=always --name registry registry:2 || {
        log "Registry already exists, starting it..."
        docker start registry || true
    }
    
    # Wait for registry to be ready
    sleep 5
    
    if curl -s http://localhost:5000/v2/ > /dev/null; then
        log_success "Local registry is ready"
    else
        log_error "Failed to start local registry"
        exit 1
    fi
}

# Function to run complete benchmark
run_complete_benchmark() {
    log "🚀 Starting complete Avalanche benchmark suite..."
    
    # Make sure we're in the right directory
    cd "$SCRIPT_DIR"
    
    # Run the benchmark
    if [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "win32" ]]; then
        # Windows
        powershell.exe -ExecutionPolicy Bypass -File "run-avalanche-benchmark.ps1"
    else
        # Unix-like systems
        bash run-avalanche-benchmark.sh
    fi
    
    log_success "Benchmark completed!"
}

# Function to generate summary report
generate_summary() {
    log "📊 Generating benchmark summary..."
    
    RESULTS_DIR="$(dirname "$SCRIPT_DIR")/benchmark-results"
    GRAPHS_DIR="$(dirname "$SCRIPT_DIR")/benchmark-graphs"
    
    echo ""
    echo "=============================================="
    echo "🎉 AVALANCHE BENCHMARK COMPLETED"
    echo "=============================================="
    echo ""
    echo "📁 Results Location:"
    echo "   Results: $RESULTS_DIR"
    echo "   Graphs:  $GRAPHS_DIR"
    echo ""
    
    if [ -d "$RESULTS_DIR" ]; then
        echo "📈 Generated Files:"
        find "$RESULTS_DIR" -name "*.json" -o -name "*.csv" -o -name "*.md" | head -10
        echo ""
    fi
    
    if [ -d "$GRAPHS_DIR" ]; then
        echo "📊 Generated Graphs:"
        find "$GRAPHS_DIR" -name "*.png" | head -10
        echo ""
    fi
    
    echo "🔍 Key Metrics to Review:"
    echo "   • Throughput comparison (TPS)"
    echo "   • Latency analysis (ms)"
    echo "   • Resource utilization (CPU/Memory)"
    echo "   • Scalability characteristics"
    echo ""
    echo "💡 Next Steps:"
    echo "   1. Review the generated graphs in $GRAPHS_DIR"
    echo "   2. Analyze the detailed report in $RESULTS_DIR"
    echo "   3. Consider running additional test scenarios"
    echo ""
}

# Main execution
main() {
    echo "🚀 Avalanche Microservices vs Monolith Benchmark Setup"
    echo "======================================================="
    echo ""
    
    check_system
    install_python_deps
    setup_go_deps
    setup_registry
    
    echo ""
    log "🎯 Environment setup complete! Starting benchmark..."
    echo ""
    
    run_complete_benchmark
    generate_summary
    
    echo "✨ All done! Check the results above."
}

# Run main function
main "$@" 