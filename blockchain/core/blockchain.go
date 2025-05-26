package core

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"sync"
	"time"

	"github.com/ava-labs/avalanche-parallel/blockchain/consensus"
	"github.com/ava-labs/avalanche-parallel/blockchain/network"
	"github.com/ava-labs/avalanche-parallel/blockchain/storage"
	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	"github.com/gorilla/mux"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"go.uber.org/zap"
	"net/http"
)





// Blockchain represents the main blockchain structure
type Blockchain struct {
	config          *types.BlockchainConfig
	storage         storage.Manager
	consensus       consensus.Engine
	network         network.Manager
	logger          *zap.Logger
	
	// Chain state
	blocks          []*types.Block
	currentBlock    *types.Block
	pendingTxs      []types.Transaction
	
	// Synchronization
	mu              sync.RWMutex
	
	// Metrics
	metrics         *BlockchainMetrics
	
	// API server
	apiServer       *http.Server
	
	// Context for lifecycle management
	ctx             context.Context
	cancel          context.CancelFunc
}

// BlockchainMetrics holds Prometheus metrics
type BlockchainMetrics struct {
	BlocksCreated      prometheus.Counter
	TransactionsAdded  prometheus.Counter
	ChainHeight        prometheus.Gauge
	ConsensusLatency   prometheus.Histogram
	NetworkPeers       prometheus.Gauge
	StorageSize        prometheus.Gauge
}

// NewBlockchain creates a new blockchain instance
func NewBlockchain(config *types.BlockchainConfig, storage storage.Manager, consensus consensus.Engine, network network.Manager, logger *zap.Logger) (*Blockchain, error) {
	bc := &Blockchain{
		config:      config,
		storage:     storage,
		consensus:   consensus,
		network:     network,
		logger:      logger,
		blocks:      make([]*types.Block, 0),
		pendingTxs:  make([]types.Transaction, 0),
	}
	
	// Initialize metrics
	bc.metrics = &BlockchainMetrics{
		BlocksCreated: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "blockchain_blocks_created_total",
			Help: "Total number of blocks created",
		}),
		TransactionsAdded: prometheus.NewCounter(prometheus.CounterOpts{
			Name: "blockchain_transactions_added_total",
			Help: "Total number of transactions added",
		}),
		ChainHeight: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "blockchain_chain_height",
			Help: "Current blockchain height",
		}),
		ConsensusLatency: prometheus.NewHistogram(prometheus.HistogramOpts{
			Name:    "blockchain_consensus_latency_seconds",
			Help:    "Consensus latency in seconds",
			Buckets: prometheus.DefBuckets,
		}),
		NetworkPeers: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "blockchain_network_peers",
			Help: "Number of connected network peers",
		}),
		StorageSize: prometheus.NewGauge(prometheus.GaugeOpts{
			Name: "blockchain_storage_size_bytes",
			Help: "Storage size in bytes",
		}),
	}
	
	// Register metrics
	prometheus.MustRegister(bc.metrics.BlocksCreated)
	prometheus.MustRegister(bc.metrics.TransactionsAdded)
	prometheus.MustRegister(bc.metrics.ChainHeight)
	prometheus.MustRegister(bc.metrics.ConsensusLatency)
	prometheus.MustRegister(bc.metrics.NetworkPeers)
	prometheus.MustRegister(bc.metrics.StorageSize)
	
	// Load existing blockchain from storage
	if err := bc.loadFromStorage(); err != nil {
		logger.Warn("Failed to load blockchain from storage, creating genesis block", zap.Error(err))
		if err := bc.createGenesisBlock(); err != nil {
			return nil, fmt.Errorf("failed to create genesis block: %w", err)
		}
	}
	
	return bc, nil
}

