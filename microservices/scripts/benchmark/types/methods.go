package types

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/vms/avm"
	"github.com/olekukonko/tablewriter"
)

// RunMicroservicesBenchmark executes benchmark against microservices architecture
func (ab *AvalancheBenchmark) RunMicroservicesBenchmark(testCase TestCase) (BenchmarkResult, error) {
	log.Printf("🔧 Running microservices benchmark: %s", testCase.Name)

	startTime := time.Now()

	// Generate test transactions
	transactions := ab.GenerateTransactions(testCase)

	// Measure system performance
	latencies := make([]time.Duration, 0, len(transactions))
	successCount := 0
	failureCount := 0

	// Execute transactions concurrently
	var wg sync.WaitGroup
	latencyChan := make(chan time.Duration, len(transactions))
	successChan := make(chan bool, len(transactions))

	// Distribute transactions across workers
	transactionsPerWorker := len(transactions) / testCase.ConcurrentUsers
	if transactionsPerWorker == 0 {
		transactionsPerWorker = 1
	}

	for i := 0; i < testCase.ConcurrentUsers; i++ {
		wg.Add(1)
		go func(workerID int) {
			defer wg.Done()

			start := workerID * transactionsPerWorker
			end := start + transactionsPerWorker
			if end > len(transactions) {
				end = len(transactions)
			}

			for j := start; j < end; j++ {
				txStartTime := time.Now()

				// Process transaction through microservices
				success := ab.ProcessMicroservicesTransaction(transactions[j])

				latency := time.Since(txStartTime)
				latencyChan <- latency
				successChan <- success
			}
		}(i)
	}

	// Wait for completion
	wg.Wait()
	close(latencyChan)
	close(successChan)

	// Collect results
	for latency := range latencyChan {
		latencies = append(latencies, latency)
	}

	for success := range successChan {
		if success {
			successCount++
		} else {
			failureCount++
		}
	}

	totalDuration := time.Since(startTime)

	// Calculate metrics
	result := BenchmarkResult{
		TestCase:          testCase,
		Architecture:      "microservices",
		TotalTransactions: len(transactions),
		SuccessfulTxs:     successCount,
		FailedTxs:         failureCount,
		TotalDuration:     totalDuration,
		Timestamp:         time.Now(),
	}

	ab.CalculateLatencyMetrics(&result, latencies)
	ab.CalculateSystemMetrics(&result)

	return result, nil
}

// RunMonolithBenchmark executes benchmark against monolith architecture
func (ab *AvalancheBenchmark) RunMonolithBenchmark(testCase TestCase) (BenchmarkResult, error) {
	log.Printf("🏗️ Running monolith benchmark: %s", testCase.Name)

	startTime := time.Now()

	// Generate test transactions
	transactions := ab.GenerateTransactions(testCase)

	// Initialize AvalancheGo client
	client := avm.NewClient(ab.Config.MonolithEndpoint, "X")

	// Measure system performance
	latencies := make([]time.Duration, 0, len(transactions))
	successCount := 0
	failureCount := 0

	// Execute transactions sequentially through AvalancheGo
	for _, tx := range transactions {
		txStartTime := time.Now()

		// Convert transaction to AvalancheGo format
		txBytes, err := json.Marshal(tx)
		if err != nil {
			failureCount++
			continue
		}

		// Issue transaction to AvalancheGo
		txID, err := client.IssueTx(context.Background(), txBytes)
		if err != nil {
			failureCount++
			continue
		}

		// Wait for transaction acceptance
		status, err := client.GetTxStatus(context.Background(), txID)
		if err != nil || status != choices.Accepted {
			failureCount++
		} else {
			successCount++
		}

		latency := time.Since(txStartTime)
		latencies = append(latencies, latency)
	}

	totalDuration := time.Since(startTime)

	// Calculate metrics
	result := BenchmarkResult{
		TestCase:          testCase,
		Architecture:      "monolith",
		TotalTransactions: len(transactions),
		SuccessfulTxs:     successCount,
		FailedTxs:         failureCount,
		TotalDuration:     totalDuration,
		Timestamp:         time.Now(),
	}

	ab.CalculateLatencyMetrics(&result, latencies)
	ab.CalculateSystemMetrics(&result)

	return result, nil
}

