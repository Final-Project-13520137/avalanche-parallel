// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

// Weighted defines how to sample based on weights
type Weighted interface {
	Initialize(weights []uint64) error
	Sample(sampleValue uint64) (int, bool)
}

// NewWeightedBest returns the best weighted implementation for the given weights
func NewWeightedBest() Weighted {
	return &weightedBest{
		sampler: &weightedHeapSampler{},
	}
}

// weightedBest implements the Weighted interface using the best available implementation
type weightedBest struct {
	sampler Weighted
}

func (s *weightedBest) Initialize(weights []uint64) error {
	return s.sampler.Initialize(weights)
}

func (s *weightedBest) Sample(sampleValue uint64) (int, bool) {
	return s.sampler.Sample(sampleValue)
}

// weightedHeapSampler implements the Weighted interface using a heap-based approach
type weightedHeapSampler struct {
	heap           *weightedHeap
	totalWeight    uint64
	maxUint64      uint64
	numWeights     int
	weights        []uint64
	cumulativeSum  []uint64
	uniform        Uniform
}

func (s *weightedHeapSampler) Initialize(weights []uint64) error {
	s.numWeights = len(weights)
	if s.numWeights <= 0 {
		return errNoEligibleSamples
	}

	// Initialize the cumulative sum of the weights
	s.weights = make([]uint64, s.numWeights)
	s.cumulativeSum = make([]uint64, s.numWeights)
	
	var totalWeight uint64
	for i, weight := range weights {
		s.weights[i] = weight
		totalWeight += weight
		s.cumulativeSum[i] = totalWeight
	}
	
	s.totalWeight = totalWeight
	s.maxUint64 = ^uint64(0)
	
	// Initialize heap
	s.heap = &weightedHeap{}
	if err := s.heap.Initialize(weights); err != nil {
		return err
	}
	
	return nil
}

func (s *weightedHeapSampler) Sample(sampleValue uint64) (int, bool) {
	if s.totalWeight == 0 || sampleValue >= s.totalWeight {
		return 0, false
	}
	
	// Binary search for the index
	low, high := 0, s.numWeights-1
	for low <= high {
		mid := (low + high) >> 1
		if s.cumulativeSum[mid] <= sampleValue {
			low = mid + 1
		} else {
			high = mid - 1
		}
	}
	
	// If low == 0, it means the sample value is less than the first cumulative weight
	if low == 0 {
		return 0, true
	}
	
	// Otherwise, the index is low-1
	return low, true
} 