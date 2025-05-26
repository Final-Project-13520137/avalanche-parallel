package network

import (
	"context"
	"encoding/json"
	"fmt"
	"net"
	"sync"
	"time"

	"github.com/ava-labs/avalanche-parallel/blockchain/consensus"
	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	"go.uber.org/zap"
)

// Manager defines the interface for network operations
type Manager interface {
	// Start starts the network manager
	Start(ctx context.Context) error
	
	// Stop stops the network manager
	Stop(ctx context.Context) error
	
	// BroadcastBlock broadcasts a block to the network
	BroadcastBlock(block *types.Block) error
	
	// BroadcastTransaction broadcasts a transaction to the network
	BroadcastTransaction(tx *types.Transaction) error
	
	// GetPeerCount returns the number of connected peers
	GetPeerCount() int
	
	// AddPeer adds a new peer
	AddPeer(address string) error
	
	// RemovePeer removes a peer
	RemovePeer(address string) error
}

// P2PManager implements the network manager using P2P networking
type P2PManager struct {
	config    *types.BlockchainConfig
	consensus consensus.Engine
	logger    *zap.Logger
	
	// Network state
	peers     map[string]*Peer
	listener  net.Listener
	mu        sync.RWMutex
	
	// Context for lifecycle
	ctx       context.Context
	cancel    context.CancelFunc
	wg        sync.WaitGroup
}

// Peer represents a network peer
type Peer struct {
	Address    string
	Connection net.Conn
	LastSeen   time.Time
	Active     bool
}

// Message represents a network message
type Message struct {
	Type      string          `json:"type"`
	Timestamp time.Time       `json:"timestamp"`
	Data      json.RawMessage `json:"data"`
}

// NewManager creates a new network manager
func NewManager(config *types.BlockchainConfig, consensus consensus.Engine, logger *zap.Logger) (Manager, error) {
	return &P2PManager{
		config:    config,
		consensus: consensus,
		logger:    logger,
		peers:     make(map[string]*Peer),
	}, nil
}

// Start starts the network manager
func (pm *P2PManager) Start(ctx context.Context) error {
	pm.ctx, pm.cancel = context.WithCancel(ctx)
	
	// Start listening for connections
	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", pm.config.P2PPort))
	if err != nil {
		return fmt.Errorf("failed to start listener: %w", err)
	}
	pm.listener = listener
	
	// Start accepting connections
	pm.wg.Add(1)
	go pm.acceptConnections()
	
	// Connect to bootstrap nodes
	for _, node := range pm.config.BootstrapNodes {
		if err := pm.AddPeer(node); err != nil {
			pm.logger.Warn("Failed to connect to bootstrap node", 
				zap.String("node", node),
				zap.Error(err))
		}
	}
	
	// Start peer maintenance
	pm.wg.Add(1)
	go pm.maintainPeers()
	
	pm.logger.Info("Network manager started", zap.Int("port", pm.config.P2PPort))
	return nil
}

// Stop stops the network manager
func (pm *P2PManager) Stop(ctx context.Context) error {
	pm.logger.Info("Stopping network manager")
	
	// Cancel context
	if pm.cancel != nil {
		pm.cancel()
	}
	
	// Close listener
	if pm.listener != nil {
		pm.listener.Close()
	}
	
	// Close all peer connections
	pm.mu.Lock()
	for _, peer := range pm.peers {
		if peer.Connection != nil {
			peer.Connection.Close()
		}
	}
	pm.peers = make(map[string]*Peer)
	pm.mu.Unlock()
	
	// Wait for goroutines to finish
	done := make(chan struct{})
	go func() {
		pm.wg.Wait()
		close(done)
	}()
	
	select {
	case <-done:
		// All goroutines finished
	case <-ctx.Done():
		// Context timeout
		pm.logger.Warn("Network manager stop timeout")
	}
	
	pm.logger.Info("Network manager stopped")
	return nil
}

// BroadcastBlock broadcasts a block to all peers
func (pm *P2PManager) BroadcastBlock(block *types.Block) error {
	data, err := json.Marshal(block)
	if err != nil {
		return fmt.Errorf("failed to marshal block: %w", err)
	}
	
	msg := Message{
		Type:      "block",
		Timestamp: time.Now(),
		Data:      data,
	}
	
	return pm.broadcast(msg)
}

