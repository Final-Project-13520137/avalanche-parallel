# Avalanche Parallel Monitoring Stack Startup Script (PowerShell)
# This script starts the complete monitoring infrastructure

param(
    [switch]$SkipDashboards = $false,
    [switch]$Quiet = $false
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
}

function Write-Step {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "==> $Message" -ForegroundColor $Colors.Blue
    }
}

function Write-Success {
    param([string]$Message)
    if (-not $Quiet) {
        Write-Host "✓ $Message" -ForegroundColor $Colors.Green
    }
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor $Colors.Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor $Colors.Red
}

function Check-Dependencies {
    Write-Step "Checking dependencies..."
    
    # Check Docker
    try {
        $dockerVersion = docker --version 2>$null
        if (-not $dockerVersion) {
            throw "Docker not found"
        }
    }
    catch {
        Write-Error "Docker is not installed or not in PATH"
        Write-Host "Please install Docker Desktop: https://docs.docker.com/desktop/install/windows/"
        exit 1
    }
    
    # Check Docker Compose
    try {
        $composeVersion = docker-compose --version 2>$null
        if (-not $composeVersion) {
            throw "Docker Compose not found"
        }
    }
    catch {
        Write-Error "Docker Compose is not installed or not in PATH"
        Write-Host "Please install Docker Compose or use Docker Desktop which includes it"
        exit 1
    }
    
    Write-Success "Dependencies check passed"
}

function Create-Directories {
    Write-Step "Creating monitoring directories..."
    
    # Create directories for persistent data
    $directories = @(
        "monitoring\grafana\provisioning\datasources",
        "monitoring\grafana\provisioning\dashboards",
        "monitoring\grafana\dashboards",
        "monitoring\loki",
        "monitoring\promtail",
        "monitoring\otel",
        "monitoring\nginx"
    )
    
    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-Success "Directories created"
}

function Setup-GrafanaProvisioning {
    Write-Step "Setting up Grafana provisioning..."
    
    # Create datasource configuration
    $datasourceConfig = @"
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: true

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true
"@
    
    $datasourceConfig | Out-File -FilePath "monitoring\grafana\provisioning\datasources\prometheus.yml" -Encoding UTF8
    
    # Create dashboard provisioning configuration
    $dashboardConfig = @"
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
"@
    
    $dashboardConfig | Out-File -FilePath "monitoring\grafana\provisioning\dashboards\dashboard.yml" -Encoding UTF8
    
    Write-Success "Grafana provisioning configured"
}

function Start-MonitoringStack {
    Write-Step "Starting monitoring stack..."
    
    try {
        # Pull latest images
        Write-Host "Pulling latest Docker images..."
        docker-compose -f docker-compose.monitoring.yml pull
        
        # Start the monitoring stack
        Write-Host "Starting monitoring services..."
        docker-compose -f docker-compose.monitoring.yml up -d
        
        Write-Success "Monitoring stack started"
    }
    catch {
        Write-Error "Failed to start monitoring stack: $($_.Exception.Message)"
        exit 1
    }
}

function Wait-ForServices {
    Write-Step "Waiting for services to be ready..."
    
    # Define services to check
    $services = @(
        @{ Name = "Grafana"; Url = "http://localhost:3000"; Port = 3000 },
        @{ Name = "Prometheus"; Url = "http://localhost:9090"; Port = 9090 },
        @{ Name = "AlertManager"; Url = "http://localhost:9093"; Port = 9093 }
    )
    
    foreach ($service in $services) {
        Write-Host "Waiting for $($service.Name)..." -NoNewline
        $timeout = 120 # 2 minutes timeout
        $elapsed = 0
        
        do {
            try {
                $response = Invoke-WebRequest -Uri $service.Url -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
                if ($response.StatusCode -eq 200) {
                    Write-Host " Ready!" -ForegroundColor Green
                    break
                }
            }
            catch {
                # Service not ready yet
            }
            
            Start-Sleep -Seconds 2
            $elapsed += 2
            Write-Host "." -NoNewline
            
        } while ($elapsed -lt $timeout)
        
        if ($elapsed -ge $timeout) {
            Write-Warning "$($service.Name) did not become ready within $timeout seconds"
        } else {
            Write-Success "$($service.Name) is ready"
        }
    }
}

