#!/usr/bin/env pwsh

Write-Host "Module Path Mismatch Fix Script" -ForegroundColor Cyan
Write-Host "=============================" -ForegroundColor Cyan
Write-Host "This script fixes module path issues in go.mod and Go files`n"

# Backup original go.mod
Write-Host "Creating backup of go.mod..." -ForegroundColor Yellow
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force

# Read the contents of the default/go.mod file to get the correct module path
Write-Host "Checking default/go.mod for correct module path..." -ForegroundColor Green
$defaultModPath = ""
if (Test-Path "default/go.mod") {
    $defaultGoMod = Get-Content -Path "default/go.mod" -Raw
    if ($defaultGoMod -match "module\s+([^\s]+)") {
        $defaultModPath = $matches[1]
        Write-Host "  * Found module path: $defaultModPath" -ForegroundColor Green
    }
}

if (-not $defaultModPath) {
    $defaultModPath = "github.com/ava-labs/avalanchego"
    Write-Host "  ! Could not find module path in default/go.mod, using: $defaultModPath" -ForegroundColor Yellow
}

# Update go.mod file
Write-Host "`nUpdating go.mod file..." -ForegroundColor Green
$goModContent = Get-Content -Path "go.mod" -Raw

# Update replace directive
if ($goModContent -match "replace\s+github\.com/Final-Project-13520137/avalanche-parallel(/default)?\s+=>\s+\./default") {
    Write-Host "  * Updating replace directive..." -ForegroundColor Gray
    $goModContent = $goModContent -replace "replace\s+github\.com/Final-Project-13520137/avalanche-parallel(/default)?\s+=>\s+\./default", "replace $defaultModPath => ./default"
} elseif ($goModContent -match "replace\s+github\.com/ava-labs/avalanchego\s+=>\s+\./default") {
    Write-Host "  * Replace directive already correct." -ForegroundColor Gray
} else {
    Write-Host "  * Adding replace directive..." -ForegroundColor Gray
    $goModContent = $goModContent + "`nreplace $defaultModPath => ./default"
}

# Write updated go.mod
Set-Content -Path "go.mod" -Value $goModContent

# Update imports in Go files
Write-Host "`nUpdating import paths in Go files..." -ForegroundColor Green

# Function to update imports
function Update-ImportPaths {
    param (
        [string]$FilePath
    )
    
    if (-not (Test-Path $FilePath)) {
        return
    }
    
    $content = Get-Content -Path $FilePath -Raw
    $original = $content
    
    # Replace old imports with new
    $content = $content -replace 'github\.com/Final-Project-13520137/avalanche-parallel/default/', "$defaultModPath/"
    
    # Write if changed
    if ($content -ne $original) {
        Write-Host "  * Updated: $FilePath" -ForegroundColor Yellow
        Set-Content -Path $FilePath -Value $content
    }
}

# Recursively process all .go files
Write-Host "  * Scanning for Go files..." -ForegroundColor Gray
Get-ChildItem -Path "." -Recurse -Filter "*.go" | ForEach-Object {
    Update-ImportPaths -FilePath $_.FullName
}

# Fix cmd directory specially (often has benchmark and tools)
if (Test-Path "cmd") {
    Write-Host "`nFixing cmd directory..." -ForegroundColor Green
    Get-ChildItem -Path "cmd" -Recurse -Filter "*.go" | ForEach-Object {
        Update-ImportPaths -FilePath $_.FullName
    }
}

# Run go mod tidy
Write-Host "`nRunning go mod tidy..." -ForegroundColor Green
go mod tidy

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ Success! Module path issues fixed." -ForegroundColor Green
} else {
    Write-Host "`n❌ Some issues remain. Check the error messages above." -ForegroundColor Red
    Write-Host "You may need to manually adjust some import paths." -ForegroundColor Yellow
}

Write-Host "`nTo restore the original go.mod, run: Copy-Item -Path go.mod.bak -Destination go.mod -Force" -ForegroundColor Cyan 