/**
 * PATCH /api/contact/:id - mark contact message as read (admin only).
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
  if (req.method !== 'PATCH') {
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
    await sql`
      UPDATE contact_messages SET read_at = NOW() WHERE id = ${id} AND read_at IS NULL
    `;
    return res.status(200).json({ ok: true });
  } catch (err) {
    console.error('contact PATCH', err);
    return res.status(500).json({ error: 'Failed to update message' });
  }
}
