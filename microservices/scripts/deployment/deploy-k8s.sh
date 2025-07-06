#!/bin/bash
# Script for deploying Avalanche Parallel Processing to Kubernetes

# Colors
RED='\e[31m'
GREEN='\e[32m'
BLUE='\e[36m'
YELLOW='\e[33m'
NC='\e[0m' # No Color

# Default values
BUILD=false
REGISTRY="localhost:5000"
NAMESPACE="avalanche-parallel"
FORCE=false

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../" && pwd)"

# Function to display usage
usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  --build              Build and push Docker images"
    echo "  --registry <url>     Docker registry URL (default: localhost:5000)"
    echo "  --namespace <name>   Kubernetes namespace (default: avalanche-parallel)"
    echo "  --force             Force deployment even if prerequisites fail"
    echo "  --help              Show this help message"
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
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Error: Unknown option $1${NC}"
            usage
            ;;
    esac
done

# Function to check prerequisites
check_prerequisites() {
    echo -e "${BLUE}🔍 Checking prerequisites...${NC}"

    # Check Docker
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}❌ Docker is not running${NC}"
        if [ "$FORCE" = false ]; then
            exit 1
        fi
    fi

    # Check kubectl
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl${NC}"
        if [ "$FORCE" = false ]; then
            exit 1
        fi
    fi

    # Check if registry is accessible
    if [ "$REGISTRY" = "localhost:5000" ]; then
        if ! curl -s "http://$REGISTRY/v2/" > /dev/null; then
            echo -e "${RED}❌ Local registry not accessible. Start it with: docker run -d -p 5000:5000 --name registry registry:2${NC}"
            if [ "$FORCE" = false ]; then
                exit 1
            fi
        fi
    fi

    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to build and push Docker images
build_images() {
    echo -e "${BLUE}🔨 Building Docker images...${NC}"

    local services=("consensus-worker" "validator-worker" "dag-state-worker")
    local build_context="$PROJECT_ROOT/workers"

    for service in "${services[@]}"; do
        local dockerfile="$build_context/$service/Dockerfile"
        local tag="$REGISTRY/$service:latest"

        echo -e "${BLUE}Building $service...${NC}"
        if ! docker build -t "$tag" -f "$dockerfile" "$build_context"; then
            echo -e "${RED}❌ Failed to build $service${NC}"
            exit 1
        fi

        echo -e "${BLUE}Pushing $service to registry...${NC}"
        if ! docker push "$tag"; then
            echo -e "${RED}❌ Failed to push $service${NC}"
            exit 1
        fi
    done

    echo -e "${GREEN}✅ All images built and pushed successfully${NC}"
}

# Function to apply Kubernetes manifests
apply_manifests() {
    echo -e "${BLUE}📦 Applying Kubernetes manifests...${NC}"

    # Create or update namespace
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

    # Apply ConfigMap
    local config_map="$PROJECT_ROOT/k8s/configmap.yaml"
    echo -e "${BLUE}Applying ConfigMap...${NC}"
    if [ -f "$config_map" ]; then
        sed "s/namespace: avalanche/namespace: $NAMESPACE/g" "$config_map" | kubectl apply -f - -n "$NAMESPACE"
    else
        echo -e "${RED}❌ ConfigMap not found at $config_map${NC}"
        exit 1
    fi

    # Apply worker deployments
    local k8s_path="$PROJECT_ROOT/k8s/worker-pools"
    for deployment in "$k8s_path"/*-deployment.yaml; do
        if [ -f "$deployment" ]; then
            echo -e "${BLUE}Applying $(basename "$deployment")...${NC}"
            sed -e "s|localhost:5000|$REGISTRY|g" \
                -e "s/namespace: avalanche/namespace: $NAMESPACE/g" \
                "$deployment" | kubectl apply -f - -n "$NAMESPACE"
        fi
    done

    echo -e "${GREEN}✅ Kubernetes manifests applied successfully${NC}"
}

# Function to wait for pods
wait_for_pods() {
    echo -e "${BLUE}⏳ Waiting for pods to be ready...${NC}"
    
    local timeout=300 # 5 minutes
    local elapsed=0
    local interval=5

    while [ $elapsed -lt $timeout ]; do
        local all_ready=true
        local pods
        pods=$(kubectl get pods -n "$NAMESPACE" -o json)
        
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ Failed to get pods${NC}"
            exit 1
        fi

        while read -r name status ready; do
            if [ "$status" != "Running" ] || [ "$ready" != "true" ]; then
                all_ready=false
                break
            fi
        done < <(echo "$pods" | jq -r '.items[] | "\(.metadata.name) \(.status.phase) \(.status.containerStatuses[0].ready)"')

        if [ "$all_ready" = true ]; then
            echo -e "${GREEN}✅ All pods are ready${NC}"
            return
        fi

        sleep $interval
        elapsed=$((elapsed + interval))
    done

    echo -e "${RED}❌ Timeout waiting for pods to be ready${NC}"
    exit 1
}

# Main execution
echo -e "${BLUE}🚀 Deploying Avalanche Parallel Processing to Kubernetes...${NC}"

# Check prerequisites
check_prerequisites

# Build and push images if requested
if [ "$BUILD" = true ]; then
    build_images
fi

# Apply Kubernetes manifests
apply_manifests

# Wait for pods to be ready
wait_for_pods

# Show deployment status
echo -e "\n${BLUE}📊 Deployment Status:${NC}"
kubectl get pods -n "$NAMESPACE"
echo -e "\n${GREEN}✨ Deployment completed successfully!${NC}"

# Show next steps
cat << EOF

🔍 Next steps:
1. Check pod logs:
   kubectl logs -f -n $NAMESPACE <pod-name>

2. Access services:
   - API Gateway: http://localhost:30080
   - Monitoring: http://localhost:30300

3. Scale workers:
   ./scripts/scaling/scale-workers.sh --type <worker-type> --count <number>

EOF 