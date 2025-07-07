# 📁 Panduan Penggunaan Avalanche Parallel Processing

Dokumentasi lengkap untuk menjalankan sistem Avalanche Parallel Processing.

## 📑 Daftar Isi
- [Prasyarat](#-prasyarat)
- [Persiapan Environment](#-persiapan-environment)
- [Deployment](#-deployment)
  - [Docker Deployment](#docker-deployment)
  - [Kubernetes Deployment](#kubernetes-deployment)
- [Scaling](#-scaling)
- [Monitoring](#-monitoring)
- [Maintenance](#-maintenance)
- [Troubleshooting](#-troubleshooting)

## 🔧 Prasyarat

1. **Docker**
   - [Docker Desktop](https://www.docker.com/products/docker-desktop/) untuk Windows/Mac
   - [Docker Engine](https://docs.docker.com/engine/install/) untuk Linux

2. **Kubernetes** (opsional, untuk deployment Kubernetes)
   - Docker Desktop Kubernetes, atau
   - [Minikube](https://minikube.sigs.k8s.io/docs/start/), atau
   - [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)

3. **Tools**
   - Git
   - Git Bash (Windows) atau Terminal (Linux/Mac)
   - [kubectl](https://kubernetes.io/docs/tasks/tools/) (untuk Kubernetes)
   - WSL2 (Opsional untuk Windows)

> ⚠️ **PENTING**: Untuk Windows, gunakan Git Bash atau WSL terminal untuk menjalankan script. PowerShell tidak didukung sepenuhnya untuk beberapa script bash.

## 🚀 Persiapan Environment

### Windows (Git Bash)

```bash
# Buat script executable
chmod +x ./scripts/setup/*.sh
chmod +x ./scripts/deployment/*.sh
chmod +x ./scripts/scaling/*.sh
chmod +x ./scripts/maintenance/*.sh

# Setup environment
./scripts/setup/setup-environment.sh --provider docker-desktop

# Setup local registry (untuk Kubernetes)
./scripts/setup/setup-registry.sh --force
```

### Linux/WSL

```bash
# Buat script executable
chmod +x ./scripts/setup/*.sh
chmod +x ./scripts/deployment/*.sh
chmod +x ./scripts/scaling/*.sh
chmod +x ./scripts/maintenance/*.sh

# Setup environment
./scripts/setup/setup-environment.sh --provider docker-desktop

# Setup local registry (untuk Kubernetes)
./scripts/setup/setup-registry.sh --force
```

## 📦 Deployment

### Docker Deployment

Deployment menggunakan Docker Compose lebih sederhana dan cocok untuk development.

#### Windows (Git Bash)
```bash
# 1. Cleanup resources (jika ada)
./scripts/maintenance/cleanup-all.sh --force

# 2. Deploy dengan 3 worker
./scripts/deployment/deploy-docker.sh --build --workers 3

# 3. Verifikasi deployment
docker ps
```

#### Linux/WSL
```bash
# 1. Cleanup resources (jika ada)
./scripts/maintenance/cleanup-all.sh --force

# 2. Deploy dengan 3 worker
./scripts/deployment/deploy-docker.sh --build --workers 3

# 3. Verifikasi deployment
docker ps
```

### Kubernetes Deployment

Deployment menggunakan Kubernetes lebih kompleks tapi lebih powerful untuk production.

#### Windows (Git Bash)
```bash
# 1. Pastikan registry lokal berjalan
./scripts/setup/setup-registry.sh --force

# 2. Cleanup resources (jika ada)
./scripts/maintenance/cleanup-all.sh --force

# 3. Siapkan build context (PENTING!)
./scripts/setup/prepare-build.sh

# 4. Deploy ke Kubernetes
./scripts/deployment/deploy-k8s.sh --build --registry localhost:5000

# 5. Verifikasi deployment
kubectl get pods -n avalanche-parallel
```

#### Linux/WSL
```bash
# 1. Pastikan registry lokal berjalan
./scripts/setup/setup-registry.sh --force

# 2. Cleanup resources (jika ada)
./scripts/maintenance/cleanup-all.sh --force

# 3. Siapkan build context (PENTING!)
./scripts/setup/prepare-build.sh

# 4. Deploy ke Kubernetes
./scripts/deployment/deploy-k8s.sh --build --registry localhost:5000

# 5. Verifikasi deployment
kubectl get pods -n avalanche-parallel
```

> ⚠️ **PENTING**: Selalu jalankan `prepare-build.sh` sebelum menjalankan `deploy-k8s.sh` untuk memastikan build context disiapkan dengan benar.

### Troubleshooting Deployment

1. **Error "target is not a directory" atau "Missing go.mod"**
   ```bash
   # Pastikan menjalankan prepare-build terlebih dahulu
   ./scripts/setup/prepare-build.sh
   
   # Jika masih error, coba cleanup dan ulangi
   ./scripts/maintenance/cleanup-all.sh --force
   ./scripts/setup/prepare-build.sh
   ```

2. **Permission Issues**
   ```bash
   # Set executable permission untuk semua script
   chmod +x ./scripts/**/*.sh
   ```

3. **Script Tidak Berjalan di PowerShell**
   ```bash
   # Gunakan Git Bash atau WSL terminal sebagai gantinya
   # Jangan gunakan PowerShell untuk menjalankan script .sh
   ```

## 📈 Scaling

### Manual Scaling

#### Windows
```powershell
# Scale validator workers
.\scripts\scaling\scale-workers.ps1 -WorkerType validator -Count 5 -Monitor

# Scale consensus workers
.\scripts\scaling\scale-workers.ps1 -WorkerType consensus -Count 3 -Monitor

# Scale DAG state workers
.\scripts\scaling\scale-workers.ps1 -WorkerType dag-state -Count 4 -Monitor
```

#### Linux/WSL
```bash
# Scale validator workers
./scripts/scaling/scale-workers.sh --type validator --count 5 --monitor

# Scale consensus workers
./scripts/scaling/scale-workers.sh --type consensus --count 3 --monitor

# Scale DAG state workers
./scripts/scaling/scale-workers.sh --type dag-state --count 4 --monitor
```

### Auto Scaling

#### Windows
```powershell
# Auto-scaling validator workers
.\scripts\scaling\auto-scale.ps1 -WorkerType validator `
    -MinWorkers 2 `
    -MaxWorkers 10 `
    -CpuThresholdUp 80 `
    -CpuThresholdDown 20
```

#### Linux/WSL
```bash
# Auto-scaling validator workers
./scripts/scaling/auto-scale.sh --type validator \
    --min-workers 2 \
    --max-workers 10 \
    --cpu-up 80 \
    --cpu-down 20
```

## 📊 Monitoring

### Akses Dashboard

1. **Grafana Dashboard**
   - Docker: http://localhost:3000
   - Kubernetes: http://localhost:30300
   - Credentials: admin/avalanche123

2. **API Gateway**
   - Docker: http://localhost:8080
   - Kubernetes: http://localhost:30080

### Melihat Logs

#### Docker
```bash
# Lihat logs semua services
docker-compose logs -f

# Lihat logs specific service
docker-compose logs -f validator-worker
```

#### Kubernetes
```bash
# Lihat logs semua pods
kubectl logs -f -n avalanche-parallel -l app=avalanche

# Lihat logs specific pod
kubectl logs -f -n avalanche-parallel <pod-name>
```

## 🧹 Maintenance

### Cleanup Resources

#### Windows
```powershell
# Cleanup semua resources
.\scripts\maintenance\cleanup-all.ps1 -Force

# Cleanup specific resources
.\scripts\maintenance\cleanup-all.ps1 -Type workers
```

#### Linux/WSL
```bash
# Cleanup semua resources
./scripts/maintenance/cleanup-all.sh --force

# Cleanup specific resources
./scripts/maintenance/cleanup-all.sh --type workers
```

## ❗ Troubleshooting

### Common Issues

1. **Docker Registry Error**
   ```bash
   # Restart registry
   docker restart registry
   # atau
   ./scripts/setup/setup-registry.sh --force
   ```

2. **Permission Issues**
   ```bash
   # Windows
   Set-ExecutionPolicy RemoteSigned -Scope Process
   
   # Linux
   chmod +x ./scripts/**/*.sh
   ```

3. **Network Issues**
   ```bash
   # Check Docker network
   docker network ls
   docker network inspect avalanche-network
   
   # Reset network
   docker network prune
   ```

4. **Resource Issues**
   ```bash
   # Check resource usage
   docker stats
   
   # Clean up resources
   docker system prune -a
   ```

### Best Practices

1. **Deployment**
   - Selalu backup data sebelum deployment
   - Mulai dengan Docker untuk development
   - Gunakan Kubernetes untuk production
   - Monitor logs setelah deployment

2. **Scaling**
   - Mulai dengan jumlah worker minimal
   - Scale up secara bertahap
   - Monitor resource usage
   - Gunakan auto-scaling di production

3. **Monitoring**
   - Check dashboard secara regular
   - Setup alerts untuk kondisi kritis
   - Maintain log rotation
   - Monitor disk space

4. **Maintenance**
   - Jalankan cleanup secara regular
   - Backup data penting
   - Update dependencies
   - Check security patches 