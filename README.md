# <img src="https://raw.githubusercontent.com/ava-labs/avalanchego/master/staking/avalanche_logo_text.png" alt="Avalanche" height="40" /> Parallel DAG

<div align="center">

[![Go Version](https://img.shields.io/badge/Go-1.18-blue.svg)](https://golang.org/dl/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)
[![Last Commit](https://img.shields.io/github/last-commit/Final-Project-13520137/avalanche-parallel-dag)](https://github.com/Final-Project-13520137/avalanche-parallel-dag/commits/main)

**A high-performance, parallel implementation of the Avalanche consensus protocol with distributed DAG processing**

</div>

<hr />

## 📑 Table of Contents
- [Overview](#-overview)
- [System Architecture](#-system-architecture)
- [Features](#-features)
- [Installation](#-installation)
- [Usage](#-usage)
- [Docker Deployment](#-docker-deployment)
- [Troubleshooting](#-troubleshooting)
- [Quick Reference](#-quick-reference)
- [License](#-license)

## 🔍 Overview

Avalanche Parallel DAG significantly improves transaction throughput and reduces confirmation latency through:

<table>
<tr>
<td width="50%" valign="top">

### Key Capabilities
- 🚀 **10x Faster Validation** through parallel transaction processing
- 🌐 **Horizontal Scaling** with distributed worker nodes
- 💪 **Enhanced Throughput** handling thousands of transactions per second
- 🛡️ **Fault Tolerance** with automatic recovery
- 📊 **Real-time Monitoring** via Prometheus and Grafana

</td>
<td width="50%" valign="top">

### Technical Approach
- Multi-threaded DAG vertex processing
- Efficient frontier tracking with dependency resolution
- Containerized deployment with Kubernetes
- Automatic load balancing and queue management
- Optimized consensus algorithm for parallel execution

</td>
</tr>
</table>

## 🏗 System Architecture

The Avalanche Parallel DAG system is designed as a layered architecture with clear separation of concerns.

### 1. High-Level Architecture

<div align="center">

```mermaid
flowchart TD
    %% System Components
    API[API Gateway]:::controller
    MN[Avalanche Main Node]:::mainNode
    QB[Queue Balancer]:::controller
    
    KO[Kubernetes Orchestration]:::k8s
    MON[Monitoring System]:::monitoring
    
    %% Worker Layer
    W1[Worker Pod 1]:::workerNode
    W2[Worker Pod 2]:::workerNode
    W3[Worker Pod N]:::workerNode
    
    %% Connections
    MN <--> API
    API <--> QB
    QB <--> W1 & W2 & W3
    
    KO --> MN
    KO --> W1 & W2 & W3
    MON --> MN
    MON --> W1 & W2 & W3
    
    %% Styles
    classDef mainNode fill:#FF5000,stroke:#333,stroke-width:3px,color:white,font-weight:bold
    classDef workerNode fill:#0078D7,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef controller fill:#FFA500,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef k8s fill:#34495E,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef monitoring fill:#E74C3C,stroke:#333,stroke-width:2px,color:white,font-weight:bold
```

*High-level view of the system components and their interactions*

</div>

The top-level architecture focuses on the main system components:

- **API Gateway**: Entry point for transactions and queries
- **Main Node**: Central coordinator for the entire system
- **Queue Balancer**: Distributes work across worker nodes
- **Worker Pods**: Distributed processing units that handle parallel execution
- **Kubernetes Orchestration**: Manages deployment and scaling
- **Monitoring System**: Tracks system health and performance

### 2. Mid-Level Implementation

<div align="center">

```mermaid
flowchart TD
    %% Main Node and Components
    MN[Avalanche Main Node]:::mainNode
    CE[Consensus Engine]:::component
    
    %% Consensus Engine Components
    subgraph "Consensus Engine Components" 
        DAG[DAG Manager]:::component
        VP[Vertex Processor]:::component
        DM[Dependency Manager]:::component
        TS[Transaction Scheduler]:::component
        
        DAG <--> VP
        VP <--> DM
        DM <--> TS
    end
    
    %% Storage Systems
    DB[(Transaction DB)]:::storage
    FS[(File System)]:::storage
    MQ[(Message Queue)]:::storage
    
    %% Monitoring Stack
    PROM[Prometheus]:::monitoring
    GRAF[Grafana]:::monitoring
    ALERT[Alertmanager]:::monitoring
    
    %% Kubernetes Resources
    HPA[Horizontal Pod Autoscaler]:::k8s
    SC[Service Controller]:::k8s
    PVC[Persistent Volume Claims]:::k8s
    SVC[Services]:::k8s
    
    %% Connections
    MN --- CE
    CE --- DAG
    CE --> DB
    CE --> FS
    CE --> MQ
    
    PROM --> GRAF
    PROM --> ALERT
    
    %% Styles
    classDef mainNode fill:#FF5000,stroke:#333,stroke-width:3px,color:white,font-weight:bold
    classDef component fill:#2ECC71,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef storage fill:#8E44AD,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef monitoring fill:#E74C3C,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef k8s fill:#34495E,stroke:#333,stroke-width:2px,color:white,font-weight:bold
```

*Mid-level view showing the internal components of the system*

</div>

The middle layer details the internal components:

- **Consensus Engine**: Implements the Avalanche protocol with DAG management, vertex processing, dependency management, and transaction scheduling
- **Storage Systems**: Handles data persistence with transaction database, file system, and message queue
- **Monitoring Stack**: Provides observability through Prometheus, Grafana, and alerts
- **Kubernetes Resources**: Manages infrastructure with autoscalers, service controllers, and persistent storage

### 3. Low-Level Implementation

<div align="center">

```mermaid
flowchart TD
    %% Worker Internals
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
    end
    
    subgraph "Parallel Processing"
        VTX[Vertex Processing]:::process
        TXVLD[Transaction Validation]:::process
        SIGN[Signature Verification]:::process
        DEPS[Dependency Resolution]:::process
    end
    
    %% Data Structures
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
    
    %% Connections
    T1 & T2 & T3 & TN --> VTXQ
    T1 & T2 & T3 & TN --> MEMPL
    T1 & T2 & T3 & TN --> LCK
    T1 & T2 & T3 & TN --> VTX & TXVLD & SIGN & DEPS
    VTX --> VTXS
    
    %% Styles
    classDef component fill:#2ECC71,stroke:#333,stroke-width:2px,color:white,font-weight:bold
    classDef thread fill:#3498DB,stroke:#333,stroke-width:1px,color:white
    classDef data fill:#27AE60,stroke:#333,stroke-width:1px,color:white
    classDef process fill:#2980B9,stroke:#333,stroke-width:1px,color:white
```

*Low-level view showing the detailed implementation and data structures*

</div>

The foundational layer focuses on implementation details:

- **Worker Internals**: Thread management, memory structures, and parallel processing components
- **Data Structures**: DAG components and transaction format details
- **Process Flow**: How threads interact with various system components

## ✨ Features

<div class="features-grid" style="display: grid; grid-template-columns: repeat(2, 1fr); gap: 10px;">

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>⚡ Parallel Processing</h3>
  <p>Execute multiple transaction vertices concurrently using multi-threaded architecture, providing up to 10x faster transaction validation</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>🌐 Distributed Architecture</h3>
  <p>Distribute processing load across multiple worker nodes, each capable of processing thousands of transactions per second</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>🔄 Dynamic Workload Distribution</h3>
  <p>Intelligently assign tasks based on worker capacity and current load for optimal resource utilization</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>♾️ Auto-Scaling</h3>
  <p>Automatically adapt to network demand by scaling worker nodes up or down with Kubernetes HPA support</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>🛡️ Fault Tolerance</h3>
  <p>Maintain continuous operation through worker redundancy and automatic task reassignment when nodes fail</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>📊 Performance Monitoring</h3>
  <p>Track system health and performance with Prometheus metrics and customized Grafana dashboards</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>🛠️ Container Orchestration</h3>
  <p>Deploy and manage with Docker Compose for development and Kubernetes for production environments</p>
</div>

<div class="feature-card" style="border: 1px solid #eee; border-radius: 8px; padding: 15px; margin-bottom: 10px;">
  <h3>📈 Horizontal Scalability</h3>
  <p>Linearly increase processing capacity by adding more worker nodes to handle higher transaction volumes</p>
</div>

</div>

## 📦 Installation

### Prerequisites

- **Go 1.18** (specifically requires Go 1.18, not later versions)
- Git
- Docker and Docker Compose (for containerized deployment)
- 4GB+ RAM
- 20GB+ free disk space

### Quick Start

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
```

### Project Structure

<details>
<summary>Click to expand file structure</summary>

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
├── docs/               # Documentation
├── fixer/              # Fix scripts for compatibility issues
├── pkg/                # Core packages
│   ├── blockchain/     # Blockchain implementation
│   ├── consensus/      # Consensus algorithms
│   ├── utils/          # Utility packages
│   └── worker/         # Worker node implementation
└── scripts/            # Helper scripts
```

</details>

## 🚀 Usage

### Running the System

#### Standalone Mode

```bash
# Windows
.\avalanche-parallel.exe --network-id=local --staking-enabled=false --http-port=9650
# In another terminal:
.\worker.exe --api-port=9652 --threads=4

# Linux/macOS
./avalanche-parallel --network-id=local --staking-enabled=false --http-port=9650
# In another terminal:
./worker --api-port=9652 --threads=4
```

## 🐳 Docker Deployment

Deploy the entire system using Docker Compose:

```bash
# Fix Go compatibility first
# Windows:
.\fixer\fix-go-version.ps1
.\fixer\fix-go-compatibility.ps1
# Linux/macOS:
chmod +x fixer/fix-go-version.sh fixer/fix-go-compatibility.sh
./fixer/fix-go-version.sh
./fixer/fix-go-compatibility.sh

# Start the Docker services
docker-compose -f config/docker-compose.yml up -d

# Scale worker nodes
docker-compose -f config/docker-compose.yml up -d --scale worker=3
```

### Accessing Services

After deployment, you can access:

- **Avalanche Node API**: http://localhost:9650/ext/info
- **Worker API**: http://localhost:9652/health
- **Prometheus**: http://localhost:19090
- **Grafana**: http://localhost:13000 (admin/admin)

## ⚠️ Important: Go 1.18 Compatibility

This project **requires Go 1.18 specifically**. It is not compatible with newer Go versions due to dependency constraints.

<details>
<summary>Common issues and solutions</summary>

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
</details>

## 🔧 Troubleshooting

### Docker Compose Issues

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

<details>
<summary>More troubleshooting tips</summary>

### Module Path Issues

```bash
# Windows (PowerShell)
.\fixer\fix-module-path.ps1

# Linux/macOS
chmod +x fixer/fix-module-path.sh
./fixer/fix-module-path.sh
```

### Import Path Issues

```bash
# Windows (PowerShell)
.\fixer\fix-all-imports.ps1

# Linux/macOS
chmod +x fixer/fix-all-imports.sh
./fixer/fix-all-imports.sh
```

### Go Version Issues

```bash
# Windows (PowerShell)
.\fixer\fix-go-version.ps1

# Linux/macOS
chmod +x fixer/fix-go-version.sh
./fixer/fix-go-version.sh
```

</details>

## 📋 Quick Reference

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

# Option 2: Run with Docker Compose
docker-compose -f config/docker-compose.yml up -d
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👥 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📱 Contact

For questions or support, please open an issue on our GitHub repository.

---