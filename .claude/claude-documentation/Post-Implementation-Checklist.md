# Post-Implementation Checklist: CI/CD Workflows

This checklist covers all steps needed to fully enable and test the GitHub Actions CI/CD workflows for TheBoosh.Zone.

## Overview

**Current State:**
- ✅ Test workflow (`.github/workflows/test.yml`) - ACTIVE and functional
- ⏸️ Staging deployment (`.github/workflows/deploy-staging.yml`) - DISABLED (manual only)
- ⏸️ Production deployment (`.github/workflows/deploy-production.yml`) - DISABLED (manual only)

**Goal:**
Enable full automated CI/CD pipeline with staging and production deployments.

---

## Phase 1: Test the Active Test Workflow (Immediate)

### 1.1 Verify GitHub Actions is Enabled

- [ ] Go to repository Settings → Actions → General
- [ ] Workflow permissions: Select **"Read and write permissions"**
- [ ] Check: **"Allow GitHub Actions to create and approve pull requests"**
- [ ] Click **Save**

### 1.2 Test the Test Workflow

- [ ] Create a test branch:
  ```bash
  git checkout -b test-ci-workflow
  echo "# Testing CI" >> README.md
  git add README.md
  git commit -m "Test CI workflow"
  git push origin test-ci-workflow
  ```

- [ ] Go to GitHub → **Actions** tab
- [ ] Verify "Run Tests" workflow appears and starts
- [ ] Monitor the workflow run:
  - [ ] Backend Tests (Perl) job should run
  - [ ] Frontend Tests (Vue/Vitest) job should run
  - [ ] Both should complete successfully (green checkmarks)

- [ ] If tests fail, review logs and fix any issues before proceeding

### 1.3 Configure Branch Protection (Optional but Recommended)

- [ ] Go to Settings → Branches → **Add rule**
- [ ] **For `main` branch:**
  - Branch name pattern: `main`
  - ☑ Require pull request reviews before merging
  - ☑ Require status checks to pass before merging
    - Search and add: **"Backend Tests (Perl)"**
    - Search and add: **"Frontend Tests (Vue/Vitest)"**
  - ☑ Require branches to be up to date before merging
  - ☑ Include administrators (recommended)
  - Click **Create**

- [ ] **For `dev` branch (optional):**
  - Repeat with same settings

---

## Phase 2: External Infrastructure Setup

### 2.1 Provision Cloud Resources

#### Managed PostgreSQL Database

- [ ] Choose cloud provider (DigitalOcean or Azure)
- [ ] Create managed PostgreSQL cluster:
  - Version: **PostgreSQL 15**
  - Size: Basic tier for staging, standard for production
  - Enable automated backups (daily, 30-day retention)

- [ ] Note connection details:
  ```
  Host: _________________________________
  Port: 5432
  Username: _____________________________
  Password: _____________________________
  Database name: ________________________
  ```

- [ ] Configure firewall rules:
  - [ ] Allow connections only from staging server IP
  - [ ] Allow connections only from production server IP
  - [ ] Allow your local IP for testing (temporary)

- [ ] Test connection from your local machine:
  ```bash
  psql "postgresql://username:password@host:port/database?sslmode=require"
  ```

- [ ] Create database schemas:
  ```sql
  CREATE SCHEMA IF NOT EXISTS thebooshzone_staging;
  CREATE SCHEMA IF NOT EXISTS thebooshzone_prod;
  
  -- Optional: Create separate users for better isolation
  CREATE USER theboosh_staging WITH PASSWORD 'secure-password-staging';
  CREATE USER theboosh_prod WITH PASSWORD 'secure-password-production';
  
  GRANT ALL PRIVILEGES ON SCHEMA thebooshzone_staging TO theboosh_staging;
  GRANT ALL PRIVILEGES ON SCHEMA thebooshzone_prod TO theboosh_prod;
  ```

- [ ] Verify schemas created:
  ```sql
  \dn
  ```

#### Staging Server (VM/Droplet)

- [ ] Create Ubuntu 22.04 LTS server:
  - Size: **2 vCPUs, 4GB RAM** (minimum)
  - Add your SSH public key during creation
  - Note IP address: _______________________

- [ ] Test SSH access:
  ```bash
  ssh root@STAGING_IP
  ```

#### Production Server (VM/Droplet)

