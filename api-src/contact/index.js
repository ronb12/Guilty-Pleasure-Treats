/**
 * GET /api/contact - list contact messages (admin only).
 * POST /api/contact - submit a contact message (public). Body: { name?, email, subject?, message, userId? }.
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

  if ((req.method || '').toUpperCase() === 'GET') {
    const token = getTokenFromRequest(req);
    const session = token ? await getSession(token) : null;
    if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
    if (!hasDb() || !sql) return res.status(200).json([]);
    try {
      const rows = await sql`
        SELECT id, name, email, subject, message, user_id, read_at, created_at
        FROM contact_messages
        ORDER BY created_at DESC
        LIMIT 500
      `;
      return res.status(200).json(rows.map(rowToMessage));
    } catch (err) {
      if (err?.code === '42P01') return res.status(200).json([]);
      console.error('[contact] GET', err);
      return res.status(500).json({ error: 'Failed to fetch messages' });
    }
  }

  if ((req.method || '').toUpperCase() === 'POST') {
    const body = req.body || {};
    const email = String(body.email ?? '').trim();
    const message = String(body.message ?? '').trim();
    if (!email || !message) return res.status(400).json({ error: 'Email and message are required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
    try {
      const name = body.name != null ? String(body.name).trim() : null;
      const subject = body.subject != null ? String(body.subject).trim() : null;
      const userId = body.userId != null ? String(body.userId) : null;
      await sql`
        INSERT INTO contact_messages (name, email, subject, message, user_id)
        VALUES (${name}, ${email}, ${subject}, ${message}, ${userId})
      `;
      return res.status(201).json({ ok: true });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[contact] POST', err);
      return res.status(500).json({ error: 'Failed to send message' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
