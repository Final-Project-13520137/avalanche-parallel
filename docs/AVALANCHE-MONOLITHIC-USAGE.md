# AvalancheGo Monolithic System - Usage Guide

**Copyright (C) 2024, Avalanche Parallel Processing. All rights reserved.**

## 📋 Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Prerequisites](#prerequisites)
4. [Installation & Setup](#installation--setup)
5. [Running Monolithic System](#running-monolithic-system)
6. [Benchmarking](#benchmarking)
7. [Configuration Options](#configuration-options)
8. [Troubleshooting](#troubleshooting)
9. [Performance Optimization](#performance-optimization)
10. [API Endpoints](#api-endpoints)

## 🎯 Overview

AvalancheGo Monolithic System adalah implementasi **real** dari AvalancheGo yang menggunakan arsitektur monolithic dengan flow system yang terintegrasi. Sistem ini mengimplementasikan:

- **Real Cryptographic Verification** menggunakan secp256k1
- **Real Snowman Consensus** dengan validator querying
- **Real State Management** dengan UTXO validation
- **Real Database Persistence** dengan atomic batching
- **Cross-Chain Operations** dengan atomic.SharedMemory

## 🏗️ System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Client Request                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              API Server Validation                          │
│  • Max transaction size validation                          │
│  • Required fields validation                               │
│  • Rate limiting                                           │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│                Mempool Queue                                │
│  • Transaction queuing                                      │
│  • Priority management                                      │
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│              Consensus Engine                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │            Vertex Builder                               ││
│  │  • Parents, Txs, Height                                 ││
│  └─────────────────────────────────────────────────────────┘│
│  ┌─────────────────────────────────────────────────────────┐│
│  │         Sequential Steps (~100ms per vertex)            ││
│  │  1. Get transactions                                    ││
│  │  2. Verify signatures (secp256k1)                      ││
│  │  3. Check dependencies                                  ││
│  │  4. Build vertex                                        ││
│  │  5. Calculate hash                                      ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│             Snowman Consensus                               │
│  ┌─────────────────────────────────────────────────────────┐│
│  │     Sequential Voting (~100ms per vertex)              ││
│  │  1. Query k random validators                           ││
│  │  2. Collect responses                                   ││
│  │  3. Update confidence                                   ││
│  │  4. Repeat until finalized                              ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────┬───────────────────────────────────────┘
                      │
┌─────────────────────▼───────────────────────────────────────┐
│               State Manager                                 │
│  ┌─────────────────────────────────────────────────────────┐│
│  │      Sequential Updates (~50ms per vertex)             ││
│  │  1. Apply transactions                                  ││
│  │  2. Update UTXO set                                     ││
│  │  3. Update balances                                     ││
│  │  4. Execute smart contracts                             ││
│  │  5. Commit state changes (database batching)           ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

### Required Software
- **Go 1.19+** - untuk compiling AvalancheGo
- **Docker & Docker Compose** - untuk microservices comparison
- **Git** - untuk source code management

### Operating System Support
- ✅ **Linux** (Ubuntu 20.04+, CentOS 8+)
- ✅ **macOS** (10.15+)
- ✅ **Windows** (Windows 10+, WSL2)

### Hardware Requirements
- **CPU**: 4+ cores recommended
- **RAM**: 8GB+ recommended
- **Storage**: 10GB+ free space
- **Network**: Stable internet connection

## 🚀 Installation & Setup

### 1. Clone Repository
```bash
git clone https://github.com/your-org/avalanche-parallel.git
cd avalanche-parallel
```

### 2. Verify Prerequisites
```bash
# Check Go installation
go version

# Check Docker installation
docker --version
docker-compose --version

# Check Git installation
git --version
```

### 3. Setup Permissions (Linux/macOS only)
```bash
# Make scripts executable
chmod +x scripts/run-monolithic.sh
chmod +x microservices/scripts/benchmark/avalanche-monolithic-vs-microservices.sh
```

## 🏃 Running Monolithic System

### Quick Start

#### Linux/macOS
```bash
# Run with defaults (auto-build and start)
./scripts/run-monolithic.sh

# Or with custom parameters
./scripts/run-monolithic.sh run --log-level debug --http-port 8080
```

#### Windows (PowerShell)
```powershell
# Run with defaults
.\scripts\run-monolithic.ps1

# Or with custom parameters
.\scripts\run-monolithic.ps1 run -LogLevel debug -HttpPort 8080
```

### Available Commands

| Command | Description | Example |
|---------|-------------|---------|
| `build` | Build monolithic binary only | `./scripts/run-monolithic.sh build` |
| `run` | Build and run monolithic system | `./scripts/run-monolithic.sh run` |
| `start` | Alias for run | `./scripts/run-monolithic.sh start` |
| `help` | Show help message | `./scripts/run-monolithic.sh help` |

### Configuration Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `--log-level` | Log level (debug, info, warn, error) | `info` | `--log-level debug` |
| `--http-port` | HTTP API port | `9650` | `--http-port 8080` |
| `--network-port` | Network listening port | `9651` | `--network-port 8081` |
| `--db-dir` | Database directory | `~/.avalanche-monolithic/db` | `--db-dir /custom/path` |
| `--log-dir` | Log directory | `~/.avalanche-monolithic/logs` | `--log-dir /custom/logs` |

### Advanced Usage Examples

#### Development Mode (Debug Logging)
```bash
./scripts/run-monolithic.sh run --log-level debug
```

#### Custom Ports (Avoid Conflicts)
```bash
./scripts/run-monolithic.sh run --http-port 8080 --network-port 8081
```

#### Custom Data Directory
```bash
./scripts/run-monolithic.sh run --args "--db-dir /custom/data --log-dir /custom/logs"
```

## 📊 Benchmarking

### Monolithic vs Microservices Comparison

#### Quick Benchmark
```bash
# Linux/macOS
cd microservices/scripts/benchmark
./avalanche-monolithic-vs-microservices.sh

# Windows
cd microservices\scripts\benchmark
.\avalanche-monolithic-vs-microservices.ps1
```

#### Custom Benchmark Parameters
```bash
# 10-minute benchmark with 2000 TPS target
./avalanche-monolithic-vs-microservices.sh --duration 600 --tps 2000

# Test only monolithic system
./avalanche-monolithic-vs-microservices.sh --monolithic-only --duration 120

# Test with custom concurrent users
./avalanche-monolithic-vs-microservices.sh --users 100 --ramp-up 60
```

#### Benchmark Options

| Option | Description | Default | Example |
|--------|-------------|---------|---------|
| `--duration` | Benchmark duration (seconds) | `300` | `--duration 600` |
| `--tps` | Target transactions per second | `1000` | `--tps 2000` |
| `--users` | Concurrent users | `50` | `--users 100` |
| `--ramp-up` | Ramp-up time (seconds) | `30` | `--ramp-up 60` |
| `--monolithic-only` | Test only monolithic | - | `--monolithic-only` |
| `--microservices-only` | Test only microservices | - | `--microservices-only` |
| `--clean` | Clean up before running | - | `--clean` |

### Understanding Benchmark Results

Benchmark generates detailed reports in `benchmark-results/` directory:

```
benchmark-results/
└── monolithic-vs-microservices-20241127_143022/
    ├── comparison_report.md          # Main comparison report
    ├── monolithic_results.json       # Detailed monolithic metrics
    ├── microservices_results.json    # Detailed microservices metrics
    ├── monolithic.log                # Monolithic system logs
    ├── monolithic_config.json        # Monolithic test configuration
    └── microservices_config.json     # Microservices test configuration
```

#### Key Metrics Explained

| Metric | Description | Good Values |
|--------|-------------|-------------|
| **TPS (Transactions Per Second)** | Actual throughput achieved | Higher is better |
| **Response Time** | Average response time | Lower is better |
| **Error Rate** | Percentage of failed requests | Lower is better |
| **Success Rate** | Percentage of successful requests | Higher is better |

## ⚙️ Configuration Options

### Environment Variables
```bash
# Set custom data directory
export AVALANCHE_DATA_DIR="/custom/data"

# Set custom log level
export AVALANCHE_LOG_LEVEL="debug"

# Set custom HTTP port
export AVALANCHE_HTTP_PORT="8080"
```

### Configuration Files

#### Database Configuration
```yaml
# ~/.avalanche-monolithic/config.yaml
database:
  path: "/custom/db/path"
  cache_size: 1024
  batch_size: 100

logging:
  level: "info"
  directory: "/custom/logs"
  max_size: "100MB"
  max_files: 10
```

### Performance Tuning

#### For High Throughput
```bash
./scripts/run-monolithic.sh run --args "--fd-limit 65536"
```

#### For Low Latency
```bash
./scripts/run-monolithic.sh run --log-level warn
```

#### For Development
```bash
./scripts/run-monolithic.sh run --log-level debug --args "--db-dir ./dev-data"
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Error: listen tcp :9650: bind: address already in use
# Solution: Use different ports
./scripts/run-monolithic.sh run --http-port 8080 --network-port 8081
```

#### 2. Go Build Errors
```bash
# Error: go: module not found
# Solution: Update dependencies
go mod tidy
go mod download
```

#### 3. Permission Denied (Linux/macOS)
```bash
# Error: permission denied
# Solution: Make scripts executable
chmod +x scripts/run-monolithic.sh
sudo chmod +x scripts/run-monolithic.sh  # if needed
```

#### 4. Docker Issues (for benchmarking)
```bash
# Error: docker: command not found
# Solution: Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

#### 5. Database Lock Issues
```bash
# Error: database is locked
# Solution: Clean up existing processes
pkill avalanche-monolithic
rm ~/.avalanche-monolithic/db/LOCK
```

### Debug Mode

#### Enable Verbose Logging
```bash
./scripts/run-monolithic.sh run --log-level debug
```

#### View Real-time Logs
```bash
# Linux/macOS
tail -f ~/.avalanche-monolithic/logs/main.log

# Windows
Get-Content "~\.avalanche-monolithic\logs\main.log" -Wait
```

#### Check System Status
```bash
# Check if system is running
curl http://localhost:9650/ext/health

# Check node info
curl -X POST http://localhost:9650/ext/info -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"info.getNodeVersion","params":{},"id":1}'
```

## 🚀 Performance Optimization

### System Configuration

#### Linux Optimizations
```bash
# Increase file descriptor limits
ulimit -n 65536

# Optimize network settings
echo 'net.core.rmem_max = 134217728' >> /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' >> /etc/sysctl.conf
sysctl -p
```

#### Go Runtime Optimizations
```bash
# Set Go garbage collector
export GOGC=100

# Set Go max processes
export GOMAXPROCS=8
```

### Database Optimization

#### For SSD Storage
```bash
./scripts/run-monolithic.sh run --args "--db-config ssd"
```

#### For High Write Throughput
```bash
./scripts/run-monolithic.sh run --args "--batch-size 1000"
```

### Monitoring

#### Real-time Metrics
```bash
# Check flow manager status
curl http://localhost:9650/ext/avalanche/flow/status

# Check consensus metrics
curl http://localhost:9650/ext/avalanche/consensus/metrics

# Check state manager metrics
curl http://localhost:9650/ext/avalanche/state/metrics
```

## 🌐 API Endpoints

### Health Check
```bash
curl http://localhost:9650/ext/health
```

### Node Information
```bash
curl -X POST http://localhost:9650/ext/info \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"info.getNodeVersion","params":{},"id":1}'
```

### Flow Manager Status
```bash
curl http://localhost:9650/ext/avalanche/flow/status
```

### Consensus Metrics
```bash
curl http://localhost:9650/ext/avalanche/consensus/metrics
```

### State Manager Metrics
```bash
curl http://localhost:9650/ext/avalanche/state/metrics
```

## 📈 Expected Performance

### Typical Benchmarks

| Configuration | TPS | Response Time | Error Rate |
|---------------|-----|---------------|------------|
| **Development** (1 core, 2GB RAM) | 500-800 TPS | 50-100ms | <1% |
| **Production** (4 cores, 8GB RAM) | 2000-5000 TPS | 20-50ms | <0.1% |
| **High-End** (8+ cores, 16GB+ RAM) | 5000+ TPS | <20ms | <0.01% |

### Comparison: Monolithic vs Microservices

| Metric | Monolithic | Microservices | Winner |
|--------|------------|---------------|---------|
| **Latency** | Lower (direct calls) | Higher (network overhead) | Monolithic |
| **Throughput** | Higher (no serialization) | Lower (network/serialization) | Monolithic |
| **Memory Usage** | Lower (single process) | Higher (multiple processes) | Monolithic |
| **Scalability** | Vertical only | Horizontal + Vertical | Microservices |
| **Complexity** | Lower | Higher | Monolithic |

## 🆘 Support

### Getting Help

1. **Check Documentation**: Review this guide thoroughly
2. **Check Logs**: Enable debug logging and check log files
3. **Check Issues**: Look for similar issues in project repository
4. **Community Support**: Join AvalancheGo community channels

### Reporting Issues

When reporting issues, please include:
- Operating system and version
- Go version
- Complete error messages
- Steps to reproduce
- Log files (with debug level)

### Contributing

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

---

**Next Steps**: After setup, try running the benchmark to compare monolithic vs microservices performance!

```bash
# Quick benchmark
./microservices/scripts/benchmark/avalanche-monolithic-vs-microservices.sh --duration 120

# View results
cat ./benchmark-results/*/comparison_report.md
``` 