// BroadcastTransaction broadcasts a transaction to all peers
func (pm *P2PManager) BroadcastTransaction(tx *types.Transaction) error {
	data, err := json.Marshal(tx)
	if err != nil {
		return fmt.Errorf("failed to marshal transaction: %w", err)
	}
	
	msg := Message{
		Type:      "transaction",
		Timestamp: time.Now(),
		Data:      data,
	}
	
	return pm.broadcast(msg)
}

// GetPeerCount returns the number of active peers
func (pm *P2PManager) GetPeerCount() int {
	pm.mu.RLock()
	defer pm.mu.RUnlock()
	
	count := 0
	for _, peer := range pm.peers {
		if peer.Active {
			count++
		}
	}
	
	return count
}

// AddPeer adds a new peer
func (pm *P2PManager) AddPeer(address string) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	
	// Check if peer already exists
	if _, exists := pm.peers[address]; exists {
		return fmt.Errorf("peer %s already exists", address)
	}
	
	// Connect to peer
	conn, err := net.DialTimeout("tcp", address, 10*time.Second)
	if err != nil {
		return fmt.Errorf("failed to connect to peer: %w", err)
	}
	
	peer := &Peer{
		Address:    address,
		Connection: conn,
		LastSeen:   time.Now(),
		Active:     true,
	}
	
	pm.peers[address] = peer
	
	// Start handling peer messages
	pm.wg.Add(1)
	go pm.handlePeer(peer)
	
	pm.logger.Info("Peer added", zap.String("address", address))
	return nil
}

// RemovePeer removes a peer
func (pm *P2PManager) RemovePeer(address string) error {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	
	peer, exists := pm.peers[address]
	if !exists {
		return fmt.Errorf("peer %s not found", address)
	}
	
	// Close connection
	if peer.Connection != nil {
		peer.Connection.Close()
	}
	
	delete(pm.peers, address)
	
	pm.logger.Info("Peer removed", zap.String("address", address))
	return nil
}

// acceptConnections accepts incoming peer connections
func (pm *P2PManager) acceptConnections() {
	defer pm.wg.Done()
	
	for {
		select {
		case <-pm.ctx.Done():
			return
		default:
			// Set accept timeout
			pm.listener.(*net.TCPListener).SetDeadline(time.Now().Add(1 * time.Second))
			
			conn, err := pm.listener.Accept()
			if err != nil {
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					continue
				}
				if pm.ctx.Err() != nil {
					return
				}
				pm.logger.Error("Failed to accept connection", zap.Error(err))
				continue
			}
			
			// Handle new connection
			pm.wg.Add(1)
			go pm.handleIncomingConnection(conn)
		}
	}
}

// handleIncomingConnection handles a new incoming connection
func (pm *P2PManager) handleIncomingConnection(conn net.Conn) {
	defer pm.wg.Done()
	
	address := conn.RemoteAddr().String()
	
	pm.mu.Lock()
	peer := &Peer{
		Address:    address,
		Connection: conn,
		LastSeen:   time.Now(),
		Active:     true,
	}
	pm.peers[address] = peer
	pm.mu.Unlock()
	
	pm.logger.Info("Incoming peer connection", zap.String("address", address))
	
	// Handle peer messages
	pm.handlePeer(peer)
}

// handlePeer handles messages from a peer
func (pm *P2PManager) handlePeer(peer *Peer) {
	defer pm.wg.Done()
	defer func() {
		pm.mu.Lock()
		peer.Active = false
		pm.mu.Unlock()
	}()
	
	decoder := json.NewDecoder(peer.Connection)
	
	for {
		select {
		case <-pm.ctx.Done():
			return
		default:
			// Set read timeout
			peer.Connection.SetReadDeadline(time.Now().Add(30 * time.Second))
			
			var msg Message
			if err := decoder.Decode(&msg); err != nil {
				if netErr, ok := err.(net.Error); ok && netErr.Timeout() {
					continue
				}
				if pm.ctx.Err() != nil {
					return
				}
				pm.logger.Debug("Peer disconnected", 
					zap.String("address", peer.Address),
					zap.Error(err))
				return
			}
			
			// Update last seen
			pm.mu.Lock()
			peer.LastSeen = time.Now()
			pm.mu.Unlock()
			
			// Handle message
			if err := pm.handleMessage(peer, msg); err != nil {
				pm.logger.Error("Failed to handle message", 
					zap.String("peer", peer.Address),
					zap.String("type", msg.Type),
					zap.Error(err))
			}
		}
	}
}

