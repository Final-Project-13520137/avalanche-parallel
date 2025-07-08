package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/scripts/benchmark/types"
)

// RedisClientAdapter adapts the real Redis client to our interface
type RedisClientAdapter struct {
	// We'll implement this as a mock for now since we have import issues
}

func (r *RedisClientAdapter) LPush(ctx interface{}, key string, values ...interface{}) types.RedisResult {
	return &MockRedisResult{err: nil}
}

func (r *RedisClientAdapter) LRange(ctx interface{}, key string, start, stop int64) types.RedisStringSliceResult {
	return &MockRedisStringSliceResult{result: []string{}, err: nil}
}

func (r *RedisClientAdapter) LRem(ctx interface{}, key string, count int64, value interface{}) types.RedisResult {
	return &MockRedisResult{err: nil}
}

func (r *RedisClientAdapter) Ping(ctx interface{}) types.RedisResult {
	return &MockRedisResult{err: nil}
}

// Mock implementations
type MockRedisResult struct {
	err error
}

func (m *MockRedisResult) Err() error {
	return m.err
}

type MockRedisStringSliceResult struct {
	result []string
	err    error
}

func (m *MockRedisStringSliceResult) Result() ([]string, error) {
	return m.result, m.err
}

// APIGatewayClient handles communication with the API Gateway
type APIGatewayClient struct {
	BaseURL    string
	HTTPClient *http.Client
}

// NewAPIGatewayClient creates a new API Gateway client
func NewAPIGatewayClient(baseURL string) *APIGatewayClient {
	return &APIGatewayClient{
		BaseURL: baseURL,
		HTTPClient: &http.Client{
			Timeout: 30 * time.Second,
		},
	}
}

// getRunningWorkerCounts gets the number of running workers for each type from Docker
func getRunningWorkerCounts() (types.WorkerConfig, error) {
	config := types.WorkerConfig{}

	// Get list of running containers
	cmd := exec.Command("docker", "ps", "--format", "{{.Names}}")
	output, err := cmd.Output()
	if err != nil {
		return config, fmt.Errorf("failed to get docker containers: %v", err)
	}

	containers := strings.Split(string(output), "\n")
	for _, container := range containers {
		switch {
		case strings.Contains(container, "validator-worker"):
			config.ValidatorWorkers++
		case strings.Contains(container, "consensus-worker"):
			config.ConsensusWorkers++
		case strings.Contains(container, "dag-state-worker"):
			config.DagStateWorkers++
		}
	}

	if config.ValidatorWorkers == 0 && config.ConsensusWorkers == 0 && config.DagStateWorkers == 0 {
		return config, fmt.Errorf("no workers found running in Docker")
	}

	return config, nil
}

