#!/usr/bin/env pwsh

Write-Host "🧹 Pembersihan Lengkap Docker dan Kubernetes" -ForegroundColor Yellow
Write-Host "=========================================" -ForegroundColor Yellow

# Fungsi untuk konfirmasi
function Confirm-Action {
    param($Message)
    $response = Read-Host "$Message (y/N)"
    return $response -eq 'y' -or $response -eq 'Y'
}

# Konfirmasi sebelum menghapus
if (!(Confirm-Action "Apakah Anda yakin ingin menghapus SEMUA container, image, dan resource Kubernetes?")) {
    Write-Host "❌ Pembersihan dibatalkan." -ForegroundColor Red
    exit 0
}

Write-Host "🔄 Memulai pembersihan..." -ForegroundColor Green

# 1. Hentikan dan hapus semua container Docker
Write-Host "🐳 Menghentikan dan menghapus semua container Docker..." -ForegroundColor Cyan
try {
    $containers = docker ps -aq
    if ($containers) {
        docker stop $containers
        docker rm $containers
        Write-Host "✅ Semua container dihapus" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Tidak ada container yang ditemukan" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Error menghapus container: $($_.Exception.Message)" -ForegroundColor Red
}

# 2. Hapus semua image Docker
Write-Host "🖼️ Menghapus semua image Docker..." -ForegroundColor Cyan
try {
    $images = docker images -aq
    if ($images) {
        docker rmi $images --force
        Write-Host "✅ Semua image dihapus" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Tidak ada image yang ditemukan" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Error menghapus image: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Hapus semua volume Docker
Write-Host "💾 Menghapus semua volume Docker..." -ForegroundColor Cyan
try {
    $volumes = docker volume ls -q
    if ($volumes) {
        docker volume rm $volumes --force
        Write-Host "✅ Semua volume dihapus" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Tidak ada volume yang ditemukan" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Error menghapus volume: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Hapus semua network Docker (kecuali default)
Write-Host "🌐 Menghapus network Docker..." -ForegroundColor Cyan
try {
    $networks = docker network ls --filter type=custom -q
    if ($networks) {
        docker network rm $networks
        Write-Host "✅ Network custom dihapus" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Tidak ada network custom yang ditemukan" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Error menghapus network: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Bersihkan Docker system
Write-Host "🧽 Membersihkan sistem Docker..." -ForegroundColor Cyan
try {
    docker system prune -af --volumes
    Write-Host "✅ Sistem Docker dibersihkan" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Error membersihkan sistem Docker: $($_.Exception.Message)" -ForegroundColor Red
}

# 6. Hapus resource Kubernetes
Write-Host "☸️ Menghapus resource Kubernetes..." -ForegroundColor Cyan
try {
    # Hapus namespace avalanche-parallel
    kubectl delete namespace avalanche-parallel --ignore-not-found=true
    Write-Host "✅ Namespace avalanche-parallel dihapus" -ForegroundColor Green
    
    # Hapus deployment dan service yang mungkin ada di default namespace
    kubectl delete deployment,service,configmap,secret -l app=avalanche-parallel --ignore-not-found=true
    Write-Host "✅ Resource Kubernetes dihapus" -ForegroundColor Green
    
    # Hapus metrics server jika ada
    kubectl delete deployment metrics-server -n kube-system --ignore-not-found=true
    Write-Host "✅ Metrics server dihapus" -ForegroundColor Green
    
} catch {
    Write-Host "⚠️ Error menghapus resource Kubernetes: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. Reset kind cluster (jika menggunakan kind)
Write-Host "🔄 Reset kind cluster..." -ForegroundColor Cyan
try {
    $kindClusters = kind get clusters 2>$null
    if ($kindClusters) {
        foreach ($cluster in $kindClusters) {
            kind delete cluster --name $cluster
            Write-Host "✅ Kind cluster '$cluster' dihapus" -ForegroundColor Green
        }
    } else {
        Write-Host "ℹ️ Tidak ada kind cluster yang ditemukan" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️ Error menghapus kind cluster: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. Reset minikube (jika menggunakan minikube)
Write-Host "🔄 Reset minikube..." -ForegroundColor Cyan
try {
    $minikubeStatus = minikube status 2>$null
    if ($minikubeStatus) {
        minikube delete --all
        Write-Host "✅ Minikube dihapus" -ForegroundColor Green
    } else {
        Write-Host "ℹ️ Minikube tidak aktif" -ForegroundColor Yellow
    }
} catch {
    Write-Host "ℹ️ Minikube tidak terinstal atau tidak aktif" -ForegroundColor Yellow
}

# 9. Hapus direktori build dan cache
Write-Host "🗂️ Menghapus direktori build dan cache..." -ForegroundColor Cyan
try {
    if (Test-Path "build") {
        Remove-Item -Recurse -Force "build"
        Write-Host "✅ Direktori build dihapus" -ForegroundColor Green
    }
    
    if (Test-Path "bin") {
        Remove-Item -Recurse -Force "bin"
        Write-Host "✅ Direktori bin dihapus" -ForegroundColor Green
    }
    
    # Hapus cache Go
    go clean -cache -modcache -testcache
    Write-Host "✅ Cache Go dibersihkan" -ForegroundColor Green
    
} catch {
    Write-Host "⚠️ Error menghapus direktori: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host ""
Write-Host "🎉 Pembersihan selesai!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host "✅ Semua container Docker dihapus" -ForegroundColor Green
Write-Host "✅ Semua image Docker dihapus" -ForegroundColor Green
Write-Host "✅ Semua volume Docker dihapus" -ForegroundColor Green
Write-Host "✅ Network Docker dibersihkan" -ForegroundColor Green
Write-Host "✅ Resource Kubernetes dihapus" -ForegroundColor Green
Write-Host "✅ Cluster Kubernetes direset" -ForegroundColor Green
Write-Host "✅ Cache dan build directory dibersihkan" -ForegroundColor Green
Write-Host ""
Write-Host "🚀 Sekarang Anda dapat memulai dari awal dengan perintah:" -ForegroundColor Cyan
Write-Host "   .\setup-k8s.ps1 -Provider kind" -ForegroundColor White
Write-Host "   .\deploy-docker.ps1 --build --workers 3" -ForegroundColor White
Write-Host "   atau" -ForegroundColor White
Write-Host "   cd deployments\kubernetes && .\deploy.ps1 -Build" -ForegroundColor White 