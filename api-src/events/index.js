/**
 * Events: public GET (list); admin POST to add. Customers get a push when a new event is created.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { notifyNewEvent } from '../../api/lib/apns.js';

function rowToEvent(row) {
  if (!row) return null;
  return {
    id: row.id,
    title: row.title ?? '',
    date: row.date ?? '',
    time: row.time ?? null,
    location: row.location ?? '',
    description: row.description ?? '',
    flyerUrl: row.flyer_url ?? null,
    displayOrder: Number(row.display_order ?? 0),
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    updatedAt: row.updated_at ? new Date(row.updated_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (!hasDb() || !sql) {
    return res.status(200).json([]);
  }

  if (req.method === 'GET') {
    try {
      const rows = await sql`SELECT * FROM events ORDER BY display_order ASC, created_at DESC`;
      return res.status(200).json(rows.map(rowToEvent));
    } catch (err) {
      if (err?.message && err.message.includes('does not exist')) {
        return res.status(200).json([]);
      }
      console.error('events GET', err);
      return res.status(200).json([]);
    }
  }

  if (req.method === 'POST') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
    const body = req.body || {};
    const title = String(body.title ?? '').trim();
    if (!title) return res.status(400).json({ error: 'title required' });
    const date = String(body.date ?? '').trim() || '';
    const time = (body.time != null && body.time !== '') ? String(body.time).trim() : null;
    const location = String(body.location ?? '').trim() || '';
    const description = String(body.description ?? '').trim() || '';
    const flyerUrl = (body.flyerUrl != null && body.flyerUrl !== '') ? String(body.flyerUrl).trim() : null;
    const displayOrder = body.displayOrder != null ? Number(body.displayOrder) : 0;
    try {
      const rows = await sql`
        INSERT INTO events (title, date, time, location, description, flyer_url, display_order)
        VALUES (${title}, ${date}, ${time}, ${location}, ${description}, ${flyerUrl}, ${displayOrder})
        RETURNING *
      `;
      const created = rows[0];
      // Notify all customers (fire-and-forget)
      try {
        const tokenRows = await sql`SELECT device_token FROM push_tokens WHERE COALESCE(is_admin, false) = false`;
        const tokens = (tokenRows || []).map((r) => r.device_token).filter(Boolean);
        if (tokens.length > 0) {
          notifyNewEvent(tokens, created.title, created.date, false).catch((err) =>
            console.error('push new event', err)
          );
        }
      } catch (_) {
        /* ignore */
      }
      return res.status(201).json(rowToEvent(created));
    } catch (err) {
      if (err?.message && err.message.includes('does not exist')) {
        return res.status(503).json({ error: 'Events table not set up. Run scripts/run-reviews-events-schema.js.' });
      }
      console.error('events POST', err);
      return res.status(500).json({ error: err.message || 'Failed to add event' });
    }
  }

  res.status(405).json({ error: 'Method not allowed' });
}
