#!/bin/bash

# Avalanche Parallel Kubernetes Deployment Script
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="avalanche-parallel"
CONTEXT=""
BUILD_IMAGES=false
PUSH_IMAGES=false
REGISTRY="docker.io/your-registry"
TAG="latest"

# Function to print colored output
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

# Function to check prerequisites
check_prerequisites() {
    print_msg $YELLOW "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_msg $RED "kubectl is not installed. Please install kubectl first."
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null && [ "$BUILD_IMAGES" = true ]; then
        print_msg $RED "Docker is not installed. Please install Docker first."
        exit 1
    fi
    
    # Check kustomize (optional)
    if ! command -v kustomize &> /dev/null; then
        print_msg $YELLOW "kustomize is not installed. Using kubectl built-in kustomize."
    fi
    
    print_msg $GREEN "Prerequisites check passed!"
}

# Function to build Docker images
build_images() {
    if [ "$BUILD_IMAGES" = true ]; then
        print_msg $YELLOW "Building Docker images..."
        
        # Build main node image
        docker build -f ../docker/Dockerfile.main-node -t ${REGISTRY}/avalanche-main-node:${TAG} ../..
        
        # Build worker image
        docker build -f ../docker/Dockerfile.worker-node -t ${REGISTRY}/avalanche-worker:${TAG} ../..
        
        if [ "$PUSH_IMAGES" = true ]; then
            print_msg $YELLOW "Pushing images to registry..."
            docker push ${REGISTRY}/avalanche-main-node:${TAG}
            docker push ${REGISTRY}/avalanche-worker:${TAG}
        fi
        
        print_msg $GREEN "Docker images built successfully!"
    fi
}

# Function to update kustomization with image tags
update_kustomization() {
    print_msg $YELLOW "Updating kustomization with image tags..."
    
    # Use sed to update image tags in kustomization.yaml
    sed -i.bak "s|avalanche-parallel/main-node|${REGISTRY}/avalanche-main-node|g" kustomization.yaml
    sed -i.bak "s|avalanche-parallel/worker|${REGISTRY}/avalanche-worker|g" kustomization.yaml
    sed -i.bak "s|newTag: .*|newTag: ${TAG}|g" kustomization.yaml
    
    # Clean up backup files
    rm -f kustomization.yaml.bak
}

# Function to deploy to Kubernetes
deploy() {
    print_msg $YELLOW "Deploying to Kubernetes..."
    
    # Set context if provided
    if [ -n "$CONTEXT" ]; then
        kubectl config use-context $CONTEXT
    fi
    
    # Create namespace if it doesn't exist
    kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    # Apply configurations using kustomize
    if command -v kustomize &> /dev/null; then
        kustomize build . | kubectl apply -f -
    else
        kubectl apply -k .
    fi
    
    print_msg $GREEN "Deployment completed!"
}

# Function to wait for deployments to be ready
wait_for_ready() {
    print_msg $YELLOW "Waiting for deployments to be ready..."
    
    # Wait for RabbitMQ
    kubectl wait --for=condition=ready pod -l app=rabbitmq -n $NAMESPACE --timeout=300s
    
    # Wait for main node
    kubectl wait --for=condition=ready pod -l app=avalanche-main-node -n $NAMESPACE --timeout=300s
    
    # Wait for workers
    kubectl wait --for=condition=ready pod -l app=avalanche-worker -n $NAMESPACE --timeout=300s
    
    # Wait for monitoring
    kubectl wait --for=condition=ready pod -l app=prometheus -n $NAMESPACE --timeout=300s
    kubectl wait --for=condition=ready pod -l app=grafana -n $NAMESPACE --timeout=300s
    
    print_msg $GREEN "All deployments are ready!"
}

# Function to show access information
show_access_info() {
    print_msg $GREEN "\n=== Access Information ==="
    
    # Get NodePort services
    API_PORT=$(kubectl get svc avalanche-api-gateway -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="http")].nodePort}')
    GRAFANA_PORT=$(kubectl get svc grafana -n $NAMESPACE -o jsonpath='{.spec.ports[?(@.name=="web")].nodePort}')
    
    # Get node IP (works for most clusters)
    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
    if [ -z "$NODE_IP" ]; then
        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
    fi
    
    print_msg $GREEN "API Gateway: http://${NODE_IP}:${API_PORT}"
    print_msg $GREEN "Grafana: http://${NODE_IP}:${GRAFANA_PORT} (admin/avalanche123)"
    print_msg $GREEN "\nTo check worker scaling:"
    print_msg $YELLOW "kubectl get hpa -n $NAMESPACE"
    print_msg $GREEN "\nTo scale workers manually:"
    print_msg $YELLOW "kubectl scale deployment avalanche-worker -n $NAMESPACE --replicas=10"
}

# Main script
main() {
    print_msg $GREEN "=== Avalanche Parallel Kubernetes Deployment ==="
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --build)
                BUILD_IMAGES=true
                shift
                ;;
            --push)
                PUSH_IMAGES=true
                BUILD_IMAGES=true
                shift
                ;;
            --registry)
                REGISTRY="$2"
                shift 2
                ;;
            --tag)
                TAG="$2"
                shift 2
                ;;
            --context)
                CONTEXT="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --build        Build Docker images"
                echo "  --push         Push images to registry (implies --build)"
                echo "  --registry     Docker registry (default: docker.io/your-registry)"
                echo "  --tag          Image tag (default: latest)"
                echo "  --context      Kubernetes context to use"
                echo "  --help         Show this help message"
                exit 0
                ;;
            *)
                print_msg $RED "Unknown option: $1"
                exit 1
                ;;
        esac
    done
    
    check_prerequisites
    build_images
    update_kustomization
    deploy
    wait_for_ready
    show_access_info
    
    print_msg $GREEN "\n=== Deployment completed successfully! ==="
}

# Run main function
main "$@" 