#!/bin/bash

# Script to download kubectl binary
# This script downloads kubectl to avoid having large binaries in the git repository

set -e

KUBECTL_VERSION="v1.28.2"
OS="linux"
ARCH="amd64"

# Detect OS
if [[ "$OSTYPE" == "darwin"* ]]; then
    OS="darwin"
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "win32" ]]; then
    OS="windows"
    KUBECTL_VERSION="${KUBECTL_VERSION}.exe"
fi

# Detect architecture
if [[ $(uname -m) == "arm64" ]] || [[ $(uname -m) == "aarch64" ]]; then
    ARCH="arm64"
fi

KUBECTL_URL="https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/${OS}/${ARCH}/kubectl"

echo "🔽 Downloading kubectl ${KUBECTL_VERSION} for ${OS}/${ARCH}..."
echo "URL: ${KUBECTL_URL}"

# Download kubectl
if command -v curl >/dev/null 2>&1; then
    curl -LO "${KUBECTL_URL}"
elif command -v wget >/dev/null 2>&1; then
    wget "${KUBECTL_URL}"
else
    echo "❌ Error: curl or wget is required to download kubectl"
    exit 1
fi

# Make it executable (Linux/macOS only)
if [[ "$OS" != "windows" ]]; then
    chmod +x kubectl
    echo "✅ kubectl downloaded and made executable"
else
    echo "✅ kubectl.exe downloaded"
fi

# Verify the download
echo "🔍 Verifying kubectl..."
if [[ "$OS" == "windows" ]]; then
    ./kubectl.exe version --client
else
    ./kubectl version --client
fi

echo "✅ kubectl is ready to use!"
echo "💡 You can move it to your PATH or use it from the current directory" 