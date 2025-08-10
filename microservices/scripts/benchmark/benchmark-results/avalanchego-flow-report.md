# AvalancheGo Monolithic Flow System Test Report

**Generated**: Sun Jul 27 20:31:22 WIB 2025  
**Duration**: 60 seconds  
**Workers**: 3  
**Test Type**: flow

## System Architecture Flow (Sesuai Diagram)

```
📝 Client Request         (Transaction submission)
     ↓
🔍 API Server Validation  (Request validation)
     ↓  
📨 Mempool Queue         (Transaction queuing)
     ↓
⚡ Consensus Engine      (Vertex Builder + Sequential Steps)
   └── Vertex Builder: Parents, Txs, Height
   └── Sequential Steps:
       1. Get transactions
       2. Verify signatures
       3. Check dependencies
       4. Build vertex
       5. Calculate hash
     ↓
❄️ Snowman Consensus     (Sequential Voting ~100ms)
   └── Sequential Voting:
       1. Query k random validators
       2. Collect responses
       3. Update confidence
       4. Repeat until finalized
     ↓
💾 State Manager         (Sequential Updates ~50ms)
   └── Sequential Updates:
       1. Apply transactions
       2. Update UTXO set
       3. Update balances
       4. Execute smart contracts
       5. Commit state changes
```

## Test Results

### AvalancheGo Flow System Tests

**Overall**: 0/6 tests passed

- **API SERVER VALIDATION**: failed
- **MEMPOOL QUEUE**: failed
- **CONSENSUS ENGINE**: failed
- **SNOWMAN CONSENSUS**: failed
- **STATE MANAGER**: failed
- **END TO END FLOW**: failed

## Timing Analysis

- **Consensus Engine**: ~100ms per vertex (as per diagram)
- **State Manager**: ~50ms per vertex (as per diagram)
- **Total Flow Latency**: ~152ms end-to-end

## Files Generated

- `benchmark-results/avalanchego-flow-report.md` - This report
- `benchmark-results/avalanchego-output.log` - System output logs
- `benchmark-results/flow-test/avalanchego-results.json` - Flow test results
- `benchmark-results/avalanchego-performance.json` - Performance metrics
