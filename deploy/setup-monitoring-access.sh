#!/bin/bash
# Generate htpasswd file for monitoring access
set -e

ENVIRONMENT=${1:-staging}

if [ -z "$MONITORING_PASSWORD" ]; then
    echo "Error: MONITORING_PASSWORD environment variable not set"
    exit 1
fi

MONITORING_USER=${MONITORING_USER:-admin}

# Install apache2-utils if needed
if ! command -v htpasswd &> /dev/null; then
    sudo apt-get install -y apache2-utils
fi

# Create htpasswd file
HTPASSWD_PATH="/opt/theboosh-zone/nginx/.htpasswd"
mkdir -p /opt/theboosh-zone/nginx
htpasswd -cb "$HTPASSWD_PATH" "$MONITORING_USER" "$MONITORING_PASSWORD"
chmod 644 "$HTPASSWD_PATH"

echo "Htpasswd file created at $HTPASSWD_PATH"
