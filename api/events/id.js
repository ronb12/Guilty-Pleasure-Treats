/**
 * GET /api/events/:id - get one event.
 * PATCH /api/events/:id - update event (admin only).
 * DELETE /api/events/:id - delete event (admin only).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession, sessionHasAdminAccessResolved } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { ensureEventsTable } from '../lib/eventsSchema.js';
import { updateLegacyEventDateTime } from '../lib/eventsCompat.js';

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
  const id = (req.query?.id ?? '').toString().trim();
  if (!id) return res.status(400).json({ error: 'Event id required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      await ensureEventsTable(sql);
      const [row] = await sql`
        SELECT id, title, description, start_at, end_at, image_url, location, created_at
        FROM events WHERE id = ${id}
      `;
      if (!row) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json(rowToEvent(row));
    } catch (err) {
      console.error('[events/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch event' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH' || (req.method || '').toUpperCase() === 'DELETE') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!token) return res.status(401).json({ error: 'Unauthorized', code: 'no_token' });
    if (!session?.userId) return res.status(401).json({ error: 'Unauthorized', code: 'invalid_session' });
    if (!(await sessionHasAdminAccessResolved(session, sql))) {
      return res.status(403).json({ error: 'Admin required', code: 'not_admin' });
    }

    try {
      await ensureEventsTable(sql);
    } catch (migErr) {
      console.error('[events/id] ensureEventsTable', migErr);
      return res.status(503).json({ error: 'Database setup failed for events.' });
    }

    if ((req.method || '').toUpperCase() === 'DELETE') {
      try {
        const result = await sql`DELETE FROM events WHERE id = ${id} RETURNING id`;
        if (!result?.length) return res.status(404).json({ error: 'Not found' });
        return res.status(204).end();
      } catch (err) {
        console.error('[events/id] DELETE', err);
        return res.status(500).json({ error: 'Failed to delete event' });
      }
    }

    const body = req.body || {};
    const title = body.title != null ? String(body.title).trim() : null;
    const description = body.description !== undefined ? (body.description == null ? null : String(body.description).trim()) : null;
    const startAt = body.start_at !== undefined ? body.start_at : (body.startAt !== undefined ? body.startAt : null);
    const endAt = body.end_at !== undefined ? body.end_at : (body.endAt !== undefined ? body.endAt : null);
    const imageUrl = body.image_url !== undefined ? body.image_url : (body.imageURL !== undefined ? body.imageURL : null);
    const location = body.location !== undefined ? (body.location == null ? null : String(body.location).trim()) : null;

    try {
      const [existing] = await sql`SELECT id FROM events WHERE id = ${id}`;
      if (!existing) return res.status(404).json({ error: 'Not found' });

      if (title != null) await sql`UPDATE events SET title = ${title}, updated_at = NOW() WHERE id = ${id}`;
      if (description !== undefined) await sql`UPDATE events SET description = ${description}, updated_at = NOW() WHERE id = ${id}`;
      if (startAt !== undefined) {
        await sql`UPDATE events SET start_at = ${startAt ? new Date(startAt) : null}, updated_at = NOW() WHERE id = ${id}`;
        await updateLegacyEventDateTime(sql, id, startAt);
      }
      if (endAt !== undefined) await sql`UPDATE events SET end_at = ${endAt ? new Date(endAt) : null}, updated_at = NOW() WHERE id = ${id}`;
      if (imageUrl !== undefined) await sql`UPDATE events SET image_url = ${imageUrl || null}, updated_at = NOW() WHERE id = ${id}`;
      if (location !== undefined) await sql`UPDATE events SET location = ${location || null}, updated_at = NOW() WHERE id = ${id}`;

      const [row] = await sql`
        SELECT id, title, description, start_at, end_at, image_url, location, created_at
        FROM events WHERE id = ${id}
      `;
      return res.status(200).json(rowToEvent(row));
    } catch (err) {
      console.error('[events/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update event' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
