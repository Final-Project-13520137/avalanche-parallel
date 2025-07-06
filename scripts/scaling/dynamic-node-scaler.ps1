# Dynamic Node Scaler with Automatic Port Allocation - PowerShell Version
param(
    [Parameter(Mandatory=$true, Position=0)]
    [ValidateSet("scale-up", "scale-down", "add-node", "remove-node", "list", "status")]
    [string]$Action,
    
    [ValidateSet("worker", "main-node", "both")]
    [string]$Type = "worker",
    
    [int]$Replicas = 3,
    [int]$Port,
    [switch]$Help
)

# Configuration
$NAMESPACE = "avalanche-parallel"
$BASE_MAIN_PORT = 9650
$BASE_WORKER_PORT = 9652
$BASE_P2P_PORT = 9651
$BASE_API_PORT = 8080
$PORT_INCREMENT = 10

# Show help
if ($Help -or $Action -eq $null) {
    Write-Host @"
Dynamic Node Scaler with Port Allocation

Usage: .\dynamic-node-scaler.ps1 [ACTION] [OPTIONS]

Actions:
  scale-up      Scale up nodes (add more instances)
  scale-down    Scale down nodes (remove instances)
  add-node      Add a single node with specific port
  remove-node   Remove a specific node
  list          List all running nodes
  status        Show current scaling status

Options:
  -Type TYPE           Node type: worker, main-node, or both (default: worker)
  -Replicas NUMBER     Number of replicas for scaling (default: 3)
  -Port PORT           Specific port for single node operations
  -Help                Show this help message

Examples:
  .\dynamic-node-scaler.ps1 scale-up -Type worker -Replicas 5
  .\dynamic-node-scaler.ps1 scale-down -Type worker -Replicas 2
  .\dynamic-node-scaler.ps1 add-node -Type worker -Port 9662
  .\dynamic-node-scaler.ps1 remove-node -Type worker -Port 9662
  .\dynamic-node-scaler.ps1 list
  .\dynamic-node-scaler.ps1 status

Port Allocation:
  - Main nodes: 9650, 9660, 9670, 9680...
  - Workers: 9652, 9662, 9672, 9682...
  - P2P: 9651, 9661, 9671, 9681...
  - API: 8080, 8090, 8100, 8110...
"@
    exit 0
}

# Colors
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

# Check prerequisites
function Check-Prerequisites {
    if (!(Get-Command kubectl -ErrorAction SilentlyContinue)) {
        Write-ColorOutput Red "kubectl is not installed. Please install kubectl first."
        exit 1
    }
    
    try {
        kubectl cluster-info --request-timeout=5s 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput Red "No Kubernetes cluster found or cluster is not accessible."
            exit 1
        }
    } catch {
        Write-ColorOutput Red "Failed to connect to Kubernetes cluster."
        exit 1
    }
}

# Get next available port
function Get-NextPort {
    param(
        [int]$BasePort,
        [string]$NodeType
    )
    
    # Get existing services and their ports
    $existingPorts = kubectl get svc -n $NAMESPACE -l app=avalanche-$NodeType -o jsonpath='{.items[*].spec.ports[0].nodePort}' 2>$null
    if ($LASTEXITCODE -ne 0) {
        $existingPorts = ""
    }
    
    $port = $BasePort
    while ($true) {
        if ($existingPorts -notmatch "\b$port\b") {
            return $port
        }
        $port += $PORT_INCREMENT
        
        # Safety check
        if ($port -gt ($BasePort + 1000)) {
            Write-ColorOutput Red "Unable to find available port after $BasePort"
            exit 1
        }
    }
}

# Create worker node
function Create-WorkerNode {
    param([int]$Port)
    
    $nodeName = "avalanche-worker-$Port"
    $p2pPort = $Port - 1
    $apiPort = $Port + 1428
    
    Write-ColorOutput Yellow "Creating worker node: $nodeName with ports API:$Port, P2P:$p2pPort, API-Gateway:$apiPort"
    
    $deployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $nodeName
  namespace: $NAMESPACE
  labels:
    app: avalanche-worker
    instance: worker-$Port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: avalanche-worker
      instance: worker-$Port
  template:
    metadata:
      labels:
        app: avalanche-worker
        instance: worker-$Port
    spec:
      containers:
      - name: worker
        image: avalanche-parallel/worker:latest
        ports:
        - containerPort: $Port
          name: api
        - containerPort: $p2pPort
          name: p2p
        env:
        - name: PORT
          value: "$Port"
        - name: P2P_PORT
          value: "$p2pPort"
        - name: WORKER_ID
          value: "worker-$Port"
        - name: LOG_LEVEL
          value: "info"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: $Port
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: $Port
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $nodeName
  namespace: $NAMESPACE
  labels:
    app: avalanche-worker
    instance: worker-$Port
spec:
  type: NodePort
  ports:
  - port: $Port
    targetPort: $Port
    nodePort: $Port
    name: api
  - port: $p2pPort
    targetPort: $p2pPort
    nodePort: $p2pPort
    name: p2p
  selector:
    app: avalanche-worker
    instance: worker-$Port
"@
    
    $deployment | kubectl apply -f -
    Write-ColorOutput Green "Worker node $nodeName created successfully!"
}

