#!/bin/bash

echo -e "\e[1;36mGo Version Fix Script\e[0m"
echo -e "\e[1;36m====================\e[0m"
echo -e "This script fixes Go version and toolchain issues in go.mod\n"

# Backup original go.mod
echo -e "\e[1;33mCreating backup of go.mod...\e[0m"
cp go.mod go.mod.bak

# Fix the go version and remove toolchain directive
echo -e "\e[1;32mFixing go.mod file...\e[0m"

# Replace invalid Go version with 1.18
sed -i 's/go 1.23.9/go 1.18/g' go.mod

# Remove toolchain directive
sed -i '/toolchain/d' go.mod

# Run go mod tidy to clean up dependencies
echo -e "\n\e[1;32mRunning go mod tidy...\e[0m"
if go mod tidy; then
    echo -e "\n\e[1;32m✅ Success! Go version fixed.\e[0m"
else
    echo -e "\n\e[1;33m⚠️ go mod tidy completed with warnings. Check the output above.\e[0m"
fi

echo -e "\n\e[1;36mTo restore the original go.mod, run: cp go.mod.bak go.mod\e[0m" 