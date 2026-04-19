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

REPO_RAW_URL="https://raw.githubusercontent.com/sostinewaliaula/pmt/feature/ldap/deploy"
LOG_DIR="./logs"
LOG_FILE="${LOG_DIR}/caava-setup.log"

mkdir -p "$LOG_DIR"

log() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

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
    echo -e "   8) ${YELLOW}Developer Mode${NC} (Build local code & Mock LDAP)"
    echo -e "   9) ${GREEN}Deploy LDAP Release${NC} (Pull GitHub Images)"
    echo -e "   10) ${RED}Wipe LDAP Data${NC} (Use to reset password/database)"
    echo -e "   11) Exit"
    echo -ne "\nAction [2]: "
}

install() {
    echo -e "${YELLOW}Installing Caava Group orchestration files...${NC}"

    # Download files to current directory
    echo -e "${BLUE}Downloading orchestration files from GitHub...${NC}"
    curl -fsSL -o docker-compose.yml "${REPO_RAW_URL}/docker-compose.yml"
    
    if [ ! -f ".env" ]; then
        curl -fsSL -o .env "${REPO_RAW_URL}/caava.env.example"
        # Generate SECRET_KEY and LIVE_SERVER_SECRET_KEY
        SECRET_KEY=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        LIVE_SECRET=$(tr -dc 'a-z0-9' < /dev/urandom | head -c50)
        echo -e "\nSECRET_KEY=\"$SECRET_KEY\"" >> .env
        echo -e "LIVE_SERVER_SECRET_KEY=\"$LIVE_SECRET\"" >> .env
        echo -e "${GREEN}✓ Created .env with new Security Keys${NC}"
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
    log "Starting backup: $BACKUP_NAME"
    
    # 1. Backup Database
    echo -e "${BLUE}Dumping Database...${NC}"
    docker compose exec -T plane-db pg_dump -U caava_admin caava_db > ./backups/"$BACKUP_NAME"/database.sql 2>> "$LOG_FILE"
    
    # 2. Backup Uploads (Minio Volume)
    echo -e "${BLUE}Compressing Uploads...${NC}"
    MINIO_ID=$(docker compose ps -q plane-minio)
    docker run --rm --volumes-from "$MINIO_ID" -v $(pwd)/backups/"$BACKUP_NAME":/backup alpine tar czf /backup/uploads.tar.gz -C /export . 2>> "$LOG_FILE"

    # 3. Final compression
    tar -czf ./backups/"$BACKUP_NAME".tar.gz -C ./backups/"$BACKUP_NAME" . 2>> "$LOG_FILE"
    rm -rf ./backups/"$BACKUP_NAME"

    echo -e "${GREEN}✓ Backup created: ./backups/${BACKUP_NAME}.tar.gz${NC}"
    log "Backup completed successfully."
}

