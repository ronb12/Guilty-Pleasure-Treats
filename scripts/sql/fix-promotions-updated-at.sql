-- Run in Neon SQL Editor if admin cannot add/edit promos (PATCH/POST errors 42703).
-- Safe to run multiple times.

ALTER TABLE promotions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_subtotal DECIMAL(10,2);
ALTER TABLE promotions ADD COLUMN IF NOT EXISTS min_total_quantity INTEGER;
ALTER TABLE promotions ADD COLUMN IF NOT EXISTS first_order_only BOOLEAN NOT NULL DEFAULT false;
