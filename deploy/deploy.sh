#!/bin/bash
# Deployment script for staging/production

set -e

ENVIRONMENT=${1:-staging}
PROJECT_DIR="/opt/theboosh-zone"

echo "========================================="
echo "TheBoosh.Zone Deployment"
echo "Environment: $ENVIRONMENT"
echo "========================================="

cd $PROJECT_DIR

# Validate environment
if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "Error: Environment must be 'staging' or 'production'"
    exit 1
fi

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    export $(cat .env.$ENVIRONMENT | grep -v '^#' | xargs)
    echo "Loaded environment variables from .env.$ENVIRONMENT"
else
    echo "Error: .env.$ENVIRONMENT file not found!"
    exit 1
fi

# Check if docker-compose file exists
if [ ! -f "docker-compose.$ENVIRONMENT.yml" ]; then
    echo "Error: docker-compose.$ENVIRONMENT.yml not found!"
    exit 1
fi

# Check for port conflicts only if no containers are currently running
# (prevents false positives on re-deployments)
echo ""
RUNNING_CONTAINERS=$(docker compose -f docker-compose.$ENVIRONMENT.yml ps -q 2>/dev/null | wc -l)

if [ "$RUNNING_CONTAINERS" -eq 0 ]; then
    echo "First deployment or clean state detected. Checking for port conflicts..."
    PORT_80_IN_USE=$(sudo ss -tulpn | grep ':80 ' | grep -v docker || true)
    PORT_443_IN_USE=$(sudo ss -tulpn | grep ':443 ' | grep -v docker || true)

    if [ ! -z "$PORT_80_IN_USE" ] || [ ! -z "$PORT_443_IN_USE" ]; then
        echo "ERROR: Ports 80 or 443 are in use by non-Docker processes:"
        [ ! -z "$PORT_80_IN_USE" ] && echo "  Port 80: $PORT_80_IN_USE"
        [ ! -z "$PORT_443_IN_USE" ] && echo "  Port 443: $PORT_443_IN_USE"
        echo ""
        echo "Common culprits: Apache (apache2), Nginx (nginx), or other web servers"
        echo "To fix, stop the conflicting service:"
        echo "  sudo systemctl stop apache2 && sudo systemctl disable apache2"
        echo "  sudo systemctl stop nginx && sudo systemctl disable nginx"

        # Check if running in non-interactive mode (CI/CD)
        if [ ! -t 0 ] || [ "$CI" = "true" ]; then
            echo ""
            echo "Running in automated mode. Deployment aborted due to port conflict."
            exit 1
        fi

        # Interactive mode: prompt user to continue or abort
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Deployment aborted. Please resolve port conflicts first."
            exit 1
        fi
    else
        echo "No port conflicts detected. Proceeding with deployment."
    fi
else
    echo "Re-deployment detected (${RUNNING_CONTAINERS} containers running). Skipping port conflict check."
fi

# Stop existing containers and clean up networks
echo ""
echo "Stopping existing containers..."
docker compose -f docker-compose.$ENVIRONMENT.yml down --remove-orphans 2>/dev/null || true

# Clean up stale Docker networks
echo ""
echo "Cleaning up stale Docker networks..."
docker network prune -f

# Check Node.js and install dependencies for CSP generation
echo ""
echo "Checking Node.js dependencies for CSP generation..."
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed on deployment server!"
    echo "Please install Node.js: curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - && sudo apt-get install -y nodejs"
    exit 1
fi

# Install Node.js dependencies for CSP generation script
if [ ! -d "node_modules" ] || [ ! -f "node_modules/ajv/package.json" ]; then
    echo "Installing Node.js dependencies for CSP generation..."
    npm install ajv ajv-formats || {
        echo "Error: Failed to install CSP generation dependencies!"
        echo "Please ensure npm is working and try manually: npm install ajv ajv-formats"
        exit 1
    }
fi

# Generate CSP configuration files
echo ""
echo "Generating CSP configuration files..."
node script/generate-csp-configs || {
    echo "Error: Failed to generate CSP configuration files!"
    echo "This is required for nginx and backend CSP headers."
    exit 1
}

# Pull latest images
echo ""
echo "Pulling latest Docker images..."
docker compose -f docker-compose.$ENVIRONMENT.yml pull

# Run database migrations
echo ""
echo "Running database migrations..."
docker compose -f docker-compose.$ENVIRONMENT.yml run --rm app perl script/migrate || {
    echo "Warning: Database migrations failed. Continuing anyway..."
}

# Deploy new version
echo ""
echo "Deploying new version..."
docker compose -f docker-compose.$ENVIRONMENT.yml up -d --remove-orphans

# Wait for application to be ready
echo ""
echo "Waiting for application to be healthy..."
MAX_ATTEMPTS=30
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
    if curl -f http://localhost:8080/health > /dev/null 2>&1; then
        echo "Application is healthy!"
        break
    fi

    if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
        echo "Application failed to become healthy!"
        echo "Check logs with: docker compose -f docker-compose.$ENVIRONMENT.yml logs"
        echo ""
        echo "Rolling back..."
        docker compose -f docker-compose.$ENVIRONMENT.yml down
        exit 1
    fi

    echo "Attempt $ATTEMPT/$MAX_ATTEMPTS - waiting..."
    sleep 5
    ATTEMPT=$((ATTEMPT + 1))
done

# Verify firewall rules for external access
echo ""
echo "Verifying firewall configuration..."
if ! iptables -L DOCKER-USER -n | grep -q "tcp dpt:443.*ACCEPT"; then
    echo "WARNING: Firewall rules for port 443 not found!"
    echo "External HTTPS access may not work."
    echo "Run: sudo ./deploy/configure-docker-firewall.sh"
elif ! iptables -L DOCKER-USER -n | grep -q "tcp dpt:80.*ACCEPT"; then
    echo "WARNING: Firewall rules for port 80 not found!"
    echo "External HTTP access may not work."
    echo "Run: sudo ./deploy/configure-docker-firewall.sh"
else
    echo "Firewall rules OK - ports 80 and 443 are accessible"
fi

# Cleanup old images
echo ""
echo "Cleaning up old Docker images..."
docker image prune -f

# Show running containers
echo ""
echo "Running containers:"
docker compose -f docker-compose.$ENVIRONMENT.yml ps

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
if [ "$ENVIRONMENT" = "staging" ]; then
    echo "Application URL: https://staging.theboosh.zone"
elif [ "$ENVIRONMENT" = "production" ]; then
    echo "Application URL: https://theboosh.zone"
fi
echo ""
echo "View logs: docker compose -f docker-compose.$ENVIRONMENT.yml logs -f"
