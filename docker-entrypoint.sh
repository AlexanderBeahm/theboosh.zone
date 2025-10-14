#!/bin/bash
set -e

echo "🚀 Starting TheBoosh.Zone application..."

# Function to wait for database to be ready
wait_for_database() {
    echo "⏳ Waiting for database to be ready..."

    # Wait for database connection to be available
    until perl -I/usr/src/hello-perld/lib -MHelloPerld::Database::Postgres -e "HelloPerld::Database::Postgres::validate_connection()" 2>/dev/null; do
        echo "Database is not ready yet, waiting 2 seconds..."
        sleep 2
    done

    echo "✅ Database connection established!"
}

# Function to run database migrations
run_migrations() {
    echo "🔄 Running database migrations..."

    if perl script/migrate; then
        echo "✅ Database migrations completed successfully!"
    else
        echo "❌ Database migrations failed!"
        exit 1
    fi
}

# Function to start the main application
start_application() {
    echo "🌟 Starting TheBoosh.Zone Mojolicious application..."
    exec "$@"
}

# Main startup sequence
echo "📊 TheBoosh.Zone Development Environment"
echo "========================================"

# Wait for database to be ready
wait_for_database

# Run migrations
run_migrations

# Start the main application
start_application "$@"