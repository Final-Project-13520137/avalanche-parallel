#!/bin/bash
# Setup environment for Avalanche Parallel Processing

# Default values
PROVIDER="docker-desktop"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

echo -e "\e[32m⚙️ Setting up environment for Avalanche Parallel Processing...\e[0m"

# Check prerequisites
echo -e "\e[33mChecking prerequisites...\e[0m"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "\e[31m❌ Docker not found. Please install Docker.\e[0m"
    exit 1
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "\e[31m❌ Docker Compose not found. Please install Docker Compose.\e[0m"
    exit 1
fi

# Check Go
if ! command -v go &> /dev/null; then
    echo -e "\e[31m❌ Go not found. Please install Go.\e[0m"
    exit 1
fi

# Setup Kubernetes if needed
if [ "$PROVIDER" = "docker-desktop" ]; then
    echo -e "\e[33mSetting up Docker Desktop Kubernetes...\e[0m"
    
    # Enable Kubernetes in Docker Desktop
    echo -e "\e[36mPlease enable Kubernetes in Docker Desktop settings manually.\e[0m"
    
    # Wait for confirmation
    read -p "Press Enter after enabling Kubernetes in Docker Desktop"
    
    # Verify Kubernetes
    kubectl version
    if [ $? -ne 0 ]; then
        echo -e "\e[31m❌ Kubernetes setup failed.\e[0m"
        exit 1
    fi
elif [ "$PROVIDER" = "kind" ]; then
    echo -e "\e[33mSetting up kind cluster...\e[0m"
    
    # Install kind if not present
    if ! command -v kind &> /dev/null; then
        echo -e "\e[36mInstalling kind...\e[0m"
        curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
        chmod +x ./kind
        sudo mv ./kind /usr/local/bin/kind
    fi
    
    # Create kind cluster
    kind create cluster --name avalanche-parallel
elif [ "$PROVIDER" = "minikube" ]; then
    echo -e "\e[33mSetting up minikube...\e[0m"
    
    # Install minikube if not present
    if ! command -v minikube &> /dev/null; then
        echo -e "\e[36mInstalling minikube...\e[0m"
        curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
        sudo install minikube-linux-amd64 /usr/local/bin/minikube
    fi
    
    # Start minikube
    minikube start
fi

# Create necessary directories
echo -e "\e[33mCreating necessary directories...\e[0m"
mkdir -p logs volumes

# Copy configuration files
echo -e "\e[33mSetting up configuration...\e[0m"
cp .env.example .env

echo -e "\e[32m✅ Environment setup completed!\e[0m"
echo -e "\e[36m🔍 Next steps:
1. Edit .env file with your configuration
2. Run deployment script:
   ./scripts/deployment/deploy-docker.sh --build\e[0m" 