-- Ensure product categories exist in Neon and are unique by normalized name.
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS product_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_product_categories_name_lower_unique
  ON product_categories (LOWER(TRIM(name)));

CREATE INDEX IF NOT EXISTS idx_product_categories_display_order
  ON product_categories(display_order ASC, name ASC);

INSERT INTO product_categories (name, display_order)
VALUES
  ('Cupcakes', 10),
  ('Cookies', 20),
  ('Cakes', 30),
  ('Brownies', 40),
  ('Seasonal Treats', 50),
  ('Treat 4 Paws', 60)
ON CONFLICT (LOWER(TRIM(name))) DO NOTHING;

