# 📁 Scripts Directory Structure

Script telah diorganisir berdasarkan fungsinya untuk memudahkan pengelolaan dan penggunaan.

## 📂 Struktur Direktori

```
scripts/
├── 📦 deployment/          # Script untuk deployment dan restart
├── ⚙️ setup/               # Script untuk setup dan konfigurasi
├── 📊 benchmark/           # Script untuk benchmark dan testing performa
├── 🧹 maintenance/         # Script untuk pembersihan dan maintenance
├── 📈 scaling/             # Script untuk scaling dan node management
├── 🧪 testing/             # Script untuk testing dan validasi
├── 🔧 utility/             # Script utility dan helper
└── 📋 README.md            # Dokumentasi ini
```

## 📦 Deployment Scripts

**Lokasi:** `scripts/deployment/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `deploy.ps1` | Deploy ke Kubernetes | Windows |
| `deploy.sh` | Deploy ke Kubernetes | Linux/WSL |
| `deploy-docker.ps1` | Deploy dengan Docker Compose | Windows |
| `deploy-docker.sh` | Deploy dengan Docker Compose | Linux/WSL |
| `restart.ps1` | Restart services | Windows |
| `restart.sh` | Restart services | Linux/WSL |
| `restart-docker.ps1` | Restart Docker services | Windows |
| `restart-docker.sh` | Restart Docker services | Linux/WSL |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\deployment\deploy-docker.ps1 --build --workers 3
.\scripts\deployment\deploy.ps1 -Build -Registry localhost:5000

# Linux/WSL
./scripts/deployment/deploy-docker.sh --build --workers 3
./scripts/deployment/deploy.sh --build --registry localhost:5000
```

## ⚙️ Setup Scripts

**Lokasi:** `scripts/setup/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `setup-k8s.ps1` | Setup Kubernetes cluster | Windows |
| `setup-k8s.sh` | Setup Kubernetes cluster | Linux/WSL |
| `make-executable.sh` | Set permissions untuk script | Linux/WSL |
| `fix-metrics-server.sh` | Fix metrics server issues | Linux/WSL |
| `create-docker-compose.ps1` | Generate docker-compose.yml | Windows |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\setup\setup-k8s.ps1 -Provider kind

# Linux/WSL
./scripts/setup/setup-k8s.sh --provider kind
./scripts/setup/make-executable.sh
```

## 📊 Benchmark Scripts

**Lokasi:** `scripts/benchmark/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `run_parallel_benchmark.ps1` | Benchmark parallel vs traditional | Windows |
| `run_parallel_benchmark.sh` | Benchmark parallel vs traditional | Linux/WSL |
| `simple_benchmark.ps1` | Benchmark sederhana | Windows |
| `simple_benchmark.sh` | Benchmark sederhana | Linux/WSL |
| `benchmark_sim.go` | Simulasi benchmark | Go |
| `visualize_benchmark.go` | Visualisasi hasil benchmark | Go |
| `transaction_load.go` | Load testing untuk transaksi | Go |
| `transaction_load_test.go` | Unit test untuk load testing | Go |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\benchmark\run_parallel_benchmark.ps1 -FullTest
.\scripts\benchmark\simple_benchmark.ps1

# Linux/WSL
./scripts/benchmark/run_parallel_benchmark.sh --full-test
./scripts/benchmark/simple_benchmark.sh

# Go scripts
go run scripts/benchmark/transaction_load.go --benchmark
go run scripts/benchmark/visualize_benchmark.go
```

## 🧹 Maintenance Scripts

**Lokasi:** `scripts/maintenance/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `cleanup-all.ps1` | Pembersihan lengkap Docker & K8s | Windows |
| `cleanup-all.sh` | Pembersihan lengkap Docker & K8s | Linux/WSL |
| `update-imports.ps1` | Update import paths | Windows |
| `update-dockerfiles.ps1` | Update Dockerfiles | Windows |
| `replace-imports.sh` | Replace import paths | Linux/WSL |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\maintenance\cleanup-all.ps1

# Linux/WSL
./scripts/maintenance/cleanup-all.sh
```

## 📈 Scaling Scripts

**Lokasi:** `scripts/scaling/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `dynamic-node-scaler.ps1` | Kubernetes dynamic scaling | Windows |
| `dynamic-node-scaler.sh` | Kubernetes dynamic scaling | Linux/WSL |
| `docker-dynamic-scaler.sh` | Docker dynamic scaling | Linux/WSL |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\scaling\dynamic-node-scaler.ps1 scale-up --type worker --replicas 5

# Linux/WSL
./scripts/scaling/dynamic-node-scaler.sh scale-up --type worker --replicas 5
./scripts/scaling/docker-dynamic-scaler.sh add-node --type worker
```

## 🧪 Testing Scripts

**Lokasi:** `scripts/testing/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `run_blockchain_tests.ps1` | Test blockchain functionality | Windows |
| `run_blockchain_tests.sh` | Test blockchain functionality | Linux/WSL |
| `runtest.ps1` | General test runner | Windows |

**Contoh Penggunaan:**
```powershell
# Windows
.\scripts\testing\run_blockchain_tests.ps1 --benchmark

# Linux/WSL
./scripts/testing/run_blockchain_tests.sh --benchmark
```

## 🔧 Utility Scripts

**Lokasi:** `scripts/utility/`

| Script | Deskripsi | Platform |
|--------|-----------|----------|
| `chmod.bat` | Set permissions (Windows) | Windows |

## 🚀 Quick Start Guide

### 1. Setup Environment
```powershell
# Windows
.\scripts\setup\setup-k8s.ps1 -Provider kind

# Linux/WSL
./scripts/setup/make-executable.sh
./scripts/setup/setup-k8s.sh --provider kind
```

### 2. Deploy System
```powershell
# Docker Compose (Development)
.\scripts\deployment\deploy-docker.ps1 --build --workers 3

# Kubernetes (Production)
.\scripts\deployment\deploy.ps1 -Build
```

### 3. Run Benchmarks
```powershell
# Performance testing
.\scripts\benchmark\run_parallel_benchmark.ps1 -FullTest
```

### 4. Scale System
```powershell
# Add more workers
.\scripts\scaling\dynamic-node-scaler.ps1 scale-up --type worker --replicas 5
```

### 5. Cleanup (if needed)
```powershell
# Complete cleanup
.\scripts\maintenance\cleanup-all.ps1
```

## 📝 Notes

- **Windows**: Gunakan PowerShell (.ps1) scripts
- **Linux/WSL/Ubuntu**: Gunakan bash (.sh) scripts
- **Go**: Scripts dapat dijalankan dengan `go run`
- **Permissions**: Gunakan `./scripts/setup/make-executable.sh` untuk set permissions di Linux/WSL

## 🔗 Related Documentation

- [Main README](../README.md) - Dokumentasi utama proyek
- [Dynamic Scaling Guide](../DYNAMIC-SCALING-GUIDE.md) - Panduan scaling
- [Linux/WSL Setup](../LINUX-WSL-SETUP.md) - Setup untuk Linux/WSL
- [Troubleshooting](../troubleshoot-metrics-server.md) - Troubleshooting guide 