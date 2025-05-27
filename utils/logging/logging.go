package logging

type Logger interface {
	Debug(format string, args ...interface{})
	Info(format string, args ...interface{})
	Warn(format string, args ...interface{})
	Error(format string, args ...interface{})
	Fatal(format string, args ...interface{})
}

type Config struct {
	DisplayLevel string
}

type Factory struct {
	config Config
}

func NewFactory(config Config) *Factory {
	return &Factory{config: config}
}

func (f *Factory) Make(name string) (Logger, error) {
	return &dummyLogger{name: name}, nil
}

type dummyLogger struct {
	name string
}

func (l *dummyLogger) Debug(format string, args ...interface{}) {}
func (l *dummyLogger) Info(format string, args ...interface{}) {}
func (l *dummyLogger) Warn(format string, args ...interface{}) {}
func (l *dummyLogger) Error(format string, args ...interface{}) {}
func (l *dummyLogger) Fatal(format string, args ...interface{}) {} 