# Avalanche Parallel Docker Compose Deployment Script
param(
    [switch]$Build,
    [switch]$Stop,
    [switch]$Logs,
    [switch]$Status,
    [int]$Workers = 3,
    [switch]$Help
)

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

if ($Help) {
    Write-Host @"
Avalanche Parallel Docker Compose Deployment Script

Usage: .\deploy-docker.ps1 [OPTIONS]

Options:
  -Build      Build Docker images before deployment
  -Stop       Stop all services
  -Logs       Show logs from all services
  -Status     Show status of all services
  -Workers    Number of worker instances (default: 3)
  -Help       Show this help message

Examples:
  .\deploy-docker.ps1 -Build
  .\deploy-docker.ps1 -Workers 5
  .\deploy-docker.ps1 -Stop
  .\deploy-docker.ps1 -Logs
  .\deploy-docker.ps1 -Status
"@
    exit 0
}

function Check-Prerequisites {
    Write-ColorOutput Yellow "Checking prerequisites..."
    
    if (!(Get-Command docker -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "Docker is not installed. Please install Docker first."
        exit 1
    }
    
    if (!(Get-Command docker-compose -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "Docker Compose is not installed. Please install Docker Compose first."
        exit 1
    }
    
    Write-ColorOutput Green "Prerequisites check passed!"
}

function Build-Images {
    if ($Build) {
        Write-ColorOutput Yellow "Building Docker images..."
        
        # Build main node image
        docker build -f deployments/docker/Dockerfile.main-node -t avalanche-parallel/main-node:latest .
        if ($LASTEXITCODE -ne 0) { 
            Write-ColorOutput Red "Failed to build main node image"
            exit 1 
        }
        
        # Build worker image
        docker build -f deployments/docker/Dockerfile.worker-node -t avalanche-parallel/worker:latest .
        if ($LASTEXITCODE -ne 0) { 
            Write-ColorOutput Red "Failed to build worker image"
            exit 1 
        }
        
        Write-ColorOutput Green "Docker images built successfully!"
    }
}

function Deploy-Services {
    Write-ColorOutput Yellow "Deploying services with Docker Compose..."
    
    # Change to project root
    Push-Location "../.."
    
    try {
        # Stop existing services
        docker-compose -f config/docker-compose.yml down 2>$null
        
        # Start services
        docker-compose -f config/docker-compose.yml up -d --scale worker=$Workers
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput Green "Services deployed successfully!"
            
            Write-ColorOutput Yellow "Waiting for services to be ready..."
            Start-Sleep -Seconds 10
            
            Show-ServiceStatus
            Show-AccessInfo
        } else {
            Write-ColorOutput Red "Failed to deploy services"
            exit 1
        }
    } finally {
        Pop-Location
    }
}

function Stop-Services {
    Write-ColorOutput Yellow "Stopping all services..."
    
    Push-Location "../.."
    
    try {
        docker-compose -f config/docker-compose.yml down
        Write-ColorOutput Green "All services stopped!"
    } finally {
        Pop-Location
    }
}

function Show-Logs {
    Write-ColorOutput Yellow "Showing logs from all services..."
    
    Push-Location "../.."
    
    try {
        docker-compose -f config/docker-compose.yml logs -f
    } finally {
        Pop-Location
    }
}

function Show-ServiceStatus {
    Write-ColorOutput Yellow "Service Status:"
    
    Push-Location "../.."
    
    try {
        docker-compose -f config/docker-compose.yml ps
    } finally {
        Pop-Location
    }
}

function Show-AccessInfo {
    Write-ColorOutput Green "`n=== Access Information ==="
    Write-ColorOutput Green "Avalanche Node API: http://localhost:9650"
    Write-ColorOutput Green "Worker Health Check: http://localhost:9652/health"
    Write-ColorOutput Green "Prometheus: http://localhost:19090"
    Write-ColorOutput Green "Grafana: http://localhost:13000 (admin/admin)"
    Write-ColorOutput Green "RabbitMQ Management: http://localhost:15672 (guest/guest)"
    Write-ColorOutput Green ""
    Write-ColorOutput Yellow "To scale workers: docker-compose -f config/docker-compose.yml up -d --scale worker=5"
    Write-ColorOutput Yellow "To view logs: docker-compose -f config/docker-compose.yml logs -f"
    Write-ColorOutput Yellow "To stop services: docker-compose -f config/docker-compose.yml down"
}

# Main execution
Write-ColorOutput Green "=== Avalanche Parallel Docker Deployment ==="

if ($Stop) {
    Check-Prerequisites
    Stop-Services
    exit 0
}

if ($Logs) {
    Show-Logs
    exit 0
}

if ($Status) {
    Show-ServiceStatus
    exit 0
}

Check-Prerequisites
Build-Images
Deploy-Services

Write-ColorOutput Green "`n=== Deployment completed successfully! ===" 