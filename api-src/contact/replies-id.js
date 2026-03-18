/**
 * GET /api/contact/:id/replies - admin fetches replies for a contact message (thread).
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToReply(row) {
  if (!row) return null;
  return {
    id: row.id,
    contactMessageId: row.contact_message_id,
    body: row.body,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
    subject: row.subject ?? null,
  };
}

export default async function handler(req, res) {
  setCors(res);
  if (req.method === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if (req.method !== 'GET') {
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

  try {
    const rows = await sql`
      SELECT r.id, r.contact_message_id, r.body, r.created_at, m.subject
      FROM contact_message_replies r
      JOIN contact_messages m ON m.id = r.contact_message_id
      WHERE r.contact_message_id = ${id}
      ORDER BY r.created_at ASC
      LIMIT 100
    `;
    return res.status(200).json((rows || []).map(rowToReply));
  } catch (err) {
    if (err?.code === '42P01') {
      return res.status(200).json([]);
    }
    console.error('contact/id/replies GET', err);
    return res.status(500).json({ error: 'Failed to load replies' });
  }
}
