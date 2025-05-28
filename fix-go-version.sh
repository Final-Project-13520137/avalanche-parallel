#!/bin/bash

# Script to fix Go version compatibility issues in go.mod
echo "Go Version Compatibility Fixer"
echo "================================"

# Check installed Go version
GO_VERSION=$(go version | grep -oE 'go[0-9]+\.[0-9]+' | sed 's/go//')
echo "Detected Go version: $GO_VERSION"

# Get current go.mod version
if [ -f "go.mod" ]; then
    MOD_GO_VERSION=$(grep -oE 'go [0-9]+\.[0-9]+' go.mod | sed 's/go //')
    echo "Current go.mod Go version: $MOD_GO_VERSION"
    
    # Compare versions
    if (( $(echo "$MOD_GO_VERSION > $GO_VERSION" | bc -l) )); then
        echo "Updating go.mod to use Go $GO_VERSION instead of Go $MOD_GO_VERSION..."
        sed -i "s/go $MOD_GO_VERSION/go $GO_VERSION/" go.mod
        echo "✓ go.mod updated successfully"
        
        # Run go mod tidy to update dependencies
        echo "Running go mod tidy..."
        go mod tidy
        if [ $? -eq 0 ]; then
            echo "✓ Dependencies updated successfully"
        else
            echo "! There was an issue updating dependencies"
            echo "Please check the error messages above"
        fi
    else
        echo "No version update needed. go.mod already uses Go $MOD_GO_VERSION"
    fi
else
    echo "! go.mod file not found in the current directory"
    exit 1
fi

echo "Done!" 