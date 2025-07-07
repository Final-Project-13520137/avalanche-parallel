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
mkdir -p benchmark-results benchmark-graphs

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
docker-compose -f "${PROJECT_ROOT}/docker-compose.benchmark.yml" up -d redis postgres &
show_spinner $! "Starting Docker services"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to start services${NC}"
    exit 1
fi

# Wait for services to be ready
echo -e "\n${YELLOW}Waiting for services to be ready...${NC}"

# Wait for Redis
echo -e "\n${BLUE}Checking Redis connection:${NC}"
until docker exec benchmark-redis redis-cli ping > /dev/null 2>&1; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for Redis..."
        sleep 0.1
    done
done
echo -e "\r✓ Redis is ready!"

# Wait for PostgreSQL
echo -e "\n${BLUE}Checking PostgreSQL connection:${NC}"
until docker exec benchmark-postgres pg_isready -U benchmark > /dev/null 2>&1; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Waiting for PostgreSQL..."
        sleep 0.1
    done
done
echo -e "\r✓ PostgreSQL is ready!"

# Run the benchmark
echo -e "\n${YELLOW}Running benchmark tests...${NC}"
echo -e "${BLUE}This may take several minutes. Please wait...${NC}\n"

# Function to show progress bar
show_progress() {
    local duration=$1
    local elapsed=0
    local width=50
    
    while [ $elapsed -le $duration ]; do
        local percent=$((elapsed * 100 / duration))
        local filled=$((elapsed * width / duration))
        local empty=$((width - filled))
        
        printf "\rProgress: [${GREEN}"
        printf "%${filled}s${NC}" | tr ' ' '█'
        printf "%${empty}s" | tr ' ' '░'
        printf "${NC}] %d%%" $percent
        
        elapsed=$((elapsed + 1))
        sleep 1
    done
    echo -e "\n"
}

# Run benchmark with progress indication
./avalanche-benchmark &
BENCHMARK_PID=$!

# Show progress while benchmark is running
while kill -0 $BENCHMARK_PID 2>/dev/null; do
    for i in $(seq 0 ${#SPINNER}); do
        printf "\r${BLUE}${SPINNER:$i:1}${NC} Running benchmark tests..."
        sleep 0.1
    done
done

if wait $BENCHMARK_PID; then
    echo -e "\r✓ Benchmark tests completed successfully!\n"
else
    echo -e "\n${RED}Benchmark failed${NC}"
    docker-compose -f "${PROJECT_ROOT}/docker-compose.benchmark.yml" down
    exit 1
fi

# Generate graphs
echo -e "${YELLOW}Generating benchmark graphs...${NC}"
python3 generate-benchmark-graphs.py --results-dir benchmark-results --output-dir benchmark-graphs &
show_spinner $! "Generating performance graphs"
if [ $? -ne 0 ]; then
    echo -e "\n${RED}Failed to generate graphs${NC}"
fi

# Clean up
echo -e "\n${YELLOW}Cleaning up...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.benchmark.yml" down &
show_spinner $! "Cleaning up Docker services"

echo -e "\n${GREEN}✅ Benchmark Suite Completed Successfully!${NC}"
echo -e "${GREEN}📊 Results available in:${NC}"
echo -e "  - ${BLUE}benchmark-results/${NC}"
echo -e "  - ${BLUE}benchmark-graphs/${NC}\n" 