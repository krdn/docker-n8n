#!/bin/bash

# n8n Monitor Systemd Installation Script
# This script installs and enables the n8n monitoring service

set -e

echo "🔧 Installing n8n monitoring systemd service..."

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "❌ This script must be run as root (use sudo)"
    exit 1
fi

# Copy service and timer files
echo "📋 Copying systemd files..."
cp /home/gon/docker-n8n/systemd/n8n-monitor.service /etc/systemd/system/
cp /home/gon/docker-n8n/systemd/n8n-monitor.timer /etc/systemd/system/

# Set proper permissions
echo "🔒 Setting permissions..."
chmod 644 /etc/systemd/system/n8n-monitor.service
chmod 644 /etc/systemd/system/n8n-monitor.timer

# Reload systemd daemon
echo "🔄 Reloading systemd daemon..."
systemctl daemon-reload

# Enable and start the timer
echo "✅ Enabling and starting n8n-monitor.timer..."
systemctl enable n8n-monitor.timer
systemctl start n8n-monitor.timer

# Show status
echo ""
echo "📊 Monitor Timer Status:"
systemctl status n8n-monitor.timer --no-pager -l

echo ""
echo "📅 Upcoming Monitor Runs:"
systemctl list-timers n8n-monitor.timer --no-pager

echo ""
echo "✅ Installation complete!"
echo ""
echo "Useful commands:"
echo "  - Check timer status:   systemctl status n8n-monitor.timer"
echo "  - Check service logs:   journalctl -u n8n-monitor.service -f"
echo "  - Run monitor now:      systemctl start n8n-monitor.service"
echo "  - Disable monitoring:   systemctl stop n8n-monitor.timer && systemctl disable n8n-monitor.timer"
echo ""
