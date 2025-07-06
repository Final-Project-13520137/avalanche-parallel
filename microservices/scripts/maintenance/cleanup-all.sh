#!/bin/bash
# Cleanup script for Avalanche Parallel Processing

# Default values
FORCE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "\e[33m🧹 Starting cleanup process...\e[0m"

# Stop all containers
echo -e "\e[36mStopping all containers...\e[0m"
docker-compose -f docker-compose.worker-pools.yml down

if [ "$FORCE" = true ]; then
    echo -e "\e[31mPerforming force cleanup...\e[0m"
    
    # Remove all containers
    docker rm $(docker ps -a -q) -f

    # Remove project images
    docker rmi $(docker images | grep 'avalanche\|microservices' | awk '{print $3}') -f

    # Remove volumes
    docker volume rm $(docker volume ls -q | grep 'microservices') -f

    # Remove networks
    docker network rm $(docker network ls | grep 'avalanche\|microservices' | awk '{print $1}')

    # Prune system
    docker system prune -f
fi

echo -e "\e[32m✅ Cleanup completed!\e[0m" 