-- Structured address columns for customers (in addition to legacy address TEXT).
-- Run: node --env-file=.env.neon scripts/run-customers-address-columns.js

ALTER TABLE customers ADD COLUMN IF NOT EXISTS street TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS address_line_2 TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS city TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS state TEXT;
ALTER TABLE customers ADD COLUMN IF NOT EXISTS postal_code TEXT;

-- Optional: backfill address into structured columns for existing rows that have address set
-- (single-line addresses go to street; newline-separated split into street, city, state, postal_code)
-- We do not run backfill in SQL; the API can derive structured from address when reading old rows.
