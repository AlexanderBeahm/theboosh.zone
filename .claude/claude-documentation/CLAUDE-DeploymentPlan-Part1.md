# TheBoosh.Zone - Multi-Environment Deployment Implementation Plan (Part 1)

## Document Purpose
This document outlines the complete plan to transform TheBoosh.Zone from a development-only setup to a production-ready application with proper dev/test/staging/production environments, CI/CD pipeline, and deployment infrastructure.

**This is Part 1 of 2**: Covers Phases 1-5 (Configuration and Infrastructure)
**See Part 2**: Phases 6-10 (CI/CD, Deployment Scripts, Documentation)

## Project Context

**Current State**:
- Perl/Mojolicious backend with Vue 3 SPA frontend
- PostgreSQL database
- Docker-based development environment
- Using `morbo` development server
- Single `.env` file for all configuration
- No CI/CD pipeline
- No production deployment strategy

**Target State**:
- Four environments: Development, Test, Staging, Production
- Production uses hypnotoad server with nginx reverse proxy
- Separate configuration per environment
- GitHub Actions CI/CD pipeline
- Tests run automatically in CI/CD
- Managed PostgreSQL database (DigitalOcean/Azure)
- Deployment to cloud platform (DigitalOcean or Azure)
- Different database schemas for dev/staging/prod on same managed instance
- Separate test database that's ephemeral

**Key Architecture Decisions**:
1. **Backend Production Server**: nginx reverse proxy → hypnotoad (Mojolicious production server)
2. **Frontend Build Strategy**: Separate build artifacts per environment with environment-specific `.env` files
3. **Database Strategy**: Managed PostgreSQL with separate schemas (dev/staging/prod), ephemeral test DB
4. **Secrets Management**: Encrypted environment variables on cloud platform + GitHub Secrets
5. **CI/CD**: GitHub Actions
6. **Deployment Model**: Simple - Single VM/Droplet with nginx + Docker Compose per environment

---

# Implementation Plan - Part 1

## Phase 1: Environment Configuration Files

### 1.1 Backend Perl Configuration Files

Create Mojolicious environment-specific configuration files in `config/` directory:

**File: `config/hello-perld.development.conf`**
```perl
{
    hypnotoad => {
        listen  => ['http://*:3000'],
        workers => 2,
        clients => 100,
        proxy   => 1,
    },
    database => {
        schema => 'thebooshzone_dev',
        host   => $ENV{POSTGRES_HOST} || 'db',
        port   => $ENV{POSTGRES_PORT} || 5432,
        dbname => $ENV{POSTGRES_DB} || 'thebooshzone_dev',
        user   => $ENV{POSTGRES_USER},
        password => $ENV{POSTGRES_PASSWORD},
    },
    logging => {
        level => 'debug',
    },
    session => {
        secret => $ENV{SESSION_SECRET} || 'development-secret-change-me',
        expiration => 86400, # 24 hours
    },
    uploads => {
        dir => $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads',
        max_size => $ENV{UPLOAD_MAX_SIZE} || 5242880,
        allowed_types => [split(',', $ENV{UPLOAD_ALLOWED_TYPES} || 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml')],
    },
}
```

**File: `config/hello-perld.test.conf`**
```perl
{
    hypnotoad => {
        listen  => ['http://*:3000'],
        workers => 1,
        clients => 10,
    },
    database => {
        schema => 'public', # Test uses separate DB, default schema
        host   => $ENV{POSTGRES_HOST} || 'db',
        port   => $ENV{POSTGRES_PORT} || 5432,
        dbname => $ENV{POSTGRES_DB} || 'thebooshzone_test',
        user   => $ENV{POSTGRES_USER},
        password => $ENV{POSTGRES_PASSWORD},
    },
    logging => {
        level => 'error', # Reduce noise in test output
    },
    session => {
        secret => 'test-secret-static',
        expiration => 3600,
    },
    uploads => {
        dir => '/tmp/test-uploads',
        max_size => 1048576, # 1MB for tests
        allowed_types => [qw(image/jpeg image/png)],
    },
}
```

**File: `config/hello-perld.staging.conf`**
```perl
{
    hypnotoad => {
        listen  => ['http://*:8080'],
        workers => 4,
        clients => 100,
        proxy   => 1,
        trusted_proxies => ['10.0.0.0/8', '127.0.0.1', '172.16.0.0/12', '192.168.0.0/16'],
        upgrade_timeout => 180,
        graceful_timeout => 15,
    },
    database => {
        schema => 'thebooshzone_staging',
        host   => $ENV{POSTGRES_HOST}, # Managed database host
        port   => $ENV{POSTGRES_PORT} || 5432,
        dbname => $ENV{POSTGRES_DB},
        user   => $ENV{POSTGRES_USER},
        password => $ENV{POSTGRES_PASSWORD},
    },
    logging => {
        level => 'info',
    },
    session => {
        secret => $ENV{SESSION_SECRET}, # MUST be set in environment
        expiration => 86400,
    },
    uploads => {
        dir => $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads',
        max_size => $ENV{UPLOAD_MAX_SIZE} || 5242880,
        allowed_types => [split(',', $ENV{UPLOAD_ALLOWED_TYPES} || 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml')],
    },
}
```

