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
        print_msg $YELLOW "Install kubectl:"
        print_msg $YELLOW "  curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
        print_msg $YELLOW "  chmod +x kubectl && sudo mv kubectl /usr/local/bin/"
        exit 1
    fi
    
    # Check docker
    if ! command -v docker &> /dev/null && [ "$BUILD_IMAGES" = true ]; then
        print_msg $RED "Docker is not installed. Please install Docker first."
        print_msg $YELLOW "Install Docker:"
        print_msg $YELLOW "  curl -fsSL https://get.docker.com -o get-docker.sh && sh get-docker.sh"
        exit 1
    fi
    
    # Check Kubernetes cluster connectivity
    print_msg $YELLOW "Checking Kubernetes cluster connectivity..."
    if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
        print_msg $RED "No Kubernetes cluster found or cluster is not accessible."
        print_msg $YELLOW "Please run one of the following to setup a cluster:"
        print_msg $YELLOW "  ./setup-k8s.sh --provider docker-desktop"
        print_msg $YELLOW "  ./setup-k8s.sh --provider kind"
        print_msg $YELLOW "  ./setup-k8s.sh --provider minikube"
        print_msg $YELLOW ""
        print_msg $YELLOW "Or if you want to deploy only Docker images without Kubernetes:"
        print_msg $YELLOW "  ./deploy-docker.sh --build --workers 3"
        exit 1
    fi
    print_msg $GREEN "Kubernetes cluster is accessible!"
    
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
        
        # Ensure go.mod.docker exists
        if [ ! -f "../../go.mod.docker" ]; then
            print_msg $RED "go.mod.docker not found. Creating it..."
            # Create go.mod.docker from go.mod by removing incompatible lines
            sed 's/go 1\.23\.9/go 1.21/' ../../go.mod | grep -v "toolchain" > ../../go.mod.docker
        fi
        
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
    
    # Apply configurations using kustomize with validation disabled for local clusters
    print_msg $YELLOW "Applying Kubernetes configurations..."
    
    # Try kustomize first
    if command -v kustomize &> /dev/null; then
        if ! kustomize build . | kubectl apply -f - --validate=false; then
            print_msg $YELLOW "Kustomize failed, trying individual file deployment..."
            deploy_individual_files
        fi
    else
        if ! kubectl apply -k . --validate=false; then
            print_msg $YELLOW "Kubectl kustomize failed, trying individual file deployment..."
            deploy_individual_files
        fi
    fi
    
    print_msg $GREEN "Deployment completed!"
    
    # Install metrics server for HPA to work
    install_metrics_server
}

# Function to deploy individual files as fallback
deploy_individual_files() {
    local files=(
        "00-namespace.yaml"
        "01-message-queue.yaml"
        "02-main-node.yaml"
        "03-worker-deployment.yaml"
        "04-api-gateway.yaml"
        "05-monitoring.yaml"
        "06-grafana-dashboard.yaml"
    )
    
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_msg $YELLOW "Applying $file..."
            kubectl apply -f "$file" --validate=false
        else
            print_msg $YELLOW "Warning: $file not found, skipping..."
        fi
    done
}

# Function to install metrics server if needed
install_metrics_server() {
    print_msg $YELLOW "Checking metrics server..."
    
    # Check if metrics server is already running
    if kubectl get deployment metrics-server -n kube-system >/dev/null 2>&1; then
        print_msg $GREEN "Metrics server already installed"
        return 0
    fi
    
    print_msg $YELLOW "Installing metrics server..."
    
    # Try to use local manifest first
    if [ -f "metrics-server.yaml" ]; then
        print_msg $YELLOW "Using local metrics-server manifest..."
        kubectl apply -f metrics-server.yaml --validate=false
    else
        print_msg $YELLOW "Local manifest not found, creating one..."
        
        # Create temporary metrics server manifest
        cat > temp-metrics-server.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
        imagePullPolicy: IfNotPresent
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
EOF
        
        # Apply the complete metrics server from remote
        kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml --validate=false
        
        # Wait for deployment to exist
        sleep 10
        
        # Patch the deployment with correct image and args
        kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"],"image":"registry.k8s.io/metrics-server/metrics-server:v0.7.0"}]}}}}' --validate=false
        
        # Clean up temp file
        rm -f temp-metrics-server.yaml
    fi
    
    # Wait for metrics server to be ready
    print_msg $YELLOW "Waiting for metrics server to be ready..."
    kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system || true
    
    print_msg $GREEN "Metrics server installation completed"
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