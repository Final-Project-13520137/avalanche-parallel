#!/bin/bash

echo "===== Fixing Go 1.18 Compatibility Issues ====="

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

# Step 5: Run go mod tidy to update dependencies
echo "Running go mod tidy..."
go mod tidy

echo "===== Compatibility fixes applied! ====="
echo "Try running tests now."

echo "Fixing go.mod with Go 1.18 compatible versions..."

# Backup the original go.mod
cp go.mod go.mod.bak

# Update go.mod to use Go 1.18 and compatible dependencies
cat > go.mod << 'EOF'
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
	golang.org/x/crypto v0.36.0 // indirect
	golang.org/x/sys v0.31.0 // indirect
	golang.org/x/term v0.30.0 // indirect
	gonum.org/v1/gonum v0.9.0 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
EOF

echo "Running go mod download and tidy..."
go mod download go.uber.org/atomic
go mod download go.uber.org/multierr@v1.6.0
go mod download go.uber.org/zap@v1.17.0
go mod tidy

echo "Fixed multierr dependency to be compatible with Go 1.18" 