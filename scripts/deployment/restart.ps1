# Stop dan hapus container yang ada
Write-Host "Stopping and removing existing containers..." -ForegroundColor Green
docker-compose down -v

# Bersihkan volume
Write-Host "Cleaning up volumes..." -ForegroundColor Green
docker volume prune -f

# Build image dari awal
Write-Host "Building images..." -ForegroundColor Green
docker-compose build --no-cache

# Start service dengan 1 worker di awal
Write-Host "Starting services..." -ForegroundColor Green
docker-compose up -d

# Tunggu service siap
Write-Host "Waiting for services to initialize (30 seconds)..." -ForegroundColor Green
Start-Sleep -Seconds 30

# Scale worker service ke 3 instance
Write-Host "Scaling worker service to 3 instances..." -ForegroundColor Green
docker-compose up -d --scale worker=3

Write-Host "`nSetup complete!" -ForegroundColor Green
Write-Host "Access the services at:" -ForegroundColor Cyan
Write-Host "  - Avalanche Node: http://localhost:9650/ext/info" -ForegroundColor Yellow
Write-Host "  - Prometheus: http://localhost:9090" -ForegroundColor Yellow
Write-Host "  - Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow 