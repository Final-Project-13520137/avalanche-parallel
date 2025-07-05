#!/bin/bash

# This script replaces imports in Go files

# Check if required commands are available
if ! command -v find &> /dev/null || ! command -v sed &> /dev/null; then
    echo "Required commands not found: find, sed"
    exit 1
fi

# Backup go.mod first
cp go.mod go.mod.backup

# Replace import paths in go files
echo "Replacing imports in Go files..."
find . -type f -name "*.go" -not -path "./vendor/*" -exec sed -i 's|"github.com/ava-labs/avalanchego/constraints"|"github.com/ava-labs/avalanchego/utils/cmp"|g' {} \;
find . -type f -name "*.go" -not -path "./vendor/*" -exec sed -i 's|"golang.org/x/exp/constraints"|"github.com/ava-labs/avalanchego/utils/cmp"|g' {} \;
find . -type f -name "*.go" -not -path "./vendor/*" -exec sed -i 's|"golang.org/x/exp/slices"|"github.com/ava-labs/avalanchego/utils/slices"|g' {} \;
find . -type f -name "*.go" -not -path "./vendor/*" -exec sed -i 's|"golang.org/x/exp/maps"|"github.com/ava-labs/avalanchego/utils/maps"|g' {} \;

echo "Imports replaced successfully"
echo "Original go.mod backed up to go.mod.backup" 