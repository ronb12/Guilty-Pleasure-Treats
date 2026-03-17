-- Push tokens: admin = new-order/new-message; customer = order-status (APNs, no Firebase).
-- Run in Neon SQL Editor or: node --env-file=.env.neon scripts/run-push-tokens-schema.js

CREATE TABLE IF NOT EXISTS push_tokens (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id)
);

CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at);
