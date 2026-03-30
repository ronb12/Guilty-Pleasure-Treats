/**
 * POST /api/admin-messages - admin sends a message to a customer (or all).
 * Body: { toUserId?: string, toUserEmail?: string, body: string }
 * If toUserId provided, send to that user. If toUserEmail, look up user by email. If neither, send to all non-admin tokens (broadcast).
 * Inserts into admin_messages, then sends push via notifyAdminMessage.
 */
import { sql, hasDb } from './lib/db.js';
import { getAuth } from './lib/auth.js';
import { setCors, handleOptions } from './lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  res.setHeader('Content-Type', 'application/json');

  const auth = await getAuth(req);
  if (!auth?.userId || !auth?.isAdmin) return res.status(403).json({ error: 'Admin required' });
  if (!hasDb() || !sql) return res.status(503).json({ error: 'Service unavailable' });
  if ((req.method || '').toUpperCase() !== 'POST') return res.status(405).json({ error: 'Method not allowed' });

  const body = req.body || {};
  const messageBody = String(body.body ?? '').trim();
  if (!messageBody) return res.status(400).json({ error: 'body is required' });

  const toUserId = body.toUserId != null ? String(body.toUserId).trim() || null : null;
  const toUserEmail = body.toUserEmail != null ? String(body.toUserEmail).trim() || null : null;

  try {
    let targetUserIds = [];
    if (toUserId) {
      targetUserIds = [toUserId];
    } else if (toUserEmail) {
      const rows = await sql`SELECT id FROM users WHERE LOWER(email) = LOWER(${toUserEmail}) LIMIT 1`;
      if (!rows.length) return res.status(404).json({ error: 'User not found for that email' });
      targetUserIds = [rows[0].id];
    } else {
      const rows = await sql`SELECT id FROM users WHERE is_admin = false AND id IS NOT NULL`;
      targetUserIds = (rows || []).map((r) => r.id).filter(Boolean);
    }

    const tokensByUser = new Map();
    if (targetUserIds.length > 0) {
      const tokenRows = await sql`
        SELECT user_id, device_token FROM push_tokens
        WHERE (is_admin = false OR is_admin IS NULL)
        AND device_token IS NOT NULL AND device_token != ''
        AND user_id IN ${sql(targetUserIds)}
      `;
      for (const r of tokenRows || []) {
        if (!r.device_token) continue;
        const uid = r.user_id?.toString?.() ?? r.user_id;
        if (!tokensByUser.has(uid)) tokensByUser.set(uid, []);
        tokensByUser.get(uid).push(r.device_token);
      }
    }

    const allTokens = [];
    const insertedIds = [];
    for (const uid of targetUserIds) {
      const [row] = await sql`
        INSERT INTO admin_messages (to_user_id, body)
        VALUES (${uid}, ${messageBody})
        RETURNING id
      `;
      const id = row?.id?.toString?.() ?? row?.id;
      if (id) insertedIds.push(id);
      const tokens = tokensByUser.get(uid?.toString?.() ?? uid) || [];
      allTokens.push(...tokens);
    }

    if (allTokens.length > 0 && insertedIds.length > 0) {
      try {
        const { notifyAdminMessage } = await import('../api/lib/apns.js');
        const title = 'Message from Guilty Pleasure Treats';
        notifyAdminMessage(allTokens, insertedIds[0], title, messageBody);
      } catch (e) {
        console.warn('[admin-messages] push', e?.message ?? e);
      }
    }

    return res.status(201).json({
      ok: true,
      sentTo: targetUserIds.length,
      pushSent: allTokens.length,
      messageIds: insertedIds,
    });
  } catch (err) {
    if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
    console.error('[admin-messages] POST', err);
    return res.status(500).json({ error: 'Failed to send message' });
  }
}
