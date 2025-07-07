// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"testing"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/stretchr/testify/assert"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/shared/common"
)

func TestNewBlock(t *testing.T) {
	// Create test transactions
	tx1 := common.NewTransaction(ids.GenerateTestID(), "alice", "bob", 100, 1)
	tx2 := common.NewTransaction(ids.GenerateTestID(), "bob", "charlie", 50, 1)
	transactions := []*common.Transaction{tx1, tx2}

	// Create parent IDs
	parentIDs := []ids.ID{ids.GenerateTestID(), ids.GenerateTestID()}

	// Create block
	block, err := NewBlock(parentIDs, transactions, 1)
	assert.NoError(t, err)
	assert.NotNil(t, block)

	// Verify block properties
	assert.Equal(t, uint64(1), block.height)
	assert.Equal(t, len(parentIDs), len(block.ParentIDs))
	assert.Equal(t, len(transactions), len(block.Transactions))
	assert.Equal(t, "Processing", block.status.String())
}

func TestBlockAcceptReject(t *testing.T) {
	// Create test transactions
	tx1 := common.NewTransaction(ids.GenerateTestID(), "alice", "bob", 100, 1)
	tx2 := common.NewTransaction(ids.GenerateTestID(), "bob", "charlie", 50, 1)
	transactions := []*common.Transaction{tx1, tx2}

	// Create block
	block, err := NewBlock([]ids.ID{ids.GenerateTestID()}, transactions, 1)
	assert.NoError(t, err)

	// Test Accept
	ctx := context.Background()
	err = block.Accept(ctx)
	assert.NoError(t, err)
	assert.Equal(t, "Accepted", block.Status().String())

	// Verify transactions are accepted
	for _, tx := range block.Transactions {
		assert.Equal(t, "Accepted", tx.Status().String())
	}

	// Create new block for reject test
	block, err = NewBlock([]ids.ID{ids.GenerateTestID()}, transactions, 1)
	assert.NoError(t, err)

	// Test Reject
	err = block.Reject(ctx)
	assert.NoError(t, err)
	assert.Equal(t, "Rejected", block.Status().String())

	// Verify transactions are rejected
	for _, tx := range block.Transactions {
		assert.Equal(t, "Rejected", tx.Status().String())
	}
}

func TestBlockTxs(t *testing.T) {
	// Create test transactions
	tx1 := common.NewTransaction(ids.GenerateTestID(), "alice", "bob", 100, 1)
	tx2 := common.NewTransaction(ids.GenerateTestID(), "bob", "charlie", 50, 1)
	transactions := []*common.Transaction{tx1, tx2}

	// Create block
	block, err := NewBlock([]ids.ID{ids.GenerateTestID()}, transactions, 1)
	assert.NoError(t, err)

	// Test Txs method
	ctx := context.Background()
	txs, err := block.Txs(ctx)
	assert.NoError(t, err)
	assert.Equal(t, len(transactions), len(txs))

	// Verify each transaction
	for i, tx := range txs {
		assert.Equal(t, transactions[i].ID(), tx.ID())
	}
}

func TestBlockVerify(t *testing.T) {
	// Create test transactions
	tx1 := common.NewTransaction(ids.GenerateTestID(), "alice", "bob", 100, 1)
	tx2 := common.NewTransaction(ids.GenerateTestID(), "bob", "charlie", 50, 1)
	transactions := []*common.Transaction{tx1, tx2}

	// Create block
	block, err := NewBlock([]ids.ID{ids.GenerateTestID()}, transactions, 1)
	assert.NoError(t, err)

	// Test Verify
	ctx := context.Background()
	err = block.Verify(ctx)
	assert.NoError(t, err)
}
