// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

// This is a standalone script to test the blockchain with various transaction conditions
// Run with: go run transaction_load_test.go

package main

import (
	"context"
	"fmt"
	"math/rand"
	"os"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

const (
	// Test parameters
	numUsers               = 50
	numTransactions        = 1000
	maxConcurrentSubmit    = 100
	transactionDelayMs     = 5
	doubleSpendProbability = 0.05
	blockInterval          = 1 * time.Second
	largeValueProbability  = 0.1
	microValueProbability  = 0.1
	runTime                = 2 * time.Minute
)

var (
	// User accounts
	users = []string{
		"alice", "bob", "charlie", "dave", "eve",
		"frank", "grace", "heidi", "ivan", "judy",
	}

	// Extended user list for more realistic testing
	extendedUsers []string
)

// generateExtendedUsers creates a larger set of users for testing
func generateExtendedUsers() {
	for i := 0; i < numUsers; i++ {
		if i < len(users) {
			extendedUsers = append(extendedUsers, users[i])
		} else {
			extendedUsers = append(extendedUsers, fmt.Sprintf("user%d", i))
		}
	}
}

func main() {
	// Setup logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: "info",
	})
	logger, err := logFactory.Make("load-test")
	if err != nil {
		fmt.Printf("Failed to initialize logger: %v\n", err)
		os.Exit(1)
	}

	// Generate extended user list
	generateExtendedUsers()

	// Create blockchain
	bc, err := blockchain.NewBlockchain(logger, 4)
	if err != nil {
		logger.Fatal("Failed to create blockchain: %s", err)
	}

	// Start consensus process
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	go bc.RunConsensus(ctx, blockInterval)

	// Create blockchain node
	nodeConfig := blockchain.NodeConfig{
		MaxParallelism: 4,
		APIPort:        8545,
	}
	node, err := blockchain.NewNode(logger, nodeConfig)
	if err != nil {
		logger.Fatal("Failed to create blockchain node: %s", err)
	}

	// Start the node
	if err := node.Start(); err != nil {
		logger.Fatal("Failed to start blockchain node: %s", err)
	}

	// Run the load test scenarios
	logger.Info("Starting transaction load test...")
	
	// Create a WaitGroup to track goroutines
	var wg sync.WaitGroup

	// Set a timeout for the entire test
	testCtx, testCancel := context.WithTimeout(ctx, runTime)
	defer testCancel()

	// Start creating blocks
	wg.Add(1)
	go func() {
		defer wg.Done()
		blockCreator(testCtx, bc, logger)
	}()

	// Run test scenarios in separate goroutines
	wg.Add(5)
	
	// Scenario 1: Normal transactions
	go func() {
		defer wg.Done()
		normalTransactions(testCtx, bc, logger)
	}()

	// Scenario 2: Double spend transactions
	go func() {
		defer wg.Done()
		doubleSpendTransactions(testCtx, bc, logger)
	}()

	// Scenario 3: High value transactions
	go func() {
		defer wg.Done()
		highValueTransactions(testCtx, bc, logger)
	}()

	// Scenario 4: Micro transactions
	go func() {
		defer wg.Done()
		microTransactions(testCtx, bc, logger)
	}()

	// Scenario 5: Transaction bursts
	go func() {
		defer wg.Done()
		transactionBursts(testCtx, bc, logger)
	}()

	// Wait for all tests to complete
	wg.Wait()

	// Stop the node
	if err := node.Stop(); err != nil {
		logger.Error("Error stopping node: %s", err)
	}

	// Print test results
	logger.Info("Load test completed!")
	logger.Info("Blockchain height: %d", bc.GetBlockchainHeight())
	logger.Info("Total blocks: %d", len(bc.GetLatestBlocks()))
}

// blockCreator creates blocks at regular intervals
func blockCreator(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			// Get the latest blocks to use as parents
			latestBlocks := bc.GetLatestBlocks()
			if len(latestBlocks) == 0 {
				continue
			}

			// Collect parent IDs
			var parentIDs []ids.ID
			for _, block := range latestBlocks {
				parentIDs = append(parentIDs, block.ID())
			}

			// Create a block with up to 50 transactions
			block, err := bc.CreateBlock(parentIDs, 50)
			if err != nil {
				logger.Error("Failed to create block: %s", err)
				continue
			}

			// Submit the block
			if err := bc.SubmitBlock(block); err != nil {
				logger.Error("Failed to submit block: %s", err)
				continue
			}

			logger.Info("Created and submitted block %s with %d transactions at height %d",
				block.ID(), len(block.Transactions), block.Height)
		}
	}
}

