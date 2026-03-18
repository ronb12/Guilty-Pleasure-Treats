-- Customer reviews (admin-managed; app displays on Home and Reviews screen).
CREATE TABLE IF NOT EXISTS reviews (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author TEXT NOT NULL,
  text TEXT NOT NULL,
  stars INT NOT NULL DEFAULT 5 CHECK (stars >= 1 AND stars <= 5),
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reviews_display_order ON reviews(display_order ASC, created_at DESC);