**File: `config/hello-perld.production.conf`**
```perl
{
    hypnotoad => {
        listen  => ['http://*:8080'],
        workers => 8, # Adjust based on CPU cores (2 per core recommended)
        clients => 100,
        proxy   => 1,
        trusted_proxies => ['10.0.0.0/8', '127.0.0.1', '172.16.0.0/12', '192.168.0.0/16'],
        upgrade_timeout => 180,
        graceful_timeout => 15,
        heartbeat_interval => 5,
        heartbeat_timeout => 20,
    },
    database => {
        schema => 'thebooshzone_prod',
        host   => $ENV{POSTGRES_HOST}, # Managed database host
        port   => $ENV{POSTGRES_PORT} || 5432,
        dbname => $ENV{POSTGRES_DB},
        user   => $ENV{POSTGRES_USER},
        password => $ENV{POSTGRES_PASSWORD},
    },
    logging => {
        level => 'warn', # Only warnings and errors in production
    },
    session => {
        secret => $ENV{SESSION_SECRET}, # MUST be set in environment
        expiration => 86400,
    },
    uploads => {
        dir => $ENV{UPLOADS_DIR} || '/usr/src/hello-perld/uploads',
        max_size => $ENV{UPLOAD_MAX_SIZE} || 5242880,
        allowed_types => [split(',', $ENV{UPLOAD_ALLOWED_TYPES} || 'image/jpeg,image/png,image/gif,image/webp,image/svg+xml')],
    },
}
```

### 1.2 Frontend Vue/Vite Environment Files

Create environment-specific `.env` files in `frontend/` directory:

**File: `frontend/.env.development`**
```env
# Development environment - local Docker setup
VITE_API_URL=http://localhost:3000
VITE_ENVIRONMENT=development
VITE_ENABLE_DEBUG=true
```

**File: `frontend/.env.test`**
```env
# Test environment - CI/CD testing
VITE_API_URL=http://localhost:3000
VITE_ENVIRONMENT=test
VITE_ENABLE_DEBUG=false
```

**File: `frontend/.env.staging`**
```env
# Staging environment - pre-production testing
VITE_API_URL=https://staging.theboosh.zone
VITE_ENVIRONMENT=staging
VITE_ENABLE_DEBUG=true
```

**File: `frontend/.env.production`**
```env
# Production environment
VITE_API_URL=https://theboosh.zone
VITE_ENVIRONMENT=production
VITE_ENABLE_DEBUG=false
```

### 1.3 Docker Environment Files

Rename existing `.env` to `.env.development.example` and create example files for all environments:

**File: `.env.development.example`** (template for developers)
```env
# PostgreSQL Configuration - Development
POSTGRES_DB=thebooshzone_dev
POSTGRES_USER=theboosh_user
POSTGRES_PASSWORD=your_secure_database_password
POSTGRES_HOST=db
POSTGRES_PORT=5432

# Database retry configuration
DB_RETRY_ATTEMPTS=30
DB_RETRY_INTERVAL=5

# Admin User
ADMIN_USERNAME=admin
ADMIN_EMAIL=alexanderbeahm@gmail.com
ADMIN_PASSWORD=your_secure_admin_password

# Session Secret (generate with: openssl rand -hex 32)
SESSION_SECRET=development-secret-change-me

# Media Upload Configuration
UPLOADS_DIR=/usr/src/hello-perld/uploads
UPLOAD_MAX_SIZE=5242880
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml

# Grafana Configuration
GF_SECURITY_ADMIN_USER=admin
GF_SECURITY_ADMIN_PASSWORD=admin_password
GF_DATABASE_NAME=grafana

# Prometheus Configuration
PROMETHEUS_RETENTION_TIME=200h

# Application Environment
APP_ENV=development
NODE_ENV=development
MOJO_MODE=development
```

