#!/bin/bash

# Utility script to make all bash scripts executable
# For Linux/WSL/Ubuntu users

echo "Making all bash scripts executable..."

# Set executable permissions for all shell scripts
chmod +x setup-k8s.sh
chmod +x deploy-docker.sh
chmod +x fix-metrics-server.sh
chmod +x dynamic-node-scaler.sh
chmod +x docker-dynamic-scaler.sh
chmod +x deployments/kubernetes/deploy.sh

# Set permissions for fixer scripts
chmod +x fixer/*.sh

# Set permissions for other scripts
chmod +x scripts/*.sh

echo "All bash scripts are now executable!"
echo ""
echo "Available commands:"
echo "  ./setup-k8s.sh --help"
echo "  ./deploy-docker.sh --help"
echo "  ./deployments/kubernetes/deploy.sh --help" 