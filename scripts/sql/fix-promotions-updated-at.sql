-- Run in Neon SQL Editor if Vercel logs show:
--   column "updated_at" of relation "promotions" does not exist
-- Safe to run multiple times.

ALTER TABLE promotions ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
