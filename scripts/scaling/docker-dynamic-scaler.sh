#!/bin/bash

# Docker Dynamic Node Scaler with Port Allocation
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_MAIN_PORT=9650
BASE_WORKER_PORT=9652
BASE_P2P_PORT=9651
PORT_INCREMENT=10
DOCKER_NETWORK="avalanche-parallel_avalanche-network"

# Default values
ACTION=""
NODE_TYPE="worker"
REPLICAS=3
SHOW_HELP=false

# Function to print colored output
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to show help
show_help() {
    cat << EOF
Docker Dynamic Node Scaler with Port Allocation

Usage: $0 [ACTION] [OPTIONS]

Actions:
  scale-up      Scale up nodes (add more instances)
  scale-down    Scale down nodes (remove instances)
  add-node      Add a single node with specific port
  remove-node   Remove a specific node
  list          List all running nodes
  status        Show current scaling status
  stop-all      Stop all dynamic nodes

Options:
  --type TYPE          Node type: worker, main, or both (default: worker)
  --replicas NUMBER    Number of replicas for scaling (default: 3)
  --port PORT          Specific port for single node operations
  --help               Show this help message

Examples:
  $0 scale-up --type worker --replicas 5
  $0 scale-down --type worker --replicas 2
  $0 add-node --type worker --port 9662
  $0 remove-node --type worker --port 9662
  $0 list
  $0 status
  $0 stop-all

Port Allocation:
  - Main nodes: 9650, 9660, 9670, 9680...
  - Workers: 9652, 9662, 9672, 9682...
  - P2P: 9651, 9661, 9671, 9681...
EOF
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    show_help
    exit 0
fi

ACTION=$1
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            NODE_TYPE="$2"
            shift 2
            ;;
        --replicas)
            REPLICAS="$2"
            shift 2
            ;;
        --port)
            SPECIFIC_PORT="$2"
            shift 2
            ;;
        --help)
            SHOW_HELP=true
            shift
            ;;
        *)
            print_msg $RED "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

if [ "$SHOW_HELP" = true ]; then
    show_help
    exit 0
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check prerequisites
check_prerequisites() {
    if ! command_exists docker; then
        print_msg $RED "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check for docker-compose or docker compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_msg $RED "Docker Compose is not installed."
        exit 1
    fi
}

# Function to get docker compose command
get_docker_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Function to get next available port
get_next_port() {
    local base_port=$1
    local node_type=$2
    
    # Get existing containers and their ports
    local existing_ports=$(docker ps --filter "name=avalanche-${node_type}" --format "table {{.Ports}}" | grep -oE "${base_port}[0-9]*" | sort -n || echo "")
    
    local port=$base_port
    while true; do
        if [[ ! " $existing_ports " =~ " $port " ]]; then
            echo $port
            return
        fi
        port=$((port + PORT_INCREMENT))
        
        # Safety check to avoid infinite loop
        if [ $port -gt $((base_port + 1000)) ]; then
            print_msg $RED "Unable to find available port after $base_port"
            exit 1
        fi
    done
}

# Function to create worker node with specific port
create_worker_node() {
    local port=$1
    local container_name="avalanche-worker-${port}"
    local p2p_port=$((port - 1))
    
    print_msg $YELLOW "Creating worker node: $container_name with ports API:$port, P2P:$p2p_port"
    
    # Get project root directory
    local project_root
    project_root="$(cd "$(dirname "$0")" && pwd)"
    
    docker run -d \
        --name "$container_name" \
        --network "$DOCKER_NETWORK" \
        -p "${port}:${port}" \
        -p "${p2p_port}:${p2p_port}" \
        -e PORT="$port" \
        -e P2P_PORT="$p2p_port" \
        -e WORKER_ID="worker-$port" \
        -e LOG_LEVEL="info" \
        -e ENABLE_TX_VALIDATION="true" \
        -e ENABLE_SIGNATURE_VER="true" \
        -e ENABLE_CONSENSUS_VOTE="true" \
        -e ENABLE_CONFIDENCE_CAL="true" \
        -e ENABLE_STATE_UPDATE="true" \
        -e ENABLE_CONFLICT_DET="true" \
        --restart unless-stopped \
        avalanche-parallel/worker:latest
    
    if [ $? -eq 0 ]; then
        print_msg $GREEN "Worker node $container_name created successfully!"
    else
        print_msg $RED "Failed to create worker node $container_name"
        return 1
    fi
}

