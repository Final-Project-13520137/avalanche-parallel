#!/usr/bin/env pwsh

# Parse command line arguments
param (
    [switch]$TestMode,
    [switch]$FullTest,
    [string]$TransactionSize = "mixed",
    [int]$TransactionCount = 5000,
    [int]$BatchSize = 50,
    [switch]$Simulate = $true  # Default to simulation mode for now
)

Write-Host "Running Avalanche Parallel vs Traditional Consensus Benchmark" -ForegroundColor Cyan
Write-Host "=============================================================" -ForegroundColor Cyan

# Create results directory if it doesn't exist
$resultsDir = "benchmark-results"
if (!(Test-Path $resultsDir)) {
    New-Item -ItemType Directory -Path $resultsDir | Out-Null
    Write-Host "Created results directory: $resultsDir" -ForegroundColor Green
}

# Get timestamp for the results file
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$resultsFile = "$resultsDir\benchmark-$timestamp.txt"

# Display test options
Write-Host "Benchmark Options:" -ForegroundColor Yellow
if ($FullTest) {
    Write-Host "  Running comprehensive test with multiple scenarios" -ForegroundColor Yellow
    Write-Host "  This will take significantly longer to complete" -ForegroundColor Yellow
} else {
    Write-Host "  Transaction Size: $TransactionSize" -ForegroundColor Yellow
    Write-Host "  Transaction Count: $TransactionCount" -ForegroundColor Yellow
    Write-Host "  Batch Size: $BatchSize" -ForegroundColor Yellow
    
    if ($TestMode) {
        Write-Host "  Mode: TestParallelConsensus (Go Test)" -ForegroundColor Yellow
    } else {
        if ($Simulate) {
            Write-Host "  Mode: Simulated Benchmark" -ForegroundColor Yellow
        } else {
            Write-Host "  Mode: Real Transaction Load Test" -ForegroundColor Yellow
        }
    }
}

# Choose the appropriate script based on simulation flag
$benchmarkScript = if ($Simulate) { "benchmark_sim.go" } else { "transaction_load.go" }

# Decide which test to run
if ($FullTest) {
    # Run comprehensive benchmark with scenarios
    Write-Host "`nRunning comprehensive scenario tests..." -ForegroundColor Green
    
    $output = & go run ".\scripts\$benchmarkScript" --scenarios
    
    # Save the raw output
    $output | Out-File -FilePath "$resultsDir\scenarios-$timestamp.txt"
    Write-Host "Raw results saved to: $resultsDir\scenarios-$timestamp.txt" -ForegroundColor Green
    
    # Display the output
    $output
} 
elseif ($TestMode) {
    # Run the Go test benchmark
    Write-Host "`nRunning Go test benchmark..." -ForegroundColor Green
    
    $output = & go test -v -run TestParallelConsensus -count=5 ./pkg/blockchain
    
    # Save the raw output
    $output | Out-File -FilePath "$resultsDir\gotest-$timestamp.txt"
    Write-Host "Raw results saved to: $resultsDir\gotest-$timestamp.txt" -ForegroundColor Green
    
    # Display the output
    $output
}
else {
    # Run the scaling benchmark using our custom Go script
    Write-Host "`nRunning transaction load test with scaling benchmark..." -ForegroundColor Green
    
    # Using separate arguments instead of splitting a string
    $cmdArgs = @("--benchmark", "--transactions=$TransactionCount", "--batch=$BatchSize", "--tx-size=$TransactionSize")
    $output = & go run ".\scripts\$benchmarkScript" $cmdArgs
    
    # Display output
    $output
    
    Write-Host "`nResults saved to the benchmark-results directory" -ForegroundColor Green
}

Write-Host "`nBenchmark completed!" -ForegroundColor Cyan

# Run visualization tool
Write-Host "`nGenerating visualization graphs..." -ForegroundColor Cyan

# Check if go-chart is installed
$goChartInstalled = go list github.com/wcharczuk/go-chart/v2 2>$null
if (-not $goChartInstalled) {
    Write-Host "Installing required dependencies..." -ForegroundColor Yellow
    go get github.com/wcharczuk/go-chart/v2
}

# Run the visualization tool
go run .\scripts\visualize_benchmark.go

Write-Host "`nAll tasks completed!" -ForegroundColor Cyan 