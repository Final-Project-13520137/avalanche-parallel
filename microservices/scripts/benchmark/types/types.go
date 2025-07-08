package types

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"sync"
	"time"
)

// RedisClient interface to avoid import issues
type RedisClient interface {
	LPush(ctx interface{}, key string, values ...interface{}) RedisResult
	LRange(ctx interface{}, key string, start, stop int64) RedisStringSliceResult
	LRem(ctx interface{}, key string, count int64, value interface{}) RedisResult
	Ping(ctx interface{}) RedisResult
}

// RedisResult interface for Redis command results
type RedisResult interface {
	Err() error
}

// RedisStringSliceResult interface for Redis string slice results
type RedisStringSliceResult interface {
	Result() ([]string, error)
}

// SimpleID represents a simple ID type instead of avalanchego IDs
type SimpleID struct {
	bytes [32]byte
}

// String returns the hex representation of the ID
func (id SimpleID) String() string {
	return hex.EncodeToString(id.bytes[:])
}

// GenerateTestID creates a new random ID for testing
func GenerateTestID() SimpleID {
	var id SimpleID
	rand.Read(id.bytes[:])
	return id
}

// APIGatewayClient handles communication with the API Gateway
type APIGatewayClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

// AvalancheBenchmark handles benchmark execution and result collection
type AvalancheBenchmark struct {
	Config           BenchmarkConfig
	RedisClient      RedisClient
	APIGatewayClient *APIGatewayClient
	Results          []BenchmarkResult
	ResultsMutex     sync.RWMutex
}

// BenchmarkConfig holds configuration for benchmark tests
type BenchmarkConfig struct {
	TestCases           []TestCase `json:"test_cases"`
	WarmupTransactions  int        `json:"warmup_transactions"`
	MeasurementDuration int        `json:"measurement_duration_seconds"`
	ResultsDir          string     `json:"results_dir"`
	GraphsDir           string     `json:"graphs_dir"`
	MonolithEndpoint    string     `json:"monolith_endpoint"`
	MicroservicesConfig MicroservicesConfig
}

// TestCase defines a benchmark test case
type TestCase struct {
	Name             string
	TransactionCount int
	ConcurrentUsers  int
	TransactionSize  int
	TransactionType  string
	ComplexityFactor int
	WorkerConfig     WorkerConfig
}

// WorkerConfig defines the worker pool configuration
type WorkerConfig struct {
	ValidatorWorkers int
	ConsensusWorkers int
	DagStateWorkers  int
}

// BenchmarkResult stores results from a benchmark run
type BenchmarkResult struct {
	TestCase             TestCase      `json:"test_case"`
	Architecture         string        `json:"architecture"`
	TotalTransactions    int           `json:"total_transactions"`
	SuccessfulTxs        int           `json:"successful_transactions"`
	FailedTxs            int           `json:"failed_transactions"`
	TotalDuration        time.Duration `json:"total_duration_ms"`
	AverageLatency       time.Duration `json:"average_latency_ms"`
	MedianLatency        time.Duration `json:"median_latency_ms"`
	P95Latency           time.Duration `json:"p95_latency_ms"`
	P99Latency           time.Duration `json:"p99_latency_ms"`
	ThroughputTPS        float64       `json:"throughput_tps"`
	CPUUsagePercent      float64       `json:"cpu_usage_percent"`
	MemoryUsageMB        float64       `json:"memory_usage_mb"`
	NetworkBandwidthMB   float64       `json:"network_bandwidth_mb"`
	ErrorRate            float64       `json:"error_rate_percent"`
	ConsensusTime        time.Duration `json:"consensus_time_ms"`
	ValidationTime       time.Duration `json:"validation_time_ms"`
	StateUpdateTime      time.Duration `json:"state_update_time_ms"`
	ConsensusStartTime   time.Time     `json:"consensus_start_time"`
	ConsensusEndTime     time.Time     `json:"consensus_end_time"`
	ValidationStartTime  time.Time     `json:"validation_start_time"`
	ValidationEndTime    time.Time     `json:"validation_end_time"`
	StateUpdateStartTime time.Time     `json:"state_update_start_time"`
	StateUpdateEndTime   time.Time     `json:"state_update_end_time"`
	Timestamp            time.Time     `json:"timestamp"`
}

// Transaction represents a test transaction
type Transaction struct {
	ID        SimpleID  `json:"id"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	Amount    uint64    `json:"amount"`
	Data      []byte    `json:"data"`
	Nonce     uint64    `json:"nonce"`
	Timestamp time.Time `json:"timestamp"`
	Size      int       `json:"size"`
	Metrics   *TransactionMetrics
}

// TransactionMetrics stores timing information for transaction processing
type TransactionMetrics struct {
	GatewayStartTime     time.Time
	ValidationStartTime  time.Time
	ValidationEndTime    time.Time
	ConsensusStartTime   time.Time
	ConsensusEndTime     time.Time
	StateUpdateStartTime time.Time
	StateUpdateEndTime   time.Time
}

// WorkerNodeInfo tracks worker node status
type WorkerNodeInfo struct {
	ID         string    `json:"id"`
	Type       string    `json:"type"`
	Status     string    `json:"status"`
	LastSeen   time.Time `json:"last_seen"`
	TasksCount int64     `json:"tasks_count"`
}

// TaskResult represents the result of a worker task
type TaskResult struct {
	TaskID    string
	Success   bool
	Error     string
	Timestamp time.Time
}

// WorkerMetrics represents resource usage metrics for a worker
type WorkerMetrics struct {
	WorkerID           string
	CPUPercent         float64
	MemoryUsageMB      float64
	NetworkBandwidthMB float64
	Timestamp          time.Time
}

// WorkerPoolMetrics represents metrics for all workers
type WorkerPoolMetrics struct {
	Workers   []WorkerMetrics
	Timestamp time.Time
}

// MonolithMetrics represents resource usage metrics for monolith node
type MonolithMetrics struct {
	CPUPercent         float64
	MemoryUsageMB      float64
	NetworkBandwidthMB float64
	Timestamp          time.Time
}

// MicroservicesConfig defines configuration for microservices architecture
type MicroservicesConfig struct {
	RedisURL           string
	PostgresURL        string
	ValidatorEndpoint  string
	ConsensusEndpoint  string
	DagStateEndpoint   string
	APIGatewayEndpoint string
	LoadBalancerConfig LoadBalancerConfig
	QueueConfig        QueueConfig
}

// LoadBalancerConfig defines load balancer settings
type LoadBalancerConfig struct {
	Algorithm      string
	HealthCheck    bool
	CheckInterval  string
	Timeout        string
	Retries        int
	CircuitBreaker bool
}

// QueueConfig defines message queue settings
type QueueConfig struct {
	ValidationQueueSize int
	ConsensusQueueSize  int
	DagStateQueueSize   int
	ResultQueueSize     int
	QueueTimeout        string
	RetryAttempts       int
}
