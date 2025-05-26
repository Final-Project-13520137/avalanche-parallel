package storage

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"os"
	"path/filepath"
	"sync"

	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	"go.uber.org/zap"
)

// Manager defines the interface for storage operations
type Manager interface {
	// SaveBlock saves a block to storage
	SaveBlock(block *types.Block) error
	
	// LoadBlocks loads all blocks from storage
	LoadBlocks() ([]*types.Block, error)
	
	// GetBlock retrieves a specific block by index
	GetBlock(index uint64) (*types.Block, error)
	
	// SaveTransaction saves a transaction
	SaveTransaction(tx *types.Transaction) error
	
	// GetTransaction retrieves a transaction by ID
	GetTransaction(id string) (*types.Transaction, error)
	
	// GetSize returns the total storage size in bytes
	GetSize() (int64, error)
	
	// Close closes the storage manager
	Close() error
}

// FileStorageManager implements storage using the file system
type FileStorageManager struct {
	dataDir    string
	blocksDir  string
	txDir      string
	logger     *zap.Logger
	mu         sync.RWMutex
	blockCache map[uint64]*types.Block
	txCache    map[string]*types.Transaction
}

// NewManager creates a new storage manager
func NewManager(dataDir string, logger *zap.Logger) (Manager, error) {
	// Create directories
	blocksDir := filepath.Join(dataDir, "blocks")
	txDir := filepath.Join(dataDir, "transactions")
	
	if err := os.MkdirAll(blocksDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create blocks directory: %w", err)
	}
	
	if err := os.MkdirAll(txDir, 0755); err != nil {
		return nil, fmt.Errorf("failed to create transactions directory: %w", err)
	}
	
	return &FileStorageManager{
		dataDir:    dataDir,
		blocksDir:  blocksDir,
		txDir:      txDir,
		logger:     logger,
		blockCache: make(map[uint64]*types.Block),
		txCache:    make(map[string]*types.Transaction),
	}, nil
}

// SaveBlock saves a block to storage
func (fsm *FileStorageManager) SaveBlock(block *types.Block) error {
	fsm.mu.Lock()
	defer fsm.mu.Unlock()
	
	// Marshal block to JSON
	data, err := json.MarshalIndent(block, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal block: %w", err)
	}
	
	// Save to file
	filename := filepath.Join(fsm.blocksDir, fmt.Sprintf("block_%06d.json", block.Index))
	if err := ioutil.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write block file: %w", err)
	}
	
	// Update cache
	fsm.blockCache[block.Index] = block
	
	fsm.logger.Debug("Block saved to storage", 
		zap.Uint64("index", block.Index),
		zap.String("hash", block.Hash))
	
	return nil
}

// LoadBlocks loads all blocks from storage
func (fsm *FileStorageManager) LoadBlocks() ([]*types.Block, error) {
	fsm.mu.Lock()
	defer fsm.mu.Unlock()
	
	// Read all block files
	files, err := ioutil.ReadDir(fsm.blocksDir)
	if err != nil {
		return nil, fmt.Errorf("failed to read blocks directory: %w", err)
	}
	
	blocks := make([]*types.Block, 0)
	
	for _, file := range files {
		if filepath.Ext(file.Name()) != ".json" {
			continue
		}
		
		// Read file
		data, err := ioutil.ReadFile(filepath.Join(fsm.blocksDir, file.Name()))
		if err != nil {
			fsm.logger.Warn("Failed to read block file", 
				zap.String("file", file.Name()),
				zap.Error(err))
			continue
		}
		
		// Unmarshal block
		var block types.Block
		if err := json.Unmarshal(data, &block); err != nil {
			fsm.logger.Warn("Failed to unmarshal block", 
				zap.String("file", file.Name()),
				zap.Error(err))
			continue
		}
		
		blocks = append(blocks, &block)
		fsm.blockCache[block.Index] = &block
	}
	
	// Sort blocks by index
	for i := 0; i < len(blocks)-1; i++ {
		for j := i + 1; j < len(blocks); j++ {
			if blocks[i].Index > blocks[j].Index {
				blocks[i], blocks[j] = blocks[j], blocks[i]
			}
		}
	}
	
	fsm.logger.Info("Blocks loaded from storage", zap.Int("count", len(blocks)))
	return blocks, nil
}

// GetBlock retrieves a specific block by index
func (fsm *FileStorageManager) GetBlock(index uint64) (*types.Block, error) {
	fsm.mu.RLock()
	
	// Check cache first
	if block, exists := fsm.blockCache[index]; exists {
		fsm.mu.RUnlock()
		return block, nil
	}
	fsm.mu.RUnlock()
	
	// Load from file
	filename := filepath.Join(fsm.blocksDir, fmt.Sprintf("block_%06d.json", index))
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("block %d not found", index)
		}
		return nil, fmt.Errorf("failed to read block file: %w", err)
	}
	
	var block types.Block
	if err := json.Unmarshal(data, &block); err != nil {
		return nil, fmt.Errorf("failed to unmarshal block: %w", err)
	}
	
	// Update cache
	fsm.mu.Lock()
	fsm.blockCache[index] = &block
	fsm.mu.Unlock()
	
	return &block, nil
}

// SaveTransaction saves a transaction
func (fsm *FileStorageManager) SaveTransaction(tx *types.Transaction) error {
	fsm.mu.Lock()
	defer fsm.mu.Unlock()
	
	// Marshal transaction to JSON
	data, err := json.MarshalIndent(tx, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal transaction: %w", err)
	}
	
	// Save to file
	filename := filepath.Join(fsm.txDir, fmt.Sprintf("tx_%s.json", tx.ID))
	if err := ioutil.WriteFile(filename, data, 0644); err != nil {
		return fmt.Errorf("failed to write transaction file: %w", err)
	}
	
	// Update cache
	fsm.txCache[tx.ID] = tx
	
	return nil
}

// GetTransaction retrieves a transaction by ID
func (fsm *FileStorageManager) GetTransaction(id string) (*types.Transaction, error) {
	fsm.mu.RLock()
	
	// Check cache first
	if tx, exists := fsm.txCache[id]; exists {
		fsm.mu.RUnlock()
		return tx, nil
	}
	fsm.mu.RUnlock()
	
	// Load from file
	filename := filepath.Join(fsm.txDir, fmt.Sprintf("tx_%s.json", id))
	data, err := ioutil.ReadFile(filename)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("transaction %s not found", id)
		}
		return nil, fmt.Errorf("failed to read transaction file: %w", err)
	}
	
	var tx types.Transaction
	if err := json.Unmarshal(data, &tx); err != nil {
		return nil, fmt.Errorf("failed to unmarshal transaction: %w", err)
	}
	
	// Update cache
	fsm.mu.Lock()
	fsm.txCache[id] = &tx
	fsm.mu.Unlock()
	
	return &tx, nil
}

// GetSize returns the total storage size in bytes
func (fsm *FileStorageManager) GetSize() (int64, error) {
	var size int64
	
	err := filepath.Walk(fsm.dataDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if !info.IsDir() {
			size += info.Size()
		}
		return nil
	})
	
	if err != nil {
		return 0, fmt.Errorf("failed to calculate storage size: %w", err)
	}
	
	return size, nil
}

// Close closes the storage manager
func (fsm *FileStorageManager) Close() error {
	fsm.mu.Lock()
	defer fsm.mu.Unlock()
	
	// Clear caches
	fsm.blockCache = make(map[uint64]*types.Block)
	fsm.txCache = make(map[string]*types.Transaction)
	
	fsm.logger.Info("Storage manager closed")
	return nil
} 