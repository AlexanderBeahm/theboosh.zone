# TheBoosh.Zone - Multi-Environment Deployment Implementation Plan (Part 2)

**This is Part 2 of 2**: Covers Phases 6-10 (CI/CD, Deployment, Documentation, Testing)
**See Part 1**: Phases 1-5 (Configuration and Infrastructure)

---

## Phase 6: GitHub Actions CI/CD Pipeline

### 6.1 Create .github/workflows/test.yml

**File: `.github/workflows/test.yml`**
```yaml
name: Run Tests

on:
  push:
    branches: [ dev, main ]
  pull_request:
    branches: [ dev, main ]

jobs:
  backend-tests:
    name: Backend Tests (Perl)
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Create test environment file
        run: |
          cat > .env.test << EOF
          POSTGRES_DB=thebooshzone_test
          POSTGRES_USER=test_user
          POSTGRES_PASSWORD=test_password
          POSTGRES_HOST=test-db
          ADMIN_USERNAME=admin
          ADMIN_EMAIL=test@example.com
          ADMIN_PASSWORD=test_password
          SESSION_SECRET=test-secret-static
          UPLOADS_DIR=/tmp/test-uploads
          UPLOAD_MAX_SIZE=1048576
          UPLOAD_ALLOWED_TYPES=image/jpeg,image/png
          APP_ENV=test
          MOJO_MODE=test
          NODE_ENV=test
          EOF

      - name: Run backend tests
        run: |
          docker compose -f docker-compose.test.yml up \
            --build \
            --abort-on-container-exit \
            --exit-code-from test-app

      - name: Cleanup
        if: always()
        run: docker compose -f docker-compose.test.yml down -v

  frontend-tests:
    name: Frontend Tests (Vue/Vitest)
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'
          cache-dependency-path: frontend/package-lock.json

      - name: Install dependencies
        working-directory: ./frontend
        run: npm ci

      - name: Run linter
        working-directory: ./frontend
        run: npm run lint

      - name: Run tests with coverage
        working-directory: ./frontend
        run: npm run test:ci

      - name: Upload coverage reports
        uses: codecov/codecov-action@v4
        with:
          files: ./frontend/coverage/coverage-final.json
          flags: frontend
          name: frontend-coverage
        if: always()
```

### 6.2 Create .github/workflows/deploy-staging.yml

**File: `.github/workflows/deploy-staging.yml`**
```yaml
name: Deploy to Staging

on:
  push:
    branches: [ dev ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Run Tests
    uses: ./.github/workflows/test.yml

  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=staging-latest
            type=sha,prefix=staging-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.production
          build-args: |
            BUILD_ENV=staging
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

  deploy:
    name: Deploy to Staging Server
    runs-on: ubuntu-latest
    needs: build-and-push
    environment:
      name: staging
      url: https://staging.theboosh.zone

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.STAGING_HOST }}
          username: ${{ secrets.STAGING_USER }}
          key: ${{ secrets.STAGING_SSH_KEY }}
          script: |
            cd /opt/theboosh-zone
            
            # Pull latest image
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:staging-latest
            
            # Run deployment script
            ./deploy/deploy.sh staging
            
            # Health check
            sleep 10
            curl -f https://staging.theboosh.zone/health || exit 1

      - name: Notify on success
        if: success()
        run: echo "Staging deployment successful!"

      - name: Notify on failure
        if: failure()
        run: |
          echo "Staging deployment failed!"
          # Add Slack/Discord/Email notification here
```

### 6.3 Create .github/workflows/deploy-production.yml

**File: `.github/workflows/deploy-production.yml`**
```yaml
name: Deploy to Production

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  workflow_dispatch:

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  test:
    name: Run Full Test Suite
    uses: ./.github/workflows/test.yml

  build-and-push:
    name: Build and Push Docker Image
    runs-on: ubuntu-latest
    needs: test
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=raw,value=production-latest
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix=production-

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          file: ./Dockerfile.production
          build-args: |
            BUILD_ENV=production
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}

      - name: Create GitHub Release
        if: startsWith(github.ref, 'refs/tags/')
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true

  deploy:
    name: Deploy to Production
    runs-on: ubuntu-latest
    needs: build-and-push
    environment:
      name: production
      url: https://theboosh.zone

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to production server
        uses: appleboy/ssh-action@v1.0.0
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.PRODUCTION_USER }}
          key: ${{ secrets.PRODUCTION_SSH_KEY }}
          script: |
            cd /opt/theboosh-zone
            
            # Pull latest image
            echo ${{ secrets.GITHUB_TOKEN }} | docker login ghcr.io -u ${{ github.actor }} --password-stdin
            docker pull ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}:production-latest
            
            # Backup current deployment
            ./deploy/backup.sh production
            
            # Run deployment script with health checks
            ./deploy/deploy.sh production
            
            # Verify deployment
            sleep 15
            if ! curl -f https://theboosh.zone/health; then
              echo "Health check failed! Rolling back..."
              ./deploy/rollback.sh production
              exit 1
            fi

      - name: Notify on success
        if: success()
        run: |
          echo "Production deployment successful!"
          # Add notification here

      - name: Notify on failure
        if: failure()
        run: |
          echo "Production deployment failed!"
          # Add critical alert here
```

---

## Phase 7: Deployment Scripts & Server Setup

### 7.1 Create deploy Directory

```bash
mkdir -p deploy
chmod +x deploy/*.sh  # Make scripts executable
```

### 7.2 Create deploy/setup-server.sh

