// Copyright (C) 2024, Avalanche Parallel Project. All rights reserved.
// See the file LICENSE for licensing terms.

package main

import (
	"context"
	"flag"
	"fmt"
	"math/rand"
	"os"
	"time"

	"github.com/Final-Project-13520137/avalanche-parallel/default/ids"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/choices"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/avalanche"
	"github.com/Final-Project-13520137/avalanche-parallel/default/snow/consensus/snowstorm"
	"github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
	"github.com/avalanche-parallel-dag/pkg/consensus"
)

const (
	defaultVertices   = 1000
	defaultThreads    = 4
	defaultIterations = 10
)

// MockTx implements the snowstorm.Tx interface
type MockTx struct {
	id        ids.ID
	status    choices.Status
	verifyErr error
}

// ID implements snowstorm.Tx
func (tx *MockTx) ID() ids.ID {
	return tx.id
}

// Accept implements snowstorm.Tx
func (tx *MockTx) Accept(context.Context) error {
	tx.status = choices.Accepted
	return nil
}

// Reject implements snowstorm.Tx
func (tx *MockTx) Reject(context.Context) error {
	tx.status = choices.Rejected
	return nil
}

// Status implements snowstorm.Tx
func (tx *MockTx) Status() choices.Status {
	return tx.status
}

// Bytes implements snowstorm.Tx
func (tx *MockTx) Bytes() []byte {
	return tx.id.Bytes()
}

// Verify implements snowstorm.Tx
func (tx *MockTx) Verify(context.Context) error {
	// Simulate work with a random delay
	time.Sleep(time.Duration(rand.Intn(5)) * time.Millisecond)
	return tx.verifyErr
}

// MockVertex implements the avalanche.Vertex interface
type MockVertex struct {
	id       ids.ID
	height   uint64
	status   choices.Status
	parents  []avalanche.Vertex
	txs      []snowstorm.Tx
	bytes    []byte
}

// ID implements ParallelVertex
func (v *MockVertex) ID() ids.ID {
	return v.id
}

// Accept implements avalanche.Vertex
func (v *MockVertex) Accept(context.Context) error {
	v.status = choices.Accepted
	return nil
}

// Reject implements avalanche.Vertex
func (v *MockVertex) Reject(context.Context) error {
	v.status = choices.Rejected
	return nil
}

// Status implements avalanche.Vertex
func (v *MockVertex) Status() choices.Status {
	return v.status
}

// Parents implements avalanche.Vertex
func (v *MockVertex) Parents() ([]avalanche.Vertex, error) {
	return v.parents, nil
}

// Height implements avalanche.Vertex
func (v *MockVertex) Height() (uint64, error) {
	return v.height, nil
}

// Txs implements avalanche.Vertex
func (v *MockVertex) Txs(context.Context) ([]snowstorm.Tx, error) {
	return v.txs, nil
}

// Bytes implements avalanche.Vertex
func (v *MockVertex) Bytes() []byte {
	return v.bytes
}

// GetProcessingPriority returns the vertex priority
func (v *MockVertex) GetProcessingPriority() uint64 {
	return v.height
}

// createMockDAG creates a mock DAG with the specified number of vertices
func createMockDAG(numVertices int) []avalanche.Vertex {
	// Create root vertex
	root := &MockVertex{
		id:      ids.GenerateTestID(),
		height:  1,
		status:  choices.Processing,
		parents: []avalanche.Vertex{},
		txs:     []snowstorm.Tx{},
		bytes:   []byte{0x01},
	}

	vertices := []avalanche.Vertex{root}
	
	// Create a DAG with specified number of vertices
	for i := 1; i < numVertices; i++ {
		// Select random parents (between 1 and 3)
		numParents := rand.Intn(3) + 1
		if numParents > len(vertices) {
			numParents = len(vertices)
		}
		
		parents := make([]avalanche.Vertex, 0, numParents)
		for j := 0; j < numParents; j++ {
			parentIndex := rand.Intn(len(vertices))
			parents = append(parents, vertices[parentIndex])
		}
		
		// Calculate max parent height
		maxHeight := uint64(0)
		for _, parent := range parents {
			h, _ := parent.Height()
			if h > maxHeight {
				maxHeight = h
			}
		}
		
		// Create transactions
		numTxs := rand.Intn(5) + 1
		txs := make([]snowstorm.Tx, 0, numTxs)
		for j := 0; j < numTxs; j++ {
			tx := &MockTx{
				id:        ids.GenerateTestID(),
				status:    choices.Processing,
				verifyErr: nil,
			}
			txs = append(txs, tx)
		}
		
		// Create vertex
		vertex := &MockVertex{
			id:      ids.GenerateTestID(),
			height:  maxHeight + 1,
			status:  choices.Processing,
			parents: parents,
			txs:     txs,
			bytes:   []byte{byte(i)},
		}
		
		vertices = append(vertices, vertex)
	}
	
	return vertices
}

func main() {
	// Parse command line flags
	numVertices := flag.Int("vertices", defaultVertices, "Number of vertices in the DAG")
	numThreads := flag.Int("threads", defaultThreads, "Number of worker threads")
	iterations := flag.Int("iterations", defaultIterations, "Number of test iterations")
	flag.Parse()
	
	// Create logger
	logFactory := logging.NewFactory(logging.Config{
		DisplayLevel: "info",
	})
	log, err := logFactory.Make("benchmark")
	if err != nil {
		fmt.Printf("Failed to create logger: %s\n", err)
		os.Exit(1)
	}

	// Create context
	ctx := context.Background()
	
	// Run benchmark
	log.Info("Creating DAG with %d vertices", *numVertices)
	vertices := createMockDAG(*numVertices)
	
	// Sequential processing
	log.Info("Running sequential processing benchmark")
	sequentialStart := time.Now()
	for i := 0; i < *iterations; i++ {
		for _, vertex := range vertices {
			txs, err := vertex.Txs(ctx)
			if err != nil {
				log.Error("Failed to get txs: %s", err)
				continue
			}
			
			for _, tx := range txs {
				err = tx.Verify(ctx)
				if err != nil {
					log.Error("Failed to verify tx: %s", err)
				}
			}
		}
	}
	sequentialDuration := time.Since(sequentialStart)
	log.Info("Sequential processing took %s", sequentialDuration)
	
	// Parallel processing
	log.Info("Running parallel processing benchmark with %d threads", *numThreads)
	parallelEngine := consensus.NewParallelEngine(log, *numThreads)
	
	parallelStart := time.Now()
	for i := 0; i < *iterations; i++ {
		for _, vertex := range vertices {
			err := parallelEngine.ProcessVertex(ctx, vertex)
			if err != nil {
				log.Error("Failed to process vertex: %s", err)
			}
		}
	}
	parallelDuration := time.Since(parallelStart)
	log.Info("Parallel processing took %s", parallelDuration)
	
	// Calculate speedup
	speedup := float64(sequentialDuration) / float64(parallelDuration)
	log.Info("Speedup: %.2fx", speedup)
	log.Info("Efficiency: %.2f%%", (speedup / float64(*numThreads)) * 100)
} 