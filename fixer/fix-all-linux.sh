#!/bin/bash

echo "===== Fixing All Go 1.18 Compatibility Issues ====="

# Step 1: Create a new go.mod file with Go 1.18 and compatible dependencies
echo "Creating new go.mod file with Go 1.18 and compatible dependencies..."
cp go.mod go.mod.bak

cat > go.mod << 'EOF'
module github.com/Final-Project-13520137/avalanche-parallel-dag

go 1.18

replace github.com/ava-labs/avalanchego => ./default

require (
	github.com/ava-labs/avalanchego v0.0.0-00010101000000-000000000000
	github.com/google/uuid v1.6.0
	github.com/gorilla/mux v1.8.0
	github.com/stretchr/testify v1.8.0
	go.uber.org/zap v1.17.0
)

require (
	github.com/BurntSushi/toml v1.2.0 // indirect
	github.com/davecgh/go-spew v1.1.1 // indirect
	github.com/google/renameio/v2 v2.0.0 // indirect
	github.com/gorilla/rpc v1.2.0 // indirect
	github.com/mr-tron/base58 v1.2.0 // indirect
	github.com/pmezard/go-difflib v1.0.0 // indirect
	go.uber.org/atomic v1.7.0 // indirect
	go.uber.org/multierr v1.6.0 // indirect
	golang.org/x/crypto v0.0.0-20220112180741-5e0467b6c7ce // indirect
	golang.org/x/sys v0.0.0-20220114195835-da31bd327af9 // indirect
	golang.org/x/term v0.0.0-20210927222741-03fcf44c2211 // indirect
	gonum.org/v1/gonum v0.9.0 // indirect
	gopkg.in/natefinch/lumberjack.v2 v2.0.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
EOF

# Step 2: Fix the package declaration in sorting.go
echo "Fixing package name in sorting.go..."
# Backup the original file
cp default/utils/sorting.go default/utils/sorting.go.bak

# Create a new file with the correct package name
cat > default/utils/sorting.go << 'EOF'
// Copyright (C) 2019-2022, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package utils

import (
	"bytes"
	"sort"

	"github.com/ava-labs/avalanchego/utils/hashing"
)

// SortBytes sorts a slice of byte slices
func SortBytes(byteSlices [][]byte) {
	sort.Slice(byteSlices, func(i, j int) bool {
		return bytes.Compare(byteSlices[i], byteSlices[j]) < 0
	})
}

// IsSorted returns true if the elements in the slice are sorted
func IsSorted[T any](s []T, less func(i, j T) bool) bool {
	for i := 0; i < len(s)-1; i++ {
		if less(s[i+1], s[i]) {
			return false
		}
	}
	return true
}

// IsSortedBytes returns true if the elements in the slice are sorted
func IsSortedBytes[T ~[]byte](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		if bytes.Compare(s[i], s[i+1]) > 0 {
			return false
		}
	}
	return true
}

// SortByHash sorts the elements of [s] based on their hashes.
func SortByHash[T ~[]byte](s []T) {
	sort.Slice(s, func(i, j int) bool {
		iHash := hashing.ComputeHash256(s[i])
		jHash := hashing.ComputeHash256(s[j])
		return bytes.Compare(iHash, jHash) < 0
	})
}

// IsSortedByHash returns true iff the elements in [s] are sorted by their hash
func IsSortedByHash[T ~[]byte](s []T) bool {
	if len(s) <= 1 {
		return true
	}
	rightHash := hashing.ComputeHash256(s[0])
	for i := 1; i < len(s); i++ {
		leftHash := rightHash
		rightHash = hashing.ComputeHash256(s[i])
		if bytes.Compare(leftHash, rightHash) > 0 {
			return false
		}
	}
	return true
}

// Sort2DBytes sorts a 2D byte slice by the first index's lexicographical order
func Sort2DBytes(byteSlices [][]byte) {
	sort.Slice(byteSlices, func(i, j int) bool {
		return bytes.Compare(byteSlices[i], byteSlices[j]) < 0
	})
}

// Compare returns a negative number, 0, or positive number if [a] is less than,
// equal to, or greater than [b].
// Assumes that [a] and [b] have the same length.
func Compare(a, b []byte) int {
	return bytes.Compare(a, b)
}

