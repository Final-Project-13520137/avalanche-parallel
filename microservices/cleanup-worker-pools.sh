#!/bin/bash
# Cleanup Worker Pools for Avalanche Parallel Processing
# This script cleans up the worker pools for the Avalanche Parallel Processing system

echo -e "\e[33mStopping Avalanche Worker Pools...\e[0m"

# Stop and remove containers
docker-compose -f docker-compose.worker-pools.yml down

echo -e "\e[32mWorker pools stopped and cleaned up!\e[0m" 