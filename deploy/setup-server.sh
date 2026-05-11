#!/bin/bash
# Initial server setup script for staging/production

set -e

ENVIRONMENT=${1:-staging}

echo "========================================="
echo "TheBoosh.Zone Server Setup"
echo "Environment: $ENVIRONMENT"
echo "========================================="

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "Error: Environment must be 'staging' or 'production'"
    exit 1
fi

# Update system
echo "Updating system packages..."
sudo apt-get update
sudo apt-get upgrade -y

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    echo "Docker installed. You may need to log out and back in for group changes to take effect."
else
    echo "Docker already installed: $(docker --version)"
fi

# Install Docker Compose plugin
if ! docker compose version &> /dev/null; then
    echo "Installing Docker Compose plugin..."
    sudo apt-get install -y docker-compose-plugin
else
    echo "Docker Compose already installed: $(docker compose version)"
fi

# Install doctl (DigitalOcean CLI)
if ! command -v doctl &> /dev/null; then
    echo "Installing doctl..."
    cd /tmp
    wget https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz
    tar xf doctl-1.104.0-linux-amd64.tar.gz
    sudo mv doctl /usr/local/bin
    rm doctl-1.104.0-linux-amd64.tar.gz
    cd -
    echo "doctl installed: $(doctl version)"
else
    echo "doctl already installed: $(doctl version)"
fi

# Install certbot for SSL
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt-get install -y certbot
else
    echo "Certbot already installed: $(certbot --version)"
fi

# Stop and disable conflicting web servers
echo "Checking for conflicting web servers on ports 80/443..."
CONFLICTING_SERVICES=("apache2" "nginx" "httpd")
for service in "${CONFLICTING_SERVICES[@]}"; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo "Stopping $service (conflicts with Docker nginx)..."
        sudo systemctl stop $service
        sudo systemctl disable $service
        echo "$service stopped and disabled"
    elif systemctl is-enabled --quiet $service 2>/dev/null; then
        echo "Disabling $service (conflicts with Docker nginx)..."
        sudo systemctl disable $service
        echo "$service disabled"
    fi
done
echo "Port conflict check complete"

# Setup firewall
echo "Configuring firewall..."
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
echo "Firewall configured"

# Create application directory
echo "Creating application directory..."
sudo mkdir -p /opt/theboosh-zone
sudo chown $USER:$USER /opt/theboosh-zone
cd /opt/theboosh-zone

# Create directory structure
mkdir -p deploy
mkdir -p nginx
mkdir -p backups
mkdir -p logs

# Setup log rotation
echo "Configuring log rotation..."
sudo tee /etc/logrotate.d/theboosh-zone > /dev/null <<EOF
/opt/theboosh-zone/logs/*.log {
    daily
    rotate 14
    compress
    delaycompress
    notifempty
    create 0640 $USER $USER
    sharedscripts
    postrotate
        docker compose -f /opt/theboosh-zone/docker-compose.$ENVIRONMENT.yml restart nginx > /dev/null 2>&1 || true
    endscript
}
EOF
echo "Log rotation configured"

# Setup SSL certificates
if [ "$ENVIRONMENT" = "staging" ]; then
    DOMAIN="staging.theboosh.zone"
elif [ "$ENVIRONMENT" = "production" ]; then
    DOMAIN="theboosh.zone"
fi

echo ""
echo "========================================="
echo "SSL Certificate Setup"
echo "========================================="
echo "Domain: $DOMAIN"
echo ""
echo "IMPORTANT: Make sure DNS is pointing to this server before continuing!"
echo "Check with: dig +short $DOMAIN"
echo ""
read -p "Press Enter to continue with SSL certificate generation, or Ctrl+C to abort..."

sudo certbot certonly --standalone -d $DOMAIN --non-interactive --agree-tos -m alexanderbeahm@gmail.com
echo "SSL certificate generated for $DOMAIN"

# Convert renewal config from standalone (used for bootstrap) to webroot,
# so the dockerized certbot service can renew without binding port 80
# (which is owned by the nginx container post-deploy).
echo "Converting renewal config to webroot..."
sudo mkdir -p /var/www/certbot/.well-known/acme-challenge
RENEWAL_CONF=/etc/letsencrypt/renewal/$DOMAIN.conf
sudo sed -i 's|^authenticator = standalone|authenticator = webroot|' "$RENEWAL_CONF"
if ! sudo grep -q "^webroot_path" "$RENEWAL_CONF"; then
    sudo sed -i '/^authenticator = webroot/a webroot_path = /var/www/certbot,' "$RENEWAL_CONF"
fi
if ! sudo grep -q "^\[\[webroot_map\]\]" "$RENEWAL_CONF"; then
    echo "[[webroot_map]]" | sudo tee -a "$RENEWAL_CONF" > /dev/null
    echo "$DOMAIN = /var/www/certbot" | sudo tee -a "$RENEWAL_CONF" > /dev/null
fi
echo "Renewal config converted to webroot"

# Disable host certbot.timer: the docker-compose certbot service owns renewals
# and reloads nginx via deploy-hook. Two renewers on the same lineage conflict.
echo "Disabling host certbot.timer (docker certbot owns renewals)..."
sudo systemctl disable --now certbot.timer 2>/dev/null || true
echo "Host certbot.timer disabled"

echo ""
echo "========================================="
echo "Server Setup Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Clone repository: git clone https://github.com/AlexanderBeahm/theboosh.zone.git /opt/theboosh-zone"
echo "2. Copy environment file: .env.$ENVIRONMENT to server"
echo "3. Copy deployment scripts to deploy/ directory"
echo "4. Run first deployment: ./deploy/deploy.sh $ENVIRONMENT"
echo "5. After Docker containers start, run: sudo ./deploy/configure-docker-firewall.sh"
echo ""
echo "IMPORTANT: After first deployment, you MUST run configure-docker-firewall.sh"
echo "to allow external access to ports 80 and 443 when UFW is enabled."
echo ""
echo "Server is ready for deployment!"
