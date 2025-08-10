# AvalancheGo Monolithic vs Microservices Benchmark Script (PowerShell)
# Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.

param(
    [int]$Duration = 300,
    [int]$TpsTarget = 1000,
    [int]$ConcurrentUsers = 50,
    [int]$RampUpTime = 30,
    [switch]$MonolithicOnly,
    [switch]$MicroservicesOnly,
    [switch]$SkipBuild,
    [switch]$Clean,
    [string]$ResultsDir = "",
    [string]$Name = "",
    [string]$Format = "both",
    [switch]$Help
)

# Colors untuk output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"
$Purple = "Magenta"
$Cyan = "Cyan"

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $ScriptDir))
if ($ResultsDir -eq "") {
    $ResultsDir = Join-Path $ProjectRoot "benchmark-results"
}
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
if ($Name -eq "") {
    $BenchmarkName = "monolithic-vs-microservices-$Timestamp"
} else {
    $BenchmarkName = $Name
}

# Function to print status
function Write-Header {
    Write-Host "==========================================" -ForegroundColor $Blue
    Write-Host "🚀 AvalancheGo Benchmark: Monolithic vs Microservices" -ForegroundColor $Blue
    Write-Host "==========================================" -ForegroundColor $Blue
}

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

function Write-Section {
    param([string]$Message)
    Write-Host "[SECTION] $Message" -ForegroundColor $Purple
}

# Function to show help
function Show-Help {
    Write-Host "Usage: .\avalanche-monolithic-vs-microservices.ps1 [OPTIONS]"
    Write-Host ""
    Write-Host "Benchmark Options:"
    Write-Host "  -Duration SECONDS       Benchmark duration in seconds [default: 300]"
    Write-Host "  -TpsTarget TARGET       Target transactions per second [default: 1000]"
    Write-Host "  -ConcurrentUsers COUNT  Concurrent users [default: 50]"
    Write-Host "  -RampUpTime SECONDS     Ramp-up time in seconds [default: 30]"
    Write-Host ""
    Write-Host "System Options:"
    Write-Host "  -MonolithicOnly         Run only monolithic benchmark"
    Write-Host "  -MicroservicesOnly      Run only microservices benchmark"
    Write-Host "  -SkipBuild             Skip building binaries"
    Write-Host "  -Clean                 Clean up processes after benchmark"
    Write-Host ""
    Write-Host "Output Options:"
    Write-Host "  -ResultsDir DIR        Results directory [default: .\benchmark-results]"
    Write-Host "  -Name NAME             Benchmark name [default: auto-generated]"
    Write-Host "  -Format FORMAT         Output format (json, csv, both) [default: both]"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  .\avalanche-monolithic-vs-microservices.ps1"
    Write-Host "  .\avalanche-monolithic-vs-microservices.ps1 -Duration 600 -TpsTarget 2000"
    Write-Host "  .\avalanche-monolithic-vs-microservices.ps1 -MonolithicOnly -Duration 120"
    Write-Host "  .\avalanche-monolithic-vs-microservices.ps1 -Clean"
    Write-Host ""
}

# Function to setup environment
function Setup-Environment {
    Write-Section "Setting up benchmark environment"
    
    # Create results directory
    $BenchmarkDir = Join-Path $ResultsDir $BenchmarkName
    if (-not (Test-Path $BenchmarkDir)) {
        New-Item -ItemType Directory -Path $BenchmarkDir -Force | Out-Null
    }
    
    # Check dependencies
    Write-Status "Checking dependencies..."
    
    try {
        $goVersion = go version 2>$null
        if (-not $goVersion) { throw "Go not found" }
    } catch {
        Write-Error "Go is not installed or not in PATH"
        exit 1
    }
    
    try {
        $dockerVersion = docker --version 2>$null
        if (-not $dockerVersion) { throw "Docker not found" }
    } catch {
        Write-Error "Docker is not installed or not in PATH"
        exit 1
    }
    
    try {
        $curlVersion = curl --version 2>$null
        if (-not $curlVersion) { throw "curl not found" }
    } catch {
        Write-Error "curl is not installed or not in PATH"
        exit 1
    }
    
    Write-Status "✅ Dependencies check passed"
    return $BenchmarkDir
}

