-- Product categories: owner can add, edit, delete. Products reference category by name.
CREATE TABLE IF NOT EXISTS product_categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL UNIQUE,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_product_categories_display_order ON product_categories(display_order ASC, name ASC);

-- Seed default categories if empty (optional; API can also return defaults when table empty)
INSERT INTO product_categories (name, display_order) VALUES
  ('Cupcakes', 0),
  ('Cookies', 1),
  ('Cakes', 2),
  ('Brownies', 3),
  ('Seasonal Treats', 4),
  ('Treat 4 Paws', 5)
ON CONFLICT (name) DO NOTHING;