- [ ] Create Ubuntu 22.04 LTS server:
  - Size: **2+ vCPUs, 4+ GB RAM** (scale based on expected traffic)
  - Add your SSH public key during creation
  - Note IP address: _______________________

- [ ] Test SSH access:
  ```bash
  ssh root@PRODUCTION_IP
  ```

### 2.2 Configure DNS

- [ ] Access domain registrar DNS settings for `theboosh.zone`

- [ ] Create A records:
  ```
  Type   Name                       Value              TTL
  ────────────────────────────────────────────────────────
  A      theboosh.zone              [PRODUCTION_IP]    300
  A      www.theboosh.zone          [PRODUCTION_IP]    300
  A      staging.theboosh.zone      [STAGING_IP]       300
  ```

- [ ] Wait for DNS propagation (5-30 minutes)

- [ ] Verify DNS resolution:
  ```bash
  dig +short theboosh.zone
  dig +short www.theboosh.zone
  dig +short staging.theboosh.zone
  ```
  Each should return the correct IP address

- [ ] **Optional:** Configure CAA records for Let's Encrypt:
  ```
  CAA    theboosh.zone    0 issue "letsencrypt.org"
  ```

### 2.3 Server Setup Scripts

The deployment scripts should now be available in the `deploy/` directory. These scripts automate server setup and deployments.

**Available Scripts:**

1. **`setup-server.sh`** - Initial server configuration (run once per server)
   - Installs Docker, Docker Compose, certbot
   - Configures firewall (ufw)
   - Generates SSL certificates
   - Sets up log rotation
   - Creates directory structure

2. **`deploy.sh`** - Deployment automation (run on every deployment)
   - Pulls latest Docker images
   - Runs database migrations
   - Performs zero-downtime deployment
   - Health check validation with automatic rollback

3. **`rollback.sh`** - Rollback to previous deployment (emergency use)
   - Interactive image selection
   - Confirmation prompts
   - Health check validation

4. **`backup.sh`** - Database backup (run before deployments)
   - Schema-specific backups
   - 30-day retention policy
   - Compressed with gzip

**Note:** See Phase 7 below for detailed testing instructions for each script.

### 2.4 Setup Staging Server

- [ ] SSH to staging server:
  ```bash
  ssh root@staging.theboosh.zone
  ```

- [ ] Clone repository:
  ```bash
  git clone https://github.com/AlexanderBeahm/theboosh.zone.git /opt/theboosh-zone
  cd /opt/theboosh-zone
  ```

- [ ] Make setup script executable and run it:
  ```bash
  chmod +x deploy/setup-server.sh
  ./deploy/setup-server.sh staging
  ```
  
  This script will:
  - Install Docker and Docker Compose
  - Install certbot for SSL
  - Configure firewall (ufw)
  - Create application directories
  - Setup log rotation
  - Generate SSL certificate for staging.theboosh.zone

- [ ] Wait for SSL certificate generation (requires DNS to be working)

- [ ] Verify certificate:
  ```bash
  sudo certbot certificates
  ```

- [ ] Create actual environment file:
  ```bash
  cp .env.staging.example .env.staging
  nano .env.staging
  ```

- [ ] Fill in actual values (use managed database credentials):
  ```env
  # PostgreSQL Configuration - Staging (Managed Database)
  POSTGRES_DB=your_database_name
  POSTGRES_USER=theboosh_staging
  POSTGRES_PASSWORD=your_actual_staging_password
  POSTGRES_HOST=your-managed-db-host.example.com
  POSTGRES_PORT=5432
  
  # Admin User
  ADMIN_USERNAME=admin
  ADMIN_EMAIL=alexanderbeahm@gmail.com
  ADMIN_PASSWORD=your_secure_admin_password
  
  # Session Secret (generate unique!)
  SESSION_SECRET=$(openssl rand -hex 32)
  
  # Media Upload Configuration
  UPLOADS_DIR=/usr/src/hello-perld/uploads
  UPLOAD_MAX_SIZE=5242880
  UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
  
  # Grafana
  GF_SECURITY_ADMIN_USER=admin
  GF_SECURITY_ADMIN_PASSWORD=your_grafana_password
  
  # Environment
  APP_ENV=staging
  NODE_ENV=production
  MOJO_MODE=staging
  DB_SCHEMA=thebooshzone_staging
  ```

