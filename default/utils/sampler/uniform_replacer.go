// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"errors"
	"math"
)

var (
	errOutOfRange      = errors.New("out of range")
	errInvalidArgument = errors.New("invalid argument")
)

type defaultMap map[int]int

func (m defaultMap) get(key, defaultVal int) int {
	if val, ok := m[key]; ok {
		return val
	}
	return defaultVal
}

// uniformReplacer allows for sampling over a uniform distribution without
// replacement.
//
// Sampling is performed by lazily performing an array mapping. By performing
// this lazily, initialization time can be significantly reduced.
//
// Initialization takes O(1) time
// Sampling is performed in O(1) time
type uniformReplacer struct {
	rng        *mathRNG
	seededRNG  *seededRNG
	length     int
	drawn      int
	replacement defaultMap
}

func (s *uniformReplacer) Initialize(length int) error {
	if length <= 0 {
		return errInvalidArgument
	}
	if length > math.MaxInt32 {
		return errInvalidArgument
	}

	s.length = length
	s.drawn = 0
	
	// For Go 1.18 compatibility, initialize an empty map instead of using clear
	s.replacement = make(defaultMap)
	return nil
}

func (s *uniformReplacer) Sample(count int) ([]int, error) {
	if count <= 0 {
		return nil, nil
	}
	if s.drawn+count > s.length {
		return nil, errOutOfRange
	}

	results := make([]int, count)
	for i := 0; i < count; i++ {
		ret, err := s.nextInt()
		if err != nil {
			return nil, err
		}
		results[i] = ret
	}
	return results, nil
}

func (s *uniformReplacer) nextInt() (int, error) {
	index := s.rng.Intn(s.length - s.drawn)
	ret := s.replacement.get(index, index)

	replacementIndex := s.length - s.drawn - 1
	replacementVal := s.replacement.get(replacementIndex, replacementIndex)

	s.replacement[index] = replacementVal
	s.drawn++
	return ret, nil
}

func (s *uniformReplacer) Reset() {
	// For Go 1.18 compatibility, create a new map rather than using clear
	s.replacement = make(defaultMap)
	s.drawn = 0
}

func (s *uniformReplacer) SetSeed(seed int64) {
	if s.seededRNG == nil {
		s.seededRNG = &seededRNG{rng: NewRNG()}
	}
	s.rng = s.seededRNG.rng
	s.seededRNG.Seed(seed)
} 