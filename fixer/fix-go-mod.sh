#!/bin/bash

# Script to completely fix Go dependencies for Go 1.18 compatibility

echo "Fixing Go dependencies for Go 1.18 compatibility..."

# Clean Go cache
echo "Cleaning Go caches..."
sudo rm -rf /root/go/pkg/mod/go.uber.org/multierr*
sudo rm -rf /root/go/pkg/mod/cache/download/go.uber.org/multierr*

# Create a completely new go.mod file
echo "Creating new go.mod file..."
cat > go.mod.new << 'EOF'
module github.com/Final-Project-13520137/avalanche-parallel-dag

go 1.18

replace github.com/ava-labs/avalanchego => ./default

require (
	github.com/ava-labs/avalanchego v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.0
	github.com/stretchr/testify v1.10.0
	go.uber.org/zap v1.26.0
)

require (
	github.com/BurntSushi/toml v1.2.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/google/renameio/v2 v2.0.0 // indirect
	github.com/gorilla/rpc v1.2.0 // indirect
	github.com/mr-tron/base58 v1.2.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	go.uber.org/multierr v1.10.0 // indirect
	golang.org/x/crypto v0.36.0 // indirect
	golang.org/x/sys v0.31.0 // indirect
	golang.org/x/term v0.30.0 // indirect
	gonum.org/v1/gonum v0.11.0 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
EOF

# Back up existing go.mod
cp go.mod go.mod.bak

# Replace with new go.mod
cp go.mod.new go.mod

# Clean go.sum file
echo "Cleaning go.sum..."
rm -f go.sum

# Update dependencies
echo "Running go mod tidy..."
sudo go mod tidy

# Run the test
echo "Running the test..."
sudo go test -v ./pkg/blockchain -run TestBlockchain

echo "Process completed."