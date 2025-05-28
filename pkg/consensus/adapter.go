// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package consensus

import (
	"context"
	"fmt"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

// VertexAdapter adapts the base avalanche.Vertex to ParallelVertex
type VertexAdapter struct {
	avalanche.Vertex
	id       ids.ID
	priority uint64
}

// NewVertexAdapter creates a new adapter for avalanche.Vertex
func NewVertexAdapter(vertex avalanche.Vertex, priority uint64) (*VertexAdapter, error) {
	if vertex == nil {
		return nil, fmt.Errorf("cannot adapt nil vertex")
	}
	
	// Create a vertex ID from the vertex bytes
	id := ids.ID(ids.NewID(vertex.Bytes()))
	
	return &VertexAdapter{
		Vertex:   vertex,
		id:       id,
		priority: priority,
	}, nil
}

// ID returns the vertex ID
func (va *VertexAdapter) ID() ids.ID {
	return va.id
}

// GetProcessingPriority returns the vertex processing priority
func (va *VertexAdapter) GetProcessingPriority() uint64 {
	return va.priority
}

// ParallelVertex is an extension of the avalanche.Vertex interface
// that adds parallel processing capabilities
type ParallelVertex interface {
	avalanche.Vertex

	// GetProcessingPriority returns the priority for processing this vertex
	GetProcessingPriority() uint64
}

// ParallelEngine implements the avalanche consensus engine with
// parallel processing capabilities
type ParallelEngine struct {
	lock        sync.RWMutex
	logger      logging.Logger
	running     bool
	vertices    map[ids.ID]ParallelVertex
	edgeMap     map[ids.ID][]ids.ID   // Map from vertex ID to parent IDs
	conflicts   map[ids.ID]ids.Set    // Map of conflicting transaction IDs
	maxWorkers  int                   // Maximum number of parallel workers
	txsAccepted map[ids.ID]struct{}   // Set of accepted transaction IDs
	txsRejected map[ids.ID]struct{}   // Set of rejected transaction IDs
}

// NewParallelEngine creates a new parallel consensus engine
func NewParallelEngine(logger logging.Logger, maxWorkers int) *ParallelEngine {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}

	return &ParallelEngine{
		logger:      logger,
		running:     false,
		vertices:    make(map[ids.ID]ParallelVertex),
		edgeMap:     make(map[ids.ID][]ids.ID),
		conflicts:   make(map[ids.ID]ids.Set),
		maxWorkers:  maxWorkers,
		txsAccepted: make(map[ids.ID]struct{}),
		txsRejected: make(map[ids.ID]struct{}),
	}
}

// ProcessVertex processes a single vertex through the consensus engine
func (e *ParallelEngine) ProcessVertex(ctx context.Context, vertex ParallelVertex) error {
	e.lock.Lock()
	defer e.lock.Unlock()

	vertexID := vertex.ID()

	// Check if already processed
	if _, exists := e.vertices[vertexID]; exists {
		return nil
	}

	// Add to vertices map
	e.vertices[vertexID] = vertex

	// Store parent relationships
	parents, err := vertex.Parents()
	if err != nil {
		return err
	}
	parentIDs := make([]ids.ID, 0, len(parents))
	for _, parent := range parents {
		parentIDs = append(parentIDs, parent.ID())
	}
	e.edgeMap[vertexID] = parentIDs

	// Verify the vertex
	if err := vertex.Verify(ctx); err != nil {
		// If verification fails, reject the vertex
		if err := vertex.Reject(ctx); err != nil {
			return err
		}
		return nil
	}

	// Get transactions from vertex
	txs, err := vertex.Txs(ctx)
	if err != nil {
		return err
	}

	// Check for transaction conflicts
	for _, tx := range txs {
		txID := tx.ID()

		// Skip if already accepted or rejected
		if _, accepted := e.txsAccepted[txID]; accepted {
			continue
		}
		if _, rejected := e.txsRejected[txID]; rejected {
			continue
		}

		// Check for conflicts with this transaction
		inputs, err := tx.InputIDs()
		if err != nil {
			return err
		}

		// For each input, check for conflicts
		for _, inputID := range inputs {
			if _, exists := e.conflicts[inputID]; !exists {
				e.conflicts[inputID] = ids.NewSet(0)
			}
			e.conflicts[inputID].Add(txID)
		}
	}

	return nil
}

// BatchProcessVertices processes multiple vertices in parallel
func (e *ParallelEngine) BatchProcessVertices(ctx context.Context, vertices []avalanche.Vertex) error {
	// Convert to ParallelVertex
	parallelVertices := make([]ParallelVertex, 0, len(vertices))
	for _, vertex := range vertices {
		if pv, ok := vertex.(ParallelVertex); ok {
			parallelVertices = append(parallelVertices, pv)
		} else {
			e.logger.Warn("Vertex does not implement ParallelVertex interface: %s", vertex.ID())
		}
	}

	// Sort vertices by priority
	sortVerticesByPriority(parallelVertices)

	// Process vertices in parallel
	var wg sync.WaitGroup
	errs := make(chan error, len(parallelVertices))
	semaphore := make(chan struct{}, e.maxWorkers)

	for _, vertex := range parallelVertices {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire semaphore

		go func(v ParallelVertex) {
			defer func() {
				<-semaphore // Release semaphore
				wg.Done()
			}()

			if err := e.ProcessVertex(ctx, v); err != nil {
				errs <- err
			}
		}(vertex)
	}

	// Wait for all goroutines to finish
	wg.Wait()
	close(errs)

	// Return first error if any
	for err := range errs {
		if err != nil {
			return err
		}
	}

	return nil
}

