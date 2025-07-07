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
TIMEOUT=600  # 10 minutes timeout
INTERVAL=10  # Check every 10 seconds

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

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
        exit 1
    fi

    # Check kubectl
    if ! command -v kubectl > /dev/null 2>&1; then
        echo -e "${RED}❌ kubectl not found. Please install kubectl${NC}"
        exit 1
    fi

    # Check if registry is accessible
    if [ "$REGISTRY" = "localhost:5000" ]; then
        if ! curl -s "http://$REGISTRY/v2/" > /dev/null; then
            echo -e "${RED}❌ Local registry not accessible. Run setup-registry.sh first${NC}"
            exit 1
        fi
    fi

    echo -e "${GREEN}✅ Prerequisites check passed${NC}"
}

# Function to prepare build environment
prepare_build() {
    echo -e "${BLUE}📦 Preparing build environment...${NC}"
    
    # Run prepare-build script
    if ! "$SCRIPT_DIR/../setup/prepare-build.sh"; then
        echo -e "${RED}❌ Failed to prepare build environment${NC}"
        exit 1
    fi
}

# Function to build and push images
build_images() {
    echo -e "${BLUE}🔨 Building and pushing images...${NC}"

    local services=("consensus-worker" "validator-worker" "dag-state-worker")
    
    for service in "${services[@]}"; do
        echo -e "${BLUE}Building $service...${NC}"
        
        # Build image
        if ! docker build \
            -t "$REGISTRY/avalanche-$service:latest" \
            -f "$PROJECT_ROOT/microservices/workers/$service/Dockerfile" \
            "$PROJECT_ROOT"; then
            echo -e "${RED}❌ Failed to build $service${NC}"
            exit 1
        fi

        # Push image
        echo -e "${BLUE}Pushing $service to registry...${NC}"
        if ! docker push "$REGISTRY/avalanche-$service:latest"; then
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
    local config_map="$PROJECT_ROOT/microservices/k8s/configmap.yaml"
    echo -e "${BLUE}Applying ConfigMap...${NC}"
    if [ -f "$config_map" ]; then
        sed "s/namespace: avalanche/namespace: $NAMESPACE/g" "$config_map" | kubectl apply -f - -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️ ConfigMap not found at $config_map, skipping...${NC}"
    fi

    # Apply Redis deployment
    local redis_deployment="$PROJECT_ROOT/microservices/k8s/redis-deployment.yaml"
    echo -e "${BLUE}Applying Redis deployment...${NC}"
    if [ -f "$redis_deployment" ]; then
        sed "s/namespace: avalanche-parallel/namespace: $NAMESPACE/g" "$redis_deployment" | kubectl apply -f - -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️ Redis deployment not found at $redis_deployment, skipping...${NC}"
    fi

    # Apply PostgreSQL initialization scripts
    local postgres_init="$PROJECT_ROOT/microservices/k8s/postgres-init.yaml"
    echo -e "${BLUE}Applying PostgreSQL initialization scripts...${NC}"
    if [ -f "$postgres_init" ]; then
        sed "s/namespace: avalanche-parallel/namespace: $NAMESPACE/g" "$postgres_init" | kubectl apply -f - -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️ PostgreSQL init scripts not found at $postgres_init, skipping...${NC}"
    fi

    # Apply PostgreSQL deployment
    local postgres_deployment="$PROJECT_ROOT/microservices/k8s/postgres-deployment.yaml"
    echo -e "${BLUE}Applying PostgreSQL deployment...${NC}"
    if [ -f "$postgres_deployment" ]; then
        sed "s/namespace: avalanche-parallel/namespace: $NAMESPACE/g" "$postgres_deployment" | kubectl apply -f - -n "$NAMESPACE"
    else
        echo -e "${YELLOW}⚠️ PostgreSQL deployment not found at $postgres_deployment, skipping...${NC}"
    fi

    # Apply worker deployments
    local k8s_path="$PROJECT_ROOT/microservices/k8s/worker-pools"
    for deployment in "$k8s_path"/*-deployment.yaml; do
        if [ -f "$deployment" ]; then
            echo -e "${BLUE}Applying $(basename "$deployment")...${NC}"
            sed -e "s|localhost:5000|$REGISTRY|g" \
                -e "s/namespace: avalanche-parallel/namespace: $NAMESPACE/g" \
                "$deployment" | kubectl apply -f - -n "$NAMESPACE"
        fi
    done

    echo -e "${GREEN}✅ Kubernetes manifests applied successfully${NC}"
}

# Function to check pod status
check_pod_status() {
    local pod_name=$1
    local pod_status
    local pod_ready
    local pod_restarts
    local pod_age
    
    pod_status=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null)
    pod_ready=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].ready}' 2>/dev/null)
    pod_restarts=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.status.containerStatuses[0].restartCount}' 2>/dev/null)
    pod_age=$(kubectl get pod "$pod_name" -n "$NAMESPACE" -o jsonpath='{.metadata.creationTimestamp}' 2>/dev/null)
    
    # Handle cases where containerStatuses might not exist yet
    if [ -z "$pod_ready" ]; then
        pod_ready="false"
    fi
    if [ -z "$pod_restarts" ]; then
        pod_restarts="0"
    fi
    
    if [ "$pod_status" = "Running" ] && [ "$pod_ready" = "true" ]; then
        echo -e "${GREEN}✓${NC} $pod_name is ready (Restarts: $pod_restarts)"
        return 0
    else
        # Get pod events
        local events
        events=$(kubectl get events -n "$NAMESPACE" --field-selector involvedObject.name="$pod_name" --sort-by='.lastTimestamp' -o custom-columns=TYPE:.type,REASON:.reason,MESSAGE:.message --no-headers 2>/dev/null)
        
        echo -e "${YELLOW}⚠${NC} $pod_name is not ready:"
        echo -e "  Status: $pod_status"
        echo -e "  Ready: $pod_ready"
        echo -e "  Restarts: $pod_restarts"
        echo -e "  Age: $pod_age"
        
        if [ ! -z "$events" ]; then
            echo -e "  Recent events:"
            echo "$events" | tail -n 3 | while read -r line; do
                echo -e "    $line"
            done
        fi
        
        # Get pod logs if available
        local logs
        logs=$(kubectl logs "$pod_name" -n "$NAMESPACE" --tail=3 2>/dev/null)
        if [ ! -z "$logs" ]; then
            echo -e "  Recent logs:"
            echo "$logs" | while read -r line; do
                echo -e "    $line"
            done
        fi
        
        return 1
    fi
}

# Function to wait for pods
wait_for_pods() {
    echo -e "${BLUE}⏳ Waiting for pods to be ready...${NC}"
    
    local elapsed=0
    local all_ready
    local pods_list
    
    while [ $elapsed -lt $TIMEOUT ]; do
        echo -e "\n${BLUE}Checking pod status (${elapsed}s elapsed):${NC}"
        
        all_ready=true
        pods_list=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
        
        if [ -z "$pods_list" ]; then
            echo -e "${YELLOW}No pods found in namespace $NAMESPACE${NC}"
            all_ready=false
        else
            for pod in $pods_list; do
                if ! check_pod_status "$pod"; then
                    all_ready=false
                fi
            done
        fi
        
        if [ "$all_ready" = true ]; then
            echo -e "\n${GREEN}✅ All pods are ready!${NC}"
            return 0
        fi
        
        # Show troubleshooting tips if taking too long
        if [ $elapsed -ge 300 ]; then  # After 5 minutes
            echo -e "\n${YELLOW}⚠️ Taking longer than expected. Troubleshooting tips:${NC}"
            echo "1. Check pod events: kubectl get events -n $NAMESPACE"
            echo "2. Check pod logs: kubectl logs <pod-name> -n $NAMESPACE"
            echo "3. Check pod description: kubectl describe pod <pod-name> -n $NAMESPACE"
            echo "4. Check node resources: kubectl describe nodes"
            echo "5. Check registry access: curl -v http://$REGISTRY/v2/_catalog"
        fi
        
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
        
        # Show progress
        echo -e "${BLUE}Waiting for pods to be ready... (${elapsed}s/${TIMEOUT}s)${NC}"
    done
    
    echo -e "\n${RED}❌ Timeout waiting for pods to be ready${NC}"
    echo -e "\n${YELLOW}Final pod status:${NC}"
    kubectl get pods -n "$NAMESPACE" -o wide
    
    echo -e "\n${YELLOW}Pod descriptions:${NC}"
    for pod in $pods_list; do
        echo -e "\n${BLUE}=== $pod ===${NC}"
        kubectl describe pod "$pod" -n "$NAMESPACE" | grep -A 5 "Events:"
    done
    
    echo -e "\n${YELLOW}Troubleshooting steps:${NC}"
    echo "1. Check pod events:"
    echo "   kubectl get events -n $NAMESPACE --sort-by='.lastTimestamp'"
    echo "2. Check pod logs:"
    echo "   kubectl logs <pod-name> -n $NAMESPACE"
    echo "3. Check pod description:"
    echo "   kubectl describe pod <pod-name> -n $NAMESPACE"
    echo "4. Check node resources:"
    echo "   kubectl describe nodes"
    echo "5. Check registry access:"
    echo "   curl -v http://$REGISTRY/v2/_catalog"
    echo "6. Check registry images:"
    echo "   curl -v http://$REGISTRY/v2/_catalog | jq"
    
    exit 1
}

# Main execution
echo -e "${BLUE}🚀 Deploying Avalanche Parallel Processing to Kubernetes...${NC}"

# Check prerequisites
check_prerequisites

# Build and push images if requested
if [ "$BUILD" = true ]; then
    prepare_build
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