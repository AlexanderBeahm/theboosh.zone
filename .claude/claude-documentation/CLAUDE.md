# TheBoosh.Zone - Claude Development Guide

## Project Overview

TheBoosh.Zone is Alex Beahm's personal portfolio and blog website, built with a modern full-stack architecture featuring a complete blogging system with media management capabilities.

**Owner**: Alex Beahm (GitHub: @AlexanderBeahm)
**Purpose**: Personal portfolio and blog platform
**Domain**: theboosh.zone

## Current Architecture

### Technology Stack
- **Backend**: Perl with Mojolicious framework
- **Frontend**: Vue 3 Single Page Application (SPA) with Vite build system
- **Database**: PostgreSQL with migration system
- **API Documentation**: OpenAPI 3.0.3 with Swagger UI
- **Media Storage**: Persistent Docker volume with organized directory structure
- **Containerization**: Docker & Docker Compose
- **Monitoring**: Prometheus & Grafana
- **Development Environment**: VSCode DevContainer support
- **Testing**:
  - Backend: Test::More, Test::Mojo, DBD::Mock (Perl TAP framework)
  - Frontend: Vitest with Vue Test Utils

### Project Structure
```
/
   frontend/                    # Vue 3 SPA
      src/
         components/         # Reusable Vue components
            NavBar.vue              # Main navigation
            ErrorBoundary.vue       # Error boundary component
            MarkdownRenderer.vue    # Markdown rendering with syntax highlighting
            ArticleCard.vue         # Article preview card component
            ArticleEditor.vue       # Admin article creation/editing
            ImageUploader.vue       # Drag-and-drop image upload component
            MediaLibrary.vue        # Media management interface
         views/             # Page components
            HomePage.vue            # Landing page
            AboutPage.vue           # About page
            ArticlesPage.vue        # Blog listing with tag filtering
            ArticlePage.vue         # Individual article display
            AdminLogin.vue          # Admin authentication
            AdminDashboard.vue      # Content management interface
            AdminMedia.vue          # Media library management page
            NotFoundPage.vue        # 404 page
         router/            # Vue Router configuration
         assets/            # Styles and static assets
      package.json
   lib/HelloPerld/            # Perl backend
      Controller/            # API controllers
         Health.pm         # Health check endpoint
         Articles.pm       # Article CRUD operations
         Tags.pm           # Tag management
         Auth.pm           # Admin authentication
         Media.pm          # Media file upload and management
      Model/                # Data models
         Article.pm        # Article data operations
         Tag.pm            # Tag data operations
         Media.pm          # Media data operations
      Database/
         Postgres.pm       # DB connection utilities & migration system
      Logger/               # Logging system
      Public/               # Static assets
         dist/             # Built frontend assets (generated)
   migrations/              # Database migrations
      001_create_articles_table.sql
      002_create_tags_table.sql
      003_create_article_tags_table.sql
      004_create_admin_users_table.sql
      005_create_default_admin_user.pl
      006_create_media_table.sql
   swagger/
      swagger.json          # API documentation (OpenAPI 3.0.3)
   script/
      hello-perld           # Main application script
      migrate               # Migration runner
      migrate_debug         # Migration debugging
      create_admin_user     # Admin user creation utility
      update_admin_password # Admin password update utility
      test                  # Run all backend tests
      test-unit             # Run unit tests only
      test-integration      # Run integration tests only
   t/                       # Backend test suite (Perl TAP)
      00-load.t             # Module loading verification
      unit/                 # Unit tests with mocked dependencies
         model/
            article.t       # Article model tests
            tag.t           # Tag model tests
            media.t         # Media model tests
         database/
            postgres.t      # Database utilities tests
      integration/          # Integration tests with real database
         controller/
            health.t        # Health endpoint tests
            auth.t          # Authentication tests
            articles.t      # Article controller tests
            tags.t          # Tag controller tests
            media.t         # Media controller tests
      lib/
         TestHelper.pm      # Shared testing utilities
      README.md             # Testing documentation
   docker-compose.yml        # Full development environment
```

## Current State Analysis

### Implemented Features
- Mojolicious application structure with OpenAPI integration
- Vue 3 SPA with routing and navigation
- PostgreSQL database with migration system
- Docker containerization with development environment
- Health check API endpoint
- Prometheus/Grafana monitoring setup
- **Complete Blog System**:
  - Article CRUD operations
  - Markdown support with syntax highlighting
  - Tag management system
  - Article-tag relationships
  - Pagination and filtering
  - Published/draft workflow
- **Admin System**:
  - Session-based authentication
  - Admin dashboard
  - Article editor with rich interface
  - Media library management
- **Media Upload System**:
  - File upload with validation
  - Image dimension extraction
  - Drag-and-drop interface
  - Media library with search/filter
  - Metadata management (alt text, captions)
  - Organized storage (YYYY/MM directory structure)
- **Synchronized Radio Station**:
  - Live streaming radio with synchronized playback across all users
  - M3U and HLS (M3U8) playlist support
  - Automatic duration calculation for playlists
  - Time-based synchronization (all users hear the same position)
  - Infinite looping playback
  - Admin-managed playlist configuration
  - Full-screen audio visualizer with Web Audio API
  - Volume control and playlist viewer
  - S3/CloudFront compatible for hosted media
  - "Click to Listen Live" splash screen

## Development Priorities
See CLAUDE-FEATURE-TODO.md for detailed feature requests and priorities.

### Next Steps
1. **Portfolio Features**:
   - Create `projects` table for portfolio items
   - Add project CRUD API endpoints
   - Build project showcase pages
   - Add skills/technologies display

2. **SEO and Performance**:
   - Add meta tags and OpenGraph for social sharing
   - Generate RSS feed for blog
   - Implement site search functionality
   - Performance optimizations

3. **Content Enhancement**:
   - Consider comment system
   - Add analytics integration
   - Newsletter signup (optional)

## Development Guidelines

### Database Schemas

#### Implemented Tables
```sql
-- Articles table for blog posts
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT NOT NULL,
    excerpt TEXT,
    author VARCHAR(255),
    published_at TIMESTAMP,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    date_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_published BOOLEAN DEFAULT FALSE,
    meta_description TEXT,
    featured_image VARCHAR(255)
);

-- Tags table
CREATE TABLE tags (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) UNIQUE NOT NULL,
    slug VARCHAR(100) UNIQUE NOT NULL,
    date_added TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Article-tag relationships
CREATE TABLE article_tags (
    article_id INTEGER REFERENCES articles(id) ON DELETE CASCADE,
    tag_id INTEGER REFERENCES tags(id) ON DELETE CASCADE,
    PRIMARY KEY (article_id, tag_id)
);

-- Admin users
CREATE TABLE admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(128) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Media files
CREATE TABLE media (
    id SERIAL PRIMARY KEY,
    filename VARCHAR(255) NOT NULL,
    original_filename VARCHAR(255) NOT NULL,
    filepath VARCHAR(512) NOT NULL,
    mime_type VARCHAR(100) NOT NULL,
    file_size INTEGER NOT NULL,
    width INTEGER,
    height INTEGER,
    uploaded_by INTEGER REFERENCES admin_users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    alt_text TEXT,
    caption TEXT
);
```

#### Recommended for Portfolio
```sql
-- Projects table for portfolio items
CREATE TABLE projects (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    description TEXT NOT NULL,
    tech_stack TEXT[], -- PostgreSQL array for technologies
    demo_url VARCHAR(255),
    github_url VARCHAR(255),
    featured_image VARCHAR(255),
    display_order INTEGER DEFAULT 0,
    is_featured BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### API Development Standards
- Follow RESTful conventions
- Use OpenAPI specifications for all endpoints
- Implement proper HTTP status codes
- Include pagination for list endpoints
- Add filtering and sorting capabilities
- Implement proper error handling and logging

### Frontend Component Architecture
- Create reusable components for articles, projects, and navigation
- Use Vue 3 Composition API for complex components
- Implement responsive design with mobile-first approach
- Add loading states and error handling
- Use semantic HTML and accessibility best practices

### Media Upload Configuration

The media upload system is configured via environment variables:

```env
UPLOADS_DIR=/usr/src/hello-perld/uploads
UPLOAD_MAX_SIZE=5242880  # 5MB in bytes
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
```

**CRITICAL**: `UPLOADS_DIR` must **always** be set to `/usr/src/hello-perld/uploads` - the **container path**, not the host path. Docker handles mapping the host storage to this container path via volume mounts.

**Storage Structure**:
- Files stored in date-based directories: `uploads/YYYY/MM/`
- Unique filenames generated using SHA-256 hash (16 chars + extension)
- Accessible via `/uploads/YYYY/MM/filename.ext` URL path

**Storage Configuration by Environment**:

**Development** - Docker named volume:
```yaml
# docker-compose.yml
volumes:
  - uploads_data:/usr/src/hello-perld/uploads  # Docker-managed volume
```

**Staging** - DigitalOcean block storage bind mount:
```yaml
# docker-compose.staging.yml
volumes:
  - /mnt/volume_sfo3_01/hello-perld-staging/uploads:/usr/share/nginx/html/uploads:ro  # Host bind mount
