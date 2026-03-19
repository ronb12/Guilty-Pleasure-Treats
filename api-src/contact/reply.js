/**
 * POST /api/contact/:id/reply - admin sends an in-app reply to a contact message.
 * Body: { body: string }
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');
  const messageId = req.query?.id;
  if (!messageId) return res.status(400).json({ error: 'Missing message id' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.isAdmin) return res.status(403).json({ error: 'Admin required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Database not configured' });
  if ((req.method || '').toUpperCase() !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const body = req.body || {};
  const replyBody = String(body.body ?? '').trim();
  if (!replyBody) return res.status(400).json({ error: 'Reply body is required' });

  try {
    const msgRows = await sql`SELECT id FROM contact_messages WHERE id = ${messageId} LIMIT 1`;
    if (!msgRows.length) return res.status(404).json({ error: 'Message not found' });
    await sql`
      INSERT INTO contact_message_replies (contact_message_id, body)
      VALUES (${messageId}, ${replyBody})
    `;
    return res.status(201).json({ ok: true });
  } catch (err) {
    if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
    console.error('[contact/reply] POST', err);
    return res.status(500).json({ error: 'Failed to send reply' });
  }
}
