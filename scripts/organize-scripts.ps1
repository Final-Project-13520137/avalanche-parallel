#!/usr/bin/env pwsh

Write-Host "🗂️ Mengorganisir Script berdasarkan Fungsi" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

# Buat direktori untuk mengorganisir script
$directories = @(
    "deployment",
    "setup",
    "benchmark",
    "maintenance",
    "scaling",
    "testing",
    "utility"
)

foreach ($dir in $directories) {
    $path = Join-Path "scripts" $dir
    if (!(Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
        Write-Host "✅ Dibuat direktori: $dir" -ForegroundColor Green
    }
}

Write-Host "🔄 Memindahkan script ke direktori yang sesuai..." -ForegroundColor Cyan

# Deployment Scripts
$deploymentScripts = @(
    "deploy.ps1",
    "deploy.sh",
    "deploy-docker.ps1",
    "deploy-docker.sh",
    "restart.ps1",
    "restart.sh",
    "restart-docker.ps1",
    "restart-docker.sh"
)

foreach ($script in $deploymentScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/deployment" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "📦 Dipindahkan: $script -> deployment/" -ForegroundColor Green
    }
}

# Setup Scripts
$setupScripts = @(
    "setup-k8s.ps1",
    "setup-k8s.sh",
    "make-executable.sh",
    "fix-metrics-server.sh",
    "create-docker-compose.ps1"
)

foreach ($script in $setupScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/setup" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "⚙️ Dipindahkan: $script -> setup/" -ForegroundColor Green
    }
}

# Benchmark Scripts
$benchmarkScripts = @(
    "run_parallel_benchmark.ps1",
    "run_parallel_benchmark.sh",
    "simple_benchmark.ps1",
    "simple_benchmark.sh",
    "benchmark_sim.go",
    "visualize_benchmark.go",
    "transaction_load.go",
    "transaction_load_test.go"
)

foreach ($script in $benchmarkScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/benchmark" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "📊 Dipindahkan: $script -> benchmark/" -ForegroundColor Green
    }
}

# Maintenance Scripts
$maintenanceScripts = @(
    "cleanup-all.ps1",
    "cleanup-all.sh",
    "update-imports.ps1",
    "update-dockerfiles.ps1",
    "replace-imports.sh"
)

foreach ($script in $maintenanceScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/maintenance" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "🧹 Dipindahkan: $script -> maintenance/" -ForegroundColor Green
    }
}

# Scaling Scripts
$scalingScripts = @(
    "dynamic-node-scaler.ps1",
    "dynamic-node-scaler.sh",
    "docker-dynamic-scaler.sh"
)

foreach ($script in $scalingScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/scaling" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "📈 Dipindahkan: $script -> scaling/" -ForegroundColor Green
    }
}

# Testing Scripts
$testingScripts = @(
    "run_blockchain_tests.ps1",
    "run_blockchain_tests.sh",
    "runtest.ps1"
)

foreach ($script in $testingScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/testing" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "🧪 Dipindahkan: $script -> testing/" -ForegroundColor Green
    }
}

# Utility Scripts
$utilityScripts = @(
    "chmod.bat"
)

foreach ($script in $utilityScripts) {
    $source = Join-Path "scripts" $script
    $dest = Join-Path "scripts/utility" $script
    if (Test-Path $source) {
        Move-Item $source $dest -Force
        Write-Host "🔧 Dipindahkan: $script -> utility/" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "🎉 Organisasi script selesai!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "📦 Deployment: scripts/deployment/" -ForegroundColor Cyan
Write-Host "⚙️ Setup: scripts/setup/" -ForegroundColor Cyan
Write-Host "📊 Benchmark: scripts/benchmark/" -ForegroundColor Cyan
Write-Host "🧹 Maintenance: scripts/maintenance/" -ForegroundColor Cyan
Write-Host "📈 Scaling: scripts/scaling/" -ForegroundColor Cyan
Write-Host "🧪 Testing: scripts/testing/" -ForegroundColor Cyan
Write-Host "🔧 Utility: scripts/utility/" -ForegroundColor Cyan
Write-Host ""
Write-Host "💡 Contoh penggunaan:" -ForegroundColor Yellow
Write-Host "   .\scripts\deployment\deploy-docker.ps1 --build" -ForegroundColor White
Write-Host "   .\scripts\setup\setup-k8s.ps1 -Provider kind" -ForegroundColor White
Write-Host "   .\scripts\benchmark\run_parallel_benchmark.ps1" -ForegroundColor White
Write-Host "   .\scripts\maintenance\cleanup-all.ps1" -ForegroundColor White 