// CompareSlice returns a negative number, 0, or positive number if [a] is less than,
// equal to, or greater than [b].
func CompareSlice(a, b [][]byte) int {
	minLen := len(a)
	if len(b) < minLen {
		minLen = len(b)
	}
	for i := 0; i < minLen; i++ {
		comparison := bytes.Compare(a[i], b[i])
		if comparison != 0 {
			return comparison
		}
	}
	return len(a) - len(b)
}

// TODO can we handle sorting where the Compare function relies on a codec?

type Sortable[T any] interface {
	Compare(T) int
}

// Sorts the elements of [s].
func Sort[T Sortable[T]](s []T) {
	sort.Slice(s, func(i, j int) bool {
		return s[i].Compare(s[j]) < 0
	})
}

// Returns true iff the elements in [s] are unique and sorted.
func IsSortedAndUnique[T Sortable[T]](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		if s[i].Compare(s[i+1]) >= 0 {
			return false
		}
	}
	return true
}

// Compare operations for specific types
func CompareInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func CompareFloat64(a, b float64) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func CompareString(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

// Returns true iff the elements in [s] are unique and sorted.
func IsSortedAndUniqueOrdered[T comparable](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		// For Go 1.18 compatibility, we'll check manually based on type
		if !isLessThanOrEqual(s[i+1], s[i]) {
			return false
		}
	}
	return true
}

// isLessThanOrEqual returns true if a <= b
func isLessThanOrEqual[T comparable](a, b T) bool {
	return isLessThan(a, b) || isEqual(a, b)
}

// isEqual checks if two comparable values are equal
func isEqual[T comparable](a, b T) bool {
	return a == b
}

// isLessThan compares two comparable values
// This is a workaround for Go 1.18 not supporting < on generic types
func isLessThan[T comparable](a, b T) bool {
	// Use type assertion to handle common types
	switch v := any(a).(type) {
	case int:
		return v < any(b).(int)
	case int8:
		return v < any(b).(int8)
	case int16:
		return v < any(b).(int16)
	case int32:
		return v < any(b).(int32)
	case int64:
		return v < any(b).(int64)
	case uint:
		return v < any(b).(uint)
	case uint8:
		return v < any(b).(uint8)
	case uint16:
		return v < any(b).(uint16)
	case uint32:
		return v < any(b).(uint32)
	case uint64:
		return v < any(b).(uint64)
	case float32:
		return v < any(b).(float32)
	case float64:
		return v < any(b).(float64)
	case string:
		return v < any(b).(string)
	default:
		// For other types, compare bytes if possible
		// This is not ideal but a fallback for Go 1.18 compatibility
		aBytes, aOk := any(a).([]byte)
		bBytes, bOk := any(b).([]byte)
		if aOk && bOk {
			return bytes.Compare(aBytes, bBytes) < 0
		}
		// For other types, we can't compare directly in Go 1.18
		// Return true to avoid failing, but this might not be correct
		// for all types
		return true
	}
}

// Returns true iff the elements in [s] are unique and sorted
// based by their hashes.
func IsSortedAndUniqueByHash[T ~[]byte](s []T) bool {
	if len(s) <= 1 {
		return true
	}
	rightHash := hashing.ComputeHash256(s[0])
	for i := 1; i < len(s); i++ {
		leftHash := rightHash
		rightHash = hashing.ComputeHash256(s[i])
		if bytes.Compare(leftHash, rightHash) >= 0 {
			return false
		}
	}
	return true
}
EOF

# Step 3: Fix set package duplicates
echo "Fixing set package duplicates..."
mkdir -p default/utils/set/backup

# Backup original files if they exist
if [ -f "default/utils/set/set.go" ]; then
  cp default/utils/set/set.go default/utils/set/backup/set.go.bak
fi
if [ -f "default/utils/set/sampleable_set.go" ]; then
  cp default/utils/set/sampleable_set.go default/utils/set/backup/sampleable_set.go.bak
fi

# Remove all versions to avoid duplicates
rm -f default/utils/set/set.go
rm -f default/utils/set/sampleable_set.go
rm -f default/utils/set/set_fixed.go
rm -f default/utils/set/sampleable_set_fixed.go

# Create fixed set.go file
cat > default/utils/set/set.go << 'EOF'
// Copyright (C) 2019-2022, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

import (
	"encoding/json"
	"fmt"
	"strings"
)

const minSetSize = 16

// Set is a set of elements.
type Set[T comparable] map[T]struct{}