# Function to build systems
function Build-Systems {
    Write-Section "Building systems"
    
    Set-Location $ProjectRoot
    
    # Build monolithic system
    Write-Status "Building monolithic system..."
    $monolithicScript = Join-Path $ProjectRoot "scripts" | Join-Path -ChildPath "run-monolithic.ps1"
    $buildResult = & $monolithicScript build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build monolithic system"
        exit 1
    }
    
    # Build microservices system
    Write-Status "Building microservices system..."
    $microservicesDir = Join-Path $ProjectRoot "microservices"
    Set-Location $microservicesDir
    $buildResult = docker-compose -f docker-compose.benchmark.yml build
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to build microservices system"
        exit 1
    }
    
    Write-Status "✅ Systems built successfully"
}

# Function to start monolithic system
function Start-MonolithicSystem {
    param([string]$BenchmarkDir)
    
    Write-Status "Starting AvalancheGo Monolithic System..."
    
    Set-Location $ProjectRoot
    $binaryPath = Join-Path $ProjectRoot "bin" | Join-Path -ChildPath "avalanche-monolithic.exe"
    $logPath = Join-Path $BenchmarkDir "monolithic.log"
    $pidPath = Join-Path $BenchmarkDir "monolithic.pid"
    
    # Start monolithic in background
    $process = Start-Process -FilePath $binaryPath -ArgumentList @(
        "--log-level", "info",
        "--http-port", "9650",
        "--network-port", "9651"
    ) -RedirectStandardOutput $logPath -RedirectStandardError $logPath -PassThru
    
    $process.Id | Out-File $pidPath
    
    # Wait for startup
    Write-Status "Waiting for monolithic system to start..."
    for ($i = 1; $i -le 30; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:9650/ext/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Status "✅ Monolithic system is ready"
                return $process
            }
        } catch {}
        Start-Sleep 2
    }
    
    Write-Error "❌ Monolithic system failed to start"
    return $null
}

# Function to start microservices system
function Start-MicroservicesSystem {
    Write-Status "Starting Microservices System..."
    
    $microservicesDir = Join-Path $ProjectRoot "microservices"
    Set-Location $microservicesDir
    
    # Start microservices
    $result = docker-compose -f docker-compose.benchmark.yml up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to start microservices"
        return $false
    }
    
    # Wait for startup
    Write-Status "Waiting for microservices to start..."
    for ($i = 1; $i -le 60; $i++) {
        try {
            $response = Invoke-WebRequest -Uri "http://localhost:8080/health" -TimeoutSec 5 -ErrorAction SilentlyContinue
            if ($response.StatusCode -eq 200) {
                Write-Status "✅ Microservices system is ready"
                return $true
            }
        } catch {}
        Start-Sleep 3
    }
    
    Write-Error "❌ Microservices system failed to start"
    return $false
}

