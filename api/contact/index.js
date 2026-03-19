/**
 * GET /api/contact - list contact messages (admin only).
 * POST /api/contact - submit a contact message (public). Body: { name?, email, subject?, message, userId? }.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';
import { checkRateLimit } from '../lib/rateLimit.js';

function rowToMessage(row) {
  if (!row) return null;
  return {
    id: row.id,
    name: row.name ?? null,
    email: row.email,
    subject: row.subject ?? null,
    message: row.message,
    userId: row.user_id ?? null,
    orderId: row.order_id?.toString?.() ?? row.order_id ?? null,
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
        SELECT id, name, email, subject, message, user_id, order_id, read_at, created_at
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
    if (!checkRateLimit(req, 'contact_post', { max: 25, windowMs: 600_000 })) {
      return res.status(429).json({ error: 'Too many messages. Please try again later.' });
    }
    const body = req.body || {};
    const email = String(body.email ?? '').trim();
    const message = String(body.message ?? '').trim();
    if (!email || !message) return res.status(400).json({ error: 'Email and message are required' });
    if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
    try {
      const name = body.name != null ? String(body.name).trim() : null;
      const subject = body.subject != null ? String(body.subject).trim() : null;
      const userId = body.userId != null ? String(body.userId) : null;
      const orderId = body.orderId != null && String(body.orderId).trim() !== '' ? String(body.orderId).trim() : null;
      const [inserted] = await sql`
        INSERT INTO contact_messages (name, email, subject, message, user_id, order_id)
        VALUES (${name}, ${email}, ${subject}, ${message}, ${userId}, ${orderId})
        RETURNING id
      `;
      const messageId = inserted?.id?.toString?.() ?? null;
      if (messageId) {
        try {
          const { notifyNewMessage } = await import('../../api/lib/apns.js');
          const adminRows = await sql`SELECT device_token FROM push_tokens WHERE is_admin = true`;
          const tokens = (adminRows || []).map((r) => r.device_token).filter(Boolean);
          if (tokens.length) notifyNewMessage(tokens, messageId, name ?? email, subject ?? message.slice(0, 60), orderId);
        } catch (e) {
          console.warn('[contact] push notify', e?.message ?? e);
        }
      }
      return res.status(201).json({ ok: true });
    } catch (err) {
      if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
      console.error('[contact] POST', err);
      return res.status(500).json({ error: 'Failed to send message' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
