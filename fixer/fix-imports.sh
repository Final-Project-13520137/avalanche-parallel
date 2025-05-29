#!/bin/bash

echo "Module Path Mismatch Fixer"
echo "=========================="
echo "This script fixes import path mismatches between the local code and Avalanche dependencies."

# Check if pkg directory exists
if [ ! -d "./pkg" ]; then
    echo "! Error: pkg directory not found. Make sure you're in the root of the project."
    exit 1
fi

echo "Updating import paths in the code..."

# Function to update imports in a file
update_imports() {
    local file=$1
    echo "  Processing: $file"
    
    # Replace all occurrences of the problematic import path with the correct one
    sed -i 's|github.com/Final-Project-13520137/avalanche-parallel/default/|github.com/ava-labs/avalanchego/|g' "$file"
}

# Find all Go files in the pkg directory and update imports
find ./pkg -name "*.go" -type f | while read -r file; do
    update_imports "$file"
done

# Update the go.mod file to use the correct import path for the replacement
echo "Updating go.mod file..."
sed -i 's|replace github.com/Final-Project-13520137/avalanche-parallel => ./default|replace github.com/ava-labs/avalanchego => ./default|g' go.mod

# Update the import statements in the code to use the correct path
echo "Updating import statements in the main code files..."
if [ -f "simple_test.go" ]; then
    update_imports "simple_test.go"
fi

if [ -f "test_blockchain.go" ]; then
    update_imports "test_blockchain.go"
fi

if [ -f "logging.go" ]; then
    update_imports "logging.go"
fi

# Find any other Go files in the root directory
find . -maxdepth 1 -name "*.go" -type f | while read -r file; do
    update_imports "$file"
done

echo "Running go mod tidy to update dependencies..."
go mod tidy

if [ $? -eq 0 ]; then
    echo "✓ Import paths updated successfully!"
    echo "Your code should now be able to properly import the Avalanche dependencies."
else
    echo "! There was an issue updating the dependencies."
    echo "Please check the error messages above."
fi 