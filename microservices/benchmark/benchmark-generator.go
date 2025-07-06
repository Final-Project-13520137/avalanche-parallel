package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics
var (
	tasksGenerated = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "benchmark_tasks_generated_total",
			Help: "Total number of tasks generated",
		},
		[]string{"task_type"},
	)
	
	benchmarkDuration = prometheus.NewHistogram(
		prometheus.HistogramOpts{
			Name: "benchmark_duration_seconds",
			Help: "Benchmark execution duration",
		},
	)
	
	throughput = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "benchmark_throughput_tps",
			Help: "Benchmark throughput in tasks per second",
		},
		[]string{"test_type"},
	)
)

type BenchmarkGenerator struct {
	RedisClient *redis.Client
	ctx         context.Context
}

type BenchmarkConfig struct {
	TotalTasks      int           `json:"total_tasks"`
	Duration        time.Duration `json:"duration"`
	WorkerTypes     []string      `json:"worker_types"`
	TaskDistribution map[string]int `json:"task_distribution"`
	Concurrency     int           `json:"concurrency"`
}

type BenchmarkResult struct {
	TestType        string        `json:"test_type"`
	TotalTasks      int           `json:"total_tasks"`
	Duration        time.Duration `json:"duration"`
	Throughput      float64       `json:"throughput"`
	AverageLatency  time.Duration `json:"average_latency"`
	WorkerStats     map[string]interface{} `json:"worker_stats"`
	StartTime       time.Time     `json:"start_time"`
	EndTime         time.Time     `json:"end_time"`
}

type Task struct {
	ID       string    `json:"id"`
	Type     string    `json:"type"`
	Data     string    `json:"data"`
	Created  time.Time `json:"created"`
	Priority string    `json:"priority"`
}

func init() {
	prometheus.MustRegister(tasksGenerated)
	prometheus.MustRegister(benchmarkDuration)
	prometheus.MustRegister(throughput)
}

func main() {
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	port := getEnv("PORT", "9000")

	// Setup Redis
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatal("Failed to parse Redis URL:", err)
	}
	redisClient := redis.NewClient(opt)

	ctx := context.Background()
	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		log.Fatal("Failed to connect to Redis:", err)
	}

	generator := &BenchmarkGenerator{
		RedisClient: redisClient,
		ctx:         ctx,
	}

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":    "healthy",
			"service":   "benchmark-generator",
			"timestamp": time.Now().Unix(),
		})
	})

	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Benchmark endpoints
	r.POST("/benchmark/microservices", func(c *gin.Context) {
		var config BenchmarkConfig
		if err := c.ShouldBindJSON(&config); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		result := generator.runMicroservicesBenchmark(config)
		c.JSON(200, result)
	})

	r.POST("/benchmark/monolith", func(c *gin.Context) {
		var config BenchmarkConfig
		if err := c.ShouldBindJSON(&config); err != nil {
			c.JSON(400, gin.H{"error": err.Error()})
			return
		}

		result := generator.runMonolithBenchmark(config)
		c.JSON(200, result)
	})

	r.GET("/benchmark/preset/:test", func(c *gin.Context) {
		testType := c.Param("test")
		result := generator.runPresetBenchmark(testType)
		c.JSON(200, result)
	})

	r.GET("/benchmark/compare", func(c *gin.Context) {
		results := generator.runComparisonBenchmark()
		c.JSON(200, results)
	})

	log.Printf("Benchmark Generator starting on port %s", port)
	log.Fatal(http.ListenAndServe(":"+port, r))
}

func (bg *BenchmarkGenerator) runMicroservicesBenchmark(config BenchmarkConfig) BenchmarkResult {
	log.Printf("Starting microservices benchmark with %d tasks", config.TotalTasks)
	
	start := time.Now()
	
	// Clear existing queues
	bg.clearQueues()
	
	// Generate tasks distributed across worker types
	var wg sync.WaitGroup
	taskChan := make(chan Task, 100)
	
	// Task generator
	go func() {
		defer close(taskChan)
		for i := 0; i < config.TotalTasks; i++ {
			workerType := bg.selectWorkerType(config.WorkerTypes)
			task := Task{
				ID:       fmt.Sprintf("task-%d", i),
				Type:     workerType,
				Data:     bg.generateTaskData(workerType),
				Created:  time.Now(),
				Priority: "medium",
			}
			taskChan <- task
		}
	}()
	
	// Task distributors
	for i := 0; i < config.Concurrency; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for task := range taskChan {
				bg.pushTask(task)
				tasksGenerated.WithLabelValues(task.Type).Inc()
			}
		}()
	}
	
	wg.Wait()
	
	// Wait for processing (monitor queue depths)
	bg.waitForProcessing()
	
	end := time.Now()
	duration := end.Sub(start)
	
	result := BenchmarkResult{
		TestType:       "microservices",
		TotalTasks:     config.TotalTasks,
		Duration:       duration,
		Throughput:     float64(config.TotalTasks) / duration.Seconds(),
		StartTime:      start,
		EndTime:        end,
		WorkerStats:    bg.getWorkerStats(),
	}
	
	throughput.WithLabelValues("microservices").Set(result.Throughput)
	benchmarkDuration.Observe(duration.Seconds())
	
	log.Printf("Microservices benchmark completed: %d tasks in %v (%.2f TPS)", 
		config.TotalTasks, duration, result.Throughput)
	
	return result
}

