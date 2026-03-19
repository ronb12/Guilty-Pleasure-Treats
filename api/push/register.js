/**
 * POST /api/push/register — register device token for push (admin: new-order/new-message; customer: order-status).
 * Body: { deviceToken: string }. Requires auth.
 */
import { sql, hasDb } from '../lib/db.js';
import { getTokenFromRequest, getSession } from '../../api/lib/auth.js';
import { setCors, handleOptions } from '../lib/cors.js';

export default async function handler(req, res) {
  setCors(res);
  if ((req.method || '').toUpperCase() === 'OPTIONS') {
    handleOptions(res);
    return;
  }
  if ((req.method || '').toUpperCase() !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const token = getTokenFromRequest(req);
  const session = token ? await getSession(token) : null;
  if (!session?.userId) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  const deviceToken = (req.body?.deviceToken ?? req.body?.device_token ?? '').trim();
  if (!deviceToken) {
    return res.status(400).json({ error: 'deviceToken is required' });
  }

  if (!hasDb() || !sql) {
    return res.status(503).json({ error: 'Service unavailable' });
  }

  try {
    const userId = session.userId;
    const isAdmin = session.isAdmin === true;
    await sql`
      INSERT INTO push_tokens (user_id, device_token, is_admin, updated_at)
      VALUES (${userId}, ${deviceToken}, ${isAdmin}, NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        device_token = EXCLUDED.device_token,
        is_admin = EXCLUDED.is_admin,
        updated_at = NOW()
    `;
    return res.status(200).json({ ok: true });
  } catch (err) {
    if (err?.code === '42P01') return res.status(503).json({ error: 'Service unavailable' });
    console.error('[push/register]', err);
    return res.status(500).json({ error: 'Failed to register device' });
  }
}
