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

func TestTransactionStatus(t *testing.T) {
	// Create a new transaction
	id := ids.GenerateTestID()
	tx := common.NewTransaction(id, "alice", "bob", 100, 1)

	// Test initial status
	assert.Equal(t, tx.Status().String(), "Processing")

	// Test accept
	err := tx.Accept(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, tx.Status().String(), "Accepted")

	// Test reject
	tx = common.NewTransaction(id, "alice", "bob", 100, 1)
	err = tx.Reject(context.Background())
	assert.NoError(t, err)
	assert.Equal(t, tx.Status().String(), "Rejected")
}

func TestTransactionDependencies(t *testing.T) {
	// Create transactions
	id1 := ids.GenerateTestID()
	id2 := ids.GenerateTestID()
	tx1 := common.NewTransaction(id1, "alice", "bob", 100, 1)
	tx2 := common.NewTransaction(id2, "bob", "charlie", 50, 1)

	// Test no dependencies initially
	missing, err := tx2.MissingDependencies()
	assert.NoError(t, err)
	assert.Equal(t, missing.Len(), 0)

	// Add dependency
	tx2.AddDependency(tx1.ID())

	// Test dependency added
	missing, err = tx2.MissingDependencies()
	assert.NoError(t, err)
	assert.Equal(t, missing.Len(), 1)
	assert.True(t, missing.Contains(tx1.ID()))
}
