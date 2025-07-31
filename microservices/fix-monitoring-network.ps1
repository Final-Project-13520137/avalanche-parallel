# Script PowerShell untuk memperbaiki konflik network monitoring
param(
    [switch]$Force = $false
)

Write-Host "🔧 Memperbaiki konflik network monitoring..." -ForegroundColor Cyan

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

# Check if we're in the right directory
if (-not (Test-Path "docker-compose.monitoring.yml")) {
    Write-Error "File docker-compose.monitoring.yml tidak ditemukan!"
    Write-Error "Pastikan Anda berada di direktori microservices\"
    exit 1
}

try {
    # 1. Stop and remove any existing monitoring containers
    Write-Step "Menghentikan container monitoring yang ada..."
    try {
        docker-compose -f docker-compose.monitoring.yml down --remove-orphans 2>$null
    } catch {
        # Ignore errors if containers don't exist
    }

    # 2. Remove conflicting networks
    Write-Step "Membersihkan network yang konflik..."
    
    $networksToCheck = @(
        "microservices_monitoring",
        "monitoring", 
        "avalanche-monitoring"
    )

    foreach ($network in $networksToCheck) {
        $networkExists = docker network ls --format "{{.Name}}" | Select-String "^$network$"
        if ($networkExists) {
            Write-Warning "Menghapus network: $network"
            try {
                docker network rm $network 2>$null
            } catch {
                # Ignore errors if network is in use
            }
        }
    }

    # 3. Check existing subnet usage
    Write-Step "Memeriksa penggunaan subnet yang ada..."
    Write-Host "Subnet yang sedang digunakan:"
    
    $networks = docker network ls --format "{{.Name}}" | Where-Object { $_ -notin @("bridge", "host", "none") }
    foreach ($network in $networks) {
        try {
            $subnet = docker network inspect $network --format '{{range .IPAM.Config}}{{.Subnet}}{{end}}' 2>$null
            if ($subnet -and $subnet -ne "N/A") {
                Write-Host "  - $network`: $subnet" -ForegroundColor Gray
            }
        } catch {
            # Ignore inspection errors
        }
    }

    # 4. Create avalanche-worker-network if it doesn't exist
    Write-Step "Memastikan network worker tersedia..."
    $workerNetworkExists = docker network ls --format "{{.Name}}" | Select-String "^avalanche-worker-network$"
    if (-not $workerNetworkExists) {
        docker network create avalanche-worker-network --subnet=172.25.0.0/16
        Write-Success "Network avalanche-worker-network dibuat dengan subnet 172.25.0.0/16"
    } else {
        Write-Success "Network avalanche-worker-network sudah ada"
    }

    # 5. Prune unused networks to clean up
    Write-Step "Membersihkan network yang tidak digunakan..."
    docker network prune -f

    # 6. Test network creation without starting services
    Write-Step "Testing konfigurasi network monitoring..."
    $testNetworkName = "test-monitoring"
    try {
        docker network create $testNetworkName --subnet=172.30.0.0/16 2>$null
        docker network rm $testNetworkName 2>$null
        Write-Success "Subnet 172.30.0.0/16 tersedia untuk monitoring"
    } catch {
        Write-Warning "Subnet 172.30.0.0/16 mungkin konflik, menggunakan alternatif..."
        
        # Try alternative subnets
        $alternativeSubnets = @(
            "172.31.0.0/16",
            "172.32.0.0/16", 
            "10.30.0.0/16",
            "192.168.30.0/24"
        )
        
        $subnetFound = $false
        foreach ($subnet in $alternativeSubnets) {
            $networkName = "test-monitoring-$($subnet -replace '[/.:]', '-')"
            try {
                docker network create $networkName --subnet=$subnet 2>$null
                docker network rm $networkName 2>$null
                Write-Success "Menggunakan subnet alternatif: $subnet"
                
                # Update docker-compose.yml with the working subnet
                $gateway = $subnet -replace '0/[0-9]+$', '1'
                
                $content = Get-Content "docker-compose.monitoring.yml" -Raw
                $content = $content -replace 'subnet: 172\.30\.0\.0/16', "subnet: $subnet"
                $content = $content -replace 'gateway: 172\.30\.0\.1', "gateway: $gateway"
                $content | Out-File "docker-compose.monitoring.yml" -Encoding UTF8
                
                Write-Success "File docker-compose.monitoring.yml diupdate dengan subnet $subnet"
                $subnetFound = $true
                break
            } catch {
                continue
            }
        }
        
        if (-not $subnetFound) {
            Write-Error "Tidak dapat menemukan subnet yang tersedia"
            exit 1
        }
    }

    # 7. Start monitoring stack
    Write-Step "Memulai monitoring stack..."
    $result = docker-compose -f docker-compose.monitoring.yml up -d
    
    if ($LASTEXITCODE -eq 0) {
        Write-Success "Monitoring stack berhasil dimulai!"
        
        # Wait a bit and check status
        Start-Sleep -Seconds 5
        Write-Host ""
        Write-Step "Status container:"
        docker-compose -f docker-compose.monitoring.yml ps
        
        Write-Host ""
        Write-Success "Setup selesai! Endpoints tersedia:"
        Write-Host "  - Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
        Write-Host "  - Prometheus: http://localhost:9090" -ForegroundColor White  
        Write-Host "  - AlertManager: http://localhost:9093" -ForegroundColor White
        
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