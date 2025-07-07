// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package logging

import (
	"go.uber.org/zap"
)

// SugaredLoggerAdapter adapts zap.SugaredLogger to our Logger interface
type SugaredLoggerAdapter struct {
	logger *zap.SugaredLogger
}

// NewSugaredLoggerAdapter creates a new adapter for zap.SugaredLogger
func NewSugaredLoggerAdapter(logger *zap.SugaredLogger) Logger {
	return &SugaredLoggerAdapter{logger: logger}
}

// Debug logs a debug message
func (a *SugaredLoggerAdapter) Debug(msg string, fields ...zap.Field) {
	a.logger.Debugw(msg, fieldsToArgs(fields...)...)
}

// Info logs an info message
func (a *SugaredLoggerAdapter) Info(msg string, fields ...zap.Field) {
	a.logger.Infow(msg, fieldsToArgs(fields...)...)
}

// Warn logs a warning message
func (a *SugaredLoggerAdapter) Warn(msg string, fields ...zap.Field) {
	a.logger.Warnw(msg, fieldsToArgs(fields...)...)
}

// Error logs an error message
func (a *SugaredLoggerAdapter) Error(msg string, fields ...zap.Field) {
	a.logger.Errorw(msg, fieldsToArgs(fields...)...)
}

// Fatal logs a fatal message and exits
func (a *SugaredLoggerAdapter) Fatal(msg string, fields ...zap.Field) {
	a.logger.Fatalw(msg, fieldsToArgs(fields...)...)
}

// fieldsToArgs converts zap.Field to key-value pairs for sugared logger
func fieldsToArgs(fields ...zap.Field) []interface{} {
	args := make([]interface{}, 0, len(fields)*2)
	for _, field := range fields {
		args = append(args, field.Key)
		args = append(args, field.Interface)
	}
	return args
}
