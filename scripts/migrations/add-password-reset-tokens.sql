-- Run once on existing Neon DBs if you already ran setup before password reset was added.
-- Or use: node --env-file=.env.neon scripts/run-missing-tables.js (idempotent).

CREATE TABLE IF NOT EXISTS password_reset_tokens (
  user_id UUID NOT NULL,
  token TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_password_reset_token ON password_reset_tokens(token);
CREATE INDEX IF NOT EXISTS idx_password_reset_user_id ON password_reset_tokens(user_id);

-- If you previously created `token_hash`, rename once:
-- ALTER TABLE password_reset_tokens RENAME COLUMN token_hash TO token;
