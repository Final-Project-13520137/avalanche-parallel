package consensus

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"time"
	"bytes"

	"github.com/ava-labs/avalanche-parallel/blockchain/storage"
	"github.com/ava-labs/avalanche-parallel/blockchain/types"
	// msconsensus "github.com/ava-labs/avalanche-parallel/microservices/services/consensus"
	"go.uber.org/zap"
	"github.com/ava-labs/avalanche-parallel/blockchain/avalanchego"
)

// MicroservicesWrapper wraps the microservices consensus for blockchain use
type MicroservicesWrapper struct {
	serviceURL string
	storage    storage.Manager
	logger     *zap.Logger
	client     *http.Client
}

// NewMicroservicesWrapper creates a new microservices consensus wrapper
func NewMicroservicesWrapper(serviceURL string, storage storage.Manager, logger *zap.Logger) (Engine, error) {
	return &MicroservicesWrapper{
		serviceURL: serviceURL,
		storage:    storage,
		logger:     logger,
		client:     &http.Client{Timeout: 10 * time.Second},
	}, nil
}

// Start starts the consensus engine
func (mw *MicroservicesWrapper) Start(ctx context.Context) error {
	mw.logger.Info("Starting microservices consensus wrapper", zap.String("service_url", mw.serviceURL))
	
	// Check if microservices consensus is available
	resp, err := mw.client.Get(fmt.Sprintf("%s/health", mw.serviceURL))
	if err != nil {
		return fmt.Errorf("microservices consensus not available: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("microservices consensus not healthy: status=%d", resp.StatusCode)
	}
	
	return nil
}

// Stop stops the consensus engine
func (mw *MicroservicesWrapper) Stop(ctx context.Context) error {
	mw.logger.Info("Stopping microservices consensus wrapper")
	return nil
}

// ProposeBlock proposes a new block for consensus
func (mw *MicroservicesWrapper) ProposeBlock(block *types.Block) (*types.ConsensusResult, error) {
	mw.logger.Info("Proposing block to microservices consensus",
		zap.Uint64("block_index", block.Index),
		zap.String("block_hash", block.Hash))

	// Marshal block to JSON
	blockData, err := json.Marshal(block)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal block: %w", err)
	}

	// Send block to microservices consensus
	resp, err := mw.client.Post(
		fmt.Sprintf("%s/consensus/propose", mw.serviceURL),
		"application/json",
		bytes.NewBuffer(blockData),
	)
	if err != nil {
		return nil, fmt.Errorf("failed to propose block: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("block proposal rejected: status=%d", resp.StatusCode)
	}

	// Parse response
	var result types.ConsensusResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode consensus result: %w", err)
	}

	return &result, nil
}

