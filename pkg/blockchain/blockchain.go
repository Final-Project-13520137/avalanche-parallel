// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/consensus"
)

const (
	// DefaultMaxParallelism defines the default maximum number of parallel processors
	DefaultMaxParallelism = 4
)

// Blockchain implements a simple blockchain using Avalanche consensus with ParallelDAG
type Blockchain struct {
	lock            sync.RWMutex
	logger          logging.Logger
	blocks          map[ids.ID]*Block
	txPool          map[ids.ID]*Transaction
	acceptedBlocks  map[ids.ID]*Block
	pendingBlocks   map[ids.ID]*Block
	acceptedTxs     map[ids.ID]*Transaction
	latestBlocks    map[ids.ID]*Block // Blocks with no children (frontier)
	parallelEngine  *consensus.ParallelEngine
	genesisBlock    *Block
	currentHeight   uint64
}

// NewBlockchain creates a new blockchain with Avalanche consensus
func NewBlockchain(logger logging.Logger, maxParallelism int) (*Blockchain, error) {
	if maxParallelism <= 0 {
		maxParallelism = DefaultMaxParallelism
	}

	bc := &Blockchain{
		logger:         logger,
		blocks:         make(map[ids.ID]*Block),
		txPool:         make(map[ids.ID]*Transaction),
		acceptedBlocks: make(map[ids.ID]*Block),
		pendingBlocks:  make(map[ids.ID]*Block),
		acceptedTxs:    make(map[ids.ID]*Transaction),
		latestBlocks:   make(map[ids.ID]*Block),
		parallelEngine: consensus.NewParallelEngine(logger, maxParallelism),
		currentHeight:  0,
	}

	// Create and add genesis block
	if err := bc.createGenesisBlock(); err != nil {
		return nil, fmt.Errorf("failed to create genesis block: %w", err)
	}

	return bc, nil
}

// createGenesisBlock creates the genesis block for the blockchain
func (bc *Blockchain) createGenesisBlock() error {
	genesisBlock, err := NewBlock([]ids.ID{}, []*Transaction{}, 0)
	if err != nil {
		return fmt.Errorf("failed to create genesis block: %w", err)
	}

	// Set genesis block as accepted
	ctx := context.Background()
	if err := genesisBlock.Accept(ctx); err != nil {
		return fmt.Errorf("failed to accept genesis block: %w", err)
	}

	// Add genesis block to blockchain
	bc.blocks[genesisBlock.ID()] = genesisBlock
	bc.acceptedBlocks[genesisBlock.ID()] = genesisBlock
	bc.latestBlocks[genesisBlock.ID()] = genesisBlock
	bc.genesisBlock = genesisBlock

	return nil
}

// GetBlock returns a block by ID
func (bc *Blockchain) GetBlock(id ids.ID) (*Block, error) {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	block, exists := bc.blocks[id]
	if !exists {
		return nil, fmt.Errorf("block not found: %s", id)
	}
	return block, nil
}

// GetTransaction returns a transaction by ID
func (bc *Blockchain) GetTransaction(id ids.ID) (*Transaction, error) {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	// Check in accepted transactions
	if tx, exists := bc.acceptedTxs[id]; exists {
		return tx, nil
	}

	// Check in transaction pool
	if tx, exists := bc.txPool[id]; exists {
		return tx, nil
	}

	return nil, fmt.Errorf("transaction not found: %s", id)
}

// AddTransaction adds a transaction to the mempool
func (bc *Blockchain) AddTransaction(tx *Transaction) error {
	bc.lock.Lock()
	defer bc.lock.Unlock()

	// Check if transaction already exists
	if _, exists := bc.txPool[tx.ID()]; exists {
		return fmt.Errorf("transaction already in pool: %s", tx.ID())
	}
	if _, exists := bc.acceptedTxs[tx.ID()]; exists {
		return fmt.Errorf("transaction already accepted: %s", tx.ID())
	}

	// Verify the transaction
	ctx := context.Background()
	if err := tx.Verify(ctx); err != nil {
		return fmt.Errorf("invalid transaction: %w", err)
	}

	// Add to mempool
	bc.txPool[tx.ID()] = tx
	bc.logger.Info("Added transaction to pool: %s", tx.ID())

	return nil
}

