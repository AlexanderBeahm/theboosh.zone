#!/bin/bash
# Backup database before deployment

set -e

ENVIRONMENT=${1:-staging}
BACKUP_DIR="/opt/theboosh-zone/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo "========================================="
echo "TheBoosh.Zone Database Backup"
echo "Environment: $ENVIRONMENT"
echo "========================================="

mkdir -p $BACKUP_DIR

echo "Creating backup for $ENVIRONMENT..."

# Load database credentials
if [ -f ".env.$ENVIRONMENT" ]; then
    export $(cat .env.$ENVIRONMENT | grep -v '^#' | xargs)
else
    echo "Error: .env.$ENVIRONMENT file not found!"
    exit 1
fi

# Determine schema based on environment
if [ "$ENVIRONMENT" = "production" ]; then
    SCHEMA="thebooshzone_prod"
elif [ "$ENVIRONMENT" = "staging" ]; then
    SCHEMA="thebooshzone_staging"
else
    SCHEMA="thebooshzone_dev"
fi

# Backup database using pg_dump
BACKUP_FILE="$BACKUP_DIR/backup_${ENVIRONMENT}_${TIMESTAMP}.sql.gz"

echo "Backing up schema: $SCHEMA"
echo "Backup file: $BACKUP_FILE"

PGPASSWORD=$POSTGRES_PASSWORD pg_dump \
    -h $POSTGRES_HOST \
    -U $POSTGRES_USER \
    -d $POSTGRES_DB \
    --schema=$SCHEMA \
    --no-owner \
    --no-acl \
    | gzip > $BACKUP_FILE

if [ $? -eq 0 ]; then
    BACKUP_SIZE=$(du -h $BACKUP_FILE | cut -f1)
    echo "Backup created successfully: $BACKUP_FILE ($BACKUP_SIZE)"
else
    echo "Error: Backup failed!"
    exit 1
fi

# Keep only last 30 days of backups
echo "Cleaning up old backups (keeping last 30 days)..."
find $BACKUP_DIR -name "backup_${ENVIRONMENT}_*.sql.gz" -mtime +30 -delete

# List recent backups
echo ""
echo "Recent backups for $ENVIRONMENT:"
ls -lh $BACKUP_DIR/backup_${ENVIRONMENT}_*.sql.gz 2>/dev/null | tail -5 || echo "No backups found"

echo ""
echo "Backup complete!"
