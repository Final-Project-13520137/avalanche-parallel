#!/bin/bash

# Remove minikube binary if exists
if [ -f "minikube-linux-amd64" ]; then
    echo "Removing minikube binary..."
    rm minikube-linux-amd64
fi

# Remove other large files
echo "Cleaning up benchmark results..."
rm -rf benchmark-results/*
touch benchmark-results/.gitkeep

echo "Cleanup completed successfully" 