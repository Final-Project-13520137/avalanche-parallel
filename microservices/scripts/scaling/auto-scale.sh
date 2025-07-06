#!/bin/bash
# Auto-scaling script for Avalanche Parallel Processing

# Default values
MIN_WORKERS=2
MAX_WORKERS=10
CPU_THRESHOLD_UP=80
CPU_THRESHOLD_DOWN=20
QUEUE_THRESHOLD_UP=100
QUEUE_THRESHOLD_DOWN=10
CHECK_INTERVAL=30
COMPOSE_FILE="docker-compose.worker-pools.yml"

# Function to show usage
usage() {
    echo "Usage: $0 --type <consensus|validator|dag-state> [options]"
    echo
    echo "Options:"
    echo "  --type              Worker type (consensus, validator, or dag-state)"
    echo "  --min-workers       Minimum number of workers (default: $MIN_WORKERS)"
    echo "  --max-workers       Maximum number of workers (default: $MAX_WORKERS)"
    echo "  --cpu-up           CPU threshold for scaling up (default: $CPU_THRESHOLD_UP%)"
    echo "  --cpu-down         CPU threshold for scaling down (default: $CPU_THRESHOLD_DOWN%)"
    echo "  --queue-up         Queue threshold for scaling up (default: $QUEUE_THRESHOLD_UP)"
    echo "  --queue-down       Queue threshold for scaling down (default: $QUEUE_THRESHOLD_DOWN)"
    echo "  --interval         Check interval in seconds (default: $CHECK_INTERVAL)"
    echo "  --file             Docker compose file (default: $COMPOSE_FILE)"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --type)
            WORKER_TYPE="$2"
            shift 2
            ;;
        --min-workers)
            MIN_WORKERS="$2"
            shift 2
            ;;
        --max-workers)
            MAX_WORKERS="$2"
            shift 2
            ;;
        --cpu-up)
            CPU_THRESHOLD_UP="$2"
            shift 2
            ;;
        --cpu-down)
            CPU_THRESHOLD_DOWN="$2"
            shift 2
            ;;
        --queue-up)
            QUEUE_THRESHOLD_UP="$2"
            shift 2
            ;;
        --queue-down)
            QUEUE_THRESHOLD_DOWN="$2"
            shift 2
            ;;
        --interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --file)
            COMPOSE_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            usage
            ;;
    esac
done

# Validate required arguments
if [ -z "$WORKER_TYPE" ]; then
    usage
fi

# Validate worker type
if [[ ! "$WORKER_TYPE" =~ ^(consensus|validator|dag-state)$ ]]; then
    echo -e "\e[31m❌ Invalid worker type. Must be consensus, validator, or dag-state.\e[0m"
    exit 1
fi

# Function to get queue length from Redis
get_queue_length() {
    local type=$1
    local queue_name
    case $type in
        consensus)
            queue_name="consensus_tasks"
            ;;
        validator)
            queue_name="validation_tasks"
            ;;
        dag-state)
            queue_name="dag_state_tasks"
            ;;
    esac
    
    docker exec avalanche-redis redis-cli LLEN "$queue_name"
}

# Function to get worker CPU usage
get_worker_cpu_usage() {
    local type=$1
    local total_cpu=0
    local count=0
    
    while read -r container; do
        local stats
        stats=$(docker stats "$container" --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
        total_cpu=$(echo "$total_cpu + $stats" | bc)
        count=$((count + 1))
    done < <(docker ps --format "{{.Names}}" | grep "$type")
    
    if [ $count -gt 0 ]; then
        echo "scale=2; $total_cpu / $count" | bc
    else
        echo "0"
    fi
}

# Function to scale workers
scale_workers() {
    local type=$1
    local count=$2
    
    echo -e "\e[33mScaling $type workers to $count...\e[0m"
    "$(dirname "$0")/scale-workers.sh" --type "$type" --count "$count" --file "$COMPOSE_FILE" --force
}

# Print configuration
echo -e "\e[32m🔄 Starting auto-scaling monitor for $WORKER_TYPE workers...\e[0m"
echo -e "\e[36mConfiguration:
- Min Workers: $MIN_WORKERS
- Max Workers: $MAX_WORKERS
- CPU Threshold (Up/Down): $CPU_THRESHOLD_UP%/$CPU_THRESHOLD_DOWN%
- Queue Threshold (Up/Down): $QUEUE_THRESHOLD_UP/$QUEUE_THRESHOLD_DOWN
- Check Interval: $CHECK_INTERVAL seconds\e[0m"

# Main loop
while true; do
    # Get current metrics
    current_workers=$(docker ps --format "{{.Names}}" | grep -c "$WORKER_TYPE")
    queue_length=$(get_queue_length "$WORKER_TYPE")
    cpu_usage=$(get_worker_cpu_usage "$WORKER_TYPE")
    
    # Log current state
    echo -e "\n\e[33m📊 Current Status:
- Workers: $current_workers
- Queue Length: $queue_length
- Average CPU: ${cpu_usage}%\e[0m"
    
    # Determine if scaling is needed
    scale_up=false
    scale_down=false
    
    if (( $(echo "$queue_length > $QUEUE_THRESHOLD_UP" | bc -l) )) || \
       (( $(echo "$cpu_usage > $CPU_THRESHOLD_UP" | bc -l) )); then
        scale_up=true
    elif (( $(echo "$queue_length < $QUEUE_THRESHOLD_DOWN" | bc -l) )) && \
         (( $(echo "$cpu_usage < $CPU_THRESHOLD_DOWN" | bc -l) )); then
        scale_down=true
    fi
    
    # Apply scaling if needed
    if [ "$scale_up" = true ] && [ "$current_workers" -lt "$MAX_WORKERS" ]; then
        new_count=$((current_workers + 1))
        if [ "$new_count" -gt "$MAX_WORKERS" ]; then
            new_count=$MAX_WORKERS
        fi
        echo -e "\e[32m⬆️ Scaling up to $new_count workers\e[0m"
        scale_workers "$WORKER_TYPE" "$new_count"
    elif [ "$scale_down" = true ] && [ "$current_workers" -gt "$MIN_WORKERS" ]; then
        new_count=$((current_workers - 1))
        if [ "$new_count" -lt "$MIN_WORKERS" ]; then
            new_count=$MIN_WORKERS
        fi
        echo -e "\e[33m⬇️ Scaling down to $new_count workers\e[0m"
        scale_workers "$WORKER_TYPE" "$new_count"
    else
        echo -e "\e[32m✅ No scaling needed\e[0m"
    fi
    
    # Wait for next check
    echo -e "\e[90m⏳ Waiting $CHECK_INTERVAL seconds...\e[0m"
    sleep "$CHECK_INTERVAL"
done 