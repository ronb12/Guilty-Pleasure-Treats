-- Run this once in Neon (Vercel Dashboard → Storage → Neon → SQL Editor)
-- or via a one-time migration. Tables match iOS Product and Order models.

-- Products (camelCase in API JSON; snake_case here)
CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  price DECIMAL(10,2) NOT NULL,
  cost DECIMAL(10,2),
  image_url TEXT,
  category TEXT NOT NULL,
  is_featured BOOLEAN NOT NULL DEFAULT false,
  is_sold_out BOOLEAN NOT NULL DEFAULT false,
  stock_quantity INT,
  low_stock_threshold INT,
  is_vegetarian BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- If table already exists, add new columns (run as needed):
-- ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegetarian BOOLEAN NOT NULL DEFAULT false;
-- ALTER TABLE products ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2);

-- Orders
CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  customer_name TEXT NOT NULL,
  customer_phone TEXT NOT NULL,
  items JSONB NOT NULL DEFAULT '[]',
  subtotal DECIMAL(10,2) NOT NULL,
  tax DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  fulfillment_type TEXT NOT NULL,
  scheduled_pickup_date TIMESTAMPTZ,
  status TEXT NOT NULL DEFAULT 'Pending',
  stripe_payment_intent_id TEXT,
  manual_paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  estimated_ready_time TIMESTAMPTZ,
  custom_cake_order_ids JSONB,
  ai_cake_design_ids JSONB
);

CREATE INDEX IF NOT EXISTS idx_orders_created_at ON orders(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_products_is_featured ON products(is_featured);

-- Users (replaces Firebase Auth + Firestore users)
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  display_name TEXT,
  password_hash TEXT,
  apple_id TEXT UNIQUE,
  is_admin BOOLEAN NOT NULL DEFAULT false,
  points INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS sessions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions(expires_at);

-- Business settings (single row)
CREATE TABLE IF NOT EXISTS business_settings (
  id TEXT PRIMARY KEY DEFAULT 'business',
  store_hours TEXT,
  delivery_radius_miles DECIMAL(5,2),
  tax_rate DECIMAL(5,4) NOT NULL DEFAULT 0.08,
  minimum_order_lead_time_hours INT DEFAULT 24,
  contact_email TEXT,
  contact_phone TEXT,
  store_name TEXT,
  cash_app_tag TEXT,
  venmo_username TEXT,
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO business_settings (id, tax_rate) VALUES ('business', 0.08) ON CONFLICT (id) DO NOTHING;

-- Promotions
CREATE TABLE IF NOT EXISTS promotions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code TEXT NOT NULL,
  discount_type TEXT NOT NULL,
  value DECIMAL(10,2) NOT NULL,
  valid_from TIMESTAMPTZ,
  valid_to TIMESTAMPTZ,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_promotions_code ON promotions(code);

-- Custom cake orders
CREATE TABLE IF NOT EXISTS custom_cake_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  size TEXT NOT NULL,
  flavor TEXT NOT NULL,
  frosting TEXT NOT NULL,
  toppings JSONB DEFAULT '[]',
  message TEXT NOT NULL DEFAULT '',
  design_image_url TEXT,
  price DECIMAL(10,2) NOT NULL,
  order_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_custom_cake_orders_created ON custom_cake_orders(created_at DESC);

-- AI cake design orders
CREATE TABLE IF NOT EXISTS ai_cake_designs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id TEXT,
  size TEXT NOT NULL,
  flavor TEXT NOT NULL,
  frosting TEXT NOT NULL,
  design_prompt TEXT NOT NULL DEFAULT '',
  generated_image_url TEXT,
  price DECIMAL(10,2) NOT NULL,
  order_id UUID,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_cake_designs_created ON ai_cake_designs(created_at DESC);

-- Custom cake builder options (admin-managed; customer app reads via GET /api/custom-cake-options)
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

CREATE TABLE IF NOT EXISTS cake_toppings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed default options (matches app enums) if empty
INSERT INTO cake_sizes (label, price, sort_order)
SELECT '6 inch', 24.00, 0 UNION ALL SELECT '8 inch', 32.00, 1 UNION ALL SELECT '10 inch', 42.00, 2
WHERE NOT EXISTS (SELECT 1 FROM cake_sizes LIMIT 1);

INSERT INTO cake_flavors (label, sort_order)
SELECT 'Chocolate', 0 UNION ALL SELECT 'Vanilla', 1 UNION ALL SELECT 'Red Velvet', 2 UNION ALL SELECT 'Strawberry', 3
WHERE NOT EXISTS (SELECT 1 FROM cake_flavors LIMIT 1);

INSERT INTO frosting_types (label, sort_order)
SELECT 'Vanilla Buttercream', 0 UNION ALL SELECT 'Chocolate', 1 UNION ALL SELECT 'Cream Cheese', 2
WHERE NOT EXISTS (SELECT 1 FROM frosting_types LIMIT 1);

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
