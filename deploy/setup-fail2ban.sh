#!/bin/bash
# Setup fail2ban for nginx scanner protection on the production server.
# Installs fail2ban, deploys custom filter/jail/action configs, and
# ensures the service is enabled.
#
# Usage: sudo ./deploy/setup-fail2ban.sh
# Run from the project root directory.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
FAIL2BAN_DIR="$PROJECT_DIR/fail2ban"

echo "========================================="
echo "fail2ban Setup for nginx Scanner Defense"
echo "========================================="

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run as root or with sudo"
    exit 1
fi

if [ ! -d "$FAIL2BAN_DIR" ]; then
    echo "Error: fail2ban config directory not found at $FAIL2BAN_DIR"
    echo "Run this script from the project root directory."
    exit 1
fi

echo ""
echo "[1/5] Installing fail2ban..."
if ! command -v fail2ban-client &> /dev/null; then
    apt-get update -qq
    apt-get install -y -qq fail2ban
    echo "  fail2ban installed."
else
    echo "  fail2ban already installed."
fi

echo ""
echo "[2/5] Deploying custom filter..."
cp "$FAIL2BAN_DIR/nginx-scanner.conf" /etc/fail2ban/filter.d/nginx-scanner.conf
echo "  Copied filter to /etc/fail2ban/filter.d/nginx-scanner.conf"

echo ""
echo "[3/5] Deploying custom iptables action for Docker..."
cp "$FAIL2BAN_DIR/iptables-docker.conf" /etc/fail2ban/action.d/iptables-docker.conf
echo "  Copied action to /etc/fail2ban/action.d/iptables-docker.conf"

echo ""
echo "[4/5] Deploying jail configuration..."
cp "$FAIL2BAN_DIR/jail-nginx-scanner.conf" /etc/fail2ban/jail.d/nginx-scanner.conf
echo "  Copied jail to /etc/fail2ban/jail.d/nginx-scanner.conf"

echo ""
echo "[5/5] Enabling and restarting fail2ban..."
systemctl enable fail2ban
systemctl restart fail2ban

sleep 2

echo ""
echo "========================================="
echo "fail2ban setup complete!"
echo "========================================="
echo ""
echo "Jail status:"
fail2ban-client status nginx-scanner 2>/dev/null || echo "  (jail may take a moment to initialize)"
echo ""
echo "Useful commands:"
echo "  sudo fail2ban-client status nginx-scanner   # Check jail status"
echo "  sudo fail2ban-client set nginx-scanner unbanip <IP>  # Unban an IP"
echo "  sudo fail2ban-client set nginx-scanner banip <IP>    # Manually ban an IP"
echo "  sudo tail -f /var/log/fail2ban.log          # Watch fail2ban logs"
