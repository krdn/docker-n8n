# n8n Docker Installation Guide

Production-ready n8n installation using Docker Compose with PostgreSQL, Redis, and automatic updates.

## Architecture

- **n8n**: Main application (queue mode)
- **n8n-worker**: Background worker for workflow execution
- **PostgreSQL 16**: Primary database
- **Redis 7**: Queue management
- **Nginx**: Reverse proxy (system-level, not containerized)

## Prerequisites

```bash
# Install Docker and Docker Compose
sudo apt update
sudo apt install -y docker.io docker-compose

# Install Nginx
sudo apt install -y nginx

# Install Certbot for SSL (Let's Encrypt)
sudo apt install -y certbot python3-certbot-nginx

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

## Initial Setup

### 1. Configure Environment Variables

Edit `.env` file and customize these values:

```bash
# REQUIRED CHANGES:
N8N_HOST=your-domain.com
WEBHOOK_URL=https://your-domain.com
POSTGRES_PASSWORD=your_secure_password_here
N8N_BASIC_AUTH_PASSWORD=your_auth_password_here
```

**IMPORTANT**:
- The `N8N_ENCRYPTION_KEY` is already generated. DO NOT CHANGE IT after first run!
- Keep a secure backup of the encryption key. If lost, encrypted credentials cannot be recovered.

### 2. Configure Nginx Reverse Proxy

```bash
# Copy nginx configuration to system
sudo cp nginx-config/n8n.conf /etc/nginx/sites-available/n8n

# Edit the configuration with your domain
sudo nano /etc/nginx/sites-available/n8n
# Replace 'your-domain.com' with your actual domain

# Enable the site
sudo ln -s /etc/nginx/sites-available/n8n /etc/nginx/sites-enabled/

# Test configuration
sudo nginx -t

# If using SSL, obtain certificate (replace your-domain.com)
sudo certbot --nginx -d your-domain.com

# Reload Nginx
sudo systemctl reload nginx
```

### 3. Start n8n

```bash
# Start all services
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f

# Check specific service logs
docker-compose logs -f n8n
docker-compose logs -f postgres
```

### 4. Access n8n

Open your browser and navigate to:
- `https://your-domain.com`

Create your admin account on first visit.

## Automatic Updates

### Setup Automatic Updates

```bash
# Copy systemd service files
sudo cp systemd/n8n-update.service /etc/systemd/system/
sudo cp systemd/n8n-update.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start the timer
sudo systemctl enable n8n-update.timer
sudo systemctl start n8n-update.timer

# Check timer status
sudo systemctl status n8n-update.timer
sudo systemctl list-timers n8n-update.timer
```

### Manual Update

```bash
# Run update script manually
./scripts/update.sh

# View update logs
cat logs/update.log
```

The update script:
- Creates database backup before updating
- Pulls latest Docker images
- Performs zero-downtime update
- Verifies service health
- Keeps last 7 backups

### Update Schedule

By default, updates run:
- **Weekly**: Every Sunday at 3:00 AM
- **Randomized**: ±30 minutes to prevent load spikes
- **Persistent**: Runs after boot if missed

To change schedule:
```bash
sudo nano /etc/systemd/system/n8n-update.timer
# Modify OnCalendar line
# Examples:
# Daily at 3 AM: OnCalendar=*-*-* 03:00:00
# Every 3 days: OnCalendar=*-*-1,4,7,10,13,16,19,22,25,28,31 03:00:00

sudo systemctl daemon-reload
sudo systemctl restart n8n-update.timer
```

## Backup System

### Setup Automatic Backups

```bash
# Copy backup service files
sudo cp systemd/n8n-backup.service /etc/systemd/system/
sudo cp systemd/n8n-backup.timer /etc/systemd/system/

# Reload systemd
sudo systemctl daemon-reload

# Enable and start the timer
sudo systemctl enable n8n-backup.timer
sudo systemctl start n8n-backup.timer

# Check timer status
sudo systemctl status n8n-backup.timer
```

### Manual Backup

```bash
# Run backup script
./scripts/backup.sh

# Backups are stored in: ./backup/
# Format: n8n_full_backup_YYYYMMDD_HHMMSS.tar.gz
```

### Backup Schedule

By default, backups run:
- **Daily**: Every day at 2:00 AM
- **Retention**: 30 days
- **Contents**: Database + n8n data + environment config

### Restore from Backup

```bash
# Stop services
docker-compose down

# Extract backup
cd backup
tar -xzf n8n_full_backup_YYYYMMDD_HHMMSS.tar.gz
cd n8n_full_backup_YYYYMMDD_HHMMSS_temp

# Restore database
docker-compose up -d postgres
sleep 10
cat database.sql | docker-compose exec -T postgres psql -U n8n -d n8n

# Restore n8n data
rm -rf ../data/n8n/*
cp -r n8n_data/* ../data/n8n/

# Restore environment (if needed)
cp env_backup ../.env

# Start all services
cd ..
docker-compose up -d
```

## Monitoring

### Service Status

```bash
# Check all services
docker-compose ps

# Check health status
docker-compose ps | grep healthy

# View resource usage
docker stats
```

### Logs

