// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

// This is a standalone script to test the blockchain with various transaction conditions
// Run with: go run transaction_load_test.go

package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

const (
	// Test parameters
	numUsers               = 200
	numTransactions        = 5000
	maxConcurrentSubmit    = 250
	transactionDelayMs     = 5
	doubleSpendProbability = 0.05
	blockInterval          = 1 * time.Second
	largeValueProbability  = 0.2
	microValueProbability  = 0.1
	runTime                = 2 * time.Minute
)

var (
	// User accounts
	users = []string{
		"alice", "bob", "charlie", "dave", "eve",
		"frank", "grace", "heidi", "ivan", "judy",
	}

	// Extended user list for more realistic testing
	extendedUsers []string
)

// Type alias to make the code easier to update
type ID = ids.ID

// generateExtendedUsers creates a larger set of users for testing
func generateExtendedUsers() {
	for i := 0; i < numUsers; i++ {
		if i < len(users) {
			extendedUsers = append(extendedUsers, users[i])
		} else {
			extendedUsers = append(extendedUsers, fmt.Sprintf("user%d", i))
		}
	}
}

func main() {
	// Parse command line flags
	parallel := flag.Bool("parallel", true, "Use parallel processing")
	numThreads := flag.Int("threads", 4, "Number of threads for parallel processing")
	numTransactions := flag.Int("transactions", 5000, "Number of transactions to test")
	batchSize := flag.Int("batch", 50, "Number of transactions per block")
	benchmark := flag.Bool("benchmark", false, "Run parallel vs traditional benchmark")
	scenarioTest := flag.Bool("scenarios", false, "Run different transaction scenarios")
	transactionSize := flag.String("tx-size", "mixed", "Transaction size profile: small, medium, large, or mixed")
	flag.Parse()

	fmt.Println("=== Avalanche Transaction Load Test ===")

	// Generate extended users
	generateExtendedUsers()

	if *benchmark {
		runBenchmark(*numTransactions, *batchSize, *transactionSize)
		return
	}

	if *scenarioTest {
		runScenarioTests()
		return
	}

	// Create logger
	logger := &testLogger{}

	// Create blockchain with specified number of threads
	threads := 1
	if *parallel {
		threads = *numThreads
	}

	fmt.Printf("Creating blockchain with %d threads\n", threads)
	bc, err := blockchain.NewBlockchain(logger, threads)
	if err != nil {
		log.Fatalf("Failed to create blockchain: %v", err)
	}

	// Create test transactions
	fmt.Printf("Generating %d test transactions...\n", *numTransactions)
	transactions := createTestTransactions(*numTransactions)

	// Process transactions
	fmt.Println("Processing transactions...")
	start := time.Now()

	// Add transactions to blockchain
	for _, tx := range transactions {
		err = bc.AddTransaction(tx)
		if err != nil {
			log.Printf("Warning: Failed to add transaction: %v", err)
		}
	}

	// Create blocks until all transactions are processed
	parentIDs := []ids.ID{getGenesisBlockID(bc)}
	blockCount := 0

	for getTxPoolSize(bc) > 0 {
		block, err := bc.CreateBlock(parentIDs, *batchSize)
		if err != nil {
			log.Printf("Warning: Failed to create block: %v", err)
			continue
		}

		err = bc.SubmitBlock(block)
		if err != nil {
			log.Printf("Warning: Failed to submit block: %v", err)
			continue
		}

		err = bc.ProcessPendingBlocks()
		if err != nil {
			log.Printf("Warning: Failed to process blocks: %v", err)
		}

		parentIDs = []ids.ID{block.ID()}
		blockCount++
	}

	duration := time.Since(start)
	txPerSecond := float64(*numTransactions) / duration.Seconds()

	// Output results
	fmt.Println("\n=== Results ===")
	fmt.Printf("Processing mode: %s\n", modeString(*parallel, threads))
	fmt.Printf("Total transactions: %d\n", *numTransactions)
	fmt.Printf("Blocks created: %d\n", blockCount)
	fmt.Printf("Processing time: %v\n", duration)
	fmt.Printf("Transactions per second: %.2f\n", txPerSecond)
}