// normalTransactions generates normal transactions
func normalTransactions(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(time.Duration(transactionDelayMs) * time.Millisecond)
	defer ticker.Stop()

	nonce := uint64(0)
	count := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("Normal transactions completed: %d", count)
			return
		case <-ticker.C:
			// Select random sender and recipient
			sender := extendedUsers[rand.Intn(len(extendedUsers))]
			recipient := extendedUsers[rand.Intn(len(extendedUsers))]
			for recipient == sender {
				recipient = extendedUsers[rand.Intn(len(extendedUsers))]
			}

			// Create transaction
			tx, err := blockchain.NewTransaction(sender, recipient, 100+uint64(rand.Intn(900)), nonce)
			if err != nil {
				logger.Error("Failed to create normal transaction: %s", err)
				continue
			}

			// Sign transaction
			if err := tx.SignTransaction([]byte("test-key")); err != nil {
				logger.Error("Failed to sign normal transaction: %s", err)
				continue
			}

			// Add to blockchain
			if err := bc.AddTransaction(tx); err != nil {
				// Ignore errors for duplicate transactions
				if count%100 == 0 {
					logger.Debug("Failed to add normal transaction: %s", err)
				}
				continue
			}

			nonce++
			count++
			
			if count >= numTransactions {
				logger.Info("Normal transactions completed: %d", count)
				return
			}
		}
	}
}

// doubleSpendTransactions generates transactions with double spending attempts
func doubleSpendTransactions(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(50 * time.Millisecond)
	defer ticker.Stop()

	type userNonce struct {
		user  string
		nonce uint64
	}

	// Track user nonces for double spends
	userNonces := make(map[string]uint64)
	var doubleSpendTargets []userNonce
	count := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("Double spend transactions completed: %d", count)
			return
		case <-ticker.C:
			// Decide whether to create a new transaction or a double spend
			if rand.Float64() < doubleSpendProbability && len(doubleSpendTargets) > 0 {
				// Double spend attempt
				targetIndex := rand.Intn(len(doubleSpendTargets))
				target := doubleSpendTargets[targetIndex]
				
				// Create double spend transaction
				recipient := extendedUsers[rand.Intn(len(extendedUsers))]
				for recipient == target.user {
					recipient = extendedUsers[rand.Intn(len(extendedUsers))]
				}
				
				tx, err := blockchain.NewTransaction(target.user, recipient, 100+uint64(rand.Intn(900)), target.nonce)
				if err != nil {
					logger.Error("Failed to create double spend transaction: %s", err)
					continue
				}
				
				// Sign transaction
				if err := tx.SignTransaction([]byte("test-key")); err != nil {
					logger.Error("Failed to sign double spend transaction: %s", err)
					continue
				}
				
				// Add to blockchain
				err = bc.AddTransaction(tx)
				if err != nil {
					logger.Debug("Double spend rejected (expected): %s", err)
				} else {
					logger.Info("Double spend transaction accepted: %s -> %s, nonce: %d", 
						target.user, recipient, target.nonce)
				}
				
				// Remove from targets to avoid repeated attempts
				doubleSpendTargets = append(doubleSpendTargets[:targetIndex], doubleSpendTargets[targetIndex+1:]...)
			} else {
				// New transaction
				sender := extendedUsers[rand.Intn(len(extendedUsers))]
				recipient := extendedUsers[rand.Intn(len(extendedUsers))]
				for recipient == sender {
					recipient = extendedUsers[rand.Intn(len(extendedUsers))]
				}
				
				nonce, exists := userNonces[sender]
				if !exists {
					nonce = 0
				}
				
				tx, err := blockchain.NewTransaction(sender, recipient, 100+uint64(rand.Intn(900)), nonce)
				if err != nil {
					logger.Error("Failed to create transaction: %s", err)
					continue
				}
				
				// Sign transaction
				if err := tx.SignTransaction([]byte("test-key")); err != nil {
					logger.Error("Failed to sign transaction: %s", err)
					continue
				}
				
				// Add to blockchain
				if err := bc.AddTransaction(tx); err != nil {
					logger.Debug("Failed to add transaction: %s", err)
					continue
				}
				
				// Add to potential double spend targets
				doubleSpendTargets = append(doubleSpendTargets, userNonce{sender, nonce})
				
				// Update nonce
				userNonces[sender] = nonce + 1
				count++
				
				if count >= numTransactions/10 {
					logger.Info("Double spend transactions completed: %d", count)
					return
				}
			}
		}
	}
}

