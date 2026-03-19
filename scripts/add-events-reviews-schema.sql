-- Events and reviews tables for bakery app. Run in Neon SQL Editor.

-- events (tastings, pop-ups, etc.)
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  start_at TIMESTAMPTZ,
  end_at TIMESTAMPTZ,
  image_url TEXT,
  location TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_events_start_at ON events(start_at ASC) WHERE start_at IS NOT NULL;

-- reviews (customer reviews; order-based like DoorDash)
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_name TEXT,
  rating INT CHECK (rating >= 1 AND rating <= 5),
  text TEXT,
  product_id TEXT,
  order_id UUID,
  user_id TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reviews_created_at ON reviews(created_at DESC);
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS order_id UUID;
ALTER TABLE reviews ADD COLUMN IF NOT EXISTS user_id TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_reviews_order_user ON reviews(order_id, user_id) WHERE order_id IS NOT NULL AND user_id IS NOT NULL;
