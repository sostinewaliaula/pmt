#!/bin/bash

# Caava Group Project Management - Self-Hosting Setup Script
# Based on Plane Community Edition

# Set colors for output messages
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Print header
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}              Caava Group - Project Management Tool                   ${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Self-Hosting Management Script${NC}\n"

# Check if docker is installed
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed. Please install Docker first.${NC}"
    exit 1
fi

show_menu() {
    echo -e "${BOLD}Select an action you want to perform:${NC}"
    echo -e "   1) ${GREEN}Install / Setup Env${NC} (Copy .env files & generate keys)"
    echo -e "   2) ${GREEN}Build Caava Group Images${NC} (From local source)"
    echo -e "   3) ${BLUE}Start Services${NC} (docker-compose up)"
    echo -e "   4) ${YELLOW}Stop Services${NC} (docker-compose down)"
    echo -e "   5) ${BLUE}Restart Services${NC}"
    echo -e "   6) ${BLUE}View Logs${NC}"
    echo -e "   7) ${RED}Backup Data${NC}"
    echo -e "   8) Exit"
    echo -ne "\nAction [3]: "
}

setup_env() {
    echo -e "\n${YELLOW}Setting up environment files...${NC}"
    services=("" "web" "api" "space" "admin" "live")
    
    for service in "${services[@]}"; do
        if [ "$service" == "" ]; then
            prefix="./"
        else
            prefix="./apps/$service/"
        fi

        if [ ! -f "${prefix}.env" ]; then
            if [ -f "${prefix}.env.example" ]; then
                cp "${prefix}.env.example" "${prefix}.env"
                echo -e "${GREEN}✓${NC} Created ${prefix}.env from example"
            fi
        else
            echo -e "${BLUE}i${NC} ${prefix}.env already exists, skipping."
        fi
    done

    # Generate SECRET_KEY for Django if not already there
    if [ -f "./apps/api/.env" ] && ! grep -q "SECRET_KEY" "./apps/api/.env"; then
        echo -e "${YELLOW}Generating Django SECRET_KEY...${NC}"
        SECRET_KEY=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        echo -e "SECRET_KEY=\"$SECRET_KEY\"" >> ./apps/api/.env
        echo -e "${GREEN}✓${NC} Added SECRET_KEY to apps/api/.env"
    fi
}

build_images() {
    echo -e "\n${YELLOW}Building Caava Group personalized images...${NC}"
    echo -e "${BLUE}This might take several minutes depending on your system.${NC}"
    docker compose build
}

start_services() {
    echo -e "\n${GREEN}Starting Caava Group services...${NC}"
    docker compose up -d
    echo -e "\n${GREEN}Services started! Access your instance via WEB_URL configured in your .env${NC}"
}

stop_services() {
    echo -e "\n${YELLOW}Stopping Caava Group services...${NC}"
    docker compose down
}

restart_services() {
    echo -e "\n${BLUE}Restarting Caava Group services...${NC}"
    docker compose restart
}

view_logs() {
    docker compose logs -f
}

while true; do
    show_menu
    read choice
    
    # Default to 3 (Start) if input is empty
    if [ -z "$choice" ]; then
        choice=3
    fi

    case $choice in
        1) setup_env ;;
        2) build_images ;;
        3) start_services ;;
        4) stop_services ;;
        5) restart_services ;;
        6) view_logs ;;
        7) 
            echo -e "${YELLOW}Backup functionality to be implemented based on your volume storage style.${NC}"
            ;;
        8) exit 0 ;;
        *) echo -e "${RED}Invalid option, please try again.${NC}" ;;
    esac
    echo -e "\n"
done
