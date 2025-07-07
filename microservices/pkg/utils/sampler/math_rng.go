// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"math/rand"
	"time"
)

// mathRNG is a wrapper around Go's math/rand package to provide a 
// pseudo-random number generator for the samplers.
type mathRNG struct {
	*rand.Rand
}

// seededRNG is a mathRNG with a specific seed.
type seededRNG struct {
	rng *mathRNG
}

// NewRNG returns a new mathRNG using the current time as a seed.
func NewRNG() *mathRNG {
	return &mathRNG{
		Rand: rand.New(rand.NewSource(time.Now().UnixNano())),
	}
}

// Seed sets the seed of the RNG
func (s *seededRNG) Seed(seed int64) {
	s.rng.Seed(seed)
}

// Defines common error values for the samplers
var (
	errNoEligibleSamples = New("no eligible samples found")
	errInvalidSampleSize = New("sample size must be <= population size")
	errOutOfRangeSample  = New("sample value out of range")
	errIndexOutOfRange   = New("index out of range")
	errElementRemoved    = New("element was already removed")
	errWeightOverflow    = New("weight overflowed")
	errUnknownWeightError = New("unknown weighted sampler error")
)

// Error defines a custom error format for this package
type Error string

// Error implements the error interface
func (e Error) Error() string {
	return "sampler error: " + string(e)
}

// New returns a new Error
func New(s string) error {
	return Error(s)
} 