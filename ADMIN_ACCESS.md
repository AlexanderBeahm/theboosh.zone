# TheBoosh.Zone Admin Access Guide

## Admin Login Information

### Accessing the Admin Panel

The admin panel can be accessed at:
- **URL**: http://localhost:3000/admin/login
- **Production**: https://theboosh.zone/admin/login

### Default Admin Credentials

The admin credentials are stored in the `.env` file:


**⚠️ IMPORTANT**: Change this password before deploying to production!

## Admin Features

Once logged in, you can:

1. **View Articles** (`/admin`)
   - See all articles including drafts/unpublished
   - Edit existing articles
   - Delete articles

2. **Create New Articles**
   - Write article content in Markdown
   - Add tags
   - Set publish status
   - Configure SEO meta information

3. **Manage Tags**
   - Create new tags
   - Edit tag names/slugs
   - View tag usage statistics

## API Endpoints

### Public Endpoints
- `GET /api/articles` - List published articles
- `GET /api/articles/{slug}` - Get single article by slug
- `GET /api/tags` - List all tags
- `GET /api/tags/popular` - Get popular tags
- `GET /api/tags/search?q=query` - Search tags

### Authentication Endpoints
- `POST /api/auth/login` - Login (username & password)
- `POST /api/auth/logout` - Logout
- `GET /api/auth/status` - Check authentication status

### Admin Endpoints (Authentication Required)
- `GET /api/admin/articles` - List all articles (including unpublished)
- `GET /api/admin/articles/{id}` - Get article by ID
- `POST /api/admin/articles` - Create new article
- `PUT /api/admin/articles/{id}` - Update article
- `DELETE /api/admin/articles/{id}` - Delete article
- `GET /api/admin/tags/{id}` - Get tag by ID
- `POST /api/admin/tags` - Create new tag
- `PUT /api/admin/tags/{id}` - Update tag
- `DELETE /api/admin/tags/{id}` - Delete tag

## Testing Admin Access

### Using cURL

**Login:**
```bash
curl -X POST http://localhost:3000/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"your_secure_admin_password"}' \
  -c cookies.txt
```

**Check Status:**
```bash
curl -b cookies.txt http://localhost:3000/api/auth/status
```

**Create Article (requires authentication):**
```bash
curl -X POST http://localhost:3000/api/admin/articles \
  -b cookies.txt \
  -H "Content-Type: application/json" \
  -d '{
    "title": "My First Article",
    "content": "This is the article content in **Markdown**.",
    "excerpt": "A short description",
    "is_published": true,
    "tags": ["tech", "blog"]
  }'
```

**List Articles:**
```bash
curl http://localhost:3000/api/articles
```

### Using the Web Interface

1. Navigate to http://localhost:3000/admin/login
2. Enter your credentials
3. You'll be redirected to the admin dashboard at /admin
4. Use the interface to create, edit, and manage content

## Security Notes

### Session Management
- Sessions expire after 24 hours
- Sessions are cookie-based
- Always log out when done (especially on shared computers)

### Rate Limiting
- Login attempts are rate-limited (5 attempts per 15 minutes)
- This helps prevent brute-force attacks

### Password Requirements
- Minimum 8 characters
- Passwords are hashed with SHA-256 and random salt
- Change your password via: `POST /api/admin/auth/change-password`

## Troubleshooting

### Can't Log In
1. Verify credentials in `.env` file
2. Check that the database is running: `docker-compose ps`
3. Check application logs: `docker-compose logs hello-perld`
4. Ensure password wasn't changed accidentally

### Session Expired
- Simply log in again at `/admin/login`
- Sessions automatically expire after 24 hours

### Reset Admin Password

Run the password update script:
```bash
docker exec -e ADMIN_PASSWORD=new_password thebooshzone-hello-perld-1 \
  perl /usr/src/hello-perld/script/update_admin_password
```

Or from the host:
```bash
ADMIN_PASSWORD=new_password perl script/update_admin_password
```

## Database Schema

### Admin Users Table
```sql
CREATE TABLE admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);
```

### Articles Table
```sql
CREATE TABLE articles (
    id SERIAL PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    slug VARCHAR(255) UNIQUE NOT NULL,
    content TEXT NOT NULL,
    excerpt TEXT,
    published_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_published BOOLEAN DEFAULT FALSE,
    meta_description TEXT,
    featured_image VARCHAR(255)
);
```

## Support

For issues or questions:
- **Email**: alexanderbeahm@gmail.com
- **GitHub**: https://github.com/AlexanderBeahm/hello-perld
- **LinkedIn**: https://www.linkedin.com/in/alex-beahm-5bb7a89b/
