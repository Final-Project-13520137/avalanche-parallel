package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/go-redis/redis/v8"
	_ "github.com/lib/pq"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// Prometheus metrics
	tasksProcessed = prometheus.NewCounterVec(
		prometheus.CounterOpts{
			Name: "dag_state_tasks_processed_total",
			Help: "Total number of DAG/State tasks processed",
		},
		[]string{"worker_id", "status"},
	)
	
	processingDuration = prometheus.NewHistogramVec(
		prometheus.HistogramOpts{
			Name: "dag_state_processing_duration_seconds",
			Help: "DAG/State processing duration in seconds",
		},
		[]string{"worker_id", "task_type"},
	)
)

type DAGStateWorker struct {
	ID       string
	redisClient *redis.Client
	db       *sql.DB
	ctx      context.Context
}

type DAGTask struct {
	Type     string          `json:"type"`
	VertexID string          `json:"vertex_id"`
	Data     json.RawMessage `json:"data"`
	Priority string          `json:"priority"`
}

type StateTask struct {
	Type      string          `json:"type"`
	VertexID  string          `json:"vertex_id"`
	AccountID string          `json:"account_id"`
	Changes   json.RawMessage `json:"changes"`
	Priority  string          `json:"priority"`
}

func init() {
	prometheus.MustRegister(tasksProcessed)
	prometheus.MustRegister(processingDuration)
}

func main() {
	workerID := getEnv("WORKER_ID", "dag-state-worker-1")
	redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
	postgresURL := getEnv("POSTGRES_URL", "postgres://avalanche:avalanche123@localhost:5432/avalanche?sslmode=disable")
	port := getEnv("PORT", "8082")

	// Setup Redis connection
	opt, err := redis.ParseURL(redisURL)
	if err != nil {
		log.Fatal("Failed to parse Redis URL:", err)
	}
	redisClient := redis.NewClient(opt)

	// Test Redis connection
	ctx := context.Background()
	_, err = redisClient.Ping(ctx).Result()
	if err != nil {
		log.Fatal("Failed to connect to Redis:", err)
	}

	// Setup PostgreSQL connection
	db, err := sql.Open("postgres", postgresURL)
	if err != nil {
		log.Fatal("Failed to connect to PostgreSQL:", err)
	}
	defer db.Close()

	// Test database connection
	err = db.Ping()
	if err != nil {
		log.Fatal("Failed to ping PostgreSQL:", err)
	}

	worker := &DAGStateWorker{
		ID:          workerID,
		redisClient: redisClient,
		db:          db,
		ctx:         ctx,
	}

	// Setup HTTP server
	gin.SetMode(gin.ReleaseMode)
	r := gin.Default()

	// Health check endpoint
	r.GET("/health", func(c *gin.Context) {
		c.JSON(200, gin.H{
			"status":    "healthy",
			"worker_id": workerID,
			"timestamp": time.Now().Unix(),
		})
	})

	// Metrics endpoint
	r.GET("/metrics", gin.WrapH(promhttp.Handler()))

	// Start HTTP server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: r,
	}

	go func() {
		log.Printf("DAG/State Worker %s starting on port %s", workerID, port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatal("Failed to start server:", err)
		}
	}()

	// Start worker processing
	go worker.processDAGTasks()
	go worker.processStateTasks()
	go worker.processSnapshots()

	// Wait for interrupt signal
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Println("Shutting down DAG/State worker...")

	// Graceful shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := server.Shutdown(ctx); err != nil {
		log.Fatal("Server forced to shutdown:", err)
	}

	log.Println("DAG/State worker stopped")
}

func (w *DAGStateWorker) processDAGTasks() {
	log.Printf("Starting DAG task processing for worker %s", w.ID)
	
	for {
		// Pop task from high priority queue first, then medium, then low
		queues := []string{"dag_tasks_high", "dag_tasks_medium", "dag_tasks_low"}
		
		var taskData string
		var err error
		
		for _, queue := range queues {
			result := w.redisClient.LPop(w.ctx, queue)
			if result.Err() == redis.Nil {
				continue // Queue is empty, try next queue
			}
			if result.Err() != nil {
				log.Printf("Error popping from queue %s: %v", queue, result.Err())
				continue
			}
			taskData = result.Val()
			break
		}
		
		if taskData == "" {
			time.Sleep(1 * time.Second)
			continue
		}

		// Process the task
		start := time.Now()
		err = w.processSingleDAGTask(taskData)
		duration := time.Since(start)

		// Record metrics
		status := "success"
		if err != nil {
			status = "error"
			log.Printf("Error processing DAG task: %v", err)
		}

		tasksProcessed.WithLabelValues(w.ID, status).Inc()
		processingDuration.WithLabelValues(w.ID, "dag").Observe(duration.Seconds())
	}
}

func (w *DAGStateWorker) processStateTasks() {
	log.Printf("Starting State task processing for worker %s", w.ID)
	
	for {
		// Pop task from high priority queue first, then medium, then low
		queues := []string{"state_tasks_high", "state_tasks_medium", "state_tasks_low"}
		
		var taskData string
		var err error
		
		for _, queue := range queues {
			result := w.redisClient.LPop(w.ctx, queue)
			if result.Err() == redis.Nil {
				continue // Queue is empty, try next queue
			}
			if result.Err() != nil {
				log.Printf("Error popping from queue %s: %v", queue, result.Err())
				continue
			}
			taskData = result.Val()
			break
		}
		
		if taskData == "" {
			time.Sleep(1 * time.Second)
			continue
		}

		// Process the task
		start := time.Now()
		err = w.processSingleStateTask(taskData)
		duration := time.Since(start)

		// Record metrics
		status := "success"
		if err != nil {
			status = "error"
			log.Printf("Error processing State task: %v", err)
		}

		tasksProcessed.WithLabelValues(w.ID, status).Inc()
		processingDuration.WithLabelValues(w.ID, "state").Observe(duration.Seconds())
	}
}