```

**Production** - DigitalOcean block storage bind mount:
```yaml
# docker-compose.production.yml
volumes:
  - /mnt/volume_nyc3_01/hello-perld-prod/uploads:/usr/src/hello-perld/uploads  # Host bind mount
```

Both staging and production environments use the same DigitalOcean block storage volume mounted on the host at `/mnt/volume_nyc3_01/`, with separate directories for environment isolation.

**Setting up Block Storage on Servers**:

**Staging server**:
```bash
# On staging server, create directory with proper permissions
sudo mkdir -p /mnt/volume_nyc3_01/hello-perld-staging/uploads
sudo chown -R 1000:1000 /mnt/volume_nyc3_01/hello-perld-staging/uploads
sudo chmod -R 755 /mnt/volume_nyc3_01/hello-perld-staging/uploads
```

**Production server**:
```bash
# On production server, create directory with proper permissions
sudo mkdir -p /mnt/volume_nyc3_01/hello-perld-prod/uploads
sudo chown -R 1000:1000 /mnt/volume_nyc3_01/hello-perld-prod/uploads
sudo chmod -R 755 /mnt/volume_nyc3_01/hello-perld-prod/uploads
```

User ID 1000 is the default non-root user in the Docker container (appuser)

**File Validation**:
- Type checking against allowed MIME types
- Size validation (configurable max size)
- Image dimension extraction (width/height)
- Metadata support (alt text, caption)

### Security Considerations

**Authentication & Session Security:**
- Admin endpoints protected by session-based authentication (24-hour expiration)
- bcrypt password hashing with backward compatibility for legacy SHA-256 passwords
- Environment-specific session cookie security:
  - Development: `httponly=1`, `samesite=Lax` (HTTP allowed)
  - Production: `secure=1`, `httponly=1`, `samesite=Strict` (HTTPS only)
- Session secrets are environment-specific and never committed to version control

**CSRF Protection Architecture:**
- Comprehensive CSRF token system using HMAC-SHA256 with session binding
- All state-changing operations (POST/PUT/DELETE) require valid CSRF tokens
- Frontend automatic integration via `composables/useCSRF.js` with axios interceptors
- Tokens included in login/logout responses and available via `/api/csrf-token`
- Automatic retry on token failures with fresh token fetch

**Content Security Policy (CSP):**
- Modern XSS protection with restrictive CSP headers applied to all responses
- Blocks inline scripts and eval() for maximum security
- Allows inline styles for Vue.js component compatibility
- Restricts all resource loading to same origin only
- Prevents embedding in frames and plugin execution

**Rate Limiting (Defense in Depth):**
- **Layer 1 (nginx)**: 30 requests/hour per IP with burst=5 (volume attack protection)
- **Layer 2 (Application)**: 5 attempts/15min per username (credential attack protection)
- File-based persistence at `/tmp/hello-perld-rate-limits.json` (survives restarts)
- Automatic cleanup of expired entries (15-minute TTL)

**Input Validation & Injection Prevention:**
- All database queries use prepared statements with parameterized queries
- Schema name validation with whitelist patterns and SQL injection detection
- File upload validation with magic number checking and MIME type validation
- SVG content validation to prevent embedded script execution
- Wildcard escaping in search queries to prevent LIKE injection

**Migration Security:**
- Comprehensive validation of Perl migration files with content security scanning
- Path traversal protection using canonical path validation
- Dangerous pattern detection (system calls, file operations, network access)
- Execution in Perl taint mode (`-T` flag) for additional security
- Strict filename format validation for SQL and Perl migrations

**File Upload Security:**
- Type validation against allowed MIME types with magic number verification
- Size validation (configurable via `UPLOAD_MAX_SIZE`)
- Image dimension extraction and validation using Imager library
- Unique filename generation with SHA-256 hashing
- Organized storage with date-based directory structure (`uploads/YYYY/MM/`)

**Additional Security Headers:**
- X-Frame-Options: DENY (prevents clickjacking)
- X-Content-Type-Options: nosniff (prevents MIME sniffing)
- X-XSS-Protection: 1; mode=block (legacy XSS protection)
- Referrer-Policy: strict-origin-when-cross-origin
- Content Security Policy (detailed above)

### Miscellaneous Code Styling
- No emoji use at all in code or comments

## Current File Locations

### Frontend Components
- `frontend/src/views/HomePage.vue` - Landing page with latest articles
- `frontend/src/views/AboutPage.vue` - About page
- `frontend/src/views/ArticlesPage.vue` - Article listing with tag filtering
- `frontend/src/views/ArticlePage.vue` - Individual article display
- `frontend/src/views/AdminDashboard.vue` - Admin content management
- `frontend/src/views/AdminMedia.vue` - Media library page
- `frontend/src/components/NavBar.vue` - Main navigation
- `frontend/src/components/ArticleEditor.vue` - Article creation/editing
- `frontend/src/components/ImageUploader.vue` - Image upload component
- `frontend/src/components/MediaLibrary.vue` - Media grid with search

### Frontend Security & Composables
- `frontend/src/composables/useCSRF.js` - CSRF token management with axios interceptors
- `frontend/src/composables/useAudioPlayer.js` - Audio player state management and playback
- `frontend/src/composables/useRadioStore.js` - Global radio singleton store

### Backend Controllers
- `lib/HelloPerld.pm` - Main application with route definitions
- `lib/HelloPerld/Controller/Articles.pm` - Article endpoints
- `lib/HelloPerld/Controller/Tags.pm` - Tag endpoints
- `lib/HelloPerld/Controller/Auth.pm` - Authentication endpoints
- `lib/HelloPerld/Controller/Media.pm` - Media upload/management endpoints

### Backend Models & Data
- `lib/HelloPerld/Model/Article.pm` - Article database operations
- `lib/HelloPerld/Model/Tag.pm` - Tag database operations
- `lib/HelloPerld/Model/Media.pm` - Media database operations
- `lib/HelloPerld/Database/Postgres.pm` - DB connection & migrations

### Backend Security
- `lib/HelloPerld/Security/CSRF.pm` - CSRF token generation and validation

### API Documentation
- `swagger/swagger.json` - OpenAPI 3.0.3 specification

### Configuration Files
- `docker-compose.yml` - Multi-service development environment
- `.env` - Environment variables (database, admin credentials, upload config)
- `Makefile.PL` - Perl dependencies

## Helpful Context for Claude

When working on TheBoosh.Zone:

1. **Always maintain the existing Perl/Mojolicious architecture** - don't suggest switching to other frameworks
2. **Preserve the Vue 3 frontend structure** - build upon the existing SPA architecture
3. **Use PostgreSQL features effectively** - leverage arrays, JSON columns, and advanced queries where appropriate
4. **Follow the existing code style** - match the current Perl and Vue.js conventions used in the project
5. **Consider SEO from the start** - this is a personal website that should rank well in search engines
6. **Design for mobile-first** - ensure responsive design for all new components
7. **Maintain the monitoring setup** - ensure new endpoints are properly logged and monitored
8. **Follow media upload patterns** - use the established MediaLibrary and ImageUploader components

## Environment Setup Notes

The project uses Docker for development. Key services:
- `hello-perld` (port 3000) - Main application
- `db` (port 5432) - PostgreSQL database
- `prometheus` (port 9090) - Metrics collection
- `grafana` (port 3001) - Monitoring dashboards

**Docker Volumes**:
- `postgres_data` - Database persistence
- `uploads_data` - Media file storage
- `prometheus_data` - Metrics storage
- `grafana_data` - Grafana configuration

**Environment Variables**:
```env
# Database
POSTGRES_DB=thebooshzone_dev
POSTGRES_USER=theboosh_user
POSTGRES_PASSWORD=<secure_password>
POSTGRES_HOST=db

# Admin User
ADMIN_USERNAME=admin
ADMIN_EMAIL=admin@example.com
ADMIN_PASSWORD=<secure_password>

