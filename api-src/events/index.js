/**
 * GET /api/events - list upcoming events (start_at >= now, ordered by start_at).
 * POST /api/events - create event (admin only). Body: title, description?, start_at?, end_at?, image_url?, location?. Sends push to customers.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToEvent(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? String(row.id ?? ''),
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

  if ((req.method || '').toUpperCase() === 'GET') {
    if (!hasDb() || !sql) return res.status(200).json([]);
    try {
      const token = getTokenFromRequest(req);
      const session = token ? await getSession(token) : null;
      const allEvents =
        session?.isAdmin === true &&
        (String(req.query?.all ?? req.query?.admin ?? '').trim() === '1' ||
          String(req.query?.all ?? '').toLowerCase() === 'true');
      const rows = allEvents
        ? await sql`
        SELECT id, title, description, start_at, end_at, image_url, location, created_at
        FROM events
        ORDER BY start_at ASC NULLS LAST, created_at DESC
        LIMIT 500
      `
        : await sql`
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

  if ((req.method || '').toUpperCase() === 'POST') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.userId || session.isAdmin !== true) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

    const body = req.body || {};
    const title = String(body.title ?? '').trim();
    if (!title) return res.status(400).json({ error: 'title is required' });
    const description = body.description != null ? String(body.description).trim() : null;
    const startAt = body.start_at ?? body.startAt ?? null;
    const endAt = body.end_at ?? body.endAt ?? null;
    const imageUrl = body.image_url ?? body.imageURL ?? null;
    const location = body.location != null ? String(body.location).trim() : null;

    try {
      const [row] = await sql`
        INSERT INTO events (title, description, start_at, end_at, image_url, location)
        VALUES (${title}, ${description || null}, ${startAt ? new Date(startAt) : null}, ${endAt ? new Date(endAt) : null}, ${imageUrl || null}, ${location || null})
        RETURNING id, title, description, start_at, end_at, image_url, location, created_at
      `;
      const eventId = row?.id?.toString?.() ?? row?.id;

      try {
        const { notifyNewEvent } = await import('../../api/lib/apns.js');
        const customerRows = await sql`SELECT device_token FROM push_tokens WHERE is_admin = false AND device_token IS NOT NULL AND device_token != ''`;
        const tokens = (customerRows || []).map((r) => r.device_token).filter(Boolean);
        const subtitle = row?.start_at ? new Date(row.start_at).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' }) : (row?.location || null);
        if (tokens.length) notifyNewEvent(tokens, eventId, title, subtitle);
      } catch (e) {
        console.warn('[events] push notify', e?.message ?? e);
      }

      return res.status(201).json(rowToEvent(row));
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[events] POST', err);
      return res.status(500).json({ error: 'Failed to create event' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
