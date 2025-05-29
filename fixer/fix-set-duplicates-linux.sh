#!/bin/bash

echo "===== Fixing Set Package Duplicates and Go Compatibility Issues ====="

# Step 1: Fix go.mod to use Go 1.18 and compatible multierr version
echo "Fixing go.mod for Go 1.18 compatibility..."
sed -i 's/go 1.23.9/go 1.18/g' go.mod
sed -i '/toolchain/d' go.mod
sed -i 's/go.uber.org\/multierr v1.11.0/go.uber.org\/multierr v1.6.0/g' go.mod

# Step 2: Create backup directory
echo "Creating backup directory..."
mkdir -p default/utils/set/backup

# Step 3: Back up original files if they exist
if [ -f "default/utils/set/set.go" ]; then
  echo "Backing up set.go..."
  cp default/utils/set/set.go default/utils/set/backup/set.go.bak
fi

if [ -f "default/utils/set/sampleable_set.go" ]; then
  echo "Backing up sampleable_set.go..."
  cp default/utils/set/sampleable_set.go default/utils/set/backup/sampleable_set.go.bak
fi

# Step 4: Remove ALL versions (both original and fixed) to avoid duplicates
echo "Removing existing files to prevent duplication..."
rm -f default/utils/set/set.go
rm -f default/utils/set/sampleable_set.go
rm -f default/utils/set/set_fixed.go
rm -f default/utils/set/sampleable_set_fixed.go

# Step 5: Copy fixed versions from root directory to set directory
echo "Installing fixed implementations..."
cp set_fixed.go default/utils/set/set.go
cp sampleable_set_fixed.go default/utils/set/sampleable_set.go

# Step 6: Fix any sorting issues
echo "Fixing sorting.go if needed..."
if [ -f "default/utils/sorting.go" ] && [ -f "sorting_fixed.go" ]; then
  cp sorting_fixed.go default/utils/sorting.go
fi

# Step 7: Fix the package name in sorting.go
echo "Fixing package name in sorting.go..."
if [ -f "default/utils/sorting.go" ]; then
  sed -i 's/package main/package utils/g' default/utils/sorting.go
fi

# Step 8: Run go mod tidy to update dependencies
echo "Running go mod tidy..."
go mod tidy

echo "===== All fixes applied! ====="
echo "Original files backed up in default/utils/set/backup/"
echo "Try running tests now."

# Create backup directory
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

# Check if there are still duplicates
echo "Fixed set package duplication issues."
echo "Try running tests now." 