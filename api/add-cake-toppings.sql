-- Add cake_toppings table and seed default toppings so Admin → Cake Options shows them.
-- Run once in Neon: Vercel Dashboard → Storage → Neon → SQL Editor (or Neon Console SQL Editor).

CREATE TABLE IF NOT EXISTS cake_toppings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  label TEXT NOT NULL,
  sort_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

INSERT INTO cake_toppings (label, sort_order)
SELECT 'Sprinkles', 0
UNION ALL SELECT 'Fresh fruit', 1
UNION ALL SELECT 'Chocolate drizzle', 2
UNION ALL SELECT 'Fresh berries', 3
UNION ALL SELECT 'Whipped cream', 4
UNION ALL SELECT 'Caramel drizzle', 5
UNION ALL SELECT 'Toasted nuts', 6
UNION ALL SELECT 'Coconut', 7
UNION ALL SELECT 'Candy pieces', 8
UNION ALL SELECT 'Edible flowers', 9
UNION ALL SELECT 'Gold dust', 10
WHERE NOT EXISTS (SELECT 1 FROM cake_toppings LIMIT 1);
