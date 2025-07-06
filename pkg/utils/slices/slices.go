package slices

import "github.com/Final-Project-13520137/avalanche-parallel/pkg/utils/cmp"

// Contains returns true if [val] is in [slice]
func Contains[T comparable](slice []T, val T) bool {
	for _, v := range slice {
		if v == val {
			return true
		}
	}
	return false
}

// Remove returns a new slice with all elements equal to [val] removed from [slice]
func Remove[T comparable](slice []T, val T) []T {
	result := make([]T, 0, len(slice))
	for _, v := range slice {
		if v != val {
			result = append(result, v)
		}
	}
	return result
}

// Unique returns a new slice containing only unique elements from [slice]
func Unique[T comparable](slice []T) []T {
	seen := make(map[T]struct{})
	result := make([]T, 0, len(slice))
	for _, v := range slice {
		if _, ok := seen[v]; !ok {
			seen[v] = struct{}{}
			result = append(result, v)
		}
	}
	return result
}

// Sort returns a new sorted slice containing the elements of [slice]
func Sort[T cmp.Bounded[T]](slice []T) []T {
	result := make([]T, len(slice))
	copy(result, slice)
	quickSort(result, 0, len(result)-1)
	return result
}

// quickSort sorts the slice in-place using quicksort
func quickSort[T cmp.Bounded[T]](slice []T, low, high int) {
	if low < high {
		pivot := partition(slice, low, high)
		quickSort(slice, low, pivot-1)
		quickSort(slice, pivot+1, high)
	}
}

// partition is a helper function for quickSort
func partition[T cmp.Bounded[T]](slice []T, low, high int) int {
	pivot := slice[high]
	i := low - 1

	for j := low; j < high; j++ {
		if slice[j] <= pivot {
			i++
			slice[i], slice[j] = slice[j], slice[i]
		}
	}

	slice[i+1], slice[high] = slice[high], slice[i+1]
	return i + 1
}

// IsSorted returns true if [slice] is sorted in ascending order
func IsSorted[T cmp.Bounded[T]](slice []T) bool {
	for i := 1; i < len(slice); i++ {
		if slice[i] < slice[i-1] {
			return false
		}
	}
	return true
}

// Reverse returns a new slice with the elements of [slice] in reverse order
func Reverse[T any](slice []T) []T {
	result := make([]T, len(slice))
	for i, j := 0, len(slice)-1; i < len(slice); i, j = i+1, j-1 {
		result[i] = slice[j]
	}
	return result
}

// Copy returns a new slice containing the elements of [slice]
func Copy[T any](slice []T) []T {
	result := make([]T, len(slice))
	copy(result, slice)
	return result
}

// Equal returns true if [s1] and [s2] have the same elements in the same order
func Equal[T comparable](s1, s2 []T) bool {
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
