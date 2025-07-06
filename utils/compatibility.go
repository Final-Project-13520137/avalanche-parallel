// compatibility.go provides compatibility functions for newer Go packages
// that are not available in Go 1.18

package utils

import (
	"fmt"
	"runtime"
)

// GetOSVersion returns the current OS version
func GetOSVersion() string {
	return fmt.Sprintf("%s %s", runtime.GOOS, runtime.GOARCH)
}

// IsWindows returns true if the current OS is Windows
func IsWindows() bool {
	return runtime.GOOS == "windows"
}

// IsLinux returns true if the current OS is Linux
func IsLinux() bool {
	return runtime.GOOS == "linux"
}

// IsMacOS returns true if the current OS is macOS
func IsMacOS() bool {
	return runtime.GOOS == "darwin"
}

// GetPlatformSpecificPath converts a path to the platform-specific format
func GetPlatformSpecificPath(path string) string {
	if IsWindows() {
		// Convert forward slashes to backslashes
		return fmt.Sprintf("C:%s", path)
	}
	return path
} 