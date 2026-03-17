-- Existing DBs only: add optional product cost column (for admin Margins).
-- Run this once in Neon: Vercel Dashboard → Storage → Neon → SQL Editor.
-- Safe to run multiple times (IF NOT EXISTS).

ALTER TABLE products ADD COLUMN IF NOT EXISTS cost DECIMAL(10,2);
