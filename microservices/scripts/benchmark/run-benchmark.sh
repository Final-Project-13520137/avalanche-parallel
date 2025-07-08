#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Loading animation characters
SPINNER="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"

# Function to show spinner
show_spinner() {
    local pid=$1
    local message=$2
    local i=0
    local delay=0.1
    
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i + 1) % ${#SPINNER} ))
        printf "\r${BLUE}${SPINNER:$i:1}${NC} ${message}"
        sleep $delay
    done
    printf "\r✓ ${message}\n"
}

# Function to get current worker count using utility script
get_current_worker_count() {
    local service_name=$1
    local count=$(bash "${SCRIPT_DIR}/get-worker-count.sh" "$service_name" 2>/dev/null)
    # Fallback to docker ps if utility script fails
    if [ -z "$count" ] || [ "$count" = "0" ]; then
        count=$(docker ps --filter "name=${service_name}" --filter "status=running" --format "{{.Names}}" | wc -l)
    fi
    echo $count
}

# Function to check if services are already running
check_services_running() {
    # Check for essential services
    local redis_running=$(docker ps --filter "name=avalanche-redis" --filter "status=running" --format "{{.Names}}" | wc -l)
    local postgres_running=$(docker ps --filter "name=avalanche-postgres" --filter "status=running" --format "{{.Names}}" | wc -l)
    local workers_running=$(docker ps --filter "name=worker" --filter "status=running" --format "{{.Names}}" | wc -l)
    
    # Check with docker-compose as fallback
    local compose_running=0
    if command -v docker-compose >/dev/null 2>&1; then
        compose_running=$(docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" ps -q 2>/dev/null | wc -l)
    fi
    
    if [ $redis_running -gt 0 ] || [ $postgres_running -gt 0 ] || [ $workers_running -gt 0 ] || [ $compose_running -gt 0 ]; then
        return 0  # Services are running
    else
        return 1  # No services running
    fi
}

# Function to start services with existing scale or default scale
start_services_with_scale() {
    local validator_count
    local consensus_count
    local dag_state_count
    
    if check_services_running; then
        echo -e "${YELLOW}Existing services detected. Preserving current scale...${NC}"
        
        # Get current worker counts
        validator_count=$(get_current_worker_count "validator-worker")
        consensus_count=$(get_current_worker_count "consensus-worker")
        dag_state_count=$(get_current_worker_count "dag-state-worker")
        
        echo -e "${BLUE}Current worker configuration:${NC}"
        echo -e "  - Validator Workers: ${validator_count}"
        echo -e "  - Consensus Workers: ${consensus_count}"
        echo -e "  - DAG+State Workers: ${dag_state_count}"
        
        # Use current scale or minimum defaults if no workers are running
        validator_count=${validator_count:-3}
        consensus_count=${consensus_count:-2}
        dag_state_count=${dag_state_count:-2}
    else
        echo -e "${YELLOW}No existing services found. Starting with default scale...${NC}"
        
        # Default worker counts for fresh start
        validator_count=3
        consensus_count=2
        dag_state_count=2
        
        echo -e "${BLUE}Default worker configuration:${NC}"
        echo -e "  - Validator Workers: ${validator_count}"
        echo -e "  - Consensus Workers: ${consensus_count}"
        echo -e "  - DAG+State Workers: ${dag_state_count}"
    fi
    
    # Start services with determined scale
    echo -e "\n${YELLOW}Starting services with preserved/default scale...${NC}"
    docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d \
        --scale validator-worker=${validator_count} \
        --scale consensus-worker=${consensus_count} \
        --scale dag-state-worker=${dag_state_count} &
    
    show_spinner $! "Starting Docker services with worker scale"
    
    if [ $? -ne 0 ]; then
        echo -e "\n${RED}Failed to start services${NC}"
        exit 1
    fi
    
    echo -e "\n${GREEN}✅ Services started successfully with:${NC}"
    echo -e "  - Validator Workers: ${validator_count}"
    echo -e "  - Consensus Workers: ${consensus_count}"
    echo -e "  - DAG+State Workers: ${dag_state_count}"
}

# Function to scale workers for test case (preserve existing workers)
scale_workers_for_test() {
    local test_case=$1
    local target_validator=$2
    local target_consensus=$3
    local target_dag_state=$4

    echo -e "\n${YELLOW}Checking worker configuration for test case: ${test_case}${NC}"

    # Get current worker counts
    local current_validator=$(get_current_worker_count "validator-worker")
    local current_consensus=$(get_current_worker_count "consensus-worker")
    local current_dag_state=$(get_current_worker_count "dag-state-worker")

    echo -e "${BLUE}Current worker counts:${NC}"
    echo -e "  - Validator Workers: ${current_validator}"
    echo -e "  - Consensus Workers: ${current_consensus}"
    echo -e "  - DAG+State Workers: ${current_dag_state}"

    echo -e "${BLUE}Required worker counts:${NC}"
    echo -e "  - Validator Workers: ${target_validator}"
    echo -e "  - Consensus Workers: ${target_consensus}"
    echo -e "  - DAG+State Workers: ${target_dag_state}"

    # Determine if scaling is needed (only scale up, never down)
    local final_validator=$current_validator
    local final_consensus=$current_consensus
    local final_dag_state=$current_dag_state
    local scaling_needed=false

    if [ $current_validator -lt $target_validator ]; then
        final_validator=$target_validator
        scaling_needed=true
        echo -e "${YELLOW}➜ Need to scale UP validator workers: ${current_validator} → ${target_validator}${NC}"
    elif [ $current_validator -gt $target_validator ]; then
        echo -e "${GREEN}➜ Validator workers sufficient: ${current_validator} (need ${target_validator})${NC}"
    else
        echo -e "${GREEN}➜ Validator workers match requirement: ${current_validator}${NC}"
    fi

    if [ $current_consensus -lt $target_consensus ]; then
        final_consensus=$target_consensus
        scaling_needed=true
        echo -e "${YELLOW}➜ Need to scale UP consensus workers: ${current_consensus} → ${target_consensus}${NC}"
    elif [ $current_consensus -gt $target_consensus ]; then
        echo -e "${GREEN}➜ Consensus workers sufficient: ${current_consensus} (need ${target_consensus})${NC}"
    else
        echo -e "${GREEN}➜ Consensus workers match requirement: ${current_consensus}${NC}"
    fi

    if [ $current_dag_state -lt $target_dag_state ]; then
        final_dag_state=$target_dag_state
        scaling_needed=true
        echo -e "${YELLOW}➜ Need to scale UP DAG+State workers: ${current_dag_state} → ${target_dag_state}${NC}"
    elif [ $current_dag_state -gt $target_dag_state ]; then
        echo -e "${GREEN}➜ DAG+State workers sufficient: ${current_dag_state} (need ${target_dag_state})${NC}"
    else
        echo -e "${GREEN}➜ DAG+State workers match requirement: ${current_dag_state}${NC}"
    fi

    # Only scale if needed
    if [ "$scaling_needed" = true ]; then
        echo -e "\n${YELLOW}Scaling workers (preserving existing workers):${NC}"
        echo -e "${BLUE}New configuration:${NC}"
        echo -e "  - Validator Workers: ${final_validator}"
        echo -e "  - Consensus Workers: ${final_consensus}"
        echo -e "  - DAG+State Workers: ${final_dag_state}"

        docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d \
            --scale validator-worker=${final_validator} \
            --scale consensus-worker=${final_consensus} \
            --scale dag-state-worker=${final_dag_state} &

        show_spinner $! "Scaling worker pools (preserving existing)"

        # Wait for new workers to be ready
        echo -e "\n${BLUE}Waiting for new workers to be ready...${NC}"
        
        # Wait for all worker pools to be healthy
        until check_worker_health "validator-haproxy" "8081"; do
            for i in $(seq 0 ${#SPINNER}); do
                printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Validator Workers..."
                sleep 0.1
            done
        done
        echo -e "\r✓ Validator Workers are ready!"

        until check_worker_health "consensus-haproxy" "8080"; do
            for i in $(seq 0 ${#SPINNER}); do
                printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Consensus Workers..."
                sleep 0.1
            done
        done
        echo -e "\r✓ Consensus Workers are ready!"

        until check_worker_health "dag-state-haproxy" "8082"; do
            for i in $(seq 0 ${#SPINNER}); do
                printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for DAG State Workers..."
                sleep 0.1
            done
        done
        echo -e "\r✓ DAG State Workers are ready!"

        # Verify final worker counts
        local actual_validator=$(get_current_worker_count "validator-worker")
        local actual_consensus=$(get_current_worker_count "consensus-worker")
        local actual_dag_state=$(get_current_worker_count "dag-state-worker")

        echo -e "\n${GREEN}✅ Final worker configuration:${NC}"
        echo -e "  - Validator Workers: ${actual_validator}"
        echo -e "  - Consensus Workers: ${actual_consensus}"
        echo -e "  - DAG+State Workers: ${actual_dag_state}"

        # Check if we have sufficient workers (not exact match required)
        if [ "$actual_validator" -ge "$target_validator" ] && \
           [ "$actual_consensus" -ge "$target_consensus" ] && \
           [ "$actual_dag_state" -ge "$target_dag_state" ]; then
            echo -e "${GREEN}✅ Sufficient workers available for test case${NC}"
        else
            echo -e "\n${RED}❌ Insufficient workers after scaling:${NC}"
            echo -e "Required vs Available:"
            echo -e "  Validator:  ${target_validator} vs ${actual_validator}"
            echo -e "  Consensus:  ${target_consensus} vs ${actual_consensus}"
            echo -e "  DAG+State:  ${target_dag_state} vs ${actual_dag_state}"
            return 1
        fi
    else
        echo -e "\n${GREEN}✅ Current worker configuration is sufficient for test case${NC}"
        echo -e "No scaling needed. Using existing workers."
    fi

    return 0
}

# Function to run test case (updated to not require exact worker counts)
run_test_case() {
    local test_case=$1
    local min_validator=$2
    local min_consensus=$3
    local min_dag_state=$4

    echo -e "\n${GREEN}🔬 Running Test Case: ${test_case}${NC}"

    # Ensure we have sufficient workers for this test case
    if ! scale_workers_for_test "$test_case" "$min_validator" "$min_consensus" "$min_dag_state"; then
        echo -e "${RED}❌ Failed to ensure sufficient workers for test case: ${test_case}${NC}"
        return 1
    fi

    # Wait for system to stabilize
    echo -e "\n${YELLOW}Allowing system to stabilize...${NC}"
    sleep 5  # Reduced from 10 seconds since we're not recreating workers

    # Get actual worker counts for the benchmark
    local actual_validator=$(get_current_worker_count "validator-worker")
    local actual_consensus=$(get_current_worker_count "consensus-worker")
    local actual_dag_state=$(get_current_worker_count "dag-state-worker")

    # Run the benchmark for this configuration
    echo -e "\n${YELLOW}Starting benchmark for ${test_case}...${NC}"
    echo -e "${BLUE}Using worker configuration:${NC}"
    echo -e "  - Validator Workers: ${actual_validator}"
    echo -e "  - Consensus Workers: ${actual_consensus}"
    echo -e "  - DAG+State Workers: ${actual_dag_state}"

    export TEST_CASE="$test_case"
    export VALIDATOR_WORKERS="$actual_validator"
    export CONSENSUS_WORKERS="$actual_consensus"
    export DAG_STATE_WORKERS="$actual_dag_state"

    ./avalanche-benchmark &
    BENCHMARK_PID=$!

    # Show progress while benchmark is running
    while kill -0 $BENCHMARK_PID 2>/dev/null; do
        for i in $(seq 0 ${#SPINNER}); do
            printf "\r${BLUE}${SPINNER:$i:1}${NC} Running ${test_case}..."
            sleep 0.1
        done
    done

    if wait $BENCHMARK_PID; then
        echo -e "\r✓ Test case completed successfully!\n"
        return 0
    else
        echo -e "\n${RED}❌ Test case failed${NC}"
        return 1
    fi
}

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

# Main benchmark execution
echo -e "\n${GREEN}🚀 Starting Avalanche Benchmark Suite${NC}\n"

# Create directories and setup
echo -e "${YELLOW}Setting up environment...${NC}"
RESULTS_DIR="${SCRIPT_DIR}/benchmark-results"
GRAPHS_DIR="${SCRIPT_DIR}/benchmark-graphs"
mkdir -p "$RESULTS_DIR" "$GRAPHS_DIR"

# Set proper permissions
chmod -R 777 "$RESULTS_DIR" "$GRAPHS_DIR"

# Install Python dependencies
echo -e "\n${YELLOW}Installing Python dependencies...${NC}"
python3 -m pip install pandas matplotlib seaborn &
show_spinner $! "Installing Python packages"

# Build the benchmark binary
echo -e "\n${YELLOW}Building benchmark binary...${NC}"
go build -o avalanche-benchmark avalanche-comparison-benchmark.go &
show_spinner $! "Building benchmark binary"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to build benchmark binary${NC}"
    exit 1
fi

# Start required services with preserved scale
echo -e "\n${YELLOW}Managing Docker services...${NC}"
start_services_with_scale

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to be ready...${NC}"

# Wait for Redis
echo -e "\n${BLUE}Checking Redis connection:${NC}"
until docker exec avalanche-redis redis-cli ping > /dev/null 2>&1; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Redis..."
        sleep 0.1
    done
done
echo -e "\r✓ Redis is ready!"

# Wait for PostgreSQL
echo -e "\n${BLUE}Checking PostgreSQL connection:${NC}"
until docker exec avalanche-postgres pg_isready -U avalanche > /dev/null 2>&1; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for PostgreSQL..."
        sleep 0.1
    done
done
echo -e "\r✓ PostgreSQL is ready!"

# Wait for Worker Pools
echo -e "\n${BLUE}Checking Worker Pools:${NC}"

# Function to check worker health
check_worker_health() {
    local service=$1
    local port=$2
    curl -s "http://localhost:${port}/health" > /dev/null 2>&1
}

# Wait for Consensus Workers
echo -e "\n${BLUE}Checking Consensus Workers:${NC}"
until check_worker_health "consensus-haproxy" "8080"; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Consensus Workers..."
        sleep 0.1
    done
done
echo -e "\r✓ Consensus Workers are ready!"

# Wait for Validator Workers
echo -e "\n${BLUE}Checking Validator Workers:${NC}"
until check_worker_health "validator-haproxy" "8081"; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Validator Workers..."
        sleep 0.1
    done
done
echo -e "\r✓ Validator Workers are ready!"

# Wait for DAG State Workers
echo -e "\n${BLUE}Checking DAG State Workers:${NC}"
until check_worker_health "dag-state-haproxy" "8082"; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for DAG State Workers..."
        sleep 0.1
    done
done
echo -e "\r✓ DAG State Workers are ready!"

# Display current worker status before benchmark
echo -e "\n${GREEN}📊 Current Worker Pool Status:${NC}"
echo -e "${BLUE}Active Workers:${NC}"
validator_active=$(get_current_worker_count "validator-worker")
consensus_active=$(get_current_worker_count "consensus-worker")
dag_state_active=$(get_current_worker_count "dag-state-worker")

echo -e "  - Validator Workers: ${validator_active} containers"
echo -e "  - Consensus Workers: ${consensus_active} containers"
echo -e "  - DAG+State Workers: ${dag_state_active} containers"
echo -e "  - Total Active Workers: $((validator_active + consensus_active + dag_state_active)) containers"

# Run test cases
echo -e "\n${YELLOW}Running benchmark test cases...${NC}"
echo -e "${BLUE}Note: Existing workers will be preserved. Only scaling UP when needed.${NC}\n"

# Test Case 1: Small Load (Minimum Workers)
echo -e "${CYAN}📋 Test Case 1: Small Load Test${NC}"
echo -e "${BLUE}Minimum requirement: 3 Validator, 2 Consensus, 2 DAG+State workers${NC}"
run_test_case "Small_Load_Validator_Only" 3 2 2

# Test Case 2: Medium Load (Balanced)
echo -e "\n${CYAN}📋 Test Case 2: Medium Load Test${NC}"
echo -e "${BLUE}Minimum requirement: 6 Validator, 4 Consensus, 3 DAG+State workers${NC}"
run_test_case "Medium_Load_Balanced" 6 4 3

# Test Case 3: High Load (Consensus Heavy)
echo -e "\n${CYAN}📋 Test Case 3: High Load Test${NC}"
echo -e "${BLUE}Minimum requirement: 9 Validator, 6 Consensus, 4 DAG+State workers${NC}"
run_test_case "High_Load_Consensus_Heavy" 9 6 4

# Test Case 4: Maximum Load (Full Scale)
echo -e "\n${CYAN}📋 Test Case 4: Maximum Load Test${NC}"
echo -e "${BLUE}Minimum requirement: 15 Validator, 10 Consensus, 8 DAG+State workers${NC}"
run_test_case "Max_Load_Full_Scale" 15 10 8

# Generate final reports and graphs
echo -e "${YELLOW}Generating benchmark graphs...${NC}"
if [ -f "generate_benchmark_graphs.py" ]; then
python3 generate_benchmark_graphs.py --results-dir "$RESULTS_DIR" --output-dir "$GRAPHS_DIR" &
show_spinner $! "Generating performance graphs"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to generate graphs${NC}"
fi
else
    echo -e "${YELLOW}Graph generator not found, skipping graph generation${NC}"
fi

# Ask user if they want to keep services running
echo -e "\n${YELLOW}Benchmark completed. Current worker configuration preserved.${NC}"
echo -e "${BLUE}Do you want to stop the services? (y/N): ${NC}"
read -r -n 1 -t 10 response
echo

if [[ "$response" =~ ^[Yy]$ ]]; then
    echo -e "\n${YELLOW}Cleaning up services...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" down &
    show_spinner $! "Stopping services and worker pools"
else
    echo -e "\n${GREEN}Services kept running with current configuration.${NC}"
    echo -e "${BLUE}To manage workers later, use:${NC}"
    echo -e "  - Scale up: docker-compose -f docker-compose.worker-pools.yml up -d --scale validator-worker=10"
    echo -e "  - Scale down: docker-compose -f docker-compose.worker-pools.yml up -d --scale validator-worker=5"
    echo -e "  - Stop all: docker-compose -f docker-compose.worker-pools.yml down"
fi

echo -e "\n${GREEN}✅ Parallel Benchmark Suite Completed Successfully!${NC}"
echo -e "${GREEN}📊 Results available in:${NC}"
echo -e "  - ${BLUE}${RESULTS_DIR}${NC}"
echo -e "  - ${BLUE}${GRAPHS_DIR}${NC}\n"

# Display final worker status
echo -e "${GREEN}📈 Final Worker Pool Status:${NC}"
final_validator=$(get_current_worker_count "validator-worker")
final_consensus=$(get_current_worker_count "consensus-worker")
final_dag_state=$(get_current_worker_count "dag-state-worker")

echo -e "  - Validator Workers: ${final_validator} containers"
echo -e "  - Consensus Workers: ${final_consensus} containers"
echo -e "  - DAG+State Workers: ${final_dag_state} containers"
echo -e "  - Total Active Workers: $((final_validator + final_consensus + final_dag_state)) containers"

# Display generated graphs
if [ -d "$GRAPHS_DIR" ] && [ "$(ls -A $GRAPHS_DIR)" ]; then
    echo -e "\n${YELLOW}Generated Graphs:${NC}"
    find "$GRAPHS_DIR" -name "*.png" -type f -printf "  - %f\n" 2>/dev/null || \
    find "$GRAPHS_DIR" -name "*.png" -type f -exec basename {} \; | sed 's/^/  - /'
else
    echo -e "\n${YELLOW}No graphs generated${NC}"
fi 
