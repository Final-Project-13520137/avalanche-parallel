package consensus

import (
	"context"
	"fmt"
	"sync"

	"github.com/ava-labs/avalanche-parallel/blockchain/storage"
	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	"go.uber.org/zap"
)

// consensusResponse represents a response from a consensus engine
type consensusResponse struct {
	result *types.ConsensusResult
	err    error
	source string
}

// HybridConsensus implements a hybrid consensus approach
type HybridConsensus struct {
	microservices Engine
	traditional   Engine
	storage       storage.Manager
	logger        *zap.Logger
	
	// Configuration
	preferMicroservices bool
	fallbackEnabled     bool
	parallelMode        bool
	
	// Metrics
	microservicesSuccess int64
	traditionalSuccess   int64
	fallbackCount        int64
	mu                   sync.RWMutex
}

// NewHybridConsensus creates a new hybrid consensus engine
func NewHybridConsensus(microservices Engine, traditional Engine, storage storage.Manager, logger *zap.Logger) (Engine, error) {
	return &HybridConsensus{
		microservices:       microservices,
		traditional:         traditional,
		storage:             storage,
		logger:              logger,
		preferMicroservices: true,
		fallbackEnabled:     true,
		parallelMode:        true,
	}, nil
}

// Start starts both consensus engines
func (hc *HybridConsensus) Start(ctx context.Context) error {
	hc.logger.Info("Starting hybrid consensus engine")
	
	// Start both engines
	errChan := make(chan error, 2)
	
	go func() {
		if err := hc.microservices.Start(ctx); err != nil {
			errChan <- fmt.Errorf("microservices consensus start failed: %w", err)
		} else {
			errChan <- nil
		}
	}()
	
	go func() {
		if err := hc.traditional.Start(ctx); err != nil {
			errChan <- fmt.Errorf("traditional consensus start failed: %w", err)
		} else {
			errChan <- nil
		}
	}()
	
	// Wait for both to start
	for i := 0; i < 2; i++ {
		if err := <-errChan; err != nil {
			hc.logger.Warn("Consensus engine start warning", zap.Error(err))
			// Continue even if one fails - we can still operate with one engine
		}
	}
	
	return nil
}

// Stop stops both consensus engines
func (hc *HybridConsensus) Stop(ctx context.Context) error {
	hc.logger.Info("Stopping hybrid consensus engine")
	
	var wg sync.WaitGroup
	wg.Add(2)
	
	go func() {
		defer wg.Done()
		if err := hc.microservices.Stop(ctx); err != nil {
			hc.logger.Error("Failed to stop microservices consensus", zap.Error(err))
		}
	}()
	
	go func() {
		defer wg.Done()
		if err := hc.traditional.Stop(ctx); err != nil {
			hc.logger.Error("Failed to stop traditional consensus", zap.Error(err))
		}
	}()
	
	wg.Wait()
	return nil
}

// ProposeBlock proposes a block using hybrid consensus
func (hc *HybridConsensus) ProposeBlock(block *types.Block) (*types.ConsensusResult, error) {
	if hc.parallelMode {
		return hc.proposeBlockParallel(block)
	}
	
	// Sequential mode with fallback
	if hc.preferMicroservices {
		result, err := hc.microservices.ProposeBlock(block)
		if err == nil {
			hc.incrementMicroservicesSuccess()
			return result, nil
		}
		
		hc.logger.Warn("Microservices consensus failed, falling back to traditional", zap.Error(err))
		hc.incrementFallbackCount()
	}
	
	result, err := hc.traditional.ProposeBlock(block)
	if err == nil {
		hc.incrementTraditionalSuccess()
	}
	return result, err
}

// proposeBlockParallel runs both consensus engines in parallel
func (hc *HybridConsensus) proposeBlockParallel(block *types.Block) (*types.ConsensusResult, error) {
	respChan := make(chan consensusResponse, 2)
	
	// Run both consensus engines in parallel
	go func() {
		result, err := hc.microservices.ProposeBlock(block)
		respChan <- consensusResponse{result: result, err: err, source: "microservices"}
	}()
	
	go func() {
		result, err := hc.traditional.ProposeBlock(block)
		respChan <- consensusResponse{result: result, err: err, source: "traditional"}
	}()
	
	// Collect results
	var microservicesResp, traditionalResp consensusResponse
	for i := 0; i < 2; i++ {
		resp := <-respChan
		if resp.source == "microservices" {
			microservicesResp = resp
		} else {
			traditionalResp = resp
		}
	}
	
	// Analyze results
	return hc.analyzeParallelResults(microservicesResp, traditionalResp)
}

// analyzeParallelResults analyzes results from parallel consensus
func (hc *HybridConsensus) analyzeParallelResults(microResp, tradResp consensusResponse) (*types.ConsensusResult, error) {
	// Both succeeded
	if microResp.err == nil && tradResp.err == nil {
		// Check if they agree
		if microResp.result.Accepted == tradResp.result.Accepted {
			// They agree, use the one with higher confidence
			if microResp.result.Confidence >= tradResp.result.Confidence {
				hc.incrementMicroservicesSuccess()
				return microResp.result, nil
			}
			hc.incrementTraditionalSuccess()
			return tradResp.result, nil
		}
		
		// They disagree, need to resolve conflict
		hc.logger.Warn("Consensus engines disagree",
			zap.Bool("microservices_accepted", microResp.result.Accepted),
			zap.Bool("traditional_accepted", tradResp.result.Accepted))
		
		// Use the one with higher confidence
		if microResp.result.Confidence > tradResp.result.Confidence {
			hc.incrementMicroservicesSuccess()
			return microResp.result, nil
		}
		hc.incrementTraditionalSuccess()
		return tradResp.result, nil
	}
	
	// Only microservices succeeded
	if microResp.err == nil {
		hc.incrementMicroservicesSuccess()
		return microResp.result, nil
	}
	
	// Only traditional succeeded
	if tradResp.err == nil {
		hc.incrementTraditionalSuccess()
		return tradResp.result, nil
	}
	
	// Both failed
	return nil, fmt.Errorf("both consensus engines failed: microservices=%v, traditional=%v", 
		microResp.err, tradResp.err)
}

