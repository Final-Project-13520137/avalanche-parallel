# Avalanche Worker Pool Parallel Benchmark
# Test performance of parallel worker pools vs sequential processing

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BenchmarkDir = Join-Path $RootDir "benchmark-results"
$MicroservicesDir = Join-Path $RootDir "microservices"

# Benchmark settings
$Duration = 120 # seconds
$WarmupTime = 30 # seconds

# Create benchmark results directory
New-Item -ItemType Directory -Force -Path $BenchmarkDir | Out-Null

# Generate timestamp for this benchmark run
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$env:BENCHMARK_TIMESTAMP = $Timestamp

# Create benchmark working directory
$WorkingDir = Join-Path $BenchmarkDir "worker-pool-$Timestamp"
New-Item -ItemType Directory -Force -Path $WorkingDir | Out-Null

Write-Host "Environment setup completed" -ForegroundColor Green

# Check prerequisites
Write-Host "Checking prerequisites..." -ForegroundColor Blue

# Check if kubectl is available
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) {
    Write-Host "kubectl is not installed" -ForegroundColor Red
    exit 1
}

# Check if Kubernetes cluster is accessible
try {
    kubectl cluster-info | Out-Null
} catch {
    Write-Host "Kubernetes cluster is not accessible" -ForegroundColor Red
    exit 1
}

# Check if avalanche namespace exists
try {
    kubectl get namespace avalanche | Out-Null
} catch {
    Write-Host "avalanche namespace does not exist" -ForegroundColor Red
    exit 1
}

Write-Host "Prerequisites check passed" -ForegroundColor Green

# Parse command line arguments
param(
    [Parameter(Position=0)]
    [string]$Action = "benchmark",
    
    [Parameter(Position=1)]
    [string]$Config,
    
    [Parameter(Position=2)]
    [int]$TxCount
)

# Start worker pools with specific configuration
Write-Host "Starting worker pools with configuration: $Config" -ForegroundColor Blue

# Parse configuration
$Workers = $Config -split ','

# Scale each worker pool
foreach ($Worker in $Workers) {
    $WorkerType, $WorkerCount = $Worker -split ':'
    
    # Scale the deployment
    kubectl scale deployment -n avalanche "${WorkerType}-worker" --replicas=$WorkerCount
}

# Wait for services to be ready
Write-Host "Waiting for worker pools to be ready..." -ForegroundColor Blue
Start-Sleep -Seconds $WarmupTime

# Check if services are healthy
$MaxRetries = 30
$Retry = 0

while ($Retry -lt $MaxRetries) {
    # Check if all pods are ready
    $NotReadyPods = (kubectl get pods -n avalanche -l type=worker | Select-String -NotMatch "Running").Count - 1
    
    if ($NotReadyPods -eq 0) {
        # Check Redis health
        $RedisPod = kubectl get pod -n avalanche -l app=redis -o jsonpath='{.items[0].metadata.name}'
        $RedisPing = kubectl exec -n avalanche $RedisPod -- redis-cli ping
        
        if ($RedisPing -eq "PONG") {
            Write-Host "All services are healthy" -ForegroundColor Green
            break
        }
    }
    
    $Retry++
    Start-Sleep -Seconds 2
    Write-Host "Waiting for services to be healthy... ($Retry/$MaxRetries)" -ForegroundColor Blue
}

if ($Retry -eq $MaxRetries) {
    Write-Host "Services failed to become healthy" -ForegroundColor Red
    exit 1
}

Write-Host "Worker pools started successfully" -ForegroundColor Green

# Generate random base58 ID
function New-Base58Id {
    param([int]$Length = 32)
    
    $Chars = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    $Random = New-Object System.Random
    $Id = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $Id += $Chars[$Random.Next(0, $Chars.Length)]
    }
    
    return $Id
}

# Generate load for worker pools
Write-Host "Generating load: $TxCount transactions with config $Config" -ForegroundColor Blue

$StartTime = Get-Date

# Get Redis pod name
$RedisPod = kubectl get pod -n avalanche -l app=redis -o jsonpath='{.items[0].metadata.name}'
Write-Host "Using Redis pod: $RedisPod" -ForegroundColor Blue

# Check Redis connection
$RedisPing = kubectl exec -n avalanche $RedisPod -- redis-cli ping
if ($RedisPing -ne "PONG") {
    Write-Host "Failed to connect to Redis" -ForegroundColor Red
    exit 1
}
Write-Host "Redis connection successful" -ForegroundColor Green

# Generate different types of tasks
Write-Host "Generating consensus tasks..." -ForegroundColor Blue
$ConsensusCount = [math]::Floor($TxCount / 3)
$TempFile = New-TemporaryFile

