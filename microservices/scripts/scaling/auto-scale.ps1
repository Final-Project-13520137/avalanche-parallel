# Auto-scaling script for Avalanche Parallel Processing
param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('consensus', 'validator', 'dag-state')]
    [string]$WorkerType,

    [int]$MinWorkers = 2,
    [int]$MaxWorkers = 10,
    
    [int]$CpuThresholdUp = 80,
    [int]$CpuThresholdDown = 20,
    
    [int]$QueueThresholdUp = 100,
    [int]$QueueThresholdDown = 10,
    
    [int]$CheckInterval = 30,
    
    [string]$ComposeFile = "docker-compose.worker-pools.yml"
)

# Function to get queue length from Redis
function Get-QueueLength {
    param($type)
    $queueName = switch ($type) {
        'consensus' { 'consensus_tasks' }
        'validator' { 'validation_tasks' }
        'dag-state' { 'dag_state_tasks' }
    }
    
    $length = docker exec avalanche-redis redis-cli LLEN $queueName
    return [int]$length
}

# Function to get worker CPU usage
function Get-WorkerCpuUsage {
    param($type)
    $containers = docker ps --format "{{.Names}}" | Where-Object { $_ -like "*$type*" }
    $totalCpu = 0
    $count = 0
    
    foreach ($container in $containers) {
        $stats = docker stats $container --no-stream --format "{{.CPUPerc}}"
        $cpuPerc = [double]($stats -replace '%','')
        $totalCpu += $cpuPerc
        $count++
    }
    
    return if ($count -gt 0) { $totalCpu / $count } else { 0 }
}

# Function to scale workers
function Scale-Workers {
    param($type, $count)
    
    Write-Host "Scaling $type workers to $count..." -ForegroundColor Yellow
    & "$PSScriptRoot\scale-workers.ps1" -WorkerType $type -Count $count -ComposeFile $ComposeFile -Force
}

Write-Host "🔄 Starting auto-scaling monitor for $WorkerType workers..." -ForegroundColor Green
Write-Host @"
Configuration:
- Min Workers: $MinWorkers
- Max Workers: $MaxWorkers
- CPU Threshold (Up/Down): $CpuThresholdUp%/$CpuThresholdDown%
- Queue Threshold (Up/Down): $QueueThresholdUp/$QueueThresholdDown
- Check Interval: $CheckInterval seconds
"@ -ForegroundColor Cyan

try {
    while ($true) {
        # Get current metrics
        $currentWorkers = (docker ps --format "{{.Names}}" | Where-Object { $_ -like "*$WorkerType*" }).Count
        $queueLength = Get-QueueLength $WorkerType
        $cpuUsage = Get-WorkerCpuUsage $WorkerType
        
        # Log current state
        Write-Host @"

📊 Current Status:
- Workers: $currentWorkers
- Queue Length: $queueLength
- Average CPU: $([math]::Round($cpuUsage,2))%
"@ -ForegroundColor Yellow
        
        # Determine if scaling is needed
        $scaleUp = $false
        $scaleDown = $false
        
        if ($queueLength -gt $QueueThresholdUp -or $cpuUsage -gt $CpuThresholdUp) {
            $scaleUp = $true
        }
        elseif ($queueLength -lt $QueueThresholdDown -and $cpuUsage -lt $CpuThresholdDown) {
            $scaleDown = $true
        }
        
        # Apply scaling if needed
        if ($scaleUp -and $currentWorkers -lt $MaxWorkers) {
            $newCount = [Math]::Min($currentWorkers + 1, $MaxWorkers)
            Write-Host "⬆️ Scaling up to $newCount workers" -ForegroundColor Green
            Scale-Workers $WorkerType $newCount
        }
        elseif ($scaleDown -and $currentWorkers -gt $MinWorkers) {
            $newCount = [Math]::Max($currentWorkers - 1, $MinWorkers)
            Write-Host "⬇️ Scaling down to $newCount workers" -ForegroundColor Yellow
            Scale-Workers $WorkerType $newCount
        }
        else {
            Write-Host "✅ No scaling needed" -ForegroundColor Green
        }
        
        # Wait for next check
        Write-Host "⏳ Waiting $CheckInterval seconds..." -ForegroundColor Gray
        Start-Sleep -Seconds $CheckInterval
    }
} catch {
    Write-Host "❌ Error during auto-scaling: $_" -ForegroundColor Red
    exit 1
} 