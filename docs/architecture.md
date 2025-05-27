# Avalanche Parallel DAG Architecture

This document describes the architecture of the Avalanche Parallel DAG implementation.

## Overview

The Avalanche Parallel DAG implementation optimizes the processing of the Directed Acyclic Graph (DAG) used in the Avalanche consensus protocol. It achieves this by parallelizing the processing of vertices and distributing the workload across multiple worker nodes.

## Components

```
                                 +-------------------+
                                 |                   |
                                 |  Avalanche Node   |
                                 |                   |
                                 +--------+----------+
                                          |
                                          | Uses
                                          v
+------------------+            +-------------------+            +------------------+
|                  |            |                   |            |                  |
|  ParallelEngine  +----------->+   ParallelDAG    +----------->+ VertexProcessor  |
|                  |            |                   |            |                  |
+------------------+            +-------------------+            +--------+---------+
                                                                          |
                                                                          | Distributes tasks
                                                                          v
                               +--------------------+           +-------------------+
                               |                    |           |                   |
                               |  Worker Client     +---------->+   Worker Pool     |
                               |                    |           |                   |
                               +--------------------+           +-------------------+
                                                                          |
                                                                          | Uses
                                                                          v
+--------------------+         +--------------------+           +-------------------+
|                    |         |                    |           |                   |
| K8s Worker Pod #1  +<--------+  Worker Service   +<----------+  Worker Instances |
|                    |         |                    |           |                   |
+--------------------+         +--------------------+           +-------------------+
         |                              |                                |
         |                              |                                |
         v                              v                                v
+--------------------+         +--------------------+           +-------------------+
|                    |         |                    |           |                   |
| K8s Worker Pod #2  |         | K8s Worker Pod #3  |           | K8s Worker Pod #N |
|                    |         |                    |           |                   |
+--------------------+         +--------------------+           +-------------------+
```

## Component Descriptions

1. **ParallelEngine**: Extends the Avalanche engine with parallel processing capabilities.
   - Adapts standard Avalanche vertices to ParallelVertex format
   - Coordinates with the ParallelDAG for processing

2. **ParallelDAG**: Core implementation of the parallel DAG algorithm.
   - Manages the DAG structure
   - Tracks frontier vertices
   - Coordinates vertex processing

3. **VertexProcessor**: Processes vertices in parallel.
   - Uses worker threads to process vertices concurrently
   - Handles transaction verification and execution

4. **Worker Client**: Client for interacting with worker services.
   - Distributes tasks to remote worker services
   - Manages communication with worker pods

5. **Worker Service**: HTTP service that runs in Kubernetes.
   - Exposes API for submitting and retrieving tasks
   - Manages worker lifecycle

6. **Worker Pool**: Manages worker instances.
   - Distributes tasks to worker instances
   - Handles load balancing

7. **Worker Instances**: Individual workers that process tasks.
   - Execute vertex processing tasks
   - Run in parallel

## Workflow

1. The Avalanche node submits vertices to the ParallelEngine
2. ParallelEngine adapts vertices and submits them to ParallelDAG
3. ParallelDAG identifies frontier vertices for processing
4. VertexProcessor processes vertices in parallel using multiple threads
5. For distributed processing, tasks are sent to the Worker Client
6. Worker Client distributes tasks to Worker Service instances
7. Worker Service assigns tasks to Worker Instances
8. Worker Instances process tasks and return results
9. Results are collected and returned to the Avalanche node

## Kubernetes Deployment

The worker pods are deployed in Kubernetes with:

- Horizontal Pod Autoscaler for automatic scaling
- Pod Disruption Budget for high availability
- Service for exposing the worker API
- Deployment for managing the worker pods

This architecture enables horizontal scaling to handle increased load by adding more worker pods as needed. 