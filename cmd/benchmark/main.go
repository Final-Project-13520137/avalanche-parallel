// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"runtime"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/pkg/consensus"
	"go.uber.org/zap"
)

func main() {
	// Parse command line flags
	workers := flag.Int("workers", runtime.NumCPU(), "Number of worker goroutines")
	transactions := flag.Int("transactions", 1000, "Number of transactions to process")
	flag.Parse()

	// Setup logging
	logger, err := zap.NewProduction()
	if err != nil {
		fmt.Printf("Failed to create logger: %v\n", err)
		os.Exit(1)
	}
	defer logger.Sync()

	// Initialize consensus engine
	engine := consensus.NewConsensusEngine(logger, *workers)

	// Run benchmark
	startTime := time.Now()

	ctx := context.Background()
	if err := engine.ProcessTransactions(ctx, *transactions); err != nil {
		logger.Error("Failed to process transactions", zap.Error(err))
		os.Exit(1)
	}

	duration := time.Since(startTime)
	tps := float64(*transactions) / duration.Seconds()

	// Print results
	fmt.Printf("\nBenchmark Results:\n")
	fmt.Printf("Workers: %d\n", *workers)
	fmt.Printf("Transactions: %d\n", *transactions)
	fmt.Printf("Duration: %v\n", duration)
	fmt.Printf("TPS: %.2f\n", tps)
}
