// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package consensus

import (
	"context"
	"fmt"

	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/snow/consensus/avalanche"
	"github.com/ava-labs/avalanchego/snow/consensus/snowstorm"
	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/utils/logging"
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

// ParallelEngine extends the avalanche engine with parallel processing capabilities
type ParallelEngine struct {
	logger      logging.Logger
	parallelDAG *ParallelDAG
	baseEngine  interface{} // Reference to the base avalanche engine
}

// NewParallelEngine creates a new parallel processing engine
func NewParallelEngine(logger logging.Logger, maxWorkers int) *ParallelEngine {
	processor := NewDefaultVertexProcessor(logger, maxWorkers)
	dag := NewParallelDAG(logger, maxWorkers, processor)
	
	return &ParallelEngine{
		logger:      logger,
		parallelDAG: dag,
	}
}

// SetBaseEngine sets the base avalanche engine
func (pe *ParallelEngine) SetBaseEngine(engine interface{}) {
	pe.baseEngine = engine
}

// ProcessVertex processes a single vertex through the parallel DAG
func (pe *ParallelEngine) ProcessVertex(ctx context.Context, vertex avalanche.Vertex) error {
	// Determine vertex priority (could be based on height, number of txs, etc.)
	height, err := vertex.Height()
	if err != nil {
		return fmt.Errorf("failed to get vertex height: %w", err)
	}
	
	// Adapt the vertex to ParallelVertex
	adaptedVertex, err := NewVertexAdapter(vertex, height)
	if err != nil {
		return fmt.Errorf("failed to adapt vertex: %w", err)
	}
	
	// Add vertex to DAG
	if err := pe.parallelDAG.AddVertex(adaptedVertex); err != nil {
		return fmt.Errorf("failed to add vertex to DAG: %w", err)
	}
	
	// Process the frontier to potentially include this vertex
	return pe.parallelDAG.ProcessFrontier(ctx)
}

// BatchProcessVertices processes multiple vertices in parallel
func (pe *ParallelEngine) BatchProcessVertices(ctx context.Context, vertices []avalanche.Vertex) error {
	for _, vertex := range vertices {
		if err := pe.ProcessVertex(ctx, vertex); err != nil {
			return err
		}
	}
	return nil
} 