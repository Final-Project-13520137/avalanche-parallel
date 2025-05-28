#!/bin/bash

echo "Applying Go 1.18 compatibility fixes..."

# Fix go.mod file
if [ -f "go.mod.fixed" ]; then
    echo "Fixing go.mod with compatible versions for Go 1.18"
    cp -f "go.mod.fixed" "go.mod"
    
    # Run go mod tidy to ensure dependencies are correct
    echo "Running go mod tidy to update dependencies"
    go mod tidy
fi

# Fix sorting.go file
if [ -f "default/utils/sorting.go" ]; then
    echo "Fixing default/utils/sorting.go with Go 1.18 compatible code"
    
    # Create a backup of the original file
    cp -f "default/utils/sorting.go" "default/utils/sorting.go.bak"
    
    # Replace problematic bytes.Compare in sorting.go
    sed -i 's/bytes.Compare(bytes\[i\], bytes\[j\]) < 0/bytes.Compare(byteSlices[i], byteSlices[j]) < 0/g' "default/utils/sorting.go"
    sed -i 's/func SortBytes(bytes \[\]\[\]byte)/func SortBytes(byteSlices [][]byte)/g' "default/utils/sorting.go"
    sed -i 's/func Sort2DBytes(bytes \[\]\[\]byte)/func Sort2DBytes(byteSlices [][]byte)/g' "default/utils/sorting.go"
    sed -i 's/bytes.Compare(s\[i\], s\[i+1\]) == 1/bytes.Compare(s[i], s[i+1]) > 0/g' "default/utils/sorting.go"
    sed -i 's/bytes.Compare(leftHash, rightHash) != -1/bytes.Compare(leftHash, rightHash) >= 0/g' "default/utils/sorting.go"
fi

# Fix set implementation
if [ -f "set_fixed.go" ]; then
    if [ -f "default/utils/set/set.go" ]; then
        echo "Fixing set.go implementation for Go 1.18 compatibility"
        cp -f "default/utils/set/set.go" "default/utils/set/set.go.bak"
        
        # Create a custom set implementation in the default directory
        cp -f "set_fixed.go" "default/utils/set/set_fixed.go"
    fi
fi

# Fix sampleable_set implementation
if [ -f "sampleable_set_fixed.go" ]; then
    if [ -f "default/utils/set/sampleable_set.go" ]; then
        echo "Fixing sampleable_set.go implementation for Go 1.18 compatibility"
        cp -f "default/utils/set/sampleable_set.go" "default/utils/set/sampleable_set.go.bak"
        
        # Create a custom sampleable_set implementation in the default directory
        cp -f "sampleable_set_fixed.go" "default/utils/set/sampleable_set_fixed.go"
    fi
fi

# Fix weighted heap implementation issues
if [ -f "weighted_heap_fixed.go" ]; then
    echo "Applying fixes for weighted heap implementation"
    cp -f "weighted_heap_fixed.go" "default/utils/sampler/weighted_heap_fixed.go"
fi

# Run go mod tidy again to make sure everything is correct
go mod tidy

echo "Go 1.18 compatibility fixes have been applied."
echo "You can now build and run the project with Go 1.18." 