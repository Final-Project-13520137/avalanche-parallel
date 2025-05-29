// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package sampler

import (
	"fmt"
	"math"
)

// weightedHeap implements the Weighted interface.
//
// Sampling is performed by using a binary heap where the priority is uniformly
// drawn random numbers to the power of (1 / weight). This results in a uniform
// distribution over the weight of the elements.
//
// Initialization takes O(n) time where n is the number of elements that can be
// sampled.
// Sampling is performed in worst case O(log(n)) time.
type weightedHeap struct {
	heap       []weightedElement
	numWeights int
}

type weightedElement struct {
	initialIndex  int
	weight        uint64
	cumulativeSum uint64
	drawIndex     int
	priority      float64
}

// Initialize implements the Weighted interface
func (s *weightedHeap) Initialize(weights []uint64) error {
	s.numWeights = len(weights)
	if s.numWeights <= 0 {
		return errNoEligibleSamples
	}

	// Scale the weights to the interval [0, uint64Max)
	var sum float64
	for _, weight := range weights {
		sum += float64(weight)
	}
	scale := float64(math.MaxUint64) / sum

	// Initialize the binary heap
	s.heap = make([]weightedElement, s.numWeights)

	var cumSum uint64
	for i, weight := range weights {
		scaledWeight := uint64(float64(weight) * scale)
		s.heap[i] = weightedElement{
			initialIndex:  i,
			weight:        scaledWeight,
			cumulativeSum: cumSum,
			drawIndex:     -1,
			priority:      0,
		}
		newSum := cumSum + scaledWeight
		if newSum < cumSum {
			return errWeightOverflow
		}
		cumSum = newSum
	}

	// Set the initial priority of the heap
	s.reset()
	return nil
}

// Sample implements the Weighted interface
func (s *weightedHeap) Sample(numSamples int) ([]int, error) {
	if numSamples <= 0 {
		return nil, nil
	}
	if numSamples > s.numWeights {
		return nil, fmt.Errorf("no more than %d elements can be sampled, requested %d",
			s.numWeights, numSamples)
	}

	indices := make([]int, numSamples)
	for i := range indices {
		if err := s.update(); err != nil {
			// Because the weights aren't changing, there shouldn't be any
			// reason for this to error except for a programming error.
			return nil, err
		}
		indices[i] = s.heap[0].initialIndex
		s.Remove(indices[i])
	}
	s.reset()
	return indices, nil
}

// Update implements the UpdatableWeighted interface
func (s *weightedHeap) Update(index int, weight uint64) (uint64, error) {
	if index < 0 || index >= s.numWeights {
		return 0, errIndexOutOfRange
	}

	elt := s.heap[index]
	if elt.drawIndex < 0 {
		return elt.weight, errElementRemoved
	}

	oldWeight := elt.weight
	s.heap[elt.drawIndex].weight = weight
	return oldWeight, s.rebalance(elt.drawIndex)
}

// Remove implements the UpdatableWeighted interface
func (s *weightedHeap) Remove(index int) error {
	if index < 0 || index >= s.numWeights {
		return errIndexOutOfRange
	}

	elt := s.heap[index]
	if elt.drawIndex < 0 {
		return errElementRemoved
	}

	// We know the sample is currently in the heap
	// Note: We are changing the removal condition for the element
	// from being drawn to being removed. This means the next call
	// to update will rebalance the priority queue.
	s.heap[elt.drawIndex].drawIndex = -1
	return nil
}

