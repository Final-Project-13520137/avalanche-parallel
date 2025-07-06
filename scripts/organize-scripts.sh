#!/bin/bash

echo "🗂️ Mengorganisir Script berdasarkan Fungsi"
echo "========================================="

# Buat direktori untuk mengorganisir script
directories=(
    "deployment"
    "setup"
    "benchmark"
    "maintenance"
    "scaling"
    "testing"
    "utility"
)

for dir in "${directories[@]}"; do
    path="scripts/$dir"
    if [ ! -d "$path" ]; then
        mkdir -p "$path"
        echo "✅ Dibuat direktori: $dir"
    fi
done

echo "🔄 Memindahkan script ke direktori yang sesuai..."

# Deployment Scripts
deployment_scripts=(
    "deploy.ps1"
    "deploy.sh"
    "deploy-docker.ps1"
    "deploy-docker.sh"
    "restart.ps1"
    "restart.sh"
    "restart-docker.ps1"
    "restart-docker.sh"
)

for script in "${deployment_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/deployment/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "📦 Dipindahkan: $script -> deployment/"
    fi
done

# Setup Scripts
setup_scripts=(
    "setup-k8s.ps1"
    "setup-k8s.sh"
    "make-executable.sh"
    "fix-metrics-server.sh"
    "create-docker-compose.ps1"
)

for script in "${setup_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/setup/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "⚙️ Dipindahkan: $script -> setup/"
    fi
done

# Benchmark Scripts
benchmark_scripts=(
    "run_parallel_benchmark.ps1"
    "run_parallel_benchmark.sh"
    "simple_benchmark.ps1"
    "simple_benchmark.sh"
    "benchmark_sim.go"
    "visualize_benchmark.go"
    "transaction_load.go"
    "transaction_load_test.go"
)

for script in "${benchmark_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/benchmark/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "📊 Dipindahkan: $script -> benchmark/"
    fi
done

# Maintenance Scripts
maintenance_scripts=(
    "cleanup-all.ps1"
    "cleanup-all.sh"
    "update-imports.ps1"
    "update-dockerfiles.ps1"
    "replace-imports.sh"
)

for script in "${maintenance_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/maintenance/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "🧹 Dipindahkan: $script -> maintenance/"
    fi
done

# Scaling Scripts
scaling_scripts=(
    "dynamic-node-scaler.ps1"
    "dynamic-node-scaler.sh"
    "docker-dynamic-scaler.sh"
)

for script in "${scaling_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/scaling/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "📈 Dipindahkan: $script -> scaling/"
    fi
done

# Testing Scripts
testing_scripts=(
    "run_blockchain_tests.ps1"
    "run_blockchain_tests.sh"
    "runtest.ps1"
)

for script in "${testing_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/testing/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "🧪 Dipindahkan: $script -> testing/"
    fi
done

# Utility Scripts
utility_scripts=(
    "chmod.bat"
)

for script in "${utility_scripts[@]}"; do
    source="scripts/$script"
    dest="scripts/utility/$script"
    if [ -f "$source" ]; then
        mv "$source" "$dest"
        echo "🔧 Dipindahkan: $script -> utility/"
    fi
done

echo ""
echo "🎉 Organisasi script selesai!"
echo "========================================="
echo "📦 Deployment: scripts/deployment/"
echo "⚙️ Setup: scripts/setup/"
echo "📊 Benchmark: scripts/benchmark/"
echo "🧹 Maintenance: scripts/maintenance/"
echo "📈 Scaling: scripts/scaling/"
echo "🧪 Testing: scripts/testing/"
echo "🔧 Utility: scripts/utility/"
echo ""
echo "💡 Contoh penggunaan:"
echo "   ./scripts/deployment/deploy-docker.sh --build"
echo "   ./scripts/setup/setup-k8s.sh --provider kind"
echo "   ./scripts/benchmark/run_parallel_benchmark.sh"
echo "   ./scripts/maintenance/cleanup-all.sh" 