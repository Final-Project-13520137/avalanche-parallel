# Avalanche Benchmark Suite - PowerShell Version
# Mempertahankan konfigurasi worker pool yang sudah di-scale

param(
    [switch]$Help,
    [int]$DefaultValidatorWorkers = 3,
    [int]$DefaultConsensusWorkers = 2,
    [int]$DefaultDagStateWorkers = 2,
    [switch]$ForceCleanup,
    [switch]$KeepRunning
)

# Colors for output
$Colors = @{
    Red = "Red"
    Green = "Green"
    Yellow = "Yellow"
    Blue = "Blue"
    Cyan = "Cyan"
}

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Show-Help {
    Write-ColorOutput @"
🚀 Avalanche Benchmark Suite - PowerShell Version

USAGE:
    .\run-benchmark.ps1 [OPTIONS]

OPTIONS:
    -Help                       Show this help message
    -DefaultValidatorWorkers    Default validator workers if none running (default: 3)
    -DefaultConsensusWorkers    Default consensus workers if none running (default: 2)
    -DefaultDagStateWorkers     Default DAG+State workers if none running (default: 2)
    -ForceCleanup              Force cleanup existing services before start
    -KeepRunning               Keep services running after benchmark

EXAMPLES:
    # Run with current worker configuration (preserves existing scale)
    .\run-benchmark.ps1

    # Run with custom defaults if no workers are running
    .\run-benchmark.ps1 -DefaultValidatorWorkers 5 -DefaultConsensusWorkers 3

    # Force cleanup and restart with defaults
    .\run-benchmark.ps1 -ForceCleanup

    # Keep services running after benchmark
    .\run-benchmark.ps1 -KeepRunning

DESCRIPTION:
    This script preserves the current worker pool configuration. If workers are
    already scaled to specific numbers, the benchmark will run with those numbers.
    Only if no workers are running will it use the default values.

"@ -Color "Cyan"
}

function Get-WorkerCount {
    param([string]$ServicePattern)
    
    try {
        # Method 1: Use docker ps with pattern matching
        $count1 = (docker ps --filter "name=$ServicePattern" --filter "status=running" --format "{{.Names}}" | Measure-Object).Count
        
        # Method 2: Alternative pattern
        $altPattern = "avalanche-$ServicePattern"
        $count2 = (docker ps --filter "name=$altPattern" --filter "status=running" --format "{{.Names}}" | Measure-Object).Count
        
        # Return the higher count
        return [Math]::Max($count1, $count2)
    }
    catch {
        return 0
    }
}

function Test-ServicesRunning {
    try {
        $redisRunning = Get-WorkerCount "redis"
        $postgresRunning = Get-WorkerCount "postgres"
        $workersRunning = Get-WorkerCount "worker"
        
        return ($redisRunning -gt 0) -or ($postgresRunning -gt 0) -or ($workersRunning -gt 0)
    }
    catch {
        return $false
    }
}

function Start-ServicesWithScale {
    $validatorCount = 0
    $consensusCount = 0
    $dagStateCount = 0
    
    if ((Test-ServicesRunning) -and (-not $ForceCleanup)) {
        Write-ColorOutput "🔍 Existing services detected. Preserving current scale..." -Color $Colors.Yellow
        
        # Get current worker counts
        $validatorCount = Get-WorkerCount "validator-worker"
        $consensusCount = Get-WorkerCount "consensus-worker"
        $dagStateCount = Get-WorkerCount "dag-state-worker"
        
        Write-ColorOutput "`n📊 Current worker configuration:" -Color $Colors.Blue
        Write-ColorOutput "  - Validator Workers: $validatorCount" -Color $Colors.Blue
        Write-ColorOutput "  - Consensus Workers: $consensusCount" -Color $Colors.Blue
        Write-ColorOutput "  - DAG+State Workers: $dagStateCount" -Color $Colors.Blue
        
        # Use current scale or minimum defaults if no workers are running
        if ($validatorCount -eq 0) { $validatorCount = $DefaultValidatorWorkers }
        if ($consensusCount -eq 0) { $consensusCount = $DefaultConsensusWorkers }
        if ($dagStateCount -eq 0) { $dagStateCount = $DefaultDagStateWorkers }
    }
    else {
        if ($ForceCleanup) {
            Write-ColorOutput "🧹 Force cleanup requested. Stopping existing services..." -Color $Colors.Yellow
            docker-compose -f "../../docker-compose.worker-pools.yml" down 2>$null
        }
        
        Write-ColorOutput "🆕 Starting with default scale..." -Color $Colors.Yellow
        
        # Default worker counts for fresh start
        $validatorCount = $DefaultValidatorWorkers
        $consensusCount = $DefaultConsensusWorkers
        $dagStateCount = $DefaultDagStateWorkers
        
        Write-ColorOutput "`n📊 Default worker configuration:" -Color $Colors.Blue
        Write-ColorOutput "  - Validator Workers: $validatorCount" -Color $Colors.Blue
        Write-ColorOutput "  - Consensus Workers: $consensusCount" -Color $Colors.Blue
        Write-ColorOutput "  - DAG+State Workers: $dagStateCount" -Color $Colors.Blue
    }
    
    # Start services with determined scale
    Write-ColorOutput "`n🚀 Starting services with preserved/default scale..." -Color $Colors.Yellow
    
    $composeArgs = @(
        "-f", "../../docker-compose.worker-pools.yml",
        "up", "-d",
        "--scale", "validator-worker=$validatorCount",
        "--scale", "consensus-worker=$consensusCount",
        "--scale", "dag-state-worker=$dagStateCount"
    )
    
    $process = Start-Process -FilePath "docker-compose" -ArgumentList $composeArgs -Wait -NoNewWindow -PassThru
    
    if ($process.ExitCode -ne 0) {
        Write-ColorOutput "❌ Failed to start services" -Color $Colors.Red
        exit 1
    }
    
    Write-ColorOutput "`n✅ Services started successfully with:" -Color $Colors.Green
    Write-ColorOutput "  - Validator Workers: $validatorCount" -Color $Colors.Green
    Write-ColorOutput "  - Consensus Workers: $consensusCount" -Color $Colors.Green
    Write-ColorOutput "  - DAG+State Workers: $dagStateCount" -Color $Colors.Green
    
    return @{
        Validator = $validatorCount
        Consensus = $consensusCount
        DagState = $dagStateCount
    }
}

