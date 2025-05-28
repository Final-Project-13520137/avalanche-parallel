# PowerShell script to fix module path issues in Windows environments

Write-Host "Avalanche Parallel DAG - Module Path Fixer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "This script will help you set up the correct path to the Avalanche code.`n"

# Check Go version
$goVersionOutput = go version
if ($goVersionOutput -match 'go(\d+\.\d+)') {
    $goVersion = $matches[1]
    Write-Host "Detected Go version: $goVersion" -ForegroundColor Cyan
    
    # Get version from go.mod
    if (Test-Path -Path "go.mod") {
        $goModContent = Get-Content -Path "go.mod"
        foreach ($line in $goModContent) {
            if ($line -match '^go (\d+\.\d+)') {
                $modGoVersion = $matches[1]
                Write-Host "Current go.mod Go version: $modGoVersion" -ForegroundColor Cyan
                
                # Compare versions
                if ([Version]$modGoVersion -gt [Version]$goVersion) {
                    Write-Host "! go.mod requires Go $modGoVersion but your environment has Go $goVersion" -ForegroundColor Yellow
                    Write-Host "Updating go.mod to use Go $goVersion..." -ForegroundColor Cyan
                    
                    # Update go.mod
                    $goModContent = $goModContent -replace "go $modGoVersion", "go $goVersion"
                    Set-Content -Path "go.mod" -Value $goModContent
                    Write-Host "✓ Updated go.mod to use Go $goVersion" -ForegroundColor Green
                }
                break
            }
        }
    }
}

# Check if default directory exists
if (Test-Path -Path ".\default") {
    Write-Host "✓ Found 'default' directory" -ForegroundColor Green
    
    # Check if it has the expected Avalanche code
    if (Test-Path -Path ".\default\go.mod") {
        Write-Host "✓ Avalanche code appears to be in place" -ForegroundColor Green
    } else {
        Write-Host "! The 'default' directory exists but does not contain Avalanche code" -ForegroundColor Yellow
    }
} else {
    Write-Host "! The 'default' directory does not exist" -ForegroundColor Yellow
}

# Ask user how to proceed
Write-Host "`nHow would you like to proceed?"
Write-Host "1. Specify the path to existing Avalanche code"
Write-Host "2. Create a directory junction to the Avalanche code"
Write-Host "3. Exit without changes"
$option = Read-Host "Choose an option (1-3)"

switch ($option) {
    "1" {
        # Update go.mod with a path
        $avalanchePath = Read-Host "Enter the absolute path to the Avalanche code"
        
        # Check if the path exists
        if (-not (Test-Path -Path $avalanchePath)) {
            Write-Host "Error: The specified path does not exist." -ForegroundColor Red
            exit 1
        }
        
        # Update go.mod
        $env:AVALANCHE_PARALLEL_PATH = $avalanchePath
        Write-Host "Updating go.mod to use path: $env:AVALANCHE_PARALLEL_PATH" -ForegroundColor Cyan
        go mod edit -replace github.com/Final-Project-13520137/avalanche-parallel=$env:AVALANCHE_PARALLEL_PATH
        Write-Host "✓ Updated go.mod with the new path" -ForegroundColor Green
    }
    
    "2" {
        # Create a directory junction (Windows equivalent of symbolic link)
        $avalanchePath = Read-Host "Enter the absolute path to the Avalanche code"
        
        # Check if the path exists
        if (-not (Test-Path -Path $avalanchePath)) {
            Write-Host "Error: The specified path does not exist." -ForegroundColor Red
            exit 1
        }
        
        # Create junction
        Write-Host "Creating directory junction from $avalanchePath to .\default" -ForegroundColor Cyan
        
        # Remove default directory if it exists but isn't a valid junction
        if (Test-Path -Path ".\default") {
            Remove-Item -Path ".\default" -Force -Recurse
        }
        
        # Create the junction
        New-Item -ItemType Junction -Path ".\default" -Target $avalanchePath
        Write-Host "✓ Created directory junction" -ForegroundColor Green
    }
    
    "3" {
        Write-Host "Exiting without changes"
        exit 0
    }
    
    default {
        Write-Host "Invalid option selected" -ForegroundColor Red
        exit 1
    }
}

# Verify the setup
Write-Host "`nTesting your setup..." -ForegroundColor Cyan
go mod tidy
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Module dependencies resolved successfully" -ForegroundColor Green
    Write-Host "Your environment is now set up correctly!" -ForegroundColor Green
} else {
    Write-Host "! There was an issue resolving dependencies" -ForegroundColor Red
    Write-Host "Please check the error messages above and try again." -ForegroundColor Yellow
} 