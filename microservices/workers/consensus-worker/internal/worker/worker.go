package worker

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync"
	"syscall"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Worker represents a consensus worker
type Worker struct {
	id          string
	redisClient *redis.Client
	taskQueue   string
	resultQueue string
	maxWorkers  int
	metrics     *metrics
	quit        chan struct{}
}

// metrics contains Prometheus metrics
type metrics struct {
	tasksProcessed prometheus.Counter
	taskDuration   prometheus.Histogram
	queueLength    prometheus.Gauge
}

// NewWorker creates a new consensus worker
func NewWorker() *Worker {
	id := getEnv("WORKER_ID", fmt.Sprintf("consensus-worker-%d", time.Now().Unix()))
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	taskQueue := getEnv("TASK_QUEUE", "consensus_tasks")
	resultQueue := getEnv("RESULT_QUEUE", "consensus_results")
	maxWorkers := getEnvAsInt("MAX_WORKERS", 4)

	// Parse Redis URL and create client
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatalf("Failed to parse Redis URL: %v", err)
	}

	redisClient := redis.NewClient(opt)

	// Initialize metrics
	m := &metrics{
		tasksProcessed: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "consensus_tasks_processed_total",
			Help: "Total number of consensus tasks processed",
		}),
		taskDuration: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "consensus_task_duration_seconds",
			Help:    "Time spent processing consensus tasks",
			Buckets: prometheus.DefBuckets,
		}),
		queueLength: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "consensus_task_queue_length",
			Help: "Current length of the consensus task queue",
		}),
	}

	// Register metrics
	prometheus.MustRegister(m.tasksProcessed)
	prometheus.MustRegister(m.taskDuration)
	prometheus.MustRegister(m.queueLength)

	return &Worker{
		id:          id,
		redisClient: redisClient,
		taskQueue:   taskQueue,
		resultQueue: resultQueue,
		maxWorkers:  maxWorkers,
		metrics:     m,
		quit:        make(chan struct{}),
	}
}

// Start starts the worker
func (w *Worker) Start() error {
	// Test Redis connection
	ctx := context.Background()
	if err := w.redisClient.Ping(ctx).Err(); err != nil {
		return fmt.Errorf("failed to connect to Redis: %v", err)
	}

	// Start HTTP server for metrics
	go w.startMetricsServer()

	// Start worker pool
	var wg sync.WaitGroup
	for i := 0; i < w.maxWorkers; i++ {
		wg.Add(1)
		go w.processTasksLoop(ctx, &wg)
	}

	// Start queue length monitoring
	go w.monitorQueueLength(ctx)

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	// Initiate shutdown
	close(w.quit)
	wg.Wait()

	return nil
}

// processTasksLoop processes tasks from the queue
func (w *Worker) processTasksLoop(ctx context.Context, wg *sync.WaitGroup) {
	defer wg.Done()

	for {
		select {
		case <-w.quit:
			return
		default:
			// Get task from queue
			result := w.redisClient.BRPop(ctx, 5*time.Second, w.taskQueue)
			if result.Err() != nil {
				if result.Err() != redis.Nil {
					log.Printf("Error getting task from queue: %v", result.Err())
				}
				continue
			}

			if len(result.Val()) < 2 {
				continue
			}

			// Process task
			startTime := time.Now()
			w.processTask(ctx, []byte(result.Val()[1]))
			duration := time.Since(startTime).Seconds()

			// Update metrics
			w.metrics.tasksProcessed.Inc()
			w.metrics.taskDuration.Observe(duration)
		}
	}
}

// processTask processes a single task
func (w *Worker) processTask(ctx context.Context, taskData []byte) {
	var task map[string]interface{}
	if err := json.Unmarshal(taskData, &task); err != nil {
		log.Printf("Error parsing task: %v", err)
		return
	}

	// Parameter konsensus
	params, _ := task["consensus_params"].(map[string]interface{})
	k := getInt(params, "k", 5)
	betaVirt := getInt(params, "beta_virtuous", 5)
	betaRogue := getInt(params, "beta_rogue", 10)
	maxRounds := getInt(params, "max_rounds", 10)

	// Snowball sederhana: preferensi awal ditentukan oleh hash id
	pref := 0
	confidence := 0

	rngSeed := time.Now().UnixNano()
	_ = rngSeed

	accepted := false
	for round := 0; round < maxRounds; round++ {
		// sampling k validator virtual
		positive := 0
		for i := 0; i < k; i++ {
			// simulasi polling: 85% menerima jika pref==1, 60% jika pref==0
			p := time.Now().UnixNano() + int64(i)
			if (pref == 1 && (p%100) < 85) || (pref == 0 && (p%100) < 60) {
				positive++
			}
		}

		// update preference berdasar alpha=0.8 (>=80% setuju)
		if float64(positive)/float64(k) >= 0.8 {
			confidence++
			pref = 1
		} else {
			confidence = 0
			pref = 0
		}

		if pref == 1 && confidence >= betaVirt {
			accepted = true
			break
		}
		if pref == 0 && confidence >= betaRogue {
			accepted = false
			break
		}
	}

	// Kirim hasil
	result := map[string]interface{}{
		"worker_id": w.id,
		"task_id":   task["id"],
		"accepted":  accepted,
		"timestamp": time.Now(),
	}
	resultData, _ := json.Marshal(result)
	if err := w.redisClient.LPush(ctx, w.resultQueue, resultData).Err(); err != nil {
		log.Printf("Error sending result: %v", err)
	}
}

func getInt(m map[string]interface{}, key string, def int) int {
	if m == nil { return def }
	if v, ok := m[key]; ok {
		switch t := v.(type) {
		case float64:
			return int(t)
		case int:
			return t
		}
	}
	return def
}

// monitorQueueLength monitors the task queue length
func (w *Worker) monitorQueueLength(ctx context.Context) {
	ticker := time.NewTicker(15 * time.Second)
	defer ticker.Stop()

	for {
		select {
		case <-w.quit:
			return
		case <-ticker.C:
			length, err := w.redisClient.LLen(ctx, w.taskQueue).Result()
			if err != nil {
				log.Printf("Error getting queue length: %v", err)
				continue
			}
			w.metrics.queueLength.Set(float64(length))
		}
	}
}

// startMetricsServer starts the Prometheus metrics server
func (w *Worker) startMetricsServer() {
	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())

	// Health check endpoint
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
	})

	port := getEnv("METRICS_PORT", "8080")
	log.Printf("Starting metrics server on port %s", port)
	if err := http.ListenAndServe(":"+port, mux); err != nil {
		log.Printf("Metrics server error: %v", err)
	}
}

// Helper functions
func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}

func getEnvAsInt(key string, defaultValue int) int {
	value := getEnv(key, "")
	if value == "" {
		return defaultValue
	}
	intValue, err := strconv.Atoi(value)
	if err != nil {
		return defaultValue
	}
	return intValue
}