function Import-GrafanaDashboards {
    if ($SkipDashboards) {
        Write-Step "Skipping dashboard import (--SkipDashboards specified)"
        return
    }
    
    Write-Step "Importing Grafana dashboards..."
    
    # Wait a bit more for Grafana to fully initialize
    Start-Sleep -Seconds 10
    
    # Import worker pool dashboard
    try {
        $dashboardPath = "monitoring\grafana\dashboards\worker-pools-dashboard.json"
        if (Test-Path $dashboardPath) {
            $dashboardContent = Get-Content $dashboardPath -Raw
            
            $headers = @{
                'Content-Type' = 'application/json'
            }
            
            $credentials = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:admin"))
            $headers['Authorization'] = "Basic $credentials"
            
            $response = Invoke-RestMethod -Uri "http://localhost:3000/api/dashboards/db" -Method Post -Body $dashboardContent -Headers $headers -ErrorAction SilentlyContinue
            
            Write-Success "Worker pools dashboard imported"
        } else {
            Write-Warning "Dashboard file not found: $dashboardPath"
        }
    }
    catch {
        Write-Warning "Failed to import worker pools dashboard (may already exist): $($_.Exception.Message)"
    }
}

function Show-MonitoringEndpoints {
    Write-Step "Monitoring setup complete!"
    
    Write-Host ""
    Write-Host "📊 Monitoring endpoints:" -ForegroundColor Cyan
    Write-Host "- Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
    Write-Host "- Prometheus: http://localhost:9090" -ForegroundColor White
    Write-Host "- AlertManager: http://localhost:9093" -ForegroundColor White
    Write-Host "- Jaeger: http://localhost:16686" -ForegroundColor White
    Write-Host "- Loki: http://localhost:3100" -ForegroundColor White
    Write-Host ""
    
    Write-Host "🔧 Management commands:" -ForegroundColor Cyan
    Write-Host "- Stop monitoring: docker-compose -f docker-compose.monitoring.yml down" -ForegroundColor White
    Write-Host "- View logs: docker-compose -f docker-compose.monitoring.yml logs -f [service-name]" -ForegroundColor White
    Write-Host "- Restart service: docker-compose -f docker-compose.monitoring.yml restart [service-name]" -ForegroundColor White
    Write-Host ""
}

function Verify-MonitoringSetup {
    Write-Step "Verifying monitoring setup..."
    
    try {
        # Check if containers are running
        $runningContainers = docker-compose -f docker-compose.monitoring.yml ps --services --filter "status=running"
        $allServices = docker-compose -f docker-compose.monitoring.yml ps --services
        
        $runningCount = ($runningContainers | Measure-Object).Count
        $totalCount = ($allServices | Measure-Object).Count
        
        if ($runningCount -eq $totalCount) {
            Write-Success "All $totalCount monitoring containers are running"
        } else {
            Write-Warning "$runningCount of $totalCount monitoring containers are running"
            Write-Host "Check status with: docker-compose -f docker-compose.monitoring.yml ps"
        }
    }
    catch {
        Write-Warning "Could not verify container status: $($_.Exception.Message)"
    }
}

function Main {
    Write-Host "🎯 Avalanche Parallel Monitoring Stack Setup" -ForegroundColor Cyan
    Write-Host "=============================================" -ForegroundColor Cyan
    Write-Host ""
    
    # Change to microservices directory if we're not already there
    if (-not (Test-Path "docker-compose.monitoring.yml")) {
        if (Test-Path "microservices\docker-compose.monitoring.yml") {
            Set-Location microservices
        } else {
            Write-Error "docker-compose.monitoring.yml not found. Please run from the correct directory."
            exit 1
        }
    }
    
    try {
        Check-Dependencies
        Create-Directories
        Setup-GrafanaProvisioning
        Start-MonitoringStack
        Wait-ForServices
        Import-GrafanaDashboards
        Verify-MonitoringSetup
        Show-MonitoringEndpoints
        
        Write-Success "Monitoring stack setup complete!"
    }
    catch {
        Write-Error "Setup failed: $($_.Exception.Message)"
        Write-Host "Check logs with: docker-compose -f docker-compose.monitoring.yml logs"
        exit 1
    }
}

# Run main function
Main 