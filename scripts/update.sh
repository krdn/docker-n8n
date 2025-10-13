#!/bin/bash

##############################################
# n8n Auto Update Script
# This script safely updates n8n and its components
##############################################

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_DIR/backup"
LOG_FILE="$PROJECT_DIR/logs/update.log"
DATE=$(date +"%Y%m%d_%H%M%S")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

# Create necessary directories
mkdir -p "$BACKUP_DIR" "$PROJECT_DIR/logs"

# Navigate to project directory
cd "$PROJECT_DIR"

log "========================================="
log "Starting n8n update process"
log "========================================="

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if docker-compose.yml exists
if [ ! -f "docker-compose.yml" ]; then
    error "docker-compose.yml not found in $PROJECT_DIR"
    exit 1
fi

# Backup database before update
log "Creating database backup..."
BACKUP_FILE="$BACKUP_DIR/n8n_backup_$DATE.sql"

if docker-compose exec -T postgres pg_dump -U n8n n8n > "$BACKUP_FILE" 2>/dev/null; then
    log "Database backup created: $BACKUP_FILE"
    gzip "$BACKUP_FILE"
    log "Backup compressed: ${BACKUP_FILE}.gz"
else
    warning "Database backup failed or database is not running"
fi

# Keep only last 7 backups
log "Cleaning old backups (keeping last 7)..."
cd "$BACKUP_DIR"
ls -t n8n_backup_*.sql.gz 2>/dev/null | tail -n +8 | xargs -r rm -f
cd "$PROJECT_DIR"

# Pull latest images
log "Pulling latest Docker images..."
if docker-compose pull; then
    log "Docker images updated successfully"
else
    error "Failed to pull Docker images"
    exit 1
fi

# Check for image updates
OLD_IMAGE_ID=$(docker-compose images -q n8n)
NEW_IMAGE_ID=$(docker images -q docker.n8n.io/n8nio/n8n:latest)

if [ "$OLD_IMAGE_ID" = "$NEW_IMAGE_ID" ]; then
    log "No new updates available. n8n is already up to date."
    exit 0
fi

log "New version detected. Proceeding with update..."

# Stop services gracefully
log "Stopping n8n services..."
if docker-compose down; then
    log "Services stopped successfully"
else
    error "Failed to stop services"
    exit 1
fi

# Remove old images
log "Removing old Docker images..."
docker image prune -f > /dev/null 2>&1

# Start services with updated images
log "Starting n8n services with new version..."
if docker-compose up -d; then
    log "Services started successfully"
else
    error "Failed to start services"
    error "Attempting to restore from backup..."

    # Restore backup if startup fails
    if [ -f "${BACKUP_FILE}.gz" ]; then
        gunzip "${BACKUP_FILE}.gz"
        docker-compose up -d postgres
        sleep 10
        docker-compose exec -T postgres psql -U n8n -d n8n < "$BACKUP_FILE"
        docker-compose up -d
    fi
    exit 1
fi

# Wait for services to be healthy
log "Waiting for services to be healthy..."
sleep 15

RETRY_COUNT=0
MAX_RETRIES=12

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if docker-compose ps | grep -q "healthy"; then
        log "Services are healthy!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT + 1))
    log "Waiting for services to be healthy... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    warning "Services did not become healthy within expected time"
    warning "Please check the logs: docker-compose logs"
fi

# Show service status
log "Current service status:"
docker-compose ps

# Get new version
NEW_VERSION=$(docker-compose exec -T n8n n8n --version 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "unknown")
log "n8n updated to version: $NEW_VERSION"

log "========================================="
log "Update completed successfully!"
log "========================================="

# Clean up old logs (keep last 30 days)
find "$PROJECT_DIR/logs" -name "update.log*" -type f -mtime +30 -delete 2>/dev/null || true

exit 0
