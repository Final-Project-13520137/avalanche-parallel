#!/bin/bash

# Avalanche Parallel Docker Compose Deployment Script for Linux/WSL/Ubuntu
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BUILD=false
STOP=false
LOGS=false
STATUS=false
WORKERS=3
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
Avalanche Parallel Docker Compose Deployment Script

Usage: $0 [OPTIONS]

Options:
  -b, --build             Build Docker images before deployment
  -s, --stop              Stop all services
  -l, --logs              Show logs from all services
  --status                Show status of all services
  -w, --workers NUMBER    Number of worker instances (default: 3)
  -h, --help              Show this help message

Examples:
  $0 --build
  $0 --workers 5
  $0 --stop
  $0 --logs
  $0 --status
EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -b|--build)
            BUILD=true
            shift
            ;;
        -s|--stop)
            STOP=true
            shift
            ;;
        -l|--logs)
            LOGS=true
            shift
            ;;
        --status)
            STATUS=true
            shift
            ;;
        -w|--workers)
            WORKERS="$2"
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

# Function to check prerequisites
check_prerequisites() {
    print_msg $YELLOW "Checking prerequisites..."
    
    if ! command_exists docker; then
        print_msg $RED "Docker is not installed."
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
    
    # Check for docker-compose or docker compose
    if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
        print_msg $RED "Docker Compose is not installed."
        print_msg $YELLOW "Install Docker Compose:"
        print_msg $YELLOW "   sudo curl -L \"https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose"
        print_msg $YELLOW "   sudo chmod +x /usr/local/bin/docker-compose"
        exit 1
    fi
    
    print_msg $GREEN "Prerequisites check passed!"
}

# Function to get docker compose command
get_docker_compose_cmd() {
    if command_exists docker-compose; then
        echo "docker-compose"
    else
        echo "docker compose"
    fi
}

# Function to build images
build_images() {
    if [ "$BUILD" = true ]; then
        print_msg $YELLOW "Building Docker images..."
        
        # Get project root directory
        local project_root
        project_root="$(cd "$(dirname "$0")/../.." && pwd)"
        
        # Build main node image
        print_msg $YELLOW "Building main node image..."
        docker build -f "$project_root/deployments/docker/Dockerfile.main-node" -t avalanche-parallel/main-node:latest "$project_root"
        
        if [ $? -ne 0 ]; then
            print_msg $RED "Failed to build main node image"
            exit 1
        fi
        
        # Build worker image
        print_msg $YELLOW "Building worker image..."
        docker build -f "$project_root/deployments/docker/Dockerfile.worker-node" -t avalanche-parallel/worker:latest "$project_root"
        
        if [ $? -ne 0 ]; then
            print_msg $RED "Failed to build worker image"
            exit 1
        fi
        
        print_msg $GREEN "Docker images built successfully!"
    fi
}

# Function to deploy services
deploy_services() {
    print_msg $YELLOW "Deploying services with Docker Compose..."
    
    # Get project root directory
    local project_root
    project_root="$(cd "$(dirname "$0")/../.." && pwd)"
    
    # Change to project root
    cd "$project_root"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    # Stop existing services
    $compose_cmd -f config/docker-compose.yml down 2>/dev/null || true
    
    # Start services
    print_msg $YELLOW "Starting services with $WORKERS workers..."
    $compose_cmd -f config/docker-compose.yml up -d --scale worker="$WORKERS"
    
    if [ $? -eq 0 ]; then
        print_msg $GREEN "Services deployed successfully!"
        
        print_msg $YELLOW "Waiting for services to be ready..."
        sleep 10
        
        show_service_status
        show_access_info
    else
        print_msg $RED "Failed to deploy services"
        exit 1
    fi
}

# Function to stop services
stop_services() {
    print_msg $YELLOW "Stopping all services..."
    
    local project_root
    project_root="$(cd "$(dirname "$0")/../.." && pwd)"
    cd "$project_root"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    $compose_cmd -f config/docker-compose.yml down
    print_msg $GREEN "All services stopped!"
}

# Function to show logs
show_logs() {
    print_msg $YELLOW "Showing logs from all services..."
    
    local project_root
    project_root="$(cd "$(dirname "$0")/../.." && pwd)"
    cd "$project_root"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    $compose_cmd -f config/docker-compose.yml logs -f
}

# Function to show service status
show_service_status() {
    print_msg $YELLOW "Service Status:"
    
    local project_root
    project_root="$(cd "$(dirname "$0")/../.." && pwd)"
    cd "$project_root"
    
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    
    $compose_cmd -f config/docker-compose.yml ps
}

# Function to show access information
show_access_info() {
    print_msg $GREEN ""
    print_msg $GREEN "=== Access Information ==="
    
    if is_wsl; then
        print_msg $GREEN "Avalanche Node API: http://localhost:9650"
        print_msg $GREEN "Worker Health Check: http://localhost:9652/health"
        print_msg $GREEN "Prometheus: http://localhost:19090"
        print_msg $GREEN "Grafana: http://localhost:13000 (admin/admin)"
        print_msg $GREEN "RabbitMQ Management: http://localhost:15672 (guest/guest)"
    else
        print_msg $GREEN "Avalanche Node API: http://localhost:9650"
        print_msg $GREEN "Worker Health Check: http://localhost:9652/health"
        print_msg $GREEN "Prometheus: http://localhost:19090"
        print_msg $GREEN "Grafana: http://localhost:13000 (admin/admin)"
        print_msg $GREEN "RabbitMQ Management: http://localhost:15672 (guest/guest)"
    fi
    
    print_msg $GREEN ""
    print_msg $YELLOW "Management Commands:"
    local compose_cmd
    compose_cmd=$(get_docker_compose_cmd)
    print_msg $YELLOW "  Scale workers: $compose_cmd -f config/docker-compose.yml up -d --scale worker=5"
    print_msg $YELLOW "  View logs: $compose_cmd -f config/docker-compose.yml logs -f"
    print_msg $YELLOW "  Stop services: $compose_cmd -f config/docker-compose.yml down"
    print_msg $YELLOW "  Restart: $0 --stop && $0 --build"
}

# Main execution
print_msg $GREEN "=== Avalanche Parallel Docker Deployment ==="

if is_wsl; then
    print_msg $YELLOW "WSL environment detected"
fi

if [ "$STOP" = true ]; then
    check_prerequisites
    stop_services
    exit 0
fi

if [ "$LOGS" = true ]; then
    show_logs
    exit 0
fi

if [ "$STATUS" = true ]; then
    show_service_status
    exit 0
fi

check_prerequisites
build_images
deploy_services

print_msg $GREEN ""
print_msg $GREEN "=== Deployment completed successfully! ===" 