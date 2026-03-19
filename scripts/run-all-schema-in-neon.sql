-- Run this in Neon SQL Editor: https://console.neon.tech → your project → SQL Editor
-- Covers: admin_messages + contact_messages, contact_message_replies, cake_gallery,
--         product_categories, customers, push_tokens (run after users exists)

-- admin_messages
CREATE TABLE IF NOT EXISTS admin_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  to_user_id TEXT NOT NULL,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_admin_messages_created_at ON admin_messages(created_at DESC);

-- contact_messages
CREATE TABLE IF NOT EXISTS contact_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  email TEXT NOT NULL,
  subject TEXT,
  message TEXT NOT NULL,
  user_id TEXT,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON contact_messages(created_at DESC);
ALTER TABLE contact_messages ADD COLUMN IF NOT EXISTS order_id UUID;

-- contact_message_replies
CREATE TABLE IF NOT EXISTS contact_message_replies (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  contact_message_id UUID NOT NULL REFERENCES contact_messages(id) ON DELETE CASCADE,
  body TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_contact_message_replies_message_id ON contact_message_replies(contact_message_id);

-- cake_gallery
CREATE TABLE IF NOT EXISTS cake_gallery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  description TEXT,
  category TEXT,
  price DECIMAL(10,2),
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_cake_gallery_display_order ON cake_gallery(display_order ASC, created_at DESC);

-- product_categories
CREATE TABLE IF NOT EXISTS product_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_product_categories_display_order ON product_categories(display_order ASC, name ASC);

-- customers
CREATE TABLE IF NOT EXISTS customers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  phone TEXT NOT NULL DEFAULT '',
  email TEXT,
  address TEXT,
  street TEXT,
  address_line_2 TEXT,
  city TEXT,
  state TEXT,
  postal_code TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name ASC);

-- push_tokens (requires users table to exist)
CREATE TABLE IF NOT EXISTS push_tokens (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id)
);
CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at);
