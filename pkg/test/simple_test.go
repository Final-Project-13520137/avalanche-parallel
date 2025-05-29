// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"fmt"
	"os"

	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

// A simplified version of the blockchain test
func main() {
	fmt.Println("Starting simplified blockchain test...")

	// Create a mock logger for testing
	logger := &simpleLogger{}

	// Create blockchain
	bc, err := blockchain.NewBlockchain(logger, 4)
	if err != nil {
		fmt.Printf("Failed to create blockchain: %s\n", err)
		os.Exit(1)
	}

	// Test 1: Add transactions
	fmt.Println("Test 1: Adding transactions...")
	for i := 0; i < 5; i++ {
		tx, err := blockchain.NewTransaction(
			fmt.Sprintf("user%d", i%3),
			fmt.Sprintf("user%d", (i+1)%3),
			uint64(10+i),
			uint64(i),
		)
		if err != nil {
			fmt.Printf("Failed to create transaction: %s\n", err)
			continue
		}

		// Sign transaction
		err = tx.SignTransaction([]byte(fmt.Sprintf("key-%d", i)))
		if err != nil {
			fmt.Printf("Failed to sign transaction: %s\n", err)
			continue
		}

		// Add to blockchain
		err = bc.AddTransaction(tx)
		if err != nil {
			fmt.Printf("Failed to add transaction: %s\n", err)
			continue
		}

		fmt.Printf("Added transaction %d\n", i)
	}

	// Test 2: Create a block
	fmt.Println("Test 2: Creating a block...")
	block, err := bc.CreateBlock(nil, 5)
	if err != nil {
		fmt.Printf("Failed to create block: %s\n", err)
		os.Exit(1)
	}
	fmt.Printf("Created block: %s\n", block.ID())

	// Submit block
	err = bc.SubmitBlock(block)
	if err != nil {
		fmt.Printf("Failed to submit block: %s\n", err)
		os.Exit(1)
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		fmt.Printf("Failed to process blocks: %s\n", err)
		os.Exit(1)
	}

	// Print statistics
	height := bc.GetBlockchainHeight()
	latestBlocks := bc.GetLatestBlocks()
	
	fmt.Printf("Blockchain height: %d\n", height)
	fmt.Printf("Number of latest blocks: %d\n", len(latestBlocks))
	
	fmt.Println("Blockchain test completed successfully!")
}

// Simple logger implementation for testing
type simpleLogger struct{}

func (l *simpleLogger) Debug(msg string, args ...interface{}) {
	fmt.Printf("[DEBUG] "+msg+"\n", args...)
}

func (l *simpleLogger) Info(msg string, args ...interface{}) {
	fmt.Printf("[INFO] "+msg+"\n", args...)
}

func (l *simpleLogger) Warn(msg string, args ...interface{}) {
	fmt.Printf("[WARN] "+msg+"\n", args...)
}

func (l *simpleLogger) Error(msg string, args ...interface{}) {
	fmt.Printf("[ERROR] "+msg+"\n", args...)
}

func (l *simpleLogger) Fatal(msg string, args ...interface{}) {
	fmt.Printf("[FATAL] "+msg+"\n", args...)
	os.Exit(1)
} 