# Media Upload
UPLOADS_DIR=/usr/src/hello-perld/uploads
UPLOAD_MAX_SIZE=5242880
UPLOAD_ALLOWED_TYPES=image/jpeg,image/png,image/gif,image/webp,image/svg+xml
```

## API Endpoints Reference

### Public Endpoints
- `GET /health` - Health check
- `GET /api/articles` - List published articles (pagination, tag filtering)
- `GET /api/articles/{slug}` - Get article by slug
- `GET /api/tags` - List all tags
- `GET /api/tags/popular` - Most popular tags
- `GET /api/tags/search?q=<query>` - Search tags

### Authentication
- `POST /api/auth/login` - Admin login (returns CSRF token)
- `POST /api/auth/logout` - Admin logout (requires CSRF token)
- `GET /api/auth/status` - Check authentication status
- `GET /api/csrf-token` - Get fresh CSRF token for authenticated users

### Security
- `POST /api/auth/change-password` - Change admin password (requires CSRF token)

### Admin - Articles (All write operations require CSRF token)
- `GET /api/admin/articles` - List all articles (including drafts)
- `POST /api/admin/articles` - Create new article (requires CSRF token)
- `GET /api/admin/articles/{id}` - Get article by ID
- `PUT /api/admin/articles/{id}` - Update article (requires CSRF token)
- `DELETE /api/admin/articles/{id}` - Delete article (requires CSRF token)

### Admin - Media (All write operations require CSRF token)
- `POST /api/admin/media/upload` - Upload media file (requires CSRF token)
- `GET /api/admin/media` - List media files (pagination, search, filter)
- `GET /api/admin/media/{id}` - Get media by ID
- `PUT /api/admin/media/{id}` - Update media metadata (requires CSRF token)
- `DELETE /api/admin/media/{id}` - Delete media file (requires CSRF token)

### Admin - Tags (All write operations require CSRF token)
- `GET /api/admin/tags` - List all tags (admin view)
- `POST /api/admin/tags` - Create new tag (requires CSRF token)
- `PUT /api/admin/tags/{id}` - Update tag (requires CSRF token)
- `DELETE /api/admin/tags/{id}` - Delete tag (requires CSRF token)

## Lessons Learned & Important Implementation Notes

### Docker Development Workflow

**CRITICAL**: This project uses modern Docker Compose commands and requires explicit rebuilds.

1. **Use `docker compose` (not `docker-compose`)**:
   ```bash
   # CORRECT
   docker compose up -d
   docker compose down

   # INCORRECT (old syntax)
   docker-compose up -d
   docker-compose down
   ```
   The project uses Docker Compose V2 which is invoked as `docker compose` (space, not hyphen).

2. **Always rebuild after code changes**:
   ```bash
   # Standard workflow after ANY code changes
   docker compose down
   docker compose up -d --build
   ```

   **Why this matters**:
   - The project does NOT use the `--watch` flag or volume mounting for code
   - Code changes are baked into the Docker image during build
   - Without `--build`, you'll be testing old code even after making changes
   - This includes changes to Perl modules, tests, migrations, and configuration files

   **Exception**: Static files mounted via volumes (like `uploads/`) don't require rebuild.

### Admin Authentication Flow

**Current Status**: Fully implemented and working

The admin authentication system is complete with:
- Session-based authentication (24-hour expiration)
- Password hashing with SHA-256 and random salt (96 hex chars: 32 salt + 64 hash)
- Rate limiting (5 attempts per 15 minutes)
- Admin login page at `/admin/login`

**Key Implementation Details**:

1. **Admin User Management**:
   - Admin credentials stored in `.env` file (`ADMIN_USERNAME`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`)
   - Password must be hashed before storing in database
   - Use `script/update_admin_password` to update passwords securely
   - Never store plaintext passwords

2. **Login Flow**:
   ```
   User submits credentials → Auth#login controller
   → _authenticate_user() queries database
   → _verify_password() checks hash
   → Session created with admin_user_id, admin_username, admin_email
   → User redirected to /admin dashboard
   ```

