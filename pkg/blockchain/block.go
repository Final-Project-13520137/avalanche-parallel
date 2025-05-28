// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
)

// Block implements the avalanche.Vertex interface for use with Avalanche consensus
type Block struct {
	BlockID     ids.ID               `json:"id"`
	ParentIDs   []ids.ID             `json:"parentIDs"`
	Height      uint64               `json:"height"`
	Timestamp   int64                `json:"timestamp"`
	Transactions []*Transaction      `json:"transactions"`
	status      choices.Status       `json:"-"`
	bytes       []byte               `json:"-"`
	priority    uint64               `json:"-"`
}

// NewBlock creates a new block with the given parent IDs and transactions
func NewBlock(parentIDs []ids.ID, txs []*Transaction, height uint64) (*Block, error) {
	block := &Block{
		ParentIDs:    parentIDs,
		Height:       height,
		Timestamp:    time.Now().UnixNano(),
		Transactions: txs,
		status:       choices.Processing,
		priority:     height, // Use height as priority for now
	}

	// Generate block ID and bytes
	jsonBytes, err := json.Marshal(block)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal block: %w", err)
	}
	block.bytes = jsonBytes

	hash := sha256.Sum256(jsonBytes)
	copy(block.BlockID[:], hash[:])

	return block, nil
}

// ID returns the block ID
func (b *Block) ID() ids.ID {
	return b.BlockID
}

// Accept marks the block as accepted
func (b *Block) Accept(ctx context.Context) error {
	b.status = choices.Accepted
	
	// Also accept all transactions in the block
	for _, tx := range b.Transactions {
		if err := tx.Accept(ctx); err != nil {
			return fmt.Errorf("failed to accept transaction: %w", err)
		}
	}
	
	return nil
}

// Reject marks the block as rejected
func (b *Block) Reject(ctx context.Context) error {
	b.status = choices.Rejected
	
	// Also reject all transactions in the block
	for _, tx := range b.Transactions {
		if err := tx.Reject(ctx); err != nil {
			return fmt.Errorf("failed to reject transaction: %w", err)
		}
	}
	
	return nil
}

// Status returns the block status
func (b *Block) Status() choices.Status {
	return b.status
}

// Parents returns the parent vertices of this block
func (b *Block) Parents() ([]avalanche.Vertex, error) {
	// In a real implementation, you would fetch the actual parent blocks
	// For now, we'll return empty to simplify
	return []avalanche.Vertex{}, nil
}

// Height returns the height of this block
func (b *Block) Height() (uint64, error) {
	return b.Height, nil
}

// Txs returns the transactions in this block
func (b *Block) Txs(ctx context.Context) ([]snowstorm.Tx, error) {
	txs := make([]snowstorm.Tx, len(b.Transactions))
	for i, tx := range b.Transactions {
		txs[i] = tx
	}
	return txs, nil
}

// Bytes returns the serialized bytes of this block
func (b *Block) Bytes() []byte {
	return b.bytes
}

// Verify verifies this block is valid
func (b *Block) Verify(ctx context.Context) error {
	// Verify all transactions
	for _, tx := range b.Transactions {
		if err := tx.Verify(ctx); err != nil {
			return fmt.Errorf("invalid transaction: %w", err)
		}
	}
	
	return nil
}

// GetProcessingPriority returns the priority for processing this block
func (b *Block) GetProcessingPriority() uint64 {
	return b.priority
} 