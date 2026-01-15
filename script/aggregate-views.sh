#!/bin/bash
# Aggregate article view counts into permanent storage
# Called by cron every hour

set -e

# Log with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Check required environment variables
if [ -z "$POSTGRES_HOST" ] || [ -z "$POSTGRES_USER" ] || [ -z "$POSTGRES_PASSWORD" ] || [ -z "$POSTGRES_DB" ]; then
    log "ERROR: Missing required environment variables (POSTGRES_HOST, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_DB)"
    exit 1
fi

# Set schema if provided
SCHEMA_OPTION=""
if [ -n "$DB_SCHEMA" ] && [ "$DB_SCHEMA" != "public" ]; then
    SCHEMA_OPTION="-c search_path=$DB_SCHEMA,public"
fi

log "Starting article view count aggregation..."

# Run the aggregation function and capture the result
RESULT=$(PGPASSWORD="$POSTGRES_PASSWORD" psql \
    -h "$POSTGRES_HOST" \
    -U "$POSTGRES_USER" \
    -d "$POSTGRES_DB" \
    $SCHEMA_OPTION \
    -t -A \
    -c "SELECT aggregate_article_view_counts();" 2>&1)

if [ $? -eq 0 ]; then
    log "Aggregation complete. Processed $RESULT new views."
else
    log "ERROR: Aggregation failed: $RESULT"
    exit 1
fi
