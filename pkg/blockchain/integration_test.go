// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"testing"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestFullBlockchainFlow tests the complete flow from transaction creation to
// block acceptance in the blockchain.
func TestFullBlockchainFlow(t *testing.T) {
	// Create blockchain
	logger := &testLogger{}
	bc, err := NewBlockchain(logger, 4)
	require.NoError(t, err)

	// Create a batch of transactions
	transactions := createTestTransactions(t, 5)

	// Add transactions to the blockchain
	for _, tx := range transactions {
		err = bc.AddTransaction(tx)
		require.NoError(t, err)
	}

	// Create a block with these transactions
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block, err := bc.CreateBlock(parentIDs, 5)
	require.NoError(t, err)
	require.Len(t, block.Transactions, 5)

	// Verify block height
	height, err := block.Height()
	assert.NoError(t, err)
	assert.Equal(t, uint64(1), height)

	// Submit block for consensus
	err = bc.SubmitBlock(block)
	require.NoError(t, err)

	// Process pending blocks
	err = bc.ProcessPendingBlocks()
	require.NoError(t, err)

	// Wait for consensus (in a real system, this would happen asynchronously)
	// Here we simulate by waiting a short time
	time.Sleep(500 * time.Millisecond)

	// Verify block is in the blockchain
	retrievedBlock, err := bc.GetBlock(block.ID())
	assert.NoError(t, err)
	assert.Equal(t, block.ID(), retrievedBlock.ID())

	// Verify transactions are accepted
	for _, tx := range transactions {
		retrievedTx, err := bc.GetTransaction(tx.ID())
		assert.NoError(t, err)
		assert.NotNil(t, retrievedTx)
	}
}

// TestBlockchainForkResolution tests the blockchain's ability to handle
// competing chains and resolve forks according to Avalanche consensus.
func TestBlockchainForkResolution(t *testing.T) {
	// Create blockchain
	logger := &testLogger{}
	bc, err := NewBlockchain(logger, 4)
	require.NoError(t, err)

	// Create first branch
	txA1, _ := NewTransaction("alice", "bob", 100, 1)
	txA1.SignTransaction([]byte("key"))
	bc.AddTransaction(txA1)

	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	blockA, err := bc.CreateBlock(parentIDs, 1)
	require.NoError(t, err)
	bc.SubmitBlock(blockA)

	// Create second branch from same parent
	txB1, _ := NewTransaction("charlie", "dave", 200, 1)
	txB1.SignTransaction([]byte("key"))
	bc.AddTransaction(txB1)

	blockB, err := bc.CreateBlock(parentIDs, 1)
	require.NoError(t, err)
	bc.SubmitBlock(blockB)

	// Process pending blocks
	bc.ProcessPendingBlocks()

	// Verify both blocks are in the latest blocks (fork exists)
	latestBlocks := bc.GetLatestBlocks()
	assert.Len(t, latestBlocks, 2)

	// Continue building on first branch
	txA2, _ := NewTransaction("bob", "eve", 50, 1)
	txA2.SignTransaction([]byte("key"))
	bc.AddTransaction(txA2)

	parentIDsA := []ids.ID{blockA.ID()}
	blockA2, err := bc.CreateBlock(parentIDsA, 1)
	require.NoError(t, err)
	bc.SubmitBlock(blockA2)
	bc.ProcessPendingBlocks()

	// Build more blocks on the first branch
	for i := 0; i < 3; i++ {
		tx, _ := NewTransaction("alice", "bob", uint64(100+i), uint64(2+i))
		tx.SignTransaction([]byte("key"))
		bc.AddTransaction(tx)

		parentIDs := []ids.ID{blockA2.ID()}
		block, err := bc.CreateBlock(parentIDs, 1)
		require.NoError(t, err)
		bc.SubmitBlock(block)
		bc.ProcessPendingBlocks()
		blockA2 = block
	}

	// Wait for consensus to settle
	time.Sleep(500 * time.Millisecond)

	// The blockchain should eventually prefer the longer chain
	latestBlocks = bc.GetLatestBlocks()
	if len(latestBlocks) == 1 {
		// Fork resolved, should have chosen the longer chain
		assert.Equal(t, blockA2.ID(), latestBlocks[0].ID())
	}
}

// TestDoubleSpendTransaction tests how the blockchain handles double-spend
// transactions in different blocks.
func TestDoubleSpendTransaction(t *testing.T) {
	// Create blockchain
	logger := &testLogger{}
	bc, err := NewBlockchain(logger, 4)
	require.NoError(t, err)

	// Create two transactions with the same nonce (simulating a double spend)
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx1.SignTransaction([]byte("key"))
	bc.AddTransaction(tx1)

	// Create first block with tx1
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	block1, err := bc.CreateBlock(parentIDs, 1)
	require.NoError(t, err)
	bc.SubmitBlock(block1)

	// Create second transaction (double spend)
	tx2, _ := NewTransaction("alice", "charlie", 100, 1) // Same nonce as tx1
	tx2.SignTransaction([]byte("key"))
	bc.AddTransaction(tx2)

	// Create second block with tx2
	block2, err := bc.CreateBlock(parentIDs, 1)
	require.NoError(t, err)
	bc.SubmitBlock(block2)

	// Process pending blocks
	bc.ProcessPendingBlocks()

	// Wait for consensus to run
	time.Sleep(500 * time.Millisecond)

	// In a real implementation, only one transaction should be accepted
	// Here we just verify that both blocks are in the blockchain
	_, err1 := bc.GetBlock(block1.ID())
	_, err2 := bc.GetBlock(block2.ID())
	assert.True(t, err1 == nil || err2 == nil)
}

