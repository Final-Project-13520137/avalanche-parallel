#!/bin/bash

# Test Docker Build Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

print_msg $GREEN "=== Testing Docker Build ==="

# Ensure we're in the right directory
cd "$(dirname "$0")"

# Check if go.mod.docker exists, create if not
if [ ! -f "../../go.mod.docker" ]; then
    print_msg $YELLOW "Creating go.mod.docker..."
    sed 's/go 1\.23\.9/go 1.21/' ../../go.mod | grep -v "toolchain" > ../../go.mod.docker
fi

print_msg $YELLOW "Building main node image..."
docker build -f Dockerfile.main-node -t test/avalanche-main-node:latest ../..

print_msg $YELLOW "Building worker node image..."
docker build -f Dockerfile.worker-node -t test/avalanche-worker:latest ../..

print_msg $GREEN "Build completed successfully!"
print_msg $GREEN "Images created:"
docker images | grep "test/avalanche" 