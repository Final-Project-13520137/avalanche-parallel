// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"fmt"
)

// WeightedWithoutReplacement defines how to sample keys with weight, without replacement
type WeightedWithoutReplacement interface {
	Initialize(weights []uint64) error
	Sample(count int) ([]int, error)
}

// NewWeightedWithoutReplacement returns a new sampler
func NewWeightedWithoutReplacement() WeightedWithoutReplacement {
	return &weightedWithoutReplacementGeneric{
		u: NewUniform(),
		w: NewWeightedBest(),
	}
}

// NewDeterministicWeightedWithoutReplacement returns a new sampler that
// produces deterministic results
func NewDeterministicWeightedWithoutReplacement(seed int64) WeightedWithoutReplacement {
	uniform := NewUniform()
	uniform.SetSeed(seed)
	return &weightedWithoutReplacementGeneric{
		u: uniform,
		w: NewWeightedBest(),
	}
}

type weightedWithoutReplacementGeneric struct {
	u              Uniform
	w              Weighted
	samplingWeight uint64
	weights        []uint64
}

func (s *weightedWithoutReplacementGeneric) Initialize(weights []uint64) error {
	if len(weights) > 0 {
		s.weights = make([]uint64, len(weights))
		copy(s.weights, weights)
	} else {
		s.weights = nil
	}

	if err := s.w.Initialize(weights); err != nil {
		return err
	}

	var totalWeight uint64
	for _, weight := range weights {
		totalWeight += weight
	}
	s.samplingWeight = totalWeight
	if s.samplingWeight > 0 {
		s.u.Initialize(s.samplingWeight)
	}
	return nil
}

func (s *weightedWithoutReplacementGeneric) Sample(count int) ([]int, error) {
	if s.samplingWeight == 0 || count <= 0 {
		return nil, nil
	}

	if count > len(s.weights) {
		return nil, fmt.Errorf("attempt to sample %d elements from a %d element list", count, len(s.weights))
	}

	indices := make([]int, count)
	tempWeights := make([]uint64, len(s.weights))
	copy(tempWeights, s.weights)

	for i := 0; i < count; i++ {
		weight, err := s.u.Next()
		if err != nil {
			return nil, err
		}

		index, ok := s.w.Sample(weight)
		if !ok {
			return nil, errNoValidUniformSamplers
		}
		indices[i] = index

		if err := s.w.Initialize(tempWeights); err != nil {
			return nil, err
		}

		s.samplingWeight -= tempWeights[index]
		tempWeights[index] = 0
		if s.samplingWeight > 0 {
			s.u.Initialize(s.samplingWeight)
		}
	}
	return indices, nil
} 