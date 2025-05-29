#!/usr/bin/env pwsh

Write-Host "Minimal Go Fix Script" -ForegroundColor Green

# Fix sorting.go
$sortingFile = "default\utils\sorting.go"
if (Test-Path $sortingFile) {
    (Get-Content $sortingFile -Raw) -replace 'return bytes.Compare\(iHash, jHash\) < 0.*?<.*?0', 'return bytes.Compare(iHash, jHash) < 0' | Set-Content $sortingFile
    Write-Host "Fixed sorting.go" -ForegroundColor Green
}

# Fix transaction.go
$txFile = "pkg\blockchain\transaction.go"
if (Test-Path $txFile) {
    (Get-Content $txFile -Raw) -replace 'return set\.Set\[ids\.ID\]\{\}, nil', 'return set.Empty[ids.ID](), nil' | Set-Content $txFile
    Write-Host "Fixed transaction.go" -ForegroundColor Green
}

# Run tests
Write-Host "Fixes applied. Run tests with: .\scripts\run_blockchain_tests.ps1" -ForegroundColor Cyan 