// ValidateBlock validates a block
func (mw *MicroservicesWrapper) ValidateBlock(block *types.Block) error {
	// Marshal block to JSON
	blockData, err := json.Marshal(block)
	if err != nil {
		return fmt.Errorf("failed to marshal block: %w", err)
	}

	// Send block for validation
	resp, err := mw.client.Post(
		fmt.Sprintf("%s/consensus/validate", mw.serviceURL),
		"application/json",
		bytes.NewBuffer(blockData),
	)
	if err != nil {
		return fmt.Errorf("failed to validate block: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("block validation failed: status=%d", resp.StatusCode)
	}

	return nil
}

// GetValidators returns the current validator set
func (mw *MicroservicesWrapper) GetValidators() ([]types.Validator, error) {
	resp, err := mw.client.Get(fmt.Sprintf("%s/consensus/validators", mw.serviceURL))
	if err != nil {
		return nil, fmt.Errorf("failed to get validators: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get validators: status=%d", resp.StatusCode)
	}

	var validators []types.Validator
	if err := json.NewDecoder(resp.Body).Decode(&validators); err != nil {
		return nil, fmt.Errorf("failed to decode validators: %w", err)
	}

	return validators, nil
}

// AddValidator adds a new validator
func (mw *MicroservicesWrapper) AddValidator(validator types.Validator) error {
	validatorData, err := json.Marshal(validator)
	if err != nil {
		return fmt.Errorf("failed to marshal validator: %w", err)
	}

	resp, err := mw.client.Post(
		fmt.Sprintf("%s/consensus/validators", mw.serviceURL),
		"application/json",
		bytes.NewBuffer(validatorData),
	)
	if err != nil {
		return fmt.Errorf("failed to add validator: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to add validator: status=%d", resp.StatusCode)
	}

	return nil
}

// RemoveValidator removes a validator
func (mw *MicroservicesWrapper) RemoveValidator(nodeID string) error {
	req, err := http.NewRequest(
		"DELETE",
		fmt.Sprintf("%s/consensus/validators/%s", mw.serviceURL, nodeID),
		nil,
	)
	if err != nil {
		return fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := mw.client.Do(req)
	if err != nil {
		return fmt.Errorf("failed to remove validator: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to remove validator: status=%d", resp.StatusCode)
	}

	return nil
}

// GetConsensusStatus returns the current consensus status
func (mw *MicroservicesWrapper) GetConsensusStatus() (*types.ConsensusStatus, error) {
	resp, err := mw.client.Get(fmt.Sprintf("%s/consensus/status", mw.serviceURL))
	if err != nil {
		return nil, fmt.Errorf("failed to get consensus status: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to get consensus status: status=%d", resp.StatusCode)
	}

	var status types.ConsensusStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("failed to decode consensus status: %w", err)
	}

	return &status, nil
}

// TraditionalWrapper wraps the traditional consensus for blockchain use
type TraditionalWrapper struct {
	storage         storage.Manager
	logger          *zap.Logger
	consensusClient *avalanchego.Client
}

// NewTraditionalWrapper creates a new traditional consensus wrapper
func NewTraditionalWrapper(storage storage.Manager, logger *zap.Logger) (Engine, error) {
	// Initialize traditional consensus client
	client, err := avalanchego.NewClient(&avalanchego.Config{
		Host:     getEnvOrDefault("AVALANCHEGO_HOST", "localhost"),
		Port:     getEnvOrDefault("AVALANCHEGO_PORT", "9650"),
		Protocol: getEnvOrDefault("AVALANCHEGO_PROTOCOL", "http"),
		ChainID:  getEnvOrDefault("AVALANCHEGO_CHAIN_ID", "X"),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to create traditional consensus client: %w", err)
	}

	return &TraditionalWrapper{
		storage:         storage,
		logger:          logger,
		consensusClient: client,
	}, nil
}

// Start starts the consensus engine
func (tw *TraditionalWrapper) Start(ctx context.Context) error {
	tw.logger.Info("Starting traditional consensus wrapper")
	
	// Check if traditional consensus node is available
	health, err := tw.consensusClient.Health(ctx)
	if err != nil {
		return fmt.Errorf("traditional consensus not available: %w", err)
	}
	
	if !health.Healthy {
		return fmt.Errorf("traditional consensus not healthy: %s", health.Error)
	}
	
	return nil
}

// Stop stops the consensus engine
func (tw *TraditionalWrapper) Stop(ctx context.Context) error {
	tw.logger.Info("Stopping traditional consensus wrapper")
	return tw.consensusClient.Close()
}

// ProposeBlock proposes a new block for consensus
func (tw *TraditionalWrapper) ProposeBlock(block *types.Block) (*types.ConsensusResult, error) {
	tw.logger.Info("Proposing block to traditional consensus",
		zap.Uint64("block_index", block.Index),
		zap.String("block_hash", block.Hash))

	// Convert block to traditional format
	tradBlock := &avalanchego.Block{
		ParentID:    block.PrevHash,
		Height:      block.Index,
		Timestamp:   block.Timestamp,
		Payload:     block.Transactions,
		ProposerID:  block.Validator,
		Signature:   block.Signature,
	}

	// Submit block to traditional consensus
	result, err := tw.consensusClient.ProposeBlock(context.Background(), tradBlock)
	if err != nil {
		return nil, fmt.Errorf("failed to propose block: %w", err)
	}

	// Convert result to our format
	return &types.ConsensusResult{
		Accepted:       result.Accepted,
		Votes:         result.Votes,
		TotalVotes:    result.TotalVotes,
		Confidence:    result.Confidence,
		Duration:      result.Duration,
		Reason:        result.Reason,
		ValidatorVotes: result.ValidatorVotes,
	}, nil
}

// ValidateBlock validates a block
func (tw *TraditionalWrapper) ValidateBlock(block *types.Block) error {
	// Convert block to traditional format
	tradBlock := &avalanchego.Block{
		ParentID:    block.PrevHash,
		Height:      block.Index,
		Timestamp:   block.Timestamp,
		Payload:     block.Transactions,
		ProposerID:  block.Validator,
		Signature:   block.Signature,
	}

	// Validate using traditional consensus
	if err := tw.consensusClient.ValidateBlock(context.Background(), tradBlock); err != nil {
		return fmt.Errorf("block validation failed: %w", err)
	}

	return nil
}

// GetValidators returns the current validator set
func (tw *TraditionalWrapper) GetValidators() ([]types.Validator, error) {
	// Get validators from traditional consensus
	tradValidators, err := tw.consensusClient.GetValidators(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get validators: %w", err)
	}

	// Convert to our format
	validators := make([]types.Validator, len(tradValidators))
	for i, v := range tradValidators {
		validators[i] = types.Validator{
			NodeID:    v.NodeID,
			Stake:     v.Weight,
			StartTime: v.StartTime,
			EndTime:   v.EndTime,
			SubnetID:  v.SubnetID,
			Active:    v.Connected,
		}
	}

	return validators, nil
}

// AddValidator adds a new validator
func (tw *TraditionalWrapper) AddValidator(validator types.Validator) error {
	// Convert to traditional format
	tradValidator := &avalanchego.Validator{
		NodeID:    validator.NodeID,
		Weight:    validator.Stake,
		StartTime: validator.StartTime,
		EndTime:   validator.EndTime,
		SubnetID:  validator.SubnetID,
	}

	// Add validator using traditional consensus
	if err := tw.consensusClient.AddValidator(context.Background(), tradValidator); err != nil {
		return fmt.Errorf("failed to add validator: %w", err)
	}

	return nil
}

// RemoveValidator removes a validator
func (tw *TraditionalWrapper) RemoveValidator(nodeID string) error {
	// Remove validator using traditional consensus
	if err := tw.consensusClient.RemoveValidator(context.Background(), nodeID); err != nil {
		return fmt.Errorf("failed to remove validator: %w", err)
	}

	return nil
}

// GetConsensusStatus returns the current consensus status
func (tw *TraditionalWrapper) GetConsensusStatus() (*types.ConsensusStatus, error) {
	// Get status from traditional consensus
	tradStatus, err := tw.consensusClient.GetConsensusStatus(context.Background())
	if err != nil {
		return nil, fmt.Errorf("failed to get consensus status: %w", err)
	}

	// Convert to our format
	return &types.ConsensusStatus{
		Mode:             "traditional",
		ActiveValidators: tradStatus.ValidatorCount,
		TotalStake:      tradStatus.TotalStake,
		BlockHeight:     tradStatus.Height,
		LastBlockTime:   tradStatus.LastBlockTime,
		ConsensusHealth: tradStatus.Health,
		Metrics:         tradStatus.Metrics,
	}, nil
}

// Helper function
func getEnvOrDefault(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
} 