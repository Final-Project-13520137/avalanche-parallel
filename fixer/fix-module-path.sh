#!/bin/bash

# Script to fix module path issues in WSL/Docker environments
echo "Avalanche Parallel DAG - Module Path Fixer"
echo "========================================"
echo "This script will help you set up the correct path to the Avalanche code."

# Check Go version
go_version=$(go version | grep -o "go[0-9]\.[0-9]*" | sed 's/go//')
echo "Detected Go version: $go_version"

# Update go.mod to match available Go version
if [ -f "go.mod" ]; then
    mod_go_version=$(grep -o "go [0-9]\.[0-9]*" go.mod | sed 's/go //')
    echo "Current go.mod Go version: $mod_go_version"
    
    # Compare versions
    if [ $(echo "$mod_go_version > $go_version" | bc -l) -eq 1 ]; then
        echo "! go.mod requires Go $mod_go_version but your environment has Go $go_version"
        echo "Updating go.mod to use Go $go_version..."
        sed -i "s/go $mod_go_version/go $go_version/" go.mod
        echo "✓ Updated go.mod to use Go $go_version"
    fi
fi

# Check if default directory exists
if [ -d "./default" ]; then
    echo "✓ Found 'default' directory"
    
    # Check if it has the expected Avalanche code
    if [ -f "./default/go.mod" ]; then
        echo "✓ Avalanche code appears to be in place"
    else
        echo "! The 'default' directory exists but does not contain Avalanche code"
    fi
else
    echo "! The 'default' directory does not exist"
fi

# Ask user how to proceed
echo
echo "How would you like to proceed?"
echo "1. Specify the path to existing Avalanche code"
echo "2. Create a symbolic link to the Avalanche code"
echo "3. Exit without changes"
read -p "Choose an option (1-3): " option

case $option in
    1)
        # Update go.mod with a path
        read -p "Enter the absolute path to the Avalanche code: " avalanche_path
        
        # Check if the path exists
        if [ ! -d "$avalanche_path" ]; then
            echo "Error: The specified path does not exist."
            exit 1
        fi
        
        # Update go.mod
        export AVALANCHE_PARALLEL_PATH="$avalanche_path"
        echo "Updating go.mod to use path: $AVALANCHE_PARALLEL_PATH"
        go mod edit -replace github.com/Final-Project-13520137/avalanche-parallel=$AVALANCHE_PARALLEL_PATH
        echo "✓ Updated go.mod with the new path"
        ;;
        
    2)
        # Create a symbolic link
        read -p "Enter the absolute path to the Avalanche code: " avalanche_path
        
        # Check if the path exists
        if [ ! -d "$avalanche_path" ]; then
            echo "Error: The specified path does not exist."
            exit 1
        fi
        
        # Create link
        echo "Creating symbolic link from $avalanche_path to ./default"
        ln -s "$avalanche_path" ./default
        echo "✓ Created symbolic link"
        ;;
        
    3)
        echo "Exiting without changes"
        exit 0
        ;;
        
    *)
        echo "Invalid option selected"
        exit 1
        ;;
esac

# Verify the setup
echo
echo "Testing your setup..."
go mod tidy
if [ $? -eq 0 ]; then
    echo "✓ Module dependencies resolved successfully"
    echo "Your environment is now set up correctly!"
else
    echo "! There was an issue resolving dependencies"
    echo "Please check the error messages above and try again."
fi 