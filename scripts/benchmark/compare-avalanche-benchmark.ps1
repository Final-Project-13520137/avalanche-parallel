# Avalanche Performance Comparison Benchmark
# Compares performance between monolithic and microservices architectures

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$BenchmarkDir = Join-Path $RootDir "benchmark-results"
$MicroservicesDir = Join-Path $RootDir "microservices"

# Benchmark settings
$TransactionCounts = @(1000, 5000, 10000, 20000)
$WorkerConfigurations = @(
    "consensus:2,validator:3,dag-state:2",
    "consensus:4,validator:6,dag-state:3",
    "consensus:6,validator:9,dag-state:4",
    "consensus:8,validator:12,dag-state:6",
    "consensus:10,validator:15,dag-state:8"
)
$Duration = 120 # seconds
$WarmupTime = 30 # seconds

# Create benchmark results directory
New-Item -ItemType Directory -Force -Path $BenchmarkDir | Out-Null

# Generate timestamp for this benchmark run
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$env:BENCHMARK_TIMESTAMP = $Timestamp

# Create benchmark working directory
$ComparisonDir = Join-Path $BenchmarkDir "comparison-$Timestamp"
New-Item -ItemType Directory -Force -Path $ComparisonDir | Out-Null

Write-Host "Environment setup completed" -ForegroundColor Green

# Run benchmarks
Write-Host "Starting architecture comparison benchmark..." -ForegroundColor Blue

foreach ($TxCount in $TransactionCounts) {
    # Run microservices benchmark for each configuration
    foreach ($Config in $WorkerConfigurations) {
        Write-Host "Running microservices benchmark with $TxCount transactions and config $Config" -ForegroundColor Blue
        
        # Start microservices with worker configuration
        kubectl scale deployment -n avalanche consensus-worker --replicas=$($Config -split ':')[1]
        kubectl scale deployment -n avalanche validator-worker --replicas=$($Config -split ':')[3]
        kubectl scale deployment -n avalanche dag-state-worker --replicas=$($Config -split ':')[5]
        
        # Wait for services to be ready
        Start-Sleep -Seconds $WarmupTime
        
        # Generate and send transactions
        $StartTime = Get-Date
        
        # Get Redis pod name
        $RedisPod = kubectl get pod -n avalanche -l app=redis -o jsonpath='{.items[0].metadata.name}'
        
        # Generate tasks
        $ConsensusCount = [math]::Floor($TxCount / 3)
        $ValidationCount = [math]::Floor($TxCount / 2)
        $DagStateCount = [math]::Floor($TxCount / 6)
        
        # Generate consensus tasks
        for ($i = 1; $i -le $ConsensusCount; $i++) {
            $Task = @{
                id = [System.Guid]::NewGuid().ToString()
                type = "vertex_validation"
                vertex_id = [System.Guid]::NewGuid().ToString()
                parent_ids = @([System.Guid]::NewGuid().ToString(), [System.Guid]::NewGuid().ToString())
                transactions = @()
                priority = "high"
                timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            } | ConvertTo-Json
            
            kubectl exec -n avalanche $RedisPod -- redis-cli LPUSH consensus_tasks $Task | Out-Null
        }
        
        # Generate validation tasks
        for ($i = 1; $i -le $ValidationCount; $i++) {
            $Task = @{
                id = [System.Guid]::NewGuid().ToString()
                type = "transaction_validation"
                transaction_id = [System.Guid]::NewGuid().ToString()
                transaction = @{
                    id = [System.Guid]::NewGuid().ToString()
                    data = "transaction_data_$i"
                    timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                }
                signature = "signature_$i"
                public_key = "public_key_$i"
                priority = "medium"
            } | ConvertTo-Json
            
            kubectl exec -n avalanche $RedisPod -- redis-cli LPUSH validation_tasks $Task | Out-Null
        }
        
        # Generate DAG/State tasks
        for ($i = 1; $i -le $DagStateCount; $i++) {
            $Task = @{
                id = [System.Guid]::NewGuid().ToString()
                type = "state_update"
                vertex_id = [System.Guid]::NewGuid().ToString()
                state_changes = @(
                    @{
                        account = [System.Guid]::NewGuid().ToString()
                        balance = Get-Random -Minimum 0 -Maximum 1000000
                        nonce = Get-Random -Minimum 0 -Maximum 1000
                    }
                )
                priority = "low"
            } | ConvertTo-Json
            
            kubectl exec -n avalanche $RedisPod -- redis-cli LPUSH dag_state_tasks $Task | Out-Null
        }
        
        # Wait for processing
        Start-Sleep -Seconds $Duration
        
        $EndTime = Get-Date
        $Duration = ($EndTime - $StartTime).TotalSeconds
        
        # Get processed results
        $ConsensusResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN consensus_results
        $ValidationResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN validation_results
        $DagStateResults = kubectl exec -n avalanche $RedisPod -- redis-cli LLEN dag_state_results
        
        # Calculate throughput
        $TotalProcessed = [int]$ConsensusResults + [int]$ValidationResults + [int]$DagStateResults
        $TPS = [math]::Round($TotalProcessed / $Duration, 2)
        
        # Save metrics
        $MetricsFile = Join-Path $ComparisonDir "microservices_${Config}_${TxCount}.json"
        @{
            timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            configuration = $Config
            transaction_count = $TxCount
            duration = $Duration
            throughput_tps = $TPS
            processed = @{
                consensus_processed = [int]$ConsensusResults
                validation_processed = [int]$ValidationResults
                dag_state_processed = [int]$DagStateResults
                total_processed = $TotalProcessed
            }
        } | ConvertTo-Json | Set-Content $MetricsFile
        
        Write-Host "Microservices benchmark completed: ${TPS} TPS" -ForegroundColor Green
        
        # Stop worker pools
        kubectl scale deployment -n avalanche consensus-worker --replicas=0
        kubectl scale deployment -n avalanche validator-worker --replicas=0
        kubectl scale deployment -n avalanche dag-state-worker --replicas=0
        
        # Wait for pods to terminate
        Start-Sleep -Seconds 30
    }
}

# Generate comparison graphs
Write-Host "Generating comparison graphs..." -ForegroundColor Blue

pip install matplotlib seaborn pandas tabulate

$GraphScript = Join-Path $ScriptDir "generate_graphs.py"
python $GraphScript $ComparisonDir

Write-Host "Graphs and report generated in $ComparisonDir" -ForegroundColor Green
Write-Host "Benchmark completed" -ForegroundColor Green 