```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f n8n
docker-compose logs -f postgres
docker-compose logs -f redis
docker-compose logs -f n8n-worker

# Last 100 lines
docker-compose logs --tail=100

# Update logs
cat logs/update.log

# Systemd service logs
sudo journalctl -u n8n-update.service -f
sudo journalctl -u n8n-backup.service -f
```

### Health Checks

All services have health checks:
- n8n: `http://localhost:5678/healthz`
- PostgreSQL: `pg_isready`
- Redis: `redis-cli ping`

```bash
# Check n8n health
curl http://localhost:5678/healthz

# Check PostgreSQL
docker-compose exec postgres pg_isready -U n8n

# Check Redis
docker-compose exec redis redis-cli ping
```

## Maintenance

### Update Commands

```bash
# Pull and update images
docker-compose pull
docker-compose up -d

# Rebuild without cache
docker-compose build --no-cache
docker-compose up -d

# View current versions
docker-compose exec n8n n8n --version
```

### Database Maintenance

```bash
# Connect to database
docker-compose exec postgres psql -U n8n -d n8n

# Create manual backup
docker-compose exec -T postgres pg_dump -U n8n n8n > backup/manual_backup_$(date +%Y%m%d).sql

# Database size
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"

# Vacuum database (optimize)
docker-compose exec postgres psql -U n8n -d n8n -c "VACUUM ANALYZE;"
```

### Cleanup

```bash
# Remove unused Docker images
docker image prune -a -f

# Remove unused volumes (CAUTION: Don't delete n8n volumes!)
docker volume ls
docker volume prune -f

# Clean old logs
find logs -name "*.log" -type f -mtime +30 -delete

# Clean old backups (older than 30 days)
find backup -name "*.tar.gz" -type f -mtime +30 -delete
```

## Troubleshooting

### Services won't start

```bash
# Check logs
docker-compose logs

# Check disk space
df -h

# Check Docker status
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
docker-compose up -d
```

### n8n is slow

```bash
# Check resource usage
docker stats

# Check Redis memory
docker-compose exec redis redis-cli INFO memory

# Check database connections
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT count(*) FROM pg_stat_activity;"

# Check workflow executions
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM execution_entity;"
```

### Database issues

```bash
# Check PostgreSQL logs
docker-compose logs postgres

# Check database connectivity
docker-compose exec postgres pg_isready -U n8n

# Check database size
docker-compose exec postgres psql -U n8n -d n8n -c "SELECT pg_size_pretty(pg_database_size('n8n'));"

# Vacuum database
docker-compose exec postgres psql -U n8n -d n8n -c "VACUUM FULL ANALYZE;"
```

### Reset n8n (DANGER: Deletes all data)

```bash
# Stop services
docker-compose down

# Remove all data (CAUTION!)
rm -rf data/*

# Start fresh
docker-compose up -d
```

## Security Best Practices

1. **Change default passwords** in `.env` file
2. **Enable firewall**:
   ```bash
   sudo ufw allow 22/tcp
   sudo ufw allow 80/tcp
   sudo ufw allow 443/tcp
   sudo ufw enable
   ```
3. **Regular updates**: Keep system and Docker updated
4. **SSL/TLS**: Use Let's Encrypt for HTTPS
5. **Backup encryption key**: Store `N8N_ENCRYPTION_KEY` securely
6. **Monitor logs**: Check for suspicious activity
7. **Restrict access**: Use Basic Auth or OAuth for additional security

## Performance Tuning

### Increase worker processes

Edit `docker-compose.yml`:
```yaml
n8n-worker:
  deploy:
    replicas: 2  # Increase number of workers
```

### Adjust PostgreSQL settings

Create `data/postgres/postgresql.conf`:
```
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 4MB
```

### Adjust Redis memory

Edit `docker-compose.yml`:
```yaml
redis:
  command: redis-server --appendonly yes --maxmemory 1gb
```

## Upgrading

The system handles updates automatically, but for major version upgrades:

1. **Backup everything**:
   ```bash
   ./scripts/backup.sh
   ```

2. **Read release notes**: Check n8n changelog for breaking changes

3. **Update**:
   ```bash
   ./scripts/update.sh
   ```

4. **Test workflows**: Verify critical workflows work correctly

## Support

- n8n Documentation: https://docs.n8n.io
- n8n Community: https://community.n8n.io
- GitHub Issues: https://github.com/n8n-io/n8n/issues

## File Structure

```
/home/gon/docker-n8n/
├── docker-compose.yml          # Main Docker Compose configuration
├── .env                         # Environment variables (DO NOT commit)
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
├── README.md                    # This file
├── data/                        # Persistent data (excluded from git)
│   ├── n8n/                    # n8n application data
│   ├── postgres/               # PostgreSQL data
│   ├── redis/                  # Redis data
│   └── local-files/            # File storage for workflows
├── backup/                      # Backup files (excluded from git)
├── logs/                        # Application logs
├── scripts/                     # Maintenance scripts
│   ├── update.sh               # Automatic update script
│   └── backup.sh               # Backup script
├── systemd/                     # Systemd service files
│   ├── n8n-update.service      # Update service
│   ├── n8n-update.timer        # Update timer
│   ├── n8n-backup.service      # Backup service
│   └── n8n-backup.timer        # Backup timer
└── nginx-config/                # Nginx configuration templates
    └── n8n.conf                # Nginx reverse proxy config
```

## License

This configuration is provided as-is. n8n is licensed under the Sustainable Use License.
