-- Run this once against your RDS instance to create the users table
-- In dev you can run it against the local docker postgres too

CREATE TABLE IF NOT EXISTS users (
  id                  SERIAL PRIMARY KEY,
  email               VARCHAR(255) UNIQUE NOT NULL,
  password_hash       VARCHAR(255) NOT NULL,
  name                VARCHAR(100) NOT NULL,
  role                VARCHAR(20) NOT NULL DEFAULT 'user',
  status              VARCHAR(20) NOT NULL DEFAULT 'active',
  refresh_token_hash  VARCHAR(255),
  last_login          TIMESTAMP,
  created_at          TIMESTAMP NOT NULL DEFAULT NOW(),
  updated_at          TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
