-- If GET /api/orders returns 500 (admin load orders fails), run in Neon SQL Editor.
-- Safe to run multiple times.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS promo_code TEXT;
ALTER TABLE orders ADD COLUMN IF NOT EXISTS tip_cents INT NOT NULL DEFAULT 0;
