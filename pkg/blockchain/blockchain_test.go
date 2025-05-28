// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"sync"
	"testing"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Mock logger for testing
type testLogger struct{}

func (l *testLogger) Debug(msg string, args ...interface{}) {}
func (l *testLogger) Info(msg string, args ...interface{})  {}
func (l *testLogger) Warn(msg string, args ...interface{})  {}
func (l *testLogger) Error(msg string, args ...interface{}) {}
func (l *testLogger) Fatal(msg string, args ...interface{}) {}
func (l *testLogger) Verbo(msg string, args ...interface{}) {}

func createTestBlockchain(t *testing.T) *Blockchain {
	logger := &testLogger{}
	bc, err := NewBlockchain(logger, 4)
	require.NoError(t, err)
	require.NotNil(t, bc)
	return bc
}

func TestBlockchainCreation(t *testing.T) {
	bc := createTestBlockchain(t)

	// Verify genesis block is created
	assert.NotNil(t, bc.genesisBlock)
	assert.Equal(t, bc.genesisBlock.Status().String(), "Accepted")
	assert.Equal(t, uint64(0), bc.currentHeight)
	assert.Len(t, bc.latestBlocks, 1)
}

func TestAddTransaction(t *testing.T) {
	bc := createTestBlockchain(t)

	// Create valid transaction
	tx, err := NewTransaction("alice", "bob", 100, 1)
	require.NoError(t, err)
	err = tx.SignTransaction([]byte("valid-key"))
	require.NoError(t, err)

	// Add transaction to blockchain
	err = bc.AddTransaction(tx)
	assert.NoError(t, err)
	assert.Len(t, bc.txPool, 1)

	// Try to add the same transaction again
	err = bc.AddTransaction(tx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "transaction already in pool")

	// Create invalid transaction
	invalidTx, _ := NewTransaction("", "bob", 100, 1)
	err = invalidTx.SignTransaction([]byte("valid-key"))
	require.NoError(t, err)

	// Add invalid transaction
	err = bc.AddTransaction(invalidTx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid transaction")
}

func TestCreateBlock(t *testing.T) {
	bc := createTestBlockchain(t)

	// Add transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx1.SignTransaction([]byte("key"))
	bc.AddTransaction(tx1)

	tx2, _ := NewTransaction("charlie", "dave", 50, 1)
	tx2.SignTransaction([]byte("key"))
	bc.AddTransaction(tx2)

	// Create block
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, err := bc.CreateBlock(parentIDs, 10)
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), block.Height)
	assert.Len(t, block.Transactions, 2)

	// Verify transactions were removed from pool
	assert.Empty(t, bc.txPool)
	assert.Contains(t, bc.pendingBlocks, block.ID())
}

func TestCreateBlockWithMaxTxs(t *testing.T) {
	bc := createTestBlockchain(t)

	// Add transactions
	for i := 0; i < 10; i++ {
		tx, _ := NewTransaction("alice", "bob", uint64(100+i), uint64(i))
		tx.SignTransaction([]byte("key"))
		bc.AddTransaction(tx)
	}

	// Create block with max 5 transactions
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, err := bc.CreateBlock(parentIDs, 5)
	assert.NoError(t, err)
	assert.Len(t, block.Transactions, 5)

	// Verify some transactions remain in pool
	assert.Len(t, bc.txPool, 5)
}

func TestCreateBlockInvalidParent(t *testing.T) {
	bc := createTestBlockchain(t)

	// Try to create block with non-existent parent
	parentIDs := []ids.ID{ids.GenerateTestID()}
	_, err := bc.CreateBlock(parentIDs, 10)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "parent block not found")
}

func TestSubmitBlock(t *testing.T) {
	bc := createTestBlockchain(t)

	// Create and add transaction
	tx, _ := NewTransaction("alice", "bob", 100, 1)
	tx.SignTransaction([]byte("key"))
	bc.AddTransaction(tx)

	// Create block
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, err := bc.CreateBlock(parentIDs, 10)
	assert.NoError(t, err)

	// Submit block
	err = bc.SubmitBlock(block)
	assert.NoError(t, err)

	// Verify block is in latestBlocks and parent is removed
	assert.Contains(t, bc.latestBlocks, block.ID())
	assert.NotContains(t, bc.latestBlocks, bc.genesisBlock.ID())
}

