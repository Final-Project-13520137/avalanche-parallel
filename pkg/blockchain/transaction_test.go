// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestNewTransaction(t *testing.T) {
	// Test valid transaction creation
	tx, err := NewTransaction("alice", "bob", 100, 1)
	assert.NoError(t, err)
	assert.NotNil(t, tx)
	assert.Equal(t, "alice", tx.Sender)
	assert.Equal(t, "bob", tx.Recipient)
	assert.Equal(t, uint64(100), tx.Amount)
	assert.Equal(t, uint64(1), tx.Nonce)

	// Verify initial status
	assert.Equal(t, tx.status.String(), "Processing")
}

func TestTransactionVerify(t *testing.T) {
	ctx := context.Background()

	// Test valid transaction
	tx, _ := NewTransaction("alice", "bob", 100, 1)
	err := tx.Verify(ctx)
	assert.NoError(t, err)

	// Test invalid transaction - empty sender
	invalidTx, _ := NewTransaction("", "bob", 100, 1)
	err = invalidTx.Verify(ctx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid sender or recipient")

	// Test invalid transaction - empty recipient
	invalidTx, _ = NewTransaction("alice", "", 100, 1)
	err = invalidTx.Verify(ctx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "invalid sender or recipient")

	// Test invalid transaction - zero amount
	invalidTx, _ = NewTransaction("alice", "bob", 0, 1)
	err = invalidTx.Verify(ctx)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "amount must be greater than zero")
}

func TestTransactionSignature(t *testing.T) {
	// Create a transaction
	tx, _ := NewTransaction("alice", "bob", 100, 1)

	// Test signing with valid private key
	err := tx.SignTransaction([]byte("valid-key"))
	assert.NoError(t, err)
	assert.NotEmpty(t, tx.Signature)

	// Test signing with empty private key
	tx, _ = NewTransaction("alice", "bob", 100, 1)
	err = tx.SignTransaction([]byte{})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "private key cannot be empty")

	// Test signature verification
	tx, _ = NewTransaction("alice", "bob", 100, 1)
	_ = tx.SignTransaction([]byte("valid-key"))
	assert.True(t, tx.VerifySignature([]byte("public-key")))
}

func TestTransactionDependencies(t *testing.T) {
	// Create transactions
	tx1, _ := NewTransaction("alice", "bob", 100, 1)
	tx2, _ := NewTransaction("bob", "charlie", 50, 1)

	// Test no dependencies initially
	deps, err := tx2.Dependencies()
	assert.NoError(t, err)
	assert.Empty(t, deps)

	// Add dependency
	tx2.AddDependency(tx1)

	// Test dependency added
	deps, err = tx2.Dependencies()
	assert.NoError(t, err)
	assert.Len(t, deps, 1)
	assert.Equal(t, tx1.ID(), deps[0].ID())

	// Test input IDs
	inputIDs, err := tx2.InputIDs()
	assert.NoError(t, err)
	assert.Len(t, inputIDs, 1)
	assert.Equal(t, tx1.ID(), inputIDs[0])
}

func TestTransactionStatus(t *testing.T) {
	ctx := context.Background()
	tx, _ := NewTransaction("alice", "bob", 100, 1)

	// Test initial status
	assert.Equal(t, tx.Status().String(), "Processing")

	// Test accept
	err := tx.Accept(ctx)
	assert.NoError(t, err)
	assert.Equal(t, tx.Status().String(), "Accepted")

	// Test reject
	tx, _ = NewTransaction("alice", "bob", 100, 1)
	err = tx.Reject(ctx)
	assert.NoError(t, err)
	assert.Equal(t, tx.Status().String(), "Rejected")
} 