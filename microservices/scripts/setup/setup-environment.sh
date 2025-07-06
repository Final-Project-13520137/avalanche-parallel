#!/bin/bash
# Setup environment for Avalanche Parallel Processing

# Default values
PROVIDER=""
FORCE=false

# Function to show usage
usage() {
    echo "Usage: $0 --provider <docker-desktop|kind|minikube> [--force]"
    echo
    echo "Options:"
    echo "  --provider    Kubernetes provider (required)"
    echo "  --force      Skip confirmations"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        --force)
            FORCE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate provider
if [[ ! "$PROVIDER" =~ ^(docker-desktop|kind|minikube)$ ]]; then
    echo "Invalid provider. Must be docker-desktop, kind, or minikube."
    usage
fi

echo -e "\e[32m⚙️ Setting up environment for Avalanche Parallel Processing...\e[0m"

# Function to install Docker
install_docker() {
    if ! command -v docker &> /dev/null; then
        echo -e "\e[33mInstalling Docker...\e[0m"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        rm get-docker.sh
    fi
}

# Function to install Go
install_go() {
    if ! command -v go &> /dev/null; then
        echo -e "\e[33mInstalling Go...\e[0m"
        wget https://golang.org/dl/go1.21.linux-amd64.tar.gz
        sudo tar -C /usr/local -xzf go1.21.linux-amd64.tar.gz
        echo 'export PATH=$PATH:/usr/local/go/bin' >> ~/.bashrc
        source ~/.bashrc
        rm go1.21.linux-amd64.tar.gz
    fi
}

# Function to install Kubernetes tools
install_kubernetes_tools() {
    # Install kubectl
    if ! command -v kubectl &> /dev/null; then
        echo -e "\e[33mInstalling kubectl...\e[0m"
        curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
        sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
        rm kubectl
    fi
    
    # Install specific provider tools
    case $PROVIDER in
        kind)
            if ! command -v kind &> /dev/null; then
                echo -e "\e[33mInstalling kind...\e[0m"
                curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.11.1/kind-linux-amd64
                chmod +x ./kind
                sudo mv ./kind /usr/local/bin/kind
            fi
            ;;
        minikube)
            if ! command -v minikube &> /dev/null; then
                echo -e "\e[33mInstalling minikube...\e[0m"
                curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
                sudo install minikube-linux-amd64 /usr/local/bin/minikube
                rm minikube-linux-amd64
            fi
            ;;
    esac
}

# Function to setup Kubernetes
setup_kubernetes() {
    echo -e "\e[33mSetting up Kubernetes with $PROVIDER...\e[0m"
    
    case $PROVIDER in
        docker-desktop)
            echo -e "\e[36mPlease enable Kubernetes in Docker Desktop settings manually.\e[0m"
            read -p "Press Enter after enabling Kubernetes in Docker Desktop"
            
            # Verify Kubernetes
            if ! kubectl version &> /dev/null; then
                echo -e "\e[31m❌ Kubernetes setup failed.\e[0m"
                exit 1
            fi
            ;;
        kind)
            echo -e "\e[33mCreating kind cluster...\e[0m"
            kind create cluster --name avalanche-parallel
            ;;
        minikube)
            echo -e "\e[33mStarting minikube...\e[0m"
            minikube start
            ;;
    esac
}

# Function to create directories
create_directories() {
    echo -e "\e[33mCreating necessary directories...\e[0m"
    
    directories=(
        "logs"
        "volumes"
        "volumes/redis"
        "volumes/postgres"
        "volumes/prometheus"
        "volumes/grafana"
    )
    
    for dir in "${directories[@]}"; do
        mkdir -p "$dir"
    done
}

# Function to setup configuration
setup_configuration() {
    echo -e "\e[33mSetting up configuration...\e[0m"
    
    # Copy example files if they exist
    if [ -f .env.example ]; then
        cp .env.example .env
    fi
    
    if [ -f config/worker-config.example.yaml ]; then
        cp config/worker-config.example.yaml config/worker-config.yaml
    fi
}

# Main setup process
{
    # Install prerequisites
    install_docker
    install_go
    install_kubernetes_tools
    
    # Setup Kubernetes
    setup_kubernetes
    
    # Create directories
    create_directories
    
    # Setup configuration
    setup_configuration
    
    echo -e "\n\e[32m✅ Environment setup completed!\e[0m"
    echo -e "\e[36m🔍 Next steps:
1. Edit .env file with your configuration
2. Start services with: ./scripts/deployment/deploy-docker.sh --build
3. Monitor with: http://localhost:3000 (Grafana)\e[0m"
    
} || {
    echo -e "\e[31m❌ Error during setup\e[0m"
    exit 1
} 