// ValidateBlock validates a block using both engines
func (hc *HybridConsensus) ValidateBlock(block *types.Block) error {
	// Validate with both engines
	microErr := hc.microservices.ValidateBlock(block)
	tradErr := hc.traditional.ValidateBlock(block)
	
	// If both agree it's invalid, return error
	if microErr != nil && tradErr != nil {
		return fmt.Errorf("block validation failed: microservices=%v, traditional=%v", microErr, tradErr)
	}
	
	// If at least one says it's valid, accept it
	return nil
}

// GetValidators returns validators from the preferred engine
func (hc *HybridConsensus) GetValidators() ([]types.Validator, error) {
	if hc.preferMicroservices {
		validators, err := hc.microservices.GetValidators()
		if err == nil {
			return validators, nil
		}
		hc.logger.Warn("Failed to get validators from microservices, falling back", zap.Error(err))
	}
	
	return hc.traditional.GetValidators()
}

// AddValidator adds a validator to both engines
func (hc *HybridConsensus) AddValidator(validator types.Validator) error {
	// Add to both engines
	microErr := hc.microservices.AddValidator(validator)
	tradErr := hc.traditional.AddValidator(validator)
	
	if microErr != nil && tradErr != nil {
		return fmt.Errorf("failed to add validator: microservices=%v, traditional=%v", microErr, tradErr)
	}
	
	if microErr != nil {
		hc.logger.Warn("Failed to add validator to microservices consensus", zap.Error(microErr))
	}
	if tradErr != nil {
		hc.logger.Warn("Failed to add validator to traditional consensus", zap.Error(tradErr))
	}
	
	return nil
}

// RemoveValidator removes a validator from both engines
func (hc *HybridConsensus) RemoveValidator(nodeID string) error {
	// Remove from both engines
	microErr := hc.microservices.RemoveValidator(nodeID)
	tradErr := hc.traditional.RemoveValidator(nodeID)
	
	if microErr != nil && tradErr != nil {
		return fmt.Errorf("failed to remove validator: microservices=%v, traditional=%v", microErr, tradErr)
	}
	
	if microErr != nil {
		hc.logger.Warn("Failed to remove validator from microservices consensus", zap.Error(microErr))
	}
	if tradErr != nil {
		hc.logger.Warn("Failed to remove validator from traditional consensus", zap.Error(tradErr))
	}
	
	return nil
}

// GetConsensusStatus returns combined status from both engines
func (hc *HybridConsensus) GetConsensusStatus() (*types.ConsensusStatus, error) {
	microStatus, microErr := hc.microservices.GetConsensusStatus()
	tradStatus, tradErr := hc.traditional.GetConsensusStatus()
	
	hc.mu.RLock()
	defer hc.mu.RUnlock()
	
	// Create hybrid status
	status := &types.ConsensusStatus{
		Mode:            "hybrid",
		ConsensusHealth: "healthy",
		Metrics: map[string]interface{}{
			"prefer_microservices":   hc.preferMicroservices,
			"fallback_enabled":       hc.fallbackEnabled,
			"parallel_mode":          hc.parallelMode,
			"microservices_success":  hc.microservicesSuccess,
			"traditional_success":    hc.traditionalSuccess,
			"fallback_count":         hc.fallbackCount,
		},
	}
	
	// Merge status from both engines
	if microErr == nil && microStatus != nil {
		status.Metrics["microservices_status"] = microStatus
		status.ActiveValidators = microStatus.ActiveValidators
		status.TotalStake = microStatus.TotalStake
		status.BlockHeight = microStatus.BlockHeight
		status.LastBlockTime = microStatus.LastBlockTime
	}
	
	if tradErr == nil && tradStatus != nil {
		status.Metrics["traditional_status"] = tradStatus
		// Use traditional values if microservices failed
		if microErr != nil {
			status.ActiveValidators = tradStatus.ActiveValidators
			status.TotalStake = tradStatus.TotalStake
			status.BlockHeight = tradStatus.BlockHeight
			status.LastBlockTime = tradStatus.LastBlockTime
		}
	}
	
	// Determine health
	if microErr != nil && tradErr != nil {
		status.ConsensusHealth = "critical"
	} else if microErr != nil || tradErr != nil {
		status.ConsensusHealth = "degraded"
	}
	
	return status, nil
}

// Helper methods for metrics

func (hc *HybridConsensus) incrementMicroservicesSuccess() {
	hc.mu.Lock()
	defer hc.mu.Unlock()
	hc.microservicesSuccess++
}

func (hc *HybridConsensus) incrementTraditionalSuccess() {
	hc.mu.Lock()
	defer hc.mu.Unlock()
	hc.traditionalSuccess++
}

func (hc *HybridConsensus) incrementFallbackCount() {
	hc.mu.Lock()
	defer hc.mu.Unlock()
	hc.fallbackCount++
} 