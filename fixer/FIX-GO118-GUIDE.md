# Go 1.18 Compatibility Guide

This project requires Go 1.18 specifically. Follow these steps to ensure compatibility.

## Common Issues

1. **Package Conflict in `utils` Directory**
   - Problem: `default/ids/id.go:12:2: found packages utils (atomic.go) and main (sorting.go) in default/utils`
   - Solution: Fix the package declaration in sorting.go from `package main` to `package utils`

2. **`bytes.Compare` Syntax Issues**
   - Problem: `bytes.Compare undefined (type [][]byte has no field or method Compare)`
   - Solution: Ensure sorting.go is using the correct variable names and syntax

3. **Duplicate Declarations in Set Package**
   - Problem: `SampleableSet redeclared in this block` or `Set redeclared in this block`
   - Solution: Remove any duplicate .go files in the set package

4. **multierr Dependency Requiring Go 1.19+**
   - Problem: `go.uber.org/multierr: undefined: atomic.Bool` and `note: module requires Go 1.19`
   - Solution: Downgrade to multierr v1.6.0 and zap v1.17.0

5. **Missing go.sum Entries**
   - Problem: `go: go.uber.org/atomic@v1.7.0: missing go.sum entry`
   - Solution: Download missing dependencies and run go mod tidy

## Fix Scripts

We've provided several scripts to automatically fix these issues:

### Windows (PowerShell)

```powershell
# Fix package conflict in sorting.go
.\fix-sorting.ps1

# Fix set package duplicates
.\fix-set-duplicates.ps1

# Fix Go version in go.mod
.\fix-go-version.ps1

# Fix all imports
.\fix-all-imports.ps1

# Complete compatibility fix
.\fix-go-compatibility.ps1
```

### Linux/macOS

```bash
# Fix package conflict in sorting.go
chmod +x fix-sorting-linux.sh
sudo ./fix-sorting-linux.sh

# Fix set package duplicates
chmod +x fix-set-duplicates-linux.sh
sudo ./fix-set-duplicates-linux.sh

# Fix Go version in go.mod
chmod +x fix-go-version.sh
sudo ./fix-go-version.sh

# Fix missing go.sum entries
chmod +x fix-go-sum.sh
sudo ./fix-go-sum.sh

# All-in-one fix
chmod +x fix-all-linux.sh
sudo ./fix-all-linux.sh
```

## Manual Fix Instructions

If the scripts don't work for your environment, here are the manual steps:

### 1. Fix go.mod

Create a go.mod file with the following content:

```go
module github.com/Final-Project-13520137/avalanche-parallel-dag

go 1.18

replace github.com/ava-labs/avalanchego => ./default

require (
	github.com/ava-labs/avalanchego v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.0
	github.com/stretchr/testify v1.8.0
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
	go.uber.org/multierr v1.6.0 // indirect
	golang.org/x/crypto v0.0.0-20220112180741-5e0467b6c7ce // indirect
	golang.org/x/sys v0.0.0-20220114195835-da31bd327af9 // indirect
	golang.org/x/term v0.0.0-20210927222741-03fcf44c2211 // indirect
	gonum.org/v1/gonum v0.9.0 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
```

### 2. Fix sorting.go

Edit `default/utils/sorting.go` to:
- Change `package main` to `package utils`
- Fix variable names to avoid conflicts with the bytes package

### 3. Fix Set Package Duplicates

1. Make sure only one copy of each set file exists
2. Remove any files named `set_fixed.go` or `sampleable_set_fixed.go`
3. Ensure both files are in `default/utils/set/` directory

### 4. Install Required Dependencies

```bash
go clean -modcache
go get go.uber.org/multierr@v1.6.0
go get go.uber.org/zap@v1.17.0
go mod tidy
```

## Troubleshooting

If you still encounter issues after following these steps:

1. Try removing the go.mod and go.sum files and recreating them
2. Delete any cached modules with `go clean -modcache`
3. Install specific versions of dependencies manually
4. For Windows users, ensure you're using PowerShell and not Command Prompt

## Known Limitation

This project currently works only with Go 1.18. Using Go 1.19+ will cause compatibility issues with some dependencies.

## Fixing the multierr Dependency Issue

If you encounter an error like this:

```
# go.uber.org/multierr
/root/go/pkg/mod/go.uber.org/multierr@v1.11.0/error.go:209:20: undefined: atomic.Bool
note: module requires Go 1.19
FAIL    github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain [build failed]
```

This is because the current version of `go.uber.org/multierr` (v1.11.0) requires Go 1.19, but you're using Go 1.18.

### Solution

To fix this issue, we need to downgrade the `multierr` package to a version compatible with Go 1.18:

1. Manually edit your `go.mod` file to:
   - Set `go 1.18` at the top
   - Change `go.uber.org/multierr` to version `v1.6.0`
   - Change `go.uber.org/zap` to version `v1.17.0` (which depends on multierr v1.6.0)
   - Update other dependencies to compatible versions

2. Run `go mod tidy` to resolve all dependencies

### Example go.mod File

```
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
```

### Automated Fix Script

You can create a PowerShell script to automate this fix:

```powershell
# PowerShell script to fix multierr version for Go 1.18 compatibility

Write-Host "Fixing multierr dependency for Go 1.18 compatibility..." -ForegroundColor Cyan

# Back up the existing go.mod file
Copy-Item -Path "go.mod" -Destination "go.mod.bak" -Force
Write-Host "Backed up original go.mod to go.mod.bak" -ForegroundColor Yellow

# Create new go.mod content
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

# Write the new go.mod content
$goModContent | Set-Content -Path "go.mod" -Force
Write-Host "Created new go.mod file with multierr v1.6.0" -ForegroundColor Green

# Update dependencies
Write-Host "Running go mod tidy..." -ForegroundColor Cyan
go mod tidy
```

Save this as `fix-multierr.ps1` and run it with `.\fix-multierr.ps1` 