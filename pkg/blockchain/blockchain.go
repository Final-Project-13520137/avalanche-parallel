// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

// Blockchain manages the chain of blocks and transaction processing
type Blockchain struct {
	lock          sync.RWMutex
	logger        logging.Logger
	genesisBlock  *Block
	txPool        map[ids.ID]*Transaction  // Pending transactions
	blocks        map[ids.ID]*Block        // All blocks
	acceptedBlocks map[ids.ID]*Block       // Accepted blocks
	pendingBlocks map[ids.ID]*Block        // Blocks being processed
	latestBlocks  map[ids.ID]*Block        // Blocks at the edge of the DAG
	blocksByHeight map[uint64][]*Block     // Blocks organized by height
	currentHeight uint64                   // Current blockchain height
	maxWorkers    int                      // Maximum number of parallel workers
}

// NewBlockchain creates a new blockchain instance
func NewBlockchain(logger logging.Logger, maxWorkers int) (*Blockchain, error) {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}

	bc := &Blockchain{
		logger:        logger,
		txPool:        make(map[ids.ID]*Transaction),
		blocks:        make(map[ids.ID]*Block),
		acceptedBlocks: make(map[ids.ID]*Block),
		pendingBlocks: make(map[ids.ID]*Block),
		latestBlocks:  make(map[ids.ID]*Block),
		blocksByHeight: make(map[uint64][]*Block),
		currentHeight: 0,
		maxWorkers:    maxWorkers,
	}

	// Create genesis block
	genesis, err := bc.createGenesisBlock()
	if err != nil {
		return nil, fmt.Errorf("failed to create genesis block: %w", err)
	}
	bc.genesisBlock = genesis
	bc.blocks[genesis.ID()] = genesis
	bc.acceptedBlocks[genesis.ID()] = genesis
	bc.latestBlocks[genesis.ID()] = genesis
	bc.blocksByHeight[0] = []*Block{genesis}

	return bc, nil
}

// AddTransaction adds a transaction to the mempool
func (bc *Blockchain) AddTransaction(tx *Transaction) error {
	bc.lock.Lock()
	defer bc.lock.Unlock()

	// Verify transaction
	if err := tx.Verify(context.Background()); err != nil {
		return fmt.Errorf("invalid transaction: %w", err)
	}

	// Check if transaction is already in the pool
	if _, exists := bc.txPool[tx.ID()]; exists {
		return fmt.Errorf("transaction already in pool: %s", tx.ID())
	}

	// Add to pool
	bc.txPool[tx.ID()] = tx
	bc.logger.Info("Added transaction %s to pool", tx.ID())

	return nil
}

// CreateBlock creates a new block with transactions from the pool
func (bc *Blockchain) CreateBlock(parentIDs []ids.ID, maxTxs int) (*Block, error) {
	bc.lock.Lock()
	defer bc.lock.Unlock()

	// Validate parent blocks exist
	for _, parentID := range parentIDs {
		if _, exists := bc.blocks[parentID]; !exists {
			return nil, fmt.Errorf("parent block not found: %s", parentID)
		}
	}

	// Determine block height (max of parents + 1)
	height := bc.currentHeight + 1
	for _, parentID := range parentIDs {
		parent := bc.blocks[parentID]
		if parent.Height >= bc.currentHeight {
			height = parent.Height + 1
		}
	}

	// Select transactions from the pool (up to maxTxs)
	selectedTxs := make([]*Transaction, 0, maxTxs)
	count := 0
	for _, tx := range bc.txPool {
		selectedTxs = append(selectedTxs, tx)
		delete(bc.txPool, tx.ID())
		count++
		if count >= maxTxs {
			break
		}
	}

	// Create the block
	block, err := NewBlock(parentIDs, selectedTxs, height)
	if err != nil {
		// Return transactions to pool on error
		for _, tx := range selectedTxs {
			bc.txPool[tx.ID()] = tx
		}
		return nil, fmt.Errorf("failed to create block: %w", err)
	}

	// Add to pending blocks
	bc.blocks[block.ID()] = block
	bc.pendingBlocks[block.ID()] = block
	
	// Add to blocks by height map
	if _, exists := bc.blocksByHeight[height]; !exists {
		bc.blocksByHeight[height] = make([]*Block, 0)
	}
	bc.blocksByHeight[height] = append(bc.blocksByHeight[height], block)

	bc.logger.Info("Created block %s at height %d with %d transactions", 
		block.ID(), height, len(selectedTxs))

	return block, nil
}