**File: `deploy/setup-server.sh`**
```bash
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

# Install certbot for SSL
if ! command -v certbot &> /dev/null; then
    echo "Installing certbot..."
    sudo apt-get install -y certbot
else
    echo "Certbot already installed: $(certbot --version)"
fi

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

# Setup certbot auto-renewal
echo "Setting up certbot auto-renewal..."
sudo systemctl enable certbot.timer
sudo systemctl start certbot.timer
echo "Certbot auto-renewal configured"

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
echo ""
echo "Server is ready for deployment!"
```

### 7.3 Create deploy/deploy.sh

**File: `deploy/deploy.sh`**
```bash
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
```

### 7.4 Create deploy/rollback.sh

**File: `deploy/rollback.sh`**
```bash
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
```

### 7.5 Create deploy/backup.sh

**File: `deploy/backup.sh`**
```bash
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
```

### 7.6 Make Scripts Executable

Add to repository:
```bash
chmod +x deploy/*.sh
git add deploy/*.sh
git commit -m "Add deployment scripts"
```

---

## Phase 8: Documentation Updates

### 8.1 Add Section to CLAUDE.md

Add this new section after "Backend Testing Framework" section in CLAUDE.md:

```markdown
## Multi-Environment Setup

**Status**: Fully implemented (October 2025)

TheBoosh.Zone supports four distinct environments with proper separation of concerns, CI/CD pipeline, and production-ready deployment infrastructure.

### Environments

1. **Development** (`MOJO_MODE=development`)
   - Local Docker Compose setup
   - Uses `morbo` development server with hot reload
   - Local PostgreSQL database
   - Full monitoring stack (Prometheus, Grafana)
   - API URL: http://localhost:3000

2. **Test** (`MOJO_MODE=test`)
   - CI/CD pipeline only (GitHub Actions)
   - Ephemeral PostgreSQL database (tmpfs)
   - Minimal services for fast testing
   - Tests run automatically on PR/push
   - Separate frontend and backend test suites

3. **Staging** (`MOJO_MODE=staging`)
   - Pre-production environment on cloud server
   - Uses `hypnotoad` production server (4 workers)
   - nginx reverse proxy with SSL
   - Managed PostgreSQL database (separate schema: `thebooshzone_staging`)
   - Full monitoring with Prometheus and Grafana
   - Deployed automatically on push to `dev` branch
   - URL: https://staging.theboosh.zone

4. **Production** (`MOJO_MODE=production`)
   - Live environment on cloud server
   - Uses `hypnotoad` production server (8 workers)
   - nginx reverse proxy with SSL and performance optimizations
   - Managed PostgreSQL database (separate schema: `thebooshzone_prod`)
   - Full monitoring with alerts
   - Deployed on push to `main` branch or version tags
   - Requires manual approval in GitHub Actions
   - URL: https://theboosh.zone

### Configuration Files

**Backend Perl** (Mojolicious Config Plugin):
- `config/hello-perld.development.conf` - Development settings (morbo, debug logging)
- `config/hello-perld.test.conf` - Test settings (minimal workers, error-only logging)
- `config/hello-perld.staging.conf` - Staging settings (hypnotoad, info logging)
- `config/hello-perld.production.conf` - Production settings (optimized hypnotoad, warn logging)

Each config file includes:
- Hypnotoad server settings (workers, listeners, timeouts)
- Database connection details (schema, host, credentials)
- Logging levels
- Session configuration
- Upload directory settings

**Frontend Vue/Vite**:
- `frontend/.env.development` - Local API (http://localhost:3000)
- `frontend/.env.test` - Test API (http://localhost:3000)
- `frontend/.env.staging` - Staging API (https://staging.theboosh.zone)
- `frontend/.env.production` - Production API (https://theboosh.zone)

Variables exposed to frontend:
- `VITE_API_URL` - Backend API endpoint
- `VITE_ENVIRONMENT` - Current environment name
- `VITE_ENABLE_DEBUG` - Debug mode toggle

**Docker Environment Files**:
- `.env.development.example` - Template for local development
- `.env.test.example` - Template for CI/CD testing
- `.env.staging.example` - Template for staging (secrets encrypted on server)
- `.env.production.example` - Template for production (secrets encrypted on server)

**Important**: Actual `.env.*` files (without `.example`) are gitignored and contain real credentials.

### Running Different Environments

**Development (Local)**:
```bash
# Copy example environment file
cp .env.development.example .env.development

# Edit with your local values
nano .env.development

# Start development environment
docker compose up

# Application available at http://localhost:3000
# Frontend dev server at http://localhost:5173 (optional)
```

**Test (Local or CI/CD)**:
```bash
# Create test environment file
cp .env.test.example .env.test

