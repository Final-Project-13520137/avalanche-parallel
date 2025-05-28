// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package consensus

import (
	"context"
	"errors"
	"fmt"
	"sync"
	"time"

	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/snow/consensus/avalanche"
	"github.com/ava-labs/avalanchego/snow/consensus/snowstorm"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
)

var (
	ErrUnknownVertex     = errors.New("unknown vertex")
	ErrInvalidDependency = errors.New("invalid dependency")
)

// ParallelVertex extends the functionality of the base Vertex
type ParallelVertex interface {
	avalanche.Vertex
	ID() ids.ID
	// GetProcessingPriority returns the priority for processing this vertex
	GetProcessingPriority() uint64
}

// VertexProcessor is the interface for parallel vertex processing
type VertexProcessor interface {
	// Process processes a vertex and its transactions
	Process(ctx context.Context, vertex ParallelVertex) error
	
	// ProcessBatch processes multiple vertices in parallel
	ProcessBatch(ctx context.Context, vertices []ParallelVertex) error
}

// DefaultVertexProcessor implements the VertexProcessor interface
type DefaultVertexProcessor struct {
	logger     logging.Logger
	maxWorkers int
}

// NewDefaultVertexProcessor creates a new DefaultVertexProcessor
func NewDefaultVertexProcessor(logger logging.Logger, maxWorkers int) *DefaultVertexProcessor {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}
	
	return &DefaultVertexProcessor{
		logger:     logger,
		maxWorkers: maxWorkers,
	}
}

// Process processes a vertex and its transactions
func (p *DefaultVertexProcessor) Process(ctx context.Context, vertex ParallelVertex) error {
	// Basic validation
	if err := vertex.Verify(ctx); err != nil {
		return err
	}
	
	// Get transactions
	txs, err := vertex.Txs(ctx)
	if err != nil {
		return err
	}
	
	// Process transactions sequentially
	for _, tx := range txs {
		if err := tx.Verify(ctx); err != nil {
			return err
		}
	}
	
	return nil
}

