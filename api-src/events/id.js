/**
 * Single event: GET (public), PATCH/DELETE (admin). Customers get a push when an event is updated.
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
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'id required' });
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const rows = await sql`SELECT * FROM events WHERE id = ${id} LIMIT 1`;
  const existing = rows[0];
  if (!existing) return res.status(404).json({ error: 'Not found' });

  if (req.method === 'GET') {
    return res.status(200).json(rowToEvent(existing));
  }

  if (req.method === 'PATCH' || req.method === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin required' });
    }
  }

  if (req.method === 'PATCH') {
    const body = req.body || {};
    const title = body.title !== undefined ? String(body.title).trim() || existing.title : existing.title;
    const date = body.date !== undefined ? String(body.date).trim() : existing.date;
    const time = body.time !== undefined ? (body.time == null || body.time === '' ? null : String(body.time).trim()) : existing.time;
    const location = body.location !== undefined ? String(body.location).trim() : existing.location;
    const description = body.description !== undefined ? String(body.description).trim() : existing.description;
    const flyerUrl = body.flyerUrl !== undefined ? (body.flyerUrl == null || body.flyerUrl === '' ? null : String(body.flyerUrl).trim()) : existing.flyer_url;
    const displayOrder = body.displayOrder !== undefined ? Number(body.displayOrder) : existing.display_order;
    await sql`
      UPDATE events
      SET title = ${title}, date = ${date}, time = ${time}, location = ${location}, description = ${description}, flyer_url = ${flyerUrl}, display_order = ${displayOrder}, updated_at = NOW()
      WHERE id = ${id}
    `;
    const updated = await sql`SELECT * FROM events WHERE id = ${id} LIMIT 1`;
    const event = updated[0];
    // Notify all customers (fire-and-forget)
    try {
      const tokenRows = await sql`SELECT device_token FROM push_tokens WHERE COALESCE(is_admin, false) = false`;
      const tokens = (tokenRows || []).map((r) => r.device_token).filter(Boolean);
      if (tokens.length > 0) {
        notifyNewEvent(tokens, event.title, event.date, true).catch((err) =>
          console.error('push event updated', err)
        );
      }
    } catch (_) {
      /* ignore */
    }
    return res.status(200).json(rowToEvent(event));
  }

  if (req.method === 'DELETE') {
    await sql`DELETE FROM events WHERE id = ${id}`;
    return res.status(204).end();
  }

  res.status(405).json({ error: 'Method not allowed' });
}
