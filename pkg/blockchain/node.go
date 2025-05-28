// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package blockchain

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
	"go.uber.org/zap"
)

const (
	// ConsensusInterval defines how often the consensus process runs
	ConsensusInterval = 1 * time.Second
	
	// DefaultAPIPort is the default port for the HTTP API
	DefaultAPIPort = 8545
)

// NodeConfig contains configuration for a blockchain node
type NodeConfig struct {
	MaxParallelism int    // Maximum number of parallel processors
	APIPort        int    // HTTP API port
}

// Node represents a blockchain node with HTTP API
type Node struct {
	lock       sync.RWMutex
	logger     logging.Logger
	blockchain *Blockchain
	server     *http.Server
	config     NodeConfig
	running    bool
	shutdownCtxCancel context.CancelFunc
}

// NewNode creates a new blockchain node
func NewNode(logger logging.Logger, config NodeConfig) (*Node, error) {
	// Create blockchain
	blockchain, err := NewBlockchain(logger, config.MaxParallelism)
	if err != nil {
		return nil, fmt.Errorf("failed to create blockchain: %w", err)
	}

	// Create node
	node := &Node{
		logger:     logger,
		blockchain: blockchain,
		config:     config,
		running:    false,
	}

	return node, nil
}

// Start starts the blockchain node and API server
func (n *Node) Start() error {
	n.lock.Lock()
	defer n.lock.Unlock()

	if n.running {
		return fmt.Errorf("node already running")
	}

	// Start blockchain consensus
	ctx, cancel := context.WithCancel(context.Background())
	go n.blockchain.RunConsensus(ctx, 500*time.Millisecond)
	n.shutdownCtxCancel = cancel  // Store the cancel function for later use

	// Setup HTTP API server
	mux := http.NewServeMux()
	mux.HandleFunc("/transaction/submit", n.handleSubmitTransaction)
	mux.HandleFunc("/transaction/get", n.handleGetTransaction)
	mux.HandleFunc("/block/create", n.handleCreateBlock)
	mux.HandleFunc("/block/get", n.handleGetBlock)
	mux.HandleFunc("/blockchain/height", n.handleGetBlockchainHeight)
	mux.HandleFunc("/blockchain/latest", n.handleGetLatestBlocks)

	// Create server
	n.server = &http.Server{
		Addr:    fmt.Sprintf(":%d", n.config.APIPort),
		Handler: mux,
	}

	// Start server in a goroutine
	go func() {
		if err := n.server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			n.logger.Error("HTTP server error", zap.Error(err))
		}
	}()

	n.running = true
	n.logger.Info("Blockchain node started", zap.Int("port", n.config.APIPort))
	return nil
}

// Stop stops the blockchain node and API server
func (n *Node) Stop() error {
	n.lock.Lock()
	defer n.lock.Unlock()

	if !n.running {
		return fmt.Errorf("node not running")
	}

	// Shutdown server
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	
	if err := n.server.Shutdown(ctx); err != nil {
		return fmt.Errorf("server shutdown error: %w", err)
	}

	n.running = false
	n.logger.Info("Blockchain node stopped")
	return nil
}

