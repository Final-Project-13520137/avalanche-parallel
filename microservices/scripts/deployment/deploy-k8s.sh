#!/bin/bash
# Deploy to Kubernetes for Avalanche Parallel Processing

# Default values
BUILD=false
REGISTRY="localhost:5000"
NAMESPACE="avalanche-parallel"
KUBECONFIG="$HOME/.kube/config"

# Function to show usage
usage() {
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  --build              Build and push Docker images"
    echo "  --registry <url>     Docker registry URL (default: $REGISTRY)"
    echo "  --namespace <name>   Kubernetes namespace (default: $NAMESPACE)"
    echo "  --kubeconfig <path>  Path to kubeconfig (default: $KUBECONFIG)"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD=true
            shift
            ;;
        --registry)
            REGISTRY="$2"
            shift 2
            ;;
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --kubeconfig)
            KUBECONFIG="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

echo -e "\e[32m🚀 Deploying Avalanche Parallel Processing to Kubernetes...\e[0m"

# Check prerequisites
echo -e "\e[33mChecking prerequisites...\e[0m"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo -e "\e[31m❌ kubectl not found. Please install kubectl.\e[0m"
    exit 1
fi

# Check kubeconfig
if [ ! -f "$KUBECONFIG" ]; then
    echo -e "\e[31m❌ kubeconfig not found at $KUBECONFIG\e[0m"
    exit 1
fi

# Build and push images if requested
if [ "$BUILD" = true ]; then
    echo -e "\e[33m🔨 Building and pushing Docker images...\e[0m"
    
    # Build images
    docker-compose -f docker-compose.worker-pools.yml build
    
    # Tag images
    docker tag microservices-consensus-worker:latest "$REGISTRY/consensus-worker:latest"
    docker tag microservices-validator-worker:latest "$REGISTRY/validator-worker:latest"
    docker tag microservices-dag-state-worker:latest "$REGISTRY/dag-state-worker:latest"
    
    # Push images
    docker push "$REGISTRY/consensus-worker:latest"
    docker push "$REGISTRY/validator-worker:latest"
    docker push "$REGISTRY/dag-state-worker:latest"
fi

# Create namespace if not exists
kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Apply Kubernetes manifests
echo -e "\e[33m📦 Applying Kubernetes manifests...\e[0m"

# Apply in order
manifests=(
    "k8s/namespace.yaml"
    "k8s/configmap.yaml"
    "k8s/secret.yaml"
    "k8s/redis.yaml"
    "k8s/postgres.yaml"
    "k8s/consensus-worker.yaml"
    "k8s/validator-worker.yaml"
    "k8s/dag-state-worker.yaml"
    "k8s/api-gateway.yaml"
    "k8s/monitoring.yaml"
)

for manifest in "${manifests[@]}"; do
    if [ -f "$manifest" ]; then
        echo -e "\e[36mApplying $manifest...\e[0m"
        kubectl apply -f "$manifest" -n "$NAMESPACE"
    fi
done

# Wait for pods to be ready
echo -e "\e[33m⏳ Waiting for pods to be ready...\e[0m"
kubectl wait --for=condition=ready pod --all -n "$NAMESPACE" --timeout=300s

# Show status
echo -e "\n\e[32m📊 Deployment Status:\e[0m"
kubectl get pods -n "$NAMESPACE"

echo -e "\n\e[32m✅ Deployment completed!\e[0m"
echo -e "\e[36m🔍 Next steps:
1. Check pod status: kubectl get pods -n $NAMESPACE
2. View logs: kubectl logs -f -n $NAMESPACE <pod-name>
3. Monitor metrics: kubectl port-forward -n $NAMESPACE svc/grafana 3000:3000\e[0m" 