- [ ] **IMPORTANT:** Ensure no placeholder values remain!

- [ ] Verify nginx configuration exists:
  ```bash
  ls -l nginx/staging.conf
  ```

### 2.5 Setup Production Server

- [ ] SSH to production server:
  ```bash
  ssh root@theboosh.zone
  ```

- [ ] Clone repository:
  ```bash
  git clone https://github.com/AlexanderBeahm/theboosh.zone.git /opt/theboosh-zone
  cd /opt/theboosh-zone
  ```

- [ ] Run setup script:
  ```bash
  chmod +x deploy/setup-server.sh
  ./deploy/setup-server.sh production
  ```

- [ ] Verify certificate:
  ```bash
  sudo certbot certificates
  ```

- [ ] Create actual environment file:
  ```bash
  cp .env.production.example .env.production
  nano .env.production
  ```

- [ ] Fill in actual values:
  ```env
  # PostgreSQL Configuration - Production (Managed Database)
  POSTGRES_DB=your_database_name
  POSTGRES_USER=theboosh_prod
  POSTGRES_PASSWORD=your_actual_production_password
  POSTGRES_HOST=your-managed-db-host.example.com
  POSTGRES_PORT=5432
  
  # Admin User
  ADMIN_USERNAME=admin
  ADMIN_EMAIL=alexanderbeahm@gmail.com
  ADMIN_PASSWORD=your_secure_admin_password_different_from_staging
  
  # Session Secret (generate unique - DIFFERENT from staging!)
  SESSION_SECRET=$(openssl rand -hex 32)
  
  # Media Upload Configuration
  UPLOADS_DIR=/usr/src/hello-perld/uploads
  UPLOAD_MAX_SIZE=5242880
  UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
  
  # Grafana
  GF_SECURITY_ADMIN_USER=admin
  GF_SECURITY_ADMIN_PASSWORD=your_grafana_password_different_from_staging
  
  # Environment
  APP_ENV=production
  NODE_ENV=production
  MOJO_MODE=production
  DB_SCHEMA=thebooshzone_prod
  ```

- [ ] **CRITICAL:** Use different passwords and secrets than staging!

- [ ] Verify nginx configuration exists:
  ```bash
  ls -l nginx/production.conf
  ```

---

## Phase 3: GitHub Repository Configuration

### 3.1 Add GitHub Secrets

- [ ] Go to repository Settings → Secrets and variables → Actions
- [ ] Click **New repository secret** and add each:

**Staging Secrets:**
```
Name: STAGING_HOST
Value: staging.theboosh.zone (or IP address)

Name: STAGING_USER
Value: root (or your SSH username)

Name: STAGING_SSH_KEY
Value: [Paste entire private SSH key including -----BEGIN/END----- headers]
```

**Production Secrets:**
```
Name: PRODUCTION_HOST
Value: theboosh.zone (or IP address)

Name: PRODUCTION_USER
Value: root (or your SSH username)

Name: PRODUCTION_SSH_KEY
Value: [Paste entire private SSH key including -----BEGIN/END----- headers]
```

- [ ] Verify all 6 secrets are saved (they will show as `***` in the list)

### 3.2 Create GitHub Environments

- [ ] Go to Settings → Environments → **New environment**

**Staging Environment:**
- [ ] Name: `staging`
- [ ] Environment protection rules: **None** (leave unchecked for auto-deploy)
- [ ] Deployment branches: All branches (default)
- [ ] Environment secrets: None needed (uses repository secrets)
- [ ] Environment URL: `https://staging.theboosh.zone`
- [ ] Click **Configure environment** (or Save)

**Production Environment:**
- [ ] Name: `production`
- [ ] Environment protection rules:
  - ☑ **Required reviewers**: Add yourself
  - Wait timer: `0` minutes (or set delay if desired)
- [ ] Deployment branches: Selected branches only → Add `main`
- [ ] Environment secrets: None needed (uses repository secrets)
- [ ] Environment URL: `https://theboosh.zone`
- [ ] Click **Configure environment** (or Save)

### 3.3 Verify GitHub Container Registry Access

- [ ] Go to repository **Packages** tab (will be empty initially)
- [ ] After first workflow run, you should see `theboosh-zone` package appear
- [ ] Package will be at: `ghcr.io/alexanderbeahm/theboosh-zone`

