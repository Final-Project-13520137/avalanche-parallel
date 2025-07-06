// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package vertex

import (
	"fmt"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow/consensus/avalanche"
)

// Adapter adapts the base avalanche.Vertex to Parallel
type Adapter struct {
	avalanche.Vertex
	id       ids.ID
	priority uint64
}

// NewAdapter creates a new adapter for avalanche.Vertex
func NewAdapter(vertex avalanche.Vertex, priority uint64) (*Adapter, error) {
	if vertex == nil {
		return nil, fmt.Errorf("cannot adapt nil vertex")
	}

	// Create a vertex ID from the vertex bytes
	id, err := ids.ToID(vertex.Bytes())
	if err != nil {
		return nil, fmt.Errorf("failed to create vertex ID: %w", err)
	}

	return &Adapter{
		Vertex:   vertex,
		id:       id,
		priority: priority,
	}, nil
}

// ID returns the vertex ID
func (va *Adapter) ID() ids.ID {
	return va.id
}

// GetProcessingPriority returns the vertex processing priority
func (va *Adapter) GetProcessingPriority() uint64 {
	return va.priority
}

// Parallel is an extension of the avalanche.Vertex interface
// that adds parallel processing capabilities
type Parallel interface {
	avalanche.Vertex

	// GetProcessingPriority returns the priority for processing this vertex
	GetProcessingPriority() uint64
}
