# Fast Docker Cleanup Script
Write-Host "🧹 Starting fast Docker cleanup..." -ForegroundColor Blue

# 1. Kill all running containers immediately (force)
Write-Host "Stopping all containers forcefully..." -ForegroundColor Yellow
docker kill $(docker ps -q)

# 2. Remove all containers (force)
Write-Host "Removing all containers..." -ForegroundColor Yellow
docker rm -f $(docker ps -a -q)

# 3. Remove all images related to our project (force)
Write-Host "Removing project images..." -ForegroundColor Yellow
$projectImages = @(
    "avalanche-worker",
    "avalanche-consensus",
    "avalanche-validator",
    "avalanche-dag",
    "avalanche-benchmark",
    "avalanche-api",
    "redis",
    "prometheus",
    "grafana"
)

foreach ($image in $projectImages) {
    docker rmi -f $(docker images "*$image*" -q)
}

# 4. Remove specific volumes
Write-Host "Removing project volumes..." -ForegroundColor Yellow
docker volume rm -f avalanche-redis-data
docker volume rm -f avalanche-prometheus-data
docker volume rm -f avalanche-grafana-data

# 5. Remove project networks
Write-Host "Removing project networks..." -ForegroundColor Yellow
docker network rm avalanche-network 2>$null

# 6. Quick system prune (only dangling images and stopped containers)
Write-Host "Quick system prune..." -ForegroundColor Yellow
docker system prune -f

# 7. Reset Docker Desktop Kubernetes (if used)
Write-Host "Resetting Kubernetes resources..." -ForegroundColor Yellow
kubectl delete namespace avalanche --force 2>$null
kubectl delete all --all -n avalanche --force 2>$null

Write-Host "✨ Cleanup completed!" -ForegroundColor Green
Write-Host "You can now rebuild your project with a clean state." -ForegroundColor Green 