func runBenchmark(numTransactions, batchSize int, sizeProfile string) {
	fmt.Println("=== Parallel vs Traditional Benchmark ===")
	fmt.Printf("Transaction size profile: %s\n", sizeProfile)
	fmt.Printf("Number of transactions: %d\n", numTransactions)
	fmt.Printf("Batch size: %d\n", batchSize)

	// Create loggers
	parallelLogger := &testLogger{}
	sequentialLogger := &testLogger{}

	// Create parallel blockchain with different thread counts to test scaling
	threadCounts := []int{1, 2, 4, 8}
	parallelResults := make(map[int]time.Duration)
	parallelThroughput := make(map[int]float64)
	
	// First test sequential (1 thread) as baseline
	fmt.Println("\nRunning baseline sequential processing (1 thread)...")
	bcSequential, err := blockchain.NewBlockchain(sequentialLogger, 1)
	if err != nil {
		log.Fatalf("Failed to create sequential blockchain: %v", err)
	}
	
	// Create test transactions based on size profile
	fmt.Printf("Generating %d test transactions with %s profile...\n", numTransactions, sizeProfile)
	transactions := createProfiledTransactions(numTransactions, sizeProfile)
	
	// Clone transactions for sequential blockchain
	sequentialTxs := cloneTransactions(transactions)
	
	// Process with sequential blockchain
	sequentialStart := time.Now()
	processTransactions(bcSequential, sequentialTxs, batchSize)
	sequentialDuration := time.Since(sequentialStart)
	sequentialTxPerSecond := float64(numTransactions) / sequentialDuration.Seconds()
	
	// Store baseline result
	parallelResults[1] = sequentialDuration
	parallelThroughput[1] = sequentialTxPerSecond
	
	// Now test with various thread counts
	for _, threads := range threadCounts {
		if threads == 1 {
			continue // Already tested
		}
		
		fmt.Printf("\nRunning parallel processing with %d threads...\n", threads)
		bcParallel, err := blockchain.NewBlockchain(parallelLogger, threads)
		if err != nil {
			log.Fatalf("Failed to create parallel blockchain with %d threads: %v", threads, err)
			continue
		}
		
		// Clone transactions
		parallelTxs := cloneTransactions(transactions)
		
		// Process with parallel blockchain
		parallelStart := time.Now()
		processTransactions(bcParallel, parallelTxs, batchSize)
		parallelDuration := time.Since(parallelStart)
		parallelTxPerSecond := float64(numTransactions) / parallelDuration.Seconds()
		
		// Store results
		parallelResults[threads] = parallelDuration
		parallelThroughput[threads] = parallelTxPerSecond
	}
	
	// Output results
	fmt.Println("\n=== Benchmark Results ===")
	
	// Calculate speedups relative to sequential
	speedups := make(map[int]float64)
	for threads, duration := range parallelResults {
		if threads == 1 {
			speedups[threads] = 1.0 // Baseline
		} else {
			speedups[threads] = float64(parallelResults[1]) / float64(duration)
		}
	}
	
	// Print results table
	fmt.Println("\n| Threads | Processing Time | Transactions/sec | Speedup |")
	fmt.Println("|---------|----------------|-----------------|---------|")
	
	for _, threads := range threadCounts {
		fmt.Printf("| %7d | %14v | %15.2f | %7.2fx |\n", 
			threads, 
			parallelResults[threads], 
			parallelThroughput[threads],
			speedups[threads])
	}
	
	// Save detailed results to file
	saveDetailedResults(parallelResults, parallelThroughput, speedups, 
		threadCounts, numTransactions, sizeProfile, batchSize)
}

