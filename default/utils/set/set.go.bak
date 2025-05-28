// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

import (
	"bytes"
	"encoding/json"

	"github.com/ava-labs/avalanchego/utils"
	"github.com/ava-labs/avalanchego/utils/maps"
	"github.com/ava-labs/avalanchego/utils/slices"
	"github.com/ava-labs/avalanchego/utils/wrappers"

	avajson "github.com/ava-labs/avalanchego/utils/json"
)

// The minimum capacity of a set
const minSetSize = 16

var _ json.Marshaler = (*Set[int])(nil)

// Set is an unordered collection of unique elements
type Set[T comparable] interface {
	// Add includes the specified elements in the set.
	// If they are already included, Add is a no-op for those elements.
	// Returns true if the set was modified.
	Add(element T) bool

	// Get returns the element in the set, if it exists.
	// The second return value is true if the element exists, and false otherwise.
	Get(element T) (T, bool)

	// Contains returns true if the element is in the set
	Contains(element T) bool

	// Remove removes the elements from the set.
	// If they are not in the set, Remove is a no-op for those elements.
	// Returns true if the set was modified.
	Remove(element T) bool

	// Len returns the number of elements in the set
	Len() int

	// List returns a slice of all elements in the set
	List() []T

	// ListExecutionOrder returns a slice of all elements in the set
	// based on their insertion order
	ListExecutionOrder() []T

	// Clear removes all elements from the set
	Clear()

	// Union adds all of the elements from the given set to this set
	Union(set Set[T])
}

// Empty returns an empty set
func Empty[T comparable]() Set[T] {
	return &set[T]{}
}

// Of returns a new set populated with the given elements
func Of[T comparable](elems ...T) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, len(elems)),
	}
	for _, elem := range elems {
		s.elements[elem] = struct{}{}
	}
	return s
}

// Equals returns true if the sets are equal
func Equals[T comparable](s1, s2 Set[T]) bool {
	if s1.Len() != s2.Len() {
		return false
	}
	for _, elem := range s1.List() {
		if !s2.Contains(elem) {
			return false
		}
	}
	return true
}

// Difference returns a new set with the elements of s1 that are not in s2
func Difference[T comparable](s1, s2 Set[T]) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, s1.Len()),
	}
	for _, elem := range s1.List() {
		if !s2.Contains(elem) {
			s.elements[elem] = struct{}{}
		}
	}
	return s
}

// Intersection returns a new set with the elements that are in both s1 and s2
func Intersection[T comparable](s1, s2 Set[T]) Set[T] {
	s := &set[T]{
		elements: make(map[T]struct{}, min(s1.Len(), s2.Len())),
	}
	for _, elem := range s1.List() {
		if s2.Contains(elem) {
			s.elements[elem] = struct{}{}
		}
	}
	return s
}

// min returns the smaller of a and b
func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

// set is a set implementation using maps
type set[T comparable] struct {
	elements map[T]struct{}
}

func (s *set[T]) Add(element T) bool {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, minSetSize)
	}
	if _, ok := s.elements[element]; ok {
		return false
	}
	s.elements[element] = struct{}{}
	return true
}

func (s *set[T]) Get(element T) (T, bool) {
	if s.elements == nil {
		return element, false
	}
	_, ok := s.elements[element]
	return element, ok
}

func (s *set[T]) Contains(element T) bool {
	if s.elements == nil {
		return false
	}
	_, ok := s.elements[element]
	return ok
}

func (s *set[T]) Remove(element T) bool {
	if s.elements == nil {
		return false
	}
	if _, ok := s.elements[element]; !ok {
		return false
	}
	delete(s.elements, element)
	return true
}

func (s *set[T]) Len() int {
	return len(s.elements)
}

func (s *set[T]) List() []T {
	elements := make([]T, 0, len(s.elements))
	for element := range s.elements {
		elements = append(elements, element)
	}
	return elements
}

func (s *set[T]) ListExecutionOrder() []T {
	return s.List()
}

func (s *set[T]) Clear() {
	s.elements = make(map[T]struct{})
}

func (s *set[T]) Union(other Set[T]) {
	if s.elements == nil {
		s.elements = make(map[T]struct{}, other.Len())
	}
	for _, element := range other.List() {
		s.elements[element] = struct{}{}
	}
}

// ContainsAny returns true if the intersection of the set is non-empty
func (s Set[T]) ContainsAny(set Set[T]) bool {
	smallElts, largeElts := s.elts, set.elts
	if len(smallElts) > len(largeElts) {
		smallElts, largeElts = largeElts, smallElts
	}

	for elt := range smallElts {
		if _, ok := largeElts[elt]; ok {
			return true
		}
	}
	return false
}

// ContainsAll returns true if the set contains all the elements of the provided
// set.
func (s Set[T]) ContainsAll(set Set[T]) bool {
	if len(s.elts) < len(set.elts) {
		return false
	}

	for elt := range set.elts {
		if _, ok := s.elts[elt]; !ok {
			return false
		}
	}
	return true
}

// Remove all the given elements from the set.
// If an element isn't in the set, it's ignored.
func (s *Set[T]) Remove(elts ...T) {
	if s.elts == nil {
		return
	}
	for _, elt := range elts {
		delete(s.elts, elt)
	}
}

// Clear empties this set
func (s *Set[T]) Clear() {
	s.elts = make(map[T]struct{})
}

// List converts this set into a list
func (s Set[T]) List() []T {
	result := make([]T, len(s.elts))
	i := 0
	for elt := range s.elts {
		result[i] = elt
		i++
	}
	return result
}

// Equals returns true if the sets contain the same elements
func (s Set[T]) Equals(other Set[T]) bool {
	return maps.Equal(s.elts, other.elts)
}

func (s *Set[T]) UnmarshalJSON(b []byte) error {
	str := string(b)
	if str == avajson.Null {
		return nil
	}
	var elements []T
	if err := json.Unmarshal(b, &elements); err != nil {
		return err
	}
	s.Clear()
	s.Add(elements...)
	return nil
}

func (s *Set[_]) MarshalJSON() ([]byte, error) {
	var (
		elementBytes = make([][]byte, len(s.elts))
		i            int
		err          error
	)
	for e := range s.elts {
		elementBytes[i], err = json.Marshal(e)
		if err != nil {
			return nil, err
		}
		i++
	}
	// Sort for determinism
	slices.Sort(elementBytes, func(a, b []byte) int {
		return bytes.Compare(a, b)
	})

	// Build the JSON
	var (
		jsonBuf = bytes.Buffer{}
		errs    = wrappers.Errs{}
	)
	_, err = jsonBuf.WriteString("[")
	errs.Add(err)
	for i, elt := range elementBytes {
		_, err := jsonBuf.Write(elt)
		errs.Add(err)
		if i != len(elementBytes)-1 {
			_, err := jsonBuf.WriteString(",")
			errs.Add(err)
		}
	}
	_, err = jsonBuf.WriteString("]")
	errs.Add(err)

	return jsonBuf.Bytes(), errs.Err
} 