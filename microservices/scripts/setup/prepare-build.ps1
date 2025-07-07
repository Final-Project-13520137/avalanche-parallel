# Script for preparing build environment

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Get-Item (Join-Path $ScriptDir "../../..")).FullName
$MicroservicesRoot = (Get-Item (Join-Path $ScriptDir "../..")).FullName

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

# Function to verify required files exist
function Test-RequiredFiles {
    Write-Host "🔍 Verifying required files..." -ForegroundColor Cyan
    
    $MissingFiles = $false
    
    # Check root files
    if (-not (Test-Path (Join-Path $ProjectRoot "go.mod"))) {
        Write-Host "❌ Missing root go.mod" -ForegroundColor Red
        $MissingFiles = $true
    }
    if (-not (Test-Path (Join-Path $ProjectRoot "go.sum"))) {
        Write-Host "❌ Missing root go.sum" -ForegroundColor Red
        $MissingFiles = $true
    }

    # Check microservices files
    if (-not (Test-Path (Join-Path $MicroservicesRoot "go.mod"))) {
        Write-Host "❌ Missing microservices go.mod" -ForegroundColor Red
        $MissingFiles = $true
    }
    if (-not (Test-Path (Join-Path $MicroservicesRoot "go.sum"))) {
        Write-Host "❌ Missing microservices go.sum" -ForegroundColor Red
        $MissingFiles = $true
    }

    # Check worker source code
    if (-not (Test-Path (Join-Path $MicroservicesRoot "workers"))) {
        Write-Host "❌ Missing workers directory" -ForegroundColor Red
        $MissingFiles = $true
    }
    else {
        # Check each worker directory
        @("consensus-worker", "validator-worker", "dag-state-worker") | ForEach-Object {
            if (-not (Test-Path (Join-Path $MicroservicesRoot "workers/$_"))) {
                Write-Host "❌ Missing $_ directory" -ForegroundColor Red
                $MissingFiles = $true
            }
        }
    }

    if ($MissingFiles) {
        Write-Host "❌ Required files verification failed" -ForegroundColor Red
        exit 1
    }

    Write-Host "✅ Required files verified successfully" -ForegroundColor Green
}

# Main execution
Write-Host "🚀 Preparing build environment..." -ForegroundColor Cyan

# Check Docker
if (-not (Test-DockerRunning)) {
    exit 1
}

# Verify required files
Test-RequiredFiles

Write-Host "✨ Build environment ready!" -ForegroundColor Green 