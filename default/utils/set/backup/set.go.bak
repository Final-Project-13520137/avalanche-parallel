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
