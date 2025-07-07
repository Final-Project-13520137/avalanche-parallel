// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package engine

import (
	"context"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/microservices/pkg/consensus/vertex"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow/consensus/avalanche"
	"github.com/ava-labs/avalanchego/utils/set"
	"go.uber.org/zap"
)

// Parallel implements the avalanche consensus engine with
// parallel processing capabilities
type Parallel struct {
	lock        sync.RWMutex
	logger      *zap.Logger
	running     bool
	vertices    map[ids.ID]vertex.Parallel
	edgeMap     map[ids.ID][]ids.ID         // Map from vertex ID to parent IDs
	conflicts   map[ids.ID]*set.Set[ids.ID] // Map of conflicting transaction IDs
	maxWorkers  int                         // Maximum number of parallel workers
	txsAccepted map[ids.ID]struct{}         // Set of accepted transaction IDs
	txsRejected map[ids.ID]struct{}         // Set of rejected transaction IDs
}

// New creates a new parallel consensus engine
func New(logger *zap.Logger, maxWorkers int) *Parallel {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}

	return &Parallel{
		logger:      logger,
		running:     false,
		vertices:    make(map[ids.ID]vertex.Parallel),
		edgeMap:     make(map[ids.ID][]ids.ID),
		conflicts:   make(map[ids.ID]*set.Set[ids.ID]),
		maxWorkers:  maxWorkers,
		txsAccepted: make(map[ids.ID]struct{}),
		txsRejected: make(map[ids.ID]struct{}),
	}
}

// ProcessVertex processes a single vertex through the consensus engine
func (e *Parallel) ProcessVertex(ctx context.Context, vertex vertex.Parallel) error {
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

	// Get transactions
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
		missingDeps, err := tx.MissingDependencies()
		if err != nil {
			return err
		}

		// For each missing dependency, check for conflicts
		for depID := range missingDeps {
			if _, exists := e.conflicts[depID]; !exists {
				newSet := set.Set[ids.ID]{}
				e.conflicts[depID] = &newSet
			}
			e.conflicts[depID].Add(txID)
		}
	}

	return nil
}

// BatchProcessVertices processes multiple vertices in parallel
func (e *Parallel) BatchProcessVertices(ctx context.Context, vertices []avalanche.Vertex) error {
	// Convert to ParallelVertex
	parallelVertices := make([]vertex.Parallel, 0, len(vertices))
	for _, v := range vertices {
		if pv, ok := v.(vertex.Parallel); ok {
			parallelVertices = append(parallelVertices, pv)
		} else {
			e.logger.Warn("Vertex does not implement ParallelVertex interface", zap.Stringer("vertexID", v.ID()))
		}
	}

	// Sort vertices by priority
	sortVerticesByPriority(parallelVertices)

	// Process vertices in parallel
	var wg sync.WaitGroup
	errs := make(chan error, len(parallelVertices))
	semaphore := make(chan struct{}, e.maxWorkers)

	for _, v := range parallelVertices {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire semaphore

		go func(v vertex.Parallel) {
			defer func() {
				<-semaphore // Release semaphore
				wg.Done()
			}()

			if err := e.ProcessVertex(ctx, v); err != nil {
				errs <- err
			}
		}(v)
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
func (e *Parallel) DecideTxs(ctx context.Context) error {
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
				missingDeps, err := tx.MissingDependencies()
				if err != nil {
					return err
				}

				for depID := range missingDeps {
					if conflicts, exists := e.conflicts[depID]; exists {
						for conflictTxID := range *conflicts {
							if conflictTxID == txID {
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
					for depID := range missingDeps {
						if conflicts, exists := e.conflicts[depID]; exists {
							for conflictTxID := range *conflicts {
								if conflictTxID == txID {
									continue
								}
								// Get the conflicting transaction and reject it
								for _, v := range e.vertices {
									vtxTxs, _ := v.Txs(ctx)
									for _, vtxTx := range vtxTxs {
										if vtxTx.ID() == conflictTxID {
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
func (e *Parallel) getFrontier() []ids.ID {
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
func sortVerticesByPriority(vertices []vertex.Parallel) {
	// Simple bubble sort for demonstration
	for i := 0; i < len(vertices); i++ {
		for j := i + 1; j < len(vertices); j++ {
			if vertices[i].GetProcessingPriority() < vertices[j].GetProcessingPriority() {
				vertices[i], vertices[j] = vertices[j], vertices[i]
			}
		}
	}
}

// RunConsensus runs the consensus engine continuously
func (e *Parallel) RunConsensus(ctx context.Context, interval time.Duration) {
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
				e.logger.Error("Error deciding transactions", zap.Error(err))
			}
		}
	}
}
