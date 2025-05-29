# Avalanche Parallel DAG

## Project Structure

The project has been reorganized into a more modular structure:

```
avalanche-parallel/
├── bin/                # Executable binaries
├── cmd/                # Command line applications
│   ├── avalanche/      # Main Avalanche node implementation
│   ├── benchmark/      # Benchmarking tools
│   ├── blockchain/     # Blockchain CLI tools
│   └── worker/         # Worker node implementation
├── config/             # Configuration files
│   ├── docker-compose.yml
│   └── temp-docker-compose.yml
├── default/            # Avalanche core fork (from avalanchego)
├── deployments/        # Deployment configurations
│   ├── docker/         # Docker deployment files
│   ├── grafana/        # Grafana dashboards and configurations
│   ├── kubernetes/     # Kubernetes deployment files
│   └── prometheus/     # Prometheus configuration
├── docs/               # Documentation
├── fixer/              # Fix scripts for compatibility issues
│   ├── fix-go-version.ps1  # Fix Go version in go.mod
│   ├── fix-go-compatibility.ps1  # Fix Go compatibility issues
│   └── ...
├── gomod-backups/      # Backup of go.mod files
├── logs/               # Log files
├── pkg/                # Core packages
│   ├── blockchain/     # Blockchain implementation
│   ├── consensus/      # Consensus algorithms
│   ├── scripts/        # Utility scripts
│   ├── test/           # Test utilities
│   ├── utils/          # Utility packages
│   │   ├── compatibility/  # Go compatibility utilities
│   │   ├── logging/        # Logging utilities
│   │   ├── math/           # Math utilities
│   │   ├── sampler/        # Sampling utilities
│   │   └── set/            # Set data structure
│   └── worker/         # Worker node implementation
├── scripts/            # Helper scripts
└── utils/              # Top-level utilities
```

# Avalanche Parallel DAG Implementation

<div align="center">

