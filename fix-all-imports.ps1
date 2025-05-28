#!/usr/bin/env pwsh

Write-Host "Comprehensive Import Path Fixer" -ForegroundColor Cyan
Write-Host "===============================" -ForegroundColor Cyan
Write-Host "This script will fix all import paths in the project files.`n"

# Step 1: Fix the root Go module
Write-Host "Step 1: Fixing root go.mod file..." -ForegroundColor Green
$goModContent = Get-Content -Path "go.mod" -Raw
if ($goModContent -match "replace github\.com/Final-Project-13520137/avalanche-parallel => \./default") {
    Write-Host "  - Updating replace directive..." -ForegroundColor Gray
    $goModContent = $goModContent -replace "replace github\.com/Final-Project-13520137/avalanche-parallel => \./default", "replace github.com/ava-labs/avalanchego => ./default"
    Set-Content -Path "go.mod" -Value $goModContent
} elseif ($goModContent -match "replace github\.com/ava-labs/avalanchego => \./default") {
    Write-Host "  - Replace directive already updated." -ForegroundColor Gray
} else {
    Write-Host "  - Adding replace directive..." -ForegroundColor Gray
    $goModContent = $goModContent + "`nreplace github.com/ava-labs/avalanchego => ./default"
    Set-Content -Path "go.mod" -Value $goModContent
}

# Also ensure the correct require statements exist
if (-not ($goModContent -match "require github\.com/ava-labs/avalanchego")) {
    Write-Host "  - Adding required dependency..." -ForegroundColor Gray
    # Add require statement if needed
    $goModContent = $goModContent -replace "require \(", "require (`n`tgithub.com/ava-labs/avalanchego v0.0.0"
    Set-Content -Path "go.mod" -Value $goModContent
}

# Step 2: Update import paths in all Go files
Write-Host "`nStep 2: Updating import paths in Go files..." -ForegroundColor Green

# Function to update import paths in a file
function Update-ImportPaths {
    param (
        [string]$FilePath
    )
    
    # Only process Go files
    if (-not $FilePath.EndsWith(".go")) {
        return
    }
    
    Write-Host "  - Processing: $FilePath" -ForegroundColor Gray
    
    # Read file content
    $fileContent = Get-Content -Path $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $fileContent) {
        Write-Host "    ! Error reading file" -ForegroundColor Red
        return
    }
    
    # Replace import paths
    $originalContent = $fileContent
    $fileContent = $fileContent -replace 'github\.com/Final-Project-13520137/avalanche-parallel/default/', 'github.com/ava-labs/avalanchego/'
    
    # Only write if content changed
    if ($fileContent -ne $originalContent) {
        Write-Host "    * Updated import paths" -ForegroundColor Yellow
        Set-Content -Path $FilePath -Value $fileContent -ErrorAction SilentlyContinue
        if ($LASTEXITCODE -ne 0) {
            Write-Host "    ! Error writing to file" -ForegroundColor Red
        }
    } else {
        Write-Host "    * No changes needed" -ForegroundColor Gray
    }
}

# Process main project files
$mainFiles = @(
    "test_blockchain.go",
    "simple_test.go",
    "logging.go"
)

foreach ($file in $mainFiles) {
    if (Test-Path $file) {
        Update-ImportPaths -FilePath $file
    }
}

# Recursively process all Go files in pkg directory
Write-Host "`n  - Processing files in pkg directory..." -ForegroundColor Green
Get-ChildItem -Path "pkg" -Recurse -Filter "*.go" | ForEach-Object {
    Update-ImportPaths -FilePath $_.FullName
}

# Step 3: Clear any cached modules to ensure fresh state
Write-Host "`nStep 3: Clearing module cache..." -ForegroundColor Green
try {
    go clean -modcache -cache
    Write-Host "  * Module cache cleared" -ForegroundColor Gray
} catch {
    Write-Host "  ! Error clearing module cache: $_" -ForegroundColor Red
}

# Step 4: Update dependencies
Write-Host "`nStep 4: Updating dependencies..." -ForegroundColor Green
try {
    go mod tidy
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  * Dependencies updated successfully" -ForegroundColor Green
    } else {
        Write-Host "  ! Error updating dependencies" -ForegroundColor Red
    }
} catch {
    Write-Host "  ! Error running go mod tidy: $_" -ForegroundColor Red
}

# Final verification
Write-Host "`nVerifying imports in key files:" -ForegroundColor Cyan
$verificationFiles = @(
    "pkg/blockchain/block.go",
    "pkg/blockchain/transaction.go",
    "test_blockchain.go"
)

foreach ($file in $verificationFiles) {
    if (Test-Path $file) {
        Write-Host "`nFile: $file" -ForegroundColor Yellow
        Get-Content $file | Select-String -Pattern "import" -Context 0,10
    }
}

Write-Host "`nImport path fixes completed!" -ForegroundColor Green
Write-Host "To verify, run: go mod tidy" -ForegroundColor Cyan 