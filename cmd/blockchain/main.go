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

	"github.com/Final-Project-13520137/avalanche-parallel/pkg/blockchain"
	"go.uber.org/zap"
)

func main() {
	// Parse command line flags
	port := flag.Int("port", 8545, "API server port")
	parallelism := flag.Int("parallelism", 4, "Maximum level of parallelism")
	logLevel := flag.String("log-level", "info", "Logging level (debug, info, warn, error)")
	flag.Parse()

	// Setup logger
	var level zap.AtomicLevel
	switch *logLevel {
	case "debug":
		level = zap.NewAtomicLevelAt(zap.DebugLevel)
	case "info":
		level = zap.NewAtomicLevelAt(zap.InfoLevel)
	case "warn":
		level = zap.NewAtomicLevelAt(zap.WarnLevel)
	case "error":
		level = zap.NewAtomicLevelAt(zap.ErrorLevel)
	default:
		level = zap.NewAtomicLevelAt(zap.InfoLevel)
	}

	config := zap.NewProductionConfig()
	config.Level = level
	log, err := config.Build()
	if err != nil {
		fmt.Printf("Failed to create logger: %s\n", err)
		os.Exit(1)
	}
	defer log.Sync()

	// Create node config
	nodeConfig := blockchain.NodeConfig{
		MaxParallelism: *parallelism,
		APIPort:        *port,
	}

	// Create and start node
	log.Info("Starting Avalanche Parallel Blockchain node...")
	node, err := blockchain.NewNode(log, nodeConfig)
	if err != nil {
		log.Fatal("Failed to create node", zap.Error(err))
	}

	if err := node.Start(); err != nil {
		log.Fatal("Failed to start node", zap.Error(err))
	}

	log.Info("Node started successfully")
	log.Info("API server running on port", zap.Int("port", *port))
	log.Info("Press Ctrl+C to stop")

	// Wait for shutdown signal
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	<-sigChan

	log.Info("Shutting down...")
	if err := node.Stop(); err != nil {
		log.Error("Error during shutdown", zap.Error(err))
	}

	// Give time for cleanup
	time.Sleep(1 * time.Second)
	log.Info("Node stopped")
}
