package consensus

import (
	"context"
	"fmt"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow"
	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/snow/consensus/snowman"
	"github.com/ava-labs/avalanchego/snow/validators"
	"github.com/ava-labs/avalanchego/utils/logging"
	"github.com/prometheus/client_golang/prometheus"
)

// TraditionalEngine wraps the traditional Avalanche consensus engine
type TraditionalEngine struct {
	snowmanEngine snowman.Consensus
	ctx           *snow.ConsensusContext
	validators    validators.Manager
	logger        logging.Logger
	metrics       prometheus.Registerer
}

// Config holds configuration for traditional consensus
type Config struct {
	Ctx        *snow.ConsensusContext
	Validators validators.Manager
	Logger     logging.Logger
	Metrics    prometheus.Registerer
}

// Block interface for traditional consensus
type Block interface {
	snowman.Block
}

// NewTraditionalEngine creates a new traditional consensus engine
func NewTraditionalEngine(config Config) (*TraditionalEngine, error) {
	if config.Ctx == nil {
		return nil, fmt.Errorf("consensus context is required")
	}
	if config.Validators == nil {
		return nil, fmt.Errorf("validators manager is required")
	}
	if config.Logger == nil {
		config.Logger = logging.NoLog{}
	}
	if config.Metrics == nil {
		config.Metrics = prometheus.NewRegistry()
	}

	// Create Snowman consensus parameters
	params := snowman.Parameters{
		K:                       20,
		AlphaPreference:         14,
		AlphaConfidence:         14,
		Beta:                    20,
		ConcurrentRepolls:       4,
		OptimalProcessing:       10,
		MaxOutstandingItems:     256,
		MaxItemProcessingTime:   30 * time.Second,
		MixedQueryNumPushNonVdr: 10,
	}

	// Create metrics
	consensusMetrics, err := snowman.NewMetrics("", config.Metrics)
	if err != nil {
		return nil, fmt.Errorf("failed to create metrics: %w", err)
	}

	// Create Snowman consensus engine
	snowmanEngine := &snowman.Topological{}
	if err := snowmanEngine.Initialize(config.Ctx, params, nil, consensusMetrics); err != nil {
		return nil, fmt.Errorf("failed to initialize snowman engine: %w", err)
	}

	return &TraditionalEngine{
		snowmanEngine: snowmanEngine,
		ctx:           config.Ctx,
		validators:    config.Validators,
		logger:        config.Logger,
		metrics:       config.Metrics,
	}, nil
}

// Start starts the consensus engine
func (te *TraditionalEngine) Start(ctx context.Context) error {
	te.logger.Info("Starting traditional consensus engine")
	return nil
}

// Stop stops the consensus engine
func (te *TraditionalEngine) Stop() error {
	te.logger.Info("Stopping traditional consensus engine")
	return nil
}

// Add adds a new block to consensus
func (te *TraditionalEngine) Add(block Block) error {
	return te.snowmanEngine.Add(context.Background(), block)
}

// Chits handles chits from validators
func (te *TraditionalEngine) Chits(ctx context.Context, nodeID ids.NodeID, requestID uint32, preferredID ids.ID, acceptedID ids.ID, preferredIDAtHeight ids.ID) error {
	return te.snowmanEngine.Chits(ctx, nodeID, requestID, preferredID, acceptedID, preferredIDAtHeight)
}

// QueryFailed handles failed queries
func (te *TraditionalEngine) QueryFailed(ctx context.Context, nodeID ids.NodeID, requestID uint32) error {
	return te.snowmanEngine.QueryFailed(ctx, nodeID, requestID)
}

// Preference returns the preferred block ID
func (te *TraditionalEngine) Preference() ids.ID {
	return te.snowmanEngine.Preference()
}

// LastAccepted returns the last accepted block ID
func (te *TraditionalEngine) LastAccepted() ids.ID {
	return te.snowmanEngine.LastAccepted()
}

// HealthCheck returns the health status
func (te *TraditionalEngine) HealthCheck(ctx context.Context) (interface{}, error) {
	return te.snowmanEngine.HealthCheck(ctx)
}

// IsPreferred checks if a block is preferred
func (te *TraditionalEngine) IsPreferred(blkID ids.ID) bool {
	return te.snowmanEngine.IsPreferred(blkID)
}

// RecordPoll records poll results
func (te *TraditionalEngine) RecordPoll(ctx context.Context, responses []ids.Bag) error {
	return te.snowmanEngine.RecordPoll(ctx, responses)
}

// SimpleBlock is a basic block implementation for testing
type SimpleBlock struct {
	id       ids.ID
	parentID ids.ID
	height   uint64
	status   choices.Status
	bytes    []byte
}

// ID returns the block ID
func (b *SimpleBlock) ID() ids.ID {
	return b.id
}

// Parent returns the parent block ID
func (b *SimpleBlock) Parent() ids.ID {
	return b.parentID
}

// Height returns the block height
func (b *SimpleBlock) Height() uint64 {
	return b.height
}

// Timestamp returns the block timestamp
func (b *SimpleBlock) Timestamp() time.Time {
	return time.Now()
}

// Verify verifies the block
func (b *SimpleBlock) Verify(ctx context.Context) error {
	return nil
}

// Accept accepts the block
func (b *SimpleBlock) Accept(ctx context.Context) error {
	b.status = choices.Accepted
	return nil
}

// Reject rejects the block
func (b *SimpleBlock) Reject(ctx context.Context) error {
	b.status = choices.Rejected
	return nil
}

// Status returns the block status
func (b *SimpleBlock) Status() choices.Status {
	return b.status
}

// Bytes returns the block bytes
func (b *SimpleBlock) Bytes() []byte {
	return b.bytes
} 