# Blockchain Test Suite

This repository contains comprehensive tests for the Avalanche Parallel Blockchain implementation. The tests cover various aspects of the blockchain functionality, with a focus on transaction handling and parallel processing.

## Test Categories

### Unit Tests

Unit tests cover individual components of the blockchain:

1. **Transaction Tests** (`pkg/blockchain/transaction_test.go`)
   - Transaction creation and validation
   - Transaction signing and verification
   - Transaction dependencies and status management

2. **Block Tests** (`pkg/blockchain/block_test.go`)
   - Block creation and validation
   - Block status transitions
   - Transaction inclusion in blocks
   - Block height and processing priority

3. **Blockchain Tests** (`pkg/blockchain/blockchain_test.go`)
   - Blockchain initialization with genesis block
   - Transaction addition to mempool
   - Block creation with transactions
   - Blockchain consensus processing

### Integration Tests

Integration tests (`pkg/blockchain/integration_test.go`) test the complete flow of the blockchain:

1. **Full Blockchain Flow Test**
   - Transaction creation → Transaction submission → Block creation → Consensus → Block acceptance

2. **Fork Resolution Test**
   - Tests the blockchain's ability to handle competing chains and resolve forks according to Avalanche consensus

3. **Double Spend Test**
   - Tests how the blockchain handles double-spend transactions in different blocks

4. **High Load Test**
   - Tests the blockchain under high transaction load

5. **Parallel Consensus Test**
   - Benchmarks parallel processing against sequential processing to verify performance improvements

## Load Testing Tool

A comprehensive load testing tool is provided in `scripts/transaction_load_test.go` to test the blockchain under various transaction conditions:

1. **Normal Transactions**
   - Regular transactions with standard values

2. **Double Spend Attempts**
   - Transactions attempting to double-spend with the same nonce

3. **High Value Transactions**
   - Transactions with very large values

4. **Micro Transactions**
   - Transactions with very small values

5. **Transaction Bursts**
   - Periods of high-frequency transaction submissions

## Running the Tests

### Using Test Scripts

Two scripts are provided to run the tests easily:

1. **For Linux/macOS:**
   ```bash
   ./scripts/run_blockchain_tests.sh
   ```

2. **For Windows:**
   ```powershell
   .\scripts\run_blockchain_tests.ps1
   ```

To run performance benchmark tests, add the `--benchmark` flag:
```bash
./scripts/run_blockchain_tests.sh --benchmark
```

### Running Tests Manually

You can also run specific tests manually:

```bash
# Run all tests
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain

# Run specific test category
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestTransaction
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestBlock
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestBlockchain
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestFull
```

### Running the Load Testing Tool

To run the load testing tool:

```bash
go run scripts/transaction_load_test.go
```

This will simulate various transaction patterns and test the blockchain's ability to handle them.

## Test Configuration

The load testing tool can be configured by modifying constants at the top of the file:

```go
const (
    numUsers               = 50
    numTransactions        = 1000
    maxConcurrentSubmit    = 100
    transactionDelayMs     = 5
    doubleSpendProbability = 0.05
    blockInterval          = 1 * time.Second
    largeValueProbability  = 0.1
    microValueProbability  = 0.1
    runTime                = 2 * time.Minute
)
```

## Dependencies

These tests depend on:
- Go 1.19 or higher
- Access to the avalanche-parallel codebase (configured via AVALANCHE_PARALLEL_PATH environment variable)
- The testify package for assertions (`github.com/stretchr/testify`)

## Test Output

The tests produce detailed output about transaction processing, block creation, and consensus outcomes. Watch for:

- Block acceptance/rejection
- Transaction status changes
- Fork resolution
- Performance metrics for parallel processing

When running the load testing tool, you'll see statistics about different transaction types, including counts and processing times. 