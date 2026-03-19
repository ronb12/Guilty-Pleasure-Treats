-- Idempotent loyalty earn: award at most once per order when marked completed.
-- Run against Neon (e.g. psql or Neon SQL editor) if you don't use scripts/run-missing-tables.js.

ALTER TABLE orders ADD COLUMN IF NOT EXISTS loyalty_points_awarded INT NULL;
COMMENT ON COLUMN orders.loyalty_points_awarded IS 'Points granted once when order reached completed; NULL = not yet processed.';
