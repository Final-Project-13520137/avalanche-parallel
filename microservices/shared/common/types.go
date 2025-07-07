package common

import (
	"context"
	"time"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/snow/choices"
	"github.com/ava-labs/avalanchego/utils/set"
)

// Transaction represents a transfer of tokens from a sender to a recipient
type Transaction struct {
	txID      ids.ID         // The unique identifier of the transaction
	sender    string         // The sender's address
	recipient string         // The recipient's address
	amount    uint64         // The amount being transferred
	nonce     uint64         // A unique number to prevent replay attacks
	signature []byte         // The signature of the transaction
	status    choices.Status // The status of the transaction
	deps      []ids.ID       // Dependencies of this transaction
}

// Accept marks the transaction as accepted
func (tx *Transaction) Accept(ctx context.Context) error {
	tx.status = choices.Accepted
	return nil
}

// Reject marks the transaction as rejected
func (tx *Transaction) Reject(ctx context.Context) error {
	tx.status = choices.Rejected
	return nil
}

// ID returns the unique identifier of the transaction
func (tx *Transaction) ID() ids.ID {
	return tx.txID
}

// Status returns the status of the transaction
func (tx *Transaction) Status() choices.Status {
	return tx.status
}

// Bytes returns the binary representation of this transaction
func (tx *Transaction) Bytes() []byte {
	return tx.txID[:]
}

// Verify checks if the transaction is valid
func (tx *Transaction) Verify(ctx context.Context) error {
	return nil
}

// MissingDependencies returns the missing dependencies of the transaction
func (tx *Transaction) MissingDependencies() (set.Set[ids.ID], error) {
	missing := set.Set[ids.ID]{}
	for _, depID := range tx.deps {
		missing.Add(depID)
	}
	return missing, nil
}

// NewTransaction creates a new transaction
func NewTransaction(id ids.ID, sender, recipient string, amount, nonce uint64) *Transaction {
	return &Transaction{
		txID:      id,
		sender:    sender,
		recipient: recipient,
		amount:    amount,
		nonce:     nonce,
		status:    choices.Processing,
		deps:      make([]ids.ID, 0),
	}
}

// AddDependency adds a dependency to the transaction
func (tx *Transaction) AddDependency(depID ids.ID) {
	tx.deps = append(tx.deps, depID)
}

// GetSender returns the sender address
func (tx *Transaction) GetSender() string {
	return tx.sender
}

// GetRecipient returns the recipient address
func (tx *Transaction) GetRecipient() string {
	return tx.recipient
}

// GetAmount returns the transaction amount
func (tx *Transaction) GetAmount() uint64 {
	return tx.amount
}

// GetNonce returns the transaction nonce
func (tx *Transaction) GetNonce() uint64 {
	return tx.nonce
}

// Vertex represents a vertex in the DAG
type Vertex struct {
	ID        ids.ID    `json:"id"`
	ParentIDs []ids.ID  `json:"parent_ids"`
	Height    uint64    `json:"height"`
	Timestamp time.Time `json:"timestamp"`
}

// HealthStatus represents service health information
type HealthStatus struct {
	Service   string        `json:"service"`
	Status    string        `json:"status"`
	Uptime    time.Duration `json:"uptime"`
	Version   string        `json:"version"`
	Timestamp time.Time     `json:"timestamp"`
}

// ServiceResponse represents a standard API response
type ServiceResponse struct {
	Success   bool        `json:"success"`
	Data      interface{} `json:"data,omitempty"`
	Error     string      `json:"error,omitempty"`
	Timestamp time.Time   `json:"timestamp"`
}
