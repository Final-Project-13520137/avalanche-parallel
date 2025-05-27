// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"
)

func main() {
	fmt.Println("Starting Avalanche DAG worker service")
	
	// Setup HTTP server
	mux := http.NewServeMux()
	
	mux.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"healthy"}`))
	})
	
	mux.HandleFunc("/tasks", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"accepted","task_id":"placeholder"}`))
	})
	
	port := os.Getenv("PORT")
	if port == "" {
		port = "9652"
	}
	
	// Create server
	server := &http.Server{
		Addr:    ":" + port,
		Handler: mux,
	}
	
	// Start server in goroutine so it doesn't block signal handling
	go func() {
		fmt.Printf("Worker service listening on port %s\n", port)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			fmt.Printf("Server error: %s\n", err)
			os.Exit(1)
		}
	}()
	
	// Setup signal handling
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
	
	// Wait for signal
	<-sigs
	fmt.Println("Shutting down worker service...")
	
	// Graceful shutdown with 5 second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := server.Shutdown(ctx); err != nil {
		fmt.Printf("Server shutdown error: %s\n", err)
	}
	
	fmt.Println("Worker service stopped")
} 