3. **Common Pitfalls**:
   - CRITICAL: Don't return from inside `eval {}` blocks - The return will exit the eval, not the function

     **This bug affected EVERY model method in the codebase!** All database queries wrapped in eval blocks were silently failing because return values were getting lost.

     ```perl
     # WRONG - return gets lost in eval (returns from eval, not function)
     eval {
         my $sth = $dbh->prepare($sql);
         $sth->execute(@params);
         my $result = $sth->fetchrow_hashref();
         $dbh->disconnect();
         return $result;  # This only exits eval!
     };
     # Function returns undef, not $result

     # CORRECT - store value, return after eval
     my $result;
     eval {
         my $sth = $dbh->prepare($sql);
         $sth->execute(@params);
         $result = $sth->fetchrow_hashref();
         $dbh->disconnect();
     };

     if ($@) {
         # Handle error
         return undef;
     }

     return $result;  # This returns from the function
     ```

     **Methods Fixed:**
     - `HelloPerld::Model::Tag::create()`
     - `HelloPerld::Model::Tag::get_by_name()`
     - `HelloPerld::Model::Article::get_all()`
     - `HelloPerld::Model::Article::get_by_slug()`
     - `HelloPerld::Model::Article::get_by_id()`
     - `HelloPerld::Model::Article::create()`
     - `HelloPerld::Model::Article::update()`
     - `HelloPerld::Model::Article::delete()`
     - `HelloPerld::Model::Media::*` - All media model methods follow correct pattern

     **Check ALL eval blocks in new code for this pattern!**

   - CRITICAL: Always call `$sth->finish()` before `$dbh->disconnect()` - Disconnecting before finishing statement handles corrupts fetched data

     **This was the root cause of article/tag association failures!** When `disconnect()` is called on an active statement handle (one that hasn't been finished), DBI invalidates the handle and any data fetched from it may be corrupted or lost.

     ```perl
     # WRONG - disconnect before finish corrupts data
     eval {
         my $sth = $dbh->prepare($sql);
         $sth->execute(@params);
         my $result = $sth->fetchrow_hashref();
         $dbh->disconnect();  # ❌ Invalidates active statement handle!
     };
     # Warning: "disconnect invalidates 1 active statement handle"
     # $result may be corrupted or incomplete

     # CORRECT - finish before disconnect
     my $result;
     eval {
         my $sth = $dbh->prepare($sql);
         $sth->execute(@params);
         $result = $sth->fetchrow_hashref();
         $sth->finish();       # ✅ Properly clean up statement handle
         $dbh->disconnect();   # ✅ Safe to disconnect now
     };
     ```

     **Why This Matters**:
     - `finish()` releases resources and marks the statement handle as complete
     - Skipping `finish()` before `disconnect()` triggers warnings AND data corruption
     - Fetched data may appear valid in tests but fail intermittently in production
     - This pattern MUST be followed for ALL fetch operations: `fetchrow_hashref()`, `fetchrow_array()`, `fetchall_arrayref()`, etc.

     **All Statement Handles Fixed**:
     - `HelloPerld::Model::Tag::*` - All methods with fetch operations
     - `HelloPerld::Model::Article::*` - All methods with fetch operations
     - `HelloPerld::Controller::Auth::_authenticate_user()` - User lookup

     **Golden Rule**: Always call `$sth->finish()` after fetching data and before calling `$dbh->disconnect()`

   - Parse JSON request bodies correctly - OpenAPI plugin requires special handling:
     ```perl
     # Support both OpenAPI and standard Mojolicious routing
     my $body = $self->req->json || {};
     my $username = $self->param('username') || $body->{username};
     my $password = $self->param('password') || $body->{password};
     ```

4. **Testing Admin Login**:
   ```bash
   # Login via API
   curl -X POST http://localhost:3000/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"admin","password":"your_secure_admin_password"}' \
     -c cookies.txt

   # Check authentication status
   curl -b cookies.txt http://localhost:3000/api/auth/status
   ```

### Article Creation & Management Flow

**Current Status**: Backend complete, Frontend ready

**Creating an Article via API**:
```bash
curl -X POST http://localhost:3000/api/admin/articles \
  -b cookies.txt \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Article",
    "content": "Article content in **Markdown**",
    "excerpt": "Short description",
    "is_published": true,
    "tags": ["tech", "blog"]
  }'
```

**Article Creation Flow**:
1. User authenticates via `/admin/login`
2. Navigate to admin dashboard (`/admin`)
3. Use ArticleEditor component to create/edit content
4. Submit to `POST /api/admin/articles`
5. Controller processes tags (creates if needed)
6. Auto-generates slug from title if not provided
7. Sets `published_at` timestamp if publishing
8. Returns created article with ID

**Important Notes**:
- Tags are created automatically if they don't exist
- Slugs must be unique (enforced by database)
- Markdown content is stored as-is, rendered on frontend
- Unpublished articles only visible to authenticated admins

### Media Upload & Management Flow

**Current Status**: Fully implemented and working

The media upload system includes:
- File upload with type and size validation
- Image dimension extraction (width/height)
- Unique filename generation with SHA-256
- Date-based directory organization (YYYY/MM)
- Media library with search and filtering
- Metadata editing (alt text, captions)
- Admin-only access with session auth

**Uploading Media via API**:
```bash
curl -X POST http://localhost:3000/api/admin/media/upload \
  -b cookies.txt \
  -F "file=@/path/to/image.jpg" \
  -F "alt_text=Description of image" \
  -F "caption=Optional caption"
```

**Media Upload Flow**:
1. User authenticates and navigates to `/admin/media`
2. Drag and drop file or click to select
3. Client-side validation (type, size)
4. Preview displayed with metadata inputs
5. Click "Upload" to send to `POST /api/admin/media/upload`
6. Server validates file, extracts dimensions
7. Generates unique filename (SHA-256 hash)
8. Creates date-based directory structure
9. Saves file to `uploads/YYYY/MM/filename.ext`
10. Records metadata in `media` table
11. Returns media object with URL

**Using Media Library Component**:
```vue
<MediaLibrary
  selection-mode="single"
  @media-selected="handleMediaSelected"
/>
```

**Important Notes**:
- Files stored in Docker volume `uploads_data` (persistent)
- Filenames are unique (16-char hash + extension)
- Directory structure: `/uploads/YYYY/MM/filename.ext`
- URL path: `/uploads/YYYY/MM/filename.ext`
- Maximum file size configurable via `UPLOAD_MAX_SIZE` env var
- Allowed types configurable via `UPLOAD_ALLOWED_TYPES` env var
- Image dimensions extracted automatically for image files
- Physical file deleted when media record is deleted

**Perl Modules Required for Media Upload**:
```perl
# In Makefile.PL
'Imager'           => 0,  # Image processing and dimension extraction
'File::Path'       => 0,  # Directory creation
'File::Copy'       => 0,  # File operations
'File::Basename'   => 0,  # Filename parsing
'MIME::Types'      => 0,  # MIME type handling
'Digest::SHA'      => 0,  # Hash generation for unique filenames
```

### Synchronized Radio Station Flow

**Overview**: The Radio feature provides a synchronized streaming experience where all users hear the same audio at the same time, similar to traditional radio broadcasting.

**Architecture**:
- **Backend**: Perl/Mojolicious with PostgreSQL
- **Frontend**: Vue 3 with Web Audio API, HLS.js for streaming
- **Storage**: S3/CloudFront or local file storage
- **Sync Method**: Time-based calculation from playlist upload timestamp

**Database Schema** (`migrations/008_create_radio_config_table.sql` and `009_add_radio_sync_fields.sql`):
```sql
CREATE TABLE radio_config (
    id SERIAL PRIMARY KEY,
    config_key VARCHAR(255) NOT NULL UNIQUE,
    config_value TEXT NOT NULL,
    description TEXT,
    total_duration INTEGER,  -- Playlist duration in seconds
    updated_by INTEGER REFERENCES admin_users(id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Synchronization Logic**:
1. Admin uploads playlist URL → Backend calculates total duration
2. `updated_at` timestamp serves as the "radio station start time"
3. User requests sync info → Backend calculates:
   - `elapsed = current_server_time - updated_at`
   - `position = elapsed % total_duration` (modulo for looping)
   - Determines current track index and position within track
4. Frontend loads track and seeks to calculated position
5. Playback starts automatically after user clicks "Listen Live"

**Playlist Format Support**:

*M3U Playlists*:
```m3u
#EXTM3U
#EXTINF:180,Artist - Song Title
https://example.com/song.mp3
#EXTINF:240,Artist - Another Song
https://example.com/song2.mp3
```

*HLS Streams (M3U8)*:
- Supports both master playlists and media playlists
- Auto-detects VOD vs Live streams
- Calculates duration from `#EXTINF` segment durations
- Requires `#EXT-X-ENDLIST` tag for VOD detection

**Backend Implementation** (`lib/HelloPerld/Controller/Radio.pm`):

Key Methods:
- `get_playlist()` - Public endpoint to fetch playlist URL
- `get_sync_info()` - Public endpoint for synchronization data
- `update_playlist()` - Admin endpoint to update playlist (calculates duration)
- `delete_playlist()` - Admin endpoint to remove playlist
- `_calculate_playlist_duration()` - Parses M3U/M3U8 and sums durations
- `_parse_m3u()` - Extracts track info from M3U format

**Frontend Implementation**:

*Audio Player* (`frontend/src/composables/useAudioPlayer.js`):
- `loadPlaylistWithSync()` - Fetches sync info and loads at correct position
- `syncToPosition()` - Syncs to specific track and time offset
- Auto-looping: When track ends, loads next track or loops to beginning
- HLS.js integration for M3U8 streams

*Radio Page* (`frontend/src/views/RadioPage.vue`):
- Full-screen visualizer using Web Audio API
- "Click to Listen Live" splash screen (browser autoplay requirement)
- Volume control and playlist viewer (read-only)
- No playback controls (play/pause/skip) - true radio station experience

*Audio Visualizer* (`frontend/src/composables/useAudioVisualizer.js`):
- Web Audio API with AnalyserNode
- Particle-based abstract visualization
- Canvas rendering with RequestAnimationFrame
- Retro-futuristic styling (pink/silver theme)

**CORS Configuration for S3**:
```json
[
    {
        "AllowedHeaders": ["*"],
        "AllowedMethods": ["GET", "HEAD"],
        "AllowedOrigins": [
            "http://localhost:3000",
            "https://yourdomain.com"
        ],
        "ExposeHeaders": [
            "Content-Length",
            "Content-Type",
            "Content-Range"
        ],
        "MaxAgeSeconds": 3600
    }
]
```

**CSP Configuration**:
```perl
"media-src 'self' blob: https:",     # Audio/video from HTTPS sources
"connect-src 'self' https:",         # XHR/fetch for HLS manifests
```

**API Endpoints**:

Public:
- `GET /api/radio/playlist?parse=1` - Get playlist with tracks
- `GET /api/radio/sync-info` - Get synchronization data

Admin (requires session auth + CSRF):
- `GET /api/admin/radio/config` - Get current configuration
- `POST /api/admin/radio/playlist` - Update playlist URL
- `DELETE /api/admin/radio/playlist` - Delete playlist

**Sync Info Response**:
```json
{
  "success": true,
  "sync_info": {
    "configured": true,
    "server_time": 1700000000,
    "playlist_start_time": 1699999000,
    "playlist_url": "https://...",
    "total_duration": 1800,
    "elapsed_time": 1000,
    "current_position": 100,
    "current_track_index": 2,
    "is_hls": false
  }
}
```

**Important Notes**:
- All users synchronized within ±1 second accuracy
- Playlist loops infinitely until admin uploads new playlist
- HLS master playlists automatically resolved to media playlists
- Duration calculation handles both M3U and HLS VOD formats
- Live HLS streams (no `#EXT-X-ENDLIST`) treated as infinite duration
- Browser autoplay policies require user interaction before playback
- Media Session API integration for OS-level controls

**Troubleshooting**:
- If sync is incorrect, check `total_duration` is not NULL in database
- For HLS, ensure manifest has `#EXT-X-ENDLIST` tag for VOD detection
- CORS errors: Configure S3 bucket or use CloudFront
- Playback issues: Check CSP headers allow media-src and connect-src

### Radio Player Architecture & State Management

**Overview**: The radio player uses a singleton pattern with lazy initialization to handle browser autoplay policies and maintain consistent state across components.

**Initialization Lifecycle**:
1. `useRadioStore()` creates singleton `useAudioPlayer()` instance (no init yet)
2. `App.vue` `onMounted` → `await nextTick()` → ensures Vue render cycle complete
3. Audio element initialized: `await radioStore.player.init()`
4. Playlist loaded and synced: `await radioStore.player.loadPlaylistWithSync()`
5. Audio ready but **not playing** (respects browser autoplay policy)
6. User interaction required to start playback

**Key Architectural Decisions**:

*Lazy Initialization Pattern*:
```javascript
// useRadioStore.js - Store creation
if (!playerInstance) {
    playerInstance = useAudioPlayer();
    // Note: init() NOT called here - done lazily in App.vue
}

// App.vue - onMounted
if (!radioStore.player.audio.value) {
    await radioStore.player.init(); // Lazy initialization
}
```

*Browser Autoplay Policy Compliance*:
- **Never** attempt auto-play on page load
- Auto-play blocked by browsers until user interacts with page
- Both new and returning users must click to start playback
- Removed auto-play attempt from App.vue (was causing `NotAllowedError`)

**State Management**:

*Core Reactive States*:
- `audio` - HTML Audio element (ref)
- `isPlaying` - Currently playing (boolean)
- `isLoading` - Buffering/loading track (boolean)
- `currentTrack` - Current track info (computed)
- `volume` - Volume 0-100 (ref)
- `playlist` - Array of tracks (ref)

*User State (useRadioStore)*:
- `hasListened` - User has clicked "Listen Live" before (boolean)
  - Used for: Volume restoration logic only
  - **NOT** used for: Button visibility (common mistake!)

**Play/Pause Control Visibility Pattern**:

The critical pattern for consistent UX:

```vue
<!-- RadioWidget.vue & VisualizerPage.vue -->
<button v-if="!player.isPlaying.value">
    Listen Live / Play
</button>
<button v-else>
    Pause
</button>
```

**Why `isPlaying` not `hasListened`**:
- `hasListened` is user history, persists across sessions
- `isPlaying` is current playback state, resets on page load
- After page refresh, audio is **not playing** → show play button
- Ensures users can always resume playback after refresh

**Component Coordination**:

*RadioWidget.vue*:
- Shows "Listen Live" button when `!isPlaying`
- Shows "Pause" button when `isPlaying`
- Includes buffering spinner in buttons
- Calls `restoreUserVolume()` on first interaction
- Calls `player.play()` to start playback

*VisualizerPage.vue*:
- Shows full-screen "Click to Listen Live" overlay when `!isPlaying`
- Overlay disappears when `isPlaying`
- Bottom controls include play/pause button
- Same `startListening()` logic as widget

*App.vue*:
- Initializes audio element on mount
- Loads and syncs playlist
- Sets initial volume (0 for new users, saved for returning users)
- Does **NOT** auto-play (waits for user interaction)

**Buffering Indicators**:

Multiple indicators provide clear feedback:
1. Button spinner: Shows in play button when `isLoading`
2. Track info: Shows "Buffering..." text when `isLoading`
3. Progress overlay: Full-screen spinner for long loads

```vue
<!-- Button with loading state -->
<button :disabled="player.isLoading.value">
    <div v-if="player.isLoading.value" class="spinner-small" />
    <svg v-else><!-- play icon --></svg>
</button>

<!-- Track info with loading state -->
<div v-if="player.isLoading.value" class="loading-state">
    <div class="spinner-small" />
    <span>Buffering...</span>
</div>
```

**Proper Async Pattern**:

Always use `nextTick()` not `setTimeout()`:
```javascript
// CORRECT - Vue lifecycle aware
await nextTick();
if (!radioStore.player.audio.value) {
    await radioStore.player.init();
}

// WRONG - Arbitrary timing, race conditions
await new Promise(resolve => setTimeout(resolve, 100));
```

**Common Pitfalls Avoided**:

1. ❌ Auto-playing on page load → Browser blocks with `NotAllowedError`
   ✅ Wait for user interaction, show play button

2. ❌ Hiding play button based on `hasListened` → No way to resume after refresh
   ✅ Show play button based on `isPlaying` state

3. ❌ Calling `play()` before audio element ready → Silent failure
   ✅ Lazy init with proper async/await chain

4. ❌ Using `setTimeout()` for initialization timing → Race conditions
   ✅ Use `nextTick()` for Vue lifecycle integration

5. ❌ Initializing audio element in store creation → Too early, no DOM
   ✅ Lazy init in App.vue onMounted after nextTick

**Volume Restoration Logic**:

First-time users:
```javascript
if (!hasListened) {
    radioStore.player.setVolume(0); // Muted
    localStorage.setItem("radio_saved_volume", savedVolume);
}
```

On "Listen Live" click:
```javascript
function restoreUserVolume() {
    userState.hasListened = true; // Mark as listened
    const saved = localStorage.getItem("radio_saved_volume");
    player.setVolume(saved ? parseInt(saved) : 70);
}
```

### Mojolicious OpenAPI Route Configuration

**CRITICAL**: Routes defined in `swagger/swagger.json` MUST include `x-mojo-to` directive!

**Problem**: Without `x-mojo-to`, Mojolicious OpenAPI plugin looks for templates instead of controller actions, resulting in:
```
Template "getArticles.html.ep" not found
Route without action and nothing to render
```

**Solution**: Add `x-mojo-to` to every route in swagger.json:

```json
{
  "/api/articles": {
    "get": {
      "summary": "List Articles",
      "operationId": "getArticles",
      "x-mojo-to": "Articles#get_all",  // REQUIRED!
      "tags": ["Articles"],
      // ... rest of definition
    }
  }
}
```

**Pattern**: `"x-mojo-to": "ControllerName#method_name"`
- `ControllerName` maps to `lib/HelloPerld/Controller/ControllerName.pm`
- `method_name` is the subroutine in that controller
- Mojolicious automatically prepends `HelloPerld::Controller::` namespace

**All Routes Requiring x-mojo-to**:
- `/api/articles` → `Articles#get_all`
- `/api/articles/{slug}` → `Articles#get_by_slug`
- `/api/auth/login` → `Auth#login`
- `/api/auth/logout` → `Auth#logout`
- `/api/auth/status` → `Auth#status`
- `/api/tags` → `Tags#get_all`
- `/api/tags/popular` → `Tags#get_popular`
- `/api/tags/search` → `Tags#search`
- `/api/admin/media/upload` → `Media#upload`
- `/api/admin/media` → `Media#get_all`
- `/api/admin/media/{id}` (GET) → `Media#get_by_id`
- `/api/admin/media/{id}` (PUT) → `Media#update`
- `/api/admin/media/{id}` (DELETE) → `Media#delete`

**Note**: Admin routes under `/api/admin/*` are protected by authentication middleware in `lib/HelloPerld.pm`

### Adding New Perl Module Dependencies

**CRITICAL**: When adding new Perl modules to controllers or libraries, they MUST be added to `Makefile.PL`!

**Problem**: If a module is used but not in `Makefile.PL`, it won't be installed during Docker build:
```perl
use Crypt::Random qw(makerandom_octet);  # Used in code
# But not in Makefile.PL → Docker build succeeds but app crashes!
```

**Solution**: Update `Makefile.PL` PREREQ_PM section:

```perl
WriteMakefile(
    NAME         => 'HelloPerld',
    VERSION      => '1.0',
    PREREQ_PM    => {
        'DBD::Pg'             => 0,
        'DBI'                 => 0,
        'Crypt::Random'       => 0,  # ADD NEW MODULES HERE
        'Digest::SHA'         => 0,  # WITH VERSION (0 = any)
        # ... existing modules
    },
);
```

**After updating Makefile.PL**:
1. Rebuild Docker image: `docker-compose build hello-perld`
2. Restart containers: `docker-compose up -d`
3. Verify module loads: `docker exec thebooshzone-hello-perld-1 perl -MYourModule -e "print 'OK'"`

**Common Modules Already Included**:
- `DBI` / `DBD::Pg` - Database connectivity
- `Mojolicious` - Web framework
- `Mojolicious::Plugin::OpenAPI` - API routing
- `Mojolicious::Plugin::SwaggerUI` - API documentation UI
- `JSON` - JSON parsing
- `Crypt::Random` - Cryptographic random number generation
- `Digest::SHA` - SHA hashing (for passwords and filenames)
- `Time::Local` - Timestamp handling
- `File::ShareDir` - Shared file management
- `Imager` - Image processing and dimension extraction
- `File::Path` - Directory creation
- `File::Copy` - File operations
- `File::Basename` - Filename parsing
- `MIME::Types` - MIME type handling

### Docker Entrypoint Script Issues

**Problem Encountered**: `docker-entrypoint.sh` was calling Perl scripts without proper library paths.

**Solution**: When calling Perl scripts that use local modules, include the library path:
```bash
# WRONG
perl -MHelloPerld::Database::Postgres -e "..."

# CORRECT - specify library path
perl -I/usr/src/hello-perld/lib -MHelloPerld::Database::Postgres -e "..."
```

**Current entrypoint script** (`docker-entrypoint.sh`) properly includes `-I/usr/src/hello-perld/lib` for database validation.

### Radio Player Race Condition & Browser Autoplay

**Problem Encountered**: Radio player had intermittent failures on first page load where audio would not play.

**Root Causes Identified**:

1. **Missing `play()` call in RadioWidget** (First-time users):
   - `handleListenLive()` function restored volume but never called `player.play()`
   - Fixed by adding `player.play()` call after `restoreUserVolume()`

2. **Browser Autoplay Policy Violation** (Returning users):
   - App.vue attempted auto-play on page load for returning users
   - Browsers block autoplay until user interaction: `NotAllowedError: play() failed because the user didn't interact with the document first`
   - Fixed by removing auto-play attempt entirely

3. **Incorrect Button Visibility Logic** (Returning users):
   - "Listen Live" button hidden based on `!userState.hasListened`
   - After removing auto-play, returning users had no way to resume after page refresh
   - Fixed by changing condition to `!player.isPlaying.value`

**Solutions Implemented**:

*Use `nextTick()` not `setTimeout()` for Vue initialization*:
```javascript
// WRONG - Arbitrary timing
await new Promise(resolve => setTimeout(resolve, 100));

// CORRECT - Vue lifecycle aware
await nextTick();
```

*Lazy initialization pattern*:
- Audio element created in `App.vue` `onMounted`, NOT in store creation
- Ensures Vue DOM is ready before creating audio element
- Prevents "too early" initialization race conditions

*Button visibility based on playback state*:
```vue
<!-- WRONG - Based on user history -->
<button v-if="!userState.hasListened">Listen Live</button>

<!-- CORRECT - Based on current state -->
<button v-if="!player.isPlaying.value">Listen Live</button>
<button v-else>Pause</button>
```

*Never auto-play on page load*:
- Both new and returning users must click to start playback
- Respects browser autoplay policies
- Consistent user experience

**Key Takeaways**:
1. Browser autoplay policies are strict - always require user interaction
2. Use playback state (`isPlaying`) not user history (`hasListened`) for UI visibility
3. `nextTick()` ensures Vue render cycle completes before DOM manipulation
4. Lazy initialization prevents "audio element not ready" race conditions
5. Always call `player.play()` after user interaction - don't assume it happens automatically

### Database Connection Best Practices

**CRITICAL: Always use HelloPerld::Model::Base for new models!**

All model classes MUST inherit from `HelloPerld::Model::Base` which provides:
- Consistent database connection handling via `_get_dbh()`
- Automatic config-based or default connection fallback
- Built-in logging helpers (`_log_error()`, `_log_info()`)
- Proper error handling and connection cleanup

**Model Structure Pattern**:
```perl
package HelloPerld::Model::YourModel;

use strict;
use warnings;

our $VERSION = '1.0.0';

use parent 'HelloPerld::Model::Base';  # REQUIRED!

# Your model methods here
sub get_something {
    my ($self, $param) = @_;
    
    my $dbh = $self->_get_dbh();  # Use this, NOT db_config->connect_db()
    return undef unless $dbh;
    
    # ... database operations
}
```

**Instantiation Pattern in Controllers**:
```perl
my $model = HelloPerld::Model::YourModel->new(
    logger => $self->app->logger_instance,
    db_config => $self->db_config
);
```

**WRONG - Do NOT do this**:
```perl
# ❌ WRONG - Missing parent class
package HelloPerld::Model::Bad;
use Mojo::Base -base, -signatures;
has 'db_config';

# ❌ WRONG - Direct connect_db() call
my $dbh = $self->db_config->connect_db();
```

**Additional Best Practices**:
1. **Always disconnect after queries** to prevent "active statement handle" warnings
2. **Use eval blocks** for error handling in database operations
3. **Test connection before running migrations** (done in entrypoint script)
4. **Environment variables** for connection config:
   - `POSTGRES_HOST=db` (Docker service name)
   - `POSTGRES_PORT=5432`
   - `POSTGRES_DB=thebooshzone_dev`
   - `POSTGRES_USER=theboosh_user`
   - `POSTGRES_PASSWORD` (from .env)

### Database Migration Best Practices

**CRITICAL**: All database migrations MUST be idempotent to allow safe re-running.

**SQL Migrations** (`migrations/*.sql`):
- Always use `CREATE TABLE IF NOT EXISTS` instead of `CREATE TABLE`
- Always use `CREATE INDEX IF NOT EXISTS` instead of `CREATE INDEX`
- For other DDL operations, use appropriate idempotent forms:
  - `ALTER TABLE ... ADD COLUMN IF NOT EXISTS ...`
  - `DROP TABLE IF EXISTS ...`
  - `DROP INDEX IF EXISTS ...`

**Example Idempotent Migration**:
```sql
-- CORRECT - Idempotent
CREATE TABLE IF NOT EXISTS my_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_my_table_name ON my_table(name);

-- WRONG - Will fail on re-run
CREATE TABLE my_table (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL
);

CREATE INDEX idx_my_table_name ON my_table(name);
```

**Perl Migrations** (`migrations/*.pl`):
- Must check for existing data before inserting/updating
- Use `SELECT` queries to verify state before making changes
- Exit with code 0 if already applied (idempotent behavior)
- See `migrations/005_create_default_admin_user.pl` and `script/create_admin_user` for reference implementation

**Migration Tracking**:
- The `schema_migrations` table automatically tracks applied migrations
- Migrations are identified by their filename prefix (e.g., `001`, `002`, etc.)
- Never manually edit `schema_migrations` - let the migration system manage it
- To verify tracking: `SELECT * FROM schema_migrations ORDER BY version;`

**Testing New Migrations**:
1. Run migration on fresh database: `docker exec thebooshzone-hello-perld-1 perl script/migrate`
2. Verify schema_migrations updated: Check for new entry with migration version
3. Run migration again: Should skip already-applied migrations cleanly
4. Check for PostgreSQL notices: `NOTICE: relation "table_name" already exists, skipping` is expected and correct

### Vue Router Authentication Guards

Protected routes (admin pages) use navigation guards to check authentication:

```javascript
// In frontend/src/router/index.js
router.beforeEach(async (to, from, next) => {
  if (to.meta.requiresAuth) {
    try {
      const response = await axios.get('/api/auth/status')
      if (response.data.authenticated) {
        next()
      } else {
        next({ name: 'AdminLogin', query: { redirect: to.fullPath } })
      }
    } catch (error) {
      next({ name: 'AdminLogin', query: { redirect: to.fullPath } })
    }
  } else {
    next()
  }
})
```

**Protected Routes**:
- `/admin` - Admin dashboard (requires auth)
- `/admin/media` - Media library (requires auth)

### Testing Checklist for New Features

When adding new functionality:

1. **Backend**:
   - [ ] Controller method implemented
   - [ ] Database queries use prepared statements
   - [ ] OpenAPI route includes `x-mojo-to`
   - [ ] Swagger schema defined
   - [ ] Authentication/authorization checked where needed
   - [ ] Error handling with proper HTTP status codes
   - [ ] Logging added for important operations

2. **Dependencies**:
   - [ ] New Perl modules added to `Makefile.PL`
   - [ ] Docker image rebuilt after Makefile changes
   - [ ] Module imports tested in container

3. **Frontend**:
   - [ ] Vue component created/updated
   - [ ] API calls handle loading and error states
   - [ ] Routes added to `router/index.js` if needed
   - [ ] Authentication guards applied to protected routes

4. **Testing**:
   - [ ] API endpoints tested with curl
   - [ ] Authentication flow works end-to-end
   - [ ] Database queries return expected results
   - [ ] Frontend displays data correctly
   - [ ] Error cases handled gracefully

5. **Media/Files** (if applicable):
   - [ ] File upload validation working
   - [ ] Files stored in correct location
   - [ ] URLs accessible from frontend
   - [ ] File deletion removes physical files
   - [ ] Docker volume configured for persistence

## Backend Testing Framework

**Status**: Fully implemented (October 2025)

TheBoosh.Zone uses the standard Perl TAP (Test Anything Protocol) testing ecosystem for comprehensive backend testing.

### Testing Stack

- **Test::More** (>= 1.302) - Core TAP-based testing framework
- **Test::Mojo** - Built-in Mojolicious web application testing
- **DBD::Mock** - Mock database driver for isolated unit tests
- **Test::Exception** - Exception and error testing
- **Test::MockModule** - Module mocking capabilities

### Test Organization

```
t/
├── 00-load.t              # Module loading verification
├── unit/                  # Pure unit tests (mocked DB)
│   ├── model/
│   │   ├── article.t      # 15+ test cases
│   │   ├── tag.t          # 20+ test cases (idempotency)
│   │   └── media.t        # 10+ test cases
│   └── database/
│       └── postgres.t     # Utility function tests
├── integration/           # Integration tests (real DB)
│   └── controller/
│       ├── health.t       # Health check endpoint
│       ├── auth.t         # Authentication (8+ cases)
│       ├── articles.t     # CRUD operations (10+ cases)
│       ├── tags.t         # Tag management (8+ cases)
│       └── media.t        # Media operations (5+ cases)
└── lib/
    └── TestHelper.pm      # Shared test utilities
```

### Running Tests

**All tests**:
```bash
./script/test
# Or: prove -l -r -v t/
```

**Unit tests only** (no database required):
```bash
./script/test-unit
```

**Integration tests only** (requires database):
```bash
./script/test-integration
```

**In Docker**:
```bash
docker exec thebooshzone-hello-perld-1 perl script/test
```

### Test Coverage

**Models (Unit Tests with DBD::Mock)**:
- Article: get_all, get_by_slug, get_by_id, create, update, delete, generate_slug, get_count
- Tag: get_all (with ordering), get_by_name, create, update, delete, search, find_or_create_by_name, get_popular_tags
- Media: create, get_all (with filters), get_by_id, update, delete, get_count

**Controllers (Integration Tests with Test::Mojo)**:
- Health: Endpoint availability, JSON structure, database validation
- Auth: Login/logout, session management, rate limiting, password verification, admin middleware
- Articles: CRUD operations, authentication checks, draft visibility, slug generation, tag associations
- Tags: Listing with ordering, popular tags, search, CRUD operations with auth, usage counts
- Media: Listing with pagination, search/filtering, authentication, upload validation

### Test Helpers (TestHelper.pm)

Shared utilities for consistent testing:

```perl
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger create_test_article_data);

my $dbh = mock_dbh();           # Mock database handle
my $logger = mock_logger();     # Test logger (ERROR only)
my $article = create_test_article_data(title => 'Custom');
```

**Available Helpers**:
- `mock_dbh()` - DBD::Mock database handle
- `mock_logger()` - Console logger for tests
- `create_test_article_data(%overrides)` - Generate test article
- `create_test_tag_data(%overrides)` - Generate test tag
- `create_test_media_data(%overrides)` - Generate test media
- `create_test_user_data(%overrides)` - Generate test user
- `setup_mock_session($t, %session)` - Mock authentication
- `mock_article_result(@articles)` - DBD::Mock article results
- `mock_tag_result(@tags)` - DBD::Mock tag results
- `mock_media_result(@media)` - DBD::Mock media results

### Writing New Tests

**Unit Test Template** (models with mocked DB):

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::MockModule;
use lib 't/lib';
use TestHelper qw(mock_dbh mock_logger);

my $postgres_mock = Test::MockModule->new('HelloPerld::Database::Postgres');
my $mock_dbh;
$postgres_mock->mock('get_connection', sub { return $mock_dbh; });

use_ok('HelloPerld::Model::YourModel');

subtest 'your test' => sub {
    $mock_dbh = mock_dbh();

    $mock_dbh->{mock_add_resultset} = {
        sql => qr/SELECT/i,
        results => [['id', 'name'], [1, 'Test']]
    };

    my $model = HelloPerld::Model::YourModel->new(logger => mock_logger());
    my $result = $model->your_method();

    ok(defined $result, 'Returns result');
};

done_testing();
```

**Integration Test Template** (controllers with Test::Mojo):

```perl
#!/usr/bin/env perl
use strict;
use warnings;
use Test::More;
use Test::Mojo;
use FindBin;
use lib "$FindBin::Bin/../../../lib";

my $t = Test::Mojo->new('HelloPerld');

subtest 'your endpoint' => sub {
    $t->get_ok('/api/your/endpoint')
      ->status_is(200)
      ->json_is('/key' => 'value')
      ->json_has('/another_key');
};

done_testing();
```

### Critical Test Patterns

**Verify these patterns from CLAUDE.md bugs are not present**:

1. **No return inside eval blocks**:
```perl
# Tests verify this pattern is followed
my $result;
eval { $result = $dbh->selectrow_hashref($sql); };
return $result;  # NOT inside eval
```

2. **Always finish() before disconnect()**:
```perl
# Tests verify statement handles are properly finished
$sth->finish();      # Before disconnect
$dbh->disconnect();
```

### Environment Variables for Integration Tests

```bash
# Database
POSTGRES_HOST=db
POSTGRES_DB=thebooshzone_dev
POSTGRES_USER=theboosh_user
POSTGRES_PASSWORD=<password>

# Admin credentials (for auth tests)
ADMIN_USERNAME=admin
ADMIN_PASSWORD=<password>
```

### CI/CD Integration

Tests are designed for easy CI/CD integration:

```yaml
# Example GitHub Actions
test:
  runs-on: ubuntu-latest
  services:
    postgres:
      image: postgres:15
      env:
        POSTGRES_DB: thebooshzone_test
        POSTGRES_USER: test_user
        POSTGRES_PASSWORD: test_pass
  steps:
    - uses: actions/checkout@v2
    - name: Install dependencies
      run: cpanm --installdeps .
    - name: Run tests
      run: ./script/test
```

### Documentation

Full testing documentation available in `t/README.md`, including:
- Running specific test files
- Troubleshooting common issues
- Writing tests for new features
- Test helper API reference
- Coverage information

## Contact Information

**Project Owner**: Alex Beahm
- GitHub: https://github.com/AlexanderBeahm
- LinkedIn: https://www.linkedin.com/in/alex-beahm-5bb7a89b/
- Email: alexanderbeahm@gmail.com

---

*This guide should be updated as the project evolves. When implementing new features, update this documentation to reflect the current state and any architectural decisions made.*

## Multi-Environment Deployment & CI/CD

**Status**: Fully implemented (October 2025)

TheBoosh.Zone supports four distinct environments with proper separation of concerns, automated CI/CD pipeline, and production-ready deployment infrastructure.

### Environments

1. **Development** (`MOJO_MODE=development`)
   - Local Docker Compose setup
   - Uses `morbo` development server with hot reload
   - Local PostgreSQL database (schema: `public`)
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
   - nginx reverse proxy with SSL (Let's Encrypt)
   - Managed PostgreSQL database (schema: `thebooshzone_staging`)
   - Full monitoring with Prometheus and Grafana
   - Deployed automatically on push to `dev` branch
   - URL: https://staging.theboosh.zone

4. **Production** (`MOJO_MODE=production`)
   - Live environment on cloud server
   - Uses `hypnotoad` production server (8 workers)
   - nginx reverse proxy with SSL and performance optimizations
   - Managed PostgreSQL database (schema: `thebooshzone_prod`)
   - Full monitoring with alerts
   - Deployed on push to `main` branch or version tags
   - Requires manual approval in GitHub Actions
   - URL: https://theboosh.zone

### Configuration Files

**Backend Perl Configuration** (Mojolicious Config Plugin):
- `config/hello-perld.development.conf` - Development settings (morbo, debug logging)
- `config/hello-perld.test.conf` - Test settings (minimal workers, error-only logging)
- `config/hello-perld.staging.conf` - Staging settings (hypnotoad, info logging)
- `config/hello-perld.production.conf` - Production settings (optimized hypnotoad, warn logging)

Each config file includes:
- Hypnotoad server settings (workers, listeners, timeouts, graceful restart)
- Database connection details (schema, host, credentials)
- Logging levels (debug/error/info/warn)
- Session configuration (secret, expiration)
- Upload directory settings

**Frontend Vue/Vite Environment Files**:
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

### Database Schema Separation

The managed PostgreSQL instance hosts multiple schemas on the same database:
- `public` - Development and test data (local Docker PostgreSQL or ephemeral test DB)
- `thebooshzone_staging` - Staging data (managed database)
- `thebooshzone_prod` - Production data (managed database)

**Benefits**:
- Cost-effective (one managed database for staging + production)
- Data isolation between environments
- Simplified connection management
- Easy to backup/restore specific environments

**Schema Configuration**:
Set via `DB_SCHEMA` environment variable and `database.schema` in config files. The database connection logic in `lib/HelloPerld/Database/Postgres.pm` automatically sets the PostgreSQL search path:

```perl
if ($schema ne 'public') {
    $dbh->do("SET search_path TO $schema, public");
}
```

### CI/CD Pipeline

**GitHub Actions Workflows**:

1. **`.github/workflows/test.yml`** - Runs on all PRs and pushes to `dev`/`main`
   - Backend tests (Perl with Test::More, Test::Mojo)
   - Frontend tests (Vitest with Vue Test Utils)
   - Code linting (ESLint)
   - Coverage reports (optional Codecov integration)
   - Must pass before merging

2. **`.github/workflows/deploy-staging.yml`** - Deploys to staging
   - Triggered on push to `dev` branch (or manual)
   - Runs full test suite first
   - Builds Docker image with staging frontend
   - Pushes to GitHub Container Registry (ghcr.io)
   - SSH to staging server and runs deployment script
   - Health checks with automatic rollback on failure

3. **`.github/workflows/deploy-production.yml`** - Deploys to production
   - Triggered on push to `main` branch or version tags (`v*`)
   - Runs full test suite first
   - **Requires manual approval** (GitHub environment protection)
   - Builds optimized production Docker image
   - Creates GitHub release (if tagged)
   - Backs up database before deployment
   - SSH to production server and runs deployment script
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
   ├─ Rate limiting (API: 10 req/s, auth: 5 req/min)
   ├─ Gzip compression
   ├─ Security headers (X-Frame-Options, CSP, etc.)
   └─ Reverse proxy to backend
       ↓
hypnotoad (port 8080)
   ├─ 8 worker processes (production)
   ├─ Hot deployment support (zero-downtime updates)
   ├─ Process management and health monitoring
   ├─ Graceful restart (15s timeout)
   └─ Perl application (Mojolicious)
       ↓
Managed PostgreSQL Database
   └─ Schema: thebooshzone_prod (or thebooshzone_staging)
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

# Hot reload (zero-downtime update) - just run same command again
hypnotoad ./script/hello-perld
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

**Automated Deployment Steps**:
1. Run full test suite
2. Build Docker image with environment-specific frontend
3. Push image to GitHub Container Registry
4. SSH to target server
5. Pull latest image
6. Create database backup (production only)
7. Run database migrations
8. Graceful restart with health checks
9. Automatic rollback on health check failure

**Manual Deployment** (if needed):
```bash
# SSH to server
ssh user@staging.theboosh.zone  # or production

# Navigate to project directory
cd /opt/theboosh-zone

# Run deployment script
./deploy/deploy.sh staging  # or production
```

### Deployment Scripts

Located in `deploy/` directory:

1. **`setup-server.sh`** - Initial server configuration (run once)
   - Installs Docker, Docker Compose, certbot
   - Configures firewall (ufw)
   - Generates SSL certificates (Let's Encrypt)
   - Sets up log rotation
   - Creates directory structure
   ```bash
   ./deploy/setup-server.sh staging  # or production
   ```

2. **`deploy.sh`** - Deployment automation (run on every deployment)
   - Validates environment and loads `.env` file
   - Pulls latest Docker images
   - Runs database migrations
   - Deploys with docker-compose up -d
   - Health check with 30 retries (5s intervals)
   - Automatic rollback on health check failure
   - Cleanup old Docker images
   ```bash
   ./deploy/deploy.sh staging  # or production
   ```

3. **`rollback.sh`** - Emergency rollback to previous deployment
   - Lists available Docker image tags
   - Interactive image selection
   - Confirmation prompt ("yes" required)
   - Stops current containers and starts with selected image
   - Health check validation
   ```bash
   ./deploy/rollback.sh staging  # or production
   ```

4. **`backup.sh`** - Database backup automation
   - Determines schema based on environment
   - Uses pg_dump with schema-specific backup
   - Compresses with gzip
   - Timestamp-based filenames
   - 30-day retention policy (auto-cleanup)
   ```bash
   ./deploy/backup.sh staging  # or production
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

**Automatic Rollback**: Production deployment workflow includes automatic rollback if health checks fail after deployment.

### Environment Variables Reference

**Critical Production Variables** (must be unique per environment):
- `POSTGRES_HOST` - Managed database hostname
- `POSTGRES_PASSWORD` - Database password
- `SESSION_SECRET` - Session encryption key (generate with `openssl rand -hex 32`)
- `ADMIN_PASSWORD` - Admin user password

**Generate Secure Secrets**:
```bash
# Generate session secret
openssl rand -hex 32

# Generate admin password
openssl rand -base64 24
```

See `.env.*.example` files for complete list of required variables.

### Security Considerations

1. **Never commit `.env.*` files** (except `.example` templates) - enforced via `.gitignore`
2. **Use unique secrets per environment** - especially `SESSION_SECRET`
3. **Rotate secrets regularly** - at least annually, or after any suspected compromise
4. **Encrypt sensitive values** - use cloud platform's secrets management
5. **Enable HSTS** in production nginx config after SSL is working
6. **Restrict Swagger UI** in production (add basic auth or remove entirely)
7. **Monitor security advisories** - GitHub Dependabot enabled
8. **Database backups** - automated daily with 30-day retention
9. **Firewall rules** - only ports 22 (SSH), 80 (HTTP), 443 (HTTPS) open
10. **Non-root containers** - production Dockerfile uses `appuser` (UID 1000)
11. **Rate limiting** - nginx configured with limits on API and auth endpoints
12. **Security headers** - X-Frame-Options, X-Content-Type-Options, X-XSS-Protection, etc.

### Monitoring & Logging

**Prometheus** (port 9090):
- Application metrics from Mojolicious
- Database metrics (via postgres-exporter)
- System metrics (via node-exporter)
- Custom business metrics

**Grafana** (port 3001):
- Pre-configured dashboards
- Real-time monitoring
- Alerting capabilities (configure as needed)
- Default credentials from `.env` file

**Application Logs**:
```bash
# View live logs
docker compose -f docker-compose.production.yml logs -f app

# View nginx access logs
docker compose -f docker-compose.production.yml logs -f nginx

# View last 100 lines
docker compose -f docker-compose.production.yml logs --tail=100 app
```

**Log Rotation**: Configured via logrotate (14 days retention, daily rotation).

### Backup & Recovery

**Automated Backups**:
- Run automatically before each production deployment (via CI/CD)
- 30-day retention policy (older backups auto-deleted)
- Stored in `/opt/theboosh-zone/backups/` on server

**Manual Backup**:
```bash
ssh user@production.theboosh.zone
cd /opt/theboosh-zone
./deploy/backup.sh production
```

**Restore from Backup**:
```bash
# List available backups
ls -lh /opt/theboosh-zone/backups/

# Restore specific backup
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
# - Database connection failed: Verify POSTGRES_* env vars in .env.production
# - Missing SESSION_SECRET: Check .env.production has unique secret
# - Port conflict: Ensure 8080 is available (check with netstat or ss)
```

**Deployment failed in GitHub Actions**:
- Check workflow run logs in GitHub Actions tab
- Verify SSH keys are correct in GitHub Secrets
- Ensure server is accessible (test with `ssh user@hostname`)
- Check server has enough disk space (`df -h`)
- Review application logs on server

**Database connection issues**:
```bash
# Test connection from server
PGPASSWORD=$POSTGRES_PASSWORD psql \
  -h $POSTGRES_HOST \
  -U $POSTGRES_USER \
  -d $POSTGRES_DB \
  -c "SELECT version();"

# Verify server IP is whitelisted in managed database firewall
# Check schema exists: \dn
```

**SSL certificate issues**:
```bash
# Check certificate status
sudo certbot certificates

# Renew manually
sudo certbot renew

# Check auto-renewal timer
sudo systemctl status certbot.timer

# Certificates should auto-renew via systemd timer
```

**High memory/CPU usage**:
- Check resource usage: `docker stats`
- Reduce hypnotoad workers in `config/hello-perld.production.conf`
- Review Prometheus metrics for bottlenecks
- Check for memory leaks in application code

**Need to rollback**:
```bash
cd /opt/theboosh-zone
./deploy/rollback.sh production
```

### UFW and Docker Firewall Configuration

**CRITICAL**: UFW (Uncomplicated Firewall) and Docker do not work well together by default. When UFW is enabled, Docker containers may not be accessible from external networks even when ports are exposed.

**The Problem:**
- Docker creates iptables rules to route traffic to containers
- UFW creates its own iptables rules that can block Docker traffic
- The `DOCKER-USER` chain is where traffic enters before Docker's routing
- If `DOCKER-USER` has a `RETURN` rule at the beginning, it exits before reaching ACCEPT rules
- This causes "connection refused" errors from external networks while localhost works fine

**Symptoms:**
- `docker ps` shows ports mapped (e.g., `0.0.0.0:443->443/tcp`)
- Containers work internally (curl from localhost succeeds)
- External access fails with "connection refused"
- Port 8080 works but 80/443 don't (different iptables rules)

**The Solution:**
We've created `deploy/configure-docker-firewall.sh` to automatically configure iptables rules for Docker/UFW compatibility.

**What it does:**
1. Installs `iptables-persistent` for rule persistence across reboots
2. Waits for Docker to create the `DOCKER-USER` chain
3. Removes any RETURN rules at the beginning of the chain
4. Adds ACCEPT rules for ports 80 and 443 at the top
5. Ensures RETURN rule exists only at the end
6. Saves rules with `netfilter-persistent save`

**When to run:**
- **First deployment**: After running `deploy.sh` for the first time
- **After Docker restart**: If containers become inaccessible after server reboot
- **After UFW changes**: If you modify UFW rules

**Usage:**
```bash
# Run after first deployment or when external access stops working
sudo ./deploy/configure-docker-firewall.sh

# Verify rules are correct
sudo iptables -L DOCKER-USER -n -v --line-numbers

# Expected output:
# 1. ACCEPT tcp -- eth0 * 0.0.0.0/0 0.0.0.0/0 tcp dpt:443
# 2. ACCEPT tcp -- eth0 * 0.0.0.0/0 0.0.0.0/0 tcp dpt:80
# 3. RETURN all -- * * 0.0.0.0/0 0.0.0.0/0
```

**Integration:**
- `setup-server.sh` reminds you to run this after first deployment
- `deploy.sh` verifies firewall rules on each deployment and warns if missing
- Rules persist across reboots via `iptables-persistent`

**Important Notes:**
- This must be run with `sudo` or as root
- Docker must be running before executing the script
- The script is idempotent - safe to run multiple times
- Rules are saved to `/etc/iptables/rules.v4` for persistence

**Troubleshooting:**
```bash
# Check if rules exist
sudo iptables -L DOCKER-USER -n -v

# If empty or wrong order, run the script
sudo ./deploy/configure-docker-firewall.sh

# Test external access
curl -v https://staging.theboosh.zone  # or production

# View Docker network traffic
sudo iptables -L FORWARD -n -v
```

**SSL Certificate Volume Mounts:**
The docker-compose files use **bind mounts** (not Docker named volumes) for SSL certificates:
```yaml
volumes:
  - /etc/letsencrypt:/etc/letsencrypt:ro
  - /var/www/certbot:/var/www/certbot:ro
```

This is critical because certbot runs on the **host** and stores certificates in `/etc/letsencrypt/`. Using Docker named volumes would create a separate isolated storage that nginx can't access.

### References & Documentation
- **Post-Implementation Checklist**: `.claude/claude-documentation/Post-Implementation-Checklist.md` (Setup Steps)
- **Mojolicious Documentation**: https://docs.mojolicious.org/
- **Hypnotoad Guide**: https://docs.mojolicious.org/Mojo/Server/Hypnotoad
- **Vite Environment Variables**: https://vite.dev/guide/env-and-mode
- **Docker Compose**: https://docs.docker.com/compose/
- **GitHub Actions**: https://docs.github.com/en/actions
- **nginx Documentation**: https://nginx.org/en/docs/
- **Let's Encrypt**: https://letsencrypt.org/docs/
- **Docker and iptables**: https://docs.docker.com/network/iptables/
- **UFW with Docker**: https://github.com/chaifeng/ufw-docker

---

**Last Updated**: October 28, 2025 - Added UFW/Docker firewall configuration automation. Created `configure-docker-firewall.sh` script to resolve iptables conflicts between UFW and Docker. Fixed SSL certificate volume mounts to use host bind mounts instead of Docker named volumes. Updated deployment scripts to verify firewall rules. Previous: Implemented comprehensive backend testing framework with Test::More, Test::Mojo, and DBD::Mock. Added 60+ test cases covering models and controllers. Deployed multi-environment setup with dev/test/staging/production environments, CI/CD pipeline via GitHub Actions, nginx reverse proxy, hypnotoad production server, and comprehensive deployment automation scripts.