// Create transactions with different size profiles
func createProfiledTransactions(count int, sizeProfile string) []*blockchain.Transaction {
	transactions := make([]*blockchain.Transaction, count)
	
	for i := 0; i < count; i++ {
		sender := fmt.Sprintf("user%d", i%numUsers)
		recipient := fmt.Sprintf("recipient%d", (i+50)%numUsers)
		
		// Determine amount based on size profile
		var amount uint64
		switch sizeProfile {
		case "small":
			amount = 1 + uint64(rand.Intn(99))
		case "medium":
			amount = 100 + uint64(rand.Intn(900))
		case "large":
			amount = 10000 + uint64(rand.Intn(990000))
		case "mixed":
			// Default mixed profile with 20% large, 70% medium, 10% small
			r := rand.Float64()
			if r < 0.1 {
				amount = 1 + uint64(rand.Intn(99)) // Small
			} else if r < 0.8 {
				amount = 100 + uint64(rand.Intn(900)) // Medium
			} else {
				amount = 10000 + uint64(rand.Intn(990000)) // Large
			}
		default:
			amount = 100 + uint64(rand.Intn(900)) // Default medium
		}
		
		nonce := uint64(i)
		
		tx, err := blockchain.NewTransaction(sender, recipient, amount, nonce)
		if err != nil {
			log.Fatalf("Failed to create transaction: %v", err)
		}
		
		err = tx.SignTransaction([]byte("test-key"))
		if err != nil {
			log.Fatalf("Failed to sign transaction: %v", err)
		}
		
		transactions[i] = tx
	}
	
	return transactions
}

// Run different transaction scenarios
func runScenarioTests() {
	fmt.Println("=== Running Transaction Scenario Tests ===")
	
	// Define scenarios to test
	scenarios := []struct {
		name           string
		txCount        int
		threads        int
		batchSize      int
		sizeProfile    string
	}{
		{"Small Transactions/Single Thread", 2000, 1, 20, "small"},
		{"Small Transactions/4 Threads", 2000, 4, 20, "small"},
		{"Medium Transactions/Single Thread", 2000, 1, 20, "medium"},
		{"Medium Transactions/4 Threads", 2000, 4, 20, "medium"},
		{"Large Transactions/Single Thread", 2000, 1, 20, "large"},
		{"Large Transactions/4 Threads", 2000, 4, 20, "large"},
		{"Mixed Transactions/Single Thread", 2000, 1, 20, "mixed"},
		{"Mixed Transactions/4 Threads", 2000, 4, 20, "mixed"},
		{"High Volume/Single Thread", 10000, 1, 100, "mixed"},
		{"High Volume/4 Threads", 10000, 4, 100, "mixed"},
		{"High Volume/8 Threads", 10000, 8, 100, "mixed"},
	}
	
	// Store results
	results := make(map[string]struct {
		duration    time.Duration
		throughput  float64
	})
	
	// Run each scenario
	for _, scenario := range scenarios {
		fmt.Printf("\nRunning scenario: %s\n", scenario.name)
		fmt.Printf("  Transactions: %d, Threads: %d, Batch Size: %d, Profile: %s\n", 
			scenario.txCount, scenario.threads, scenario.batchSize, scenario.sizeProfile)
		
		// Create logger
		logger := &testLogger{}
		
		// Create blockchain
		bc, err := blockchain.NewBlockchain(logger, scenario.threads)
		if err != nil {
			log.Printf("Failed to create blockchain for scenario %s: %v", scenario.name, err)
			continue
		}
		
		// Create transactions
		transactions := createProfiledTransactions(scenario.txCount, scenario.sizeProfile)
		
		// Process transactions
		start := time.Now()
		processTransactions(bc, transactions, scenario.batchSize)
		duration := time.Since(start)
		
		// Calculate throughput
		throughput := float64(scenario.txCount) / duration.Seconds()
		
		// Store results
		results[scenario.name] = struct {
			duration    time.Duration
			throughput  float64
		}{duration, throughput}
		
		fmt.Printf("  Processing time: %v\n", duration)
		fmt.Printf("  Throughput: %.2f tx/s\n", throughput)
	}
	
	// Display summary table
	fmt.Println("\n=== Scenario Test Results ===")
	fmt.Println("\n| Scenario | Processing Time | Transactions/sec |")
	fmt.Println("|----------|----------------|-----------------|")
	
	for _, scenario := range scenarios {
		result := results[scenario.name]
		fmt.Printf("| %-40s | %14v | %15.2f |\n", 
			scenario.name, result.duration, result.throughput)
	}
	
	// Calculate speedups for same workloads with different thread counts
	fmt.Println("\n=== Parallel Speedups ===")
	fmt.Println("\n| Workload | Sequential | Parallel | Speedup |")
	fmt.Println("|----------|------------|----------|---------|")
	
	speedupPairs := []struct {
		workload    string
		seqScenario string
		parScenario string
	}{
		{"Small Transactions", "Small Transactions/Single Thread", "Small Transactions/4 Threads"},
		{"Medium Transactions", "Medium Transactions/Single Thread", "Medium Transactions/4 Threads"},
		{"Large Transactions", "Large Transactions/Single Thread", "Large Transactions/4 Threads"},
		{"Mixed Transactions", "Mixed Transactions/Single Thread", "Mixed Transactions/4 Threads"},
		{"High Volume", "High Volume/Single Thread", "High Volume/4 Threads"},
	}
	
	for _, pair := range speedupPairs {
		seqResult := results[pair.seqScenario]
		parResult := results[pair.parScenario]
		speedup := float64(seqResult.duration) / float64(parResult.duration)
		
		fmt.Printf("| %-16s | %10v | %8v | %7.2fx |\n",
			pair.workload, seqResult.duration, parResult.duration, speedup)
	}
	
	// Save scenario results
	saveScenarioResults(scenarios, results)
}

