// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
)

func main() {
	// Setup logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: "info",
		LogLevel:     "info",
	})
	logger, err := logFactory.Make("test")
	if err != nil {
		log.Fatalf("Failed to create logger: %s", err)
	}

	logger.Info("Starting blockchain test...")

	// Create blockchain
	bc, err := blockchain.NewBlockchain(logger, 4)
	if err != nil {
		logger.Fatal("Failed to create blockchain: %s", err)
	}

	// Test 1: Add transactions
	logger.Info("Test 1: Adding transactions...")
	for i := 0; i < 20; i++ {
		tx, err := blockchain.NewTransaction(
			fmt.Sprintf("user%d", i%5),
			fmt.Sprintf("user%d", (i+1)%5),
			uint64(10+i),
			uint64(i),
		)
		if err != nil {
			logger.Error("Failed to create transaction: %s", err)
			continue
		}

		// Sign transaction
		err = tx.SignTransaction([]byte(fmt.Sprintf("key-%d", i)))
		if err != nil {
			logger.Error("Failed to sign transaction: %s", err)
			continue
		}

		// Add to blockchain
		err = bc.AddTransaction(tx)
		if err != nil {
			logger.Error("Failed to add transaction: %s", err)
			continue
		}

		logger.Info("Added transaction %d", i)
	}

	// Test 2: Create blocks
	logger.Info("Test 2: Creating blocks...")
	var blocks []*blockchain.Block
	
	// Create first block
	block1, err := bc.CreateBlock(nil, 5)
	if err != nil {
		logger.Fatal("Failed to create block: %s", err)
	}
	blocks = append(blocks, block1)
	logger.Info("Created block 1: %s", block1.ID())

	// Submit block
	err = bc.SubmitBlock(block1)
	if err != nil {
		logger.Fatal("Failed to submit block: %s", err)
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks: %s", err)
	}

	// Create second block with first block as parent
	block2, err := bc.CreateBlock([]blockchain.Block{block1}.ParentID(), 5)
	if err != nil {
		logger.Fatal("Failed to create block: %s", err)
	}
	blocks = append(blocks, block2)
	logger.Info("Created block 2: %s", block2.ID())

	// Submit block
	err = bc.SubmitBlock(block2)
	if err != nil {
		logger.Fatal("Failed to submit block: %s", err)
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks: %s", err)
	}

	// Test 3: Create a fork in the blockchain
	logger.Info("Test 3: Creating a fork in the blockchain...")
	
	// Create two blocks with the same parent
	block3a, err := bc.CreateBlock([]blockchain.Block{block2}.ParentID(), 3)
	if err != nil {
		logger.Fatal("Failed to create block 3a: %s", err)
	}
	blocks = append(blocks, block3a)
	logger.Info("Created block 3a: %s", block3a.ID())

	block3b, err := bc.CreateBlock([]blockchain.Block{block2}.ParentID(), 3)
	if err != nil {
		logger.Fatal("Failed to create block 3b: %s", err)
	}
	blocks = append(blocks, block3b)
	logger.Info("Created block 3b: %s", block3b.ID())

	// Submit both blocks
	err = bc.SubmitBlock(block3a)
	if err != nil {
		logger.Fatal("Failed to submit block 3a: %s", err)
	}

	err = bc.SubmitBlock(block3b)
	if err != nil {
		logger.Fatal("Failed to submit block 3b: %s", err)
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks: %s", err)
	}

	// Test 4: Create a block with both forks as parents (join the forks)
	logger.Info("Test 4: Joining the forks...")
	
	block4, err := bc.CreateBlock([]blockchain.Block{block3a, block3b}.ParentID(), 4)
	if err != nil {
		logger.Fatal("Failed to create block 4: %s", err)
	}
	blocks = append(blocks, block4)
	logger.Info("Created block 4: %s", block4.ID())

	// Submit block
	err = bc.SubmitBlock(block4)
	if err != nil {
		logger.Fatal("Failed to submit block: %s", err)
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks: %s", err)
	}

	// Test 5: Parallel block creation and submission
	logger.Info("Test 5: Testing parallel block creation and submission...")
	
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			
			// Create block
			parentIDs := []blockchain.Block{block4}.ParentID()
			newBlock, err := bc.CreateBlock(parentIDs, 2)
			if err != nil {
				logger.Error("Failed to create parallel block %d: %s", index, err)
				return
			}
			
			// Submit block
			err = bc.SubmitBlock(newBlock)
			if err != nil {
				logger.Error("Failed to submit parallel block %d: %s", index, err)
				return
			}
			
			logger.Info("Created and submitted parallel block %d: %s", index, newBlock.ID())
		}(i)
	}
	
	wg.Wait()
	
	// Process all pending blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process parallel blocks: %s", err)
	}

	// Test 6: Simulate some blockchain activity
	logger.Info("Test 6: Simulating blockchain activity...")
	
	// Start consensus in background
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	go bc.RunConsensus(ctx, 200*time.Millisecond)
	
	// Add more transactions
	for i := 0; i < 10; i++ {
		tx, err := blockchain.NewTransaction(
			fmt.Sprintf("user%d", i%3),
			fmt.Sprintf("user%d", (i+2)%3),
			uint64(50+i),
			uint64(20+i),
		)
		if err != nil {
			logger.Error("Failed to create transaction: %s", err)
			continue
		}

		// Sign transaction
		err = tx.SignTransaction([]byte(fmt.Sprintf("activity-key-%d", i)))
		if err != nil {
			logger.Error("Failed to sign transaction: %s", err)
			continue
		}

		// Add to blockchain
		err = bc.AddTransaction(tx)
		if err != nil {
			logger.Error("Failed to add transaction: %s", err)
			continue
		}
	}
	
	// Create a few blocks with the latest blocks as parents
	latestBlocks := bc.GetLatestBlocks()
	if len(latestBlocks) > 0 {
		parentIDs := make([]blockchain.Block, 0, len(latestBlocks))
		for _, b := range latestBlocks {
			parentIDs = append(parentIDs, b)
		}
		
		newBlock, err := bc.CreateBlock(parentIDs.ParentID(), 5)
		if err != nil {
			logger.Error("Failed to create activity block: %s", err)
		} else {
			err = bc.SubmitBlock(newBlock)
			if err != nil {
				logger.Error("Failed to submit activity block: %s", err)
			} else {
				logger.Info("Created and submitted activity block: %s", newBlock.ID())
			}
		}
	}
	
	// Let consensus run for a bit
	time.Sleep(1 * time.Second)
	
	// Print blockchain statistics
	height := bc.GetBlockchainHeight()
	latestBlocks = bc.GetLatestBlocks()
	
	logger.Info("Final blockchain height: %d", height)
	logger.Info("Number of latest blocks: %d", len(latestBlocks))
	
	logger.Info("Blockchain test completed successfully!")
}

// Helper method to extract parent IDs from blocks
func (blocks []blockchain.Block) ParentID() []blockchain.ID {
	parentIDs := make([]blockchain.ID, 0, len(blocks))
	for _, block := range blocks {
		parentIDs = append(parentIDs, block.ID())
	}
	return parentIDs
} 