#!/usr/bin/env pwsh

Write-Host "Go Version Fix Script" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "This script fixes Go version and toolchain issues in go.mod`n"

# Backup original go.mod
Write-Host "Creating backup of go.mod..." -ForegroundColor Yellow
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force

# Fix go.mod file
Write-Host "Fixing go.mod file..." -ForegroundColor Green

# Read content
$goModContent = Get-Content -Path "go.mod" -Raw

# Replace invalid Go version with 1.18
$goModContent = $goModContent -replace "go 1.23.9", "go 1.18"

# Remove toolchain directive
$goModContent = $goModContent -replace "toolchain go1.24.3`r`n`r`n", ""
$goModContent = $goModContent -replace "toolchain go1.24.3`n`n", ""

# Write the fixed content to go.mod
Set-Content -Path "go.mod" -Value $goModContent

# Run go mod tidy to clean up dependencies
Write-Host "`nRunning go mod tidy..." -ForegroundColor Green
try {
    go mod tidy
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Success! Go version fixed." -ForegroundColor Green
    } else {
        Write-Host "`n⚠️ go mod tidy completed with warnings. Check the output above." -ForegroundColor Yellow
    }
} catch {
    Write-Host "`n❌ Error running go mod tidy: $_" -ForegroundColor Red
}

Write-Host "`nTo restore the original go.mod, run: Copy-Item -Path go.mod.bak -Destination go.mod -Force" -ForegroundColor Cyan 