// ProcessMicroservicesTransaction processes transaction through microservices architecture
func (ab *AvalancheBenchmark) ProcessMicroservicesTransaction(tx Transaction) bool {
	ctx := context.Background()

	// Step 1: Submit to validator worker
	validationStartTime := time.Now()
	validationTask := map[string]interface{}{
		"id":             tx.ID.String(),
		"type":           "transaction_validation",
		"transaction_id": tx.ID,
		"transaction":    tx,
		"priority":       "high",
		"timestamp":      validationStartTime,
	}

	validationData, _ := json.Marshal(validationTask)
	if err := ab.RedisClient.LPush(ctx, "validation_tasks", validationData).Err(); err != nil {
		return false
	}

	// Wait for validation result
	validationResult, err := ab.WaitForResult(ctx, "validation_results", tx.ID.String())
	validationEndTime := time.Now()
	if err != nil || !validationResult.Success {
		return false
	}

	// Step 2: Submit to consensus worker
	consensusStartTime := time.Now()
	consensusTask := map[string]interface{}{
		"id":           tx.ID.String(),
		"type":         "vertex_validation",
		"vertex_id":    tx.ID,
		"parent_ids":   []ids.ID{},
		"transactions": []Transaction{tx},
		"priority":     "high",
		"timestamp":    consensusStartTime,
	}

	consensusData, _ := json.Marshal(consensusTask)
	if err := ab.RedisClient.LPush(ctx, "consensus_tasks", consensusData).Err(); err != nil {
		return false
	}

	// Wait for consensus result
	consensusResult, err := ab.WaitForResult(ctx, "consensus_results", tx.ID.String())
	consensusEndTime := time.Now()
	if err != nil || !consensusResult.Success {
		return false
	}

	// Step 3: Submit to DAG state worker
	stateUpdateStartTime := time.Now()
	dagStateTask := map[string]interface{}{
		"id":        tx.ID.String(),
		"type":      "update_dag",
		"vertex_id": tx.ID.String(),
		"data":      tx.Data,
		"priority":  "high",
		"timestamp": stateUpdateStartTime,
	}

	dagStateData, _ := json.Marshal(dagStateTask)
	if err := ab.RedisClient.LPush(ctx, "dag_state_tasks", dagStateData).Err(); err != nil {
		return false
	}

	// Wait for DAG state update result
	dagStateResult, err := ab.WaitForResult(ctx, "dag_state_results", tx.ID.String())
	stateUpdateEndTime := time.Now()
	if err != nil || !dagStateResult.Success {
		return false
	}

	// Record timing information
	tx.Metrics = &TransactionMetrics{
		ValidationStartTime:  validationStartTime,
		ValidationEndTime:    validationEndTime,
		ConsensusStartTime:   consensusStartTime,
		ConsensusEndTime:     consensusEndTime,
		StateUpdateStartTime: stateUpdateStartTime,
		StateUpdateEndTime:   stateUpdateEndTime,
	}

	return true
}

// WaitForResult waits for a task result from Redis
func (ab *AvalancheBenchmark) WaitForResult(ctx context.Context, resultQueue string, taskID string) (*TaskResult, error) {
	timeout := time.After(10 * time.Second)
	ticker := time.NewTicker(100 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-timeout:
			return nil, fmt.Errorf("timeout waiting for result")
		case <-ticker.C:
			// Check for result
			result, err := ab.RedisClient.LRange(ctx, resultQueue, 0, -1).Result()
			if err != nil {
				continue
			}

			for _, r := range result {
				var taskResult TaskResult
				if err := json.Unmarshal([]byte(r), &taskResult); err != nil {
					continue
				}

				if taskResult.TaskID == taskID {
					// Remove the result from queue
					ab.RedisClient.LRem(ctx, resultQueue, 1, r)
					return &taskResult, nil
				}
			}
		}
	}
}

// GenerateTransactions creates test transactions for benchmark
func (ab *AvalancheBenchmark) GenerateTransactions(testCase TestCase) []Transaction {
	transactions := make([]Transaction, testCase.TransactionCount)

	for i := 0; i < testCase.TransactionCount; i++ {
		// Generate random transaction data
		data := make([]byte, testCase.TransactionSize)
		rand.Read(data)

		tx := Transaction{
			ID:        ids.GenerateTestID(),
			From:      fmt.Sprintf("address_%d", rand.Intn(1000)),
			To:        fmt.Sprintf("address_%d", rand.Intn(1000)),
			Amount:    uint64(rand.Intn(1000000) + 1),
			Data:      data,
			Nonce:     uint64(i),
			Timestamp: time.Now(),
			Size:      testCase.TransactionSize,
		}

		transactions[i] = tx
	}

	return transactions
}

