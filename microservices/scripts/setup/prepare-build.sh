#!/bin/bash
# Script for preparing build environment

# Colors
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[36m'
YELLOW='\e[33m'
NC='\e[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MICROSERVICES_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        exit 1
    fi
}

# Function to verify required files exist
verify_files() {
    echo -e "${BLUE}🔍 Verifying required files...${NC}"
    
    local missing_files=0
    
    # Check root files
    if [ ! -f "$PROJECT_ROOT/go.mod" ]; then
        echo -e "${RED}❌ Missing root go.mod${NC}"
        missing_files=1
    fi
    if [ ! -f "$PROJECT_ROOT/go.sum" ]; then
        echo -e "${RED}❌ Missing root go.sum${NC}"
        missing_files=1
    fi

    # Check microservices files
    if [ ! -f "$MICROSERVICES_ROOT/go.mod" ]; then
        echo -e "${RED}❌ Missing microservices go.mod${NC}"
        missing_files=1
    fi
    if [ ! -f "$MICROSERVICES_ROOT/go.sum" ]; then
        echo -e "${RED}❌ Missing microservices go.sum${NC}"
        missing_files=1
    fi

    # Check worker source code
    if [ ! -d "$MICROSERVICES_ROOT/workers" ]; then
        echo -e "${RED}❌ Missing workers directory${NC}"
        missing_files=1
    else
        # Check each worker directory
        for worker in consensus-worker validator-worker dag-state-worker; do
            if [ ! -d "$MICROSERVICES_ROOT/workers/$worker" ]; then
                echo -e "${RED}❌ Missing $worker directory${NC}"
                missing_files=1
            fi
        done
    fi

    if [ $missing_files -eq 1 ]; then
        echo -e "${RED}❌ Required files verification failed${NC}"
        exit 1
    fi

    echo -e "${GREEN}✅ Required files verified successfully${NC}"
}

# Main execution
echo -e "${BLUE}🚀 Preparing build environment...${NC}"

# Check Docker
check_docker

# Verify required files
verify_files

echo -e "${GREEN}✨ Build environment ready!${NC}" 