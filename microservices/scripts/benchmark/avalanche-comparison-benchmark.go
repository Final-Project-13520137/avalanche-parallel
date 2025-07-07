package main

import (
	"context"
	"log"
	"os"
	"path/filepath"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/scripts/benchmark/types"
	"github.com/go-redis/redis/v8"
)

func main() {
	log.Println("🚀 Starting Avalanche Microservices vs Monolith Benchmark")

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

	// Load configuration
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
			// {
			// 	Name:             "Medium_Load_5K_Transactions",
			// 	TransactionCount: 5000,
			// 	ConcurrentUsers:  25,
			// 	TransactionSize:  512,
			// 	TransactionType:  "transfer",
			// 	ComplexityFactor: 2,
			// },
			// {
			// 	Name:             "Large_Load_10K_Transactions",
			// 	TransactionCount: 10000,
			// 	ConcurrentUsers:  50,
			// 	TransactionSize:  1024,
			// 	TransactionType:  "contract",
			// 	ComplexityFactor: 3,
			// },
			// {
			// 	Name:             "High_Load_20K_Transactions",
			// 	TransactionCount: 20000,
			// 	ConcurrentUsers:  100,
			// 	TransactionSize:  2048,
			// 	TransactionType:  "contract",
			// 	ComplexityFactor: 4,
			// },
		},
		ResultsDir:       resultsDir,
		GraphsDir:        graphsDir,
		MonolithEndpoint: "http://localhost:9650",
		MicroservicesConfig: types.MicroservicesConfig{
			RedisURL:           "redis://localhost:6379",
			PostgresURL:        "postgres://avalanche:avalanche123@localhost:5432/avalanche",
			ValidatorEndpoint:  "http://localhost:8081",
			ConsensusEndpoint:  "http://localhost:8082",
			DagStateEndpoint:   "http://localhost:8083",
			APIGatewayEndpoint: "http://localhost:9750",
		},
	}

	// Create directories with proper permissions
	if err := os.MkdirAll(config.ResultsDir, 0777); err != nil {
		log.Fatalf("Failed to create results directory: %v", err)
	}
	if err := os.MkdirAll(config.GraphsDir, 0777); err != nil {
		log.Fatalf("Failed to create graphs directory: %v", err)
	}

	// Initialize Redis client for microservices communication
	redisClient := redis.NewClient(&redis.Options{
		Addr: "localhost:6379",
	})

	// Test Redis connection
	ctx := context.Background()
	if err := redisClient.Ping(ctx).Err(); err != nil {
		log.Fatalf("Failed to connect to Redis: %v", err)
	}

	// Initialize benchmark
	benchmark := &types.AvalancheBenchmark{
		Config:      config,
		RedisClient: redisClient,
		Results:     make([]types.BenchmarkResult, 0),
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

		// Wait between tests
		// time.Sleep(5 * time.Second)

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

		// Wait between test cases
		// time.Sleep(10 * time.Second)
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