```mermaid
flowchart TD
    %% System Layers Division
    subgraph "High-Level Architecture"
        subgraph "System Components"
            API[API Gateway]:::controller
            MN[Avalanche Main Node]:::mainNode
            QB[Queue Balancer]:::controller
            
            KO[Kubernetes Orchestration]:::k8s
            MON[Monitoring System]:::monitoring
            
            MN <--> API
            API <--> QB
            KO --> MN
            KO --> WL
            MON --> MN
            MON --> WL
        end
        
        subgraph "WL: Worker Layer"
            W1[Worker Pod 1]:::workerNode
            W2[Worker Pod 2]:::workerNode
            W3[Worker Pod N]:::workerNode
            
            QB <--> W1 & W2 & W3
        end
    end
    
    %% Mid-Level Architecture
    subgraph "Mid-Level Implementation"
        subgraph "Main Node Components"
            subgraph "Consensus Engine" 
                DAG[DAG Manager]:::component
                VP[Vertex Processor]:::component
                DM[Dependency Manager]:::component
                TS[Transaction Scheduler]:::component
                
                DAG <--> VP
                VP <--> DM
                DM <--> TS
            end
            
            subgraph "Storage Systems"
                DB[(Transaction DB)]:::storage
                FS[(File System)]:::storage
                MQ[(Message Queue)]:::storage
            end
            
            CE[Consensus Engine] --> Storage
            MN --- CE
            MN --- Storage
        end
        
        subgraph "Monitoring Stack"
            PROM[Prometheus]:::monitoring
            GRAF[Grafana]:::monitoring
            ALERT[Alertmanager]:::monitoring
            
            PROM --> GRAF
            PROM --> ALERT
        end
        
        subgraph "Kubernetes Resources"
            HPA[Horizontal Pod Autoscaler]:::k8s
            SC[Service Controller]:::k8s
            PVC[Persistent Volume Claims]:::k8s
            SVC[Services]:::k8s
        end
    end
    
    %% Low-Level Implementation
    subgraph "Low-Level Implementation"
        subgraph "Worker Internals"
            subgraph "Thread Management"
                WM[Worker Manager]:::component
                T1[Thread 1]:::thread
                T2[Thread 2]:::thread
                T3[Thread 3]:::thread
                TN[Thread N]:::thread
                
                WM --> T1 & T2 & T3 & TN
            end
            
            subgraph "Memory Structures"
                VTXQ[Vertex Queue]:::data
                MEMPL[Memory Pool]:::data
                LCK[Lock Manager]:::data
                
                T1 & T2 & T3 & TN --> VTXQ
                T1 & T2 & T3 & TN --> MEMPL
                T1 & T2 & T3 & TN --> LCK
            end
            
            subgraph "Parallel Processing"
                VTX[Vertex Processing]:::process
                TXVLD[Transaction Validation]:::process
                SIGN[Signature Verification]:::process
                DEPS[Dependency Resolution]:::process
                
                T1 & T2 & T3 & TN --> VTX & TXVLD & SIGN & DEPS
            end
        end
        
        subgraph "Data Structures"
            subgraph "DAG Components"
                VTXS[Vertices]:::data
                EDGES[Edges]:::data
                FRNT[Frontier]:::data
                
                VTXS <--> EDGES
                EDGES --> FRNT
            end
            
            subgraph "Transaction Format"
                HEADER[TX Header]:::data
                PAYLOAD[TX Payload]:::data
                SIG[Signatures]:::data
                
                HEADER --> PAYLOAD
                HEADER --> SIG
            end
        end
    end
    
    %% Connections between layers
    W1 & W2 & W3 -.-> "Worker Internals"
    DAG -.-> "DAG Components"
    VP -.-> VTX
    
    %% Styles
    classDef mainNode fill:#FF5000,stroke:#333,stroke-width:3px,color:white,font-weight:bold
    classDef workerNode fill:#0078D7,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef controller fill:#FFA500,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef component fill:#2ECC71,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef storage fill:#8E44AD,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef thread fill:#3498DB,stroke:#333,stroke-width:1px,color:white
    classDef monitoring fill:#E74C3C,stroke:#333,stroke-width:2px,color:white
    classDef k8s fill:#34495E,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef data fill:#27AE60,stroke:#333,stroke-width:1px,color:white
    classDef process fill:#2980B9,stroke:#333,stroke-width:1px,color:white
```

*A multi-layered architecture showing the Avalanche Parallel DAG system from low-level implementation details to high-level system design*

</div>

## 📋 System Architecture Overview

The Avalanche Parallel DAG system is designed as a layered architecture with clear separation of concerns:

### High-Level Architecture

The top-level view focuses on the main system components and their interactions:

- **API Gateway**: Entry point for transactions and queries
- **Main Node**: Central coordinator for the entire system
- **Queue Balancer**: Distributes work across worker nodes
- **Worker Layer**: Distributed processing units that handle parallel execution
- **Kubernetes Orchestration**: Manages deployment and scaling
- **Monitoring System**: Tracks system health and performance

### Mid-Level Implementation

The middle layer details the internal components that power the system:

- **Consensus Engine**: Implements the Avalanche protocol with components for DAG management, vertex processing, dependency management, and transaction scheduling
- **Storage Systems**: Handles data persistence with transaction database, file system, and message queue
- **Monitoring Stack**: Provides observability through Prometheus, Grafana, and alerts
- **Kubernetes Resources**: Manages infrastructure with autoscalers, service controllers, and persistent storage

### Low-Level Implementation

The foundational layer focuses on the detailed implementation:

- **Worker Internals**: 
  - Thread Management: Controls parallel execution with multiple worker threads
  - Memory Structures: Manages data with vertex queues, memory pools, and concurrency controls
  - Parallel Processing: Executes vertex processing, transaction validation, signature verification, and dependency resolution
- **Data Structures**:
  - DAG Components: Represents the directed acyclic graph with vertices, edges, and frontier management
  - Transaction Format: Defines the structure of transactions with headers, payloads, and signatures

This layered approach allows the system to scale efficiently while maintaining the core performance benefits of parallel execution across distributed nodes.

