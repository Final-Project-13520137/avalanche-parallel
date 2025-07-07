#!/bin/bash

# Script untuk menguji apakah run-benchmark.sh mempertahankan worker scaling
# Test: Scale workers -> Run benchmark -> Verify workers unchanged

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/../../" && pwd )"

echo -e "\n${GREEN}🧪 Testing Worker Scaling Preservation${NC}\n"

# Function to get current worker counts
get_current_counts() {
    echo "$(bash "${SCRIPT_DIR}/get-worker-count.sh" validator-worker):$(bash "${SCRIPT_DIR}/get-worker-count.sh" consensus-worker):$(bash "${SCRIPT_DIR}/get-worker-count.sh" dag-state-worker)"
}

# Function to display worker counts
display_counts() {
    local validator=$1
    local consensus=$2
    local dag_state=$3
    echo -e "  ${BLUE}Validator Workers: ${validator}${NC}"
    echo -e "  ${BLUE}Consensus Workers: ${consensus}${NC}"
    echo -e "  ${BLUE}DAG+State Workers: ${dag_state}${NC}"
    echo -e "  ${BLUE}Total Workers: $((validator + consensus + dag_state))${NC}"
}

# Step 1: Clean slate - stop all services
echo -e "${YELLOW}Step 1: Preparing clean environment...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" down >/dev/null 2>&1 || true
sleep 5

# Step 2: Start services with custom scaling
echo -e "\n${YELLOW}Step 2: Starting services with custom worker scale...${NC}"
CUSTOM_VALIDATOR=8
CUSTOM_CONSENSUS=5
CUSTOM_DAG_STATE=3

echo -e "${BLUE}Scaling to custom configuration:${NC}"
display_counts $CUSTOM_VALIDATOR $CUSTOM_CONSENSUS $CUSTOM_DAG_STATE

docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d \
  --scale validator-worker=$CUSTOM_VALIDATOR \
  --scale consensus-worker=$CUSTOM_CONSENSUS \
  --scale dag-state-worker=$CUSTOM_DAG_STATE

echo -e "${BLUE}Waiting for services to stabilize...${NC}"
sleep 30

# Step 3: Verify initial scaling
echo -e "\n${YELLOW}Step 3: Verifying initial worker configuration...${NC}"
INITIAL_COUNTS=$(get_current_counts)
IFS=':' read -r INITIAL_VALIDATOR INITIAL_CONSENSUS INITIAL_DAG_STATE <<< "$INITIAL_COUNTS"

echo -e "${BLUE}Initial worker counts:${NC}"
display_counts $INITIAL_VALIDATOR $INITIAL_CONSENSUS $INITIAL_DAG_STATE

# Verify the scaling worked
if [ "$INITIAL_VALIDATOR" -eq "$CUSTOM_VALIDATOR" ] && \
   [ "$INITIAL_CONSENSUS" -eq "$CUSTOM_CONSENSUS" ] && \
   [ "$INITIAL_DAG_STATE" -eq "$CUSTOM_DAG_STATE" ]; then
    echo -e "${GREEN}✅ Initial scaling successful${NC}"
else
    echo -e "${RED}❌ Initial scaling failed${NC}"
    echo -e "Expected: ${CUSTOM_VALIDATOR}:${CUSTOM_CONSENSUS}:${CUSTOM_DAG_STATE}"
    echo -e "Actual: ${INITIAL_VALIDATOR}:${INITIAL_CONSENSUS}:${INITIAL_DAG_STATE}"
    exit 1
fi

# Step 4: Run benchmark with preservation
echo -e "\n${YELLOW}Step 4: Running benchmark (this should preserve worker counts)...${NC}"
echo -e "${BLUE}This will test if run-benchmark.sh preserves the existing scale...${NC}"

# Create a mock benchmark that just sleeps (to test scaling preservation)
cat > "${SCRIPT_DIR}/mock-benchmark.go" << 'EOF'
package main

import (
    "fmt"
    "time"
)

func main() {
    fmt.Println("Mock benchmark running...")
    fmt.Println("Simulating benchmark workload...")
    time.Sleep(10 * time.Second)
    fmt.Println("Mock benchmark completed successfully!")
}
EOF

# Build mock benchmark
go build -o "${SCRIPT_DIR}/mock-benchmark" "${SCRIPT_DIR}/mock-benchmark.go"

# Replace the benchmark binary temporarily
if [ -f "${SCRIPT_DIR}/avalanche-benchmark" ]; then
    mv "${SCRIPT_DIR}/avalanche-benchmark" "${SCRIPT_DIR}/avalanche-benchmark.backup"
fi
cp "${SCRIPT_DIR}/mock-benchmark" "${SCRIPT_DIR}/avalanche-benchmark"

# Run the benchmark script with timeout to prevent hanging
timeout 180 bash "${SCRIPT_DIR}/run-benchmark.sh" || true

# Restore original benchmark if it existed
if [ -f "${SCRIPT_DIR}/avalanche-benchmark.backup" ]; then
    mv "${SCRIPT_DIR}/avalanche-benchmark.backup" "${SCRIPT_DIR}/avalanche-benchmark"
fi

# Clean up mock files
rm -f "${SCRIPT_DIR}/mock-benchmark" "${SCRIPT_DIR}/mock-benchmark.go"

# Step 5: Verify worker counts after benchmark
echo -e "\n${YELLOW}Step 5: Verifying worker configuration after benchmark...${NC}"
sleep 10  # Wait for any changes to settle