restore_data() {
    echo -e "${RED}${BOLD}WARNING: This will overwrite your current data!${NC}"
    echo -ne "Enter the path to your backup .tar.gz file: "
    read backup_file

    if [ ! -f "$backup_file" ]; then
        echo -e "${RED}Error: Backup file not found.${NC}"
        log "Restore failed: File $backup_file not found."
        return
    fi

    echo -e "${YELLOW}Preparing restoration...${NC}"
    log "Starting restoration from $backup_file"
    mkdir -p ./restore_tmp
    tar -xzf "$backup_file" -C ./restore_tmp 2>> "$LOG_FILE"

    # 1. Restore Uploads
    echo -e "${BLUE}Restoring Uploads...${NC}"
    MINIO_ID=$(docker compose ps -q plane-minio)
    docker run --rm -v ./restore_tmp:/backup --volumes-from "$MINIO_ID" alpine sh -c "rm -rf /export/* && tar xzf /backup/uploads.tar.gz -C /export" 2>> "$LOG_FILE"

    # 2. Restore Database
    echo -e "${BLUE}Restoring Database...${NC}"
    # Fresh Slate: Drop and recreate schema
    docker compose exec -T plane-db psql -U caava_admin -d caava_db -c "DROP SCHEMA public CASCADE; CREATE SCHEMA public;" 2>> "$LOG_FILE"
    docker compose exec -T plane-db psql -U caava_admin -d caava_db < ./restore_tmp/database.sql 2>> "$LOG_FILE"

    rm -rf ./restore_tmp
    echo -e "${GREEN}✓ Restoration completed successfully!${NC}"
    log "Restoration completed successfully."
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

dev_mode() {
    echo -e "${YELLOW}Entering Developer Mode...${NC}"
    log "Initiating developer mode"

    # 1. Download dev compose if not present
    if [ ! -f "docker-compose.dev.yml" ]; then
        echo -e "${BLUE}Downloading development orchestration files...${NC}"
        curl -fsSL -o docker-compose.dev.yml "${REPO_RAW_URL}/docker-compose.dev.yml"
    fi

    # 2. Setup dev .env if not present
    if [ ! -f ".dev.env" ]; then
        echo -e "${BLUE}Creating .dev.env from template...${NC}"
        curl -fsSL -o .dev.env "${REPO_RAW_URL}/caava.dev.env.example"
        # Set dev keys
        # Replace localhost with 8091 for dev
        sed -i 's/localhost/localhost:8091/g' .dev.env
        echo "SECRET_KEY=\"caava-dev-secret-key-12345\"" >> .dev.env
        echo "LIVE_SERVER_SECRET_KEY=\"caava-dev-live-key-12345\"" >> .dev.env
    fi

    echo -e "${GREEN}Building and launching Sandbox on Port 8091...${NC}"
    # Use -p to isolate dev project from production
    docker compose -p caava-dev -f docker-compose.dev.yml up -d --build
    
    echo -e "${BOLD}${GREEN}✅ Sandbox is live!${NC}"
    # Try to extract URL from .dev.env
    DEV_URL=$(grep WEB_URL .dev.env | cut -d'=' -f2 | tr -d '"')
    echo -e "URL: ${BLUE}${DEV_URL:-http://localhost:8091}${NC}"
    echo -e "Logs: ${BLUE}docker compose -p caava-dev -f docker-compose.dev.yml logs -f${NC}"
    log "Developer mode active on port 8091"
}

ldap_release() {
    echo -e "${GREEN}Deploying LDAP Release from GitHub...${NC}"
    log "Initiating LDAP release deployment"

    # 1. Download LDAP compose if not present
    if [ ! -f "docker-compose.ldap.yml" ]; then
        echo -e "${BLUE}Downloading LDAP orchestration files...${NC}"
        curl -fsSL -o docker-compose.ldap.yml "${REPO_RAW_URL}/docker-compose.ldap.yml"
    fi

    echo -e "${BLUE}Pulling pre-built feature images from GHCR...${NC}"
    docker compose -p caava-ldap -f docker-compose.ldap.yml pull
    
    echo -e "${GREEN}Launching LDAP Release on Port 8092...${NC}"
    docker compose -p caava-ldap -f docker-compose.ldap.yml up -d
    
    echo -e "${BOLD}${GREEN}✅ LDAP Release is live!${NC}"
    # Try to extract URL from .env
    PROD_URL=$(grep WEB_URL .env | cut -d'=' -f2 | tr -d '"')
    echo -e "URL: ${BLUE}${PROD_URL:-http://localhost:8092}${NC}"
    log "LDAP release active on port 8092"
}

wipe_ldap() {
    echo -e "${RED}${BOLD}WARNING: This will permanently delete your LDAP test database and uploads!${NC}"
    echo -ne "Are you sure you want to continue? (y/N): "
    read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Wiping LDAP Release data...${NC}"
        docker compose -p caava-ldap -f docker-compose.ldap.yml down -v
        echo -e "${GREEN}✓ Done. You can now run Option 9 for a fresh start.${NC}"
        log "LDAP data wiped successfully"
    else
        echo -e "${BLUE}Wipe cancelled.${NC}"
    fi
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
        8) dev_mode ;;
        9) ldap_release ;;
        10) wipe_ldap ;;
        11) exit 0 ;;
        *) echo -e "${RED}Invalid option.${NC}" ;;
    esac
done
