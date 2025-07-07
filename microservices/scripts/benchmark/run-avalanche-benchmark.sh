#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

# Check if running as root
if [ "$(id -u)" = "0" ]; then
    echo -e "${RED}❌ This script should not be run as root/sudo${NC}"
    echo -e "${YELLOW}Please run without sudo:${NC}"
    echo -e "chmod +x run-avalanche-benchmark.sh"
    echo -e "./run-avalanche-benchmark.sh"
        exit 1
    fi
    
echo -e "\n${GREEN}🚀 Starting Avalanche Benchmark Suite${NC}\n"

# Function to check command existence
check_command() {
    if ! command -v $1 &> /dev/null; then
        echo -e "${RED}❌ $1 is not installed. Please install $1 first.${NC}"
        exit 1
    fi
}

# Check required commands
check_command kubectl
check_command minikube
check_command docker

# Check Docker daemon
if ! docker info &> /dev/null; then
    echo -e "${RED}❌ Docker daemon is not running. Please start Docker first.${NC}"
        exit 1
    fi
    
# Check if user is in docker group
if ! groups | grep -q docker; then
    echo -e "${RED}❌ Current user is not in the docker group${NC}"
    echo -e "${YELLOW}Please add your user to the docker group:${NC}"
    echo -e "sudo usermod -aG docker $USER"
    echo -e "Then log out and log back in."
        exit 1
    fi
    
# Delete existing minikube cluster if exists
echo -e "${YELLOW}🔄 Cleaning up existing minikube cluster...${NC}"
minikube delete

# Start fresh minikube cluster
echo -e "${YELLOW}🚀 Starting fresh minikube cluster...${NC}"
minikube start --driver=docker --memory=4096 --cpus=2 --kubernetes-version=v1.26.3
if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to start minikube${NC}"
        exit 1
    fi
    
# Enable required addons
echo -e "\n${YELLOW}📦 Enabling required addons...${NC}"
minikube addons enable metrics-server
minikube addons enable ingress

# Wait for metrics-server
echo -e "\n${YELLOW}⏳ Waiting for metrics-server...${NC}"
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Create namespace
echo -e "\n${YELLOW}📦 Creating namespace...${NC}"
cat << EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: avalanche-parallel
  labels:
    name: avalanche-parallel
    environment: benchmark
EOF

# Function to apply manifest with validation disabled and check result
apply_manifest() {
    local file=$1
    local name=$2
    echo -e "Applying ${name}..."
    
    if [ ! -f "$file" ]; then
        echo -e "${RED}❌ Manifest file not found: $file${NC}"
        return 1
    fi
    
    # Print manifest content for debugging
    echo -e "${BLUE}Contents of $name:${NC}"
    cat "$file"
    echo
    
    kubectl apply -f "$file" --validate=false -n avalanche-parallel
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to apply $name${NC}"
        return 1
    fi
    echo -e "${GREEN}✓ Successfully applied $name${NC}"
    return 0
}

# Apply Kubernetes manifests
echo -e "\n${YELLOW}📦 Applying Kubernetes manifests...${NC}"

# Create ConfigMap
apply_manifest "${PROJECT_ROOT}/k8s/configmap.yaml" "ConfigMap" || exit 1

# Apply Redis
apply_manifest "${PROJECT_ROOT}/k8s/redis-deployment.yaml" "Redis deployment" || exit 1

# Apply PostgreSQL
apply_manifest "${PROJECT_ROOT}/k8s/postgres-init.yaml" "PostgreSQL initialization scripts" || exit 1
apply_manifest "${PROJECT_ROOT}/k8s/postgres-deployment.yaml" "PostgreSQL deployment" || exit 1

# Apply Worker Deployments
apply_manifest "${PROJECT_ROOT}/k8s/worker-pools/consensus-worker-deployment.yaml" "Consensus worker deployment" || exit 1
apply_manifest "${PROJECT_ROOT}/k8s/worker-pools/dag-state-worker-deployment.yaml" "DAG state worker deployment" || exit 1
apply_manifest "${PROJECT_ROOT}/k8s/worker-pools/validator-worker-deployment.yaml" "Validator worker deployment" || exit 1

echo -e "${GREEN}✅ Kubernetes manifests applied successfully${NC}"

# Function to check pod status
check_pod_status() {
    local namespace=$1
    local label=$2
    local expected_count=$3
    local timeout=$4
    local start_time=$(date +%s)
    local end_time=$((start_time + timeout))

    echo -e "\n${YELLOW}⏳ Waiting for $label pods (expecting $expected_count)...${NC}"
    
    while true; do
        current_time=$(date +%s)
        elapsed=$((current_time - start_time))
        
        if [ $current_time -gt $end_time ]; then
            echo -e "${RED}❌ Timeout waiting for $label pods${NC}"
            kubectl get pods -n $namespace -l $label -o wide
            kubectl describe pods -n $namespace -l $label
            return 1
        fi

        ready_count=$(kubectl get pods -n $namespace -l $label -o jsonpath='{range .items[*]}{@.status.containerStatuses[*].ready}{"\n"}{end}' | grep -c "true" || echo 0)
        total_count=$(kubectl get pods -n $namespace -l $label --no-headers | wc -l)
        
        echo "Ready: $ready_count/$total_count pods for $label (${elapsed}s elapsed)"
        
        if [ "$ready_count" -eq "$expected_count" ]; then
            echo -e "${GREEN}✓ All $label pods are ready${NC}"
            return 0
        fi
        
        # Show pod status if not ready
        if [ $((elapsed % 30)) -eq 0 ]; then
            echo -e "\n${BLUE}Current pod status:${NC}"
            kubectl get pods -n $namespace -l $label -o wide
            echo
        fi
            
            sleep 5
        done
}

# Wait for infrastructure pods
echo -e "\n${YELLOW}⏳ Waiting for infrastructure pods...${NC}"
check_pod_status "avalanche-parallel" "app=redis" 1 300 || exit 1
check_pod_status "avalanche-parallel" "app=postgres" 1 300 || exit 1

# Wait for worker pods
echo -e "\n${YELLOW}⏳ Waiting for worker pods...${NC}"
check_pod_status "avalanche-parallel" "app=consensus-worker" 3 300 || exit 1
check_pod_status "avalanche-parallel" "app=validator-worker" 3 300 || exit 1
check_pod_status "avalanche-parallel" "app=dag-state-worker" 2 300 || exit 1

# Show final status
echo -e "\n${YELLOW}📊 Final Cluster Status:${NC}"
minikube status
echo
kubectl cluster-info
echo
kubectl get nodes -o wide
echo
kubectl get pods -n avalanche-parallel -o wide
echo
kubectl get services -n avalanche-parallel

echo -e "\n${GREEN}✅ Benchmark environment is ready!${NC}"
echo -e "You can now run the benchmark tests." 