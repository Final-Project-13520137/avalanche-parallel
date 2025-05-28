#!/bin/bash

echo -e "\e[1;36mGo 1.18 Compatibility Fix Script\e[0m"
echo -e "\e[1;36m=================================================\e[0m"
echo -e "This script replaces newer Go features with Go 1.18 compatible alternatives\n"

# Step 1: Check Go version
echo -e "\e[1;32mStep 1: Checking Go version...\e[0m"
GO_VERSION=$(go version | awk '{print $3}' | sed 's/go//')
echo "Detected Go version: $GO_VERSION"

# Step 2: Find files using incompatible imports
echo -e "\n\e[1;32mStep 2: Finding files with incompatible imports...\e[0m"
FILES_WITH_CMP=$(grep -r "import.*\"cmp\"" --include="*.go" . || echo "")
FILES_WITH_SLICES=$(grep -r "import.*\"slices\"" --include="*.go" . || echo "")
FILES_WITH_MAPS=$(grep -r "import.*\"maps\"" --include="*.go" . || echo "")

echo -e "\nFiles using 'cmp' package:"
if [ -z "$FILES_WITH_CMP" ]; then
  echo "  None found"
else
  echo "$FILES_WITH_CMP"
fi

echo -e "\nFiles using 'slices' package:"
if [ -z "$FILES_WITH_SLICES" ]; then
  echo "  None found"
else
  echo "$FILES_WITH_SLICES"
fi

echo -e "\nFiles using 'maps' package:"
if [ -z "$FILES_WITH_MAPS" ]; then
  echo "  None found"
else
  echo "$FILES_WITH_MAPS"
fi

# Step 3: Find and replace specific functions
echo -e "\n\e[1;32mStep 3: Fixing incompatible code...\e[0m"

# Fix sorting.go
if [ -f "default/utils/sorting.go" ]; then
  echo "Fixing default/utils/sorting.go..."
  sed -i 's/import "cmp"/import "sort"/' default/utils/sorting.go
  sed -i 's/import "slices"//' default/utils/sorting.go
  sed -i 's/slices.SortFunc(s, T.Compare)/sort.Slice(s, func(i, j int) bool {\n\t\treturn s[i].Compare(s[j]) < 0\n\t})/' default/utils/sorting.go
  sed -i 's/slices.SortFunc(s, func(i, j T) int {/sort.Slice(s, func(i, j int) bool {/' default/utils/sorting.go
  sed -i 's/return bytes.Compare(iHash, jHash)/return bytes.Compare(iHash, jHash) < 0/' default/utils/sorting.go
  sed -i 's/\[T cmp.Ordered\]/[T comparable]/' default/utils/sorting.go
fi

# Fix batch.go
if [ -f "default/database/batch.go" ]; then
  echo "Fixing default/database/batch.go..."
  sed -i 's/import "slices"/import "github.com\/Final-Project-13520137\/avalanche-parallel\/utils"/' default/database/batch.go
  sed -i 's/slices.Clone/utils.SlicesClone/g' default/database/batch.go
  sed -i 's/clear(b.Ops)/b.Ops = utils.SlicesClear(b.Ops)/' default/database/batch.go
  sed -i '/b.Ops = b.Ops\[:0\]/d' default/database/batch.go
fi

# Step 4: Create compatibility file if not exists
echo -e "\n\e[1;32mStep 4: Ensuring compatibility utils are available...\e[0m"

if [ ! -d "utils" ]; then
  echo "Creating utils directory..."
  mkdir -p utils
fi

if [ ! -f "utils/compatibility.go" ]; then
  echo "Creating compatibility.go file..."
  cat > utils/compatibility.go << 'EOF'
// compatibility.go provides compatibility functions for newer Go packages
// that are not available in Go 1.18

package utils

import (
	"bytes"
	"sort"
)

// SlicesSort provides a compatibility function for slices.Sort
func SlicesSort[T any](s []T, less func(a, b T) bool) {
	sort.Slice(s, func(i, j int) bool {
		return less(s[i], s[j])
	})
}

// SlicesSortFunc provides a compatibility function for slices.SortFunc
func SlicesSortFunc[T any](s []T, cmp func(a, b T) int) {
	sort.Slice(s, func(i, j int) bool {
		return cmp(s[i], s[j]) < 0
	})
}

// SlicesClone provides a compatibility function for slices.Clone
func SlicesClone[T any](s []T) []T {
	if s == nil {
		return nil
	}
	result := make([]T, len(s))
	copy(result, s)
	return result
}

// MapsClear provides a compatibility function for maps.Clear
func MapsClear[M ~map[K]V, K comparable, V any](m M) {
	for k := range m {
		delete(m, k)
	}
}

// Compare provides a compatibility function for cmp.Compare
func Compare[T comparable](a, b T) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

// SlicesClear provides a compatibility function for clear() on slices
func SlicesClear[T any](s []T) []T {
	return s[:0]
}

// CompareBytes provides a compatibility function for comparing byte slices
func CompareBytes(a, b []byte) int {
	return bytes.Compare(a, b)
}

// SlicesContains checks if a slice contains a specific element
func SlicesContains[T comparable](s []T, e T) bool {
	for _, v := range s {
		if v == e {
			return true
		}
	}
	return false
}

// SlicesEqual checks if two slices are equal
func SlicesEqual[T comparable](a, b []T) bool {
	if len(a) != len(b) {
		return false
	}
	for i, v := range a {
		if v != b[i] {
			return false
		}
	}
	return true
}

// SlicesIndex returns the index of the first occurrence of e in s, or -1 if not found
func SlicesIndex[T comparable](s []T, e T) int {
	for i, v := range s {
		if v == e {
			return i
		}
	}
	return -1
}

// MapKeys returns the keys of a map in a slice
func MapKeys[M ~map[K]V, K comparable, V any](m M) []K {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// MapValues returns the values of a map in a slice
func MapValues[M ~map[K]V, K comparable, V any](m M) []V {
	values := make([]V, 0, len(m))
	for _, v := range m {
		values = append(values, v)
	}
	return values
}
EOF
fi

# Step 5: Update go.mod to fix dependencies
echo -e "\n\e[1;32mStep 5: Updating go.mod...\e[0m"
go mod tidy

# Fix assertions in tests that directly compare to Height() method
echo -e "\n\e[1;32mChecking for test files that need to be updated...\e[0m"

TEST_FILES_TO_FIX=(
  "pkg/blockchain/blockchain_test.go"
  "pkg/blockchain/block_test.go"
  "pkg/blockchain/integration_test.go"
)

for testFile in "${TEST_FILES_TO_FIX[@]}"; do
  if [ -f "$testFile" ]; then
    echo "Checking $testFile for Height assertions..."
    
    # Create a temporary file
    temp_file=$(mktemp)
    
    # Use sed to replace direct height assertions with proper method calls
    sed -E 's/(assert\.Equal\(t, uint64\([0-9]+\), [a-zA-Z0-9]+\.Height\))/height, err := \1.Height()\n\tassert.NoError(t, err)\n\tassert.Equal(t, uint64(1), height)/' "$testFile" > "$temp_file"
    
    # Check if file was modified
    if ! cmp -s "$testFile" "$temp_file"; then
      echo "  Fixed Height assertions in $testFile"
      mv "$temp_file" "$testFile"
    else
      rm "$temp_file"
    fi
  fi
done

echo -e "\n\e[1;32mDone! Go 1.18 compatibility fixes have been applied.\e[0m"
echo -e "You should now be able to build and test with Go 1.18." 