#!/usr/bin/env pwsh

Write-Host "Go Version Fix Script" -ForegroundColor Cyan
Write-Host "====================" -ForegroundColor Cyan
Write-Host "This script fixes Go version and toolchain issues in go.mod`n"

# Backup original go.mod
Write-Host "Creating backup of go.mod..." -ForegroundColor Yellow
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force

# Read the current go.mod file
Write-Host "Reading go.mod file..." -ForegroundColor Green
$goModContent = Get-Content -Path "go.mod" -Raw

# Fix the Go version (change 1.23.9 to a proper format like 1.18)
Write-Host "Fixing Go version..." -ForegroundColor Green
$goModContent = $goModContent -replace "go 1.23.9", "go 1.18"

# Remove the toolchain directive
Write-Host "Removing toolchain directive..." -ForegroundColor Green
$goModContent = $goModContent -replace "toolchain go1.24.3`r`n`r`n", ""
$goModContent = $goModContent -replace "toolchain go1.24.3`n`n", ""
$goModContent = $goModContent -replace "toolchain go1.24.3", ""

# Write the fixed content back to go.mod
Write-Host "Writing updated go.mod file..." -ForegroundColor Green
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