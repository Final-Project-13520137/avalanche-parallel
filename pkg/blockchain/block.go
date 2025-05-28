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
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
)

// Block represents a block in the blockchain, implementing the ParallelVertex interface
type Block struct {
	ID_          ids.ID          `json:"id"`
	ParentIDs    []ids.ID        `json:"parentIDs"`
	Height       uint64          `json:"height"`
	Timestamp    int64           `json:"timestamp"`
	Transactions []*Transaction  `json:"transactions"`
	status       choices.Status  `json:"status"`
	bytes        []byte          `json:"bytes"`
}

// NewBlock creates a new block
func NewBlock(parentIDs []ids.ID, transactions []*Transaction, height uint64) (*Block, error) {
	block := &Block{
		ParentIDs:    parentIDs,
		Transactions: transactions,
		Height:       height,
		Timestamp:    time.Now().UnixNano(),
		status:       choices.Processing,
	}

	// Generate bytes and ID
	bytes, err := block.generateBytes()
	if err != nil {
		return nil, err
	}
	block.bytes = bytes
	block.ID_ = ids.ID(ids.NewID(bytes))

	return block, nil
}

// ID returns the block ID
func (b *Block) ID() ids.ID {
	return b.ID_
}

// Accept marks the block as accepted and processes all its transactions
func (b *Block) Accept(ctx context.Context) error {
	b.status = choices.Accepted

	// Accept all transactions in this block
	for _, tx := range b.Transactions {
		if err := tx.Accept(ctx); err != nil {
			return err
		}
	}

	return nil
}

// Reject marks the block as rejected
func (b *Block) Reject(ctx context.Context) error {
	b.status = choices.Rejected

	// Reject all transactions in this block
	for _, tx := range b.Transactions {
		if err := tx.Reject(ctx); err != nil {
			return err
		}
	}

	return nil
}

// Status returns the block status
func (b *Block) Status() choices.Status {
	return b.status
}

// Parent returns the parent block IDs
func (b *Block) Parents() ([]ids.ID, error) {
	return b.ParentIDs, nil
}

// Height returns the block height
func (b *Block) Height() (uint64, error) {
	return b.Height, nil
}

// Bytes returns the byte representation of the block
func (b *Block) Bytes() []byte {
	return b.bytes
}

// Verify verifies the block and all its transactions
func (b *Block) Verify(ctx context.Context) error {
	// Verify each transaction
	for _, tx := range b.Transactions {
		if err := tx.Verify(ctx); err != nil {
			return fmt.Errorf("invalid transaction: %w", err)
		}
	}

	return nil
}

// Txs returns all transactions in the block as snowstorm.Tx
func (b *Block) Txs(ctx context.Context) ([]snowstorm.Tx, error) {
	txs := make([]snowstorm.Tx, len(b.Transactions))
	for i, tx := range b.Transactions {
		txs[i] = tx
	}
	return txs, nil
}

// generateBytes creates a byte representation of the block
func (b *Block) generateBytes() ([]byte, error) {
	// For simplicity, create a basic representation
	// In a real implementation, we would use a more sophisticated encoding
	
	// Allocate buffer for height (8 bytes) + parent count (8 bytes) + parent IDs + tx count (8 bytes)
	parentIDsSize := len(b.ParentIDs) * ids.IDLen
	buffer := make([]byte, 8+8+parentIDsSize+8)
	
	// Add height
	binary.BigEndian.PutUint64(buffer[:8], b.Height)
	
	// Add parent count
	binary.BigEndian.PutUint64(buffer[8:16], uint64(len(b.ParentIDs)))
	
	// Add parent IDs
	offset := 16
	for _, parentID := range b.ParentIDs {
		copy(buffer[offset:offset+ids.IDLen], parentID[:])
		offset += ids.IDLen
	}
	
	// Add transaction count
	binary.BigEndian.PutUint64(buffer[offset:offset+8], uint64(len(b.Transactions)))
	
	return buffer, nil
}

// GetProcessingPriority returns the block's processing priority
func (b *Block) GetProcessingPriority() uint64 {
	return b.Height
}

// Parents returns the parent vertices of this block
func (b *Block) Parents() ([]avalanche.Vertex, error) {
	// In a real implementation, you would fetch the actual parent blocks
	// For now, we'll return empty to simplify
	return []avalanche.Vertex{}, nil
}

// Timestamp returns the timestamp of this block
func (b *Block) Timestamp() (int64, error) {
	return b.Timestamp, nil
} 