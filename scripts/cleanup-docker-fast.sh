#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🧹 Starting fast Docker cleanup...${NC}"

# 1. Kill all running containers immediately (force)
echo -e "${YELLOW}Stopping all containers forcefully...${NC}"
docker kill $(docker ps -q) 2>/dev/null

# 2. Remove all containers (force)
echo -e "${YELLOW}Removing all containers...${NC}"
docker rm -f $(docker ps -a -q) 2>/dev/null

# 3. Remove all images related to our project (force)
echo -e "${YELLOW}Removing project images...${NC}"
project_images=(
    "avalanche-worker"
    "avalanche-consensus"
    "avalanche-validator"
    "avalanche-dag"
    "avalanche-benchmark"
    "avalanche-api"
    "redis"
    "prometheus"
    "grafana"
)

for image in "${project_images[@]}"; do
    docker rmi -f $(docker images "*${image}*" -q) 2>/dev/null
done

# 4. Remove specific volumes
echo -e "${YELLOW}Removing project volumes...${NC}"
docker volume rm -f avalanche-redis-data 2>/dev/null
docker volume rm -f avalanche-prometheus-data 2>/dev/null
docker volume rm -f avalanche-grafana-data 2>/dev/null

# 5. Remove project networks
echo -e "${YELLOW}Removing project networks...${NC}"
docker network rm avalanche-network 2>/dev/null

# 6. Quick system prune (only dangling images and stopped containers)
echo -e "${YELLOW}Quick system prune...${NC}"
docker system prune -f

# 7. Reset Docker Desktop Kubernetes (if used)
echo -e "${YELLOW}Resetting Kubernetes resources...${NC}"
kubectl delete namespace avalanche --force 2>/dev/null
kubectl delete all --all -n avalanche --force 2>/dev/null

echo -e "${GREEN}✨ Cleanup completed!${NC}"
echo -e "${GREEN}You can now rebuild your project with a clean state.${NC}" 