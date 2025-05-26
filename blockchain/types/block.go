package types

import (
	"time"
)

// Block represents a blockchain block
type Block struct {
	Index        uint64            `json:"index"`
	Timestamp    time.Time         `json:"timestamp"`
	PrevHash     string            `json:"prev_hash"`
	Hash         string            `json:"hash"`
	Transactions []Transaction     `json:"transactions"`
	Nonce        uint64            `json:"nonce"`
	Difficulty   uint64            `json:"difficulty"`
	Validator    string            `json:"validator"`
	Signature    string            `json:"signature"`
	Metadata     map[string]string `json:"metadata"`
}

// Transaction represents a blockchain transaction
type Transaction struct {
	ID        string                 `json:"id"`
	From      string                 `json:"from"`
	To        string                 `json:"to"`
	Amount    float64                `json:"amount"`
	Fee       float64                `json:"fee"`
	Timestamp time.Time              `json:"timestamp"`
	Data      map[string]interface{} `json:"data"`
	Signature string                 `json:"signature"`
}

// Validator represents a network validator
type Validator struct {
	NodeID    string     `json:"node_id"`
	Stake     int64      `json:"stake"`
	StartTime time.Time  `json:"start_time"`
	EndTime   *time.Time `json:"end_time,omitempty"`
	SubnetID  string     `json:"subnet_id"`
	Active    bool       `json:"active"`
}

// ConsensusResult represents the result of consensus
type ConsensusResult struct {
	Accepted       bool                   `json:"accepted"`
	Votes          int                    `json:"votes"`
	TotalVotes     int                    `json:"total_votes"`
	Confidence     float64                `json:"confidence"`
	Duration       time.Duration          `json:"duration"`
	Reason         string                 `json:"reason"`
	ValidatorVotes map[string]bool        `json:"validator_votes,omitempty"`
}

// ConsensusStatus represents the current consensus status
type ConsensusStatus struct {
	Mode             string                 `json:"mode"`
	ActiveValidators int                    `json:"active_validators"`
	TotalStake       int64                  `json:"total_stake"`
	BlockHeight      uint64                 `json:"block_height"`
	LastBlockTime    time.Time              `json:"last_block_time"`
	ConsensusHealth  string                 `json:"consensus_health"`
	Metrics          map[string]interface{} `json:"metrics"`
}

// BlockchainConfig represents blockchain configuration
type BlockchainConfig struct {
	ConsensusMode   string   `json:"consensus_mode"`
	NetworkMode     string   `json:"network_mode"`
	DataDir         string   `json:"data_dir"`
	APIPort         int      `json:"api_port"`
	P2PPort         int      `json:"p2p_port"`
	BootstrapNodes  []string `json:"bootstrap_nodes"`
	ValidatorKey    string   `json:"validator_key"`
	ValidatorCert   string   `json:"validator_cert"`
	MicroserviceURL string   `json:"microservice_url"`
} 