// handleSubmitTransaction handles transaction submission API
func (n *Node) handleSubmitTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		Sender    string `json:"sender"`
		Recipient string `json:"recipient"`
		Amount    uint64 `json:"amount"`
		Nonce     uint64 `json:"nonce"`
		Key       string `json:"key"` // Simplified key for signing
	}

	// Decode request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Create transaction
	tx, err := NewTransaction(req.Sender, req.Recipient, req.Amount, req.Nonce)
	if err != nil {
		http.Error(w, "Failed to create transaction: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Sign transaction
	if err := tx.SignTransaction([]byte(req.Key)); err != nil {
		http.Error(w, "Failed to sign transaction: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Add to blockchain
	if err := n.blockchain.AddTransaction(tx); err != nil {
		http.Error(w, "Failed to add transaction: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Return transaction ID
	response := struct {
		ID string `json:"id"`
	}{
		ID: tx.ID().String(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleGetTransaction handles transaction lookup API
func (n *Node) handleGetTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse transaction ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "Missing transaction ID", http.StatusBadRequest)
		return
	}

	id, err := ids.FromString(idStr)
	if err != nil {
		http.Error(w, "Invalid transaction ID: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Get transaction
	tx, err := n.blockchain.GetTransaction(id)
	if err != nil {
		http.Error(w, "Transaction not found: "+err.Error(), http.StatusNotFound)
		return
	}

	// Return transaction
	response := struct {
		ID        string `json:"id"`
		Sender    string `json:"sender"`
		Recipient string `json:"recipient"`
		Amount    uint64 `json:"amount"`
		Nonce     uint64 `json:"nonce"`
		Status    string `json:"status"`
	}{
		ID:        tx.ID().String(),
		Sender:    tx.Sender,
		Recipient: tx.Recipient,
		Amount:    tx.Amount,
		Nonce:     tx.Nonce,
		Status:    tx.Status().String(),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleCreateBlock handles block creation API
func (n *Node) handleCreateBlock(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req struct {
		ParentIDs []string `json:"parentIDs"`
		MaxTxs    int      `json:"maxTxs"`
	}

	// Decode request
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Convert parent IDs
	parentIDs := make([]ids.ID, 0, len(req.ParentIDs))
	for _, idStr := range req.ParentIDs {
		id, err := ids.FromString(idStr)
		if err != nil {
			http.Error(w, "Invalid parent ID: "+err.Error(), http.StatusBadRequest)
			return
		}
		parentIDs = append(parentIDs, id)
	}

	// Create block
	block, err := n.blockchain.CreateBlock(parentIDs, req.MaxTxs)
	if err != nil {
		http.Error(w, "Failed to create block: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Submit block
	if err := n.blockchain.SubmitBlock(block); err != nil {
		http.Error(w, "Failed to submit block: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Return block ID
	response := struct {
		ID     string   `json:"id"`
		Height uint64   `json:"height"`
		TxIDs  []string `json:"txIDs"`
	}{
		ID:     block.ID().String(),
		Height: block.Height_,
	}

	// Convert transaction IDs to strings
	txIDs := make([]string, 0, len(block.Transactions))
	for _, tx := range block.Transactions {
		txIDs = append(txIDs, tx.ID().String())
	}
	response.TxIDs = txIDs

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleGetBlock handles block lookup API
func (n *Node) handleGetBlock(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Parse block ID
	idStr := r.URL.Query().Get("id")
	if idStr == "" {
		http.Error(w, "Missing block ID", http.StatusBadRequest)
		return
	}

	id, err := ids.FromString(idStr)
	if err != nil {
		http.Error(w, "Invalid block ID: "+err.Error(), http.StatusBadRequest)
		return
	}

	// Get block
	block, err := n.blockchain.GetBlock(id)
	if err != nil {
		http.Error(w, "Block not found: "+err.Error(), http.StatusNotFound)
		return
	}

	// Convert parent IDs to strings
	parentIDs := make([]string, 0, len(block.ParentIDs))
	for _, parentID := range block.ParentIDs {
		parentIDs = append(parentIDs, parentID.String())
	}

	// Convert transaction IDs to strings
	txIDs := make([]string, 0, len(block.Transactions))
	for _, tx := range block.Transactions {
		txIDs = append(txIDs, tx.ID().String())
	}

	// Return block
	response := struct {
		ID        string   `json:"id"`
		ParentIDs []string `json:"parentIDs"`
		Height    uint64   `json:"height"`
		Status    string   `json:"status"`
		TxIDs     []string `json:"txIDs"`
	}{
		ID:        block.ID().String(),
		ParentIDs: parentIDs,
		Height:    block.Height_,
		Status:    block.Status().String(),
		TxIDs:     txIDs,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleGetBlockchainHeight handles blockchain height API
func (n *Node) handleGetBlockchainHeight(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	height := n.blockchain.GetBlockchainHeight()

	// Return height
	response := struct {
		Height uint64 `json:"height"`
	}{
		Height: height,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// handleGetLatestBlocks handles latest blocks API
func (n *Node) handleGetLatestBlocks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	latestBlocks := n.blockchain.GetLatestBlocks()

	// Convert blocks to response format
	blocks := make([]struct {
		ID     string `json:"id"`
		Height uint64 `json:"height"`
	}, 0, len(latestBlocks))

	for _, block := range latestBlocks {
		blocks = append(blocks, struct {
			ID     string `json:"id"`
			Height uint64 `json:"height"`
		}{
			ID:     block.ID().String(),
			Height: block.Height_,
		})
	}

	// Return latest blocks
	response := struct {
		Blocks []struct {
			ID     string `json:"id"`
			Height uint64 `json:"height"`
		} `json:"blocks"`
	}{
		Blocks: blocks,
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
} 