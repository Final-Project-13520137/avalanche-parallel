package consensus

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"sync"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/redis/go-redis/v9"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
)

// Engine represents the consensus engine interface
type Engine interface {
	ProcessBlock(block interface{}) error
	GetValidators() ([]*Validator, error)
	AddValidator(validator *Validator) error
	RemoveValidator(nodeID string) error
	GetStatus() (map[string]interface{}, error)
	Start(ctx context.Context) error
	Stop() error
}

// ConsensusEngine represents the main consensus engine
type ConsensusEngine struct {
	db                *gorm.DB
	redis             *redis.Client
	consensusMode     string
	validatorThreshold float64
	blockHeight       int64
	validators        map[string]*Validator
	mu                sync.RWMutex
	metrics           *ConsensusMetrics
	ctx               context.Context
	cancel            context.CancelFunc
}

// Config holds configuration for consensus engine
type Config struct {
	DBHost             string
	DBPort             string
	DBUser             string
	DBPassword         string
	DBName             string
	RedisURL           string
	ConsensusMode      string
	ValidatorThreshold float64
}

// NewConsensusEngine creates a new consensus engine
func NewConsensusEngine(config Config) (Engine, error) {
	// Database connection
	dsn := fmt.Sprintf("host=%s user=%s password=%s dbname=%s port=%s sslmode=disable",
		config.DBHost, config.DBUser, config.DBPassword, config.DBName, config.DBPort)

	db, err := gorm.Open(postgres.Open(dsn), &gorm.Config{})
	if err != nil {
		return nil, fmt.Errorf("failed to connect to database: %v", err)
	}

	// Auto-migrate tables
	if err := db.AutoMigrate(&Validator{}, &Block{}); err != nil {
		return nil, fmt.Errorf("failed to migrate database: %v", err)
	}

	// Redis connection
	opt, err := redis.ParseURL(config.RedisURL)
	if err != nil {
		return nil, fmt.Errorf("failed to parse Redis URL: %v", err)
	}

	redisClient := redis.NewClient(opt)
	if err := redisClient.Ping(context.Background()).Err(); err != nil {
		return nil, fmt.Errorf("failed to connect to Redis: %v", err)
	}

	// Initialize metrics
	metrics := NewConsensusMetrics()

	engine := &ConsensusEngine{
		db:                 db,
		redis:              redisClient,
		consensusMode:      config.ConsensusMode,
		validatorThreshold: config.ValidatorThreshold,
		blockHeight:        0,
		validators:         make(map[string]*Validator),
		metrics:            metrics,
	}

	// Load existing validators
	if err := engine.loadValidators(); err != nil {
		// Log warning but don't fail
	}

	return engine, nil
}

// Start starts the consensus engine
func (ce *ConsensusEngine) Start(ctx context.Context) error {
	ce.ctx, ce.cancel = context.WithCancel(ctx)
	return nil
}

// Stop stops the consensus engine
func (ce *ConsensusEngine) Stop() error {
	if ce.cancel != nil {
		ce.cancel()
	}
	return nil
}

// ProcessBlock processes a new block through consensus
func (ce *ConsensusEngine) ProcessBlock(blockInterface interface{}) error {
	// Convert interface to Block
	blockData, err := json.Marshal(blockInterface)
	if err != nil {
		return fmt.Errorf("failed to marshal block: %v", err)
	}

	var block Block
	if err := json.Unmarshal(blockData, &block); err != nil {
		return fmt.Errorf("failed to unmarshal block: %v", err)
	}

	start := time.Now()
	defer func() {
		ce.metrics.ConsensusLatency.Observe(time.Since(start).Seconds())
		ce.metrics.BlocksProcessed.Inc()
	}()

	ce.mu.Lock()
	defer ce.mu.Unlock()

	// Validate block
	if err := ce.validateBlock(&block); err != nil {
		ce.metrics.ConsensusErrors.Inc()
		return fmt.Errorf("block validation failed: %v", err)
	}

	// Run consensus algorithm
	if err := ce.runConsensus(&block); err != nil {
		ce.metrics.ConsensusErrors.Inc()
		return fmt.Errorf("consensus failed: %v", err)
	}

	// Store block
	if err := ce.db.Create(&block).Error; err != nil {
		ce.metrics.ConsensusErrors.Inc()
		return fmt.Errorf("failed to store block: %v", err)
	}

	// Update block height
	if block.Height > ce.blockHeight {
		ce.blockHeight = block.Height
		ce.metrics.BlockHeight.Set(float64(ce.blockHeight))
	}

	// Publish block to Redis
	blockData, _ = json.Marshal(block)
	ce.redis.Publish(context.Background(), "new_block", blockData)

	ce.metrics.BlocksProduced.Inc()
	return nil
}

