package logging

import (
	"fmt"
	"os"
	"path/filepath"
	"time"

	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
	"gopkg.in/natefinch/lumberjack.v2"
)

var (
	// Logger is the global logger instance
	Logger *zap.Logger
)

// InitLogger initializes the global logger
func InitLogger(logDir string, logLevel string) error {
	// Create logs directory if it doesn't exist
	if err := os.MkdirAll(logDir, 0755); err != nil {
		return fmt.Errorf("failed to create logs directory: %v", err)
	}

	// Configure logging level
	var level zapcore.Level
	switch logLevel {
	case "debug":
		level = zapcore.DebugLevel
	case "info":
		level = zapcore.InfoLevel
	case "warn":
		level = zapcore.WarnLevel
	case "error":
		level = zapcore.ErrorLevel
	default:
		level = zapcore.InfoLevel
	}

	// Configure file output
	logFile := filepath.Join(logDir, fmt.Sprintf("avalanche-%s.log", time.Now().Format("20060102")))
	fileWriter := zapcore.AddSync(&lumberjack.Logger{
		Filename:   logFile,
		MaxSize:    100, // megabytes
		MaxBackups: 3,
		MaxAge:     28, // days
		Compress:   true,
	})

	// Configure console output
	consoleEncoder := zapcore.NewConsoleEncoder(zap.NewDevelopmentEncoderConfig())
	fileEncoder := zapcore.NewJSONEncoder(zap.NewProductionEncoderConfig())

	core := zapcore.NewTee(
		zapcore.NewCore(consoleEncoder, zapcore.AddSync(os.Stdout), level),
		zapcore.NewCore(fileEncoder, fileWriter, level),
	)

	Logger = zap.New(core)
	return nil
}

// Debug logs a message at debug level
func Debug(msg string, fields ...zapcore.Field) {
	Logger.Debug(msg, fields...)
}

// Info logs a message at info level
func Info(msg string, fields ...zapcore.Field) {
	Logger.Info(msg, fields...)
}

// Warn logs a message at warn level
func Warn(msg string, fields ...zapcore.Field) {
	Logger.Warn(msg, fields...)
}

// Error logs a message at error level
func Error(msg string, fields ...zapcore.Field) {
	Logger.Error(msg, fields...)
}

// Fatal logs a message at fatal level and then calls os.Exit(1)
func Fatal(msg string, fields ...zapcore.Field) {
	Logger.Fatal(msg, fields...)
}

// With creates a child logger with additional fields
func With(fields ...zapcore.Field) *zap.Logger {
	return Logger.With(fields...)
}

// Sync flushes any buffered log entries
func Sync() error {
	return Logger.Sync()
} 