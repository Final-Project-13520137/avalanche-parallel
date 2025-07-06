// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"math/rand"
)

// UniformReplacer allows for sampling over a uniform distribution with replacement
type UniformReplacer struct {
	rng *rand.Rand
	n   uint64
}

// NewUniformReplacer returns a new sampler
func NewUniformReplacer(rng *rand.Rand) *UniformReplacer {
	return &UniformReplacer{rng: rng}
}

// Initialize the sampler to support sampling values in [0, n)
func (s *UniformReplacer) Initialize(n uint64) {
	s.n = n
}

// Sample returns a random value in [0, n)
func (s *UniformReplacer) Sample() uint64 {
	return uint64(s.rng.Int63n(int64(s.n)))
}

// Sample returns a random value in [0, n) without replacement
func (s *UniformReplacer) SampleWithoutReplacement() uint64 {
	if s.n == 0 {
		return 0
	}
	return uint64(s.rng.Int63n(int64(s.n)))
}

// Reset the sampler to the original state
func (s *UniformReplacer) Reset() {
	s.n = 0
}
