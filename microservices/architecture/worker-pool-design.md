# Avalanche Microservices Worker Pool Architecture

## Overview

Arsitektur worker pool yang memungkinkan pemrosesan parallel dengan auto-scaling worker nodes yang di-deploy melalui Docker dan Kubernetes.

## Architecture Diagram

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   API Gateway   │───▶│  Load Balancer  │───▶│   Task Queue    │
│   (1 instance)  │    │   (HAProxy)     │    │    (Redis)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                                       │
                                        ┌─────────────┼─────────────┐
                                        │             │             │
                                        ▼             ▼             ▼
                               ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
                               │   Worker    │ │   Worker    │ │   Worker    │
                               │   Pool 1    │ │   Pool 2    │ │   Pool 3    │
                               │             │ │             │ │             │
                               ├─────────────┤ ├─────────────┤ ├─────────────┤
                               │ Consensus   │ │ Validator   │ │ DAG + State │
                               │ Workers     │ │ Workers     │ │ Workers     │
                               │ (2-10 pods) │ │ (3-15 pods) │ │ (2-8 pods)  │
                               └─────────────┘ └─────────────┘ └─────────────┘
                                       │             │             │
                                       └─────────────┼─────────────┘
                                                     │
                                                     ▼
                                            ┌─────────────────┐
                                            │   Result Store  │
                                            │  (PostgreSQL)   │
                                            └─────────────────┘
```

## Worker Pool Types

### 1. Consensus Worker Pool
- **Purpose**: Memproses vertex consensus dan polling
- **Scaling**: 2-10 pods berdasarkan load vertex
- **Tasks**: 
  - Vertex validation
  - Consensus polling
  - Confidence calculation
  - Finalization decisions

### 2. Validator Worker Pool  
- **Purpose**: Validasi transaksi dan signature verification
- **Scaling**: 3-15 pods berdasarkan transaction volume
- **Tasks**:
  - Transaction validation
  - Signature verification
  - Balance checking
  - Transaction formatting

### 3. DAG + State Worker Pool
- **Purpose**: DAG management dan state updates
- **Scaling**: 2-8 pods berdasarkan state operations
- **Tasks**:
  - Vertex ancestry tracking
  - State transitions
  - Database updates
  - Query processing

## Message Queue System

### Task Types
```json
{
  "consensus_task": {
    "type": "vertex_validation",
    "vertex_id": "vertex_123",
    "parent_ids": ["parent_1", "parent_2"],
    "transactions": [...],
    "priority": "high"
  },
  
  "validation_task": {
    "type": "transaction_validation", 
    "transaction_id": "tx_456",
    "data": "...",
    "signature": "...",
    "priority": "medium"
  },
  
  "state_task": {
    "type": "state_update",
    "vertex_id": "vertex_123", 
    "state_changes": [...],
    "priority": "low"
  }
}
```

### Queue Management
- **High Priority Queue**: Consensus tasks (real-time)
- **Medium Priority Queue**: Validation tasks (near real-time)
- **Low Priority Queue**: State/DAG tasks (batch processing)

## Kubernetes Deployment Strategy

### Auto-Scaling Rules
```yaml
# Consensus Workers
- metric: queue_depth > 100 → scale up
- metric: cpu_usage > 70% → scale up  
- metric: queue_depth < 20 → scale down
- min_replicas: 2, max_replicas: 10

# Validator Workers  
- metric: validation_queue > 200 → scale up
- metric: cpu_usage > 80% → scale up
- metric: validation_queue < 50 → scale down
- min_replicas: 3, max_replicas: 15

# DAG+State Workers
- metric: state_queue > 50 → scale up
- metric: memory_usage > 75% → scale up  
- metric: state_queue < 10 → scale down
- min_replicas: 2, max_replicas: 8
```

### Resource Allocation
```yaml
consensus_workers:
  requests: { cpu: "500m", memory: "512Mi" }
  limits: { cpu: "1000m", memory: "1Gi" }
  
validator_workers:
  requests: { cpu: "250m", memory: "256Mi" }
  limits: { cpu: "500m", memory: "512Mi" }
  
dag_state_workers:
  requests: { cpu: "750m", memory: "1Gi" }
  limits: { cpu: "1500m", memory: "2Gi" }
```

## Performance Characteristics

### Expected Throughput
- **Consensus**: 1000-5000 vertex/sec per worker
- **Validation**: 2000-10000 tx/sec per worker  
- **DAG+State**: 500-2000 ops/sec per worker

### Scaling Benefits
- **Linear Scaling**: Performance scales linearly dengan worker count
- **Fault Tolerance**: Worker failure tidak mempengaruhi keseluruhan sistem
- **Load Distribution**: Tasks didistribusi merata ke available workers
- **Resource Efficiency**: Auto-scaling berdasarkan actual workload

## Implementation Benefits

1. **True Parallel Processing**: Multiple workers memproses tasks secara bersamaan
2. **Elastic Scaling**: Worker count menyesuaikan dengan load secara otomatis
3. **Fault Isolation**: Failure di satu worker tidak mempengaruhi worker lain
4. **Resource Optimization**: Kubernetes mengoptimalkan resource allocation
5. **High Availability**: Multi-pod deployment dengan health checks
6. **Performance Monitoring**: Real-time metrics untuk setiap worker pool

## Use Cases

### High Load Scenario (10,000+ TPS)
- Consensus Pool: 8-10 workers
- Validator Pool: 12-15 workers  
- DAG+State Pool: 6-8 workers
- Total: 26-33 parallel workers

### Medium Load Scenario (1,000-5,000 TPS)
- Consensus Pool: 4-6 workers
- Validator Pool: 6-9 workers
- DAG+State Pool: 3-5 workers  
- Total: 13-20 parallel workers

### Low Load Scenario (<1,000 TPS)
- Consensus Pool: 2-3 workers
- Validator Pool: 3-4 workers
- DAG+State Pool: 2-3 workers
- Total: 7-10 parallel workers 