// update consumes the minimum element of the priority queue and adds a new
// uniform random element to the queue.
func (s *weightedHeap) update() error {
	heap := s.heap
	element := &heap[0]
	element.drawIndex = -1

	max := len(heap) - 1
	if max < 0 {
		return errUnknownWeightError
	}

	// Get the minimum value of the heap.
	// Add the value at the end of the heap to the beginning.
	// Then fix the heap
	heap[0], heap[max] = heap[max], heap[0]
	s.numWeights--
	if s.numWeights <= 0 {
		return nil
	}
	heap = heap[:s.numWeights]
	s.heap = heap

	// Percolate the heap
	index := 0
	for {
		minChild := 2*index + 1
		if minChild >= s.numWeights {
			// We reached the bottom of the heap
			break
		}

		// Calculate the minimum child
		rightChild := minChild + 1
		if rightChild < s.numWeights &&
			heap[rightChild].priority < heap[minChild].priority {
			minChild = rightChild
		}

		// If this element is less than the least of our children, then we are
		// done
		if heap[index].priority <= heap[minChild].priority {
			break
		}

		// We are less than at least one of our children, swap with the min one
		heap[index], heap[minChild] = heap[minChild], heap[index]
		heap[index].drawIndex = index
		heap[minChild].drawIndex = minChild
		index = minChild
	}
	return nil
}

// rebalance the heap using the new weights
func (s *weightedHeap) rebalance(index int) error {
	heap := s.heap

	// Percolate up
	for index > 0 {
		parentIndex := (index - 1) / 2
		if heap[index].priority >= heap[parentIndex].priority {
			// We are >= our parent, so we are done
			break
		}

		// We are < our parent, so swap
		heap[index], heap[parentIndex] = heap[parentIndex], heap[index]
		heap[index].drawIndex = index
		heap[parentIndex].drawIndex = parentIndex
		index = parentIndex
	}

	// Percolate down
	for {
		minChild := 2*index + 1
		if minChild >= s.numWeights {
			// We reached the bottom of the heap
			break
		}

		// Calculate the minimum child
		rightChild := minChild + 1
		if rightChild < s.numWeights &&
			heap[rightChild].priority < heap[minChild].priority {
			minChild = rightChild
		}

		// If this element is less than the least of our children, then we are done
		if heap[index].priority <= heap[minChild].priority {
			break
		}

		// We are less than at least one of our children, swap with the min one
		heap[index], heap[minChild] = heap[minChild], heap[index]
		heap[index].drawIndex = index
		heap[minChild].drawIndex = minChild
		index = minChild
	}
	return nil
}

// reset the priority of the elements in the heap
func (s *weightedHeap) reset() {
	s.numWeights = len(s.heap)
	if s.numWeights <= 0 {
		return
	}

	for i := range s.heap {
		// If the element has been removed, provide a sentinel priority
		if s.heap[i].drawIndex < 0 {
			s.heap[i].priority = math.Inf(1) // infinity
			continue
		}

		// Calculate the new priority for this element
		// We are doing a uniform random value to the power of (1/weight)
		// This gives us a uniform distribution over the weight of the elements
		if s.heap[i].weight > 0 {
			uniform := float64(s.heap[i].cumulativeSum) / float64(s.heap[i].weight)
			s.heap[i].priority = math.Pow(uniform, 1/float64(s.heap[i].weight))
		} else {
			s.heap[i].priority = math.Inf(1) // infinity
		}
		s.heap[i].drawIndex = i
	}

	// Build a heap
	for i := (s.numWeights - 1) / 2; i >= 0; i-- {
		index := i
		for {
			minChild := 2*index + 1
			if minChild >= s.numWeights {
				// We reached the bottom of the heap
				break
			}

			// Calculate the minimum child
			rightChild := minChild + 1
			if rightChild < s.numWeights &&
				s.heap[rightChild].priority < s.heap[minChild].priority {
				minChild = rightChild
			}

			// If this element is less than the least of our children, then we are done
			if s.heap[index].priority <= s.heap[minChild].priority {
				break
			}

			// We are less than at least one of our children, swap with the min one
			s.heap[index], s.heap[minChild] = s.heap[minChild], s.heap[index]
			s.heap[index].drawIndex = index
			s.heap[minChild].drawIndex = minChild
			index = minChild
		}
	}
} 