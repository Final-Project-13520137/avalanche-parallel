# Script PowerShell untuk memperbaiki masalah Docker monitoring
param(
    [switch]$Force = $false
)

Write-Host "🔧 Memperbaiki monitoring stack Avalanche Parallel..." -ForegroundColor Cyan

function Write-Step {
    param([string]$Message)
    Write-Host "==> $Message" -ForegroundColor Blue
}

function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠ $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

# Cek apakah kita di direktori yang benar
if (-not (Test-Path "docker-compose.monitoring.yml")) {
    Write-Error "File docker-compose.monitoring.yml tidak ditemukan!"
    Write-Error "Pastikan Anda berada di direktori microservices\"
    exit 1
}

try {
    # 1. Bersihkan Docker credentials yang bermasalah
    Write-Step "Membersihkan Docker credentials..."
    $dockerConfigPath = "$env:USERPROFILE\.docker\config.json"
    
    if (Test-Path $dockerConfigPath) {
        # Backup file asli
        Copy-Item $dockerConfigPath "$dockerConfigPath.backup" -Force
        Write-Success "Backup docker config dibuat"
        
        # Buat config baru tanpa credential store
        $newConfig = @{
            auths = @{}
        }
        $newConfig | ConvertTo-Json | Out-File -FilePath $dockerConfigPath -Encoding UTF8
        Write-Success "Docker config dibersihkan"
    } else {
        # Buat direktori dan config baru
        $dockerDir = "$env:USERPROFILE\.docker"
        if (-not (Test-Path $dockerDir)) {
            New-Item -ItemType Directory -Path $dockerDir -Force | Out-Null
        }
        
        $newConfig = @{
            auths = @{}
        }
        $newConfig | ConvertTo-Json | Out-File -FilePath $dockerConfigPath -Encoding UTF8
        Write-Success "Docker config baru dibuat"
    }

    # 2. Buat network jika belum ada
    Write-Step "Membuat network worker..."
    $networkExists = docker network ls | Select-String "avalanche-worker-network"
    if (-not $networkExists) {
        docker network create avalanche-worker-network
        Write-Success "Network avalanche-worker-network dibuat"
    } else {
        Write-Success "Network avalanche-worker-network sudah ada"
    }

    # 3. Buat direktori yang diperlukan
    Write-Step "Membuat direktori monitoring..."
    $directories = @(
        "monitoring\prometheus",
        "monitoring\grafana\provisioning\datasources",
        "monitoring\grafana\provisioning\dashboards",
        "monitoring\grafana\dashboards",
        "monitoring\alertmanager",
        "monitoring\loki",
        "monitoring\promtail",
        "monitoring\otel",
        "monitoring\nginx",
        "sql"
    )

    foreach ($dir in $directories) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            Write-Success "Direktori $dir dibuat"
        }
    }

    # 4. Buat file init.sql jika belum ada
    if (-not (Test-Path "sql\init.sql")) {
        Write-Step "Membuat file init.sql..."
        $sqlContent = @"
-- Avalanche Parallel Database Initialization
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- Create tables for metrics storage
CREATE TABLE IF NOT EXISTS metrics_history (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT NOW(),
    metric_name VARCHAR(255),
    metric_value DECIMAL,
    labels JSONB
);

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_metrics_timestamp ON metrics_history(timestamp);
CREATE INDEX IF NOT EXISTS idx_metrics_name ON metrics_history(metric_name);
"@
        $sqlContent | Out-File -FilePath "sql\init.sql" -Encoding UTF8
        Write-Success "File sql\init.sql dibuat"
    }

    # 5. Buat nginx config jika belum ada
    if (-not (Test-Path "monitoring\nginx\nginx.conf")) {
        Write-Step "Membuat konfigurasi nginx..."
        $nginxContent = @"
events {
    worker_connections 1024;
}

http {
    upstream grafana {
        server grafana:3000;
    }
    
    upstream prometheus {
        server prometheus:9090;
    }
    
    upstream alertmanager {
        server alertmanager:9093;
    }
    
    server {
        listen 80;
        server_name localhost;
        
        location /grafana/ {
            proxy_pass http://grafana/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
        }
        
        location /prometheus/ {
            proxy_pass http://prometheus/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
        }
        
        location /alertmanager/ {
            proxy_pass http://alertmanager/;
            proxy_set_header Host `$host;
            proxy_set_header X-Real-IP `$remote_addr;
        }
        
        location / {
            return 302 /grafana/;
        }
    }
}
"@
        $nginxContent | Out-File -FilePath "monitoring\nginx\nginx.conf" -Encoding UTF8
        Write-Success "File nginx.conf dibuat"
    }

    # 6. Bersihkan container lama
    Write-Step "Membersihkan container lama..."
    try {
        docker-compose -f docker-compose.monitoring.yml down --remove-orphans 2>$null
    } catch {
        # Ignore errors if containers don't exist
    }

    # 7. Coba tarik image satu per satu untuk menghindari masalah credentials
    Write-Step "Menarik Docker images..."
    $images = @(
        "redis:7-alpine",
        "postgres:15-alpine",
        "nginx:1.24-alpine",
        "prom/prometheus:v2.40.0",
        "grafana/grafana:9.2.0",
        "prom/alertmanager:v0.25.0",
        "prom/node-exporter:v1.4.0"
    )

    foreach ($image in $images) {
        try {
            docker pull $image 2>$null
            Write-Success "Berhasil pull $image"
        } catch {
            Write-Warning "Skip $image - akan dicoba saat startup"
        }
    }

    # 8. Mulai monitoring stack
    Write-Step "Memulai monitoring stack..."
    $result = docker-compose -f docker-compose.monitoring.yml up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Monitoring stack berhasil dimulai"
        
        # 9. Tunggu sebentar dan cek layanan
        Write-Step "Menunggu layanan siap..."
        Start-Sleep -Seconds 15
        
        # Cek layanan utama
        try {
            $grafanaResponse = Invoke-WebRequest -Uri "http://localhost:3000" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Success "Grafana (port 3000) - Siap"
        } catch {
            Write-Warning "Grafana masih loading..."
        }
        
        try {
            $prometheusResponse = Invoke-WebRequest -Uri "http://localhost:9090" -Method Get -TimeoutSec 5 -ErrorAction SilentlyContinue
            Write-Success "Prometheus (port 9090) - Siap"
        } catch {
            Write-Warning "Prometheus masih loading..."
        }
        
        Write-Host ""
        Write-Host "📊 Endpoint monitoring:" -ForegroundColor Cyan
        Write-Host "- Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
        Write-Host "- Prometheus: http://localhost:9090" -ForegroundColor White
        Write-Host "- AlertManager: http://localhost:9093" -ForegroundColor White
        Write-Host ""
        
        Write-Step "Cek status container:"
        docker-compose -f docker-compose.monitoring.yml ps
        
        Write-Success "Setup selesai! Jika ada layanan yang belum siap, tunggu beberapa menit."
        
    } else {
        Write-Error "Gagal memulai monitoring stack"
        Write-Host ""
        Write-Step "Log error:"
        docker-compose -f docker-compose.monitoring.yml logs --tail=20
        exit 1
    }

} catch {
    Write-Error "Terjadi kesalahan: $($_.Exception.Message)"
    exit 1
} 