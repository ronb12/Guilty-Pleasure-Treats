-- Run this in Neon SQL Editor if you already applied an older schema.
-- Safe to run multiple times (IF NOT EXISTS / ON CONFLICT).

-- 1. Add is_vegetarian to products (if you created products before this column existed)
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegetarian BOOLEAN NOT NULL DEFAULT false;

-- 1b. Add cost (optional, for admin margins/profit)
ALTER TABLE products ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2);

-- 1c. Add minimum order notice (hours) to business_settings
ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS minimum_order_lead_time_hours INT DEFAULT 24;

-- 2. Custom cake options tables (admin-managed sizes, flavors, frostings)
CREATE TABLE IF NOT EXISTS cake_sizes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  price DECIMAL(10,2) NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS cake_flavors (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS frosting_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. Seed default cake options if empty
INSERT INTO cake_sizes (label, price, sort_order)
SELECT '6 inch', 24.00, 0 UNION ALL SELECT '8 inch', 32.00, 1 UNION ALL SELECT '10 inch', 42.00, 2
WHERE NOT EXISTS (SELECT 1 FROM cake_sizes LIMIT 1);

INSERT INTO cake_flavors (label, sort_order)
SELECT 'Chocolate', 0 UNION ALL SELECT 'Vanilla', 1 UNION ALL SELECT 'Red Velvet', 2 UNION ALL SELECT 'Strawberry', 3
WHERE NOT EXISTS (SELECT 1 FROM cake_flavors LIMIT 1);

INSERT INTO frosting_types (label, sort_order)
SELECT 'Vanilla Buttercream', 0 UNION ALL SELECT 'Chocolate', 1 UNION ALL SELECT 'Cream Cheese', 2
WHERE NOT EXISTS (SELECT 1 FROM frosting_types LIMIT 1);

-- 3b. Cake toppings (admin-managed; optional for custom cakes)
CREATE TABLE IF NOT EXISTS cake_toppings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO cake_toppings (label, sort_order)
SELECT 'Sprinkles', 0
UNION ALL SELECT 'Fresh fruit', 1
UNION ALL SELECT 'Chocolate drizzle', 2
UNION ALL SELECT 'Fresh berries', 3
UNION ALL SELECT 'Whipped cream', 4
UNION ALL SELECT 'Caramel drizzle', 5
UNION ALL SELECT 'Toasted nuts', 6
UNION ALL SELECT 'Coconut', 7
UNION ALL SELECT 'Candy pieces', 8
UNION ALL SELECT 'Edible flowers', 9
UNION ALL SELECT 'Gold dust', 10
WHERE NOT EXISTS (SELECT 1 FROM cake_toppings LIMIT 1);

ALTER TABLE custom_cake_orders ADD COLUMN IF NOT EXISTS toppings JSONB DEFAULT '[]';

-- 4. Push tokens (admin: new-order/new-message; customer: order-status)
CREATE TABLE IF NOT EXISTS push_tokens (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  device_token TEXT NOT NULL,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  PRIMARY KEY (user_id)
);
ALTER TABLE push_tokens ADD COLUMN IF NOT EXISTS is_admin BOOLEAN NOT NULL DEFAULT false;
CREATE INDEX IF NOT EXISTS idx_push_tokens_updated ON push_tokens(updated_at);

-- 5. Forgot password: one-time tokens (token, user_id, expires_at)
CREATE TABLE IF NOT EXISTS password_reset_tokens (
  token TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_password_reset_tokens_expires ON password_reset_tokens(expires_at);
