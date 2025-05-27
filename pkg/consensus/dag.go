// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package consensus

import (
	"context"
	"sync"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

// ParallelVertex extends the functionality of the base Vertex
type ParallelVertex interface {
	avalanche.Vertex
	ID() ids.ID
	// GetProcessingPriority returns the priority for processing this vertex
	GetProcessingPriority() uint64
}

// VertexProcessor processes vertices in parallel
type VertexProcessor interface {
	// Process the vertex and its transactions
	ProcessVertex(ctx context.Context, vertex ParallelVertex) error
	// ProcessVertices processes multiple vertices in parallel
	ProcessVertices(ctx context.Context, vertices []ParallelVertex) error
}

// ParallelDAG optimizes the DAG processing using parallel execution
type ParallelDAG struct {
	lock         sync.RWMutex
	logger       logging.Logger
	vertices     map[ids.ID]ParallelVertex
	edgeVertices map[ids.ID]struct{}
	frontier     map[ids.ID]ParallelVertex
	maxWorkers   int
	processor    VertexProcessor
}

// NewParallelDAG creates a new DAG processor with parallel execution
func NewParallelDAG(logger logging.Logger, maxWorkers int, processor VertexProcessor) *ParallelDAG {
	if maxWorkers <= 0 {
		maxWorkers = 4 // Default to 4 workers
	}

	return &ParallelDAG{
		logger:       logger,
		vertices:     make(map[ids.ID]ParallelVertex),
		edgeVertices: make(map[ids.ID]struct{}),
		frontier:     make(map[ids.ID]ParallelVertex),
		maxWorkers:   maxWorkers,
		processor:    processor,
	}
}

// AddVertex adds a vertex to the DAG
func (d *ParallelDAG) AddVertex(vertex ParallelVertex) error {
	d.lock.Lock()
	defer d.lock.Unlock()

	vertexID := vertex.ID()
	if _, exists := d.vertices[vertexID]; exists {
		return nil // Already added
	}

	d.vertices[vertexID] = vertex
	d.frontier[vertexID] = vertex

	// Update frontier by removing parents from it
	parents, err := vertex.Parents()
	if err != nil {
		return err
	}

	for _, parent := range parents {
		parentVertex, ok := parent.(ParallelVertex)
		if !ok {
			continue
		}
		delete(d.frontier, parentVertex.ID())
	}

	return nil
}

// ProcessFrontier processes the DAG frontier in parallel
func (d *ParallelDAG) ProcessFrontier(ctx context.Context) error {
	d.lock.RLock()
	vertices := make([]ParallelVertex, 0, len(d.frontier))
	for _, v := range d.frontier {
		if v.Status() == choices.Processing {
			vertices = append(vertices, v)
		}
	}
	d.lock.RUnlock()

	if len(vertices) == 0 {
		return nil
	}

	return d.processor.ProcessVertices(ctx, vertices)
}

// DefaultVertexProcessor is a basic processor that processes vertices in parallel
type DefaultVertexProcessor struct {
	logger     logging.Logger
	maxWorkers int
}

// NewDefaultVertexProcessor creates a new processor with the specified number of workers
func NewDefaultVertexProcessor(logger logging.Logger, maxWorkers int) *DefaultVertexProcessor {
	if maxWorkers <= 0 {
		maxWorkers = 4
	}

	return &DefaultVertexProcessor{
		logger:     logger,
		maxWorkers: maxWorkers,
	}
}

// ProcessVertex processes a single vertex
func (p *DefaultVertexProcessor) ProcessVertex(ctx context.Context, vertex ParallelVertex) error {
	// Get transactions to process
	txs, err := vertex.Txs(ctx)
	if err != nil {
		return err
	}

	// Process each transaction
	for _, tx := range txs {
		if err := p.processTransaction(ctx, tx); err != nil {
			return err
		}
	}

	return nil
}

// processTransaction handles transaction processing logic
func (p *DefaultVertexProcessor) processTransaction(ctx context.Context, tx snowstorm.Tx) error {
	// Implement transaction processing logic here
	// For now, just verify the transaction
	return tx.Verify(ctx)
}

// ProcessVertices processes multiple vertices in parallel
func (p *DefaultVertexProcessor) ProcessVertices(ctx context.Context, vertices []ParallelVertex) error {
	if len(vertices) == 0 {
		return nil
	}

	// Create a worker pool
	wg := sync.WaitGroup{}
	errChan := make(chan error, len(vertices))
	semaphore := make(chan struct{}, p.maxWorkers)

	for _, v := range vertices {
		wg.Add(1)
		semaphore <- struct{}{} // Acquire a slot
		
		go func(vertex ParallelVertex) {
			defer func() {
				<-semaphore // Release the slot
				wg.Done()
			}()

			if err := p.ProcessVertex(ctx, vertex); err != nil {
				p.logger.Error("Failed to process vertex: %s", err)
				select {
				case errChan <- err:
				default:
					// Channel is full, log and continue
				}
			}
		}(v)
	}

	wg.Wait()
	close(errChan)

	// Check for errors
	if err, hasErr := <-errChan; hasErr {
		return err
	}

	return nil
}

// Result represents the processing result of a vertex
type Result struct {
	VertexID ids.ID
	Status   choices.Status
	Latency  time.Duration
	Error    error
} 