FINAL_COUNTS=$(get_current_counts)
IFS=':' read -r FINAL_VALIDATOR FINAL_CONSENSUS FINAL_DAG_STATE <<< "$FINAL_COUNTS"

echo -e "${BLUE}Final worker counts:${NC}"
display_counts $FINAL_VALIDATOR $FINAL_CONSENSUS $FINAL_DAG_STATE

# Step 6: Compare and report results
echo -e "\n${YELLOW}Step 6: Comparing results...${NC}"

echo -e "\n${BLUE}=== SCALING PRESERVATION TEST RESULTS ===${NC}"
echo -e "Initial Configuration:"
display_counts $INITIAL_VALIDATOR $INITIAL_CONSENSUS $INITIAL_DAG_STATE

echo -e "\nFinal Configuration:"
display_counts $FINAL_VALIDATOR $FINAL_CONSENSUS $FINAL_DAG_STATE

# Check if scaling was preserved
if [ "$INITIAL_VALIDATOR" -eq "$FINAL_VALIDATOR" ] && \
   [ "$INITIAL_CONSENSUS" -eq "$FINAL_CONSENSUS" ] && \
   [ "$INITIAL_DAG_STATE" -eq "$FINAL_DAG_STATE" ]; then
    echo -e "\n${GREEN}🎉 SUCCESS: Worker scaling was preserved!${NC}"
    echo -e "${GREEN}✅ run-benchmark.sh correctly maintained worker configuration${NC}"
    TEST_RESULT="PASS"
else
    echo -e "\n${RED}❌ FAILURE: Worker scaling was NOT preserved!${NC}"
    echo -e "${RED}❌ run-benchmark.sh modified the worker configuration${NC}"
    
    echo -e "\n${RED}Differences detected:${NC}"
    if [ "$INITIAL_VALIDATOR" -ne "$FINAL_VALIDATOR" ]; then
        echo -e "  ${RED}Validator Workers: ${INITIAL_VALIDATOR} → ${FINAL_VALIDATOR}${NC}"
    fi
    if [ "$INITIAL_CONSENSUS" -ne "$FINAL_CONSENSUS" ]; then
        echo -e "  ${RED}Consensus Workers: ${INITIAL_CONSENSUS} → ${FINAL_CONSENSUS}${NC}"
    fi
    if [ "$INITIAL_DAG_STATE" -ne "$FINAL_DAG_STATE" ]; then
        echo -e "  ${RED}DAG+State Workers: ${INITIAL_DAG_STATE} → ${FINAL_DAG_STATE}${NC}"
    fi
    TEST_RESULT="FAIL"
fi

# Step 7: Additional tests with different scales
echo -e "\n${YELLOW}Step 7: Testing with different scale configurations...${NC}"

# Test with minimal configuration
echo -e "\n${BLUE}Testing minimal configuration (3:2:2)...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d \
  --scale validator-worker=3 \
  --scale consensus-worker=2 \
  --scale dag-state-worker=2

sleep 15

MINIMAL_BEFORE=$(get_current_counts)
timeout 60 bash "${SCRIPT_DIR}/run-benchmark.sh" >/dev/null 2>&1 || true
sleep 5
MINIMAL_AFTER=$(get_current_counts)

if [ "$MINIMAL_BEFORE" = "$MINIMAL_AFTER" ]; then
    echo -e "${GREEN}✅ Minimal configuration preserved${NC}"
else
    echo -e "${RED}❌ Minimal configuration NOT preserved${NC}"
    echo -e "  Before: $MINIMAL_BEFORE"
    echo -e "  After: $MINIMAL_AFTER"
    TEST_RESULT="FAIL"
fi

# Test with maximum configuration
echo -e "\n${BLUE}Testing maximum configuration (15:10:8)...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" up -d \
  --scale validator-worker=15 \
  --scale consensus-worker=10 \
  --scale dag-state-worker=8

sleep 20

MAXIMUM_BEFORE=$(get_current_counts)
timeout 60 bash "${SCRIPT_DIR}/run-benchmark.sh" >/dev/null 2>&1 || true
sleep 5
MAXIMUM_AFTER=$(get_current_counts)

if [ "$MAXIMUM_BEFORE" = "$MAXIMUM_AFTER" ]; then
    echo -e "${GREEN}✅ Maximum configuration preserved${NC}"
else
    echo -e "${RED}❌ Maximum configuration NOT preserved${NC}"
    echo -e "  Before: $MAXIMUM_BEFORE"
    echo -e "  After: $MAXIMUM_AFTER"
    TEST_RESULT="FAIL"
fi

# Step 8: Cleanup and final report
echo -e "\n${YELLOW}Step 8: Cleaning up test environment...${NC}"
docker-compose -f "${PROJECT_ROOT}/docker-compose.worker-pools.yml" down >/dev/null 2>&1

echo -e "\n${GREEN}=== FINAL TEST REPORT ===${NC}"
echo -e "Test: Worker Scaling Preservation"
echo -e "Script: run-benchmark.sh"
echo -e "Date: $(date)"

if [ "$TEST_RESULT" = "PASS" ]; then
    echo -e "Result: ${GREEN}✅ PASSED${NC}"
    echo -e "\n${GREEN}🎉 All tests passed! run-benchmark.sh correctly preserves worker scaling.${NC}"
    exit 0
else
    echo -e "Result: ${RED}❌ FAILED${NC}"
    echo -e "\n${RED}💥 Some tests failed! run-benchmark.sh needs to be fixed.${NC}"
    exit 1
fi 