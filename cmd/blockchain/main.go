// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

func main() {
	// Parse command line flags
	parallelism := flag.Int("parallelism", 4, "Maximum parallelism for consensus")
	apiPort := flag.Int("api-port", 8545, "API server port")
	logLevel := flag.String("log-level", "info", "Logging level (debug, info, warn, error)")
	flag.Parse()

	// Initialize logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: *logLevel,
	})
	logger, err := logFactory.Make("avalanche-blockchain")
	if err != nil {
		fmt.Printf("Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}

	// Create blockchain node
	nodeConfig := blockchain.NodeConfig{
		MaxParallelism: *parallelism,
		APIPort:        *apiPort,
	}

	node, err := blockchain.NewNode(logger, nodeConfig)
	if err != nil {
		logger.Fatal("Failed to create blockchain node: %s", err)
	}

	// Start the node
	if err := node.Start(); err != nil {
		logger.Fatal("Failed to start blockchain node: %s", err)
	}

	logger.Info("Avalanche blockchain started with parallelism=%d, API port=%d", *parallelism, *apiPort)
	logger.Info("Press Ctrl+C to stop the node")

	// Setup graceful shutdown
	signalChan := make(chan os.Signal, 1)
	signal.Notify(signalChan, syscall.SIGINT, syscall.SIGTERM)

	// Wait for termination signal
	<-signalChan
	logger.Info("Shutdown signal received, stopping node...")

	// Create a timeout context for shutdown
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Stop the node
	if err := node.Stop(); err != nil {
		logger.Error("Error stopping node: %s", err)
		os.Exit(1)
	}

	// Wait for context timeout or completion
	<-ctx.Done()
	if ctx.Err() == context.DeadlineExceeded {
		logger.Error("Shutdown timed out")
		os.Exit(1)
	}

	logger.Info("Node stopped successfully")
} 