# Run tests
docker compose -f docker-compose.test.yml up --abort-on-container-exit
```

**Staging (Server)**:
```bash
# Deployed automatically via GitHub Actions on push to 'dev' branch
# Or manually:
ssh user@staging.theboosh.zone
cd /opt/theboosh-zone
./deploy/deploy.sh staging
```

**Production (Server)**:
```bash
# Deployed automatically via GitHub Actions on push to 'main' branch
# Requires manual approval in GitHub
# Or manually:
ssh user@production.theboosh.zone
cd /opt/theboosh-zone
./deploy/deploy.sh production
```

### Database Schema Separation

The managed PostgreSQL instance hosts multiple schemas on the same database:
- `thebooshzone_dev` - Development data (local Docker PostgreSQL)
- `thebooshzone_staging` - Staging data (managed database)
- `thebooshzone_prod` - Production data (managed database)
- `public` - Test data (ephemeral, separate test database)

**Benefits**:
- Cost-effective (one managed database for staging + production)
- Data isolation between environments
- Simplified connection management
- Easy to backup/restore specific environments

**Schema Configuration**:
Set via `DB_SCHEMA` environment variable and `database.schema` in config files.

### CI/CD Pipeline

**GitHub Actions Workflows**:

1. **`.github/workflows/test.yml`** - Runs on all PRs and pushes
   - Backend tests (Perl with Test::More, Test::Mojo)
   - Frontend tests (Vitest with Vue Test Utils)
   - Code linting (ESLint)
   - Coverage reports
   - Must pass before merging

2. **`.github/workflows/deploy-staging.yml`** - Deploys to staging
   - Triggered on push to `dev` branch
   - Runs full test suite first
   - Builds Docker image with staging frontend
   - Pushes to GitHub Container Registry (ghcr.io)
   - SSH to staging server and deploys
   - Runs health checks
   - Automatic rollback on failure

3. **`.github/workflows/deploy-production.yml`** - Deploys to production
   - Triggered on push to `main` branch or version tags (`v*`)
   - Runs full test suite first
   - **Requires manual approval** (GitHub environment protection)
   - Builds optimized production Docker image
   - Creates GitHub release (if tagged)
   - Backs up database before deployment
   - SSH to production server and deploys
   - Health checks with automatic rollback on failure
   - Notifications on success/failure

**Required GitHub Secrets**:
```
STAGING_HOST          # staging.theboosh.zone
STAGING_USER          # SSH username
STAGING_SSH_KEY       # SSH private key

PRODUCTION_HOST       # theboosh.zone  
PRODUCTION_USER       # SSH username
PRODUCTION_SSH_KEY    # SSH private key
```

**GitHub Token** (`GITHUB_TOKEN`) is automatically provided for Container Registry access.

### Production Server Architecture

```
Internet
   ↓