func (bg *BenchmarkGenerator) runMonolithBenchmark(config BenchmarkConfig) BenchmarkResult {
	log.Printf("Starting monolith benchmark with %d tasks", config.TotalTasks)
	
	start := time.Now()
	
	// Simulate monolith processing (sequential or limited parallel)
	var wg sync.WaitGroup
	semaphore := make(chan struct{}, 4) // Limit concurrency to simulate monolith
	
	for i := 0; i < config.TotalTasks; i++ {
		wg.Add(1)
		go func(taskID int) {
			defer wg.Done()
			
			semaphore <- struct{}{} // Acquire
			defer func() { <-semaphore }() // Release
			
			// Simulate monolith processing
			bg.simulateMonolithTask(taskID)
		}(i)
	}
	
	wg.Wait()
	
	end := time.Now()
	duration := end.Sub(start)
	
	result := BenchmarkResult{
		TestType:   "monolith",
		TotalTasks: config.TotalTasks,
		Duration:   duration,
		Throughput: float64(config.TotalTasks) / duration.Seconds(),
		StartTime:  start,
		EndTime:    end,
	}
	
	throughput.WithLabelValues("monolith").Set(result.Throughput)
	
	log.Printf("Monolith benchmark completed: %d tasks in %v (%.2f TPS)", 
		config.TotalTasks, duration, result.Throughput)
	
	return result
}

func (bg *BenchmarkGenerator) runPresetBenchmark(testType string) interface{} {
	configs := map[string]BenchmarkConfig{
		"small": {
			TotalTasks:  1000,
			WorkerTypes: []string{"consensus", "validator", "dag-state"},
			Concurrency: 10,
		},
		"medium": {
			TotalTasks:  5000,
			WorkerTypes: []string{"consensus", "validator", "dag-state"},
			Concurrency: 20,
		},
		"large": {
			TotalTasks:  10000,
			WorkerTypes: []string{"consensus", "validator", "dag-state"},
			Concurrency: 50,
		},
	}
	
	config, exists := configs[testType]
	if !exists {
		return map[string]string{"error": "Unknown test type"}
	}
	
	microResult := bg.runMicroservicesBenchmark(config)
	monolithResult := bg.runMonolithBenchmark(config)
	
	return map[string]interface{}{
		"test_type":        testType,
		"microservices":    microResult,
		"monolith":        monolithResult,
		"improvement":     microResult.Throughput / monolithResult.Throughput,
	}
}

func (bg *BenchmarkGenerator) runComparisonBenchmark() map[string]interface{} {
	tests := []string{"small", "medium", "large"}
	results := make(map[string]interface{})
	
	for _, test := range tests {
		results[test] = bg.runPresetBenchmark(test)
		time.Sleep(5 * time.Second) // Cool down between tests
	}
	
	return results
}

func (bg *BenchmarkGenerator) clearQueues() {
	queues := []string{"consensus_tasks", "validator_tasks", "dag-state_tasks"}
	for _, queue := range queues {
		bg.RedisClient.Del(bg.ctx, queue)
	}
}

func (bg *BenchmarkGenerator) pushTask(task Task) error {
	queueName := fmt.Sprintf("%s_tasks", task.Type)
	taskJSON, _ := json.Marshal(task)
	return bg.RedisClient.RPush(bg.ctx, queueName, taskJSON).Err()
}

func (bg *BenchmarkGenerator) selectWorkerType(types []string) string {
	return types[rand.Intn(len(types))]
}

func (bg *BenchmarkGenerator) generateTaskData(taskType string) string {
	// Generate realistic task data based on type
	switch taskType {
	case "consensus":
		return fmt.Sprintf(`{"vertex_id":"v-%d","parents":["%d","%d"]}`, 
			rand.Intn(10000), rand.Intn(1000), rand.Intn(1000))
	case "validator":
		return fmt.Sprintf(`{"tx_id":"tx-%d","signature":"sig-%d","amount":%d}`,
			rand.Intn(10000), rand.Intn(1000), rand.Intn(1000000))
	case "dag-state":
		return fmt.Sprintf(`{"account":"addr-%d","balance":%d,"nonce":%d}`,
			rand.Intn(1000), rand.Intn(1000000), rand.Intn(100))
	default:
		return `{"data":"generic"}`
	}
}

func (bg *BenchmarkGenerator) waitForProcessing() {
	// Wait until all queues are empty
	for {
		totalDepth := 0
		queues := []string{"consensus_tasks", "validator_tasks", "dag-state_tasks"}
		
		for _, queue := range queues {
			depth := bg.RedisClient.LLen(bg.ctx, queue).Val()
			totalDepth += int(depth)
		}
		
		if totalDepth == 0 {
			break
		}
		
		time.Sleep(100 * time.Millisecond)
	}
	
	// Additional wait to ensure processing completion
	time.Sleep(2 * time.Second)
}

func (bg *BenchmarkGenerator) simulateMonolithTask(taskID int) {
	// Simulate monolith processing (all in one process)
	processingTime := time.Duration(50+rand.Intn(100)) * time.Millisecond
	
	// Simulate consensus
	time.Sleep(processingTime / 3)
	
	// Simulate validation
	time.Sleep(processingTime / 3)
	
	// Simulate DAG/state
	time.Sleep(processingTime / 3)
}

func (bg *BenchmarkGenerator) getWorkerStats() map[string]interface{} {
	// This would collect stats from actual workers
	// For now, return simulated stats
	return map[string]interface{}{
		"total_workers": 10,
		"active_workers": 8,
		"queue_depths": map[string]int{
			"consensus_tasks":  0,
			"validator_tasks":  0,
			"dag-state_tasks": 0,
		},
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
} 