---

## Phase 4: Test Deployments (Manual Trigger)

### 4.1 First Manual Staging Deployment

Before enabling automatic deployments, test manually:

- [ ] Go to GitHub → **Actions** tab
- [ ] Click **Deploy to Staging** workflow (left sidebar)
- [ ] Click **Run workflow** dropdown (right side)
- [ ] Select branch: `dev`
- [ ] Click **Run workflow** button

- [ ] Monitor the workflow:
  - [ ] Test job completes successfully
  - [ ] Build-and-push job completes (image pushed to ghcr.io)
  - [ ] Deploy job completes (SSH to server and deploys)

- [ ] If deployment fails, check:
  - [ ] GitHub secrets are correct
  - [ ] Server is accessible via SSH
  - [ ] Deployment scripts exist on server
  - [ ] `.env.staging` file exists with correct values

### 4.2 Verify Staging Deployment

- [ ] Open browser: `https://staging.theboosh.zone`
- [ ] Verify SSL certificate is valid (green padlock)
- [ ] Test the application:
  - [ ] Homepage loads
  - [ ] Articles page works
  - [ ] Admin login works
  - [ ] Create/edit test article
  - [ ] Upload test image
  - [ ] Verify image displays correctly

- [ ] Check health endpoint:
  ```bash
  curl https://staging.theboosh.zone/health
  ```

- [ ] Review application logs:
  ```bash
  ssh root@staging.theboosh.zone
  cd /opt/theboosh-zone
  docker compose -f docker-compose.staging.yml logs -f app
  ```

### 4.3 First Manual Production Deployment

- [ ] Go to GitHub → **Actions** tab
- [ ] Click **Deploy to Production** workflow
- [ ] Click **Run workflow** dropdown
- [ ] Select branch: `main`
- [ ] Click **Run workflow** button

- [ ] Monitor the workflow:
  - [ ] Test job completes
  - [ ] Build-and-push job completes
  - [ ] Deploy job **waits for approval**

- [ ] **Approve the deployment:**
  - [ ] Click on the workflow run
  - [ ] Click **Review deployments** button
  - [ ] Select **production** checkbox
  - [ ] Click **Approve and deploy**

- [ ] Monitor deployment completion:
  - [ ] Database backup created
  - [ ] Application deployed
  - [ ] Health check passes

### 4.4 Verify Production Deployment

- [ ] Open browser: `https://theboosh.zone`
- [ ] Verify SSL certificate is valid
- [ ] Full smoke test:
  - [ ] Browse homepage
  - [ ] View articles
  - [ ] Test tag filtering
  - [ ] Login to admin
  - [ ] Create test article
  - [ ] Upload test image
  - [ ] Verify everything works
  - [ ] Delete test content

- [ ] Check health endpoint:
  ```bash
  curl https://theboosh.zone/health
  ```

- [ ] Verify backup was created:
  ```bash
  ssh root@theboosh.zone
  ls -lh /opt/theboosh-zone/backups/
  ```

---

## Phase 5: Enable Automatic Deployments

Once manual deployments are working, enable automatic triggers:

### 5.1 Enable Automatic Staging Deployment

- [ ] Edit `.github/workflows/deploy-staging.yml`
- [ ] Find the commented section at the top:
  ```yaml
  # CURRENTLY DISABLED: Only manual triggers allowed
  # To enable automatic deployment to staging, uncomment the lines below:
  #
  # on:
  #   push:
  #     branches: [ dev ]
  #   workflow_dispatch:
  ```

- [ ] Replace the entire `on:` section with:
  ```yaml
  on:
    push:
      branches: [ dev ]
    workflow_dispatch:
  ```

- [ ] Commit and push:
  ```bash
  git add .github/workflows/deploy-staging.yml
  git commit -m "Enable automatic staging deployment"
  git push origin dev
  ```

- [ ] This push should trigger automatic deployment to staging!

### 5.2 Enable Automatic Production Deployment

- [ ] Edit `.github/workflows/deploy-production.yml`
- [ ] Find the commented section at the top:
  ```yaml
  # CURRENTLY DISABLED: Only manual triggers allowed
  # To enable automatic deployment to production, uncomment the lines below:
  #
  # on:
  #   push:
  #     branches: [ main ]
  #     tags: [ 'v*' ]
  #   workflow_dispatch:
  ```

