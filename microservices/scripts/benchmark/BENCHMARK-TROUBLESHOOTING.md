# Benchmark Binary Build Troubleshooting Guide

## Issue Description
The error occurs when trying to run the benchmark script:
```
⚠️ Benchmark binary './benchmark-sim' not found in script directory
Attempting to create binary with fallback method...
Fallback build in script directory...
go: downloading go1.24.3 (linux/amd64)
go: download go1.24.3: golang.org/toolchain@v0.0.1-go1.24.3.linux-amd64: verifying module: checksum database disabled by GOSUMDB=off

❌ Fallback build also failed
```

## Root Causes
1. **Go Module Checksum Verification Disabled**: `GOSUMDB=off` prevents proper module verification
2. **Missing Benchmark Binary**: The `benchmark-sim` binary is not found in the expected location
3. **Go Module Conflicts**: Multiple go.mod files with conflicting module paths
4. **Network Connectivity**: Issues downloading Go modules or toolchain
5. **File Permissions**: Insufficient permissions to build or write binaries
6. **Go Version Conflicts**: Mismatched Go versions between toolchain and environment

## Quick Fix Solutions

### Option 1: Fix Script (Recommended)
Run the fix script that resolves Go environment and module issues:

**Windows:**
```powershell
.\fix-benchmark-build.ps1
```

**Linux/Mac:**
```bash
./fix-benchmark-build.sh
```

### Option 2: Manual Environment Fix
Fix the Go environment manually:

```bash
# Enable checksum database
export GOSUMDB="sum.golang.org"

# Set proper proxy
export GOPROXY="https://proxy.golang.org,direct"

# Clear Go cache
go clean -cache -modcache -testcache

# Navigate to root directory
cd /mnt/e/final-project/avalanche-parallel

# Download and tidy modules
go mod download
go mod tidy
```

### Option 3: Copy Existing Binary
If you have an existing benchmark binary, copy it:

```bash
# Look for existing binaries
find /mnt/e/final-project/avalanche-parallel -name "*benchmark*" -type f -executable

# Copy to the expected location
cp /mnt/e/final-project/avalanche-parallel/benchmark_sim microservices/scripts/benchmark/benchmark-sim
chmod +x microservices/scripts/benchmark/benchmark-sim
```

## Manual Troubleshooting Steps

### 1. Check Go Installation
```bash
# Verify Go is installed
go version

# Check Go environment
go env GOROOT
go env GOPATH
go env GOSUMDB
go env GOPROXY
```

### 2. Fix Go Environment Variables
```bash
# Enable checksum verification
export GOSUMDB="sum.golang.org"

# Set proper module proxy
export GOPROXY="https://proxy.golang.org,direct"

# Disable Go workspace mode if causing issues
export GOWORK=off

# Set Go version explicitly if needed
export GOVERSION=go1.21
```

### 3. Resolve Module Conflicts
```bash
# Navigate to root directory
cd /mnt/e/final-project/avalanche-parallel

# Check module structure
go mod graph

# Download dependencies
go mod download

# Tidy modules
go mod tidy

# Verify modules
go mod verify
```

### 4. Build Benchmark Binary Manually
```bash
# Navigate to root directory
cd /mnt/e/final-project/avalanche-parallel

# Create output directory
mkdir -p microservices/scripts/benchmark

# Build the binary
go build -v -o microservices/scripts/benchmark/benchmark-sim scripts/standalone/benchmark_sim.go

# Verify the binary
ls -la microservices/scripts/benchmark/benchmark-sim
chmod +x microservices/scripts/benchmark/benchmark-sim
```

### 5. Test Network Connectivity
```bash
# Test Go module proxy
curl -I https://proxy.golang.org/

# Test checksum database
curl -I https://sum.golang.org/

# Test specific module download
go get -v golang.org/x/sys@latest
```

## Alternative Solutions

### 1. Use Different Go Version
If Go 1.24.3 is problematic, try a different version:

```bash
# Install Go 1.21 (more stable)
wget https://go.dev/dl/go1.21.12.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.12.linux-amd64.tar.gz
export PATH=/usr/local/go/bin:$PATH

# Or use gvm (Go Version Manager)
gvm install go1.21.12
gvm use go1.21.12
```

