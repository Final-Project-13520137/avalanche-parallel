package cmp

// Min returns the minimum of a and b
func Min[T Bounded[T]](a, b T) T {
	if Compare(a, b) < 0 {
		return a
	}
	return b
}

// Max returns the maximum of a and b
func Max[T Bounded[T]](a, b T) T {
	if Compare(a, b) > 0 {
		return a
	}
	return b
}

// Compare returns:
//   -1 if a < b
//    0 if a == b
//   +1 if a > b
func Compare[T Bounded[T]](a, b T) int {
	switch v := any(a).(type) {
	case int:
		if v < any(b).(int) {
			return -1
		}
		if v > any(b).(int) {
			return 1
		}
	case int8:
		if v < any(b).(int8) {
			return -1
		}
		if v > any(b).(int8) {
			return 1
		}
	case int16:
		if v < any(b).(int16) {
			return -1
		}
		if v > any(b).(int16) {
			return 1
		}
	case int32:
		if v < any(b).(int32) {
			return -1
		}
		if v > any(b).(int32) {
			return 1
		}
	case int64:
		if v < any(b).(int64) {
			return -1
		}
		if v > any(b).(int64) {
			return 1
		}
	case uint:
		if v < any(b).(uint) {
			return -1
		}
		if v > any(b).(uint) {
			return 1
		}
	case uint8:
		if v < any(b).(uint8) {
			return -1
		}
		if v > any(b).(uint8) {
			return 1
		}
	case uint16:
		if v < any(b).(uint16) {
			return -1
		}
		if v > any(b).(uint16) {
			return 1
		}
	case uint32:
		if v < any(b).(uint32) {
			return -1
		}
		if v > any(b).(uint32) {
			return 1
		}
	case uint64:
		if v < any(b).(uint64) {
			return -1
		}
		if v > any(b).(uint64) {
			return 1
		}
	case uintptr:
		if v < any(b).(uintptr) {
			return -1
		}
		if v > any(b).(uintptr) {
			return 1
		}
	case float32:
		if v < any(b).(float32) {
			return -1
		}
		if v > any(b).(float32) {
			return 1
		}
	case float64:
		if v < any(b).(float64) {
			return -1
		}
		if v > any(b).(float64) {
			return 1
		}
	case string:
		if v < any(b).(string) {
			return -1
		}
		if v > any(b).(string) {
			return 1
		}
	}
	return 0
}

// Bounded is a type constraint that enforces a type has bounds
type Bounded[T any] interface {
	~int | ~int8 | ~int16 | ~int32 | ~int64 |
		~uint | ~uint8 | ~uint16 | ~uint32 | ~uint64 | ~uintptr |
		~float32 | ~float64 |
		~string
}

// cmp is a type constraint that enforces a type can be compared with <, >, and ==
type cmp[T any] interface {
	Bounded[T]
}