// Start starts the blockchain
func (bc *Blockchain) Start(ctx context.Context) error {
	bc.ctx, bc.cancel = context.WithCancel(ctx)
	
	// Start consensus engine
	if err := bc.consensus.Start(bc.ctx); err != nil {
		return fmt.Errorf("failed to start consensus engine: %w", err)
	}
	
	// Start network manager
	if err := bc.network.Start(bc.ctx); err != nil {
		return fmt.Errorf("failed to start network manager: %w", err)
	}
	
	// Start API server
	if err := bc.startAPIServer(); err != nil {
		return fmt.Errorf("failed to start API server: %w", err)
	}
	
	// Start block production loop
	go bc.blockProductionLoop()
	
	// Start metrics update loop
	go bc.metricsUpdateLoop()
	
	bc.logger.Info("Blockchain started successfully")
	return nil
}

// Stop stops the blockchain
func (bc *Blockchain) Stop(ctx context.Context) error {
	bc.logger.Info("Stopping blockchain...")
	
	// Cancel context
	if bc.cancel != nil {
		bc.cancel()
	}
	
	// Stop API server
	if bc.apiServer != nil {
		if err := bc.apiServer.Shutdown(ctx); err != nil {
			bc.logger.Error("Failed to shutdown API server", zap.Error(err))
		}
	}
	
	// Stop consensus engine
	if err := bc.consensus.Stop(ctx); err != nil {
		bc.logger.Error("Failed to stop consensus engine", zap.Error(err))
	}
	
	// Stop network manager
	if err := bc.network.Stop(ctx); err != nil {
		bc.logger.Error("Failed to stop network manager", zap.Error(err))
	}
	
	// Save current state
	if err := bc.saveToStorage(); err != nil {
		bc.logger.Error("Failed to save blockchain state", zap.Error(err))
	}
	
	bc.logger.Info("Blockchain stopped")
	return nil
}

// AddTransaction adds a new transaction to the pending pool
func (bc *Blockchain) AddTransaction(tx types.Transaction) error {
	bc.mu.Lock()
	defer bc.mu.Unlock()
	
	// Validate transaction
	if err := bc.validateTransaction(tx); err != nil {
		return fmt.Errorf("invalid transaction: %w", err)
	}
	
	// Add to pending transactions
	bc.pendingTxs = append(bc.pendingTxs, tx)
	bc.metrics.TransactionsAdded.Inc()
	
	bc.logger.Info("Transaction added to pending pool", 
		zap.String("tx_id", tx.ID),
		zap.String("from", tx.From),
		zap.String("to", tx.To),
		zap.Float64("amount", tx.Amount))
	
	return nil
}

// GetBlock returns a block by index
func (bc *Blockchain) GetBlock(index uint64) (*types.Block, error) {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	if index >= uint64(len(bc.blocks)) {
		return nil, fmt.Errorf("block not found: index %d", index)
	}
	
	return bc.blocks[index], nil
}

// GetLatestBlock returns the latest block
func (bc *Blockchain) GetLatestBlock() *types.Block {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	if len(bc.blocks) == 0 {
		return nil
	}
	
	return bc.blocks[len(bc.blocks)-1]
}

// GetChainHeight returns the current chain height
func (bc *Blockchain) GetChainHeight() uint64 {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	return uint64(len(bc.blocks))
}

// createGenesisBlock creates the genesis block
func (bc *Blockchain) createGenesisBlock() error {
	genesis := &types.Block{
		Index:     0,
		Timestamp: time.Now(),
		PrevHash:  "0",
		Metadata: map[string]string{
			"network": bc.config.NetworkMode,
			"version": "1.0.0",
		},
	}
	
	genesis.Hash = bc.calculateBlockHash(genesis)
	
	bc.blocks = append(bc.blocks, genesis)
	bc.currentBlock = genesis
	bc.metrics.ChainHeight.Set(1)
	
	// Save genesis block
	if err := bc.storage.SaveBlock(genesis); err != nil {
		return fmt.Errorf("failed to save genesis block: %w", err)
	}
	
	bc.logger.Info("Genesis block created", zap.String("hash", genesis.Hash))
	return nil
}

// calculateBlockHash calculates the hash of a block
func (bc *Blockchain) calculateBlockHash(block *types.Block) string {
	data := fmt.Sprintf("%d%s%s%s%d",
		block.Index,
		block.Timestamp.Format(time.RFC3339),
		block.PrevHash,
		bc.hashTransactions(block.Transactions),
		block.Nonce)
	
	hash := sha256.Sum256([]byte(data))
	return hex.EncodeToString(hash[:])
}

