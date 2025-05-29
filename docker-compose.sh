#!/bin/bash
# docker-compose.sh
# Helper script to use docker-compose with the configuration file in the config directory

echo -e "\e[1;36mUsing docker-compose.yml from config directory\e[0m"

# Forward all arguments to docker-compose with the -f flag pointing to the config file
docker-compose -f config/docker-compose.yml "$@" 