# Cleanup script for Avalanche Parallel Processing
param(
    [switch]$Force = $false
)

Write-Host "🧹 Starting cleanup process..." -ForegroundColor Yellow

# Stop all containers
Write-Host "Stopping all containers..." -ForegroundColor Cyan
docker-compose -f docker-compose.worker-pools.yml down

if ($Force) {
    Write-Host "Performing force cleanup..." -ForegroundColor Red
    
    # Remove all containers
    docker rm $(docker ps -a -q) -f

    # Remove project images
    docker images | Where-Object {$_.Contains('avalanche') -or $_.Contains('microservices')} | ForEach-Object { docker rmi $_.Split()[2] -f }

    # Remove volumes
    docker volume ls -q | Where-Object {$_.Contains('microservices')} | ForEach-Object { docker volume rm $_ -f }

    # Remove networks
    docker network ls | Where-Object {$_.Contains('avalanche') -or $_.Contains('microservices')} | ForEach-Object { docker network rm $_.Split()[0] }

    # Prune system
    docker system prune -f
}

Write-Host "✅ Cleanup completed!" -ForegroundColor Green 