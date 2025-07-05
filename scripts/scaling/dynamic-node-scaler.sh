#!/bin/bash

# Dynamic Node Scaler with Automatic Port Allocation
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="avalanche-parallel"
BASE_MAIN_PORT=9650
BASE_WORKER_PORT=9652
BASE_P2P_PORT=9651
BASE_API_PORT=8080
PORT_INCREMENT=10

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
Dynamic Node Scaler with Port Allocation

Usage: $0 [ACTION] [OPTIONS]

Actions:
  scale-up      Scale up nodes (add more instances)
  scale-down    Scale down nodes (remove instances)
  add-node      Add a single node with specific port
  remove-node   Remove a specific node
  list          List all running nodes
  status        Show current scaling status

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

Port Allocation:
  - Main nodes: 9650, 9660, 9670, 9680...
  - Workers: 9652, 9662, 9672, 9682...
  - P2P: 9651, 9661, 9671, 9681...
  - API: 8080, 8090, 8100, 8110...
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
    if ! command_exists kubectl; then
        print_msg $RED "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
        print_msg $RED "No Kubernetes cluster found or cluster is not accessible."
        exit 1
    fi
}

# Function to get next available port
get_next_port() {
    local base_port=$1
    local node_type=$2
    
    # Get existing services and their ports
    local existing_ports=$(kubectl get svc -n $NAMESPACE -l app=avalanche-${node_type} -o jsonpath='{.items[*].spec.ports[0].nodePort}' 2>/dev/null || echo "")
    
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
    local node_name="avalanche-worker-${port}"
    local p2p_port=$((port - 1))
    local api_port=$((port + 1428))  # 9652 + 1428 = 8080 offset
    
    print_msg $YELLOW "Creating worker node: $node_name with ports API:$port, P2P:$p2p_port, API-Gateway:$api_port"
    
    cat > /tmp/${node_name}-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $node_name
  namespace: $NAMESPACE
  labels:
    app: avalanche-worker
    instance: worker-$port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: avalanche-worker
      instance: worker-$port
  template:
    metadata:
      labels:
        app: avalanche-worker
        instance: worker-$port
    spec:
      containers:
      - name: worker
        image: avalanche-parallel/worker:latest
        ports:
        - containerPort: $port
          name: api
        - containerPort: $p2p_port
          name: p2p
        env:
        - name: PORT
          value: "$port"
        - name: P2P_PORT
          value: "$p2p_port"
        - name: WORKER_ID
          value: "worker-$port"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: $port
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: $port
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $node_name
  namespace: $NAMESPACE
  labels:
    app: avalanche-worker
    instance: worker-$port
spec:
  type: NodePort
  ports:
  - port: $port
    targetPort: $port
    nodePort: $port
    name: api
  - port: $p2p_port
    targetPort: $p2p_port
    nodePort: $p2p_port
    name: p2p
  selector:
    app: avalanche-worker
    instance: worker-$port
EOF
    
    kubectl apply -f /tmp/${node_name}-deployment.yaml
    rm -f /tmp/${node_name}-deployment.yaml
    
    print_msg $GREEN "Worker node $node_name created successfully!"
}

# Function to create main node with specific port
create_main_node() {
    local port=$1
    local node_name="avalanche-main-${port}"
    local p2p_port=$((port + 1))
    local api_port=$((port - 1570))  # 9650 - 1570 = 8080 offset
    
    print_msg $YELLOW "Creating main node: $node_name with ports API:$port, P2P:$p2p_port, API-Gateway:$api_port"
    
    cat > /tmp/${node_name}-deployment.yaml << EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $node_name
  namespace: $NAMESPACE
  labels:
    app: avalanche-main-node
    instance: main-$port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: avalanche-main-node
      instance: main-$port
  template:
    metadata:
      labels:
        app: avalanche-main-node
        instance: main-$port
    spec:
      containers:
      - name: main-node
        image: avalanche-parallel/main-node:latest
        ports:
        - containerPort: $port
          name: api
        - containerPort: $p2p_port
          name: p2p
        env:
        - name: PORT
          value: "$port"
        - name: P2P_PORT
          value: "$p2p_port"
        - name: NODE_ID
          value: "main-$port"
        - name: LOG_LEVEL
          value: "info"
        - name: ENABLE_DAG_STATE_MGMT
          value: "true"
        - name: ENABLE_CONSENSUS_ORCH
          value: "true"
        - name: ENABLE_RESULT_AGGREG
          value: "true"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /ext/health
            port: $port
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ext/info
            port: $port
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $node_name
  namespace: $NAMESPACE
  labels:
    app: avalanche-main-node
    instance: main-$port
spec:
  type: NodePort
  ports:
  - port: $port
    targetPort: $port
    nodePort: $port
    name: api
  - port: $p2p_port
    targetPort: $p2p_port
    nodePort: $p2p_port
    name: p2p
  selector:
    app: avalanche-main-node
    instance: main-$port
EOF
    
    kubectl apply -f /tmp/${node_name}-deployment.yaml
    rm -f /tmp/${node_name}-deployment.yaml
    
    print_msg $GREEN "Main node $node_name created successfully!"
}