// CreateBlock creates a new block with pending transactions
func (bc *Blockchain) CreateBlock(parentIDs []ids.ID, maxTxs int) (*Block, error) {
	bc.lock.Lock()
	defer bc.lock.Unlock()

	// Determine block height (max of parent heights + 1)
	var maxParentHeight uint64 = 0
	for _, parentID := range parentIDs {
		parent, exists := bc.blocks[parentID]
		if !exists {
			return nil, fmt.Errorf("parent block not found: %s", parentID)
		}
		if parent.Height > maxParentHeight {
			maxParentHeight = parent.Height
		}
	}
	blockHeight := maxParentHeight + 1

	// If no parents specified, use latest blocks
	if len(parentIDs) == 0 {
		for _, latestBlock := range bc.latestBlocks {
			parentIDs = append(parentIDs, latestBlock.ID())
		}
	}

	// Select transactions for the block
	var selectedTxs []*Transaction
	for _, tx := range bc.txPool {
		if tx.Status() == choices.Processing {
			selectedTxs = append(selectedTxs, tx)
			if len(selectedTxs) >= maxTxs && maxTxs > 0 {
				break
			}
		}
	}

	// Create new block
	block, err := NewBlock(parentIDs, selectedTxs, blockHeight)
	if err != nil {
		return nil, fmt.Errorf("failed to create block: %w", err)
	}

	// Add block to blockchain
	bc.blocks[block.ID()] = block
	bc.pendingBlocks[block.ID()] = block
	bc.currentHeight = blockHeight

	// Remove transactions from pool
	for _, tx := range selectedTxs {
		delete(bc.txPool, tx.ID())
	}

	bc.logger.Info("Created new block: %s at height %d with %d transactions", 
		block.ID(), blockHeight, len(selectedTxs))

	return block, nil
}

// SubmitBlock submits a block to the consensus engine
func (bc *Blockchain) SubmitBlock(block *Block) error {
	// Submit block to parallel engine for processing
	ctx := context.Background()
	if err := bc.parallelEngine.ProcessVertex(ctx, block); err != nil {
		return fmt.Errorf("failed to process block: %w", err)
	}

	// Update latest blocks - remove parents from frontier and add this block
	bc.lock.Lock()
	defer bc.lock.Unlock()

	for _, parentID := range block.ParentIDs {
		delete(bc.latestBlocks, parentID)
	}
	bc.latestBlocks[block.ID()] = block

	bc.logger.Info("Submitted block to consensus: %s", block.ID())
	return nil
}

// ProcessPendingBlocks processes all pending blocks through the consensus engine
func (bc *Blockchain) ProcessPendingBlocks() error {
	bc.lock.Lock()
	pendingBlocks := make([]*Block, 0, len(bc.pendingBlocks))
	for _, block := range bc.pendingBlocks {
		pendingBlocks = append(pendingBlocks, block)
	}
	bc.lock.Unlock()

	if len(pendingBlocks) == 0 {
		return nil
	}

	// Convert to avalanche.Vertex slice
	vertices := make([]avalanche.Vertex, len(pendingBlocks))
	for i, block := range pendingBlocks {
		vertices[i] = block
	}

	// Process through parallel engine
	ctx := context.Background()
	if err := bc.parallelEngine.BatchProcessVertices(ctx, vertices); err != nil {
		return fmt.Errorf("failed to process pending blocks: %w", err)
	}

	// Update blockchain state based on consensus results
	bc.lock.Lock()
	defer bc.lock.Unlock()

	for _, block := range pendingBlocks {
		if block.Status() == choices.Accepted {
			bc.acceptedBlocks[block.ID()] = block
			delete(bc.pendingBlocks, block.ID())

			// Add accepted transactions
			for _, tx := range block.Transactions {
				bc.acceptedTxs[tx.ID()] = tx
			}

			bc.logger.Info("Block accepted: %s", block.ID())
		} else if block.Status() == choices.Rejected {
			delete(bc.pendingBlocks, block.ID())
			bc.logger.Info("Block rejected: %s", block.ID())
		}
	}

	return nil
}

// GetLatestBlocks returns the blocks at the frontier (with no children)
func (bc *Blockchain) GetLatestBlocks() []*Block {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	latest := make([]*Block, 0, len(bc.latestBlocks))
	for _, block := range bc.latestBlocks {
		latest = append(latest, block)
	}
	return latest
}

// GetBlockchainHeight returns the current height of the blockchain
func (bc *Blockchain) GetBlockchainHeight() uint64 {
	bc.lock.RLock()
	defer bc.lock.RUnlock()
	return bc.currentHeight
}

// GetBlocksByHeight returns blocks at the specified height
func (bc *Blockchain) GetBlocksByHeight(height uint64) []*Block {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	var blocksAtHeight []*Block
	for _, block := range bc.blocks {
		if block.Height == height {
			blocksAtHeight = append(blocksAtHeight, block)
		}
	}
	return blocksAtHeight
}

// RunConsensus runs the consensus process continuously
func (bc *Blockchain) RunConsensus(ctx context.Context, interval time.Duration) {
	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			if err := bc.ProcessPendingBlocks(); err != nil {
				bc.logger.Error("Error processing pending blocks: %s", err)
			}
		}
	}
} 