**File: `.env.test.example`**
```env
# PostgreSQL Configuration - Test (ephemeral)
POSTGRES_DB=thebooshzone_test
POSTGRES_USER=test_user
POSTGRES_PASSWORD=test_password
POSTGRES_HOST=db
POSTGRES_PORT=5432

DB_RETRY_ATTEMPTS=10
DB_RETRY_INTERVAL=2

# Admin User (for auth tests)
ADMIN_USERNAME=admin
ADMIN_EMAIL=test@example.com
ADMIN_PASSWORD=test_password

SESSION_SECRET=test-secret-static

# Test uploads directory (temporary)
UPLOADS_DIR=/tmp/test-uploads
UPLOAD_MAX_SIZE=1048576
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png

APP_ENV=test
NODE_ENV=test
MOJO_MODE=test
```

**File: `.env.staging.example`**
```env
# PostgreSQL Configuration - Staging (Managed Database)
POSTGRES_DB=thebooshzone
POSTGRES_USER=theboosh_staging
POSTGRES_PASSWORD=<ENCRYPTED_OR_FROM_SECRETS>
POSTGRES_HOST=<MANAGED_DB_HOST>
POSTGRES_PORT=5432

DB_RETRY_ATTEMPTS=30
DB_RETRY_INTERVAL=5

# Admin User
ADMIN_USERNAME=admin
ADMIN_EMAIL=alexanderbeahm@gmail.com
ADMIN_PASSWORD=<ENCRYPTED_OR_FROM_SECRETS>

# Session Secret (generate unique per environment)
SESSION_SECRET=<ENCRYPTED_OR_FROM_SECRETS>

# Media Upload Configuration
UPLOADS_DIR=/usr/src/hello-perld/uploads
UPLOAD_MAX_SIZE=5242880
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml

APP_ENV=staging
NODE_ENV=production
MOJO_MODE=staging
```

**File: `.env.production.example`**
```env
# PostgreSQL Configuration - Production (Managed Database)
POSTGRES_DB=thebooshzone
POSTGRES_USER=theboosh_prod
POSTGRES_PASSWORD=<ENCRYPTED_OR_FROM_SECRETS>
POSTGRES_HOST=<MANAGED_DB_HOST>
POSTGRES_PORT=5432

DB_RETRY_ATTEMPTS=30
DB_RETRY_INTERVAL=5

# Admin User
ADMIN_USERNAME=admin
ADMIN_EMAIL=alexanderbeahm@gmail.com
ADMIN_PASSWORD=<ENCRYPTED_OR_FROM_SECRETS>

# Session Secret (generate unique per environment)
SESSION_SECRET=<ENCRYPTED_OR_FROM_SECRETS>

# Media Upload Configuration
UPLOADS_DIR=/usr/src/hello-perld/uploads
UPLOAD_MAX_SIZE=5242880
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml

APP_ENV=production
NODE_ENV=production
MOJO_MODE=production
```

### 1.4 Update .gitignore

Add to `.gitignore`:
```
# Environment files (keep only examples in repo)
.env
.env.local
.env.development
.env.test
.env.staging
.env.production
.env.*.local

# Keep example files
!.env.*.example
```

---

## Phase 2: Backend Production Readiness

### 2.1 Update lib/HelloPerld.pm

Modify the main application file to support environment-specific configuration and hypnotoad:

**Key Changes**:
1. Add Mojolicious::Plugin::Config
2. Load environment-specific config based on `MOJO_MODE`
3. Use configuration values instead of environment variables directly
4. Make session secrets configurable
5. Support database schema parameter

**Code modifications in `lib/HelloPerld.pm`**:

```perl
# Near the top of the file, after version declaration
use Mojolicious::Plugin::Config;

# In the startup() method, add at the beginning:
sub startup {
    my $self = shift;

    # Load environment-specific configuration
    my $mode = $self->mode; # Gets from MOJO_MODE env var or --mode flag
    my $config_file = $self->home->rel_file("config/hello-perld.$mode.conf");
    
    $self->plugin('Config' => {
        file => $config_file,
        default => {}
    });

    $self->log->info("Loading configuration for mode: $mode");
    $self->log->info("Config file: $config_file");

    # Validate production configuration
    if ($mode eq 'production') {
        my $session_secret = $self->config->{session}->{secret};
        die "SESSION_SECRET must be set for production!" 
            if !$session_secret || $session_secret eq 'development-secret-change-me';
        
        die "Database configuration missing for production!"
            unless $self->config->{database}->{host} 
                && $self->config->{database}->{user}
                && $self->config->{database}->{password};
    }

    # Initialize logger
    $self->helper(logger_instance => sub {
        state $logger = HelloPerld::Logger::LoggerFactory->create_default_logger();
        return $logger;
    });

    # Configure template path
    $self->renderer->paths->[0] = 'lib/HelloPerld/Templates';

    # Configure static file serving
    push @{$self->static->paths}, 'lib/HelloPerld/Public';

    # Configure session management from config
    my $session_config = $self->config->{session};
    $self->secrets([$session_config->{secret}]);
    $self->sessions->default_expiration($session_config->{expiration});

    # Rest of startup code remains the same...
    # (keep all existing route definitions, middleware, etc.)
}
```