// SubmitBlock submits a block for consensus
func (bc *Blockchain) SubmitBlock(block *Block) error {
	bc.lock.Lock()
	defer bc.lock.Unlock()

	// Check if block already exists
	if _, exists := bc.blocks[block.ID()]; !exists {
		bc.blocks[block.ID()] = block
		bc.pendingBlocks[block.ID()] = block
	}

	// Update latest blocks
	// Remove parents from latest blocks
	for _, parentID := range block.ParentIDs {
		delete(bc.latestBlocks, parentID)
	}
	
	// Add this block to latest blocks
	bc.latestBlocks[block.ID()] = block

	// Update blockchain height if needed
	if block.Height > bc.currentHeight {
		bc.currentHeight = block.Height
	}

	bc.logger.Info("Submitted block %s for processing", block.ID())
	return nil
}

// ProcessPendingBlocks processes blocks waiting for consensus
func (bc *Blockchain) ProcessPendingBlocks() error {
	bc.lock.Lock()
	pendingBlocks := make([]*Block, 0, len(bc.pendingBlocks))
	for _, block := range bc.pendingBlocks {
		pendingBlocks = append(pendingBlocks, block)
	}
	bc.lock.Unlock()

	// Process blocks in parallel
	var wg sync.WaitGroup
	results := make(chan struct {
		blockID ids.ID
		err     error
	}, len(pendingBlocks))

	// Create a semaphore to limit concurrency
	semaphore := make(chan struct{}, bc.maxWorkers)

	for _, block := range pendingBlocks {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire
		
		go func(b *Block) {
			defer func() {
				<-semaphore // Release
				wg.Done()
			}()

			ctx := context.Background()
			err := b.Verify(ctx)
			
			if err == nil {
				// Simulate consensus process
				time.Sleep(100 * time.Millisecond)
				
				// Accept the block
				err = b.Accept(ctx)
			}

			results <- struct {
				blockID ids.ID
				err     error
			}{b.ID(), err}
		}(block)
	}

	// Wait for all blocks to be processed
	go func() {
		wg.Wait()
		close(results)
	}()

	// Process results
	bc.lock.Lock()
	defer bc.lock.Unlock()

	for result := range results {
		if result.err != nil {
			bc.logger.Error("Failed to process block %s: %s", result.blockID, result.err)
			// Could implement rejection here
			continue
		}

		// Mark as accepted
		block := bc.blocks[result.blockID]
		bc.acceptedBlocks[result.blockID] = block
		delete(bc.pendingBlocks, result.blockID)
		bc.logger.Info("Accepted block %s at height %d", result.blockID, block.Height)
	}

	return nil
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

// GetBlock retrieves a block by ID
func (bc *Blockchain) GetBlock(id ids.ID) (*Block, error) {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	block, exists := bc.blocks[id]
	if !exists {
		return nil, fmt.Errorf("block not found: %s", id)
	}
	return block, nil
}

// GetTransaction retrieves a transaction by ID
func (bc *Blockchain) GetTransaction(id ids.ID) (*Transaction, error) {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	// Check in mempool first
	if tx, exists := bc.txPool[id]; exists {
		return tx, nil
	}

	// Check in blocks
	for _, block := range bc.blocks {
		for _, tx := range block.Transactions {
			if tx.ID() == id {
				return tx, nil
			}
		}
	}

	return nil, fmt.Errorf("transaction not found: %s", id)
}

// GetBlockchainHeight returns the current blockchain height
func (bc *Blockchain) GetBlockchainHeight() uint64 {
	bc.lock.RLock()
	defer bc.lock.RUnlock()
	return bc.currentHeight
}

// GetBlocksByHeight returns blocks at the specified height
func (bc *Blockchain) GetBlocksByHeight(height uint64) []*Block {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	blocks, exists := bc.blocksByHeight[height]
	if !exists {
		return []*Block{}
	}
	return blocks
}

// GetLatestBlocks returns the blocks at the edge of the DAG
func (bc *Blockchain) GetLatestBlocks() []*Block {
	bc.lock.RLock()
	defer bc.lock.RUnlock()

	latest := make([]*Block, 0, len(bc.latestBlocks))
	for _, block := range bc.latestBlocks {
		latest = append(latest, block)
	}
	return latest
}

// createGenesisBlock creates the genesis block
func (bc *Blockchain) createGenesisBlock() (*Block, error) {
	genesis, err := NewBlock([]ids.ID{}, []*Transaction{}, 0)
	if err != nil {
		return nil, err
	}

	// Accept the genesis block
	err = genesis.Accept(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to accept genesis block: %w", err)
	}

	return genesis, nil
} 