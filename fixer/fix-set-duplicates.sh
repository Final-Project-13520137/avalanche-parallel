#!/bin/bash

echo "Fixing set package duplicates..."

# Step 1: Back up original files
echo "Backing up original files..."
mkdir -p default/utils/set/backup
cp default/utils/set/set.go default/utils/set/backup/set.go.bak
cp default/utils/set/sampleable_set.go default/utils/set/backup/sampleable_set.go.bak

# Step 2: Remove original files
echo "Removing original files..."
rm default/utils/set/set.go
rm default/utils/set/sampleable_set.go

# Step 3: Copy fixed files
echo "Installing fixed implementations..."
cp set_fixed.go default/utils/set/set.go
cp sampleable_set_fixed.go default/utils/set/sampleable_set.go

echo "Set package duplicates fixed."
echo "Original files backed up in default/utils/set/backup/"

# Step 4: Run go mod tidy to update dependencies
echo "Running go mod tidy..."
go mod tidy

echo "Done! Try running tests now." 