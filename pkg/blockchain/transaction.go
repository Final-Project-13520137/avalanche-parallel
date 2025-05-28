// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"crypto/sha256"
	"errors"
	"fmt"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/snow/consensus/snowstorm"
	"github.com/ava-labs/avalanchego/utils/set"
)

var (
	ErrInvalidSenderOrRecipient = errors.New("invalid sender or recipient")
	ErrZeroAmount               = errors.New("amount must be greater than zero")
	ErrEmptyPrivateKey          = errors.New("private key cannot be empty")
	ErrInvalidSignature         = errors.New("invalid signature")
)

// Transaction represents a transfer of tokens from a sender to a recipient
type Transaction struct {
	ID_       ids.ID              `json:"id"`
	Sender    string              `json:"sender"`
	Recipient string              `json:"recipient"`
	Amount    uint64              `json:"amount"`
	Nonce     uint64              `json:"nonce"`
	Signature []byte              `json:"signature"`
	status    choices.Status      `json:"status"`
	deps      []snowstorm.Tx      `json:"dependencies"`
	bytes     []byte              `json:"bytes"`
}

// NewTransaction creates a new transaction
func NewTransaction(sender, recipient string, amount, nonce uint64) (*Transaction, error) {
	tx := &Transaction{
		Sender:    sender,
		Recipient: recipient,
		Amount:    amount,
		Nonce:     nonce,
		status:    choices.Processing,
	}

	// Generate ID based on transaction data
	bytes, err := tx.generateBytes()
	if err != nil {
		return nil, err
	}
	tx.bytes = bytes
	
	// Use the bytes to create the ID
	hasher := sha256.New()
	hasher.Write(bytes)
	copy(tx.ID_[:], hasher.Sum(nil))

	return tx, nil
}

// ID returns the transaction ID
func (tx *Transaction) ID() ids.ID {
	return tx.ID_
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

// Bytes returns the byte representation of the transaction
func (tx *Transaction) Bytes() []byte {
	if tx.bytes == nil {
		// Generate bytes if not already cached
		bytes, err := tx.generateBytes()
		if err != nil {
			// In case of error, return a default value
			return []byte{}
		}
		tx.bytes = bytes
	}
	return tx.bytes
}

// generateBytes creates the byte representation of the transaction
func (tx *Transaction) generateBytes() ([]byte, error) {
	return []byte(fmt.Sprintf("%s-%s-%d-%d", tx.Sender, tx.Recipient, tx.Amount, tx.Nonce)), nil
}

// Verify checks if the transaction is valid
func (tx *Transaction) Verify(ctx context.Context) error {
	// Check for valid sender and recipient
	if tx.Sender == "" || tx.Recipient == "" {
		return ErrInvalidSenderOrRecipient
	}

	// Check for valid amount
	if tx.Amount == 0 {
		return ErrZeroAmount
	}

	return nil
}

// Dependencies returns transactions that must be accepted before this one
func (tx *Transaction) Dependencies() ([]snowstorm.Tx, error) {
	return tx.deps, nil
}

// InputIDs returns the IDs of transactions this transaction depends on
func (tx *Transaction) InputIDs() ([]ids.ID, error) {
	inputIDs := make([]ids.ID, 0, len(tx.deps))
	for _, dep := range tx.deps {
		inputIDs = append(inputIDs, dep.ID())
	}
	return inputIDs, nil
}

// SignTransaction signs the transaction with the given private key
func (tx *Transaction) SignTransaction(privateKey []byte) error {
	if len(privateKey) == 0 {
		return ErrEmptyPrivateKey
	}

	// In a real implementation, we would use the private key to sign the transaction
	// For testing purposes, we'll just store the key as the signature
	tx.Signature = privateKey
	return nil
}

// VerifySignature verifies the transaction signature with the given public key
func (tx *Transaction) VerifySignature(publicKey []byte) bool {
	// In a real implementation, we would verify the signature using the public key
	// For testing purposes, we'll just return true
	return len(tx.Signature) > 0
}

// AddDependency adds a transaction as a dependency
func (tx *Transaction) AddDependency(dep snowstorm.Tx) {
	tx.deps = append(tx.deps, dep)
}

// MissingDependencies returns the missing dependencies of the transaction
func (tx *Transaction) MissingDependencies() (set.Set[ids.ID], error) {
	// For simplicity, we'll just return an empty set since we don't track missing dependencies
	return set.Set[ids.ID]{}, nil
} 