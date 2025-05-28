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

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

const (
	// ConsensusInterval defines how often the consensus process runs
	ConsensusInterval = 1 * time.Second
	
	// DefaultAPIPort is the default port for the HTTP API
	DefaultAPIPort = 8545
)

// Node represents a blockchain node with HTTP API
type Node struct {
	lock       sync.RWMutex
	logger     logging.Logger
	blockchain *Blockchain
	apiServer  *http.Server
	apiPort    int
	ctx        context.Context
	cancel     context.CancelFunc
}

// NodeConfig contains configuration for a node
type NodeConfig struct {
	MaxParallelism int
	APIPort        int
}

// NewNode creates a new blockchain node
func NewNode(logger logging.Logger, config NodeConfig) (*Node, error) {
	if config.MaxParallelism <= 0 {
		config.MaxParallelism = DefaultMaxParallelism
	}
	
	if config.APIPort <= 0 {
		config.APIPort = DefaultAPIPort
	}

	blockchain, err := NewBlockchain(logger, config.MaxParallelism)
	if err != nil {
		return nil, fmt.Errorf("failed to create blockchain: %w", err)
	}

	ctx, cancel := context.WithCancel(context.Background())

	node := &Node{
		logger:     logger,
		blockchain: blockchain,
		apiPort:    config.APIPort,
		ctx:        ctx,
		cancel:     cancel,
	}

	return node, nil
}

// Start starts the node and all its components
func (n *Node) Start() error {
	n.lock.Lock()
	defer n.lock.Unlock()

	// Start consensus process
	go n.blockchain.RunConsensus(n.ctx, ConsensusInterval)

	// Start API server
	if err := n.startAPI(); err != nil {
		return fmt.Errorf("failed to start API server: %w", err)
	}

	n.logger.Info("Node started successfully")
	return nil
}

// Stop stops the node and all its components
func (n *Node) Stop() error {
	n.lock.Lock()
	defer n.lock.Unlock()

	// Cancel context to stop consensus process
	n.cancel()

	// Stop API server
	if n.apiServer != nil {
		ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		if err := n.apiServer.Shutdown(ctx); err != nil {
			return fmt.Errorf("failed to stop API server: %w", err)
		}
	}

	n.logger.Info("Node stopped")
	return nil
}

// startAPI starts the HTTP API server
func (n *Node) startAPI() error {
	mux := http.NewServeMux()

	// API endpoints
	mux.HandleFunc("/info", n.handleGetInfo)
	mux.HandleFunc("/blocks", n.handleGetBlocks)
	mux.HandleFunc("/block", n.handleGetBlockByID)
	mux.HandleFunc("/transactions", n.handleGetTransactions)
	mux.HandleFunc("/transaction", n.handleGetTransactionByID)
	mux.HandleFunc("/submit-transaction", n.handleSubmitTransaction)
	mux.HandleFunc("/create-block", n.handleCreateBlock)

	addr := fmt.Sprintf(":%d", n.apiPort)
	n.apiServer = &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	go func() {
		n.logger.Info("API server listening on %s", addr)
		if err := n.apiServer.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			n.logger.Error("API server error: %s", err)
		}
	}()

	return nil
}

