#!/bin/bash
# Script to run blockchain tests

set -e

echo "Running Avalanche Parallel Blockchain Tests"
echo "----------------------------------------"

# Change to the project root directory if needed
# cd $(dirname $0)/..

# Set GOPATH if needed
# export GOPATH=$(go env GOPATH)

# Set environment variables for testing
export AVALANCHE_PARALLEL_PATH="../avalanche-parallel"

echo "Running unit tests..."
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "^Test[^(Full|Blockchain|Parallel)]" -count=1

echo "Running blockchain integration tests..."
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestBlockchain" -count=1

echo "Running full flow tests..."
go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestFull" -count=1

# Performance benchmark tests - run only if specified
if [ "$1" == "--benchmark" ]; then
  echo "Running parallel performance benchmark tests..."
  go test -v github.com/Final-Project-13520137/avalanche-parallel-dag/pkg/blockchain -run "TestParallelConsensus" -count=1
else
  echo "Skipping performance benchmark tests. Use --benchmark flag to run them."
fi

echo "All tests completed successfully!" 