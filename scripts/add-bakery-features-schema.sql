-- Bakery app feature columns and tables. Run in Neon SQL Editor (or node script).
-- Covers: order status/pickup/tip/tax, business hours/lead time, product availability.

-- 1. Orders: pickup time, tip, tax, Stripe payment intent (for refunds)
ALTER TABLE orders ADD COLUMN IF NOT EXISTS pickup_time TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS ready_by TIMESTAMPTZ;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tax_cents INT NOT NULL DEFAULT 0;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS stripe_payment_intent_id TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'pending';
COMMENT ON COLUMN orders.status IS 'pending, confirmed, in_progress, ready, completed, cancelled';

-- 2. Business settings table (if not exists) with hours and lead time
CREATE TABLE IF NOT EXISTS business_settings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  key TEXT NOT NULL UNIQUE,
  value_json JSONB NOT NULL DEFAULT '{}',
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
INSERT INTO business_settings (key, value_json)
VALUES ('main', '{"lead_time_hours": 24, "business_hours": {"mon":"9-17","tue":"9-17","wed":"9-17","thu":"9-17","fri":"9-17","sat":"9-15","sun":null}, "min_order_cents": 0, "tax_rate_percent": 0}'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- 3. Products: availability
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_available BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE products ADD COLUMN IF NOT EXISTS available_from DATE;

-- Index for order status filtering
CREATE INDEX IF NOT EXISTS idx_orders_status ON orders(status);
CREATE INDEX IF NOT EXISTS idx_orders_pickup_time ON orders(pickup_time);
CREATE INDEX IF NOT EXISTS idx_products_is_available ON products(is_available) WHERE is_available = true;
