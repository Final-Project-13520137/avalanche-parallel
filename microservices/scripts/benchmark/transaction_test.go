package benchmark

import (
	"context"
	"fmt"
	"testing"

	"github.com/ava-labs/avalanchego/ids"
	"github.com/ava-labs/avalanchego/vms/components/avax"
	"github.com/ava-labs/avalanchego/vms/secp256k1fx"
	"github.com/stretchr/testify/assert"
)

func TestGenerateTransactions(t *testing.T) {
	count := 10
	txs := generateTestTransactions(count)
	assert.Equal(t, count, len(txs))

	// Verify each transaction
	for i, tx := range txs {
		assert.Equal(t, uint64(1000000+i), tx.Amount)
		assert.NotEmpty(t, tx.FromAddr)
		assert.NotEmpty(t, tx.ToAddr)
		assert.NotEqual(t, tx.FromAddr, tx.ToAddr)
	}
}

func TestMonolithicPayment(t *testing.T) {
	ctx := context.Background()
	txCount := 10
	testTxs := generateTestTransactions(txCount)
	env := setupMonolithicTestEnv()

	// Process transactions
	for _, tx := range testTxs {
		baseTx := &avax.BaseTx{
			NetworkID:    LocalNetworkID,
			BlockchainID: env.ChainID,
			Outs: []*avax.TransferableOutput{{
				Asset: avax.Asset{ID: env.AssetID},
				Out: &secp256k1fx.TransferOutput{
					Amt: tx.Amount,
					OutputOwners: secp256k1fx.OutputOwners{
						Threshold: 1,
						Addrs:     []ids.ShortID{tx.ToAddr},
					},
				},
			}},
			Ins: []*avax.TransferableInput{{
				Asset: avax.Asset{ID: env.AssetID},
				In: &secp256k1fx.TransferInput{
					Amt: tx.Amount,
				},
			}},
		}

		err := env.AcceptTx(ctx, baseTx)
		assert.NoError(t, err)
	}
}

func TestParallelPayment(t *testing.T) {
	ctx := context.Background()
	txCount := 10
	workerCount := 4
	testTxs := generateTestTransactions(txCount)
	env := setupParallelTestEnv(workerCount)

	// Create channels
	txChan := make(chan TestTx, txCount)
	doneChan := make(chan bool, workerCount)

	// Start workers
	for w := 0; w < workerCount; w++ {
		go func() {
			for tx := range txChan {
				baseTx := &avax.BaseTx{
					NetworkID:    LocalNetworkID,
					BlockchainID: env.ChainID,
					Outs: []*avax.TransferableOutput{{
						Asset: avax.Asset{ID: env.AssetID},
						Out: &secp256k1fx.TransferOutput{
							Amt: tx.Amount,
							OutputOwners: secp256k1fx.OutputOwners{
								Threshold: 1,
								Addrs:     []ids.ShortID{tx.ToAddr},
							},
						},
					}},
					Ins: []*avax.TransferableInput{{
						Asset: avax.Asset{ID: env.AssetID},
						In: &secp256k1fx.TransferInput{
							Amt: tx.Amount,
						},
					}},
				}

				err := env.AcceptTx(ctx, baseTx)
				assert.NoError(t, err)
			}
			doneChan <- true
		}()
	}

	// Send transactions
	for _, tx := range testTxs {
		txChan <- tx
	}
	close(txChan)

	// Wait for completion
	for w := 0; w < workerCount; w++ {
		<-doneChan
	}
}

func generateTestTransactions(count int) []TestTx {
	transactions := make([]TestTx, count)

	// Generate addresses for testing
	for i := 0; i < count; i++ {
		fromAddr := ids.GenerateTestShortID()
		toAddr := ids.GenerateTestShortID()

		transactions[i] = TestTx{
			Amount:   uint64(1000000 + i), // Different amounts for each tx
			FromAddr: fromAddr,
			ToAddr:   toAddr,
		}
	}

	return transactions
}

