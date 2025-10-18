#!/bin/bash
set -e

echo "Starting TheBoosh.Zone application..."

# Function to wait for database to be ready with intelligent retry logic
wait_for_database() {
    local max_attempts="${DB_RETRY_ATTEMPTS:-30}"
    local retry_interval="${DB_RETRY_INTERVAL:-5}"
    local attempt=1

    echo "Waiting for database to be ready..."
    echo "Configuration: max_attempts=${max_attempts}, retry_interval=${retry_interval}s"

    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Testing database connection..."

        if perl -I/usr/src/hello-perld/lib -MHelloPerld::Database::Postgres -e "HelloPerld::Database::Postgres::validate_connection()" 2>/dev/null; then
            echo "Database connection established successfully!"
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            echo "FATAL: Database connection failed after $max_attempts attempts ($(($max_attempts * $retry_interval)) seconds total)"
            echo "Please check:"
            echo "  1. Database service is running"
            echo "  2. Database credentials are correct"
            echo "  3. Network connectivity between containers"
            exit 1
        fi

        echo "Database not ready, waiting ${retry_interval}s before retry..."
        sleep $retry_interval
        attempt=$((attempt + 1))
    done
}

# Function to run database migrations
run_migrations() {
    echo "Running database migrations..."

    if perl script/migrate; then
        echo "Database migrations completed successfully!"
    else
        echo "Database migrations failed!"
        exit 1
    fi
}

# Function to start the main application
start_application() {
    echo "Starting TheBoosh.Zone Mojolicious application..."
    exec "$@"
}

# Main startup sequence
echo "TheBoosh.Zone Development Environment"
echo "========================================"

# Wait for database to be ready
wait_for_database

# Run migrations
run_migrations

# Start the main application
start_application "$@"
