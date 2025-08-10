#!/bin/bash

# AvalancheGo Monolithic Flow System Runner
# Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.

set -e

# Colors untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print header
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}🚀 AvalancheGo Monolithic Flow System${NC}"
echo -e "${BLUE}=====================================${NC}"

# Directory paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BIN_DIR="$PROJECT_ROOT/bin"
CMD_DIR="$PROJECT_ROOT/cmd/avalanche-monolithic"

# Create bin directory if it doesn't exist
mkdir -p "$BIN_DIR"

# Function to print status
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to build monolithic binary
build_monolithic() {
    print_status "Building AvalancheGo Monolithic Flow System..."
    
    cd "$PROJECT_ROOT"
    
    # Check if go is installed
    if ! command -v go &> /dev/null; then
        print_error "Go is not installed or not in PATH"
        exit 1
    fi
    
    # Build the monolithic binary
    print_status "Compiling avalanche-monolithic binary..."
    go build -o "$BIN_DIR/avalanche-monolithic" "$CMD_DIR/main.go"
    
    if [ $? -eq 0 ]; then
        print_status "✅ Build successful: $BIN_DIR/avalanche-monolithic"
    else
        print_error "❌ Build failed"
        exit 1
    fi
}

# Function to run monolithic system
run_monolithic() {
    local log_level="${1:-info}"
    local http_port="${2:-9650}"
    local network_port="${3:-9651}"
    local custom_args="${4:-}"
    
    print_status "Starting AvalancheGo Monolithic Flow System..."
    print_status "Log Level: $log_level"
    print_status "HTTP Port: $http_port"
    print_status "Network Port: $network_port"
    
    # Create data directories
    mkdir -p "$HOME/.avalanche-monolithic/db"
    mkdir -p "$HOME/.avalanche-monolithic/logs"
    
    # Run the monolithic system
    print_status "Executing avalanche-monolithic..."
    echo ""
    
    "$BIN_DIR/avalanche-monolithic" \
        --log-level "$log_level" \
        --http-port "$http_port" \
        --network-port "$network_port" \
        $custom_args
}

# Function to show help
show_help() {
    echo "Usage: $0 [COMMAND] [OPTIONS]"
    echo ""
    echo "Commands:"
    echo "  build          Build the monolithic binary"
    echo "  run            Build and run the monolithic system"
    echo "  start          Start the monolithic system (alias for run)"
    echo "  help           Show this help message"
    echo ""
    echo "Options for run/start:"
    echo "  --log-level LEVEL    Log level (debug, info, warn, error) [default: info]"
    echo "  --http-port PORT     HTTP API port [default: 9650]"
    echo "  --network-port PORT  Network listening port [default: 9651]"
    echo "  --args \"ARGS\"        Additional arguments to pass to avalanche-monolithic"
    echo ""
    echo "Examples:"
    echo "  $0 build"
    echo "  $0 run"
    echo "  $0 run --log-level debug"
    echo "  $0 run --log-level debug --http-port 8080"
    echo "  $0 run --args \"--db-dir /custom/path\""
    echo ""
}

# Parse command line arguments
COMMAND="${1:-run}"
LOG_LEVEL="info"
HTTP_PORT="9650"
NETWORK_PORT="9651"
CUSTOM_ARGS=""

shift || true

while [[ $# -gt 0 ]]; do
    case $1 in
        --log-level)
            LOG_LEVEL="$2"
            shift 2
            ;;
        --http-port)
            HTTP_PORT="$2"
            shift 2
            ;;
        --network-port)
            NETWORK_PORT="$2"
            shift 2
            ;;
        --args)
            CUSTOM_ARGS="$2"
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

# Execute command
case "$COMMAND" in
    build)
        build_monolithic
        ;;
    run|start)
        build_monolithic
        echo ""
        run_monolithic "$LOG_LEVEL" "$HTTP_PORT" "$NETWORK_PORT" "$CUSTOM_ARGS"
        ;;
    help)
        show_help
        ;;
    *)
        print_error "Unknown command: $COMMAND"
        echo ""
        show_help
        exit 1
        ;;
esac 