for ($i = 1; $i -le $ConsensusCount; $i++) {
    $Task = @{
        id = New-Base58Id
        type = "vertex_validation"
        vertex_id = New-Base58Id
        parent_ids = @(New-Base58Id, New-Base58Id)
        transactions = @()
        priority = "high"
        timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json
    
    Add-Content -Path $TempFile -Value $Task
    
    if (($i % 100 -eq 0) -or ($i -eq $ConsensusCount)) {
        Write-Host "Sending batch of consensus tasks ($i/$ConsensusCount)..." -ForegroundColor Blue
        
        kubectl cp $TempFile.FullName "avalanche/${RedisPod}:/tmp/tasks.txt"
        kubectl exec -n avalanche $RedisPod -- sh -c 'while read -r task; do redis-cli LPUSH consensus_tasks "$task" > /dev/null; done < /tmp/tasks.txt'
        
        Clear-Content -Path $TempFile
        Start-Sleep -Milliseconds 100
    }
}

Remove-Item -Path $TempFile
Write-Host "Generated $ConsensusCount consensus tasks" -ForegroundColor Green

Write-Host "Generating validation tasks..." -ForegroundColor Blue
$ValidationCount = [math]::Floor($TxCount / 2)
$TempFile = New-TemporaryFile

for ($i = 1; $i -le $ValidationCount; $i++) {
    $Task = @{
        id = New-Base58Id
        type = "transaction_validation"
        transaction_id = New-Base58Id
        transaction = @{
            id = New-Base58Id
            data = "transaction_data_$i"
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        }
        signature = "signature_$i"
        public_key = "public_key_$i"
        priority = "medium"
    } | ConvertTo-Json
    
    Add-Content -Path $TempFile -Value $Task
    
    if (($i % 200 -eq 0) -or ($i -eq $ValidationCount)) {
        Write-Host "Sending batch of validation tasks ($i/$ValidationCount)..." -ForegroundColor Blue
        
        kubectl cp $TempFile.FullName "avalanche/${RedisPod}:/tmp/tasks.txt"
        kubectl exec -n avalanche $RedisPod -- sh -c 'while read -r task; do redis-cli LPUSH validation_tasks "$task" > /dev/null; done < /tmp/tasks.txt'
        
        Clear-Content -Path $TempFile
        Start-Sleep -Milliseconds 50
    }
}

Remove-Item -Path $TempFile
Write-Host "Generated $ValidationCount validation tasks" -ForegroundColor Green

Write-Host "Generating DAG/State tasks..." -ForegroundColor Blue
$DagStateCount = [math]::Floor($TxCount / 6)
$TempFile = New-TemporaryFile

for ($i = 1; $i -le $DagStateCount; $i++) {
    $Task = @{
        id = New-Base58Id
        type = "state_update"
        vertex_id = New-Base58Id
        state_changes = @(
            @{
                account = New-Base58Id
                balance = Get-Random -Minimum 0 -Maximum 1000000
                nonce = Get-Random -Minimum 0 -Maximum 1000
            }
        )
        priority = "low"
    } | ConvertTo-Json
    
    Add-Content -Path $TempFile -Value $Task
    
    if (($i % 50 -eq 0) -or ($i -eq $DagStateCount)) {
        Write-Host "Sending batch of DAG/State tasks ($i/$DagStateCount)..." -ForegroundColor Blue
        
        kubectl cp $TempFile.FullName "avalanche/${RedisPod}:/tmp/tasks.txt"
        kubectl exec -n avalanche $RedisPod -- sh -c 'while read -r task; do redis-cli LPUSH dag_state_tasks "$task" > /dev/null; done < /tmp/tasks.txt'
        
        Clear-Content -Path $TempFile
        Start-Sleep -Milliseconds 200
    }
}

Remove-Item -Path $TempFile
Write-Host "Generated $DagStateCount DAG/State tasks" -ForegroundColor Green

$EndTime = Get-Date
$Duration = ($EndTime - $StartTime).TotalSeconds

# Check task counts
$ConsensusQueue = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN consensus_tasks
$ValidationQueue = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN validation_tasks
$DagStateQueue = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN dag_state_tasks

Write-Host "Task counts:" -ForegroundColor Blue
Write-Host "Consensus tasks: $ConsensusQueue" -ForegroundColor Blue
Write-Host "Validation tasks: $ValidationQueue" -ForegroundColor Blue
Write-Host "DAG/State tasks: $DagStateQueue" -ForegroundColor Blue

# Get processed results
$ConsensusResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN consensus_results
$ValidationResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN validation_results
$DagStateResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN dag_state_results

# Calculate throughput
$TotalProcessed = [int]$ConsensusResults + [int]$ValidationResults + [int]$DagStateResults
$TPS = [math]::Round($TotalProcessed / $Duration, 2)

# Get worker statistics
$WorkerStats = (kubectl get pods -n avalanche -l type=worker --no-headers | Measure-Object).Count

# Save metrics
$MetricsFile = Join-Path $WorkingDir "metrics_${Config}_${TxCount}.json"
@{
    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    configuration = $Config
    transaction_count = $TxCount
    duration = $Duration
    throughput_tps = $TPS
    queues = @{
        consensus_remaining = [int]$ConsensusQueue
        validation_remaining = [int]$ValidationQueue
        dag_state_remaining = [int]$DagStateQueue
    }
    processed = @{
        consensus_processed = [int]$ConsensusResults
        validation_processed = [int]$ValidationResults
        dag_state_processed = [int]$DagStateResults
        total_processed = $TotalProcessed
    }
    workers = @{
        active_workers = $WorkerStats
    }
} | ConvertTo-Json | Set-Content $MetricsFile

Write-Host "Metrics collected: ${TPS} TPS, ${TotalProcessed} total processed" -ForegroundColor Green

# Stop worker pools
Write-Host "Stopping worker pools..." -ForegroundColor Blue

# Scale down all worker pools to 0
kubectl scale deployment -n avalanche consensus-worker --replicas=0
kubectl scale deployment -n avalanche validator-worker --replicas=0
kubectl scale deployment -n avalanche dag-state-worker --replicas=0

# Wait for pods to terminate
kubectl wait --for=delete pod -l type=worker -n avalanche --timeout=60s

Write-Host "Worker pools stopped" -ForegroundColor Green 