**Add helper for database config**:
```perl
# Add this helper in startup() after logger_instance helper
$self->helper(db_config => sub {
    my $c = shift;
    return $c->app->config->{database};
});
```

### 2.2 Update Database Connection Logic

Modify `lib/HelloPerld/Database/Postgres.pm` to support schemas:

**Replace `get_connection` method**:
```perl
sub get_connection {
    my ($class, %options) = @_;
    
    # Get config from options or environment
    my $schema = $options{schema} || $ENV{DB_SCHEMA} || 'public';
    my $host = $options{host} || $ENV{POSTGRES_HOST} || 'localhost';
    my $port = $options{port} || $ENV{POSTGRES_PORT} || 5432;
    my $dbname = $options{dbname} || $ENV{POSTGRES_DB} || 'thebooshzone_dev';
    my $user = $options{user} || $ENV{POSTGRES_USER};
    my $password = $options{password} || $ENV{POSTGRES_PASSWORD};

    my $dsn = "DBI:Pg:dbname=$dbname;host=$host;port=$port";
    
    my $dbh = DBI->connect($dsn, $user, $password, {
        RaiseError => 1,
        AutoCommit => 1,
        PrintError => 0,
    }) or die "Could not connect to database: $DBI::errstr";

    # Set schema search path if not public
    if ($schema ne 'public') {
        $dbh->do("SET search_path TO $schema, public");
    }

    return $dbh;
}
```

**Add method to get connection from app config**:
```perl
sub get_connection_from_config {
    my ($class, $config) = @_;
    
    return $class->get_connection(
        schema => $config->{schema},
        host => $config->{host},
        port => $config->{port},
        dbname => $config->{dbname},
        user => $config->{user},
        password => $config->{password},
    );
}
```

### 2.3 Update Model Files to Use App Config

Modify model files to accept database config from controller:

**Example for `lib/HelloPerld/Model/Article.pm`**:

```perl
# Add optional db_config parameter to constructor
sub new {
    my ($class, %args) = @_;
    
    my $self = {
        logger => $args{logger} || HelloPerld::Logger::LoggerFactory->create_default_logger(),
        db_config => $args{db_config} || {}, # New: accept db config
    };
    
    return bless $self, $class;
}

# Update methods to use db_config if provided
sub get_all {
    my ($self, %params) = @_;
    
    my $dbh;
    if ($self->{db_config} && %{$self->{db_config}}) {
        $dbh = HelloPerld::Database::Postgres->get_connection_from_config($self->{db_config});
    } else {
        $dbh = HelloPerld::Database::Postgres->get_connection();
    }
    
    # Rest of method remains the same...
}
```

**Update controllers to pass db_config**:

```perl
# In lib/HelloPerld/Controller/Articles.pm
sub get_all {
    my $c = shift;
    
    my $article_model = HelloPerld::Model::Article->new(
        logger => $c->logger_instance,
        db_config => $c->db_config, # Pass config from app
    );
    
    # Rest of controller method...
}
```

### 2.4 Update Migration System for Schemas

Modify `script/migrate` to support schema parameter:

**Add schema support**:
```perl
#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Getopt::Long;

use HelloPerld::Database::Postgres;
use DBI;

# Parse command-line options
my $schema = $ENV{DB_SCHEMA} || 'public';
my $help = 0;

GetOptions(
    'schema=s' => \$schema,
    'help'     => \$help,
) or die "Invalid options\n";

if ($help) {
    print "Usage: $0 [--schema SCHEMA_NAME]\n";
    print "  --schema  Database schema to run migrations in (default: public)\n";
    exit 0;
}

print "Running migrations for schema: $schema\n";

# Rest of migration logic with schema awareness...
```

### 2.5 Update docker-entrypoint.sh

Update to support different environments and pass schema to migrations:

