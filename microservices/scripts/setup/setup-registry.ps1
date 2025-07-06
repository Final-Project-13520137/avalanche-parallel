# Script for setting up local Docker registry

param(
    [int]$Port = 5000,
    [string]$Name = "registry",
    [switch]$Force
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to check if Docker is running
function Test-DockerRunning {
    try {
        docker info > $null 2>&1
        return $true
    }
    catch {
        Write-Host "❌ Docker is not running" -ForegroundColor Red
        return $false
    }
}

# Function to check if registry is already running
function Test-Registry {
    $container = docker ps -a --filter "name=$Name" --format '{{.Names}}'
    if ($container -eq $Name) {
        $running = docker ps --filter "name=$Name" --format '{{.Names}}'
        if ($running -eq $Name) {
            Write-Host "✅ Registry is already running" -ForegroundColor Green
            return $true
        }
        else {
            if ($Force) {
                Write-Host "⚠️ Registry container exists but not running. Removing..." -ForegroundColor Yellow
                docker rm -f $Name > $null 2>&1
                return $false
            }
            else {
                Write-Host "⚠️ Registry container exists but not running. Use -Force to remove and recreate" -ForegroundColor Yellow
                exit 1
            }
        }
    }
    return $false
}

# Function to check if port is available
function Test-Port {
    $portInUse = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue
    if ($portInUse) {
        Write-Host "❌ Port $Port is already in use" -ForegroundColor Red
        exit 1
    }
}

# Function to start registry
function Start-Registry {
    Write-Host "🚀 Starting local registry..." -ForegroundColor Cyan
    
    # Pull registry image if not exists
    if (-not (docker images | Select-String "^registry\s+2")) {
        Write-Host "Pulling registry image..." -ForegroundColor Cyan
        docker pull registry:2
    }

    # Start registry container
    docker run -d `
        --name $Name `
        --restart=always `
        -p "${Port}:5000" `
        -v registry-data:/var/lib/registry `
        registry:2

    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Registry started successfully" -ForegroundColor Green
        
        # Wait for registry to be ready
        Write-Host "⏳ Waiting for registry to be ready..." -ForegroundColor Cyan
        $ready = $false
        $attempts = 30

        for ($i = 1; $i -le $attempts; $i++) {
            try {
                $response = Invoke-WebRequest "http://localhost:$Port/v2/" -UseBasicParsing
                if ($response.StatusCode -eq 200) {
                    Write-Host "✅ Registry is ready" -ForegroundColor Green
                    $ready = $true
                    break
                }
            }
            catch {
                Start-Sleep -Seconds 1
            }
        }

        if (-not $ready) {
            Write-Host "❌ Registry failed to start" -ForegroundColor Red
            exit 1
        }
    }
    else {
        Write-Host "❌ Failed to start registry" -ForegroundColor Red
        exit 1
    }
}

# Main execution
Write-Host "🔧 Setting up local Docker registry..." -ForegroundColor Cyan

# Check prerequisites
if (-not (Test-DockerRunning)) {
    exit 1
}

# Check if registry is already running
if (-not (Test-Registry)) {
    # Check if port is available
    Test-Port
    # Start registry
    Start-Registry
}

# Show registry information
Write-Host "`n📋 Registry Information:" -ForegroundColor Cyan
Write-Host "Name: $Name" -ForegroundColor Green
Write-Host "URL: localhost:$Port" -ForegroundColor Green
Write-Host "Status: Running" -ForegroundColor Green

Write-Host "`n🔍 Test registry with:" -ForegroundColor Cyan
Write-Host "  Invoke-WebRequest http://localhost:$Port/v2/_catalog"
Write-Host "  docker tag myimage:latest localhost:$Port/myimage:latest"
Write-Host "  docker push localhost:$Port/myimage:latest" 