#!/bin/bash
# Script for scaling worker nodes in Avalanche Parallel Processing

# Default values
ENVIRONMENT="docker"
NAMESPACE="avalanche-parallel"
COMPOSE_FILE="docker-compose.worker-pools.yml"
FORCE=false
MONITOR=false
TIMEOUT=300  # 5 minutes timeout
INTERVAL=10  # Check every 10 seconds

# Help function
show_help() {
    echo "Usage: $0 [OPTIONS] WORKERS"
    echo
    echo "Scale worker nodes in Avalanche Parallel Processing"
    echo
    echo "Options:"
    echo "  -e, --environment    Environment (docker or kubernetes) [default: docker]"
    echo "  -n, --namespace      Kubernetes namespace [default: avalanche-parallel]"
    echo "  -f, --file          Docker compose file [default: docker-compose.worker-pools.yml]"
    echo "  -h, --help          Show this help message"
    echo
    echo "Example:"
    echo "  $0 --environment kubernetes 5    # Scale to 5 workers in Kubernetes"
    echo "  $0 --environment docker 3        # Scale to 3 workers in Docker"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -f|--file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            WORKERS=$1
            shift
            ;;
    esac
done

# Validate input
if [ -z "$WORKERS" ]; then
    echo "Error: Number of workers must be specified"
    show_help
    exit 1
fi

if ! [[ "$WORKERS" =~ ^[0-9]+$ ]]; then
    echo "Error: Workers must be a positive integer"
    exit 1
fi

if [ "$ENVIRONMENT" != "docker" ] && [ "$ENVIRONMENT" != "kubernetes" ]; then
    echo "Error: Environment must be either 'docker' or 'kubernetes'"
    exit 1
fi

# Function to check resource availability
check_resources() {
    # Get CPU usage
    CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    
    # Get memory usage
    MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
    MEM_USED=$(free | grep Mem | awk '{print $3}')
    MEM_USAGE=$(echo "scale=2; $MEM_USED/$MEM_TOTAL * 100" | bc)
    
    if (( $(echo "$CPU_USAGE > 80" | bc -l) )) || (( $(echo "$MEM_USAGE > 80" | bc -l) )); then
        echo -e "\e[33m⚠️ Warning: High resource usage detected!\e[0m"
        echo -e "\e[33mCPU Usage: ${CPU_USAGE}%\e[0m"
        echo -e "\e[33mMemory Usage: ${MEM_USAGE}%\e[0m"
        
        if [ "$FORCE" = false ]; then
            read -p "Continue scaling? (y/n) " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

# Function to get current worker count
get_current_workers() {
    local type=$1
    docker ps --format "{{.Names}}" | grep -c "$type"
}

# Function to monitor scaling
monitor_scaling() {
    local type=$1
    local target_count=$2
    local elapsed=0
    
    echo -e "\e[36m📊 Monitoring scaling process...\e[0m"
    
    while [ $elapsed -lt $TIMEOUT ]; do
        current_count=$(get_current_workers "$type")
        if [ "$current_count" -eq "$target_count" ]; then
            status="✅"
        else
            status="⏳"
        fi
        
        echo -e "\e[33m[$status] Current $type workers: $current_count / Target: $target_count\e[0m"
        
        if [ "$current_count" -eq "$target_count" ]; then
            echo -e "\e[32m✅ Scaling completed successfully!\e[0m"
            return 0
        fi
        
        sleep $INTERVAL
        elapsed=$((elapsed + INTERVAL))
    done
    
    echo -e "\e[31m❌ Scaling timeout reached!\e[0m"
    return 1
}

# Function to scale Docker workers
scale_docker() {
    local workers=$1
    local compose_file=$2

    echo "Scaling Docker workers to $workers instances..."

    if [ ! -f "$compose_file" ]; then
        echo "Error: Docker compose file not found: $compose_file"
        exit 1
    }

    # Scale worker service
    if docker-compose -f "$compose_file" up -d --scale worker="$workers"; then
        echo "Successfully scaled workers to $workers instances"
    else
        echo "Error: Failed to scale workers"
        exit 1
    fi
}

# Function to scale Kubernetes workers
scale_kubernetes() {
    local workers=$1
    local namespace=$2

    echo "Scaling Kubernetes workers to $workers instances..."

    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl not found. Please install kubectl and configure your Kubernetes cluster."
        exit 1
    }

    # Check if namespace exists
    if ! kubectl get namespace "$namespace" &> /dev/null; then
        echo "Error: Namespace '$namespace' not found"
        exit 1
    }

    # Scale deployment
    if kubectl scale deployment avalanche-worker -n "$namespace" --replicas="$workers"; then
        echo "Successfully scaled workers to $workers instances"
        
        # Wait for scaling to complete
        echo "Waiting for scaling to complete..."
        kubectl rollout status deployment/avalanche-worker -n "$namespace"
        
        # Show current pods
        echo -e "\nCurrent worker pods:"
        kubectl get pods -n "$namespace" -l app=avalanche-worker
    else
        echo "Error: Failed to scale workers"
        exit 1
    fi
}

# Main execution
if [ "$ENVIRONMENT" = "docker" ]; then
    scale_docker "$WORKERS" "$COMPOSE_FILE"
else
    scale_kubernetes "$WORKERS" "$NAMESPACE"
fi

# Show monitoring command
echo -e "\n\e[36m📊 Monitor workers with:
docker-compose -f $COMPOSE_FILE logs -f\e[0m" 