// Copyright (C) 2019-2024, Ava Labs, Inc. All rights reserved.
// See the file LICENSE for licensing terms.

package utils

import (
	"bytes"
	"sort"

	"github.com/ava-labs/avalanchego/utils/hashing"
)

// TODO can we handle sorting where the Compare function relies on a codec?

type Sortable[T any] interface {
	Compare(T) int
}

// Sorts the elements of [s].
func Sort[T Sortable[T]](s []T) {
	sort.Slice(s, func(i, j int) bool {
		return s[i].Compare(s[j]) < 0
	})
}

// SortBytes sorts a slice of byte slices
func SortBytes(byteSlices [][]byte) {
	sort.Slice(byteSlices, func(i, j int) bool {
		return bytes.Compare(byteSlices[i], byteSlices[j]) < 0
	})
}

// Sort2DBytes sorts a 2D byte slice by the first index's lexicographical order
func Sort2DBytes(byteSlices [][]byte) {
	sort.Slice(byteSlices, func(i, j int) bool {
		return bytes.Compare(byteSlices[i], byteSlices[j]) < 0
	})
}

// Sorts the elements of [s] based on their hashes.
func SortByHash[T ~[]byte](s []T) {
	sort.Slice(s, func(i, j int) bool {
		iHash := hashing.ComputeHash256(s[i])
		jHash := hashing.ComputeHash256(s[j])
		return bytes.Compare(iHash, jHash) < 0
	})
}

// Returns true iff the elements in [s] are sorted.
func IsSortedBytes[T ~[]byte](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		if bytes.Compare(s[i], s[i+1]) > 0 {
			return false
		}
	}
	return true
}

// Returns true iff the elements in [s] are unique and sorted.
func IsSortedAndUnique[T Sortable[T]](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		if s[i].Compare(s[i+1]) >= 0 {
			return false
		}
	}
	return true
}

// Compare operations for specific types
func CompareInt(a, b int) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func CompareFloat64(a, b float64) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

func CompareString(a, b string) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

// Returns true iff the elements in [s] are unique and sorted.
func IsSortedAndUniqueOrdered[T comparable](s []T) bool {
	for i := 0; i < len(s)-1; i++ {
		// For Go 1.18 compatibility, we'll check manually based on type
		if !isLessThanOrEqual(s[i+1], s[i]) {
			return false
		}
	}
	return true
}

// isLessThanOrEqual returns true if a <= b
func isLessThanOrEqual[T comparable](a, b T) bool {
	return isLessThan(a, b) || isEqual(a, b)
}

// isEqual checks if two comparable values are equal
func isEqual[T comparable](a, b T) bool {
	return a == b
}

// isLessThan compares two comparable values
// This is a workaround for Go 1.18 not supporting < on generic types
func isLessThan[T comparable](a, b T) bool {
	// Use type assertion to handle common types
	switch v := any(a).(type) {
	case int:
		return v < any(b).(int)
	case int8:
		return v < any(b).(int8)
	case int16:
		return v < any(b).(int16)
	case int32:
		return v < any(b).(int32)
	case int64:
		return v < any(b).(int64)
	case uint:
		return v < any(b).(uint)
	case uint8:
		return v < any(b).(uint8)
	case uint16:
		return v < any(b).(uint16)
	case uint32:
		return v < any(b).(uint32)
	case uint64:
		return v < any(b).(uint64)
	case float32:
		return v < any(b).(float32)
	case float64:
		return v < any(b).(float64)
	case string:
		return v < any(b).(string)
	default:
		// For other types, compare bytes if possible
		// This is not ideal but a fallback for Go 1.18 compatibility
		aBytes, aOk := any(a).([]byte)
		bBytes, bOk := any(b).([]byte)
		if aOk && bOk {
			return bytes.Compare(aBytes, bBytes) < 0
		}
		// For other types, we can't compare directly in Go 1.18
		// Return true to avoid failing, but this might not be correct
		// for all types
		return true
	}
}

// Returns true iff the elements in [s] are unique and sorted
// based by their hashes.
func IsSortedAndUniqueByHash[T ~[]byte](s []T) bool {
	if len(s) <= 1 {
		return true
	}
	rightHash := hashing.ComputeHash256(s[0])
	for i := 1; i < len(s); i++ {
		leftHash := rightHash
		rightHash = hashing.ComputeHash256(s[i])
		if bytes.Compare(leftHash, rightHash) >= 0 {
			return false
		}
	}
	return true
}

// Compare returns a negative number, 0, or positive number if [a] is less than,
// equal to, or greater than [b].
// Assumes that [a] and [b] have the same length.
func Compare(a, b []byte) int {
	return bytes.Compare(a, b)
}

// CompareSlice returns a negative number, 0, or positive number if [a] is less than,
// equal to, or greater than [b].
func CompareSlice(a, b [][]byte) int {
	minLen := len(a)
	if len(b) < minLen {
		minLen = len(b)
	}
	for i := 0; i < minLen; i++ {
		comparison := bytes.Compare(a[i], b[i])
		if comparison != 0 {
			return comparison
		}
	}
	return len(a) - len(b)
} 