## 🔄 How It Works

The system operates through the following process flow:

1. **Task Distribution**: The main Avalanche node receives transactions and distributes processing tasks to worker nodes
2. **Parallel Processing**: Each worker node executes its assigned DAG vertices in parallel using multiple threads
3. **Dependency Management**: The system tracks parent-child relationships to ensure correct transaction ordering
4. **Result Aggregation**: Processed results are collected and validated by the main node
5. **Consensus Finalization**: The main node applies consensus rules and finalizes transaction confirmations

This architecture enables:
- Processing hundreds of thousands of transactions per second
- Automatic scaling based on network load
- Fault tolerance through worker redundancy
- Real-time metrics and performance monitoring

## ⚠️ Important: Go 1.18 Compatibility

This project **requires Go 1.18 specifically**. It is not compatible with newer Go versions due to dependency constraints.

Common issues and their solutions:

1. **Package Conflict in `utils` Directory**
   - Error: `found packages utils (atomic.go) and main (sorting.go) in default/utils`
   - Solution: Run our fix scripts to correct the package declaration

2. **`bytes.Compare` Syntax Issues**
   - Error: `bytes.Compare undefined (type [][]byte has no field or method Compare)`
   - Solution: Our fix scripts update sorting.go with correct syntax

3. **multierr Dependency Requiring Go 1.19+**
   - Error: `go.uber.org/multierr: undefined: atomic.Bool` and `note: module requires Go 1.19`
   - Solution: Our fix scripts downgrade dependencies to Go 1.18 compatible versions

For detailed troubleshooting, see [fixer/FIX-GO118-GUIDE.md](fixer/FIX-GO118-GUIDE.md).

## 🚀 Installation and Setup Guide

This section provides comprehensive instructions for installing, building, and running the Avalanche Parallel DAG system.

### Prerequisites

- Go 1.18 (specifically requires Go 1.18, not later versions)
- Git
- Docker and Docker Compose (for containerized deployment)
- 4GB+ RAM
- 20GB+ free disk space

### Quick Start Guide

For the fastest setup experience, follow these steps:

```bash
# 1. Clone the repository
git clone https://github.com/Final-Project-13520137/avalanche-parallel-dag.git
cd avalanche-parallel-dag

# 2. Fix Go compatibility (essential for Go 1.18)
# For Windows:
.\fixer\fix-go-version.ps1
.\fixer\fix-go-compatibility.ps1

# For Linux/macOS:
chmod +x fixer/fix-go-version.sh fixer/fix-go-compatibility.sh
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh

# 3. Build the binaries
# For Windows:
go build -o avalanche-parallel.exe .\cmd\avalanche
go build -o worker.exe .\cmd\worker

# For Linux/macOS:
go build -o avalanche-parallel ./cmd/avalanche
go build -o worker ./cmd/worker

# 4. Run the applications
# For Windows:
.\avalanche-parallel.exe --network-id=local --staking-enabled=false --http-port=9650
# In another terminal:
.\worker.exe --api-port=9652 --threads=4

# For Linux/macOS:
./avalanche-parallel --network-id=local --staking-enabled=false --http-port=9650
# In another terminal:
./worker --api-port=9652 --threads=4
```

### Detailed Installation Steps

#### Option 1: Clone Repository

```bash
# Clone the repository
git clone https://github.com/Final-Project-13520137/avalanche-parallel-dag.git
cd avalanche-parallel-dag

# Clone the Avalanche reference code into the default directory (if needed)
git clone https://github.com/ava-labs/avalanchego.git default
```

#### Option 2: Download Release

```bash
# Download the latest release
curl -LO https://github.com/Final-Project-13520137/avalanche-parallel-dag/archive/refs/tags/v1.0.0.tar.gz
tar -xzf v1.0.0.tar.gz
cd avalanche-parallel-dag-1.0.0
```

### Essential: Go Version Compatibility

This project requires Go 1.18 specifically. Follow these steps to ensure compatibility:

#### Step 1: Fix Go Module Version