# Function to create main node with specific port
create_main_node() {
    local port=$1
    local container_name="avalanche-main-${port}"
    local p2p_port=$((port + 1))
    
    print_msg $YELLOW "Creating main node: $container_name with ports API:$port, P2P:$p2p_port"
    
    docker run -d \
        --name "$container_name" \
        --network "$DOCKER_NETWORK" \
        -p "${port}:${port}" \
        -p "${p2p_port}:${p2p_port}" \
        -e PORT="$port" \
        -e P2P_PORT="$p2p_port" \
        -e NODE_ID="main-$port" \
        -e LOG_LEVEL="info" \
        -e ENABLE_DAG_STATE_MGMT="true" \
        -e ENABLE_CONSENSUS_ORCH="true" \
        -e ENABLE_RESULT_AGGREG="true" \
        -e DAG_STATE_SYNC_INTERVAL="30s" \
        -e CONSENSUS_TIMEOUT="60s" \
        --restart unless-stopped \
        avalanche-parallel/main-node:latest
    
    if [ $? -eq 0 ]; then
        print_msg $GREEN "Main node $container_name created successfully!"
    else
        print_msg $RED "Failed to create main node $container_name"
        return 1
    fi
}

# Function to remove node by port
remove_node() {
    local port=$1
    local node_type=$2
    local container_name="avalanche-${node_type}-${port}"
    
    print_msg $YELLOW "Removing $node_type node: $container_name"
    
    docker stop "$container_name" >/dev/null 2>&1 || true
    docker rm "$container_name" >/dev/null 2>&1 || true
    
    print_msg $GREEN "Node $container_name removed successfully!"
}

# Function to scale up nodes
scale_up() {
    local node_type=$1
    local target_replicas=$2
    
    print_msg $BLUE "Scaling up $node_type nodes to $target_replicas replicas"
    
    # Get current number of nodes
    local current_nodes=$(docker ps --filter "name=avalanche-${node_type}" --format "table {{.Names}}" | grep -c "avalanche-${node_type}" || echo "0")
    local nodes_to_add=$((target_replicas - current_nodes))
    
    if [ $nodes_to_add -le 0 ]; then
        print_msg $YELLOW "Already have $current_nodes $node_type nodes. No scaling needed."
        return
    fi
    
    print_msg $YELLOW "Adding $nodes_to_add new $node_type nodes..."
    
    for ((i=1; i<=nodes_to_add; i++)); do
        if [ "$node_type" = "worker" ]; then
            local port=$(get_next_port $BASE_WORKER_PORT $node_type)
            create_worker_node $port
        elif [ "$node_type" = "main" ]; then
            local port=$(get_next_port $BASE_MAIN_PORT $node_type)
            create_main_node $port
        fi
        sleep 2
    done
    
    local new_count=$(docker ps --filter "name=avalanche-${node_type}" --format "table {{.Names}}" | grep -c "avalanche-${node_type}" || echo "0")
    print_msg $GREEN "Scale up completed! Now have $new_count $node_type nodes"
}

