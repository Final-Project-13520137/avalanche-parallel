#!/bin/bash

# Avalanche Parallel Kubernetes Setup Script for Linux/WSL/Ubuntu
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
PROVIDER="docker-desktop"
CLUSTER_NAME="avalanche-parallel"
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
Avalanche Parallel Kubernetes Setup Script

Usage: $0 [OPTIONS]

Options:
  -p, --provider PROVIDER    Kubernetes provider (docker-desktop, kind, minikube)
  -n, --name CLUSTER_NAME    Name for the cluster (default: avalanche-parallel)
  -h, --help                 Show this help message

Examples:
  $0 --provider docker-desktop
  $0 --provider kind --name my-cluster
  $0 --provider minikube

Requirements:
  - Docker (for all providers)
  - kind (for kind provider): https://kind.sigs.k8s.io/docs/user/quick-start/
  - minikube (for minikube provider): https://minikube.sigs.k8s.io/docs/start/
  - kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/

For WSL users:
  - Make sure Docker Desktop is running on Windows with WSL2 integration enabled
  - Or install Docker Engine directly in WSL2
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        -n|--name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        -h|--help)
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

# Validate provider
if [[ ! "$PROVIDER" =~ ^(docker-desktop|kind|minikube)$ ]]; then
    print_msg $RED "Invalid provider: $PROVIDER"
    print_msg $YELLOW "Valid providers: docker-desktop, kind, minikube"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect WSL
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null || 
    grep -qi wsl /proc/version 2>/dev/null ||
    [ -n "${WSL_DISTRO_NAME}" ]
}

# Function to setup Docker Desktop Kubernetes
setup_docker_desktop() {
    print_msg $GREEN "Setting up Docker Desktop Kubernetes..."
    
    if ! command_exists docker; then
        print_msg $RED "Docker not found."
        if is_wsl; then
            print_msg $YELLOW "For WSL:"
            print_msg $YELLOW "1. Install Docker Desktop on Windows with WSL2 integration"
            print_msg $YELLOW "2. Or install Docker Engine in WSL2:"
            print_msg $YELLOW "   curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        else
            print_msg $YELLOW "Install Docker Engine:"
            print_msg $YELLOW "   curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        fi
        exit 1
    fi
    
    if is_wsl; then
        print_msg $YELLOW "WSL detected. Please ensure:"
        print_msg $YELLOW "1. Docker Desktop is running on Windows"
        print_msg $YELLOW "2. WSL2 integration is enabled in Docker Desktop settings"
        print_msg $YELLOW "3. Your WSL distro is enabled in Docker Desktop > Settings > Resources > WSL Integration"
    fi
    
    print_msg $YELLOW "Please enable Kubernetes in Docker Desktop:"
    print_msg $YELLOW "1. Open Docker Desktop"
    print_msg $YELLOW "2. Go to Settings > Kubernetes"
    print_msg $YELLOW "3. Check 'Enable Kubernetes'"
    print_msg $YELLOW "4. Click 'Apply & Restart'"
    print_msg $YELLOW ""
    print_msg $YELLOW "Press Enter after enabling Kubernetes..."
    read -r
    
    # Wait for cluster to be ready
    local max_retries=30
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        retry_count=$((retry_count + 1))
        print_msg $YELLOW "Waiting for Kubernetes cluster... (attempt $retry_count/$max_retries)"
        
        if kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
            print_msg $GREEN "Kubernetes cluster is ready!"
            kubectl config use-context docker-desktop
            return 0
        fi
        
        sleep 10
    done
    
    print_msg $RED "Failed to connect to Kubernetes cluster. Please check Docker Desktop settings."
    exit 1
}

# Function to setup kind cluster
setup_kind() {
    print_msg $GREEN "Setting up kind cluster..."
    
    if ! command_exists kind; then
        print_msg $YELLOW "kind not found. Installing kind..."
        
        # Install kind
        if command_exists go; then
            go install sigs.k8s.io/kind@v0.20.0
            # Add GOPATH/bin to PATH if not already there
            export PATH="$PATH:$(go env GOPATH)/bin"
        else
            # Install kind binary directly
            local kind_version="v0.20.0"
            local arch
            arch=$(uname -m)
            case $arch in
                x86_64) arch="amd64" ;;
                aarch64) arch="arm64" ;;
                *) print_msg $RED "Unsupported architecture: $arch"; exit 1 ;;
            esac
            
            curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${kind_version}/kind-linux-${arch}"
            chmod +x ./kind
            sudo mv ./kind /usr/local/bin/kind
        fi
    fi
    
    # Create kind cluster config
    cat > kind-config.yaml << EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  extraPortMappings:
  - containerPort: 80
    hostPort: 30080
    protocol: TCP
  - containerPort: 443
    hostPort: 30443
    protocol: TCP
  - containerPort: 30300
    hostPort: 30300
    protocol: TCP
