#!/usr/bin/env pwsh

Write-Host "Avalanche Parallel Docker Environment Restart Script" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "This script restarts the Docker environment with port conflict resolution`n"

# Step 1: Stop all running containers
Write-Host "Step 1: Stopping all existing containers..." -ForegroundColor Green
docker-compose down
if ($LASTEXITCODE -ne 0) {
    Write-Host "  ! Warning: Issues stopping containers. Proceeding anyway..." -ForegroundColor Yellow
}

# Step 2: Check for port conflicts
Write-Host "`nStep 2: Checking for port conflicts..." -ForegroundColor Green

# Function to check if a port is in use
function Test-PortInUse {
    param (
        [int]$Port
    )
    
    $connections = netstat -ano | Select-String -Pattern ":$Port "
    return ($null -ne $connections)
}

# Check critical ports
$portCheck = @(
    @{Port = 9650; Service = "Avalanche API"},
    @{Port = 9651; Service = "Avalanche P2P"},
    @{Port = 19090; Service = "Prometheus (modified)"},
    @{Port = 13000; Service = "Grafana (modified)"}
)

$hasConflicts = $false
foreach ($check in $portCheck) {
    if (Test-PortInUse -Port $check.Port) {
        Write-Host "  ! Port $($check.Port) is in use (service: $($check.Service))" -ForegroundColor Red
        $hasConflicts = $true
    } else {
        Write-Host "  * Port $($check.Port) is available" -ForegroundColor Green
    }
}

if ($hasConflicts) {
    Write-Host "`n  ! Some ports are already in use. You may need to modify docker-compose.yml" -ForegroundColor Red
    $proceed = Read-Host "`nDo you want to proceed anyway? (y/n)"
    if ($proceed -ne "y") {
        Write-Host "Exiting script." -ForegroundColor Yellow
        exit
    }
}

# Step 3: Start with clean containers
Write-Host "`nStep 3: Starting containers..." -ForegroundColor Green
docker-compose up -d
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n  ! Error starting containers. Checking for more specific issues..." -ForegroundColor Red
    
    # Try to identify specific issues
    Write-Host "`nChecking container status:" -ForegroundColor Yellow
    docker ps -a --filter "name=avalanche-parallel" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Offer potential solutions
    Write-Host "`nPotential solutions:" -ForegroundColor Cyan
    Write-Host "  1. Edit docker-compose.yml to change ports (current changes: Prometheus 19090, Grafana 13000)"
    Write-Host "  2. Stop conflicting services/applications using the same ports"
    Write-Host "  3. Try running: docker system prune -f to clean up unused Docker resources"
    Write-Host "  4. Check if you have multiple Docker Compose projects using the same container names"
    
    $restart = Read-Host "`nWould you like to try docker system prune and restart? (y/n)"
    if ($restart -eq "y") {
        docker system prune -f
        Write-Host "`nTrying to start containers again..." -ForegroundColor Green
        docker-compose up -d
    }
} else {
    # Step 4: Scale workers
    Write-Host "`nStep 4: Scaling worker service to 3 instances..." -ForegroundColor Green
    docker-compose up -d --scale worker=3
    
    # Step 5: Check services
    Write-Host "`nStep 5: Checking service status..." -ForegroundColor Green
    docker-compose ps
    
    Write-Host "`nServices should be available at:"
    Write-Host "  - Avalanche Node API: http://localhost:9650/ext/info"
    Write-Host "  - Prometheus: http://localhost:19090"
    Write-Host "  - Grafana: http://localhost:13000 (admin/admin)"
}

Write-Host "`nDone!" -ForegroundColor Cyan 