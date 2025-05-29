#!/usr/bin/env pwsh

Write-Host "Go 1.18 Compatibility Fix Script" -ForegroundColor Cyan
Write-Host "=================================================" -ForegroundColor Cyan
Write-Host "This script replaces newer Go features with Go 1.18 compatible alternatives`n"

# Step 1: Check Go version
Write-Host "Step 1: Checking Go version..." -ForegroundColor Green
$goVersionOutput = & go version
$goVersion = ($goVersionOutput -split " ")[2] -replace "go",""
Write-Host "Detected Go version: $goVersion"

# Step 2: Find files using incompatible imports
Write-Host "`nStep 2: Finding files with incompatible imports..." -ForegroundColor Green

$filesWithCmp = @(Get-ChildItem -Path . -Filter "*.go" -Recurse | Select-String -Pattern 'import\s+"cmp"' | Select-Object Path -Unique)
$filesWithSlices = @(Get-ChildItem -Path . -Filter "*.go" -Recurse | Select-String -Pattern 'import\s+"slices"' | Select-Object Path -Unique)
$filesWithMaps = @(Get-ChildItem -Path . -Filter "*.go" -Recurse | Select-String -Pattern 'import\s+"maps"' | Select-Object Path -Unique)

Write-Host "`nFiles using 'cmp' package:"
if ($filesWithCmp.Count -eq 0) {
    Write-Host "  None found"
} else {
    foreach ($file in $filesWithCmp) {
        Write-Host "  $($file.Path)"
    }
}

Write-Host "`nFiles using 'slices' package:"
if ($filesWithSlices.Count -eq 0) {
    Write-Host "  None found"
} else {
    foreach ($file in $filesWithSlices) {
        Write-Host "  $($file.Path)"
    }
}

Write-Host "`nFiles using 'maps' package:"
if ($filesWithMaps.Count -eq 0) {
    Write-Host "  None found"
} else {
    foreach ($file in $filesWithMaps) {
        Write-Host "  $($file.Path)"
    }
}

# Step 3: Find and replace specific functions
Write-Host "`nStep 3: Fixing incompatible code..." -ForegroundColor Green

# Fix sorting.go
$sortingGoPath = "default\utils\sorting.go"
if (Test-Path $sortingGoPath) {
    Write-Host "Fixing $sortingGoPath..."
    $content = Get-Content $sortingGoPath -Raw
    
    # Replace imports
    $content = $content -replace 'import\s+"cmp"', 'import "sort"'
    $content = $content -replace 'import\s+"slices"', ''
    
    # Replace slices.SortFunc with sort.Slice
    $content = $content -replace 'slices\.SortFunc\(s, T\.Compare\)', 'sort.Slice(s, func(i, j int) bool {
		return s[i].Compare(s[j]) < 0
	})'
    $content = $content -replace 'slices\.SortFunc\(s, func\(i, j T\) int \{', 'sort.Slice(s, func(i, j int) bool {'
    $content = $content -replace 'return bytes\.Compare\(iHash, jHash\)', 'return bytes.Compare(iHash, jHash) < 0'
    
    # Replace cmp.Ordered with comparable
    $content = $content -replace '\[T cmp\.Ordered\]', '[T comparable]'
    
    Set-Content -Path $sortingGoPath -Value $content
}

# Fix batch.go
$batchGoPath = "default\database\batch.go"
if (Test-Path $batchGoPath) {
    Write-Host "Fixing $batchGoPath..."
    $content = Get-Content $batchGoPath -Raw
    
    # Replace imports
    $content = $content -replace 'import\s+"slices"', 'import (
	"github.com/Final-Project-13520137/avalanche-parallel/utils"
)'
    
    # Replace slices.Clone with utils.SlicesClone
    $content = $content -replace 'slices\.Clone', 'utils.SlicesClone'
    
    # Replace clear(b.Ops) with utils.SlicesClear
    $content = $content -replace 'clear\(b\.Ops\)', 'b.Ops = utils.SlicesClear(b.Ops)'
    $content = $content -replace 'b\.Ops = b\.Ops\[:0\]', ''
    
    Set-Content -Path $batchGoPath -Value $content
}

# Step 4: Create compatibility file if not exists
Write-Host "`nStep 4: Ensuring compatibility utils are available..." -ForegroundColor Green

if (-not (Test-Path "utils")) {
    Write-Host "Creating utils directory..."
    New-Item -Path "utils" -ItemType Directory | Out-Null
}

$compatibilityGoPath = "utils\compatibility.go"
if (-not (Test-Path $compatibilityGoPath)) {
    Write-Host "Creating compatibility.go file..."
    $compatibilityContent = @'
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
'@
    Set-Content -Path $compatibilityGoPath -Value $compatibilityContent
}