func BenchmarkMonolithicPayment(b *testing.B) {
	ctx := context.Background()
	txCount := 1000 // Number of transactions to test

	// Generate test transactions
	testTxs := generateTestTransactions(txCount)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		// Setup monolithic environment
		env := setupMonolithicTestEnv()
		b.StartTimer()

		// Process transactions in monolithic mode
		for _, tx := range testTxs {
			baseTx := &avax.BaseTx{
				NetworkID:    LocalNetworkID,
				BlockchainID: env.ChainID,
				Outs: []*avax.TransferableOutput{{
					Asset: avax.Asset{ID: env.AssetID},
					Out: &secp256k1fx.TransferOutput{
						Amt: tx.Amount,
						OutputOwners: secp256k1fx.OutputOwners{
							Threshold: 1,
							Addrs:     []ids.ShortID{tx.ToAddr},
						},
					},
				}},
				Ins: []*avax.TransferableInput{{
					Asset: avax.Asset{ID: env.AssetID},
					In: &secp256k1fx.TransferInput{
						Amt: tx.Amount,
					},
				}},
			}

			if err := env.AcceptTx(ctx, baseTx); err != nil {
				b.Fatal(err)
			}
		}
	}
}

func BenchmarkParallelPayment(b *testing.B) {
	ctx := context.Background()
	txCount := 1000  // Number of transactions to test
	workerCount := 4 // Number of parallel workers

	// Generate test transactions
	testTxs := generateTestTransactions(txCount)

	b.ResetTimer()
	for i := 0; i < b.N; i++ {
		b.StopTimer()
		// Setup parallel environment
		env := setupParallelTestEnv(workerCount)
		b.StartTimer()

		// Create channels for parallel processing
		txChan := make(chan TestTx, txCount)
		doneChan := make(chan bool, workerCount)

		// Start worker goroutines
		for w := 0; w < workerCount; w++ {
			go func() {
				for tx := range txChan {
					baseTx := &avax.BaseTx{
						NetworkID:    LocalNetworkID,
						BlockchainID: env.ChainID,
						Outs: []*avax.TransferableOutput{{
							Asset: avax.Asset{ID: env.AssetID},
							Out: &secp256k1fx.TransferOutput{
								Amt: tx.Amount,
								OutputOwners: secp256k1fx.OutputOwners{
									Threshold: 1,
									Addrs:     []ids.ShortID{tx.ToAddr},
								},
							},
						}},
						Ins: []*avax.TransferableInput{{
							Asset: avax.Asset{ID: env.AssetID},
							In: &secp256k1fx.TransferInput{
								Amt: tx.Amount,
							},
						}},
					}

					if err := env.AcceptTx(ctx, baseTx); err != nil {
						b.Error(err)
					}
				}
				doneChan <- true
			}()
		}

		// Send transactions to workers
		for _, tx := range testTxs {
			txChan <- tx
		}
		close(txChan)

		// Wait for all workers to complete
		for w := 0; w < workerCount; w++ {
			<-doneChan
		}
	}
}

func BenchmarkParallelPaymentWithDifferentWorkers(b *testing.B) {
	workerCounts := []int{1, 2, 4, 8, 16}
	txCounts := []int{1000, 5000, 10000}

	for _, txCount := range txCounts {
		for _, workers := range workerCounts {
			b.Run(fmt.Sprintf("Workers_%d_Tx_%d", workers, txCount), func(b *testing.B) {
				ctx := context.Background()
				testTxs := generateTestTransactions(txCount)

				b.ResetTimer()
				for i := 0; i < b.N; i++ {
					b.StopTimer()
					env := setupParallelTestEnv(workers)
					b.StartTimer()

					txChan := make(chan TestTx, txCount)
					doneChan := make(chan bool, workers)

					// Start workers
					for w := 0; w < workers; w++ {
						go func() {
							for tx := range txChan {
								baseTx := &avax.BaseTx{
									NetworkID:    LocalNetworkID,
									BlockchainID: env.ChainID,
									Outs: []*avax.TransferableOutput{{
										Asset: avax.Asset{ID: env.AssetID},
										Out: &secp256k1fx.TransferOutput{
											Amt: tx.Amount,
											OutputOwners: secp256k1fx.OutputOwners{
												Threshold: 1,
												Addrs:     []ids.ShortID{tx.ToAddr},
											},
										},
									}},
									Ins: []*avax.TransferableInput{{
										Asset: avax.Asset{ID: env.AssetID},
										In: &secp256k1fx.TransferInput{
											Amt: tx.Amount,
										},
									}},
								}

								if err := env.AcceptTx(ctx, baseTx); err != nil {
									b.Error(err)
								}
							}
							doneChan <- true
						}()
					}

					// Send transactions
					for _, tx := range testTxs {
						txChan <- tx
					}
					close(txChan)

					// Wait for completion
					for w := 0; w < workers; w++ {
						<-doneChan
					}
				}
			})
		}
	}
}