// handleGetInfo handles requests for blockchain info
func (n *Node) handleGetInfo(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	info := struct {
		Height          uint64 `json:"height"`
		LatestBlocksNum int    `json:"latestBlocksCount"`
	}{
		Height:          n.blockchain.GetBlockchainHeight(),
		LatestBlocksNum: len(n.blockchain.GetLatestBlocks()),
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(info)
}

// handleGetBlocks handles requests for blocks
func (n *Node) handleGetBlocks(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var blocks []*Block
	heightParam := r.URL.Query().Get("height")
	
	if heightParam != "" {
		var height uint64
		fmt.Sscanf(heightParam, "%d", &height)
		blocks = n.blockchain.GetBlocksByHeight(height)
	} else {
		blocks = n.blockchain.GetLatestBlocks()
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(blocks)
}

// handleGetBlockByID handles requests for a specific block
func (n *Node) handleGetBlockByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	idParam := r.URL.Query().Get("id")
	if idParam == "" {
		http.Error(w, "Missing block ID", http.StatusBadRequest)
		return
	}

	var id ids.ID
	if err := id.UnmarshalText([]byte(idParam)); err != nil {
		http.Error(w, "Invalid block ID", http.StatusBadRequest)
		return
	}

	block, err := n.blockchain.GetBlock(id)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error getting block: %s", err), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(block)
}

// handleGetTransactions handles requests for transactions
func (n *Node) handleGetTransactions(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// For simplicity, we'll just return transactions from the latest blocks
	latestBlocks := n.blockchain.GetLatestBlocks()
	
	var transactions []*Transaction
	for _, block := range latestBlocks {
		transactions = append(transactions, block.Transactions...)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(transactions)
}

// handleGetTransactionByID handles requests for a specific transaction
func (n *Node) handleGetTransactionByID(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	idParam := r.URL.Query().Get("id")
	if idParam == "" {
		http.Error(w, "Missing transaction ID", http.StatusBadRequest)
		return
	}

	var id ids.ID
	if err := id.UnmarshalText([]byte(idParam)); err != nil {
		http.Error(w, "Invalid transaction ID", http.StatusBadRequest)
		return
	}

	tx, err := n.blockchain.GetTransaction(id)
	if err != nil {
		http.Error(w, fmt.Sprintf("Error getting transaction: %s", err), http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tx)
}

// TransactionRequest represents a request to submit a transaction
type TransactionRequest struct {
	Sender    string `json:"sender"`
	Recipient string `json:"recipient"`
	Amount    uint64 `json:"amount"`
	Nonce     uint64 `json:"nonce"`
}

// handleSubmitTransaction handles transaction submission
func (n *Node) handleSubmitTransaction(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req TransactionRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	tx, err := NewTransaction(req.Sender, req.Recipient, req.Amount, req.Nonce)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create transaction: %s", err), http.StatusInternalServerError)
		return
	}

	// Sign the transaction (simplified)
	if err := tx.SignTransaction([]byte("dummy-private-key")); err != nil {
		http.Error(w, fmt.Sprintf("Failed to sign transaction: %s", err), http.StatusInternalServerError)
		return
	}

	if err := n.blockchain.AddTransaction(tx); err != nil {
		http.Error(w, fmt.Sprintf("Failed to add transaction: %s", err), http.StatusInternalServerError)
		return
	}

	response := struct {
		Success    bool   `json:"success"`
		TxID       string `json:"txId"`
		Message    string `json:"message"`
	}{
		Success:    true,
		TxID:       tx.ID().String(),
		Message:    "Transaction submitted successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
}

// BlockRequest represents a request to create a block
type BlockRequest struct {
	ParentIDs []string `json:"parentIds"`
	MaxTxs    int      `json:"maxTransactions"`
}

// handleCreateBlock handles block creation and submission
func (n *Node) handleCreateBlock(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req BlockRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "Invalid request body", http.StatusBadRequest)
		return
	}

	// Convert parent IDs
	parentIDs := make([]ids.ID, 0, len(req.ParentIDs))
	for _, idStr := range req.ParentIDs {
		var id ids.ID
		if err := id.UnmarshalText([]byte(idStr)); err != nil {
			http.Error(w, fmt.Sprintf("Invalid parent ID: %s", idStr), http.StatusBadRequest)
			return
		}
		parentIDs = append(parentIDs, id)
	}

	// Create and submit block
	block, err := n.blockchain.CreateBlock(parentIDs, req.MaxTxs)
	if err != nil {
		http.Error(w, fmt.Sprintf("Failed to create block: %s", err), http.StatusInternalServerError)
		return
	}

	if err := n.blockchain.SubmitBlock(block); err != nil {
		http.Error(w, fmt.Sprintf("Failed to submit block: %s", err), http.StatusInternalServerError)
		return
	}

	response := struct {
		Success    bool   `json:"success"`
		BlockID    string `json:"blockId"`
		Height     uint64 `json:"height"`
		TxCount    int    `json:"transactionCount"`
		Message    string `json:"message"`
	}{
		Success:    true,
		BlockID:    block.ID().String(),
		Height:     block.Height,
		TxCount:    len(block.Transactions),
		Message:    "Block created and submitted successfully",
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(response)
} 