# Function to run benchmark test
function Run-BenchmarkTest {
    param(
        [string]$SystemName,
        [string]$Endpoint,
        [string]$ResultsFile,
        [string]$BenchmarkDir
    )
    
    Write-Status "Running benchmark for $SystemName..."
    Write-Status "Target: $TpsTarget TPS, Duration: ${Duration}s, Users: $ConcurrentUsers"
    
    # Create benchmark configuration
    $configFile = Join-Path $BenchmarkDir "${SystemName}_config.json"
    $config = @{
        endpoint = $Endpoint
        duration = $Duration
        tps_target = $TpsTarget
        concurrent_users = $ConcurrentUsers
        ramp_up_time = $RampUpTime
        test_scenarios = @(
            @{
                name = "transaction_processing"
                weight = 70
                requests = @(
                    @{
                        method = "POST"
                        path = "/ext/bc/X"
                        payload = @{
                            jsonrpc = "2.0"
                            method = "avm.createAddress"
                            params = @{}
                            id = 1
                        }
                    }
                )
            },
            @{
                name = "balance_queries"
                weight = 20
                requests = @(
                    @{
                        method = "GET"
                        path = "/ext/health"
                    }
                )
            },
            @{
                name = "consensus_queries"
                weight = 10
                requests = @(
                    @{
                        method = "POST"
                        path = "/ext/info"
                        payload = @{
                            jsonrpc = "2.0"
                            method = "info.getNodeVersion"
                            params = @{}
                            id = 1
                        }
                    }
                )
            }
        )
    }
    
    $config | ConvertTo-Json -Depth 10 | Out-File $configFile
    
    # Run actual benchmark
    Write-Status "Executing benchmark test..."
    
    $startTime = Get-Date
    $requestCount = 0
    $errorCount = 0
    $totalResponseTime = 0
    
    # Simple benchmark loop
    for ($i = 1; $i -le $Duration; $i++) {
        $iterationStart = Get-Date
        
        # Simulate concurrent requests
        for ($j = 1; $j -le [math]::Max(1, $TpsTarget / $Duration); $j++) {
            try {
                $response = Invoke-WebRequest -Uri "$Endpoint/ext/health" -TimeoutSec 5 -ErrorAction Stop
                $requestCount++
            } catch {
                $errorCount++
            }
        }
        
        $iterationEnd = Get-Date
        $iterationTime = ($iterationEnd - $iterationStart).TotalMilliseconds
        $totalResponseTime += $iterationTime
        
        if ($i % 30 -eq 0) {
            Write-Status "Progress: ${i}/${Duration}s (Requests: $requestCount, Errors: $errorCount)"
        }
        
        Start-Sleep 1
    }
    
    $endTime = Get-Date
    $durationActual = ($endTime - $startTime).TotalSeconds
    $avgResponseTime = if ($requestCount -gt 0) { $totalResponseTime / $requestCount } else { 0 }
    $tpsActual = if ($durationActual -gt 0) { $requestCount / $durationActual } else { 0 }
    $errorRate = if (($requestCount + $errorCount) -gt 0) { ($errorCount * 100) / ($requestCount + $errorCount) } else { 0 }
    
    # Generate results
    $results = @{
        system = $SystemName
        timestamp = (Get-Date).ToString("o")
        configuration = @{
            duration = $Duration
            target_tps = $TpsTarget
            concurrent_users = $ConcurrentUsers
            ramp_up_time = $RampUpTime
        }
        results = @{
            duration_actual = [math]::Round($durationActual, 2)
            total_requests = $requestCount
            total_errors = $errorCount
            tps_actual = [math]::Round($tpsActual, 2)
            avg_response_time_ms = [math]::Round($avgResponseTime, 2)
            error_rate_percent = [math]::Round($errorRate, 2)
            success_rate_percent = [math]::Round(100 - $errorRate, 2)
        }
    }
    
    $results | ConvertTo-Json -Depth 10 | Out-File $ResultsFile
    
    Write-Status "✅ Benchmark completed for $SystemName"
    Write-Status "Results: $([math]::Round($tpsActual, 2)) TPS, $([math]::Round($avgResponseTime, 2))ms avg response, $([math]::Round($errorRate, 2))% error rate"
}

# Function to stop systems
function Stop-MonolithicSystem {
    param([string]$BenchmarkDir)
    
    Write-Status "Stopping monolithic system..."
    $pidPath = Join-Path $BenchmarkDir "monolithic.pid"
    
    if (Test-Path $pidPath) {
        $pid = Get-Content $pidPath
        try {
            $process = Get-Process -Id $pid -ErrorAction SilentlyContinue
            if ($process) {
                $process.Kill()
                $process.WaitForExit(5000)
            }
        } catch {}
        Remove-Item $pidPath -ErrorAction SilentlyContinue
    }
    
    Write-Status "✅ Monolithic system stopped"
}

function Stop-MicroservicesSystem {
    Write-Status "Stopping microservices..."
    $microservicesDir = Join-Path $ProjectRoot "microservices"
    Set-Location $microservicesDir
    docker-compose -f docker-compose.benchmark.yml down
    Write-Status "✅ Microservices stopped"
}