# Create main node
function Create-MainNode {
    param([int]$Port)
    
    $nodeName = "avalanche-main-$Port"
    $p2pPort = $Port + 1
    $apiPort = $Port - 1570
    
    Write-ColorOutput Yellow "Creating main node: $nodeName with ports API:$Port, P2P:$p2pPort, API-Gateway:$apiPort"
    
    $deployment = @"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $nodeName
  namespace: $NAMESPACE
  labels:
    app: avalanche-main-node
    instance: main-$Port
spec:
  replicas: 1
  selector:
    matchLabels:
      app: avalanche-main-node
      instance: main-$Port
  template:
    metadata:
      labels:
        app: avalanche-main-node
        instance: main-$Port
    spec:
      containers:
      - name: main-node
        image: avalanche-parallel/main-node:latest
        ports:
        - containerPort: $Port
          name: api
        - containerPort: $p2pPort
          name: p2p
        env:
        - name: PORT
          value: "$Port"
        - name: P2P_PORT
          value: "$p2pPort"
        - name: NODE_ID
          value: "main-$Port"
        - name: LOG_LEVEL
          value: "info"
        - name: ENABLE_DAG_STATE_MGMT
          value: "true"
        - name: ENABLE_CONSENSUS_ORCH
          value: "true"
        - name: ENABLE_RESULT_AGGREG
          value: "true"
        resources:
          requests:
            memory: "1Gi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /ext/health
            port: $Port
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ext/info
            port: $Port
          initialDelaySeconds: 10
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: $nodeName
  namespace: $NAMESPACE
  labels:
    app: avalanche-main-node
    instance: main-$Port
spec:
  type: NodePort
  ports:
  - port: $Port
    targetPort: $Port
    nodePort: $Port
    name: api
  - port: $p2pPort
    targetPort: $p2pPort
    nodePort: $p2pPort
    name: p2p
  selector:
    app: avalanche-main-node
    instance: main-$Port
"@
    
    $deployment | kubectl apply -f -
    Write-ColorOutput Green "Main node $nodeName created successfully!"
}

# Remove node
function Remove-Node {
    param(
        [int]$Port,
        [string]$NodeType
    )
    
    $nodeName = "avalanche-$NodeType-$Port"
    Write-ColorOutput Yellow "Removing $NodeType node: $nodeName"
    
    kubectl delete deployment $nodeName -n $NAMESPACE --ignore-not-found=true
    kubectl delete service $nodeName -n $NAMESPACE --ignore-not-found=true
    
    Write-ColorOutput Green "Node $nodeName removed successfully!"
}

# Scale up nodes
function Scale-Up {
    param(
        [string]$NodeType,
        [int]$TargetReplicas
    )
    
    Write-ColorOutput Blue "Scaling up $NodeType nodes to $TargetReplicas replicas"
    
    $currentNodes = (kubectl get deployments -n $NAMESPACE -l app=avalanche-$NodeType --no-headers | Measure-Object).Count
    $nodesToAdd = $TargetReplicas - $currentNodes
    
    if ($nodesToAdd -le 0) {
        Write-ColorOutput Yellow "Already have $currentNodes $NodeType nodes. No scaling needed."
        return
    }
    
    Write-ColorOutput Yellow "Adding $nodesToAdd new $NodeType nodes..."
    
    for ($i = 1; $i -le $nodesToAdd; $i++) {
        if ($NodeType -eq "worker") {
            $port = Get-NextPort -BasePort $BASE_WORKER_PORT -NodeType $NodeType
            Create-WorkerNode -Port $port
        } elseif ($NodeType -eq "main-node") {
            $port = Get-NextPort -BasePort $BASE_MAIN_PORT -NodeType $NodeType
            Create-MainNode -Port $port
        }
        Start-Sleep -Seconds 2
    }
    
    $newCount = (kubectl get deployments -n $NAMESPACE -l app=avalanche-$NodeType --no-headers | Measure-Object).Count
    Write-ColorOutput Green "Scale up completed! Now have $newCount $NodeType nodes"
}