- role: worker
- role: worker
EOF
    
    # Delete existing cluster if exists
    kind delete cluster --name "$CLUSTER_NAME" 2>/dev/null || true
    
    # Create new cluster
    print_msg $YELLOW "Creating kind cluster '$CLUSTER_NAME'..."
    kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml
    
    if [ $? -eq 0 ]; then
        print_msg $GREEN "Kind cluster '$CLUSTER_NAME' created successfully!"
        kubectl config use-context "kind-$CLUSTER_NAME"
        
        # Install ingress controller
        print_msg $YELLOW "Installing NGINX Ingress Controller..."
        kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
        
        # Wait for ingress controller
        print_msg $YELLOW "Waiting for ingress controller to be ready..."
        kubectl wait --namespace ingress-nginx --for=condition=ready pod --selector=app.kubernetes.io/component=controller --timeout=90s
        
        # Clean up config file
        rm -f kind-config.yaml
    else
        print_msg $RED "Failed to create kind cluster"
        exit 1
    fi
}

# Function to setup minikube
setup_minikube() {
    print_msg $GREEN "Setting up minikube cluster..."
    
    if ! command_exists minikube; then
        print_msg $YELLOW "minikube not found. Installing minikube..."
        
        # Install minikube
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
        rm minikube-linux-amd64
    fi
    
    # Stop existing cluster if running
    minikube stop -p "$CLUSTER_NAME" 2>/dev/null || true
    minikube delete -p "$CLUSTER_NAME" 2>/dev/null || true
    
    # Determine driver
    local driver="docker"
    if is_wsl; then
        print_msg $YELLOW "WSL detected. Using docker driver."
    fi
    
    # Start new cluster
    print_msg $YELLOW "Starting minikube cluster '$CLUSTER_NAME'..."
    minikube start -p "$CLUSTER_NAME" --nodes=3 --driver="$driver" --memory=4096 --cpus=2
    
    if [ $? -eq 0 ]; then
        print_msg $GREEN "Minikube cluster '$CLUSTER_NAME' started successfully!"
        kubectl config use-context "$CLUSTER_NAME"
        
        # Enable addons
        print_msg $YELLOW "Enabling minikube addons..."
        minikube addons enable ingress -p "$CLUSTER_NAME"
        minikube addons enable metrics-server -p "$CLUSTER_NAME"
    else
        print_msg $RED "Failed to start minikube cluster"
        exit 1
    fi
}

# Function to install kubectl if not present
install_kubectl() {
    if ! command_exists kubectl; then
        print_msg $YELLOW "kubectl not found. Installing kubectl..."
        
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        chmod +x kubectl
        sudo mv kubectl /usr/local/bin/
    fi
}

# Function to verify cluster
verify_cluster() {
    print_msg $YELLOW "Verifying cluster setup..."
    
    # Check cluster info
    kubectl cluster-info
    
    # Check nodes
    print_msg $YELLOW "Cluster nodes:"
    kubectl get nodes
    
    # Check if metrics server is available
    print_msg $YELLOW "Checking metrics server..."
    if ! kubectl top nodes >/dev/null 2>&1; then
        print_msg $YELLOW "Metrics server not available. Installing..."
        
        # First, delete any existing metrics-server installation
        kubectl delete deployment metrics-server -n kube-system --ignore-not-found=true
        kubectl delete service metrics-server -n kube-system --ignore-not-found=true
        kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found=true
        
        # Wait a bit for cleanup
        sleep 5
        
        # Install metrics server using local manifest
        local metrics_manifest="deployments/kubernetes/metrics-server.yaml"
        if [ -f "$metrics_manifest" ]; then
            print_msg $YELLOW "Installing metrics server from local manifest..."
            kubectl apply -f "$metrics_manifest"
        else
            print_msg $YELLOW "Local manifest not found, using remote..."
            # Fallback to remote installation with proper patching
            kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
            
            # Wait for deployment to be created
            sleep 10
            
            # Patch metrics server for local clusters
            kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"],"image":"registry.k8s.io/metrics-server/metrics-server:v0.7.0"}]}}}}'
        fi
        
        # Wait for metrics server to be ready
        print_msg $YELLOW "Waiting for metrics server to be ready..."
        kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system
    fi
    
    print_msg $GREEN "Cluster verification completed!"
}

# Main execution
print_msg $GREEN "=== Avalanche Parallel Kubernetes Setup ==="
print_msg $YELLOW "Provider: $PROVIDER"
print_msg $YELLOW "Cluster Name: $CLUSTER_NAME"

if is_wsl; then
    print_msg $YELLOW "WSL environment detected"
fi

print_msg $YELLOW ""

# Install kubectl if needed
install_kubectl

# Setup based on provider
case $PROVIDER in
    docker-desktop)
        setup_docker_desktop
        ;;
    kind)
        setup_kind
        ;;
    minikube)
        setup_minikube
        ;;
esac

verify_cluster

print_msg $GREEN ""
print_msg $GREEN "=== Setup completed successfully! ==="
print_msg $GREEN "You can now deploy Avalanche Parallel using:"
print_msg $YELLOW "./deploy.sh --build --registry localhost:5000" 