-- Admin replies to contact messages. Run in Neon SQL Editor after contact_messages exists.
-- Customers can fetch replies for their own messages (by user_id).

CREATE TABLE IF NOT EXISTS contact_message_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_message_id UUID NOT NULL REFERENCES contact_messages(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_contact_message_replies_message_id ON contact_message_replies(contact_message_id);
CREATE INDEX IF NOT EXISTS idx_contact_message_replies_created_at ON contact_message_replies(created_at DESC);
