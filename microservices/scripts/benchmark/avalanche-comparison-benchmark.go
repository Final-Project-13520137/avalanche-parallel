package main

import (
	"context"
	"log"
	"os"
	"sync"
	"time"

	"benchmark/types"

	"github.com/go-redis/redis/v8"
)

// ParallelBenchmark handles parallel processing with worker nodes
type ParallelBenchmark struct {
	redisClient *redis.Client
	workerNodes map[string]types.WorkerNodeInfo
	nodeMutex   sync.RWMutex
	results     chan types.BenchmarkResult
	errors      chan error
}

func main() {
	log.Println("🚀 Starting Avalanche Microservices vs Monolith Benchmark")

	// Load configuration
	config, err := loadBenchmarkConfig()
	if err != nil {
		log.Fatalf("Failed to load benchmark config: %v", err)
	}

	// Initialize benchmark
	benchmark, err := NewAvalancheBenchmark(config)
	if err != nil {
		log.Fatalf("Failed to initialize benchmark: %v", err)
	}

	// Create results directories
	if err := createDirectories(config); err != nil {
		log.Fatalf("Failed to create directories: %v", err)
	}

	// Run benchmarks
	log.Println("📊 Running benchmark test cases...")

	for _, testCase := range config.TestCases {
		log.Printf("🔄 Running test case: %s", testCase.Name)

		// Run microservices benchmark
		microResult, err := benchmark.RunMicroservicesBenchmark(testCase)
		if err != nil {
			log.Printf("❌ Microservices benchmark failed for %s: %v", testCase.Name, err)
			continue
		}

		// Run monolith benchmark
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

		// Wait between test cases to allow system recovery
		time.Sleep(30 * time.Second)
	}

	// Generate final report and graphs
	log.Println("📈 Generating benchmark report and graphs...")

	if err := benchmark.GenerateReport(); err != nil {
		log.Printf("❌ Failed to generate report: %v", err)
	}

	if err := benchmark.GenerateGraphs(); err != nil {
		log.Printf("❌ Failed to generate graphs: %v", err)
	}

	// Print summary
	benchmark.PrintSummary()

	log.Println("🎉 Benchmark completed successfully!")
}

// NewAvalancheBenchmark creates a new benchmark instance
func NewAvalancheBenchmark(config types.BenchmarkConfig) (*types.AvalancheBenchmark, error) {
	// Initialize Redis client for microservices communication
	redisClient := redis.NewClient(&redis.Options{
		Addr:     "localhost:6379",
		Password: "",
		DB:       0,
	})

	// Test Redis connection
	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Printf("⚠️ Redis not available, some features may be limited: %v", err)
	}

	return &types.AvalancheBenchmark{
		Config:      config,
		RedisClient: redisClient,
		Results:     make([]types.BenchmarkResult, 0),
	}, nil
}

// loadBenchmarkConfig loads configuration from file or creates default
func loadBenchmarkConfig() (types.BenchmarkConfig, error) {
	config := types.BenchmarkConfig{
		TestCases: []types.TestCase{
			{
				Name:             "Small_Load_1K_Transactions",
				TransactionCount: 1000,
				ConcurrentUsers:  10,
				TransactionSize:  256,
				TransactionType:  "transfer",
				ComplexityFactor: 1,
			},
			{
				Name:             "Medium_Load_5K_Transactions",
				TransactionCount: 5000,
				ConcurrentUsers:  25,
				TransactionSize:  512,
				TransactionType:  "transfer",
				ComplexityFactor: 2,
			},
			{
				Name:             "Large_Load_10K_Transactions",
				TransactionCount: 10000,
				ConcurrentUsers:  50,
				TransactionSize:  1024,
				TransactionType:  "contract",
				ComplexityFactor: 3,
			},
			{
				Name:             "High_Load_20K_Transactions",
				TransactionCount: 20000,
				ConcurrentUsers:  100,
				TransactionSize:  2048,
				TransactionType:  "contract",
				ComplexityFactor: 4,
			},
		},
		WarmupTransactions:  100,
		MeasurementDuration: 300,
		ResultsDir:          "benchmark-results",
		GraphsDir:           "benchmark-graphs",
	}

	return config, nil
}

// createDirectories creates necessary directories for results
func createDirectories(config types.BenchmarkConfig) error {
	dirs := []string{config.ResultsDir, config.GraphsDir}

	for _, dir := range dirs {
		if err := os.MkdirAll(dir, 0755); err != nil {
			return err
		}
	}

	return nil
}