func processTransactions(bc *blockchain.Blockchain, transactions []*blockchain.Transaction, batchSize int) {
	// Add transactions to blockchain
	for _, tx := range transactions {
		bc.AddTransaction(tx)
	}

	// Create blocks until all transactions are processed
	parentIDs := []ids.ID{getGenesisBlockID(bc)}
	
	for getTxPoolSize(bc) > 0 {
		block, _ := bc.CreateBlock(parentIDs, batchSize)
		bc.SubmitBlock(block)
		bc.ProcessPendingBlocks()
		parentIDs = []ids.ID{block.ID()}
	}
}

func createTestTransactions(count int) []*blockchain.Transaction {
	transactions := make([]*blockchain.Transaction, count)
	for i := 0; i < count; i++ {
		sender := fmt.Sprintf("user%d", i%100)
		recipient := fmt.Sprintf("recipient%d", (i+50)%100)
		amount := uint64(100 + i%900)
		nonce := uint64(i)
		
		tx, err := blockchain.NewTransaction(sender, recipient, amount, nonce)
		if err != nil {
			log.Fatalf("Failed to create transaction: %v", err)
		}
		
		err = tx.SignTransaction([]byte("test-key"))
		if err != nil {
			log.Fatalf("Failed to sign transaction: %v", err)
		}
		
		transactions[i] = tx
	}
	return transactions
}

func cloneTransactions(original []*blockchain.Transaction) []*blockchain.Transaction {
	cloned := make([]*blockchain.Transaction, len(original))
	for i, tx := range original {
		clonedTx, _ := blockchain.NewTransaction(tx.Sender, tx.Recipient, tx.Amount, tx.Nonce)
		clonedTx.SignTransaction([]byte("test-key"))
		cloned[i] = clonedTx
	}
	return cloned
}

func modeString(parallel bool, threads int) string {
	if parallel {
		return fmt.Sprintf("Parallel (%d threads)", threads)
	}
	return "Sequential (1 thread)"
}

