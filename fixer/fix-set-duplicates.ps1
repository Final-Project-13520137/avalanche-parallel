Write-Host "===== Fixing Set Package Duplicates and Go Compatibility Issues =====" -ForegroundColor Cyan

# Step 1: Fix go.mod to use Go 1.18 and compatible multierr version
Write-Host "Fixing go.mod for Go 1.18 compatibility..." -ForegroundColor Green
$content = Get-Content -Path go.mod
$content = $content -replace "go 1.23.9", "go 1.18"
$content = $content | Where-Object { $_ -notmatch "toolchain" }
$content = $content -replace "go.uber.org/multierr v1.11.0", "go.uber.org/multierr v1.6.0"
$content | Set-Content -Path go.mod

# Step 2: Create backup directory
Write-Host "Creating backup directory..." -ForegroundColor Green
New-Item -Path "default\utils\set\backup" -ItemType Directory -Force | Out-Null

# Step 3: Back up original files if they exist
if (Test-Path "default\utils\set\set.go") {
    Write-Host "Backing up set.go..." -ForegroundColor Green
    Copy-Item -Path "default\utils\set\set.go" -Destination "default\utils\set\backup\set.go.bak" -Force
}

if (Test-Path "default\utils\set\sampleable_set.go") {
    Write-Host "Backing up sampleable_set.go..." -ForegroundColor Green
    Copy-Item -Path "default\utils\set\sampleable_set.go" -Destination "default\utils\set\backup\sampleable_set.go.bak" -Force
}

# Step 4: Remove ALL versions (both original and fixed) to avoid duplicates
Write-Host "Removing existing files to prevent duplication..." -ForegroundColor Green
Remove-Item -Path "default\utils\set\set.go" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "default\utils\set\sampleable_set.go" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "default\utils\set\set_fixed.go" -Force -ErrorAction SilentlyContinue
Remove-Item -Path "default\utils\set\sampleable_set_fixed.go" -Force -ErrorAction SilentlyContinue

# Step 5: Copy fixed versions from root directory to set directory
Write-Host "Installing fixed implementations..." -ForegroundColor Green
Copy-Item -Path "set_fixed.go" -Destination "default\utils\set\set.go" -Force
Copy-Item -Path "sampleable_set_fixed.go" -Destination "default\utils\set\sampleable_set.go" -Force

# Step 6: Fix any sorting issues
Write-Host "Fixing sorting.go if needed..." -ForegroundColor Green
if ((Test-Path "default\utils\sorting.go") -and (Test-Path "sorting_fixed.go")) {
    Copy-Item -Path "sorting_fixed.go" -Destination "default\utils\sorting.go" -Force
}

# Step 7: Fix the package name in sorting.go
Write-Host "Fixing package name in sorting.go..." -ForegroundColor Green
if (Test-Path "default\utils\sorting.go") {
    $sortingContent = Get-Content -Path "default\utils\sorting.go"
    $sortingContent = $sortingContent -replace "package main", "package utils"
    $sortingContent | Set-Content -Path "default\utils\sorting.go"
}

# Step 8: Run go mod tidy to update dependencies
Write-Host "Running go mod tidy..." -ForegroundColor Green
go mod tidy

Write-Host "===== All fixes applied! =====" -ForegroundColor Cyan
Write-Host "Original files backed up in default\utils\set\backup\" -ForegroundColor Yellow
Write-Host "Try running tests now." -ForegroundColor Green 