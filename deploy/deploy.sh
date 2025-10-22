#!/bin/bash
# Deployment script for staging/production

set -e

ENVIRONMENT=${1:-staging}
PROJECT_DIR="/opt/theboosh.zone"

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
