#!/bin/bash

##############################################
# n8n Backup Script
# Creates full backup of n8n data and database
##############################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backup"
DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="n8n_full_backup_$DATE"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Create backup directory
mkdir -p "$BACKUP_DIR"
cd "$PROJECT_DIR"

# Load and validate environment variables
if [ -f ".env" ]; then
    source .env

    # Validate critical environment variables
    if [ -z "$N8N_ENCRYPTION_KEY" ]; then
        error "N8N_ENCRYPTION_KEY is not set in .env file!"
        exit 1
    fi

    if [ -z "$POSTGRES_PASSWORD" ]; then
        error "POSTGRES_PASSWORD is not set in .env file!"
        exit 1
    fi
else
    error ".env file not found in $PROJECT_DIR"
    exit 1
fi

log "Starting full backup process..."

# Check available disk space (require at least 1GB free)
AVAILABLE_SPACE=$(df "$BACKUP_DIR" | tail -1 | awk '{print $4}')
REQUIRED_SPACE=1048576  # 1GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    error "Insufficient disk space. Available: $(($AVAILABLE_SPACE/1024))MB, Required: $(($REQUIRED_SPACE/1024))MB"
    exit 1
fi

log "Disk space check passed: $(($AVAILABLE_SPACE/1024))MB available"

# Create temporary directory for this backup
TEMP_BACKUP="$BACKUP_DIR/${BACKUP_NAME}_temp"
mkdir -p "$TEMP_BACKUP"

# Backup database
log "Backing up PostgreSQL database..."
if docker-compose exec -T postgres pg_dump -U n8n n8n > "$TEMP_BACKUP/database.sql"; then
    log "Database backup completed"
else
    error "Database backup failed"
    rm -rf "$TEMP_BACKUP"
    exit 1
fi

# Backup n8n data directory
log "Backing up n8n data directory..."
if [ -d "data/n8n" ]; then
    cp -r data/n8n "$TEMP_BACKUP/n8n_data"
    log "n8n data backup completed"
fi

# Backup environment file
log "Backing up environment configuration..."
if [ -f ".env" ]; then
    cp .env "$TEMP_BACKUP/env_backup"
    log "Environment file backed up"
fi

# Create compressed archive
log "Creating compressed archive..."
cd "$BACKUP_DIR"

if tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}_temp"; then
    log "Archive created successfully"
    rm -rf "${BACKUP_NAME}_temp"
else
    error "Failed to create archive"
    rm -rf "${BACKUP_NAME}_temp"
    exit 1
fi

log "Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"

# Calculate backup size
BACKUP_SIZE=$(du -h "${BACKUP_NAME}.tar.gz" | cut -f1)
log "Backup size: $BACKUP_SIZE"

# Clean old backups (keep last 30 days)
log "Cleaning old backups (keeping last 30 days)..."
find "$BACKUP_DIR" -name "n8n_full_backup_*.tar.gz" -type f -mtime +30 -delete

# List remaining backups
BACKUP_COUNT=$(ls -1 n8n_full_backup_*.tar.gz 2>/dev/null | wc -l)
log "Total backups available: $BACKUP_COUNT"

log "Backup process completed successfully!"
exit 0