function Wait-ForService {
    param(
        [string]$ServiceName,
        [string]$HealthEndpoint,
        [int]$TimeoutSeconds = 300
    )
    
    Write-ColorOutput "`n🔍 Waiting for $ServiceName..." -Color $Colors.Blue
    
    $elapsed = 0
    $interval = 5
    
    while ($elapsed -lt $TimeoutSeconds) {
        try {
            if ($HealthEndpoint) {
                $response = Invoke-RestMethod -Uri $HealthEndpoint -TimeoutSec 5 -ErrorAction SilentlyContinue
                if ($response) {
                    Write-ColorOutput "✅ $ServiceName is ready!" -Color $Colors.Green
                    return $true
                }
            }
            else {
                # For services without HTTP endpoints, check if container is running
                $running = docker ps --filter "name=$ServiceName" --filter "status=running" --format "{{.Names}}"
                if ($running) {
                    Write-ColorOutput "✅ $ServiceName is ready!" -Color $Colors.Green
                    return $true
                }
            }
        }
        catch {
            # Continue waiting
        }
        
        Write-Host "." -NoNewline
        Start-Sleep -Seconds $interval
        $elapsed += $interval
    }
    
    Write-ColorOutput "⚠️ Timeout waiting for $ServiceName" -Color $Colors.Yellow
    return $false
}

function Show-WorkerStatus {
    param([hashtable]$WorkerCounts)
    
    Write-ColorOutput "`n📊 Current Worker Pool Status:" -Color $Colors.Green
    Write-ColorOutput "Active Workers:" -Color $Colors.Blue
    
    $validatorActive = Get-WorkerCount "validator-worker"
    $consensusActive = Get-WorkerCount "consensus-worker"
    $dagStateActive = Get-WorkerCount "dag-state-worker"
    $totalActive = $validatorActive + $consensusActive + $dagStateActive
    
    Write-ColorOutput "  - Validator Workers: $validatorActive containers" -Color $Colors.Blue
    Write-ColorOutput "  - Consensus Workers: $consensusActive containers" -Color $Colors.Blue
    Write-ColorOutput "  - DAG+State Workers: $dagStateActive containers" -Color $Colors.Blue
    Write-ColorOutput "  - Total Active Workers: $totalActive containers" -Color $Colors.Blue
    
    return @{
        Validator = $validatorActive
        Consensus = $consensusActive
        DagState = $dagStateActive
        Total = $totalActive
    }
}

# Main execution
if ($Help) {
    Show-Help
    exit 0
}

Write-ColorOutput "`n🚀 Starting Avalanche Benchmark Suite - PowerShell Version`n" -Color $Colors.Green

# Get script directory and project root
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)

# Create directories
Write-ColorOutput "📁 Setting up environment..." -Color $Colors.Yellow
$ResultsDir = Join-Path $ScriptDir "benchmark-results"
$GraphsDir = Join-Path $ScriptDir "benchmark-graphs"

if (-not (Test-Path $ResultsDir)) { New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null }
if (-not (Test-Path $GraphsDir)) { New-Item -ItemType Directory -Path $GraphsDir -Force | Out-Null }

# Build the benchmark binary
Write-ColorOutput "`n🔨 Building benchmark binary..." -Color $Colors.Yellow
$buildResult = go build -o avalanche-benchmark.exe avalanche-comparison-benchmark.go
if ($LASTEXITCODE -ne 0) {
    Write-ColorOutput "❌ Failed to build benchmark binary" -Color $Colors.Red
    exit 1
}

# Start services with preserved scale
Write-ColorOutput "`n📦 Managing Docker services..." -Color $Colors.Yellow
$workerCounts = Start-ServicesWithScale

