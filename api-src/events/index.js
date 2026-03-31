/**
 * GET /api/events - list upcoming events (start_at >= now, ordered by start_at).
 * POST /api/events - create event (admin only). Body: title, description?, start_at?, end_at?, image_url?, location?. Sends push to customers.
 */
import { sql, hasDb, awaitNeonRows } from '../../api/lib/db.js';
import {
  getTokenFromRequest,
  getSession,
  coerceAdminFlag,
  sessionHasAdminAccessResolved,
} from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { ensureEventsTable } from '../lib/eventsSchema.js';
import { insertEventRow } from '../../api/lib/eventsCompat.js';

function normalizeImageUrl(v) {
  if (v == null) return null;
  const s = String(v).trim();
  return s.length ? s : null;
}

function rowToEvent(row) {
  if (!row) return null;
  return {
    id: row.id?.toString?.() ?? String(row.id ?? ''),
    title: row.title,
    description: row.description ?? null,
    start_at: row.start_at ? new Date(row.start_at).toISOString() : null,
    end_at: row.end_at ? new Date(row.end_at).toISOString() : null,
    image_url: normalizeImageUrl(row.image_url),
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
      await ensureEventsTable(sql);
      const token = getTokenFromRequest(req);
      const session = token ? await getSession(token) : null;
      const wantsAll =
        String(req.query?.all ?? req.query?.admin ?? '').trim() === '1' ||
        String(req.query?.all ?? '').toLowerCase() === 'true';
      // Admin list must be authorized; otherwise non-admins silently got the public list and Create Event still failed.
      if (wantsAll) {
        if (!token) return res.status(401).json({ error: 'Unauthorized', code: 'no_token' });
        if (!session?.userId) return res.status(401).json({ error: 'Unauthorized', code: 'invalid_session' });
        const adminOk = await sessionHasAdminAccessResolved(session, sql);
        if (!adminOk) {
          return res.status(403).json({ error: 'Admin required', code: 'not_admin' });
        }
      }
      const allEvents = wantsAll;
      const rows = allEvents
        ? await awaitNeonRows(
            sql`
        SELECT id, title, description, start_at, end_at, image_url, location, created_at
        FROM events
        ORDER BY start_at ASC NULLS LAST, created_at DESC
        LIMIT 500
      `,
            'events_GET_all'
          )
        : await awaitNeonRows(
            sql`
        SELECT id, title, description, start_at, end_at, image_url, location, created_at
        FROM events
        WHERE start_at IS NULL OR start_at >= NOW()
        ORDER BY start_at ASC NULLS LAST, created_at DESC
        LIMIT 100
      `,
            'events_GET_public'
          );
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
    if (!token) {
      console.warn('[events] POST auth failed', { reason: 'no_token' });
      return res.status(401).json({ error: 'Unauthorized', code: 'no_token' });
    }
    if (!session?.userId) {
      const parts = String(token).split('.');
      const tokenKind = parts.length === 3 ? 'jwt' : 'session';
      console.warn('[events] POST auth failed', { reason: 'invalid_or_expired_session', tokenKind });
      return res.status(401).json({ error: 'Unauthorized', code: 'invalid_session' });
    }
    const allowed = await sessionHasAdminAccessResolved(session, sql);
    if (!allowed) {
      console.warn('[events] POST auth failed (not admin)', {
        hasUserId: true,
        isAdminCoerced: coerceAdminFlag(session?.isAdmin),
        envGrantEligible: Boolean(process.env.ADMIN_GRANT_EMAILS?.trim()),
      });
      return res.status(403).json({ error: 'Admin required', code: 'not_admin' });
    }
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });

    try {
      await ensureEventsTable(sql);
    } catch (migErr) {
      console.error('[events] ensureEventsTable', migErr);
      return res.status(503).json({ error: 'Database setup failed for events.' });
    }

    const body = req.body || {};
    const title = String(body.title ?? '').trim();
    if (!title) return res.status(400).json({ error: 'title is required' });
    const description = body.description != null ? String(body.description).trim() : null;
    const startAt = body.start_at ?? body.startAt ?? null;
    const endAt = body.end_at ?? body.endAt ?? null;
    const imageUrl = body.image_url ?? body.imageURL ?? null;
    const location = body.location != null ? String(body.location).trim() : null;

    try {
      const inserted = await insertEventRow(sql, {
        title,
        description,
        startAt,
        endAt,
        imageUrl,
        location,
      });
      const row = inserted[0];
      if (!row) {
        return res.status(503).json({
          error: 'Could not save event (database rejected the row). If this persists, check the events table schema.',
          code: 'insert_failed',
        });
      }
      const eventId = row?.id?.toString?.() ?? row?.id;

      try {
        const { notifyNewEvent } = await import('../../api/lib/apns.js');
        const customerRows = await awaitNeonRows(
          sql`SELECT device_token FROM push_tokens WHERE is_admin = false AND device_token IS NOT NULL AND device_token != ''`,
          'events_POST_push_tokens'
        );
        const tokens = (customerRows || []).map((r) => r.device_token).filter(Boolean);
        const subtitle = row?.start_at ? new Date(row.start_at).toLocaleString(undefined, { dateStyle: 'short', timeStyle: 'short' }) : (row?.location || null);
        if (tokens.length) notifyNewEvent(tokens, eventId, title, subtitle);
      } catch (e) {
        console.warn('[events] push notify', e?.message ?? e);
      }

      return res.status(201).json(rowToEvent(row));
    } catch (err) {
      console.error('[events] POST', err);
      return res.status(500).json({
        error: 'Failed to create event',
        details: process.env.NODE_ENV === 'development' ? err?.message || String(err) : undefined,
      });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
