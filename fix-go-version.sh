#!/bin/bash

echo "Fixing Go version in go.mod..."

# Create a temporary file
TMP_FILE=$(mktemp)

# Fix the go.mod file:
# 1. Change go 1.23.9 to go 1.18
# 2. Remove the toolchain directive
cat go.mod | grep -v "toolchain" | sed 's/go 1.23.9/go 1.18/g' > "$TMP_FILE"

# Copy the fixed file back
cp "$TMP_FILE" go.mod

# Clean up
rm "$TMP_FILE"

# Run go mod tidy to update dependencies
echo "Running go mod tidy..."
go mod tidy

echo "Go version in go.mod has been fixed to 1.18" 