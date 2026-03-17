-- Gallery: owner showcase of treats (cakes, cookies, cupcakes, etc.). Admin adds photos; customers browse and can order.
CREATE TABLE IF NOT EXISTS cake_gallery (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  image_url TEXT NOT NULL,
  title TEXT NOT NULL DEFAULT '',
  description TEXT,
  category TEXT,
  price DECIMAL(10,2),
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
-- Add category if table already existed without it
ALTER TABLE cake_gallery ADD COLUMN IF NOT EXISTS category TEXT;

CREATE INDEX IF NOT EXISTS idx_cake_gallery_display_order ON cake_gallery(display_order ASC, created_at DESC);
