package consensus

import (
	"context"

	"github.com/ava-labs/avalanche-parallel/blockchain/types"
)

// Engine defines the interface for consensus engines
type Engine interface {
	// Start starts the consensus engine
	Start(ctx context.Context) error
	
	// Stop stops the consensus engine
	Stop(ctx context.Context) error
	
	// ProposeBlock proposes a new block for consensus
	ProposeBlock(block *types.Block) (*types.ConsensusResult, error)
	
	// ValidateBlock validates a block
	ValidateBlock(block *types.Block) error
	
	// GetValidators returns the current validator set
	GetValidators() ([]types.Validator, error)
	
	// AddValidator adds a new validator
	AddValidator(validator types.Validator) error
	
	// RemoveValidator removes a validator
	RemoveValidator(nodeID string) error
	
	// GetConsensusStatus returns the current consensus status
	GetConsensusStatus() (*types.ConsensusStatus, error)
}

 