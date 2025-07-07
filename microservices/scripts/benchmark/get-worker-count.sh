#!/bin/bash

# Script untuk mendapatkan jumlah worker yang sedang berjalan
# Usage: ./get-worker-count.sh [worker-type]

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

# Function to get accurate worker count using docker ps
get_worker_count_accurate() {
    local service_pattern=$1
    local count=$(docker ps --filter "name=${service_pattern}" --filter "status=running" --format "{{.Names}}" | wc -l)
    echo $count
}

# Function to get worker count using docker-compose
get_worker_count_compose() {
    local service_name=$1
    cd "$PROJECT_ROOT"
    local count=$(docker-compose -f docker-compose.worker-pools.yml ps -q "$service_name" 2>/dev/null | wc -l)
    echo $count
}

# Function to get the most accurate count by trying multiple methods
get_best_worker_count() {
    local service_name=$1
    local container_pattern="${PROJECT_ROOT##*/}_${service_name}"
    
    # Method 1: Try docker ps with pattern matching
    local count1=$(get_worker_count_accurate "$container_pattern")
    
    # Method 2: Try docker-compose ps
    local count2=$(get_worker_count_compose "$service_name")
    
    # Method 3: Try alternative pattern
    local alt_pattern="avalanche-${service_name}"
    local count3=$(get_worker_count_accurate "$alt_pattern")
    
    # Return the highest non-zero count
    local max_count=0
    for count in $count1 $count2 $count3; do
        if [ "$count" -gt "$max_count" ]; then
            max_count=$count
        fi
    done
    
    echo $max_count
}

# Main execution
if [ $# -eq 0 ]; then
    # Get all worker counts
    echo "Current Worker Pool Status:"
    
    validator_count=$(get_best_worker_count "validator-worker")
    consensus_count=$(get_best_worker_count "consensus-worker")
    dag_state_count=$(get_best_worker_count "dag-state-worker")
    
    echo "validator:$validator_count"
    echo "consensus:$consensus_count"
    echo "dag-state:$dag_state_count"
    echo "total:$((validator_count + consensus_count + dag_state_count))"
else
    # Get specific worker count
    worker_type=$1
    case $worker_type in
        "validator"|"validator-worker")
            count=$(get_best_worker_count "validator-worker")
            echo $count
            ;;
        "consensus"|"consensus-worker")
            count=$(get_best_worker_count "consensus-worker")
            echo $count
            ;;
        "dag-state"|"dag-state-worker")
            count=$(get_best_worker_count "dag-state-worker")
            echo $count
            ;;
        *)
            echo "Unknown worker type: $worker_type"
            echo "Available types: validator, consensus, dag-state"
            exit 1
            ;;
    esac
fi 