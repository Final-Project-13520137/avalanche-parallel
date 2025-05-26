package avalanchego

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

// Config represents the configuration for the Avalanche client
type Config struct {
	Host     string
	Port     string
	Protocol string
	ChainID  string
}

// Client represents a client for interacting with AvalancheGo
type Client struct {
	config *Config
	http   *http.Client
	baseURL string
}

// Block represents a block in the traditional consensus
type Block struct {
	ParentID    string        `json:"parentID"`
	Height      uint64        `json:"height"`
	Timestamp   time.Time     `json:"timestamp"`
	Payload     interface{}   `json:"payload"`
	ProposerID  string       `json:"proposerID"`
	Signature   string       `json:"signature"`
}

// Validator represents a validator in the traditional consensus
type Validator struct {
	NodeID    string     `json:"nodeID"`
	Weight    int64      `json:"weight"`
	StartTime time.Time  `json:"startTime"`
	EndTime   *time.Time `json:"endTime,omitempty"`
	SubnetID  string     `json:"subnetID"`
	Connected bool       `json:"connected"`
}

// ConsensusResult represents the result of consensus operations
type ConsensusResult struct {
	Accepted       bool              `json:"accepted"`
	Votes         int               `json:"votes"`
	TotalVotes    int               `json:"totalVotes"`
	Confidence    float64           `json:"confidence"`
	Duration      time.Duration     `json:"duration"`
	Reason        string            `json:"reason"`
	ValidatorVotes map[string]bool  `json:"validatorVotes,omitempty"`
}

// ConsensusStatus represents the status of the consensus engine
type ConsensusStatus struct {
	ValidatorCount int                    `json:"validatorCount"`
	TotalStake    int64                  `json:"totalStake"`
	Height        uint64                 `json:"height"`
	LastBlockTime time.Time              `json:"lastBlockTime"`
	Health        string                 `json:"health"`
	Metrics       map[string]interface{} `json:"metrics"`
}

// HealthResponse represents the health check response
type HealthResponse struct {
	Healthy bool   `json:"healthy"`
	Error   string `json:"error,omitempty"`
}

// NewClient creates a new Avalanche client
func NewClient(config *Config) (*Client, error) {
	if config.Host == "" || config.Port == "" || config.Protocol == "" {
		return nil, fmt.Errorf("invalid client configuration")
	}

	return &Client{
		config: config,
		http: &http.Client{
			Timeout: 30 * time.Second,
		},
		baseURL: fmt.Sprintf("%s://%s:%s", config.Protocol, config.Host, config.Port),
	}, nil
}

// Health checks the health of the consensus node
func (c *Client) Health(ctx context.Context) (*HealthResponse, error) {
	resp, err := c.get(ctx, "/ext/health")
	if err != nil {
		return nil, err
	}

	var health HealthResponse
	if err := json.NewDecoder(resp.Body).Decode(&health); err != nil {
		return nil, fmt.Errorf("failed to decode health response: %w", err)
	}

	return &health, nil
}

// ProposeBlock proposes a new block for consensus
func (c *Client) ProposeBlock(ctx context.Context, block *Block) (*ConsensusResult, error) {
	resp, err := c.post(ctx, fmt.Sprintf("/ext/bc/%s/consensus/propose", c.config.ChainID), block)
	if err != nil {
		return nil, err
	}

	var result ConsensusResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode consensus result: %w", err)
	}

	return &result, nil
}

// ValidateBlock validates a block
func (c *Client) ValidateBlock(ctx context.Context, block *Block) error {
	resp, err := c.post(ctx, fmt.Sprintf("/ext/bc/%s/consensus/validate", c.config.ChainID), block)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("block validation failed: status=%d", resp.StatusCode)
	}

	return nil
}

// GetValidators returns the current validator set
func (c *Client) GetValidators(ctx context.Context) ([]Validator, error) {
	resp, err := c.get(ctx, fmt.Sprintf("/ext/bc/%s/validators", c.config.ChainID))
	if err != nil {
		return nil, err
	}

	var validators []Validator
	if err := json.NewDecoder(resp.Body).Decode(&validators); err != nil {
		return nil, fmt.Errorf("failed to decode validators: %w", err)
	}

	return validators, nil
}

// AddValidator adds a new validator
func (c *Client) AddValidator(ctx context.Context, validator *Validator) error {
	resp, err := c.post(ctx, fmt.Sprintf("/ext/bc/%s/validators", c.config.ChainID), validator)
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to add validator: status=%d", resp.StatusCode)
	}

	return nil
}

// RemoveValidator removes a validator
func (c *Client) RemoveValidator(ctx context.Context, nodeID string) error {
	resp, err := c.delete(ctx, fmt.Sprintf("/ext/bc/%s/validators/%s", c.config.ChainID, nodeID))
	if err != nil {
		return err
	}

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("failed to remove validator: status=%d", resp.StatusCode)
	}

	return nil
}

// GetConsensusStatus returns the current consensus status
func (c *Client) GetConsensusStatus(ctx context.Context) (*ConsensusStatus, error) {
	resp, err := c.get(ctx, fmt.Sprintf("/ext/bc/%s/consensus/status", c.config.ChainID))
	if err != nil {
		return nil, err
	}

	var status ConsensusStatus
	if err := json.NewDecoder(resp.Body).Decode(&status); err != nil {
		return nil, fmt.Errorf("failed to decode consensus status: %w", err)
	}

	return &status, nil
}

// Close closes the client
func (c *Client) Close() error {
	c.http.CloseIdleConnections()
	return nil
}

// Helper methods for HTTP requests

func (c *Client) get(ctx context.Context, path string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "GET", c.baseURL+path, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}

	return resp, nil
}

func (c *Client) post(ctx context.Context, path string, body interface{}) (*http.Response, error) {
	data, err := json.Marshal(body)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal request body: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", c.baseURL+path, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json")

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}

	return resp, nil
}

func (c *Client) delete(ctx context.Context, path string) (*http.Response, error) {
	req, err := http.NewRequestWithContext(ctx, "DELETE", c.baseURL+path, nil)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("request failed: %w", err)
	}

	return resp, nil
} 