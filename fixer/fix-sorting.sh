#!/bin/bash
# Script to fix sorting.go comparison issue

echo -e "\e[1;32mFixing sorting.go bytes.Compare issue...\e[0m"

SORTING_FILE="default/utils/sorting.go"

if [ ! -f "$SORTING_FILE" ]; then
    echo -e "\e[1;31m  ! Error: sorting.go file not found at: $SORTING_FILE\e[0m"
    echo -e "\e[1;31m    Make sure you are running this script from the project root directory.\e[0m"
    exit 1
fi

echo -e "\e[1;36m  * Reading file: $SORTING_FILE\e[0m"

# Fix the SortByHash function
echo -e "\e[1;36m  * Fixing SortByHash function...\e[0m"
sed -i 's/return bytes.Compare(iHash, jHash) < 0.*< 0.*/return bytes.Compare(iHash, jHash) < 0/g' "$SORTING_FILE"

# Check if the fix was applied
if [ $? -eq 0 ]; then
    echo -e "\e[1;32m✓ sorting.go fixed successfully!\e[0m"
else
    echo -e "\e[1;31m  ! Error: Failed to fix sorting.go\e[0m"
    exit 1
fi 