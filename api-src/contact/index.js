/**
 * Contact messages: POST = submit (public), GET = list (admin only).
 * Owner gets a push notification when a customer sends a message (same tokens as new-order).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { notifyNewMessage } from '../../api/lib/apns.js';

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
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }

  if (req.method === 'POST') {
    // Public: submit a contact message
    if (!hasDb() || !sql) {
      return res.status(503).json({ error: 'Contact form is temporarily unavailable.' });
    }
    const body = req.body && typeof req.body === 'object' ? req.body : {};
    const email = body.email != null ? String(body.email).trim() : '';
    const message = body.message != null ? String(body.message).trim() : '';
    const name = body.name != null ? String(body.name).trim() : null;
    const subject = body.subject != null ? String(body.subject).trim() : null;
    const userId = body.userId != null ? String(body.userId) : null;

    if (!email || !message) {
      return res.status(400).json({ error: 'Email and message are required.' });
    }
    if (message.length > 5000) {
      return res.status(400).json({ error: 'Message is too long.' });
    }

    try {
      const rows = await sql`
        INSERT INTO contact_messages (name, email, subject, message, user_id)
        VALUES (${name || null}, ${email}, ${subject || null}, ${message}, ${userId || null})
        RETURNING id, name, email, subject, message, user_id, read_at, created_at
      `;
      const created = rowToMessage(rows[0]);
      if (!created) return res.status(500).json({ error: 'Failed to save message.' });
      try {
        const tokenRows = await sql`SELECT device_token FROM push_tokens WHERE is_admin = true`;
        const tokens = (tokenRows || []).map((r) => r.device_token).filter(Boolean);
        if (tokens.length > 0) {
          const preview = (subject || message).slice(0, 50);
          notifyNewMessage(tokens, created.id, name || email, preview).catch((err) =>
            console.error('push new message', err)
          );
        }
      } catch (_) {
        /* ignore */
      }
      return res.status(201).json({ ok: true, id: created.id, message: 'Thanks! We’ll get back to you soon.' });
    } catch (err) {
      if (err?.code === '42P01') {
        return res.status(503).json({ error: 'Contact form is being set up. Please email us directly for now.' });
      }
      console.error('contact POST', err);
      return res.status(500).json({ error: 'Failed to send message. Please try email or Instagram.' });
    }
  }

  if (req.method === 'GET') {
    // Admin only: list contact messages
    if (!hasDb() || !sql) {
      return res.status(503).json({ error: 'Database not configured' });
    }
    const token = getTokenFromRequest(req);
    const session = await getSession(token);
    if (!session || !session.isAdmin) {
      return res.status(401).json({ error: 'Admin access required' });
    }
    try {
      const rows = await sql`
        SELECT id, name, email, subject, message, user_id, read_at, created_at
        FROM contact_messages
        ORDER BY created_at DESC
        LIMIT 200
      `;
      return res.status(200).json(rows.map(rowToMessage));
    } catch (err) {
      if (err?.code === '42P01') {
        return res.status(200).json([]);
      }
      console.error('contact GET', err);
      return res.status(500).json({ error: 'Failed to load messages' });
    }
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
