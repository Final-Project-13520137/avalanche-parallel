# Avalanche Microservices Startup Script
Write-Host "Starting Avalanche Microservices..." -ForegroundColor Green
Write-Host "==============================================="

# Clean up
Write-Host "Cleaning up existing containers..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml down --volumes

# Start infrastructure
Write-Host "Starting infrastructure (Redis and PostgreSQL)..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml up -d redis postgres

Write-Host "Waiting for infrastructure to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 20

# Check status
Write-Host "Infrastructure status:" -ForegroundColor Cyan
docker-compose -f docker-compose.simple.yml ps

# Test connections
Write-Host "Testing Redis connection..." -ForegroundColor Yellow
try {
    $redisTest = docker exec avalanche-redis redis-cli ping
    if ($redisTest -eq "PONG") {
        Write-Host "Redis: Connected" -ForegroundColor Green
    } else {
        Write-Host "Redis: Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "Redis: Error testing connection" -ForegroundColor Red
}

Write-Host "Testing PostgreSQL connection..." -ForegroundColor Yellow
try {
    $pgTest = docker exec avalanche-postgres pg_isready -U avalanche
    if ($pgTest -match "accepting connections") {
        Write-Host "PostgreSQL: Connected" -ForegroundColor Green
    } else {
        Write-Host "PostgreSQL: Failed" -ForegroundColor Red
    }
} catch {
    Write-Host "PostgreSQL: Error testing connection" -ForegroundColor Red
}

# Start monitoring
Write-Host "Starting monitoring services..." -ForegroundColor Yellow
docker-compose -f docker-compose.simple.yml up -d prometheus grafana

Start-Sleep -Seconds 10

# Final status
Write-Host ""
Write-Host "Final Status:" -ForegroundColor Green
Write-Host "==============================================="
docker-compose -f docker-compose.simple.yml ps

Write-Host ""
Write-Host "Service URLs:" -ForegroundColor Cyan
Write-Host "- Redis: localhost:6379"
Write-Host "- PostgreSQL: localhost:5432 (user: avalanche, pass: avalanche123)"
Write-Host "- Prometheus: http://localhost:9090"
Write-Host "- Grafana: http://localhost:3000 (admin/admin)"

Write-Host ""
Write-Host "Infrastructure ready! Use 'docker-compose -f docker-compose.simple.yml logs -f [service]' to view logs" -ForegroundColor Gray 