// CalculateLatencyMetrics computes latency statistics
func (ab *AvalancheBenchmark) CalculateLatencyMetrics(result *BenchmarkResult, latencies []time.Duration) {
	if len(latencies) == 0 {
		return
	}

	// Calculate average
	var total time.Duration
	for _, latency := range latencies {
		total += latency
	}
	result.AverageLatency = total / time.Duration(len(latencies))

	// Sort for percentile calculations
	sortedLatencies := make([]time.Duration, len(latencies))
	copy(sortedLatencies, latencies)

	// Simple bubble sort for demonstration
	for i := 0; i < len(sortedLatencies); i++ {
		for j := i + 1; j < len(sortedLatencies); j++ {
			if sortedLatencies[i] > sortedLatencies[j] {
				sortedLatencies[i], sortedLatencies[j] = sortedLatencies[j], sortedLatencies[i]
			}
		}
	}

	// Calculate percentiles
	result.MedianLatency = sortedLatencies[len(sortedLatencies)/2]
	result.P95Latency = sortedLatencies[int(float64(len(sortedLatencies))*0.95)]
	result.P99Latency = sortedLatencies[int(float64(len(sortedLatencies))*0.99)]

	// Calculate throughput
	result.ThroughputTPS = float64(result.SuccessfulTxs) / result.TotalDuration.Seconds()

	// Calculate error rate
	result.ErrorRate = float64(result.FailedTxs) / float64(result.TotalTransactions) * 100
}

// CalculateSystemMetrics simulates system resource usage
func (ab *AvalancheBenchmark) CalculateSystemMetrics(result *BenchmarkResult) {
	// Mengukur CPU usage menggunakan psutil atau metrics dari container
	cpuPercent := 0.0
	memoryMB := 0.0
	networkMB := 0.0

	if result.Architecture == "microservices" {
		// Mengambil metrics dari worker pools
		metrics, err := ab.GetWorkerPoolMetrics()
		if err != nil {
			log.Printf("Warning: Failed to get worker pool metrics: %v", err)
			return
		}

		// Menghitung total penggunaan resources dari semua workers
		for _, worker := range metrics.Workers {
			cpuPercent += worker.CPUPercent
			memoryMB += float64(worker.MemoryUsageMB)
			networkMB += float64(worker.NetworkBandwidthMB)
		}
	} else {
		// Mengambil metrics dari node monolith
		metrics, err := ab.GetMonolithMetrics()
		if err != nil {
			log.Printf("Warning: Failed to get monolith metrics: %v", err)
			return
		}

		cpuPercent = metrics.CPUPercent
		memoryMB = float64(metrics.MemoryUsageMB)
		networkMB = float64(metrics.NetworkBandwidthMB)
	}

	result.CPUUsagePercent = cpuPercent
	result.MemoryUsageMB = memoryMB
	result.NetworkBandwidthMB = networkMB

	// Mengukur waktu pemrosesan yang sebenarnya
	result.ConsensusTime = result.ConsensusEndTime.Sub(result.ConsensusStartTime)
	result.ValidationTime = result.ValidationEndTime.Sub(result.ValidationStartTime)
	result.StateUpdateTime = result.StateUpdateEndTime.Sub(result.StateUpdateStartTime)
}

// AddResult safely adds a result to the collection
func (ab *AvalancheBenchmark) AddResult(result BenchmarkResult) {
	ab.ResultsMutex.Lock()
	defer ab.ResultsMutex.Unlock()
	ab.Results = append(ab.Results, result)
}

// SaveResults saves benchmark results to JSON file
func (ab *AvalancheBenchmark) SaveResults() error {
	ab.ResultsMutex.RLock()
	defer ab.ResultsMutex.RUnlock()

	timestamp := time.Now().Format("20060102_150405")
	filename := filepath.Join(ab.Config.ResultsDir, fmt.Sprintf("benchmark_results_%s.json", timestamp))

	log.Printf("📝 Saving results to: %s", filename)
	log.Printf("📊 Number of results to save: %d", len(ab.Results))

	// Create the directory if it doesn't exist
	if err := os.MkdirAll(ab.Config.ResultsDir, 0777); err != nil {
		log.Printf("❌ Failed to create results directory: %v", err)
		return fmt.Errorf("failed to create results directory: %v", err)
	}

	file, err := os.OpenFile(filename, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0666)
	if err != nil {
		log.Printf("❌ Failed to create results file: %v", err)
		return fmt.Errorf("failed to create results file: %v", err)
	}
	defer file.Close()

	encoder := json.NewEncoder(file)
	encoder.SetIndent("", "  ")

	if err := encoder.Encode(ab.Results); err != nil {
		log.Printf("❌ Failed to encode results: %v", err)
		return fmt.Errorf("failed to encode results: %v", err)
	}

	log.Printf("✅ Successfully saved %d results to %s", len(ab.Results), filename)
	return nil
}

