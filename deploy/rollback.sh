#!/bin/bash
# Rollback to previous deployment

set -e

ENVIRONMENT=${1:-staging}
PROJECT_DIR="/opt/theboosh-zone"

echo "========================================="
echo "TheBoosh.Zone Rollback"
echo "Environment: $ENVIRONMENT"
echo "========================================="

cd $PROJECT_DIR

if [ "$ENVIRONMENT" != "staging" ] && [ "$ENVIRONMENT" != "production" ]; then
    echo "Error: Environment must be 'staging' or 'production'"
    exit 1
fi

echo ""
echo "Available images:"
docker images | grep theboosh-zone | head -10

echo ""
read -p "Enter image tag to rollback to (e.g., staging-abc123): " ROLLBACK_TAG

if [ -z "$ROLLBACK_TAG" ]; then
    echo "Error: No tag specified"
    exit 1
fi

# Verify image exists
if ! docker image inspect ghcr.io/alexanderbeahm/theboosh-zone:$ROLLBACK_TAG > /dev/null 2>&1; then
    echo "Error: Image ghcr.io/alexanderbeahm/theboosh-zone:$ROLLBACK_TAG not found"
    echo "Pull it first with: docker pull ghcr.io/alexanderbeahm/theboosh-zone:$ROLLBACK_TAG"
    exit 1
fi

echo ""
echo "Rolling back to: $ROLLBACK_TAG"
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Rollback cancelled"
    exit 0
fi

# Stop current containers
echo "Stopping current containers..."
docker compose -f docker-compose.$ENVIRONMENT.yml down

# Update image tag in environment
export IMAGE_TAG=$ROLLBACK_TAG

# Start with specific image
echo "Starting containers with image: $ROLLBACK_TAG"
docker compose -f docker-compose.$ENVIRONMENT.yml up -d

# Wait for health check
echo ""
echo "Waiting for application to be healthy..."
sleep 10

if curl -f http://localhost:8080/health > /dev/null 2>&1; then
    echo "Rollback successful!"
    echo "Application is healthy"
else
    echo "Warning: Application may not be healthy"
    echo "Check logs: docker compose -f docker-compose.$ENVIRONMENT.yml logs"
fi

echo ""
echo "Rollback complete!"