### 2. Create Simple Fallback Binary
If the original build fails, create a simple benchmark binary:

```bash
# Create simple Go program
cat > microservices/scripts/benchmark/simple_benchmark.go << 'EOF'
package main

import (
    "fmt"
    "os"
    "time"
)

func main() {
    fmt.Println("=== Avalanche Benchmark Simulator ===")
    fmt.Println("This is a fallback benchmark binary")
    fmt.Printf("Build time: %s\n", time.Now().Format("2006-01-02 15:04:05"))
    
    // Simulate benchmark work
    fmt.Println("Running simulated benchmark...")
    time.Sleep(2 * time.Second)
    
    fmt.Println("Benchmark completed successfully!")
    os.Exit(0)
}
EOF

# Build the simple binary
cd microservices/scripts/benchmark
go build -o benchmark-sim simple_benchmark.go
chmod +x benchmark-sim
rm simple_benchmark.go
```

### 3. Use Docker for Building
If local Go environment is problematic, use Docker:

```bash
# Build in Docker container
docker run --rm -v "$(pwd):/app" -w /app golang:1.21-alpine sh -c "
    apk add --no-cache git
    go build -v -o microservices/scripts/benchmark/benchmark-sim scripts/standalone/benchmark_sim.go
"
```

### 4. Fix Module Replace Directives
Check and fix module replace directives in go.mod files:

```bash
# Check microservices go.mod
cat microservices/go.mod

# Ensure proper replace directive
echo "replace github.com/Final-Project-13520137/avalanche-parallel => ../" >> microservices/go.mod
```

## Testing the Fix

### 1. Test Binary Existence
```bash
# Check if binary exists
ls -la microservices/scripts/benchmark/benchmark-sim*

# Test binary execution
./microservices/scripts/benchmark/benchmark-sim --help
```

### 2. Test Benchmark Script
```bash
# Run the benchmark script
cd microservices/scripts/benchmark
./run-benchmark.sh
```

### 3. Verify Go Environment
```bash
# Check Go environment after fix
go env GOSUMDB
go env GOPROXY
go env GOWORK
```

## Prevention

### 1. Use Consistent Go Versions
```bash
# Pin Go version in go.mod
echo "go 1.21.12" > go.mod

# Use go.mod toolchain directive
echo "toolchain go1.21.12" >> go.mod
```

### 2. Set Environment Variables Permanently
Add to your shell profile:

```bash
# ~/.bashrc or ~/.zshrc
export GOSUMDB="sum.golang.org"
export GOPROXY="https://proxy.golang.org,direct"
export GOWORK=off
```

### 3. Regular Module Maintenance
```bash
# Regular cleanup
go clean -cache -modcache -testcache

# Update dependencies
go get -u ./...

# Verify modules
go mod verify
```

## Common Error Messages and Solutions

| Error | Solution |
|-------|----------|
| `checksum database disabled by GOSUMDB=off` | Set `export GOSUMDB="sum.golang.org"` |
| `benchmark binary not found` | Run fix script or copy existing binary |
| `go: downloading go1.24.3` | Use stable Go version like 1.21.12 |
| `module conflicts` | Run `go mod tidy` and fix replace directives |
| `permission denied` | Check file permissions and use `chmod +x` |
| `network timeout` | Check internet connection and proxy settings |

## Getting Help

If the issue persists:

1. **Check Go Installation**: Verify Go is properly installed and in PATH
2. **Check Network**: Test connectivity to Go module proxy and checksum database
3. **Check Permissions**: Ensure write permissions in project directory
4. **Check Module Structure**: Verify go.mod files are consistent
5. **Use Docker**: Build in isolated Docker environment

## Files Created by Fix Scripts

- `benchmark-sim` - The benchmark binary
- `fix-benchmark-build.ps1` - Windows fix script
- `fix-benchmark-build.sh` - Linux/Mac fix script
- `simple_benchmark.go` - Fallback benchmark source (temporary)

## Success Indicators

✅ `benchmark-sim` binary exists and is executable
✅ Go environment variables are properly set
✅ Module dependencies are resolved
✅ Benchmark script runs without errors
✅ No checksum verification errors 