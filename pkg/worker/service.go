// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package worker

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

// Task represents a unit of work to be processed
type Task struct {
	ID        string
	Payload   []byte
	StartTime time.Time
}

// Result represents the outcome of a task
type Result struct {
	TaskID    string
	Output    []byte
	Error     error
	StartTime time.Time
	EndTime   time.Time
}

// Worker defines the interface for task processors
type Worker interface {
	ProcessTask(ctx context.Context, task Task) (Result, error)
}

// DefaultWorker implements the Worker interface
type DefaultWorker struct {
	id     string
	logger logging.Logger
}

// NewDefaultWorker creates a new worker instance
func NewDefaultWorker(id string, logger logging.Logger) *DefaultWorker {
	return &DefaultWorker{
		id:     id,
		logger: logger,
	}
}

// ProcessTask handles the processing of a task
func (w *DefaultWorker) ProcessTask(ctx context.Context, task Task) (Result, error) {
	startTime := time.Now()
	
	// Process the task (implement the actual processing logic)
	// This is just a placeholder
	time.Sleep(100 * time.Millisecond)
	
	result := Result{
		TaskID:    task.ID,
		Output:    []byte(fmt.Sprintf("Processed by worker %s", w.id)),
		StartTime: task.StartTime,
		EndTime:   time.Now(),
	}
	
	return result, nil
}

// WorkerPool manages a pool of workers
type WorkerPool struct {
	lock     sync.RWMutex
	workers  map[string]Worker
	taskChan chan Task
	results  map[string]Result
	logger   logging.Logger
	wg       sync.WaitGroup
}

// NewWorkerPool creates a new worker pool
func NewWorkerPool(logger logging.Logger, capacity int) *WorkerPool {
	return &WorkerPool{
		workers:  make(map[string]Worker),
		taskChan: make(chan Task, capacity),
		results:  make(map[string]Result),
		logger:   logger,
	}
}

// AddWorker adds a worker to the pool
func (wp *WorkerPool) AddWorker(id string, worker Worker) {
	wp.lock.Lock()
	defer wp.lock.Unlock()
	
	wp.workers[id] = worker
}

// RemoveWorker removes a worker from the pool
func (wp *WorkerPool) RemoveWorker(id string) {
	wp.lock.Lock()
	defer wp.lock.Unlock()
	
	delete(wp.workers, id)
}

// GetWorkers returns all registered workers
func (wp *WorkerPool) GetWorkers() map[string]Worker {
	wp.lock.RLock()
	defer wp.lock.RUnlock()
	
	// Create a copy to avoid race conditions
	workersCopy := make(map[string]Worker, len(wp.workers))
	for id, worker := range wp.workers {
		workersCopy[id] = worker
	}
	
	return workersCopy
}

// SubmitTask submits a task to the worker pool
func (wp *WorkerPool) SubmitTask(task Task) {
	wp.taskChan <- task
}

// Start starts the worker pool
func (wp *WorkerPool) Start(ctx context.Context, numWorkers int) {
	// Start worker goroutines
	for i := 0; i < numWorkers; i++ {
		wp.wg.Add(1)
		go func() {
			defer wp.wg.Done()
			for {
				select {
				case task, ok := <-wp.taskChan:
					if !ok {
						return
					}
					
					// Find an available worker
					wp.lock.RLock()
					workers := make([]Worker, 0, len(wp.workers))
					for _, w := range wp.workers {
						workers = append(workers, w)
					}
					wp.lock.RUnlock()
					
					if len(workers) == 0 {
						wp.logger.Warn("No workers available to process task %s", task.ID)
						continue
					}
					
					// Use a simple round-robin approach for now
					// In a real implementation, we would use a better scheduling algorithm
					worker := workers[task.ID[0]%byte(len(workers))]
					
					// Process the task
					result, err := worker.ProcessTask(ctx, task)
					if err != nil {
						wp.logger.Error("Failed to process task %s: %s", task.ID, err)
						result.Error = err
					}
					
					// Store the result
					wp.lock.Lock()
					wp.results[task.ID] = result
					wp.lock.Unlock()
					
				case <-ctx.Done():
					return
				}
			}
		}()
	}
}

// Stop stops the worker pool
func (wp *WorkerPool) Stop() {
	close(wp.taskChan)
	wp.wg.Wait()
}

// GetResult returns the result for a specific task
func (wp *WorkerPool) GetResult(taskID string) (Result, bool) {
	wp.lock.RLock()
	defer wp.lock.RUnlock()
	
	result, found := wp.results[taskID]
	return result, found
} 