// Package cmp provides Go 1.18 compatible implementation of constraints
package cmp

// Ordered is a constraint that permits any ordered type: any type
// that supports the operators < <= >= >.
type Ordered interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 |
		~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr |
		~float32 | ~float64 |
		~string
}

// Signed is a constraint that permits any signed integer type.
type Signed interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64
}

// Unsigned is a constraint that permits any unsigned integer type.
type Unsigned interface {
	~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr
}

// Integer is a constraint that permits any integer type.
type Integer interface {
	Signed | Unsigned
}

// Float is a constraint that permits any floating-point type.
type Float interface {
	~float32 | ~float64
}

// Complex is a constraint that permits any complex numeric type.
type Complex interface {
	~complex64 | ~complex128
}

// Compare returns an integer comparing two values.
// The result will be 0 if a == b, -1 if a < b, and +1 if a > b.
func Compare[T Ordered](a, b T) int {
	if a < b {
		return -1
	}
	if a > b {
		return 1
	}
	return 0
} 