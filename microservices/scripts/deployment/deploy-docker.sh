#!/bin/bash
# Run Worker Pools for Avalanche Parallel Processing
# This script runs the worker pools for the Avalanche Parallel Processing system

echo -e "\e[32mStarting Avalanche Worker Pools...\e[0m"

# Run docker-compose
docker-compose -f docker-compose.worker-pools.yml up -d

echo -e "\e[32mWorker pools started successfully!\e[0m"
echo -e "\e[33mUse 'docker-compose -f docker-compose.worker-pools.yml down' to stop the worker pools.\e[0m" 