```bash
# Windows (PowerShell)
.\fixer\fix-go-version.ps1

# Linux/macOS
chmod +x fixer/fix-go-version.sh
./fixer/fix-go-version.sh
```

This will:
- Update go.mod to use Go 1.18
- Remove any toolchain directives
- Run go mod tidy

#### Step 2: Fix Go Compatibility Issues

```bash
# Windows (PowerShell)
.\fixer\fix-go-compatibility.ps1

# Linux/macOS
chmod +x fixer/fix-go-compatibility.sh
./fixer/fix-go-compatibility.sh
```

This will:
- Create compatibility layers for newer Go packages (cmp, slices, maps)
- Fix sorting.go implementation issues
- Update set implementation for Go 1.18 compatibility

### Building from Source

After applying the compatibility fixes, build the binaries:

#### Build the Main Binary

```bash
# Windows (PowerShell)
go build -o avalanche-parallel.exe .\cmd\avalanche

# Linux/macOS
go build -o avalanche-parallel ./cmd/avalanche
```

#### Build Worker Nodes

```bash
# Windows (PowerShell)
go build -o worker.exe .\cmd\worker

# Linux/macOS
go build -o worker ./cmd/worker
```

### Running the System

#### Starting the Node (Standalone)

```bash
# Windows
.\avalanche-parallel.exe --network-id=local --staking-enabled=false --http-port=9650

# Linux/macOS
./avalanche-parallel --network-id=local --staking-enabled=false --http-port=9650
```

#### Starting Worker Nodes (Standalone)

```bash
# Windows
.\worker.exe --api-port=9652 --threads=4

# Linux/macOS
./worker --api-port=9652 --threads=4
```

#### Using Docker Compose (Recommended)

Before using Docker Compose, ensure you've applied the compatibility fixes:

```bash
# Fix Go compatibility first
# Windows:
.\fixer\fix-go-version.ps1
.\fixer\fix-go-compatibility.ps1
# Linux/macOS:
chmod +x fixer/fix-go-version.sh fixer/fix-go-compatibility.sh
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh

# Then start the Docker services
docker-compose -f config/docker-compose.yml up -d

# Scale worker nodes
docker-compose -f config/docker-compose.yml up -d --scale worker=3

# Check service status
docker-compose -f config/docker-compose.yml ps

# View logs
docker-compose -f config/docker-compose.yml logs -f

# Stop all services
docker-compose -f config/docker-compose.yml down
```

### Running with Modified Ports

If you encounter port conflicts, use our restart scripts:

```bash
# Windows (PowerShell)
.\scripts\restart-docker.ps1 -DockerComposeFile config/docker-compose.yml

# Linux/macOS
chmod +x scripts/restart-docker.sh
./scripts/restart-docker.sh -f config/docker-compose.yml
```

### Running Tests

Before running tests, make sure you've applied the compatibility fixes:

```bash
# Fix Go compatibility first
# Windows:
.\fixer\fix-go-version.ps1
.\fixer\fix-go-compatibility.ps1
# Linux/macOS:
chmod +x fixer/fix-go-version.sh fixer/fix-go-compatibility.sh
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh

# Then run tests
# Run all blockchain tests
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain

# Run specific test categories
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestTransaction
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestBlock
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run TestBlockchain

# Using test script (Windows)
.\scripts\runtest.ps1

# Using test script (Linux/macOS)
chmod +x scripts/restart.sh
./scripts/restart.sh
```

### Running Benchmarks

```bash
# Run benchmarks with 1000 vertices and 4 threads
go run ./cmd/benchmark -vertices=1000 -threads=4
```

### Accessing Services

Once running, you can access the following services:

- **Avalanche Node API**: http://localhost:9650/ext/info
- **Worker API**: http://localhost:9652/health
- **Prometheus**: http://localhost:19090 (modified port to avoid conflicts)
- **Grafana**: http://localhost:13000 (modified port to avoid conflicts)
  - Default credentials: username `admin`, password `admin`

### Troubleshooting Common Issues

#### 1. Module Path Issues

