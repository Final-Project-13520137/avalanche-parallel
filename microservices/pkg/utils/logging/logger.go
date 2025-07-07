package logging

import (
	"fmt"
	"os"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

// CustomLogger wraps zap.Logger with additional functionality
type CustomLogger struct {
	*zap.Logger
}

// NewLogger creates a new logger with the given name
func NewLogger(name string) *CustomLogger {
	// Create log directory if it doesn't exist
	if err := os.MkdirAll("logs", 0755); err != nil {
		fmt.Printf("Failed to create log directory: %v\n", err)
		os.Exit(1)
	}

	// Configure logging output
	logFile := &lumberjack.Logger{
		Filename:   fmt.Sprintf("logs/%s.log", name),
		MaxSize:    10, // megabytes
		MaxBackups: 3,
		MaxAge:     7, // days
		Compress:   true,
	}

	// Create encoder config
	encoderConfig := zapcore.EncoderConfig{
		TimeKey:        "ts",
		LevelKey:       "level",
		NameKey:        "logger",
		CallerKey:      "caller",
		MessageKey:     "msg",
		StacktraceKey:  "stacktrace",
		LineEnding:     zapcore.DefaultLineEnding,
		EncodeLevel:    zapcore.LowercaseLevelEncoder,
		EncodeTime:     zapcore.ISO8601TimeEncoder,
		EncodeDuration: zapcore.SecondsDurationEncoder,
		EncodeCaller:   zapcore.ShortCallerEncoder,
	}

	// Create core
	core := zapcore.NewCore(
		zapcore.NewJSONEncoder(encoderConfig),
		zapcore.NewMultiWriteSyncer(
			zapcore.AddSync(os.Stdout),
			zapcore.AddSync(logFile),
		),
		zap.NewAtomicLevelAt(zap.InfoLevel),
	)

	// Create logger
	logger := zap.New(core)
	return &CustomLogger{logger}
}

// Info logs an info message with additional fields
func (l *CustomLogger) Info(msg string, keysAndValues ...interface{}) {
	fields := make([]zap.Field, 0, len(keysAndValues)/2)
	for i := 0; i < len(keysAndValues); i += 2 {
		key := keysAndValues[i].(string)
		value := keysAndValues[i+1]
		fields = append(fields, zap.Any(key, value))
	}
	l.Logger.Info(msg, fields...)
}

// Error logs an error message with additional fields
func (l *CustomLogger) Error(msg string, err error, keysAndValues ...interface{}) {
	fields := make([]zap.Field, 0, len(keysAndValues)/2+1)
	fields = append(fields, zap.Error(err))
	for i := 0; i < len(keysAndValues); i += 2 {
		key := keysAndValues[i].(string)
		value := keysAndValues[i+1]
		fields = append(fields, zap.Any(key, value))
	}
	l.Logger.Error(msg, fields...)
}

// Sync flushes any buffered log entries
func (l *CustomLogger) Sync() error {
	return l.Logger.Sync()
}
