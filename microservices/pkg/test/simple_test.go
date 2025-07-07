// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package test

import (
	"testing"

	"github.com/Final-Project-13520137/avalanche-parallel/pkg/blockchain"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"go.uber.org/zap"
)

func TestSimpleBlockchain(t *testing.T) {
	// Setup logger
	logger, err := zap.NewDevelopment()
	require.NoError(t, err)
	defer logger.Sync()

	// Create blockchain
	chain, err := blockchain.NewBlockchain(logger, 4)
	require.NoError(t, err)

	// Create and sign transaction
	tx, err := blockchain.NewTransaction("alice", "bob", 100, 1)
	require.NoError(t, err)
	err = tx.SignTransaction([]byte("test-key"))
	require.NoError(t, err)

	// Add transaction to blockchain
	err = chain.AddTransaction(tx)
	require.NoError(t, err)

	// Create block
	block, err := chain.CreateBlock(nil, 10) // nil parent IDs for first block
	require.NoError(t, err)

	// Submit block
	err = chain.SubmitBlock(block)
	require.NoError(t, err)

	// Process blocks
	err = chain.ProcessPendingBlocks()
	require.NoError(t, err)

	// Verify block was added correctly
	retrievedBlock, err := chain.GetBlock(block.ID())
	assert.NoError(t, err)
	assert.NotNil(t, retrievedBlock)

	// Test chain state
	assert.Equal(t, uint64(1), chain.GetBlockchainHeight())
	latestBlocks := chain.GetLatestBlocks()
	assert.Len(t, latestBlocks, 1)
	assert.Equal(t, block.ID(), latestBlocks[0].ID())
}
