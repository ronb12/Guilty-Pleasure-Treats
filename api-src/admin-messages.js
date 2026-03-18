/**
 * GET /api/admin-messages - admin lists all messages they sent (like Sent folder).
 * POST /api/admin-messages - admin sends a new message. Body: { toUserId: string, body: string }
 */
import { sql, hasDb } from '../api/lib/db.js';
import { setCors, handleOptions } from '../api/lib/cors.js';
import { getTokenFromRequest, getSession } from '../api/lib/auth.js';

function rowToMessage(row) {
  if (!row) return null;
  return {
    id: row.id,
    toUserId: row.to_user_id,
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
  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Database not configured' });
  }

  const token = getTokenFromRequest(req);
  const session = await getSession(token);
  if (!session || !session.isAdmin) {
    return res.status(401).json({ error: 'Admin access required' });
  }

  if (req.method === 'GET') {
    try {
      const rows = await sql`
        SELECT id, to_user_id, body, created_at
        FROM admin_messages
        ORDER BY created_at DESC
        LIMIT 200
      `;
      return res.status(200).json((rows || []).map(rowToMessage));
    } catch (err) {
      if (err?.code === '42P01') {
        return res.status(200).json([]);
      }
      console.error('admin-messages GET', err);
      return res.status(500).json({ error: 'Failed to load sent messages' });
    }
  }

  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const body = req.body && typeof req.body === 'object' ? req.body : {};
  const toUserId = body.toUserId != null ? String(body.toUserId).trim() : '';
  const messageBody = body.body != null ? String(body.body).trim() : '';
  if (!toUserId) return res.status(400).json({ error: 'toUserId is required' });
  if (!messageBody) return res.status(400).json({ error: 'body is required' });
  if (messageBody.length > 5000) return res.status(400).json({ error: 'Message is too long' });

  try {
    const rows = await sql`
      INSERT INTO admin_messages (to_user_id, body)
      VALUES (${toUserId}, ${messageBody})
      RETURNING id, to_user_id, body, created_at
    `;
    const created = rows[0];
    if (!created) return res.status(500).json({ error: 'Failed to save message' });
    return res.status(201).json({
      id: created.id,
      toUserId: created.to_user_id,
      body: created.body,
      createdAt: created.created_at ? new Date(created.created_at).toISOString() : null,
    });
  } catch (err) {
    if (err?.code === '42P01') {
      return res.status(503).json({ error: 'Messages are not set up yet. Run admin-messages-schema.sql in Neon.' });
    }
    console.error('admin-messages POST', err);
    return res.status(500).json({ error: 'Failed to send message' });
  }
}