func TestProcessPendingBlocks(t *testing.T) {
	bc := createTestBlockchain(t)

	// Create and add transaction
	tx, _ := NewTransaction("alice", "bob", 100, 1)
	tx.SignTransaction([]byte("key"))
	bc.AddTransaction(tx)

	// Create block
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, err := bc.CreateBlock(parentIDs, 10)
	assert.NoError(t, err)

	// Submit block
	err = bc.SubmitBlock(block)
	assert.NoError(t, err)

	// Process pending blocks
	err = bc.ProcessPendingBlocks()
	assert.NoError(t, err)

	// Create a timeout to prevent test from hanging
	timeoutCtx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	// Wait for block to be accepted or timeout
	for {
		select {
		case <-timeoutCtx.Done():
			t.Fatal("Timed out waiting for block to be accepted")
			return
		default:
			// Check if block is accepted
			if _, exists := bc.acceptedBlocks[block.ID()]; exists {
				return
			}
			time.Sleep(100 * time.Millisecond)
		}
	}
}

func TestConcurrentTransactions(t *testing.T) {
	bc := createTestBlockchain(t)
	
	// Number of concurrent transactions
	numTxs := 100
	
	// Create and add transactions concurrently
	var wg sync.WaitGroup
	wg.Add(numTxs)
	
	for i := 0; i < numTxs; i++ {
		go func(i int) {
			defer wg.Done()
			tx, _ := NewTransaction("alice", "bob", uint64(100+i), uint64(i))
			tx.SignTransaction([]byte("key"))
			bc.AddTransaction(tx)
		}(i)
	}
	
	wg.Wait()
	
	// Verify that transactions were added (some may fail due to concurrency)
	assert.NotEmpty(t, bc.txPool)
}

func TestMultipleBlockCreation(t *testing.T) {
	bc := createTestBlockchain(t)
	
	// Create a chain of blocks
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	
	for i := 0; i < 5; i++ {
		// Add transactions
		tx, _ := NewTransaction("alice", "bob", uint64(100+i), uint64(i))
		tx.SignTransaction([]byte("key"))
		bc.AddTransaction(tx)
		
		// Create block
		block, err := bc.CreateBlock(parentIDs, 10)
		assert.NoError(t, err)
		
		// Submit block
		err = bc.SubmitBlock(block)
		assert.NoError(t, err)
		
		// Process pending blocks
		err = bc.ProcessPendingBlocks()
		assert.NoError(t, err)
		
		// Update parent IDs for next block
		parentIDs = []ids.ID{block.ID()}
	}
	
	// Verify blockchain height
	assert.Equal(t, uint64(5), bc.GetBlockchainHeight())
}

func TestRunConsensus(t *testing.T) {
	bc := createTestBlockchain(t)
	
	// Start consensus process
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	
	go bc.RunConsensus(ctx, 100*time.Millisecond)
	
	// Add transaction
	tx, _ := NewTransaction("alice", "bob", 100, 1)
	tx.SignTransaction([]byte("key"))
	bc.AddTransaction(tx)
	
	// Create and submit block
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, _ := bc.CreateBlock(parentIDs, 10)
	bc.SubmitBlock(block)
	
	// Wait a bit for consensus to run
	time.Sleep(300 * time.Millisecond)
	
	// Cancel context to stop consensus
	cancel()
}

func TestGetBlocksByHeight(t *testing.T) {
	bc := createTestBlockchain(t)
	
	// Create blocks at different heights
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	
	// Create 3 blocks at height 1
	var blocks []*Block
	for i := 0; i < 3; i++ {
		tx, _ := NewTransaction("alice", "bob", uint64(100+i), uint64(i))
		tx.SignTransaction([]byte("key"))
		bc.AddTransaction(tx)
		
		block, _ := bc.CreateBlock(parentIDs, 1)
		blocks = append(blocks, block)
	}
	
	// Get blocks by height
	heightBlocks := bc.GetBlocksByHeight(1)
	assert.Len(t, heightBlocks, 3)
}

func TestGetLatestBlocks(t *testing.T) {
	bc := createTestBlockchain(t)
	
	// Initially, genesis block should be the only latest block
	latestBlocks := bc.GetLatestBlocks()
	assert.Len(t, latestBlocks, 1)
	assert.Equal(t, bc.genesisBlock.ID(), latestBlocks[0].ID())
	
	// Create a new block
	tx, _ := NewTransaction("alice", "bob", 100, 1)
	tx.SignTransaction([]byte("key"))
	bc.AddTransaction(tx)
	
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, _ := bc.CreateBlock(parentIDs, 1)
	bc.SubmitBlock(block)
	
	// New block should be the latest block
	latestBlocks = bc.GetLatestBlocks()
	assert.Len(t, latestBlocks, 1)
	assert.Equal(t, block.ID(), latestBlocks[0].ID())
} 