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
