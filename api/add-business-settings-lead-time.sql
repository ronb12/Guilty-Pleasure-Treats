-- Existing DBs only: add minimum order notice (hours) to business_settings.
-- Run once in Neon: Vercel Dashboard → Storage → Neon → SQL Editor.
-- Safe to run multiple times (IF NOT EXISTS).

ALTER TABLE business_settings ADD COLUMN IF NOT EXISTS minimum_order_lead_time_hours INT DEFAULT 24;
