# Cleanup Worker Pools for Avalanche Parallel Processing
# This script cleans up the worker pools for the Avalanche Parallel Processing system

Write-Host "Stopping Avalanche Worker Pools..." -ForegroundColor Yellow

# Stop and remove containers
docker-compose -f docker-compose.worker-pools.yml down

Write-Host "Worker pools stopped and cleaned up!" -ForegroundColor Green 