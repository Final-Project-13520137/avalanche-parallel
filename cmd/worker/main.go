// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"strconv"

	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel/default/version"
	"github.com/avalanche-parallel-dag/pkg/worker"
)

const (
	defaultPort           = 9650
	defaultMaxWorkers     = 4
	defaultLogLevel       = "info"
	defaultProcessThreads = 4
)

func main() {
	fs := flag.NewFlagSet("avalanche-dag-worker", flag.ContinueOnError)

	// Define flags
	port := fs.Int("port", defaultPort, "Port to listen on")
	maxWorkers := fs.Int("max-workers", defaultMaxWorkers, "Maximum number of worker instances")
	logLevel := fs.String("log-level", defaultLogLevel, "Log level (debug, info, warn, error, fatal)")
	processingThreads := fs.Int("processing-threads", defaultProcessThreads, "Number of processing threads per worker")

	// Parse flags
	if err := fs.Parse(os.Args[1:]); err != nil {
		fmt.Printf("Failed to parse flags: %s\n", err)
		os.Exit(1)
	}

	// Check for environment variables
	if portEnv := os.Getenv("PORT"); portEnv != "" {
		if p, err := strconv.Atoi(portEnv); err == nil {
			*port = p
		}
	}

	if maxWorkersEnv := os.Getenv("MAX_WORKERS"); maxWorkersEnv != "" {
		if mw, err := strconv.Atoi(maxWorkersEnv); err == nil {
			*maxWorkers = mw
		}
	}

	if logLevelEnv := os.Getenv("LOG_LEVEL"); logLevelEnv != "" {
		*logLevel = logLevelEnv
	}

	if threadsEnv := os.Getenv("MAX_PROCESSING_THREADS"); threadsEnv != "" {
		if pt, err := strconv.Atoi(threadsEnv); err == nil {
			*processingThreads = pt
		}
	}

	// Setup logging
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: *logLevel,
	})
	log, err := logFactory.Make("worker")
	if err != nil {
		fmt.Printf("Failed to create logger: %s\n", err)
		os.Exit(1)
	}

	// Log version info
	log.Info("Starting Avalanche DAG Worker version %s", version.Current)
	log.Info("Git commit: %s", version.GitCommit)

	// Create server
	addr := fmt.Sprintf(":%d", *port)
	server := worker.NewServer(log, addr, *processingThreads)

	// Start server
	ctx := context.Background()
	log.Info("Starting worker server with %d processing threads", *processingThreads)
	if err := server.Start(ctx); err != nil {
		log.Fatal("Server error: %s", err)
		os.Exit(1)
	}
} 