func saveDetailedResults(times map[int]time.Duration, throughputs map[int]float64, 
                        speedups map[int]float64, threadCounts []int, numTransactions int,
                        sizeProfile string, batchSize int) {
	
	// Create results directory if it doesn't exist
	resultsDir := "benchmark-results"
	if _, err := os.Stat(resultsDir); os.IsNotExist(err) {
		os.Mkdir(resultsDir, 0755)
	}
	
	// Create results file
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	filename := fmt.Sprintf("%s/scaling-benchmark-%s.md", resultsDir, timestamp)
	
	file, err := os.Create(filename)
	if err != nil {
		log.Printf("Failed to create results file: %v", err)
		return
	}
	defer file.Close()
	
	// Write results
	fmt.Fprintf(file, "# Avalanche Parallel Scaling Benchmark Results\n\n")
	fmt.Fprintf(file, "## Test Information\n")
	fmt.Fprintf(file, "- **Date:** %s\n", time.Now().Format("2006-01-02 15:04:05"))
	fmt.Fprintf(file, "- **Transactions:** %d\n", numTransactions)
	fmt.Fprintf(file, "- **Size Profile:** %s\n", sizeProfile)
	fmt.Fprintf(file, "- **Batch Size:** %d\n\n", batchSize)
	
	fmt.Fprintf(file, "## Performance Results\n\n")
	fmt.Fprintf(file, "| Threads | Processing Time | Transactions/sec | Speedup |\n")
	fmt.Fprintf(file, "|---------|----------------|-----------------|--------|\n")
	
	for _, threads := range threadCounts {
		fmt.Fprintf(file, "| %d | %v | %.2f | %.2fx |\n", 
			threads, times[threads], throughputs[threads], speedups[threads])
	}
	
	// Add scaling graph description
	fmt.Fprintf(file, "\n## Scaling Analysis\n\n")
	fmt.Fprintf(file, "The benchmark demonstrates how the Avalanche parallel consensus implementation ")
	fmt.Fprintf(file, "scales with additional processing threads. The baseline single-threaded implementation ")
	fmt.Fprintf(file, "represents traditional blockchain processing, while the multi-threaded versions ")
	fmt.Fprintf(file, "show the benefits of parallel transaction processing.\n\n")
	
	// Add efficiency calculation
	fmt.Fprintf(file, "### Parallel Efficiency\n\n")
	fmt.Fprintf(file, "Parallel efficiency measures how effectively additional threads are utilized:\n\n")
	fmt.Fprintf(file, "| Threads | Speedup | Efficiency |\n")
	fmt.Fprintf(file, "|---------|---------|------------|\n")
	
	for _, threads := range threadCounts {
		if threads == 1 {
			fmt.Fprintf(file, "| %d | %.2fx | 100%% |\n", threads, speedups[threads])
		} else {
			efficiency := (speedups[threads] / float64(threads)) * 100
			fmt.Fprintf(file, "| %d | %.2fx | %.1f%% |\n", threads, speedups[threads], efficiency)
		}
	}
	
	fmt.Printf("Detailed results saved to: %s\n", filename)
}