If you encounter module path errors:

```bash
# Windows (PowerShell)
.\fixer\fix-module-path.ps1

# Linux/macOS
chmod +x fixer/fix-module-path.sh
./fixer/fix-module-path.sh
```

#### 2. Import Path Issues

For import path errors:

```bash
# Windows (PowerShell)
.\fixer\fix-all-imports.ps1

# Linux/macOS
chmod +x fixer/fix-all-imports.sh
./fixer/fix-all-imports.sh
```

#### 3. Go Version Issues

If you see errors about incompatible Go versions:

```bash
# Windows (PowerShell)
.\fixer\fix-go-version.ps1

# Linux/macOS
chmod +x fixer/fix-go-version.sh
./fixer/fix-go-version.sh
```

#### 4. Docker Compose Issues

For Docker Compose issues:

```bash
# Rebuild containers with specific arguments
docker-compose -f config/docker-compose.yml build --build-arg AVALANCHE_PARALLEL_PATH=../avalanche-parallel

# Or use our restart script
# Windows (PowerShell)
.\scripts\restart-docker.ps1 -DockerComposeFile config/docker-compose.yml

# Linux/macOS
chmod +x scripts/restart-docker.sh
./scripts/restart-docker.sh -f config/docker-compose.yml
```

#### 5. Sorting Errors with bytes.Compare

If you encounter syntax errors in sorting.go:

```bash
# Windows (PowerShell)
.\fixer\fix-sorting.ps1

# Linux/macOS - manually fix by copying sorting_fixed.go
cp fixer/sorting_fixed.go default/utils/sorting.go
```

#### 6. Missing Package Errors (cmp, maps, slices)

Apply the compatibility fixes to create compatible implementations:

```bash
# Windows (PowerShell)
.\fixer\fix-go-compatibility.ps1

# Linux/macOS
chmod +x fixer/fix-go-compatibility.sh
./fixer/fix-go-compatibility.sh
```

This will create:
- cmp_compatibility.go
- maps_compatibility.go  
- slices_compatibility.go

#### 7. Set Redeclaration Errors (on Linux)

If you encounter "redeclared in this block" errors in the set package on Linux:

```bash
# Linux/macOS
chmod +x fixer/fix-set-duplicates-linux.sh
./fixer/fix-set-duplicates-linux.sh
```

For Windows, use:
```powershell
.\fixer\fix-set-duplicates.ps1
```

#### 8. Package Conflict in Utils Directory

If you encounter errors like "found packages utils and main in default/utils":

```bash
# Windows PowerShell
$sortingContent = Get-Content -Path "default\utils\sorting.go"
$sortingContent = $sortingContent -replace "package main", "package utils"
$sortingContent | Set-Content -Path "default\utils\sorting.go"

# Linux/macOS
sed -i 's/package main/package utils/g' default/utils/sorting.go
```

This is already included in the fix-set-duplicates scripts.

#### 9. Multierr and bytes.Compare Errors on Linux

If you encounter errors like:
```
# go.uber.org/multierr: undefined: atomic.Bool
note: module requires Go 1.19
# github.com/ava-labs/avalanchego/utils: bytes.Compare undefined (type [][]byte has no field or method Compare)
```

Use our all-in-one fix script for Linux:
```bash
chmod +x fixer/fix-all-linux.sh
./fixer/fix-all-linux.sh
```

This script will:
1. Fix Go version and dependencies in go.mod
2. Fix package declarations
3. Fix bytes.Compare issues in sorting.go
4. Fix set package duplicates
5. Run go mod tidy

#### 10. Missing go.sum Entries

If you encounter errors like:
```
go: go.uber.org/atomic@v1.7.0: missing go.sum entry; to add it:
        go mod download go.uber.org/atomic
```

Fix it with:
```bash
# Single fix script
chmod +x fixer/fix-go-sum.sh
./fixer/fix-go-sum.sh

# Or use our all-in-one fix script which includes this fix
chmod +x fixer/fix-all-linux.sh
./fixer/fix-all-linux.sh
```

