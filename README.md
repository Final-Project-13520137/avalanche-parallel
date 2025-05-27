# Avalanche Parallel DAG Implementation

This project implements an optimized version of the Directed Acyclic Graph (DAG) for the Avalanche consensus protocol using parallel processing. It provides significant performance improvements by leveraging multithreading and distributed processing through Kubernetes worker pods.

## Features

- **Parallel Vertex Processing**: Process multiple vertices simultaneously to improve throughput
- **Distributed Worker Pool**: Distributes processing across multiple worker instances
- **Kubernetes Integration**: Easily scale workers up or down based on demand
- **Auto-scaling**: Automatically scales the number of worker pods based on CPU/Memory utilization
- **Fault Tolerance**: Continues operation even if individual worker pods fail

## System Architecture

The system is designed as a layered architecture with core components optimized for parallel processing:

```
┌─────────────────────────────────────────────────────────────┐
│                   Avalanche Node                             │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     ParallelEngine                           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                 VertexAdapter                        │    │
│  └─────────────────────────────────────────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                       ParallelDAG                            │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                Frontier Management                   │    │
│  └─────────────────────────────────────────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    VertexProcessor                           │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Transaction Processor                   │    │
│  └─────────────────────────────────────────────────────┘    │
└───────────────────────────┬─────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                    Worker System                             │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │WorkerClient │──▶│ WorkerPool  │──▶│WorkerService│        │
│  └─────────────┘   └─────────────┘   └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                         │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐        │
│  │Worker Pod 1 │   │Worker Pod 2 │   │Worker Pod N │        │
│  └─────────────┘   └─────────────┘   └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

### Core Components

1. **ParallelEngine**
   - Acts as the interface between AvalancheGo and our parallel implementation
   - Adapts standard Avalanche vertices to ParallelVertex format
   - Manages the processing lifecycle

2. **ParallelDAG**
   - Core DAG data structure optimized for parallel processing
   - Maintains the frontier (vertices with no accepted descendants)
   - Manages vertex relationships and dependencies

3. **VertexProcessor**
   - Processes vertices in parallel using a thread pool
   - Handles transaction verification
   - Distributes processing across worker threads

4. **Worker System**
   - Scales processing across multiple nodes using a client-server architecture
   - Consists of WorkerClient, WorkerPool, and WorkerService components
   - Provides load balancing and fault tolerance

5. **Kubernetes Integration**
   - Deploys and manages worker pods
   - Auto-scales based on load
   - Ensures high availability

## Data Flow Diagram

This diagram shows how data flows through the system:

```
┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
│            │     │            │     │            │     │            │
│  Vertices  │────▶│ ParallelDAG│────▶│  Frontier  │────▶│ Processing │
│            │     │            │     │  Vertices  │     │   Queue    │
└────────────┘     └────────────┘     └────────────┘     └─────┬──────┘
                                                               │
                                                               ▼
┌────────────┐     ┌────────────┐     ┌────────────┐     ┌────────────┐
│            │     │            │     │            │     │            │
│  Results   │◀────│Worker Nodes│◀────│ Worker Pool│◀────│ Processor  │
│            │     │            │     │            │     │  Threads   │
└────────────┘     └────────────┘     └────────────┘     └────────────┘
```

## Processing Flow

The system follows this processing flow:

1. **Vertex Submission**: Vertices are submitted to the ParallelEngine
2. **Vertex Adaptation**: Standard vertices are adapted to ParallelVertex format
3. **DAG Management**: ParallelDAG adds vertices and updates the frontier
4. **Frontier Processing**: Frontier vertices are processed in parallel
5. **Task Distribution**: Processing tasks are distributed to worker threads or remote workers
6. **Parallel Execution**: Tasks are executed in parallel across multiple threads/nodes
7. **Result Collection**: Results are collected and aggregated
8. **State Update**: The DAG state is updated based on processing results

## Kubernetes Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                   Kubernetes Cluster                         │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                  Worker Deployment                   │    │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │    │
│  │  │Worker Pod│  │Worker Pod│  │Worker Pod│  ...      │    │
│  │  │    #1    │  │    #2    │  │    #3    │           │    │
│  │  └──────────┘  └──────────┘  └──────────┘           │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │            Horizontal Pod Autoscaler                │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               Worker Service                         │    │
│  └─────────────────────────────────────────────────────┘    │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              Pod Disruption Budget                   │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

Each worker pod is configured with:

- CPU and memory resource limits
- Health and readiness probes
- Environment variables for configuration
- Connection to the worker service

## System Components and Implementation

### ParallelVertex Interface

```go
// ParallelVertex extends the functionality of the base Vertex
type ParallelVertex interface {
    avalanche.Vertex
    ID() ids.ID
    GetProcessingPriority() uint64
}
```

### ParallelDAG Structure

```go
// ParallelDAG optimizes the DAG processing using parallel execution
type ParallelDAG struct {
    lock         sync.RWMutex
    logger       logging.Logger
    vertices     map[ids.ID]ParallelVertex
    edgeVertices map[ids.ID]struct{}
    frontier     map[ids.ID]ParallelVertex
    maxWorkers   int
    processor    VertexProcessor
}
```

### Worker Service API

The Worker Service exposes the following API endpoints:

- `POST /tasks`: Submit a new processing task
- `GET /tasks/{id}`: Retrieve the result of a task
- `GET /health`: Check the health of the worker service
- `GET /readiness`: Check if the worker service is ready to accept tasks

## Performance Characteristics

The parallel DAG implementation provides significant performance improvements over the sequential implementation:

- Up to 4x throughput improvement with 4 worker threads per node
- Linear scaling with additional worker nodes up to cluster capacity
- Reduced latency for transaction confirmation

## Benchmark

You can benchmark the DAG processing performance:

```bash
# Run the benchmark with 1000 vertices and 4 threads
go run ./cmd/benchmark -vertices=1000 -threads=4 -iterations=10
```

## Usage

To use the parallel DAG implementation:

```go
import (
    "github.com/avalanche-parallel-dag/pkg/consensus"
    "github.com/Final-Project-13520137/avalanche-parallel/default/utils/logging"
)

// Create a parallel engine
logger := logging.NoLog{}
parallelEngine := consensus.NewParallelEngine(logger, 4) // 4 worker threads

// Process vertices
ctx := context.Background()
parallelEngine.ProcessVertex(ctx, vertex)
```

## Configuration

Worker nodes can be configured using environment variables:

- `PORT`: HTTP port for worker API (default: 9650)
- `LOG_LEVEL`: Logging level (default: info)
- `MAX_PROCESSING_THREADS`: Number of processing threads per worker (default: 4)
- `MAX_WORKERS`: Maximum number of worker instances (default: 4)

## Dependencies

This project depends on the local avalanche-parallel codebase. Make sure it's available at the relative path:

```
../avalanche-parallel
```

The go.mod file includes a replace directive to handle this dependency:

```
replace github.com/Final-Project-13520137/avalanche-parallel => ../avalanche-parallel
```

## License

See the LICENSE file for details. 