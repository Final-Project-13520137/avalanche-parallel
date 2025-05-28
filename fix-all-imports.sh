#!/bin/bash

echo -e "\e[1;36mComprehensive Import Path Fixer\e[0m"
echo -e "\e[1;36m===============================\e[0m"
echo -e "This script will fix all import paths in the project files.\n"

# Step 1: Fix the root Go module
echo -e "\e[1;32mStep 1: Fixing root go.mod file...\e[0m"
if grep -q "replace github.com/Final-Project-13520137/avalanche-parallel => ./default" go.mod; then
    echo -e "  - \e[0;90mUpdating replace directive...\e[0m"
    sed -i 's|replace github.com/Final-Project-13520137/avalanche-parallel => ./default|replace github.com/ava-labs/avalanchego => ./default|g' go.mod
elif grep -q "replace github.com/ava-labs/avalanchego => ./default" go.mod; then
    echo -e "  - \e[0;90mReplace directive already updated.\e[0m"
else
    echo -e "  - \e[0;90mAdding replace directive...\e[0m"
    echo -e "\nreplace github.com/ava-labs/avalanchego => ./default" >> go.mod
fi

# Also ensure the correct require statements exist
if ! grep -q "require github.com/ava-labs/avalanchego" go.mod; then
    echo -e "  - \e[0;90mAdding required dependency...\e[0m"
    # Add require statement if needed
    sed -i 's|require (|require (\n\tgithub.com/ava-labs/avalanchego v0.0.0|g' go.mod
fi

# Step 2: Update import paths in all Go files
echo -e "\n\e[1;32mStep 2: Updating import paths in Go files...\e[0m"

# Function to update import paths in a file
update_import_paths() {
    local file="$1"
    
    # Only process Go files
    if [[ ! "$file" =~ \.go$ ]]; then
        return
    fi
    
    echo -e "  - \e[0;90mProcessing: $file\e[0m"
    
    # Check if file exists and is readable
    if [ ! -r "$file" ]; then
        echo -e "    ! \e[0;31mError reading file\e[0m"
        return
    fi
    
    # Create a backup
    cp "$file" "${file}.bak"
    
    # Replace import paths
    sed -i 's|github.com/Final-Project-13520137/avalanche-parallel/default/|github.com/ava-labs/avalanchego/|g' "$file"
    
    # Check if file was modified
    if diff -q "$file" "${file}.bak" > /dev/null; then
        echo -e "    * \e[0;90mNo changes needed\e[0m"
        rm "${file}.bak"
    else
        echo -e "    * \e[0;33mUpdated import paths\e[0m"
        rm "${file}.bak"
    fi
}

# Process main project files
main_files=("test_blockchain.go" "simple_test.go" "logging.go")

for file in "${main_files[@]}"; do
    if [ -f "$file" ]; then
        update_import_paths "$file"
    fi
done

# Recursively process all Go files in pkg directory
echo -e "\n  - \e[1;32mProcessing files in pkg directory...\e[0m"
find ./pkg -name "*.go" -type f | while read -r file; do
    update_import_paths "$file"
done

# Step 3: Clear any cached modules to ensure fresh state
echo -e "\n\e[1;32mStep 3: Clearing module cache...\e[0m"
if go clean -modcache -cache; then
    echo -e "  * \e[0;90mModule cache cleared\e[0m"
else
    echo -e "  ! \e[0;31mError clearing module cache\e[0m"
fi

# Step 4: Update dependencies
echo -e "\n\e[1;32mStep 4: Updating dependencies...\e[0m"
if go mod tidy; then
    echo -e "  * \e[1;32mDependencies updated successfully\e[0m"
else
    echo -e "  ! \e[0;31mError updating dependencies\e[0m"
fi

# Final verification
echo -e "\n\e[1;36mVerifying imports in key files:\e[0m"
verification_files=("pkg/blockchain/block.go" "pkg/blockchain/transaction.go" "test_blockchain.go")

for file in "${verification_files[@]}"; do
    if [ -f "$file" ]; then
        echo -e "\n\e[1;33m$file:\e[0m"
        grep -A 10 "import" "$file"
    fi
done

echo -e "\n\e[1;32mImport path fixes completed!\e[0m"
echo -e "\e[1;36mTo verify, run: go mod tidy\e[0m" 