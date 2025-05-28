// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package math

import (
	"errors"

	"github.com/ava-labs/avalanchego/utils/cmp"
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
func MaxUint[T cmp.Unsigned]() T {
	return ^T(0)
}

// Add returns:
// 1) a + b
// 2) If there is overflow, an error
func Add[T cmp.Unsigned](a, b T) (T, error) {
	if a > MaxUint[T]()-b {
		return 0, ErrOverflow
	}
	return a + b, nil
}

// Sub returns:
// 1) a - b
// 2) If there is underflow, an error
func Sub[T cmp.Unsigned](a, b T) (T, error) {
	if a < b {
		return 0, ErrUnderflow
	}
	return a - b, nil
}

// Mul returns:
// 1) a * b
// 2) If there is overflow, an error
func Mul[T cmp.Unsigned](a, b T) (T, error) {
	if b != 0 && a > MaxUint[T]()/b {
		return 0, ErrOverflow
	}
	return a * b, nil
}

func AbsDiff[T cmp.Unsigned](a, b T) T {
	if a > b {
		return a - b
	}
	return b - a
} 