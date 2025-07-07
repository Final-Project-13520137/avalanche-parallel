#!/bin/bash

# Test script untuk memverifikasi setup benchmark

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() {
    echo -e "${BLUE}[TEST] $1${NC}"
}

log_success() {
    echo -e "${GREEN}[TEST] ✅ $1${NC}"
}

log_error() {
    echo -e "${RED}[TEST] ❌ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}[TEST] ⚠️ $1${NC}"
}

# Test Go setup
test_go_setup() {
    log "Testing Go setup..."
    
    cd "$SCRIPT_DIR"
    
    if ! go mod tidy; then
        log_error "Go mod tidy failed"
        return 1
    fi
    
    if ! go build -o test-benchmark avalanche-comparison-benchmark.go; then
        log_error "Go build failed"
        return 1
    fi
    
    rm -f test-benchmark
    log_success "Go setup working"
}

# Test Python setup
test_python_setup() {
    log "Testing Python setup..."
    
    if command -v python3 > /dev/null 2>&1; then
        python3 -c "import matplotlib, seaborn, pandas, numpy" 2>/dev/null || {
            log_warning "Python dependencies not installed. Run: pip3 install -r requirements.txt"
            return 1
        }
        log_success "Python setup working"
    elif command -v python > /dev/null 2>&1; then
        python -c "import matplotlib, seaborn, pandas, numpy" 2>/dev/null || {
            log_warning "Python dependencies not installed. Run: pip install -r requirements.txt"
            return 1
        }
        log_success "Python setup working"
    else
        log_warning "Python not found"
        return 1
    fi
}

# Test Docker setup
test_docker_setup() {
    log "Testing Docker setup..."
    
    if ! docker info > /dev/null 2>&1; then
        log_error "Docker not running"
        return 1
    fi
    
    # Test local registry
    if curl -s http://localhost:5000/v2/ > /dev/null; then
        log_success "Local Docker registry working"
    else
        log_warning "Local registry not running. Run: docker run -d -p 5000:5000 --name registry registry:2"
    fi
}

# Test Kubernetes setup
test_kubernetes_setup() {
    log "Testing Kubernetes setup..."
    
    if ! command -v kubectl > /dev/null 2>&1; then
        log_error "kubectl not found"
        return 1
    fi
    
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log_error "Kubernetes cluster not accessible"
        return 1
    fi
    
    log_success "Kubernetes setup working"
}

# Test microservices deployment
test_microservices() {
    log "Testing microservices deployment..."
    
    # Check if pods are running
    if kubectl get pods -n avalanche-parallel > /dev/null 2>&1; then
        READY_PODS=$(kubectl get pods -n avalanche-parallel --no-headers | grep "1/1.*Running" | wc -l)
        TOTAL_PODS=$(kubectl get pods -n avalanche-parallel --no-headers | wc -l)
        
        if [ "$READY_PODS" -gt 0 ]; then
            log_success "Microservices running ($READY_PODS/$TOTAL_PODS pods ready)"
        else
            log_warning "Microservices not ready. Run deployment script first."
        fi
    else
        log_warning "Microservices not deployed"
    fi
}

# Main test execution
main() {
    echo "🧪 Avalanche Benchmark Setup Test"
    echo "=================================="
    echo ""
    
    test_go_setup
    test_python_setup
    test_docker_setup
    test_kubernetes_setup
    test_microservices
    
    echo ""
    echo "🎯 Test Summary:"
    echo "- If all tests pass, you can run the benchmark"
    echo "- If any warnings, follow the suggestions to fix"
    echo "- Run './setup-and-run.sh' for automated setup"
    echo ""
}

main "$@" 