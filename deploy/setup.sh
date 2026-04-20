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

REPO_RAW_URL="https://raw.githubusercontent.com/sostinewaliaula/pmt/main/deploy"

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
    echo -e "   2) ${BLUE}Download Latest Release${NC} (Pull images from GitHub)"
    echo -e "   3) ${BLUE}Start Services${NC} (docker-compose up)"
    echo -e "   4) ${YELLOW}Stop Services${NC} (docker-compose down)"
    echo -e "   5) ${BLUE}Restart Services${NC}"
    echo -e "   6) ${BLUE}View Logs${NC}"
    echo -e "   7) ${RED}Restore Data${NC} (Full or DB Only)"
    echo -e "   8) ${RED}Wipe Instance Data${NC} (Reset all volumes)"
    echo -e "   9) Exit"
    echo -ne "\nAction [3]: "
}

wipe_data() {
    echo -e "${RED}${BOLD}🚨 WARNING: This will permanently delete your database and all uploaded files!${NC}"
    echo -ne "Are you sure you want to completely reset this instance? (y/N): "
    read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Wiping all instance data...${NC}"
        docker compose down -v
        echo -e "${GREEN}✓ Done. Instance has been reset to a clean state.${NC}"
    else
        echo -e "${BLUE}Wipe cancelled.${NC}"
    fi
}

restore_data() {
    echo -e "${RED}${BOLD}WARNING: This will overwrite your current data!${NC}"
    echo -ne "Enter the path to your backup .tar.gz file: "
    read backup_file

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found.${NC}"
        return
    fi

    echo -e "\n${BOLD}Select Restoration Type:${NC}"
    echo -e "   1) ${BLUE}Database Only${NC} (Cleanest - No old logos/attachments)"
    echo -e "   2) ${GREEN}Full Restore${NC} (Includes all uploads/images)"
    echo -ne "\nChoice [1]: "
    read restore_choice

    echo -e "${YELLOW}Preparing restoration...${NC}"
    mkdir -p ./restore_tmp
    tar -xzf "$backup_file" -C ./restore_tmp

    if [[ "$restore_choice" == "2" ]]; then
        # Restore Uploads
        echo -e "${BLUE}Restoring Uploads...${NC}"
        # We find the volume name dynamically
        UPLOAD_VOL=$(docker volume ls -q | grep uploads | head -n 1)
        docker run --rm -v ./restore_tmp:/backup -v "$UPLOAD_VOL":/export alpine sh -c "rm -rf /export/* && tar xzf /backup/uploads.tar.gz -C /export"
    else
        # Wipe Uploads (Clean Start)
        echo -e "${BLUE}Wiping existing storage for a clean start...${NC}"
        UPLOAD_VOL=$(docker volume ls -q | grep uploads | head -n 1)
        docker run --rm -v "$UPLOAD_VOL":/export alpine sh -c "rm -rf /export/*"
    fi

    # Restore Database
    echo -e "${BLUE}Restoring Database...${NC}"
    docker compose exec -T plane-db psql -U caava -d caava_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
    docker compose exec -T plane-db psql -U caava -d caava_db < ./restore_tmp/database.sql

    rm -rf ./restore_tmp
    echo -e "${GREEN}✓ Restoration completed successfully!${NC}"
}

setup_env() {
    echo -e "\n${YELLOW}Setting up orchestration and environment files...${NC}"

    # 1. Download docker-compose.yml if missing
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${BLUE}Downloading docker-compose.yml from GitHub...${NC}"
        curl -fsSL -o docker-compose.yml "${REPO_RAW_URL}/docker-compose.yml"
    fi
    
    # 2. Setup .env
    if [ ! -f ".env" ]; then
        echo -e "${BLUE}Downloading .env.example from GitHub...${NC}"
        curl -fsSL -o .env.example "${REPO_RAW_URL}/caava.env.example"
        cp .env.example .env
        echo -e "${GREEN}✓${NC} Created .env from remote example"
        
        # Generate Security Keys and Backend Glue
        echo -e "${YELLOW}Generating Security Keys and Backend Glue...${NC}"
        SECRET_KEY=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        LIVE_SECRET=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        echo -e "\n# Security Keys" >> .env
        echo -e "SECRET_KEY=\"$SECRET_KEY\"" >> .env
        echo -e "LIVE_SERVER_SECRET_KEY=\"$LIVE_SECRET\"" >> .env
        echo -e "\n# Backend Connection URLs" >> .env
        echo -e "REDIS_URL=redis://plane-redis:6379/0" >> .env
        echo -e "DATABASE_URL=postgresql://\${POSTGRES_USER}:\${POSTGRES_PASSWORD}@plane-db:5432/\${POSTGRES_DB}" >> .env
    else
        echo -e "${BLUE}i${NC} .env already exists, skipping download."
    fi
}

pull_images() {
    echo -e "\n${YELLOW}Downloading your latest Caava Group release...${NC}"
    docker compose pull
    echo -e "${GREEN}✓ Done. Pull complete.${NC}"
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
        2) pull_images ;;
        3) start_services ;;
        4) stop_services ;;
        5) restart_services ;;
        6) view_logs ;;
        7) restore_data ;;
        8) wipe_data ;;
        9) exit 0 ;;
        *) echo -e "${RED}Invalid option, please try again.${NC}" ;;
    esac
    echo -e "\n"
done
