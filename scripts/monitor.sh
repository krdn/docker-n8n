#!/bin/bash

# n8n Service Monitoring and Auto-Recovery Script
# This script checks n8n service health and sends email alerts on failure

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
LOG_DIR="$PROJECT_DIR/logs"
ALERT_EMAIL="krdn.net@gmail.com"
HOSTNAME=$(hostname)
TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
LOG_FILE="$LOG_DIR/monitor.log"

# Ensure log directory exists
mkdir -p "$LOG_DIR"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Send email notification
send_email_alert() {
    local subject="$1"
    local body="$2"
    local temp_file=$(mktemp)

    cat > "$temp_file" << EOF
Subject: [n8n Alert] $subject
To: $ALERT_EMAIL
From: n8n-monitor@$HOSTNAME

==============================================
n8n Service Alert
==============================================

Time: $TIMESTAMP
Host: $HOSTNAME
Alert: $subject

$body

==============================================
This is an automated alert from n8n monitoring system.
==============================================
EOF

    # Send email using sendmail/msmtp
    if command -v msmtp &> /dev/null; then
        cat "$temp_file" | msmtp "$ALERT_EMAIL"
        log_message "✉️ Email sent via msmtp to $ALERT_EMAIL"
    elif command -v sendmail &> /dev/null; then
        cat "$temp_file" | sendmail -t
        log_message "✉️ Email sent via sendmail to $ALERT_EMAIL"
    else
        log_message "⚠️ No email client found (msmtp or sendmail)"
        # Save email to file as fallback
        cat "$temp_file" > "$LOG_DIR/unsent_alert_$(date +%Y%m%d_%H%M%S).txt"
        log_message "📁 Alert saved to log directory"
    fi

    rm -f "$temp_file"
}

# Check service health
check_service_health() {
    cd "$PROJECT_DIR" || exit 1

    log_message "🔍 Checking n8n service health..."

    # Get service status
    local status_output=$(docker-compose ps 2>&1)
    local services=("n8n" "n8n-postgres" "n8n-redis" "n8n-worker")
    local failed_services=()
    local service_logs=""

    # Check each service
    for service in "${services[@]}"; do
        if echo "$status_output" | grep -q "$service"; then
            # Service exists, check if it's running and healthy
            local service_line=$(echo "$status_output" | grep "$service")

            # Check for "Up" and "healthy" in the state column
            if echo "$service_line" | grep -qE "Up.*\(healthy\)|Up \(healthy\)"; then
                log_message "✅ Service $service is healthy"
            elif echo "$service_line" | grep -q "Up"; then
                # Service is up but not healthy (no health check or starting)
                log_message "⚠️ Service $service is up but not healthy yet"
                failed_services+=("$service")

                # Collect last 50 lines of logs
                service_logs+="\\n\\n=== Logs for $service ===\\n"
                service_logs+="$(docker-compose logs --tail=50 "$service" 2>&1 | head -n 50)"
            else
                # Service is not running
                local service_status=$(echo "$service_line" | awk '{for(i=4;i<=NF;i++) printf "%s ", $i; print ""}')
                failed_services+=("$service")
                log_message "❌ Service $service is not running: $service_status"

                # Collect last 50 lines of logs
                service_logs+="\\n\\n=== Logs for $service ===\\n"
                service_logs+="$(docker-compose logs --tail=50 "$service" 2>&1 | head -n 50)"
            fi
        else
            failed_services+=("$service")
            log_message "❌ Service $service not found"
        fi
    done

    # If any service failed, take action
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_message "⚠️ ${#failed_services[@]} service(s) failed: ${failed_services[*]}"

        # Prepare detailed alert message
        local alert_body="Failed Services: ${failed_services[*]}

=== Service Status ===
$status_output

=== Recent Logs ===
$service_logs

=== System Info ===
Disk Usage: $(df -h / | tail -1 | awk '{print $5}')
Memory Usage: $(free -h | grep Mem | awk '{print $3 "/" $2}')
Docker Status: $(systemctl is-active docker)

=== Automatic Recovery Action ===
Attempting to restart failed services..."

        # Send email alert
        send_email_alert "Service Failure Detected on $HOSTNAME" "$alert_body"

        # Attempt to restart services
        attempt_recovery

        return 1
    else
        log_message "✅ All services are healthy"
        return 0
    fi
}

# Attempt to recover services
attempt_recovery() {
    log_message "🔧 Attempting automatic recovery..."

    cd "$PROJECT_DIR" || exit 1

    # Try to restart services
    log_message "🔄 Restarting all services..."
    docker-compose restart 2>&1 | tee -a "$LOG_FILE"

    # Wait for services to stabilize
    sleep 30

    # Check if recovery was successful
    local recovery_status=$(docker-compose ps 2>&1)
    local recovery_success=true

    for service in n8n n8n-postgres n8n-redis n8n-worker; do
        if echo "$recovery_status" | grep "$service" | grep -qE "(healthy|Up)"; then
            log_message "✅ Service $service recovered successfully"
        else
            log_message "❌ Service $service recovery failed"
            recovery_success=false
        fi
    done

    # Send recovery status email
    if [ "$recovery_success" = true ]; then
        send_email_alert "Service Recovery Successful on $HOSTNAME" "All services have been successfully restarted and are now healthy.

=== Current Status ===
$recovery_status

Recovery completed at: $(date '+%Y-%m-%d %H:%M:%S')"
        log_message "✅ Recovery successful"
    else
        send_email_alert "Service Recovery FAILED on $HOSTNAME" "Automatic recovery was attempted but some services are still failing.

=== Current Status ===
$recovery_status

Manual intervention may be required.
Please check the system immediately."
        log_message "❌ Recovery failed - manual intervention required"
    fi
}

# Main execution
main() {
    log_message "========================================="
    log_message "Starting n8n service health check"

    check_service_health
    exit_code=$?

    log_message "Health check completed with exit code: $exit_code"
    log_message "========================================="

    exit $exit_code
}

# Run main function
main
