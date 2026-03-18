-- Events / pop-ups (admin-managed; app displays on Home and Events screen).
CREATE TABLE IF NOT EXISTS events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  date TEXT NOT NULL,
  time TEXT,
  location TEXT NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  flyer_url TEXT,
  display_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_events_display_order ON events(display_order ASC, created_at DESC);
