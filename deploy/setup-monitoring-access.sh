#!/bin/bash
# Setup monitoring access: SSL certificates, htpasswd, and IP whitelist
set -e

ENVIRONMENT=${1:-staging}

echo "========================================="
echo "Monitoring Access Setup"
echo "Environment: $ENVIRONMENT"
echo "========================================="

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "Error: Environment must be 'staging' or 'production'"
    exit 1
fi

# Validate required environment variables
if [ -z "$MONITORING_PASSWORD" ]; then
    echo "Error: MONITORING_PASSWORD environment variable not set"
    exit 1
fi

if [ -z "$MONITORING_ALLOWED_IPS" ]; then
    echo "Error: MONITORING_ALLOWED_IPS environment variable not set"
    echo "Example: export MONITORING_ALLOWED_IPS='1.2.3.4 5.6.7.8'"
    exit 1
fi

MONITORING_USER=${MONITORING_USER:-admin}

# =========================================
# Step 1: Generate SSL Certificates
# =========================================
echo ""
echo "Step 1: SSL Certificate Generation"
echo "-----------------------------------"

# Determine monitoring domains based on environment
if [ "$ENVIRONMENT" = "staging" ]; then
    MONITORING_DOMAINS=(
        "monitoring-staging.theboosh.zone"
        "prometheus-staging.theboosh.zone"
        "alertmanager-staging.theboosh.zone"
    )
    COMPOSE_FILE="docker-compose.staging.yml"
elif [ "$ENVIRONMENT" = "production" ]; then
    MONITORING_DOMAINS=(
        "monitoring.theboosh.zone"
        "prometheus.theboosh.zone"
        "alertmanager.theboosh.zone"
    )
    COMPOSE_FILE="docker-compose.production.yml"
fi

# Check if certbot is installed
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt-get update
    sudo apt-get install -y certbot
fi

# Check which certs already exist
CERTS_NEEDED=()
for domain in "${MONITORING_DOMAINS[@]}"; do
    if [ ! -d "/etc/letsencrypt/live/$domain" ]; then
        CERTS_NEEDED+=("$domain")
    else
        echo "Certificate already exists for $domain"
    fi
done

if [ ${#CERTS_NEEDED[@]} -gt 0 ]; then
    echo ""
    echo "Certificates needed for: ${CERTS_NEEDED[*]}"
    echo "IMPORTANT: Make sure DNS records point to this server!"
    echo ""

    # Check if nginx is running and stop it to free port 80
    NGINX_WAS_RUNNING=false
    if docker compose -f "/opt/theboosh-zone/$COMPOSE_FILE" ps nginx 2>/dev/null | grep -q "Up"; then
        echo "Stopping nginx to free port 80..."
        docker compose -f "/opt/theboosh-zone/$COMPOSE_FILE" stop nginx
        NGINX_WAS_RUNNING=true
    fi

    # Generate certificates
    for domain in "${CERTS_NEEDED[@]}"; do
        echo "Generating certificate for $domain..."
        sudo certbot certonly --standalone -d "$domain" \
            --non-interactive --agree-tos -m alexanderbeahm@gmail.com || {
            echo "Warning: Failed to generate cert for $domain - DNS may not be ready"
        }
    done

    # Restart nginx if it was running
    if [ "$NGINX_WAS_RUNNING" = true ]; then
        echo "Restarting nginx..."
        docker compose -f "/opt/theboosh-zone/$COMPOSE_FILE" start nginx
    fi
else
    echo "All SSL certificates already exist"
fi

# =========================================
# Step 2: Generate htpasswd and IP Whitelist
# =========================================
echo ""
echo "Step 2: htpasswd and IP Whitelist Generation"
echo "---------------------------------------------"

# Install apache2-utils if needed
if ! command -v htpasswd &> /dev/null; then
    sudo apt-get install -y apache2-utils
fi

# Create directory
mkdir -p /opt/theboosh-zone/nginx

# Create htpasswd file
HTPASSWD_PATH="/opt/theboosh-zone/nginx/.htpasswd"
htpasswd -cb "$HTPASSWD_PATH" "$MONITORING_USER" "$MONITORING_PASSWORD"
chmod 644 "$HTPASSWD_PATH"
echo "Htpasswd file created at $HTPASSWD_PATH"

# Create IP whitelist file
WHITELIST_PATH="/opt/theboosh-zone/nginx/ip-whitelist.conf"
echo "# Auto-generated IP whitelist for monitoring access" > "$WHITELIST_PATH"
echo "# Generated: $(date)" >> "$WHITELIST_PATH"
echo "" >> "$WHITELIST_PATH"

# Add each IP from the space-separated list
for ip in $MONITORING_ALLOWED_IPS; do
    echo "allow $ip;" >> "$WHITELIST_PATH"
done

echo "deny all;" >> "$WHITELIST_PATH"
chmod 644 "$WHITELIST_PATH"

echo "IP whitelist file created at $WHITELIST_PATH"
echo "Allowed IPs: $MONITORING_ALLOWED_IPS"

# =========================================
# Summary
# =========================================
echo ""
echo "========================================="
echo "Monitoring Access Setup Complete!"
echo "========================================="
echo ""
echo "Files created:"
echo "  - $HTPASSWD_PATH"
echo "  - $WHITELIST_PATH"
echo ""
echo "SSL certificates checked for:"
for domain in "${MONITORING_DOMAINS[@]}"; do
    if [ -d "/etc/letsencrypt/live/$domain" ]; then
        echo "  - $domain ✓"
    else
        echo "  - $domain ✗ (missing)"
    fi
done
echo ""
echo "Next: Run ./deploy/deploy.sh $ENVIRONMENT"