# Function to scale down nodes
scale_down() {
    local node_type=$1
    local target_replicas=$2
    
    print_msg $BLUE "Scaling down $node_type nodes to $target_replicas replicas"
    
    # Get current containers
    local containers=($(docker ps --filter "name=avalanche-${node_type}" --format "{{.Names}}" | sort))
    local current_count=${#containers[@]}
    local nodes_to_remove=$((current_count - target_replicas))
    
    if [ $nodes_to_remove -le 0 ]; then
        print_msg $YELLOW "Already have $current_count $node_type nodes. No scaling needed."
        return
    fi
    
    print_msg $YELLOW "Removing $nodes_to_remove $node_type nodes..."
    
    # Remove the last N containers
    for ((i=0; i<nodes_to_remove; i++)); do
        local container_name=${containers[$((current_count - 1 - i))]}
        print_msg $YELLOW "Removing container: $container_name"
        docker stop "$container_name" >/dev/null 2>&1 || true
        docker rm "$container_name" >/dev/null 2>&1 || true
        sleep 1
    done
    
    local new_count=$(docker ps --filter "name=avalanche-${node_type}" --format "table {{.Names}}" | grep -c "avalanche-${node_type}" || echo "0")
    print_msg $GREEN "Scale down completed! Now have $new_count $node_type nodes"
}

# Function to list all nodes
list_nodes() {
    print_msg $BLUE "=== Current Avalanche Nodes ==="
    
    print_msg $YELLOW "\nMain Nodes:"
    docker ps --filter "name=avalanche-main" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    print_msg $YELLOW "\nWorker Nodes:"
    docker ps --filter "name=avalanche-worker" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    print_msg $YELLOW "\nAll Avalanche Containers:"
    docker ps --filter "name=avalanche" --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
}

# Function to show status
show_status() {
    print_msg $BLUE "=== Avalanche Parallel Cluster Status ==="
    
    local main_count=$(docker ps --filter "name=avalanche-main" --format "table {{.Names}}" | grep -c "avalanche-main" || echo "0")
    local worker_count=$(docker ps --filter "name=avalanche-worker" --format "table {{.Names}}" | grep -c "avalanche-worker" || echo "0")
    local total_containers=$(docker ps --filter "name=avalanche" --format "table {{.Names}}" | grep -c "avalanche" || echo "0")
    
    print_msg $GREEN "Main Nodes: $main_count"
    print_msg $GREEN "Worker Nodes: $worker_count"
    print_msg $GREEN "Total Containers: $total_containers"
    
    print_msg $YELLOW "\nPort Allocation:"
    docker ps --filter "name=avalanche" --format "table {{.Names}}\t{{.Ports}}" | sort
    
    print_msg $YELLOW "\nResource Usage:"
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $(docker ps --filter "name=avalanche" --format "{{.Names}}" | tr '\n' ' ') 2>/dev/null || print_msg $YELLOW "No containers running"
}

# Function to stop all dynamic nodes
stop_all() {
    print_msg $YELLOW "Stopping all dynamic Avalanche nodes..."
    
    # Stop and remove all avalanche containers except the original ones from docker-compose
    local containers=($(docker ps --filter "name=avalanche" --format "{{.Names}}" | grep -E "(avalanche-main-[0-9]+|avalanche-worker-[0-9]+)"))
    
    if [ ${#containers[@]} -eq 0 ]; then
        print_msg $YELLOW "No dynamic nodes found to stop."
        return
    fi
    
    for container in "${containers[@]}"; do
        print_msg $YELLOW "Stopping container: $container"
        docker stop "$container" >/dev/null 2>&1 || true
        docker rm "$container" >/dev/null 2>&1 || true
    done
    
    print_msg $GREEN "All dynamic nodes stopped successfully!"
}

# Function to ensure network exists
ensure_network() {
    if ! docker network ls | grep -q "$DOCKER_NETWORK"; then
        print_msg $YELLOW "Creating Docker network: $DOCKER_NETWORK"
        docker network create "$DOCKER_NETWORK" >/dev/null 2>&1 || true
    fi
}

# Main execution
check_prerequisites
ensure_network

case $ACTION in
    scale-up)
        if [ "$NODE_TYPE" = "both" ]; then
            scale_up "main" $REPLICAS
            scale_up "worker" $REPLICAS
        else
            scale_up $NODE_TYPE $REPLICAS
        fi
        ;;
    scale-down)
        if [ "$NODE_TYPE" = "both" ]; then
            scale_down "main" $REPLICAS
            scale_down "worker" $REPLICAS
        else
            scale_down $NODE_TYPE $REPLICAS
        fi
        ;;
    add-node)
        if [ -z "$SPECIFIC_PORT" ]; then
            if [ "$NODE_TYPE" = "worker" ]; then
                SPECIFIC_PORT=$(get_next_port $BASE_WORKER_PORT $NODE_TYPE)
            else
                SPECIFIC_PORT=$(get_next_port $BASE_MAIN_PORT $NODE_TYPE)
            fi
        fi
        
        if [ "$NODE_TYPE" = "worker" ]; then
            create_worker_node $SPECIFIC_PORT
        elif [ "$NODE_TYPE" = "main" ]; then
            create_main_node $SPECIFIC_PORT
        else
            print_msg $RED "Invalid node type for add-node: $NODE_TYPE"
            exit 1
        fi
        ;;
    remove-node)
        if [ -z "$SPECIFIC_PORT" ]; then
            print_msg $RED "Port must be specified for remove-node action"
            exit 1
        fi
        remove_node $SPECIFIC_PORT $NODE_TYPE
        ;;
    list)
        list_nodes
        ;;
    status)
        show_status
        ;;
    stop-all)
        stop_all
        ;;
    *)
        print_msg $RED "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac

print_msg $GREEN "\n=== Operation completed successfully! ===" 