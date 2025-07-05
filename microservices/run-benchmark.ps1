# Avalanche Microservices vs Monolith Benchmark Script

Write-Host "Starting Avalanche Microservices vs Monolith Benchmark..." -ForegroundColor Green
Write-Host "==============================================="

# Step 1: Clean up and prepare environment
Write-Host "Preparing benchmark environment..." -ForegroundColor Yellow
docker-compose -f docker-compose.benchmark.yml down --volumes 2>$null

# Step 2: Start benchmark infrastructure
Write-Host "Starting benchmark infrastructure..." -ForegroundColor Yellow
docker-compose -f docker-compose.benchmark.yml up -d redis

Write-Host "Waiting for Redis to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 10

# Step 3: Start worker pools
Write-Host "Starting worker pools..." -ForegroundColor Yellow
docker-compose -f docker-compose.benchmark.yml up -d --build consensus-worker-1 consensus-worker-2 consensus-worker-3
docker-compose -f docker-compose.benchmark.yml up -d --build validator-worker-1 validator-worker-2 validator-worker-3 validator-worker-4
docker-compose -f docker-compose.benchmark.yml up -d --build dag-state-worker-1 dag-state-worker-2

Write-Host "Waiting for workers to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Step 4: Start benchmark generator
Write-Host "Starting benchmark generator..." -ForegroundColor Yellow
docker-compose -f docker-compose.benchmark.yml up -d --build benchmark-generator

Write-Host "Waiting for benchmark generator to be ready..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

# Step 5: Start monitoring
Write-Host "Starting monitoring services..." -ForegroundColor Yellow
docker-compose -f docker-compose.benchmark.yml up -d prometheus grafana

# Step 6: Check all services are healthy
Write-Host "Checking service health..." -ForegroundColor Cyan
docker-compose -f docker-compose.benchmark.yml ps

# Step 7: Run benchmarks
Write-Host ""
Write-Host "Running Benchmark Tests..." -ForegroundColor Green
Write-Host "==============================================="

# Test Redis connection
Write-Host "Testing Redis connection..." -ForegroundColor Yellow
try {
    $redisTest = docker exec benchmark-redis redis-cli ping 2>$null
    if ($redisTest -eq "PONG") {
        Write-Host "Redis: Connected" -ForegroundColor Green
    } else {
        Write-Host "Redis: Failed to connect" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Redis: Error testing connection" -ForegroundColor Red
    exit 1
}

# Test benchmark generator
Write-Host "Testing benchmark generator..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "http://localhost:9000/health" -Method GET -TimeoutSec 10
    if ($response.status -eq "healthy") {
        Write-Host "Benchmark Generator: Ready" -ForegroundColor Green
    } else {
        Write-Host "Benchmark Generator: Not ready" -ForegroundColor Red
        exit 1
    }
} catch {
    Write-Host "Benchmark Generator: Error connecting" -ForegroundColor Red
    exit 1
}

# Run small test first
Write-Host ""
Write-Host "Running Small Test (1,000 tasks)..." -ForegroundColor Cyan
try {
    $smallResult = Invoke-RestMethod -Uri "http://localhost:9000/benchmark/preset/small" -Method GET -TimeoutSec 120
    Write-Host "Small Test Results:" -ForegroundColor White
    Write-Host "  Microservices TPS: $($smallResult.microservices.throughput)" -ForegroundColor White
    Write-Host "  Monolith TPS: $($smallResult.monolith.throughput)" -ForegroundColor White
    Write-Host "  Improvement: $([math]::Round($smallResult.improvement, 2))x" -ForegroundColor Green
} catch {
    Write-Host "Small test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Start-Sleep -Seconds 10

# Run medium test
Write-Host ""
Write-Host "Running Medium Test (5,000 tasks)..." -ForegroundColor Cyan
try {
    $mediumResult = Invoke-RestMethod -Uri "http://localhost:9000/benchmark/preset/medium" -Method GET -TimeoutSec 300
    Write-Host "Medium Test Results:" -ForegroundColor White
    Write-Host "  Microservices TPS: $($mediumResult.microservices.throughput)" -ForegroundColor White
    Write-Host "  Monolith TPS: $($mediumResult.monolith.throughput)" -ForegroundColor White
    Write-Host "  Improvement: $([math]::Round($mediumResult.improvement, 2))x" -ForegroundColor Green
} catch {
    Write-Host "Medium test failed: $($_.Exception.Message)" -ForegroundColor Red
}

Start-Sleep -Seconds 10

# Run large test
Write-Host ""
Write-Host "Running Large Test (10,000 tasks)..." -ForegroundColor Cyan
try {
    $largeResult = Invoke-RestMethod -Uri "http://localhost:9000/benchmark/preset/large" -Method GET -TimeoutSec 600
    Write-Host "Large Test Results:" -ForegroundColor White
    Write-Host "  Microservices TPS: $($largeResult.microservices.throughput)" -ForegroundColor White
    Write-Host "  Monolith TPS: $($largeResult.monolith.throughput)" -ForegroundColor White
    Write-Host "  Improvement: $([math]::Round($largeResult.improvement, 2))x" -ForegroundColor Green
} catch {
    Write-Host "Large test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 8: Generate comprehensive report
Write-Host ""
Write-Host "Generating Comprehensive Benchmark Report..." -ForegroundColor Cyan
try {
    $fullResults = Invoke-RestMethod -Uri "http://localhost:9000/benchmark/compare" -Method GET -TimeoutSec 300
    
    # Create timestamp for report
    $timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
    $reportFile = "benchmark-results/microservices-vs-monolith-$timestamp.json"
    
    # Ensure directory exists
    if (-not (Test-Path "benchmark-results")) {
        New-Item -ItemType Directory -Path "benchmark-results" -Force | Out-Null
    }
    
    # Save detailed results
    $fullResults | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportFile -Encoding UTF8
    
    Write-Host "Detailed report saved to: $reportFile" -ForegroundColor Green
} catch {
    Write-Host "Failed to generate comprehensive report: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 9: Final summary
Write-Host ""
Write-Host "Benchmark Completed!" -ForegroundColor Green
Write-Host "==============================================="
Write-Host "Services Available:" -ForegroundColor Cyan
Write-Host "  Benchmark Generator: http://localhost:9000" -ForegroundColor White
Write-Host "  Prometheus Metrics: http://localhost:9090" -ForegroundColor White
Write-Host "  Grafana Dashboard: http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "  Redis: localhost:6379" -ForegroundColor White
Write-Host ""
Write-Host "Worker Pools:" -ForegroundColor Cyan
Write-Host "  Consensus Workers: 3 instances (ports 8081-8083)" -ForegroundColor White
Write-Host "  Validator Workers: 4 instances (ports 8091-8094)" -ForegroundColor White
Write-Host "  DAG/State Workers: 2 instances (ports 8101-8102)" -ForegroundColor White
Write-Host ""
Write-Host "View logs: docker-compose -f docker-compose.benchmark.yml logs -f [service]" -ForegroundColor Gray
Write-Host "Stop benchmark: docker-compose -f docker-compose.benchmark.yml down" -ForegroundColor Gray 