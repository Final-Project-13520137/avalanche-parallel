[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [int[]]$WorkerCounts = @(1, 2, 4, 8, 16),

    [Parameter(Mandatory = $false)]
    [int[]]$TransactionCounts = @(1000, 5000, 10000),

    [Parameter(Mandatory = $false)]
    [string]$OutputDir = "benchmark-results",

    [Parameter(Mandatory = $false)]
    [switch]$GenerateGraphs = $true
)

# Ensure Python is available for graph generation
function Test-Python {
    try {
        python --version
        return $true
    }
    catch {
        Write-Error "Python is not installed. Please install Python to generate graphs."
        return $false
    }
}

# Create output directory
function Initialize-OutputDirectory {
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir | Out-Null
    }
}

# Run benchmarks and collect results
function Run-Benchmarks {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $resultsFile = Join-Path $OutputDir "benchmark_results_$timestamp.json"
    $results = @{
        timestamp = $timestamp
        monolithic = @()
        parallel = @()
    }

    Write-Host "Running benchmarks..." -ForegroundColor Cyan

    # Run monolithic benchmarks
    Write-Host "`nRunning monolithic benchmarks..." -ForegroundColor Yellow
    foreach ($txCount in $TransactionCounts) {
        Write-Host "Testing with $txCount transactions..."
        $output = go test -bench "BenchmarkMonolithicPayment" -count 5 ./benchmark/...
        
        $results.monolithic += @{
            transactions = $txCount
            time = ParseBenchmarkOutput $output
        }
    }

    # Run parallel benchmarks
    Write-Host "`nRunning parallel benchmarks..." -ForegroundColor Yellow
    foreach ($workers in $WorkerCounts) {
        foreach ($txCount in $TransactionCounts) {
            Write-Host "Testing with $workers workers and $txCount transactions..."
            $output = go test -bench "BenchmarkParallelPayment" -count 5 ./benchmark/...
            
            $results.parallel += @{
                workers = $workers
                transactions = $txCount
                time = ParseBenchmarkOutput $output
            }
        }
    }

    # Save results
    $results | ConvertTo-Json -Depth 10 | Set-Content $resultsFile
    Write-Host "`nResults saved to: $resultsFile" -ForegroundColor Green

    return $resultsFile
}

# Parse benchmark output
function ParseBenchmarkOutput {
    param($output)
    
    $times = @()
    foreach ($line in $output) {
        if ($line -match "ns/op") {
            $time = [decimal]($line -split '\s+')[2]
            $times += $time
        }
    }
    
    # Calculate average
    $avg = ($times | Measure-Object -Average).Average
    return $avg
}

# Generate comparison graphs using Python
function Generate-Graphs {
    param($resultsFile)

    $pythonScript = @"
import json
import matplotlib.pyplot as plt
import numpy as np
from datetime import datetime

# Load benchmark results
with open('$resultsFile') as f:
    results = json.load(f)

# Create output directory for graphs
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
output_dir = f'$OutputDir/graphs_{timestamp}'
import os
os.makedirs(output_dir, exist_ok=True)

# Plot 1: Transaction Count vs Processing Time (Monolithic vs Parallel)
plt.figure(figsize=(12, 6))
tx_counts = sorted(set(r['transactions'] for r in results['monolithic']))
mono_times = [next(r['time'] for r in results['monolithic'] if r['transactions'] == tx)
              for tx in tx_counts]

# Get parallel results for each worker count
worker_counts = sorted(set(r['workers'] for r in results['parallel']))
for workers in worker_counts:
    parallel_times = [next(r['time'] for r in results['parallel'] 
                         if r['transactions'] == tx and r['workers'] == workers)
                     for tx in tx_counts]
    plt.plot(tx_counts, parallel_times, marker='o', label=f'Parallel ({workers} workers)')

plt.plot(tx_counts, mono_times, marker='s', label='Monolithic', linewidth=2)
plt.xlabel('Number of Transactions')
plt.ylabel('Processing Time (ns)')
plt.title('Transaction Processing Time Comparison')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/processing_time_comparison.png')
plt.close()

# Plot 2: Speedup Factor vs Worker Count
plt.figure(figsize=(12, 6))
for tx_count in tx_counts:
    mono_time = next(r['time'] for r in results['monolithic'] 
                    if r['transactions'] == tx_count)
    speedups = [mono_time / next(r['time'] for r in results['parallel']
                               if r['transactions'] == tx_count and r['workers'] == w)
                for w in worker_counts]
    plt.plot(worker_counts, speedups, marker='o', label=f'{tx_count} transactions')

plt.xlabel('Number of Workers')
plt.ylabel('Speedup Factor')
plt.title('Parallel Processing Speedup')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/speedup_factor.png')
plt.close()

# Plot 3: Worker Efficiency
plt.figure(figsize=(12, 6))
for tx_count in tx_counts:
    mono_time = next(r['time'] for r in results['monolithic']
                    if r['transactions'] == tx_count)
    efficiency = [mono_time / (next(r['time'] for r in results['parallel']
                                  if r['transactions'] == tx_count and r['workers'] == w) * w)
                 for w in worker_counts]
    plt.plot(worker_counts, efficiency, marker='o', label=f'{tx_count} transactions')

plt.xlabel('Number of Workers')
plt.ylabel('Efficiency')
plt.title('Worker Efficiency (Speedup/Worker)')
plt.legend()
plt.grid(True)
plt.savefig(f'{output_dir}/worker_efficiency.png')
plt.close()

print(f"Graphs generated in: {output_dir}")
"@

    $pythonScriptFile = Join-Path $OutputDir "generate_graphs.py"
    $pythonScript | Set-Content $pythonScriptFile

    Write-Host "`nGenerating comparison graphs..." -ForegroundColor Yellow
    python $pythonScriptFile

    Remove-Item $pythonScriptFile
}

# Main execution
try {
    Initialize-OutputDirectory

    if ($GenerateGraphs -and -not (Test-Python)) {
        Write-Error "Cannot generate graphs without Python. Please install Python or run without -GenerateGraphs"
        exit 1
    }

    $resultsFile = Run-Benchmarks

    if ($GenerateGraphs) {
        Generate-Graphs $resultsFile
    }

    Write-Host "`nBenchmark completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "Error during benchmark: $_"
    exit 1
} 