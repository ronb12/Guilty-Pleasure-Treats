-- Loyalty rewards: owner-configured point costs tied to catalog products.
-- Run in Neon SQL Editor or via scripts/run-missing-tables.js (preferred).

CREATE TABLE IF NOT EXISTS loyalty_rewards (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  points_required INT NOT NULL CHECK (points_required > 0),
  product_id UUID NOT NULL REFERENCES products(id) ON DELETE RESTRICT,
  sort_order INT NOT NULL DEFAULT 0,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_loyalty_rewards_active ON loyalty_rewards (is_active, sort_order);