// GetValidators returns all validators
func (ce *ConsensusEngine) GetValidators() ([]*Validator, error) {
	ce.mu.RLock()
	defer ce.mu.RUnlock()

	validators := make([]*Validator, 0, len(ce.validators))
	for _, validator := range ce.validators {
		validators = append(validators, validator)
	}

	return validators, nil
}

// AddValidator adds a new validator
func (ce *ConsensusEngine) AddValidator(validator *Validator) error {
	ce.mu.Lock()
	defer ce.mu.Unlock()

	validator.CreatedAt = time.Now()
	validator.Active = true

	if err := ce.db.Create(validator).Error; err != nil {
		return fmt.Errorf("failed to add validator: %v", err)
	}

	ce.validators[validator.NodeID] = validator
	ce.metrics.ValidatorCount.Set(float64(len(ce.validators)))

	return nil
}

// RemoveValidator removes a validator
func (ce *ConsensusEngine) RemoveValidator(nodeID string) error {
	ce.mu.Lock()
	defer ce.mu.Unlock()

	if _, exists := ce.validators[nodeID]; !exists {
		return fmt.Errorf("validator %s not found", nodeID)
	}

	// Mark as inactive instead of deleting
	if err := ce.db.Model(&Validator{}).Where("node_id = ?", nodeID).Update("active", false).Error; err != nil {
		return fmt.Errorf("failed to remove validator: %v", err)
	}

	delete(ce.validators, nodeID)
	ce.metrics.ValidatorCount.Set(float64(len(ce.validators)))

	return nil
}

// GetStatus returns the current status
func (ce *ConsensusEngine) GetStatus() (map[string]interface{}, error) {
	ce.mu.RLock()
	defer ce.mu.RUnlock()

	status := map[string]interface{}{
		"consensus_mode":      ce.consensusMode,
		"validator_threshold": ce.validatorThreshold,
		"block_height":        ce.blockHeight,
		"active_validators":   len(ce.validators),
		"timestamp":           time.Now(),
	}

	return status, nil
}

// loadValidators loads validators from database
func (ce *ConsensusEngine) loadValidators() error {
	var validators []Validator
	if err := ce.db.Where("active = ?", true).Find(&validators).Error; err != nil {
		return err
	}

	ce.mu.Lock()
	defer ce.mu.Unlock()

	for _, validator := range validators {
		ce.validators[validator.NodeID] = &validator
	}

	ce.metrics.ValidatorCount.Set(float64(len(ce.validators)))
	return nil
}

// validateBlock validates a block
func (ce *ConsensusEngine) validateBlock(block *Block) error {
	if block.ID == "" {
		return fmt.Errorf("block ID cannot be empty")
	}

	if block.Height <= 0 {
		return fmt.Errorf("block height must be positive")
	}

	if block.Timestamp.IsZero() {
		return fmt.Errorf("block timestamp cannot be zero")
	}

	// Check if block already exists
	var existingBlock Block
	if err := ce.db.Where("id = ?", block.ID).First(&existingBlock).Error; err == nil {
		return fmt.Errorf("block %s already exists", block.ID)
	}

	return nil
}

// runConsensus runs the consensus algorithm
func (ce *ConsensusEngine) runConsensus(block *Block) error {
	switch ce.consensusMode {
	case "snowman":
		return ce.runSnowmanConsensus(block)
	case "avalanche":
		return ce.runAvalancheConsensus(block)
	default:
		return fmt.Errorf("unknown consensus mode: %s", ce.consensusMode)
	}
}

// runSnowmanConsensus runs Snowman consensus
func (ce *ConsensusEngine) runSnowmanConsensus(block *Block) error {
	// Simplified Snowman consensus implementation
	activeValidators := 0
	for _, validator := range ce.validators {
		if validator.Active {
			activeValidators++
		}
	}

	if activeValidators == 0 {
		return fmt.Errorf("no active validators")
	}

	// Simulate consensus voting
	requiredVotes := int(float64(activeValidators) * ce.validatorThreshold)
	votes := activeValidators // Simplified: assume all validators vote yes

	if votes < requiredVotes {
		return fmt.Errorf("insufficient votes: got %d, required %d", votes, requiredVotes)
	}

	return nil
}

// runAvalancheConsensus runs Avalanche consensus
func (ce *ConsensusEngine) runAvalancheConsensus(block *Block) error {
	// Simplified Avalanche consensus implementation
	return ce.runSnowmanConsensus(block) // For now, use same logic
} 