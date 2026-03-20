-- Run on Neon if POST /api/products fails with: column "is_vegetarian" does not exist
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegetarian BOOLEAN NOT NULL DEFAULT false;