- [ ] Replace the entire `on:` section with:
  ```yaml
  on:
    push:
      branches: [ main ]
      tags: [ 'v*' ]
    workflow_dispatch:
  ```

- [ ] Commit and push:
  ```bash
  git add .github/workflows/deploy-production.yml
  git commit -m "Enable automatic production deployment"
  git push origin main
  ```

- [ ] This push should trigger automatic deployment to production!
- [ ] **Remember:** You'll still need to approve the deployment

### 5.3 Test Automatic Deployments

**Test Staging:**
- [ ] Make a small change to the codebase
- [ ] Commit and push to `dev` branch
- [ ] Verify workflow runs automatically
- [ ] Verify staging updates without manual intervention

**Test Production:**
- [ ] Merge `dev` to `main` (or push directly to main)
- [ ] Verify workflow runs automatically
- [ ] Verify approval is required
- [ ] Approve and verify deployment completes

**Test Version Tagging:**
- [ ] Create and push a version tag:
  ```bash
  git tag v1.0.0
  git push origin v1.0.0
  ```
- [ ] Verify workflow runs
- [ ] Verify GitHub Release is created automatically
- [ ] Approve production deployment

---

## Phase 6: Monitoring & Maintenance

### 6.1 Setup Monitoring

**Prometheus:**
- [ ] Access staging: `https://staging.theboosh.zone:9090`
- [ ] Access production: `https://theboosh.zone:9090`
- [ ] Verify targets are "UP" under Status → Targets

**Grafana:**
- [ ] Access staging: `https://staging.theboosh.zone:3001`
- [ ] Access production: `https://theboosh.zone:3001`
- [ ] Login with credentials from `.env` files
- [ ] Verify Prometheus datasource is connected
- [ ] Create or import dashboards

### 6.2 Verify Backup System

- [ ] SSH to production server
- [ ] Test manual backup:
  ```bash
  cd /opt/theboosh-zone
  ./deploy/backup.sh production
  ```
- [ ] Verify backup file created:
  ```bash
  ls -lh /opt/theboosh-zone/backups/
  ```

### 6.3 Test Rollback Procedure (Staging Only!)

- [ ] SSH to staging server
- [ ] Run rollback script:
  ```bash
  cd /opt/theboosh-zone
  ./deploy/rollback.sh staging
  ```
- [ ] Follow prompts and select a previous image tag
- [ ] Verify rollback completes successfully
- [ ] Re-deploy staging to get back to latest

---

## Phase 7: Verify and Test Deployment Scripts

The deployment scripts have been created in the `deploy/` directory. Before using them in production, you need to verify they exist and test them manually.

### 7.1 Verify Deployment Scripts Exist

- [ ] Check that all scripts are in the repository:
  ```bash
  ls -lh deploy/
  ```

- [ ] Verify the following scripts exist and are executable:
  - [ ] `deploy/setup-server.sh` (initial server setup)
  - [ ] `deploy/deploy.sh` (deployment automation)
  - [ ] `deploy/rollback.sh` (rollback functionality)
  - [ ] `deploy/backup.sh` (database backup)

- [ ] All scripts should have execute permissions (`-rwxr-xr-x`)

### 7.2 Copy Scripts to Servers

**Staging Server:**
- [ ] The scripts should already be in the repository on the server
- [ ] If you cloned the repo, scripts are already there
- [ ] Verify: `ssh root@staging.theboosh.zone "ls -l /opt/theboosh-zone/deploy/"`

**Production Server:**
- [ ] Same verification for production
- [ ] Verify: `ssh root@theboosh.zone "ls -l /opt/theboosh-zone/deploy/"`

### 7.3 Test setup-server.sh (Already Run)

This script should have been run during Phase 2.4 and 2.5. Verify it was successful:

- [ ] **On Staging Server:**
  ```bash
  ssh root@staging.theboosh.zone
  
  # Verify Docker is installed
  docker --version
  docker compose version
  
  # Verify certbot is installed
  certbot --version
  
  # Verify SSL certificate exists
  sudo certbot certificates
  
  # Verify firewall is configured
  sudo ufw status
  ```

- [ ] **On Production Server:**
  - Repeat same verification steps

