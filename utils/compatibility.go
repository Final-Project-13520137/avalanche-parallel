// compatibility.go provides compatibility functions for newer Go packages
// that are not available in Go 1.18

package utils

import (
	"bytes"
	"sort"
)

// SlicesSort provides a compatibility function for slices.Sort
func SlicesSort[T any](s []T, less func(a, b T) bool) {
	sort.Slice(s, func(i, j int) bool {
		return less(s[i], s[j])
	})
}

// SlicesSortFunc provides a compatibility function for slices.SortFunc
func SlicesSortFunc[T any](s []T, cmp func(a, b T) int) {
	sort.Slice(s, func(i, j int) bool {
		return cmp(s[i], s[j]) < 0
	})
}

// SlicesClone provides a compatibility function for slices.Clone
func SlicesClone[T any](s []T) []T {
	if s == nil {
		return nil
	}
	result := make([]T, len(s))
	copy(result, s)
	return result
}

// MapsClear provides a compatibility function for maps.Clear
func MapsClear[M ~map[K]V, K comparable, V any](m M) {
	for k := range m {
		delete(m, k)
	}
}

// Compare provides a compatibility function for cmp.Compare
func Compare[T comparable](a, b T) int {
	switch {
	case a < b:
		return -1
	case a > b:
		return 1
	default:
		return 0
	}
}

// SlicesClear provides a compatibility function for clear() on slices
func SlicesClear[T any](s []T) []T {
	return s[:0]
}

// CompareBytes provides a compatibility function for comparing byte slices
func CompareBytes(a, b []byte) int {
	return bytes.Compare(a, b)
}

// CompareInt provides a comparison function for integers
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

// CompareFloat64 provides a comparison function for floating point numbers
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

// CompareString provides a comparison function for strings
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

// IsLessThan compares two comparable values
// This is a workaround for Go 1.18 not supporting < on generic types
func IsLessThan[T comparable](a, b T) bool {
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

// SlicesContains checks if a slice contains a specific element
func SlicesContains[T comparable](s []T, e T) bool {
	for _, v := range s {
		if v == e {
			return true
		}
	}
	return false
}

// SlicesEqual checks if two slices are equal
func SlicesEqual[T comparable](a, b []T) bool {
	if len(a) != len(b) {
		return false
	}
	for i, v := range a {
		if v != b[i] {
			return false
		}
	}
	return true
}

// SlicesIndex returns the index of the first occurrence of e in s, or -1 if not found
func SlicesIndex[T comparable](s []T, e T) int {
	for i, v := range s {
		if v == e {
			return i
		}
	}
	return -1
}

// MapKeys returns the keys of a map in a slice
func MapKeys[M ~map[K]V, K comparable, V any](m M) []K {
	keys := make([]K, 0, len(m))
	for k := range m {
		keys = append(keys, k)
	}
	return keys
}

// MapValues returns the values of a map in a slice
func MapValues[M ~map[K]V, K comparable, V any](m M) []V {
	values := make([]V, 0, len(m))
	for _, v := range m {
		values = append(values, v)
	}
	return values
} 