// DecideTxs decides which transactions to accept/reject based on DAG traversal
func (e *ParallelEngine) DecideTxs(ctx context.Context) error {
	e.lock.Lock()
	defer e.lock.Unlock()

	// Start from the frontier (vertices with no children)
	frontier := e.getFrontier()

	// Process vertices in topological order
	for len(frontier) > 0 {
		// Process current frontier
		for _, vertexID := range frontier {
			vertex := e.vertices[vertexID]

			// Process transactions in the vertex
			txs, err := vertex.Txs(ctx)
			if err != nil {
				return err
			}

			// For each transaction, decide if it can be accepted
			for _, tx := range txs {
				txID := tx.ID()

				// Skip if already decided
				if _, accepted := e.txsAccepted[txID]; accepted {
					continue
				}
				if _, rejected := e.txsRejected[txID]; rejected {
					continue
				}

				// Check if all conflicts are rejected, if so we can accept this tx
				canAccept := true
				inputs, err := tx.InputIDs()
				if err != nil {
					return err
				}

				for _, inputID := range inputs {
					if conflicts, exists := e.conflicts[inputID]; exists {
						for conflictTxID := range conflicts {
							if conflictTxID.Equals(txID) {
								continue
							}
							if _, rejected := e.txsRejected[conflictTxID]; !rejected {
								// If a conflicting tx is not rejected, we can't accept this one yet
								canAccept = false
								break
							}
						}
					}
					if !canAccept {
						break
					}
				}

				if canAccept {
					// Accept this transaction
					if err := tx.Accept(ctx); err != nil {
						return err
					}
					e.txsAccepted[txID] = struct{}{}

					// Reject all conflicting transactions
					for _, inputID := range inputs {
						if conflicts, exists := e.conflicts[inputID]; exists {
							for conflictTxID := range conflicts {
								if conflictTxID.Equals(txID) {
									continue
								}
								// Get the conflicting transaction and reject it
								for _, v := range e.vertices {
									vtxTxs, _ := v.Txs(ctx)
									for _, vtxTx := range vtxTxs {
										if vtxTx.ID().Equals(conflictTxID) {
											if err := vtxTx.Reject(ctx); err != nil {
												return err
											}
											e.txsRejected[conflictTxID] = struct{}{}
										}
									}
								}
							}
						}
					}
				}
			}

			// Check if all transactions in vertex are decided
			allDecided := true
			for _, tx := range txs {
				txID := tx.ID()
				if _, accepted := e.txsAccepted[txID]; accepted {
					continue
				}
				if _, rejected := e.txsRejected[txID]; rejected {
					continue
				}
				allDecided = false
				break
			}

			if allDecided {
				// If all transactions are decided, we can accept the vertex
				if err := vertex.Accept(ctx); err != nil {
					return err
				}
			}
		}

		// Update frontier
		frontier = e.getFrontier()
	}

	return nil
}

// getFrontier returns vertices with no children (frontier of the DAG)
func (e *ParallelEngine) getFrontier() []ids.ID {
	// Find vertices that are not parents of any other vertex
	isParent := make(map[ids.ID]bool)
	for _, parents := range e.edgeMap {
		for _, parentID := range parents {
			isParent[parentID] = true
		}
	}

	// Vertices in our set that are not parents are frontier vertices
	frontier := make([]ids.ID, 0)
	for vertexID := range e.vertices {
		if !isParent[vertexID] {
			frontier = append(frontier, vertexID)
		}
	}

	return frontier
}

// sortVerticesByPriority sorts vertices by their processing priority
func sortVerticesByPriority(vertices []ParallelVertex) {
	// Simple bubble sort for demonstration
	for i := 0; i < len(vertices); i++ {
		for j := 0; j < len(vertices)-i-1; j++ {
			if vertices[j].GetProcessingPriority() < vertices[j+1].GetProcessingPriority() {
				vertices[j], vertices[j+1] = vertices[j+1], vertices[j]
			}
		}
	}
}

// RunConsensus runs the consensus engine continuously
func (e *ParallelEngine) RunConsensus(ctx context.Context, interval time.Duration) {
	e.lock.Lock()
	if e.running {
		e.lock.Unlock()
		return
	}
	e.running = true
	e.lock.Unlock()

	ticker := time.NewTicker(interval)
	defer ticker.Stop()

	for {
		select {
		case <-ctx.Done():
			e.lock.Lock()
			e.running = false
			e.lock.Unlock()
			return
		case <-ticker.C:
			if err := e.DecideTxs(ctx); err != nil {
				e.logger.Error("Error deciding transactions: %s", err)
			}
		}
	}
} 