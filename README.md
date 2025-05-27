# Avalanche Parallel DAG Implementation

This project implements an optimized version of the Directed Acyclic Graph (DAG) for the Avalanche consensus protocol using parallel processing. It provides significant performance improvements by leveraging multithreading and distributed processing through Kubernetes worker pods.

## Features

- **Parallel Vertex Processing**: Process multiple vertices simultaneously to improve throughput
- **Distributed Worker Pool**: Distributes processing across multiple worker instances
- **Kubernetes Integration**: Easily scale workers up or down based on demand
- **Auto-scaling**: Automatically scales the number of worker pods based on CPU/Memory utilization
- **Fault Tolerance**: Continues operation even if individual worker pods fail

## Architecture

The system is built with the following components:

1. **ParallelDAG**: Core optimization of the DAG algorithm that supports parallel processing
2. **VertexProcessor**: Processes DAG vertices in parallel using worker threads
3. **WorkerPool**: Manages a pool of worker instances for distributed processing
4. **Worker Service**: HTTP service that runs in Kubernetes and processes vertex tasks

## Deployment

The system is designed to be deployed in a Kubernetes cluster:

```bash
# Deploy the worker service
kubectl apply -f deployments/kubernetes/worker.yaml
```

This will create:
- A Deployment with multiple worker pods
- A Service to expose the worker API
- A HorizontalPodAutoscaler to automatically scale based on load
- A PodDisruptionBudget to ensure high availability

## Performance

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