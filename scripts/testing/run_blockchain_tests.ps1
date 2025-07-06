# PowerShell script to run blockchain tests

Write-Host "Running Avalanche Parallel Blockchain Tests" -ForegroundColor Green
Write-Host "----------------------------------------" -ForegroundColor Green

# Set environment variables for testing
$env:AVALANCHE_PARALLEL_PATH = "..\avalanche-parallel"

Write-Host "Running unit tests..." -ForegroundColor Cyan
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "^Test[^(Full|Blockchain|Parallel)]" -count=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Unit tests failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Running blockchain integration tests..." -ForegroundColor Cyan
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestBlockchain" -count=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Blockchain integration tests failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host "Running full flow tests..." -ForegroundColor Cyan
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestFull" -count=1
if ($LASTEXITCODE -ne 0) {
    Write-Host "Full flow tests failed!" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Performance benchmark tests - run only if specified
if ($args.Contains("--benchmark")) {
    Write-Host "Running parallel performance benchmark tests..." -ForegroundColor Cyan
    go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestParallelConsensus" -count=1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Performance benchmark tests failed!" -ForegroundColor Red
        exit $LASTEXITCODE
    }
} else {
    Write-Host "Skipping performance benchmark tests. Use --benchmark flag to run them." -ForegroundColor Yellow
}

Write-Host "All tests completed successfully!" -ForegroundColor Green 