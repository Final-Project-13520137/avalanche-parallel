package main

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
    "github.com/ava-labs/avalanchego/ids"
    "github.com/ava-labs/avalanchego/snow/choices"
)

// Transaction represents a transaction in the system
type Transaction struct {
    ID        ids.ID      `json:"id"`
    From      string      `json:"from"`
    To        string      `json:"to"`
    Amount    uint64      `json:"amount"`
    Data      []byte      `json:"data"`
    Hash      ids.ID      `json:"hash"`
    Size      int         `json:"size"`
    Nonce     uint64      `json:"nonce"`
    Timestamp time.Time   `json:"timestamp"`
}

// ConsensusWorker processes consensus tasks in parallel
type ConsensusWorker struct {
    ID           string
    RedisClient  *redis.Client
    TaskQueue    string
    ResultQueue  string
    WorkerPool   chan chan ConsensusTask
    Workers      []Worker
    Quit         chan bool
    WaitGroup    sync.WaitGroup
    ProcessedTasks int64
    mu           sync.RWMutex
}

// ConsensusTask represents a consensus task
type ConsensusTask struct {
    ID          string              `json:"id"`
    Type        string              `json:"type"`
    VertexID    ids.ID              `json:"vertex_id"`
    ParentIDs   []ids.ID            `json:"parent_ids"`
    Transactions []Transaction `json:"transactions"`
    Priority    string              `json:"priority"`
    Timestamp   time.Time           `json:"timestamp"`
    RetryCount  int                 `json:"retry_count"`
}

// ConsensusResult represents the result of consensus processing
type ConsensusResult struct {
    TaskID      string         `json:"task_id"`
    VertexID    ids.ID         `json:"vertex_id"`
    Status      choices.Status `json:"status"`
    Confidence  int           `json:"confidence"`
    Finalized   bool          `json:"finalized"`
    Duration    time.Duration `json:"duration"`
    WorkerID    string        `json:"worker_id"`
    Timestamp   time.Time     `json:"timestamp"`
    Error       string        `json:"error,omitempty"`
}

// Worker interface for processing tasks
type Worker interface {
    Start()
    Stop()
    ProcessTask(task ConsensusTask) ConsensusResult
}

// ConsensusTaskWorker implements the Worker interface
type ConsensusTaskWorker struct {
    ID         string
    WorkerPool chan chan ConsensusTask
    TaskChannel chan ConsensusTask
    Quit       chan bool
    Parent     *ConsensusWorker
}

func main() {
    // Configuration from environment
    workerID := getEnv("WORKER_ID", fmt.Sprintf("consensus-worker-%d", time.Now().Unix()))
    redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
    taskQueue := getEnv("TASK_QUEUE", "consensus_tasks")
    resultQueue := getEnv("RESULT_QUEUE", "consensus_results")
    maxWorkers := getEnvAsInt("MAX_WORKERS", 10)
    
    log.Printf("Starting Consensus Worker: %s", workerID)
    
    // Create Redis client
    opt, err := redis.ParseURL(redisURL)
    if err != nil {
        log.Fatalf("Failed to parse Redis URL: %v", err)
    }
    
    redisClient := redis.NewClient(opt)
    ctx := context.Background()
    
    // Test Redis connection
    if err := redisClient.Ping(ctx).Err(); err != nil {
        log.Fatalf("Failed to connect to Redis: %v", err)
    }
    
    // Create consensus worker
    worker := NewConsensusWorker(workerID, redisClient, taskQueue, resultQueue, maxWorkers)
    
    // Start HTTP server for health checks
    go startHTTPServer(worker)
    
    // Start worker
    worker.Start(ctx)
    
    // Wait for shutdown signal
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down consensus worker...")
    worker.Stop()
    log.Println("Consensus worker stopped")
}

// NewConsensusWorker creates a new consensus worker
func NewConsensusWorker(id string, redisClient *redis.Client, taskQueue, resultQueue string, maxWorkers int) *ConsensusWorker {
    worker := &ConsensusWorker{
        ID:          id,
        RedisClient: redisClient,
        TaskQueue:   taskQueue,
        ResultQueue: resultQueue,
        WorkerPool:  make(chan chan ConsensusTask, maxWorkers),
        Workers:     make([]Worker, maxWorkers),
        Quit:        make(chan bool),
    }
    
    // Create worker pool
    for i := 0; i < maxWorkers; i++ {
        taskWorker := &ConsensusTaskWorker{
            ID:          fmt.Sprintf("%s-task-%d", id, i),
            WorkerPool:  worker.WorkerPool,
            TaskChannel: make(chan ConsensusTask),
            Quit:        make(chan bool),
            Parent:      worker,
        }
        worker.Workers[i] = taskWorker
    }
    
    return worker
}

