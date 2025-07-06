# 🚀 Panduan Setup Avalanche Parallel Processing

Dokumen ini berisi panduan lengkap untuk setup dan konfigurasi sistem Avalanche Parallel Processing.

## 📑 Daftar Isi
- [Prasyarat](#-prasyarat)
- [Instalasi](#-instalasi)
- [Konfigurasi](#-konfigurasi)
- [Verifikasi](#-verifikasi)
- [Troubleshooting](#-troubleshooting)

## 📋 Prasyarat

### 1. Software Requirements

- **Docker & Docker Compose**
  - Docker Desktop (Windows/Mac)
  - Docker Engine (Linux)
  - Minimum version: 20.10.0+

- **Kubernetes Tools**
  - kubectl
  - kind atau minikube (opsional)
  - Helm (opsional)

- **Development Tools**
  - Go 1.21+
  - Git
  - PowerShell 7+ (Windows)
  - WSL2 (Windows)

### 2. Hardware Requirements

- **Minimum:**
  - CPU: 4 cores
  - RAM: 8GB
  - Storage: 50GB free space

- **Recommended:**
  - CPU: 8 cores
  - RAM: 16GB
  - Storage: 100GB free space

### 3. Network Requirements

- **Ports:**
  - 9650: API Gateway
  - 9750: Metrics
  - 6379: Redis
  - 5432: PostgreSQL
  - 8082: DAG State
  - 9090: Prometheus
  - 3000: Grafana

## 🔧 Instalasi

### 1. Clone Repository

```bash
# Clone repository
git clone https://github.com/your-org/avalanche-parallel.git
cd avalanche-parallel/microservices

# Update submodules (jika ada)
git submodule update --init --recursive
```

### 2. Setup Environment

#### Windows:
```powershell
# 1. Install Chocolatey (jika belum)
Set-ExecutionPolicy Bypass -Scope Process -Force
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))

# 2. Install dependencies
choco install docker-desktop kubernetes-cli golang git -y

# 3. Enable WSL2
wsl --install

# 4. Setup environment
.\scripts\setup\setup-environment.ps1
```

#### Linux/Ubuntu:
```bash
# 1. Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 2. Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# 3. Install Go
wget https://golang.org/dl/go1.21.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.linux-amd64.tar.gz
echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
source ~/.bashrc

# 4. Setup environment
./scripts/setup/setup-environment.sh
```

#### macOS:
```bash
# 1. Install Homebrew (jika belum)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 2. Install dependencies
brew install docker kubernetes-cli go git

# 3. Setup environment
./scripts/setup/setup-environment.sh
```

### 3. Konfigurasi Database

```bash
# 1. Setup PostgreSQL
docker-compose -f docker-compose.setup.yml up -d postgres

# 2. Initialize database
./scripts/setup/init-database.sh

# 3. Verify database
psql -h localhost -U avalanche -d avalanche -c "\dt"
```

### 4. Setup Redis

```bash
# 1. Start Redis
docker-compose -f docker-compose.setup.yml up -d redis

# 2. Verify Redis
redis-cli ping
```

## ⚙️ Konfigurasi

### 1. Environment Variables

1. **Copy template:**
   ```bash
   cp .env.example .env
   ```

2. **Edit konfigurasi:**
   ```env
   # API Gateway
   API_PORT=9650
   METRICS_PORT=9750

   # Database
   POSTGRES_USER=avalanche
   POSTGRES_PASSWORD=your_secure_password
   POSTGRES_DB=avalanche

   # Redis
   REDIS_PASSWORD=your_secure_password
   REDIS_PORT=6379

   # Workers
   MAX_WORKERS=15
   BATCH_SIZE=100
   LOG_LEVEL=info
   ```

### 2. Worker Configuration

1. **Edit `config/worker-config.yaml`:**
   ```yaml
   consensus_workers:
     min_replicas: 2
     max_replicas: 10
     resources:
       requests:
         cpu: "500m"
         memory: "512Mi"
       limits:
         cpu: "1000m"
         memory: "1Gi"

   validator_workers:
     min_replicas: 3
     max_replicas: 15
     resources:
       requests:
         cpu: "250m"
         memory: "256Mi"
       limits:
         cpu: "500m"
         memory: "512Mi"
   ```

### 3. Monitoring Setup

1. **Configure Prometheus:**
   ```bash
   # Edit prometheus config
   nano monitoring/prometheus-worker.yml
   ```

2. **Configure Grafana:**
   ```bash
   # Import dashboards
   cp monitoring/dashboards/* /etc/grafana/provisioning/dashboards/
   ```

## ✅ Verifikasi

### 1. Verify Services

```bash
# 1. Check Docker services
docker-compose ps

# 2. Check Kubernetes services (if using K8s)
kubectl get pods -n avalanche-parallel

# 3. Check logs
docker-compose logs -f
```

### 2. Run Tests

```bash
# 1. Unit tests
go test ./...

# 2. Integration tests
./scripts/testing/run-integration-tests.sh

# 3. Load tests
./scripts/benchmark/run-load-tests.sh
```

### 3. Verify Monitoring

1. Access Grafana: http://localhost:3000
   - Username: admin
   - Password: admin

2. Access Prometheus: http://localhost:9090

## ❗ Troubleshooting

### Common Issues

1. **Docker Permission Issues:**
   ```bash
   # Add user to docker group
   sudo usermod -aG docker $USER
   newgrp docker
   ```

2. **Database Connection:**
   ```bash
   # Check PostgreSQL logs
   docker-compose logs postgres

   # Test connection
   psql -h localhost -U avalanche -d avalanche
   ```

3. **Redis Connection:**
   ```bash
   # Check Redis logs
   docker-compose logs redis

   # Test connection
   redis-cli ping
   ```

4. **Worker Issues:**
   ```bash
   # Check worker logs
   docker-compose logs worker-1

   # Restart worker
   docker-compose restart worker-1
   ```

### Performance Issues

1. **Check resource usage:**
   ```bash
   docker stats
   ```

2. **Monitor metrics:**
   ```bash
   # Open Grafana
   open http://localhost:3000
   ```

3. **Adjust worker configuration:**
   ```bash
   # Edit worker config
   nano config/worker-config.yaml
   ```

## 📝 Notes

1. **Security:**
   - Change default passwords
   - Use secure network configuration
   - Enable TLS in production

2. **Backup:**
   - Regular database backups
   - Configuration backups
   - State backups

3. **Monitoring:**
   - Set up alerts
   - Monitor resource usage
   - Check logs regularly

4. **Updates:**
   - Keep dependencies updated
   - Follow security advisories
   - Test updates in staging 