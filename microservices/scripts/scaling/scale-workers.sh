#!/bin/bash
# Script for scaling worker nodes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default values
MIN_CONSENSUS_WORKERS=2
MAX_CONSENSUS_WORKERS=10
MIN_VALIDATOR_WORKERS=3
MAX_VALIDATOR_WORKERS=15
MIN_DAG_STATE_WORKERS=2
MAX_DAG_STATE_WORKERS=8

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Function to scale workers
scale_workers() {
    local worker_type=$1
    local count=$2
    local min_count=$3
    local max_count=$4

    if [ $count -lt $min_count ]; then
        echo -e "${RED}Error: Cannot scale $worker_type below minimum of $min_count workers${NC}"
        return 1
    fi

    if [ $count -gt $max_count ]; then
        echo -e "${RED}Error: Cannot scale $worker_type above maximum of $max_count workers${NC}"
        return 1
    fi

    echo -e "${YELLOW}Scaling $worker_type to $count workers...${NC}"
    docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" up -d --scale $worker_type=$count
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Successfully scaled $worker_type to $count workers${NC}"
    else
        echo -e "${RED}Failed to scale $worker_type${NC}"
        return 1
    fi
}

# Function to show current scaling
show_scaling() {
    echo -e "${YELLOW}Current worker pool sizes:${NC}"
    echo "Consensus Workers: $(docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ps -q consensus-worker | wc -l)"
    echo "Validator Workers: $(docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ps -q validator-worker | wc -l)"
    echo "DAG State Workers: $(docker-compose -f "$PROJECT_ROOT/docker-compose.worker-pools.yml" ps -q dag-state-worker | wc -l)"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [command] [options]"
    echo
    echo "Commands:"
    echo "  scale <worker-type> <count>  Scale specific worker type to count"
    echo "  status                       Show current scaling status"
    echo "  help                         Show this help message"
    echo
    echo "Worker Types:"
    echo "  consensus-worker     (min: $MIN_CONSENSUS_WORKERS, max: $MAX_CONSENSUS_WORKERS)"
    echo "  validator-worker    (min: $MIN_VALIDATOR_WORKERS, max: $MAX_VALIDATOR_WORKERS)"
    echo "  dag-state-worker    (min: $MIN_DAG_STATE_WORKERS, max: $MAX_DAG_STATE_WORKERS)"
}

# Main script
case "$1" in
    scale)
        if [ -z "$2" ] || [ -z "$3" ]; then
            show_usage
            exit 1
        fi

        case "$2" in
            consensus-worker)
                scale_workers "$2" "$3" $MIN_CONSENSUS_WORKERS $MAX_CONSENSUS_WORKERS
                ;;
            validator-worker)
                scale_workers "$2" "$3" $MIN_VALIDATOR_WORKERS $MAX_VALIDATOR_WORKERS
                ;;
            dag-state-worker)
                scale_workers "$2" "$3" $MIN_DAG_STATE_WORKERS $MAX_DAG_STATE_WORKERS
                ;;
            *)
                echo -e "${RED}Error: Unknown worker type $2${NC}"
                show_usage
                exit 1
                ;;
        esac
        ;;
    status)
        show_scaling
        ;;
    help|--help|-h)
        show_usage
        ;;
    *)
        show_usage
        exit 1
        ;;
esac 