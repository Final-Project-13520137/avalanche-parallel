// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"crypto/sha256"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
)

// Transaction implements the snowstorm.Tx interface to be used with Avalanche consensus
type Transaction struct {
	TxID        ids.ID          `json:"id"`
	Sender      string          `json:"sender"`
	Recipient   string          `json:"recipient"`
	Amount      uint64          `json:"amount"`
	Nonce       uint64          `json:"nonce"`
	Timestamp   int64           `json:"timestamp"`
	Signature   []byte          `json:"signature"`
	status      choices.Status  `json:"-"`
	bytes       []byte          `json:"-"`
	dependencies []snowstorm.Tx `json:"-"`
}

// NewTransaction creates a new transaction
func NewTransaction(sender string, recipient string, amount uint64, nonce uint64) (*Transaction, error) {
	tx := &Transaction{
		Sender:    sender,
		Recipient: recipient,
		Amount:    amount,
		Nonce:     nonce,
		Timestamp: time.Now().UnixNano(),
		status:    choices.Processing,
	}

	// Generate transaction ID and bytes
	bytes, err := json.Marshal(tx)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal transaction: %w", err)
	}
	tx.bytes = bytes

	hash := sha256.Sum256(bytes)
	copy(tx.TxID[:], hash[:])

	return tx, nil
}

// ID returns the transaction ID
func (tx *Transaction) ID() ids.ID {
	return tx.TxID
}

// Accept marks the transaction as accepted
func (tx *Transaction) Accept(ctx context.Context) error {
	tx.status = choices.Accepted
	return nil
}

// Reject marks the transaction as rejected
func (tx *Transaction) Reject(ctx context.Context) error {
	tx.status = choices.Rejected
	return nil
}

// Status returns the transaction status
func (tx *Transaction) Status() choices.Status {
	return tx.status
}

// Bytes returns the transaction bytes
func (tx *Transaction) Bytes() []byte {
	return tx.bytes
}

// Verify verifies the transaction validity
func (tx *Transaction) Verify(ctx context.Context) error {
	// In a real implementation, you would:
	// 1. Verify signature
	// 2. Check if sender has enough balance
	// 3. Validate nonce
	// For simplicity, we'll just do basic validation

	if tx.Sender == "" || tx.Recipient == "" {
		return fmt.Errorf("invalid sender or recipient")
	}

	if tx.Amount == 0 {
		return fmt.Errorf("amount must be greater than zero")
	}

	return nil
}

// Dependencies returns the transactions this one depends on
func (tx *Transaction) Dependencies() ([]snowstorm.Tx, error) {
	return tx.dependencies, nil
}

// AddDependency adds a transaction dependency
func (tx *Transaction) AddDependency(dep snowstorm.Tx) {
	tx.dependencies = append(tx.dependencies, dep)
}

// InputIDs returns the IDs of the inputs consumed by this transaction
func (tx *Transaction) InputIDs() ([]ids.ID, error) {
	// For simplicity, we'll treat dependencies as inputs
	deps, err := tx.Dependencies()
	if err != nil {
		return nil, err
	}

	inputIDs := make([]ids.ID, len(deps))
	for i, dep := range deps {
		inputIDs[i] = dep.ID()
	}
	return inputIDs, nil
}

// SignTransaction signs the transaction (simplified)
func (tx *Transaction) SignTransaction(privateKey []byte) error {
	// In a real implementation, this would use proper cryptographic signing
	// For simplicity, we'll just create a dummy signature

	if len(privateKey) == 0 {
		return fmt.Errorf("private key cannot be empty")
	}

	// Create dummy signature based on private key and transaction data
	data := tx.Bytes()
	signature := make([]byte, 8)
	binary.LittleEndian.PutUint64(signature, uint64(len(data)))
	
	tx.Signature = signature
	return nil
}

// VerifySignature verifies the transaction signature (simplified)
func (tx *Transaction) VerifySignature(publicKey []byte) bool {
	// In a real implementation, this would use proper cryptographic verification
	// For simplicity, we'll just return true
	return len(tx.Signature) > 0
} 