# PowerShell script for running Avalanche benchmarks

# Get script directory and project root
$SCRIPT_DIR = $PSScriptRoot
$PROJECT_ROOT = (Get-Item $SCRIPT_DIR).Parent.Parent.FullName

Write-Host "🚀 Starting Avalanche Benchmark Suite" -ForegroundColor Green

# Create directories
New-Item -ItemType Directory -Force -Path "benchmark-results"
New-Item -ItemType Directory -Force -Path "benchmark-graphs"

# Build the benchmark binary
Write-Host "Building benchmark binary..." -ForegroundColor Yellow
go build -o avalanche-benchmark.exe avalanche-comparison-benchmark.go
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to build benchmark binary" -ForegroundColor Red
    exit 1
}

# Start required services
Write-Host "Starting required services..." -ForegroundColor Yellow
docker-compose -f "$PROJECT_ROOT/docker-compose.benchmark.yml" up -d redis postgres
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to start services" -ForegroundColor Red
    exit 1
}

# Wait for services to be ready
Write-Host "Waiting for services to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Run the benchmark
Write-Host "Running benchmark..." -ForegroundColor Yellow
.\avalanche-benchmark.exe
if ($LASTEXITCODE -ne 0) {
    Write-Host "Benchmark failed" -ForegroundColor Red
    docker-compose -f "$PROJECT_ROOT/docker-compose.benchmark.yml" down
    exit 1
}

# Generate graphs
Write-Host "Generating benchmark graphs..." -ForegroundColor Yellow
python generate-benchmark-graphs.py --results-dir benchmark-results --output-dir benchmark-graphs
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to generate graphs" -ForegroundColor Red
}

# Clean up
Write-Host "Cleaning up..." -ForegroundColor Yellow
docker-compose -f "$PROJECT_ROOT/docker-compose.benchmark.yml" down

Write-Host "✅ Benchmark completed" -ForegroundColor Green
Write-Host "📊 Results available in:" -ForegroundColor Green
Write-Host "  - benchmark-results/"
Write-Host "  - benchmark-graphs/" 