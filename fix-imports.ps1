# PowerShell script to fix module path mismatches

Write-Host "Module Path Mismatch Fixer" -ForegroundColor Cyan
Write-Host "==========================" -ForegroundColor Cyan
Write-Host "This script fixes import path mismatches between the local code and Avalanche dependencies.`n"

# Check if pkg directory exists
if (-not (Test-Path -Path ".\pkg")) {
    Write-Host "! Error: pkg directory not found. Make sure you're in the root of the project." -ForegroundColor Red
    exit 1
}

Write-Host "Updating import paths in the code..." -ForegroundColor Cyan

# Function to update imports in a file
function Update-Imports {
    param (
        [string]$FilePath
    )
    
    Write-Host "  Processing: $FilePath" -ForegroundColor Gray
    
    # Read the file content
    $content = Get-Content -Path $FilePath -Raw
    
    # Replace all occurrences of the problematic import path with the correct one
    $updatedContent = $content -replace 'github\.com/Final-Project-13520137/avalanche-parallel/default/', 'github.com/ava-labs/avalanchego/'
    
    # Write the updated content back to the file
    Set-Content -Path $FilePath -Value $updatedContent
}

# Find all Go files in the pkg directory and update imports
Get-ChildItem -Path ".\pkg" -Filter "*.go" -Recurse | ForEach-Object {
    Update-Imports -FilePath $_.FullName
}

# Update the go.mod file to use the correct import path for the replacement
Write-Host "Updating go.mod file..." -ForegroundColor Cyan
$goModContent = Get-Content -Path "go.mod" -Raw
$updatedGoModContent = $goModContent -replace 'replace github\.com/Final-Project-13520137/avalanche-parallel => \./default', 'replace github.com/ava-labs/avalanchego => ./default'
Set-Content -Path "go.mod" -Value $updatedGoModContent

# Update the import statements in the main code files
Write-Host "Updating import statements in the main code files..." -ForegroundColor Cyan
$mainFiles = @("simple_test.go", "test_blockchain.go", "logging.go")
foreach ($file in $mainFiles) {
    if (Test-Path -Path ".\$file") {
        Update-Imports -FilePath ".\$file"
    }
}

# Find any other Go files in the root directory
Get-ChildItem -Path "." -Filter "*.go" -File | ForEach-Object {
    Update-Imports -FilePath $_.FullName
}

Write-Host "Running go mod tidy to update dependencies..." -ForegroundColor Cyan
go mod tidy

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Import paths updated successfully!" -ForegroundColor Green
    Write-Host "Your code should now be able to properly import the Avalanche dependencies." -ForegroundColor Green
} else {
    Write-Host "! There was an issue updating the dependencies." -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
} 