# 📁 Scripts untuk Avalanche Parallel Processing

Direktori ini berisi semua script yang diperlukan untuk mengelola dan menjalankan sistem Avalanche Parallel Processing.

## 📑 Struktur Direktori

```
scripts/
├── deployment/          # Script untuk deployment
│   ├── deploy-docker.ps1      # Deploy dengan Docker (Windows)
│   ├── deploy-docker.sh       # Deploy dengan Docker (Linux)
│   ├── deploy-k8s.ps1        # Deploy ke Kubernetes (Windows)
│   └── deploy-k8s.sh         # Deploy ke Kubernetes (Linux)
├── setup/               # Script untuk setup environment
│   ├── setup-environment.ps1  # Setup environment (Windows)
│   └── setup-environment.sh   # Setup environment (Linux)
├── benchmark/          # Script untuk benchmark
│   ├── run-benchmark.ps1      # Run benchmark (Windows)
│   └── run-benchmark.sh       # Run benchmark (Linux)
├── maintenance/        # Script untuk maintenance
│   ├── cleanup-all.ps1        # Cleanup resources (Windows)
│   └── cleanup-all.sh         # Cleanup resources (Linux)
├── scaling/           # Script untuk scaling
│   ├── scale-workers.ps1      # Scale workers (Windows)
│   └── scale-workers.sh       # Scale workers (Linux)
├── testing/           # Script untuk testing
│   ├── run-tests.ps1          # Run tests (Windows)
│   └── run-tests.sh           # Run tests (Linux)
└── utility/           # Script utility
    ├── set-permissions.ps1    # Set permissions (Windows)
    └── set-permissions.sh     # Set permissions (Linux)
```

## 🚀 Penggunaan

### 1. Setup Environment

**Windows:**
```powershell
# Setup dengan Docker Desktop
.\scripts\setup\setup-environment.ps1 -Provider docker-desktop

# Setup dengan kind
.\scripts\setup\setup-environment.ps1 -Provider kind

# Setup dengan minikube
.\scripts\setup\setup-environment.ps1 -Provider minikube
```

**Linux/WSL:**
```bash
# Setup dengan Docker Desktop
./scripts/setup/setup-environment.sh --provider docker-desktop

# Setup dengan kind
./scripts/setup/setup-environment.sh --provider kind

# Setup dengan minikube
./scripts/setup/setup-environment.sh --provider minikube
```

### 2. Deployment

**Windows:**
```powershell
# Deploy dengan Docker
.\scripts\deployment\deploy-docker.ps1 -Build -Workers 3

# Deploy ke Kubernetes
.\scripts\deployment\deploy-k8s.ps1 -Build -Registry localhost:5000
```

**Linux/WSL:**
```bash
# Deploy dengan Docker
./scripts/deployment/deploy-docker.sh --build --workers 3

# Deploy ke Kubernetes
./scripts/deployment/deploy-k8s.sh --build --registry localhost:5000
```

### 3. Maintenance

**Windows:**
```powershell
# Cleanup normal
.\scripts\maintenance\cleanup-all.ps1

# Force cleanup
.\scripts\maintenance\cleanup-all.ps1 -Force
```

**Linux/WSL:**
```bash
# Cleanup normal
./scripts/maintenance/cleanup-all.sh

# Force cleanup
./scripts/maintenance/cleanup-all.sh --force
```

### 4. Benchmark

**Windows:**
```powershell
# Run benchmark
.\scripts\benchmark\run-benchmark.ps1 -Workers 5 -Transactions 1000
```

**Linux/WSL:**
```bash
# Run benchmark
./scripts/benchmark/run-benchmark.sh --workers 5 --transactions 1000
```

### 5. Testing

**Windows:**
```powershell
# Run tests
.\scripts\testing\run-tests.ps1
```

**Linux/WSL:**
```bash
# Run tests
./scripts/testing/run-tests.sh
```

## 📝 Notes

1. **Windows Users:**
   - Gunakan script PowerShell (.ps1)
   - Run PowerShell sebagai Administrator untuk beberapa operasi
   - Pastikan execution policy diset dengan benar:
     ```powershell
     Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
     ```

2. **Linux/WSL Users:**
   - Gunakan script bash (.sh)
   - Set executable permissions:
     ```bash
     chmod +x ./scripts/setup/set-permissions.sh
     ./scripts/setup/set-permissions.sh
     ```

3. **Best Practices:**
   - Selalu backup data sebelum menjalankan cleanup
   - Monitor resource usage saat scaling
   - Review logs secara regular
   - Jalankan benchmark setelah perubahan signifikan

4. **Troubleshooting:**
   - Cek logs di direktori `logs/`
   - Gunakan flag `-Verbose` (PowerShell) atau `--verbose` (bash) untuk debug
   - Lihat [DOCKER-TROUBLESHOOTING.md](../DOCKER-TROUBLESHOOTING.md) untuk masalah Docker 