func (w *DAGStateWorker) processSnapshots() {
	log.Printf("Starting Snapshot processing for worker %s", w.ID)
	
	for {
		// Process snapshots every 30 seconds
		time.Sleep(30 * time.Second)
		
		start := time.Now()
		err := w.createSnapshot()
		duration := time.Since(start)

		// Record metrics
		status := "success"
		if err != nil {
			status = "error"
			log.Printf("Error creating snapshot: %v", err)
		}

		tasksProcessed.WithLabelValues(w.ID, status).Inc()
		processingDuration.WithLabelValues(w.ID, "snapshot").Observe(duration.Seconds())
	}
}

func (w *DAGStateWorker) processSingleDAGTask(taskData string) error {
	var task DAGTask
	if err := json.Unmarshal([]byte(taskData), &task); err != nil {
		return fmt.Errorf("failed to unmarshal DAG task: %w", err)
	}

	switch task.Type {
	case "update_dag":
		return w.updateDAG(task.VertexID, task.Data)
	case "calculate_ancestry":
		return w.calculateAncestry(task.VertexID)
	case "finalize_vertex":
		return w.finalizeVertex(task.VertexID)
	default:
		return fmt.Errorf("unknown DAG task type: %s", task.Type)
	}
}

func (w *DAGStateWorker) processSingleStateTask(taskData string) error {
	var task StateTask
	if err := json.Unmarshal([]byte(taskData), &task); err != nil {
		return fmt.Errorf("failed to unmarshal State task: %w", err)
	}

	switch task.Type {
	case "apply_state_changes":
		return w.applyStateChanges(task.VertexID, task.AccountID, task.Changes)
	case "verify_state":
		return w.verifyState(task.VertexID)
	case "rollback_state":
		return w.rollbackState(task.VertexID)
	default:
		return fmt.Errorf("unknown State task type: %s", task.Type)
	}
}

func (w *DAGStateWorker) updateDAG(vertexID string, data json.RawMessage) error {
	// Simulate DAG update processing
	log.Printf("Worker %s: Updating DAG for vertex %s", w.ID, vertexID)
	
	// Store in database
	_, err := w.db.Exec(`
		INSERT INTO dag_state.dag_vertices (vertex_id, parent_ids, children_ids, depth, ancestry_path, confidence_score)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (vertex_id) DO UPDATE SET
			confidence_score = EXCLUDED.confidence_score,
			updated_at = NOW()
	`, vertexID, "{}", "{}", 0, "{}", 0.5)
	
	return err
}

func (w *DAGStateWorker) calculateAncestry(vertexID string) error {
	log.Printf("Worker %s: Calculating ancestry for vertex %s", w.ID, vertexID)
	
	// Simulate ancestry calculation (complex operation)
	time.Sleep(time.Duration(100+len(vertexID)) * time.Millisecond)
	
	// Update ancestry path in database
	_, err := w.db.Exec(`
		UPDATE dag_state.dag_vertices 
		SET ancestry_path = $1, depth = $2
		WHERE vertex_id = $3
	`, "{}", 1, vertexID)
	
	return err
}

func (w *DAGStateWorker) finalizeVertex(vertexID string) error {
	log.Printf("Worker %s: Finalizing vertex %s", w.ID, vertexID)
	
	_, err := w.db.Exec(`
		UPDATE dag_state.dag_vertices 
		SET finalized = true, finalized_at = NOW()
		WHERE vertex_id = $1
	`, vertexID)
	
	return err
}

func (w *DAGStateWorker) applyStateChanges(vertexID, accountID string, changes json.RawMessage) error {
	log.Printf("Worker %s: Applying state changes for vertex %s, account %s", w.ID, vertexID, accountID)
	
	// Store state update
	_, err := w.db.Exec(`
		INSERT INTO dag_state.state_updates (vertex_id, account_address, state_changes, applied)
		VALUES ($1, $2, $3, true)
	`, vertexID, accountID, changes)
	
	return err
}

func (w *DAGStateWorker) verifyState(vertexID string) error {
	log.Printf("Worker %s: Verifying state for vertex %s", w.ID, vertexID)
	
	// Simulate state verification
	time.Sleep(50 * time.Millisecond)
	
	return nil
}

func (w *DAGStateWorker) rollbackState(vertexID string) error {
	log.Printf("Worker %s: Rolling back state for vertex %s", w.ID, vertexID)
	
	_, err := w.db.Exec(`
		UPDATE dag_state.state_updates 
		SET applied = false
		WHERE vertex_id = $1
	`, vertexID)
	
	return err
}

func (w *DAGStateWorker) createSnapshot() error {
	snapshotID := fmt.Sprintf("snapshot_%d", time.Now().Unix())
	log.Printf("Worker %s: Creating snapshot %s", w.ID, snapshotID)
	
	// Create snapshot
	_, err := w.db.Exec(`
		INSERT INTO dag_state.snapshots (snapshot_id, vertex_id, state_root, account_states)
		VALUES ($1, $2, $3, $4)
	`, snapshotID, "latest", "0x123", "{}")
	
	return err
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
} 