#!/bin/bash

# Script to fix multierr version for Go 1.18 compatibility in Linux

echo "Fixing multierr dependency for Go 1.18 compatibility..."

# Remove any cached multierr packages
sudo rm -rf /root/go/pkg/mod/go.uber.org/multierr*
sudo rm -rf /root/go/pkg/mod/cache/download/go.uber.org/multierr*

# Create a new go.mod file
cat > go.mod << 'EOF'
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

# Update dependencies
echo "Running go mod tidy..."
sudo go mod tidy

echo "Fix completed. The multierr package has been downgraded to v1.10.0 which is compatible with Go 1.18."
echo "You can now run your tests with: sudo go test -v ./pkg/blockchain -run TestBlockchain" 