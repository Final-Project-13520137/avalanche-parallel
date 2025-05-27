package logging

import (
	"fmt"
	"log"
	"os"
)

// Config holds logging configuration
type Config struct {
	DisplayLevel string
}

// Logger defines the interface for the logging methods
type Logger interface {
	Debug(format string, args ...interface{})
	Info(format string, args ...interface{})
	Warn(format string, args ...interface{})
	Error(format string, args ...interface{})
	Fatal(format string, args ...interface{})
}

// Factory creates new loggers
type Factory struct {
	config Config
}

// DefaultLogger implements the Logger interface
type DefaultLogger struct {
	name   string
	logger *log.Logger
}

// NewFactory creates a new Factory with the given config
func NewFactory(config Config) *Factory {
	return &Factory{
		config: config,
	}
}

// Make creates a new logger with the given name
func (f *Factory) Make(name string) (Logger, error) {
	logger := log.New(os.Stdout, fmt.Sprintf("[%s] ", name), log.LstdFlags)
	return &DefaultLogger{
		name:   name,
		logger: logger,
	}, nil
}

// Debug logs a debug message
func (l *DefaultLogger) Debug(format string, args ...interface{}) {
	l.logger.Printf("DEBUG "+format, args...)
}

// Info logs an info message
func (l *DefaultLogger) Info(format string, args ...interface{}) {
	l.logger.Printf("INFO "+format, args...)
}

// Warn logs a warning message
func (l *DefaultLogger) Warn(format string, args ...interface{}) {
	l.logger.Printf("WARN "+format, args...)
}

// Error logs an error message
func (l *DefaultLogger) Error(format string, args ...interface{}) {
	l.logger.Printf("ERROR "+format, args...)
}

// Fatal logs a fatal message and exits
func (l *DefaultLogger) Fatal(format string, args ...interface{}) {
	l.logger.Printf("FATAL "+format, args...)
	os.Exit(1)
} 