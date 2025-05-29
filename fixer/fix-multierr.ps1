# PowerShell script to fix multierr version for Go 1.18 compatibility

Write-Host "Fixing multierr dependency for Go 1.18 compatibility..." -ForegroundColor Cyan

# Create a new go.mod file with a downgraded multierr version
$goModContent = @"
module github.com/Final-Project-13520137/avalanche-parallel-dag

go 1.18

replace github.com/ava-labs/avalanchego => ./default

require (
	github.com/ava-labs/avalanchego v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.0
	github.com/stretchr/testify v1.10.0
	go.uber.org/multierr v1.6.0
	go.uber.org/zap v1.17.0
)

require (
	github.com/BurntSushi/toml v1.2.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/google/renameio/v2 v2.0.0 // indirect
	github.com/gorilla/rpc v1.2.0 // indirect
	github.com/mr-tron/base58 v1.2.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	go.uber.org/atomic v1.7.0 // indirect
	golang.org/x/crypto v0.0.0-20220112180741-5e0467b6c7ce // indirect
	golang.org/x/sys v0.0.0-20220114195835-da31bd327af9 // indirect
	golang.org/x/term v0.0.0-20210927222741-03fcf44c2211 // indirect
	gonum.org/v1/gonum v0.9.3 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
"@

# Back up the existing go.mod file
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force
Write-Host "Backed up original go.mod to go.mod.bak" -ForegroundColor Yellow

# Write the new go.mod content
$goModContent | Set-Content -Path "go.mod" -Force
Write-Host "Created new go.mod file with multierr v1.6.0" -ForegroundColor Green

# Update dependencies
Write-Host "Running go mod tidy..." -ForegroundColor Cyan
go mod tidy

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Fix completed successfully!" -ForegroundColor Green
    Write-Host "The multierr package has been downgraded to v1.6.0 which is compatible with Go 1.18." -ForegroundColor Green
    Write-Host "You can now run your tests with: go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestBlockchain" -ForegroundColor Cyan
} else {
    Write-Host "! There was an issue running go mod tidy." -ForegroundColor Red
    Write-Host "Please check the error messages above." -ForegroundColor Yellow
} 