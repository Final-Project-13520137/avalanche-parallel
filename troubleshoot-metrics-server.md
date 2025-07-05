# Troubleshooting: Metrics Server Stuck "Waiting to be ready"

## 🚨 Situasi: Script terhenti di "Waiting for metrics server to be ready..."

### 1. **Buka Terminal Baru** (Jangan tutup terminal yang sedang waiting)

### 2. **Check Status Metrics Server**
```bash
# Check deployment status
kubectl get deployment metrics-server -n kube-system

# Check pods status
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check pod details
kubectl describe pod -n kube-system -l k8s-app=metrics-server
```

### 3. **Check Logs untuk Error**
```bash
# Check metrics server logs
kubectl logs -n kube-system deployment/metrics-server

# Check recent events
kubectl get events -n kube-system --sort-by=.metadata.creationTimestamp
```

### 4. **Common Issues & Solutions**

#### **Issue 1: Pod CrashLoopBackOff atau ImagePullError**
```bash
# Check pod status
kubectl get pods -n kube-system -l k8s-app=metrics-server

# If status shows CrashLoopBackOff or ImagePullError:
# Delete and recreate
kubectl delete deployment metrics-server -n kube-system
kubectl apply -f deployments/kubernetes/metrics-server.yaml
```

#### **Issue 2: Pod Running tapi Ready 0/1**
```bash
# Check readiness probe
kubectl describe pod -n kube-system -l k8s-app=metrics-server

# Check if it's a TLS issue (common in local clusters)
kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","args":["--cert-dir=/tmp","--secure-port=4443","--kubelet-preferred-address-types=InternalIP,ExternalIP,Hostname","--kubelet-use-node-status-port","--metric-resolution=15s","--kubelet-insecure-tls"]}]}}}}'
```

#### **Issue 3: Timeout karena Resource Constraints**
```bash
# Check node resources
kubectl top nodes

# If nodes are under resource pressure, increase metrics-server resources
kubectl patch deployment metrics-server -n kube-system --type='merge' -p='{"spec":{"template":{"spec":{"containers":[{"name":"metrics-server","resources":{"requests":{"cpu":"200m","memory":"300Mi"},"limits":{"cpu":"500m","memory":"500Mi"}}}]}}}}'
```

### 5. **Quick Fix Commands**

#### **Option A: Cancel dan Restart**
```bash
# In the stuck terminal, press Ctrl+C to cancel
# Then run the fix script:
./fix-metrics-server.sh
```

#### **Option B: Force Delete dan Reinstall**
```bash
# Force delete everything metrics-server related
kubectl delete deployment metrics-server -n kube-system --force --grace-period=0
kubectl delete service metrics-server -n kube-system --ignore-not-found=true
kubectl delete apiservice v1beta1.metrics.k8s.io --ignore-not-found=true

# Wait a moment
sleep 10

# Reinstall
kubectl apply -f deployments/kubernetes/metrics-server.yaml
```

#### **Option C: Skip Metrics Server (Temporary)**
```bash
# If you just want to proceed without metrics server:
# Cancel the current process (Ctrl+C)
# Deploy without waiting for metrics server:
kubectl apply -k . --validate=false
```

### 6. **Verification Commands**

```bash
# Check if metrics server is working
kubectl top nodes

# If above works, metrics server is ready
# Check pods metrics
kubectl top pods -n avalanche-parallel

# Check HPA status (requires metrics server)
kubectl get hpa -n avalanche-parallel
```

### 7. **Expected Output When Working**

```bash
# kubectl get deployment metrics-server -n kube-system
NAME             READY   UP-TO-DATE   AVAILABLE   AGE
metrics-server   1/1     1            1           2m

# kubectl get pods -n kube-system -l k8s-app=metrics-server
NAME                              READY   STATUS    RESTARTS   AGE
metrics-server-7c4c8b7b9c-xyz12   1/1     Running   0          2m

# kubectl top nodes
NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
kind-worker    100m         5%     500Mi           25%
```

### 8. **Alternative: Use Minikube's Built-in Metrics Server**

```bash
# If using minikube, you can use built-in metrics server
minikube addons enable metrics-server

# Check if it's enabled
minikube addons list | grep metrics-server
```

### 9. **Last Resort: Continue Without Metrics Server**

```bash
# If metrics server keeps failing, you can deploy without it
# HPA won't work, but other components will
kubectl apply -f 00-namespace.yaml
kubectl apply -f 01-message-queue.yaml
kubectl apply -f 02-main-node.yaml
kubectl apply -f 03-worker-deployment.yaml
kubectl apply -f 04-api-gateway.yaml
kubectl apply -f 05-monitoring.yaml
kubectl apply -f 06-grafana-dashboard.yaml

# Manual scaling instead of auto-scaling
kubectl scale deployment avalanche-worker -n avalanche-parallel --replicas=3
```

## 🕐 Typical Wait Times

- **Normal**: 30-60 seconds
- **Slow cluster**: 2-3 minutes  
- **Resource constrained**: 5+ minutes
- **If > 5 minutes**: Likely an issue, check logs

## 🚀 Quick Commands Summary

```bash
# Check status
kubectl get pods -n kube-system -l k8s-app=metrics-server

# Check logs
kubectl logs -n kube-system deployment/metrics-server

# Force fix
./fix-metrics-server.sh

# Test if working
kubectl top nodes
``` 