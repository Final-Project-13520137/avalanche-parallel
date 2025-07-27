// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package set

import (
	"bytes"
	"encoding/json"
	"math/rand"

	"github.com/Final-Project-13520137/avalanche-parallel/pkg/utils/sampler"
	"github.com/ava-labs/avalanchego/utils"
	avajson "github.com/ava-labs/avalanchego/utils/json"
	"github.com/ava-labs/avalanchego/utils/wrappers"
)

// SampleableSet is a set that can be sampled from
type SampleableSet[T comparable] struct {
	indices  map[T]int
	elements []T
	rand     *rand.Rand
}

// NewSampleableSet returns a new sampleable set with initial capacity [size].
// More or less than [size] elements can be added to this set.
func NewSampleableSet[T comparable](size int) *SampleableSet[T] {
	if size < 0 {
		size = 16 // Default minimum size
	}
	return &SampleableSet[T]{
		indices:  make(map[T]int, size),
		elements: make([]T, 0, size),
		rand:     rand.New(rand.NewSource(1)), // Use deterministic source for testing
	}
}

// Add all the elements to this set.
// If the element is already in the set, nothing happens.
func (s *SampleableSet[T]) Add(elements ...T) {
	s.resize(2 * len(elements))
	for _, e := range elements {
		s.add(e)
	}
}

// Union adds all the elements from the provided set to this set.
func (s *SampleableSet[T]) Union(set *SampleableSet[T]) {
	s.resize(2 * set.Len())
	for _, e := range set.elements {
		s.add(e)
	}
}

// Difference removes all the elements in [set] from [s].
func (s *SampleableSet[T]) Difference(set *SampleableSet[T]) {
	for _, e := range set.elements {
		s.remove(e)
	}
}

// Contains returns true iff the set contains this element.
func (s *SampleableSet[T]) Contains(e T) bool {
	_, contains := s.indices[e]
	return contains
}

// Overlaps returns true if the intersection of the set is non-empty
func (s *SampleableSet[T]) Overlaps(big *SampleableSet[T]) bool {
	small := s
	if small.Len() > big.Len() {
		small, big = big, small
	}

	for _, e := range small.elements {
		if _, ok := big.indices[e]; ok {
			return true
		}
	}
	return false
}

// Len returns the number of elements in this set.
func (s *SampleableSet[T]) Len() int {
	return len(s.elements)
}

// Remove all the given elements from this set.
// If an element isn't in the set, it's ignored.
func (s *SampleableSet[T]) Remove(elements ...T) {
	for _, e := range elements {
		s.remove(e)
	}
}

// Clear empties this set
func (s *SampleableSet[T]) Clear() {
	s.indices = make(map[T]int, len(s.indices))
	s.elements = make([]T, 0, cap(s.elements))
}

// List converts this set into a list
func (s *SampleableSet[T]) List() []T {
	result := make([]T, len(s.elements))
	copy(result, s.elements)
	return result
}

// Equals returns true if the sets contain the same elements
func (s *SampleableSet[T]) Equals(other *SampleableSet[T]) bool {
	if len(s.indices) != len(other.indices) {
		return false
	}
	for k := range s.indices {
		if _, ok := other.indices[k]; !ok {
			return false
		}
	}
	return true
}

// Sample returns a random sample of at most [numToSample] elements from the set.
// If there are not enough elements in the set, all elements will be returned.
func (s *SampleableSet[T]) Sample(numToSample int) []T {
	if numToSample <= 0 {
		return nil
	}

	uniform := sampler.NewUniformReplacer(s.rand)
	uniform.Initialize(uint64(len(s.elements)))

	if numToSample > len(s.elements) {
		numToSample = len(s.elements)
	}
	indices := make([]uint64, numToSample)
	for i := range indices {
		indices[i] = uniform.Sample()
	}

	elements := make([]T, len(indices))
	for i, index := range indices {
		elements[i] = s.elements[index]
	}
	return elements
}

// SampleableSetJSON is used for marshaling/unmarshaling SampleableSet
type SampleableSetJSON[T comparable] struct {
	*SampleableSet[T]
}

// UnmarshalJSON unmarshals the JSON representation of a sampleable set
func (s *SampleableSetJSON[T]) UnmarshalJSON(b []byte) error {
	str := string(b)
	if str == avajson.Null {
		return nil
	}
	var elements []T
	if err := json.Unmarshal(b, &elements); err != nil {
		return err
	}
	if s.SampleableSet == nil {
		s.SampleableSet = NewSampleableSet[T](len(elements))
	} else {
		s.Clear()
	}
	s.Add(elements...)
	return nil
}

// MarshalJSON marshals a sampleable set to JSON
func (s *SampleableSetJSON[T]) MarshalJSON() ([]byte, error) {
	var (
		elementBytes = make([][]byte, len(s.elements))
		err          error
	)
	for i, e := range s.elements {
		elementBytes[i], err = json.Marshal(e)
		if err != nil {
			return nil, err
		}
	}
	// Sort for determinism - manual sort for Go 1.18 compatibility
	for i := 0; i < len(elementBytes); i++ {
		for j := i + 1; j < len(elementBytes); j++ {
			if bytes.Compare(elementBytes[i], elementBytes[j]) > 0 {
				elementBytes[i], elementBytes[j] = elementBytes[j], elementBytes[i]
			}
		}
	}

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

func (s *SampleableSet[T]) resize(size int) {
	if s.elements == nil {
		if size < 16 { // Default minimum size
			size = 16
		}
		s.indices = make(map[T]int, size)
		s.elements = make([]T, 0, size)
	}
}

func (s *SampleableSet[T]) add(e T) {
	_, ok := s.indices[e]
	if ok {
		return
	}

	s.indices[e] = len(s.elements)
	s.elements = append(s.elements, e)
}

func (s *SampleableSet[T]) remove(e T) {
	indexToRemove, ok := s.indices[e]
	if !ok {
		return
	}

	lastIndex := len(s.elements) - 1
	if indexToRemove != lastIndex {
		lastElement := s.elements[lastIndex]

		s.indices[lastElement] = indexToRemove
		s.elements[indexToRemove] = lastElement
	}

	delete(s.indices, e)
	s.elements[lastIndex] = utils.Zero[T]()
	s.elements = s.elements[:lastIndex]
}
