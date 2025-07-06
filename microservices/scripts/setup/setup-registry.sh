#!/bin/bash
# Script for setting up local Docker registry

# Colors
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[36m'
YELLOW='\e[33m'
NC='\e[0m' # No Color

# Default values
REGISTRY_PORT=5000
REGISTRY_NAME="registry"
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --port)
            REGISTRY_PORT="$2"
            shift 2
            ;;
        --name)
            REGISTRY_NAME="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            exit 1
            ;;
    esac
done

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        exit 1
    fi
}

# Function to check if registry is already running
check_registry() {
    if docker ps -a --filter "name=$REGISTRY_NAME" --format '{{.Names}}' | grep -q "^$REGISTRY_NAME$"; then
        if docker ps --filter "name=$REGISTRY_NAME" --format '{{.Names}}' | grep -q "^$REGISTRY_NAME$"; then
            echo -e "${GREEN}✅ Registry is already running${NC}"
            return 0
        else
            if [ "$FORCE" = true ]; then
                echo -e "${YELLOW}⚠️ Registry container exists but not running. Removing...${NC}"
                docker rm -f "$REGISTRY_NAME" > /dev/null 2>&1
                return 1
            else
                echo -e "${YELLOW}⚠️ Registry container exists but not running. Use --force to remove and recreate${NC}"
                exit 1
            fi
        fi
    fi
    return 1
}

# Function to check if port is available
check_port() {
    if netstat -tln | grep -q ":$REGISTRY_PORT "; then
        echo -e "${RED}❌ Port $REGISTRY_PORT is already in use${NC}"
        exit 1
    fi
}

# Function to start registry
start_registry() {
    echo -e "${BLUE}🚀 Starting local registry...${NC}"
    
    # Pull registry image if not exists
    if ! docker images | grep -q "^registry[[:space:]]*2"; then
        echo -e "${BLUE}Pulling registry image...${NC}"
        docker pull registry:2
    fi

    # Start registry container
    docker run -d \
        --name "$REGISTRY_NAME" \
        --restart=always \
        -p "$REGISTRY_PORT:5000" \
        -v registry-data:/var/lib/registry \
        registry:2

    # Check if registry started successfully
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Registry started successfully${NC}"
        
        # Wait for registry to be ready
        echo -e "${BLUE}⏳ Waiting for registry to be ready...${NC}"
        for i in {1..30}; do
            if curl -s "http://localhost:$REGISTRY_PORT/v2/" > /dev/null; then
                echo -e "${GREEN}✅ Registry is ready${NC}"
                return 0
            fi
            sleep 1
        done
        echo -e "${RED}❌ Registry failed to start${NC}"
        exit 1
    else
        echo -e "${RED}❌ Failed to start registry${NC}"
        exit 1
    fi
}

# Main execution
echo -e "${BLUE}🔧 Setting up local Docker registry...${NC}"

# Check prerequisites
check_docker

# Check if registry is already running
if ! check_registry; then
    # Check if port is available
    check_port
    # Start registry
    start_registry
fi

# Show registry information
echo -e "\n${BLUE}📋 Registry Information:${NC}"
echo -e "Name: ${GREEN}$REGISTRY_NAME${NC}"
echo -e "URL: ${GREEN}localhost:$REGISTRY_PORT${NC}"
echo -e "Status: ${GREEN}Running${NC}"
echo -e "\n${BLUE}🔍 Test registry with:${NC}"
echo -e "  curl http://localhost:$REGISTRY_PORT/v2/_catalog"
echo -e "  docker tag myimage:latest localhost:$REGISTRY_PORT/myimage:latest"
echo -e "  docker push localhost:$REGISTRY_PORT/myimage:latest" 