# Scale down nodes
function Scale-Down {
    param(
        [string]$NodeType,
        [int]$TargetReplicas
    )
    
    Write-ColorOutput Blue "Scaling down $NodeType nodes to $TargetReplicas replicas"
    
    $deployments = kubectl get deployments -n $NAMESPACE -l app=avalanche-$NodeType -o jsonpath='{.items[*].metadata.name}'
    $deploymentList = $deployments -split ' ' | Where-Object { $_ -ne '' }
    $currentCount = $deploymentList.Count
    $nodesToRemove = $currentCount - $TargetReplicas
    
    if ($nodesToRemove -le 0) {
        Write-ColorOutput Yellow "Already have $currentCount $NodeType nodes. No scaling needed."
        return
    }
    
    Write-ColorOutput Yellow "Removing $nodesToRemove $NodeType nodes..."
    
    for ($i = 0; $i -lt $nodesToRemove; $i++) {
        $deploymentName = $deploymentList[$currentCount - 1 - $i]
        Write-ColorOutput Yellow "Removing deployment: $deploymentName"
        kubectl delete deployment $deploymentName -n $NAMESPACE
        kubectl delete service $deploymentName -n $NAMESPACE --ignore-not-found=true
        Start-Sleep -Seconds 1
    }
    
    $newCount = (kubectl get deployments -n $NAMESPACE -l app=avalanche-$NodeType --no-headers | Measure-Object).Count
    Write-ColorOutput Green "Scale down completed! Now have $newCount $NodeType nodes"
}

# List nodes
function List-Nodes {
    Write-ColorOutput Blue "=== Current Avalanche Nodes ==="
    
    Write-ColorOutput Yellow "`nMain Nodes:"
    kubectl get deployments,services -n $NAMESPACE -l app=avalanche-main-node -o wide
    
    Write-ColorOutput Yellow "`nWorker Nodes:"
    kubectl get deployments,services -n $NAMESPACE -l app=avalanche-worker -o wide
    
    Write-ColorOutput Yellow "`nPod Status:"
    kubectl get pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' -o wide
}

# Show status
function Show-Status {
    Write-ColorOutput Blue "=== Avalanche Parallel Cluster Status ==="
    
    $mainCount = (kubectl get deployments -n $NAMESPACE -l app=avalanche-main-node --no-headers | Measure-Object).Count
    $workerCount = (kubectl get deployments -n $NAMESPACE -l app=avalanche-worker --no-headers | Measure-Object).Count
    $totalPods = (kubectl get pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' --field-selector=status.phase=Running --no-headers | Measure-Object).Count
    
    Write-ColorOutput Green "Main Nodes: $mainCount"
    Write-ColorOutput Green "Worker Nodes: $workerCount"
    Write-ColorOutput Green "Running Pods: $totalPods"
    
    Write-ColorOutput Yellow "`nPort Allocation:"
    kubectl get services -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' -o custom-columns="NAME:.metadata.name,TYPE:.spec.type,PORTS:.spec.ports[*].nodePort" --no-headers | Sort-Object
    
    Write-ColorOutput Yellow "`nResource Usage:"
    try {
        kubectl top pods -n $NAMESPACE -l 'app in (avalanche-main-node,avalanche-worker)' 2>$null
    } catch {
        Write-ColorOutput Yellow "Metrics server not available"
    }
}

# Main execution
Write-ColorOutput Green "=== Avalanche Parallel Dynamic Node Scaler ==="

Check-Prerequisites

switch ($Action) {
    "scale-up" {
        if ($Type -eq "both") {
            Scale-Up -NodeType "main-node" -TargetReplicas $Replicas
            Scale-Up -NodeType "worker" -TargetReplicas $Replicas
        } else {
            Scale-Up -NodeType $Type -TargetReplicas $Replicas
        }
    }
    "scale-down" {
        if ($Type -eq "both") {
            Scale-Down -NodeType "main-node" -TargetReplicas $Replicas
            Scale-Down -NodeType "worker" -TargetReplicas $Replicas
        } else {
            Scale-Down -NodeType $Type -TargetReplicas $Replicas
        }
    }
    "add-node" {
        if (-not $Port) {
            if ($Type -eq "worker") {
                $Port = Get-NextPort -BasePort $BASE_WORKER_PORT -NodeType $Type
            } else {
                $Port = Get-NextPort -BasePort $BASE_MAIN_PORT -NodeType $Type
            }
        }
        
        if ($Type -eq "worker") {
            Create-WorkerNode -Port $Port
        } elseif ($Type -eq "main-node") {
            Create-MainNode -Port $Port
        } else {
            Write-ColorOutput Red "Invalid node type for add-node: $Type"
            exit 1
        }
    }
    "remove-node" {
        if (-not $Port) {
            Write-ColorOutput Red "Port must be specified for remove-node action"
            exit 1
        }
        Remove-Node -Port $Port -NodeType $Type
    }
    "list" {
        List-Nodes
    }
    "status" {
        Show-Status
    }
}

Write-ColorOutput Green "`n=== Operation completed successfully! ===" 