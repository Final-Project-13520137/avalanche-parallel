// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"testing"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/stretchr/testify/assert"
)

func TestNewBlock(t *testing.T) {
	// Create test transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx2, _ := NewTransaction("charlie", "dave", 50, 2)
	txs := []*Transaction{tx1, tx2}

	// Create parent IDs
	parentIDs := []ids.ID{ids.GenerateTestID()}

	// Test block creation
	block, err := NewBlock(parentIDs, txs, 1)
	assert.NoError(t, err)
	assert.NotNil(t, block)
	assert.Equal(t, parentIDs, block.ParentIDs)
	assert.Equal(t, uint64(1), block.Height)
	assert.Equal(t, txs, block.Transactions)
	assert.Equal(t, block.status.String(), "Processing")
	assert.NotEmpty(t, block.bytes)
}

func TestBlockVerify(t *testing.T) {
	ctx := context.Background()

	// Create valid transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx2, _ := NewTransaction("charlie", "dave", 50, 2)
	validTxs := []*Transaction{tx1, tx2}

	// Create block with valid transactions
	validBlock, _ := NewBlock([]ids.ID{ids.GenerateTestID()}, validTxs, 1)
	err := validBlock.Verify(ctx)
	assert.NoError(t, err)

	// Create invalid transaction
	invalidTx, _ := NewTransaction("alice", "", 100, 1)
	invalidTxs := []*Transaction{invalidTx}

	// Create block with invalid transaction
	invalidBlock, _ := NewBlock([]ids.ID{ids.GenerateTestID()}, invalidTxs, 1)
	err = invalidBlock.Verify(ctx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid transaction")
}

func TestBlockStatus(t *testing.T) {
	ctx := context.Background()

	// Create test transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx2, _ := NewTransaction("charlie", "dave", 50, 2)
	txs := []*Transaction{tx1, tx2}

	// Create block
	block, _ := NewBlock([]ids.ID{ids.GenerateTestID()}, txs, 1)

	// Test initial status
	assert.Equal(t, block.Status().String(), "Processing")

	// Test accept
	err := block.Accept(ctx)
	assert.NoError(t, err)
	assert.Equal(t, block.Status().String(), "Accepted")
	
	// Verify that transactions are also accepted
	assert.Equal(t, tx1.Status().String(), "Accepted")
	assert.Equal(t, tx2.Status().String(), "Accepted")

	// Test reject
	newBlock, _ := NewBlock([]ids.ID{ids.GenerateTestID()}, txs, 1)
	err = newBlock.Reject(ctx)
	assert.NoError(t, err)
	assert.Equal(t, newBlock.Status().String(), "Rejected")
}

func TestBlockTxs(t *testing.T) {
	ctx := context.Background()

	// Create test transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx2, _ := NewTransaction("charlie", "dave", 50, 2)
	inputTxs := []*Transaction{tx1, tx2}

	// Create block
	block, _ := NewBlock([]ids.ID{ids.GenerateTestID()}, inputTxs, 1)

	// Get transactions from block
	outputTxs, err := block.Txs(ctx)
	assert.NoError(t, err)
	assert.Len(t, outputTxs, 2)

	// Verify transaction IDs match
	assert.Equal(t, tx1.ID(), outputTxs[0].ID())
	assert.Equal(t, tx2.ID(), outputTxs[1].ID())
}

func TestBlockHeight(t *testing.T) {
	// Create blocks at different heights
	block1, _ := NewBlock([]ids.ID{}, []*Transaction{}, 5)
	block2, _ := NewBlock([]ids.ID{}, []*Transaction{}, 10)

	// Test Height method
	height1, err := block1.Height()
	assert.NoError(t, err)
	assert.Equal(t, uint64(5), height1)

	height2, err := block2.Height()
	assert.NoError(t, err)
	assert.Equal(t, uint64(10), height2)

	// Test GetProcessingPriority method
	assert.Equal(t, uint64(5), block1.GetProcessingPriority())
	assert.Equal(t, uint64(10), block2.GetProcessingPriority())
} 