// highValueTransactions generates high-value transactions
func highValueTransactions(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(200 * time.Millisecond)
	defer ticker.Stop()

	nonce := uint64(1000)
	count := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("High value transactions completed: %d", count)
			return
		case <-ticker.C:
			// Select random sender and recipient
			sender := extendedUsers[rand.Intn(len(extendedUsers))]
			recipient := extendedUsers[rand.Intn(len(extendedUsers))]
			
			// Create high value transaction
			tx, err := blockchain.NewTransaction(sender, recipient, 1000000+uint64(rand.Intn(9000000)), nonce)
			if err != nil {
				logger.Error("Failed to create high value transaction: %s", err)
				continue
			}
			
			// Sign transaction
			if err := tx.SignTransaction([]byte("test-key")); err != nil {
				logger.Error("Failed to sign high value transaction: %s", err)
				continue
			}
			
			// Add to blockchain
			if err := bc.AddTransaction(tx); err != nil {
				logger.Debug("Failed to add high value transaction: %s", err)
				continue
			}
			
			logger.Info("Added high value transaction: %s -> %s, amount: %d", 
				sender, recipient, tx.Amount)
			
			nonce++
			count++
			
			if count >= numTransactions/20 {
				logger.Info("High value transactions completed: %d", count)
				return
			}
		}
	}
}

// microTransactions generates very small transactions
func microTransactions(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(10 * time.Millisecond)
	defer ticker.Stop()

	nonce := uint64(2000)
	count := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("Micro transactions completed: %d", count)
			return
		case <-ticker.C:
			// Select random sender and recipient
			sender := extendedUsers[rand.Intn(len(extendedUsers))]
			recipient := extendedUsers[rand.Intn(len(extendedUsers))]
			
			// Create micro transaction
			tx, err := blockchain.NewTransaction(sender, recipient, 1+uint64(rand.Intn(10)), nonce)
			if err != nil {
				logger.Error("Failed to create micro transaction: %s", err)
				continue
			}
			
			// Sign transaction
			if err := tx.SignTransaction([]byte("test-key")); err != nil {
				logger.Error("Failed to sign micro transaction: %s", err)
				continue
			}
			
			// Add to blockchain
			if err := bc.AddTransaction(tx); err != nil {
				logger.Debug("Failed to add micro transaction: %s", err)
				continue
			}
			
			nonce++
			count++
			
			if count >= numTransactions/5 {
				logger.Info("Micro transactions completed: %d", count)
				return
			}
		}
	}
}

// transactionBursts generates bursts of transactions
func transactionBursts(ctx context.Context, bc *blockchain.Blockchain, logger logging.Logger) {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()

	nonce := uint64(3000)
	burstCount := 0

	for {
		select {
		case <-ctx.Done():
			logger.Info("Transaction bursts completed: %d", burstCount)
			return
		case <-ticker.C:
			burstCount++
			logger.Info("Starting transaction burst #%d", burstCount)
			
			// Create a burst of transactions concurrently
			var wg sync.WaitGroup
			burstSize := 50 + rand.Intn(50)
			wg.Add(burstSize)
			
			for i := 0; i < burstSize; i++ {
				go func(i int) {
					defer wg.Done()
					
					localNonce := nonce + uint64(i)
					sender := extendedUsers[rand.Intn(len(extendedUsers))]
					recipient := extendedUsers[rand.Intn(len(extendedUsers))]
					
					// Create transaction
					tx, err := blockchain.NewTransaction(sender, recipient, 100+uint64(rand.Intn(900)), localNonce)
					if err != nil {
						logger.Error("Failed to create burst transaction: %s", err)
						return
					}
					
					// Sign transaction
					if err := tx.SignTransaction([]byte("test-key")); err != nil {
						logger.Error("Failed to sign burst transaction: %s", err)
						return
					}
					
					// Add to blockchain
					if err := bc.AddTransaction(tx); err != nil {
						logger.Debug("Failed to add burst transaction: %s", err)
						return
					}
				}(i)
			}
			
			wg.Wait()
			logger.Info("Completed transaction burst #%d with %d transactions", burstCount, burstSize)
			nonce += uint64(burstSize)
			
			if burstCount >= 5 {
				logger.Info("Transaction bursts completed: %d", burstCount)
				return
			}
		}
	}
} 