# TheBoosh.Zone

Alex Beahm's personal portfolio and blog website built with modern full-stack architecture.

[![Docker Image CI](https://github.com/AlexanderBeahm/hello-perld/actions/workflows/docker-image.yml/badge.svg)](https://github.com/AlexanderBeahm/hello-perld/actions/workflows/docker-image.yml)

## About

TheBoosh.Zone is a full-featured personal website and blog platform showcasing my professional work, technical writing, and software engineering projects. Built with a robust tech stack combining Perl's Mojolicious framework on the backend and Vue 3 on the frontend, the site demonstrates modern web development practices with an emphasis on performance, security, and maintainability.

## Features

### Content Management
- **Blog System**: Full-featured article management with Markdown support and syntax highlighting
- **Tag Management**: Organize articles with tags, search, and filtering capabilities
- **Media Library**: Upload and manage images with drag-and-drop interface, automatic dimension extraction, and metadata support
- **Rich Text Editor**: Admin interface for creating and editing articles with live Markdown preview

### Administration
- **Secure Authentication**: Session-based admin login with password hashing and rate limiting
- **Admin Dashboard**: Comprehensive interface for content creation and management
- **Media Management**: Upload, organize, search, and delete media files
- **Article Management**: Create, edit, publish, and delete blog articles with draft support

### Technical Features
- **RESTful API**: Complete backend API with OpenAPI 3.0 documentation
- **Database Migrations**: Automated schema management with SQL and Perl migration support
- **Responsive Design**: Mobile-first Vue 3 single-page application
- **Monitoring**: Prometheus metrics and Grafana dashboards for performance tracking
- **DevContainer Support**: Integrated development environment with VSCode

### Architecture
- **Backend**: Mojolicious Perl framework with RESTful API design
- **Frontend**: Vue 3 SPA with Vite build system and Vue Router
- **Database**: PostgreSQL with custom migration system
- **Storage**: Organized media storage with date-based directory structure
- **Documentation**: Complete OpenAPI 3.0 specification with Swagger UI
- **Containerization**: Docker and Docker Compose for development and production

## Prerequisites

- **Docker & Docker Compose** (recommended for development)
- **Node.js LTS** (for frontend development)
- **Perl 5** with cpanm (for local development without Docker)
- **PostgreSQL** (if running without Docker)
- **VSCode** (optional, for DevContainer support)

## Quick Start

### Using Docker Compose (Recommended)

1. **Clone the repository:**
   ```bash
   git clone https://github.com/AlexanderBeahm/theboosh.zone.git
   cd theboosh.zone
   ```

2. **Configure environment variables:**
   ```bash
   cp .env.example .env
   ```

   Edit `.env` and set secure passwords:
   ```env
   # Database Configuration
   POSTGRES_DB=thebooshzone_dev
   POSTGRES_USER=theboosh_user
   POSTGRES_PASSWORD=your_secure_database_password

   # Admin User Configuration
   ADMIN_USERNAME=admin
   ADMIN_EMAIL=your-email@example.com
   ADMIN_PASSWORD=your_secure_admin_password

   # Media Upload Configuration
   UPLOAD_MAX_SIZE=5242880
   UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
   ```

3. **Start services:**
   ```bash
   docker compose up --build
   ```

4. **Run database migrations** (in a new terminal):
   ```bash
   docker exec thebooshzone-hello-perld-1 perl script/migrate
   ```

5. **Access the application:**
   - **Main Site**: http://localhost:3000
   - **Admin Dashboard**: http://localhost:3000/admin
   - **Admin Media Library**: http://localhost:3000/admin/media
   - **API Documentation**: http://localhost:3000/swagger
   - **Grafana Monitoring**: http://localhost:3001

### Using DevContainer (VSCode)

For the best development experience with integrated tooling:

1. **Open repository in VSCode:**
   ```bash
   code .
   ```

2. **Reopen in DevContainer:**
   - Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac)
   - Select "Dev Containers: Reopen in Container"
   - Wait for container to build and initialize

3. **Start services:**
   ```bash
   docker compose up --build --watch
   ```

   The `--watch` flag enables hot-reload for backend changes.

4. **Run migrations:**
   ```bash
   docker exec thebooshzone-hello-perld-1 perl script/migrate
   ```

## Configuration

### Environment Variables

All configuration is done through environment variables in the `.env` file:

#### Database Configuration
```env
POSTGRES_DB=thebooshzone_dev           # Database name
POSTGRES_USER=theboosh_user            # Database user
POSTGRES_PASSWORD=secure_password      # Database password
POSTGRES_HOST=db                       # Host (use 'db' for Docker, 'localhost' for local)
POSTGRES_PORT=5432                     # Database port
```

#### Admin User Configuration
```env
ADMIN_USERNAME=admin                   # Admin username
ADMIN_EMAIL=admin@example.com          # Admin email
ADMIN_PASSWORD=secure_password         # Admin password (will be hashed)
```

#### Media Upload Configuration
```env
UPLOADS_DIR=/usr/src/hello-perld/uploads           # Upload directory path
UPLOAD_MAX_SIZE=5242880                            # Max file size in bytes (5MB)
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
```

#### Monitoring Configuration
```env
GF_SECURITY_ADMIN_USER=admin           # Grafana admin username
GF_SECURITY_ADMIN_PASSWORD=password    # Grafana admin password
```

### Docker Volumes

The application uses persistent Docker volumes:

- **postgres_data**: Database storage
- **uploads_data**: Media file storage (organized as YYYY/MM directories)
- **prometheus_data**: Metrics storage
- **grafana_data**: Grafana configuration and dashboards

## Database Management

### Migration System

TheBoosh.Zone uses a custom migration system that supports both SQL and Perl scripts.

#### Running Migrations

```bash
# Run all pending migrations
docker exec thebooshzone-hello-perld-1 perl script/migrate

# Debug migration issues
docker exec thebooshzone-hello-perld-1 perl script/migrate_debug

# Check applied migrations
docker exec thebooshzone-db-1 psql -U theboosh_user -d thebooshzone_dev -c "SELECT * FROM schema_migrations;"
```

#### Migration Files

Migrations are located in `/migrations/` and executed in numerical order:

- `001_create_articles_table.sql` - Blog articles table with metadata
- `002_create_tags_table.sql` - Content tags for categorization
- `003_create_article_tags_table.sql` - Many-to-many article-tag relationships
- `004_create_admin_users_table.sql` - Admin user authentication
- `005_create_default_admin_user.pl` - Creates initial admin user from .env
- `006_create_media_table.sql` - Media file metadata and tracking

#### Creating New Migrations

1. Create a new file in `/migrations/` with format: `NNN_description.{sql|pl}`
2. For SQL migrations, write standard SQL commands
3. For Perl migrations, implement the migration logic
4. Run `perl script/migrate` to apply

### Troubleshooting Database Issues

**Connection refused:**
```bash
# Check if PostgreSQL container is running
docker compose ps

# Restart database service
docker compose restart db
```

**User does not exist:**
```bash
# Delete postgres volume and restart
docker compose down
docker volume rm thebooshzone_postgres_data
docker compose up -d
docker exec thebooshzone-hello-perld-1 perl script/migrate
```

**Reset database completely:**
```bash
docker compose down
docker volume rm thebooshzone_postgres_data
docker compose up -d
docker exec thebooshzone-hello-perld-1 perl script/migrate
```

## Development

### Frontend Development

The frontend is a Vue 3 single-page application built with Vite.

#### Development Mode with Hot Module Replacement

For the best development experience, run frontend and backend separately:

**Terminal 1 - Backend:**
```bash
morbo ./script/hello-perld
```

**Terminal 2 - Frontend:**
```bash
cd frontend
npm run dev
```

The Vite dev server runs at http://localhost:5173 and proxies API calls to http://localhost:3000.

#### Production Build

```bash
cd frontend
npm install
npm run build
```

This builds assets to `lib/HelloPerld/Public/dist/` which are served by Mojolicious.

### Backend Development

#### Running Locally (Without Docker)

1. **Install Perl dependencies:**
   ```bash
   cpanm --installdeps --notest .
   ```

2. **Start PostgreSQL** (ensure it's running locally or via Docker)

3. **Configure environment:**
   ```bash
   export POSTGRES_HOST=localhost
   export POSTGRES_PORT=5432
   export POSTGRES_DB=thebooshzone_dev
   export POSTGRES_USER=theboosh_user
   export POSTGRES_PASSWORD=your_password
   ```

4. **Run migrations:**
   ```bash
   perl script/migrate
   ```

5. **Start application:**
   ```bash
   morbo ./script/hello-perld
   ```

#### Development with Docker Watch Mode

```bash
docker compose up --watch
```

This enables automatic restart when backend code changes are detected.

### API Documentation

The complete API documentation is available via Swagger UI:

**URL**: http://localhost:3000/swagger

The OpenAPI 3.0 specification is located at `swagger/swagger.json`.

## Project Structure

```
theboosh.zone/
├── frontend/                    # Vue 3 SPA frontend
│   ├── src/
│   │   ├── components/         # Reusable Vue components
│   │   │   ├── ArticleCard.vue         # Article preview card
│   │   │   ├── ArticleEditor.vue       # Admin article editor
│   │   │   ├── ErrorBoundary.vue       # Error handling
│   │   │   ├── ImageUploader.vue       # Drag-and-drop upload
│   │   │   ├── MarkdownRenderer.vue    # Markdown with syntax highlighting
│   │   │   ├── MediaLibrary.vue        # Media management grid
│   │   │   └── NavBar.vue              # Main navigation
│   │   ├── views/                      # Page components
│   │   │   ├── AboutPage.vue           # About page
│   │   │   ├── AdminDashboard.vue      # Admin content management
│   │   │   ├── AdminLogin.vue          # Admin authentication
│   │   │   ├── AdminMedia.vue          # Media library page
│   │   │   ├── ArticlePage.vue         # Single article view
│   │   │   ├── ArticlesPage.vue        # Article listing
│   │   │   ├── HomePage.vue            # Landing page
│   │   │   └── NotFoundPage.vue        # 404 page
│   │   ├── router/                     # Vue Router config
│   │   ├── assets/                     # CSS and static assets
│   │   ├── App.vue                     # Root component
│   │   └── main.js                     # Application entry point
│   ├── index.html                      # HTML template
│   ├── vite.config.js                  # Vite configuration
│   └── package.json                    # Frontend dependencies
│
├── lib/HelloPerld/              # Perl backend
│   ├── Controller/              # API controllers
│   │   ├── Articles.pm          # Article CRUD operations
│   │   ├── Auth.pm              # Admin authentication
│   │   ├── Health.pm            # Health check endpoint
│   │   ├── Media.pm             # Media upload and management
│   │   └── Tags.pm              # Tag management
│   ├── Model/                   # Data models
│   │   ├── Article.pm           # Article database operations
│   │   ├── Media.pm             # Media database operations
│   │   └── Tag.pm               # Tag database operations
│   ├── Database/
│   │   └── Postgres.pm          # Connection and migration system
│   ├── Logger/                  # Logging system
│   ├── Public/                  # Static assets
│   │   └── dist/                # Built frontend assets (generated)
│   └── Templates/               # Mojolicious templates
│
├── migrations/                  # Database migrations
│   ├── 001_create_articles_table.sql
│   ├── 002_create_tags_table.sql
│   ├── 003_create_article_tags_table.sql
│   ├── 004_create_admin_users_table.sql
│   ├── 005_create_default_admin_user.pl
│   └── 006_create_media_table.sql
│
├── script/                      # Perl utility scripts
│   ├── hello-perld              # Main application script
│   ├── migrate                  # Migration runner
│   ├── migrate_debug            # Migration debugging
│   ├── create_admin_user        # Admin user creation
│   └── update_admin_password    # Password management
│
├── swagger/                     # API documentation
│   └── swagger.json             # OpenAPI 3.0 specification
│
├── .devcontainer/               # VSCode DevContainer config
├── .env.example                 # Environment template
├── docker-compose.yml           # Multi-service orchestration
├── Dockerfile                   # Multi-stage build (Node + Perl)
├── docker-entrypoint.sh         # Container startup script
├── Makefile.PL                  # Perl dependencies
└── README.md                    # This file
```

## Usage

### Creating Blog Content

1. **Login to admin dashboard:**
   - Navigate to http://localhost:3000/admin/login
   - Use credentials from your `.env` file

2. **Create a new article:**
   - Click "New Article" on the dashboard
   - Write content using Markdown
   - Add tags (separated by commas or spaces)
   - Upload featured image via media library
   - Publish or save as draft

3. **Manage media:**
   - Navigate to http://localhost:3000/admin/media
   - Drag and drop images or click to upload
   - Add alt text for accessibility
   - Search and filter media files
   - Edit metadata or delete files

### API Usage

The API follows RESTful conventions and is documented in OpenAPI format.

#### Public Endpoints

```bash
# List published articles
curl http://localhost:3000/api/articles

# Get article by slug
curl http://localhost:3000/api/articles/my-article-slug

# List tags
curl http://localhost:3000/api/tags

# Get popular tags
curl http://localhost:3000/api/tags/popular?limit=10
```

#### Admin Endpoints (Requires Authentication)

```bash
# Login
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_password"}' \
  -c cookies.txt

# Create article
curl -X POST http://localhost:3000/api/admin/articles \
  -b cookies.txt \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My Article",
    "content": "Content in **Markdown**",
    "is_published": true,
    "tags": ["tech", "blog"]
  }'

# Upload media
curl -X POST http://localhost:3000/api/admin/media/upload \
  -b cookies.txt \
  -F "file=@/path/to/image.jpg" \
  -F "alt_text=Description"
```

## Monitoring

### Prometheus Metrics

Available at http://localhost:9090

Metrics include:
- HTTP request rates and latencies
- Database connection pool stats
- PostgreSQL performance metrics
- System resource usage

### Grafana Dashboards

Available at http://localhost:3001

Default credentials (configure in `.env`):
- Username: admin
- Password: (set via `GF_SECURITY_ADMIN_PASSWORD`)

## Production Deployment

TheBoosh.Zone includes a complete CI/CD pipeline and deployment automation for staging and production environments.

### Deployment Architecture

**Environments:**
- **Development**: Local Docker setup with `morbo` (port 3000)
- **Test**: CI/CD only with ephemeral database
- **Staging**: Cloud server with `hypnotoad` + nginx (https://staging.theboosh.zone)
- **Production**: Cloud server with `hypnotoad` + nginx (https://theboosh.zone)

**Production Stack:**
```
Internet → nginx (SSL/TLS, static files) → hypnotoad (Perl app) → PostgreSQL (managed)
```

### Automated CI/CD Pipeline

**GitHub Actions Workflows:**

1. **Test Workflow** (`.github/workflows/test.yml`)
   - Runs on every push/PR to `dev` or `main`
   - Backend tests (Perl)
   - Frontend tests (Vue/Vitest)
   - Must pass before deployment

2. **Staging Deployment** (`.github/workflows/deploy-staging.yml`)
   - Automatically deploys on push to `dev` branch
   - Builds Docker image with staging config
   - Pushes to GitHub Container Registry (ghcr.io)
   - Deploys to staging.theboosh.zone
   - Health checks with automatic rollback

3. **Production Deployment** (`.github/workflows/deploy-production.yml`)
   - Automatically deploys on push to `main` branch
   - **Requires manual approval** before deploying
   - Creates database backup before deployment
   - Zero-downtime deployment with hypnotoad
   - Health checks with automatic rollback
   - Creates GitHub release for version tags (`v*`)

### Manual Deployment

For first-time setup or manual deployments:

```bash
# SSH to server
ssh user@staging.theboosh.zone  # or theboosh.zone

# Navigate to project
cd /opt/theboosh-zone

# Run deployment script
./deploy/deploy.sh staging  # or production
```

### Deployment Scripts

Located in `deploy/` directory:

- **`setup-server.sh`** - Initial server setup (Docker, SSL, firewall)
- **`deploy.sh`** - Deploy application with health checks
- **`rollback.sh`** - Rollback to previous deployment
- **`backup.sh`** - Create database backup

### Environment Configuration

Each environment uses separate configuration files:

**Backend Perl:**
- `config/hello-perld.development.conf` - Development (morbo, debug logging)
- `config/hello-perld.test.conf` - Test (minimal, error-only logging)
- `config/hello-perld.staging.conf` - Staging (hypnotoad, 4 workers)
- `config/hello-perld.production.conf` - Production (hypnotoad, 8 workers)

**Frontend Vue:**
- `frontend/.env.development` - Local API
- `frontend/.env.test` - Test API
- `frontend/.env.staging` - Staging API
- `frontend/.env.production` - Production API

**Server Environment:**
- `.env.development.example` - Template for local dev
- `.env.staging.example` - Template for staging
- `.env.production.example` - Template for production

### Database Schema Separation

Uses managed PostgreSQL with separate schemas:
- `public` - Development/test (local Docker)
- `thebooshzone_staging` - Staging environment
- `thebooshzone_prod` - Production environment

Benefits: Cost-effective (one database), data isolation, easy backup/restore.

### Security

**Implemented:**
- SSL/TLS via Let's Encrypt (auto-renewal)
- nginx rate limiting (API: 10 req/s, auth: 5 req/min)
- Security headers (X-Frame-Options, CSP, HSTS)
- Session-based authentication with secure cookies
- Non-root Docker containers
- Firewall (ufw): Only SSH, HTTP, HTTPS open
- Automated database backups (30-day retention)

**Secrets Management:**
- Environment-specific `.env` files (gitignored)
- GitHub Secrets for CI/CD (SSH keys, server IPs)
- Unique `SESSION_SECRET` per environment

### Monitoring

**Prometheus** (port 9090):
- Application metrics
- Database metrics (postgres-exporter)
- System metrics (node-exporter)

**Grafana** (port 3001):
- Real-time dashboards
- Alerting configuration
- Performance monitoring

**Logs:**
```bash
# View application logs
docker compose -f docker-compose.production.yml logs -f app

# View nginx logs
docker compose -f docker-compose.production.yml logs -f nginx
```

### Backup & Recovery

**Automated Backups:**
- Run before each production deployment
- 30-day retention policy
- Schema-specific (pg_dump)
- Compressed with gzip

**Manual Backup:**
```bash
ssh user@theboosh.zone
cd /opt/theboosh-zone
./deploy/backup.sh production
```

**Restore:**
```bash
gunzip -c backup_production_YYYYMMDD_HHMMSS.sql.gz | \
  psql -h $POSTGRES_HOST -U $POSTGRES_USER -d $POSTGRES_DB
```

### Rollback Procedure

If deployment causes issues:

```bash
ssh user@theboosh.zone
cd /opt/theboosh-zone
./deploy/rollback.sh production
```

Select previous image tag and confirm. Automatic health checks verify rollback success.

### Deployment Workflow

1. Create feature branch
2. Push to GitHub → tests run automatically
3. Create PR to `dev` → tests must pass
4. Merge to `dev` → auto-deploy to staging
5. Verify on https://staging.theboosh.zone
6. Merge `dev` to `main` → wait for approval
7. Approve → auto-deploy to production
8. Verify on https://theboosh.zone

### Setup Requirements

**For CI/CD:**
- GitHub repository secrets (SSH keys, server IPs)
- GitHub environments: `staging` (no approval), `production` (requires approval)
- GitHub Container Registry access (automatic)

**For Servers:**
- Ubuntu 22.04 LTS
- Docker & Docker Compose
- nginx with SSL (Let's Encrypt)
- Managed PostgreSQL database
- DNS configured (A records)

**See Full Documentation:**
- `.claude/claude-documentation/CLAUDE-DeploymentPlan-Part1.md` - Configuration
- `.claude/claude-documentation/CLAUDE-DeploymentPlan-Part2.md` - CI/CD
- `.claude/claude-documentation/Post-Implementation-Checklist.md` - Setup steps

## Troubleshooting

### Common Issues

**Port already in use:**
```bash
# Change ports in docker-compose.yml
# Or stop conflicting services
sudo lsof -i :3000
```

**Frontend not loading:**
```bash
# Rebuild frontend
cd frontend
npm run build

# Restart container
docker compose restart hello-perld
```

**Database connection errors:**
```bash
# Check database is running
docker compose ps

# Check logs
docker compose logs db

# Verify connection settings in .env
```

**Media uploads failing:**
```bash
# Check permissions on uploads volume
docker exec thebooshzone-hello-perld-1 ls -la /usr/src/hello-perld/uploads

# Check disk space
docker exec thebooshzone-hello-perld-1 df -h

# Verify upload size limits in .env
```

## Development Resources

- **Mojolicious Documentation**: https://docs.mojolicious.org/
- **Vue 3 Documentation**: https://vuejs.org/
- **PostgreSQL Documentation**: https://www.postgresql.org/docs/
- **OpenAPI Specification**: https://swagger.io/specification/
- **Docker Documentation**: https://docs.docker.com/

## Contributing

This is a personal project, but suggestions and bug reports are welcome:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License - See LICENSE file for details

## Contact

**Alex Beahm**
- GitHub: [@AlexanderBeahm](https://github.com/AlexanderBeahm)
- LinkedIn: [Alex Beahm](https://www.linkedin.com/in/alex-beahm-5bb7a89b/)
- Email: alexanderbeahm@gmail.com
- Website: https://theboosh.zone

---

Built with Perl, Vue.js, PostgreSQL.
