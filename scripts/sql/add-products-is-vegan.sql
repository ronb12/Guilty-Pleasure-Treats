-- Run on Neon if POST /api/products fails with: column "is_vegan" does not exist
ALTER TABLE products ADD COLUMN IF NOT EXISTS is_vegan BOOLEAN NOT NULL DEFAULT false;
