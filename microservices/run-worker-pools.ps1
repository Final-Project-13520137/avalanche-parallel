# Run Worker Pools for Avalanche Parallel Processing
# This script runs the worker pools for the Avalanche Parallel Processing system

Write-Host "Starting Avalanche Worker Pools..." -ForegroundColor Green

# Run docker-compose
docker-compose -f docker-compose.worker-pools.yml up -d

Write-Host "Worker pools started successfully!" -ForegroundColor Green
Write-Host "Use 'docker-compose -f docker-compose.worker-pools.yml down' to stop the worker pools." -ForegroundColor Yellow 