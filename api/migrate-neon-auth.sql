-- Add Neon Auth user id to link our users table to Neon Auth (Better Auth) users.
-- Run once in Neon SQL Editor if you use Neon Auth for sign-in.
ALTER TABLE users ADD COLUMN IF NOT EXISTS neon_auth_id TEXT UNIQUE;
CREATE INDEX IF NOT EXISTS idx_users_neon_auth_id ON users(neon_auth_id) WHERE neon_auth_id IS NOT NULL;