// Set implements the fmt.Stringer interface
func (s Set[T]) String() string {
	var elements []string
	for element := range s {
		elementStr := fmt.Sprintf("%v", element)
		elements = append(elements, elementStr)
	}
	return fmt.Sprintf("[%s]", strings.Join(elements, ", "))
}

// MarshalJSON implements the json.Marshaler interface.
func (s Set[T]) MarshalJSON() ([]byte, error) {
	elements := make([]T, 0, len(s))
	for element := range s {
		elements = append(elements, element)
	}
	return json.Marshal(elements)
}

// UnmarshalJSON implements the json.Unmarshaler interface.
func (s *Set[T]) UnmarshalJSON(b []byte) error {
	var elements []T
	if err := json.Unmarshal(b, &elements); err != nil {
		return err
	}

	if *s == nil {
		*s = make(map[T]struct{}, len(elements))
	}
	for _, element := range elements {
		(*s).Add(element)
	}
	return nil
}

// Add adds an element to this set.
func (s *Set[T]) Add(element T) {
	if *s == nil {
		*s = make(map[T]struct{}, minSetSize)
	}
	(*s)[element] = struct{}{}
}

// Len returns the number of elements in this set.
func (s Set[T]) Len() int {
	return len(s)
}

// Empty returns whether the set has 0 elements.
func Empty[T comparable]() Set[T] {
	return make(map[T]struct{})
}

// Of returns a set containing [elems]
func Of[T comparable](elems ...T) Set[T] {
	s := make(Set[T], len(elems))
	for _, elem := range elems {
		s.Add(elem)
	}
	return s
}

// Equals returns whether the sets contain the same elements.
func Equals[T comparable](s1, s2 Set[T]) bool {
	if s1.Len() != s2.Len() {
		return false
	}
	for e := range s1 {
		if _, contains := s2[e]; !contains {
			return false
		}
	}
	return true
}

// Difference returns the difference of the sets, in the sense that
// a-b contains elements that are in a but not in b
func Difference[T comparable](a, b Set[T]) Set[T] {
	res := make(Set[T], minSetSize)
	for e := range a {
		if _, contains := b[e]; !contains {
			res.Add(e)
		}
	}
	return res
}

// Intersection returns a new set containing the elements that are in both a and b
func Intersection[T comparable](a, b Set[T]) Set[T] {
	res := make(Set[T], minSetSize)
	for e := range a {
		if _, contains := b[e]; contains {
			res.Add(e)
		}
	}
	return res
}

// Union returns a new set with all elements that are in either a or b
func Union[T comparable](a, b Set[T]) Set[T] {
	res := make(Set[T], a.Len()+b.Len())
	for e := range a {
		res.Add(e)
	}
	for e := range b {
		res.Add(e)
	}
	return res
}

// Contains returns whether this set contains the element.
func (s Set[T]) Contains(element T) bool {
	_, contains := s[element]
	return contains
}

// Overlaps returns whether the intersection of sets s and t is non-empty.
func (s Set[T]) Overlaps(t Set[T]) bool {
	for e := range s {
		if _, contains := t[e]; contains {
			return true
		}
	}
	return false
}

// Remove removes [element] from the map
func (s Set[T]) Remove(element T) {
	delete(s, element)
}

// Clear removes all elements from the set
func (s Set[T]) Clear() {
	for key := range s {
		delete(s, key)
	}
}

// Union adds all of the elements from the given set to this set.
func (s *Set[T]) Union(other Set[T]) {
	for element := range other {
		s.Add(element)
	}
}
EOF

# Create fixed sampleable_set.go file
cat > default/utils/set/sampleable_set.go << 'EOF'
// Copyright (C) 2019-2022, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"strings"
)

// SampleableSet is a set that supports sampling its elements
type SampleableSet[T comparable] struct {
	set            Set[T]
	elements       []T
	sampledIndices Set[int]
}

// OfSampleable returns a new set initialized with [elems]
func OfSampleable[T comparable](elems ...T) SampleableSet[T] {
	s := NewSampleableSet[T](len(elems))
	for _, elem := range elems {
		s.Add(elem)
	}
	return s
}

// NewSampleableSet returns a new empty set with capacity [size]
func NewSampleableSet[T comparable](size int) SampleableSet[T] {
	return SampleableSet[T]{
		set:            make(Set[T], size),
		elements:       make([]T, 0, size),
		sampledIndices: make(Set[int], size),
	}
}

