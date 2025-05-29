#!/bin/bash

echo "===== Fixing Go Version and Compatibility Issues ====="

# Step 1: Fix go.mod to use Go 1.18
echo "Setting Go version to 1.18..."
sed -i 's/go 1.23.9/go 1.18/g' go.mod
# Remove toolchain directive
sed -i '/toolchain/d' go.mod

# Step 2: Fix multierr version to be compatible with Go 1.18
echo "Setting multierr to v1.6.0 (Go 1.18 compatible)..."
# If multierr is a direct dependency
sed -i 's/go.uber.org\/multierr v1.11.0/go.uber.org\/multierr v1.6.0/g' go.mod
# If multierr is an indirect dependency
sed -i 's/go.uber.org\/multierr v1.11.0 \/\//go.uber.org\/multierr v1.6.0 \/\//g' go.mod

# Step 3: Fix zap version to be compatible with multierr v1.6.0
echo "Setting zap to v1.17.0 (compatible with multierr v1.6.0)..."
sed -i 's/go.uber.org\/zap v1.26.0/go.uber.org\/zap v1.17.0/g' go.mod

# Step 4: Fix other dependency versions for Go 1.18 compatibility
echo "Fixing other dependency versions..."
sed -i 's/golang.org\/x\/crypto v0.36.0/golang.org\/x\/crypto v0.0.0-20220112180741-5e0467b6c7ce/g' go.mod
sed -i 's/golang.org\/x\/sys v0.31.0/golang.org\/x\/sys v0.0.0-20220114195835-da31bd327af9/g' go.mod 
sed -i 's/golang.org\/x\/term v0.30.0/golang.org\/x\/term v0.0.0-20210927222741-03fcf44c2211/g' go.mod
sed -i 's/gonum.org\/v1\/gonum v0.11.0/gonum.org\/v1\/gonum v0.9.3/g' go.mod

# Step 5: Add required dependencies that might be missing for Go 1.18
echo "Adding atomic dependency for Go 1.18 compatibility..."
if ! grep -q "go.uber.org/atomic" go.mod; then
  sed -i '/require (/a\\tgo.uber.org/atomic v1.7.0' go.mod
fi

# Step 6: Run go mod tidy to update dependencies
echo "Running go mod tidy..."
go mod tidy

echo "===== Go version fixed to 1.18! =====" 