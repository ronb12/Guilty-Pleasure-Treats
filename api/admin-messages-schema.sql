-- Admin-initiated messages to customers (not tied to a contact form). Run in Neon SQL Editor.
CREATE TABLE IF NOT EXISTS admin_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  to_user_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_admin_messages_to_user_id ON admin_messages(to_user_id);
CREATE INDEX IF NOT EXISTS idx_admin_messages_created_at ON admin_messages(created_at DESC);
