package consensus

import (
	"context"
	"sync"

	"go.uber.org/zap"
)

// ConsensusEngine handles parallel transaction processing
type ConsensusEngine struct {
	workerCount int
	logger      *zap.Logger
	workers     []*Worker
}

// Worker represents a transaction processing worker
type Worker struct {
	id     int
	engine *ConsensusEngine
	txChan chan struct{}
	wg     *sync.WaitGroup
	logger *zap.Logger
}

// NewConsensusEngine creates a new consensus engine with the specified number of workers
func NewConsensusEngine(logger *zap.Logger, workerCount int) *ConsensusEngine {
	engine := &ConsensusEngine{
		workerCount: workerCount,
		logger:      logger,
		workers:     make([]*Worker, workerCount),
	}

	// Initialize workers
	wg := &sync.WaitGroup{}
	for i := 0; i < workerCount; i++ {
		worker := &Worker{
			id:     i,
			engine: engine,
			txChan: make(chan struct{}, 1000),
			wg:     wg,
			logger: logger,
		}
		engine.workers[i] = worker
		go worker.start()
	}

	return engine
}

// ProcessTransactions processes the specified number of transactions
func (e *ConsensusEngine) ProcessTransactions(ctx context.Context, count int) error {
	e.logger.Info("Processing transactions", zap.Int("count", count))

	// Add transactions to process
	wg := &sync.WaitGroup{}
	wg.Add(count)

	// Distribute transactions to workers
	for i := 0; i < count; i++ {
		workerIdx := i % e.workerCount
		e.workers[workerIdx].txChan <- struct{}{}
	}

	// Close worker channels
	for _, w := range e.workers {
		close(w.txChan)
	}

	// Wait for all transactions to complete
	wg.Wait()

	e.logger.Info("Finished processing transactions", zap.Int("count", count))
	return nil
}

// start starts the worker's processing loop
func (w *Worker) start() {
	w.logger.Info("Starting worker", zap.Int("id", w.id))

	for range w.txChan {
		// Process transaction
		w.wg.Done()
	}

	w.logger.Info("Worker stopped", zap.Int("id", w.id))
}
