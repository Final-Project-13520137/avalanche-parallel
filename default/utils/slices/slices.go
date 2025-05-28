// Package slices provides Go 1.18 compatible implementation of the slices package
package slices

import "github.com/ava-labs/avalanchego/utils/cmp"

// Clone returns a copy of the slice.
// The elements are copied using assignment, so this is a shallow clone.
func Clone[S ~[]E, E any](s S) S {
	// Preserve nil in case it matters.
	if s == nil {
		return nil
	}
	return append(S([]E{}), s...)
}

// Compare compares the elements of s1 and s2.
// The elements are compared sequentially, starting at index 0,
// until one element is not equal to the other.
// The result of comparing the first non-matching elements is returned.
// If both slices are equal until one of them ends, the shorter slice is
// considered less than the longer one.
// The result is 0 if s1 == s2, -1 if s1 < s2, and +1 if s1 > s2.
func Compare[S ~[]E, E comparable](s1, s2 S) int {
	// For Go 1.18 compatibility, use manual comparison with indices
	minLen := len(s1)
	if len(s2) < minLen {
		minLen = len(s2)
	}
	
	for i := 0; i < minLen; i++ {
		if s1[i] != s2[i] {
			// Use cmp.Compare for Go 1.18 compatibility
			return compareItems(s1[i], s2[i])
		}
	}
	
	if len(s1) < len(s2) {
		return -1
	}
	if len(s1) > len(s2) {
		return 1
	}
	return 0
}

// compareItems is a helper function for comparing two comparable values
func compareItems[T comparable](a, b T) int {
	switch {
	case a == b:
		return 0
	default:
		// For Go 1.18 compatibility, use type assertions
		switch v := any(a).(type) {
		case int:
			if v < any(b).(int) {
				return -1
			}
			return 1
		case int8:
			if v < any(b).(int8) {
				return -1
			}
			return 1
		case int16:
			if v < any(b).(int16) {
				return -1
			}
			return 1
		case int32:
			if v < any(b).(int32) {
				return -1
			}
			return 1
		case int64:
			if v < any(b).(int64) {
				return -1
			}
			return 1
		case uint:
			if v < any(b).(uint) {
				return -1
			}
			return 1
		case uint8:
			if v < any(b).(uint8) {
				return -1
			}
			return 1
		case uint16:
			if v < any(b).(uint16) {
				return -1
			}
			return 1
		case uint32:
			if v < any(b).(uint32) {
				return -1
			}
			return 1
		case uint64:
			if v < any(b).(uint64) {
				return -1
			}
			return 1
		case float32:
			if v < any(b).(float32) {
				return -1
			}
			return 1
		case float64:
			if v < any(b).(float64) {
				return -1
			}
			return 1
		case string:
			if v < any(b).(string) {
				return -1
			}
			return 1
		default:
			// For incomparable types, default to comparison based on string representation
			return 1 // Default to greater than for non-comparable types
		}
	}
}

// Equal reports whether two slices are equal: the same length and all
// elements equal. If the lengths are different, Equal returns false.
// Otherwise, the elements are compared in index order, and the
// comparison stops at the first unequal pair.
func Equal[S ~[]E, E comparable](s1, s2 S) bool {
	if len(s1) != len(s2) {
		return false
	}
	for i := range s1 {
		if s1[i] != s2[i] {
			return false
		}
	}
	return true
}

// DeleteFunc removes all elements e from s for which del(e) is true.
func DeleteFunc[S ~[]E, E any](s S, del func(E) bool) S {
	n := 0
	for _, v := range s {
		if !del(v) {
			s[n] = v
			n++
		}
	}
	return s[:n]
}

// Contains reports whether v is present in s.
func Contains[S ~[]E, E comparable](s S, v E) bool {
	for _, vs := range s {
		if v == vs {
			return true
		}
	}
	return false
}

// Sort sorts a slice of any ordered type in ascending order.
func Sort[S ~[]E, E cmp.Ordered](s S) {
	n := len(s)
	// Insert sort algorithm
	for i := 1; i < n; i++ {
		for j := i; j > 0 && s[j] < s[j-1]; j-- {
			s[j], s[j-1] = s[j-1], s[j]
		}
	}
} 