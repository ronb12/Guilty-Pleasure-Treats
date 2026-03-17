/**
 * POST /api/contact/:id/reply - admin sends an in-app reply to a contact message.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session || !session.isAdmin) {
    return res.status(401).json({ error: 'Admin access required' });
  }

  const id = req.query.id;
  if (!id) return res.status(400).json({ error: 'Message id required' });

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const replyBody = body.body != null ? String(body.body).trim() : '';
  if (!replyBody) return res.status(400).json({ error: 'Reply body is required' });
  if (replyBody.length > 5000) return res.status(400).json({ error: 'Reply is too long' });

  try {
    const existing = await sql`
      SELECT id FROM contact_messages WHERE id = ${id}
    `;
    if (!existing || existing.length === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }
    await sql`
      INSERT INTO contact_message_replies (contact_message_id, body)
      VALUES (${id}, ${replyBody})
    `;
    return res.status(201).json({ ok: true });
  } catch (err) {
    if (err?.code === '42P01') {
      return res.status(503).json({ error: 'Replies are not set up yet.' });
    }
    console.error('contact reply POST', err);
    return res.status(500).json({ error: 'Failed to send reply' });
  }
}