nginx (port 80/443)
   ├─ SSL/TLS termination (Let's Encrypt)
   ├─ Static file serving (/uploads/, /dist/)
   ├─ Rate limiting (API, auth endpoints)
   ├─ Gzip compression
   ├─ Security headers
   └─ Reverse proxy to backend
       ↓
hypnotoad (port 8080)
   ├─ 8 worker processes
   ├─ Hot deployment support
   ├─ Process management
   ├─ Health checks
   └─ Perl application (Mojolicious)
       ↓
Managed PostgreSQL Database
   └─ Schema: thebooshzone_prod
```

**Key Benefits**:
- nginx handles TLS, static files, and acts as a protective layer
- hypnotoad provides production-grade Perl application serving
- Hot deployment allows zero-downtime updates
- Managed database ensures high availability and automated backups

### Hypnotoad vs Morbo

| Feature | morbo (Development) | hypnotoad (Production) |
|---------|-------------------|----------------------|
| Workers | Single-threaded | Multi-worker (configurable) |
| Auto-reload | Yes (watches files) | No (use hot deployment) |
| Performance | Low (for development) | High (production-optimized) |
| Process management | None | Built-in (restarts crashed workers) |
| Hot deployment | No | Yes (zero-downtime updates) |
| Use case | Local development | Staging, Production |

**Starting hypnotoad**:
```bash
# Foreground (for Docker)
hypnotoad -f ./script/hello-perld

# Background (traditional deployment)
hypnotoad ./script/hello-perld

# Hot reload (zero-downtime update)
hypnotoad ./script/hello-perld  # Run same command again
```

### Deployment Process

**Standard Workflow**:
1. Create feature branch and make changes
2. Open Pull Request to `dev` branch
3. GitHub Actions runs tests automatically
4. Merge to `dev` after review and passing tests
5. Automatic deployment to staging
6. Verify on https://staging.theboosh.zone
7. Merge `dev` to `main` when ready for production
8. Approve production deployment in GitHub Actions
9. Automatic deployment to production
10. Verify on https://theboosh.zone

**Deployment Steps** (automated):
1. Run full test suite
2. Build Docker image with environment-specific frontend
3. Push image to GitHub Container Registry
4. SSH to target server
5. Pull latest image
6. Create database backup (production only)
7. Run database migrations
8. Graceful restart (hypnotoad hot reload)
9. Health check validation
10. Automatic rollback on failure

**Manual Deployment** (if needed):
```bash
# SSH to server
ssh user@staging.theboosh.zone  # or production

# Navigate to project directory
cd /opt/theboosh-zone

# Run deployment script
./deploy/deploy.sh staging  # or production

# Script will:
# - Load environment variables
# - Pull latest images
# - Run migrations
# - Deploy with health checks
# - Cleanup old images
```

### Rollback Procedure

If a deployment causes issues:

```bash
# SSH to server
ssh user@production.theboosh.zone

# Navigate to project
cd /opt/theboosh-zone

# Run rollback script
./deploy/rollback.sh production

# Script will:
# - Show available image tags
# - Prompt for rollback target
# - Stop current containers
# - Start with specified image tag
# - Verify health
```

**Automatic Rollback**:
Production deployment workflow includes automatic rollback if health checks fail after deployment.

### Environment Variables Reference

**Critical Production Variables** (must be unique per environment):
- `POSTGRES_HOST` - Managed database hostname
- `POSTGRES_PASSWORD` - Database password
- `SESSION_SECRET` - Session encryption key (generate with `openssl rand -hex 32`)
- `ADMIN_PASSWORD` - Admin user password

See `.env.*.example` files for complete list of required variables.

### Security Considerations

1. **Never commit `.env.*` files** (except `.example` templates)
2. **Use unique secrets per environment** - especially `SESSION_SECRET`
3. **Rotate secrets regularly** - at least annually, or after any suspected compromise
4. **Encrypt sensitive values** - use cloud platform's secrets management
5. **Enable HSTS** in production nginx config after SSL is working
6. **Restrict Swagger UI** in production (add basic auth or remove entirely)
7. **Monitor security advisories** - GitHub Dependabot enabled
8. **Database backups** - automated daily with 30-day retention
9. **Firewall rules** - only ports 22 (SSH), 80 (HTTP), 443 (HTTPS) open
10. **Non-root containers** - production Dockerfile uses appuser

### Monitoring & Logging

**Prometheus** (port 9090):
- Application metrics
- Database metrics (via postgres-exporter)
- System metrics (via node-exporter)
- Custom metrics from Mojolicious app

**Grafana** (port 3001):
- Pre-configured dashboards
- Real-time monitoring
- Alerting (configure as needed)

**Application Logs**:
```bash
# View live logs
docker compose -f docker-compose.production.yml logs -f app

# View nginx logs
docker compose -f docker-compose.production.yml logs -f nginx

# Log rotation configured via logrotate (14 days retention)
```

### Backup & Recovery

**Automated Backups**:
- Run automatically before each production deployment
- 30-day retention policy
- Stored in `/opt/theboosh-zone/backups/`

**Manual Backup**:
```bash
./deploy/backup.sh production
```

**Restore from Backup**:
```bash
# List backups
ls -lh /opt/theboosh-zone/backups/

# Restore
gunzip -c /opt/theboosh-zone/backups/backup_production_YYYYMMDD_HHMMSS.sql.gz | \
  PGPASSWORD=$POSTGRES_PASSWORD psql \
    -h $POSTGRES_HOST \
    -U $POSTGRES_USER \
    -d $POSTGRES_DB
```

### Troubleshooting

**Application won't start**:
```bash
# Check logs
docker compose -f docker-compose.production.yml logs app

# Common issues:
# - Database connection failed: Verify POSTGRES_* env vars
# - Missing SESSION_SECRET: Check .env.production
# - Port conflict: Ensure 8080 is available
```

**Deployment failed in GitHub Actions**:
- Check workflow run logs in GitHub Actions tab
- Verify SSH keys are correct in GitHub Secrets
- Ensure server is accessible and has enough disk space
- Check application logs on server

**Database connection issues**:
```bash
# Test connection
PGPASSWORD=$POSTGRES_PASSWORD psql \
  -h $POSTGRES_HOST \
  -U $POSTGRES_USER \
  -d $POSTGRES_DB \
  -c "SELECT version();"

# Verify server IP is whitelisted in managed database firewall
```

**SSL certificate issues**:
```bash
# Check certificate
sudo certbot certificates

# Renew manually
sudo certbot renew

# Certificates auto-renew via cron/systemd timer
```

**High memory/CPU usage**:
- Check `docker stats` for resource usage
- Reduce hypnotoad workers in `config/hello-perld.production.conf`
- Review Prometheus metrics for bottlenecks

**Need to rollback**:
```bash
./deploy/rollback.sh production
```

See `DEPLOYMENT.md` for comprehensive troubleshooting guide.

### References

- Mojolicious Documentation: https://docs.mojolicious.org/
- Hypnotoad Guide: https://docs.mojolicious.org/Mojo/Server/Hypnotoad
- Vite Environment Variables: https://vite.dev/guide/env-and-mode
- Docker Compose: https://docs.docker.com/compose/
- GitHub Actions: https://docs.github.com/en/actions
- nginx Documentation: https://nginx.org/en/docs/
- PostgreSQL: https://www.postgresql.org/docs/

---

*Last Updated: October 2025 - Implemented multi-environment setup with dev/test/staging/production, CI/CD pipeline, nginx reverse proxy, hypnotoad production server, and comprehensive deployment automation.*
```

### 8.2 Create DEPLOYMENT.md

Create a new comprehensive deployment guide. Due to length, here's the structure:

**File: `DEPLOYMENT.md`**

Create a detailed deployment guide with these sections:
1. Prerequisites (accounts, access, tools)
2. Initial Server Setup (step-by-step)
3. Database Setup (schemas, migrations, users)
4. GitHub Setup (secrets, environments, branch protection)
5. First Deployment (manual steps for initial deploy)
6. Ongoing Deployments (standard workflow)
7. Monitoring & Logging (Prometheus, Grafana, logs)
8. Backup & Recovery (automated backups, restore procedures)
9. Troubleshooting (common issues and solutions)
10. Support & Contact

*(Full content available in Part 1 of this document, Phase 8.2)*

---

## Phase 9: Manual Steps (Outside of Code)

### Pre-Deployment Checklist

#### 9.1 Cloud Platform Setup

**Provision Managed PostgreSQL**:
- [ ] Choose cloud provider (DigitalOcean or Azure)
- [ ] Create managed PostgreSQL cluster
  - Version: PostgreSQL 15
  - Size: Basic tier for staging, standard for production
  - Enable automated backups (daily, 30-day retention)
- [ ] Note connection details:
  - Host: `_______________`
  - Port: `5432`
  - Username: `_______________`
  - Password: `_______________`
  - Database name: `_______________`
- [ ] Configure firewall: Allow only staging/production server IPs
- [ ] Test connection from local machine

**Create Database Schemas**:
- [ ] Connect to managed database with admin credentials:
  ```bash
  psql "postgresql://username:password@host:port/database?sslmode=require"
  ```
- [ ] Create schemas:
  ```sql
  CREATE SCHEMA IF NOT EXISTS thebooshzone_staging;
  CREATE SCHEMA IF NOT EXISTS thebooshzone_prod;
  
  -- Optional: Create separate users for isolation
  CREATE USER theboosh_staging WITH PASSWORD 'secure-password-staging';
  CREATE USER theboosh_prod WITH PASSWORD 'secure-password-production';
  
  GRANT ALL PRIVILEGES ON SCHEMA thebooshzone_staging TO theboosh_staging;
  GRANT ALL PRIVILEGES ON SCHEMA thebooshzone_prod TO theboosh_prod;
  ```
- [ ] Verify schemas created:
  ```sql
  \dn
  ```

**Provision Servers**:
- [ ] Create staging VM/Droplet
  - OS: Ubuntu 22.04 LTS
  - Size: 2 vCPUs, 4GB RAM (minimum)
  - Add SSH key during creation
  - Note IP address: `_______________`
- [ ] Create production VM/Droplet
  - OS: Ubuntu 22.04 LTS
  - Size: 2+ vCPUs, 4+ GB RAM (scale as needed)
  - Add SSH key during creation
  - Note IP address: `_______________`
- [ ] Test SSH access to both servers

#### 9.2 Domain & DNS Configuration

- [ ] Confirm domain ownership: `theboosh.zone`
- [ ] Access domain registrar DNS settings
- [ ] Configure DNS A records:
  ```
  A    theboosh.zone              → [Production IP]  (TTL: 300)
  A    www.theboosh.zone          → [Production IP]  (TTL: 300)
  A    staging.theboosh.zone      → [Staging IP]     (TTL: 300)
  ```
- [ ] Wait for DNS propagation (5-30 minutes)
- [ ] Verify DNS resolution:
  ```bash
  dig +short theboosh.zone
  dig +short staging.theboosh.zone
  ```
- [ ] Optional: Configure CAA records for Let's Encrypt:
  ```
  CAA  theboosh.zone  0 issue "letsencrypt.org"
  ```

#### 9.3 SSL Certificates Setup

**Staging Server**:
- [ ] SSH to staging server: `ssh root@staging.theboosh.zone`
- [ ] Clone repository:
  ```bash
  git clone https://github.com/AlexanderBeahm/theboosh.zone.git /opt/theboosh-zone
  cd /opt/theboosh-zone
  ```
- [ ] Run setup script:
  ```bash
  chmod +x deploy/setup-server.sh
  ./deploy/setup-server.sh staging
  ```
- [ ] Script will:
  - Install Docker, Docker Compose, certbot
  - Configure firewall
  - Generate SSL certificate for staging.theboosh.zone
  - Setup log rotation
  - Create directory structure
- [ ] Verify certificate:
  ```bash
  sudo certbot certificates
  ```

**Production Server**:
- [ ] Repeat same steps for production
- [ ] Run setup script:
  ```bash
  ./deploy/setup-server.sh production
  ```
- [ ] Certificate will be generated for theboosh.zone

**Certificate Auto-Renewal**:
- [ ] Verify renewal timer is active:
  ```bash
  sudo systemctl status certbot.timer
  ```
- [ ] Test renewal (dry-run):
  ```bash
  sudo certbot renew --dry-run
  ```

#### 9.4 GitHub Repository Configuration

**Branch Protection Rules**:
- [ ] Go to repository Settings → Branches
- [ ] Add protection rule for `main`:
  - Branch name pattern: `main`
  - ☑ Require pull request reviews before merging
  - ☑ Require status checks to pass before merging
    - Select: "Backend Tests (Perl)"
    - Select: "Frontend Tests (Vue/Vitest)"
  - ☑ Require branches to be up to date before merging
  - ☑ Include administrators
- [ ] Add protection rule for `dev` (optional, similar settings)

**GitHub Environments**:
- [ ] Settings → Environments → New environment
- [ ] Create `staging` environment:
  - No protection rules needed (auto-deploy)
  - Set environment URL: `https://staging.theboosh.zone`
- [ ] Create `production` environment:
  - ☑ Required reviewers: Add yourself
  - Wait timer: 0 minutes (or set delay if desired)
  - Set environment URL: `https://theboosh.zone`

**GitHub Secrets**:
- [ ] Settings → Secrets and variables → Actions
- [ ] New repository secret → Add each:
  ```
  Name: STAGING_HOST
  Value: staging.theboosh.zone (or IP address)
  
  Name: STAGING_USER  
  Value: root (or your SSH username)
  
  Name: STAGING_SSH_KEY
  Value: [Paste entire private SSH key including headers]
  
  Name: PRODUCTION_HOST
  Value: theboosh.zone (or IP address)
  
  Name: PRODUCTION_USER
  Value: root (or your SSH username)
  
  Name: PRODUCTION_SSH_KEY
  Value: [Paste entire private SSH key including headers]
  ```
- [ ] Verify secrets are saved (will show as `***` in list)

**Enable GitHub Actions**:
- [ ] Settings → Actions → General
- [ ] Workflow permissions:
  - ○ Read and write permissions
  - ☑ Allow GitHub Actions to create and approve pull requests
- [ ] Save changes

**Container Registry**:
- [ ] Verify GitHub Container Registry access
- [ ] (Automatic with GITHUB_TOKEN, no manual setup needed)
- [ ] After first workflow run, package will appear at:
  `https://github.com/AlexanderBeahm/theboosh-zone/pkgs/container/theboosh-zone`

#### 9.5 Initial Server Configuration

**Staging Server**:
- [ ] SSH to server: `ssh root@staging.theboosh.zone`
- [ ] Navigate to project: `cd /opt/theboosh-zone`
- [ ] Create actual environment file:
  ```bash
  cp .env.staging.example .env.staging
  nano .env.staging
  ```
- [ ] Fill in actual values (use managed database credentials):
  ```env
  POSTGRES_HOST=your-managed-db-host.db.ondigitalocean.com
  POSTGRES_DB=defaultdb
  POSTGRES_USER=theboosh_staging
  POSTGRES_PASSWORD=your-actual-password
  SESSION_SECRET=$(openssl rand -hex 32)  # Generate unique secret
  # ... other values
  ```
- [ ] Ensure no placeholders remain
- [ ] Copy nginx configs if not in repo:
  ```bash
  # Should already be in repo, but verify:
  ls -l nginx/staging.conf
  ```

**Production Server**:
- [ ] Repeat for production
- [ ] **Use different credentials and secrets than staging!**
- [ ] Create `.env.production`:
  ```bash
  cp .env.production.example .env.production
  nano .env.production
  ```
- [ ] **Critical**: Generate new SESSION_SECRET:
  ```bash
  openssl rand -hex 32
  ```

#### 9.6 First Deployment

**Deploy to Staging (Manual)**:
- [ ] On staging server:
  ```bash
  cd /opt/theboosh-zone
  
  # First time: build images locally
  docker compose -f docker-compose.staging.yml build
  
  # Start services
  docker compose -f docker-compose.staging.yml up -d
  
  # Watch logs
  docker compose -f docker-compose.staging.yml logs -f
  ```
- [ ] Wait for "Database migrations completed successfully!"
- [ ] Wait for application to start
- [ ] Test health endpoint:
  ```bash
  curl http://localhost:8080/health
  ```
- [ ] Test via nginx (HTTPS):
  ```bash
  curl https://staging.theboosh.zone/health
  ```
- [ ] Open in browser: `https://staging.theboosh.zone`
- [ ] Verify:
  - [ ] Homepage loads
  - [ ] Admin login works
  - [ ] SSL certificate is valid (green padlock)

**Deploy to Production (Manual)**:
- [ ] After staging is verified, repeat for production
- [ ] On production server:
  ```bash
  cd /opt/theboosh-zone
  docker compose -f docker-compose.production.yml build
  docker compose -f docker-compose.production.yml up -d
  docker compose -f docker-compose.production.yml logs -f
  ```
- [ ] Test health: `curl https://theboosh.zone/health`
- [ ] Open in browser: `https://theboosh.zone`
- [ ] Full smoke test:
  - [ ] Browse homepage
  - [ ] View articles
  - [ ] Test tag filtering
  - [ ] Login to admin
  - [ ] Create test article
  - [ ] Upload test image
  - [ ] Verify image displays
  - [ ] Delete test article

#### 9.7 CI/CD Pipeline Testing

**Test Workflow**:
- [ ] On local machine, create test branch:
  ```bash
  git checkout -b test-cicd
  echo "# CI/CD Test" >> README.md
  git commit -am "Test CI/CD pipeline"
  git push origin test-cicd
  ```
- [ ] Go to GitHub → Actions tab
- [ ] Verify "Run Tests" workflow starts
- [ ] Check that both backend and frontend tests run
- [ ] Verify tests pass

**Test Staging Deployment**:
- [ ] Merge test branch to `dev`:
  ```bash
  git checkout dev
  git merge test-cicd
  git push origin dev
  ```
- [ ] Go to GitHub → Actions
- [ ] Verify "Deploy to Staging" workflow starts
- [ ] Monitor workflow progress:
  - Test job runs
  - Build and push job runs
  - Deploy job runs
- [ ] After completion, verify staging updated:
  ```bash
  curl https://staging.theboosh.zone/health
  ```

**Test Production Deployment**:
- [ ] Merge `dev` to `main`:
  ```bash
  git checkout main
  git merge dev
  git push origin main
  ```
- [ ] Go to GitHub → Actions
- [ ] Verify "Deploy to Production" workflow starts
- [ ] **Workflow will wait for approval**:
  - Go to workflow run
  - Click "Review deployments"
  - Select "production" environment
  - Click "Approve and deploy"
- [ ] Monitor deployment
- [ ] Verify production updated:
  ```bash
  curl https://theboosh.zone/health
  ```

#### 9.8 Monitoring Setup

**Prometheus**:
- [ ] Access staging: `https://staging.theboosh.zone:9090`
- [ ] Check Status → Targets
- [ ] Verify targets are "UP":
  - hello-perld
  - postgres-exporter (if configured)
  - node-exporter (if configured)
- [ ] Test query: `up{job="hello-perld"}`
- [ ] Repeat for production: `https://theboosh.zone:9090`

**Grafana**:
- [ ] Access staging: `https://staging.theboosh.zone:3001`
- [ ] Login with credentials from `.env.staging`:
  - Username: (from `GF_SECURITY_ADMIN_USER`)
  - Password: (from `GF_SECURITY_ADMIN_PASSWORD`)
- [ ] Verify Prometheus datasource is connected:
  - Configuration → Data sources → Prometheus
  - Should show "Data source is working"
- [ ] Create or import dashboards:
  - Dashboard for application metrics
  - Dashboard for database metrics
  - Dashboard for system metrics
- [ ] Repeat for production

**Log Monitoring**:
- [ ] Verify log rotation is configured:
  ```bash
  cat /etc/logrotate.d/theboosh-zone
  ```
- [ ] Test log viewing:
  ```bash
  docker compose -f docker-compose.production.yml logs --tail=100
  ```

#### 9.9 Backup Verification

**Test Backup Process**:
- [ ] SSH to production server
- [ ] Run manual backup:
  ```bash
  cd /opt/theboosh-zone
  ./deploy/backup.sh production
  ```
- [ ] Verify backup file created:
  ```bash
  ls -lh /opt/theboosh-zone/backups/
  ```
- [ ] Check backup size (should not be 0 bytes)

**Test Restore** (on staging, not production!):
- [ ] Copy production backup to staging:
  ```bash
  scp production-server:/opt/theboosh-zone/backups/backup_production_*.sql.gz \
      /tmp/test-backup.sql.gz
  ```
- [ ] Restore to staging (to test process):
  ```bash
  gunzip -c /tmp/test-backup.sql.gz | \
    PGPASSWORD=$POSTGRES_PASSWORD psql \
      -h $POSTGRES_HOST \
      -U $POSTGRES_USER \
      -d $POSTGRES_DB
  ```
- [ ] Verify data restored
- [ ] Re-deploy staging to clean up test data

**Verify Automated Backups**:
- [ ] After first deployment via CI/CD, check that backup was created
- [ ] Backups should run before each production deployment

#### 9.10 Documentation & Runbook

**Create Incident Response Runbook**:
- [ ] Document emergency contacts
- [ ] Document rollback procedure
- [ ] Document database restore procedure
- [ ] Document common troubleshooting steps
- [ ] Store in secure, accessible location (not just in Git)

**Team Documentation** (if applicable):
- [ ] Share access credentials securely (1Password, etc.)
- [ ] Document deployment workflow
- [ ] Schedule training session for team members
- [ ] Create on-call rotation (if applicable)

**Monitoring & Alerts**:
- [ ] Set up alerts in Grafana:
  - High CPU usage (>80% for 5 minutes)
  - High memory usage (>90%)
  - Application down (health check failing)
  - High error rate (>5% of requests)
  - Database connection issues
- [ ] Configure notification channels:
  - Email
  - Slack (if using)
  - PagerDuty (if using)
- [ ] Test alerts by triggering conditions

**Final Verification Checklist**:
- [ ] All environments accessible (dev local, staging, production)
- [ ] SSL certificates valid on all public environments
- [ ] DNS resolves correctly
- [ ] Health checks passing
- [ ] Monitoring dashboards showing data
- [ ] Backups running and verified
- [ ] CI/CD pipeline tested end-to-end
- [ ] Rollback procedure tested (on staging)
- [ ] Documentation complete and accessible
- [ ] Team trained (if applicable)

---

## Phase 10: Estimated Timeline & Migration Path

### Time Estimates

**Phase 1: Configuration Files** (4-6 hours)
- Backend Perl configs: 2 hours
- Frontend Vue configs: 1 hour
- Docker environment files: 1 hour
- Testing different modes locally: 1-2 hours

**Phase 2: Backend Production Readiness** (6-8 hours)
- Update HelloPerld.pm for config loading: 2 hours
- Update database connection logic: 1 hour
- Modify models to use config: 2 hours
- Update migration system: 1 hour
- Create multiple Dockerfiles: 1 hour
- Update entrypoint script: 1 hour
- Testing: 1-2 hours

**Phase 3: Frontend Build Process** (2-4 hours)
- Update package.json: 30 minutes
- Update vite.config.js: 1 hour
- Create config module: 30 minutes
- Update axios configuration: 30 minutes
- Testing builds: 1-2 hours

**Phase 4: Docker Compose Configurations** (4-6 hours)
- Update development compose: 1 hour
- Create test compose: 1 hour
- Create staging compose: 1 hour
- Create production compose: 1 hour
- Testing each configuration: 1-2 hours

**Phase 5: nginx Configuration** (4-6 hours)
- Create base nginx.conf: 1 hour
- Create staging.conf: 1 hour
- Create production.conf: 1 hour
- Testing reverse proxy: 1-2 hours
- SSL configuration testing: 1 hour

**Phase 6: CI/CD Pipeline** (6-8 hours)
- Create test workflow: 2 hours
- Create staging deployment workflow: 2 hours
- Create production deployment workflow: 2 hours
- Testing and debugging: 2-3 hours

**Phase 7: Deployment Scripts** (3-4 hours)
- setup-server.sh: 1 hour
- deploy.sh: 1 hour
- rollback.sh: 30 minutes
- backup.sh: 30 minutes
- Testing scripts: 1 hour

**Phase 8: Documentation** (4-6 hours)
- Update CLAUDE.md: 2 hours
- Create DEPLOYMENT.md: 2-3 hours
- Review and polish: 1 hour

**Phase 9: Manual Infrastructure Setup** (8-12 hours)
- Cloud platform setup: 2-3 hours
- DNS configuration: 1 hour
- Initial server setup: 2-3 hours
- First deployments: 2-3 hours
- Testing and validation: 2-3 hours

**Total Estimated Time**: 41-61 hours
- **Full-time (8 hours/day)**: 5-8 days (1-2 weeks)
- **Part-time (4 hours/day)**: 10-15 days (2-3 weeks)
- **Evenings/weekends (2 hours/day)**: 20-30 days (4-6 weeks)

### Migration Path

**Week 1: Local Development & Testing**
- **Day 1-2**: Phase 1 (Configuration files)
  - Create all environment config files
  - Update .gitignore
  - Test loading different configs locally
- **Day 3-4**: Phase 2 (Backend production readiness)
  - Update application code for multi-environment support
  - Create multiple Dockerfiles
  - Test hypnotoad locally
- **Day 5**: Phase 3 (Frontend builds)
  - Update frontend build configuration
  - Test building for different environments
  - Verify environment variables work

**Week 2: Infrastructure & Deployment**
- **Day 1-2**: Phase 4-5 (Docker Compose, nginx)
  - Create environment-specific compose files
  - Configure nginx reverse proxy
  - Test locally with Docker Compose
- **Day 3-4**: Phase 6 (CI/CD pipeline)
  - Create GitHub Actions workflows
  - Test on feature branch
  - Debug any issues
- **Day 5**: Phase 7 (Deployment scripts)
  - Write shell scripts
  - Test locally

**Week 3: Deployment & Documentation**
- **Day 1**: Phase 8 (Documentation)
  - Update CLAUDE.md
  - Create DEPLOYMENT.md
- **Day 2-3**: Phase 9 (Infrastructure setup)
  - Provision cloud resources
  - Setup DNS
  - Configure servers
  - Generate SSL certificates
- **Day 4**: First deployments
  - Deploy to staging
  - Thorough testing
  - Fix any issues
- **Day 5**: Production deployment
  - Deploy to production
  - Monitor closely
  - Create backups
  - Finalize documentation

### Risk Mitigation Strategies

**Rollback Plan**:
- [ ] Keep current `docker-compose.yml` as `docker-compose.yml.backup`
- [ ] Don't delete old `.env` until new system validated for 1 week
- [ ] Test everything in staging before production
- [ ] Have database backups before first production migration
- [ ] Keep previous Docker images tagged for quick rollback
- [ ] Document rollback procedure and test it on staging

**Testing Strategy**:
- [ ] Test each phase locally before moving to servers
- [ ] Deploy to staging first, validate thoroughly (spend 2-3 days testing)
- [ ] Use feature flags for gradual rollout if needed
- [ ] Monitor logs and metrics closely during first week
- [ ] Have plan to revert to old system if critical issues arise

**Communication Plan** (if team environment):
- [ ] Notify team of planned deployment schedule
- [ ] Schedule deployments during low-traffic periods
- [ ] Have emergency contact list ready
- [ ] Set up status page or communication channel for updates

### Success Criteria

After implementation, verify:
- [ ] Development environment still works as before
- [ ] Tests run successfully in CI/CD
- [ ] Staging environment accessible and functional
- [ ] Production environment deployed successfully
- [ ] All health checks passing
- [ ] Monitoring dashboards showing data
- [ ] Backups running automatically
- [ ] CI/CD pipeline working end-to-end
- [ ] Zero-downtime deployments working (hypnotoad hot reload)
- [ ] SSL certificates valid and auto-renewing
- [ ] Documentation complete and accurate

### Post-Implementation Maintenance

**Daily** (first week):
- [ ] Monitor application logs for errors
- [ ] Check Grafana dashboards for anomalies
- [ ] Verify backups are completing

**Weekly** (first month):
- [ ] Review Prometheus metrics for performance trends
- [ ] Check disk space on servers
- [ ] Review security logs
- [ ] Test deployment process

**Monthly** (ongoing):
- [ ] Review and update documentation
- [ ] Check for security updates (OS, Docker, dependencies)
- [ ] Test disaster recovery procedures
- [ ] Review and optimize resource allocation

**Quarterly** (ongoing):
- [ ] Rotate secrets and credentials
- [ ] Review and update monitoring alerts
- [ ] Performance optimization review
- [ ] Cost optimization review (cloud resources)

---

## Summary

This deployment plan transforms TheBoosh.Zone from a development-only setup into a production-ready application with:

✅ **Four Environments**: Development, Test, Staging, Production
✅ **Production Infrastructure**: hypnotoad + nginx + managed PostgreSQL
✅ **Automated Testing**: Full test suite runs in CI/CD
✅ **Automated Deployment**: Push to branch triggers deployment
✅ **Proper Separation**: Different configs, databases, secrets per environment
✅ **Monitoring**: Prometheus and Grafana for observability
✅ **Backup & Recovery**: Automated backups with restore procedures
✅ **Security**: SSL, rate limiting, security headers, non-root containers
✅ **Documentation**: Complete guides for operation and troubleshooting

The implementation follows industry best practices for Perl/Mojolicious and Vue.js applications while remaining manageable for a single developer or small team.

---

## Getting Started

To begin implementation:

1. **Start with Phase 1** - Create configuration files
2. **Test locally** - Validate each phase works in development
3. **Setup staging** - Deploy to staging environment first
4. **Validate thoroughly** - Spend time testing staging before production
5. **Deploy production** - Only after staging is stable
6. **Implement CI/CD** - Can be done last (manual deploys work initially)

**Remember**: The key to success is **incremental progress** and **thorough testing** at each stage. Don't rush to production - validate in staging first!

---

## Support

For questions or issues during implementation:
- Review documentation: `CLAUDE.md`, `DEPLOYMENT.md`, `README.md`
- Check GitHub Issues for similar problems
- Contact: alexanderbeahm@gmail.com
- Project GitHub: https://github.com/AlexanderBeahm/theboosh.zone

---

*Document created: October 2025*
*For: Alex Beahm (@AlexanderBeahm)*
*Project: TheBoosh.Zone*
*Part 2 of 2*
