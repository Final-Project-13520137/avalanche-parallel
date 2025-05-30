#!/usr/bin/env pwsh
# Script to fix sorting.go comparison issue

Write-Host "Fixing sorting.go bytes.Compare issue..." -ForegroundColor Green

$sortingFilePath = "default\utils\sorting.go"

if (!(Test-Path $sortingFilePath)) {
    Write-Host "  ! Error: sorting.go file not found at: $sortingFilePath" -ForegroundColor Red
    Write-Host "    Make sure you are running this script from the project root directory." -ForegroundColor Red
    exit 1
}

Write-Host "  * Reading file: $sortingFilePath" -ForegroundColor Cyan
$content = Get-Content $sortingFilePath -Raw

# Fix the SortByHash function
$oldPattern = 'return bytes.Compare\(iHash, jHash\) < 0.*?<.*?0'
$newPattern = 'return bytes.Compare(iHash, jHash) < 0'

Write-Host "  * Fixing SortByHash function..." -ForegroundColor Cyan
$fixedContent = $content -replace $oldPattern, $newPattern

# Save the fixed content
Write-Host "  * Saving fixed file..." -ForegroundColor Cyan
$fixedContent | Set-Content $sortingFilePath

Write-Host "✓ sorting.go fixed successfully!" -ForegroundColor Green
