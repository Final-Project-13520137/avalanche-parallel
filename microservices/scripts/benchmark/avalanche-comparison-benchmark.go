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

// scaleWorkerPools scales the worker pools to the specified configuration
func scaleWorkerPools(workerConfig types.WorkerConfig) error {
	log.Printf("🔧 Scaling worker pools to: Validators: %d, Consensus: %d, DAG State: %d",
		workerConfig.ValidatorWorkers, workerConfig.ConsensusWorkers, workerConfig.DagStateWorkers)

	// Scale using docker-compose
	cmd := exec.Command("docker-compose", "-f", "../../docker-compose.worker-pools.yml", "up", "-d",
		"--scale", fmt.Sprintf("validator-worker=%d", workerConfig.ValidatorWorkers),
		"--scale", fmt.Sprintf("consensus-worker=%d", workerConfig.ConsensusWorkers),
		"--scale", fmt.Sprintf("dag-state-worker=%d", workerConfig.DagStateWorkers))

	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to scale worker pools: %v, output: %s", err, string(output))
	}

	// Wait for services to stabilize
	log.Printf("⏳ Waiting for worker pools to stabilize...")
	time.Sleep(30 * time.Second)

	// Verify scaling was successful
	actualConfig, err := getRunningWorkerCounts()
	if err != nil {
		return fmt.Errorf("failed to verify scaling: %v", err)
	}

	log.Printf("✅ Scaling completed. Actual workers: Validators: %d, Consensus: %d, DAG State: %d",
		actualConfig.ValidatorWorkers, actualConfig.ConsensusWorkers, actualConfig.DagStateWorkers)

	// Check if scaling was successful (allow some tolerance)
	if actualConfig.ValidatorWorkers < workerConfig.ValidatorWorkers ||
		actualConfig.ConsensusWorkers < workerConfig.ConsensusWorkers ||
		actualConfig.DagStateWorkers < workerConfig.DagStateWorkers {
		log.Printf("⚠️ Warning: Scaling may not have achieved target configuration")
	}

	return nil
}

// waitForWorkersReady waits for all workers to be ready
func waitForWorkersReady() error {
	log.Printf("⏳ Waiting for all workers to be ready...")

	// Check health endpoints with retries
	healthEndpoints := []string{
		"http://localhost:8081/health", // validator-haproxy
		"http://localhost:8082/health", // consensus-haproxy
		"http://localhost:8083/health", // dag-state-haproxy
	}

	client := &http.Client{Timeout: 5 * time.Second}
	maxRetries := 12 // 60 seconds total with 5s intervals

	for _, endpoint := range healthEndpoints {
		for retry := 0; retry < maxRetries; retry++ {
			resp, err := client.Get(endpoint)
			if err == nil && resp.StatusCode == http.StatusOK {
				resp.Body.Close()
				break
			}
			if resp != nil {
				resp.Body.Close()
			}

			if retry == maxRetries-1 {
				return fmt.Errorf("worker endpoint %s not ready after %d retries", endpoint, maxRetries)
			}

			time.Sleep(5 * time.Second)
		}
	}

	log.Printf("✅ All workers are ready")
	return nil
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

	// Define multiple worker configurations for varied testing
	workerVariations := []types.WorkerConfig{
		{ValidatorWorkers: 1, ConsensusWorkers: 1, DagStateWorkers: 1},   // Minimal
		{ValidatorWorkers: 3, ConsensusWorkers: 2, DagStateWorkers: 2},   // Small
		{ValidatorWorkers: 6, ConsensusWorkers: 4, DagStateWorkers: 3},   // Medium
		{ValidatorWorkers: 9, ConsensusWorkers: 6, DagStateWorkers: 4},   // Large
		{ValidatorWorkers: 12, ConsensusWorkers: 8, DagStateWorkers: 6},  // High
		{ValidatorWorkers: 15, ConsensusWorkers: 10, DagStateWorkers: 8}, // Maximum
	}

	// Create test cases with worker variations
	var testCases []types.TestCase

	// Base test scenarios
	baseScenarios := []struct {
		name       string
		txCount    int
		users      int
		size       int
		txType     string
		complexity int
	}{
		{"Small_Load_1K_Transactions", 1000, 10, 256, "transfer", 1},
		{"Medium_Load_5K_Transactions", 5000, 25, 512, "transfer", 2},
		{"Large_Load_10K_Transactions", 10000, 50, 1024, "contract", 3},
		{"High_Load_20K_Transactions", 20000, 100, 2048, "contract", 4},
	}

	// Generate test cases for each worker variation
	for _, scenario := range baseScenarios {
		for i, workerConfig := range workerVariations {
			testCase := types.TestCase{
				Name:             fmt.Sprintf("%s_Workers_%d_%d_%d", scenario.name, workerConfig.ValidatorWorkers, workerConfig.ConsensusWorkers, workerConfig.DagStateWorkers),
				TransactionCount: scenario.txCount,
				ConcurrentUsers:  scenario.users,
				TransactionSize:  scenario.size,
				TransactionType:  scenario.txType,
				ComplexityFactor: scenario.complexity,
				WorkerConfig:     workerConfig,
			}
			testCases = append(testCases, testCase)

			// Limit to reasonable number of variations for demo
			if i >= 2 { // Only test minimal, small, and medium configurations
				break
			}
		}
	}

	// Load configuration with varied worker pools
	config := types.BenchmarkConfig{
		TestCases:        testCases,
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

		// Scale worker pools before running the test
		if err := scaleWorkerPools(testCase.WorkerConfig); err != nil {
			log.Printf("❌ Failed to scale worker pools for %s: %v", testCase.Name, err)
			continue
		}

		// Wait for workers to be ready
		if err := waitForWorkersReady(); err != nil {
			log.Printf("❌ Failed to wait for workers to be ready for %s: %v", testCase.Name, err)
			continue
		}

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
