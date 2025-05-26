package consensus

import (
	"encoding/json"
	"time"
)

// Validator represents a network validator
type Validator struct {
	NodeID    string     `json:"node_id" gorm:"primaryKey"`
	Stake     int64      `json:"stake"`
	StartTime time.Time  `json:"start_time"`
	EndTime   *time.Time `json:"end_time,omitempty"`
	SubnetID  string     `json:"subnet_id"`
	Active    bool       `json:"active" gorm:"default:true"`
	CreatedAt time.Time  `json:"created_at"`
}

// Block represents a blockchain block
type Block struct {
	ID        string          `json:"id" gorm:"primaryKey"`
	ParentID  string          `json:"parent_id"`
	Height    int64           `json:"height"`
	Timestamp time.Time       `json:"timestamp"`
	Data      json.RawMessage `json:"data" gorm:"type:jsonb"`
	CreatedAt time.Time       `json:"created_at"`
} 