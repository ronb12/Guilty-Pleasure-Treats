/**
 * GET /api/events - list upcoming events (start_at >= now, ordered by start_at).
 */
import { sql, hasDb } from '../lib/db.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToEvent(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title,
    description: row.description ?? null,
    start_at: row.start_at ? new Date(row.start_at).toISOString() : null,
    end_at: row.end_at ? new Date(row.end_at).toISOString() : null,
    image_url: row.image_url ?? null,
    location: row.location ?? null,
    created_at: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  if ((req.method || '').toUpperCase() !== 'GET') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(200).json([]);
  }
  try {
    const rows = await sql`
      SELECT id, title, description, start_at, end_at, image_url, location, created_at
      FROM events
      WHERE start_at IS NULL OR start_at >= NOW()
      ORDER BY start_at ASC NULLS LAST, created_at DESC
      LIMIT 100
    `;
    return res.status(200).json(rows.map(rowToEvent));
  } catch (err) {
    if (err?.code === '42P01') return res.status(200).json([]);
    console.error('[events] GET', err);
    return res.status(500).json({ error: 'Failed to fetch events' });
  }
}