# Wait for services to be ready
Write-ColorOutput "`n⏳ Waiting for services to be ready..." -Color $Colors.Yellow

# Wait for Redis
Wait-ForService -ServiceName "avalanche-redis" -HealthEndpoint $null

# Wait for PostgreSQL
Wait-ForService -ServiceName "avalanche-postgres" -HealthEndpoint $null

# Wait for Worker Pools
Wait-ForService -ServiceName "consensus-haproxy" -HealthEndpoint "http://localhost:8080/health"
Wait-ForService -ServiceName "validator-haproxy" -HealthEndpoint "http://localhost:8081/health"
Wait-ForService -ServiceName "dag-state-haproxy" -HealthEndpoint "http://localhost:8082/health"

# Display current worker status before benchmark
$activeWorkers = Show-WorkerStatus -WorkerCounts $workerCounts

# Set environment variables for the benchmark
$env:BENCHMARK_RESULTS_DIR = $ResultsDir
$env:BENCHMARK_GRAPHS_DIR = $GraphsDir
$env:API_GATEWAY_ENDPOINT = "http://localhost:9650"
$env:METRICS_ENDPOINT = "http://localhost:9090"
$env:VALIDATOR_WORKERS = $activeWorkers.Validator
$env:CONSENSUS_WORKERS = $activeWorkers.Consensus
$env:DAG_STATE_WORKERS = $activeWorkers.DagState

# Run the benchmark
Write-ColorOutput "`n🏃‍♂️ Running parallel benchmark tests..." -Color $Colors.Yellow
Write-ColorOutput "This may take several minutes. Please wait...`n" -Color $Colors.Blue

$benchmarkResult = Start-Process -FilePath ".\avalanche-benchmark.exe" -Wait -NoNewWindow -PassThru

if ($benchmarkResult.ExitCode -eq 0) {
    Write-ColorOutput "✅ Benchmark tests completed successfully!`n" -Color $Colors.Green
}
else {
    Write-ColorOutput "❌ Benchmark failed" -Color $Colors.Red
    Write-ColorOutput "⚠️ Note: Worker pool configuration preserved for debugging" -Color $Colors.Yellow
    exit 1
}

# Generate graphs (if Python script exists)
Write-ColorOutput "📊 Generating benchmark graphs..." -Color $Colors.Yellow
if (Test-Path "generate_benchmark_graphs.py") {
    $graphResult = Start-Process -FilePath "python" -ArgumentList @("generate_benchmark_graphs.py", "--results-dir", $ResultsDir, "--output-dir", $GraphsDir) -Wait -NoNewWindow -PassThru
    if ($graphResult.ExitCode -ne 0) {
        Write-ColorOutput "⚠️ Failed to generate graphs" -Color $Colors.Yellow
    }
}
else {
    Write-ColorOutput "⚠️ Graph generator not found, skipping graph generation" -Color $Colors.Yellow
}

# Ask user if they want to keep services running
if (-not $KeepRunning) {
    Write-ColorOutput "`n✅ Benchmark completed. Current worker configuration preserved." -Color $Colors.Yellow
    $response = Read-Host "Do you want to stop the services? (y/N)"
    
    if ($response -match "^[Yy]") {
        Write-ColorOutput "`n🧹 Cleaning up services..." -Color $Colors.Yellow
        docker-compose -f "../../docker-compose.worker-pools.yml" down
    }
    else {
        Write-ColorOutput "`n✅ Services kept running with current configuration." -Color $Colors.Green
        Write-ColorOutput "💡 To manage workers later, use:" -Color $Colors.Blue
        Write-ColorOutput "  - Scale up: docker-compose -f docker-compose.worker-pools.yml up -d --scale validator-worker=10" -Color $Colors.Blue
        Write-ColorOutput "  - Scale down: docker-compose -f docker-compose.worker-pools.yml up -d --scale validator-worker=5" -Color $Colors.Blue
        Write-ColorOutput "  - Stop all: docker-compose -f docker-compose.worker-pools.yml down" -Color $Colors.Blue
    }
}
else {
    Write-ColorOutput "`n✅ Services kept running as requested." -Color $Colors.Green
}

Write-ColorOutput "`n🎉 Parallel Benchmark Suite Completed Successfully!" -Color $Colors.Green
Write-ColorOutput "📊 Results available in:" -Color $Colors.Green
Write-ColorOutput "  - $ResultsDir" -Color $Colors.Blue
Write-ColorOutput "  - $GraphsDir" -Color $Colors.Blue

# Display final worker status
$finalWorkers = Show-WorkerStatus -WorkerCounts @{}

# Display generated graphs
$graphs = Get-ChildItem -Path $GraphsDir -Filter "*.png" -ErrorAction SilentlyContinue
if ($graphs) {
    Write-ColorOutput "`n📈 Generated Graphs:" -Color $Colors.Yellow
    foreach ($graph in $graphs) {
        Write-ColorOutput "  - $($graph.Name)" -Color $Colors.Blue
    }
}
else {
    Write-ColorOutput "`n⚠️ No graphs generated" -Color $Colors.Yellow
} 