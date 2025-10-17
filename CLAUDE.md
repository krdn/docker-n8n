# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Architecture Overview

This is a **production-ready n8n deployment** using Docker Compose with a queue-based architecture for scalability:

- **n8n main service**: Web UI and API (port 5678, localhost only)
- **n8n-worker**: Background worker for executing workflows via Redis queue
- **PostgreSQL 16**: Primary database for workflow data and executions
- **Redis 7**: Queue management with LRU eviction policy (1GB limit)
- **System Nginx**: Reverse proxy (NOT containerized) with SSL/TLS termination

**Key architectural decision**: Queue mode (`EXECUTIONS_MODE=queue`) allows horizontal scaling of workers. The main n8n service handles UI/API while workers process workflows asynchronously.

## Critical Environment Variables

The `.env` file contains sensitive configuration. **NEVER modify `N8N_ENCRYPTION_KEY` after first deployment** - this will make all encrypted credentials unrecoverable.

Required variables:
- `N8N_HOST`: Domain name
- `WEBHOOK_URL`: Full webhook URL (must match domain)
- `POSTGRES_PASSWORD`: Database password
- `N8N_ENCRYPTION_KEY`: Generated encryption key (IMMUTABLE)

## Common Commands

### Service Management
```bash
# Start all services
docker-compose up -d

# Check health status (all should show "healthy")
docker-compose ps

# View logs
docker-compose logs -f [service_name]  # n8n, postgres, redis, n8n-worker

# Restart specific service
docker-compose restart [service_name]
```

### Updates
```bash
# Automated update (recommended)
./scripts/update.sh

# Manual update
docker-compose pull
docker-compose down
docker-compose up -d
```

### Backups
```bash
# Create backup
./scripts/backup.sh

# Restore from backup
docker-compose down
cd backup && tar -xzf n8n_full_backup_YYYYMMDD_HHMMSS.tar.gz
# Follow restore steps in README.md
```

### Database Operations
```bash
# Connect to PostgreSQL
docker-compose exec postgres psql -U n8n -d n8n

# Manual backup
docker-compose exec -T postgres pg_dump -U n8n n8n > backup/manual_$(date +%Y%m%d).sql

# Check database size
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"

# Optimize database
docker-compose exec postgres psql -U n8n -d n8n -c "VACUUM ANALYZE;"
```

### Monitoring
```bash
# Health checks
curl http://localhost:5678/healthz
docker-compose exec postgres pg_isready -U n8n
docker-compose exec redis redis-cli ping

# Resource usage
docker stats

# Check automation timers
sudo systemctl list-timers n8n-*
```

## Automation System

### Systemd Timers
- **n8n-update.timer**: Weekly updates (Sunday 3:00 AM ±30min)
- **n8n-backup.timer**: Daily backups (2:00 AM ±15min)

Both run from systemd, not cron. Service files are in `/etc/systemd/system/`.

### Update Script Workflow
The `scripts/update.sh` script follows this sequence:
1. Validates Docker is running
2. Creates database backup with timestamp
3. Pulls latest images
4. Compares image IDs to detect actual updates
5. Stops services gracefully
6. Prunes old images
7. Starts services with new version
8. Waits for health checks (up to 60 seconds)
9. Logs version and status

**Auto-rollback**: If startup fails, attempts to restore from the backup created in step 2.

## Nginx Configuration

Nginx runs on the **host system**, not in Docker. Configuration in `nginx-config/n8n.conf` includes:

- Upstream to `127.0.0.1:5678` (n8n main service)
- WebSocket support (Upgrade/Connection headers)
- SSL/TLS with Let's Encrypt certificates
- Security headers (HSTS, X-Frame-Options, etc.)
- Health endpoint at `/healthz`

To update Nginx config:
```bash
sudo cp nginx-config/n8n.conf /etc/nginx/sites-available/n8n
sudo nginx -t
sudo systemctl reload nginx
```

## Performance Tuning

### Scaling Workers
Edit `docker-compose.yml` to add worker replicas:
```yaml
n8n-worker:
  deploy:
    replicas: 3  # Increase based on workload
```

### Redis Memory
Current limit: 1GB with `allkeys-lru` eviction and `everysec` fsync. Adjust in `docker-compose.yml`:
```yaml
command: redis-server --appendonly yes --maxmemory 2gb --maxmemory-policy allkeys-lru --appendfsync everysec
```

### PostgreSQL Tuning
Shared buffers and connection limits can be adjusted via custom `postgresql.conf` in `data/postgres/`.

## Troubleshooting

### Services won't start
1. Check Docker status: `sudo systemctl status docker`
2. Check disk space: `df -h`
3. Review logs: `docker-compose logs`
4. Restart Docker: `sudo systemctl restart docker && docker-compose up -d`

### Database connection issues
- Verify PostgreSQL is healthy: `docker-compose exec postgres pg_isready -U n8n`
- Check connection count: `docker-compose exec postgres psql -U n8n -d n8n -c "SELECT count(*) FROM pg_stat_activity;"`
- If max connections reached, restart PostgreSQL: `docker-compose restart postgres`

### Worker not processing
- Check Redis connection: `docker-compose exec redis redis-cli ping`
- Review worker logs: `docker-compose logs -f n8n-worker`
- Verify queue mode: `docker-compose exec n8n env | grep EXECUTIONS_MODE` (should be "queue")

### SSL certificate renewal
Certbot auto-renewal is enabled via systemd timer. Manual renewal:
```bash
sudo certbot renew --nginx
sudo systemctl reload nginx
```

## Data Persistence

All persistent data is in `./data/`:
- `data/n8n/`: Workflow definitions, credentials (encrypted), settings
- `data/postgres/`: PostgreSQL database files
- `data/redis/`: Redis AOF persistence
- `data/local-files/`: User-uploaded files from workflows

**Never delete `data/` without backup** - it contains all workflow data and encrypted credentials.

## Security Notes

- n8n port 5678 is bound to `127.0.0.1` only (not exposed to network)
- All external traffic goes through Nginx with SSL/TLS
- Firewall (UFW) should allow ports 22, 80, 443 only
- `N8N_BASIC_AUTH_ACTIVE` can be enabled for additional authentication layer
- Encryption key must be backed up securely and never changed
