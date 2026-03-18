/**
 * GET /api/messages - authenticated user fetches admin-initiated messages sent to them.
 */
import { sql, hasDb } from '../../api/lib/db.js';
import { setCors, handleOptions } from '../../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';

function rowToMessage(row) {
  if (!row) return null;
  return {
    id: row.id,
    body: row.body,
    createdAt: row.created_at ? new Date(row.created_at).toISOString() : null,
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
  if (!session || !session.userId) {
    return res.status(401).json({ error: 'Sign in to view messages' });
  }

  const userId = session.userId;

  try {
    const rows = await sql`
      SELECT id, body, created_at
      FROM admin_messages
      WHERE to_user_id = ${userId}
      ORDER BY created_at DESC
      LIMIT 100
    `;
    return res.status(200).json((rows || []).map(rowToMessage));
  } catch (err) {
    if (err?.code === '42P01') {
      return res.status(200).json([]);
    }
    console.error('messages GET', err);
    return res.status(500).json({ error: 'Failed to load messages' });
  }
}
