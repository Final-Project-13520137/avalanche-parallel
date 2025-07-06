#!/bin/bash
# Deploy Docker services for Avalanche Parallel Processing

# Default values
BUILD=false
WORKERS=3
COMPOSE_FILE="docker-compose.worker-pools.yml"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --build)
            BUILD=true
            shift
            ;;
        --workers)
            WORKERS="$2"
            shift 2
            ;;
        --file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "\e[32m🚀 Deploying Avalanche Parallel Processing with Docker...\e[0m"

# Build images if requested
if [ "$BUILD" = true ]; then
    echo -e "\e[33m🔨 Building Docker images...\e[0m"
    docker-compose -f $COMPOSE_FILE build
fi

# Start services
echo -e "\e[33m📦 Starting services with $WORKERS workers...\e[0m"
docker-compose -f $COMPOSE_FILE up -d --scale validator-worker=$WORKERS

echo -e "\e[32m✅ Deployment completed!\e[0m"
echo -e "\e[36mℹ️ Use 'docker-compose -f $COMPOSE_FILE logs -f' to view logs\e[0m" 