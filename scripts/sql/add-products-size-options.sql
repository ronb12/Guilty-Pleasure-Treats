-- Optional: run in Neon SQL Editor if admin product sizes fail with "column size_options does not exist" (42703).
-- Safe to run multiple times (IF NOT EXISTS).
-- Prefer: npm run neon:migrate  (runs scripts/run-missing-tables.js with .env.neon)

ALTER TABLE products ADD COLUMN IF NOT EXISTS size_options JSONB DEFAULT '[]'::jsonb;

COMMENT ON COLUMN products.size_options IS 'JSON array of {id, label, price} for menu size options; empty array = single price only';
