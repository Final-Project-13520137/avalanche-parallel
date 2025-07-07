package worker

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Metrics
var (
	tasksProcessed = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "worker_tasks_processed_total",
			Help: "Total number of tasks processed",
		},
		[]string{"worker_id", "task_type", "status"},
	)

	processingDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "worker_processing_duration_seconds",
			Help: "Task processing duration in seconds",
		},
		[]string{"worker_id", "task_type"},
	)

	queueDepth = prometheus.NewGaugeVec(
		prometheus.GaugeOpts{
			Name: "worker_queue_depth",
			Help: "Current queue depth",
		},
		[]string{"queue_name"},
	)
)

type Worker struct {
	ID          string
	WorkerType  string
	RedisClient *redis.Client
	Port        string
	ctx         context.Context
}

type Task struct {
	ID       string    `json:"id"`
	Type     string    `json:"type"`
	Data     string    `json:"data"`
	Created  time.Time `json:"created"`
	Priority string    `json:"priority"`
}

func init() {
	prometheus.MustRegister(tasksProcessed)
	prometheus.MustRegister(processingDuration)
	prometheus.MustRegister(queueDepth)
}

func main() {
	workerID := getEnv("WORKER_ID", "worker-1")
	workerType := getEnv("WORKER_TYPE", "consensus")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	port := getEnv("PORT", "8080")

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

	worker := &Worker{
		ID:          workerID,
		WorkerType:  workerType,
		RedisClient: redisClient,
		Port:        port,
		ctx:         ctx,
	}

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":      "healthy",
			"worker_id":   workerID,
			"worker_type": workerType,
			"timestamp":   time.Now().Unix(),
		})
	})

	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	r.GET("/stats", func(c *gin.Context) {
		stats := worker.getStats()
		c.JSON(200, stats)
	})

	// Start HTTP server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		log.Printf("Worker %s (%s) starting on port %s", workerID, workerType, port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	// Start worker processing
	go worker.processTask()
	go worker.updateQueueMetrics()

	// Wait for interrupt
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Printf("Shutting down worker %s...", workerID)

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Printf("Worker %s stopped", workerID)
}

func (w *Worker) processTask() {
	queueName := fmt.Sprintf("%s_tasks", w.WorkerType)
	log.Printf("Worker %s processing tasks from queue: %s", w.ID, queueName)

	for {
		// Pop task from queue
		result := w.RedisClient.BLPop(w.ctx, 1*time.Second, queueName)
		if result.Err() == redis.Nil {
			continue // No task available
		}
		if result.Err() != nil {
			log.Printf("Error popping from queue: %v", result.Err())
			time.Sleep(1 * time.Second)
			continue
		}

		if len(result.Val()) < 2 {
			continue
		}

		taskData := result.Val()[1]
		start := time.Now()

		// Process the task
		err := w.processSingleTask(taskData)
		duration := time.Since(start)

		// Record metrics
		status := "success"
		if err != nil {
			status = "error"
			log.Printf("Error processing task: %v", err)
		}

		tasksProcessed.WithLabelValues(w.ID, w.WorkerType, status).Inc()
		processingDuration.WithLabelValues(w.ID, w.WorkerType).Observe(duration.Seconds())
	}
}

func (w *Worker) processSingleTask(taskData string) error {
	var task Task
	if err := json.Unmarshal([]byte(taskData), &task); err != nil {
		return fmt.Errorf("failed to unmarshal task: %w", err)
	}

	// Simulate different processing times based on worker type
	var processingTime time.Duration
	switch w.WorkerType {
	case "consensus":
		// Consensus requires more CPU - simulate complex computation
		processingTime = time.Duration(50+rand.Intn(100)) * time.Millisecond
		w.simulateConsensusWork()
	case "validator":
		// Validation is typically faster but varies
		processingTime = time.Duration(10+rand.Intn(50)) * time.Millisecond
		w.simulateValidationWork()
	case "dag-state":
		// DAG operations can be complex
		processingTime = time.Duration(100+rand.Intn(200)) * time.Millisecond
		w.simulateDAGWork()
	default:
		processingTime = time.Duration(20+rand.Intn(30)) * time.Millisecond
	}

	// Simulate actual work
	time.Sleep(processingTime)

	log.Printf("Worker %s processed task %s in %v", w.ID, task.ID, processingTime)
	return nil
}

func (w *Worker) simulateConsensusWork() {
	// Simulate consensus computation
	for i := 0; i < 1000; i++ {
		_ = rand.Intn(1000)
	}
}

func (w *Worker) simulateValidationWork() {
	// Simulate signature validation
	for i := 0; i < 500; i++ {
		_ = rand.Intn(500)
	}
}

func (w *Worker) simulateDAGWork() {
	// Simulate DAG traversal and state updates
	for i := 0; i < 2000; i++ {
		_ = rand.Intn(2000)
	}
}

func (w *Worker) updateQueueMetrics() {
	for {
		queueName := fmt.Sprintf("%s_tasks", w.WorkerType)
		length := w.RedisClient.LLen(w.ctx, queueName)
		if length.Err() == nil {
			queueDepth.WithLabelValues(queueName).Set(float64(length.Val()))
		}
		time.Sleep(5 * time.Second)
	}
}

func (w *Worker) getStats() map[string]interface{} {
	queueName := fmt.Sprintf("%s_tasks", w.WorkerType)
	queueLen := w.RedisClient.LLen(w.ctx, queueName).Val()

	return map[string]interface{}{
		"worker_id":   w.ID,
		"worker_type": w.WorkerType,
		"queue_name":  queueName,
		"queue_depth": queueLen,
		"status":      "active",
		"uptime":      time.Now().Unix(),
	}
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
