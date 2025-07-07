package types

import (
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/go-redis/redis/v8"
)

// AvalancheBenchmark handles benchmark execution and result collection
type AvalancheBenchmark struct {
	Config       BenchmarkConfig
	RedisClient  *redis.Client
	Results      []BenchmarkResult
	ResultsMutex sync.RWMutex
}

// BenchmarkConfig holds configuration for benchmark tests
type BenchmarkConfig struct {
	TestCases           []TestCase `json:"test_cases"`
	WarmupTransactions  int        `json:"warmup_transactions"`
	MeasurementDuration int        `json:"measurement_duration_seconds"`
	ResultsDir          string     `json:"results_dir"`
	GraphsDir           string     `json:"graphs_dir"`
}

// TestCase defines a specific benchmark scenario
type TestCase struct {
	Name             string `json:"name"`
	TransactionCount int    `json:"transaction_count"`
	ConcurrentUsers  int    `json:"concurrent_users"`
	TransactionSize  int    `json:"transaction_size_bytes"`
	TransactionType  string `json:"transaction_type"`
	ComplexityFactor int    `json:"complexity_factor"`
}

// BenchmarkResult stores results from a benchmark run
type BenchmarkResult struct {
	TestCase           TestCase      `json:"test_case"`
	Architecture       string        `json:"architecture"`
	TotalTransactions  int           `json:"total_transactions"`
	SuccessfulTxs      int           `json:"successful_transactions"`
	FailedTxs          int           `json:"failed_transactions"`
	TotalDuration      time.Duration `json:"total_duration_ms"`
	AverageLatency     time.Duration `json:"average_latency_ms"`
	MedianLatency      time.Duration `json:"median_latency_ms"`
	P95Latency         time.Duration `json:"p95_latency_ms"`
	P99Latency         time.Duration `json:"p99_latency_ms"`
	ThroughputTPS      float64       `json:"throughput_tps"`
	CPUUsagePercent    float64       `json:"cpu_usage_percent"`
	MemoryUsageMB      float64       `json:"memory_usage_mb"`
	NetworkBandwidthMB float64       `json:"network_bandwidth_mb"`
	ErrorRate          float64       `json:"error_rate_percent"`
	ConsensusTime      time.Duration `json:"consensus_time_ms"`
	ValidationTime     time.Duration `json:"validation_time_ms"`
	StateUpdateTime    time.Duration `json:"state_update_time_ms"`
	Timestamp          time.Time     `json:"timestamp"`
}

// Transaction represents a test transaction
type Transaction struct {
	ID        ids.ID    `json:"id"`
	From      string    `json:"from"`
	To        string    `json:"to"`
	Amount    uint64    `json:"amount"`
	Data      []byte    `json:"data"`
	Nonce     uint64    `json:"nonce"`
	Timestamp time.Time `json:"timestamp"`
	Size      int       `json:"size"`
}

// WorkerNodeInfo tracks worker node status
type WorkerNodeInfo struct {
	ID         string    `json:"id"`
	Type       string    `json:"type"`
	Status     string    `json:"status"`
	LastSeen   time.Time `json:"last_seen"`
	TasksCount int64     `json:"tasks_count"`
}
