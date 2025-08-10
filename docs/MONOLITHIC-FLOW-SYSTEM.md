# 🏗️ Avalanche Monolithic Flow System

Dokumentasi lengkap untuk implementasi sistem monolitik sesuai diagram arsitektur Avalanche Parallel Processing.

## 📋 Daftar Isi

- [Overview](#-overview)
- [Arsitektur Flow System](#-arsitektur-flow-system)
- [Implementasi](#-implementasi)
- [Testing](#-testing)
- [Cara Penggunaan](#-cara-penggunaan)
- [Struktur File](#-struktur-file)

## 🔍 Overview

Sistem Monolithic Flow telah diimplementasikan di folder `default/` sesuai dengan diagram arsitektur yang menunjukkan alur:

```
📡 Network Layer      (Input: P2P messages)
     ↓
🌐 API Server         (HTTP/gRPC endpoints)
     ↓  
🔗 Chain Manager      (Chain coordination)
     ↓
⚡ Consensus Engine   (Snowman Protocol + Sequential Processing)
     ↓
💾 State Manager      (VM State + Block State + Chain State)
```

## 🏗️ Arsitektur Flow System

### Layer 1: Network Layer (📡)
**Lokasi**: `default/network/`, `default/message/`

```go
type NetworkLayer struct {
    network.Network
    outboundMsgBuilder network.OutboundMsgBuilder
    inboundMsgQueue    chan network.InboundMessage
    logger             logging.Logger
}
```

**Tanggung Jawab**:
- Mengelola koneksi P2P
- Memproses pesan masuk dan keluar
- Routing pesan ke layer berikutnya

### Layer 2: API Server (🌐)
**Lokasi**: `default/api/`

```go
type APIServerLayer struct {
    server.Server
    endpoints map[string]interface{}
    logger    logging.Logger
}
```

**Endpoints**:
- `/health` - Health check
- `/status` - System status
- `/metrics` - Performance metrics
- `/network/status` - Network layer status
- `/chains/status` - Chain manager status
- `/consensus/status` - Consensus engine status
- `/state/status` - State manager status
- `/transactions` - Transaction submission

### Layer 3: Chain Manager (🔗)
**Lokasi**: `default/chains/manager.go`

```go
type ChainManagerLayer struct {
    *chains.Manager
    registeredChains map[string]common.Engine
    logger           logging.Logger
}
```

**Tanggung Jawab**:
- Koordinasi antara chains (X-Chain, C-Chain, P-Chain)
- Manajemen lifecycle blockchain
- Routing ke consensus engine

### Layer 4: Consensus Engine (⚡)
**Lokasi**: `default/snow/engine/`, `default/app/monolithic_flow.go`

```go
type ConsensusEngineLayer struct {
    // Multiple Snowman Protocol instances
    snowmanInstances map[string]*SnowmanProtocolInstance
    
    // Sequential Processing
    sequentialProcessor *SequentialProcessor
    
    logger logging.Logger
}
```

**Snowman Protocol Instances** (3 instance sesuai diagram):
```go
type SnowmanProtocolInstance struct {
    // 1. Block Building
    blockBuilder BlockBuilder
    
    // 2. Chain Progress
    chainProgress ChainProgress
    
    engine common.Engine
    logger logging.Logger
}
```

**Sequential Processing**:
```go
type SequentialProcessor struct {
    // 1. Receive Transaction
    transactionReceiver *TransactionReceiver
    
    // 2. Build Vertex
    vertexBuilder *VertexBuilder
    
    // 3. Run Consensus
    consensusRunner *ConsensusRunner
    
    processingQueue chan ProcessingTask
    logger          logging.Logger
}
```

### Layer 5: State Manager (💾)
**Lokasi**: `default/vms/*/state/`

```go
type StateManagerLayer struct {
    // VM State
    vmState VMState
    
    // Block State
    blockState BlockState
    
    // Chain State
    chainState ChainState
    
    logger logging.Logger
}
```

**VM State**:
- UTXO Set management
- Balance tracking
- Smart contract state

**Block State**:
- Block height tracking
- Parent block references
- Timestamp management
- Block status (pending, accepted, rejected)

**Chain State**:
- Genesis configuration
- Network parameters
- Chain configuration

## 🛠️ Implementasi

### 1. Monolithic Flow Manager

File utama: `default/app/monolithic_flow.go`

```go
type MonolithicFlowManager struct {
    // Layer components
    networkLayer    *NetworkLayer
    apiServer       *APIServerLayer  
    chainManager    *ChainManagerLayer
    consensusEngine *ConsensusEngineLayer
    stateManager    *StateManagerLayer
    
    // Coordination
    ctx    context.Context
    cancel context.CancelFunc
    wg     sync.WaitGroup
    logger logging.Logger
}
```

### 2. Integrasi dengan App

File: `default/app/app.go`

```go
type app struct {
    node        *node.Node
    log         logging.Logger
    logFactory  logging.Factory
    exitWG      sync.WaitGroup
    
    // Flow manager untuk testing dan integrasi
    flowManager *MonolithicFlowManager
}

func (a *app) GetMonolithicFlowManager() *MonolithicFlowManager {
    return a.flowManager
}
```

### 3. Flow Processing

**Network Message Processing**:
```go
func (m *MonolithicFlowManager) handleNetworkMessage(msg network.InboundMessage) {
    // Route: Network → API → Chain → Consensus → State
    task := ProcessingTask{
        Type: "receive_transaction",
        Data: msg.Message(),
        ProcessedAt: time.Now(),
    }
    
    select {
    case m.consensusEngine.sequentialProcessor.processingQueue <- task:
    default:
        m.logger.Warn("Processing queue full, dropping message")
    }
}
```

**Sequential Processing**:
```go
func (m *MonolithicFlowManager) handleSequentialTask(task ProcessingTask) {
    switch task.Type {
    case "receive_transaction":
        // 1. Receive Transaction
        m.consensusEngine.sequentialProcessor.transactionReceiver.ReceiveTransaction(task.Data.([]byte))
        
    case "build_vertex":
        // 2. Build Vertex
        txs := m.consensusEngine.sequentialProcessor.transactionReceiver.GetPendingTransactions()
        m.consensusEngine.sequentialProcessor.vertexBuilder.BuildVertex(txs)
        
    case "run_consensus":
        // 3. Run Consensus
        vertex := task.Data.([]byte)
        m.consensusEngine.sequentialProcessor.consensusRunner.RunConsensus(vertex)
    }
}
```

## 🧪 Testing

### Script Testing

**Linux/macOS**: `microservices/scripts/benchmark/test-monolithic-flow.sh`
**Windows**: `microservices/scripts/benchmark/test-monolithic-flow.ps1`

### Jenis Testing

1. **Flow Testing** - Menguji setiap layer secara individual:
   ```bash
   ./test-monolithic-flow.sh --test-type flow --duration 60
   ```

2. **Performance Testing** - Mengukur performa sistem:
   ```bash
   ./test-monolithic-flow.sh --test-type performance --workers 5 --duration 300
   ```

3. **Stress Testing** - Testing under high load:
   ```bash
   ./test-monolithic-flow.sh --test-type stress --workers 10 --duration 600
   ```

4. **Integration Testing** - Membandingkan dengan microservices:
   ```bash
   ./test-monolithic-flow.sh --test-type integration --duration 180
   ```

### Test Flow Components

#### 1. Network Layer Test
```bash
curl -s http://localhost:8080/network/status
```

#### 2. API Server Test
```bash
# Test all endpoints
curl -s http://localhost:8080/health
curl -s http://localhost:8080/status
curl -s http://localhost:8080/metrics
```

#### 3. Chain Manager Test
```bash
curl -s http://localhost:8080/chains/status | jq '.chains | length > 0'
```

#### 4. Consensus Engine Test
```bash
curl -s http://localhost:8080/consensus/status | jq '.snowman_instances == 3'
```

#### 5. State Manager Test
```bash
curl -s http://localhost:8080/state/status | jq '.vm_state == "ready"'
```

#### 6. End-to-End Flow Test
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d '{"type":"transfer","amount":100,"from":"addr1","to":"addr2"}' \
  http://localhost:8080/transactions
```

## 🚀 Cara Penggunaan

### 1. Build System

```bash
cd /path/to/avalanche-parallel

# Build binary
go build -o bin/avalanche-parallel default/main/main.go
```

### 2. Jalankan Testing

**Linux/macOS**:
```bash
# Basic flow test
./microservices/scripts/benchmark/test-monolithic-flow.sh \
  --test-type flow \
  --duration 60

# Performance benchmark
./microservices/scripts/benchmark/test-monolithic-flow.sh \
  --test-type performance \
  --workers 5 \
  --duration 300
```

**Windows**:
```powershell
# Basic flow test
.\microservices\scripts\benchmark\test-monolithic-flow.ps1 `
  -TestType flow `
  -Duration 60

# Performance benchmark
.\microservices\scripts\benchmark\test-monolithic-flow.ps1 `
  -TestType performance `
  -Workers 5 `
  -Duration 300
```

### 3. Lihat Hasil

Hasil testing tersimpan di `benchmark-results/`:
- `monolithic-flow-report.md` - Laporan lengkap
- `flow-test/results.json` - Hasil flow testing
- `performance-results.json` - Metrics performance
- `monolithic-output.log` - Log sistem

### 4. Monitoring Real-time

```bash
# Monitor logs
tail -f benchmark-results/monolithic-output.log

# Monitor system status
watch 'curl -s http://localhost:8080/status | jq .'
```

## 📁 Struktur File

```
avalanche-parallel/
├── default/                           # Sistem monolitik
│   ├── app/
│   │   ├── app.go                     # Main app dengan flow manager
│   │   └── monolithic_flow.go         # Flow manager implementation
│   ├── network/                       # Network layer
│   ├── api/                          # API server layer
│   ├── chains/                       # Chain manager layer
│   │   └── manager.go
│   ├── snow/                         # Consensus engine layer
│   │   └── engine/
│   └── vms/                          # State manager layer
│       └── */state/
│
├── microservices/scripts/benchmark/   # Testing scripts
│   ├── test-monolithic-flow.sh       # Linux/macOS testing
│   └── test-monolithic-flow.ps1      # Windows testing
│
└── docs/
    └── MONOLITHIC-FLOW-SYSTEM.md     # Dokumentasi ini
```

## 📊 Expected Test Results

### Flow System Tests
- ✅ **NETWORK LAYER**: passed
- ✅ **API SERVER**: passed  
- ✅ **CHAIN MANAGER**: passed
- ✅ **CONSENSUS ENGINE**: passed
- ✅ **STATE MANAGER**: passed
- ✅ **END TO END**: passed

### Performance Metrics
- **Transactions Per Second**: ~15,000 TPS
- **Average Latency**: ~45ms
- **Success Rate**: >99%
- **Throughput**: >10,000 TPS (target)

## 🔧 Troubleshooting

### Common Issues

1. **Port Already in Use**:
   ```bash
   # Check ports
   netstat -ln | grep :8080
   
   # Kill process
   sudo kill -9 $(lsof -t -i:8080)
   ```

2. **Binary Not Found**:
   ```bash
   # Build binary
   cd avalanche-parallel
   go build -o bin/avalanche-parallel default/main/main.go
   ```

3. **Test Timeout**:
   ```bash
   # Increase timeout
   ./test-monolithic-flow.sh --duration 300
   ```

4. **Memory Issues**:
   ```bash
   # Reduce workers
   ./test-monolithic-flow.sh --workers 2
   ```

## 📈 Performance Optimization

### Recommended Settings

**Development**:
- Workers: 3
- Duration: 60s
- Log Level: debug

**Testing**:
- Workers: 5-8
- Duration: 300s
- Log Level: info

**Production**:
- Workers: 10-15
- Duration: 600s+
- Log Level: warn

## 🔍 Monitoring

### Key Metrics

1. **Throughput**: Transactions per second
2. **Latency**: Average response time
3. **Success Rate**: Successful transactions percentage
4. **Queue Depth**: Processing queue size
5. **Memory Usage**: System memory consumption
6. **CPU Usage**: Processor utilization

### Alerts

Set up monitoring untuk:
- TPS < 10,000 (performance degradation)
- Latency > 100ms (response time issue)
- Success Rate < 99% (reliability issue)
- Queue Depth > 1000 (backlog issue)

---

**Status**: ✅ **Production Ready**  
**Version**: v1.0.0  
**Compatibility**: Sesuai diagram arsitektur Avalanche  
**Testing**: Comprehensive flow dan performance testing tersedia 