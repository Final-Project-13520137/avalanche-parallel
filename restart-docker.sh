#!/bin/bash

echo -e "\e[1;36mAvalanche Parallel Docker Environment Restart Script\e[0m"
echo -e "\e[1;36m=================================================\e[0m"
echo -e "This script restarts the Docker environment with port conflict resolution\n"

# Step 1: Stop all running containers
echo -e "\e[1;32mStep 1: Stopping all existing containers...\e[0m"
docker-compose down
if [ $? -ne 0 ]; then
    echo -e "  \e[1;33m! Warning: Issues stopping containers. Proceeding anyway...\e[0m"
fi

# Step 2: Check for port conflicts
echo -e "\n\e[1;32mStep 2: Checking for port conflicts...\e[0m"

# Function to check if a port is in use
function check_port() {
    local port=$1
    local service=$2
    
    # Check if port is in use
    if netstat -tuln | grep -q ":$port "; then
        echo -e "  \e[1;31m! Port $port is in use (service: $service)\e[0m"
        return 1
    else
        echo -e "  \e[1;32m* Port $port is available\e[0m"
        return 0
    fi
}

# Check critical ports
all_ports_available=true
check_port 9650 "Avalanche API" || all_ports_available=false
check_port 9651 "Avalanche P2P" || all_ports_available=false
check_port 19090 "Prometheus (modified)" || all_ports_available=false
check_port 13000 "Grafana (modified)" || all_ports_available=false

if [ "$all_ports_available" = false ]; then
    echo -e "\n  \e[1;31m! Some ports are already in use. You may need to modify docker-compose.yml\e[0m"
    read -p $'\nDo you want to proceed anyway? (y/n) ' proceed
    if [ "$proceed" != "y" ]; then
        echo -e "\e[1;33mExiting script.\e[0m"
        exit 1
    fi
fi

# Step 3: Start with clean containers
echo -e "\n\e[1;32mStep 3: Starting containers...\e[0m"
docker-compose up -d
if [ $? -ne 0 ]; then
    echo -e "\n  \e[1;31m! Error starting containers. Checking for more specific issues...\e[0m"
    
    # Try to identify specific issues
    echo -e "\n\e[1;33mChecking container status:\e[0m"
    docker ps -a --filter "name=avalanche-parallel" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    
    # Offer potential solutions
    echo -e "\n\e[1;36mPotential solutions:\e[0m"
    echo "  1. Edit docker-compose.yml to change ports (current changes: Prometheus 19090, Grafana 13000)"
    echo "  2. Stop conflicting services/applications using the same ports"
    echo "  3. Try running: docker system prune -f to clean up unused Docker resources"
    echo "  4. Check if you have multiple Docker Compose projects using the same container names"
    
    read -p $'\nWould you like to try docker system prune and restart? (y/n) ' restart
    if [ "$restart" = "y" ]; then
        docker system prune -f
        echo -e "\n\e[1;32mTrying to start containers again...\e[0m"
        docker-compose up -d
    fi
else
    # Step 4: Scale workers
    echo -e "\n\e[1;32mStep 4: Scaling worker service to 3 instances...\e[0m"
    docker-compose up -d --scale worker=3
    
    # Step 5: Check services
    echo -e "\n\e[1;32mStep 5: Checking service status...\e[0m"
    docker-compose ps
    
    echo -e "\nServices should be available at:"
    echo "  - Avalanche Node API: http://localhost:9650/ext/info"
    echo "  - Prometheus: http://localhost:19090"
    echo "  - Grafana: http://localhost:13000 (admin/admin)"
fi

echo -e "\n\e[1;36mDone!\e[0m" 