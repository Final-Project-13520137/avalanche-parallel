# PowerShell script to run the simplified blockchain test

Write-Host "Building and running the blockchain test..." -ForegroundColor Green

# Make sure go.mod is updated
go mod tidy

# Build the test
Write-Host "Building simple_test.go..." -ForegroundColor Green
go build -o test_blockchain.exe simple_test.go

# Check if build was successful
if ($LASTEXITCODE -eq 0) {
    Write-Host "Test built successfully. Running test..." -ForegroundColor Green
    # Run the test
    .\test_blockchain.exe
} else {
    Write-Host "Failed to build test" -ForegroundColor Red
}

# Clean up
if (Test-Path "test_blockchain.exe") {
    Write-Host "Cleaning up..." -ForegroundColor Green
    Remove-Item "test_blockchain.exe"
} 