// GenerateReport creates a detailed benchmark report
func (ab *AvalancheBenchmark) GenerateReport() error {
	ab.ResultsMutex.RLock()
	defer ab.ResultsMutex.RUnlock()

	timestamp := time.Now().Format("20060102_150405")
	filename := filepath.Join(ab.Config.ResultsDir, fmt.Sprintf("benchmark_report_%s.md", timestamp))

	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	// Write markdown report
	fmt.Fprintf(file, "# Avalanche Microservices vs Monolith Benchmark Report\n\n")
	fmt.Fprintf(file, "Generated: %s\n\n", time.Now().Format("2006-01-02 15:04:05"))

	// Summary table
	fmt.Fprintf(file, "## Summary\n\n")

	// Group results by test case
	testCaseResults := make(map[string][]BenchmarkResult)
	for _, result := range ab.Results {
		testCaseResults[result.TestCase.Name] = append(testCaseResults[result.TestCase.Name], result)
	}

	for testCaseName, results := range testCaseResults {
		fmt.Fprintf(file, "### %s\n\n", testCaseName)

		// Create comparison table
		fmt.Fprintf(file, "| Metric | Microservices | Monolith | Improvement |\n")
		fmt.Fprintf(file, "|--------|---------------|----------|-------------|\n")

		var microResult, monolithResult BenchmarkResult
		for _, result := range results {
			if result.Architecture == "microservices" {
				microResult = result
			} else {
				monolithResult = result
			}
		}

		if microResult.Architecture != "" && monolithResult.Architecture != "" {
			// Throughput comparison
			improvement := ((microResult.ThroughputTPS - monolithResult.ThroughputTPS) / monolithResult.ThroughputTPS) * 100
			fmt.Fprintf(file, "| Throughput (TPS) | %.2f | %.2f | %.1f%% |\n",
				microResult.ThroughputTPS, monolithResult.ThroughputTPS, improvement)

			// Latency comparison
			improvement = ((monolithResult.AverageLatency.Seconds() - microResult.AverageLatency.Seconds()) / monolithResult.AverageLatency.Seconds()) * 100
			fmt.Fprintf(file, "| Average Latency (ms) | %.2f | %.2f | %.1f%% |\n",
				float64(microResult.AverageLatency.Nanoseconds())/1e6,
				float64(monolithResult.AverageLatency.Nanoseconds())/1e6, improvement)

			// CPU usage comparison
			improvement = ((monolithResult.CPUUsagePercent - microResult.CPUUsagePercent) / monolithResult.CPUUsagePercent) * 100
			fmt.Fprintf(file, "| CPU Usage (%%) | %.1f | %.1f | %.1f%% |\n",
				microResult.CPUUsagePercent, monolithResult.CPUUsagePercent, improvement)

			// Memory usage comparison
			improvement = ((monolithResult.MemoryUsageMB - microResult.MemoryUsageMB) / monolithResult.MemoryUsageMB) * 100
			fmt.Fprintf(file, "| Memory Usage (MB) | %.1f | %.1f | %.1f%% |\n",
				microResult.MemoryUsageMB, monolithResult.MemoryUsageMB, improvement)
		}

		fmt.Fprintf(file, "\n")
	}

	return nil
}

// GenerateGraphs creates performance comparison graphs
func (ab *AvalancheBenchmark) GenerateGraphs() error {
	// This would generate graphs using a plotting library
	// For now, we'll create data files that can be used with external tools

	timestamp := time.Now().Format("20060102_150405")

	// Create CSV data for throughput comparison
	throughputFile := filepath.Join(ab.Config.GraphsDir, fmt.Sprintf("throughput_comparison_%s.csv", timestamp))
	if err := ab.CreateThroughputCSV(throughputFile); err != nil {
		return err
	}

	// Create CSV data for latency comparison
	latencyFile := filepath.Join(ab.Config.GraphsDir, fmt.Sprintf("latency_comparison_%s.csv", timestamp))
	if err := ab.CreateLatencyCSV(latencyFile); err != nil {
		return err
	}

	// Create CSV data for resource usage comparison
	resourceFile := filepath.Join(ab.Config.GraphsDir, fmt.Sprintf("resource_usage_%s.csv", timestamp))
	if err := ab.CreateResourceUsageCSV(resourceFile); err != nil {
		return err
	}

	return nil
}