Alternatively, run these commands manually:
```bash
go mod download go.uber.org/atomic
go mod download
go mod tidy
```

## ✨ Features

<table>
  <tr>
    <td align="center"><b>⚡ Parallel Processing</b></td>
    <td>Execute multiple transaction vertices concurrently using multi-threaded architecture, providing up to 10x faster transaction validation</td>
  </tr>
  <tr>
    <td align="center"><b>🌐 Distributed Architecture</b></td>
    <td>Distribute processing load across multiple worker nodes, each capable of processing thousands of transactions per second</td>
  </tr>
  <tr>
    <td align="center"><b>🔄 Dynamic Workload Distribution</b></td>
    <td>Intelligently assign tasks based on worker capacity and current load for optimal resource utilization</td>
  </tr>
  <tr>
    <td align="center"><b>♾️ Auto-Scaling</b></td>
    <td>Automatically adapt to network demand by scaling worker nodes up or down with Kubernetes HPA support</td>
  </tr>
  <tr>
    <td align="center"><b>🛡️ Fault Tolerance</b></td>
    <td>Maintain continuous operation through worker redundancy and automatic task reassignment when nodes fail</td>
  </tr>
  <tr>
    <td align="center"><b>📊 Performance Monitoring</b></td>
    <td>Track system health and performance with Prometheus metrics and customized Grafana dashboards</td>
  </tr>
  <tr>
    <td align="center"><b>🛠️ Container Orchestration</b></td>
    <td>Deploy and manage with Docker Compose for development and Kubernetes for production environments</td>
  </tr>
  <tr>
    <td align="center"><b>📈 Horizontal Scalability</b></td>
    <td>Linearly increase processing capacity by adding more worker nodes to handle higher transaction volumes</td>
  </tr>
</table>

## 📋 Quick Reference Commands

Here's a simplified cheat sheet for building and running the project with Go 1.18:

### Step 1: Setup & Fix Compatibility

```bash
# Clone repository and enter directory
git clone https://github.com/Final-Project-13520137/avalanche-parallel-dag.git
cd avalanche-parallel-dag

# Windows (PowerShell)
.\fixer\fix-go-version.ps1
.\fixer\fix-go-compatibility.ps1

# Linux/macOS
chmod +x fixer/fix-go-version.sh fixer/fix-go-compatibility.sh
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh
```

### Step 2: Build Binaries

```bash
# Windows (PowerShell)
go build -o avalanche-parallel.exe .\cmd\avalanche
go build -o worker.exe .\cmd\worker

# Linux/macOS
go build -o avalanche-parallel ./cmd/avalanche
go build -o worker ./cmd/worker
```

### Step 3: Run the Application

```bash
# Option 1: Run standalone (in separate terminals)
# Windows:
.\avalanche-parallel.exe --network-id=local --staking-enabled=false --http-port=9650
.\worker.exe --api-port=9652 --threads=4

# Linux/macOS:
./avalanche-parallel --network-id=local --staking-enabled=false --http-port=9650
./worker --api-port=9652 --threads=4

# Option 2: Run with Docker Compose
docker-compose -f config/docker-compose.yml up -d
```

### Step 4: Run Tests (Optional)

```bash
# Run test with script
# Windows:
.\scripts\runtest.ps1

# Linux/macOS:
chmod +x scripts/restart.sh
./scripts/restart.sh

# Or run individual tests
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain
```

### Troubleshooting

If you encounter any issues, these commands may help:

```bash
# Fix sorting errors
# Windows:
.\fixer\fix-sorting.ps1
# Linux/macOS:
cp fixer/sorting_fixed.go default/utils/sorting.go

# Fix module path issues
# Windows:
.\fixer\fix-module-path.ps1
# Linux/macOS:
chmod +x fixer/fix-module-path.sh
./fixer/fix-module-path.sh

# Fix import path issues
# Windows:
.\fixer\fix-all-imports.ps1
# Linux/macOS:
chmod +x fixer/fix-all-imports.sh
./fixer/fix-all-imports.sh
```