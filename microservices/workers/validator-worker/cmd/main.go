package main

import (
    "context"
    "crypto/sha256"
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

// ValidatorWorker processes validation tasks in parallel
type ValidatorWorker struct {
    ID           string
    RedisClient  *redis.Client
    TaskQueue    string
    ResultQueue  string
    WorkerPool   chan chan ValidationTask
    Workers      []ValidationTaskWorker
    Quit         chan bool
    WaitGroup    sync.WaitGroup
    ProcessedTasks int64
    ValidTasks     int64
    InvalidTasks   int64
    mu           sync.RWMutex
}

// ValidationTask represents a transaction validation task
type ValidationTask struct {
    ID            string              `json:"id"`
    Type          string              `json:"type"`
    TransactionID ids.ID              `json:"transaction_id"`
    Transaction   Transaction  `json:"transaction"`
    Signature     []byte              `json:"signature"`
    PublicKey     []byte              `json:"public_key"`
    Priority      string              `json:"priority"`
    Timestamp     time.Time           `json:"timestamp"`
    RetryCount    int                 `json:"retry_count"`
}

// ValidationResult represents the result of validation processing
type ValidationResult struct {
    TaskID        string        `json:"task_id"`
    TransactionID ids.ID        `json:"transaction_id"`
    Valid         bool          `json:"valid"`
    Reason        string        `json:"reason"`
    Duration      time.Duration `json:"duration"`
    WorkerID      string        `json:"worker_id"`
    Timestamp     time.Time     `json:"timestamp"`
    Error         string        `json:"error,omitempty"`
}

// ValidationTaskWorker processes individual validation tasks
type ValidationTaskWorker struct {
    ID          string
    WorkerPool  chan chan ValidationTask
    TaskChannel chan ValidationTask
    Quit        chan bool
    Parent      *ValidatorWorker
}

func main() {
    // Configuration from environment
    workerID := getEnv("WORKER_ID", fmt.Sprintf("validator-worker-%d", time.Now().Unix()))
    redisURL := getEnv("REDIS_URL", "redis://localhost:6379")
    taskQueue := getEnv("TASK_QUEUE", "validation_tasks")
    resultQueue := getEnv("RESULT_QUEUE", "validation_results")
    maxWorkers := getEnvAsInt("MAX_WORKERS", 15)
    
    log.Printf("Starting Validator Worker: %s", workerID)
    
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
    
    // Create validator worker
    worker := NewValidatorWorker(workerID, redisClient, taskQueue, resultQueue, maxWorkers)
    
    // Start HTTP server for health checks
    go startHTTPServer(worker)
    
    // Start worker
    worker.Start(ctx)
    
    // Wait for shutdown signal
    sigChan := make(chan os.Signal, 1)
    signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
    <-sigChan
    
    log.Println("Shutting down validator worker...")
    worker.Stop()
    log.Println("Validator worker stopped")
}

// NewValidatorWorker creates a new validator worker
func NewValidatorWorker(id string, redisClient *redis.Client, taskQueue, resultQueue string, maxWorkers int) *ValidatorWorker {
    worker := &ValidatorWorker{
        ID:          id,
        RedisClient: redisClient,
        TaskQueue:   taskQueue,
        ResultQueue: resultQueue,
        WorkerPool:  make(chan chan ValidationTask, maxWorkers),
        Workers:     make([]ValidationTaskWorker, maxWorkers),
        Quit:        make(chan bool),
    }
    
    // Create worker pool
    for i := 0; i < maxWorkers; i++ {
        taskWorker := ValidationTaskWorker{
            ID:          fmt.Sprintf("%s-task-%d", id, i),
            WorkerPool:  worker.WorkerPool,
            TaskChannel: make(chan ValidationTask),
            Quit:        make(chan bool),
            Parent:      worker,
        }
        worker.Workers[i] = taskWorker
    }
    
    return worker
}

// Start begins processing validation tasks
func (vw *ValidatorWorker) Start(ctx context.Context) {
    log.Printf("Starting validator worker %s with %d task workers", vw.ID, len(vw.Workers))
    
    // Start all task workers
    for i := range vw.Workers {
        go vw.Workers[i].run()
    }
    
    // Start task dispatcher
    go vw.dispatcher(ctx)
    
    // Start metrics reporter
    go vw.reportMetrics(ctx)
    
    log.Printf("Validator worker %s started successfully", vw.ID)
}

// Stop stops the validator worker
func (vw *ValidatorWorker) Stop() {
    log.Printf("Stopping validator worker %s", vw.ID)
    
    // Stop all task workers
    for i := range vw.Workers {
        close(vw.Workers[i].Quit)
    }
    
    // Signal dispatcher to stop
    close(vw.Quit)
    
    // Wait for all goroutines to finish
    vw.WaitGroup.Wait()
    
    log.Printf("Validator worker %s stopped", vw.ID)
}

// dispatcher listens for tasks and distributes them to workers
func (vw *ValidatorWorker) dispatcher(ctx context.Context) {
    vw.WaitGroup.Add(1)
    defer vw.WaitGroup.Done()
    
    for {
        select {
        case <-vw.Quit:
            log.Printf("Dispatcher for worker %s stopping", vw.ID)
            return
        default:
            // Get task from Redis queue
            result := vw.RedisClient.BRPop(ctx, 5*time.Second, vw.TaskQueue)
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
            var task ValidationTask
            if err := json.Unmarshal([]byte(result.Val()[1]), &task); err != nil {
                log.Printf("Error parsing task: %v", err)
                continue
            }
            
            // Find available worker
            select {
            case taskChannel := <-vw.WorkerPool:
                // Send task to available worker
                taskChannel <- task
            case <-time.After(10 * time.Second):
                // No worker available, put task back in queue
                taskData, _ := json.Marshal(task)
                vw.RedisClient.LPush(ctx, vw.TaskQueue, taskData)
                log.Printf("No worker available, task %s returned to queue", task.ID)
            }
        }
    }
}

// reportMetrics reports worker metrics
func (vw *ValidatorWorker) reportMetrics(ctx context.Context) {
    vw.WaitGroup.Add(1)
    defer vw.WaitGroup.Done()
    
    ticker := time.NewTicker(30 * time.Second)
    defer ticker.Stop()
    
    for {
        select {
        case <-vw.Quit:
            return
        case <-ticker.C:
            vw.mu.RLock()
            metrics := map[string]interface{}{
                "worker_id":       vw.ID,
                "processed_tasks": vw.ProcessedTasks,
                "valid_tasks":     vw.ValidTasks,
                "invalid_tasks":   vw.InvalidTasks,
                "active_workers":  len(vw.Workers),
                "timestamp":       time.Now(),
                "type":           "validator_worker_metrics",
            }
            vw.mu.RUnlock()
            
            metricsData, _ := json.Marshal(metrics)
            vw.RedisClient.Publish(ctx, "worker_metrics", metricsData)
        }
    }
}

// run is the main loop for the validation task worker
func (vtw *ValidationTaskWorker) run() {
    for {
        // Register worker in pool
        vtw.WorkerPool <- vtw.TaskChannel
        
        select {
        case task := <-vtw.TaskChannel:
            // Process the task
            result := vtw.processTask(task)
            
            // Send result back
            vtw.sendResult(result)
            
            // Update metrics
            vtw.Parent.mu.Lock()
            vtw.Parent.ProcessedTasks++
            if result.Valid {
                vtw.Parent.ValidTasks++
            } else {
                vtw.Parent.InvalidTasks++
            }
            vtw.Parent.mu.Unlock()
            
        case <-vtw.Quit:
            log.Printf("Validation task worker %s stopping", vtw.ID)
            return
        }
    }
}

// processTask processes a validation task
func (vtw *ValidationTaskWorker) processTask(task ValidationTask) ValidationResult {
    startTime := time.Now()
    
    log.Printf("Worker %s validating task %s (type: %s)", vtw.ID, task.ID, task.Type)
    
    result := ValidationResult{
        TaskID:        task.ID,
        TransactionID: task.TransactionID,
        WorkerID:      vtw.ID,
        Timestamp:     time.Now(),
    }
    
    switch task.Type {
    case "transaction_validation":
        result.Valid, result.Reason = vtw.validateTransaction(task)
    case "signature_verification":
        result.Valid, result.Reason = vtw.verifySignature(task)
    case "balance_check":
        result.Valid, result.Reason = vtw.checkBalance(task)
    case "format_validation":
        result.Valid, result.Reason = vtw.validateFormat(task)
    default:
        result.Valid = false
        result.Reason = fmt.Sprintf("Unknown validation type: %s", task.Type)
        result.Error = result.Reason
    }
    
    result.Duration = time.Since(startTime)
    
    log.Printf("Worker %s completed validation %s in %v (valid: %t)", 
        vtw.ID, task.ID, result.Duration, result.Valid)
    
    return result
}

// validateTransaction validates a complete transaction
func (vtw *ValidationTaskWorker) validateTransaction(task ValidationTask) (bool, string) {
    // Simulate transaction validation
    time.Sleep(5 * time.Millisecond)
    
    tx := task.Transaction
    
    // Check basic transaction structure
    if tx.ID.String() == "" {
        return false, "Transaction ID is empty"
    }
    
    if len(tx.Data) == 0 {
        return false, "Transaction data is empty"
    }
    
    if tx.Size <= 0 {
        return false, "Invalid transaction size"
    }
    
    // Verify transaction hash
    expectedHash := sha256.Sum256(tx.Data)
    if tx.Hash.String() != fmt.Sprintf("%x", expectedHash) {
        return false, "Transaction hash mismatch"
    }
    
    return true, "Transaction is valid"
}

// verifySignature verifies transaction signature
func (vtw *ValidationTaskWorker) verifySignature(task ValidationTask) (bool, string) {
    // Simulate signature verification
    time.Sleep(10 * time.Millisecond)
    
    if len(task.Signature) == 0 {
        return false, "Signature is empty"
    }
    
    if len(task.PublicKey) == 0 {
        return false, "Public key is empty"
    }
    
    // Simulate signature verification (90% success rate)
    hash := sha256.Sum256(append(task.Transaction.Data, task.PublicKey...))
    if hash[0]%10 < 9 {
        return true, "Signature is valid"
    }
    
    return false, "Invalid signature"
}

// checkBalance checks if sender has sufficient balance
func (vtw *ValidationTaskWorker) checkBalance(task ValidationTask) (bool, string) {
    // Simulate balance check
    time.Sleep(3 * time.Millisecond)
    
    // Simulate balance lookup (95% success rate)
    if task.Transaction.Hash[0]%20 < 19 {
        return true, "Sufficient balance"
    }
    
    return false, "Insufficient balance"
}

// validateFormat validates transaction format
func (vtw *ValidationTaskWorker) validateFormat(task ValidationTask) (bool, string) {
    // Simulate format validation
    time.Sleep(2 * time.Millisecond)
    
    tx := task.Transaction
    
    // Check timestamp
    if tx.Timestamp.IsZero() {
        return false, "Invalid timestamp"
    }
    
    // Check if timestamp is not in the future
    if tx.Timestamp.After(time.Now().Add(5 * time.Minute)) {
        return false, "Transaction timestamp is too far in the future"
    }
    
    // Check data size limits
    if len(tx.Data) > 1024*1024 { // 1MB limit
        return false, "Transaction data too large"
    }
    
    return true, "Format is valid"
}

// sendResult sends the validation result back
func (vtw *ValidationTaskWorker) sendResult(result ValidationResult) {
    ctx := context.Background()
    resultData, err := json.Marshal(result)
    if err != nil {
        log.Printf("Error marshaling result: %v", err)
        return
    }
    
    err = vtw.Parent.RedisClient.LPush(ctx, vtw.Parent.ResultQueue, resultData).Err()
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
func startHTTPServer(worker *ValidatorWorker) {
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
        validTasks := worker.ValidTasks
        invalidTasks := worker.InvalidTasks
        worker.mu.RUnlock()
        
        json.NewEncoder(w).Encode(map[string]interface{}{
            "worker_id":       worker.ID,
            "processed_tasks": processedTasks,
            "valid_tasks":     validTasks,
            "invalid_tasks":   invalidTasks,
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