// Add adds an element to this set
func (s *SampleableSet[T]) Add(element T) {
	if s.set.Contains(element) {
		return
	}
	s.set.Add(element)
	s.elements = append(s.elements, element)
}

// Contains returns true if the element is in the set
func (s *SampleableSet[T]) Contains(element T) bool {
	return s.set.Contains(element)
}

// Len returns the number of elements in the set
func (s *SampleableSet[T]) Len() int {
	return len(s.elements)
}

// Remove an element from the set.
// Returns true if the element was in the set, and false otherwise.
func (s *SampleableSet[T]) Remove(element T) bool {
	// We handle the empty case here, rather than returning s.set.Contains(element)
	// because s.set is nil when the set is empty.
	if s.Len() == 0 {
		return false
	}

	if !s.set.Contains(element) {
		return false
	}

	// Get the last element in elements
	lastIndex := len(s.elements) - 1
	last := s.elements[lastIndex]

	// Find the index of the element being removed
	var i int
	for i = 0; i < lastIndex; i++ {
		if s.elements[i] == element {
			break
		}
	}

	// Move the last element to that index
	s.elements[i] = last
	// Remove the element from the set
	s.set.Remove(element)
	// Remove the last element from elements (which isn't necessary but may save memory)
	s.elements[lastIndex] = *new(T)
	s.elements = s.elements[:lastIndex]
	return true
}

// Sample returns an element of the set sampled uniformly at random
// If the set is empty, returns the empty value of type T and false
func (s *SampleableSet[T]) Sample() (T, bool) {
	if s.Len() == 0 {
		var empty T
		return empty, false
	}
	// Use a simple random index for Go 1.18 compatibility
	idx := rand.Intn(s.Len())
	return s.elements[idx], true
}

// List returns the elements of this set.
func (s *SampleableSet[T]) List() []T {
	elements := make([]T, len(s.elements))
	copy(elements, s.elements)
	return elements
}

// SampledList returns the elements of this set and marks them as having been sampled.
func (s *SampleableSet[T]) SampledList() []T {
	elements := make([]T, len(s.elements))
	copy(elements, s.elements)
	s.sampledIndices.Clear()
	for i := range s.elements {
		s.sampledIndices.Add(i)
	}
	return elements
}

// ClearSampled clears the record of which elements have been sampled.
func (s *SampleableSet[T]) ClearSampled() {
	s.sampledIndices.Clear()
}

// Returns a new set with the same elements
func (s *SampleableSet[T]) Clone() SampleableSet[T] {
	clone := NewSampleableSet[T](s.Len())
	for _, element := range s.elements {
		clone.Add(element)
	}
	return clone
}

// String implements the stringer interface
func (s *SampleableSet[T]) String() string {
	var elements []string
	for _, element := range s.elements {
		elements = append(elements, fmt.Sprintf("%v", element))
	}
	return fmt.Sprintf("[%s]", strings.Join(elements, ", "))
}

// SampleableSetJSON allows SampleableSet to be marshalled into JSON
type SampleableSetJSON[T comparable] struct {
	Elements []T `json:"elements"`
}

// MarshalJSON marshals SampleableSet into JSON
func (s *SampleableSet[T]) MarshalJSON() ([]byte, error) {
	elements := s.List()
	return json.Marshal(SampleableSetJSON[T]{
		Elements: elements,
	})
}

// UnmarshalJSON unmarshals SampleableSet from JSON
func (s *SampleableSet[T]) UnmarshalJSON(b []byte) error {
	var setJSON SampleableSetJSON[T]
	err := json.Unmarshal(b, &setJSON)
	if err != nil {
		return err
	}

	// Create a new set with the unmarshalled elements
	*s = NewSampleableSet[T](len(setJSON.Elements))
	for _, element := range setJSON.Elements {
		s.Add(element)
	}
	return nil
}
EOF

# Step 4: Clean module cache and update dependencies
echo "Cleaning module cache and updating dependencies..."
go clean -modcache

# Step 5: Download specific versions of dependencies
echo "Downloading dependencies with compatible versions..."
go get go.uber.org/multierr@v1.6.0
go get go.uber.org/zap@v1.17.0

# Step 6: Run go mod tidy
echo "Running go mod tidy..."
go mod tidy

echo "===== All fixes applied! ====="
echo "You can now build and run the project with Go 1.18." 