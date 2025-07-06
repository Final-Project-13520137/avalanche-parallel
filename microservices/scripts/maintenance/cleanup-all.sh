#!/bin/bash
# Cleanup script for Avalanche Parallel Processing

# Exit on error
set -e

# Default values
FORCE=false
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Colors
RED='\e[31m'
GREEN='\e[32m'
YELLOW='\e[33m'
BLUE='\e[36m'
NC='\e[0m' # No Color

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            exit 1
            ;;
    esac
done

# Function to safely execute docker commands
safe_docker_cmd() {
    local cmd="$1"
    local msg="$2"
    echo -e "${BLUE}$msg${NC}"
    if ! eval "$cmd"; then
        echo -e "${YELLOW}Warning: Command failed, continuing...${NC}"
        return 1
    fi
    return 0
}

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

# Function to check if kubectl is available
check_kubectl() {
    if command -v kubectl > /dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to cleanup Kubernetes resources
cleanup_kubernetes() {
    echo -e "${BLUE}Checking for Kubernetes resources...${NC}"
    if check_kubectl; then
        echo -e "${BLUE}Found kubectl, cleaning up Kubernetes resources...${NC}"
        
        # Delete all resources in avalanche namespace
        if kubectl get namespace avalanche > /dev/null 2>&1; then
            echo -e "${BLUE}Deleting all resources in avalanche namespace...${NC}"
            safe_docker_cmd "kubectl delete namespace avalanche --grace-period=0 --force" "Deleting avalanche namespace"
            
            # Wait for namespace deletion
            echo -e "${BLUE}Waiting for namespace deletion...${NC}"
            while kubectl get namespace avalanche > /dev/null 2>&1; do
                echo -n "."
                sleep 1
            done
            echo
        else
            echo -e "${GREEN}No avalanche namespace found in Kubernetes${NC}"
        fi
    else
        echo -e "${YELLOW}kubectl not found, skipping Kubernetes cleanup${NC}"
    fi
}

echo -e "${YELLOW}🧹 Starting cleanup process...${NC}"

# Check if Docker is running
check_docker

# Stop all containers
echo -e "${BLUE}Stopping all containers...${NC}"
if [ -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ]; then
    safe_docker_cmd "docker-compose -f '$PROJECT_ROOT/docker-compose.worker-pools.yml' down" "Stopping docker-compose services..."
else
    echo -e "${YELLOW}Warning: docker-compose.worker-pools.yml not found${NC}"
fi

if [ "$FORCE" = true ]; then
    echo -e "${RED}Performing force cleanup...${NC}"

    # First, cleanup Kubernetes resources
    cleanup_kubernetes
    
    # Remove all project-related containers
    echo -e "${BLUE}Checking for project containers...${NC}"
    CONTAINERS=$(docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" -q)
    if [ ! -z "$CONTAINERS" ]; then
        echo -e "${BLUE}Found containers to remove:${NC}"
        docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}"
        
        # Stop containers first
        echo -e "${BLUE}Stopping containers...${NC}"
        for container in $CONTAINERS; do
            safe_docker_cmd "docker stop $container" "Stopping container $container"
        done
        
        # Then remove them
        echo -e "${BLUE}Removing containers...${NC}"
        for container in $CONTAINERS; do
            safe_docker_cmd "docker rm -f $container" "Removing container $container"
        done
    else
        echo -e "${GREEN}No project containers found${NC}"
    fi

    # Remove project images
    echo -e "${BLUE}Checking for project images...${NC}"
    IMAGES=$(docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" -q)
    if [ ! -z "$IMAGES" ]; then
        echo -e "${BLUE}Removing images:${NC}"
        docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}"
        for image in $IMAGES; do
            safe_docker_cmd "docker rmi -f $image" "Removing image $image"
        done
    else
        echo -e "${GREEN}No project images found${NC}"
    fi

    # Remove volumes
    echo -e "${BLUE}Checking for project volumes...${NC}"
    VOLUMES=$(docker volume ls --filter "name=microservices" --filter "name=k8s" -q)
    if [ ! -z "$VOLUMES" ]; then
        echo -e "${BLUE}Removing volumes:${NC}"
        docker volume ls --filter "name=microservices" --filter "name=k8s" --format "table {{.Name}}\t{{.Driver}}"
        for volume in $VOLUMES; do
            safe_docker_cmd "docker volume rm -f $volume" "Removing volume $volume"
        done
    else
        echo -e "${GREEN}No project volumes found${NC}"
    fi

    # Remove networks
    echo -e "${BLUE}Checking for project networks...${NC}"
    NETWORKS=$(docker network ls --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" -q)
    if [ ! -z "$NETWORKS" ]; then
        echo -e "${BLUE}Removing networks:${NC}"
        docker network ls --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}\t{{.Name}}\t{{.Driver}}"
        for network in $NETWORKS; do
            safe_docker_cmd "docker network rm $network" "Removing network $network"
        done
    else
        echo -e "${GREEN}No project networks found${NC}"
    fi

    # Prune system
    echo -e "${BLUE}Pruning unused Docker resources...${NC}"
    safe_docker_cmd "docker system prune -f" "Pruning system..."
fi

echo -e "${GREEN}✅ Cleanup completed!${NC}"

# Final status check
echo -e "\n${BLUE}Final status:${NC}"
echo -e "${BLUE}Remaining containers:${NC}"
docker ps -a --filter "name=avalanche" --filter "name=microservices" --filter "name=k8s" --format "table {{.ID}}\t{{.Names}}\t{{.Status}}" 2>/dev/null || echo "None"
echo -e "\n${BLUE}Remaining images:${NC}"
docker images --filter "reference=avalanche*" --filter "reference=microservices*" --filter "reference=k8s.gcr.io/*" --format "table {{.ID}}\t{{.Repository}}\t{{.Tag}}" 2>/dev/null || echo "None" 