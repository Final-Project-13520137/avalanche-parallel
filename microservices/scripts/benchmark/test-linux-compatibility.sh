#!/bin/bash

# Test script to verify Linux compatibility of comprehensive benchmark
# This script checks if all required dependencies are available

echo "🔍 Testing Linux Compatibility for Comprehensive Benchmark"
echo "========================================================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Function to check command availability
check_command() {
    local cmd=$1
    local name=$2
    
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✅ $name is available${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is NOT available${NC}"
        return 1
    fi
}

# Function to check Python module
check_python_module() {
    local module=$1
    local name=$2
    
    if python3 -c "import $module" 2>/dev/null; then
        echo -e "${GREEN}✅ $name is available${NC}"
        return 0
    else
        echo -e "${RED}❌ $name is NOT available${NC}"
        return 1
    fi
}

echo ""
echo "📋 Checking Required Commands:"
echo "-----------------------------"

# Check essential commands
check_command "bash" "Bash"
check_command "bc" "Basic Calculator (bc)"
check_command "python3" "Python 3"
check_command "pip3" "Pip 3"

echo ""
echo "📋 Checking Python Modules:"
echo "---------------------------"

# Check Python modules
check_python_module "matplotlib" "Matplotlib"
check_python_module "pandas" "Pandas"
check_python_module "json" "JSON (built-in)"
check_python_module "sys" "Sys (built-in)"

echo ""
echo "📋 Checking Script Files:"
echo "------------------------"

# Check if benchmark script exists
if [ -f "comprehensive-benchmark-fixed.sh" ]; then
    echo -e "${GREEN}✅ comprehensive-benchmark-fixed.sh exists${NC}"
    
    # Check if script is executable
    if [ -x "comprehensive-benchmark-fixed.sh" ]; then
        echo -e "${GREEN}✅ Script is executable${NC}"
    else
        echo -e "${YELLOW}⚠️ Script is not executable (run: chmod +x comprehensive-benchmark-fixed.sh)${NC}"
    fi
else
    echo -e "${RED}❌ comprehensive-benchmark-fixed.sh not found${NC}"
fi

echo ""
echo "📋 Testing Basic Functionality:"
echo "------------------------------"

# Test basic math operations with bc
if command -v bc &> /dev/null; then
    result=$(echo "2.5 * 3.2" | bc -l)
    if [ "$result" = "8.0" ]; then
        echo -e "${GREEN}✅ Basic math operations work${NC}"
    else
        echo -e "${RED}❌ Basic math operations failed${NC}"
    fi
else
    echo -e "${RED}❌ Cannot test math operations (bc not available)${NC}"
fi

# Test JSON generation
if command -v python3 &> /dev/null; then
    python3 -c "import json; print('{\"test\": \"value\"}')" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ JSON operations work${NC}"
    else
        echo -e "${RED}❌ JSON operations failed${NC}"
    fi
else
    echo -e "${RED}❌ Cannot test JSON operations (python3 not available)${NC}"
fi

echo ""
echo "📋 System Information:"
echo "--------------------"

# Display system info
echo "OS: $(uname -s)"
echo "Architecture: $(uname -m)"
echo "Bash Version: $(bash --version | head -n1)"
if command -v python3 &> /dev/null; then
    echo "Python Version: $(python3 --version)"
fi
if command -v bc &> /dev/null; then
    echo "BC Version: $(bc --version | head -n1)"
fi

echo ""
echo "🎯 Summary:"
echo "----------"

# Count available vs required
available=0
required=0

# Count command availability
for cmd in bash bc python3 pip3; do
    required=$((required + 1))
    if command -v "$cmd" &> /dev/null; then
        available=$((available + 1))
    fi
done

# Count module availability
for module in matplotlib pandas; do
    required=$((required + 1))
    if python3 -c "import $module" 2>/dev/null; then
        available=$((available + 1))
    fi
done

echo "Available: $available/$required components"

if [ $available -eq $required ]; then
    echo -e "${GREEN}🎉 All requirements met! Ready to run comprehensive benchmark.${NC}"
    echo ""
    echo "To run the benchmark:"
    echo "  ./comprehensive-benchmark-fixed.sh --report --graphs"
else
    echo -e "${YELLOW}⚠️ Some requirements missing. Please install missing components.${NC}"
    echo ""
    echo "Install missing components:"
    echo "  sudo apt update"
    echo "  sudo apt install -y bc python3 python3-pip"
    echo "  pip3 install matplotlib pandas"
fi

echo ""
echo "📚 For detailed setup instructions, see: LINUX-UBUNTU-SETUP.md" 