// hashTransactions creates a hash of all transactions
func (bc *Blockchain) hashTransactions(txs []types.Transaction) string {
	var txHashes []string
	for _, tx := range txs {
		txData := fmt.Sprintf("%s%s%s%f%f%s",
			tx.ID,
			tx.From,
			tx.To,
			tx.Amount,
			tx.Fee,
			tx.Timestamp.Format(time.RFC3339))
		hash := sha256.Sum256([]byte(txData))
		txHashes = append(txHashes, hex.EncodeToString(hash[:]))
	}
	
	combinedData := ""
	for _, h := range txHashes {
		combinedData += h
	}
	
	finalHash := sha256.Sum256([]byte(combinedData))
	return hex.EncodeToString(finalHash[:])
}

// validateTransaction validates a transaction
func (bc *Blockchain) validateTransaction(tx types.Transaction) error {
	if tx.ID == "" {
		return fmt.Errorf("transaction ID is empty")
	}
	if tx.From == "" {
		return fmt.Errorf("transaction from address is empty")
	}
	if tx.To == "" {
		return fmt.Errorf("transaction to address is empty")
	}
	if tx.Amount <= 0 {
		return fmt.Errorf("transaction amount must be positive")
	}
	if tx.Fee < 0 {
		return fmt.Errorf("transaction fee cannot be negative")
	}
	
	// Additional validation can be added here (e.g., signature verification)
	
	return nil
}

// blockProductionLoop continuously produces new blocks
func (bc *Blockchain) blockProductionLoop() {
	ticker := time.NewTicker(10 * time.Second) // Produce block every 10 seconds
	defer ticker.Stop()
	
	for {
		select {
		case <-bc.ctx.Done():
			return
		case <-ticker.C:
			if err := bc.produceBlock(); err != nil {
				bc.logger.Error("Failed to produce block", zap.Error(err))
			}
		}
	}
}

// produceBlock produces a new block
func (bc *Blockchain) produceBlock() error {
	bc.mu.Lock()
	defer bc.mu.Unlock()
	
	// Check if there are pending transactions
	if len(bc.pendingTxs) == 0 {
		return nil
	}
	
	// Create new block
	latestBlock := bc.blocks[len(bc.blocks)-1]
	newBlock := &types.Block{
		Index:        latestBlock.Index + 1,
		Timestamp:    time.Now(),
		Transactions: bc.pendingTxs,
		PrevHash:     latestBlock.Hash,
		Validator:    bc.config.ValidatorKey, // Simplified, should use actual validator ID
		Metadata: map[string]string{
			"consensus_mode": bc.config.ConsensusMode,
		},
	}
	
	// Run consensus
	start := time.Now()
	consensusResult, err := bc.consensus.ProposeBlock(newBlock)
	if err != nil {
		return fmt.Errorf("consensus failed: %w", err)
	}
	bc.metrics.ConsensusLatency.Observe(time.Since(start).Seconds())
	
	if !consensusResult.Accepted {
		bc.logger.Info("Block rejected by consensus", zap.Uint64("index", newBlock.Index))
		return nil
	}
	
	// Calculate block hash
	newBlock.Hash = bc.calculateBlockHash(newBlock)
	
	// Add block to chain
	bc.blocks = append(bc.blocks, newBlock)
	bc.currentBlock = newBlock
	bc.metrics.BlocksCreated.Inc()
	bc.metrics.ChainHeight.Set(float64(len(bc.blocks)))
	
	// Clear pending transactions
	bc.pendingTxs = make([]types.Transaction, 0)
	
	// Save block to storage
	if err := bc.storage.SaveBlock(newBlock); err != nil {
		bc.logger.Error("Failed to save block", zap.Error(err))
	}
	
	// Broadcast block to network
	if err := bc.network.BroadcastBlock(newBlock); err != nil {
		bc.logger.Error("Failed to broadcast block", zap.Error(err))
	}
	
	bc.logger.Info("New block produced", 
		zap.Uint64("index", newBlock.Index),
		zap.String("hash", newBlock.Hash),
		zap.Int("transactions", len(newBlock.Transactions)))
	
	return nil
}

