#!/bin/bash
# Script for scaling worker nodes

# Colors
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[36m'
NC='\e[0m' # No Color

# Default values
WORKER_TYPE=""
COUNT=0
MONITOR=false

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Function to display usage
usage() {
    echo "Usage: $0 --type <validator|consensus|dag-state> --count <number> [--monitor]"
    echo
    echo "Options:"
    echo "  --type      Type of worker (validator, consensus, or dag-state)"
    echo "  --count     Number of worker instances (1-100)"
    echo "  --monitor   Monitor worker status after scaling"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            WORKER_TYPE="$2"
            shift 2
            ;;
        --count)
            COUNT="$2"
            shift 2
            ;;
        --monitor)
            MONITOR=true
            shift
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Validate arguments
if [[ -z "$WORKER_TYPE" ]]; then
    echo -e "${RED}Error: Worker type must be specified${NC}"
    usage
fi

if [[ ! "$WORKER_TYPE" =~ ^(validator|consensus|dag-state)$ ]]; then
    echo -e "${RED}Error: Invalid worker type. Must be validator, consensus, or dag-state${NC}"
    usage
fi

if [[ ! "$COUNT" =~ ^[0-9]+$ ]] || [ "$COUNT" -lt 1 ] || [ "$COUNT" -gt 100 ]; then
    echo -e "${RED}Error: Count must be a number between 1 and 100${NC}"
    usage
fi

# Function to check if Docker is running
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}Error: Docker is not running${NC}"
        exit 1
    fi
}

# Function to check if docker-compose file exists
check_compose_file() {
    if [ ! -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ]; then
        echo -e "${RED}Error: docker-compose.worker-pools.yml not found in $PROJECT_ROOT${NC}"
        exit 1
    fi
}

# Format worker type for docker-compose service name
case "$WORKER_TYPE" in
    "validator")
        SERVICE_NAME="validator-worker"
        ;;
    "consensus")
        SERVICE_NAME="consensus-worker"
        ;;
    "dag-state")
        SERVICE_NAME="dag-state-worker"
        ;;
esac

# Validate environment
check_docker
check_compose_file

echo -e "${BLUE}Scaling $SERVICE_NAME to $COUNT instances...${NC}"

# Scale workers
if ! docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" up -d --scale "$SERVICE_NAME=$COUNT" --no-recreate; then
    echo -e "${RED}Error: Failed to scale workers${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully scaled $SERVICE_NAME to $COUNT instances${NC}"

# Monitor if requested
if [ "$MONITOR" = true ]; then
    echo -e "${BLUE}Monitoring worker status...${NC}"
    while true; do
        clear
        echo -e "${BLUE}Current $SERVICE_NAME status:${NC}"
        docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ps "$SERVICE_NAME"
        echo
        docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" --no-stream | grep "$SERVICE_NAME"
        sleep 5
    done
fi 