#!/bin/bash
set -e

APP_ENV=${APP_ENV:-development}
MOJO_MODE=${MOJO_MODE:-$APP_ENV}
DB_SCHEMA=${DB_SCHEMA:-public}

echo "Starting TheBoosh.Zone application..."
echo "Environment: $APP_ENV"
echo "Mojo Mode: $MOJO_MODE"
echo "DB Schema: $DB_SCHEMA"

# Function to wait for database to be ready with intelligent retry logic
wait_for_database() {
    if [ "$APP_ENV" = "test" ]; then
        echo "Test mode: checking for database..."
    fi

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

# Function to validate production environment
validate_production_env() {
    if [ "$APP_ENV" != "production" ] && [ "$APP_ENV" != "staging" ]; then
        return 0
    fi

    echo "Validating $APP_ENV environment variables..."

    local required_vars=(
        "POSTGRES_HOST"
        "POSTGRES_DB"
        "POSTGRES_USER"
        "POSTGRES_PASSWORD"
        "SESSION_SECRET"
        "ADMIN_USERNAME"
        "ADMIN_PASSWORD"
    )

    local missing_vars=()

    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            missing_vars+=("$var")
        fi
    done

    if [ ${#missing_vars[@]} -ne 0 ]; then
        echo "FATAL: Missing required environment variables for $APP_ENV:"
        printf '  - %s\n' "${missing_vars[@]}"
        exit 1
    fi

    # Validate session secret is not default
    if [ "$SESSION_SECRET" = "development-secret-change-me" ]; then
        echo "FATAL: SESSION_SECRET cannot be the default value in $APP_ENV"
        exit 1
    fi

    echo "$APP_ENV environment validation passed!"
}

# Function to run database migrations
run_migrations() {
    if [ "$APP_ENV" = "test" ]; then
        echo "Test mode: skipping automatic migrations (tests will handle this)"
        return 0
    fi

    echo "Running database migrations for $APP_ENV environment (schema: $DB_SCHEMA)..."

    # Export schema for migration script
    export DB_SCHEMA=$DB_SCHEMA

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
    echo "Starting application with command: $@"
    echo "Config file: config/hello-perld.$MOJO_MODE.conf"
    exec "$@"
}

# Main startup sequence
echo "TheBoosh.Zone - Environment: $APP_ENV"
echo "========================================"

# Validate production environment
validate_production_env

# Wait for database to be ready
wait_for_database

# Run migrations
run_migrations

# Start the main application
start_application "$@"