```bash
#!/bin/bash
set -e

APP_ENV=${APP_ENV:-development}
MOJO_MODE=${MOJO_MODE:-$APP_ENV}
DB_SCHEMA=${DB_SCHEMA:-public}

echo "Starting TheBoosh.Zone application..."
echo "Environment: $APP_ENV"
echo "Mojo Mode: $MOJO_MODE"
echo "DB Schema: $DB_SCHEMA"

# Function to wait for database
wait_for_database() {
    if [ "$APP_ENV" = "test" ]; then
        echo "Test mode: checking for database..."
    fi
    
    local max_attempts="${DB_RETRY_ATTEMPTS:-30}"
    local retry_interval="${DB_RETRY_INTERVAL:-5}"
    local attempt=1

    echo "Waiting for database to be ready..."
    
    while [ $attempt -le $max_attempts ]; do
        echo "Attempt $attempt/$max_attempts: Testing database connection..."

        if perl -I/usr/src/hello-perld/lib -MHelloPerld::Database::Postgres -e "HelloPerld::Database::Postgres::validate_connection()" 2>/dev/null; then
            echo "Database connection established successfully!"
            return 0
        fi

        if [ $attempt -eq $max_attempts ]; then
            echo "FATAL: Database connection failed after $max_attempts attempts"
            exit 1
        fi

        echo "Database not ready, waiting ${retry_interval}s..."
        sleep $retry_interval
        attempt=$((attempt + 1))
    done
}

# Function to run migrations
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

# Main startup sequence
echo "TheBoosh.Zone - Environment: $APP_ENV"
echo "========================================"

validate_production_env
wait_for_database
run_migrations

echo "Starting application with command: $@"
echo "Config file: config/hello-perld.$MOJO_MODE.conf"

exec "$@"
```

### 2.6 Create Multiple Dockerfiles

**File: `Dockerfile.development`** (similar to current)
```dockerfile
# Build stage for frontend
FROM node:lts-alpine AS frontend-builder
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build:dev

# Final stage for Perl application
FROM perl:5.42
WORKDIR /usr/src/hello-perld

# Copy dependency file first for better layer caching
COPY Makefile.PL cpanfile /usr/src/hello-perld/

# Install necessary Perl modules using cpanm
RUN cpanm --installdeps --notest .

# Copy application files
COPY . /usr/src/hello-perld

# Copy built frontend assets from builder stage
COPY --from=frontend-builder /frontend/dist /usr/src/hello-perld/lib/HelloPerld/Public/dist

# Copy and set up entrypoint script
COPY docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

EXPOSE 3000
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["morbo", "./script/hello-perld"]
```

**File: `Dockerfile.production`**
```dockerfile
# Build stage for frontend
FROM node:lts-alpine AS frontend-builder
ARG BUILD_ENV=production
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build:${BUILD_ENV}

# Final stage for Perl application
FROM perl:5.42
WORKDIR /usr/src/hello-perld

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy dependency file first for better layer caching
COPY Makefile.PL cpanfile /usr/src/hello-perld/

# Install Perl modules
RUN cpanm --installdeps --notest .

# Create app user for security (don't run as root)
RUN useradd -m -u 1000 appuser && \
    mkdir -p /usr/src/hello-perld/uploads && \
    chown -R appuser:appuser /usr/src/hello-perld

# Copy application files
COPY --chown=appuser:appuser . /usr/src/hello-perld

# Copy built frontend assets from builder stage
COPY --from=frontend-builder --chown=appuser:appuser /frontend/dist /usr/src/hello-perld/lib/HelloPerld/Public/dist

# Copy and set up entrypoint script
COPY --chown=appuser:appuser docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

USER appuser
EXPOSE 8080

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["hypnotoad", "-f", "./script/hello-perld"]
```

**File: `Dockerfile.test`**
```dockerfile
# Build stage for frontend
FROM node:lts-alpine AS frontend-builder
WORKDIR /frontend
COPY frontend/package*.json ./
RUN npm ci
COPY frontend/ ./
RUN npm run build:test

# Test stage for Perl application
FROM perl:5.42
WORKDIR /usr/src/hello-perld

# Install test dependencies
COPY Makefile.PL cpanfile /usr/src/hello-perld/
RUN cpanm --installdeps .

# Copy application files
COPY . /usr/src/hello-perld

# Copy built frontend
COPY --from=frontend-builder /frontend/dist /usr/src/hello-perld/lib/HelloPerld/Public/dist

# Create test uploads directory
RUN mkdir -p /tmp/test-uploads

EXPOSE 3000

# Run tests by default
CMD ["perl", "script/test"]
```

---

## Phase 3: Frontend Build Process

### 3.1 Update frontend/package.json

Add environment-specific build scripts:

```json
{
  "name": "helloperld-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "build:dev": "vite build --mode development",
    "build:test": "vite build --mode test",
    "build:staging": "vite build --mode staging",
    "build:prod": "vite build --mode production",
    "preview": "vite preview",
    "test": "vitest",
    "test:ci": "vitest run --coverage",
    "test:ui": "vitest --ui",
    "lint": "eslint src --ext .vue,.js",
    "lint:fix": "eslint src --ext .vue,.js --fix"
  },
  "dependencies": {
    "axios": "^1.12.2",
    "highlight.js": "^11.11.1",
    "marked": "^16.4.0",
    "vue": "^3.4.21",
    "vue-router": "^4.3.0"
  },
  "devDependencies": {
    "@vitejs/plugin-vue": "^5.0.4",
    "@vitest/coverage-v8": "^3.2.4",
    "@vue/test-utils": "^2.4.6",
    "eslint": "^9.36.0",
    "eslint-plugin-vue": "^10.5.0",
    "happy-dom": "^19.0.2",
    "jsdom": "^27.0.0",
    "terser": "^5.44.0",
    "vite": "^5.1.6",
    "vitest": "^3.2.4"
  }
}
```