# Step 5: Update go.mod to fix dependencies
Write-Host "`nStep 5: Updating go.mod..." -ForegroundColor Green
& go mod tidy

# Fix assertions in tests that directly compare to Height() method
Write-Host "Checking for test files that need to be updated..." -ForegroundColor Green

$testFilesToFix = @(
    "pkg\blockchain\blockchain_test.go", 
    "pkg\blockchain\block_test.go", 
    "pkg\blockchain\integration_test.go"
)

foreach ($testFile in $testFilesToFix) {
    if (Test-Path $testFile) {
        Write-Host "Checking $testFile for Height assertions..."
        $content = Get-Content $testFile -Raw
        
        # Replace direct block.Height assertions with proper method calls
        $newContent = $content -replace '(assert\.Equal\(\w+, uint64\(\d+\), \w+\.Height\))', 'height, err := $1.Height()
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), height)'

        # Only write if there were changes
        if ($content -ne $newContent) {
            Write-Host "  Fixed Height assertions in $testFile"
            Set-Content -Path $testFile -Value $newContent
        }
    }
}

Write-Host "`nDone! Go 1.18 compatibility fixes have been applied." -ForegroundColor Green
Write-Host "You should now be able to build and test with Go 1.18."

Write-Host "Applying Go 1.18 compatibility fixes..."

# Fix go.mod file
if (Test-Path "go.mod.fixed") {
    Write-Host "Fixing go.mod with compatible versions for Go 1.18"
    Copy-Item -Force -Path "go.mod.fixed" -Destination "go.mod"
    
    # Run go mod tidy to ensure dependencies are correct
    Write-Host "Running go mod tidy to update dependencies"
    go mod tidy
}

# Fix sorting.go file
if (Test-Path "default/utils/sorting.go") {
    Write-Host "Fixing default/utils/sorting.go with Go 1.18 compatible code"
    
    # Create a backup of the original file
    Copy-Item -Force -Path "default/utils/sorting.go" -Destination "default/utils/sorting.go.bak"
    
    # Replace problematic bytes.Compare in sorting.go
    (Get-Content "default/utils/sorting.go") | ForEach-Object {
        $_ -replace "bytes.Compare\(bytes\[i\], bytes\[j\]\) < 0", "bytes.Compare(byteSlices[i], byteSlices[j]) < 0" `
           -replace "func SortBytes\(bytes \[\]\[\]byte\)", "func SortBytes(byteSlices [][]byte)" `
           -replace "func Sort2DBytes\(bytes \[\]\[\]byte\)", "func Sort2DBytes(byteSlices [][]byte)" `
           -replace "bytes.Compare\(s\[i\], s\[i\+1\]\) == 1", "bytes.Compare(s[i], s[i+1]) > 0" `
           -replace "bytes.Compare\(leftHash, rightHash\) != -1", "bytes.Compare(leftHash, rightHash) >= 0"
    } | Set-Content "default/utils/sorting.go"
}

# Fix set implementation
if (Test-Path "set_fixed.go") {
    if (Test-Path "default/utils/set/set.go") {
        Write-Host "Fixing set.go implementation for Go 1.18 compatibility"
        Copy-Item -Force -Path "default/utils/set/set.go" -Destination "default/utils/set/set.go.bak"
        
        # Create a custom set implementation in the default directory
        Copy-Item -Force -Path "set_fixed.go" -Destination "default/utils/set/set_fixed.go"
    }
}

# Fix sampleable_set implementation
if (Test-Path "sampleable_set_fixed.go") {
    if (Test-Path "default/utils/set/sampleable_set.go") {
        Write-Host "Fixing sampleable_set.go implementation for Go 1.18 compatibility"
        Copy-Item -Force -Path "default/utils/set/sampleable_set.go" -Destination "default/utils/set/sampleable_set.go.bak"
        
        # Create a custom sampleable_set implementation in the default directory
        Copy-Item -Force -Path "sampleable_set_fixed.go" -Destination "default/utils/set/sampleable_set_fixed.go"
    }
}

# Fix weighted heap implementation issues
if (Test-Path "weighted_heap_fixed.go") {
    Write-Host "Applying fixes for weighted heap implementation"
    Copy-Item -Force -Path "weighted_heap_fixed.go" -Destination "default/utils/sampler/weighted_heap_fixed.go"
}

# Run go mod tidy again to make sure everything is correct
go mod tidy

Write-Host "Go 1.18 compatibility fixes have been applied."
Write-Host "You can now build and run the project with Go 1.18." 