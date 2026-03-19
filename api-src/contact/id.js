/**
 * GET /api/contact/:id - get one contact message (admin only).
 * PATCH /api/contact/:id - mark message as read (admin only).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToMessage(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name ?? null,
    email: row.email,
    subject: row.subject ?? null,
    message: row.message,
    userId: row.user_id ?? null,
    readAt: row.read_at ? new Date(row.read_at).toISOString() : null,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  const id = req.query?.id;
  if (!id) return res.status(400).json({ error: 'Missing message id' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });

  if ((req.method || '').toUpperCase() === 'GET') {
    try {
      const rows = await sql`
        SELECT id, name, email, subject, message, user_id, read_at, created_at
        FROM contact_messages WHERE id = ${id} LIMIT 1
      `;
      if (!rows.length) return res.status(404).json({ error: 'Not found' });
      return res.status(200).json(rowToMessage(rows[0]));
    } catch (err) {
      console.error('[contact/id] GET', err);
      return res.status(500).json({ error: 'Failed to fetch message' });
    }
  }

  if ((req.method || '').toUpperCase() === 'PATCH') {
    try {
      const result = await sql`
        UPDATE contact_messages SET read_at = NOW() WHERE id = ${id} AND read_at IS NULL
      `;
      return res.status(200).json({ ok: true });
    } catch (err) {
      console.error('[contact/id] PATCH', err);
      return res.status(500).json({ error: 'Failed to update message' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