// ProcessBatch processes multiple vertices in parallel
func (p *DefaultVertexProcessor) ProcessBatch(ctx context.Context, vertices []ParallelVertex) error {
	var wg sync.WaitGroup
	errs := make(chan error, len(vertices))
	
	// Create a semaphore to limit concurrency
	semaphore := make(chan struct{}, p.maxWorkers)
	
	for _, vertex := range vertices {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire semaphore
		
		go func(v ParallelVertex) {
			defer func() {
				<-semaphore // Release semaphore
				wg.Done()
			}()
			
			if err := p.Process(ctx, v); err != nil {
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

// ParallelDAG represents a directed acyclic graph optimized for parallel processing
type ParallelDAG struct {
	lock       sync.RWMutex
	logger     logging.Logger
	vertices   map[ids.ID]ParallelVertex
	edges      map[ids.ID][]ids.ID  // Map from vertex ID to parent IDs
	reversedge map[ids.ID][]ids.ID  // Map from vertex ID to child IDs
	frontier   ids.Set              // Vertices with no children
	maxWorkers int
	processor  VertexProcessor
}

// NewParallelDAG creates a new parallel DAG
func NewParallelDAG(logger logging.Logger, maxWorkers int, processor VertexProcessor) *ParallelDAG {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}
	
	return &ParallelDAG{
		logger:     logger,
		vertices:   make(map[ids.ID]ParallelVertex),
		edges:      make(map[ids.ID][]ids.ID),
		reversedge: make(map[ids.ID][]ids.ID),
		frontier:   ids.NewSet(0),
		maxWorkers: maxWorkers,
		processor:  processor,
	}
}

// AddVertex adds a vertex to the DAG
func (dag *ParallelDAG) AddVertex(vertex ParallelVertex) error {
	dag.lock.Lock()
	defer dag.lock.Unlock()
	
	vertexID := vertex.ID()
	
	// Check if already exists
	if _, exists := dag.vertices[vertexID]; exists {
		return nil
	}
	
	// Add to vertices map
	dag.vertices[vertexID] = vertex
	
	// Get parents
	parents, err := vertex.Parents()
	if err != nil {
		return err
	}
	
	// Add edges
	parentIDs := make([]ids.ID, 0, len(parents))
	for _, parent := range parents {
		parentID := parent.ID()
		parentIDs = append(parentIDs, parentID)
		
		// Add this vertex as child of parent
		if _, exists := dag.reversedge[parentID]; !exists {
			dag.reversedge[parentID] = make([]ids.ID, 0)
		}
		dag.reversedge[parentID] = append(dag.reversedge[parentID], vertexID)
		
		// Remove parent from frontier if it was there
		dag.frontier.Remove(parentID)
	}
	
	// Add parents to edges map
	dag.edges[vertexID] = parentIDs
	
	// Add to frontier if it has no children yet
	if _, hasChildren := dag.reversedge[vertexID]; !hasChildren {
		dag.frontier.Add(vertexID)
	}
	
	return nil
}

// GetVertex returns a vertex by its ID
func (dag *ParallelDAG) GetVertex(id ids.ID) (ParallelVertex, error) {
	dag.lock.RLock()
	defer dag.lock.RUnlock()
	
	if vertex, exists := dag.vertices[id]; exists {
		return vertex, nil
	}
	
	return nil, ErrUnknownVertex
}

// GetFrontier returns the frontier vertices
func (dag *ParallelDAG) GetFrontier() []ParallelVertex {
	dag.lock.RLock()
	defer dag.lock.RUnlock()
	
	frontier := make([]ParallelVertex, 0, dag.frontier.Len())
	for frontierID := range dag.frontier {
		if vertex, exists := dag.vertices[frontierID]; exists {
			frontier = append(frontier, vertex)
		}
	}
	
	return frontier
}

// ProcessFrontier processes the frontier vertices in parallel
func (dag *ParallelDAG) ProcessFrontier(ctx context.Context) error {
	dag.lock.Lock()
	frontierVertices := dag.GetFrontier()
	dag.lock.Unlock()
	
	if len(frontierVertices) == 0 {
		return nil
	}
	
	// Process frontier vertices in parallel
	return dag.processor.ProcessBatch(ctx, frontierVertices)
}

// UpdateStatus updates the status of a vertex and propagates changes
func (dag *ParallelDAG) UpdateStatus(ctx context.Context, id ids.ID, status choices.Status) error {
	dag.lock.Lock()
	defer dag.lock.Unlock()
	
	vertex, exists := dag.vertices[id]
	if !exists {
		return ErrUnknownVertex
	}
	
	// Only update if status is different
	if vertex.Status() == status {
		return nil
	}
	
	// Update status
	switch status {
	case choices.Accepted:
		if err := vertex.Accept(ctx); err != nil {
			return err
		}
	case choices.Rejected:
		if err := vertex.Reject(ctx); err != nil {
			return err
		}
	default:
		return fmt.Errorf("unsupported status: %s", status)
	}
	
	// Propagate changes to children if needed
	if children, hasChildren := dag.reversedge[id]; hasChildren {
		for _, childID := range children {
			// Process child status updates as needed
			// This could involve checking if all parents are accepted, etc.
		}
	}
	
	return nil
}

// Size returns the number of vertices in the DAG
func (dag *ParallelDAG) Size() int {
	dag.lock.RLock()
	defer dag.lock.RUnlock()
	
	return len(dag.vertices)
}

// VertexAdapter adapts an avalanche.Vertex to ParallelVertex
type VertexAdapter struct {
	avalanche.Vertex
	priority uint64
}

// NewVertexAdapter creates a new vertex adapter
func NewVertexAdapter(vertex avalanche.Vertex, priority uint64) (*VertexAdapter, error) {
	if vertex == nil {
		return nil, errors.New("nil vertex")
	}
	
	return &VertexAdapter{
		Vertex:   vertex,
		priority: priority,
	}, nil
}

// GetProcessingPriority implements the ParallelVertex interface
func (va *VertexAdapter) GetProcessingPriority() uint64 {
	return va.priority
}

// Result represents the processing result of a vertex
type Result struct {
	VertexID ids.ID
	Status   choices.Status
	Latency  time.Duration
	Error    error
} 
