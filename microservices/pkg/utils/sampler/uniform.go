// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"errors"
	"math"
)

// Uniform samples uniformly from the provided range
type Uniform interface {
	Initialize(sampleRange uint64)
	Sample() (uint64, error)
	Next() (uint64, error)
	Draw(samples []uint64) error
	Reset()
	SetSeed(int64)
}

var (
	errNoValidUniformSamplers = errors.New("no valid uniform samplers found")
)

// NewUniform returns a uniform sampler over the specified range
func NewUniform() Uniform {
	return &uniformSampler{
		rng:       NewRNG(),
		maxSize:   math.MaxInt32,
		generator: &uniformGenerator{},
	}
}

// uniformSampler implements the Uniform interface
type uniformSampler struct {
	rng       *mathRNG
	seededRNG *seededRNG
	maxSize   int
	generator *uniformGenerator
}

// Initialize implements the Uniform interface
func (s *uniformSampler) Initialize(sampleRange uint64) {
	s.generator.Initialize(sampleRange)
}

// Sample implements the Uniform interface
func (s *uniformSampler) Sample() (uint64, error) {
	return s.Next()
}

// Next implements the Uniform interface
func (s *uniformSampler) Next() (uint64, error) {
	return s.generator.Next(s.rng.Int63())
}

// Draw implements the Uniform interface
func (s *uniformSampler) Draw(samples []uint64) error {
	for i := range samples {
		value, err := s.Next()
		if err != nil {
			return err
		}
		samples[i] = value
	}
	return nil
}

// Reset implements the Uniform interface
func (s *uniformSampler) Reset() {
	// No need to reset for this implementation
}

// SetSeed implements the Uniform interface
func (s *uniformSampler) SetSeed(seed int64) {
	if s.seededRNG == nil {
		s.seededRNG = &seededRNG{rng: NewRNG()}
	}
	s.rng = s.seededRNG.rng
	s.seededRNG.Seed(seed)
}

// uniformGenerator generates uniform samples in [0, sampleRange)
type uniformGenerator struct {
	sampleRange uint64
}

// Initialize sets the sample range to [0, sampleRange)
func (g *uniformGenerator) Initialize(sampleRange uint64) {
	g.sampleRange = sampleRange
}

// Next returns a uniform sample in [0, sampleRange)
func (g *uniformGenerator) Next(value int64) (uint64, error) {
	if g.sampleRange == 0 {
		return 0, errNoEligibleSamples
	}

	max := (1 << 63) - ((1 << 63) % uint64(g.sampleRange))
	val := uint64(value)
	if val < max {
		return val % g.sampleRange, nil
	}
	return g.Next(int64(val - max))
} 