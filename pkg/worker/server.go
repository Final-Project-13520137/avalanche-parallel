// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package worker

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// Server implements the worker service
type Server struct {
	logger     logging.Logger
	workerPool *WorkerPool
	server     *http.Server
	lock       sync.RWMutex
	tasks      map[string]Task
}

// NewServer creates a new worker server
func NewServer(logger logging.Logger, addr string, numWorkers int) *Server {
	workerPool := NewWorkerPool(logger, 100) // Buffer for 100 tasks
	
	// Create default workers
	for i := 0; i < numWorkers; i++ {
		workerID := fmt.Sprintf("worker-%d", i)
		worker := NewDefaultWorker(workerID, logger)
		workerPool.AddWorker(workerID, worker)
	}
	
	s := &Server{
		logger:     logger,
		workerPool: workerPool,
		tasks:      make(map[string]Task),
	}
	
	router := mux.NewRouter()
	router.HandleFunc("/tasks", s.handleSubmitTask).Methods(http.MethodPost)
	router.HandleFunc("/tasks/{id}", s.handleGetTaskResult).Methods(http.MethodGet)
	router.HandleFunc("/health", s.handleHealth).Methods(http.MethodGet)
	router.HandleFunc("/readiness", s.handleReadiness).Methods(http.MethodGet)
	
	s.server = &http.Server{
		Addr:         addr,
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}
	
	return s
}

// Start starts the server
func (s *Server) Start(ctx context.Context) error {
	// Start the worker pool
	s.workerPool.Start(ctx, 10) // Start with 10 worker goroutines
	
	// Start the HTTP server
	go func() {
		if err := s.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			s.logger.Error("Server error: %s", err)
		}
	}()
	
	s.logger.Info("Server started on %s", s.server.Addr)
	
	// Wait for shutdown signal
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, os.Interrupt, syscall.SIGTERM)
	
	select {
	case <-ctx.Done():
		s.logger.Info("Shutting down server due to context cancellation")
	case <-stop:
		s.logger.Info("Shutting down server due to signal")
	}
	
	// Create a shutdown context with timeout
	shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	
	// Shutdown the server
	if err := s.server.Shutdown(shutdownCtx); err != nil {
		s.logger.Error("Server shutdown error: %s", err)
		return err
	}
	
	// Stop the worker pool
	s.workerPool.Stop()
	
	s.logger.Info("Server stopped gracefully")
	return nil
}

// handleSubmitTask handles task submission
func (s *Server) handleSubmitTask(w http.ResponseWriter, r *http.Request) {
	var req TaskRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid request: %s", err), http.StatusBadRequest)
		return
	}
	
	taskID := uuid.New().String()
	task := Task{
		ID:        taskID,
		Payload:   req.Payload,
		StartTime: time.Now(),
	}
	
	// Store the task
	s.lock.Lock()
	s.tasks[taskID] = task
	s.lock.Unlock()
	
	// Submit the task to the worker pool
	s.workerPool.SubmitTask(task)
	
	// Return the task ID
	resp := TaskResponse{
		TaskID: taskID,
		Status: "accepted",
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusAccepted)
	json.NewEncoder(w).Encode(resp)
}

// handleGetTaskResult handles task result retrieval
func (s *Server) handleGetTaskResult(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	taskID := vars["id"]
	
	// Check if the task exists
	s.lock.RLock()
	_, exists := s.tasks[taskID]
	s.lock.RUnlock()
	
	if !exists {
		http.Error(w, fmt.Sprintf("Task not found: %s", taskID), http.StatusNotFound)
		return
	}
	
	// Get the result
	result, found := s.workerPool.GetResult(taskID)
	if !found {
		// Task exists but result not ready
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusAccepted)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "processing",
		})
		return
	}
	
	// Return the result
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(result)
}

// handleHealth handles health check requests
func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "healthy",
	})
}

// handleReadiness handles readiness check requests
func (s *Server) handleReadiness(w http.ResponseWriter, r *http.Request) {
	// Check if we have workers available
	workers := s.workerPool.GetWorkers()
	if len(workers) == 0 {
		w.WriteHeader(http.StatusServiceUnavailable)
		json.NewEncoder(w).Encode(map[string]string{
			"status": "not ready - no workers available",
		})
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(map[string]string{
		"status": "ready",
	})
} 