### 3.2 Update frontend/vite.config.js

Add environment-aware configuration:

```javascript
import { defineConfig, loadEnv } from 'vite'
import vue from '@vitejs/plugin-vue'
import path from 'path'

export default defineConfig(({ mode }) => {
  // Load env file based on `mode` in the current working directory.
  const env = loadEnv(mode, process.cwd(), '')
  
  const isProduction = mode === 'production'
  const isTest = mode === 'test'

  console.log(`Building for mode: ${mode}`)
  console.log(`API URL: ${env.VITE_API_URL}`)

  return {
    plugins: [vue()],

    base: '/dist/',

    build: {
      outDir: '../lib/HelloPerld/Public/dist',
      emptyOutDir: true,
      
      // Source maps only in development/staging
      sourcemap: !isProduction,
      
      // Production optimizations
      minify: isProduction ? 'terser' : 'esbuild',
      
      terserOptions: isProduction ? {
        compress: {
          drop_console: true,
          drop_debugger: true,
        }
      } : {},

      rollupOptions: {
        output: {
          manualChunks: isProduction ? {
            'vendor': ['vue', 'vue-router'],
            'markdown': ['marked', 'highlight.js'],
          } : undefined,
        }
      },

      // Chunk size warnings
      chunkSizeWarningLimit: 1000,
    },

    server: {
      port: 5173,
      proxy: {
        '/api': {
          target: env.VITE_API_URL || 'http://localhost:3000',
          changeOrigin: true
        },
        '/swagger': {
          target: env.VITE_API_URL || 'http://localhost:3000',
          changeOrigin: true
        },
        '/swagger.json': {
          target: env.VITE_API_URL || 'http://localhost:3000',
          changeOrigin: true
        }
      }
    },

    resolve: {
      alias: {
        '@': path.resolve(__dirname, './src')
      }
    },

    // Test configuration
    test: {
      globals: true,
      environment: 'happy-dom',
      coverage: {
        provider: 'v8',
        reporter: ['text', 'json', 'html'],
      }
    }
  }
})
```

### 3.3 Create Frontend Config Module

**File: `frontend/src/config.js`** (new file)
```javascript
// Environment configuration
export const config = {
  apiUrl: import.meta.env.VITE_API_URL || 'http://localhost:3000',
  environment: import.meta.env.VITE_ENVIRONMENT || 'development',
  isDevelopment: import.meta.env.VITE_ENVIRONMENT === 'development',
  isProduction: import.meta.env.VITE_ENVIRONMENT === 'production',
  enableDebug: import.meta.env.VITE_ENABLE_DEBUG === 'true',
}

// Log configuration in non-production
if (!config.isProduction) {
  console.log('App Configuration:', config)
}
```

### 3.4 Update Axios Configuration (if centralized)

**File: `frontend/src/api/client.js`** (create or update)
```javascript
import axios from 'axios'
import { config } from '@/config'

const apiClient = axios.create({
  baseURL: config.apiUrl,
  withCredentials: true,
  headers: {
    'Content-Type': 'application/json',
  },
})

// Add debug logging in development
if (config.enableDebug) {
  apiClient.interceptors.request.use(request => {
    console.log('[API Request]', request.method.toUpperCase(), request.url)
    return request
  })

  apiClient.interceptors.response.use(
    response => {
      console.log('[API Response]', response.status, response.config.url)
      return response
    },
    error => {
      console.error('[API Error]', error.response?.status, error.config?.url)
      return Promise.reject(error)
    }
  )
}

export default apiClient
```

---

## Phase 4: Docker Compose Configurations

### 4.1 docker-compose.yml (Development)

Update existing file to be explicitly for development:

