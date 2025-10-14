-- Create admin_users table for authentication
CREATE TABLE admin_users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT TRUE
);

-- Create index on username for fast lookups during authentication
CREATE INDEX idx_admin_users_username ON admin_users(username);

-- Create index on email for lookups
CREATE INDEX idx_admin_users_email ON admin_users(email);

-- Create index on is_active for filtering active users
CREATE INDEX idx_admin_users_active ON admin_users(is_active);