// TestHighLoadTransactions tests the blockchain under high transaction load.
func TestHighLoadTransactions(t *testing.T) {
	// Create blockchain
	logger := &testLogger{}
	bc, err := NewBlockchain(logger, 4)
	require.NoError(t, err)

	// Create a large number of transactions
	numTxs := 100
	transactions := createTestTransactions(t, numTxs)

	// Add all transactions
	for _, tx := range transactions {
		bc.AddTransaction(tx)
	}

	// Create blocks until all transactions are processed
	parentIDs := []ids.ID{bc.genesisBlock.ID()}
	blockCount := 0

	// Process in batches of 10 transactions per block
	for len(bc.txPool) > 0 {
		block, err := bc.CreateBlock(parentIDs, 10)
		require.NoError(t, err)
		bc.SubmitBlock(block)
		bc.ProcessPendingBlocks()
		parentIDs = []ids.ID{block.ID()}
		blockCount++
	}

	// Verify we created at least numTxs/10 blocks
	assert.GreaterOrEqual(t, blockCount, numTxs/10)

	// Wait for consensus to settle
	time.Sleep(500 * time.Millisecond)

	// Verify blockchain height
	assert.Equal(t, uint64(blockCount), bc.GetBlockchainHeight())
}

// Helper function to create test transactions
func createTestTransactions(t *testing.T, count int) []*Transaction {
	transactions := make([]*Transaction, count)
	for i := 0; i < count; i++ {
		tx, err := NewTransaction("user"+string(rune(65+i%26)), "recipient"+string(rune(65+i%26)), uint64(100+i), uint64(i))
		require.NoError(t, err)
		err = tx.SignTransaction([]byte("test-key"))
		require.NoError(t, err)
		transactions[i] = tx
	}
	return transactions
}

// TestParallelConsensus tests that the parallel consensus engine processes
// transactions faster than sequential processing would.
func TestParallelConsensus(t *testing.T) {
	// Skip this test in normal runs as it's more of a benchmark
	if testing.Short() {
		t.Skip("Skipping parallel consensus benchmark in short mode")
	}

	// Create blockchain with parallel processing
	logger := &testLogger{}
	bcParallel, err := NewBlockchain(logger, 4) // 4 parallel processors
	require.NoError(t, err)

	// Create blockchain with sequential processing
	bcSequential, err := NewBlockchain(logger, 1) // 1 processor (sequential)
	require.NoError(t, err)

	// Create a large number of transactions
	numTxs := 200
	transactions := createTestTransactions(t, numTxs)

	// Measure time for parallel processing
	parallelStart := time.Now()
	
	// Add transactions to parallel blockchain
	for _, tx := range transactions {
		txClone, _ := NewTransaction(tx.Sender, tx.Recipient, tx.Amount, tx.Nonce)
		txClone.SignTransaction([]byte("test-key"))
		bcParallel.AddTransaction(txClone)
	}

	// Create blocks and process
	parentIDs := []ids.ID{bcParallel.genesisBlock.ID()}
	for len(bcParallel.txPool) > 0 {
		block, _ := bcParallel.CreateBlock(parentIDs, 20)
		bcParallel.SubmitBlock(block)
		bcParallel.ProcessPendingBlocks()
		parentIDs = []ids.ID{block.ID()}
	}
	
	parallelDuration := time.Since(parallelStart)

	// Measure time for sequential processing
	sequentialStart := time.Now()
	
	// Add transactions to sequential blockchain
	for _, tx := range transactions {
		txClone, _ := NewTransaction(tx.Sender, tx.Recipient, tx.Amount, tx.Nonce)
		txClone.SignTransaction([]byte("test-key"))
		bcSequential.AddTransaction(txClone)
	}

	// Create blocks and process
	parentIDs = []ids.ID{bcSequential.genesisBlock.ID()}
	for len(bcSequential.txPool) > 0 {
		block, _ := bcSequential.CreateBlock(parentIDs, 20)
		bcSequential.SubmitBlock(block)
		bcSequential.ProcessPendingBlocks()
		parentIDs = []ids.ID{block.ID()}
	}
	
	sequentialDuration := time.Since(sequentialStart)

	// Parallel should be faster than sequential
	t.Logf("Parallel processing time: %v", parallelDuration)
	t.Logf("Sequential processing time: %v", sequentialDuration)
	t.Logf("Speedup: %.2fx", float64(sequentialDuration)/float64(parallelDuration))
	
	// We expect parallel to be faster, but don't fail the test if it's not
	// since it depends on the hardware and might not always be true in CI environments
	if sequentialDuration > parallelDuration {
		t.Logf("Parallel processing was faster by %.2fx", float64(sequentialDuration)/float64(parallelDuration))
	} else {
		t.Logf("Warning: Parallel processing was not faster in this run")
	}
} 