```yaml
# docker-compose.yml - Development Environment
services:
  hello-perld:
    build:
      context: .
      dockerfile: Dockerfile.development
    ports:
      - "3000:3000"
    env_file:
      - .env.development
    environment:
      POSTGRES_HOST: db
      APP_ENV: development
      MOJO_MODE: development
      NODE_ENV: development
      DB_SCHEMA: public
    volumes:
      - uploads_data:/usr/src/hello-perld/uploads
    develop:
      watch:
        - action: sync+restart
          path: ./lib
          target: /usr/src/hello-perld/lib
        - action: sync+restart
          path: ./script
          target: /usr/src/hello-perld/script
        - action: rebuild
          path: ./frontend
    depends_on:
      db:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  db:
    image: postgres:15
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

  prometheus:
    build:
      context: .
      dockerfile: Dockerfile.prometheus
    ports:
      - "9090:9090"
    volumes:
      - prometheus_data:/prometheus
    depends_on:
      - hello-perld

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus

  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:latest
    environment:
      DATA_SOURCE_NAME: "postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@db:5432/${POSTGRES_DB}?sslmode=disable"
    ports:
      - "9187:9187"
    depends_on:
      - db

  node-exporter:
    image: prom/node-exporter:latest
    ports:
      - "9100:9100"
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'

volumes:
  postgres_data:
  prometheus_data:
  grafana_data:
  uploads_data:
```

### 4.2 docker-compose.test.yml (CI/CD Testing)

Create new file:

```yaml
# docker-compose.test.yml - Test Environment (CI/CD)
services:
  test-db:
    image: postgres:15
    environment:
      POSTGRES_USER: test_user
      POSTGRES_PASSWORD: test_password
      POSTGRES_DB: thebooshzone_test
    tmpfs:
      - /var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U test_user -d thebooshzone_test"]
      interval: 5s
      timeout: 5s
      retries: 5

  test-app:
    build:
      context: .
      dockerfile: Dockerfile.test
    env_file:
      - .env.test
    environment:
      POSTGRES_HOST: test-db
      APP_ENV: test
      MOJO_MODE: test
      NODE_ENV: test
      DB_SCHEMA: public
    depends_on:
      test-db:
        condition: service_healthy
    command: ["perl", "script/test"]
```

### 4.3 docker-compose.staging.yml

Create new file:

```yaml
# docker-compose.staging.yml - Staging Environment
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.production
      args:
        BUILD_ENV: staging
    image: ghcr.io/alexanderbeahm/theboosh-zone:staging-latest
    ports:
      - "8080:8080"
    env_file:
      - .env.staging
    environment:
      APP_ENV: staging
      MOJO_MODE: staging
      NODE_ENV: production
      DB_SCHEMA: thebooshzone_staging
    volumes:
      - uploads_data:/usr/src/hello-perld/uploads
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 1G
        reservations:
          memory: 512M

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/staging.conf:/etc/nginx/conf.d/default.conf:ro
      - uploads_data:/usr/share/nginx/html/uploads:ro
      - letsencrypt:/etc/letsencrypt:ro
      - letsencrypt-www:/var/www/certbot:ro
    depends_on:
      - app
    restart: unless-stopped

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=200h'
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: unless-stopped

volumes:
  uploads_data:
  prometheus_data:
  grafana_data:
  letsencrypt:
  letsencrypt-www:
```

### 4.4 docker-compose.production.yml

Create new file:

```yaml
# docker-compose.production.yml - Production Environment
services:
  app:
    build:
      context: .
      dockerfile: Dockerfile.production
      args:
        BUILD_ENV: production
    image: ghcr.io/alexanderbeahm/theboosh-zone:production-latest
    ports:
      - "8080:8080"
    env_file:
      - .env.production
    environment:
      APP_ENV: production
      MOJO_MODE: production
      NODE_ENV: production
      DB_SCHEMA: thebooshzone_prod
    volumes:
      - uploads_data:/usr/src/hello-perld/uploads
    restart: always
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/health/ready"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2'
        reservations:
          memory: 1G
          cpus: '1'
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/production.conf:/etc/nginx/conf.d/default.conf:ro
      - uploads_data:/usr/share/nginx/html/uploads:ro
      - letsencrypt:/etc/letsencrypt:ro
      - letsencrypt-www:/var/www/certbot:ro
    depends_on:
      - app
    restart: always
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"

  certbot:
    image: certbot/certbot
    volumes:
      - letsencrypt:/etc/letsencrypt
      - letsencrypt-www:/var/www/certbot
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"

  prometheus:
    image: prom/prometheus:latest
    ports:
      - "127.0.0.1:9090:9090"
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.retention.time=200h'
    restart: always

  grafana:
    image: grafana/grafana:latest
    ports:
      - "127.0.0.1:3001:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=${GF_SECURITY_ADMIN_USER}
      - GF_SECURITY_ADMIN_PASSWORD=${GF_SECURITY_ADMIN_PASSWORD}
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=https://monitoring.theboosh.zone
    volumes:
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus
    restart: always

volumes:
  uploads_data:
  prometheus_data:
  grafana_data:
  letsencrypt:
  letsencrypt-www:
```

---

## Phase 5: nginx Reverse Proxy Configuration

