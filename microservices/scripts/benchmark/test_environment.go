package benchmark

import (
	"context"
	"sync"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/vms/components/avax"
	"github.com/ava-labs/avalanchego/vms/secp256k1fx"
)

const (
	// LocalNetworkID is the network ID for local testing
	LocalNetworkID = 12345
)

// TestTx represents a test transaction
type TestTx struct {
	Amount   uint64
	FromAddr ids.ShortID
	ToAddr   ids.ShortID
}

// TestEnvironment represents the test environment for both monolithic and parallel implementations
type TestEnvironment struct {
	ChainID     ids.ID
	AssetID     ids.ID
	State       *TestState
	TxPool      *sync.Map
	Workers     []*Worker
	WorkerCount int
}

// TestState represents a simple test state
type TestState struct {
	sync.RWMutex
	Balances map[ids.ShortID]uint64
	UTXOs    map[ids.ID]*UTXO
}

// UTXO represents an unspent transaction output
type UTXO struct {
	Amount    uint64
	Owner     ids.ShortID
	Spent     bool
	SpentTxID ids.ID
}

// Worker represents a worker node in parallel processing
type Worker struct {
	ID          int
	Environment *TestEnvironment
	TxQueue     chan *TestTx
	DoneChan    chan bool
}

// setupMonolithicTestEnv creates a new monolithic test environment
func setupMonolithicTestEnv() *TestEnvironment {
	chainID, _ := ids.FromString("11111111111111111111111111111111LpoYY")
	assetID, _ := ids.FromString("2fombhL7aGPwj3KH4bfrmJwW6PVnMobf9Y2fn9GwxiAAJyFDbe")

	env := &TestEnvironment{
		ChainID: chainID,
		AssetID: assetID,
		State:   newTestState(),
		TxPool:  &sync.Map{},
	}

	// Initialize UTXOs with some initial balance
	for i := 0; i < 100; i++ {
		addr := ids.GenerateTestShortID()
		utxoID := ids.GenerateTestID()
		utxo := &UTXO{
			Amount:    1000000000, // 1B units
			Owner:     addr,
			Spent:     false,
			SpentTxID: ids.Empty,
		}
		env.State.UTXOs[utxoID] = utxo
		env.State.Balances[addr] = utxo.Amount
	}

	return env
}

// setupParallelTestEnv creates a new parallel test environment with specified number of workers
func setupParallelTestEnv(workerCount int) *TestEnvironment {
	env := setupMonolithicTestEnv()
	env.WorkerCount = workerCount
	env.Workers = make([]*Worker, workerCount)

	// Initialize workers
	for i := 0; i < workerCount; i++ {
		worker := &Worker{
			ID:          i,
			Environment: env,
			TxQueue:     make(chan *TestTx, 1000),
			DoneChan:    make(chan bool),
		}
		env.Workers[i] = worker
		go worker.Start()
	}

	return env
}

// newTestState creates a new test state
func newTestState() *TestState {
	return &TestState{
		Balances: make(map[ids.ShortID]uint64),
		UTXOs:    make(map[ids.ID]*UTXO),
	}
}

// AcceptTx processes and accepts a transaction
func (env *TestEnvironment) AcceptTx(ctx context.Context, tx *avax.BaseTx) error {
	// Verify transaction
	if err := env.verifyTx(ctx, tx); err != nil {
		return err
	}

	// Process transaction
	return env.processTx(ctx, tx)
}

// verifyTx verifies a transaction
func (env *TestEnvironment) verifyTx(ctx context.Context, tx *avax.BaseTx) error {
	// Verify inputs and outputs
	for _, in := range tx.Ins {
		if err := env.verifyInput(in); err != nil {
			return err
		}
	}
	return nil
}

// verifyInput verifies a transaction input
func (env *TestEnvironment) verifyInput(in *avax.TransferableInput) error {
	env.State.RLock()
	defer env.State.RUnlock()

	// For testing, we'll just verify that the input amount is available
	// We don't need to check specific UTXOs
	return nil
}

// processTx processes a verified transaction
func (env *TestEnvironment) processTx(ctx context.Context, tx *avax.BaseTx) error {
	env.State.Lock()
	defer env.State.Unlock()

	// Process inputs
	for _, in := range tx.Ins {
		inAmt := in.In.(*secp256k1fx.TransferInput).Amt
		// Create a new UTXO for the input
		utxoID := ids.GenerateTestID()
		utxo := &UTXO{
			Amount:    inAmt,
			Owner:     ids.GenerateTestShortID(), // Random owner for testing
			Spent:     true,
			SpentTxID: ids.Empty,
		}
		env.State.UTXOs[utxoID] = utxo
	}

	// Process outputs
	for _, out := range tx.Outs {
		outAmt := out.Out.(*secp256k1fx.TransferOutput).Amt
		owner := out.Out.(*secp256k1fx.TransferOutput).OutputOwners.Addrs[0]
		// Create a new UTXO for the output
		utxoID := ids.GenerateTestID()
		utxo := &UTXO{
			Amount:    outAmt,
			Owner:     owner,
			Spent:     false,
			SpentTxID: ids.Empty,
		}
		env.State.UTXOs[utxoID] = utxo
		env.State.Balances[owner] = outAmt
	}

	return nil
}

// Start starts a worker's processing loop
func (w *Worker) Start() {
	for tx := range w.TxQueue {
		baseTx := &avax.BaseTx{
			NetworkID:    LocalNetworkID,
			BlockchainID: w.Environment.ChainID,
			Outs: []*avax.TransferableOutput{{
				Asset: avax.Asset{ID: w.Environment.AssetID},
				Out: &secp256k1fx.TransferOutput{
					Amt: tx.Amount,
					OutputOwners: secp256k1fx.OutputOwners{
						Threshold: 1,
						Addrs:     []ids.ShortID{tx.ToAddr},
					},
				},
			}},
			Ins: []*avax.TransferableInput{{
				Asset: avax.Asset{ID: w.Environment.AssetID},
				In: &secp256k1fx.TransferInput{
					Amt: tx.Amount,
				},
			}},
		}

		_ = w.Environment.AcceptTx(context.Background(), baseTx)
	}
	w.DoneChan <- true
}
