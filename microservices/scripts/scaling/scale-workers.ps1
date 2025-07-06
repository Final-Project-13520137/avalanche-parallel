# Script for scaling worker nodes

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("validator", "consensus", "dag-state")]
    [string]$WorkerType,

    [Parameter(Mandatory=$true)]
    [ValidateRange(1, 100)]
    [int]$Count,

    [switch]$Monitor
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item $ScriptDir).Parent.Parent.FullName

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker info > $null 2>&1
        return $true
    }
    catch {
        Write-Host "Error: Docker is not running" -ForegroundColor Red
        return $false
    }
}

# Function to check if docker-compose file exists
function Test-DockerComposeFile {
    $composePath = Join-Path $ProjectRoot "docker-compose.worker-pools.yml"
    if (-not (Test-Path $composePath)) {
        Write-Host "Error: docker-compose.worker-pools.yml not found in $ProjectRoot" -ForegroundColor Red
        return $false
    }
    return $true
}

# Validate environment
if (-not (Test-DockerRunning)) {
    exit 1
}

if (-not (Test-DockerComposeFile)) {
    exit 1
}

# Format worker type for docker-compose service name
$serviceName = switch ($WorkerType) {
    "validator" { "validator-worker" }
    "consensus" { "consensus-worker" }
    "dag-state" { "dag-state-worker" }
}

Write-Host "Scaling $serviceName to $Count instances..." -ForegroundColor Cyan

# Scale workers
try {
    $composePath = Join-Path $ProjectRoot "docker-compose.worker-pools.yml"
    docker-compose -f $composePath up -d --scale "$serviceName=$Count" --no-recreate
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Error: Failed to scale workers" -ForegroundColor Red
        exit 1
    }

    Write-Host "Successfully scaled $serviceName to $Count instances" -ForegroundColor Green

    # Monitor if requested
    if ($Monitor) {
        Write-Host "Monitoring worker status..." -ForegroundColor Cyan
        while ($true) {
            Clear-Host
            Write-Host "Current $serviceName status:" -ForegroundColor Cyan
            docker-compose -f $composePath ps $serviceName
            docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" --no-stream | Where-Object { $_ -match $serviceName }
            Start-Sleep -Seconds 5
        }
    }
}
catch {
    Write-Host "Error: $_" -ForegroundColor Red
    exit 1
} 