# AvalancheGo Monolithic Flow System Runner (PowerShell)
# Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.

param(
    [string]$Command = "run",
    [string]$LogLevel = "info",
    [int]$HttpPort = 9650,
    [int]$NetworkPort = 9651,
    [string]$Args = "",
    [switch]$Help
)

# Colors untuk output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

# Print header
Write-Host "=====================================" -ForegroundColor $Blue
Write-Host "🚀 AvalancheGo Monolithic Flow System" -ForegroundColor $Blue
Write-Host "=====================================" -ForegroundColor $Blue

# Directory paths
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
$BinDir = Join-Path $ProjectRoot "bin"
$CmdDir = Join-Path $ProjectRoot "cmd" | Join-Path -ChildPath "avalanche-monolithic"

# Create bin directory if it doesn't exist
if (-not (Test-Path $BinDir)) {
    New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
}

# Function to print status
function Write-Status {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor $Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor $Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Red
}

# Function to build monolithic binary
function Build-Monolithic {
    Write-Status "Building AvalancheGo Monolithic Flow System..."
    
    Set-Location $ProjectRoot
    
    # Check if go is installed
    try {
        $goVersion = go version 2>$null
        if (-not $goVersion) {
            throw "Go not found"
        }
    }
    catch {
        Write-Error "Go is not installed or not in PATH"
        exit 1
    }
    
    # Build the monolithic binary
    Write-Status "Compiling avalanche-monolithic.exe binary..."
    $binaryPath = Join-Path $BinDir "avalanche-monolithic.exe"
    $mainPath = Join-Path $CmdDir "main.go"
    
    $buildResult = go build -o $binaryPath $mainPath
    
    if ($LASTEXITCODE -eq 0) {
        Write-Status "✅ Build successful: $binaryPath"
    }
    else {
        Write-Error "❌ Build failed"
        exit 1
    }
}

# Function to run monolithic system
function Start-Monolithic {
    param(
        [string]$LogLevel = "info",
        [int]$HttpPort = 9650,
        [int]$NetworkPort = 9651,
        [string]$CustomArgs = ""
    )
    
    Write-Status "Starting AvalancheGo Monolithic Flow System..."
    Write-Status "Log Level: $LogLevel"
    Write-Status "HTTP Port: $HttpPort"
    Write-Status "Network Port: $NetworkPort"
    
    # Create data directories
    $dataDir = Join-Path $env:USERPROFILE ".avalanche-monolithic"
    $dbDir = Join-Path $dataDir "db"
    $logDir = Join-Path $dataDir "logs"
    
    if (-not (Test-Path $dbDir)) {
        New-Item -ItemType Directory -Path $dbDir -Force | Out-Null
    }
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    
    # Run the monolithic system
    Write-Status "Executing avalanche-monolithic.exe..."
    Write-Host ""
    
    $binaryPath = Join-Path $BinDir "avalanche-monolithic.exe"
    $arguments = @(
        "--log-level", $LogLevel,
        "--http-port", $HttpPort,
        "--network-port", $NetworkPort
    )
    
    if ($CustomArgs) {
        $arguments += $CustomArgs.Split(' ')
    }
    
    & $binaryPath $arguments
}

# Function to show help
function Show-Help {
    Write-Host "Usage: .\run-monolithic.ps1 [COMMAND] [OPTIONS]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  build          Build the monolithic binary"
    Write-Host "  run            Build and run the monolithic system"
    Write-Host "  start          Start the monolithic system (alias for run)"
    Write-Host "  help           Show this help message"
    Write-Host ""
    Write-Host "Options for run/start:"
    Write-Host "  -LogLevel LEVEL      Log level (debug, info, warn, error) [default: info]"
    Write-Host "  -HttpPort PORT       HTTP API port [default: 9650]"
    Write-Host "  -NetworkPort PORT    Network listening port [default: 9651]"
    Write-Host "  -Args 'ARGS'         Additional arguments to pass to avalanche-monolithic"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\run-monolithic.ps1 build"
    Write-Host "  .\run-monolithic.ps1 run"
    Write-Host "  .\run-monolithic.ps1 run -LogLevel debug"
    Write-Host "  .\run-monolithic.ps1 run -LogLevel debug -HttpPort 8080"
    Write-Host "  .\run-monolithic.ps1 run -Args '--db-dir C:\custom\path'"
    Write-Host ""
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Execute command
switch ($Command.ToLower()) {
    "build" {
        Build-Monolithic
    }
    "run" {
        Build-Monolithic
        Write-Host ""
        Start-Monolithic -LogLevel $LogLevel -HttpPort $HttpPort -NetworkPort $NetworkPort -CustomArgs $Args
    }
    "start" {
        Build-Monolithic
        Write-Host ""
        Start-Monolithic -LogLevel $LogLevel -HttpPort $HttpPort -NetworkPort $NetworkPort -CustomArgs $Args
    }
    "help" {
        Show-Help
    }
    default {
        Write-Error "Unknown command: $Command"
        Write-Host ""
        Show-Help
        exit 1
    }
} 