# Panduan Mengatasi Masalah Docker Monitoring

## Masalah: Docker Credentials Error

Error yang sering muncul:
```
error getting credentials - err: exit status 1, out: ``
```

### 🔧 Solusi Cepat

**Untuk Linux/WSL:**
```bash
cd microservices
chmod +x fix-docker-monitoring-simple.sh
./fix-docker-monitoring-simple.sh
```

**Untuk Windows (PowerShell):**
```powershell
cd microservices
.\fix-docker-monitoring.ps1
```

### 🔧 Solusi Manual

#### 1. Hapus Version dari docker-compose.yml

File `docker-compose.monitoring.yml` sudah diperbaiki dengan menghapus:
```yaml
version: '3.8'  # <- Ini sudah dihapus
```

#### 2. Bersihkan Docker Credentials

**Linux/WSL:**
```bash
# Backup config lama
cp ~/.docker/config.json ~/.docker/config.json.backup

# Buat config baru tanpa credential store
echo '{"auths": {}}' > ~/.docker/config.json
```

**Windows:**
```powershell
# Backup config lama
Copy-Item "$env:USERPROFILE\.docker\config.json" "$env:USERPROFILE\.docker\config.json.backup"

# Buat config baru
'{"auths": {}}' | Out-File -FilePath "$env:USERPROFILE\.docker\config.json" -Encoding UTF8
```

#### 3. Buat Network Worker

```bash
docker network create avalanche-worker-network
```

#### 4. Buat Direktori yang Diperlukan

```bash
mkdir -p monitoring/{prometheus,grafana/{provisioning/{datasources,dashboards},dashboards},alertmanager,loki,promtail,otel,nginx}
mkdir -p sql
```

#### 5. Tarik Images Secara Manual

```bash
# Images utama yang sering bermasalah
docker pull redis:7-alpine
docker pull postgres:15-alpine
docker pull nginx:1.24-alpine
docker pull prom/prometheus:v2.40.0
docker pull grafana/grafana:9.2.0
```

#### 6. Jalankan Monitoring Stack

```bash
# Bersihkan container lama
docker-compose -f docker-compose.monitoring.yml down --remove-orphans

# Mulai stack baru
docker-compose -f docker-compose.monitoring.yml up -d
```

### 🔍 Diagnosa Masalah

#### Cek Status Container
```bash
docker-compose -f docker-compose.monitoring.yml ps
```

#### Cek Log Error
```bash
# Log semua layanan
docker-compose -f docker-compose.monitoring.yml logs

# Log layanan spesifik
docker-compose -f docker-compose.monitoring.yml logs grafana
docker-compose -f docker-compose.monitoring.yml logs prometheus
```

#### Cek Network
```bash
docker network ls | grep avalanche
```

#### Cek Port yang Digunakan
```bash
# Linux/WSL
netstat -tulpn | grep -E "3000|9090|9093"

# Windows
netstat -an | findstr "3000 9090 9093"
```

### ⚠️ Masalah Umum dan Solusi

#### 1. Network Pool Overlap Error

Error: `failed to create network microservices_monitoring: Error response from daemon: invalid pool request: Pool overlaps with other one on this address space`

**Solusi Cepat:**
```bash
# Linux/WSL
cd microservices
chmod +x fix-monitoring-network.sh
./fix-monitoring-network.sh

# Windows PowerShell
cd microservices
.\fix-monitoring-network.ps1
```

**Solusi Manual:**
```bash
# 1. Stop monitoring containers
docker-compose -f docker-compose.monitoring.yml down --remove-orphans

# 2. Remove conflicting networks
docker network rm microservices_monitoring 2>/dev/null || true

# 3. Prune unused networks
docker network prune -f

# 4. Update subnet in docker-compose.monitoring.yml
# Ganti subnet dari 172.20.0.0/16 ke 172.30.0.0/16 atau lainnya

# 5. Start monitoring stack
docker-compose -f docker-compose.monitoring.yml up -d
```

#### 2. Port Sudah Digunakan

Error: `bind: address already in use`

**Solusi:**
```bash
# Cek proses yang menggunakan port
sudo lsof -i :3000  # Ganti dengan port yang bermasalah

# Atau hentikan semua container
docker stop $(docker ps -q)
```

#### 2. Permission Denied (Linux)

**Solusi:**
```bash
# Tambahkan user ke grup docker
sudo usermod -aG docker $USER

# Logout dan login kembali, atau:
newgrp docker
```

#### 3. Image Pull Gagal

**Solusi:**
```bash
# Reset Docker daemon
sudo systemctl restart docker

# Atau coba pull manual
docker pull --disable-content-trust grafana/grafana:9.2.0
```

#### 4. Grafana Tidak Dapat Diakses

**Cek:**
1. Container berjalan: `docker ps | grep grafana`
2. Port terbuka: `curl http://localhost:3000`
3. Log error: `docker logs avalanche-grafana`

**Solusi:**
```bash
# Restart container grafana
docker-compose -f docker-compose.monitoring.yml restart grafana
```

#### 5. Prometheus Config Error

**Cek:**
```bash
# Cek syntax config
docker exec avalanche-prometheus promtool check config /etc/prometheus/prometheus.yml
```

**Solusi:**
```bash
# Edit config jika ada error
nano monitoring/prometheus/prometheus.yml

# Restart prometheus
docker-compose -f docker-compose.monitoring.yml restart prometheus
```

### 🚀 Verifikasi Setup Berhasil

Setelah setup, cek endpoint berikut:

1. **Grafana**: http://localhost:3000 (admin/admin)
2. **Prometheus**: http://localhost:9090
3. **AlertManager**: http://localhost:9093
4. **Container Status**: Semua container harus "Up"

### 📚 Tools Debugging

```bash
# Cek semua container Docker
docker ps -a

# Cek penggunaan resource
docker stats

# Cek network Docker
docker network inspect avalanche-worker-network

# Reset semua (hati-hati!)
docker system prune -a --volumes
```

### 🆘 Jika Masih Bermasalah

1. **Restart Docker Service:**
   ```bash
   sudo systemctl restart docker
   ```

2. **Bersihkan Semua:**
   ```bash
   docker system prune -a --volumes
   docker network prune
   ```

3. **Cek Log Docker Daemon:**
   ```bash
   sudo journalctl -u docker.service
   ```

4. **Gunakan Docker Desktop** (Windows/Mac) dan restart aplikasi

### 📞 Mendapatkan Bantuan

Jika masih ada masalah, jalankan ini dan kirim outputnya:

```bash
# Informasi sistem
docker version
docker-compose version
docker info

# Status containers
docker-compose -f docker-compose.monitoring.yml ps

# Log terakhir
docker-compose -f docker-compose.monitoring.yml logs --tail=50
``` 