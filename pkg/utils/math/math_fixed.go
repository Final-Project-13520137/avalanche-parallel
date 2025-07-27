// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package math

import (
	"errors"

	"github.com/Final-Project-13520137/avalanche-parallel/pkg/utils/cmp"
)

var (
	ErrOverflow  = errors.New("overflow")
	ErrUnderflow = errors.New("underflow")

	// Deprecated: Add64 is deprecated. Use Add[uint64] instead.
	Add64 = Add[uint64]

	// Deprecated: Mul64 is deprecated. Use Mul[uint64] instead.
	Mul64 = Mul[uint64]
)

// MaxUint returns the maximum value of an unsigned integer of type T.
func MaxUint[T ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr]() T {
	return ^T(0)
}

// Add returns:
// 1) a + b
// 2) If there is overflow, an error
func Add[T ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr](a, b T) (T, error) {
	if a > MaxUint[T]()-b {
		return 0, ErrOverflow
	}
	return a + b, nil
}

// Sub returns:
// 1) a - b
// 2) If there is underflow, an error
func Sub[T ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr](a, b T) (T, error) {
	if a < b {
		return 0, ErrUnderflow
	}
	return a - b, nil
}

// Mul returns:
// 1) a * b
// 2) If there is overflow, an error
func Mul[T ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr](a, b T) (T, error) {
	if b != 0 && a > MaxUint[T]()/b {
		return 0, ErrOverflow
	}
	return a * b, nil
}

func AbsDiff[T ~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr](a, b T) T {
	if a > b {
		return a - b
	}
	return b - a
}

// Max returns the maximum of a and b
func Max[T cmp.Bounded[T]](a, b T) T {
	return cmp.Max(a, b)
}

// Min returns the minimum of a and b
func Min[T cmp.Bounded[T]](a, b T) T {
	return cmp.Min(a, b)
}

// Compare returns:
//
//	-1 if a < b
//	 0 if a == b
//	+1 if a > b
func Compare[T cmp.Bounded[T]](a, b T) int {
	return cmp.Compare(a, b)
}