### 5.1 Create nginx Directory Structure

```bash
mkdir -p nginx
```

### 5.2 Create nginx/nginx.conf (Base Configuration)

**File: `nginx/nginx.conf`**
```nginx
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 10M;

    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript 
               application/json application/javascript application/xml+rss 
               application/rss+xml font/truetype font/opentype 
               application/vnd.ms-fontobject image/svg+xml;

    # Security headers (applied to all virtual hosts)
    add_header X-Frame-Options "DENY" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Rate limiting zones
    limit_req_zone $binary_remote_addr zone=api_limit:10m rate=10r/s;
    limit_req_zone $binary_remote_addr zone=auth_limit:10m rate=5r/m;

    # Include virtual host configs
    include /etc/nginx/conf.d/*.conf;
}
```

### 5.3 Create nginx/staging.conf

**File: `nginx/staging.conf`**
```nginx
upstream app_backend {
    server app:8080 fail_timeout=10s max_fails=3;
    keepalive 32;
}

server {
    listen 80;
    server_name staging.theboosh.zone;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name staging.theboosh.zone;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/staging.theboosh.zone/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/staging.theboosh.zone/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Root directory for static files
    root /usr/share/nginx/html;

    # Serve uploaded media files directly from nginx
    location /uploads/ {
        alias /usr/share/nginx/html/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Serve frontend static assets
    location /dist/ {
        proxy_pass http://app_backend;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        # Disable buffering for streaming responses
        proxy_buffering off;
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Auth endpoints with stricter rate limiting
    location /api/auth/ {
        limit_req zone=auth_limit burst=3 nodelay;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint (no rate limit)
    location /health {
        proxy_pass http://app_backend;
        access_log off;
    }

    # Swagger documentation
    location /swagger {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    location /swagger.json {
        proxy_pass http://app_backend;
        expires 1h;
    }

    # All other requests go to Vue.js SPA
    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
    }

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
```

### 5.4 Create nginx/production.conf

**File: `nginx/production.conf`**
```nginx
upstream app_backend {
    server app:8080 fail_timeout=10s max_fails=3;
    keepalive 32;
}

server {
    listen 80;
    server_name theboosh.zone www.theboosh.zone;

    # Redirect HTTP to HTTPS
    return 301 https://theboosh.zone$request_uri;
}

server {
    listen 443 ssl http2;
    server_name www.theboosh.zone;

    # Redirect www to non-www
    return 301 https://theboosh.zone$request_uri;
}

server {
    listen 443 ssl http2;
    server_name theboosh.zone;

    # SSL configuration
    ssl_certificate /etc/letsencrypt/live/theboosh.zone/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/theboosh.zone/privkey.pem;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers off;
    
    # HSTS (enable after testing)
    # add_header Strict-Transport-Security "max-age=63072000" always;

    # Root directory for static files
    root /usr/share/nginx/html;

    # Serve uploaded media files directly from nginx
    location /uploads/ {
        alias /usr/share/nginx/html/uploads/;
        expires 30d;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # Serve frontend static assets with aggressive caching
    location /dist/ {
        proxy_pass http://app_backend;
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # API endpoints with rate limiting
    location /api/ {
        limit_req zone=api_limit burst=20 nodelay;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
        
        proxy_buffering off;
        
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }

    # Auth endpoints with stricter rate limiting
    location /api/auth/ {
        limit_req zone=auth_limit burst=3 nodelay;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Health check endpoint
    location /health {
        proxy_pass http://app_backend;
        access_log off;
    }

    # Swagger documentation (consider removing in production)
    location /swagger {
        # Uncomment to require basic auth for Swagger in production
        # auth_basic "Restricted";
        # auth_basic_user_file /etc/nginx/.htpasswd;
        
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
    }

    location /swagger.json {
        proxy_pass http://app_backend;
        expires 1h;
    }

    # All other requests go to Vue.js SPA
    location / {
        proxy_pass http://app_backend;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header Connection "";
    }

    # Let's Encrypt challenge
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    # Deny access to hidden files
    location ~ /\. {
        deny all;
        access_log off;
        log_not_found off;
    }
}
```

---

## Next Steps

**Continue to Part 2** of this deployment plan, which covers:
- Phase 6: GitHub Actions CI/CD Pipeline
- Phase 7: Deployment Scripts & Server Setup
- Phase 8: Documentation Updates
- Phase 9: Manual Infrastructure Steps
- Phase 10: Testing & Validation

See `CLAUDE-DeploymentPlan-Part2.md` for the remaining phases.

---

*Document created: October 2025*
*For: Alex Beahm (@AlexanderBeahm)*
*Project: TheBoosh.Zone*
*Part 1 of 2*
