/**
 * Ensures `events` exists (Neon / Postgres). Safe to call on every request.
 */
export async function ensureEventsTable(sql) {
  if (!sql) return;
  await sql`
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
    )
  `;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS description TEXT`;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ`;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ`;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url TEXT`;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS location TEXT`;
  await sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`;
  await sql`CREATE INDEX IF NOT EXISTS idx_events_start_at ON events(start_at ASC) WHERE start_at IS NOT NULL`;
}