**If setup-server.sh wasn't run yet:**
- [ ] Run it now: `./deploy/setup-server.sh staging` (or production)
- [ ] Wait for SSL certificate generation
- [ ] Verify all checks above pass

### 7.4 Test backup.sh (Manual Test)

Test the backup script on staging before relying on it:

- [ ] SSH to staging server:
  ```bash
  ssh root@staging.theboosh.zone
  cd /opt/theboosh-zone
  ```

- [ ] Run manual backup:
  ```bash
  ./deploy/backup.sh staging
  ```

- [ ] Verify backup file was created:
  ```bash
  ls -lh /opt/theboosh-zone/backups/
  ```

- [ ] Check backup file is not empty (should be several KB at minimum):
  ```bash
  du -h /opt/theboosh-zone/backups/backup_staging_*.sql.gz | tail -1
  ```

- [ ] **Test restore procedure (IMPORTANT!):**
  ```bash
  # Get the latest backup file
  LATEST_BACKUP=$(ls -t /opt/theboosh-zone/backups/backup_staging_*.sql.gz | head -1)
  
  # Test that it can be uncompressed and viewed
  gunzip -c $LATEST_BACKUP | head -20
  
  # This should show SQL commands
  ```

- [ ] **Repeat for production:**
  ```bash
  ssh root@theboosh.zone
  cd /opt/theboosh-zone
  ./deploy/backup.sh production
  ```

### 7.5 Test deploy.sh (Manual Deployment)

**IMPORTANT:** Test deploy.sh manually BEFORE enabling automatic CI/CD deployments.

**Test on Staging First:**

- [ ] SSH to staging server:
  ```bash
  ssh root@staging.theboosh.zone
  cd /opt/theboosh-zone
  ```

- [ ] Ensure `.env.staging` file exists with correct values

- [ ] Run manual deployment:
  ```bash
  ./deploy/deploy.sh staging
  ```

- [ ] Watch the output and verify:
  - [ ] Environment variables loaded
  - [ ] Docker images pulled successfully
  - [ ] Database migrations ran (or warning shown)
  - [ ] Containers started
  - [ ] Health checks passed (application became healthy)
  - [ ] Old images cleaned up
  - [ ] "Deployment Complete!" message shown

- [ ] Verify application is working:
  ```bash
  curl https://staging.theboosh.zone/health
  ```

- [ ] Check application logs:
  ```bash
  docker compose -f docker-compose.staging.yml logs -f app
  ```
  Press Ctrl+C to exit

- [ ] Open in browser: `https://staging.theboosh.zone`
  - [ ] Homepage loads
  - [ ] Admin login works
  - [ ] No errors in browser console

**Test on Production:**

- [ ] After staging test succeeds, repeat for production:
  ```bash
  ssh root@theboosh.zone
  cd /opt/theboosh-zone
  ./deploy/deploy.sh production
  ```

- [ ] Verify all the same checks as staging

- [ ] **CRITICAL:** Ensure production backup was created first:
  ```bash
  ls -lh /opt/theboosh-zone/backups/backup_production_*.sql.gz | tail -1
  ```

### 7.6 Test rollback.sh (Simulation)

Test the rollback functionality on staging to ensure it works when needed:

- [ ] SSH to staging server:
  ```bash
  ssh root@staging.theboosh.zone
  cd /opt/theboosh-zone
  ```

- [ ] Run rollback script:
  ```bash
  ./deploy/rollback.sh staging
  ```

- [ ] The script will show available image tags:
  ```
  Available images:
  ghcr.io/alexanderbeahm/theboosh-zone   staging-abc123   ...
  ghcr.io/alexanderbeahm/theboosh-zone   staging-def456   ...
  ```

- [ ] Enter one of the shown tags (the one you just deployed)

- [ ] Confirm with "yes" when prompted

- [ ] Verify:
  - [ ] Containers stopped
  - [ ] Containers restarted with specified image
  - [ ] Health check passed
  - [ ] "Rollback complete!" message shown

- [ ] Verify application still works:
  ```bash
  curl https://staging.theboosh.zone/health
  ```

- [ ] Re-deploy to get back to latest:
  ```bash
  ./deploy/deploy.sh staging
  ```

### 7.7 Document Script Usage

- [ ] Create a quick reference document for your team with:
  - When to use each script
  - Example commands
  - Common troubleshooting steps

