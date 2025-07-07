package maps

// Clone returns a copy of the given map
func Clone[K comparable, V any](m map[K]V) map[K]V {
	result := make(map[K]V, len(m))
	for k, v := range m {
		result[k] = v
	}
	return result
}

// Merge merges maps [m1] and [m2] and returns the result.
// If there is a key overlap, the value from [m2] is used.
func Merge[K comparable, V any](m1, m2 map[K]V) map[K]V {
	result := make(map[K]V, len(m1)+len(m2))
	for k, v := range m1 {
		result[k] = v
	}
	for k, v := range m2 {
		result[k] = v
	}
	return result
}

// Keys returns the keys of map [m] in a slice
func Keys[K comparable, V any](m map[K]V) []K {
	result := make([]K, 0, len(m))
	for k := range m {
		result = append(result, k)
	}
	return result
}

// Values returns the values of map [m] in a slice
func Values[K comparable, V any](m map[K]V) []V {
	result := make([]V, 0, len(m))
	for _, v := range m {
		result = append(result, v)
	}
	return result
}

// Union returns a map containing all key-value pairs that appear in either [m1] or [m2].
// If a key appears in both maps, the value from [m2] is used.
func Union[K comparable, V any](m1, m2 map[K]V) map[K]V {
	return Merge(m1, m2)
}

// Intersect returns a map containing all key-value pairs that appear in both [m1] and [m2].
// The values from [m2] are used in the result.
func Intersect[K comparable, V any](m1, m2 map[K]V) map[K]V {
	result := make(map[K]V)
	for k, v2 := range m2 {
		if _, ok := m1[k]; ok {
			result[k] = v2
		}
	}
	return result
}

// Subtract returns a map containing all key-value pairs that appear in [m1] but not in [m2].
func Subtract[K comparable, V any](m1, m2 map[K]V) map[K]V {
	result := make(map[K]V)
	for k, v := range m1 {
		if _, ok := m2[k]; !ok {
			result[k] = v
		}
	}
	return result
}