# Function to remove node by port
remove_node() {
    local port=$1
    local node_type=$2
    local node_name="avalanche-${node_type}-${port}"
    
    print_msg $YELLOW "Removing $node_type node: $node_name"
    
    kubectl delete deployment $node_name -n $NAMESPACE --ignore-not-found=true
    kubectl delete service $node_name -n $NAMESPACE --ignore-not-found=true
    
    print_msg $GREEN "Node $node_name removed successfully!"
}

# Function to scale up nodes
scale_up() {
    local node_type=$1
    local target_replicas=$2
    
    print_msg $BLUE "Scaling up $node_type nodes to $target_replicas replicas"
    
    # Get current number of nodes
    local current_nodes=$(kubectl get deployments -n $NAMESPACE -l app=avalanche-${node_type} --no-headers | wc -l)
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
        elif [ "$node_type" = "main-node" ]; then
            local port=$(get_next_port $BASE_MAIN_PORT $node_type)
            create_main_node $port
        fi
        sleep 2
    done
    
    print_msg $GREEN "Scale up completed! Now have $(kubectl get deployments -n $NAMESPACE -l app=avalanche-${node_type} --no-headers | wc -l) $node_type nodes"
}

# Function to scale down nodes
scale_down() {
    local node_type=$1
    local target_replicas=$2
    
    print_msg $BLUE "Scaling down $node_type nodes to $target_replicas replicas"
    
    # Get current deployments
    local deployments=($(kubectl get deployments -n $NAMESPACE -l app=avalanche-${node_type} -o jsonpath='{.items[*].metadata.name}'))
    local current_count=${#deployments[@]}
    local nodes_to_remove=$((current_count - target_replicas))
    
    if [ $nodes_to_remove -le 0 ]; then
        print_msg $YELLOW "Already have $current_count $node_type nodes. No scaling needed."
        return
    fi
    
    print_msg $YELLOW "Removing $nodes_to_remove $node_type nodes..."
    
    # Remove the last N deployments
    for ((i=0; i<nodes_to_remove; i++)); do
        local deployment_name=${deployments[$((current_count - 1 - i))]}
        print_msg $YELLOW "Removing deployment: $deployment_name"
        kubectl delete deployment $deployment_name -n $NAMESPACE
        kubectl delete service $deployment_name -n $NAMESPACE --ignore-not-found=true
        sleep 1
    done
    
    print_msg $GREEN "Scale down completed! Now have $(kubectl get deployments -n $NAMESPACE -l app=avalanche-${node_type} --no-headers | wc -l) $node_type nodes"
}

# Function to list all nodes
list_nodes() {
    print_msg $BLUE "=== Current Avalanche Nodes ==="
    
    print_msg $YELLOW "\nMain Nodes:"
    kubectl get deployments,services -n $NAMESPACE -l app=avalanche-main-node -o wide
    
    print_msg $YELLOW "\nWorker Nodes:"
    kubectl get deployments,services -n $NAMESPACE -l app=avalanche-worker -o wide
    
    print_msg $YELLOW "\nPod Status:"
    kubectl get pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' -o wide
}

# Function to show status
show_status() {
    print_msg $BLUE "=== Avalanche Parallel Cluster Status ==="
    
    local main_count=$(kubectl get deployments -n $NAMESPACE -l app=avalanche-main-node --no-headers | wc -l)
    local worker_count=$(kubectl get deployments -n $NAMESPACE -l app=avalanche-worker --no-headers | wc -l)
    local total_pods=$(kubectl get pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' --field-selector=status.phase=Running --no-headers | wc -l)
    
    print_msg $GREEN "Main Nodes: $main_count"
    print_msg $GREEN "Worker Nodes: $worker_count"
    print_msg $GREEN "Running Pods: $total_pods"
    
    print_msg $YELLOW "\nPort Allocation:"
    kubectl get services -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].nodePort" --no-headers | sort
    
    print_msg $YELLOW "\nResource Usage:"
    kubectl top pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' 2>/dev/null || print_msg $YELLOW "Metrics server not available"
}

# Main execution
check_prerequisites

case $ACTION in
    scale-up)
        if [ "$NODE_TYPE" = "both" ]; then
            scale_up "main-node" $REPLICAS
            scale_up "worker" $REPLICAS
        else
            scale_up $NODE_TYPE $REPLICAS
        fi
        ;;
    scale-down)
        if [ "$NODE_TYPE" = "both" ]; then
            scale_down "main-node" $REPLICAS
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
        elif [ "$NODE_TYPE" = "main-node" ]; then
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
    *)
        print_msg $RED "Unknown action: $ACTION"
        show_help
        exit 1
        ;;
esac

print_msg $GREEN "\n=== Operation completed successfully! ===" 