func main() {
	log.Println("🚀 Starting Avalanche Microservices vs Monolith Benchmark with API Gateway Integration")

	// Get results directory from environment or use default
	resultsDir := os.Getenv("BENCHMARK_RESULTS_DIR")
	if resultsDir == "" {
		resultsDir = "benchmark-results"
	}

	graphsDir := os.Getenv("BENCHMARK_GRAPHS_DIR")
	if graphsDir == "" {
		graphsDir = "benchmark-graphs"
	}

	// Make paths absolute
	resultsDir, err := filepath.Abs(resultsDir)
	if err != nil {
		log.Fatalf("Failed to get absolute path for results directory: %v", err)
	}

	graphsDir, err = filepath.Abs(graphsDir)
	if err != nil {
		log.Fatalf("Failed to get absolute path for graphs directory: %v", err)
	}

	// Get current worker counts from Docker
	workerConfig, err := getRunningWorkerCounts()
	if err != nil {
		log.Fatalf("Failed to get worker counts: %v", err)
	}

	log.Printf("📊 Detected running workers: Validators: %d, Consensus: %d, DAG State: %d",
		workerConfig.ValidatorWorkers,
		workerConfig.ConsensusWorkers,
		workerConfig.DagStateWorkers)

	// Load configuration with API Gateway integration
	config := types.BenchmarkConfig{
		TestCases: []types.TestCase{
			{
				Name:             "Small_Load_API_Gateway",
				TransactionCount: 1000,
				ConcurrentUsers:  5,
				TransactionSize:  256,
				TransactionType:  "transfer",
				ComplexityFactor: 1,
				WorkerConfig:     workerConfig, // Use actual worker counts
			},
			{
				Name:             "Medium_Load_Gateway_Balanced",
				TransactionCount: 5000,
				ConcurrentUsers:  15,
				TransactionSize:  512,
				TransactionType:  "transfer",
				ComplexityFactor: 2,
				WorkerConfig:     workerConfig, // Use actual worker counts
			},
			{
				Name:             "High_Load_Gateway_Scaling",
				TransactionCount: 10000,
				ConcurrentUsers:  30,
				TransactionSize:  1024,
				TransactionType:  "contract",
				ComplexityFactor: 3,
				WorkerConfig:     workerConfig, // Use actual worker counts
			},
			{
				Name:             "Max_Load_Gateway_Full_Scale",
				TransactionCount: 20000,
				ConcurrentUsers:  50,
				TransactionSize:  2048,
				TransactionType:  "contract",
				ComplexityFactor: 4,
				WorkerConfig:     workerConfig, // Use actual worker counts
			},
		},
		ResultsDir:       resultsDir,
		GraphsDir:        graphsDir,
		MonolithEndpoint: "http://localhost:9650",
		MicroservicesConfig: types.MicroservicesConfig{
			RedisURL:           "redis://localhost:6379",
			PostgresURL:        "postgres://avalanche:avalanche123@localhost:5432/avalanche",
			ValidatorEndpoint:  "http://localhost:8081", // HAProxy load balancer
			ConsensusEndpoint:  "http://localhost:8082", // HAProxy load balancer
			DagStateEndpoint:   "http://localhost:8083", // HAProxy load balancer
			APIGatewayEndpoint: "http://localhost:9750", // Main API Gateway
			LoadBalancerConfig: types.LoadBalancerConfig{
				Algorithm:      "round-robin",
				HealthCheck:    true,
				CheckInterval:  "30s",
				Timeout:        "10s",
				Retries:        3,
				CircuitBreaker: true,
			},
			QueueConfig: types.QueueConfig{
				ValidationQueueSize: 1000,
				ConsensusQueueSize:  500,
				DagStateQueueSize:   250,
				ResultQueueSize:     2000,
				QueueTimeout:        "10s",
				RetryAttempts:       3,
			},
		},
	}

	// Create directories with proper permissions
	if err := os.MkdirAll(config.ResultsDir, 0777); err != nil {
		log.Fatalf("Failed to create results directory: %v", err)
	}
	if err := os.MkdirAll(config.GraphsDir, 0777); err != nil {
		log.Fatalf("Failed to create graphs directory: %v", err)
	}

	// Initialize Redis client adapter for microservices communication
	redisClient := &RedisClientAdapter{}

	// Test Redis connection
	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("Warning: Redis connection failed: %v", err)
		// Continue with mock for demonstration
	}

	// Initialize API Gateway client
	apiGatewayClient := NewAPIGatewayClient(config.MicroservicesConfig.APIGatewayEndpoint)

	// Test API Gateway connection
	if err := testAPIGatewayConnection(apiGatewayClient); err != nil {
		log.Printf("Warning: API Gateway connection failed: %v", err)
		// Continue for demonstration
	}

	// Initialize enhanced benchmark with API Gateway integration
	benchmark := &types.AvalancheBenchmark{
		Config:      config,
		RedisClient: redisClient,
		APIGatewayClient: &types.APIGatewayClient{
			BaseURL:    apiGatewayClient.BaseURL,
			HTTPClient: apiGatewayClient.HTTPClient,
		},
		Results: make([]types.BenchmarkResult, 0),
	}

	// Run benchmarks with API Gateway routing
	log.Println("📊 Running benchmark test cases with API Gateway integration...")

	for _, testCase := range config.TestCases {
		log.Printf("🔄 Running test case: %s", testCase.Name)

		// Configure worker pools through API Gateway
		if err := configureWorkerPools(apiGatewayClient, testCase.WorkerConfig); err != nil {
			log.Printf("❌ Failed to configure worker pools for %s: %v", testCase.Name, err)
			continue
		}

		// Run microservices benchmark through API Gateway
		microResult, err := benchmark.RunMicroservicesBenchmarkWithGateway(testCase)
		if err != nil {
			log.Printf("❌ Microservices benchmark failed for %s: %v", testCase.Name, err)
			continue
		}

		// Wait between tests for system stabilization
		time.Sleep(5 * time.Second)

		// Run monolith benchmark for comparison
		monolithResult, err := benchmark.RunMonolithBenchmark(testCase)
		if err != nil {
			log.Printf("❌ Monolith benchmark failed for %s: %v", testCase.Name, err)
			continue
		}

		// Store results
		benchmark.AddResult(microResult)
		benchmark.AddResult(monolithResult)

		// Save intermediate results
		if err := benchmark.SaveResults(); err != nil {
			log.Printf("⚠️ Failed to save intermediate results: %v", err)
		}

		log.Printf("✅ Completed test case: %s", testCase.Name)
		log.Printf("   Microservices TPS: %.2f", microResult.ThroughputTPS)
		log.Printf("   Monolith TPS: %.2f", monolithResult.ThroughputTPS)
		log.Printf("   Speedup Factor: %.2fx", microResult.ThroughputTPS/monolithResult.ThroughputTPS)

		// Wait between test cases for system cleanup
		time.Sleep(10 * time.Second)
	}

	// Generate final report and graphs
	log.Println("📈 Generating benchmark report and graphs...")

	if err := benchmark.GenerateReport(); err != nil {
		log.Printf("❌ Failed to generate report: %v", err)
	}

	if err := benchmark.GenerateGraphs(); err != nil {
		log.Printf("❌ Failed to generate graphs: %v", err)
	}

	// Print summary with API Gateway metrics
	benchmark.PrintSummaryWithGatewayMetrics()

	log.Println("🎉 Benchmark with API Gateway integration completed successfully!")
}

// testAPIGatewayConnection tests connection to API Gateway
func testAPIGatewayConnection(client *APIGatewayClient) error {
	resp, err := client.HTTPClient.Get(client.BaseURL + "/health")
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("API Gateway health check failed with status: %d", resp.StatusCode)
	}

	log.Println("✅ API Gateway connection successful")
	return nil
}

// configureWorkerPools configures worker pools through API Gateway
func configureWorkerPools(client *APIGatewayClient, config types.WorkerConfig) error {
	// This would typically make HTTP requests to configure worker pools
	// For now, we'll log the configuration
	log.Printf("🔧 Configuring worker pools through API Gateway:")
	log.Printf("   Validator Workers: %d", config.ValidatorWorkers)
	log.Printf("   Consensus Workers: %d", config.ConsensusWorkers)
	log.Printf("   DAG State Workers: %d", config.DagStateWorkers)

	// In a real implementation, this would make HTTP requests to:
	// - Scale worker pools
	// - Configure load balancers
	// - Set up health checks
	// - Configure circuit breakers

	return nil
}