// Start begins processing consensus tasks
func (cw *ConsensusWorker) Start(ctx context.Context) {
    log.Printf("Starting consensus worker %s with %d task workers", cw.ID, len(cw.Workers))
    
    // Start all task workers
    for _, worker := range cw.Workers {
        worker.Start()
    }
    
    // Start task dispatcher
    go cw.dispatcher(ctx)
    
    // Start metrics reporter
    go cw.reportMetrics(ctx)
    
    log.Printf("Consensus worker %s started successfully", cw.ID)
}

// Stop stops the consensus worker
func (cw *ConsensusWorker) Stop() {
    log.Printf("Stopping consensus worker %s", cw.ID)
    
    // Stop all task workers
    for _, worker := range cw.Workers {
        worker.Stop()
    }
    
    // Signal dispatcher to stop
    close(cw.Quit)
    
    // Wait for all goroutines to finish
    cw.WaitGroup.Wait()
    
    log.Printf("Consensus worker %s stopped", cw.ID)
}

// dispatcher listens for tasks and distributes them to workers
func (cw *ConsensusWorker) dispatcher(ctx context.Context) {
    cw.WaitGroup.Add(1)
    defer cw.WaitGroup.Done()
    
    for {
        select {
        case <-cw.Quit:
            log.Printf("Dispatcher for worker %s stopping", cw.ID)
            return
        default:
            // Get task from Redis queue
            result := cw.RedisClient.BRPop(ctx, 5*time.Second, cw.TaskQueue)
            if result.Err() != nil {
                if result.Err() != redis.Nil {
                    log.Printf("Error getting task from queue: %v", result.Err())
                }
                continue
            }
            
            if len(result.Val()) < 2 {
                continue
            }
            
            // Parse task
            var task ConsensusTask
            if err := json.Unmarshal([]byte(result.Val()[1]), &task); err != nil {
                log.Printf("Error parsing task: %v", err)
                continue
            }
            
            // Find available worker
            select {
            case taskChannel := <-cw.WorkerPool:
                // Send task to available worker
                taskChannel <- task
            case <-time.After(10 * time.Second):
                // No worker available, put task back in queue
                taskData, _ := json.Marshal(task)
                cw.RedisClient.LPush(ctx, cw.TaskQueue, taskData)
                log.Printf("No worker available, task %s returned to queue", task.ID)
            }
        }
    }
}

// reportMetrics reports worker metrics
func (cw *ConsensusWorker) reportMetrics(ctx context.Context) {
    cw.WaitGroup.Add(1)
    defer cw.WaitGroup.Done()
    
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-cw.Quit:
            return
        case <-ticker.C:
            cw.mu.RLock()
            processed := cw.ProcessedTasks
            cw.mu.RUnlock()
            
            metrics := map[string]interface{}{
                "worker_id":       cw.ID,
                "processed_tasks": processed,
                "active_workers":  len(cw.Workers),
                "timestamp":       time.Now(),
                "type":           "consensus_worker_metrics",
            }
            
            metricsData, _ := json.Marshal(metrics)
            cw.RedisClient.Publish(ctx, "worker_metrics", metricsData)
        }
    }
}

// Start starts the task worker
func (ctw *ConsensusTaskWorker) Start() {
    log.Printf("Starting task worker %s", ctw.ID)
    go ctw.run()
}

// Stop stops the task worker
func (ctw *ConsensusTaskWorker) Stop() {
    log.Printf("Stopping task worker %s", ctw.ID)
    close(ctw.Quit)
}

// run is the main loop for the task worker
func (ctw *ConsensusTaskWorker) run() {
    for {
        // Register worker in pool
        ctw.WorkerPool <- ctw.TaskChannel
        
        select {
        case task := <-ctw.TaskChannel:
            // Process the task
            result := ctw.ProcessTask(task)
            
            // Send result back
            ctw.sendResult(result)
            
            // Update processed count
            ctw.Parent.mu.Lock()
            ctw.Parent.ProcessedTasks++
            ctw.Parent.mu.Unlock()
            
        case <-ctw.Quit:
            log.Printf("Task worker %s stopping", ctw.ID)
            return
        }
    }
}

