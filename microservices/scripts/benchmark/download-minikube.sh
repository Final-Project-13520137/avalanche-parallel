#!/bin/bash

# Download minikube binary
curl -Lo minikube-linux-amd64 https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64

# Make it executable
chmod +x minikube-linux-amd64

echo "Minikube binary downloaded successfully" 