// loadFromStorage loads the blockchain from storage
func (bc *Blockchain) loadFromStorage() error {
	blocks, err := bc.storage.LoadBlocks()
	if err != nil {
		return err
	}
	
	if len(blocks) == 0 {
		return fmt.Errorf("no blocks found in storage")
	}
	
	bc.blocks = blocks
	bc.currentBlock = blocks[len(blocks)-1]
	bc.metrics.ChainHeight.Set(float64(len(blocks)))
	
	bc.logger.Info("Blockchain loaded from storage", zap.Int("blocks", len(blocks)))
	return nil
}

// saveToStorage saves the blockchain to storage
func (bc *Blockchain) saveToStorage() error {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	for _, block := range bc.blocks {
		if err := bc.storage.SaveBlock(block); err != nil {
			return fmt.Errorf("failed to save block %d: %w", block.Index, err)
		}
	}
	
	return nil
}

// metricsUpdateLoop updates metrics periodically
func (bc *Blockchain) metricsUpdateLoop() {
	ticker := time.NewTicker(5 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-bc.ctx.Done():
			return
		case <-ticker.C:
			// Update network peers metric
			peerCount := bc.network.GetPeerCount()
			bc.metrics.NetworkPeers.Set(float64(peerCount))
			
			// Update storage size metric
			storageSize, _ := bc.storage.GetSize()
			bc.metrics.StorageSize.Set(float64(storageSize))
		}
	}
}

// startAPIServer starts the HTTP API server
func (bc *Blockchain) startAPIServer() error {
	router := mux.NewRouter()
	
	// Health check endpoint
	router.HandleFunc("/health", bc.healthHandler).Methods("GET")
	
	// Blockchain endpoints
	router.HandleFunc("/blocks", bc.getBlocksHandler).Methods("GET")
	router.HandleFunc("/blocks/{index}", bc.getBlockHandler).Methods("GET")
	router.HandleFunc("/transactions", bc.addTransactionHandler).Methods("POST")
	router.HandleFunc("/status", bc.getStatusHandler).Methods("GET")
	
	// Metrics endpoint
	router.Handle("/metrics", promhttp.Handler())
	
	bc.apiServer = &http.Server{
		Addr:    fmt.Sprintf(":%d", bc.config.APIPort),
		Handler: router,
	}
	
	go func() {
		bc.logger.Info("Starting API server", zap.Int("port", bc.config.APIPort))
		if err := bc.apiServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			bc.logger.Error("API server error", zap.Error(err))
		}
	}()
	
	return nil
}

// API Handlers

func (bc *Blockchain) healthHandler(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "healthy"})
}

func (bc *Blockchain) getBlocksHandler(w http.ResponseWriter, r *http.Request) {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(bc.blocks)
}

func (bc *Blockchain) getBlockHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	var index uint64
	fmt.Sscanf(vars["index"], "%d", &index)
	
	block, err := bc.GetBlock(index)
	if err != nil {
		w.WriteHeader(http.StatusNotFound)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(block)
}

func (bc *Blockchain) addTransactionHandler(w http.ResponseWriter, r *http.Request) {
	var tx types.Transaction
	if err := json.NewDecoder(r.Body).Decode(&tx); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": "invalid transaction data"})
		return
	}
	
	if err := bc.AddTransaction(tx); err != nil {
		w.WriteHeader(http.StatusBadRequest)
		json.NewEncoder(w).Encode(map[string]string{"error": err.Error()})
		return
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"status": "transaction added", "tx_id": tx.ID})
}

func (bc *Blockchain) getStatusHandler(w http.ResponseWriter, r *http.Request) {
	bc.mu.RLock()
	defer bc.mu.RUnlock()
	
	status := map[string]interface{}{
		"chain_height":     len(bc.blocks),
		"pending_txs":      len(bc.pendingTxs),
		"consensus_mode":   bc.config.ConsensusMode,
		"network_mode":     bc.config.NetworkMode,
		"peer_count":       bc.network.GetPeerCount(),
		"latest_block_hash": bc.currentBlock.Hash,
	}
	
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(status)
} 