-- Run this in Neon SQL Editor to verify all tables and key columns exist.
-- Expected: 11 tables. If any are missing, run api/schema.sql (or migrate-neon.sql for incremental).

-- List all tables in public schema
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- Expected tables:
-- ai_cake_designs
-- business_settings
-- cake_flavors
-- cake_sizes
-- custom_cake_orders
-- frosting_types
-- orders
-- products
-- promotions
-- sessions
-- users

-- Quick check: products should have is_vegetarian
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'products'
ORDER BY ordinal_position;
