#!/bin/bash

# Caava Group - Project Management One-Line Installer
# This script downloads necessary orchestration files and manages your instance.

# Set colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

REPO_RAW_URL="https://raw.githubusercontent.com/sostinewaliaula/pmt/main/deploy"

echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${BLUE}              Caava Group - One-Line Installer                        ${NC}"
echo -e "${BOLD}${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

show_menu() {
    echo -e "\n${BOLD}Select an action you want to perform:${NC}"
    echo -e "   1) ${GREEN}Install/Update${NC} (Download orchestration files)"
    echo -e "   2) ${BLUE}Start Services${NC} (Fetch containers & Launch)"
    echo -e "   3) ${YELLOW}Stop Services${NC}"
    echo -e "   4) ${BLUE}Restart Services${NC}"
    echo -e "   5) ${BLUE}View Logs${NC}"
    echo -e "   6) ${RED}Backup Data${NC} (Database & Uploads)"
    echo -e "   7) ${RED}Restore Data${NC} (From backup file)"
    echo -e "   8) Exit"
    echo -ne "\nAction [2]: "
}

install() {
    echo -e "${YELLOW}Installing Caava Group orchestration files...${NC}"

    # Download files to current directory
    echo -e "${BLUE}Downloading orchestration files from GitHub...${NC}"
    curl -fsSL -o docker-compose.yml "${REPO_RAW_URL}/docker-compose.yml"
    
    if [ ! -f ".env" ]; then
        curl -fsSL -o .env "${REPO_RAW_URL}/caava.env.example"
        # Generate SECRET_KEY
        SECRET_KEY=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        echo -e "\nSECRET_KEY=\"$SECRET_KEY\"" >> .env
        echo -e "${GREEN}✓ Created .env with new SECRET_KEY${NC}"
    else
        echo -e "${BLUE}i${NC} .env already exists, skipping download to protect your settings."
    fi

    echo -e "${GREEN}✓ Deployment files are ready in $(pwd)${NC}"
    echo -e "${YELLOW}Next Step: Edit the .env file to set your WEB_URL, then run Option 2 to Start.${NC}"
}

backup_data() {
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    BACKUP_NAME="caava-backup-${TIMESTAMP}"
    mkdir -p ./backups/"$BACKUP_NAME"

    echo -e "${YELLOW}Starting Full Backup...${NC}"
    
    # 1. Backup Database
    echo -e "${BLUE}Dumping Database...${NC}"
    docker compose exec plane-db pg_dump -U caava_admin caava_db > ./backups/"$BACKUP_NAME"/database.sql
    
    # 2. Backup Uploads (Minio Volume)
    echo -e "${BLUE}Compressing Uploads...${NC}"
    # We use a temporary container to access the volume
    docker run --rm --volumes-from caava-minio -v $(pwd)/backups/"$BACKUP_NAME":/backup alpine tar czf /backup/uploads.tar.gz -C /export .

    # 3. Final compression
    tar -czf ./backups/"$BACKUP_NAME".tar.gz -C ./backups/"$BACKUP_NAME" .
    rm -rf ./backups/"$BACKUP_NAME"

    echo -e "${GREEN}✓ Backup created: ./backups/${BACKUP_NAME}.tar.gz${NC}"
}

restore_data() {
    echo -e "${RED}${BOLD}WARNING: This will overwrite your current data!${NC}"
    echo -ne "Enter the path to your backup .tar.gz file: "
    read backup_file

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found.${NC}"
        return
    fi

    echo -e "${YELLOW}Preparing restoration...${NC}"
    mkdir -p ./restore_tmp
    tar -xzf "$backup_file" -C ./restore_tmp

    # 1. Restore Uploads
    echo -e "${BLUE}Restoring Uploads...${NC}"
    docker run --rm -v ./restore_tmp:/backup --volumes-from caava-minio alpine sh -c "rm -rf /export/* && tar xzf /backup/uploads.tar.gz -C /export"

    # 2. Restore Database
    echo -e "${BLUE}Restoring Database...${NC}"
    cat ./restore_tmp/database.sql | docker compose exec -T plane-db psql -U caava_admin caava_db

    rm -rf ./restore_tmp
    echo -e "${GREEN}✓ Restoration completed successfully!${NC}"
}

start() {
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}Error: docker-compose.yml not found. Please run Install (1) first.${NC}"
        return
    fi
    echo -e "${BLUE}Fetching latest Caava Group containers...${NC}"
    docker compose pull
    echo -e "${GREEN}Starting services...${NC}"
    docker compose up -d
}

stop() {
    docker compose down
}

restart() {
    docker compose restart
}

view_logs() {
    docker compose logs -f
}

while true; do
    show_menu
    read choice
    
    if [ -z "$choice" ]; then
        choice=2
    fi

    case $choice in
        1) install ;;
        2) start ;;
        3) stop ;;
        4) restart ;;
        5) view_logs ;;
        6) backup_data ;;
        7) restore_data ;;
        8) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
done