func saveScenarioResults(scenarios []struct {
	name           string
	txCount        int
	threads        int
	batchSize      int
	sizeProfile    string
}, results map[string]struct {
	duration    time.Duration
	throughput  float64
}) {
	
	// Create results directory if it doesn't exist
	resultsDir := "benchmark-results"
	if _, err := os.Stat(resultsDir); os.IsNotExist(err) {
		os.Mkdir(resultsDir, 0755)
	}
	
	// Create results file
	timestamp := time.Now().Format("2006-01-02_15-04-05")
	filename := fmt.Sprintf("%s/scenario-tests-%s.md", resultsDir, timestamp)
	
	file, err := os.Create(filename)
	if err != nil {
		log.Printf("Failed to create scenario results file: %v", err)
		return
	}
	defer file.Close()
	
	// Write results
	fmt.Fprintf(file, "# Avalanche Transaction Scenario Test Results\n\n")
	fmt.Fprintf(file, "## Test Information\n")
	fmt.Fprintf(file, "- **Date:** %s\n", time.Now().Format("2006-01-02 15:04:05"))
	fmt.Fprintf(file, "- **Total Scenarios:** %d\n\n", len(scenarios))
	
	fmt.Fprintf(file, "## Scenario Configurations\n\n")
	fmt.Fprintf(file, "| Scenario | Transactions | Threads | Batch Size | Size Profile |\n")
	fmt.Fprintf(file, "|----------|--------------|---------|------------|-------------|\n")
	
	for _, scenario := range scenarios {
		fmt.Fprintf(file, "| %s | %d | %d | %d | %s |\n", 
			scenario.name, scenario.txCount, scenario.threads, 
			scenario.batchSize, scenario.sizeProfile)
	}
	
	fmt.Fprintf(file, "\n## Performance Results\n\n")
	fmt.Fprintf(file, "| Scenario | Processing Time | Transactions/sec |\n")
	fmt.Fprintf(file, "|----------|----------------|------------------|\n")
	
	for _, scenario := range scenarios {
		result := results[scenario.name]
		fmt.Fprintf(file, "| %s | %v | %.2f |\n", 
			scenario.name, result.duration, result.throughput)
	}
	
	// Calculate speedups for comparable scenarios
	fmt.Fprintf(file, "\n## Parallel vs Sequential Speedups\n\n")
	fmt.Fprintf(file, "| Workload | Sequential | Parallel | Speedup |\n")
	fmt.Fprintf(file, "|----------|------------|----------|--------|\n")
	
	speedupPairs := []struct {
		workload    string
		seqScenario string
		parScenario string
	}{
		{"Small Transactions", "Small Transactions/Single Thread", "Small Transactions/4 Threads"},
		{"Medium Transactions", "Medium Transactions/Single Thread", "Medium Transactions/4 Threads"},
		{"Large Transactions", "Large Transactions/Single Thread", "Large Transactions/4 Threads"},
		{"Mixed Transactions", "Mixed Transactions/Single Thread", "Mixed Transactions/4 Threads"},
		{"High Volume", "High Volume/Single Thread", "High Volume/4 Threads"},
	}
	
	for _, pair := range speedupPairs {
		seqResult := results[pair.seqScenario]
		parResult := results[pair.parScenario]
		speedup := float64(seqResult.duration) / float64(parResult.duration)
		
		fmt.Fprintf(file, "| %s | %v | %v | %.2fx |\n",
			pair.workload, seqResult.duration, parResult.duration, speedup)
	}
	
	fmt.Printf("Scenario test results saved to: %s\n", filename)
}

// Test logger implementation
type testLogger struct{}

func (l *testLogger) Debug(format string, args ...interface{}) {
	// Uncomment for debug logging
	// fmt.Printf("[DEBUG] "+format+"\n", args...)
}

func (l *testLogger) Info(format string, args ...interface{}) {
	// Uncomment for info logging
	// fmt.Printf("[INFO] "+format+"\n", args...)
}

func (l *testLogger) Warn(format string, args ...interface{}) {
	fmt.Printf("[WARN] "+format+"\n", args...)
}

func (l *testLogger) Error(format string, args ...interface{}) {
	fmt.Printf("[ERROR] "+format+"\n", args...)
}

func (l *testLogger) Fatal(format string, args ...interface{}) {
	fmt.Printf("[FATAL] "+format+"\n", args...)
	os.Exit(1)
}

// Helper to satisfy zap parameters that might be used in the Blockchain implementation
func (l *testLogger) Log(level string, msg string) {
	fmt.Printf("[%s] %s\n", level, msg)
}

// Helper functions to access blockchain information
func getGenesisBlockID(bc *blockchain.Blockchain) ids.ID {
	// Access the genesis block directly since it's a field in the struct
	// but check the API to access it properly
	genesis, err := bc.GetBlock(bc.GetLatestBlocks()[0].ParentIDs[0])
	if err != nil {
		log.Fatalf("Failed to get genesis block: %v", err)
	}
	return genesis.ID()
}

func getTxPoolSize(bc *blockchain.Blockchain) int {
	// We can't directly access the txPool size, so use a workaround
	// Create a block with all transactions and see how many are in it
	parents := bc.GetLatestBlocks()
	parentIDs := make([]ids.ID, len(parents))
	for i, parent := range parents {
		parentIDs[i] = parent.ID()
	}
	
	// Try to create a block with a very large maxTxs to get all transactions
	block, err := bc.CreateBlock(parentIDs, 10000)
	if err != nil {
		// If there are no transactions, it might error
		return 0
	}
	
	// If block was created, it consumed the transactions, so add them back
	for _, tx := range block.Transactions {
		bc.AddTransaction(tx)
	}
	
	return len(block.Transactions)
} 
