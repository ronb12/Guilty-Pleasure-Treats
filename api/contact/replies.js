/**
 * GET /api/contact/replies - list replies to the current user's contact messages (authenticated).
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

function rowToReply(row) {
  if (!row) return null;
  return {
    id: row.id,
    contactMessageId: row.contact_message_id,
    body: row.body,
    subject: row.subject ?? null,
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
  if ((req.method || '').toUpperCase() !== 'GET') return res.status(405).json({ error: 'Method not allowed' });

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) return res.status(401).json({ error: 'Sign in required' });
  if (!hasDb() || !sql) return res.status(200).json([]);

  try {
    const rows = await sql`
      SELECT r.id, r.contact_message_id, r.body, r.created_at, m.subject
      FROM contact_message_replies r
      JOIN contact_messages m ON m.id = r.contact_message_id
      WHERE m.user_id = ${session.userId}
      ORDER BY r.created_at DESC
      LIMIT 200
    `;
    return res.status(200).json(rows.map(rowToReply));
  } catch (err) {
    if (err?.code === '42P01') return res.status(200).json([]);
    console.error('[contact/replies] GET', err);
    return res.status(500).json({ error: 'Failed to fetch replies' });
  }
}
