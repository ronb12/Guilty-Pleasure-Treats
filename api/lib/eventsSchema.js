/**
 * Ensures `events` exists (Neon / Postgres). Safe to call on every request.
 * Uses awaitNeonRows so Neon `fetch failed` does not surface as unhandled rejections.
 */
import { awaitNeonRows } from './db.js';

export async function ensureEventsTable(sql) {
  if (!sql) return;
  await awaitNeonRows(
    sql`
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
  `,
    'events_schema_create'
  );
  await awaitNeonRows(sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS description TEXT`, 'events_schema_col_desc');
  await awaitNeonRows(sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS start_at TIMESTAMPTZ`, 'events_schema_col_start');
  await awaitNeonRows(sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS end_at TIMESTAMPTZ`, 'events_schema_col_end');
  await awaitNeonRows(sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url TEXT`, 'events_schema_col_img');
  await awaitNeonRows(sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS location TEXT`, 'events_schema_col_loc');
  await awaitNeonRows(
    sql`ALTER TABLE events ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW()`,
    'events_schema_col_updated'
  );
  await awaitNeonRows(
    sql`CREATE INDEX IF NOT EXISTS idx_events_start_at ON events(start_at ASC) WHERE start_at IS NOT NULL`,
    'events_schema_idx'
  );
}
