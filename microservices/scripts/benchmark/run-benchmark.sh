#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

echo -e "\n${GREEN}🚀 Starting Avalanche Benchmark Suite${NC}\n"

# Create directories
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

# Start required services
echo -e "\n${YELLOW}Starting required services...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d &
show_spinner $! "Starting Docker services"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to start services${NC}"
    exit 1
fi

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

# Run the benchmark
echo -e "\n${YELLOW}Running parallel benchmark tests...${NC}"
echo -e "${BLUE}This may take several minutes. Please wait...${NC}\n"

# Set environment variables for the benchmark
export BENCHMARK_RESULTS_DIR="$RESULTS_DIR"
export BENCHMARK_GRAPHS_DIR="$GRAPHS_DIR"
export API_GATEWAY_ENDPOINT="http://localhost:9650"
export METRICS_ENDPOINT="http://localhost:9090"

# Run benchmark with progress indication
./avalanche-benchmark &
BENCHMARK_PID=$!

# Show progress while benchmark is running
while kill -0 $BENCHMARK_PID 2>/dev/null; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Running parallel benchmark tests..."
        sleep 0.1
    done
done

if wait $BENCHMARK_PID; then
    echo -e "\r✓ Benchmark tests completed successfully!\n"
else
    echo -e "\n${RED}Benchmark failed${NC}"
    docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" down
    exit 1
fi

# Generate graphs
echo -e "${YELLOW}Generating benchmark graphs...${NC}"
python3 generate_benchmark_graphs.py --results-dir "$RESULTS_DIR" --output-dir "$GRAPHS_DIR" &
show_spinner $! "Generating performance graphs"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to generate graphs${NC}"
fi

# Clean up
echo -e "\n${YELLOW}Cleaning up...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" down &
show_spinner $! "Cleaning up services and worker pools"

echo -e "\n${GREEN}✅ Parallel Benchmark Suite Completed Successfully!${NC}"
echo -e "${GREEN}📊 Results available in:${NC}"
echo -e "  - ${BLUE}${RESULTS_DIR}${NC}"
echo -e "  - ${BLUE}${GRAPHS_DIR}${NC}\n"

# Display generated graphs
echo -e "${YELLOW}Generated Graphs:${NC}"
find "$GRAPHS_DIR" -name "*.png" -type f -printf "  - %f\n" 