- [ ] Add to your runbook:
  - Emergency rollback procedure
  - How to check backup success
  - Who to contact if scripts fail

---

## Phase 8: Documentation & Training

### 8.1 Team Documentation

- [ ] Document workflow for team members:
  - How to create feature branches
  - PR process and required reviews
  - Testing requirements before merge
  - Deployment process (automatic vs manual)

- [ ] Share access credentials securely (use 1Password, etc.):
  - Server SSH access (if needed)
  - Grafana credentials
  - Database credentials (read-only for developers)

### 8.2 Incident Response

- [ ] Create incident response runbook
- [ ] Document emergency rollback procedure
- [ ] Document who to contact for issues
- [ ] Setup on-call rotation (if applicable)

---

## Troubleshooting

### Workflow Fails on Test Job

**Issue:** Backend or frontend tests fail in GitHub Actions

**Solutions:**
- [ ] Run tests locally first: `docker compose -f docker-compose.test.yml up`
- [ ] Check GitHub Actions logs for specific error messages
- [ ] Ensure all required files exist (docker-compose.test.yml, .env.test)
- [ ] Verify Node.js version matches (20.x)

### Deployment Fails: SSH Connection

**Issue:** Cannot connect to server via SSH

**Solutions:**
- [ ] Verify GitHub secrets are correct (STAGING_HOST, STAGING_SSH_KEY, etc.)
- [ ] Test SSH manually: `ssh root@staging.theboosh.zone`
- [ ] Ensure SSH key has no passphrase
- [ ] Check firewall rules allow SSH (port 22)
- [ ] Verify server is running

### Deployment Fails: Docker Login

**Issue:** Cannot pull image from ghcr.io

**Solutions:**
- [ ] Verify GITHUB_TOKEN has packages:read permission
- [ ] Check if image was built and pushed successfully
- [ ] Manually test: `echo $TOKEN | docker login ghcr.io -u username --password-stdin`

### Health Check Fails After Deployment

**Issue:** Application doesn't respond to health checks

**Solutions:**
- [ ] SSH to server and check logs: `docker compose -f docker-compose.staging.yml logs -f`
- [ ] Verify database connection: Check POSTGRES_* environment variables
- [ ] Check if application is listening on correct port (8080)
- [ ] Ensure nginx is running and proxying correctly
- [ ] Test health endpoint directly: `curl http://localhost:8080/health`

### Automatic Rollback Triggered

**Issue:** Production deployment rolled back automatically

**Solutions:**
- [ ] Check workflow logs for health check failure reason
- [ ] SSH to server and investigate: `docker compose -f docker-compose.production.yml logs`
- [ ] Verify the issue in staging first before redeploying production
- [ ] Consider rolling back to a known-good version tag

---

## Success Criteria

You're done when:

- ✅ Test workflow runs automatically on every push/PR
- ✅ Tests pass consistently
- ✅ Staging deploys automatically when merging to `dev`
- ✅ Production deploys automatically when merging to `main` (with approval)
- ✅ Health checks pass after deployments
- ✅ Rollback procedure tested and documented
- ✅ Monitoring shows application metrics
- ✅ Backups are being created
- ✅ SSL certificates are valid and auto-renewing
- ✅ Team is trained on the workflow

---

## Quick Reference

**Test Workflow Locally:**
```bash
docker compose -f docker-compose.test.yml up --build --abort-on-container-exit
```

**Manual Staging Deploy:**
Go to Actions → Deploy to Staging → Run workflow

**Manual Production Deploy:**
Go to Actions → Deploy to Production → Run workflow → Approve

**SSH to Servers:**
```bash
ssh root@staging.theboosh.zone
ssh root@theboosh.zone
```

**View Logs:**
```bash
docker compose -f docker-compose.staging.yml logs -f app
docker compose -f docker-compose.production.yml logs -f app
```

**Manual Backup:**
```bash
./deploy/backup.sh production
```

**Manual Rollback:**
```bash
./deploy/rollback.sh production
```

**Check Health:**
```bash
curl https://staging.theboosh.zone/health
curl https://theboosh.zone/health
```

---

**Questions or Issues?**

Contact: Alex Beahm (alexanderbeahm@gmail.com)

Repository: https://github.com/AlexanderBeahm/theboosh.zone

---

*Last Updated: [Current Date]*
*Version: 1.0*