# Function to generate comparison report
function Generate-Report {
    param([string]$BenchmarkDir)
    
    Write-Section "Generating comparison report"
    
    $monolithicResults = Join-Path $BenchmarkDir "monolithic_results.json"
    $microservicesResults = Join-Path $BenchmarkDir "microservices_results.json"
    $reportFile = Join-Path $BenchmarkDir "comparison_report.md"
    
    $report = @"
# AvalancheGo Benchmark Results: Monolithic vs Microservices

**Benchmark Date**: $(Get-Date)
**Benchmark ID**: $BenchmarkName

## Configuration
- **Duration**: ${Duration} seconds
- **Target TPS**: ${TpsTarget}
- **Concurrent Users**: ${ConcurrentUsers}
- **Ramp-up Time**: ${RampUpTime} seconds

## Results Summary

### Monolithic System
"@

    if (Test-Path $monolithicResults) {
        $monoData = Get-Content $monolithicResults | ConvertFrom-Json
        $report += @"

- **Actual TPS**: $($monoData.results.tps_actual)
- **Average Response Time**: $($monoData.results.avg_response_time_ms)ms
- **Error Rate**: $($monoData.results.error_rate_percent)%
- **Success Rate**: $($monoData.results.success_rate_percent)%

"@
    } else {
        $report += "`n- **Status**: Not tested`n"
    }

    $report += @"

### Microservices System
"@

    if (Test-Path $microservicesResults) {
        $microData = Get-Content $microservicesResults | ConvertFrom-Json
        $report += @"

- **Actual TPS**: $($microData.results.tps_actual)
- **Average Response Time**: $($microData.results.avg_response_time_ms)ms
- **Error Rate**: $($microData.results.error_rate_percent)%
- **Success Rate**: $($microData.results.success_rate_percent)%

## Performance Comparison

| Metric | Monolithic | Microservices | Winner |
|--------|------------|---------------|---------|
| TPS | $($monoData.results.tps_actual) | $($microData.results.tps_actual) | $(if ($monoData.results.tps_actual -gt $microData.results.tps_actual) { "Monolithic" } else { "Microservices" }) |
| Response Time | $($monoData.results.avg_response_time_ms)ms | $($microData.results.avg_response_time_ms)ms | $(if ($monoData.results.avg_response_time_ms -lt $microData.results.avg_response_time_ms) { "Monolithic" } else { "Microservices" }) |
| Error Rate | $($monoData.results.error_rate_percent)% | $($microData.results.error_rate_percent)% | $(if ($monoData.results.error_rate_percent -lt $microData.results.error_rate_percent) { "Monolithic" } else { "Microservices" }) |

"@
    } else {
        $report += "`n- **Status**: Not tested`n"
    }

    $report += @"

## Files Generated
- Monolithic Results: ``monolithic_results.json``
- Microservices Results: ``microservices_results.json``
- Monolithic Logs: ``monolithic.log``
- Configuration Files: ``*_config.json``

## Benchmark Environment
- **Host OS**: $([System.Environment]::OSVersion.VersionString)
- **Architecture**: $([System.Environment]::Is64BitOperatingSystem)
- **PowerShell Version**: $($PSVersionTable.PSVersion)
- **Go Version**: $(go version 2>$null)
- **Docker Version**: $(docker --version 2>$null)

Generated on $(Get-Date)
"@

    $report | Out-File $reportFile
    Write-Status "✅ Report generated: $reportFile"
}

# Show help if requested
if ($Help) {
    Show-Help
    exit 0
}

# Main execution
function Main {
    Write-Header
    
    # Setup
    $BenchmarkDir = Setup-Environment
    
    # Clean up if requested
    if ($Clean) {
        Write-Section "Cleaning up existing processes"
        Stop-MonolithicSystem $BenchmarkDir
        Stop-MicroservicesSystem
        Start-Sleep 5
    }
    
    # Build systems
    if (-not $SkipBuild) {
        Build-Systems
    }
    
    # Run monolithic benchmark
    if (-not $MicroservicesOnly) {
        Write-Section "Benchmarking Monolithic System"
        $monolithicProcess = Start-MonolithicSystem $BenchmarkDir
        if ($monolithicProcess) {
            Start-Sleep 10  # Allow system to stabilize
            Run-BenchmarkTest "monolithic" "http://localhost:9650" (Join-Path $BenchmarkDir "monolithic_results.json") $BenchmarkDir
            Stop-MonolithicSystem $BenchmarkDir
            Start-Sleep 5
        }
    }
    
    # Run microservices benchmark
    if (-not $MonolithicOnly) {
        Write-Section "Benchmarking Microservices System"
        $microservicesStarted = Start-MicroservicesSystem
        if ($microservicesStarted) {
            Start-Sleep 15  # Allow system to stabilize
            Run-BenchmarkTest "microservices" "http://localhost:8080" (Join-Path $BenchmarkDir "microservices_results.json") $BenchmarkDir
            Stop-MicroservicesSystem
            Start-Sleep 5
        }
    }
    
    # Generate report
    Generate-Report $BenchmarkDir
    
    Write-Section "Benchmark Complete!"
    Write-Status "Results available in: $BenchmarkDir"
    Write-Status "View report: Get-Content '$BenchmarkDir\comparison_report.md'"
}

# Run main function
Main 