// ProcessTask processes a consensus task
func (ctw *ConsensusTaskWorker) ProcessTask(task ConsensusTask) ConsensusResult {
    startTime := time.Now()
    
    log.Printf("Worker %s processing task %s (type: %s)", ctw.ID, task.ID, task.Type)
    
    result := ConsensusResult{
        TaskID:    task.ID,
        VertexID:  task.VertexID,
        WorkerID:  ctw.ID,
        Timestamp: time.Now(),
    }
    
    switch task.Type {
    case "vertex_validation":
        result.Status, result.Confidence, result.Finalized = ctw.processVertexValidation(task)
    case "consensus_poll":
        result.Status, result.Confidence, result.Finalized = ctw.processConsensusPoll(task)
    case "finalization_check":
        result.Status, result.Confidence, result.Finalized = ctw.processFinalizationCheck(task)
    default:
        result.Error = fmt.Sprintf("Unknown task type: %s", task.Type)
        result.Status = choices.Unknown
    }
    
    result.Duration = time.Since(startTime)
    
    log.Printf("Worker %s completed task %s in %v (status: %s, confidence: %d)", 
        ctw.ID, task.ID, result.Duration, result.Status, result.Confidence)
    
    return result
}

// processVertexValidation validates a vertex
func (ctw *ConsensusTaskWorker) processVertexValidation(task ConsensusTask) (choices.Status, int, bool) {
    // Simulate vertex validation logic
    time.Sleep(10 * time.Millisecond) // Simulate processing time
    
    // Simple validation: check if vertex has valid parent relationships
    if len(task.ParentIDs) == 0 {
        return choices.Rejected, 0, true
    }
    
    // Simulate successful validation
    return choices.Processing, 1, false
}

// processConsensusPoll processes consensus polling
func (ctw *ConsensusTaskWorker) processConsensusPoll(task ConsensusTask) (choices.Status, int, bool) {
    // Simulate consensus polling
    time.Sleep(50 * time.Millisecond) // Simulate network polling
    
    // Simulate votes (80% acceptance rate)
    acceptVotes := 16 // out of 20 total votes
    alpha := 15       // threshold for preference
    
    if acceptVotes >= alpha {
        confidence := 5 // Increment confidence
        finalized := confidence >= 20 // Beta threshold
        
        if finalized {
            return choices.Accepted, confidence, true
        }
        return choices.Processing, confidence, false
    }
    
    return choices.Processing, 0, false
}

// processFinalizationCheck checks if vertex can be finalized
func (ctw *ConsensusTaskWorker) processFinalizationCheck(task ConsensusTask) (choices.Status, int, bool) {
    // Simulate finalization check
    time.Sleep(5 * time.Millisecond)
    
    // Simple check: assume vertex is ready for finalization
    return choices.Accepted, 20, true
}

// sendResult sends the processing result back
func (ctw *ConsensusTaskWorker) sendResult(result ConsensusResult) {
    ctx := context.Background()
    resultData, err := json.Marshal(result)
    if err != nil {
        log.Printf("Error marshaling result: %v", err)
        return
    }
    
    err = ctw.Parent.RedisClient.LPush(ctx, ctw.Parent.ResultQueue, resultData).Err()
    if err != nil {
        log.Printf("Error sending result to queue: %v", err)
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

// startHTTPServer starts an HTTP server for health checks
func startHTTPServer(worker *ConsensusWorker) {
    mux := http.NewServeMux()
    
    // Health check endpoint
    mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        json.NewEncoder(w).Encode(map[string]interface{}{
            "status":    "healthy",
            "worker_id": worker.ID,
            "uptime":    time.Since(time.Now()).String(),
        })
    })
    
    // Metrics endpoint
    mux.HandleFunc("/metrics", func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Content-Type", "application/json")
        w.WriteHeader(http.StatusOK)
        
        worker.mu.RLock()
        processedTasks := worker.ProcessedTasks
        worker.mu.RUnlock()
        
        json.NewEncoder(w).Encode(map[string]interface{}{
            "worker_id":       worker.ID,
            "processed_tasks": processedTasks,
            "active_workers":  len(worker.Workers),
            "timestamp":       time.Now().Unix(),
        })
    })
    
    // Start server
    log.Printf("Starting HTTP server on port 8080")
    if err := http.ListenAndServe(":8080", mux); err != nil {
        log.Printf("HTTP server error: %v", err)
    }
} 