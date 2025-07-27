// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"flag"
	"fmt"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/ava-labs/avalanchego/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

func main() {
	// Parse command line flags
	port := flag.Int("port", 8545, "API server port")
	parallelism := flag.Int("parallelism", 4, "Maximum level of parallelism")
	logLevel := flag.String("log-level", "info", "Logging level (debug, info, warn, error)")
	flag.Parse()

	// Setup logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: *logLevel,
		LogLevel:     *logLevel,
	})
	log, err := logFactory.Make("blockchain")
	if err != nil {
		fmt.Printf("Failed to create logger: %s\n", err)
		os.Exit(1)
	}

	// Create node config
	config := blockchain.NodeConfig{
		MaxParallelism: *parallelism,
		APIPort:        *port,
	}

	// Create and start node
	log.Info("Starting Avalanche Parallel Blockchain node...")
	node, err := blockchain.NewNode(log, config)
	if err != nil {
		log.Fatal("Failed to create node: %s", err)
	}

	if err := node.Start(); err != nil {
		log.Fatal("Failed to start node: %s", err)
	}

	log.Info("Node started successfully")
	log.Info("API server running on port %d", *port)
	log.Info("Press Ctrl+C to stop")

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Info("Shutting down...")
	if err := node.Stop(); err != nil {
		log.Error("Error during shutdown: %s", err)
	}

	// Give time for cleanup
	time.Sleep(1 * time.Second)
	log.Info("Node stopped")
} 
