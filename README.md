# TheBoosh.Zone

Alex Beahm's personal portfolio and blog website built with modern full-stack architecture.

[![Docker Image CI](https://github.com/AlexanderBeahm/hello-perld/actions/workflows/docker-image.yml/badge.svg)](https://github.com/AlexanderBeahm/hello-perld/actions/workflows/docker-image.yml)

# Features
- **Blog System**: Full-featured articles with Markdown support, syntax highlighting, and tag management
- **Admin Interface**: Comprehensive dashboard for content creation and management
- **Authentication**: Secure admin login system with session management
- **Database**: PostgreSQL with migration system for schema management
- **Frontend**: Vue 3 SPA with responsive design and modern UI components
- **Backend**: Mojolicious Perl framework with RESTful API
- **OpenAPI Documentation**: Complete API documentation with Swagger UI
- **Development**: DevContainer support with hot-reload and integrated tooling
- **Monitoring**: Prometheus metrics and Grafana dashboards included

# Prerequisites
- **Node.js LTS** (for frontend development)
- **Docker & Docker Compose**
- **VSCode** (recommended for DevContainer support)

# Setup

## DevContainer Setup (Recommended)
1. **Configure Environment**: Copy `.env.example` to `.env` and update with your database credentials:
   ```bash
   cp .env.example .env
   # Edit .env with your secure passwords and configuration
   ```

2. Open repository with VSCode `code .`

3. Use VSCode command 'Open Folder In Container...'

4. Wait until postcreate.sh and poststart.sh are completed (installs dependencies and builds frontend)

5. **Start Services**:
   ```bash
   docker compose up --build --watch
   ```

6. **Run Database Migrations** (in a new terminal):
   ```bash
   docker exec thebooshzone-hello-perld-1 perl script/migrate
   ```

7. TheBoosh.Zone will be served at:
   - **Main Site**: http://localhost:3000
   - **Admin Dashboard**: http://localhost:3000/admin
   - **API Documentation**: http://localhost:3000/swagger
   - **Monitoring**: http://localhost:3001 (Grafana)

## Local Development Setup
1. **Install Perl dependencies:**
   ```bash
   cpanm --installdeps --notest .
   ```

2. **Install frontend dependencies and build:**
   ```bash
   cd frontend
   npm install
   npm run build
   cd ..
   ```

3. **Start the Mojolicious server:**
   ```bash
   morbo ./script/hello-perld
   ```
   The application will be available at http://localhost:3000

## Docker Production Setup
```bash
docker compose up --build
```

# Database Management

TheBoosh.Zone uses PostgreSQL with a custom migration system that supports both SQL and Perl scripts.

## Environment Configuration

Configure database connection in your `.env` file:

```env
# PostgreSQL Database Configuration
POSTGRES_DB=thebooshzone_dev
POSTGRES_USER=theboosh_user
POSTGRES_PASSWORD=your_secure_database_password
POSTGRES_HOST=db  # Use 'db' for Docker, 'localhost' for external connections

# Admin User Configuration (for initial setup)
ADMIN_USERNAME=admin
ADMIN_EMAIL=your-email@example.com
ADMIN_PASSWORD=your_secure_admin_password
```

## Migration System

### Running Migrations

**After starting Docker containers**, run migrations to set up the database schema:

```bash
# Run all pending migrations
docker exec thebooshzone-hello-perld-1 perl script/migrate

# Debug migration issues (detailed output)
docker exec thebooshzone-hello-perld-1 perl script/migrate_debug
```

### Migration Files

Migrations are located in `/migrations/` and are applied in numerical order:

- `001_create_articles_table.sql` - Blog articles table
- `002_create_tags_table.sql` - Content tags
- `003_create_article_tags_table.sql` - Many-to-many relationship
- `004_create_admin_users_table.sql` - Admin authentication
- `005_create_default_admin_user.pl` - Creates initial admin user

### Development Workflow for Migrations

1. **Start containers**: `docker compose up -d`
2. **Run migrations**: `docker exec thebooshzone-hello-perld-1 perl script/migrate`
3. **Verify setup**: Check that all tables exist and admin user is created

### Troubleshooting Database Issues

- **Connection refused**: Ensure PostgreSQL container is running (`docker compose ps`)
- **User does not exist**: Delete postgres volume and restart: `docker compose down && docker volume rm thebooshzone_postgres_data && docker compose up -d`
- **Migration issues**: Use `script/migrate_debug` for detailed diagnostics
- **Check applied migrations**: `docker exec thebooshzone-db-1 psql -U theboosh_user -d thebooshzone_dev -c "SELECT * FROM schema_migrations;"`

# Development Workflow

## Frontend Development
The frontend is a Vue 3 single-page application built with Vite.

### Development Mode (with Hot Module Replacement)
For the best development experience, run the Vite dev server and Mojolicious backend separately:

1. **Terminal 1 - Start Mojolicious backend:**
   ```bash
   morbo ./script/hello-perld
   ```

2. **Terminal 2 - Start Vite dev server:**
   ```bash
   cd frontend
   npm run dev
   ```
   The Vite dev server runs at http://localhost:5173 and proxies API calls to the Mojolicious backend at http://localhost:3000

### Production Build
To build the frontend for production:
```bash
cd frontend
npm run build
```
This builds assets to `lib/HelloPerld/Public/dist/` which are served by Mojolicious.

## Project Structure
```
theboosh.zone/
├── frontend/                    # Vue 3 SPA frontend
│   ├── src/
│   │   ├── components/         # Vue components
│   │   │   ├── MarkdownRenderer.vue    # Markdown rendering with syntax highlighting
│   │   │   ├── ArticleEditor.vue       # Admin article creation/editing
│   │   │   └── NavBar.vue              # Main navigation
│   │   ├── views/              # Page views
│   │   │   ├── HomePage.vue            # Landing page
│   │   │   ├── AboutPage.vue           # About page
│   │   │   ├── ArticlesPage.vue        # Blog listing with tag filtering
│   │   │   ├── ArticlePage.vue         # Individual article display
│   │   │   ├── AdminLogin.vue          # Admin authentication
│   │   │   └── AdminDashboard.vue      # Content management interface
│   │   ├── router/             # Vue Router config
│   │   ├── assets/             # CSS and static assets
│   │   ├── App.vue             # Root component
│   │   └── main.js             # Entry point
│   ├── index.html              # HTML template
│   ├── vite.config.js          # Vite configuration
│   └── package.json            # Frontend dependencies
├── lib/HelloPerld/             # Perl backend
│   ├── Controller/             # API controllers
│   │   ├── Articles.pm         # Article CRUD operations
│   │   ├── Tags.pm             # Tag management
│   │   ├── Auth.pm             # Admin authentication
│   │   └── Health.pm           # Health check endpoint
│   ├── Model/                  # Data models
│   │   ├── Article.pm          # Article data operations
│   │   └── Tag.pm              # Tag data operations
│   ├── Database/               # Database utilities
│   │   └── Postgres.pm         # Connection and migration system
│   ├── Logger/                 # Logging system
│   ├── Public/                 # Static assets
│   │   └── dist/               # Built frontend assets (generated)
│   └── Templates/              # Mojolicious templates
├── migrations/                 # Database migrations
│   ├── 001_create_articles_table.sql
│   ├── 002_create_tags_table.sql
│   ├── 003_create_article_tags_table.sql
│   ├── 004_create_admin_users_table.sql
│   └── 005_create_default_admin_user.pl
├── script/                     # Perl scripts
│   ├── hello-perld             # Main application script
│   ├── migrate                 # Migration runner
│   ├── migrate_debug           # Migration debugging
│   └── create_admin_user       # Admin user creation utility
├── swagger/                    # API documentation
│   └── swagger.json            # OpenAPI 3.0 specification
├── .env.example                # Environment configuration template
├── docker-compose.yml          # Multi-service development environment
├── Dockerfile                  # Multi-stage build (Node + Perl)
└── docker-entrypoint.sh        # Container startup script

---
## ssh-agent Setup (for use with Git SSH within Dev Container)
### Prep WSL2 (Ubuntu/Debian shown—adapt as needed), Ensure OpenSSH client & ssh-agent
```
sudo apt-get update
sudo apt-get install -y openssh-client
```

### Start (and persist) an ssh-agent in WSL2

Put this tiny helper in your shell init so a single socket lives across sessions:

### Add to ~/.bashrc (or ~/.zshrc)
```
if [ -z "$SSH_AUTH_SOCK" ]; then
  SOCK="$HOME/.ssh/agent.sock"
  if [ -S "$SOCK" ]; then
    export SSH_AUTH_SOCK="$SOCK"
  else
    mkdir -p "$HOME/.ssh"
    eval "$(ssh-agent -a "$SOCK" -s)" >/dev/null
    export SSH_AUTH_SOCK="$SOCK"
  fi
fi
```

Reload your shell:

`exec $SHELL -l`

### Add your key to the agent
```
ssh-add ~/.ssh/id_ed25519
# or: ssh-add ~/.ssh/id_rsa
ssh-add -l    # should list your key fingerprint
```


Tip: First confirm this works directly in WSL:
```
ssh -T git@github.com
```
### Expect: "Hi <username>! You've successfully authenticated..."


If that succeeds, your host (WSL2) SSH is good.

### Validate in dev container

Open the folder in WSL (VS Code: “Open Folder in WSL”), then Reopen in Container.

Inside the container’s terminal:
```
echo "$SSH_AUTH_SOCK"       # should be /ssh-agent
ls -l "$SSH_AUTH_SOCK"      # should be a socket file
ssh -T git@github.com       # should greet you (no password prompt)
```

Ensure the repo remote uses SSH, not HTTPS:
```
git remote -v
git remote set-url origin git@github.com:<org>/<repo>.git
```

git fetch, git pull, git push should now work from inside the dev container.

## Common issues & fixes
“Permission denied (publickey)”

In WSL (not container): `ssh-add -l` must list your key. If empty, `ssh-add ~/.ssh/<yourkey>`.

Inside container: `echo $SSH_AUTH_SOCK` should be /ssh-agent and `ls -l /ssh-agent` should show a socket.

Ensure devcontainer.json used `${localEnv:SSH_AUTH_SOCK}` (not ${env:...}) so it resolves in the WSL VS Code context.

If that fails, it may be possible that there are multiple agents available and that is causing a conflict in forwarding the correct one.

### In WSL2: run one pinned ssh-agent and load keys

Put the agent on a stable path so VS Code always mounts the same socket.

### In WSL2
```
pkill ssh-agent 2>/dev/null || true
rm -f ~/.ssh/agent.sock
eval "$(ssh-agent -a "$HOME/.ssh/agent.sock" -s)"
ssh-add -D
ssh-add ~/.ssh/id_ed25519  # or your key file
ssh-add -l                 # should list your key(s)
```

Verify you’re using the pinned agent:
```
SSH_AUTH_SOCK=$HOME/.ssh/agent.sock ssh-add -l   # must list the same keys
echo "$SSH_AUTH_SOCK"                            # ideally /home/<you>/.ssh/agent.sock
```
