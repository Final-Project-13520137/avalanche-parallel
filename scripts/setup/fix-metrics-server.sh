#!/bin/bash

# Fix Metrics Server Issues Script
set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_msg() {
    local color=$1
    local msg=$2
    echo -e "${color}${msg}${NC}"
}

print_msg $GREEN "=== Fixing Metrics Server Issues ==="

# Check if kubectl is available
if ! command -v kubectl >/dev/null 2>&1; then
    print_msg $RED "kubectl is not installed. Please install kubectl first."
    exit 1
fi

# Check cluster connectivity
if ! kubectl cluster-info --request-timeout=5s >/dev/null 2>&1; then
    print_msg $RED "No Kubernetes cluster found or cluster is not accessible."
    exit 1
fi

print_msg $YELLOW "Removing existing metrics server installation..."

# Delete existing metrics server components
kubectl delete deployment metrics-server -n kube-system --ignore-not-found=true
kubectl delete service metrics-server -n kube-system --ignore-not-found=true
kubectl delete serviceaccount metrics-server -n kube-system --ignore-not-found=true
kubectl delete clusterrole system:aggregated-metrics-reader --ignore-not-found=true
kubectl delete clusterrole system:metrics-server --ignore-not-found=true
kubectl delete clusterrolebinding metrics-server:system:auth-delegator --ignore-not-found=true
kubectl delete clusterrolebinding system:metrics-server --ignore-not-found=true
kubectl delete rolebinding metrics-server-auth-reader -n kube-system --ignore-not-found=true
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found=true

print_msg $YELLOW "Waiting for cleanup to complete..."
sleep 10

print_msg $YELLOW "Installing metrics server with proper configuration..."

# Create metrics server manifest
cat > /tmp/metrics-server-fixed.yaml << 'EOF'
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
    rbac.authorization.k8s.io/aggregate-to-admin: "true"
    rbac.authorization.k8s.io/aggregate-to-edit: "true"
    rbac.authorization.k8s.io/aggregate-to-view: "true"
  name: system:aggregated-metrics-reader
rules:
- apiGroups:
  - metrics.k8s.io
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
rules:
- apiGroups:
  - ""
  resources:
  - nodes/metrics
  verbs:
  - get
- apiGroups:
  - ""
  resources:
  - pods
  - nodes
  verbs:
  - get
  - list
  - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server-auth-reader
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: extension-apiserver-authentication-reader
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server:system:auth-delegator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  labels:
    k8s-app: metrics-server
  name: system:metrics-server
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:metrics-server
subjects:
- kind: ServiceAccount
  name: metrics-server
  namespace: kube-system
---
apiVersion: v1
kind: Service
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  ports:
  - name: https
    port: 443
    protocol: TCP
    targetPort: https
  selector:
    k8s-app: metrics-server
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    k8s-app: metrics-server
  name: metrics-server
  namespace: kube-system
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  strategy:
    rollingUpdate:
      maxUnavailable: 0
  template:
    metadata:
      labels:
        k8s-app: metrics-server
    spec:
      containers:
      - args:
        - --cert-dir=/tmp
        - --secure-port=4443
        - --kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname
        - --kubelet-use-node-status-port
        - --metric-resolution=15s
        - --kubelet-insecure-tls
        image: registry.k8s.io/metrics-server/metrics-server:v0.7.0
        imagePullPolicy: IfNotPresent
        livenessProbe:
          failureThreshold: 3
          httpGet:
            path: /livez
            port: https
            scheme: HTTPS
          periodSeconds: 10
        name: metrics-server
        ports:
        - containerPort: 4443
          name: https
          protocol: TCP
        readinessProbe:
          failureThreshold: 3
          httpGet:
            path: /readyz
            port: https
            scheme: HTTPS
          initialDelaySeconds: 20
          periodSeconds: 10
        resources:
          requests:
            cpu: 100m
            memory: 200Mi
        securityContext:
          allowPrivilegeEscalation: false
          readOnlyRootFilesystem: true
          runAsNonRoot: true
          runAsUser: 1000
        volumeMounts:
        - mountPath: /tmp
          name: tmp-dir
      nodeSelector:
        kubernetes.io/os: linux
      priorityClassName: system-cluster-critical
      serviceAccountName: metrics-server
      volumes:
      - emptyDir: {}
        name: tmp-dir
---
apiVersion: apiregistration.k8s.io/v1
kind: APIService
metadata:
  labels:
    k8s-app: metrics-server
  name: v1beta1.metrics.k8s.io
spec:
  group: metrics.k8s.io
  groupPriorityMinimum: 100
  insecureSkipTLSVerify: true
  service:
    name: metrics-server
    namespace: kube-system
  version: v1beta1
  versionPriority: 100
EOF

# Apply the manifest
kubectl apply -f /tmp/metrics-server-fixed.yaml

print_msg $YELLOW "Waiting for metrics server to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/metrics-server -n kube-system

# Clean up temp file
rm -f /tmp/metrics-server-fixed.yaml

print_msg $GREEN "Metrics server installation completed!"

# Test metrics server
print_msg $YELLOW "Testing metrics server..."
sleep 30  # Wait for metrics to be collected

if kubectl top nodes >/dev/null 2>&1; then
    print_msg $GREEN "Metrics server is working correctly!"
    kubectl top nodes
else
    print_msg $YELLOW "Metrics server may need more time to collect metrics. Try 'kubectl top nodes' in a few minutes."
fi

print_msg $GREEN "=== Metrics server fix completed! ===" 