// handleMessage handles a message from a peer
func (pm *P2PManager) handleMessage(peer *Peer, msg Message) error {
	switch msg.Type {
	case "block":
		var block types.Block
		if err := json.Unmarshal(msg.Data, &block); err != nil {
			return fmt.Errorf("failed to unmarshal block: %w", err)
		}
		// Process block through consensus
		// This is simplified - in real implementation, would need more logic
		pm.logger.Info("Received block from peer", 
			zap.String("peer", peer.Address),
			zap.Uint64("index", block.Index))
		
	case "transaction":
		var tx types.Transaction
		if err := json.Unmarshal(msg.Data, &tx); err != nil {
			return fmt.Errorf("failed to unmarshal transaction: %w", err)
		}
		pm.logger.Info("Received transaction from peer", 
			zap.String("peer", peer.Address),
			zap.String("tx_id", tx.ID))
		
	case "ping":
		// Send pong
		pong := Message{
			Type:      "pong",
			Timestamp: time.Now(),
		}
		if err := pm.sendMessage(peer, pong); err != nil {
			return fmt.Errorf("failed to send pong: %w", err)
		}
		
	case "pong":
		// Update peer status
		pm.logger.Debug("Received pong from peer", zap.String("peer", peer.Address))
		
	default:
		pm.logger.Warn("Unknown message type", 
			zap.String("type", msg.Type),
			zap.String("peer", peer.Address))
	}
	
	return nil
}

// broadcast sends a message to all active peers
func (pm *P2PManager) broadcast(msg Message) error {
	pm.mu.RLock()
	peers := make([]*Peer, 0)
	for _, peer := range pm.peers {
		if peer.Active {
			peers = append(peers, peer)
		}
	}
	pm.mu.RUnlock()
	
	var wg sync.WaitGroup
	errors := make(chan error, len(peers))
	
	for _, peer := range peers {
		wg.Add(1)
		go func(p *Peer) {
			defer wg.Done()
			if err := pm.sendMessage(p, msg); err != nil {
				errors <- fmt.Errorf("failed to send to %s: %w", p.Address, err)
			}
		}(peer)
	}
	
	wg.Wait()
	close(errors)
	
	// Collect errors
	var errs []error
	for err := range errors {
		errs = append(errs, err)
	}
	
	if len(errs) > 0 {
		pm.logger.Warn("Broadcast errors", zap.Int("count", len(errs)))
	}
	
	return nil
}

// sendMessage sends a message to a peer
func (pm *P2PManager) sendMessage(peer *Peer, msg Message) error {
	peer.Connection.SetWriteDeadline(time.Now().Add(10 * time.Second))
	
	encoder := json.NewEncoder(peer.Connection)
	if err := encoder.Encode(msg); err != nil {
		return fmt.Errorf("failed to encode message: %w", err)
	}
	
	return nil
}

// maintainPeers periodically checks peer health
func (pm *P2PManager) maintainPeers() {
	defer pm.wg.Done()
	
	ticker := time.NewTicker(30 * time.Second)
	defer ticker.Stop()
	
	for {
		select {
		case <-pm.ctx.Done():
			return
		case <-ticker.C:
			pm.checkPeerHealth()
		}
	}
}

// checkPeerHealth checks the health of all peers
func (pm *P2PManager) checkPeerHealth() {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	
	for address, peer := range pm.peers {
		if !peer.Active {
			continue
		}
		
		// Check if peer is responsive
		if time.Since(peer.LastSeen) > 60*time.Second {
			pm.logger.Warn("Peer inactive, sending ping", zap.String("address", address))
			
			ping := Message{
				Type:      "ping",
				Timestamp: time.Now(),
			}
			
			if err := pm.sendMessage(peer, ping); err != nil {
				pm.logger.Warn("Failed to ping peer, marking as inactive", 
					zap.String("address", address),
					zap.Error(err))
				peer.Active = false
			}
		}
		
		// Remove peers that have been inactive for too long
		if time.Since(peer.LastSeen) > 5*time.Minute {
			pm.logger.Info("Removing inactive peer", zap.String("address", address))
			if peer.Connection != nil {
				peer.Connection.Close()
			}
			delete(pm.peers, address)
		}
	}
} 