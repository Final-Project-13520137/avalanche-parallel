#!/bin/bash

echo "🧹 Pembersihan Lengkap Docker dan Kubernetes"
echo "========================================="

# Fungsi untuk konfirmasi
confirm_action() {
    read -p "$1 (y/N): " response
    case $response in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Konfirmasi sebelum menghapus
if ! confirm_action "Apakah Anda yakin ingin menghapus SEMUA container, image, dan resource Kubernetes?"; then
    echo "❌ Pembersihan dibatalkan."
    exit 0
fi

echo "🔄 Memulai pembersihan..."

# 1. Hentikan dan hapus semua container Docker
echo "🐳 Menghentikan dan menghapus semua container Docker..."
containers=$(docker ps -aq 2>/dev/null)
if [ -n "$containers" ]; then
    docker stop $containers 2>/dev/null
    docker rm $containers 2>/dev/null
    echo "✅ Semua container dihapus"
else
    echo "ℹ️ Tidak ada container yang ditemukan"
fi

# 2. Hapus semua image Docker
echo "🖼️ Menghapus semua image Docker..."
images=$(docker images -aq 2>/dev/null)
if [ -n "$images" ]; then
    docker rmi $images --force 2>/dev/null
    echo "✅ Semua image dihapus"
else
    echo "ℹ️ Tidak ada image yang ditemukan"
fi

# 3. Hapus semua volume Docker
echo "💾 Menghapus semua volume Docker..."
volumes=$(docker volume ls -q 2>/dev/null)
if [ -n "$volumes" ]; then
    docker volume rm $volumes --force 2>/dev/null
    echo "✅ Semua volume dihapus"
else
    echo "ℹ️ Tidak ada volume yang ditemukan"
fi

# 4. Hapus semua network Docker (kecuali default)
echo "🌐 Menghapus network Docker..."
networks=$(docker network ls --filter type=custom -q 2>/dev/null)
if [ -n "$networks" ]; then
    docker network rm $networks 2>/dev/null
    echo "✅ Network custom dihapus"
else
    echo "ℹ️ Tidak ada network custom yang ditemukan"
fi

# 5. Bersihkan Docker system
echo "🧽 Membersihkan sistem Docker..."
docker system prune -af --volumes 2>/dev/null
echo "✅ Sistem Docker dibersihkan"

# 6. Hapus resource Kubernetes
echo "☸️ Menghapus resource Kubernetes..."
if command -v kubectl &> /dev/null; then
    # Hapus namespace avalanche-parallel
    kubectl delete namespace avalanche-parallel --ignore-not-found=true 2>/dev/null
    echo "✅ Namespace avalanche-parallel dihapus"
    
    # Hapus deployment dan service yang mungkin ada di default namespace
    kubectl delete deployment,service,configmap,secret -l app=avalanche-parallel --ignore-not-found=true 2>/dev/null
    echo "✅ Resource Kubernetes dihapus"
    
    # Hapus metrics server jika ada
    kubectl delete deployment metrics-server -n kube-system --ignore-not-found=true 2>/dev/null
    echo "✅ Metrics server dihapus"
else
    echo "ℹ️ kubectl tidak ditemukan, melewati pembersihan Kubernetes"
fi

# 7. Reset kind cluster (jika menggunakan kind)
echo "🔄 Reset kind cluster..."
if command -v kind &> /dev/null; then
    clusters=$(kind get clusters 2>/dev/null)
    if [ -n "$clusters" ]; then
        for cluster in $clusters; do
            kind delete cluster --name $cluster 2>/dev/null
            echo "✅ Kind cluster '$cluster' dihapus"
        done
    else
        echo "ℹ️ Tidak ada kind cluster yang ditemukan"
    fi
else
    echo "ℹ️ kind tidak terinstal"
fi

# 8. Reset minikube (jika menggunakan minikube)
echo "🔄 Reset minikube..."
if command -v minikube &> /dev/null; then
    if minikube status &> /dev/null; then
        minikube delete --all 2>/dev/null
        echo "✅ Minikube dihapus"
    else
        echo "ℹ️ Minikube tidak aktif"
    fi
else
    echo "ℹ️ Minikube tidak terinstal"
fi

# 9. Hapus direktori build dan cache
echo "🗂️ Menghapus direktori build dan cache..."
if [ -d "build" ]; then
    rm -rf build
    echo "✅ Direktori build dihapus"
fi

if [ -d "bin" ]; then
    rm -rf bin
    echo "✅ Direktori bin dihapus"
fi

# Hapus cache Go
if command -v go &> /dev/null; then
    go clean -cache -modcache -testcache 2>/dev/null
    echo "✅ Cache Go dibersihkan"
fi

echo ""
echo "🎉 Pembersihan selesai!"
echo "========================================="
echo "✅ Semua container Docker dihapus"
echo "✅ Semua image Docker dihapus"
echo "✅ Semua volume Docker dihapus"
echo "✅ Network Docker dibersihkan"
echo "✅ Resource Kubernetes dihapus"
echo "✅ Cluster Kubernetes direset"
echo "✅ Cache dan build directory dibersihkan"
echo ""
echo "🚀 Sekarang Anda dapat memulai dari awal dengan perintah:"
echo "   ./setup-k8s.sh --provider kind"
echo "   ./deploy-docker.sh --build --workers 3"
echo "   atau"
echo "   cd deployments/kubernetes && ./deploy.sh --build" 