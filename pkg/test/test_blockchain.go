// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"fmt"
	"log"
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain"
	"go.uber.org/zap"
)

func main() {
	// Setup logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: logging.Info,
		LogLevel:     logging.Info,
	})
	logger, err := logFactory.Make("test")
	if err != nil {
		log.Fatalf("Failed to create logger: %s", err)
	}

	logger.Info("Starting blockchain test...")

	// Create blockchain
	bc, err := blockchain.NewBlockchain(logger, 4)
	if err != nil {
		logger.Fatal("Failed to create blockchain", zap.Error(err))
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
			logger.Error("Failed to create transaction", zap.Error(err))
			continue
		}

		// Sign transaction
		err = tx.SignTransaction([]byte(fmt.Sprintf("key-%d", i)))
		if err != nil {
			logger.Error("Failed to sign transaction", zap.Error(err))
			continue
		}

		// Add to blockchain
		err = bc.AddTransaction(tx)
		if err != nil {
			logger.Error("Failed to add transaction", zap.Error(err))
			continue
		}

		logger.Info("Added transaction", zap.Int("index", i))
	}

	// Test 2: Create blocks
	logger.Info("Test 2: Creating blocks...")
	var blocks []*blockchain.Block
	
	// Create first block
	block1, err := bc.CreateBlock(nil, 5)
	if err != nil {
		logger.Fatal("Failed to create block", zap.Error(err))
	}
	blocks = append(blocks, block1)
	logger.Info("Created block 1", zap.String("blockID", block1.ID().String()))

	// Submit block
	err = bc.SubmitBlock(block1)
	if err != nil {
		logger.Fatal("Failed to submit block", zap.Error(err))
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks", zap.Error(err))
	}

	// Create second block with first block as parent
	block2, err := bc.CreateBlock([]ids.ID{block1.ID()}, 5)
	if err != nil {
		logger.Fatal("Failed to create block", zap.Error(err))
	}
	blocks = append(blocks, block2)
	logger.Info("Created block 2", zap.String("blockID", block2.ID().String()))

	// Submit block
	err = bc.SubmitBlock(block2)
	if err != nil {
		logger.Fatal("Failed to submit block", zap.Error(err))
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks", zap.Error(err))
	}

	// Test 3: Create a fork in the blockchain
	logger.Info("Test 3: Creating a fork in the blockchain...")
	
	// Create two blocks with the same parent
	block3a, err := bc.CreateBlock([]ids.ID{block2.ID()}, 3)
	if err != nil {
		logger.Fatal("Failed to create block 3a", zap.Error(err))
	}
	blocks = append(blocks, block3a)
	logger.Info("Created block 3a", zap.String("blockID", block3a.ID().String()))

	block3b, err := bc.CreateBlock([]ids.ID{block2.ID()}, 3)
	if err != nil {
		logger.Fatal("Failed to create block 3b", zap.Error(err))
	}
	blocks = append(blocks, block3b)
	logger.Info("Created block 3b", zap.String("blockID", block3b.ID().String()))

	// Submit both blocks
	err = bc.SubmitBlock(block3a)
	if err != nil {
		logger.Fatal("Failed to submit block 3a", zap.Error(err))
	}

	err = bc.SubmitBlock(block3b)
	if err != nil {
		logger.Fatal("Failed to submit block 3b", zap.Error(err))
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks", zap.Error(err))
	}

	// Test 4: Create a block with both forks as parents (join the forks)
	logger.Info("Test 4: Joining the forks...")
	
	block4, err := bc.CreateBlock([]ids.ID{block3a.ID(), block3b.ID()}, 4)
	if err != nil {
		logger.Fatal("Failed to create block 4", zap.Error(err))
	}
	blocks = append(blocks, block4)
	logger.Info("Created block 4", zap.String("blockID", block4.ID().String()))

	// Submit block
	err = bc.SubmitBlock(block4)
	if err != nil {
		logger.Fatal("Failed to submit block", zap.Error(err))
	}

	// Process blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process blocks", zap.Error(err))
	}

	// Test 5: Parallel block creation and submission
	logger.Info("Test 5: Testing parallel block creation and submission...")
	
	var wg sync.WaitGroup
	for i := 0; i < 5; i++ {
		wg.Add(1)
		go func(index int) {
			defer wg.Done()
			
			// Create block
			parentIDs := []ids.ID{block4.ID()}
			newBlock, err := bc.CreateBlock(parentIDs, 2)
			if err != nil {
				logger.Error("Failed to create parallel block", zap.Int("index", index), zap.Error(err))
				return
			}
			
			// Submit block
			err = bc.SubmitBlock(newBlock)
			if err != nil {
				logger.Error("Failed to submit parallel block", zap.Int("index", index), zap.Error(err))
				return
			}
			
			logger.Info("Created and submitted parallel block", zap.Int("index", index), zap.String("blockID", newBlock.ID().String()))
		}(i)
	}
	
	wg.Wait()
	
	// Process all pending blocks
	err = bc.ProcessPendingBlocks()
	if err != nil {
		logger.Fatal("Failed to process parallel blocks", zap.Error(err))
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
			logger.Error("Failed to create transaction", zap.Error(err))
			continue
		}

		// Sign transaction
		err = tx.SignTransaction([]byte(fmt.Sprintf("activity-key-%d", i)))
		if err != nil {
			logger.Error("Failed to sign transaction", zap.Error(err))
			continue
		}

		// Add to blockchain
		err = bc.AddTransaction(tx)
		if err != nil {
			logger.Error("Failed to add transaction", zap.Error(err))
			continue
		}
	}
	
	// Create a few blocks with the latest blocks as parents
	latestBlocks := bc.GetLatestBlocks()
	if len(latestBlocks) > 0 {
		parentIDs := make([]ids.ID, 0, len(latestBlocks))
		for _, b := range latestBlocks {
			parentIDs = append(parentIDs, b.ID())
		}
		
		newBlock, err := bc.CreateBlock(parentIDs, 5)
		if err != nil {
			logger.Error("Failed to create activity block", zap.Error(err))
		} else {
			err = bc.SubmitBlock(newBlock)
			if err != nil {
				logger.Error("Failed to submit activity block", zap.Error(err))
			} else {
				logger.Info("Created and submitted activity block", zap.String("blockID", newBlock.ID().String()))
			}
		}
	}
	
	// Let consensus run for a bit
	time.Sleep(1 * time.Second)
	
	// Print blockchain statistics
	height := bc.GetBlockchainHeight()
	latestBlocks = bc.GetLatestBlocks()
	
	logger.Info("Final blockchain height", zap.Uint64("height", height))
	logger.Info("Number of latest blocks", zap.Int("count", len(latestBlocks)))
	
	logger.Info("Blockchain test completed successfully!")
} 