// CreateThroughputCSV creates CSV data for throughput comparison
func (ab *AvalancheBenchmark) CreateThroughputCSV(filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	fmt.Fprintf(file, "TestCase,TransactionCount,Microservices_TPS,Monolith_TPS,Speedup\n")

	// Group results by test case
	testCaseResults := make(map[string][]BenchmarkResult)
	for _, result := range ab.Results {
		testCaseResults[result.TestCase.Name] = append(testCaseResults[result.TestCase.Name], result)
	}

	for testCaseName, results := range testCaseResults {
		var microResult, monolithResult BenchmarkResult
		for _, result := range results {
			if result.Architecture == "microservices" {
				microResult = result
			} else {
				monolithResult = result
			}
		}

		if microResult.Architecture != "" && monolithResult.Architecture != "" {
			speedup := microResult.ThroughputTPS / monolithResult.ThroughputTPS
			fmt.Fprintf(file, "%s,%d,%.2f,%.2f,%.2f\n",
				testCaseName, microResult.TestCase.TransactionCount,
				microResult.ThroughputTPS, monolithResult.ThroughputTPS, speedup)
		}
	}

	return nil
}

// CreateLatencyCSV creates CSV data for latency comparison
func (ab *AvalancheBenchmark) CreateLatencyCSV(filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	fmt.Fprintf(file, "TestCase,TransactionCount,Microservices_Avg_Latency_ms,Monolith_Avg_Latency_ms,Microservices_P95_ms,Monolith_P95_ms\n")

	// Group results by test case
	testCaseResults := make(map[string][]BenchmarkResult)
	for _, result := range ab.Results {
		testCaseResults[result.TestCase.Name] = append(testCaseResults[result.TestCase.Name], result)
	}

	for testCaseName, results := range testCaseResults {
		var microResult, monolithResult BenchmarkResult
		for _, result := range results {
			if result.Architecture == "microservices" {
				microResult = result
			} else {
				monolithResult = result
			}
		}

		if microResult.Architecture != "" && monolithResult.Architecture != "" {
			fmt.Fprintf(file, "%s,%d,%.2f,%.2f,%.2f,%.2f\n",
				testCaseName, microResult.TestCase.TransactionCount,
				float64(microResult.AverageLatency.Nanoseconds())/1e6,
				float64(monolithResult.AverageLatency.Nanoseconds())/1e6,
				float64(microResult.P95Latency.Nanoseconds())/1e6,
				float64(monolithResult.P95Latency.Nanoseconds())/1e6)
		}
	}

	return nil
}

// CreateResourceUsageCSV creates CSV data for resource usage comparison
func (ab *AvalancheBenchmark) CreateResourceUsageCSV(filename string) error {
	file, err := os.Create(filename)
	if err != nil {
		return err
	}
	defer file.Close()

	fmt.Fprintf(file, "TestCase,Architecture,CPU_Percent,Memory_MB,Network_MB\n")

	for _, result := range ab.Results {
		fmt.Fprintf(file, "%s,%s,%.1f,%.1f,%.1f\n",
			result.TestCase.Name, result.Architecture,
			result.CPUUsagePercent, result.MemoryUsageMB, result.NetworkBandwidthMB)
	}

	return nil
}

// PrintSummary prints a summary of benchmark results
func (ab *AvalancheBenchmark) PrintSummary() {
	ab.ResultsMutex.RLock()
	defer ab.ResultsMutex.RUnlock()

	fmt.Println("\n📊 BENCHMARK SUMMARY")
	fmt.Println(strings.Repeat("=", 50))

	table := tablewriter.NewWriter(os.Stdout)
	table.SetHeader([]string{"Test Case", "Architecture", "TPS", "Avg Latency (ms)", "CPU %", "Memory (MB)"})

	for _, result := range ab.Results {
		table.Append([]string{
			result.TestCase.Name,
			result.Architecture,
			fmt.Sprintf("%.2f", result.ThroughputTPS),
			fmt.Sprintf("%.2f", float64(result.AverageLatency.Nanoseconds())/1e6),
			fmt.Sprintf("%.1f", result.CPUUsagePercent),
			fmt.Sprintf("%.1f", result.MemoryUsageMB),
		})
	}

	table.Render()
}
