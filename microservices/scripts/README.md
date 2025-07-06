# 📁 Scripts untuk Avalanche Parallel Processing

Dokumentasi lengkap untuk penggunaan scripts dalam sistem Avalanche Parallel Processing.

## 📑 Daftar Isi
- [Struktur Direktori](#-struktur-direktori)
- [Panduan Penggunaan](#-panduan-penggunaan)
  - [Deployment Scripts](#deployment-scripts)
  - [Scaling Scripts](#scaling-scripts)
  - [Maintenance Scripts](#maintenance-scripts)
  - [Setup Scripts](#setup-scripts)
  - [Benchmark Scripts](#benchmark-scripts)
  - [Testing Scripts](#testing-scripts)
- [Troubleshooting](#-troubleshooting)

## 📂 Struktur Direktori

```
scripts/
├── deployment/          # Script untuk deployment
│   ├── deploy-docker.ps1      # Deploy dengan Docker (Windows)
│   ├── deploy-docker.sh       # Deploy dengan Docker (Linux)
│   ├── deploy-k8s.ps1        # Deploy ke Kubernetes (Windows)
│   └── deploy-k8s.sh         # Deploy ke Kubernetes (Linux)
├── scaling/            # Script untuk scaling
│   ├── scale-workers.ps1     # Manual scaling (Windows)
│   ├── scale-workers.sh      # Manual scaling (Linux)
│   ├── auto-scale.ps1        # Auto-scaling (Windows)
│   └── auto-scale.sh         # Auto-scaling (Linux)
├── maintenance/        # Script untuk maintenance
│   ├── cleanup-all.ps1       # Cleanup resources (Windows)
│   └── cleanup-all.sh        # Cleanup resources (Linux)
├── setup/             # Script untuk setup
│   ├── setup-environment.ps1 # Setup environment (Windows)
│   └── setup-environment.sh  # Setup environment (Linux)
├── benchmark/         # Script untuk benchmark
│   ├── run-benchmark.ps1     # Run benchmark (Windows)
│   └── run-benchmark.sh      # Run benchmark (Linux)
```

## 🚀 Panduan Penggunaan

### Deployment Scripts

#### Docker Deployment
```powershell
# Windows
.\scripts\deployment\deploy-docker.ps1 -Build -Workers 3

# Linux/WSL
./scripts/deployment/deploy-docker.sh --build --workers 3
```

#### Kubernetes Deployment
```powershell
# Windows
.\scripts\deployment\deploy-k8s.ps1 -Build -Registry localhost:5000

# Linux/WSL
./scripts/deployment/deploy-k8s.sh --build --registry localhost:5000
```

### Scaling Scripts

#### Manual Scaling
```powershell
# Windows - Scale validator workers
.\scripts\scaling\scale-workers.ps1 -WorkerType validator -Count 5 -Monitor

# Linux/WSL - Scale validator workers
./scripts/scaling/scale-workers.sh --type validator --count 5 --monitor
```

Opsi untuk `scale-workers`:
- `-WorkerType`/`--type`: `consensus`, `validator`, atau `dag-state`
- `-Count`/`--count`: Jumlah worker yang diinginkan
- `-Monitor`/`--monitor`: Monitor progress scaling
- `-Force`/`--force`: Skip resource checks

#### Auto-scaling
```powershell
# Windows - Auto-scaling validator workers
.\scripts\scaling\auto-scale.ps1 -WorkerType validator `
    -MinWorkers 2 `
    -MaxWorkers 10 `
    -CpuThresholdUp 80 `
    -CpuThresholdDown 20 `
    -QueueThresholdUp 100 `
    -QueueThresholdDown 10

# Linux/WSL - Auto-scaling validator workers
./scripts/scaling/auto-scale.sh --type validator \
    --min-workers 2 \
    --max-workers 10 \
    --cpu-up 80 \
    --cpu-down 20 \
    --queue-up 100 \
    --queue-down 10
```

Opsi untuk `auto-scale`:
- `-WorkerType`/`--type`: Tipe worker
- `-MinWorkers`/`--min-workers`: Minimum jumlah workers
- `-MaxWorkers`/`--max-workers`: Maximum jumlah workers
- `-CpuThresholdUp`/`--cpu-up`: CPU threshold untuk scale up (%)
- `-CpuThresholdDown`/`--cpu-down`: CPU threshold untuk scale down (%)
- `-QueueThresholdUp`/`--queue-up`: Queue threshold untuk scale up
- `-QueueThresholdDown`/`--queue-down`: Queue threshold untuk scale down
- `-CheckInterval`/`--interval`: Interval pengecekan (detik)

### Maintenance Scripts

```powershell
# Windows - Cleanup resources
.\scripts\maintenance\cleanup-all.ps1 -Force

# Linux/WSL - Cleanup resources
./scripts/maintenance/cleanup-all.sh --force
```

### Setup Scripts

```powershell
# Windows - Setup environment
.\scripts\setup\setup-environment.ps1 -Provider docker-desktop

# Linux/WSL - Setup environment
./scripts/setup/setup-environment.sh --provider docker-desktop
```

Opsi provider:
- `docker-desktop`: Docker Desktop dengan Kubernetes
- `kind`: Kubernetes in Docker
- `minikube`: Minikube

### Benchmark Scripts

```powershell
# Windows - Run benchmark
.\scripts\benchmark\run-benchmark.ps1 -Workers 5 -Transactions 1000

# Linux/WSL - Run benchmark
./scripts/benchmark/run-benchmark.sh --workers 5 --transactions 1000
```

### Testing Scripts

```powershell
# Windows - Run tests
.\scripts\testing\run-tests.ps1

# Linux/WSL - Run tests
./scripts/testing/run-tests.sh
```

## ❗ Troubleshooting

### Common Issues

1. **Permission Issues**
   ```powershell
   # Windows
   Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

   # Linux/WSL
   chmod +x ./scripts/setup/set-permissions.sh
   ./scripts/setup/set-permissions.sh
   ```

2. **Docker Issues**
   ```bash
   # Check Docker status
   docker info

   # Reset Docker environment
   .\scripts\maintenance\cleanup-all.ps1 -Force
   ```

3. **Scaling Issues**
   ```bash
   # Check worker status
   docker ps --filter "name=worker"

   # Check logs
   docker-compose logs -f
   ```

### Best Practices

1. **Deployment**:
   - Selalu backup data sebelum deployment
   - Gunakan flag `-Build`/`--build` untuk rebuild images
   - Monitor logs setelah deployment

2. **Scaling**:
   - Mulai dengan manual scaling untuk testing
   - Gunakan auto-scaling dengan threshold yang sesuai
   - Monitor resource usage

3. **Maintenance**:
   - Jalankan cleanup secara regular
   - Backup data penting
   - Monitor disk space

4. **Testing**:
   - Run tests sebelum deployment
   - Verifikasi semua services berjalan
   - Check logs untuk errors

### Logging

Semua scripts menggunakan sistem logging yang konsisten:
- ✅ Success messages: Hijau
- ⚠️ Warnings: Kuning
- ❌ Errors: Merah
- ℹ️ Info: Cyan
- 📊 Metrics: Default

Logs tersimpan di:
- Windows: `logs\script-name.log`
- Linux: `logs/script-name.log` 